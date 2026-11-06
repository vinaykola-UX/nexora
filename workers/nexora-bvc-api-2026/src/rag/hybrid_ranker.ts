/**
 * ============================================================================
 * BVC Nexora Phase 4 & Phase 5 — Hybrid Ranker & Reciprocal Rank Fusion (RRF)
 * ============================================================================
 *
 * Combines three retrieval signal sources into a single relevance score:
 *
 *   ADS Score    (40%) — Hash Table + AVL + Graph keyword/structural matching
 *   Vector Score (35%) — Cosine similarity from Vectorize semantic search
 *   Graph Score  (25%) — Knowledge Graph concept relationship boost
 *
 * STRATEGIES SUPPORTED:
 * 1. 'weighted' (default):
 *    - All scores are normalized to [0, 1] before weighting.
 *    - If Vectorize is unavailable, ADS weight increases to 60%, Graph to 40%.
 *    - If Graph is unavailable, ADS weight increases to 55%, Vector to 45%.
 *    - Never returns negative scores.
 *
 * 2. 'rrf' (Reciprocal Rank Fusion):
 *    - RRF Score = Σ 1 / (k + rank_i)
 *    - Default k = 60 (RRF_CONFIG.DEFAULT_K)
 *    - Standard competition ranking for tied scores.
 *    - Preserves deterministic tie-breaking using chunkId ascending.
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

/** Default constant k for Reciprocal Rank Fusion */
export const RRF_CONFIG = {
  DEFAULT_K: 60,
} as const;

export type RankingStrategy = 'weighted' | 'rrf';

export interface HybridScoreInput {
  chunkId: number;
  adsScore: number;         // Raw ADS pipeline score (unnormalized)
  vectorScore: number;      // Cosine similarity [0, 1] from Vectorize
  graphScore: number;       // Graph proximity boost (unnormalized)
}

export interface HybridRankingOptions {
  vectorAvailable?: boolean;
  graphAvailable?: boolean;
  strategy?: RankingStrategy;
  rrfK?: number;
}

export interface HybridScoreOutput {
  chunkId: number;
  hybridScore: number;      // Final weighted or normalized RRF score [0, 1]
  normalizedAds: number;
  normalizedVector: number;
  normalizedGraph: number;
  weightsUsed: {
    ads: number;
    vector: number;
    graph: number;
    strategy?: RankingStrategy;
    rrfK?: number;
  };
  strategy?: RankingStrategy;
  rrfScore?: number;
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
 * Assigns competition ranks (1, 2, 2, 4...) to candidates based on score.
 * Tied scores receive the exact same rank.
 */
function assignRanks<T extends { chunkId: number }>(
  items: T[],
  getScore: (item: T) => number
): Map<number, number> {
  const rankMap = new Map<number, number>();
  if (items.length === 0) return rankMap;

  // Sort descending by score, deterministic secondary sort by chunkId
  const sorted = [...items].sort((a, b) => getScore(b) - getScore(a) || a.chunkId - b.chunkId);

  let currentRank = 1;
  for (let i = 0; i < sorted.length; i++) {
    if (i > 0 && getScore(sorted[i]) < getScore(sorted[i - 1])) {
      currentRank = i + 1;
    }
    rankMap.set(sorted[i].chunkId, currentRank);
  }

  return rankMap;
}

/**
 * Calculates Reciprocal Rank Fusion (RRF) scores across retrieval channels.
 * Formula: RRF Score = Σ 1 / (k + rank)
 */
export function calculateRRFScores(
  candidates: HybridScoreInput[],
  options?: {
    vectorAvailable?: boolean;
    graphAvailable?: boolean;
    rrfK?: number;
  }
): HybridScoreOutput[] {
  if (candidates.length === 0) return [];

  const k = options?.rrfK ?? RRF_CONFIG.DEFAULT_K;
  const vectorAvailable = options?.vectorAvailable ?? true;
  const graphAvailable = options?.graphAvailable ?? true;

  // Compute ranks per signal with tie-handling
  const adsCandidates = candidates.filter((c) => c.adsScore > 0);
  const adsRankMap = assignRanks(adsCandidates, (c) => c.adsScore);

  let vecRankMap = new Map<number, number>();
  if (vectorAvailable) {
    const vecCandidates = candidates.filter((c) => c.vectorScore > 0);
    vecRankMap = assignRanks(vecCandidates, (c) => c.vectorScore);
  }

  let graphRankMap = new Map<number, number>();
  if (graphAvailable) {
    const graphCandidates = candidates.filter((c) => c.graphScore > 0);
    graphRankMap = assignRanks(graphCandidates, (c) => c.graphScore);
  }

  // Find max values for individual normalization (so normalized fields remain informative)
  let maxAds = 0;
  let maxGraph = 0;
  for (const c of candidates) {
    if (c.adsScore > maxAds) maxAds = c.adsScore;
    if (c.graphScore > maxGraph) maxGraph = c.graphScore;
  }

  // Count active signals
  let activeSignalCount = 1; // ADS always active
  if (vectorAvailable) activeSignalCount++;
  if (graphAvailable) activeSignalCount++;

  // Max theoretical RRF score = activeSignalCount / (k + 1)
  const maxPossibleRrf = activeSignalCount * (1.0 / (k + 1));

  return candidates.map((c) => {
    let rrf = 0;
    const rAds = adsRankMap.get(c.chunkId);
    if (rAds !== undefined) {
      rrf += 1.0 / (k + rAds);
    }

    if (vectorAvailable) {
      const rVec = vecRankMap.get(c.chunkId);
      if (rVec !== undefined) {
        rrf += 1.0 / (k + rVec);
      }
    }

    if (graphAvailable) {
      const rGraph = graphRankMap.get(c.chunkId);
      if (rGraph !== undefined) {
        rrf += 1.0 / (k + rGraph);
      }
    }

    // Normalized to [0, 1] relative to theoretical maximum
    const normalizedRrf = Math.min(1.0, rrf / maxPossibleRrf);

    return {
      chunkId: c.chunkId,
      hybridScore: Math.round(normalizedRrf * 10000) / 10000,
      normalizedAds: Math.round(normalize(c.adsScore, maxAds) * 10000) / 10000,
      normalizedVector: Math.round(Math.max(0, Math.min(1, c.vectorScore)) * 10000) / 10000,
      normalizedGraph: Math.round(normalize(c.graphScore, maxGraph) * 10000) / 10000,
      weightsUsed: {
        ads: 0,
        vector: 0,
        graph: 0,
        strategy: 'rrf',
        rrfK: k,
      },
      strategy: 'rrf',
      rrfScore: Math.round(rrf * 100000) / 100000,
    };
  });
}

/**
 * Calculates hybrid scores for a batch of candidates.
 * Supports both standard 'weighted' ranking and 'rrf' (Reciprocal Rank Fusion).
 * Automatically selects weight configuration based on signal availability.
 */
export function calculateHybridScores(
  candidates: HybridScoreInput[],
  options?: HybridRankingOptions
): HybridScoreOutput[] {
  if (candidates.length === 0) return [];

  const strategy = options?.strategy ?? 'weighted';

  if (strategy === 'rrf') {
    return calculateRRFScores(candidates, options);
  }

  const vectorAvailable = options?.vectorAvailable ?? true;
  const graphAvailable = options?.graphAvailable ?? true;

  // Select weight configuration
  let weights: { ADS: number; VECTOR: number; GRAPH: number } = { ...HYBRID_WEIGHTS };
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
        strategy: 'weighted',
      },
      strategy: 'weighted',
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
