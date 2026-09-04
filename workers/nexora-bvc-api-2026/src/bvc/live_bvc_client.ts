import { IBVCClient } from './bvc_client_interface';
import { BVCSyncResult, BVCStudentProfile } from './bvc_types';
import { BVCNormalizer } from './bvc_normalizer';

/**
 * Live BVC Portal Client (ASP.NET WebForms SBCMS Connector)
 *
 * Connects directly to the official BVC Autonomous Examination Student Portal:
 * https://www.bvcecautonomous.com/SBLogin.aspx
 *
 * Protocol:
 * 1. Initial GET https://www.bvcecautonomous.com/SBLogin.aspx
 *    - Extracts hidden ASP.NET WebForms fields: __VIEWSTATE, __VIEWSTATEGENERATOR, __EVENTVALIDATION
 *    - Captures the initial ASP.NET_SessionId cookie
 * 2. POST to https://www.bvcecautonomous.com/SBLogin.aspx
 *    - txtUserName = normalized uppercase roll number (e.g. 25221A0568)
 *    - txtPassword = normalized uppercase roll number (e.g. 25221A0568)
 *    - btnSubmit = Login
 * 3. Validates authentication response:
 *    - Checks for invalid credentials banner (<span id="lblMessage">Invalid Login Credentials</span>)
 *    - Follows redirect to /modules.aspx and verifies authenticated session elements (lblHTNo / imgStudUser)
 * 4. Navigates to student profile:
 *    - Submits ctl00$Stud_cpModules$imgbtnInfo from modules.aspx to reach /STUDENTLOGIN/Frm_StudentProfile.aspx
 *    - Parses official student details: Full Name, Branch, Course, Semester, Batch, College Email, College Name
 * 5. Security Guarantee:
 *    - Credentials, WebForms tokens, and portal session cookies are held ONLY in short-lived memory during the call
 *    - NEVER persisted to D1, Firestore, SharedPreferences, logs, or analytics.
 */
export class LiveBVCClient implements IBVCClient {
  public readonly clientType = 'live' as const;

  private static readonly PORTAL_BASE_URL = 'https://www.bvcecautonomous.com';
  private static readonly LOGIN_URL = 'https://www.bvcecautonomous.com/SBLogin.aspx';
  private static readonly MODULES_URL = 'https://www.bvcecautonomous.com/modules.aspx';

  public get isAuthorized(): boolean {
    return true;
  }

  public async syncStudentData(params: {
    firebaseUid: string;
    rollNumber: string;
    password?: string;
  }): Promise<BVCSyncResult> {
    const normalizedRoll = BVCNormalizer.normalizeRollNumber(params.rollNumber);
    if (!BVCNormalizer.isValidRollNumber(normalizedRoll)) {
      throw new Error(`Invalid BVC roll number format: '${params.rollNumber}'. Expected pattern e.g. 25221A0568.`);
    }

    // Portal password rule: uppercase roll number is both username and password
    const portalPassword = params.password
      ? params.password.trim().toUpperCase()
      : normalizedRoll;

    const now = new Date().toISOString();

    try {
      // -----------------------------------------------------------------------
      // Step 1: GET SBLogin.aspx & extract WebForms tokens
      // -----------------------------------------------------------------------
      const getRes = await fetch(LiveBVCClient.LOGIN_URL, {
        method: 'GET',
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        },
      });

      if (!getRes.ok) {
        return this.buildFailureResult(
          params.firebaseUid,
          normalizedRoll,
          `Official BVC student portal responded with HTTP ${getRes.status}. The college server may be temporarily down.`
        );
      }

      const getHtml = await getRes.text();
      const vs = this.extractFormField(getHtml, '__VIEWSTATE');
      const vsg = this.extractFormField(getHtml, '__VIEWSTATEGENERATOR');
      const ev = this.extractFormField(getHtml, '__EVENTVALIDATION');

      // Capture initial session cookie
      let sessionCookie = this.extractCookie(getRes.headers.get('set-cookie') || '');

      // -----------------------------------------------------------------------
      // Step 2: POST credentials to SBLogin.aspx
      // -----------------------------------------------------------------------
      const postParams = new URLSearchParams();
      postParams.set('__EVENTTARGET', '');
      postParams.set('__EVENTARGUMENT', '');
      postParams.set('__VIEWSTATE', vs);
      postParams.set('__VIEWSTATEGENERATOR', vsg);
      postParams.set('__SCROLLPOSITIONX', '0');
      postParams.set('__SCROLLPOSITIONY', '0');
      postParams.set('__EVENTVALIDATION', ev);
      postParams.set('txtUserName', normalizedRoll);
      postParams.set('txtPassword', portalPassword);
      postParams.set('btnSubmit', 'Login');

      const postHeaders: Record<string, string> = {
        'Content-Type': 'application/x-www-form-urlencoded',
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Referer': LiveBVCClient.LOGIN_URL,
      };
      if (sessionCookie) {
        postHeaders['Cookie'] = sessionCookie;
      }

      const postRes = await fetch(LiveBVCClient.LOGIN_URL, {
        method: 'POST',
        headers: postHeaders,
        body: postParams.toString(),
        redirect: 'manual',
      });

      // Update session cookie if refreshed
      const postCookieHeader = postRes.headers.get('set-cookie');
      if (postCookieHeader) {
        sessionCookie = this.extractCookie(postCookieHeader) || sessionCookie;
      }

      const postHtml = await postRes.text();

      // -----------------------------------------------------------------------
      // Step 3: Check for invalid credentials in portal response
      // -----------------------------------------------------------------------
      const errorBanner = this.cleanSpanText(postHtml, 'lblMessage');
      if (errorBanner && errorBanner.toLowerCase().includes('invalid')) {
        return this.buildFailureResult(
          params.firebaseUid,
          normalizedRoll,
          'Invalid BVC student portal credentials. Please check your roll number.'
        );
      }

      // -----------------------------------------------------------------------
      // Step 4: Follow to /modules.aspx and verify authenticated session
      // -----------------------------------------------------------------------
      let redirectLocation = postRes.headers.get('location') || '/modules.aspx';
      if (!redirectLocation.startsWith('http')) {
        redirectLocation = `${LiveBVCClient.PORTAL_BASE_URL}/${redirectLocation.replace(/^\//, '')}`;
      }

      const modRes = await fetch(redirectLocation, {
        method: 'GET',
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Referer': LiveBVCClient.LOGIN_URL,
          'Cookie': sessionCookie,
        },
      });

      if (!modRes.ok) {
        return this.buildFailureResult(
          params.firebaseUid,
          normalizedRoll,
          'Failed to establish authenticated session with the official BVC student portal.'
        );
      }

      const modHtml = await modRes.text();
      const authenticatedHTNo = this.cleanSpanText(modHtml, 'lblHTNo');

      // Strict session validation: verify portal HTML contains the student roll number
      if (!authenticatedHTNo || authenticatedHTNo.toUpperCase() !== normalizedRoll) {
        // Double-check if profile picture or user icon is present
        if (!modHtml.includes('ctl00$imgStudUser') && !modHtml.includes('Stud_cpModules')) {
          return this.buildFailureResult(
            params.firebaseUid,
            normalizedRoll,
            'Official BVC portal session could not be verified. Please check your credentials.'
          );
        }
      }

      // -----------------------------------------------------------------------
      // Step 5: Extract official profile from /STUDENTLOGIN/Frm_StudentProfile.aspx
      // -----------------------------------------------------------------------
      const mVs = this.extractFormField(modHtml, '__VIEWSTATE');
      const mVsg = this.extractFormField(modHtml, '__VIEWSTATEGENERATOR');
      const mEv = this.extractFormField(modHtml, '__EVENTVALIDATION');

      const infoParams = new URLSearchParams();
      infoParams.set('ScriptManager1_HiddenField', '');
      infoParams.set('__EVENTTARGET', '');
      infoParams.set('__EVENTARGUMENT', '');
      infoParams.set('__VIEWSTATE', mVs);
      infoParams.set('__VIEWSTATEGENERATOR', mVsg);
      infoParams.set('__SCROLLPOSITIONX', '0');
      infoParams.set('__SCROLLPOSITIONY', '0');
      infoParams.set('__EVENTVALIDATION', mEv);
      infoParams.set('ctl00$Stud_cpModules$imgbtnInfo.x', '30');
      infoParams.set('ctl00$Stud_cpModules$imgbtnInfo.y', '30');

      const infoRes = await fetch(LiveBVCClient.MODULES_URL, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Referer': LiveBVCClient.MODULES_URL,
          'Cookie': sessionCookie,
        },
        body: infoParams.toString(),
        redirect: 'follow',
      });

      const profileHtml = await infoRes.text();

      // -----------------------------------------------------------------------
      // Step 6: Parse official student information
      // -----------------------------------------------------------------------
      const rawName = this.cleanSpanText(profileHtml, 'cpBody_lblname');
      const rawBranch = this.cleanSpanText(profileHtml, 'cpBody_lblbranch');
      const rawCourse = this.cleanSpanText(profileHtml, 'cpBody_lblcourse');
      const rawSem = this.cleanSpanText(profileHtml, 'cpBody_lblsem');
      const rawBatch = this.cleanSpanText(profileHtml, 'cpBody_lblbatch');
      const rawEmail = this.cleanSpanText(profileHtml, 'cpBody_lblstdemail');

      const normalizedBranch = BVCNormalizer.normalizeBranch(rawBranch);
      const parsedAcademic = this.parseAcademicStatus(rawSem, rawBatch);

      const profile: BVCStudentProfile = {
        firebase_uid: params.firebaseUid,
        roll_number: normalizedRoll,
        name: rawName,
        branch: normalizedBranch || rawBranch,
        course: rawCourse || 'B.Tech',
        year: parsedAcademic.year,
        semester: parsedAcademic.semester,
        section: null, // Official portal does not expose section in student profile
        regulation: null,
        academic_batch: rawBatch,
        college_email: rawEmail || `${normalizedRoll.toLowerCase()}@bvcgroup.in`,
        connected: true,
        last_synced_at: now,
        data_source: 'BVC_PORTAL',
        created_at: now,
        updated_at: now,
      };

      // -----------------------------------------------------------------------
      // Step 7: Memory cleanup guarantee - zero persistence of credentials
      // -----------------------------------------------------------------------
      // All local variables (portalPassword, sessionCookie, postParams) fall out of scope here.

      return {
        success: true,
        message: `Successfully connected official BVC profile for ${normalizedRoll}.`,
        profile,
        subjects: [],
        attendance: [],
        results: [],
        timetable: [],
        fees: [],
      };
    } catch (err: any) {
      return this.buildFailureResult(
        params.firebaseUid,
        normalizedRoll,
        `Error connecting to official BVC portal: ${err?.message || 'Network timeout or unreachable host'}`
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Internal Helpers
  // ---------------------------------------------------------------------------

  private extractFormField(html: string, name: string): string {
    const regex = new RegExp(`name="${name}"[^>]*value="([^"]*)"`, 'i');
    const match = html.match(regex);
    return match ? match[1] : '';
  }

  private extractCookie(setCookieHeader: string): string {
    if (!setCookieHeader) return '';
    const match = setCookieHeader.match(/(ASP\.NET_SessionId=[^;]+)/i);
    return match ? match[1] : setCookieHeader.split(';')[0].trim();
  }

  private cleanSpanText(html: string, id: string): string | null {
    const regex = new RegExp(`id="${id}"[^>]*>(?:[:\\s]*)([^<]+)<\\/span>`, 'i');
    const match = html.match(regex);
    if (!match || !match[1]) return null;
    const val = match[1].replace(/^[:\s\-]+/, '').trim();
    return val.length > 0 ? val : null;
  }

  private parseAcademicStatus(rawSem: string | null, rawBatch: string | null): { year: number | null; semester: number | null } {
    let year: number | null = null;
    let semester: number | null = null;

    if (rawSem) {
      const match = rawSem.match(/([IVX]+)\s*-\s*([IVX]+)/i);
      if (match) {
        const romanToNum: Record<string, number> = { 'I': 1, 'II': 2, 'III': 3, 'IV': 4 };
        const y = romanToNum[match[1].toUpperCase()];
        const s = romanToNum[match[2].toUpperCase()];
        if (y) year = y;
        if (y && s) {
          semester = (y - 1) * 2 + s;
        }
      } else {
        semester = BVCNormalizer.normalizeSemester(rawSem);
        year = BVCNormalizer.normalizeYear(rawSem);
      }
    }

    if (!year && rawBatch) {
      const match = rawBatch.match(/(\d{4})/);
      if (match) {
        const startYear = parseInt(match[1], 10);
        const currentYear = new Date().getFullYear();
        const diff = currentYear - startYear + 1;
        if (diff >= 1 && diff <= 4) year = diff;
      }
    }

    return { year, semester };
  }

  private buildFailureResult(firebaseUid: string, rollNumber: string, message: string): BVCSyncResult {
    const now = new Date().toISOString();
    return {
      success: false,
      message,
      profile: {
        firebase_uid: firebaseUid,
        roll_number: rollNumber,
        name: null,
        branch: null,
        course: 'B.Tech',
        year: null,
        semester: null,
        section: null,
        regulation: null,
        academic_batch: null,
        college_email: `${rollNumber.toLowerCase()}@bvcgroup.in`,
        connected: false,
        last_synced_at: null,
        data_source: 'BVC_PORTAL',
        created_at: now,
        updated_at: now,
      },
      subjects: [],
      attendance: [],
      results: [],
      timetable: [],
      fees: [],
    };
  }
}
