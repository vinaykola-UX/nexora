import { Router } from 'express';
import { healthCheck } from '../controllers/healthController';
import {
  createConversation,
  createConversationMessage,
  createDocument,
  getConversationMessages,
  getCurrentUser,
  listConversations,
  listDocuments,
} from '../controllers/apiController';
import { developmentAuthMiddleware } from '../middleware/authMiddleware';

const router = Router();

router.get('/health', healthCheck);

router.use('/api', developmentAuthMiddleware);

router.get('/api/users/me', getCurrentUser);
router.get('/api/documents', listDocuments);
router.post('/api/documents', createDocument);
router.get('/api/conversations', listConversations);
router.post('/api/conversations', createConversation);
router.get('/api/conversations/:id/messages', getConversationMessages);
router.post('/api/conversations/:id/messages', createConversationMessage);

export default router;
