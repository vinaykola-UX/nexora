/**
 * ============================================================================
 * BVC Nexora Phase 4 — Semantic Search (Vectorize Query)
 * ============================================================================
 *
 * Queries Cloudflare Vectorize for semantically similar chunks,
 * then fetches authoritative content from D1.
 *
 * RULES:
 * - Vectorize is the semantic index only; D1 is authoritative.
 * - Never return Vectorize metadata as the final content.
 * - Always fetch the actual chunk text from D1 using retrieved IDs.
 * - If Vectorize is unavailable, returns empty results with clear status.
 * - Marks vectorStatus='fallback' when falling back to ADS-only search.
 * ============================================================================
 */

import { embedText, parseChunkIdFromVectorId, EMBEDDING_CONFIG } from './embedding_service';

export interface SemanticCandidate {
  chunkId: number;
  vectorId: string;
  score: number;               // cosine similarity [0, 1]
  metadata: Record<string, any>;
}

export interface SemanticSearchResult {
  candidates: SemanticCandidate[];
  vectorStatus: 'success' | 'fallback' | 'unavailable' | 'empty';
  embeddingModel: string;
  queryDimension: number;
  vectorCount: number;
  timingMs: number;
  error?: string;
}

/**
 * Embeds the query and queries Vectorize for top semantic candidates.
 * Returns chunk IDs for D1 lookup — does not return raw content.
 */
export async function semanticSearch(
  query: string,
  topK: number,
  env: { AI?: any; VECTORIZE?: any; EMBEDDING_MODEL?: string }
): Promise<SemanticSearchResult> {
  const t0 = performance.now();
  const model = env.EMBEDDING_MODEL || EMBEDDING_CONFIG.MODEL;

  if (!env.VECTORIZE) {
    return {
      candidates: [],
      vectorStatus: 'unavailable',
      embeddingModel: model,
      queryDimension: 0,
      vectorCount: 0,
      timingMs: 0,
      error: 'VECTORIZE binding not available — check wrangler.toml [[vectorize]] binding.',
    };
  }

  if (!env.AI) {
    return {
      candidates: [],
      vectorStatus: 'fallback',
      embeddingModel: model,
      queryDimension: 0,
      vectorCount: 0,
      timingMs: Math.round(performance.now() - t0),
      error: 'Workers AI binding unavailable — cannot embed query.',
    };
  }

  let queryEmbedding: number[];
  let queryDimension = 0;

  try {
    const embResult = await embedText(query, env);
    queryEmbedding = embResult.vector;
    queryDimension = embResult.dimension;
  } catch (embedErr: any) {
    return {
      candidates: [],
      vectorStatus: 'fallback',
      embeddingModel: model,
      queryDimension: 0,
      vectorCount: 0,
      timingMs: Math.round(performance.now() - t0),
      error: `Query embedding failed: ${embedErr?.message || String(embedErr)}`,
    };
  }

  try {
    const vectorizeResponse = await env.VECTORIZE.query(queryEmbedding, {
      topK: Math.min(topK * 2, 20), // over-fetch for hybrid re-ranking
      returnMetadata: 'indexed',
    });

    const matches = vectorizeResponse?.matches || [];

    const candidates: SemanticCandidate[] = matches
      .filter((m: any) => m?.id && typeof m.score === 'number')
      .map((m: any) => {
        const chunkId = parseChunkIdFromVectorId(m.id);
        return {
          chunkId: chunkId ?? -1,
          vectorId: m.id as string,
          score: m.score as number,
          metadata: m.metadata || {},
        };
      })
      .filter((c: SemanticCandidate) => c.chunkId > 0);

    return {
      candidates,
      vectorStatus: candidates.length > 0 ? 'success' : 'empty',
      embeddingModel: model,
      queryDimension,
      vectorCount: matches.length,
      timingMs: Math.round(performance.now() - t0),
    };
  } catch (queryErr: any) {
    return {
      candidates: [],
      vectorStatus: 'fallback',
      embeddingModel: model,
      queryDimension,
      vectorCount: 0,
      timingMs: Math.round(performance.now() - t0),
      error: `Vectorize query failed: ${queryErr?.message || String(queryErr)}`,
    };
  }
}
