import os

from dotenv import load_dotenv

load_dotenv()

SUPABASE_URL = os.environ["SUPABASE_URL"]
SUPABASE_SERVICE_KEY = os.environ["SUPABASE_SERVICE_KEY"]

FIREBASE_CREDENTIALS_PATH = os.environ.get("FIREBASE_CREDENTIALS_PATH", "firebase-service-account.json")

# Lower = stricter match. 0.5 is a good default for face_recognition's 128-d encodings.
FACE_MATCH_THRESHOLD = float(os.environ.get("FACE_MATCH_THRESHOLD", "0.5"))

BUCKET_STUDENT_PHOTOS = "student-photos"
BUCKET_ATTENDANCE_IMAGES = "attendance-images"
BUCKET_FACE_CROPS = "face-crops"

SECRET_KEY = os.environ.get("FLASK_SECRET_KEY", "dev-secret-change-me")
