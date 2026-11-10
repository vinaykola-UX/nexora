import { DatabaseSync } from 'node:sqlite';
import { ResultProcessor } from './src/notifications/result_processor';
import { BVCStorage } from './src/bvc/bvc_storage';
import { BVCNormalizer } from './src/bvc/bvc_normalizer';
import { RawResultInputRecord } from './src/notifications/notification_types';

function createD1Mock(): any {
  const db = new DatabaseSync(':memory:');

  function adaptSql(sql: string): string {
    // Replace CURRENT_TIMESTAMP defaults and syntax differences if any
    return sql;
  }

  return {
    async batch(stmts: any[]) {
      const results = [];
      for (const s of stmts) {
        results.push(await s.run());
      }
      return results;
    },
    prepare(sql: string) {
      const cleanSql = adaptSql(sql);
      let boundParams: any[] = [];
      return {
        bind(...params: any[]) {
          boundParams = params.map(p => p === undefined ? null : p);
          return this;
        },
        async run() {
          const stmt = db.prepare(cleanSql);
          const info = stmt.run(...boundParams);
          return { success: true, meta: { changes: info.changes } };
        },
        async all<T = any>() {
          const stmt = db.prepare(cleanSql);
          const rows = stmt.all(...boundParams) as T[];
          return { results: rows };
        },
        async first<T = any>() {
          const stmt = db.prepare(cleanSql);
          const rows = stmt.all(...boundParams) as T[];
          return rows.length > 0 ? rows[0] : null;
        }
      };
    }
  };
}

function assert(condition: boolean, msg: string) {
  if (!condition) {
    throw new Error(`[ASSERTION FAILED]: ${msg}`);
  }
}

async function runTests() {
  console.log('==================================================================');
  console.log('   BVC NEXORA RESULTS RELEASE & DELIVERY VALIDATION SUITE        ');
  console.log('==================================================================\n');

  const d1 = createD1Mock();

  // Test 1: Deterministic Roll Extraction from College Email
  console.log('[TEST 1] Roll Number Normalization & Deterministic Email Parsing');
  const email1 = '25221A0569@bvcgroup.in';
  const rollFromEmail1 = email1.split('@')[0].toUpperCase();
  assert(BVCNormalizer.isValidRollNumber(rollFromEmail1), 'Roll 25221A0569 must be valid');
  assert(BVCNormalizer.normalizeRollNumber('25221a0569') === '25221A0569', 'Lowercase roll must normalize to uppercase');
  assert(BVCNormalizer.normalizeRollNumber(' 25221A0569 ') === '25221A0569', 'Trim whitespace in roll');
  console.log('  ✅ [PASS] Successfully validated roll number extraction & normalization.\n');

  // Test 2: Admin Ingestion for Unregistered Student (Safe store in unmatched_results)
  console.log('[TEST 2] Admin Uploads Results for Student Not Yet Registered');
  const uploadRecords: RawResultInputRecord[] = [
    {
      roll_number: '25221A0569',
      semester: 2,
      subject_code: 'CS201',
      subject_name: 'Data Structures & Algorithms',
      grade: 'A+',
      credits: 3.0,
      grade_points: 9.0,
      status: 'PASS',
      sgpa: 8.75,
      cgpa: 8.60,
      exam_month_year: 'MAY 2026',
    },
    {
      roll_number: '25221A0569',
      semester: 2,
      subject_code: 'CS202',
      subject_name: 'Database Management Systems',
      grade: 'O',
      credits: 3.0,
      grade_points: 10.0,
      status: 'PASS',
      sgpa: 8.75,
      cgpa: 8.60,
      exam_month_year: 'MAY 2026',
    }
  ];

  const report1 = await ResultProcessor.processResultUpload(d1, {}, uploadRecords);
  assert(report1.total_processed === 2, 'Total processed must be 2');
  assert(report1.valid_records === 2, 'Valid records must be 2');
  assert(report1.matched_students === 0, 'No profiles matched yet');
  assert(report1.unmatched_roll_numbers.includes('25221A0569'), '25221A0569 must be in unmatched list');
  console.log(`  ✅ [PASS] Ingested 2 records into unmatched_results safely for ${report1.unmatched_roll_numbers[0]}.\n`);

  // Test 3: Student Logs In and Opens App (/results) -> Auto-Claim Pipeline
  console.log('[TEST 3] Student Logs In via 25221A0569@bvcgroup.in -> Auto-Claim & Deliver');
  const studentUid = 'firebase_uid_student_0569';
  const studentEmail = '25221A0569@bvcgroup.in';
  const derivedRoll = studentEmail.split('@')[0].toUpperCase();

  // Auto-upsert profile as done in GET /student/results
  await d1.prepare(`
    INSERT INTO bvc_student_profiles (firebase_uid, roll_number, college_email, connected, updated_at)
    VALUES (?, ?, ?, 1, CURRENT_TIMESTAMP)
  `).bind(studentUid, derivedRoll, studentEmail.toLowerCase()).run();

  // Student fetches results
  const studentResults = await BVCStorage.getStudentResults(d1, studentUid, derivedRoll);
  assert(studentResults.length === 2, `Student must receive 2 subjects, received ${studentResults.length}`);
  assert(studentResults[0].roll_number === '25221A0569', 'Roll number must match');
  assert(studentResults[0].sgpa === 8.75, 'SGPA must match 8.75');
  assert(studentResults.some(r => r.subject_code === 'CS201' && r.grade === 'A+' && r.status === 'PASS'), 'CS201 must match');
  assert(studentResults.some(r => r.subject_code === 'CS202' && r.grade === 'O' && r.status === 'PASS'), 'CS202 must match');

  // Verify unmatched_results was cleaned up
  const { results: remainingUnmatched } = await d1.prepare(`SELECT * FROM unmatched_results WHERE UPPER(roll_number) = ?`).bind(derivedRoll).all();
  assert((remainingUnmatched || []).length === 0, 'Unmatched table must be cleared after claiming');
  console.log('  ✅ [PASS] Auto-claim linked results to student UID and cleared unmatched store.\n');

  // Test 4: Privacy Isolation Verification
  console.log('[TEST 4] Strict Privacy Isolation: Student B Cannot Access Student A Results');
  const studentB_Uid = 'firebase_uid_student_0570';
  const studentB_Email = '25221A0570@bvcgroup.in';
  const studentB_Roll = studentB_Email.split('@')[0].toUpperCase();

  const studentB_Results = await BVCStorage.getStudentResults(d1, studentB_Uid, studentB_Roll);
  assert(studentB_Results.length === 0, `Student B must receive 0 subjects, received ${studentB_Results.length}`);
  console.log('  ✅ [PASS] Student B receives 0 results. Zero cross-student exposure.\n');

  // Test 5: Post-Registration Direct Match Scenario
  console.log('[TEST 5] Admin Uploads Results for Registered Student -> Instant Direct Match');
  await d1.prepare(`
    INSERT INTO bvc_student_profiles (firebase_uid, roll_number, college_email, connected, updated_at)
    VALUES (?, ?, ?, 1, CURRENT_TIMESTAMP)
  `).bind(studentB_Uid, studentB_Roll, studentB_Email.toLowerCase()).run();

  const uploadForB: RawResultInputRecord[] = [
    {
      roll_number: '25221A0570',
      semester: 2,
      subject_code: 'CS201',
      subject_name: 'Data Structures & Algorithms',
      grade: 'A',
      credits: 3.0,
      grade_points: 8.0,
      status: 'PASS',
      sgpa: 8.10,
      exam_month_year: 'MAY 2026',
    }
  ];

  const report2 = await ResultProcessor.processResultUpload(d1, {}, uploadForB);
  assert(report2.matched_students === 1, 'Student B profile must be directly matched');
  assert(report2.notifications_queued === 1, 'Notification must be queued for student B');

  const bFetched = await BVCStorage.getStudentResults(d1, studentB_Uid, studentB_Roll);
  assert(bFetched.length === 1, 'Student B must have 1 result');
  assert(bFetched[0].grade === 'A', 'Student B grade must be A');
  assert(bFetched[0].sgpa === 8.10, 'Student B SGPA must be 8.10');
  console.log('  ✅ [PASS] Directly matched results and queued notifications for registered student.\n');

  console.log('==================================================================');
  console.log('       ALL 5/5 RESULTS RELEASE & DELIVERY TESTS PASSED!           ');
  console.log('==================================================================');
}

runTests().catch(err => {
  console.error('[TEST ERROR]:', err);
  process.exit(1);
});
