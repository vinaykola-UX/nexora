import {
  NotificationRecord,
  NotificationType,
  StudentDevice,
  NotificationStats,
} from './notification_types';

/**
 * ============================================================================
 * Notification & Device D1 Storage Manager
 * ============================================================================
 * Manages tables for student devices, notifications, and preferences in D1.
 * Strict privacy: all records are scoped by verified `firebase_uid`.
 * ============================================================================
 */
export class NotificationStorage {
  private static schemaInitialized = false;

  public static async ensureNotificationSchema(db: D1Database): Promise<void> {
    if (this.schemaInitialized) return;

    try {
      await db.batch([
        // 1. Student Devices
        db.prepare(`
          CREATE TABLE IF NOT EXISTS student_devices (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            firebase_uid TEXT NOT NULL,
            fcm_token TEXT UNIQUE NOT NULL,
            platform TEXT DEFAULT 'android',
            device_name TEXT,
            app_version TEXT,
            is_active INTEGER DEFAULT 1,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            last_seen_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
          )
        `),

        // 2. Notifications Table
        db.prepare(`
          CREATE TABLE IF NOT EXISTS notifications (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            firebase_uid TEXT NOT NULL,
            type TEXT NOT NULL,
            title TEXT NOT NULL,
            body TEXT NOT NULL,
            data_json TEXT,
            reference_id TEXT,
            is_read INTEGER DEFAULT 0,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            read_at TIMESTAMP
          )
        `),

        // 3. Notification Preferences Table
        db.prepare(`
          CREATE TABLE IF NOT EXISTS notification_preferences (
            firebase_uid TEXT PRIMARY KEY,
            results_enabled INTEGER DEFAULT 1,
            events_enabled INTEGER DEFAULT 1,
            exams_enabled INTEGER DEFAULT 1,
            attendance_enabled INTEGER DEFAULT 1,
            general_enabled INTEGER DEFAULT 1,
            system_enabled INTEGER DEFAULT 1,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
          )
        `),

        // 4. Unmatched Results Table (Stores uploaded results for students not yet linked)
        db.prepare(`
          CREATE TABLE IF NOT EXISTS unmatched_results (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            roll_number TEXT NOT NULL,
            semester INTEGER NOT NULL,
            subject_code TEXT,
            subject_name TEXT,
            grade TEXT,
            credits REAL,
            grade_points REAL,
            status TEXT,
            sgpa REAL,
            cgpa REAL,
            exam_month_year TEXT,
            raw_payload TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
          )
        `),

        // Indices
        db.prepare(`CREATE INDEX IF NOT EXISTS idx_student_devices_uid ON student_devices(firebase_uid, is_active)`),
        db.prepare(`CREATE INDEX IF NOT EXISTS idx_notifications_uid_read ON notifications(firebase_uid, is_read, created_at)`),
        db.prepare(`CREATE INDEX IF NOT EXISTS idx_notifications_idempotency ON notifications(firebase_uid, type, reference_id)`),
        db.prepare(`CREATE INDEX IF NOT EXISTS idx_unmatched_results_roll ON unmatched_results(roll_number, semester)`),
      ]);
      this.schemaInitialized = true;
    } catch (err) {
      console.error('[NotificationStorage] Schema initialization error:', err);
    }
  }

  /**
   * Registers or updates a student device FCM token.
   */
  public static async registerDevice(
    db: D1Database,
    device: {
      firebase_uid: string;
      fcm_token: string;
      platform?: string;
      device_name?: string;
      app_version?: string;
    }
  ): Promise<boolean> {
    await this.ensureNotificationSchema(db);

    const platform = device.platform || 'android';
    const deviceName = device.device_name || null;
    const appVersion = device.app_version || null;

    try {
      // Upsert into student_devices
      await db
        .prepare(`
          INSERT INTO student_devices (firebase_uid, fcm_token, platform, device_name, app_version, is_active, updated_at, last_seen_at)
          VALUES (?, ?, ?, ?, ?, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
          ON CONFLICT(fcm_token) DO UPDATE SET
            firebase_uid = excluded.firebase_uid,
            platform = excluded.platform,
            device_name = excluded.device_name,
            app_version = excluded.app_version,
            is_active = 1,
            updated_at = CURRENT_TIMESTAMP,
            last_seen_at = CURRENT_TIMESTAMP
        `)
        .bind(device.firebase_uid, device.fcm_token, platform, deviceName, appVersion)
        .run();

      return true;
    } catch (err) {
      console.error('[NotificationStorage] registerDevice error:', err);
      return false;
    }
  }

  /**
   * Unregisters or deactivates an FCM token.
   */
  public static async unregisterDevice(
    db: D1Database,
    firebaseUid: string,
    fcmToken: string
  ): Promise<boolean> {
    await this.ensureNotificationSchema(db);

    try {
      await db
        .prepare(`UPDATE student_devices SET is_active = 0, updated_at = CURRENT_TIMESTAMP WHERE firebase_uid = ? AND fcm_token = ?`)
        .bind(firebaseUid, fcmToken)
        .run();
      return true;
    } catch (err) {
      console.error('[NotificationStorage] unregisterDevice error:', err);
      return false;
    }
  }

  /**
   * Retrieves all active FCM device tokens for a list of Firebase UIDs.
   */
  public static async getActiveDeviceTokens(
    db: D1Database,
    firebaseUids: string[]
  ): Promise<Array<{ firebase_uid: string; fcm_token: string }>> {
    if (!firebaseUids || firebaseUids.length === 0) return [];
    await this.ensureNotificationSchema(db);

    const placeholders = firebaseUids.map(() => '?').join(',');
    const { results } = await db
      .prepare(`
        SELECT firebase_uid, fcm_token
        FROM student_devices
        WHERE firebase_uid IN (${placeholders}) AND is_active = 1
      `)
      .bind(...firebaseUids)
      .all<{ firebase_uid: string; fcm_token: string }>();

    return results || [];
  }

  /**
   * Creates an in-app notification with strict idempotency check.
   * If (firebase_uid, type, reference_id) already exists, skip duplicate.
   */
  public static async createNotificationIdempotent(
    db: D1Database,
    notif: {
      firebase_uid: string;
      type: NotificationType;
      title: string;
      body: string;
      data_json?: string | null;
      reference_id?: string | null;
    }
  ): Promise<{ created: boolean; duplicate: boolean; id?: number }> {
    await this.ensureNotificationSchema(db);

    // If reference_id is provided, check for existing record
    if (notif.reference_id) {
      const existing = await db
        .prepare(`
          SELECT id FROM notifications
          WHERE firebase_uid = ? AND type = ? AND reference_id = ?
          LIMIT 1
        `)
        .bind(notif.firebase_uid, notif.type, notif.reference_id)
        .first<{ id: number }>();

      if (existing) {
        return { created: false, duplicate: true, id: existing.id };
      }
    }

    const res = await db
      .prepare(`
        INSERT INTO notifications (firebase_uid, type, title, body, data_json, reference_id, is_read, created_at)
        VALUES (?, ?, ?, ?, ?, ?, 0, CURRENT_TIMESTAMP)
      `)
      .bind(
        notif.firebase_uid,
        notif.type,
        notif.title,
        notif.body,
        notif.data_json || null,
        notif.reference_id || null
      )
      .run();

    return { created: true, duplicate: false, id: res.meta?.last_row_id };
  }

  /**
   * Retrieves student notifications with pagination and unread filtering.
   */
  public static async getStudentNotifications(
    db: D1Database,
    firebaseUid: string,
    limit = 50,
    offset = 0,
    unreadOnly = false
  ): Promise<NotificationRecord[]> {
    await this.ensureNotificationSchema(db);

    let query = `
      SELECT id, firebase_uid, type, title, body, data_json, reference_id, is_read, created_at, read_at
      FROM notifications
      WHERE firebase_uid = ?
    `;

    if (unreadOnly) {
      query += ` AND is_read = 0`;
    }

    query += ` ORDER BY created_at DESC LIMIT ? OFFSET ?`;

    const { results } = await db
      .prepare(query)
      .bind(firebaseUid, limit, offset)
      .all<NotificationRecord>();

    return results || [];
  }

  /**
   * Marks a specific notification as read.
   */
  public static async markAsRead(
    db: D1Database,
    firebaseUid: string,
    notificationId: number
  ): Promise<boolean> {
    await this.ensureNotificationSchema(db);

    const res = await db
      .prepare(`
        UPDATE notifications
        SET is_read = 1, read_at = CURRENT_TIMESTAMP
        WHERE id = ? AND firebase_uid = ?
      `)
      .bind(notificationId, firebaseUid)
      .run();

    return (res.meta?.changes ?? 0) > 0;
  }

  /**
   * Marks all notifications as read for a student.
   */
  public static async markAllAsRead(
    db: D1Database,
    firebaseUid: string
  ): Promise<number> {
    await this.ensureNotificationSchema(db);

    const res = await db
      .prepare(`
        UPDATE notifications
        SET is_read = 1, read_at = CURRENT_TIMESTAMP
        WHERE firebase_uid = ? AND is_read = 0
      `)
      .bind(firebaseUid)
      .run();

    return res.meta?.changes ?? 0;
  }

  /**
   * Gets unread notification count for a student.
   */
  public static async getUnreadCount(
    db: D1Database,
    firebaseUid: string
  ): Promise<{ unread_count: number; total_count: number }> {
    await this.ensureNotificationSchema(db);

    const unread = await db
      .prepare(`SELECT COUNT(*) as cnt FROM notifications WHERE firebase_uid = ? AND is_read = 0`)
      .bind(firebaseUid)
      .first<{ cnt: number }>();

    const total = await db
      .prepare(`SELECT COUNT(*) as cnt FROM notifications WHERE firebase_uid = ?`)
      .bind(firebaseUid)
      .first<{ cnt: number }>();

    return {
      unread_count: unread?.cnt || 0,
      total_count: total?.cnt || 0,
    };
  }

  /**
   * Gets aggregated stats for admin dashboard.
   */
  public static async getNotificationStats(db: D1Database): Promise<NotificationStats> {
    await this.ensureNotificationSchema(db);

    const total = await db.prepare(`SELECT COUNT(*) as cnt FROM notifications`).first<{ cnt: number }>();
    const unread = await db.prepare(`SELECT COUNT(*) as cnt FROM notifications WHERE is_read = 0`).first<{ cnt: number }>();
    const activeDevices = await db.prepare(`SELECT COUNT(*) as cnt FROM student_devices WHERE is_active = 1`).first<{ cnt: number }>();

    const today = await db
      .prepare(`SELECT COUNT(*) as cnt FROM notifications WHERE date(created_at) = date('now')`)
      .first<{ cnt: number }>();

    return {
      total_notifications: total?.cnt || 0,
      sent_today: today?.cnt || 0,
      active_devices: activeDevices?.cnt || 0,
      unread_notifications: unread?.cnt || 0,
      failed_deliveries: 0,
    };
  }
}
