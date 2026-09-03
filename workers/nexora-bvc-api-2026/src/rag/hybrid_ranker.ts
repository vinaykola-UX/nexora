/**
 * ============================================================================
 * BVC Nexora Phase 4 — Hybrid Ranker
 * ============================================================================
 *
 * Combines three retrieval signal sources into a single hybrid relevance score:
 *
 *   ADS Score    (40%) — Hash Table + AVL + Graph keyword/structural matching
 *   Vector Score (35%) — Cosine similarity from Vectorize semantic search
 *   Graph Score  (25%) — Knowledge Graph concept relationship boost
 *
 * RULES:
 * - All scores are normalized to [0, 1] before weighting.
 * - If Vectorize is unavailable, ADS weight increases to 60%, Graph to 40%.
 * - If Graph is unavailable, ADS weight increases to 55%, Vector to 45%.
 * - Never returns negative scores.
 * ============================================================================
 */

export const HYBRID_WEIGHTS = {
  ADS: 0.40,
  VECTOR: 0.35,
  GRAPH: 0.25,
} as const;

/** Fallback weights when Vectorize is unavailable */
export const FALLBACK_WEIGHTS_NO_VECTOR = {
  ADS: 0.60,
  VECTOR: 0.0,
  GRAPH: 0.40,
} as const;

/** Fallback weights when Graph is unavailable */
export const FALLBACK_WEIGHTS_NO_GRAPH = {
  ADS: 0.55,
  VECTOR: 0.45,
  GRAPH: 0.0,
} as const;

export interface HybridScoreInput {
  chunkId: number;
  adsScore: number;         // Raw ADS pipeline score (unnormalized)
  vectorScore: number;      // Cosine similarity [0, 1] from Vectorize
  graphScore: number;       // Graph proximity boost (unnormalized)
}

export interface HybridScoreOutput {
  chunkId: number;
  hybridScore: number;      // Final weighted score [0, 1]
  normalizedAds: number;
  normalizedVector: number;
  normalizedGraph: number;
  weightsUsed: { ads: number; vector: number; graph: number };
}

/**
 * Normalizes a raw score to [0, 1] given the max observed value.
 * Returns 0 if maxVal is 0 or score is negative.
 */
function normalize(score: number, maxVal: number): number {
  if (maxVal <= 0 || score <= 0) return 0;
  return Math.min(score / maxVal, 1.0);
}

/**
 * Calculates hybrid scores for a batch of candidates.
 * Automatically selects weight configuration based on signal availability.
 */
export function calculateHybridScores(
  candidates: HybridScoreInput[],
  options?: {
    vectorAvailable?: boolean;
    graphAvailable?: boolean;
  }
): HybridScoreOutput[] {
  if (candidates.length === 0) return [];

  const vectorAvailable = options?.vectorAvailable ?? true;
  const graphAvailable = options?.graphAvailable ?? true;

  // Select weight configuration
  let weights = { ...HYBRID_WEIGHTS };
  if (!vectorAvailable && !graphAvailable) {
    weights = { ADS: 1.0, VECTOR: 0.0, GRAPH: 0.0 };
  } else if (!vectorAvailable) {
    weights = { ...FALLBACK_WEIGHTS_NO_VECTOR };
  } else if (!graphAvailable) {
    weights = { ...FALLBACK_WEIGHTS_NO_GRAPH };
  }

  // Find max values for normalization
  let maxAds = 0;
  let maxGraph = 0;
  for (const c of candidates) {
    if (c.adsScore > maxAds) maxAds = c.adsScore;
    if (c.graphScore > maxGraph) maxGraph = c.graphScore;
  }

  // Vector scores are already in [0, 1] (cosine similarity), no normalization needed

  return candidates.map((c) => {
    const normalizedAds = normalize(c.adsScore, maxAds);
    const normalizedVector = Math.max(0, Math.min(1, c.vectorScore));
    const normalizedGraph = normalize(c.graphScore, maxGraph);

    const hybridScore =
      weights.ADS * normalizedAds +
      weights.VECTOR * normalizedVector +
      weights.GRAPH * normalizedGraph;

    return {
      chunkId: c.chunkId,
      hybridScore: Math.round(hybridScore * 10000) / 10000,
      normalizedAds: Math.round(normalizedAds * 10000) / 10000,
      normalizedVector: Math.round(normalizedVector * 10000) / 10000,
      normalizedGraph: Math.round(normalizedGraph * 10000) / 10000,
      weightsUsed: {
        ads: weights.ADS,
        vector: weights.VECTOR,
        graph: weights.GRAPH,
      },
    };
  });
}

/**
 * Merge ADS results, vector candidates, and graph scores into unified candidates.
 * Maps by chunkId to combine signals from all three sources.
 */
export function mergeRetrievalSignals(
  adsResults: Array<{ chunkId: number; adsScore: number }>,
  vectorCandidates: Array<{ chunkId: number; vectorScore: number }>,
  graphScores?: Map<number, number>
): HybridScoreInput[] {
  const mergedMap = new Map<number, HybridScoreInput>();

  // Seed from ADS results
  for (const r of adsResults) {
    mergedMap.set(r.chunkId, {
      chunkId: r.chunkId,
      adsScore: r.adsScore,
      vectorScore: 0,
      graphScore: 0,
    });
  }

  // Merge vector scores
  for (const v of vectorCandidates) {
    const existing = mergedMap.get(v.chunkId);
    if (existing) {
      existing.vectorScore = v.vectorScore;
    } else {
      mergedMap.set(v.chunkId, {
        chunkId: v.chunkId,
        adsScore: 0,
        vectorScore: v.vectorScore,
        graphScore: 0,
      });
    }
  }

  // Merge graph scores
  if (graphScores) {
    for (const [chunkId, score] of graphScores.entries()) {
      const existing = mergedMap.get(chunkId);
      if (existing) {
        existing.graphScore = score;
      } else {
        mergedMap.set(chunkId, {
          chunkId,
          adsScore: 0,
          vectorScore: 0,
          graphScore: score,
        });
      }
    }
  }

  return Array.from(mergedMap.values());
}
