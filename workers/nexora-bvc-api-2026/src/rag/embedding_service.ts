/**
 * ============================================================================
 * BVC Nexora Phase 4 — Embedding Service
 * ============================================================================
 *
 * Wraps Cloudflare Workers AI @cf/baai/bge-small-en-v1.5 embedding model.
 *
 * SPECIFICATION:
 * - Model:     @cf/baai/bge-small-en-v1.5
 * - Dimension: 384
 * - Metric:    cosine (matches nexora-vector-index)
 * - Billing:   Free tier Workers AI allocation (no paid plan required)
 *
 * RULES:
 * - Validates returned vector dimension strictly.
 * - Does NOT truncate/pad vectors on dimension mismatch — fails clearly.
 * - Does NOT generate embeddings unnecessarily (caller controls batching).
 * ============================================================================
 */

/** Expected dimension must match the Vectorize index dimension exactly. */
export const EMBEDDING_CONFIG = {
  MODEL: '@cf/baai/bge-small-en-v1.5',
  DIMENSION: 384,
  METRIC: 'cosine' as const,
  INDEX_NAME: 'nexora-vector-index',
  /** Vectorize vector ID prefix */
  VECTOR_ID_PREFIX: 'chunk:',
} as const;

/**
 * Derives the deterministic Vectorize vector ID for a D1 chunk.
 * Format: "chunk:<D1_CHUNK_ID>"
 */
export function chunkVectorId(chunkId: number): string {
  return `${EMBEDDING_CONFIG.VECTOR_ID_PREFIX}${chunkId}`;
}

/**
 * Parses the D1 chunk ID from a vector ID string.
 */
export function parseChunkIdFromVectorId(vectorId: string): number | null {
  if (!vectorId.startsWith(EMBEDDING_CONFIG.VECTOR_ID_PREFIX)) return null;
  const num = parseInt(vectorId.slice(EMBEDDING_CONFIG.VECTOR_ID_PREFIX.length), 10);
  return isNaN(num) ? null : num;
}

export interface EmbeddingResult {
  vector: number[];
  dimension: number;
  model: string;
}

export interface EmbeddingError {
  error: string;
  model: string;
}

/**
 * Embeds a single text string using Workers AI.
 * Returns the embedding vector or throws a descriptive error.
 */
export async function embedText(
  text: string,
  env: { AI?: any; EMBEDDING_MODEL?: string }
): Promise<EmbeddingResult> {
  if (!env.AI || typeof env.AI.run !== 'function') {
    throw new Error('Workers AI binding (env.AI) is not available. Check wrangler.toml [ai] binding.');
  }

  const model = env.EMBEDDING_MODEL || EMBEDDING_CONFIG.MODEL;
  const truncatedText = text.slice(0, 2000); // BGE-small max safe input

  let response: any;
  try {
    response = await env.AI.run(model, { text: [truncatedText] });
  } catch (err: any) {
    throw new Error(`Workers AI embedding failed for model ${model}: ${err?.message || String(err)}`);
  }

  // Workers AI returns: { shape: [1, 384], data: [[...384 floats...]] }
  const vector: number[] | undefined =
    response?.data?.[0] ??
    response?.result?.data?.[0] ??
    (Array.isArray(response) ? response[0] : undefined);

  if (!vector || !Array.isArray(vector)) {
    throw new Error(`Workers AI returned unexpected embedding format from model ${model}. Response: ${JSON.stringify(response).slice(0, 200)}`);
  }

  const dim = vector.length;
  if (dim !== EMBEDDING_CONFIG.DIMENSION) {
    throw new Error(
      `Dimension mismatch! Model ${model} returned ${dim} dimensions but Vectorize index nexora-vector-index expects ${EMBEDDING_CONFIG.DIMENSION}. ` +
      `Do NOT truncate/pad vectors. Check EMBEDDING_MODEL configuration.`
    );
  }

  return { vector, dimension: dim, model };
}

/**
 * Embeds multiple texts in one call (batch).
 * Workers AI BGE supports up to 100 inputs per call.
 * Falls back to sequential embedding if batch fails.
 */
export async function embedBatch(
  texts: string[],
  env: { AI?: any; EMBEDDING_MODEL?: string }
): Promise<EmbeddingResult[]> {
  if (!env.AI || typeof env.AI.run !== 'function') {
    throw new Error('Workers AI binding (env.AI) is not available.');
  }

  if (texts.length === 0) return [];

  const model = env.EMBEDDING_MODEL || EMBEDDING_CONFIG.MODEL;
  const truncatedTexts = texts.map((t) => t.slice(0, 2000));

  try {
    const response = await env.AI.run(model, { text: truncatedTexts });
    const vectors: number[][] | undefined = response?.data ?? response?.result?.data;

    if (vectors && Array.isArray(vectors) && vectors.length === texts.length) {
      return vectors.map((vector, i) => {
        if (vector.length !== EMBEDDING_CONFIG.DIMENSION) {
          throw new Error(
            `Dimension mismatch at batch index ${i}: got ${vector.length}, expected ${EMBEDDING_CONFIG.DIMENSION}`
          );
        }
        return { vector, dimension: vector.length, model };
      });
    }
  } catch (batchErr: any) {
    console.warn(`[EmbeddingService] Batch embedding failed, falling back to sequential: ${batchErr?.message}`);
  }

  // Sequential fallback
  const results: EmbeddingResult[] = [];
  for (const text of texts) {
    results.push(await embedText(text, env));
  }
  return results;
}
