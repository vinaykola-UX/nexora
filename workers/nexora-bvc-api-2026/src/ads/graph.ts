/**
 * ============================================================================
 * BVC Nexora ADS Engine — Component 3: Academic Knowledge Graph & BFS / DFS
 * ============================================================================
 * 
 * ADS VIVA SPECIFICATION:
 * - What it is:
 *   A directed, weighted graph represented as an Adjacency List where vertices 
 *   represent academic entities (Subject, Unit, Topic, Concept) and directed 
 *   edges represent academic relationships (part-of, related-to, prerequisite-of).
 * 
 * - Why Nexora uses it:
 *   Captures structural curriculum hierarchy and concept semantics. When a 
 *   student asks about "single inheritance", BFS traverses neighbors to discover 
 *   closely related concepts like "super keyword", "classes", and "polymorphism",
 *   boosting candidate retrieval relevance beyond pure keyword matching.
 * 
 * - Complexity:
 *   - Graph Space: O(V + E) where V is vertices and E is relationship edges
 *   - BFS Traversal: O(V + E) level-by-level exploration using a FIFO queue
 *   - DFS Traversal: O(V + E) deep prerequisite-chain exploration using recursion/stack
 * 
 * - Dual Design:
 *   A. Hardcoded syllabus seed: Core curriculum relationships for BVC B.Tech ADS,
 *      Data Structures, and Java OOP.
 *   B. Dynamic document derivation: Automatically attaches newly ingested units, 
 *      topics, and chunk nodes from D1 metadata.
 * ============================================================================
 */

export type NodeType = 'subject' | 'unit' | 'topic' | 'concept';
export type EdgeType = 'part-of' | 'related-to' | 'prerequisite-of';

export interface GraphNode {
  id: string;             // Unique identifier, e.g. "topic:single_inheritance"
  label: string;          // Human readable display label
  type: NodeType;
  subject?: string;
  unit?: number;
  metadata?: Record<string, any>;
}

export interface GraphEdge {
  targetId: string;
  type: EdgeType;
  weight: number;         // 1.0 for direct hierarchy, 0.8 for related, 0.9 for prerequisite
}

export class KnowledgeGraph {
  private nodes: Map<string, GraphNode> = new Map();
  private adjacencyList: Map<string, GraphEdge[]> = new Map();

  constructor() {
    this.seedCurriculumGraph();
  }

  /**
   * Add or update a vertex in the graph.
   */
  public addNode(node: GraphNode): void {
    const id = node.id.toLowerCase().trim();
    if (!this.nodes.has(id)) {
      this.nodes.set(id, { ...node, id });
      this.adjacencyList.set(id, []);
    }
  }

  /**
   * Add a directed relationship edge.
   * If biDirectional is true (e.g. related-to), adds both directions.
   */
  public addEdge(sourceId: string, targetId: string, type: EdgeType, weight = 1.0, biDirectional = false): void {
    const src = sourceId.toLowerCase().trim();
    const dst = targetId.toLowerCase().trim();

    if (!this.nodes.has(src) || !this.nodes.has(dst)) {
      return; // Source or target node does not exist
    }

    const edges = this.adjacencyList.get(src) || [];
    if (!edges.some((e) => e.targetId === dst && e.type === type)) {
      edges.push({ targetId: dst, type, weight });
      this.adjacencyList.set(src, edges);
    }

    if (biDirectional) {
      const revEdges = this.adjacencyList.get(dst) || [];
      if (!revEdges.some((e) => e.targetId === src && e.type === type)) {
        revEdges.push({ targetId: src, type, weight });
        this.adjacencyList.set(dst, revEdges);
      }
    }
  }

  /**
   * Breadth-First Search (BFS) Traversal
   * 
   * Explores neighbors level-by-level using an explicit FIFO queue.
   * Ideal for finding all related topics within K hops of a query concept.
   * 
   * Time Complexity: O(V + E)
   * Space Complexity: O(V) for visited set & queue
   */
  public bfs(startNodeId: string, maxDepth = 2): Array<{ node: GraphNode; depth: number; weight: number }> {
    const start = startNodeId.toLowerCase().trim();
    if (!this.nodes.has(start)) return [];

    const visited = new Set<string>();
    const queue: Array<{ id: string; depth: number; cumulativeWeight: number }> = [];
    const results: Array<{ node: GraphNode; depth: number; weight: number }> = [];

    queue.push({ id: start, depth: 0, cumulativeWeight: 1.0 });
    visited.add(start);

    while (queue.length > 0) {
      const { id, depth, cumulativeWeight } = queue.shift()!;
      const node = this.nodes.get(id);

      if (node && id !== start) {
        results.push({ node, depth, weight: cumulativeWeight });
      }

      if (depth < maxDepth) {
        const edges = this.adjacencyList.get(id) || [];
        for (const edge of edges) {
          if (!visited.has(edge.targetId)) {
            visited.add(edge.targetId);
            queue.push({
              id: edge.targetId,
              depth: depth + 1,
              cumulativeWeight: cumulativeWeight * edge.weight,
            });
          }
        }
      }
    }

    return results;
  }

  /**
   * Depth-First Search (DFS) Traversal
   * 
   * Explores deep prerequisite chains recursively.
   * Useful for academic syllabus pathways (e.g. Array -> Linked List -> Hash Table).
   * 
   * Time Complexity: O(V + E)
   * Space Complexity: O(V) call stack
   */
  public dfs(startNodeId: string, maxDepth = 3): Array<{ node: GraphNode; depth: number }> {
    const start = startNodeId.toLowerCase().trim();
    if (!this.nodes.has(start)) return [];

    const visited = new Set<string>();
    const results: Array<{ node: GraphNode; depth: number }> = [];

    this.dfsHelper(start, 0, maxDepth, visited, results);
    return results;
  }

  private dfsHelper(
    currentId: string,
    depth: number,
    maxDepth: number,
    visited: Set<string>,
    results: Array<{ node: GraphNode; depth: number }>
  ): void {
    visited.add(currentId);

    if (depth > 0) {
      const node = this.nodes.get(currentId);
      if (node) results.push({ node, depth });
    }

    if (depth >= maxDepth) return;

    const edges = this.adjacencyList.get(currentId) || [];
    for (const edge of edges) {
      if (!visited.has(edge.targetId)) {
        this.dfsHelper(edge.targetId, depth + 1, maxDepth, visited, results);
      }
    }
  }

  /**
   * Finds concepts in the graph matching any of the query terms,
   * then applies BFS to collect neighboring related concepts with proximity weights.
   */
  public getRelatedConcepts(queryTerms: string[]): Map<string, number> {
    const conceptBoosts = new Map<string, number>();

    for (const rawTerm of queryTerms) {
      const term = rawTerm.toLowerCase().trim();
      if (!term || term.length < 3) continue;

      // Find direct matches in graph node IDs or labels
      for (const [nodeId, node] of this.nodes.entries()) {
        if (nodeId.includes(term) || node.label.toLowerCase().includes(term)) {
          // Direct hit gets highest boost
          conceptBoosts.set(node.label.toLowerCase(), 1.0);

          // BFS 1-2 hops away
          const neighbors = this.bfs(nodeId, 2);
          for (const neighbor of neighbors) {
            const key = neighbor.node.label.toLowerCase();
            const currentScore = conceptBoosts.get(key) || 0;
            const newScore = neighbor.weight * (1 / (neighbor.depth + 1));
            if (newScore > currentScore) {
              conceptBoosts.set(key, newScore);
            }
          }
        }
      }
    }

    return conceptBoosts;
  }

  /**
   * Seed Part A: Core BVC B.Tech Syllabus Hierarchy (ADS, DS, Software Engineering)
   * Small, clear, deterministic, and 100% explainable during ADS viva.
   */
  private seedCurriculumGraph(): void {
    // 1. Subjects
    this.addNode({ id: 'subj:ads', label: 'Advanced Data Structures', type: 'subject' });
    this.addNode({ id: 'subj:ds', label: 'Data Structures', type: 'subject' });
    this.addNode({ id: 'subj:se', label: 'Software Engineering', type: 'subject' });

    // 2. Units
    this.addNode({ id: 'unit:ads_1', label: 'Unit 1: Dictionaries & Hashing', type: 'unit', subject: 'Advanced Data Structures', unit: 1 });
    this.addNode({ id: 'unit:ds_2', label: 'Unit 2: Linked Lists', type: 'unit', subject: 'Data Structures', unit: 2 });
    this.addNode({ id: 'unit:se_2', label: 'Unit 2: Java OOP & Inheritance', type: 'unit', subject: 'Software Engineering', unit: 2 });

    this.addEdge('subj:ads', 'unit:ads_1', 'part-of', 1.0);
    this.addEdge('subj:ds', 'unit:ds_2', 'part-of', 1.0);
    this.addEdge('subj:se', 'unit:se_2', 'part-of', 1.0);

    // 3. Topics: Advanced Data Structures Unit 1
    this.addNode({ id: 'topic:dictionaries', label: 'Dictionaries', type: 'topic', subject: 'Advanced Data Structures', unit: 1 });
    this.addNode({ id: 'topic:hash_tables', label: 'Hash Tables', type: 'topic', subject: 'Advanced Data Structures', unit: 1 });
    this.addNode({ id: 'topic:collision_resolution', label: 'Collision Resolution', type: 'topic', subject: 'Advanced Data Structures', unit: 1 });
    this.addNode({ id: 'concept:linear_probing', label: 'Linear Probing', type: 'concept', subject: 'Advanced Data Structures', unit: 1 });
    this.addNode({ id: 'concept:quadratic_probing', label: 'Quadratic Probing', type: 'concept', subject: 'Advanced Data Structures', unit: 1 });
    this.addNode({ id: 'concept:separate_chaining', label: 'Separate Chaining', type: 'concept', subject: 'Advanced Data Structures', unit: 1 });

    this.addEdge('unit:ads_1', 'topic:dictionaries', 'part-of', 1.0);
    this.addEdge('unit:ads_1', 'topic:hash_tables', 'part-of', 1.0);
    this.addEdge('unit:ads_1', 'topic:collision_resolution', 'part-of', 1.0);
    this.addEdge('topic:dictionaries', 'topic:hash_tables', 'related-to', 0.9, true);
    this.addEdge('topic:hash_tables', 'topic:collision_resolution', 'prerequisite-of', 0.95);
    this.addEdge('topic:collision_resolution', 'concept:linear_probing', 'part-of', 0.9);
    this.addEdge('topic:collision_resolution', 'concept:quadratic_probing', 'part-of', 0.9);
    this.addEdge('topic:collision_resolution', 'concept:separate_chaining', 'part-of', 0.9);
    this.addEdge('concept:linear_probing', 'concept:separate_chaining', 'related-to', 0.8, true);

    // 4. Topics: Data Structures Unit 2
    this.addNode({ id: 'topic:singly_linked_list', label: 'Singly Linked List', type: 'topic', subject: 'Data Structures', unit: 2 });
    this.addNode({ id: 'topic:doubly_linked_list', label: 'Doubly Linked List', type: 'topic', subject: 'Data Structures', unit: 2 });
    this.addNode({ id: 'topic:circular_linked_list', label: 'Circular Linked List', type: 'topic', subject: 'Data Structures', unit: 2 });

    this.addEdge('unit:ds_2', 'topic:singly_linked_list', 'part-of', 1.0);
    this.addEdge('unit:ds_2', 'topic:doubly_linked_list', 'part-of', 1.0);
    this.addEdge('unit:ds_2', 'topic:circular_linked_list', 'part-of', 1.0);
    this.addEdge('topic:singly_linked_list', 'topic:doubly_linked_list', 'related-to', 0.85, true);
    this.addEdge('topic:doubly_linked_list', 'topic:circular_linked_list', 'related-to', 0.85, true);

    // Cross-curriculum prerequisite: Linked List is a prerequisite for Separate Chaining
    this.addEdge('topic:singly_linked_list', 'concept:separate_chaining', 'prerequisite-of', 0.9);

    // 5. Topics: Software Engineering Unit 2
    this.addNode({ id: 'topic:single_inheritance', label: 'Single Inheritance', type: 'topic', subject: 'Software Engineering', unit: 2 });
    this.addNode({ id: 'topic:multilevel_inheritance', label: 'Multilevel Inheritance', type: 'topic', subject: 'Software Engineering', unit: 2 });
    this.addNode({ id: 'topic:super_keyword', label: 'Super Keyword', type: 'topic', subject: 'Software Engineering', unit: 2 });
    this.addNode({ id: 'topic:abstract_classes', label: 'Abstract Classes', type: 'topic', subject: 'Software Engineering', unit: 2 });
    this.addNode({ id: 'topic:polymorphism', label: 'Polymorphism', type: 'topic', subject: 'Software Engineering', unit: 2 });

    this.addEdge('unit:se_2', 'topic:single_inheritance', 'part-of', 1.0);
    this.addEdge('unit:se_2', 'topic:multilevel_inheritance', 'part-of', 1.0);
    this.addEdge('unit:se_2', 'topic:super_keyword', 'part-of', 1.0);
    this.addEdge('unit:se_2', 'topic:abstract_classes', 'part-of', 1.0);
    this.addEdge('unit:se_2', 'topic:polymorphism', 'part-of', 1.0);

    this.addEdge('topic:single_inheritance', 'topic:multilevel_inheritance', 'related-to', 0.9, true);
    this.addEdge('topic:single_inheritance', 'topic:super_keyword', 'related-to', 0.85, true);
    this.addEdge('topic:abstract_classes', 'topic:polymorphism', 'related-to', 0.9, true);
  }

  /**
   * Seed Part B: Dynamically attaches document and chunk nodes from ingested D1 knowledge
   */
  public attachDocumentMetadata(docId: number, title: string, subject: string, unit: number, topic?: string): void {
    const docNodeId = `doc:${docId}`;
    this.addNode({
      id: docNodeId,
      label: title,
      type: 'topic',
      subject,
      unit,
    });

    const unitNodeId = `unit:${subject.toLowerCase().replace(/\s+/g, '_')}_${unit}`;
    this.addNode({
      id: unitNodeId,
      label: `${subject} Unit ${unit}`,
      type: 'unit',
      subject,
      unit,
    });

    this.addEdge(unitNodeId, docNodeId, 'part-of', 1.0);

    if (topic && topic.trim()) {
      const topicNodeId = `topic:${topic.toLowerCase().replace(/[^a-z0-9]/g, '_')}`;
      this.addNode({
        id: topicNodeId,
        label: topic,
        type: 'concept',
        subject,
        unit,
      });
      this.addEdge(docNodeId, topicNodeId, 'part-of', 0.95);
    }
  }

  /**
   * Diagnostic statistics for ADS viva
   */
  public getStats(): { vertices: number; edges: number } {
    let edgeCount = 0;
    for (const edges of this.adjacencyList.values()) {
      edgeCount += edges.length;
    }
    return {
      vertices: this.nodes.size,
      edges: edgeCount,
    };
  }

  public getNode(id: string): GraphNode | undefined {
    return this.nodes.get(id.toLowerCase().trim());
  }
}
