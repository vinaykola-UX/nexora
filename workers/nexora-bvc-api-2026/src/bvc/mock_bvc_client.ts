import { IBVCClient } from './bvc_client_interface';
import { BVCSyncResult, BVCStudentProfile, BVCSubject, BVCAttendanceRecord, BVCResultRecord, BVCTimetablePeriod, BVCFeeRecord } from './bvc_types';
import { BVCNormalizer } from './bvc_normalizer';

/**
 * Mock BVC Client Adapter
 * Provides deterministic, realistic academic records for authorized development & integration testing
 * without requiring live automated hits to the production BVC SBCMS portal.
 */
export class MockBVCClient implements IBVCClient {
  public readonly clientType = 'mock' as const;
  public readonly isAuthorized = true;

  public async syncStudentData(params: {
    firebaseUid: string;
    rollNumber: string;
    password?: string;
  }): Promise<BVCSyncResult> {
    const normalizedRoll = BVCNormalizer.normalizeRollNumber(params.rollNumber);
    const now = new Date().toISOString();

    const profile: BVCStudentProfile = {
      firebase_uid: params.firebaseUid,
      roll_number: normalizedRoll,
      name: 'K. Vinay',
      branch: 'CSE',
      course: 'B.Tech',
      year: 2,
      semester: 2,
      section: 'A',
      regulation: 'BR23',
      academic_batch: '2023-2027',
      college_email: `${normalizedRoll.toLowerCase()}@bvcgroup.in`,
      connected: true,
      last_synced_at: now,
      data_source: 'MOCK_TEST',
      created_at: now,
      updated_at: now,
    };

    const subjects: BVCSubject[] = [
      {
        firebase_uid: params.firebaseUid,
        subject_code: '23CS401',
        subject_name: 'Data Structures and Algorithms',
        credits: 4,
        faculty_name: 'Dr. M. S. Rao',
        semester: 2,
        academic_year: '2024-2025',
      },
      {
        firebase_uid: params.firebaseUid,
        subject_code: '23CS402',
        subject_name: 'Software Engineering',
        credits: 3,
        faculty_name: 'Mrs. K. Lakshmi',
        semester: 2,
        academic_year: '2024-2025',
      },
      {
        firebase_uid: params.firebaseUid,
        subject_code: '23CS403',
        subject_name: 'Database Management Systems',
        credits: 3,
        faculty_name: 'Mr. P. V. Reddy',
        semester: 2,
        academic_year: '2024-2025',
      },
      {
        firebase_uid: params.firebaseUid,
        subject_code: '23CS404',
        subject_name: 'Computer Organization & Architecture',
        credits: 3,
        faculty_name: 'Dr. T. Suresh',
        semester: 2,
        academic_year: '2024-2025',
      },
    ];

    const attendance: BVCAttendanceRecord[] = [
      {
        firebase_uid: params.firebaseUid,
        subject_code: '23CS401',
        subject_name: 'Data Structures and Algorithms',
        classes_conducted: 42,
        classes_attended: 37,
        percentage: 88.1,
        status: 'Satisfactory',
        updated_at: now,
      },
      {
        firebase_uid: params.firebaseUid,
        subject_code: '23CS402',
        subject_name: 'Software Engineering',
        classes_conducted: 38,
        classes_attended: 32,
        percentage: 84.2,
        status: 'Satisfactory',
        updated_at: now,
      },
      {
        firebase_uid: params.firebaseUid,
        subject_code: '23CS403',
        subject_name: 'Database Management Systems',
        classes_conducted: 40,
        classes_attended: 31,
        percentage: 77.5,
        status: 'Satisfactory',
        updated_at: now,
      },
      {
        firebase_uid: params.firebaseUid,
        subject_code: '23CS404',
        subject_name: 'Computer Organization & Architecture',
        classes_conducted: 36,
        classes_attended: 25,
        percentage: 69.4,
        status: 'Shortage Warning',
        updated_at: now,
      },
    ];

    const results: BVCResultRecord[] = [
      {
        firebase_uid: params.firebaseUid,
        semester: 1,
        subject_code: '23CS301',
        subject_name: 'Discrete Mathematics',
        internal_marks: 28,
        external_marks: 54,
        total_marks: 82,
        grade: 'A+',
        grade_points: 9.0,
        credits: 4,
        result_status: 'PASS',
        sgpa: 8.75,
        cgpa: 8.75,
      },
      {
        firebase_uid: params.firebaseUid,
        semester: 1,
        subject_code: '23CS302',
        subject_name: 'Object Oriented Programming with Java',
        internal_marks: 29,
        external_marks: 56,
        total_marks: 85,
        grade: 'O',
        grade_points: 10.0,
        credits: 4,
        result_status: 'PASS',
        sgpa: 8.75,
        cgpa: 8.75,
      },
    ];

    const timetable: BVCTimetablePeriod[] = [
      {
        firebase_uid: params.firebaseUid,
        day_of_week: 'Monday',
        period_number: 1,
        time_slot: '09:30 AM - 10:20 AM',
        subject_code: '23CS401',
        subject_name: 'Data Structures and Algorithms',
        faculty_name: 'Dr. M. S. Rao',
        room_number: 'LH-204',
      },
      {
        firebase_uid: params.firebaseUid,
        day_of_week: 'Monday',
        period_number: 2,
        time_slot: '10:20 AM - 11:10 AM',
        subject_code: '23CS402',
        subject_name: 'Software Engineering',
        faculty_name: 'Mrs. K. Lakshmi',
        room_number: 'LH-204',
      },
    ];

    const fees: BVCFeeRecord[] = [
      {
        firebase_uid: params.firebaseUid,
        fee_type: 'Semester Examination Fee',
        amount_due: 1450,
        amount_paid: 1450,
        due_date: '2025-04-15',
        payment_status: 'PAID',
      },
    ];

    return {
      success: true,
      message: `Successfully connected BVC profile for roll number ${normalizedRoll}.`,
      profile,
      subjects,
      attendance,
      results,
      timetable,
      fees,
      overallAttendancePercentage: 79.8,
      currentCgpa: 8.75,
    };
  }
}
