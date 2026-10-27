/**
 * ============================================================================
 * Faculty Materials Route Handler
 * ============================================================================
 * Handles all /faculty/materials/* and related analytics routes.
 * Also handles POST /student/materials/:id/track for student telemetry.
 *
 * Routes:
 *   POST   /faculty/materials/check-duplicate
 *   POST   /faculty/materials/upload
 *   GET    /faculty/materials
 *   DELETE /faculty/materials/:id
 *   GET    /faculty/analytics/materials/:id/students
 *   GET    /faculty/analytics/subject/:code/insights
 *   POST   /student/materials/:id/track
 * ============================================================================
 */

import {
  CanonicalDocument,
  FacultyMaterialShare,
  DuplicateCheckResult,
  StudentFlowRecord,
  SubjectInsightSummary,
} from './faculty_types';
import {
  computeSimHash,
  checkDuplicate,
  normalizeText,
} from './dedup_service';
import {
  FirebaseAuthGuard,
  AuthenticatedFirebaseUser,
} from '../bvc/firebase_auth_guard';
import { backfillChunksToVectorize, VectorSyncInput } from '../rag/vector_sync';

// ---------------------------------------------------------------------------
// Env subset needed by this handler
// ---------------------------------------------------------------------------
interface FacultyEnv {
  DB?: D1Database;
  VECTORIZE?: VectorizeIndex;
  AI?: any;
  ENVIRONMENT?: string;
  EMBEDDING_MODEL?: string;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function jsonResponse(data: any, status = 200): Response {
  return new Response(JSON.stringify(data, null, 2), {
    status,
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
    },
  });
}

/**
 * Faculty emails do NOT start with digits (student pattern like 25221A0568).
 * Faculty emails look like: vinaybvcec@bvcgroup.in, rajeshcse@bvcgroup.in
 */
function isFacultyEmail(email: string): boolean {
  if (!email) return false;
  const localPart = email.split('@')[0];
  return !/^\d/.test(localPart);
}

/**
 * Authenticates a Firebase user and verifies they are faculty.
 */
async function authenticateFaculty(
  request: Request,
  env: FacultyEnv
): Promise<AuthenticatedFirebaseUser | null> {
  const user = await FirebaseAuthGuard.authenticate(request, {
    environment: env.ENVIRONMENT,
  });
  if (!user) return null;
  if (!user.email || !isFacultyEmail(user.email)) return null;
  return user;
}

// ---------------------------------------------------------------------------
// Main Router
// ---------------------------------------------------------------------------

/**
 * Handles faculty material management and student tracking routes.
 * Returns a Response if the path matches, or null to fall through.
 */
export async function handleFacultyMaterialRoutes(
  request: Request,
  url: URL,
  path: string,
  env: FacultyEnv
): Promise<Response | null> {
  // =========================================================================
  // 1. POST /faculty/materials/check-duplicate
  // =========================================================================
  if (request.method === 'POST' && path === '/faculty/materials/check-duplicate') {
    const faculty = await authenticateFaculty(request, env);
    if (!faculty) {
      return jsonResponse(
        { success: false, error: 'Unauthorized', message: 'Valid faculty authentication required.' },
        401
      );
    }
    if (!env.DB) {
      return jsonResponse({ success: false, error: 'Database Unavailable' }, 503);
    }

    let body: any;
    try {
      body = await request.json();
    } catch {
      return jsonResponse(
        { success: false, error: 'Bad Request', message: 'Invalid JSON body. Required: { file_sha256, subject_code }' },
        400
      );
    }

    const sha256 = (body?.file_sha256 || '').trim();
    const subjectCode = (body?.subject_code || '').trim();
    const textContent = (body?.text_content || '').trim();

    if (!sha256 || !subjectCode) {
      return jsonResponse(
        { success: false, error: 'Validation Error', message: 'file_sha256 and subject_code are required.' },
        400
      );
    }

    const simhash = textContent ? computeSimHash(textContent) : null;
    const result = await checkDuplicate(sha256, simhash, subjectCode, env.DB);

    return jsonResponse({
      success: true,
      deduplication: result,
      simhash_computed: simhash,
    });
  }

  // =========================================================================
  // 2. POST /faculty/materials/upload
  // =========================================================================
  if (request.method === 'POST' && path === '/faculty/materials/upload') {
    const faculty = await authenticateFaculty(request, env);
    if (!faculty) {
      return jsonResponse(
        { success: false, error: 'Unauthorized', message: 'Valid faculty authentication required.' },
        401
      );
    }
    if (!env.DB) {
      return jsonResponse({ success: false, error: 'Database Unavailable' }, 503);
    }

    let body: any;
    try {
      body = await request.json();
    } catch {
      return jsonResponse(
        { success: false, error: 'Bad Request', message: 'Invalid JSON body.' },
        400
      );
    }

    const title = (body?.title || '').trim();
    const subjectCode = (body?.subject_code || '').trim();
    const subjectName = (body?.subject_name || '').trim();
    const unit = parseInt(String(body?.unit || '1'), 10) || 1;
    const topic = (body?.topic || '').trim();
    const sha256 = (body?.file_sha256 || '').trim();
    const fileSizeBytes = parseInt(String(body?.file_size_bytes || '0'), 10) || 0;
    const fileType = (body?.file_type || 'application/pdf').trim();
    const textContent = (body?.text_content || '').trim();
    const rawChunks: string[] = body?.chunks || [];
    const facultyName = (body?.faculty_name || faculty.email?.split('@')[0] || 'Faculty').trim();
    const department = (body?.department || 'CSE').trim();
    const academicYear = (body?.academic_year || '2025-2026').trim();
    const sections = (body?.sections || 'ALL').trim();
    const forceUpload = body?.force === true;

    if (!title || !subjectCode || !sha256) {
      return jsonResponse(
        { success: false, error: 'Validation Error', message: 'title, subject_code, and file_sha256 are required.' },
        400
      );
    }

    if (!Array.isArray(rawChunks) || rawChunks.length === 0) {
      return jsonResponse(
        { success: false, error: 'Validation Error', message: 'chunks[] array with at least one text chunk is required.' },
        400
      );
    }

    // Validate all chunks are non-empty strings
    const chunkTexts: string[] = [];
    for (let i = 0; i < rawChunks.length; i++) {
      const text = (typeof rawChunks[i] === 'string' ? rawChunks[i] : '').trim();
      if (!text) {
        return jsonResponse(
          { success: false, error: 'Validation Error', message: `Chunk #${i + 1} is empty.` },
          400
        );
      }
      chunkTexts.push(text);
    }

    // Compute SimHash from text content
    const simhash = textContent ? computeSimHash(textContent) : null;

    // Run deduplication check
    const dupResult = await checkDuplicate(sha256, simhash, subjectCode, env.DB);

    // --- EXACT MATCH: Link to existing canonical doc, zero new storage ---
    if (dupResult.status === 'EXACT_MATCH' && dupResult.existingDocument) {
      const existingDoc = dupResult.existingDocument;

      // Create faculty share link (ignore if already exists)
      try {
        await env.DB.prepare(
          `INSERT OR IGNORE INTO faculty_material_shares
           (canonical_doc_id, faculty_uid, faculty_email, faculty_name, department, academic_year, sections, is_primary_author)
           VALUES (?, ?, ?, ?, ?, ?, ?, 0)`
        )
          .bind(existingDoc.id, faculty.uid, faculty.email || '', facultyName, department, academicYear, sections)
          .run();
      } catch (e: any) {
        console.error('[Faculty Upload] Share link error:', e?.message);
      }

      return jsonResponse({
        success: true,
        status: 'LINKED_EXISTING',
        canonical_doc_id: existingDoc.id,
        title: existingDoc.title,
        message: dupResult.message,
        storage_saved_bytes: fileSizeBytes,
        chunks_saved: chunkTexts.length,
        vectors_saved: chunkTexts.length,
      });
    }

    // --- NEAR DUPLICATE (≥95%): Auto-link ---
    if (
      dupResult.status === 'NEAR_DUPLICATE' &&
      dupResult.existingDocument &&
      dupResult.similarity !== undefined &&
      dupResult.similarity >= 95
    ) {
      const existingDoc = dupResult.existingDocument;

      try {
        await env.DB.prepare(
          `INSERT OR IGNORE INTO faculty_material_shares
           (canonical_doc_id, faculty_uid, faculty_email, faculty_name, department, academic_year, sections, is_primary_author)
           VALUES (?, ?, ?, ?, ?, ?, ?, 0)`
        )
          .bind(existingDoc.id, faculty.uid, faculty.email || '', facultyName, department, academicYear, sections)
          .run();
      } catch (e: any) {
        console.error('[Faculty Upload] Near-dup share link error:', e?.message);
      }

      return jsonResponse({
        success: true,
        status: 'LINKED_NEAR_DUPLICATE',
        canonical_doc_id: existingDoc.id,
        similarity: dupResult.similarity,
        title: existingDoc.title,
        message: dupResult.message,
        storage_saved_bytes: fileSizeBytes,
      });
    }

    // --- NEAR DUPLICATE (85-94%): Warn unless forced ---
    if (
      dupResult.status === 'NEAR_DUPLICATE' &&
      dupResult.existingDocument &&
      !forceUpload
    ) {
      return jsonResponse({
        success: false,
        status: 'NEAR_DUPLICATE_WARNING',
        existing_document: {
          id: dupResult.existingDocument.id,
          title: dupResult.existingDocument.title,
          subject_code: dupResult.existingDocument.subject_code,
          version: dupResult.existingDocument.version,
        },
        similarity: dupResult.similarity,
        message: dupResult.message,
        hint: 'Set "force": true in request body to upload as a new version, or reuse the existing material.',
      });
    }

    // --- UNIQUE or FORCED: Full ingestion pipeline ---
    try {
      // 1. Insert canonical document
      const version =
        dupResult.status === 'NEAR_DUPLICATE' && dupResult.existingDocument
          ? `${parseFloat(dupResult.existingDocument.version || '1.0') + 1}.0`
          : '1.0';

      const insertCanonical = await env.DB.prepare(
        `INSERT INTO canonical_documents
         (file_sha256, simhash, title, subject_code, subject_name, unit, topic, file_type, file_size_bytes, total_chunks, version)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
      )
        .bind(sha256, simhash, title, subjectCode, subjectName || subjectCode, unit, topic || null, fileType, fileSizeBytes, chunkTexts.length, version)
        .run();

      const canonicalDocId =
        insertCanonical.meta?.last_row_id ||
        (insertCanonical as any).lastRowId ||
        Date.now();

      // 2. Insert faculty share as primary author
      await env.DB.prepare(
        `INSERT INTO faculty_material_shares
         (canonical_doc_id, faculty_uid, faculty_email, faculty_name, department, academic_year, sections, is_primary_author)
         VALUES (?, ?, ?, ?, ?, ?, ?, 1)`
      )
        .bind(canonicalDocId, faculty.uid, faculty.email || '', facultyName, department, academicYear, sections)
        .run();

      // 3. Insert into legacy `documents` table for backward compatibility with RAG search
      const insertDoc = await env.DB.prepare(
        `INSERT INTO documents (title, subject, unit, file_url, created_at)
         VALUES (?, ?, ?, ?, CURRENT_TIMESTAMP)`
      )
        .bind(title, subjectCode, unit, topic || null)
        .run();

      const legacyDocId =
        insertDoc.meta?.last_row_id ||
        (insertDoc as any).lastRowId ||
        Date.now();

      // 4. Insert chunks into `chunks` table
      const chunkStatements = chunkTexts.map((text, idx) =>
        env.DB!.prepare(
          `INSERT INTO chunks (document_id, content, chunk_index, created_at)
           VALUES (?, ?, ?, CURRENT_TIMESTAMP)`
        ).bind(legacyDocId, text, idx)
      );

      await env.DB.batch(chunkStatements);

      // 5. Vectorize embeddings (best-effort)
      let vectorizeStatus = 'skipped';
      let vectorizedCount = 0;

      if (env.VECTORIZE && env.AI) {
        try {
          const { results: newChunks } = await env.DB.prepare(
            `SELECT id, document_id, content, chunk_index FROM chunks WHERE document_id = ? ORDER BY chunk_index ASC`
          )
            .bind(legacyDocId)
            .all<{ id: number; document_id: number; content: string; chunk_index: number }>();

          if (newChunks && newChunks.length > 0) {
            const syncInputs: VectorSyncInput[] = newChunks.map((c) => ({
              chunkId: c.id,
              documentId: c.document_id,
              content: c.content,
              title,
              subject: subjectCode,
              unit,
              chunkIndex: c.chunk_index,
              topic: topic || undefined,
            }));

            const syncResult = await backfillChunksToVectorize(syncInputs, env);
            vectorizeStatus = syncResult.vectorStatus;
            vectorizedCount = syncResult.vectorized;
          }
        } catch (vecErr: any) {
          console.error('[Faculty Upload] Vectorize sync error:', vecErr?.message);
          vectorizeStatus = 'error';
        }
      }

      return jsonResponse({
        success: true,
        status: 'UPLOADED',
        canonical_doc_id: canonicalDocId,
        legacy_doc_id: legacyDocId,
        title,
        subject_code: subjectCode,
        unit,
        version,
        chunks_created: chunkTexts.length,
        vectorize: { status: vectorizeStatus, vectorized: vectorizedCount },
        message: `Successfully uploaded and indexed "${title}" with ${chunkTexts.length} chunks into Memex knowledge base.`,
      });
    } catch (dbErr: any) {
      console.error('[Faculty Upload] Database error:', dbErr?.message || dbErr);
      return jsonResponse(
        { success: false, error: 'Database Error', message: `Failed to store material: ${dbErr?.message || dbErr}` },
        500
      );
    }
  }

  // =========================================================================
  // 3. GET /faculty/materials
  // =========================================================================
  if (request.method === 'GET' && path === '/faculty/materials') {
    const faculty = await authenticateFaculty(request, env);
    if (!faculty) {
      return jsonResponse(
        { success: false, error: 'Unauthorized', message: 'Valid faculty authentication required.' },
        401
      );
    }
    if (!env.DB) {
      return jsonResponse({ success: false, error: 'Database Unavailable' }, 503);
    }

    try {
      const { results } = await env.DB.prepare(
        `SELECT
           fms.id AS share_id,
           fms.canonical_doc_id,
           fms.faculty_uid,
           fms.faculty_email,
           fms.faculty_name,
           fms.department,
           fms.academic_year,
           fms.sections,
           fms.is_primary_author,
           fms.created_at AS shared_at,
           cd.title,
           cd.subject_code,
           cd.subject_name,
           cd.unit,
           cd.topic,
           cd.file_type,
           cd.file_size_bytes,
           cd.total_chunks,
           cd.version,
           cd.is_verified,
           cd.created_at AS doc_created_at,
           (SELECT COUNT(*) FROM faculty_material_shares WHERE canonical_doc_id = cd.id) AS total_shares,
           (SELECT COUNT(*) FROM student_material_interactions WHERE canonical_doc_id = cd.id AND action_type = 'VIEW') AS total_views,
           (SELECT COUNT(*) FROM student_material_interactions WHERE canonical_doc_id = cd.id AND action_type = 'DOWNLOAD') AS total_downloads
         FROM faculty_material_shares fms
         JOIN canonical_documents cd ON fms.canonical_doc_id = cd.id
         WHERE fms.faculty_uid = ?
         ORDER BY fms.created_at DESC`
      )
        .bind(faculty.uid)
        .all();

      return jsonResponse({
        success: true,
        materials: results || [],
        total: (results || []).length,
      });
    } catch (err: any) {
      console.error('[Faculty Materials] List error:', err?.message);
      return jsonResponse(
        { success: false, error: 'Database Error', message: err?.message || 'Failed to fetch materials.' },
        500
      );
    }
  }

  // =========================================================================
  // 4. DELETE /faculty/materials/:id
  // =========================================================================
  if (request.method === 'DELETE' && path.startsWith('/faculty/materials/')) {
    const faculty = await authenticateFaculty(request, env);
    if (!faculty) {
      return jsonResponse(
        { success: false, error: 'Unauthorized', message: 'Valid faculty authentication required.' },
        401
      );
    }
    if (!env.DB) {
      return jsonResponse({ success: false, error: 'Database Unavailable' }, 503);
    }

    const shareIdStr = path.replace('/faculty/materials/', '').trim();
    const shareId = parseInt(shareIdStr, 10);
    if (isNaN(shareId) || shareId <= 0) {
      return jsonResponse(
        { success: false, error: 'Bad Request', message: 'Valid share ID is required.' },
        400
      );
    }

    try {
      // Verify ownership
      const share = await env.DB.prepare(
        'SELECT * FROM faculty_material_shares WHERE id = ? AND faculty_uid = ?'
      )
        .bind(shareId, faculty.uid)
        .first<FacultyMaterialShare>();

      if (!share) {
        return jsonResponse(
          { success: false, error: 'Not Found', message: 'Material share not found or not owned by you.' },
          404
        );
      }

      const canonicalDocId = share.canonical_doc_id;

      // Delete this faculty's share
      await env.DB.prepare('DELETE FROM faculty_material_shares WHERE id = ?')
        .bind(shareId)
        .run();

      // Check if any other shares reference the same canonical document
      const remainingShares = await env.DB.prepare(
        'SELECT COUNT(*) AS cnt FROM faculty_material_shares WHERE canonical_doc_id = ?'
      )
        .bind(canonicalDocId)
        .first<{ cnt: number }>();

      let canonicalDeleted = false;

      if (!remainingShares || remainingShares.cnt === 0) {
        // No other faculty references this document — purge canonical copy
        // Delete student interactions for this document
        await env.DB.prepare(
          'DELETE FROM student_material_interactions WHERE canonical_doc_id = ?'
        )
          .bind(canonicalDocId)
          .run();

        // Find and delete legacy document + chunks
        // Match by title + subject since we don't have a direct FK
        const canonicalDoc = await env.DB.prepare(
          'SELECT title, subject_code, unit FROM canonical_documents WHERE id = ?'
        )
          .bind(canonicalDocId)
          .first<{ title: string; subject_code: string; unit: number }>();

        if (canonicalDoc) {
          const legacyDoc = await env.DB.prepare(
            'SELECT id FROM documents WHERE title = ? AND subject = ? AND unit = ?'
          )
            .bind(canonicalDoc.title, canonicalDoc.subject_code, canonicalDoc.unit)
            .first<{ id: number }>();

          if (legacyDoc) {
            await env.DB.batch([
              env.DB.prepare('DELETE FROM chunks WHERE document_id = ?').bind(legacyDoc.id),
              env.DB.prepare('DELETE FROM documents WHERE id = ?').bind(legacyDoc.id),
            ]);
          }
        }

        // Delete canonical document itself
        await env.DB.prepare('DELETE FROM canonical_documents WHERE id = ?')
          .bind(canonicalDocId)
          .run();

        canonicalDeleted = true;
      }

      return jsonResponse({
        success: true,
        message: canonicalDeleted
          ? 'Material unlinked and canonical copy purged (no other lecturers reference it).'
          : 'Material unlinked from your profile. Canonical copy retained for other lecturers.',
        canonical_deleted: canonicalDeleted,
      });
    } catch (err: any) {
      console.error('[Faculty Materials] Delete error:', err?.message);
      return jsonResponse(
        { success: false, error: 'Database Error', message: err?.message || 'Failed to delete material.' },
        500
      );
    }
  }

  // =========================================================================
  // 5. GET /faculty/analytics/materials/:id/students
  // =========================================================================
  if (
    request.method === 'GET' &&
    path.startsWith('/faculty/analytics/materials/') &&
    path.endsWith('/students')
  ) {
    const faculty = await authenticateFaculty(request, env);
    if (!faculty) {
      return jsonResponse(
        { success: false, error: 'Unauthorized', message: 'Valid faculty authentication required.' },
        401
      );
    }
    if (!env.DB) {
      return jsonResponse({ success: false, error: 'Database Unavailable' }, 503);
    }

    // Extract :id from /faculty/analytics/materials/:id/students
    const segments = path.split('/');
    const docIdStr = segments[4]; // ['', 'faculty', 'analytics', 'materials', ':id', 'students']
    const canonicalDocId = parseInt(docIdStr, 10);

    if (isNaN(canonicalDocId) || canonicalDocId <= 0) {
      return jsonResponse(
        { success: false, error: 'Bad Request', message: 'Valid document ID is required.' },
        400
      );
    }

    try {
      // Verify faculty has access to this document
      const hasShare = await env.DB.prepare(
        'SELECT id FROM faculty_material_shares WHERE canonical_doc_id = ? AND faculty_uid = ?'
      )
        .bind(canonicalDocId, faculty.uid)
        .first();

      if (!hasShare) {
        return jsonResponse(
          { success: false, error: 'Forbidden', message: 'You do not have access to this material.' },
          403
        );
      }

      // Aggregate student interactions
      const { results } = await env.DB.prepare(
        `SELECT
           student_roll,
           student_name,
           branch,
           section,
           SUM(CASE WHEN action_type = 'VIEW' THEN 1 ELSE 0 END) AS total_views,
           SUM(CASE WHEN action_type = 'DOWNLOAD' THEN 1 ELSE 0 END) AS total_downloads,
           SUM(CASE WHEN action_type = 'ASK_AI' THEN 1 ELSE 0 END) AS total_ai_queries,
           MIN(created_at) AS first_accessed,
           MAX(created_at) AS last_accessed
         FROM student_material_interactions
         WHERE canonical_doc_id = ?
         GROUP BY student_roll
         ORDER BY last_accessed DESC`
      )
        .bind(canonicalDocId)
        .all<StudentFlowRecord>();

      // Get document info
      const docInfo = await env.DB.prepare(
        'SELECT title, subject_code, subject_name, unit FROM canonical_documents WHERE id = ?'
      )
        .bind(canonicalDocId)
        .first();

      return jsonResponse({
        success: true,
        document: docInfo,
        students: results || [],
        total_students: (results || []).length,
      });
    } catch (err: any) {
      console.error('[Faculty Analytics] Student flow error:', err?.message);
      return jsonResponse(
        { success: false, error: 'Database Error', message: err?.message || 'Failed to fetch analytics.' },
        500
      );
    }
  }

  // =========================================================================
  // 6. GET /faculty/analytics/subject/:code/insights
  // =========================================================================
  if (
    request.method === 'GET' &&
    path.startsWith('/faculty/analytics/subject/') &&
    path.endsWith('/insights')
  ) {
    const faculty = await authenticateFaculty(request, env);
    if (!faculty) {
      return jsonResponse(
        { success: false, error: 'Unauthorized', message: 'Valid faculty authentication required.' },
        401
      );
    }
    if (!env.DB) {
      return jsonResponse({ success: false, error: 'Database Unavailable' }, 503);
    }

    // Extract :code from /faculty/analytics/subject/:code/insights
    const segments = path.split('/');
    const subjectCode = decodeURIComponent(segments[4] || '').toUpperCase();

    if (!subjectCode) {
      return jsonResponse(
        { success: false, error: 'Bad Request', message: 'Subject code is required.' },
        400
      );
    }

    try {
      // Total materials for this subject
      const materialCount = await env.DB.prepare(
        'SELECT COUNT(*) AS cnt FROM canonical_documents WHERE subject_code = ?'
      )
        .bind(subjectCode)
        .first<{ cnt: number }>();

      // Aggregate interactions across all docs in this subject
      const interactions = await env.DB.prepare(
        `SELECT
           SUM(CASE WHEN smi.action_type = 'VIEW' THEN 1 ELSE 0 END) AS total_views,
           SUM(CASE WHEN smi.action_type = 'DOWNLOAD' THEN 1 ELSE 0 END) AS total_downloads,
           SUM(CASE WHEN smi.action_type = 'ASK_AI' THEN 1 ELSE 0 END) AS total_ai_queries,
           COUNT(DISTINCT smi.student_roll) AS unique_students
         FROM student_material_interactions smi
         JOIN canonical_documents cd ON smi.canonical_doc_id = cd.id
         WHERE cd.subject_code = ?`
      )
        .bind(subjectCode)
        .first<{ total_views: number; total_downloads: number; total_ai_queries: number; unique_students: number }>();

      // Concept difficulty hotspots
      const { results: hotspots } = await env.DB.prepare(
        `SELECT concept_topic AS topic, query_count, unit
         FROM subject_concept_insights
         WHERE subject_code = ?
         ORDER BY query_count DESC
         LIMIT 20`
      )
        .bind(subjectCode)
        .all<{ topic: string; query_count: number; unit: number }>();

      // Engagement rate: unique students who interacted / total enrolled (estimate from interactions)
      const totalMaterials = materialCount?.cnt || 0;
      const uniqueStudents = interactions?.unique_students || 0;
      // Estimate: assume ~180 students per subject section
      const estimatedEnrolled = 180;
      const engagementRate =
        estimatedEnrolled > 0
          ? Math.min(100, Math.round((uniqueStudents / estimatedEnrolled) * 100 * 10) / 10)
          : 0;

      const summary: SubjectInsightSummary = {
        subject_code: subjectCode,
        total_materials: totalMaterials,
        total_student_views: interactions?.total_views || 0,
        total_downloads: interactions?.total_downloads || 0,
        total_ai_queries: interactions?.total_ai_queries || 0,
        concept_hotspots: hotspots || [],
        student_engagement_rate: engagementRate,
      };

      return jsonResponse({
        success: true,
        insights: summary,
        unique_students: uniqueStudents,
      });
    } catch (err: any) {
      console.error('[Faculty Analytics] Subject insights error:', err?.message);
      return jsonResponse(
        { success: false, error: 'Database Error', message: err?.message || 'Failed to fetch insights.' },
        500
      );
    }
  }

  // =========================================================================
  // 7. POST /student/materials/:id/track
  // =========================================================================
  if (
    request.method === 'POST' &&
    path.startsWith('/student/materials/') &&
    path.endsWith('/track')
  ) {
    // Student auth (requireBvcDomain)
    const student = await FirebaseAuthGuard.authenticate(request, {
      environment: env.ENVIRONMENT,
      requireBvcDomain: true,
    });
    if (!student) {
      return jsonResponse(
        { success: false, error: 'Unauthorized', message: 'Valid student authentication required.' },
        401
      );
    }
    if (!env.DB) {
      return jsonResponse({ success: false, error: 'Database Unavailable' }, 503);
    }

    // Extract :id from /student/materials/:id/track
    const segments = path.split('/');
    const docIdStr = segments[3]; // ['', 'student', 'materials', ':id', 'track']
    const canonicalDocId = parseInt(docIdStr, 10);

    if (isNaN(canonicalDocId) || canonicalDocId <= 0) {
      return jsonResponse(
        { success: false, error: 'Bad Request', message: 'Valid document ID is required.' },
        400
      );
    }

    let body: any;
    try {
      body = await request.json();
    } catch {
      return jsonResponse(
        { success: false, error: 'Bad Request', message: 'Invalid JSON body.' },
        400
      );
    }

    const actionType = (body?.action_type || '').trim().toUpperCase();
    if (!['VIEW', 'DOWNLOAD', 'ASK_AI'].includes(actionType)) {
      return jsonResponse(
        { success: false, error: 'Validation Error', message: 'action_type must be VIEW, DOWNLOAD, or ASK_AI.' },
        400
      );
    }

    const studentRoll = (body?.student_roll || '').trim();
    if (!studentRoll) {
      return jsonResponse(
        { success: false, error: 'Validation Error', message: 'student_roll is required.' },
        400
      );
    }

    const studentName = (body?.student_name || '').trim() || null;
    const branch = (body?.branch || '').trim() || null;
    const section = (body?.section || '').trim() || null;

    try {
      // Verify document exists
      const docExists = await env.DB.prepare(
        'SELECT id FROM canonical_documents WHERE id = ?'
      )
        .bind(canonicalDocId)
        .first();

      if (!docExists) {
        return jsonResponse(
          { success: false, error: 'Not Found', message: 'Document not found.' },
          404
        );
      }

      await env.DB.prepare(
        `INSERT INTO student_material_interactions
         (canonical_doc_id, student_uid, student_roll, student_name, branch, section, action_type)
         VALUES (?, ?, ?, ?, ?, ?, ?)`
      )
        .bind(canonicalDocId, student.uid, studentRoll, studentName, branch, section, actionType)
        .run();

      return jsonResponse({
        success: true,
        message: `${actionType} interaction recorded for document #${canonicalDocId}.`,
      });
    } catch (err: any) {
      console.error('[Student Track] Error:', err?.message);
      return jsonResponse(
        { success: false, error: 'Database Error', message: err?.message || 'Failed to record interaction.' },
        500
      );
    }
  }

  // No route matched — return null to let the main router continue
  return null;
}
