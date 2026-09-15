/**
 * ============================================================================
 * Nexora AI — Production-Grade Memory Storage Layer (D1)
 * ============================================================================
 * Safe, scoped persistence for conversations, messages, memories, and settings.
 * All queries are strictly scoped to the authenticated student_uid.
 * ============================================================================
 */

import {
  ConversationRecord,
  MessageRecord,
  StudentMemory,
  MemoryCategory,
} from './memory_types';

export class MemoryStorage {
  /**
   * Initializes memory tables and indexes if they do not already exist.
   * Safe and non-destructive.
   */
  public static async ensureTables(db: any): Promise<void> {
    if (!db) return;

    try {
      // 1. Conversations Table
      await db.prepare(`
        CREATE TABLE IF NOT EXISTS conversations (
          id TEXT PRIMARY KEY,
          student_uid TEXT NOT NULL,
          title TEXT NOT NULL,
          summary TEXT,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          archived_at TIMESTAMP
        )
      `).run();

      await db.prepare(`
        CREATE INDEX IF NOT EXISTS idx_conversations_student 
        ON conversations(student_uid, updated_at DESC)
      `).run();

      // 2. Messages Table
      await db.prepare(`
        CREATE TABLE IF NOT EXISTS messages (
          id TEXT PRIMARY KEY,
          conversation_id TEXT NOT NULL,
          student_uid TEXT NOT NULL,
          role TEXT NOT NULL,
          content TEXT NOT NULL,
          metadata_json TEXT,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
      `).run();

      await db.prepare(`
        CREATE INDEX IF NOT EXISTS idx_messages_conv 
        ON messages(conversation_id, created_at ASC)
      `).run();

      await db.prepare(`
        CREATE INDEX IF NOT EXISTS idx_messages_student 
        ON messages(student_uid, created_at DESC)
      `).run();

      // 3. Student Long-Term Memories Table
      await db.prepare(`
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
        )
      `).run();

      await db.prepare(`
        CREATE INDEX IF NOT EXISTS idx_student_memories_student 
        ON student_memories(student_uid, status, importance DESC)
      `).run();

      // 4. Student Memory Settings Table
      await db.prepare(`
        CREATE TABLE IF NOT EXISTS student_memory_settings (
          student_uid TEXT PRIMARY KEY,
          memory_enabled INTEGER DEFAULT 1,
          updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
      `).run();
    } catch (err) {
      console.warn('[MemoryStorage] ensureTables warning:', err);
    }
  }

  // ---------------------------------------------------------------------------
  // Memory Settings Operations
  // ---------------------------------------------------------------------------

  public static async isMemoryEnabled(db: any, studentUid: string): Promise<boolean> {
    if (!db || !studentUid) return true; // default ON
    try {
      const row = (await db.prepare(
        `SELECT memory_enabled FROM student_memory_settings WHERE student_uid = ?`
      ).bind(studentUid).first()) as { memory_enabled: number } | null;

      if (!row) return true; // default ON
      return row.memory_enabled === 1;
    } catch (e) {
      console.warn('[MemoryStorage] isMemoryEnabled error:', e);
      return true;
    }
  }

  public static async setMemoryEnabled(db: any, studentUid: string, enabled: boolean): Promise<void> {
    if (!db || !studentUid) return;
    try {
      await db.prepare(`
        INSERT INTO student_memory_settings (student_uid, memory_enabled, updated_at)
        VALUES (?, ?, CURRENT_TIMESTAMP)
        ON CONFLICT(student_uid) DO UPDATE SET
          memory_enabled = excluded.memory_enabled,
          updated_at = CURRENT_TIMESTAMP
      `).bind(studentUid, enabled ? 1 : 0).run();
    } catch (e) {
      console.error('[MemoryStorage] setMemoryEnabled error:', e);
      throw e;
    }
  }

  // ---------------------------------------------------------------------------
  // Conversation Operations (Scoped to authenticated student_uid)
  // ---------------------------------------------------------------------------

  public static async createConversation(
    db: any,
    studentUid: string,
    title: string,
    conversationId?: string
  ): Promise<ConversationRecord> {
    if (!db || !studentUid) {
      throw new Error('Database and student UID required');
    }

    const id = conversationId || (crypto.randomUUID ? crypto.randomUUID() : `conv_${Date.now()}_${Math.random().toString(36).slice(2, 9)}`);
    const cleanTitle = (title || 'New Chat').trim().slice(0, 80);
    const now = new Date().toISOString();

    await db.prepare(`
      INSERT INTO conversations (id, student_uid, title, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?)
    `).bind(id, studentUid, cleanTitle, now, now).run();

    return {
      id,
      student_uid: studentUid,
      title: cleanTitle,
      created_at: now,
      updated_at: now,
    };
  }

  public static async getConversation(
    db: any,
    studentUid: string,
    conversationId: string
  ): Promise<ConversationRecord | null> {
    if (!db || !studentUid || !conversationId) return null;

    const row = (await db.prepare(`
      SELECT id, student_uid, title, summary, created_at, updated_at, archived_at
      FROM conversations
      WHERE id = ? AND student_uid = ?
    `).bind(conversationId, studentUid).first()) as ConversationRecord | null;

    return row || null;
  }

  public static async listConversations(
    db: any,
    studentUid: string,
    limit = 50,
    offset = 0
  ): Promise<ConversationRecord[]> {
    if (!db || !studentUid) return [];

    const res = (await db.prepare(`
      SELECT id, student_uid, title, summary, created_at, updated_at, archived_at
      FROM conversations
      WHERE student_uid = ? AND (archived_at IS NULL)
      ORDER BY updated_at DESC
      LIMIT ? OFFSET ?
    `).bind(studentUid, limit, offset).all()) as { results?: ConversationRecord[] };

    return res?.results || [];
  }

  public static async updateConversationTitle(
    db: any,
    studentUid: string,
    conversationId: string,
    title: string
  ): Promise<boolean> {
    if (!db || !studentUid || !conversationId) return false;
    const cleanTitle = title.trim().slice(0, 80);

    const res = await db.prepare(`
      UPDATE conversations
      SET title = ?, updated_at = CURRENT_TIMESTAMP
      WHERE id = ? AND student_uid = ?
    `).bind(cleanTitle, conversationId, studentUid).run();

    return Boolean(res?.success);
  }

  public static async updateConversationSummary(
    db: any,
    studentUid: string,
    conversationId: string,
    summary: string
  ): Promise<boolean> {
    if (!db || !studentUid || !conversationId) return false;

    const res = await db.prepare(`
      UPDATE conversations
      SET summary = ?, updated_at = CURRENT_TIMESTAMP
      WHERE id = ? AND student_uid = ?
    `).bind(summary, conversationId, studentUid).run();

    return Boolean(res?.success);
  }

  public static async deleteConversation(
    db: any,
    studentUid: string,
    conversationId: string
  ): Promise<boolean> {
    if (!db || !studentUid || !conversationId) return false;

    // 1. Delete all messages for this conversation belonging to this student
    await db.prepare(`
      DELETE FROM messages
      WHERE conversation_id = ? AND student_uid = ?
    `).bind(conversationId, studentUid).run();

    // 2. Delete the conversation record
    const res = await db.prepare(`
      DELETE FROM conversations
      WHERE id = ? AND student_uid = ?
    `).bind(conversationId, studentUid).run();

    return Boolean(res?.success);
  }

  // ---------------------------------------------------------------------------
  // Message Operations (Scoped to student_uid)
  // ---------------------------------------------------------------------------

  public static async saveMessage(
    db: any,
    studentUid: string,
    conversationId: string,
    role: 'user' | 'assistant',
    content: string,
    metadataJson?: string,
    messageId?: string
  ): Promise<MessageRecord> {
    if (!db || !studentUid || !conversationId) {
      throw new Error('Database, studentUid, and conversationId required');
    }

    const id = messageId || (crypto.randomUUID ? crypto.randomUUID() : `msg_${Date.now()}_${Math.random().toString(36).slice(2, 9)}`);
    const now = new Date().toISOString();

    await db.prepare(`
      INSERT INTO messages (id, conversation_id, student_uid, role, content, metadata_json, created_at)
      VALUES (?, ?, ?, ?, ?, ?, ?)
    `).bind(id, conversationId, studentUid, role, content, metadataJson || null, now).run();

    // Touch conversation updated_at
    await db.prepare(`
      UPDATE conversations
      SET updated_at = ?
      WHERE id = ? AND student_uid = ?
    `).bind(now, conversationId, studentUid).run();

    return {
      id,
      conversation_id: conversationId,
      student_uid: studentUid,
      role,
      content,
      metadata_json: metadataJson || null,
      created_at: now,
    };
  }

  public static async getMessages(
    db: any,
    studentUid: string,
    conversationId: string,
    limit = 50
  ): Promise<MessageRecord[]> {
    if (!db || !studentUid || !conversationId) return [];

    const res = (await db.prepare(`
      SELECT id, conversation_id, student_uid, role, content, metadata_json, created_at
      FROM messages
      WHERE conversation_id = ? AND student_uid = ?
      ORDER BY created_at ASC
      LIMIT ?
    `).bind(conversationId, studentUid, limit).all()) as { results?: MessageRecord[] };

    return res?.results || [];
  }

  // ---------------------------------------------------------------------------
  // Long-Term Student Memory Operations
  // ---------------------------------------------------------------------------

  public static async getActiveMemories(
    db: any,
    studentUid: string,
    limit = 10
  ): Promise<StudentMemory[]> {
    if (!db || !studentUid) return [];

    const res = (await db.prepare(`
      SELECT id, student_uid, memory_text, category, importance, created_at, updated_at, last_used_at, source_conversation_id, status
      FROM student_memories
      WHERE student_uid = ? AND status = 'active'
      ORDER BY importance DESC, updated_at DESC
      LIMIT ?
    `).bind(studentUid, limit).all()) as { results?: StudentMemory[] };

    return res?.results || [];
  }

  public static async upsertMemory(
    db: any,
    studentUid: string,
    params: {
      text: string;
      category: MemoryCategory;
      importance?: number;
      sourceConversationId?: string;
    }
  ): Promise<StudentMemory> {
    if (!db || !studentUid || !params.text.trim()) {
      throw new Error('Database, studentUid, and memory text are required');
    }

    const cleanText = params.text.trim();
    const importance = params.importance ?? 0.7;

    // Check if similar memory exists for this student & category
    const existing = await this.findSimilarMemory(db, studentUid, cleanText, params.category);

    if (existing) {
      // Update existing memory with higher importance or refreshed timestamp
      const newImportance = Math.max(existing.importance, importance);
      const now = new Date().toISOString();

      await db.prepare(`
        UPDATE student_memories
        SET memory_text = ?, importance = ?, updated_at = ?, status = 'active'
        WHERE id = ? AND student_uid = ?
      `).bind(cleanText, newImportance, now, existing.id, studentUid).run();

      return {
        ...existing,
        memory_text: cleanText,
        importance: newImportance,
        updated_at: now,
        status: 'active',
      };
    }

    const id = crypto.randomUUID ? crypto.randomUUID() : `mem_${Date.now()}_${Math.random().toString(36).slice(2, 9)}`;
    const now = new Date().toISOString();

    await db.prepare(`
      INSERT INTO student_memories (id, student_uid, memory_text, category, importance, created_at, updated_at, source_conversation_id, status)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'active')
    `).bind(id, studentUid, cleanText, params.category, importance, now, now, params.sourceConversationId || null).run();

    return {
      id,
      student_uid: studentUid,
      memory_text: cleanText,
      category: params.category,
      importance,
      created_at: now,
      updated_at: now,
      source_conversation_id: params.sourceConversationId || null,
      status: 'active',
    };
  }

  public static async findSimilarMemory(
    db: any,
    studentUid: string,
    text: string,
    category: MemoryCategory
  ): Promise<StudentMemory | null> {
    if (!db || !studentUid) return null;

    const memories = await this.getActiveMemories(db, studentUid, 50);
    const targetTokens = new Set(
      text.toLowerCase().replace(/[^a-z0-9\s]/g, '').split(/\s+/).filter(Boolean)
    );

    if (targetTokens.size === 0) return null;

    for (const mem of memories) {
      if (mem.category !== category) continue;

      const memTokens = new Set(
        mem.memory_text.toLowerCase().replace(/[^a-z0-9\s]/g, '').split(/\s+/).filter(Boolean)
      );

      let overlap = 0;
      for (const t of targetTokens) {
        if (memTokens.has(t)) overlap++;
      }

      const union = new Set([...targetTokens, ...memTokens]).size;
      const jaccard = union > 0 ? overlap / union : 0;

      // Direct substring match or high token similarity (> 0.55 on memory statements)
      if (
        jaccard >= 0.55 ||
        mem.memory_text.toLowerCase().includes(text.toLowerCase()) ||
        text.toLowerCase().includes(mem.memory_text.toLowerCase())
      ) {
        return mem;
      }
    }

    return null;
  }

  public static async deleteMemory(
    db: any,
    studentUid: string,
    memoryId: string
  ): Promise<boolean> {
    if (!db || !studentUid || !memoryId) return false;

    const res = await db.prepare(`
      DELETE FROM student_memories
      WHERE id = ? AND student_uid = ?
    `).bind(memoryId, studentUid).run();

    return Boolean(res?.success);
  }

  public static async clearAllMemories(
    db: any,
    studentUid: string
  ): Promise<number> {
    if (!db || !studentUid) return 0;

    const res = await db.prepare(`
      DELETE FROM student_memories
      WHERE student_uid = ?
    `).bind(studentUid).run();

    return res?.meta?.changes ?? 1;
  }

  public static async searchRelevantMemories(
    db: any,
    studentUid: string,
    query: string,
    limit = 5
  ): Promise<StudentMemory[]> {
    if (!db || !studentUid) return [];

    const allMemories = await this.getActiveMemories(db, studentUid, 20);
    if (allMemories.length === 0) return [];

    const queryTokens = new Set(
      query.toLowerCase().replace(/[^a-z0-9\s]/g, '').split(/\s+/).filter(Boolean)
    );

    const scored = allMemories.map((mem) => {
      let score = mem.importance; // Base importance
      const memTokens = mem.memory_text.toLowerCase().split(/\s+/);
      for (const token of memTokens) {
        if (queryTokens.has(token)) {
          score += 1.0;
        }
      }
      return { mem, score };
    });

    scored.sort((a, b) => b.score - a.score);
    return scored.slice(0, limit).map((s) => s.mem);
  }

  public static async searchRelevantPastConversations(
    db: any,
    studentUid: string,
    currentConvId: string | undefined,
    query: string,
    limit = 3
  ): Promise<Array<{ title: string; content: string }>> {
    if (!db || !studentUid || !query.trim()) return [];

    const cleanTokens = query
      .toLowerCase()
      .replace(/[^a-z0-9\s]/g, '')
      .split(/\s+/)
      .filter((w) => w.length > 3 && !['what', 'when', 'where', 'explain', 'please', 'tell', 'show'].includes(w));

    if (cleanTokens.length === 0) return [];

    // Search past messages from other conversations of the SAME student
    try {
      const topKeyword = cleanTokens[0];
      const res = (await db.prepare(`
        SELECT c.title, m.content
        FROM messages m
        JOIN conversations c ON m.conversation_id = c.id
        WHERE m.student_uid = ?
          AND (? IS NULL OR m.conversation_id != ?)
          AND m.content LIKE ?
        ORDER BY m.created_at DESC
        LIMIT ?
      `).bind(studentUid, currentConvId || null, currentConvId || null, `%${topKeyword}%`, limit).all()) as {
        results?: Array<{ title: string; content: string }>;
      };

      return (res?.results || []).map((r: { title: string; content: string }) => ({
        title: r.title || 'Previous Discussion',
        content: r.content.length > 250 ? `${r.content.slice(0, 250)}...` : r.content,
      }));
    } catch (e) {
      console.warn('[MemoryStorage] searchRelevantPastConversations note:', e);
      return [];
    }
  }
}
