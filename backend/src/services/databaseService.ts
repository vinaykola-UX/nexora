export type DbRecordStatus = 'pending' | 'uploaded' | 'failed';

export interface UserRecord {
  id: string;
  email: string;
  firstName?: string;
  lastName?: string;
  role: 'student' | 'teacher' | 'staff' | 'admin' | 'unknown';
  createdAt: string;
  updatedAt?: string;
}

export interface DocumentRecord {
  id: string;
  userId: string;
  fileName: string;
  fileType: string;
  storageKey: string;
  uploadStatus: DbRecordStatus;
  createdAt: string;
  updatedAt?: string;
}

export interface ConversationRecord {
  id: string;
  userId: string;
  title: string;
  createdAt: string;
  updatedAt?: string;
}

export interface ConversationMessageRecord {
  id: string;
  conversationId: string;
  userId: string;
  role: 'user' | 'assistant' | 'system';
  content: string;
  createdAt: string;
}

export class DatabaseFoundation {
  private readonly users: UserRecord[] = [];
  private readonly documents: DocumentRecord[] = [];
  private readonly conversations: ConversationRecord[] = [];
  private readonly messages: ConversationMessageRecord[] = [];

  getUsers() {
    return [...this.users];
  }

  getUserById(id: string) {
    return this.users.find((user) => user.id === id);
  }

  createUser(input: Omit<UserRecord, 'createdAt'> & { createdAt?: string }) {
    const createdAt = input.createdAt ?? new Date().toISOString();
    const user: UserRecord = {
      ...input,
      createdAt,
    };
    this.users.push(user);
    return user;
  }

  getDocuments() {
    return [...this.documents];
  }

  createDocument(input: Omit<DocumentRecord, 'createdAt'> & { createdAt?: string }) {
    const createdAt = input.createdAt ?? new Date().toISOString();
    const doc: DocumentRecord = {
      ...input,
      createdAt,
    };
    this.documents.push(doc);
    return doc;
  }

  getConversations() {
    return [...this.conversations];
  }

  getConversationById(id: string) {
    return this.conversations.find((conversation) => conversation.id === id);
  }

  createConversation(input: Omit<ConversationRecord, 'createdAt'> & { createdAt?: string }) {
    const createdAt = input.createdAt ?? new Date().toISOString();
    const conversation: ConversationRecord = {
      ...input,
      createdAt,
    };
    this.conversations.push(conversation);
    return conversation;
  }

  getConversationMessages(conversationId: string) {
    return this.messages.filter((message) => message.conversationId === conversationId);
  }

  createMessage(input: Omit<ConversationMessageRecord, 'createdAt'> & { createdAt?: string }) {
    const createdAt = input.createdAt ?? new Date().toISOString();
    const message: ConversationMessageRecord = {
      ...input,
      createdAt,
    };
    this.messages.push(message);
    return message;
  }
}

export const databaseFoundation = new DatabaseFoundation();
