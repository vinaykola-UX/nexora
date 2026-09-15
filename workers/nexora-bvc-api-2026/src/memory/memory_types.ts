/**
 * ============================================================================
 * Nexora AI — Production-Grade Chat Memory System Types
 * ============================================================================
 * Defines types for persistent conversations, messages, long-term student
 * memories, categories, extraction schemas, and settings.
 * ============================================================================
 */

export type MemoryCategory =
  | 'learning_goal'
  | 'subject_interest'
  | 'programming_preference'
  | 'study_preference'
  | 'recurring_context'
  | 'project_context'
  | 'other_non_sensitive_context';

export interface ConversationRecord {
  id: string;
  student_uid: string;
  title: string;
  summary?: string | null;
  created_at: string;
  updated_at: string;
  archived_at?: string | null;
}

export interface MessageRecord {
  id: string;
  conversation_id: string;
  student_uid: string;
  role: 'user' | 'assistant';
  content: string;
  metadata_json?: string | null;
  created_at: string;
}

export interface StudentMemory {
  id: string;
  student_uid: string;
  memory_text: string;
  category: MemoryCategory;
  importance: number; // 0.0 to 1.0
  created_at: string;
  updated_at: string;
  last_used_at?: string | null;
  source_conversation_id?: string | null;
  status: 'active' | 'archived';
}

export interface MemorySettings {
  student_uid: string;
  memory_enabled: boolean;
  updated_at: string;
}

export interface ExtractedMemory {
  text: string;
  category: MemoryCategory;
  importance: number;
}

export interface MemoryExtractionResult {
  shouldRemember: boolean;
  memories: ExtractedMemory[];
}

export interface ChatMemoryContext {
  studentMemories: StudentMemory[];
  conversationSummary?: string;
  recentMessages: Array<{ role: 'user' | 'assistant'; content: string }>;
  relevantPastSnippets: Array<{ title: string; content: string }>;
  memoryEnabled: boolean;
}
