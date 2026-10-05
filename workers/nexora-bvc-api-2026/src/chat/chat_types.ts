/**
 * ============================================================================
 * Nexora AI — Cloud-Synced Chat Types
 * ============================================================================
 * Definitions for cross-device synchronized chat conversations and messages.
 * All records are strictly scoped to the authenticated firebase_uid.
 * ============================================================================
 */

export interface ChatConversationRecord {
  id: string;
  firebase_uid: string;
  title: string;
  created_at: string;
  updated_at: string;
  last_message?: string | null;
  message_count?: number;
}

export interface ChatMessageRecord {
  id: string;
  conversation_id: string;
  firebase_uid: string;
  role: 'user' | 'assistant' | 'system';
  content: string;
  created_at: string;
}

export interface CreateConversationInput {
  id?: string;
  title?: string;
}

export interface CreateMessageInput {
  id?: string;
  conversation_id: string;
  role: 'user' | 'assistant' | 'system';
  content: string;
  created_at?: string;
}
