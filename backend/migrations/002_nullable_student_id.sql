-- Run this once in the Supabase SQL editor. Needed for the "unknown face -> teacher assigns a name"
-- feature: every detected face now gets an attendance_records row, even before it's identified.
alter table attendance_records alter column student_id drop not null;
alter table attendance_records add column if not exists manually_confirmed boolean not null default false;
