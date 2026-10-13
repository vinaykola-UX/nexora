import { NotificationStorage } from './src/notifications/notification_storage';
import { TargetingEngine } from './src/notifications/targeting_engine';
import { FCMV1Service } from './src/notifications/fcm_v1_service';
import { AIController } from './src/ai/ai_controller';

// Comprehensive In-Memory Mock of Cloudflare D1 Database
class MockD1PreparedStatement {
  private query: string;
  private bindings: any[] = [];
  private db: MockD1Database;

  constructor(query: string, db: MockD1Database) {
    this.query = query;
    this.db = db;
  }

  bind(...args: any[]) {
    this.bindings = args;
    return this;
  }

  async run(): Promise<{ success: boolean; meta: any }> {
    return this.db.executeRun(this.query, this.bindings);
  }

  async all<T = any>(): Promise<{ results: T[]; success: boolean }> {
    return this.db.executeAll<T>(this.query, this.bindings);
  }

  async first<T = any>(column?: string): Promise<T | null> {
    const { results } = await this.all<T>();
    if (results.length === 0) return null;
    return column ? (results[0] as any)[column] : results[0];
  }
}

class MockD1Database {
  public devices: Map<string, any> = new Map(); // fcm_token -> record
  public notifications: any[] = [];
  public studentProfiles: any[] = [];

  prepare(query: string) {
    return new MockD1PreparedStatement(query, this);
  }

  async batch(statements: MockD1PreparedStatement[]) {
    for (const stmt of statements) {
      await stmt.run();
    }
    return [];
  }

  executeRun(query: string, bindings: any[]) {
    const q = query.replace(/\s+/g, ' ').trim();

    if (q.includes('INSERT INTO student_devices')) {
      const [uid, token, platform, deviceName, appVersion] = bindings;
      const existing = this.devices.get(token);
      this.devices.set(token, {
        id: existing?.id || this.devices.size + 1,
        firebase_uid: uid,
        fcm_token: token,
        platform: platform || 'android',
        device_name: deviceName || null,
        app_version: appVersion || null,
        is_active: 1,
        updated_at: new Date().toISOString(),
        last_seen_at: new Date().toISOString(),
      });
      return { success: true, meta: { changes: 1 } };
    }

    if (q.includes('INSERT INTO notifications')) {
      const [uid, type, title, body, dataJson, refId] = bindings;
      const newRecord = {
        id: this.notifications.length + 1,
        firebase_uid: uid,
        type,
        title,
        body,
        data_json: dataJson || null,
        reference_id: refId || null,
        is_read: 0,
        created_at: new Date().toISOString(),
        read_at: null,
      };
      this.notifications.push(newRecord);
      return { success: true, meta: { changes: 1, last_row_id: newRecord.id } };
    }

    if (q.includes('UPDATE notifications SET is_read = 1')) {
      const [id, uid] = bindings;
      const notif = this.notifications.find((n) => n.id === id && n.firebase_uid === uid);
      if (notif) {
        notif.is_read = 1;
        notif.read_at = new Date().toISOString();
        return { success: true, meta: { changes: 1 } };
      }
      return { success: true, meta: { changes: 0 } };
    }

    return { success: true, meta: {} };
  }

  executeAll<T>(query: string, bindings: any[]) {
    const q = query.replace(/\s+/g, ' ').trim();

    if (q.includes('SELECT firebase_uid, fcm_token FROM student_devices')) {
      const uids = new Set(bindings);
      const matched: any[] = [];
      for (const dev of this.devices.values()) {
        if (dev.is_active === 1 && uids.has(dev.firebase_uid)) {
          matched.push({
            firebase_uid: dev.firebase_uid,
            fcm_token: dev.fcm_token,
          });
        }
      }
      return { results: matched as T[], success: true };
    }

    if (q.includes('SELECT DISTINCT firebase_uid FROM (')) {
      // UNION between bvc_student_profiles and student_devices
      const uids = new Set<string>();
      for (const p of this.studentProfiles) {
        if (p.connected === 1) uids.add(p.firebase_uid);
      }
      for (const d of this.devices.values()) {
        if (d.is_active === 1) uids.add(d.firebase_uid);
      }
      const res = Array.from(uids).map((uid) => ({ firebase_uid: uid }));
      return { results: res as T[], success: true };
    }

    if (q.includes('SELECT firebase_uid FROM bvc_student_profiles WHERE UPPER(branch) = UPPER(?)')) {
      const [branch] = bindings;
      const matched = this.studentProfiles
        .filter((p) => p.branch && p.branch.toUpperCase() === String(branch).toUpperCase() && p.connected === 1)
        .map((p) => ({ firebase_uid: p.firebase_uid }));
      return { results: matched as T[], success: true };
    }

    if (q.includes('SELECT title, body, created_at, type FROM notifications WHERE type = ?')) {
      const [type] = bindings;
      const matched = this.notifications
        .filter((n) => n.type === type)
        .sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime());
      return { results: matched as T[], success: true };
    }

    if (q.includes('SELECT id FROM notifications WHERE firebase_uid = ? AND type = ? AND reference_id = ?')) {
      const [uid, type, refId] = bindings;
      const found = this.notifications.filter(
        (n) => n.firebase_uid === uid && n.type === type && n.reference_id === refId
      );
      return { results: found as T[], success: true };
    }

    if (q.includes('SELECT id, firebase_uid, type, title, body, data_json, reference_id, is_read, created_at')) {
      const [uid] = bindings;
      const list = this.notifications.filter((n) => n.firebase_uid === uid);
      return { results: list as T[], success: true };
    }

    return { results: [] as T[], success: true };
  }
}

async function runAcademicNotificationTests() {
  console.log('===============================================================');
  console.log('NEXORA ACADEMIC & HOLIDAY NOTIFICATION TEST SUITE');
  console.log('===============================================================');

  const mockDb = new MockD1Database();
  const db = mockDb as unknown as D1Database;
  let passed = 0;
  let failed = 0;

  function assert(condition: boolean, testName: string, detail?: string) {
    if (condition) {
      console.log(`[PASS] ${testName}`);
      passed++;
    } else {
      console.error(`[FAIL] ${testName}${detail ? ` - ${detail}` : ''}`);
      failed++;
    }
  }

  // 1. SETUP: Register two student devices
  console.log('\n--- Test 1: Device Registration & Multi-Student Tracking ---');
  await NotificationStorage.registerDevice(db, {
    firebase_uid: 'uid_student_1',
    fcm_token: 'token_student_1_android',
    platform: 'android',
    device_name: 'Samsung Galaxy S24',
    app_version: '1.2.0',
  });

  await NotificationStorage.registerDevice(db, {
    firebase_uid: 'uid_student_2',
    fcm_token: 'token_student_2_pixel',
    platform: 'android',
    device_name: 'Google Pixel 8',
    app_version: '1.2.0',
  });

  // Also add profile for student 1 in CSE
  mockDb.studentProfiles.push({
    firebase_uid: 'uid_student_1',
    roll_number: '25221A0568',
    branch: 'CSE',
    year: 2,
    semester: 2,
    connected: 1,
  });

  assert(mockDb.devices.size === 2, 'Two student devices registered');

  // 2. TEST: TargetingEngine resolves all active devices for ALL scope
  console.log('\n--- Test 2: Targeting Engine ALL Scope Union Resolution ---');
  const allTargets = await TargetingEngine.resolveTargetUids(db, { scope: 'ALL' });
  assert(
    allTargets.includes('uid_student_1') && allTargets.includes('uid_student_2'),
    'TargetingEngine resolves ALL students including those without linked profiles'
  );

  // 3. TEST: Holiday Announcement (Tomorrow Holiday)
  console.log('\n--- Test 3: Tomorrow Holiday Notification Creation & Dispatch ---');
  const holidayTitle = 'College Holiday Announced — Tomorrow';
  const holidayDate = 'Tomorrow (14-Oct-2026)';
  const holidayReason = 'Annual Vijayadashami / Ayudha Puja Festivities';
  const holidayBody = `Tomorrow (${holidayDate}) has been declared an official college holiday on account of ${holidayReason}. Regular classes resume on 15-Oct-2026.`;
  const holidayRef = `HOLIDAY:2026-10-14`;

  let holidayQueued = 0;
  for (const uid of allTargets) {
    const res = await NotificationStorage.createNotificationIdempotent(db, {
      firebase_uid: uid,
      type: 'HOLIDAY',
      title: holidayTitle,
      body: holidayBody,
      data_json: JSON.stringify({
        type: 'HOLIDAY',
        holiday_date: holidayDate,
        reason: holidayReason,
        route: '/notifications',
      }),
      reference_id: `${holidayRef}:${uid}`,
    });
    if (res.created) holidayQueued++;
  }

  assert(holidayQueued === 2, 'Holiday notifications queued for all student devices');

  // Verify notification records in D1
  const student1Notifs = await NotificationStorage.getStudentNotifications(db, 'uid_student_1');
  assert(student1Notifs.length >= 1, 'Student 1 has notification in inbox');
  assert(student1Notifs[0].type === 'HOLIDAY', 'Notification type is HOLIDAY');
  assert(student1Notifs[0].title === holidayTitle, 'Notification title matches holiday alert');

  // Verify FCM Push formatting for Holiday
  const holidayPush = await FCMV1Service.sendPush(
    {},
    'token_student_1_android',
    {
      title: holidayTitle,
      body: holidayBody,
      type: 'HOLIDAY',
      route: '/notifications',
      referenceId: holidayRef,
    }
  );
  assert(holidayPush.success === true, 'FCM push dispatched for Holiday alert');

  // 4. TEST: Semester Results Announcement (Deep-Link to /results)
  console.log('\n--- Test 4: Semester Results Release Notification & /results Deep-Link ---');
  const semResultTitle = 'Semester 2 Results Officially Released';
  const semResultBody = 'B.Tech Semester 2 regular & supplementary exam results are declared today. Tap to view your SGPA and grades in Nexora.';
  const semResultRef = 'RESULT_RELEASE:SEM2:2026';

  let resultQueued = 0;
  for (const uid of allTargets) {
    const res = await NotificationStorage.createNotificationIdempotent(db, {
      firebase_uid: uid,
      type: 'RESULT',
      title: semResultTitle,
      body: semResultBody,
      data_json: JSON.stringify({
        type: 'RESULT',
        semester: 2,
        route: '/results',
      }),
      reference_id: `${semResultRef}:${uid}`,
    });
    if (res.created) resultQueued++;
  }

  assert(resultQueued === 2, 'Semester result notifications queued for all student devices');

  // Verify Student 2 Result Notification
  const student2Notifs = await NotificationStorage.getStudentNotifications(db, 'uid_student_2');
  const resultItem = student2Notifs.find((n) => n.type === 'RESULT');
  assert(resultItem !== undefined, 'Student 2 received RESULT notification');
  const parsedData = JSON.parse(resultItem!.data_json!);
  assert(parsedData.route === '/results', 'Result notification routes directly to /results');

  // Verify FCM push with /results route
  const resultPush = await FCMV1Service.sendPush(
    {},
    'token_student_2_pixel',
    {
      title: semResultTitle,
      body: semResultBody,
      type: 'RESULT',
      route: '/results',
      referenceId: semResultRef,
    }
  );
  assert(resultPush.success === true, 'FCM push dispatched with /results route for device');

  // 5. TEST: AI Controller Grounding for "Is tomorrow a holiday?"
  console.log('\n--- Test 5: AI Grounding for Holiday Queries ---');
  const aiController = AIController.getInstance();
  const mockEnv: any = {
    DB: db,
    AI_MODEL: '@cf/meta/llama-3.2-3b-instruct',
  };

  const holidayAiResponse = await aiController.handleChat({
    message: 'Is tomorrow a holiday for college?',
    env: mockEnv,
    allChunks: [],
  });

  assert(
    holidayAiResponse.answer.includes('Official Holiday Notification') &&
    holidayAiResponse.answer.includes(holidayTitle),
    'Nexora AI accurately retrieves official tomorrow holiday notice and answers student query'
  );

  // 6. TEST: AI Controller Grounding for "Are sem results released?"
  console.log('\n--- Test 6: AI Grounding for Semester Result Queries ---');
  const resultAiResponse = await aiController.handleChat({
    message: 'Are semester results declared or announced?',
    env: mockEnv,
    allChunks: [],
  });

  assert(
    resultAiResponse.answer.includes('Semester Results Announcement') &&
    resultAiResponse.answer.includes(semResultTitle),
    'Nexora AI accurately answers student results question with official announcement and guides to Academic Results tab'
  );

  // 7. TEST: Idempotency Protection (Prevent duplicate notifications)
  console.log('\n--- Test 7: Idempotency Protection ---');
  const duplicateRes = await NotificationStorage.createNotificationIdempotent(db, {
    firebase_uid: 'uid_student_1',
    type: 'HOLIDAY',
    title: holidayTitle,
    body: holidayBody,
    reference_id: `${holidayRef}:uid_student_1`,
  });
  assert(duplicateRes.duplicate === true && duplicateRes.created === false, 'Duplicate holiday notification prevented');

  console.log('===============================================================');
  console.log(`TEST SUMMARY: ${passed} passed, ${failed} failed`);
  console.log('===============================================================');

  if (failed > 0) {
    process.exit(1);
  }
}

runAcademicNotificationTests().catch((err) => {
  console.error('Test runner fatal error:', err);
  process.exit(1);
});
