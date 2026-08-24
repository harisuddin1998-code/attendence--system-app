import uuid

from supabase_client import get_supabase


def upload_image(bucket: str, content: bytes, extension: str = "jpg", content_type: str = "image/jpeg") -> str:
    """Uploads bytes to a Supabase Storage bucket and returns its public URL.
    The bucket must be created and set to "public" in the Supabase dashboard beforehand.
    """
    supabase = get_supabase()
    path = f"{uuid.uuid4().hex}.{extension}"
    supabase.storage.from_(bucket).upload(path, content, {"content-type": content_type})
    return supabase.storage.from_(bucket).get_public_url(path)
