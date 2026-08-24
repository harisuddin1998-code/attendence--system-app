# Face Recognition Attendance System

Three parts:

1. **`backend/`** — Flask API + the student-facing web app (registration, attendance history, push
   notifications). Deployed on PythonAnywhere. Uses Supabase (Postgres + Storage) as the database.
2. **`teacher_app/`** — Flutter mobile app for teachers. Captures a left-half and right-half photo of
   the classroom, uploads them, and shows who was recognized as present.
3. **Supabase** — Postgres tables + storage buckets for student photos, raw classroom photos, and
   cropped recognized faces.

How a class gets marked: the teacher captures two photos covering the whole room → the backend detects
every face in both photos → each detected face is compared against the 128-d face encoding stored for
every registered student in that class → matches are recorded as `attendance_records`, deduplicated so
a student appearing in both photos is only marked once → each matched student's cropped face + name is
returned to the teacher app, and a push notification is sent to that student.

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
5. For the Flutter app to also receive pushes, add an Android app in the same Firebase project and
   follow FlutterFire's setup (`flutterfire configure`) — the backend code doesn't change either way,
   since it just sends to whatever token is stored in `students.fcm_token`.

## 3. Backend — run locally

```bash
cd backend
python -m venv venv
venv\Scripts\activate          # Windows
pip install -r requirements.txt
copy .env.example .env         # then fill in SUPABASE_URL / SUPABASE_SERVICE_KEY
python app.py
```

Visit `http://localhost:5000` — that's the student registration/dashboard web app. The API is under
`/api/...` and is what the Flutter app talks to.

> **Note on `face_recognition`/dlib on PythonAnywhere:** dlib needs to compile from source unless a
> prebuilt wheel is available for PythonAnywhere's Python version, and free-tier accounts don't have
> enough memory/CPU time for that build. Before relying on this in production:
> - Try `pip install face_recognition` in a PythonAnywhere Bash console first.
> - If it fails, the practical fallback is a **paid PythonAnywhere plan** (more CPU/RAM for the
>   build), or swapping `face_service.py` to call a hosted face-recognition API instead of doing it
>   in-process (the rest of the app doesn't need to change — only `encode_single_face` /
>   `detect_faces_in_group_photo` would call out to that API instead of `face_recognition`).

## 4. Deploy backend to PythonAnywhere

1. Upload the `backend/` folder (Files tab, or `git clone` if you push this repo to GitHub).
2. **Web tab → Add a new web app → Manual configuration → Python 3.11**.
3. Set the **Virtualenv** path and run `pip install -r requirements.txt` inside it from a Bash console.
4. Edit the generated **WSGI file** to import your app:
   ```python
   import sys
   path = "/home/yourusername/attendence-application/backend"
   if path not in sys.path:
       sys.path.insert(0, path)
   from app import app as application
   ```
5. In the **Web tab → Environment variables**, set `SUPABASE_URL` and `SUPABASE_SERVICE_KEY` (or keep
   using `.env` — `python-dotenv` will pick it up from the backend folder).
6. Upload `firebase-service-account.json` into `backend/` on PythonAnywhere too.
7. Reload the web app. Your student site is now live at `https://yourusername.pythonanywhere.com`.

## 5. Teacher Flutter app

Flutter isn't installed in this environment, so the `teacher_app/` folder currently only has the Dart
source (`lib/`) and `pubspec.yaml` — the platform folders (`android/`, `ios/`, etc.) need to be
generated once by the Flutter SDK on your machine:

```bash
cd teacher_app
flutter create .          # generates android/, ios/, web/, etc. around the existing lib/ and pubspec.yaml
flutter pub get
```

Then:

1. Open `lib/services/api_service.dart` and set `ApiConfig.baseUrl` to your PythonAnywhere URL
   (use `http://10.0.2.2:5000` instead if testing against a local Flask server from the Android emulator).
2. Add camera permission:
   - **Android** (`android/app/src/main/AndroidManifest.xml`), inside `<manifest>`:
     ```xml
     <uses-permission android:name="android.permission.CAMERA"/>
     <uses-permission android:name="android.permission.INTERNET"/>
     ```
   - **iOS** (`ios/Runner/Info.plist`):
     ```xml
     <key>NSCameraUsageDescription</key>
     <string>Camera access is needed to capture classroom photos for attendance.</string>
     ```
3. Run it: `flutter run` (device/emulator attached), or build a release APK with `flutter build apk`.

App flow: teacher registers/logs in → enters a class name → captures the left half then the right half
of the room → submits → sees a grid of every recognized student's cropped face, name and roll number,
plus counts of faces detected vs. matched.

## 6. Student flow

Students go to `https://yourusername.pythonanywhere.com/register`, fill in name/roll number/class, and
capture one clear face photo via their laptop/phone webcam (one-time). Afterwards they can go to
`/dashboard`, enter their roll number to see their attendance history and enable push notifications —
the next time a teacher marks their class present, they get a browser push and their entry appears in
the history with the cropped face the system matched.

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
  templates/                Student web app pages (Jinja2)
  static/                   CSS/JS for the student web app + FCM service worker
teacher_app/
  lib/main.dart
  lib/screens/              login, home, capture (left/right photos), report
  lib/services/api_service.dart
  lib/models/attendance_report.dart
  pubspec.yaml
```

## Known MVP simplifications (call these out before real deployment)

- Teacher auth is a plain email/password check with no session tokens/JWT — the app just stores the
  teacher id locally. Fine for a small trusted group of teachers, not for a public rollout.
- Student "login" on the web dashboard is just their roll number (no password) — anyone who knows a
  roll number can view that student's history. Add a proper auth step before going beyond a pilot.
- Face match threshold (`FACE_MATCH_THRESHOLD` = 0.5) is a reasonable default for `face_recognition`'s
  128-d encodings but should be tuned against your own classroom photos (lighting/camera quality
  affects this a lot).
