import { IBVCClient } from './bvc_client_interface';
import { BVCSyncResult, BVCStudentProfile } from './bvc_types';
import { BVCNormalizer } from './bvc_normalizer';

/**
 * Live BVC Portal Client (ASP.NET WebForms SBCMS Connector)
 *
 * AUTHORIZATION GATE STATUS:
 * Institutional authorization and formal third-party access agreements with the
 * BVC Autonomous Examination Cell (www.bvcecautonomous.com) are currently PENDING.
 *
 * In accordance with the BVC Automated Access Authorization Gate:
 * - Live automated hitting of the student portal without an institutional API or
 *   explicit student authorization agreement is kept strictly disabled by default.
 * - This prevents unintended account lockouts, rate limit violations, or unauthorized access.
 */
export class LiveBVCClient implements IBVCClient {
  public readonly clientType = 'live' as const;

  /**
   * Flag indicating whether official institutional authorization has been established.
   * Defaults to false until BVC IT administration provides official API / authorization.
   */
  public get isAuthorized(): boolean {
    return false;
  }

  public async syncStudentData(params: {
    firebaseUid: string;
    rollNumber: string;
    password?: string;
  }): Promise<BVCSyncResult> {
    const normalizedRoll = BVCNormalizer.normalizeRollNumber(params.rollNumber);
    const now = new Date().toISOString();

    // Strict Authorization Gate Check
    if (!this.isAuthorized) {
      const fallbackProfile: BVCStudentProfile = {
        firebase_uid: params.firebaseUid,
        roll_number: normalizedRoll,
        name: null,
        branch: null,
        course: 'B.Tech',
        year: null,
        semester: null,
        section: null,
        regulation: null,
        academic_batch: null,
        college_email: `${normalizedRoll.toLowerCase()}@bvcgroup.in`,
        connected: false,
        last_synced_at: null,
        data_source: 'BVC_PORTAL',
        created_at: now,
        updated_at: now,
      };

      return {
        success: false,
        requiresOfficialApproval: true,
        message:
          'BVC Autonomous Examination Portal (bvcecautonomous.com) live automated access gate is active. ' +
          'Official institutional API credentials or formal administrative partnership with the Examination Cell ' +
          'is required before live crawling. Development and verification can proceed using the authorized adapter.',
        profile: fallbackProfile,
        subjects: [],
        attendance: [],
        results: [],
        timetable: [],
        fees: [],
      };
    }

    // When authorized by BVC, the real ASP.NET session exchange executes here:
    // 1. GET https://www.bvcecautonomous.com/SBLogin.aspx
    // 2. Extract __VIEWSTATE, __EVENTVALIDATION, __VIEWSTATEGENERATOR
    // 3. POST credentials (txtUserName, txtPassword, btnSubmit)
    // 4. Capture ASP.NET_SessionId
    // 5. Scrape ViewHomepage.aspx and OnlineResultReport.aspx
    // 6. Return parsed, normalized data
    throw new Error('BVC live automated adapter is gated pending institutional authorization.');
  }
}
