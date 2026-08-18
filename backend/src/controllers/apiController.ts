import type { Request, Response } from 'express';
import { v4 as uuidv4 } from 'uuid';
import { databaseFoundation } from '../services/databaseService';

export const getCurrentUser = (req: Request, res: Response) => {
  const user = (req as any).user;

  if (!user) {
    return res.status(401).json({ error: 'Authentication required in development mode.' });
  }

  return res.json({
    id: user.id,
    email: user.email,
    role: user.role ?? 'student',
  });
};

export const listDocuments = (_req: Request, res: Response) => {
  res.json({
    documents: databaseFoundation.getDocuments(),
  });
};

export const createDocument = (req: Request, res: Response) => {
  const body = req.body ?? {};
  const record = databaseFoundation.createDocument({
    id: uuidv4(),
    userId: (req as any).user?.id ?? 'dev-user-001',
    fileName: body.fileName ?? 'untitled.txt',
    fileType: body.fileType ?? 'text/plain',
    storageKey: body.storageKey ?? `documents/${uuidv4()}`,
    uploadStatus: body.uploadStatus ?? 'pending',
    createdAt: new Date().toISOString(),
  });

  res.status(201).json(record);
};

export const listConversations = (req: Request, res: Response) => {
  const userId = (req as any).user?.id ?? 'dev-user-001';

  const conversations = databaseFoundation
    .getConversations()
    .filter((conversation) => conversation.userId === userId);

  res.json({ conversations });
};

export const createConversation = (req: Request, res: Response) => {
  const body = req.body ?? {};
  const userId = (req as any).user?.id ?? 'dev-user-001';

  const conversation = databaseFoundation.createConversation({
    id: uuidv4(),
    userId,
    title: body.title ?? 'New conversation',
    createdAt: new Date().toISOString(),
  });

  res.status(201).json(conversation);
};

export const getConversationMessages = (req: Request, res: Response) => {
  const { id } = req.params;
  const conversation = databaseFoundation.getConversationById(id);

  if (!conversation) {
    return res.status(404).json({ error: 'Conversation not found' });
  }

  const messages = databaseFoundation.getConversationMessages(id);
  return res.json({ conversationId: id, messages });
};

export const createConversationMessage = (req: Request, res: Response) => {
  const { id } = req.params;
  const body = req.body ?? {};

  const conversation = databaseFoundation.getConversationById(id);
  if (!conversation) {
    return res.status(404).json({ error: 'Conversation not found' });
  }

  const message = databaseFoundation.createMessage({
    id: uuidv4(),
    conversationId: id,
    userId: (req as any).user?.id ?? 'dev-user-001',
    role: body.role ?? 'user',
    content: body.content ?? '',
    createdAt: new Date().toISOString(),
  });

  return res.status(201).json(message);
};
