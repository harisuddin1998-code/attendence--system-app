"""Sends attendance push notifications to students via Firebase Cloud Messaging.

Works for both the Flutter app and web-push (student registration web app), since FCM
issues a device/browser token in both cases that we store in students.fcm_token.
"""
import logging

import firebase_admin
from firebase_admin import credentials, messaging

from config import FIREBASE_CREDENTIALS_PATH

logger = logging.getLogger(__name__)

_firebase_app = None


def _get_app():
    global _firebase_app
    if _firebase_app is None:
        cred = credentials.Certificate(FIREBASE_CREDENTIALS_PATH)
        _firebase_app = firebase_admin.initialize_app(cred)
    return _firebase_app


def send_attendance_notification(fcm_token: str, student_name: str, class_name: str, marked_at: str) -> bool:
    if not fcm_token:
        return False

    _get_app()
    message = messaging.Message(
        notification=messaging.Notification(
            title="Attendance Marked",
            body=f"You were marked present in {class_name} at {marked_at}.",
        ),
        data={
            "type": "attendance_marked",
            "class_name": class_name,
            "marked_at": marked_at,
        },
        token=fcm_token,
    )

    try:
        messaging.send(message)
        return True
    except Exception:
        logger.exception("Failed to send FCM notification to student %s", student_name)
        return False
