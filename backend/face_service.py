"""Face detection, encoding and matching built on top of face_recognition (dlib).

All encodings are 128-d vectors (face_recognition's default). Matching is done with
Euclidean distance between encodings: lower distance = more similar face.
"""
import io
from dataclasses import dataclass

import face_recognition
import numpy as np
from PIL import Image, ImageOps

from config import FACE_MATCH_THRESHOLD

# HOG face detection time AND memory scale with image area, and phone cameras routinely produce
# 3000-4000px wide photos - on Render's free-tier 512MB instance that's enough to both blow past the
# request timeout and get OOM-killed mid-request. Capping the longest side keeps both in check
# without hurting accuracy at normal classroom-photo distances.
MAX_IMAGE_DIMENSION = 640


class NoFaceFoundError(Exception):
    pass


class MultipleFacesFoundError(Exception):
    pass


@dataclass
class DetectedFace:
    location: tuple  # (top, right, bottom, left)
    encoding: np.ndarray
    crop_jpeg_bytes: bytes


@dataclass
class ProcessedImage:
    rgb_array: np.ndarray
    # Re-encoded, downscaled JPEG bytes - this is what actually gets stored in Supabase now,
    # instead of the original multi-MB phone photo, since only the array is needed for detection.
    downscaled_jpeg_bytes: bytes


def process_image(image_bytes: bytes) -> ProcessedImage:
    """Decodes, EXIF-corrects and downscales an uploaded photo exactly once. The array is used for
    face detection/encoding; the re-encoded bytes are what gets uploaded to storage - doing both
    from a single decode avoids paying for it twice, and uploading the downscaled JPEG instead of
    the original cuts storage use (and upload time) by roughly 5-8x for a typical phone photo.
    """
    image = Image.open(io.BytesIO(image_bytes))
    image = ImageOps.exif_transpose(image)  # phone photos carry rotation as EXIF, not pixel data
    image = image.convert("RGB")

    if max(image.size) > MAX_IMAGE_DIMENSION:
        image.thumbnail((MAX_IMAGE_DIMENSION, MAX_IMAGE_DIMENSION), Image.LANCZOS)

    buffer = io.BytesIO()
    # Quality 70 balances fast processing with enough detail for face recognition;
    # lower quality means smaller arrays for dlib/HOG to process.
    image.save(buffer, format="JPEG", quality=70)
    return ProcessedImage(rgb_array=np.array(image), downscaled_jpeg_bytes=buffer.getvalue())


def _load_rgb_image(image_bytes: bytes) -> np.ndarray:
    return process_image(image_bytes).rgb_array


def encode_single_face_from_array(rgb_image: np.ndarray) -> list:
    # number_of_times_to_upsample=0 skips building the larger image pyramid dlib normally uses to
    # find small/far-away faces - a registration photo is a single close-up face, so it's not needed
    # here, and skipping it noticeably cuts both memory and processing time.
    locations = face_recognition.face_locations(rgb_image, model="hog", number_of_times_to_upsample=0)

    if len(locations) == 0:
        raise NoFaceFoundError("No face detected in the registration photo. Please retake it with good lighting.")
    if len(locations) > 1:
        raise MultipleFacesFoundError("More than one face detected. Please submit a photo with only your face.")

    encodings = face_recognition.face_encodings(rgb_image, known_face_locations=locations)
    return encodings[0].tolist()


def encode_single_face(image_bytes: bytes) -> list:
    """Used during one-time student registration. Requires exactly one face in the photo."""
    return encode_single_face_from_array(_load_rgb_image(image_bytes))


def _crop_face_jpeg(rgb_image: np.ndarray, location: tuple, padding_ratio: float = 0.3) -> bytes:
    top, right, bottom, left = location
    height, width = bottom - top, right - left
    pad_y, pad_x = int(height * padding_ratio), int(width * padding_ratio)

    img_height, img_width = rgb_image.shape[0], rgb_image.shape[1]
    top = max(0, top - pad_y)
    left = max(0, left - pad_x)
    bottom = min(img_height, bottom + pad_y)
    right = min(img_width, right + pad_x)

    crop = Image.fromarray(rgb_image[top:bottom, left:right])
    buffer = io.BytesIO()
    crop.save(buffer, format="JPEG", quality=90)
    return buffer.getvalue()


def detect_faces_in_array(rgb_image: np.ndarray) -> list[DetectedFace]:
    # Same reasoning as encode_single_face_from_array - no upsampling pyramid, which is the biggest
    # single lever for keeping this under Render's free-tier 512MB ceiling. Faces at normal
    # classroom-photo distance are still well within range at MAX_IMAGE_DIMENSION.
    locations = face_recognition.face_locations(rgb_image, model="hog", number_of_times_to_upsample=0)
    encodings = face_recognition.face_encodings(rgb_image, known_face_locations=locations)

    faces = []
    for location, encoding in zip(locations, encodings):
        crop_bytes = _crop_face_jpeg(rgb_image, location)
        faces.append(DetectedFace(location=location, encoding=encoding, crop_jpeg_bytes=crop_bytes))
    return faces


def detect_faces_in_group_photo(image_bytes: bytes) -> list[DetectedFace]:
    """Used when a teacher uploads a classroom photo (left or right half)."""
    return detect_faces_in_array(_load_rgb_image(image_bytes))


def closest_student(encoding: np.ndarray, students: list[dict]) -> tuple[dict | None, float | None]:
    """students: list of {"id", "face_encoding": [...]}. Always returns the nearest candidate + its
    distance (even if it's not a confident match) so callers can decide what to do with it."""
    if not students:
        return None, None

    known_encodings = np.array([s["face_encoding"] for s in students])
    distances = np.linalg.norm(known_encodings - encoding, axis=1)
    best_index = int(np.argmin(distances))
    return students[best_index], float(distances[best_index])


def match_face_to_student(encoding: np.ndarray, students: list[dict]) -> tuple[dict | None, float | None]:
    """Same as closest_student, but returns (None, None) if the closest candidate isn't within
    FACE_MATCH_THRESHOLD."""
    student, distance = closest_student(encoding, students)
    if student is not None and distance <= FACE_MATCH_THRESHOLD:
        return student, distance
    return None, None
