export interface AuthenticatedRequest {
  user?: {
    id: string;
    email: string;
    role?: string;
  };
}

export const developmentAuthMiddleware = (req: any, res: any, next: any) => {
  req.user = {
    id: 'dev-user-001',
    email: 'dev@nexora.local',
    role: 'student',
  };

  next();
};
