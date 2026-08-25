import os

from dotenv import load_dotenv

load_dotenv()

SUPABASE_URL = os.environ["SUPABASE_URL"]
SUPABASE_SERVICE_KEY = os.environ["SUPABASE_SERVICE_KEY"]

FIREBASE_CREDENTIALS_PATH = os.environ.get("FIREBASE_CREDENTIALS_PATH", "firebase-service-account.json")
# On hosts with no file upload (e.g. Render's free tier has no "Secret Files"), paste the whole
# service-account JSON as one environment variable instead - takes priority over the path above.
FIREBASE_CREDENTIALS_JSON = os.environ.get("FIREBASE_CREDENTIALS_JSON")

# Lower = stricter match. face_recognition's own docs use 0.6 as the standard tolerance for its
# 128-d encodings; 0.5 (the old default here) was tight enough to reject genuine matches once
# lighting/angle/distance differ from the registration photo, which is normal for a classroom shot.
FACE_MATCH_THRESHOLD = float(os.environ.get("FACE_MATCH_THRESHOLD", "0.6"))

BUCKET_STUDENT_PHOTOS = "student-photos"
BUCKET_ATTENDANCE_IMAGES = "attendance-images"
BUCKET_FACE_CROPS = "face-crops"

SECRET_KEY = os.environ.get("FLASK_SECRET_KEY", "dev-secret-change-me")
