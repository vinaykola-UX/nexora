import { ChatStorage } from './src/chat/chat_storage';

// In-memory mock D1 for testing
class MockD1Statement {
  private sql: string;
  private params: any[];
  private db: MockD1Database;

  constructor(db: MockD1Database, sql: string, params: any[] = []) {
    this.db = db;
    this.sql = sql;
    this.params = params;
  }

  bind(...params: any[]) {
    return new MockD1Statement(this.db, this.sql, params);
  }

  async run() {
    return this.db.execute(this.sql, this.params);
  }

  async all() {
    return this.db.query(this.sql, this.params);
  }

  async first() {
    const res = await this.all();
    return res.results && res.results.length > 0 ? res.results[0] : null;
  }
}

class MockD1Database {
  public conversations: any[] = [];
  public messages: any[] = [];

  prepare(sql: string) {
    return new MockD1Statement(this, sql);
  }

  async execute(sql: string, params: any[]): Promise<any> {
    const s = sql.trim().toUpperCase();

    if (s.startsWith('CREATE TABLE') || s.startsWith('CREATE INDEX')) {
      return { success: true, meta: { changes: 0 } };
    }

    if (s.startsWith('INSERT INTO CHAT_CONVERSATIONS')) {
      const [id, firebase_uid, title] = params;
      const existing = this.conversations.find((c) => c.id === id);
      if (existing) {
        if (existing.firebase_uid === firebase_uid) {
          if (title && title !== 'New Chat') existing.title = title;
          existing.updated_at = new Date().toISOString();
        }
      } else {
        this.conversations.push({
          id,
          firebase_uid,
          title,
          created_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
        });
      }
      return { success: true, meta: { changes: 1 } };
    }

    if (s.startsWith('INSERT OR IGNORE INTO CHAT_MESSAGES')) {
      const [id, conversation_id, firebase_uid, role, content, created_at] = params;
      const existing = this.messages.find((m) => m.id === id);
      if (!existing) {
        this.messages.push({
          id,
          conversation_id,
          firebase_uid,
          role,
          content,
          created_at: created_at || new Date().toISOString(),
        });
        return { success: true, meta: { changes: 1 } };
      }
      return { success: true, meta: { changes: 0 } };
    }

    if (s.startsWith('UPDATE CHAT_CONVERSATIONS')) {
      if (params.length === 2) {
        const [convId, uid] = params;
        const c = this.conversations.find((x) => x.id === convId && x.firebase_uid === uid);
        if (c) {
          c.updated_at = new Date().toISOString();
          return { success: true, meta: { changes: 1 } };
        }
      } else if (params.length === 3) {
        const [title, convId, uid] = params;
        const c = this.conversations.find((x) => x.id === convId && x.firebase_uid === uid);
        if (c) {
          c.title = title;
          c.updated_at = new Date().toISOString();
          return { success: true, meta: { changes: 1 } };
        }
      }
      return { success: true, meta: { changes: 0 } };
    }

    if (s.startsWith('DELETE FROM CHAT_MESSAGES')) {
      const [convId, uid] = params;
      const initial = this.messages.length;
      this.messages = this.messages.filter((m) => !(m.conversation_id === convId && m.firebase_uid === uid));
      return { success: true, meta: { changes: initial - this.messages.length } };
    }

    if (s.startsWith('DELETE FROM CHAT_CONVERSATIONS')) {
      const [convId, uid] = params;
      const initial = this.conversations.length;
      this.conversations = this.conversations.filter((c) => !(c.id === convId && c.firebase_uid === uid));
      return { success: true, meta: { changes: initial - this.conversations.length } };
    }

    return { success: true, meta: { changes: 0 } };
  }

  async query(sql: string, params: any[]): Promise<any> {
    const s = sql.trim().toUpperCase();

    if (s.includes('FROM CHAT_CONVERSATIONS C') && s.includes('WHERE C.FIREBASE_UID = ?')) {
      const [uid, limit, offset] = params;
      const userConvs = this.conversations
        .filter((c) => c.firebase_uid === uid)
        .sort((a, b) => new Date(b.updated_at).getTime() - new Date(a.updated_at).getTime());

      const results = userConvs.slice(offset, offset + limit).map((c) => {
        const msgs = this.messages.filter((m) => m.conversation_id === c.id && m.firebase_uid === uid);
        const lastMsg = msgs.length > 0 ? msgs[msgs.length - 1].content : null;
        return {
          ...c,
          last_message: lastMsg,
          message_count: msgs.length,
        };
      });
      return { results };
    }

    if (s.includes('FROM CHAT_CONVERSATIONS') && s.includes('WHERE ID = ? AND FIREBASE_UID = ?')) {
      const [id, uid] = params;
      const match = this.conversations.find((c) => c.id === id && c.firebase_uid === uid);
      return { results: match ? [match] : [] };
    }

    if (s.includes('FROM CHAT_MESSAGES') && s.includes('WHERE CONVERSATION_ID = ? AND FIREBASE_UID = ?')) {
      const [convId, uid, limit, offset] = params;
      const msgs = this.messages
        .filter((m) => m.conversation_id === convId && m.firebase_uid === uid)
        .sort((a, b) => new Date(a.created_at).getTime() - new Date(b.created_at).getTime())
        .slice(offset, offset + limit);
      return { results: msgs };
    }

    if (s.includes('FROM CHAT_MESSAGES') && s.includes('WHERE ID = ? AND FIREBASE_UID = ?')) {
      const [msgId, uid] = params;
      const match = this.messages.find((m) => m.id === msgId && m.firebase_uid === uid);
      return { results: match ? [match] : [] };
    }

    return { results: [] };
  }
}

async function runChatSyncTests() {
  console.log('🧪 Starting ChatSync & Cross-Device Storage Invariants Test Suite...\n');
  const db = new MockD1Database();
  const UID_USER1 = 'user_device_sync_alpha';
  const UID_USER2 = 'user_device_sync_beta';

  let passed = 0;
  let total = 0;

  function assert(cond: boolean, name: string, detail?: string) {
    total++;
    if (cond) {
      console.log(`  ✅ [PASS] ${name}`);
      passed++;
    } else {
      console.error(`  ❌ [FAIL] ${name} - ${detail || ''}`);
    }
  }

  // 1. Device 1 creates a conversation
  const conv1 = await ChatStorage.createConversation(db, UID_USER1, {
    id: 'conv-phone-1',
    title: 'Operating Systems Revision',
  });
  assert(conv1.id === 'conv-phone-1', 'Test 1: Conversation created by Device 1');

  // 2. Device 1 saves messages
  await ChatStorage.saveMessage(db, UID_USER1, {
    id: 'msg-1',
    conversation_id: 'conv-phone-1',
    role: 'user',
    content: 'What is round-robin scheduling?',
  });
  await ChatStorage.saveMessage(db, UID_USER1, {
    id: 'msg-2',
    conversation_id: 'conv-phone-1',
    role: 'assistant',
    content: 'Round-robin is a preemptive scheduling algorithm...',
  });

  // 3. Device 2 (same UID, e.g. laptop or second phone) lists conversations
  const device2Convs = await ChatStorage.listConversations(db, UID_USER1);
  assert(device2Convs.length === 1, 'Test 2: Device 2 sees the conversation created by Device 1');
  assert(device2Convs[0].id === 'conv-phone-1', 'Test 3: Conversation ID matches on Device 2');
  assert(device2Convs[0].title === 'Operating Systems Revision', 'Test 4: Conversation title matches on Device 2');

  // 4. Device 2 retrieves messages for this conversation
  const device2Messages = await ChatStorage.getMessages(db, UID_USER1, 'conv-phone-1');
  assert(device2Messages.length === 2, 'Test 5: Device 2 sees both messages created by Device 1');
  assert(device2Messages[0].content === 'What is round-robin scheduling?', 'Test 6: User message content preserved');
  assert(device2Messages[1].role === 'assistant', 'Test 7: Assistant message role preserved');

  // 5. Device 2 renames conversation
  const renameOk = await ChatStorage.updateConversation(db, UID_USER1, 'conv-phone-1', 'OS Process Scheduling');
  assert(renameOk === true, 'Test 8: Device 2 can rename conversation');
  const updatedConv = await ChatStorage.getConversation(db, UID_USER1, 'conv-phone-1');
  assert(updatedConv?.title === 'OS Process Scheduling', 'Test 9: Renamed title reflected across devices');

  // 6. Security Isolation: User 2 CANNOT access User 1's conversations or messages
  const user2Convs = await ChatStorage.listConversations(db, UID_USER2);
  assert(user2Convs.length === 0, 'Test 10: User 2 sees 0 conversations (strict isolation)');

  const user2AccessConv1 = await ChatStorage.getConversation(db, UID_USER2, 'conv-phone-1');
  assert(user2AccessConv1 === null, 'Test 11: User 2 cannot access User 1 conversation directly');

  const user2AccessMsgs = await ChatStorage.getMessages(db, UID_USER2, 'conv-phone-1');
  assert(user2AccessMsgs.length === 0, 'Test 12: User 2 cannot read User 1 messages');

  // 7. Message Idempotency: Duplicate message ID is ignored
  await ChatStorage.saveMessage(db, UID_USER1, {
    id: 'msg-1', // existing id
    conversation_id: 'conv-phone-1',
    role: 'user',
    content: 'Duplicate message attempt',
  });
  const msgsAfterDup = await ChatStorage.getMessages(db, UID_USER1, 'conv-phone-1');
  assert(msgsAfterDup.length === 2, 'Test 13: Duplicate message ID is ignored (idempotent)');

  // 8. Delete conversation
  const delOk = await ChatStorage.deleteConversation(db, UID_USER1, 'conv-phone-1');
  assert(delOk === true, 'Test 14: Conversation deletion succeeds');
  const convsAfterDel = await ChatStorage.listConversations(db, UID_USER1);
  assert(convsAfterDel.length === 0, 'Test 15: Conversation deleted from list');
  const msgsAfterDel = await ChatStorage.getMessages(db, UID_USER1, 'conv-phone-1');
  assert(msgsAfterDel.length === 0, 'Test 16: Associated messages deleted');

  console.log(`\n================================================================`);
  console.log(`📊 Chat Sync Test Results: ${passed}/${total} Passed, ${total - passed} Failed`);
  console.log(`================================================================\n`);

  if (passed !== total) process.exit(1);
}

runChatSyncTests().catch((err) => {
  console.error('Test error:', err);
  process.exit(1);
});
