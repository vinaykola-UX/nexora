/**
 * ============================================================================
 * Nexora Phase N — Notification & Personal Matching Types
 * ============================================================================
 */

export type NotificationType =
  | 'RESULT'
  | 'EVENT'
  | 'ATTENDANCE'
  | 'TIMETABLE'
  | 'EXAM'
  | 'FEE'
  | 'CIRCULAR'
  | 'GENERAL'
  | 'SYSTEM';

export interface StudentDevice {
  id?: number;
  firebase_uid: string;
  fcm_token: string;
  platform: 'android' | 'ios' | 'web' | string;
  device_name?: string | null;
  app_version?: string | null;
  is_active: number; // 1 = active, 0 = inactive
  created_at?: string;
  updated_at?: string;
  last_seen_at?: string;
}

export interface NotificationRecord {
  id?: number;
  firebase_uid: string;
  type: NotificationType;
  title: string;
  body: string;
  data_json?: string | null;
  reference_id?: string | null;
  is_read: number; // 0 = unread, 1 = read
  created_at?: string;
  read_at?: string | null;
}

export type NotificationScope =
  | 'ALL'
  | 'BRANCH'
  | 'YEAR'
  | 'SEMESTER'
  | 'SECTION'
  | 'BRANCH_YEAR'
  | 'BRANCH_SEMESTER'
  | 'CUSTOM_STUDENTS'
  | 'RESULT_MATCH';

export interface NotificationTarget {
  scope: NotificationScope;
  branch?: string | null;
  year?: number | null;
  semester?: number | null;
  section?: string | null;
  custom_roll_numbers?: string[];
  custom_firebase_uids?: string[];
}

export interface RawResultInputRecord {
  roll_number: string;
  semester: number | string;
  subject_code?: string;
  subject_name?: string;
  grade?: string;
  credits?: number | string;
  grade_points?: number | string;
  status?: string;
  sgpa?: number | string;
  cgpa?: number | string;
  exam_month_year?: string;
}

export interface ResultIngestReport {
  total_processed: number;
  valid_records: number;
  matched_students: number;
  unmatched_roll_numbers: string[];
  notifications_queued: number;
  duplicates_skipped: number;
  matched_profiles: Array<{
    roll_number: string;
    firebase_uid: string;
    name?: string | null;
    branch?: string | null;
  }>;
  created_at: string;
}

export interface NotificationStats {
  total_notifications: number;
  sent_today: number;
  active_devices: number;
  unread_notifications: number;
  failed_deliveries: number;
}
