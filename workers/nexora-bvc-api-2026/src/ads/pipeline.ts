/**
 * ============================================================================
 * BVC Nexora ADS Engine — Component 6: ADS Search Pipeline
 * ============================================================================
 * 
 * ADS VIVA SPECIFICATION:
 * - What it is:
 *   The unified algorithmic retrieval engine for BVC Nexora AI. Integrates
 *   five foundational data structures into a staged retrieval pipeline:
 * 
 *   User Query
 *       ↓
 *   Hash Table Lookup (O(1) keyword → candidate chunk indexes)
 *       ↓
 *   AVL Tree (O(log n) prefix & topic index)
 *       ↓
 *   Knowledge Graph (BFS/DFS related concept traversal, O(V+E))
 *       ↓
 *   D1 Candidate Retrieval
 *       ↓
 *   Max-Heap (O(k log n) Top-K relevance ranking)
 *       ↓
 *   Merge Sort (O(n log n) stable tie-breaking and final ordering)
 *       ↓
 *   Best Academic Results
 * 
 * - Performance / Caching:
 *   Maintains in-memory singleton indexes between Cloudflare Worker invocations.
 *   Only rebuilds when the underlying D1 document count or hash changes.
 * ============================================================================
 */

import { CustomHashTable } from './hash_table';
import { AVLTree } from './avl_tree';
import { KnowledgeGraph } from './graph';
import { MaxHeap } from './heap';
import { mergeSort } from './sorting';

export interface ChunkItem {
  id?: number;
  document_id?: number;
  content: string;
  title: string;
  subject: string;
  unit: number;
  chunk_index: number;
}

export interface RankedChunk {
  content: string;
  title: string;
  subject: string;
  unit: number;
  chunk_index: number;
  relevanceScore: number;
  scoreBreakdown?: {
    exactPhraseScore: number;
    hashTokenScore: number;
    avlTopicScore: number;
    graphBoostScore: number;
    metadataScore: number;
  };
}

export interface PipelineDebugInfo {
  hashLookups: Array<{ term: string; matchesFound: number }>;
  avlPrefixMatches: Array<{ prefix: string; topicsFound: string[] }>;
  graphRelatedConcepts: Array<{ concept: string; boostWeight: number }>;
  candidateCountBeforeHeap: number;
  heapTopKExtracted: number;
  sortingAlgorithm: string;
  timingsMs: {
    hashLookup: number;
    avlLookup: number;
    graphTraversal: number;
    heapRanking: number;
    mergeSort: number;
    totalPipeline: number;
  };
  adsVivaMetadata: {
    hashTableCapacity: number;
    hashTableEntries: number;
    avlTreeNodes: number;
    avlTreeHeight: number;
    avlRotations: { ll: number; rr: number; lr: number; rl: number };
    graphVertices: number;
    graphEdges: number;
  };
}

export class ADSSearchPipeline {
  private static instance: ADSSearchPipeline | null = null;

  private hashTable: CustomHashTable<number[]> = new CustomHashTable<number[]>(61);
  private avlTree: AVLTree<number[]> = new AVLTree<number[]>();
  private graph: KnowledgeGraph = new KnowledgeGraph();
  private indexedChunks: ChunkItem[] = [];
  private lastIndexFingerprint = '';

  private readonly stopWords = new Set([
    'what', 'is', 'a', 'an', 'the', 'for', 'in', 'of', 'and', 'to', 'how',
    'why', 'when', 'where', 'who', 'can', 'i', 'get', 'my', 'me', 'please',
    'tell', 'about', 'write', 'implement', 'give', 'bvcec', 'bvc',
  ]);

  private constructor() {}

  /**
   * Singleton accessor for in-memory worker reuse across requests.
   */
  public static getInstance(): ADSSearchPipeline {
    if (!ADSSearchPipeline.instance) {
      ADSSearchPipeline.instance = new ADSSearchPipeline();
    }
    return ADSSearchPipeline.instance;
  }

  /**
   * Builds or updates ADS indexes from D1 chunks.
   * Re-uses existing indexes if the knowledge fingerprint has not changed.
   */
  public buildIndex(chunks: ChunkItem[], forceRebuild = false): void {
    const fingerprint = `${chunks.length}:${chunks.map((c) => c.title).join('|')}`;
    if (!forceRebuild && this.lastIndexFingerprint === fingerprint && this.indexedChunks.length > 0) {
      return; // Cache valid
    }

    // Initialize fresh ADS structures
    this.hashTable = new CustomHashTable<number[]>(Math.max(61, chunks.length * 5));
    this.avlTree = new AVLTree<number[]>();
    this.graph = new KnowledgeGraph();
    this.indexedChunks = chunks;
    this.lastIndexFingerprint = fingerprint;

    for (let idx = 0; idx < chunks.length; idx++) {
      const chunk = chunks[idx];
      const text = `${chunk.title} ${chunk.subject} ${chunk.content}`.toLowerCase();

      // 1. Dynamic Graph vertex derivation
      this.graph.attachDocumentMetadata(
        chunk.document_id || idx + 1,
        chunk.title,
        chunk.subject,
        chunk.unit
      );

      // 2. Tokenize & index into Hash Table
      const terms = text
        .replace(/[^a-z0-9\s]/g, ' ')
        .split(/\s+/)
        .filter((w) => w.length > 2 && !this.stopWords.has(w));

      for (const term of terms) {
        // Hash Table posting list: term -> chunk index list
        const existing = this.hashTable.get(term) || [];
        if (!existing.includes(idx)) {
          existing.push(idx);
          this.hashTable.set(term, existing);
        }
      }

      // 3. Index topics and title keywords into AVL Tree
      const topicTerms = `${chunk.title} ${chunk.subject}`
        .toLowerCase()
        .replace(/[^a-z0-9\s]/g, ' ')
        .split(/\s+/)
        .filter((w) => w.length > 2 && !this.stopWords.has(w));

      for (const tTerm of topicTerms) {
        const existingAvl = this.avlTree.search(tTerm) || [];
        if (!existingAvl.includes(idx)) {
          existingAvl.push(idx);
          this.avlTree.insert(tTerm, existingAvl);
        }
      }
    }
  }

  /**
   * Executes the full ADS search and ranking pipeline.
   */
  public search(
    query: string,
    topK = 5,
    includeDebug = false
  ): { results: RankedChunk[]; debug?: PipelineDebugInfo } {
    const totalStart = performance.now();
    const trimmedQuery = query.trim();
    const lowerQuery = trimmedQuery.toLowerCase();

    // Tokenize student query
    const queryTerms = lowerQuery
      .replace(/[^a-z0-9\s]/g, ' ')
      .split(/\s+/)
      .filter((w) => w.length > 2 && !this.stopWords.has(w));

    // ----------------------------------------------------
    // STAGE 1: Hash Table Lookup (O(1) per token)
    // ----------------------------------------------------
    const tHashStart = performance.now();
    const candidateScores = new Map<number, { exact: number; hash: number; avl: number; graph: number; meta: number }>();
    const hashDebug: Array<{ term: string; matchesFound: number }> = [];

    const getCandidate = (idx: number) => {
      if (!candidateScores.has(idx)) {
        candidateScores.set(idx, { exact: 0, hash: 0, avl: 0, graph: 0, meta: 0 });
      }
      return candidateScores.get(idx)!;
    };

    for (const term of queryTerms) {
      const matchingIndices = this.hashTable.get(term) || [];
      hashDebug.push({ term, matchesFound: matchingIndices.length });

      for (const idx of matchingIndices) {
        const c = getCandidate(idx);
        c.hash += 6.0; // 6 points per matching keyword token
      }
    }
    const tHashEnd = performance.now();

    // ----------------------------------------------------
    // STAGE 2: AVL Tree Prefix & Topic Search (O(log n))
    // ----------------------------------------------------
    const tAvlStart = performance.now();
    const avlDebug: Array<{ prefix: string; topicsFound: string[] }> = [];

    for (const term of queryTerms) {
      // Prefix search on AVL tree (e.g. "single" or "inher")
      const prefixMatches = this.avlTree.searchPrefix(term.substring(0, Math.min(term.length, 5)));
      const matchedKeys: string[] = [];

      for (const match of prefixMatches) {
        matchedKeys.push(match.key);
        for (const idx of match.value) {
          const c = getCandidate(idx);
          c.avl += 4.0; // 4 points per AVL topic match
        }
      }
      avlDebug.push({ prefix: term, topicsFound: matchedKeys.slice(0, 5) });
    }
    const tAvlEnd = performance.now();

    // ----------------------------------------------------
    // STAGE 3: Knowledge Graph BFS / DFS Traversal (O(V+E))
    // ----------------------------------------------------
    const tGraphStart = performance.now();
    const relatedConcepts = this.graph.getRelatedConcepts(queryTerms);
    const graphDebug: Array<{ concept: string; boostWeight: number }> = [];

    for (const [concept, boostWeight] of relatedConcepts.entries()) {
      graphDebug.push({ concept, boostWeight });

      // Boost candidate chunks that contain this related concept
      for (let idx = 0; idx < this.indexedChunks.length; idx++) {
        const chunk = this.indexedChunks[idx];
        const fullChunkText = `${chunk.title} ${chunk.content}`.toLowerCase();

        if (fullChunkText.includes(concept)) {
          const c = getCandidate(idx);
          c.graph += boostWeight * 8.0; // Graph proximity boost
        }
      }
    }
    const tGraphEnd = performance.now();

    // ----------------------------------------------------
    // STAGE 4: Candidate Scoring & Evaluation
    // ----------------------------------------------------
    for (let idx = 0; idx < this.indexedChunks.length; idx++) {
      const chunk = this.indexedChunks[idx];
      const fullText = `${chunk.title} ${chunk.subject} ${chunk.content}`.toLowerCase();

      // Exact query match bonus
      if (fullText.includes(lowerQuery)) {
        const c = getCandidate(idx);
        c.exact += 25.0; // High score for exact question / phrase
      }

      // Metadata match bonus (Subject / Topic alignment)
      if (queryTerms.some((t) => chunk.subject.toLowerCase().includes(t) || chunk.title.toLowerCase().includes(t))) {
        const c = getCandidate(idx);
        c.meta += 5.0;
      }
    }

    // ----------------------------------------------------
    // STAGE 5: Max-Heap Priority Queue Ranking (O(k log n))
    // ----------------------------------------------------
    const tHeapStart = performance.now();
    const heap = new MaxHeap<RankedChunk>();

    for (const [chunkIdx, scores] of candidateScores.entries()) {
      const totalScore = scores.exact + scores.hash + scores.avl + scores.graph + scores.meta;
      if (totalScore > 0) {
        const chunk = this.indexedChunks[chunkIdx];
        const ranked: RankedChunk = {
          content: chunk.content,
          title: chunk.title,
          subject: chunk.subject,
          unit: chunk.unit,
          chunk_index: chunk.chunk_index,
          relevanceScore: Math.round(totalScore * 10) / 10,
          scoreBreakdown: {
            exactPhraseScore: scores.exact,
            hashTokenScore: scores.hash,
            avlTopicScore: scores.avl,
            graphBoostScore: Math.round(scores.graph * 10) / 10,
            metadataScore: scores.meta,
          },
        };
        heap.insert(ranked, totalScore);
      }
    }

    const candidateCount = heap.size();
    const topCandidates = heap.extractTopK(topK).map((node) => node.data);
    const tHeapEnd = performance.now();

    // ----------------------------------------------------
    // STAGE 6: Stable Merge Sort Final Ordering (O(n log n))
    // ----------------------------------------------------
    const tSortStart = performance.now();
    // Sort primarily by relevanceScore descending; tie-break by unit asc, chunk_index asc
    const sortedResults = mergeSort(topCandidates, (a, b) => {
      if (b.relevanceScore !== a.relevanceScore) {
        return b.relevanceScore - a.relevanceScore;
      }
      if (a.unit !== b.unit) {
        return a.unit - b.unit;
      }
      return a.chunk_index - b.chunk_index;
    });
    const tSortEnd = performance.now();
    const totalEnd = performance.now();

    // Optional Viva Debug Output
    let debugInfo: PipelineDebugInfo | undefined;
    if (includeDebug) {
      const graphStats = this.graph.getStats();
      debugInfo = {
        hashLookups: hashDebug,
        avlPrefixMatches: avlDebug,
        graphRelatedConcepts: graphDebug.slice(0, 10),
        candidateCountBeforeHeap: candidateCount,
        heapTopKExtracted: topCandidates.length,
        sortingAlgorithm: 'Divide-and-Conquer Stable Merge Sort (O(n log n))',
        timingsMs: {
          hashLookup: Math.round((tHashEnd - tHashStart) * 100) / 100,
          avlLookup: Math.round((tAvlEnd - tAvlStart) * 100) / 100,
          graphTraversal: Math.round((tGraphEnd - tGraphStart) * 100) / 100,
          heapRanking: Math.round((tHeapEnd - tHeapStart) * 100) / 100,
          mergeSort: Math.round((tSortEnd - tSortStart) * 100) / 100,
          totalPipeline: Math.round((totalEnd - totalStart) * 100) / 100,
        },
        adsVivaMetadata: {
          hashTableCapacity: this.hashTable.getCapacity(),
          hashTableEntries: this.hashTable.size(),
          avlTreeNodes: this.avlTree.size(),
          avlTreeHeight: this.avlTree.treeHeight(),
          avlRotations: this.avlTree.rotationStats,
          graphVertices: graphStats.vertices,
          graphEdges: graphStats.edges,
        },
      };
    }

    return {
      results: sortedResults,
      debug: debugInfo,
    };
  }
}
