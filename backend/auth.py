"""Bearer-token auth for the mobile apps. Stateless JWTs signed with the Flask secret key - no
session table needed. A teacher token authorizes attendance-marking actions; a student token
authorizes access to that one student's own data (checked by comparing the token's subject to the
:student_id in the URL, not just that *some* valid token was presented).
"""
import functools
from datetime import datetime, timedelta, timezone

import jwt
from flask import g, jsonify, request

import config

ALGORITHM = "HS256"
TOKEN_TTL_DAYS = 90  # long-lived on purpose - these are installed apps, not browser sessions


def issue_token(subject_type: str, subject_id: str) -> str:
    now = datetime.now(timezone.utc)
    payload = {
        "sub": str(subject_id),
        "type": subject_type,  # "teacher" or "student"
        "iat": now,
        "exp": now + timedelta(days=TOKEN_TTL_DAYS),
    }
    return jwt.encode(payload, config.SECRET_KEY, algorithm=ALGORITHM)


def _decode(token: str) -> dict | None:
    try:
        return jwt.decode(token, config.SECRET_KEY, algorithms=[ALGORITHM])
    except jwt.PyJWTError:
        return None


def require_auth(subject_type: str):
    """Rejects the request with 401 unless a valid Bearer token of the given type is present.
    On success, sets flask.g.auth_subject_id for the view to use (e.g. for ownership checks)."""

    def decorator(view):
        @functools.wraps(view)
        def wrapped(*args, **kwargs):
            header = request.headers.get("Authorization", "")
            if not header.startswith("Bearer "):
                return jsonify({"error": "Authentication required."}), 401

            payload = _decode(header[len("Bearer ") :])
            if not payload or payload.get("type") != subject_type:
                return jsonify({"error": "Invalid or expired token."}), 401

            g.auth_subject_id = payload["sub"]
            return view(*args, **kwargs)

        return wrapped

    return decorator
