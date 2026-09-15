-- ============================================================================
-- Migration: 0003_chat_memory_system.sql
-- Nexora Phase M — Production-Grade Chat Memory System
-- Safe non-destructive creation: CREATE TABLE IF NOT EXISTS
-- ============================================================================

-- 1. Conversations — Persistent chat sessions scoped to authenticated student
CREATE TABLE IF NOT EXISTS conversations (
    id TEXT PRIMARY KEY,
    student_uid TEXT NOT NULL,
    title TEXT NOT NULL,
    summary TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    archived_at TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_conversations_student
  ON conversations(student_uid, updated_at DESC);

-- 2. Messages — Individual chat messages linked to conversations
CREATE TABLE IF NOT EXISTS messages (
    id TEXT PRIMARY KEY,
    conversation_id TEXT NOT NULL,
    student_uid TEXT NOT NULL,
    role TEXT NOT NULL,
    content TEXT NOT NULL,
    metadata_json TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_messages_conv
  ON messages(conversation_id, created_at ASC);

CREATE INDEX IF NOT EXISTS idx_messages_student
  ON messages(student_uid, created_at DESC);

-- 3. Student Long-Term Memories — Extracted facts/preferences per student
CREATE TABLE IF NOT EXISTS student_memories (
    id TEXT PRIMARY KEY,
    student_uid TEXT NOT NULL,
    memory_text TEXT NOT NULL,
    category TEXT NOT NULL,
    importance REAL DEFAULT 0.5,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_used_at TIMESTAMP,
    source_conversation_id TEXT,
    status TEXT DEFAULT 'active'
);

CREATE INDEX IF NOT EXISTS idx_student_memories_student
  ON student_memories(student_uid, status, importance DESC);

-- 4. Student Memory Settings — Per-student toggle for memory feature
CREATE TABLE IF NOT EXISTS student_memory_settings (
    student_uid TEXT PRIMARY KEY,
    memory_enabled INTEGER DEFAULT 1,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
