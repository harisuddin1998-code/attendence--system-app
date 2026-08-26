-- Run this once in the Supabase SQL editor (Project -> SQL Editor -> New query)
-- Enables pgcrypto for gen_random_uuid()
create extension if not exists pgcrypto;

create table if not exists teachers (
    id uuid primary key default gen_random_uuid(),
    name text not null,
    teaching_id text not null unique,
    email text not null unique,
    password_hash text not null,
    courses text[] not null default '{}',
    created_at timestamptz not null default now()
);

create table if not exists students (
    id uuid primary key default gen_random_uuid(),
    full_name text not null,
    roll_number text not null unique,
    class_name text not null,
    photo_url text,
    fcm_token text,
    password_hash text,
    created_at timestamptz not null default now()
);

-- Up to 4 face angles per student (front + side poses) captured at registration, so matching can
-- compare an incoming face against every stored angle and keep the closest one. One row per photo.
create table if not exists student_face_encodings (
    id uuid primary key default gen_random_uuid(),
    student_id uuid not null references students(id) on delete cascade,
    pose_label text not null default 'front',
    face_encoding double precision[] not null,
    created_at timestamptz not null default now()
);

create table if not exists attendance_sessions (
    id uuid primary key default gen_random_uuid(),
    teacher_id uuid references teachers(id) on delete set null,
    class_name text not null,
    session_date date not null default current_date,
    left_image_url text,
    right_image_url text,
    total_faces_detected int not null default 0,
    total_students_recognized int not null default 0,
    created_at timestamptz not null default now()
);

create table if not exists attendance_records (
    id uuid primary key default gen_random_uuid(),
    session_id uuid not null references attendance_sessions(id) on delete cascade,
    -- Nullable: every detected face gets a row, even ones that didn't match anyone. A teacher can
    -- later identify an "unknown" face, which fills this in via the /identify endpoint.
    student_id uuid references students(id) on delete cascade,
    source_image text not null check (source_image in ('left', 'right')),
    face_crop_url text,
    confidence double precision,
    manually_confirmed boolean not null default false,
    marked_at timestamptz not null default now(),
    unique (session_id, student_id)
);

create index if not exists idx_students_class on students (class_name);
create index if not exists idx_sessions_class_date on attendance_sessions (class_name, session_date);
create index if not exists idx_records_student on attendance_records (student_id);
create index if not exists idx_face_encodings_student on student_face_encodings (student_id);

-- Storage buckets (create these from Supabase Dashboard -> Storage -> New bucket, all "public" so the
-- generated URLs can be shown directly in the apps):
--   student-photos     -> one-time registration face photos
--   attendance-images  -> raw left/right classroom photos uploaded by the teacher
--   face-crops         -> cropped face images of recognized students per session
