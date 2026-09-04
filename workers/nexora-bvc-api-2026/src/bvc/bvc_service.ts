import { IBVCClient } from './bvc_client_interface';
import { MockBVCClient } from './mock_bvc_client';
import { LiveBVCClient } from './live_bvc_client';
import { BVCSyncResult } from './bvc_types';
import { BVCNormalizer } from './bvc_normalizer';
import { BVCStorage } from './bvc_storage';

export class BVCService {
  private static liveClient: LiveBVCClient = new LiveBVCClient();
  private static mockClient: MockBVCClient = new MockBVCClient();

  /**
   * Connects and synchronizes student data directly from the official BVC portal.
   * Uses the live official portal client by default.
   */
  public static async syncStudent(params: {
    firebaseUid: string;
    rollNumber: string;
    password?: string;
    useLiveClient?: boolean;
    db?: D1Database;
  }): Promise<BVCSyncResult> {
    const normalizedRoll = BVCNormalizer.normalizeRollNumber(params.rollNumber);
    if (!BVCNormalizer.isValidRollNumber(normalizedRoll)) {
      throw new Error(`Invalid BVC roll number format: '${params.rollNumber}'. Expected pattern e.g. 25221A0568.`);
    }

    // Default to LiveBVCClient unless mock client is explicitly requested
    let client: IBVCClient = this.liveClient;
    if (params.useLiveClient === false) {
      client = this.mockClient;
    }

    const result = await client.syncStudentData({
      firebaseUid: params.firebaseUid,
      rollNumber: normalizedRoll,
      password: params.password,
    });

    if (result.success && params.db) {
      await BVCStorage.saveSyncResult(params.db, result);
    }

    return result;
  }
}
