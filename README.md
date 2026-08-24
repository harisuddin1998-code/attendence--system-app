# Face Recognition Attendance System

Four parts:

1. **`backend/`** — Flask API + the student-facing web app (registration, attendance history, push
   notifications, APK downloads page). Deployed on PythonAnywhere. Uses Supabase (Postgres + Storage)
   as the database.
2. **`teacher_app/`** — Flutter mobile app for teachers. Registers with a teaching ID, name and course
   list; captures a left-half and right-half photo of the classroom; shows who was recognized as present.
3. **`student_app/`** — Flutter mobile app for students. Registers face (front photo required, plus
   optional left/right/extra-angle photos for accuracy) with name, roll number and class; view
   attendance history.
4. **Supabase** — Postgres tables + storage buckets for student photos, raw classroom photos, and
   cropped recognized faces.

How a class gets marked: the teacher captures two photos covering the whole room → the backend detects
every face in both photos → each detected face is compared against every stored face angle for every
registered student in that class (1–4 encodings per student) → matches are recorded as
`attendance_records`, deduplicated so a student appearing in both photos is only marked once → each
matched student's cropped face + name is returned to the teacher app, and a push notification is sent
to that student.

Students don't have to install an app — the same registration/attendance-history flow is also available
as a website served by the backend, for anyone who'd rather use a browser.

---

## 1. Supabase setup

1. Create a project at supabase.com.
2. Open **SQL Editor** → run [`backend/schema.sql`](backend/schema.sql).
3. Open **Storage** → create three **public** buckets: `student-photos`, `attendance-images`, `face-crops`.
4. Open **Project settings → API** → copy the **Project URL** and the **service_role key** (not the
   anon key — the backend needs full write access to bypass row-level security).

## 2. Firebase setup (push notifications)

1. Create a project at the Firebase console.
2. **Project settings → Service accounts → Generate new private key** → save the JSON as
   `backend/firebase-service-account.json` (already gitignored).
3. **Project settings → General → Your apps → Add app → Web** → copy the config object into
   `backend/static/js/firebase-config.js` (`FIREBASE_CONFIG`), and paste the *same* values into
   `backend/static/firebase-messaging-sw.js`.
4. **Project settings → Cloud Messaging → Web Push certificates → Generate key pair** → copy the key
   into `FIREBASE_VAPID_KEY` in `firebase-config.js`.
5. Native push in `teacher_app`/`student_app` needs `flutterfire configure` (adds `firebase_core` +
   `firebase_messaging` and the native config files) — not wired up by default, since it requires an
   interactive Firebase CLI login. The backend doesn't care which platform a push token came from, it
   just sends to whatever is stored in `students.fcm_token` / could be extended the same way for
   teachers, so this can be added later without backend changes.

## 3. Backend — run locally

```bash
cd backend
python -m venv venv
venv\Scripts\activate          # Windows
pip install -r requirements.txt
copy .env.example .env         # then fill in SUPABASE_URL / SUPABASE_SERVICE_KEY
python app.py
```

Visit `http://localhost:5000` for the student registration/dashboard/downloads web app. The JSON API is
under `/api/...` and is what both Flutter apps talk to.

> **Note on `face_recognition`/dlib on PythonAnywhere:** dlib needs to compile from source unless a
> prebuilt wheel is available for PythonAnywhere's Python version, and free-tier accounts don't have
> enough memory/CPU time for that build. Before relying on this in production:
> - Try `pip install face_recognition` in a PythonAnywhere Bash console first.
> - If it fails, the practical fallback is a **paid PythonAnywhere plan** (more CPU/RAM for the
>   build), or swapping `face_service.py` to call a hosted face-recognition API instead of doing it
>   in-process (the rest of the app doesn't need to change — only `encode_single_face` /
>   `detect_faces_in_group_photo` would call out to that API instead of `face_recognition`).

## 4. Deploy backend to PythonAnywhere

1. Upload the `backend/` folder (Files tab, or `git clone https://github.com/harisuddin1998-code/attendence--system-app.git` then use the `backend/` subfolder).
2. **Web tab → Add a new web app → Manual configuration → Python 3.11**.
3. Set the **Virtualenv** path and run `pip install -r requirements.txt` inside it from a Bash console.
4. Edit the generated **WSGI file** to import your app:
   ```python
   import sys
   path = "/home/yourusername/attendence--system-app/backend"
   if path not in sys.path:
       sys.path.insert(0, path)
   from app import app as application
   ```
5. In the **Web tab → Environment variables**, set `SUPABASE_URL` and `SUPABASE_SERVICE_KEY` (or keep
   using `.env` — `python-dotenv` will pick it up from the backend folder).
6. Upload `firebase-service-account.json` into `backend/` on PythonAnywhere too.
7. Once you've built the APKs (see below), upload them as `backend/static/downloads/teacher_app.apk`
   and `backend/static/downloads/student_app.apk` — the `/downloads` page picks them up automatically.
8. Reload the web app. Your site is now live at `https://yourusername.pythonanywhere.com`.

## 5. Teacher Flutter app (`teacher_app/`)

Already has `android/` generated and a `flutter analyze` clean bill of health. To build:

```bash
cd teacher_app
flutter pub get
```

1. Open `lib/services/api_service.dart` and set `ApiConfig.baseUrl` to your PythonAnywhere URL
   (use `http://10.0.2.2:5000` instead if testing against a local Flask server from the Android emulator).
2. `flutter run` (device/emulator attached) to test, or `flutter build apk --release` to produce
   `build/app/outputs/flutter-apk/app-release.apk` — rename it `teacher_app.apk` and upload to
   `backend/static/downloads/`.

App flow: teacher registers (name, teaching ID, email/password, courses) or logs in → picks a course
from their list (or types a class name) → captures the left half then the right half of the room →
submits → sees a grid of every recognized student's cropped face, name and roll number, plus counts of
faces detected vs. matched.

## 6. Student Flutter app (`student_app/`)

Same idea, already has `android/` generated and analyzes clean:

```bash
cd student_app
flutter pub get
```

1. Set `ApiConfig.baseUrl` in `lib/services/api_service.dart` the same way as the teacher app.
2. `flutter run` to test, or `flutter build apk --release` → rename the output `student_app.apk` and
   upload to `backend/static/downloads/`.

App flow: student registers once (name, roll number, class, front photo required + optional
left/right/extra-angle photos for accuracy) → afterwards opens the app and it goes straight to their
attendance history (roll number is remembered on-device), pull-to-refresh to see new records.

## 7. Student flow via the website (no app install)

Students can instead go to `https://yourusername.pythonanywhere.com/register`, fill in name/roll
number/class, and capture their face photo(s) via webcam (front required, left/right/extra optional —
same accuracy benefit as the app). Afterwards `/dashboard` lets them look up their roll number to see
attendance history and turn on browser push notifications.

## 8. Download Apps page

`https://yourusername.pythonanywhere.com/downloads` lists both APKs once you've uploaded them (step 4.7
above). Until then it shows "Not uploaded yet" for whichever one is missing — the route checks
`backend/static/downloads/` at request time, no config needed.

---

## Project structure

```
backend/
  app.py                  Flask routes (student web pages + JSON API)
  face_service.py         Face detection/encoding/matching (face_recognition/dlib)
  firebase_service.py     Sends FCM push notifications
  storage_service.py      Uploads images to Supabase Storage
  supabase_client.py      Supabase client singleton
  config.py                Env-driven settings
  schema.sql               Supabase table definitions (run once)
  templates/                Student web app pages incl. downloads.html (Jinja2)
  static/                   CSS/JS for the student web app + FCM service worker
  static/downloads/         Drop teacher_app.apk / student_app.apk here
teacher_app/               Flutter — login/register (teaching ID + courses), capture left/right, report
student_app/                Flutter — register (multi-pose face capture), attendance history
```

## Known MVP simplifications (call these out before real deployment)

- Teacher auth is a plain email/password check with no session tokens/JWT — the app just stores the
  teacher id locally. Fine for a small trusted group of teachers, not for a public rollout.
- Student "login" (both the web dashboard and `student_app`) is just their roll number (no password) —
  anyone who knows a roll number can view that student's history. Add a proper auth step before going
  beyond a pilot.
- Face match threshold (`FACE_MATCH_THRESHOLD` = 0.5) is a reasonable default for `face_recognition`'s
  128-d encodings but should be tuned against your own classroom photos (lighting/camera quality/photo
  count per student all affect this).
- Native push notifications in the Flutter apps need `flutterfire configure` (see section 2) — not
  wired up out of the box.
