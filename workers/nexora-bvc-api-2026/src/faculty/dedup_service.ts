/**
 * ============================================================================
 * Faculty Material Deduplication Service
 * ============================================================================
 * Multi-tier deduplication engine for Cloudflare Workers environment.
 *
 * Tier 1: Cryptographic SHA-256 exact byte matching (O(1) lookup)
 * Tier 2: 64-bit SimHash text fingerprinting with Hamming distance
 *
 * Uses Web Crypto API (crypto.subtle) — no Node.js dependencies.
 * Uses BigInt for 64-bit SimHash computation (V8 Workers runtime).
 * ============================================================================
 */

import { CanonicalDocument, DuplicateCheckResult } from './faculty_types';

// ============================================================================
// Tier 1: SHA-256 Cryptographic Byte Hash
// ============================================================================

/**
 * Computes SHA-256 hash of a raw file buffer using Web Crypto API.
 * Returns lowercase hex string (64 characters).
 */
export async function computeSHA256(buffer: ArrayBuffer): Promise<string> {
  const hashBuffer = await crypto.subtle.digest('SHA-256', buffer);
  const hashArray = new Uint8Array(hashBuffer);
  return Array.from(hashArray)
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
}

// ============================================================================
// Text Normalization
// ============================================================================

/**
 * Normalizes text for semantic comparison by stripping:
 * - University/college headers and footers
 * - Page numbers (e.g., "Page 1 of 10", "- 3 -")
 * - Excessive whitespace, tabs, newlines
 * - Common boilerplate lines
 */
export function normalizeText(text: string): string {
  let cleaned = text;

  // Remove common college header patterns
  cleaned = cleaned.replace(
    /BVC\s+Engineering\s+College[\s\S]*?Odalarevu/gi,
    ''
  );
  cleaned = cleaned.replace(
    /(?:Acharya\s+Nagarjuna|JNTU|JNTUK)[\s\S]*?University/gi,
    ''
  );

  // Remove page numbers: "Page X of Y", "- X -", standalone numbers at line edges
  cleaned = cleaned.replace(/\bPage\s+\d+\s+of\s+\d+\b/gi, '');
  cleaned = cleaned.replace(/^-\s*\d+\s*-$/gm, '');
  cleaned = cleaned.replace(/^\s*\d{1,3}\s*$/gm, '');

  // Remove date stamps like "2025-2026", "Academic Year: ..."
  cleaned = cleaned.replace(/Academic\s+Year\s*:\s*\d{4}\s*-\s*\d{4}/gi, '');

  // Collapse whitespace: tabs, multiple spaces, multiple newlines
  cleaned = cleaned.replace(/\t/g, ' ');
  cleaned = cleaned.replace(/ {2,}/g, ' ');
  cleaned = cleaned.replace(/\n{3,}/g, '\n\n');

  // Trim each line and remove empty lines
  cleaned = cleaned
    .split('\n')
    .map((line) => line.trim())
    .filter((line) => line.length > 0)
    .join('\n');

  return cleaned.trim().toLowerCase();
}

// ============================================================================
// Tier 2: 64-bit SimHash with 3-gram Shingles
// ============================================================================

/**
 * Generates 3-gram shingles from normalized text.
 */
function generateShingles(text: string, n: number = 3): string[] {
  const words = text.split(/\s+/).filter((w) => w.length > 0);
  if (words.length < n) return [words.join(' ')];

  const shingles: string[] = [];
  for (let i = 0; i <= words.length - n; i++) {
    shingles.push(words.slice(i, i + n).join(' '));
  }
  return shingles;
}

/**
 * Simple 64-bit hash of a string using FNV-1a variant with BigInt.
 * Returns a 64-bit BigInt hash value.
 */
function fnv1a64(str: string): bigint {
  let hash = 0xcbf29ce484222325n; // FNV offset basis (64-bit)
  const prime = 0x100000001b3n; // FNV prime (64-bit)
  const mask = 0xffffffffffffffffn; // 64-bit mask

  for (let i = 0; i < str.length; i++) {
    hash ^= BigInt(str.charCodeAt(i));
    hash = (hash * prime) & mask;
  }
  return hash;
}

/**
 * Computes a 64-bit SimHash fingerprint from text.
 *
 * Algorithm:
 * 1. Generate 3-gram shingles from the normalized text.
 * 2. Hash each shingle with FNV-1a to a 64-bit integer.
 * 3. For each bit position (0-63), tally +1 (bit=1) or -1 (bit=0).
 * 4. Final fingerprint: bit=1 where tally > 0, else 0.
 *
 * Returns hex string (16 characters representing 64 bits).
 */
export function computeSimHash(text: string): string {
  const normalized = normalizeText(text);
  const shingles = generateShingles(normalized);

  if (shingles.length === 0) {
    return '0000000000000000';
  }

  // 64 accumulators for each bit position
  const bitCounts = new Array<number>(64).fill(0);

  for (const shingle of shingles) {
    const hash = fnv1a64(shingle);
    for (let bit = 0; bit < 64; bit++) {
      if ((hash >> BigInt(bit)) & 1n) {
        bitCounts[bit]++;
      } else {
        bitCounts[bit]--;
      }
    }
  }

  // Build final fingerprint
  let fingerprint = 0n;
  for (let bit = 0; bit < 64; bit++) {
    if (bitCounts[bit] > 0) {
      fingerprint |= 1n << BigInt(bit);
    }
  }

  return fingerprint.toString(16).padStart(16, '0');
}

// ============================================================================
// Hamming Distance & Similarity
// ============================================================================

/**
 * Computes the Hamming distance (number of differing bits) between
 * two 64-bit SimHash hex strings.
 */
export function hammingDistance(hash1: string, hash2: string): number {
  const h1 = BigInt('0x' + hash1);
  const h2 = BigInt('0x' + hash2);
  let xor = h1 ^ h2;
  let distance = 0;

  while (xor > 0n) {
    distance += Number(xor & 1n);
    xor >>= 1n;
  }

  return distance;
}

/**
 * Calculates similarity percentage between two SimHash fingerprints.
 * Returns value between 0 and 100.
 */
export function similarityPercentage(hash1: string, hash2: string): number {
  const distance = hammingDistance(hash1, hash2);
  return ((64 - distance) / 64) * 100;
}

// ============================================================================
// Duplicate Checker (queries D1)
// ============================================================================

/**
 * Checks for duplicates in the canonical_documents table.
 *
 * Strategy:
 * 1. Tier 1: Exact SHA-256 match → EXACT_MATCH (zero storage)
 * 2. Tier 2: SimHash similarity ≥ 95% → auto-link as NEAR_DUPLICATE
 *    SimHash similarity 85-94% → warn as NEAR_DUPLICATE
 *    SimHash similarity < 85% → UNIQUE
 */
export async function checkDuplicate(
  sha256: string,
  simhash: string | null,
  subjectCode: string,
  db: D1Database
): Promise<DuplicateCheckResult> {
  // Tier 1: Exact byte match
  const exactMatch = await db
    .prepare('SELECT * FROM canonical_documents WHERE file_sha256 = ?')
    .bind(sha256)
    .first<CanonicalDocument>();

  if (exactMatch) {
    return {
      status: 'EXACT_MATCH',
      existingDocument: exactMatch,
      similarity: 100,
      message: `Identical study material "${exactMatch.title}" already exists in the college library. Material will be linked to your section without redundant storage.`,
    };
  }

  // Tier 2: SimHash near-duplicate detection within same subject
  if (simhash) {
    const { results: subjectDocs } = await db
      .prepare(
        'SELECT * FROM canonical_documents WHERE subject_code = ? AND simhash IS NOT NULL'
      )
      .bind(subjectCode)
      .all<CanonicalDocument>();

    if (subjectDocs && subjectDocs.length > 0) {
      let bestMatch: CanonicalDocument | null = null;
      let bestSimilarity = 0;

      for (const doc of subjectDocs) {
        if (doc.simhash) {
          const sim = similarityPercentage(simhash, doc.simhash);
          if (sim > bestSimilarity) {
            bestSimilarity = sim;
            bestMatch = doc;
          }
        }
      }

      if (bestMatch && bestSimilarity >= 85) {
        const message =
          bestSimilarity >= 95
            ? `Near-identical material "${bestMatch.title}" detected (${bestSimilarity.toFixed(1)}% match). Auto-linking to existing canonical document.`
            : `Similar material "${bestMatch.title}" found (${bestSimilarity.toFixed(1)}% match). You can reuse the existing notes or publish as an updated version.`;

        return {
          status: 'NEAR_DUPLICATE',
          existingDocument: bestMatch,
          similarity: Math.round(bestSimilarity * 10) / 10,
          message,
        };
      }
    }
  }

  return {
    status: 'UNIQUE',
    similarity: 0,
    message: 'No duplicates found. This is unique study material ready for ingestion.',
  };
}
