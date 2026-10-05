/**
 * ============================================================================
 * Nexora AI — Cloud-Synced Chat Storage Layer (D1)
 * ============================================================================
 * Implements cloud-synced, cross-device persistence for chat conversations and
 * messages backed by Cloudflare D1 SQLite.
 *
 * Security & Isolation:
 * - Every table has a firebase_uid column.
 * - Every read, write, update, and delete query is strictly parameterized
 *   with the authenticated firebase_uid from Firebase Auth Guard.
 * - Never trusts client-supplied firebase_uid.
 * - Prevents User B from reading, creating in, or mutating User A's conversations.
 * ============================================================================
 */

import {
  ChatConversationRecord,
  ChatMessageRecord,
  CreateConversationInput,
  CreateMessageInput,
} from './chat_types';

export class ChatStorage {
  /**
   * Initializes private D1 chat tables and indexes if they do not exist.
   * Safe and non-destructive.
   */
  public static async ensureTables(db: any): Promise<void> {
    if (!db) return;

    try {
      // 1. chat_conversations
      await db.prepare(`
        CREATE TABLE IF NOT EXISTS chat_conversations (
          id TEXT PRIMARY KEY,
          firebase_uid TEXT NOT NULL,
          title TEXT NOT NULL,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
      `).run();

      await db.prepare(`
        CREATE INDEX IF NOT EXISTS idx_chat_conversations_user 
        ON chat_conversations(firebase_uid, updated_at DESC)
      `).run();

      // 2. chat_messages
      await db.prepare(`
        CREATE TABLE IF NOT EXISTS chat_messages (
          id TEXT PRIMARY KEY,
          conversation_id TEXT NOT NULL,
          firebase_uid TEXT NOT NULL,
          role TEXT NOT NULL,
          content TEXT NOT NULL,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
      `).run();

      await db.prepare(`
        CREATE INDEX IF NOT EXISTS idx_chat_messages_conv 
        ON chat_messages(conversation_id, created_at ASC)
      `).run();

      await db.prepare(`
        CREATE INDEX IF NOT EXISTS idx_chat_messages_user 
        ON chat_messages(firebase_uid, created_at DESC)
      `).run();
    } catch (err) {
      console.warn('[ChatStorage] ensureTables warning:', err);
    }
  }

  /**
   * List all conversations belonging to the authenticated Firebase user.
   * Sorted by updated_at descending.
   */
  public static async listConversations(
    db: any,
    firebaseUid: string,
    limit = 50,
    offset = 0
  ): Promise<ChatConversationRecord[]> {
    if (!db || !firebaseUid) return [];

    await this.ensureTables(db);

    const safeLimit = Math.min(Math.max(1, limit), 100);
    const safeOffset = Math.max(0, offset);

    try {
      // Query conversations and include the last message snippet
      const query = `
        SELECT 
          c.id,
          c.firebase_uid,
          c.title,
          c.created_at,
          c.updated_at,
          (
            SELECT content FROM chat_messages m 
            WHERE m.conversation_id = c.id AND m.firebase_uid = c.firebase_uid 
            ORDER BY m.created_at DESC LIMIT 1
          ) as last_message,
          (
            SELECT COUNT(*) FROM chat_messages m 
            WHERE m.conversation_id = c.id AND m.firebase_uid = c.firebase_uid
          ) as message_count
        FROM chat_conversations c
        WHERE c.firebase_uid = ?
        ORDER BY c.updated_at DESC
        LIMIT ? OFFSET ?
      `;

      const { results } = await db
        .prepare(query)
        .bind(firebaseUid, safeLimit, safeOffset)
        .all();

      return (results || []).map((row: any) => ({
        id: String(row.id),
        firebase_uid: String(row.firebase_uid),
        title: String(row.title || 'New Chat'),
        created_at: String(row.created_at),
        updated_at: String(row.updated_at),
        last_message: row.last_message ? String(row.last_message) : null,
        message_count: typeof row.message_count === 'number' ? row.message_count : 0,
      }));
    } catch (err) {
      console.error('[ChatStorage] listConversations error:', err);
      return [];
    }
  }

  /**
   * Retrieve a specific conversation by ID, strictly verifying ownership.
   */
  public static async getConversation(
    db: any,
    firebaseUid: string,
    conversationId: string
  ): Promise<ChatConversationRecord | null> {
    if (!db || !firebaseUid || !conversationId) return null;

    await this.ensureTables(db);

    try {
      const row = await db
        .prepare(`
          SELECT id, firebase_uid, title, created_at, updated_at
          FROM chat_conversations
          WHERE id = ? AND firebase_uid = ?
        `)
        .bind(conversationId, firebaseUid)
        .first();

      if (!row) return null;

      return {
        id: String(row.id),
        firebase_uid: String(row.firebase_uid),
        title: String(row.title || 'New Chat'),
        created_at: String(row.created_at),
        updated_at: String(row.updated_at),
      };
    } catch (err) {
      console.error('[ChatStorage] getConversation error:', err);
      return null;
    }
  }

  /**
   * Create or upsert a conversation for the authenticated Firebase user.
   */
  public static async createConversation(
    db: any,
    firebaseUid: string,
    input: CreateConversationInput
  ): Promise<ChatConversationRecord> {
    if (!db || !firebaseUid) throw new Error('Database and authenticated UID required');

    await this.ensureTables(db);

    const convId = (input.id && input.id.trim()) ? input.id.trim() : crypto.randomUUID();
    const title = (input.title && input.title.trim()) ? input.title.trim() : 'New Chat';

    // Insert or update (if id already exists for this user)
    await db
      .prepare(`
        INSERT INTO chat_conversations (id, firebase_uid, title, created_at, updated_at)
        VALUES (?, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
        ON CONFLICT(id) DO UPDATE SET
          title = CASE WHEN excluded.title != 'New Chat' THEN excluded.title ELSE chat_conversations.title END,
          updated_at = CURRENT_TIMESTAMP
        WHERE chat_conversations.firebase_uid = ?
      `)
      .bind(convId, firebaseUid, title, firebaseUid)
      .run();

    const created = await this.getConversation(db, firebaseUid, convId);
    if (!created) {
      return {
        id: convId,
        firebase_uid: firebaseUid,
        title,
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      };
    }
    return created;
  }

  /**
   * Update the title of an existing conversation, strictly verifying ownership.
   */
  public static async updateConversation(
    db: any,
    firebaseUid: string,
    conversationId: string,
    title: string
  ): Promise<boolean> {
    if (!db || !firebaseUid || !conversationId) return false;

    await this.ensureTables(db);

    const safeTitle = title.trim();
    if (!safeTitle) return false;

    try {
      const res = await db
        .prepare(`
          UPDATE chat_conversations
          SET title = ?, updated_at = CURRENT_TIMESTAMP
          WHERE id = ? AND firebase_uid = ?
        `)
        .bind(safeTitle, conversationId, firebaseUid)
        .run();

      return (res?.meta?.changes ?? 0) > 0;
    } catch (err) {
      console.error('[ChatStorage] updateConversation error:', err);
      return false;
    }
  }

  /**
   * Delete a conversation and all its messages, strictly verifying ownership.
   */
  public static async deleteConversation(
    db: any,
    firebaseUid: string,
    conversationId: string
  ): Promise<boolean> {
    if (!db || !firebaseUid || !conversationId) return false;

    await this.ensureTables(db);

    try {
      // First verify ownership
      const existing = await this.getConversation(db, firebaseUid, conversationId);
      if (!existing) return false;

      // Delete messages first, then conversation
      await db
        .prepare(`DELETE FROM chat_messages WHERE conversation_id = ? AND firebase_uid = ?`)
        .bind(conversationId, firebaseUid)
        .run();

      const res = await db
        .prepare(`DELETE FROM chat_conversations WHERE id = ? AND firebase_uid = ?`)
        .bind(conversationId, firebaseUid)
        .run();

      return (res?.meta?.changes ?? 0) > 0;
    } catch (err) {
      console.error('[ChatStorage] deleteConversation error:', err);
      return false;
    }
  }

  /**
   * Retrieve messages for a conversation, strictly verifying user ownership.
   */
  public static async getMessages(
    db: any,
    firebaseUid: string,
    conversationId: string,
    limit = 100,
    offset = 0
  ): Promise<ChatMessageRecord[]> {
    if (!db || !firebaseUid || !conversationId) return [];

    await this.ensureTables(db);

    const safeLimit = Math.min(Math.max(1, limit), 200);
    const safeOffset = Math.max(0, offset);

    try {
      const { results } = await db
        .prepare(`
          SELECT id, conversation_id, firebase_uid, role, content, created_at
          FROM chat_messages
          WHERE conversation_id = ? AND firebase_uid = ?
          ORDER BY created_at ASC
          LIMIT ? OFFSET ?
        `)
        .bind(conversationId, firebaseUid, safeLimit, safeOffset)
        .all();

      return (results || []).map((row: any) => ({
        id: String(row.id),
        conversation_id: String(row.conversation_id),
        firebase_uid: String(row.firebase_uid),
        role: row.role as 'user' | 'assistant' | 'system',
        content: String(row.content),
        created_at: String(row.created_at),
      }));
    } catch (err) {
      console.error('[ChatStorage] getMessages error:', err);
      return [];
    }
  }

  /**
   * Save a single chat message idempotently.
   * If a message with this id already exists, it is ignored (safe on retries).
   * Ensures parent conversation exists, and updates conversation updated_at.
   */
  public static async saveMessage(
    db: any,
    firebaseUid: string,
    input: CreateMessageInput
  ): Promise<ChatMessageRecord> {
    if (!db || !firebaseUid || !input.conversation_id || !input.content) {
      throw new Error('Database, authenticated UID, conversation_id, and content required');
    }

    await this.ensureTables(db);

    const msgId = (input.id && input.id.trim()) ? input.id.trim() : crypto.randomUUID();
    const convId = input.conversation_id.trim();
    const role = input.role || 'user';
    const content = input.content;

    // 1. Ensure conversation exists for this user; if not, create it
    const existingConv = await this.getConversation(db, firebaseUid, convId);
    if (!existingConv) {
      const autoTitle = content.length > 35 ? `${content.substring(0, 35)}...` : content;
      await this.createConversation(db, firebaseUid, {
        id: convId,
        title: role === 'user' ? autoTitle : 'New Chat',
      });
    } else if (role === 'user' && (existingConv.title === 'New Chat' || !existingConv.title)) {
      const autoTitle = content.length > 35 ? `${content.substring(0, 35)}...` : content;
      await this.updateConversation(db, firebaseUid, convId, autoTitle);
    }

    // 2. Insert message idempotently (INSERT OR IGNORE)
    if (input.created_at) {
      await db
        .prepare(`
          INSERT OR IGNORE INTO chat_messages (id, conversation_id, firebase_uid, role, content, created_at)
          VALUES (?, ?, ?, ?, ?, ?)
        `)
        .bind(msgId, convId, firebaseUid, role, content, input.created_at)
        .run();
    } else {
      await db
        .prepare(`
          INSERT OR IGNORE INTO chat_messages (id, conversation_id, firebase_uid, role, content, created_at)
          VALUES (?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
        `)
        .bind(msgId, convId, firebaseUid, role, content)
        .run();
    }

    // 3. Update conversation updated_at
    await db
      .prepare(`
        UPDATE chat_conversations
        SET updated_at = CURRENT_TIMESTAMP
        WHERE id = ? AND firebase_uid = ?
      `)
      .bind(convId, firebaseUid)
      .run();

    // 4. Return the stored message
    const row = await db
      .prepare(`
        SELECT id, conversation_id, firebase_uid, role, content, created_at
        FROM chat_messages
        WHERE id = ? AND firebase_uid = ?
      `)
      .bind(msgId, firebaseUid)
      .first();

    return {
      id: msgId,
      conversation_id: convId,
      firebase_uid: firebaseUid,
      role,
      content,
      created_at: row?.created_at ? String(row.created_at) : new Date().toISOString(),
    };
  }
}
