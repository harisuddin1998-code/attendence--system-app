"""Face detection, encoding and matching built on top of face_recognition (dlib).

All encodings are 128-d vectors (face_recognition's default). Matching is done with
Euclidean distance between encodings: lower distance = more similar face.
"""
import io
from dataclasses import dataclass

import face_recognition
import numpy as np
from PIL import Image

from config import FACE_MATCH_THRESHOLD


class NoFaceFoundError(Exception):
    pass


class MultipleFacesFoundError(Exception):
    pass


@dataclass
class DetectedFace:
    location: tuple  # (top, right, bottom, left)
    encoding: np.ndarray
    crop_jpeg_bytes: bytes


def _load_rgb_image(image_bytes: bytes) -> np.ndarray:
    image = Image.open(io.BytesIO(image_bytes))
    image = image.convert("RGB")
    return np.array(image)


def encode_single_face(image_bytes: bytes) -> list:
    """Used during one-time student registration. Requires exactly one face in the photo."""
    rgb_image = _load_rgb_image(image_bytes)
    locations = face_recognition.face_locations(rgb_image, model="hog")

    if len(locations) == 0:
        raise NoFaceFoundError("No face detected in the registration photo. Please retake it with good lighting.")
    if len(locations) > 1:
        raise MultipleFacesFoundError("More than one face detected. Please submit a photo with only your face.")

    encodings = face_recognition.face_encodings(rgb_image, known_face_locations=locations)
    return encodings[0].tolist()


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


def detect_faces_in_group_photo(image_bytes: bytes) -> list[DetectedFace]:
    """Used when a teacher uploads a classroom photo (left or right half)."""
    rgb_image = _load_rgb_image(image_bytes)
    locations = face_recognition.face_locations(rgb_image, model="hog")
    encodings = face_recognition.face_encodings(rgb_image, known_face_locations=locations)

    faces = []
    for location, encoding in zip(locations, encodings):
        crop_bytes = _crop_face_jpeg(rgb_image, location)
        faces.append(DetectedFace(location=location, encoding=encoding, crop_jpeg_bytes=crop_bytes))
    return faces


def match_face_to_student(encoding: np.ndarray, students: list[dict]) -> tuple[dict | None, float | None]:
    """students: list of {"id", "face_encoding": [...]}. Returns (best_matching_student, distance) or (None, None)."""
    if not students:
        return None, None

    known_encodings = np.array([s["face_encoding"] for s in students])
    distances = np.linalg.norm(known_encodings - encoding, axis=1)
    best_index = int(np.argmin(distances))
    best_distance = float(distances[best_index])

    if best_distance <= FACE_MATCH_THRESHOLD:
        return students[best_index], best_distance
    return None, None
