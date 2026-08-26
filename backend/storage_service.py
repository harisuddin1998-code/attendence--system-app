import uuid

from supabase_client import get_supabase

# Student face photos and attendance crops are biometric data - a permanently public bucket means
# anyone who ever sees a URL (a screenshot, a shared link, a browser history entry) has permanent
# access. Buckets are private; every URL handed out is a signed link that expires instead.
SIGNED_URL_TTL_SECONDS = 60 * 60 * 24 * 365  # 1 year - long enough that attendance history stays usable


def upload_image(bucket: str, content: bytes, extension: str = "jpg", content_type: str = "image/jpeg") -> str:
    """Uploads bytes to a private Supabase Storage bucket and returns a signed, expiring URL."""
    supabase = get_supabase()
    path = f"{uuid.uuid4().hex}.{extension}"
    supabase.storage.from_(bucket).upload(path, content, {"content-type": content_type})
    response = supabase.storage.from_(bucket).create_signed_url(path, SIGNED_URL_TTL_SECONDS)
    return response["signedURL"]
