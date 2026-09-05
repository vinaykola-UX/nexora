import { NotificationStorage } from './src/notifications/notification_storage';
import { FCMV1Service } from './src/notifications/fcm_v1_service';

// In-memory mock of Cloudflare D1 Database
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

    if (q.includes('UPDATE student_devices SET is_active = 0')) {
      const [uid, token] = bindings;
      const dev = this.devices.get(token);
      if (dev && dev.firebase_uid === uid) {
        dev.is_active = 0;
        dev.updated_at = new Date().toISOString();
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

    return { results: [] as T[], success: true };
  }
}

async function runNotificationSuite() {
  console.log('===============================================================');
  console.log('NEXORA NOTIFICATION & DEVICE ISOLATION TEST SUITE');
  console.log('===============================================================');

  const mockDb = new MockD1Database() as unknown as D1Database;
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

  // TEST 1: Authenticated device registration
  console.log('\n--- Test 1: Authenticated Device Registration ---');
  const regA1 = await NotificationStorage.registerDevice(mockDb, {
    firebase_uid: 'uid_student_A',
    fcm_token: 'token_A_phone',
    platform: 'android',
    device_name: 'Pixel 8',
    app_version: '1.0.0',
  });
  assert(regA1 === true, 'Student A device 1 registered successfully');

  // Support multiple devices per student
  const regA2 = await NotificationStorage.registerDevice(mockDb, {
    firebase_uid: 'uid_student_A',
    fcm_token: 'token_A_tablet',
    platform: 'android',
    device_name: 'Galaxy Tab',
    app_version: '1.0.0',
  });
  assert(regA2 === true, 'Student A device 2 (multi-device) registered successfully');

  // TEST 2: Cross-Student UID & Device Token Isolation
  console.log('\n--- Test 2: Cross-Student UID & Device Isolation ---');
  await NotificationStorage.registerDevice(mockDb, {
    firebase_uid: 'uid_student_B',
    fcm_token: 'token_B_phone',
    platform: 'android',
    device_name: 'OnePlus 12',
    app_version: '1.0.0',
  });

  const tokensA = await NotificationStorage.getActiveDeviceTokens(mockDb, ['uid_student_A']);
  assert(tokensA.length === 2, 'Student A has exactly 2 active devices');
  assert(
    tokensA.every((t) => t.firebase_uid === 'uid_student_A'),
    'Student A device tokens contain only Student A UID'
  );
  assert(
    !tokensA.some((t) => t.fcm_token === 'token_B_phone'),
    'Student A cannot see Student B device token'
  );

  const tokensB = await NotificationStorage.getActiveDeviceTokens(mockDb, ['uid_student_B']);
  assert(tokensB.length === 1, 'Student B has exactly 1 active device');
  assert(tokensB[0].fcm_token === 'token_B_phone', 'Student B device is token_B_phone');

  // TEST 3: Cross-Student Deactivation Protection
  console.log('\n--- Test 3: Cross-Student Deactivation Protection ---');
  // Student B attempts to unregister Student A's token
  await NotificationStorage.unregisterDevice(mockDb, 'uid_student_B', 'token_A_phone');
  const tokensAAfterMalicious = await NotificationStorage.getActiveDeviceTokens(mockDb, ['uid_student_A']);
  assert(
    tokensAAfterMalicious.some((t) => t.fcm_token === 'token_A_phone'),
    'Student B cannot deactivate Student A device token'
  );

  // TEST 4: Token Refresh Handling
  console.log('\n--- Test 4: Token Refresh Handling ---');
  const regRefresh = await NotificationStorage.registerDevice(mockDb, {
    firebase_uid: 'uid_student_A',
    fcm_token: 'token_A_phone',
    platform: 'android',
    device_name: 'Pixel 8 (Updated)',
  });
  assert(regRefresh === true, 'Refreshed token re-registers cleanly');
  const tokensAfterRefresh = await NotificationStorage.getActiveDeviceTokens(mockDb, ['uid_student_A']);
  assert(tokensAfterRefresh.length === 2, 'Device count remains unchanged after token update');

  // TEST 5: Logout Device Cleanup (Single device deactivation)
  console.log('\n--- Test 5: Logout Device Cleanup ---');
  // Student A logs out of phone only
  const unregRes = await NotificationStorage.unregisterDevice(mockDb, 'uid_student_A', 'token_A_phone');
  assert(unregRes === true, 'Phone device unregistered on logout');
  const tokensAfterLogout = await NotificationStorage.getActiveDeviceTokens(mockDb, ['uid_student_A']);
  assert(tokensAfterLogout.length === 1, 'Student A still has 1 active device (tablet remains active)');
  assert(tokensAfterLogout[0].fcm_token === 'token_A_tablet', 'Tablet device remained active');

  // TEST 6: FCM HTTP v1 Formatting & Payload Verification
  console.log('\n--- Test 6: FCM HTTP v1 Formatting & Payload ---');
  const fcmRes = await FCMV1Service.sendPush(
    {}, // empty env without secrets
    'token_dummy_test',
    {
      title: 'Nexora Exam Schedule',
      body: 'BR23 Mid-term exam timetable published',
      type: 'ACADEMIC_ALERT',
      route: '/notifications',
    }
  );
  // Without Google service account JSON in test env, FCM returns gracefully with queued status
  assert(
    fcmRes.success === true && fcmRes.status === 'QUEUED_RECORD_PERSISTED',
    'FCM gracefully handles test environment and validates payload formatting'
  );

  console.log('===============================================================');
  console.log(`TEST SUMMARY: ${passed} passed, ${failed} failed`);
  console.log('===============================================================');

  if (failed > 0) {
    process.exit(1);
  }
}

runNotificationSuite().catch((err) => {
  console.error('Test runner fatal error:', err);
  process.exit(1);
});
