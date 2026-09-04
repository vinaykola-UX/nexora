import { BVCNormalizer } from '../bvc/bvc_normalizer';
import { BVCStorage } from '../bvc/bvc_storage';
import { RawResultInputRecord, ResultIngestReport } from './notification_types';
import { NotificationStorage } from './notification_storage';
import { FCMV1Service } from './fcm_v1_service';

/**
 * ============================================================================
 * Result Ingestion, Deterministic Matching & Notification Engine
 * ============================================================================
 * Ingests academic results, deterministically matches normalized roll numbers
 * with existing student profiles, saves authorized records into D1 private storage,
 * and creates idempotent in-app & FCM HTTP v1 notifications.
 *
 * ZERO GUESSING & STRICT PRIVACY ISOLATION.
 * ============================================================================
 */
export class ResultProcessor {
  public static async processResultUpload(
    db: D1Database,
    env: any,
    records: RawResultInputRecord[]
  ): Promise<ResultIngestReport> {
    await BVCStorage.ensurePrivateSchema(db);
    await NotificationStorage.ensureNotificationSchema(db);

    const report: ResultIngestReport = {
      total_processed: records.length,
      valid_records: 0,
      matched_students: 0,
      unmatched_roll_numbers: [],
      notifications_queued: 0,
      duplicates_skipped: 0,
      matched_profiles: [],
      created_at: new Date().toISOString(),
    };

    if (!records || records.length === 0) {
      return report;
    }

    // Group records by normalized roll number
    const normalizedMap = new Map<string, RawResultInputRecord[]>();

    for (const rawRecord of records) {
      const normalizedRoll = BVCNormalizer.normalizeRollNumber(rawRecord.roll_number);
      const sem = BVCNormalizer.normalizeSemester(rawRecord.semester);

      if (!normalizedRoll || !sem) {
        continue;
      }

      report.valid_records++;

      const existingList = normalizedMap.get(normalizedRoll) || [];
      existingList.push({
        ...rawRecord,
        roll_number: normalizedRoll,
        semester: sem,
      });
      normalizedMap.set(normalizedRoll, existingList);
    }

    const uniqueRollNumbers = Array.from(normalizedMap.keys());
    if (uniqueRollNumbers.length === 0) {
      return report;
    }

    // Fetch existing student profiles matching these roll numbers
    const placeholders = uniqueRollNumbers.map(() => '?').join(',');
    const { results: matchedProfiles } = await db
      .prepare(`
        SELECT firebase_uid, roll_number, name, branch, year, semester, section
        FROM bvc_student_profiles
        WHERE roll_number IN (${placeholders})
      `)
      .bind(...uniqueRollNumbers)
      .all<{
        firebase_uid: string;
        roll_number: string;
        name: string | null;
        branch: string | null;
        year: number | null;
        semester: number | null;
        section: string | null;
      }>();

    const profileByRoll = new Map<string, typeof matchedProfiles[0]>();
    for (const prof of matchedProfiles || []) {
      profileByRoll.set(prof.roll_number, prof);
    }

    const notificationsToPush: Array<{
      firebase_uid: string;
      title: string;
      body: string;
      type: string;
      route: string;
      referenceId: string;
    }> = [];

    // Process each student's results
    for (const roll of uniqueRollNumbers) {
      const studentRecords = normalizedMap.get(roll) || [];
      const profile = profileByRoll.get(roll);

      if (profile) {
        // MATCHED STUDENT
        report.matched_students++;
        report.matched_profiles.push({
          roll_number: roll,
          firebase_uid: profile.firebase_uid,
          name: profile.name,
          branch: profile.branch,
        });

        // Insert / Update results in private table `bvc_student_results`
        for (const rec of studentRecords) {
          const sem = typeof rec.semester === 'number' ? rec.semester : parseInt(String(rec.semester), 10);
          const credits = rec.credits ? parseFloat(String(rec.credits)) : null;
          const gradePoints = rec.grade_points ? parseFloat(String(rec.grade_points)) : null;
          const sgpa = rec.sgpa ? parseFloat(String(rec.sgpa)) : null;
          const cgpa = rec.cgpa ? parseFloat(String(rec.cgpa)) : null;

          if (rec.subject_code) {
            await db
              .prepare(`
                INSERT INTO bvc_student_results (
                  firebase_uid, semester, subject_code, subject_name, grade, credits, grade_points, status, sgpa, cgpa, exam_month_year, updated_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
                ON CONFLICT(firebase_uid, semester, subject_code) DO UPDATE SET
                  subject_name = excluded.subject_name,
                  grade = excluded.grade,
                  credits = excluded.credits,
                  grade_points = excluded.grade_points,
                  status = excluded.status,
                  sgpa = excluded.sgpa,
                  cgpa = excluded.cgpa,
                  exam_month_year = excluded.exam_month_year,
                  updated_at = CURRENT_TIMESTAMP
              `)
              .bind(
                profile.firebase_uid,
                sem,
                rec.subject_code,
                rec.subject_name || 'Academic Course',
                rec.grade || null,
                credits,
                gradePoints,
                rec.status || (rec.grade === 'F' ? 'FAIL' : 'PASS'),
                sgpa,
                cgpa,
                rec.exam_month_year || null
              )
              .run();
          }
        }

        // Create Idempotent Notification
        const targetSemester = studentRecords[0]?.semester || profile.semester || 1;
        const referenceId = `RESULT:SEM${targetSemester}:${roll}`;

        const notifResult = await NotificationStorage.createNotificationIdempotent(db, {
          firebase_uid: profile.firebase_uid,
          type: 'RESULT',
          title: 'Semester Results Published',
          body: `Your Semester ${targetSemester} results are now available in Nexora.`,
          data_json: JSON.stringify({
            type: 'RESULT',
            semester: targetSemester,
            screen: 'results',
            route: '/results',
          }),
          reference_id: referenceId,
        });

        if (notifResult.created) {
          report.notifications_queued++;
          notificationsToPush.push({
            firebase_uid: profile.firebase_uid,
            title: 'Semester Results Published',
            body: `Your Semester ${targetSemester} results are now available in Nexora.`,
            type: 'RESULT',
            route: '/results',
            referenceId: referenceId,
          });
        } else if (notifResult.duplicate) {
          report.duplicates_skipped++;
        }
      } else {
        // UNMATCHED ROLL NUMBER — store safely in unmatched_results
        report.unmatched_roll_numbers.push(roll);

        for (const rec of studentRecords) {
          const sem = typeof rec.semester === 'number' ? rec.semester : parseInt(String(rec.semester), 10);
          await db
            .prepare(`
              INSERT INTO unmatched_results (
                roll_number, semester, subject_code, subject_name, grade, credits, grade_points, status, sgpa, cgpa, exam_month_year, raw_payload
              ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            `)
            .bind(
              roll,
              sem,
              rec.subject_code || null,
              rec.subject_name || null,
              rec.grade || null,
              rec.credits ? parseFloat(String(rec.credits)) : null,
              rec.grade_points ? parseFloat(String(rec.grade_points)) : null,
              rec.status || null,
              rec.sgpa ? parseFloat(String(rec.sgpa)) : null,
              rec.cgpa ? parseFloat(String(rec.cgpa)) : null,
              rec.exam_month_year || null,
              JSON.stringify(rec)
            )
            .run();
        }
      }
    }

    // Dispatch FCM HTTP v1 notifications for queued items
    if (notificationsToPush.length > 0) {
      const uids = notificationsToPush.map((n) => n.firebase_uid);
      const devices = await NotificationStorage.getActiveDeviceTokens(db, uids);
      const tokenMap = new Map<string, string[]>();

      for (const d of devices) {
        const list = tokenMap.get(d.firebase_uid) || [];
        list.push(d.fcm_token);
        tokenMap.set(d.firebase_uid, list);
      }

      const fcmBatchItems: Array<{
        fcm_token: string;
        title: string;
        body: string;
        type: string;
        route?: string;
        referenceId?: string;
      }> = [];

      for (const item of notificationsToPush) {
        const tokens = tokenMap.get(item.firebase_uid) || [];
        for (const token of tokens) {
          fcmBatchItems.push({
            fcm_token: token,
            title: item.title,
            body: item.body,
            type: item.type,
            route: item.route,
            referenceId: item.referenceId,
          });
        }
      }

      if (fcmBatchItems.length > 0) {
        await FCMV1Service.batchSend(env, fcmBatchItems);
      }
    }

    return report;
  }
}
