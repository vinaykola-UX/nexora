/**
 * ============================================================================
 * BVC Normalizer & Sanitizer Layer
 * ============================================================================
 * Handles canonical data normalization and enforces the ZERO GUESSING principle.
 *
 * RULES:
 * 1. Normalize Roll Number to trimmed uppercase (e.g. " 25221a0568 " -> "25221A0568").
 * 2. NEVER guess or infer branch, section, year, semester, or regulation from the
 *    roll number. Only use values explicitly provided by BVC.
 * 3. Return null for missing fields.
 * ============================================================================
 */

export class BVCNormalizer {
  /**
   * Normalizes a student roll number:
   * - Strips all surrounding and embedded whitespace
   * - Converts strictly to uppercase
   *
   * Example: " 25221a0568 " -> "25221A0568"
   */
  public static normalizeRollNumber(raw: string): string {
    if (!raw || typeof raw !== 'string') return '';
    return raw.trim().toUpperCase().replace(/\s+/g, '');
  }

  /**
   * Validates if the string matches the canonical BVC Roll Number pattern
   * (e.g. 25221A0568, 21221A0501, 22225A0402).
   */
  public static isValidRollNumber(roll: string): boolean {
    const normalized = this.normalizeRollNumber(roll);
    if (!normalized) return false;
    // Standard JNTU/BVC 10-character roll number pattern
    const pattern = /^[0-9]{2}[0-9A-Z]{2}[0-9A-Z][0-9A-Z0-9]{4,5}$/;
    return pattern.test(normalized);
  }

  /**
   * Normalizes branch names into canonical acronyms without guessing.
   * Only operates on an explicit branch string provided by BVC.
   */
  public static normalizeBranch(rawBranch?: string | null): string | null {
    if (!rawBranch || typeof rawBranch !== 'string') return null;
    const clean = rawBranch.trim().toUpperCase();

    if (clean.includes('ARTIFICIAL INTELLIGENCE') || clean.includes('AI&ML') || clean.includes('AIML')) {
      return 'AI&ML';
    }
    if (clean.includes('COMPUTER SCIENCE') || clean.includes('CSE')) {
      return 'CSE';
    }
    if (clean.includes('ELECTRONICS') || clean.includes('ECE')) {
      return 'ECE';
    }
    if (clean.includes('ELECTRICAL') || clean.includes('EEE')) {
      return 'EEE';
    }
    if (clean.includes('INFORMATION TECHNOLOGY') || clean === 'IT') {
      return 'IT';
    }
    if (clean.includes('MECHANICAL') || clean.includes('MECH')) {
      return 'MECH';
    }
    if (clean.includes('CIVIL')) {
      return 'CIVIL';
    }

    return rawBranch.trim();
  }

  /**
   * Normalizes semester representation (e.g. "II" -> 2, "SEM-1" -> 1).
   * Returns null if unparseable or not provided.
   */
  public static normalizeSemester(rawSem?: string | number | null): number | null {
    if (rawSem === undefined || rawSem === null) return null;
    if (typeof rawSem === 'number') {
      return rawSem >= 1 && rawSem <= 8 ? rawSem : null;
    }

    const str = String(rawSem).trim().toUpperCase();
    if (str === 'I' || str === '1' || str === 'SEM-1' || str === 'FIRST') return 1;
    if (str === 'II' || str === '2' || str === 'SEM-2' || str === 'SECOND') return 2;
    if (str === 'III' || str === '3' || str === 'SEM-3') return 3;
    if (str === 'IV' || str === '4' || str === 'SEM-4') return 4;
    if (str === 'V' || str === '5' || str === 'SEM-5') return 5;
    if (str === 'VI' || str === '6' || str === 'SEM-6') return 6;
    if (str === 'VII' || str === '7' || str === 'SEM-7') return 7;
    if (str === 'VIII' || str === '8' || str === 'SEM-8') return 8;

    const num = parseInt(str.replace(/[^0-9]/g, ''), 10);
    return isNaN(num) || num < 1 || num > 8 ? null : num;
  }

  /**
   * Normalizes academic year (1, 2, 3, 4).
   */
  public static normalizeYear(rawYear?: string | number | null): number | null {
    if (rawYear === undefined || rawYear === null) return null;
    if (typeof rawYear === 'number') {
      return rawYear >= 1 && rawYear <= 4 ? rawYear : null;
    }

    const str = String(rawYear).trim().toUpperCase();
    if (str === 'I' || str === '1' || str.includes('1ST') || str.includes('FIRST')) return 1;
    if (str === 'II' || str === '2' || str.includes('2ND') || str.includes('SECOND')) return 2;
    if (str === 'III' || str === '3' || str.includes('3RD') || str.includes('THIRD')) return 3;
    if (str === 'IV' || str === '4' || str.includes('4TH') || str.includes('FOURTH')) return 4;

    const num = parseInt(str.replace(/[^0-9]/g, ''), 10);
    return isNaN(num) || num < 1 || num > 4 ? null : num;
  }

  /**
   * Normalizes regulation code (e.g. "BR-23" -> "BR23").
   */
  public static normalizeRegulation(rawReg?: string | null): string | null {
    if (!rawReg || typeof rawReg !== 'string') return null;
    const clean = rawReg.trim().toUpperCase().replace(/[\s-_]+/g, '');
    if (clean.startsWith('BR') || clean.startsWith('R')) {
      return clean.startsWith('BR') ? clean : `B${clean}`;
    }
    return clean || null;
  }
}
