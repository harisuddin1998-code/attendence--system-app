import logging
import os
from datetime import datetime, timezone

from flask import Flask, jsonify, render_template, request, send_from_directory
from werkzeug.security import check_password_hash, generate_password_hash

import config
from face_service import (
    MultipleFacesFoundError,
    NoFaceFoundError,
    detect_faces_in_group_photo,
    encode_single_face,
    match_face_to_student,
)
from firebase_service import send_attendance_notification
from storage_service import upload_image
from supabase_client import get_supabase

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)
app.config["SECRET_KEY"] = config.SECRET_KEY
app.config["MAX_CONTENT_LENGTH"] = 16 * 1024 * 1024  # 16 MB, enough for two classroom photos


def error_response(message: str, status: int = 400):
    return jsonify({"error": message}), status


# ---------------------------------------------------------------------------
# Pages (student registration web app)
# ---------------------------------------------------------------------------

@app.get("/")
def index():
    return render_template("index.html")


@app.get("/register")
def register_page():
    return render_template("register.html")


@app.get("/dashboard")
def dashboard_page():
    return render_template("dashboard.html")


@app.get("/downloads")
def downloads_page():
    downloads_dir = os.path.join(app.static_folder, "downloads")
    apks = {
        "teacher": os.path.isfile(os.path.join(downloads_dir, "teacher_app.apk")),
        "student": os.path.isfile(os.path.join(downloads_dir, "student_app.apk")),
    }
    return render_template("downloads.html", apks=apks)


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
def register_student():
    full_name = request.form.get("full_name", "").strip()
    roll_number = request.form.get("roll_number", "").strip()
    class_name = request.form.get("class_name", "").strip()
    front_photo = request.files.get("photo_front")

    if not full_name or not roll_number or not class_name or not front_photo:
        return error_response("full_name, roll_number, class_name and photo_front are all required.")

    pose_photos = []
    for field_name, pose_label in POSE_FIELDS.items():
        file = request.files.get(field_name)
        if file:
            pose_photos.append((pose_label, file.read()))

    encoded_poses = []
    for pose_label, photo_bytes in pose_photos:
        try:
            encoding = encode_single_face(photo_bytes)
        except (NoFaceFoundError, MultipleFacesFoundError) as exc:
            return error_response(f"{pose_label} photo: {exc}")
        encoded_poses.append((pose_label, photo_bytes, encoding))

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
            }
        )
        .execute()
    )
    student = student_result.data[0]

    encoding_rows = []
    for pose_label, _photo_bytes, encoding in encoded_poses:
        encoding_rows.append({"student_id": student["id"], "pose_label": pose_label, "face_encoding": encoding})
    supabase.table("student_face_encodings").insert(encoding_rows).execute()

    return jsonify(
        {
            "id": student["id"],
            "full_name": student["full_name"],
            "roll_number": student["roll_number"],
            "class_name": student["class_name"],
            "photo_url": student["photo_url"],
            "poses_registered": len(encoded_poses),
        }
    ), 201


@app.get("/api/students/lookup")
def lookup_student():
    roll_number = request.args.get("roll_number", "").strip()
    if not roll_number:
        return error_response("roll_number query param is required.")

    supabase = get_supabase()
    result = (
        supabase.table("students")
        .select("id, full_name, roll_number, class_name, photo_url")
        .eq("roll_number", roll_number)
        .execute()
    )
    if not result.data:
        return error_response("No student found with that roll number.", status=404)
    return jsonify(result.data[0])


@app.post("/api/students/<student_id>/fcm-token")
def save_fcm_token(student_id):
    body = request.get_json(silent=True) or {}
    token = body.get("token", "").strip()
    if not token:
        return error_response("token is required.")

    supabase = get_supabase()
    supabase.table("students").update({"fcm_token": token}).eq("id", student_id).execute()
    return jsonify({"status": "ok"})


@app.get("/api/students/<student_id>/attendance")
def student_attendance_history(student_id):
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
# Teachers (minimal auth, no JWT - MVP)
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
    return jsonify(_teacher_public_fields(result.data[0])), 201


@app.post("/api/teachers/login")
def login_teacher():
    body = request.get_json(silent=True) or {}
    email = body.get("email", "").strip().lower()
    password = body.get("password", "")

    supabase = get_supabase()
    result = supabase.table("teachers").select("*").eq("email", email).execute()
    if not result.data or not check_password_hash(result.data[0]["password_hash"], password):
        return error_response("Invalid email or password.", status=401)

    return jsonify(_teacher_public_fields(result.data[0]))


# ---------------------------------------------------------------------------
# Attendance
# ---------------------------------------------------------------------------

@app.post("/api/attendance/mark")
def mark_attendance():
    teacher_id = request.form.get("teacher_id", "").strip()
    class_name = request.form.get("class_name", "").strip()
    left_image = request.files.get("left_image")
    right_image = request.files.get("right_image")

    if not class_name or not left_image or not right_image:
        return error_response("class_name, left_image and right_image are all required.")

    left_bytes = left_image.read()
    right_bytes = right_image.read()

    supabase = get_supabase()

    # One row per registered pose photo - a student with 4 poses appears 4 times here, each with a
    # different face_encoding, so a face can match whichever of their angles is closest.
    encodings_result = (
        supabase.table("student_face_encodings")
        .select("student_id, face_encoding, students!inner(id, full_name, roll_number, fcm_token, class_name)")
        .eq("students.class_name", class_name)
        .execute()
    )
    known_students = [
        {
            "id": row["students"]["id"],
            "full_name": row["students"]["full_name"],
            "roll_number": row["students"]["roll_number"],
            "fcm_token": row["students"]["fcm_token"],
            "face_encoding": row["face_encoding"],
        }
        for row in encodings_result.data
    ]
    total_registered_students = len({s["id"] for s in known_students})

    session_result = (
        supabase.table("attendance_sessions")
        .insert({"teacher_id": teacher_id or None, "class_name": class_name})
        .execute()
    )
    session = session_result.data[0]
    session_id = session["id"]

    left_url = upload_image(config.BUCKET_ATTENDANCE_IMAGES, left_bytes)
    right_url = upload_image(config.BUCKET_ATTENDANCE_IMAGES, right_bytes)

    matched_student_ids = set()
    recognized = []
    total_faces_detected = 0
    marked_at_iso = datetime.now(timezone.utc).isoformat()

    for source_label, image_bytes in (("left", left_bytes), ("right", right_bytes)):
        faces = detect_faces_in_group_photo(image_bytes)
        total_faces_detected += len(faces)

        for face in faces:
            student, distance = match_face_to_student(face.encoding, known_students)
            if student is None or student["id"] in matched_student_ids:
                continue

            matched_student_ids.add(student["id"])
            confidence = round(1 - distance, 4)
            face_crop_url = upload_image(config.BUCKET_FACE_CROPS, face.crop_jpeg_bytes)

            supabase.table("attendance_records").insert(
                {
                    "session_id": session_id,
                    "student_id": student["id"],
                    "source_image": source_label,
                    "face_crop_url": face_crop_url,
                    "confidence": confidence,
                }
            ).execute()

            if student.get("fcm_token"):
                send_attendance_notification(student["fcm_token"], student["full_name"], class_name, marked_at_iso)

            recognized.append(
                {
                    "student_id": student["id"],
                    "full_name": student["full_name"],
                    "roll_number": student["roll_number"],
                    "confidence": confidence,
                    "face_crop_url": face_crop_url,
                    "source_image": source_label,
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
            "recognized": recognized,
        }
    ), 201


@app.get("/api/attendance/sessions/<session_id>/report")
def attendance_session_report(session_id):
    supabase = get_supabase()
    session_result = supabase.table("attendance_sessions").select("*").eq("id", session_id).execute()
    if not session_result.data:
        return error_response("Session not found.", status=404)
    session = session_result.data[0]

    records_result = (
        supabase.table("attendance_records")
        .select("student_id, confidence, face_crop_url, source_image, students(full_name, roll_number)")
        .eq("session_id", session_id)
        .execute()
    )

    recognized = [
        {
            "student_id": r["student_id"],
            "full_name": r["students"]["full_name"],
            "roll_number": r["students"]["roll_number"],
            "confidence": r["confidence"],
            "face_crop_url": r["face_crop_url"],
            "source_image": r["source_image"],
        }
        for r in records_result.data
    ]

    return jsonify({**session, "recognized": recognized})


if __name__ == "__main__":
    app.run(debug=True, port=5000)
