-- ============================================================================
-- Migration: 0004_chat_sync.sql
-- Nexora Cloud-Synced Chat History Layer (D1)
-- Safe non-destructive creation: CREATE TABLE IF NOT EXISTS
-- ============================================================================

-- 1. chat_conversations — Scoped to authenticated Firebase UID
CREATE TABLE IF NOT EXISTS chat_conversations (
    id TEXT PRIMARY KEY,
    firebase_uid TEXT NOT NULL,
    title TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_chat_conversations_user 
  ON chat_conversations(firebase_uid, updated_at DESC);

-- 2. chat_messages — Scoped to conversation_id and authenticated Firebase UID
CREATE TABLE IF NOT EXISTS chat_messages (
    id TEXT PRIMARY KEY,
    conversation_id TEXT NOT NULL,
    firebase_uid TEXT NOT NULL,
    role TEXT NOT NULL,
    content TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_chat_messages_conv 
  ON chat_messages(conversation_id, created_at ASC);

CREATE INDEX IF NOT EXISTS idx_chat_messages_user 
  ON chat_messages(firebase_uid, created_at DESC);
