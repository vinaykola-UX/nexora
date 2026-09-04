-- ============================================================================
-- Migration: 0002_notifications_and_devices.sql
-- Nexora Phase N — Smart Push Notifications & Device Token Architecture
-- Safe non-destructive creation: CREATE TABLE IF NOT EXISTS
-- ============================================================================

-- 1. Student Registered FCM Devices
CREATE TABLE IF NOT EXISTS student_devices (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    firebase_uid TEXT NOT NULL,
    fcm_token TEXT UNIQUE NOT NULL,
    platform TEXT DEFAULT 'android',
    device_name TEXT,
    app_version TEXT,
    is_active INTEGER DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_seen_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_student_devices_uid ON student_devices(firebase_uid, is_active);
CREATE INDEX IF NOT EXISTS idx_student_devices_token ON student_devices(fcm_token);

-- 2. In-App Notifications Storage
CREATE TABLE IF NOT EXISTS notifications (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    firebase_uid TEXT NOT NULL,
    type TEXT NOT NULL,
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    data_json TEXT,
    reference_id TEXT,
    is_read INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    read_at TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_notifications_uid_read ON notifications(firebase_uid, is_read, created_at);
CREATE INDEX IF NOT EXISTS idx_notifications_idempotency ON notifications(firebase_uid, type, reference_id);

-- 3. Notification Preferences
CREATE TABLE IF NOT EXISTS notification_preferences (
    firebase_uid TEXT PRIMARY KEY,
    results_enabled INTEGER DEFAULT 1,
    events_enabled INTEGER DEFAULT 1,
    exams_enabled INTEGER DEFAULT 1,
    attendance_enabled INTEGER DEFAULT 1,
    general_enabled INTEGER DEFAULT 1,
    system_enabled INTEGER DEFAULT 1,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 4. Unmatched Uploaded Results (Authoritative data store for unlinked students)
CREATE TABLE IF NOT EXISTS unmatched_results (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    roll_number TEXT NOT NULL,
    semester INTEGER NOT NULL,
    subject_code TEXT,
    subject_name TEXT,
    grade TEXT,
    credits REAL,
    grade_points REAL,
    status TEXT,
    sgpa REAL,
    cgpa REAL,
    exam_month_year TEXT,
    raw_payload TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_unmatched_results_roll ON unmatched_results(roll_number, semester);
