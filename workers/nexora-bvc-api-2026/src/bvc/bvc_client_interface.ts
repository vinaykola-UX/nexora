import { BVCSyncResult } from './bvc_types';

export interface IBVCClient {
  readonly clientType: 'live' | 'mock';
  readonly isAuthorized: boolean;

  /**
   * Connects and syncs student data for a given roll number and optional credentials.
   * Enforces normalization and zero guessing.
   */
  syncStudentData(params: {
    firebaseUid: string;
    rollNumber: string;
    password?: string;
  }): Promise<BVCSyncResult>;
}
