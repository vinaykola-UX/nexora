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
   * In production, STRICTLY uses the live official portal client (Mock client is never permitted).
   * In non-production, mock client is allowed only if explicitly enabled by test configuration.
   */
  public static async syncStudent(params: {
    firebaseUid: string;
    rollNumber: string;
    password?: string;
    environment?: string;
    allowMockForTesting?: boolean;
    db?: D1Database;
  }): Promise<BVCSyncResult> {
    const normalizedRoll = BVCNormalizer.normalizeRollNumber(params.rollNumber);
    if (!BVCNormalizer.isValidRollNumber(normalizedRoll)) {
      throw new Error(`Invalid BVC roll number format: '${params.rollNumber}'. Expected pattern e.g. 25221A0568.`);
    }

    const isProduction = !params.environment || params.environment.toLowerCase() === 'production';

    // Production Invariant: ALWAYS use LiveBVCClient in production
    let client: IBVCClient = this.liveClient;
    if (!isProduction && params.allowMockForTesting === true) {
      client = this.mockClient;
    }

    const result = await client.syncStudentData({
      firebaseUid: params.firebaseUid,
      rollNumber: normalizedRoll,
      password: params.password,
    });

    // Mandatory Profile Identity Cross-Check
    if (result.success && result.profile) {
      const returnedRoll = BVCNormalizer.normalizeRollNumber(result.profile.roll_number || '');
      if (returnedRoll !== normalizedRoll) {
        return {
          success: false,
          message: 'BVC verification failed because the returned student identity did not match the requested roll number.',
          profile: null as any,
          subjects: [],
          attendance: [],
          results: [],
          timetable: [],
          fees: [],
        };
      }

      // Validate required official profile fields
      if (!result.profile.name || !result.profile.branch) {
        return {
          success: false,
          message: 'Unable to verify your BVC details. Official student information was incomplete. Please try again.',
          profile: null as any,
          subjects: [],
          attendance: [],
          results: [],
          timetable: [],
          fees: [],
        };
      }
    }

    // Persist verified records ONLY when verification succeeded and profile is valid
    if (result.success && result.profile && params.db) {
      await BVCStorage.saveSyncResult(params.db, result);
    }

    return result;
  }
}
