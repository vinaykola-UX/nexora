/**
 * ============================================================================
 * BVC Nexora Phase 4 — Vector Sync Service
 * ============================================================================
 *
 * Handles D1 ↔ Cloudflare Vectorize synchronization.
 *
 * RULES:
 * - Every D1 chunk gets a deterministic Vectorize ID: "chunk:<D1_CHUNK_ID>"
 * - D1 remains the authoritative content store.
 * - Vectorize stores semantic index only.
 * - Upserts are idempotent — safe to run multiple times.
 * - Does NOT delete D1 data on vector failure.
 * - Reports failures explicitly, never silently.
 * ============================================================================
 */

import { embedBatch, chunkVectorId, EMBEDDING_CONFIG } from './embedding_service';

export interface VectorSyncInput {
  chunkId: number;
  documentId: number;
  content: string;
  title: string;
  subject: string;
  unit: number;
  chunkIndex: number;
  topic?: string;
  source?: string;
  page_info?: string;
}

export interface VectorSyncResult {
  chunkId: number;
  vectorId: string;
  status: 'success' | 'failed';
  error?: string;
}

export interface BackfillResult {
  totalChunks: number;
  vectorized: number;
  failed: number;
  results: VectorSyncResult[];
  vectorStatus: 'complete' | 'partial' | 'failed' | 'unavailable';
}

/** Maximum vectors per Vectorize upsert call */
const VECTORIZE_BATCH_SIZE = 100;
/** Maximum text inputs per Workers AI embedding call */
const EMBED_BATCH_SIZE = 20;

/**
 * Upserts a single chunk's vector into Vectorize.
 * Idempotent — calling twice with the same vector ID overwrites safely.
 */
export async function syncChunkToVectorize(
  chunk: VectorSyncInput,
  env: { AI?: any; VECTORIZE?: any; EMBEDDING_MODEL?: string }
): Promise<VectorSyncResult> {
  const vectorId = chunkVectorId(chunk.chunkId);

  if (!env.VECTORIZE) {
    return { chunkId: chunk.chunkId, vectorId, status: 'failed', error: 'VECTORIZE binding not available' };
  }

  try {
    const embResult = await embedBatch([chunk.content], env);
    const embedding = embResult[0];

    const vectorMetadata: Record<string, string | number> = {
      chunk_id: chunk.chunkId,
      document_id: chunk.documentId,
      subject: chunk.subject,
      unit: chunk.unit,
      chunk_index: chunk.chunkIndex,
      title: chunk.title.slice(0, 128),
    };
    if (chunk.topic) vectorMetadata['topic'] = chunk.topic.slice(0, 64);
    if (chunk.source) vectorMetadata['source'] = chunk.source.slice(0, 128);
    if (chunk.page_info) vectorMetadata['page_info'] = chunk.page_info.slice(0, 64);

    await env.VECTORIZE.upsert([
      {
        id: vectorId,
        values: embedding.vector,
        metadata: vectorMetadata,
      },
    ]);

    return { chunkId: chunk.chunkId, vectorId, status: 'success' };
  } catch (err: any) {
    const errMsg = err?.message || String(err);
    console.error(`[VectorSync] Failed to sync chunk ${chunk.chunkId}:`, errMsg);
    return { chunkId: chunk.chunkId, vectorId, status: 'failed', error: errMsg };
  }
}

/**
 * Backfills all provided chunks to Vectorize in batches.
 * Idempotent — safe to re-run; existing vectors are overwritten (not duplicated).
 */
export async function backfillChunksToVectorize(
  chunks: VectorSyncInput[],
  env: { AI?: any; VECTORIZE?: any; EMBEDDING_MODEL?: string }
): Promise<BackfillResult> {
  if (!env.VECTORIZE) {
    return {
      totalChunks: chunks.length,
      vectorized: 0,
      failed: chunks.length,
      results: chunks.map((c) => ({
        chunkId: c.chunkId,
        vectorId: chunkVectorId(c.chunkId),
        status: 'failed' as const,
        error: 'VECTORIZE binding not available',
      })),
      vectorStatus: 'unavailable',
    };
  }

  const allResults: VectorSyncResult[] = [];
  let vectorized = 0;
  let failed = 0;

  // Process in embedding batches
  for (let i = 0; i < chunks.length; i += EMBED_BATCH_SIZE) {
    const batch = chunks.slice(i, i + EMBED_BATCH_SIZE);
    const texts = batch.map((c) => c.content);

    let embeddings: number[][] = [];

    try {
      const embResults = await embedBatch(texts, env);
      embeddings = embResults.map((r) => r.vector);
    } catch (embedErr: any) {
      // Embedding batch failed — mark all in this batch as failed
      const errMsg = embedErr?.message || String(embedErr);
      for (const chunk of batch) {
        allResults.push({
          chunkId: chunk.chunkId,
          vectorId: chunkVectorId(chunk.chunkId),
          status: 'failed',
          error: `Embedding error: ${errMsg}`,
        });
        failed++;
      }
      continue;
    }

    // Build Vectorize upsert payload for this embedding batch
    const vectorizeVectors = batch.map((chunk, j) => {
      const metadata: Record<string, string | number> = {
        chunk_id: chunk.chunkId,
        document_id: chunk.documentId,
        subject: chunk.subject,
        unit: chunk.unit,
        chunk_index: chunk.chunkIndex,
        title: chunk.title.slice(0, 128),
      };
      if (chunk.topic) metadata['topic'] = chunk.topic.slice(0, 64);
      if (chunk.source) metadata['source'] = chunk.source.slice(0, 128);
      if (chunk.page_info) metadata['page_info'] = chunk.page_info.slice(0, 64);

      return {
        id: chunkVectorId(chunk.chunkId),
        values: embeddings[j],
        metadata,
      };
    });

    // Upsert to Vectorize in sub-batches
    for (let v = 0; v < vectorizeVectors.length; v += VECTORIZE_BATCH_SIZE) {
      const subBatch = vectorizeVectors.slice(v, v + VECTORIZE_BATCH_SIZE);
      const subChunks = batch.slice(v, v + VECTORIZE_BATCH_SIZE);

      try {
        await env.VECTORIZE.upsert(subBatch);
        for (const chunk of subChunks) {
          allResults.push({ chunkId: chunk.chunkId, vectorId: chunkVectorId(chunk.chunkId), status: 'success' });
          vectorized++;
        }
      } catch (upsertErr: any) {
        const errMsg = upsertErr?.message || String(upsertErr);
        for (const chunk of subChunks) {
          allResults.push({
            chunkId: chunk.chunkId,
            vectorId: chunkVectorId(chunk.chunkId),
            status: 'failed',
            error: `Vectorize upsert error: ${errMsg}`,
          });
          failed++;
        }
      }
    }
  }

  const vectorStatus: BackfillResult['vectorStatus'] =
    failed === 0 ? 'complete' : vectorized === 0 ? 'failed' : 'partial';

  return { totalChunks: chunks.length, vectorized, failed, results: allResults, vectorStatus };
}
