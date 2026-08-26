-- Students used to "log in" with just their roll number - anyone who knew (or guessed) another
-- student's roll number could see their attendance history and hijack their push notifications.
-- This adds a real password so /api/students/login can actually authenticate them.
alter table students add column if not exists password_hash text;
