/**
 * ============================================================================
 * BVC Private Student Profile — Core Type Definitions
 * ============================================================================
 * Defines types for the private student academic profile, subjects,
 * attendance, marks, and synchronization status.
 *
 * PRIVACY GUARANTEE:
 * These structures are strictly isolated to authenticated student storage.
 * They are NEVER ingested into public Vectorize, D1 study chunks, or GraphRAG.
 * ============================================================================
 */

export interface BVCStudentProfile {
  firebase_uid: string;
  roll_number: string;
  name: string | null;
  branch: string | null;
  course: string | null;
  year: number | null;
  semester: number | null;
  section: string | null;
  regulation: string | null;
  academic_batch: string | null;
  college_email: string | null;
  connected: boolean;
  last_synced_at: string | null;
  data_source: 'BVC_PORTAL' | 'MOCK_TEST' | 'VERIFIED_DOC';
  created_at?: string;
  updated_at?: string;
}

export interface BVCSubject {
  id?: number;
  firebase_uid: string;
  subject_code: string;
  subject_name: string;
  credits: number | null;
  faculty_name: string | null;
  semester: number | null;
  academic_year?: string | null;
}

export interface BVCAttendanceRecord {
  id?: number;
  firebase_uid: string;
  subject_code: string;
  subject_name: string;
  classes_conducted: number;
  classes_attended: number;
  percentage: number;
  status: string | null; // e.g. 'Satisfactory', 'Shortage Warning', 'Condonation'
  updated_at?: string;
}

export interface BVCResultRecord {
  id?: number;
  firebase_uid: string;
  semester: number;
  subject_code: string;
  subject_name: string;
  internal_marks: number | null;
  external_marks: number | null;
  total_marks: number | null;
  grade: string | null;
  grade_points: number | null;
  credits: number | null;
  result_status: string | null; // 'PASS', 'FAIL', etc.
  sgpa?: number | null;
  cgpa?: number | null;
}

export interface BVCTimetablePeriod {
  id?: number;
  firebase_uid: string;
  day_of_week: string; // 'Monday', 'Tuesday', etc.
  period_number: number;
  time_slot: string | null; // '09:30 AM - 10:20 AM'
  subject_code: string;
  subject_name: string;
  faculty_name: string | null;
  room_number: string | null;
}

export interface BVCFeeRecord {
  id?: number;
  firebase_uid: string;
  fee_type: string; // 'Tuition', 'Examination', etc.
  amount_due: number;
  amount_paid: number;
  due_date: string | null;
  payment_status: 'PAID' | 'PENDING' | 'OVERDUE';
}

export interface BVCSyncResult {
  success: boolean;
  message: string;
  requiresOfficialApproval?: boolean;
  profile: BVCStudentProfile;
  subjects: BVCSubject[];
  attendance: BVCAttendanceRecord[];
  results: BVCResultRecord[];
  timetable: BVCTimetablePeriod[];
  fees: BVCFeeRecord[];
  overallAttendancePercentage?: number;
  currentCgpa?: number;
}
