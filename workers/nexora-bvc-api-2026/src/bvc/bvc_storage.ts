import {
  BVCStudentProfile,
  BVCSubject,
  BVCAttendanceRecord,
  BVCResultRecord,
  BVCTimetablePeriod,
  BVCFeeRecord,
  BVCSyncResult,
} from './bvc_types';

/**
 * BVC Storage Manager
 *
 * PRIVACY GUARANTEE:
 * Manages private, isolated student database tables in Cloudflare D1.
 * Every record is scoped strictly by `firebase_uid`.
 * Never writes or reads from public RAG tables (documents/chunks/vectorize).
 */
export class BVCStorage {
  private static schemaInitialized = false;

  public static async ensurePrivateSchema(db: D1Database): Promise<void> {
    if (this.schemaInitialized) return;

    try {
      await db.batch([
        // 1. Private Student Profiles
        db.prepare(`
          CREATE TABLE IF NOT EXISTS bvc_student_profiles (
            firebase_uid TEXT PRIMARY KEY,
            roll_number TEXT NOT NULL,
            name TEXT,
            branch TEXT,
            course TEXT DEFAULT 'B.Tech',
            year INTEGER,
            semester INTEGER,
            section TEXT,
            regulation TEXT,
            academic_batch TEXT,
            college_email TEXT,
            connected INTEGER DEFAULT 1,
            last_synced_at TIMESTAMP,
            data_source TEXT DEFAULT 'BVC_PORTAL',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
          )
        `),

        // 2. Private Enrolled Subjects
        db.prepare(`
          CREATE TABLE IF NOT EXISTS bvc_student_subjects (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            firebase_uid TEXT NOT NULL,
            subject_code TEXT NOT NULL,
            subject_name TEXT NOT NULL,
            credits REAL,
            faculty_name TEXT,
            semester INTEGER,
            academic_year TEXT,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            UNIQUE(firebase_uid, subject_code, semester)
          )
        `),

        // 3. Private Attendance Records
        db.prepare(`
          CREATE TABLE IF NOT EXISTS bvc_student_attendance (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            firebase_uid TEXT NOT NULL,
            subject_code TEXT NOT NULL,
            subject_name TEXT NOT NULL,
            classes_conducted INTEGER DEFAULT 0,
            classes_attended INTEGER DEFAULT 0,
            percentage REAL DEFAULT 0.0,
            status TEXT,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            UNIQUE(firebase_uid, subject_code)
          )
        `),

        // 4. Private Examination Results & Marks
        db.prepare(`
          CREATE TABLE IF NOT EXISTS bvc_student_results (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            firebase_uid TEXT NOT NULL,
            semester INTEGER NOT NULL,
            subject_code TEXT NOT NULL,
            subject_name TEXT NOT NULL,
            internal_marks REAL,
            external_marks REAL,
            total_marks REAL,
            grade TEXT,
            grade_points REAL,
            credits REAL,
            result_status TEXT,
            sgpa REAL,
            cgpa REAL,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            UNIQUE(firebase_uid, semester, subject_code)
          )
        `),

        // 5. Private Timetable
        db.prepare(`
          CREATE TABLE IF NOT EXISTS bvc_student_timetable (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            firebase_uid TEXT NOT NULL,
            day_of_week TEXT NOT NULL,
            period_number INTEGER NOT NULL,
            time_slot TEXT,
            subject_code TEXT NOT NULL,
            subject_name TEXT NOT NULL,
            faculty_name TEXT,
            room_number TEXT,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
          )
        `),

        // 6. Private Fee Status
        db.prepare(`
          CREATE TABLE IF NOT EXISTS bvc_student_fees (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            firebase_uid TEXT NOT NULL,
            fee_type TEXT NOT NULL,
            amount_due REAL DEFAULT 0.0,
            amount_paid REAL DEFAULT 0.0,
            due_date TEXT,
            payment_status TEXT,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
          )
        `),
      ]);

      this.schemaInitialized = true;
    } catch (err: any) {
      console.error('[BVCStorage] Schema provisioning error:', err?.message || err);
    }
  }

  /**
   * Saves or updates a student's full BVC profile and academic records atomically.
   */
  public static async saveSyncResult(db: D1Database, syncResult: BVCSyncResult): Promise<void> {
    await this.ensurePrivateSchema(db);
    const p = syncResult.profile;
    const now = new Date().toISOString();

    const statements: D1PreparedStatement[] = [
      // Upsert profile
      db.prepare(`
        INSERT INTO bvc_student_profiles (
          firebase_uid, roll_number, name, branch, course, year, semester, section,
          regulation, academic_batch, college_email, connected, last_synced_at, data_source, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1, ?, ?, ?)
        ON CONFLICT(firebase_uid) DO UPDATE SET
          roll_number = excluded.roll_number,
          name = COALESCE(excluded.name, bvc_student_profiles.name),
          branch = COALESCE(excluded.branch, bvc_student_profiles.branch),
          course = COALESCE(excluded.course, bvc_student_profiles.course),
          year = COALESCE(excluded.year, bvc_student_profiles.year),
          semester = COALESCE(excluded.semester, bvc_student_profiles.semester),
          section = COALESCE(excluded.section, bvc_student_profiles.section),
          regulation = COALESCE(excluded.regulation, bvc_student_profiles.regulation),
          academic_batch = COALESCE(excluded.academic_batch, bvc_student_profiles.academic_batch),
          college_email = COALESCE(excluded.college_email, bvc_student_profiles.college_email),
          connected = 1,
          last_synced_at = excluded.last_synced_at,
          data_source = excluded.data_source,
          updated_at = excluded.updated_at
      `).bind(
        p.firebase_uid,
        p.roll_number,
        p.name,
        p.branch,
        p.course,
        p.year,
        p.semester,
        p.section,
        p.regulation,
        p.academic_batch,
        p.college_email,
        p.last_synced_at || now,
        p.data_source,
        now
      ),
    ];

    // Upsert subjects
    for (const s of syncResult.subjects) {
      statements.push(
        db.prepare(`
          INSERT INTO bvc_student_subjects (
            firebase_uid, subject_code, subject_name, credits, faculty_name, semester, academic_year, updated_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
          ON CONFLICT(firebase_uid, subject_code, semester) DO UPDATE SET
            subject_name = excluded.subject_name,
            credits = excluded.credits,
            faculty_name = excluded.faculty_name,
            academic_year = excluded.academic_year,
            updated_at = excluded.updated_at
        `).bind(
          s.firebase_uid,
          s.subject_code,
          s.subject_name,
          s.credits,
          s.faculty_name,
          s.semester,
          s.academic_year || null,
          now
        )
      );
    }

    // Upsert attendance
    for (const a of syncResult.attendance) {
      statements.push(
        db.prepare(`
          INSERT INTO bvc_student_attendance (
            firebase_uid, subject_code, subject_name, classes_conducted, classes_attended, percentage, status, updated_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
          ON CONFLICT(firebase_uid, subject_code) DO UPDATE SET
            subject_name = excluded.subject_name,
            classes_conducted = excluded.classes_conducted,
            classes_attended = excluded.classes_attended,
            percentage = excluded.percentage,
            status = excluded.status,
            updated_at = excluded.updated_at
        `).bind(
          a.firebase_uid,
          a.subject_code,
          a.subject_name,
          a.classes_conducted,
          a.classes_attended,
          a.percentage,
          a.status,
          now
        )
      );
    }

    // Upsert results
    for (const r of syncResult.results) {
      statements.push(
        db.prepare(`
          INSERT INTO bvc_student_results (
            firebase_uid, semester, subject_code, subject_name, internal_marks, external_marks,
            total_marks, grade, grade_points, credits, result_status, sgpa, cgpa, updated_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
          ON CONFLICT(firebase_uid, semester, subject_code) DO UPDATE SET
            subject_name = excluded.subject_name,
            internal_marks = excluded.internal_marks,
            external_marks = excluded.external_marks,
            total_marks = excluded.total_marks,
            grade = excluded.grade,
            grade_points = excluded.grade_points,
            credits = excluded.credits,
            result_status = excluded.result_status,
            sgpa = excluded.sgpa,
            cgpa = excluded.cgpa,
            updated_at = excluded.updated_at
        `).bind(
          r.firebase_uid,
          r.semester,
          r.subject_code,
          r.subject_name,
          r.internal_marks,
          r.external_marks,
          r.total_marks,
          r.grade,
          r.grade_points,
          r.credits,
          r.result_status,
          r.sgpa || null,
          r.cgpa || null,
          now
        )
      );
    }

    await db.batch(statements);
  }

  public static async getStudentProfile(db: D1Database, firebaseUid: string): Promise<BVCStudentProfile | null> {
    await this.ensurePrivateSchema(db);
    return await db
      .prepare(`SELECT * FROM bvc_student_profiles WHERE firebase_uid = ?`)
      .bind(firebaseUid)
      .first<BVCStudentProfile>();
  }

  public static async getStudentAttendance(db: D1Database, firebaseUid: string): Promise<BVCAttendanceRecord[]> {
    await this.ensurePrivateSchema(db);
    const { results } = await db
      .prepare(`SELECT * FROM bvc_student_attendance WHERE firebase_uid = ? ORDER BY subject_code ASC`)
      .bind(firebaseUid)
      .all<BVCAttendanceRecord>();
    return results || [];
  }

  public static async getStudentResults(db: D1Database, firebaseUid: string): Promise<BVCResultRecord[]> {
    await this.ensurePrivateSchema(db);
    const { results } = await db
      .prepare(`SELECT * FROM bvc_student_results WHERE firebase_uid = ? ORDER BY semester DESC, subject_code ASC`)
      .bind(firebaseUid)
      .all<BVCResultRecord>();
    return results || [];
  }

  public static async getStudentSubjects(db: D1Database, firebaseUid: string): Promise<BVCSubject[]> {
    await this.ensurePrivateSchema(db);
    const { results } = await db
      .prepare(`SELECT * FROM bvc_student_subjects WHERE firebase_uid = ? ORDER BY semester DESC, subject_code ASC`)
      .bind(firebaseUid)
      .all<BVCSubject>();
    return results || [];
  }

  public static async getStudentTimetable(db: D1Database, firebaseUid: string): Promise<BVCTimetablePeriod[]> {
    await this.ensurePrivateSchema(db);
    const { results } = await db
      .prepare(`SELECT * FROM bvc_student_timetable WHERE firebase_uid = ? ORDER BY day_of_week ASC, period_number ASC`)
      .bind(firebaseUid)
      .all<BVCTimetablePeriod>();
    return results || [];
  }

  public static async getStudentFees(db: D1Database, firebaseUid: string): Promise<BVCFeeRecord[]> {
    await this.ensurePrivateSchema(db);
    const { results } = await db
      .prepare(`SELECT * FROM bvc_student_fees WHERE firebase_uid = ?`)
      .bind(firebaseUid)
      .all<BVCFeeRecord>();
    return results || [];
  }

  /**
   * Disconnects BVC account and removes private student records for that Firebase UID.
   */
  public static async disconnectStudent(db: D1Database, firebaseUid: string): Promise<void> {
    await this.ensurePrivateSchema(db);
    await db.batch([
      db.prepare(`DELETE FROM bvc_student_profiles WHERE firebase_uid = ?`).bind(firebaseUid),
      db.prepare(`DELETE FROM bvc_student_subjects WHERE firebase_uid = ?`).bind(firebaseUid),
      db.prepare(`DELETE FROM bvc_student_attendance WHERE firebase_uid = ?`).bind(firebaseUid),
      db.prepare(`DELETE FROM bvc_student_results WHERE firebase_uid = ?`).bind(firebaseUid),
      db.prepare(`DELETE FROM bvc_student_timetable WHERE firebase_uid = ?`).bind(firebaseUid),
      db.prepare(`DELETE FROM bvc_student_fees WHERE firebase_uid = ?`).bind(firebaseUid),
    ]);
  }

  /**
   * Constructs sanitized, privacy-safe <private_student_context> for the AI Controller.
   * STRICT GUARANTEE: Never includes credentials, passwords, tokens, or session IDs.
   */
  public static async buildPrivateAIContext(db: D1Database, firebaseUid: string): Promise<string> {
    const profile = await this.getStudentProfile(db, firebaseUid);
    if (!profile || !profile.connected) return '';

    const attendance = await this.getStudentAttendance(db, firebaseUid);
    const results = await this.getStudentResults(db, firebaseUid);
    const subjects = await this.getStudentSubjects(db, firebaseUid);

    const lines: string[] = ['<private_student_context>'];
    lines.push(`student_name: ${profile.name || 'Student'}`);
    lines.push(`roll_number: ${profile.roll_number}`);
    if (profile.branch) lines.push(`branch: ${profile.branch}`);
    if (profile.year) lines.push(`academic_year: ${profile.year}`);
    if (profile.semester) lines.push(`current_semester: ${profile.semester}`);
    if (profile.section) lines.push(`section: ${profile.section}`);
    if (profile.regulation) lines.push(`regulation: ${profile.regulation}`);

    if (subjects.length > 0) {
      lines.push('enrolled_subjects:');
      for (const s of subjects) {
        lines.push(`  - ${s.subject_code}: ${s.subject_name} (${s.credits ?? 'N/A'} credits)`);
      }
    }

    if (attendance.length > 0) {
      lines.push('attendance_records:');
      let totalConducted = 0;
      let totalAttended = 0;
      for (const a of attendance) {
        totalConducted += a.classes_conducted;
        totalAttended += a.classes_attended;
        lines.push(
          `  - ${a.subject_name} (${a.subject_code}): ${a.classes_attended}/${a.classes_conducted} classes (${a.percentage.toFixed(1)}%) [Status: ${a.status || 'Normal'}]`
        );
      }
      if (totalConducted > 0) {
        const overall = ((totalAttended / totalConducted) * 100).toFixed(1);
        lines.push(`overall_attendance: ${overall}%`);
      }
    }

    if (results.length > 0) {
      lines.push('academic_results:');
      for (const r of results) {
        lines.push(
          `  - Sem ${r.semester} | ${r.subject_code} ${r.subject_name}: Grade ${r.grade || 'N/A'}, Points ${r.grade_points ?? 'N/A'}, Status: ${r.result_status || 'N/A'}`
        );
        if (r.cgpa) lines.push(`cumulative_cgpa: ${r.cgpa}`);
      }
    }

    lines.push('</private_student_context>');
    return lines.join('\n');
  }
}
