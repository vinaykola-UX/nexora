import { NotificationTarget } from './notification_types';

/**
 * ============================================================================
 * Notification Targeting Engine
 * ============================================================================
 * Resolves target student Firebase UIDs from canonical D1 student profiles.
 * ZERO GUESSING: Only queries verified profile fields (branch, year, semester, section).
 * ============================================================================
 */
export class TargetingEngine {
  public static async resolveTargetUids(
    db: D1Database,
    target: NotificationTarget
  ): Promise<string[]> {
    const scope = target.scope || 'ALL';

    switch (scope) {
      case 'ALL': {
        const { results } = await db
          .prepare(`SELECT firebase_uid FROM bvc_student_profiles WHERE connected = 1`)
          .all<{ firebase_uid: string }>();
        return (results || []).map((r) => r.firebase_uid);
      }

      case 'BRANCH': {
        if (!target.branch) return [];
        const { results } = await db
          .prepare(`SELECT firebase_uid FROM bvc_student_profiles WHERE branch = ? AND connected = 1`)
          .bind(target.branch)
          .all<{ firebase_uid: string }>();
        return (results || []).map((r) => r.firebase_uid);
      }

      case 'YEAR': {
        if (!target.year) return [];
        const { results } = await db
          .prepare(`SELECT firebase_uid FROM bvc_student_profiles WHERE year = ? AND connected = 1`)
          .bind(target.year)
          .all<{ firebase_uid: string }>();
        return (results || []).map((r) => r.firebase_uid);
      }

      case 'SEMESTER': {
        if (!target.semester) return [];
        const { results } = await db
          .prepare(`SELECT firebase_uid FROM bvc_student_profiles WHERE semester = ? AND connected = 1`)
          .bind(target.semester)
          .all<{ firebase_uid: string }>();
        return (results || []).map((r) => r.firebase_uid);
      }

      case 'SECTION': {
        if (!target.section) return [];
        const { results } = await db
          .prepare(`SELECT firebase_uid FROM bvc_student_profiles WHERE section = ? AND connected = 1`)
          .bind(target.section)
          .all<{ firebase_uid: string }>();
        return (results || []).map((r) => r.firebase_uid);
      }

      case 'BRANCH_YEAR': {
        if (!target.branch || !target.year) return [];
        const { results } = await db
          .prepare(
            `SELECT firebase_uid FROM bvc_student_profiles WHERE branch = ? AND year = ? AND connected = 1`
          )
          .bind(target.branch, target.year)
          .all<{ firebase_uid: string }>();
        return (results || []).map((r) => r.firebase_uid);
      }

      case 'BRANCH_SEMESTER': {
        if (!target.branch || !target.semester) return [];
        const { results } = await db
          .prepare(
            `SELECT firebase_uid FROM bvc_student_profiles WHERE branch = ? AND semester = ? AND connected = 1`
          )
          .bind(target.branch, target.semester)
          .all<{ firebase_uid: string }>();
        return (results || []).map((r) => r.firebase_uid);
      }

      case 'CUSTOM_STUDENTS': {
        const uids = new Set<string>(target.custom_firebase_uids || []);
        if (target.custom_roll_numbers && target.custom_roll_numbers.length > 0) {
          const placeholders = target.custom_roll_numbers.map(() => '?').join(',');
          const { results } = await db
            .prepare(
              `SELECT firebase_uid FROM bvc_student_profiles WHERE roll_number IN (${placeholders}) AND connected = 1`
            )
            .bind(...target.custom_roll_numbers)
            .all<{ firebase_uid: string }>();

          for (const r of results || []) {
            uids.add(r.firebase_uid);
          }
        }
        return Array.from(uids);
      }

      default:
        return [];
    }
  }
}
