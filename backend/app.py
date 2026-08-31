import concurrent.futures
import logging
import os
from datetime import datetime, timezone

from flask import Flask, g, jsonify, render_template, request, send_from_directory
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address
from werkzeug.security import check_password_hash, generate_password_hash

import config
from auth import issue_token, require_auth
from face_service import (
    MultipleFacesFoundError,
    NoFaceFoundError,
    closest_student,
    detect_faces_in_array,
    encode_single_face_from_array,
    process_image,
)
from firebase_service import send_attendance_notification
from storage_service import upload_image
from supabase_client import get_supabase

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)
app.config["SECRET_KEY"] = config.SECRET_KEY
app.config["MAX_CONTENT_LENGTH"] = 16 * 1024 * 1024  # 16 MB, enough for two classroom photos

limiter = Limiter(get_remote_address, app=app, default_limits=["200 per hour"])

# Face crop uploads / DB inserts / FCM sends are network round-trips to Supabase - running them one
# face at a time (as the old code did) meant a 30-face class made 60-90 sequential HTTP calls. Batching
# them across a thread pool turns that into a handful of concurrent calls.
MAX_WORKERS = 8

# Load student face encodings into cache at startup so every attendance request uses the in-memory
# dict instead of hitting Supabase on every request.
refresh_known_students()

# Cache for student face encodings loaded from Supabase.
# Structure: {student_id: {"encoding": [...], "full_name": ..., "roll_number": ..., "fcm_token": ...}}
# Loaded once at startup and refreshed when students are registered.
known_students_cache: dict = {}

def refresh_known_students():
    """Load all student face encodings from Supabase into the cache."""
    global known_students_cache
    supabase = get_supabase()
    result = supabase.table("student_face_encodings").select(
        "student_id, face_encoding, students!inner(id, full_name, roll_number, fcm_token, class_name)"
    ).execute()
    cache = {}
    for row in result.data:
        student_id = row["student_id"]
        cache[student_id] = {
            "encoding": row["face_encoding"],
            "full_name": row["students"]["full_name"],
            "roll_number": row["students"]["roll_number"],
            "fcm_token": row["students"]["fcm_token"],
    }
    known_students_cache = cache
    logger.info(f"Loaded {len(cache)} student face encodings into cache")


def error_response(message: str, status: int = 400):
    return jsonify({"error": message}), status


# ---------------------------------------------------------------------------
# Pages (student attendance web app - registration is app-only, see student_app/)
# ---------------------------------------------------------------------------

@app.get("/")
def index():
    return render_template("index.html")


@app.get("/dashboard")
def dashboard_page():
    return render_template("dashboard.html")


@app.get("/about")
def about_page():
    return render_template("about.html")


@app.get("/downloads")
def downloads_page():
    downloads_dir = os.path.join(app.static_folder, "downloads")
    apks = {
        "teacher": os.path.isfile(os.path.join(downloads_dir, "teacher_app.apk")),
        "student": os.path.isfile(os.path.join(downloads_dir, "student_app.apk")),
    }
    return render_template("downloads.html", apks=apks)


@app.get("/downloads/apk/<apk_name>")
def download_apk(apk_name):
    if apk_name not in ("teacher_app.apk", "student_app.apk"):
        return error_response("Not found.", status=404)

    downloads_dir = os.path.join(app.static_folder, "downloads")
    # Every rebuilt APK reuses the same filename, so without this the browser (and phones especially)
    # will happily serve a stale cached copy instead of re-downloading after an update.
    response = send_from_directory(downloads_dir, apk_name, as_attachment=True, conditional=False)
    response.headers["Cache-Control"] = "no-store, no-cache, must-revalidate, max-age=0"
    response.headers.pop("ETag", None)
    return response


@app.get("/firebase-messaging-sw.js")
def firebase_messaging_sw():
    # Served from the root path (not /static/...) so its default service-worker scope covers the whole site.
    return send_from_directory(app.static_folder, "firebase-messaging-sw.js")


# ---------------------------------------------------------------------------
# Students
# ---------------------------------------------------------------------------

# Poses a student can submit at registration. "front" is mandatory; the rest are optional extra
# angles that improve recognition accuracy in group photos taken from odd angles/distances.
POSE_FIELDS = {
    "photo_front": "front",
    "photo_left": "left",
    "photo_right": "right",
    "photo_extra": "extra",
}


@app.post("/api/students/register")
@limiter.limit("10 per hour")
def register_student():
    full_name = request.form.get("full_name", "").strip()
    roll_number = request.form.get("roll_number", "").strip()
    class_name = request.form.get("class_name", "").strip()
    password = request.form.get("password", "")
    front_photo = request.files.get("photo_front")

    if not full_name or not roll_number or not class_name or not password or not front_photo:
        return error_response(
            "full_name, roll_number, class_name, password and photo_front are all required."
        )
    if len(password) < 4:
        return error_response("password must be at least 4 characters.")

    pose_photos = []
    for field_name, pose_label in POSE_FIELDS.items():
        file = request.files.get(field_name)
        if file:
            pose_photos.append((pose_label, file.read()))

    encoded_poses = []
    skipped_poses = []
    for pose_label, photo_bytes in pose_photos:
        try:
            processed = process_image(photo_bytes)
            encoding = encode_single_face_from_array(processed.rgb_array)
        except (NoFaceFoundError, MultipleFacesFoundError) as exc:
            if pose_label == "front":
                return error_response(f"{pose_label} photo: {exc}")
            # Profile angles (left/right/extra) are optional accuracy boosters - dlib's detector often
            # can't find a face in a strongly turned profile shot, so skip rather than block the whole
            # registration over a photo that was never required.
            skipped_poses.append(pose_label)
            continue
        # Store the downscaled photo, not the original multi-MB phone capture.
        encoded_poses.append((pose_label, processed.downscaled_jpeg_bytes, encoding))

    supabase = get_supabase()

    existing = supabase.table("students").select("id").eq("roll_number", roll_number).execute()
    if existing.data:
        return error_response(f"Roll number '{roll_number}' is already registered.", status=409)

    front_url = upload_image(config.BUCKET_STUDENT_PHOTOS, dict((p, b) for p, b, _ in encoded_poses)["front"])

    student_result = (
        supabase.table("students")
        .insert(
            {
                "full_name": full_name,
                "roll_number": roll_number,
                "class_name": class_name,
                "photo_url": front_url,
                "password_hash": generate_password_hash(password),
            }
        )
        .execute()
    )
    student = student_result.data[0]

    encoding_rows = []
    for pose_label, _photo_bytes, encoding in encoded_poses:
        encoding_rows.append({"student_id": student["id"], "pose_label": pose_label, "face_encoding": encoding})
    supabase.table("student_face_encodings").insert(encoding_rows).execute()
    refresh_known_students()

    return jsonify(
        {
            "token": issue_token("student", student["id"]),
            "id": student["id"],
            "full_name": student["full_name"],
            "roll_number": student["roll_number"],
            "class_name": student["class_name"],
            "photo_url": student["photo_url"],
            "poses_registered": len(encoded_poses),
            "poses_skipped": skipped_poses,
        }
    ), 201


@app.post("/api/students/login")
@limiter.limit("10 per minute")
def login_student():
    body = request.get_json(silent=True) or {}
    roll_number = body.get("roll_number", "").strip()
    password = body.get("password", "")
    if not roll_number or not password:
        return error_response("roll_number and password are required.")

    supabase = get_supabase()
    result = (
        supabase.table("students")
        .select("id, full_name, roll_number, class_name, photo_url, password_hash")
        .eq("roll_number", roll_number)
        .execute()
    )
    student = result.data[0] if result.data else None
    if not student or not student.get("password_hash") or not check_password_hash(
        student["password_hash"], password
    ):
        return error_response("Invalid roll number or password.", status=401)

    return jsonify(
        {
            "token": issue_token("student", student["id"]),
            "id": student["id"],
            "full_name": student["full_name"],
            "roll_number": student["roll_number"],
            "class_name": student["class_name"],
            "photo_url": student["photo_url"],
        }
    )


@app.post("/api/students/<student_id>/fcm-token")
@require_auth("student")
def save_fcm_token(student_id):
    if g.auth_subject_id != student_id:
        return error_response("Forbidden.", status=403)

    body = request.get_json(silent=True) or {}
    token = body.get("token", "").strip()
    if not token:
        return error_response("token is required.")

    supabase = get_supabase()
    supabase.table("students").update({"fcm_token": token}).eq("id", student_id).execute()
    return jsonify({"status": "ok"})


@app.get("/api/students/<student_id>/attendance")
@require_auth("student")
def student_attendance_history(student_id):
    if g.auth_subject_id != student_id:
        return error_response("Forbidden.", status=403)

    supabase = get_supabase()
    result = (
        supabase.table("attendance_records")
        .select("id, face_crop_url, confidence, marked_at, attendance_sessions(class_name, session_date)")
        .eq("student_id", student_id)
        .order("marked_at", desc=True)
        .execute()
    )
    return jsonify(result.data)


# ---------------------------------------------------------------------------
# Teachers
# ---------------------------------------------------------------------------

def _teacher_public_fields(teacher: dict) -> dict:
    return {
        "id": teacher["id"],
        "name": teacher["name"],
        "teaching_id": teacher["teaching_id"],
        "email": teacher["email"],
        "courses": teacher.get("courses", []),
    }


@app.post("/api/teachers/register")
@limiter.limit("10 per hour")
def register_teacher():
    body = request.get_json(silent=True) or {}
    name = body.get("name", "").strip()
    teaching_id = body.get("teaching_id", "").strip()
    email = body.get("email", "").strip().lower()
    password = body.get("password", "")
    courses = [c.strip() for c in body.get("courses", []) if isinstance(c, str) and c.strip()]

    if not name or not teaching_id or not email or not password:
        return error_response("name, teaching_id, email and password are required.")

    supabase = get_supabase()
    existing = (
        supabase.table("teachers")
        .select("id")
        .or_(f"email.eq.{email},teaching_id.eq.{teaching_id}")
        .execute()
    )
    if existing.data:
        return error_response("A teacher with this email or teaching ID already exists.", status=409)

    password_hash = generate_password_hash(password)
    result = (
        supabase.table("teachers")
        .insert(
            {
                "name": name,
                "teaching_id": teaching_id,
                "email": email,
                "password_hash": password_hash,
                "courses": courses,
            }
        )
        .execute()
    )
    teacher = result.data[0]
    return jsonify({"token": issue_token("teacher", teacher["id"]), **_teacher_public_fields(teacher)}), 201


@app.post("/api/teachers/login")
@limiter.limit("10 per minute")
def login_teacher():
    body = request.get_json(silent=True) or {}
    email = body.get("email", "").strip().lower()
    password = body.get("password", "")

    supabase = get_supabase()
    result = supabase.table("teachers").select("*").eq("email", email).execute()
    if not result.data or not check_password_hash(result.data[0]["password_hash"], password):
        return error_response("Invalid email or password.", status=401)

    teacher = result.data[0]
    return jsonify({"token": issue_token("teacher", teacher["id"]), **_teacher_public_fields(teacher)})


# ---------------------------------------------------------------------------
# Attendance
# ---------------------------------------------------------------------------

@app.post("/api/attendance/mark")
@require_auth("teacher")
@limiter.limit("30 per minute")
def mark_attendance():
    # The token identifies the teacher now - a client can no longer just pass any teacher_id in
    # the form and have it trusted.
    teacher_id = g.auth_subject_id
    class_name = request.form.get("class_name", "").strip()
    left_image = request.files.get("left_image")
    right_image = request.files.get("right_image")

    if not class_name or not left_image or not right_image:
        return error_response("class_name, left_image and right_image are all required.")

    left_bytes = left_image.read()
    right_bytes = right_image.read()

    # Use cached student encodings instead of querying Supabase on every request.
    # The cache is loaded at startup and refreshed when students are registered.
    known_students = list(known_students_cache.values())
    total_registered_students = len(known_students_cache)

    session_result = (
        supabase.table("attendance_sessions")
        .insert({"teacher_id": teacher_id or None, "class_name": class_name})
        .execute()
    )
    session = session_result.data[0]
    session_id = session["id"]

    # Decode + downscale both photos once (in parallel) - the resulting array feeds face detection
    # and the re-encoded JPEG is what gets uploaded, instead of paying for a second decode and
    # uploading the original multi-MB phone photo.
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
        left_processed, right_processed = pool.map(process_image, [left_bytes, right_bytes])

    # Uploads are pure network waiting, cheap to run concurrently. Face detection (dlib/HOG) is the
    # actually memory-heavy step - running it on both photos at once nearly doubled peak memory and
    # was tipping Render's free-tier 512MB instance into OOM restarts. Keep detection sequential; the
    # uploads below still overlap with it on their own threads either way.
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
        left_url_future = pool.submit(upload_image, config.BUCKET_ATTENDANCE_IMAGES, left_processed.downscaled_jpeg_bytes)
        right_url_future = pool.submit(upload_image, config.BUCKET_ATTENDANCE_IMAGES, right_processed.downscaled_jpeg_bytes)

        left_faces = detect_faces_in_array(left_processed.rgb_array)
        right_faces = detect_faces_in_array(right_processed.rgb_array)

        left_url = left_url_future.result()
        right_url = right_url_future.result()

    all_faces = [("left", f) for f in left_faces] + [("right", f) for f in right_faces]
    total_faces_detected = len(all_faces)

    # Work out every match first - this is pure in-memory numpy math, no network calls, so it's cheap
    # even for a full class.
    matched_student_ids = set()
    face_infos = []
    for source_label, face in all_faces:
        candidate, distance = closest_student(face.encoding, known_students)
        is_match = candidate is not None and distance <= config.FACE_MATCH_THRESHOLD
        # A student appearing in both photos (or twice in one) only gets marked present once - the
        # unique(session_id, student_id) constraint enforces that at the DB level too.
        already_marked = is_match and candidate["id"] in matched_student_ids
        if is_match and not already_marked:
            matched_student_ids.add(candidate["id"])
        face_infos.append(
            {
                "source_label": source_label,
                "face": face,
                "candidate": candidate,
                "distance": distance,
                "is_match": is_match,
                "already_marked": already_marked,
            }
        )

    # Upload every face crop concurrently instead of one at a time.
    if face_infos:
        with concurrent.futures.ThreadPoolExecutor(max_workers=MAX_WORKERS) as pool:
            crop_urls = list(
                pool.map(
                    lambda info: upload_image(config.BUCKET_FACE_CROPS, info["face"].crop_jpeg_bytes),
                    face_infos,
                )
            )
    else:
        crop_urls = []

    # One batch insert for every detected face instead of one insert per face.
    records_payload = [
        {
            "session_id": session_id,
            "student_id": info["candidate"]["id"] if (info["is_match"] and not info["already_marked"]) else None,
            "source_image": info["source_label"],
            "face_crop_url": face_crop_url,
            "confidence": round(1 - info["distance"], 4) if info["is_match"] else None,
        }
        for info, face_crop_url in zip(face_infos, crop_urls)
    ]
    inserted_records = (
        supabase.table("attendance_records").insert(records_payload).execute().data if records_payload else []
    )

    marked_at_iso = datetime.now(timezone.utc).isoformat()
    detected_faces = []

    # Push notifications go out concurrently too - the response doesn't wait on them one at a time.
    with concurrent.futures.ThreadPoolExecutor(max_workers=MAX_WORKERS) as pool:
        for info, face_crop_url, record in zip(face_infos, crop_urls, inserted_records):
            candidate = info["candidate"]
            is_match = info["is_match"]
            already_marked = info["already_marked"]
            distance = info["distance"]
            confidence = round(1 - distance, 4) if is_match else None

            if is_match and not already_marked and candidate.get("fcm_token"):
                pool.submit(
                    send_attendance_notification,
                    candidate["fcm_token"],
                    candidate["full_name"],
                    class_name,
                    marked_at_iso,
                    face_crop_url,
                )

            # "Unknown" faces still carry the nearest candidate's name/distance as a hint - lets the
            # teacher confirm a near-miss with one tap instead of typing the roll number from scratch.
            has_hint = candidate is not None and not is_match
            detected_faces.append(
                {
                    "record_id": record["id"],
                    "face_crop_url": face_crop_url,
                    "source_image": info["source_label"],
                    "student_id": candidate["id"] if is_match else None,
                    "full_name": candidate["full_name"] if is_match else None,
                    "roll_number": candidate["roll_number"] if is_match else None,
                    "confidence": confidence,
                    "closest_guess_name": candidate["full_name"] if has_hint else None,
                    "closest_guess_roll_number": candidate["roll_number"] if has_hint else None,
                    "closest_guess_distance": round(distance, 4) if has_hint else None,
                }
            )

    supabase.table("attendance_sessions").update(
        {
            "left_image_url": left_url,
            "right_image_url": right_url,
            "total_faces_detected": total_faces_detected,
            "total_students_recognized": len(matched_student_ids),
        }
    ).eq("id", session_id).execute()

    return jsonify(
        {
            "session_id": session_id,
            "class_name": class_name,
            "session_date": session["session_date"],
            "total_registered_students": total_registered_students,
            "total_faces_detected": total_faces_detected,
            "total_students_recognized": len(matched_student_ids),
            "unrecognized_faces_count": total_faces_detected - len(matched_student_ids),
            "detected_faces": detected_faces,
            "match_threshold": config.FACE_MATCH_THRESHOLD,
        }
    ), 201


@app.post("/api/attendance/records/<record_id>/identify")
@require_auth("teacher")
def identify_attendance_record(record_id):
    """Lets a teacher assign a name to a face the automatic matching left as "unknown"."""
    body = request.get_json(silent=True) or {}
    roll_number = body.get("roll_number", "").strip()
    if not roll_number:
        return error_response("roll_number is required.")

    supabase = get_supabase()

    record_result = (
        supabase.table("attendance_records")
        .select("*, attendance_sessions(class_name)")
        .eq("id", record_id)
        .execute()
    )
    if not record_result.data:
        return error_response("Attendance record not found.", status=404)
    record = record_result.data[0]

    if record["student_id"]:
        return error_response("This face is already identified.", status=409)

    student_result = (
        supabase.table("students")
        .select("id, full_name, roll_number, fcm_token")
        .eq("roll_number", roll_number)
        .execute()
    )
    if not student_result.data:
        return error_response(f"No student found with roll number '{roll_number}'.")
    student = student_result.data[0]

    already_marked = (
        supabase.table("attendance_records")
        .select("id")
        .eq("session_id", record["session_id"])
        .eq("student_id", student["id"])
        .execute()
    )
    if already_marked.data:
        return error_response(f"{student['full_name']} is already marked present in this session.", status=409)

    supabase.table("attendance_records").update(
        {"student_id": student["id"], "manually_confirmed": True}
    ).eq("id", record_id).execute()

    matched_count = (
        supabase.table("attendance_records")
        .select("student_id")
        .eq("session_id", record["session_id"])
        .execute()
    )
    unique_matched = len({r["student_id"] for r in matched_count.data if r["student_id"]})
    supabase.table("attendance_sessions").update({"total_students_recognized": unique_matched}).eq(
        "id", record["session_id"]
    ).execute()

    if student.get("fcm_token"):
        class_name = record["attendance_sessions"]["class_name"]
        marked_at_iso = record.get("marked_at") or datetime.now(timezone.utc).isoformat()
        send_attendance_notification(
            student["fcm_token"], student["full_name"], class_name, marked_at_iso, record.get("face_crop_url")
        )

    return jsonify(
        {
            "record_id": record_id,
            "student_id": student["id"],
            "full_name": student["full_name"],
            "roll_number": student["roll_number"],
        }
    )


@app.get("/api/attendance/sessions/<session_id>/report")
@require_auth("teacher")
def attendance_session_report(session_id):
    supabase = get_supabase()
    session_result = supabase.table("attendance_sessions").select("*").eq("id", session_id).execute()
    if not session_result.data:
        return error_response("Session not found.", status=404)
    session = session_result.data[0]

    records_result = (
        supabase.table("attendance_records")
        .select("id, student_id, confidence, face_crop_url, source_image, students(full_name, roll_number)")
        .eq("session_id", session_id)
        .execute()
    )

    detected_faces = [
        {
            "record_id": r["id"],
            "student_id": r["student_id"],
            "full_name": r["students"]["full_name"] if r["students"] else None,
            "roll_number": r["students"]["roll_number"] if r["students"] else None,
            "confidence": r["confidence"],
            "face_crop_url": r["face_crop_url"],
            "source_image": r["source_image"],
        }
        for r in records_result.data
    ]

    return jsonify({**session, "detected_faces": detected_faces})


if __name__ == "__main__":
    app.run(debug=True, port=5000)
