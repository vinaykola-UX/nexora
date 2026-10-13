-- Migration: 0005 - Faculty Materials Deduplication & Student Flow Analytics
-- ============================================================================
-- 1. Canonical Documents (Single-Instance Storage for Materials)
-- ============================================================================
CREATE TABLE IF NOT EXISTS canonical_documents (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  file_sha256 TEXT UNIQUE NOT NULL,
  simhash TEXT,
  title TEXT NOT NULL,
  subject_code TEXT NOT NULL,
  subject_name TEXT NOT NULL,
  unit INTEGER DEFAULT 1,
  topic TEXT,
  file_type TEXT DEFAULT 'application/pdf',
  file_size_bytes INTEGER DEFAULT 0,
  r2_storage_key TEXT,
  total_chunks INTEGER DEFAULT 0,
  version TEXT DEFAULT '1.0',
  is_verified INTEGER DEFAULT 1,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_canonical_docs_subject ON canonical_documents(subject_code, unit);
CREATE INDEX IF NOT EXISTS idx_canonical_docs_sha256 ON canonical_documents(file_sha256);

-- ============================================================================
-- 2. Faculty Material Shares (Multi-Lecturer Virtual Links)
-- ============================================================================
CREATE TABLE IF NOT EXISTS faculty_material_shares (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  canonical_doc_id INTEGER NOT NULL REFERENCES canonical_documents(id) ON DELETE CASCADE,
  faculty_uid TEXT NOT NULL,
  faculty_email TEXT NOT NULL,
  faculty_name TEXT NOT NULL,
  department TEXT NOT NULL,
  academic_year TEXT DEFAULT '2025-2026',
  sections TEXT DEFAULT 'ALL',
  is_primary_author INTEGER DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(canonical_doc_id, faculty_uid)
);

CREATE INDEX IF NOT EXISTS idx_faculty_shares_uid ON faculty_material_shares(faculty_uid);

-- ============================================================================
-- 3. Student Material Interactions (Student Access Flow)
-- ============================================================================
CREATE TABLE IF NOT EXISTS student_material_interactions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  canonical_doc_id INTEGER NOT NULL REFERENCES canonical_documents(id) ON DELETE CASCADE,
  student_uid TEXT NOT NULL,
  student_roll TEXT NOT NULL,
  student_name TEXT,
  branch TEXT,
  section TEXT,
  action_type TEXT NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_student_interactions_doc ON student_material_interactions(canonical_doc_id, action_type);
CREATE INDEX IF NOT EXISTS idx_student_interactions_student ON student_material_interactions(student_roll);

-- ============================================================================
-- 4. Subject Concept Question Analytics (Difficulty Insights)
-- ============================================================================
CREATE TABLE IF NOT EXISTS subject_concept_insights (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  subject_code TEXT NOT NULL,
  unit INTEGER NOT NULL,
  canonical_doc_id INTEGER REFERENCES canonical_documents(id),
  concept_topic TEXT NOT NULL,
  query_count INTEGER DEFAULT 1,
  last_queried_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(subject_code, unit, concept_topic)
);
