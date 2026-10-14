/**
 * ============================================================================
 * BVC Nexora — Visual Study Prompt Engine
 * ============================================================================
 *
 * Dynamically generates AI image-generation prompts based on academic context.
 *
 * When a student asks about a syllabus unit, topic workflow, or concept
 * diagram (e.g. "generate 2nd unit syllabus based workflow image", "show me CADS unit 2 diagram"),
 * this engine:
 *   1. Analyzes user message, conversation context, and retrieved knowledge chunks
 *   2. Accurately extracts subject, unit number (supports "2nd unit", "2nd unity", "unit 2", "second unit"), and topics
 *   3. If chunks lack detailed topics, falls back to the authoritative BVC Curriculum Syllabus Map
 *   4. Crafts a precise, descriptive image-generation prompt suitable for
 *      AI image generators (Midjourney v6, DALL-E 3, Stable Diffusion XL, or Cloudflare Workers AI)
 *   5. Generates structured Mermaid workflow diagrams for in-chat visualization
 *
 * RULES:
 * - Robust against typos ("unity", "syllubs", "imag", "diag").
 * - Prompts must be self-contained for text-to-image AI models.
 * - Optimized for educational infographics and workflow diagrams.
 * ============================================================================
 */

import { RankedChunk } from '../ads/pipeline';

export interface VisualPromptResult {
  /** The generated image-generation prompt */
  imagePrompt: string;
  /** Short display title for the visual */
  title: string;
  /** Detected visual style */
  style: VisualStyle;
  /** Subject extracted from context */
  subject: string;
  /** Unit number extracted from context */
  unit: number;
  /** Key topics extracted or mapped */
  topics: string[];
  /** Mermaid diagram syntax for web rendering */
  mermaidDiagram: string;
  /** Whether sufficient context was found to generate a meaningful prompt */
  hasContext: boolean;
}

export type VisualStyle =
  | 'flowchart'
  | 'mind_map'
  | 'infographic'
  | 'timeline'
  | 'concept_diagram'
  | 'comparison_table'
  | 'hierarchy';

/**
 * Authoritative BVC B.Tech Curriculum Map for Core Subjects & Units 1–5.
 * Used when retrieved D1 chunks do not have granular topic breakdowns.
 */
export const BVC_CURRICULUM_TOPIC_MAP: Record<string, Record<number, string[]>> = {
  CADS: {
    1: [
      'Dictionaries and Abstract Data Types',
      'Hash Table Representation & Hash Functions',
      'Collision Resolution Techniques',
      'Linear Probing & Quadratic Probing',
      'Separate Chaining and Open Addressing',
      'Rehashing and Performance Analysis',
    ],
    2: [
      'Priority Queues & Heap Data Structures',
      'Binary Min-Heap and Max-Heap Operations (Insert, Extract-Min, Heapify)',
      'Binomial Heaps and Meld/Merge Operations',
      'Fibonacci Heaps and Amortized Complexity Analysis',
      'Balanced Binary Search Trees & AVL Trees',
      'AVL Tree Rotations (Single LL/RR and Double LR/RL Rotations)',
      'Red-Black Trees (Color Invariants and Balancing Properties)',
      'Splay Trees & Self-Adjusting Trees',
    ],
    3: [
      'Multi-Way Search Trees and External Memory Storage',
      'B-Tree Definition, Properties, and Degree Constraints',
      'B-Tree Search, Insertion, and Splitting Algorithms',
      'B-Tree Key Deletion, Merging, and Borrowing Mechanisms',
      'B+ Trees: Structure, Leaf Node Chaining, and Range Queries',
      'Comparison between B-Trees and B+ Trees in Relational Database Indexing',
    ],
    4: [
      'Digital Search Trees and Radix Searching',
      'Standard Tries and Compressed Tries (Patricia Tries)',
      'Prefix Matching and Dictionary Search Performance',
      'Suffix Trees and Suffix Arrays',
      'String Matching Algorithms (KMP Algorithm, Boyer-Moore, Rabin-Karp)',
    ],
    5: [
      'Graph Algorithms & Graph Representations (Adjacency Matrix & List)',
      'Single-Source Shortest Path: Dijkstra Algorithm & Greedy Choice',
      'Bellman-Ford Algorithm with Negative Weight Detection',
      'All-Pairs Shortest Path: Floyd-Warshall Dynamic Programming',
      'Minimum Spanning Trees: Kruskal and Prim Algorithms with Union-Find',
    ],
  },
  ADS: {
    1: [
      'Dictionaries and Abstract Data Types',
      'Hash Table Representation & Hash Functions',
      'Collision Resolution Techniques',
      'Linear Probing & Quadratic Probing',
      'Separate Chaining and Open Addressing',
    ],
    2: [
      'Priority Queues & Binary Heaps',
      'Binomial and Fibonacci Heaps',
      'AVL Trees and Height Balancing',
      'AVL Tree Rotations and Insertion Algorithms',
      'Red-Black Trees and Invariants',
    ],
    3: [
      'Multiway Search Trees: 2-3 Trees',
      'B-Trees (Order, Search, Insertion, Deletion)',
      'B+ Trees and Indexing Mechanics',
    ],
    4: [
      'Digital Search Trees and Binary Tries',
      'Compressed Tries and Suffix Trees',
      'Pattern Matching Algorithms',
    ],
    5: [
      'Graph Algorithms: Dijkstra, Bellman-Ford',
      'Minimum Spanning Trees: Prim and Kruskal',
      'Disjoint Set Union (DSU)',
    ],
  },
  DS: {
    1: [
      'Linear Data Structures Overview',
      'Array Implementations and Asymptotic Notation',
      'Stack Abstract Data Type and Push/Pop Operations',
      'Infix, Prefix, and Postfix Expressions Conversion',
      'Queue Abstract Data Type and Circular Queue Mechanics',
    ],
    2: [
      'Singly Linked List Structure and Pointer Traversal',
      'Node Insertion at Beginning, End, and Specific Position',
      'Node Deletion and Boundary Condition Handling',
      'Doubly Linked List and Bidirectional Pointers',
      'Circular Linked List Architecture and Loop Traversal',
      'Polynomial Addition & Representation using Linked Lists',
    ],
    3: [
      'Trees Terminology: Root, Degree, Depth, and Height',
      'Binary Tree Representation and Properties',
      'Binary Tree Traversals: Inorder, Preorder, and Postorder',
      'Binary Search Trees (BST): Insertion, Search, and Deletion',
    ],
    4: [
      'Graph Representations: Adjacency Matrix and Adjacency List',
      'Breadth First Search (BFS) Traversal using Queue',
      'Depth First Search (DFS) Traversal using Recursion/Stack',
      'Connected Components and Topological Sorting',
    ],
    5: [
      'Searching Techniques: Linear Search and Binary Search',
      'Sorting Algorithms: Bubble, Selection, and Insertion Sort',
      'Divide and Conquer Sorting: Merge Sort and Quick Sort',
      'Heap Sort and Time/Space Complexity Comparison',
    ],
  },
  DBMS: {
    1: [
      'Introduction to Database Management Systems & File System Limitations',
      'Three-Tier Schema Architecture and Data Independence',
      'Entity-Relationship (ER) Modeling: Entities, Attributes, and Relationships',
      'Cardinality Ratios and Extended ER (EER) Specialization/Generalization',
    ],
    2: [
      'Relational Data Model & Relational Database Schemas',
      'Integrity Constraints: Domain, Entity, and Referential Integrity',
      'Relational Algebra: Select, Project, Union, Set Difference, Cartesian Product',
      'Join Operations: Inner Join, Outer Join (Left, Right, Full), and Theta Join',
      'SQL Query Construction: DDL (CREATE, ALTER, DROP), DML (SELECT, INSERT, UPDATE)',
      'Nested Subqueries, Correlated Subqueries, and Aggregate Functions (GROUP BY, HAVING)',
    ],
    3: [
      'Functional Dependencies and Axioms (Armstrong Rules)',
      'Database Normalization: 1NF, 2NF, 3NF',
      'Boyce-Codd Normal Form (BCNF) and Multi-Valued Dependencies (4NF)',
      'Lossless Join Decomposition and Dependency Preservation',
    ],
    4: [
      'Transaction Processing and ACID Properties',
      'Serializability: Conflict and View Serializability',
      'Concurrency Control Protocols: Two-Phase Locking (2PL)',
      'Deadlock Handling: Wait-Die, Wound-Wait, and Deadlock Detection Graphs',
    ],
    5: [
      'Indexing Structures for Files: Primary, Clustering, and Secondary Indexes',
      'Multilevel Indexing using B+ Trees and Hashing',
      'Query Processing Architecture and Optimization Heuristics',
    ],
  },
  OS: {
    1: [
      'Operating System Roles, Structures, and Dual-Mode Operation',
      'System Calls and OS Interface (fork, exec, wait, exit)',
      'Process Concept: Process State Transition Diagram and Process Control Block (PCB)',
      'Context Switching Mechanics and Thread Models',
    ],
    2: [
      'CPU Scheduling Criteria: Turnaround, Waiting, and Response Times',
      'Scheduling Algorithms: First-Come First-Served (FCFS), Shortest Job First (SJF)',
      'Priority Scheduling and Round-Robin (RR) Scheduling with Time Quantum',
      'Multilevel Queue and Multilevel Feedback Queue Scheduling',
      'Process Synchronization and Critical Section Problem',
      'Peterson Solution and Test-and-Set Hardware Instructions',
      'Semaphores: Counting & Binary Semaphores with Wait/Signal',
      'Classical IPC Problems: Producer-Consumer, Readers-Writers, Dining Philosophers',
    ],
    3: [
      'Deadlock Definition, Resource Allocation Graph (RAG)',
      'Deadlock Prevention and Deadlock Avoidance',
      'Banker Algorithm for Deadlock Avoidance (Safety & Resource-Request Algorithms)',
      'Deadlock Detection and Recovery Mechanisms',
    ],
    4: [
      'Memory Management: Logical vs Physical Address Spaces',
      'Contiguous Allocation, Paging Architecture, Page Table Structure',
      'Virtual Memory & Demand Paging',
      'Page Replacement Algorithms: FIFO, Optimal (OPT), Least Recently Used (LRU)',
      'Thrashing, Working-Set Model, and Page Fault Handling',
    ],
    5: [
      'File System Architecture and Directory Structures',
      'File Allocation Methods: Contiguous, Linked, and Indexed Allocation',
      'Disk Scheduling Algorithms: FCFS, SSTF, SCAN, C-SCAN, LOOK, C-LOOK',
    ],
  },
  SE: {
    1: [
      'Software Engineering Principles and SDLC Lifecycle Models',
      'Waterfall Model, Incremental Process, and Prototyping',
      'Agile Software Development and Scrum Framework',
      'Software Requirements Specification (SRS) and Functional Requirements',
    ],
    2: [
      'Object-Oriented Programming Core Concepts: Classes, Objects, Encapsulation',
      'Inheritance Types: Single, Multilevel, and Hierarchical Inheritance',
      'Method Overriding vs Method Overloading (Runtime vs Compile-time Polymorphism)',
      'Super Keyword, Constructor Invocation, and Final Classes',
      'Abstract Classes, Abstract Methods, and Interface Contracts',
      'Multiple Inheritance Simulation via Java Interfaces',
    ],
    3: [
      'Java Packages and Access Modifiers',
      'Exception Handling Mechanics: try-catch-finally Blocks',
      'User-Defined Exceptions, throw, and throws Keywords',
      'Multithreading Architecture: Thread Life Cycle, Synchronization, and Locks',
    ],
    4: [
      'Unified Modeling Language (UML): Class Diagrams, Use Case Diagrams',
      'Sequence Diagrams and Activity Workflow Diagrams',
      'Design Patterns: Singleton, Factory, and Observer Patterns',
    ],
    5: [
      'Software Testing Strategies: Unit Testing, Integration Testing, System Testing',
      'Black-Box Testing (Boundary Value Analysis) and White-Box Testing (Cyclomatic Complexity)',
      'Software Maintenance and Quality Assurance (SQA)',
    ],
  },
};

// Aliases for matching subjects
const SUBJECT_ALIASES: Record<string, string> = {
  CADS: 'CADS',
  'COMPLEX ANALYSIS AND DISCRETE STRUCTURES': 'CADS',
  ADS: 'ADS',
  'ADVANCED DATA STRUCTURES': 'ADS',
  DS: 'DS',
  DSA: 'DS',
  'DATA STRUCTURES': 'DS',
  DBMS: 'DBMS',
  DATABASE: 'DBMS',
  DATABASES: 'DBMS',
  OS: 'OS',
  'OPERATING SYSTEMS': 'OS',
  'OPERATING SYSTEM': 'OS',
  SE: 'SE',
  'SOFTWARE ENGINEERING': 'SE',
  OOPS: 'SE',
  OOP: 'SE',
  JAVA: 'SE',
};

/**
 * Detects whether a student's message is requesting a visual/diagram/image
 * representation of study content.
 */
export function isVisualStudyRequest(message: string): boolean {
  const q = message.toLowerCase();

  const visualKeywords = [
    'diagram', 'diag', 'flowchart', 'flow chart', 'mind map', 'mindmap',
    'infographic', 'visual', 'visualize', 'visualise', 'image', 'imag', 'img',
    'picture', 'pic', 'chart', 'illustration', 'draw', 'sketch',
    'roadmap', 'workflow', 'timeline', 'map of', 'overview image',
    'concept map', 'concept diagram', 'tree diagram', 'block diagram',
    'show me a diagram', 'generate image', 'generate diagram',
    'syllabus image', 'syllabus diagram', 'syllabus workflow',
    'unit diagram', 'topic map', 'topic flow', 'architecture diagram',
    'visual representation', 'pictorial', 'graphic representation',
    'blueprint', 'wireframe', 'visual flow',
  ];

  if (visualKeywords.some((kw) => q.includes(kw))) {
    return true;
  }

  const visualPatterns = [
    /\b(show|create|make|generate|draw|give|design|craft|produce|prompt)\b.*\b(diagram|flowchart|flow\s*chart|mind\s*map|infographic|visual|image|imag|img|picture|chart|illustration|roadmap|workflow|blueprint)\b/i,
    /\b(diagram|flowchart|flow\s*chart|mind\s*map|mindmap|infographic|visual|image|imag|img|chart)\b.*\b(of|for|about|on|based)\b/i,
    /\b(syllabus|syllubs|unit\s*\d+|unity\s*\d+|\d+(?:st|nd|rd|th)?\s*(?:unit|unity)|topic)\b.*\b(workflow|flow|diagram|image|imag|img|visual|roadmap)\b/i,
    /\b(workflow|flow|roadmap)\b.*\b(image|imag|img|diagram|chart|of\s*unit|of\s*unity|of\s*syllabus|of\s*syllubs|based)\b/i,
    /\b(visualize|visualise|pictorial|graphic\s*representation|visual\s*representation|block\s*diagram|architecture\s*diagram|tree\s*diagram|concept\s*diagram)\b/i,
  ];

  return visualPatterns.some((pattern) => pattern.test(q));
}

/**
 * Detects the preferred visual style from the student's message.
 */
export function detectVisualStyle(message: string): VisualStyle {
  const q = message.toLowerCase();

  if (q.includes('flowchart') || q.includes('flow chart') || q.includes('workflow') || q.includes('flow')) {
    return 'flowchart';
  }
  if (q.includes('mind map') || q.includes('mindmap') || q.includes('concept map')) {
    return 'mind_map';
  }
  if (q.includes('timeline') || q.includes('roadmap') || q.includes('progression')) {
    return 'timeline';
  }
  if (q.includes('infographic') || q.includes('poster') || q.includes('overview')) {
    return 'infographic';
  }
  if (q.includes('comparison') || q.includes('compare') || q.includes('vs') || q.includes('versus') || q.includes('difference between')) {
    return 'comparison_table';
  }
  if (q.includes('hierarchy') || q.includes('tree') || q.includes('classification')) {
    return 'hierarchy';
  }
  if (q.includes('block diagram') || q.includes('architecture') || q.includes('concept diagram')) {
    return 'concept_diagram';
  }

  return 'flowchart';
}

/**
 * Extracts key topics from retrieved knowledge chunks.
 */
function extractTopicsFromChunks(chunks: RankedChunk[]): string[] {
  const topics = new Set<string>();

  for (const chunk of chunks) {
    const topicMatch = chunk.content.match(/TOPIC:\s*([^|\n]+)/i);
    if (topicMatch) {
      topics.add(topicMatch[1].trim());
    }

    if (chunk.title && chunk.title.trim().length > 0) {
      topics.add(chunk.title.trim());
    }

    const boldTerms = chunk.content.match(/\*\*([^*]+)\*\*/g);
    if (boldTerms) {
      for (const term of boldTerms.slice(0, 3)) {
        const cleaned = term.replace(/\*\*/g, '').trim();
        if (cleaned.length > 3 && cleaned.length < 70) {
          topics.add(cleaned);
        }
      }
    }

    const headings = chunk.content.match(/^#{1,3}\s+(.+)$/gm);
    if (headings) {
      for (const heading of headings.slice(0, 3)) {
        const cleaned = heading.replace(/^#+\s*/, '').trim();
        if (cleaned.length > 3 && cleaned.length < 70) {
          topics.add(cleaned);
        }
      }
    }
  }

  return Array.from(topics).slice(0, 10);
}

/**
 * Extracts target unit number from user message, handling Arabic ordinals (2nd, 3rd),
 * misspellings ("unity"), word numerals ("second"), and roman numerals ("II").
 */
export function extractUnitFromMessage(message: string): number {
  const q = message.toLowerCase();

  // 1. Ordinal Arabic: 1st, 2nd, 3rd, 4th, 5th unit / unity
  const ordinalMatch = q.match(/\b(\d+)(?:st|nd|rd|th)?\s*(?:unit|unity|u)\b/i);
  if (ordinalMatch) {
    const num = parseInt(ordinalMatch[1], 10);
    if (num >= 1 && num <= 10) return num;
  }

  // 2. Unit prefix followed by number: unit 2, unit-2, unity 2, u2
  const prefixMatch = q.match(/\b(?:unit|unity|u)[-\s]*(\d+)\b/i);
  if (prefixMatch) {
    const num = parseInt(prefixMatch[1], 10);
    if (num >= 1 && num <= 10) return num;
  }

  // 3. Word ordinals: first, second, third, fourth, fifth
  const wordMap: Record<string, number> = {
    first: 1, second: 2, third: 3, fourth: 4, fifth: 5,
    one: 1, two: 2, three: 3, four: 4, five: 5,
  };
  const wordMatch = q.match(/\b(first|second|third|fourth|fifth|one|two|three|four|five)\s*(?:unit|unity)\b/i);
  if (wordMatch && wordMap[wordMatch[1]]) {
    return wordMap[wordMatch[1]];
  }

  // 4. Roman numerals
  const romanMap: Record<string, number> = { i: 1, ii: 2, iii: 3, iv: 4, v: 5 };
  const romanMatch = q.match(/\b(?:unit|unity|u)[-\s]+(i|ii|iii|iv|v)\b/i);
  if (romanMatch && romanMap[romanMatch[1]]) {
    return romanMap[romanMatch[1]];
  }

  return 0;
}

/**
 * Extracts subject code from text or conversation history.
 */
export function extractSubject(
  text: string,
  conversation?: Array<{ role: string; content: string }>
): string {
  const subjectPatterns = [
    /\b(CADS|COMPLEX ANALYSIS AND DISCRETE STRUCTURES)\b/i,
    /\b(ADS|ADVANCED DATA STRUCTURES)\b/i,
    /\b(DS|DSA|DATA STRUCTURES)\b/i,
    /\b(DBMS|DATABASE MANAGEMENT SYSTEMS?|DATABASE)\b/i,
    /\b(OS|OPERATING SYSTEMS?)\b/i,
    /\b(SE|SOFTWARE ENGINEERING|OOPS?|JAVA)\b/i,
    /\b(CN|COMPUTER NETWORKS?)\b/i,
    /\b(CD|COMPILER DESIGN)\b/i,
    /\b(AIML|AI|MACHINE LEARNING|ARTIFICIAL INTELLIGENCE)\b/i,
  ];

  for (const pattern of subjectPatterns) {
    const match = text.match(pattern);
    if (match) {
      const key = match[1].toUpperCase();
      return SUBJECT_ALIASES[key] || key;
    }
  }

  // Scan previous conversation turns if available
  if (conversation && conversation.length > 0) {
    const reversed = [...conversation].reverse();
    for (const msg of reversed.slice(0, 6)) {
      for (const pattern of subjectPatterns) {
        const match = msg.content.match(pattern);
        if (match) {
          const key = match[1].toUpperCase();
          return SUBJECT_ALIASES[key] || key;
        }
      }
    }
  }

  return '';
}

/**
 * Determines primary subject and unit from chunks, user message, and conversation.
 */
export function extractSubjectAndUnit(
  chunks: RankedChunk[],
  userMessage: string,
  conversation?: Array<{ role: string; content: string }>
): { subject: string; unit: number } {
  let subject = '';
  let unit = 0;

  // 1. Chunks first
  for (const chunk of chunks) {
    if (!subject && chunk.subject) subject = chunk.subject;
    if (!unit && chunk.unit) unit = chunk.unit;
    if (subject && unit) break;
  }

  // 2. Unit from message
  if (!unit) {
    unit = extractUnitFromMessage(userMessage);
  }

  // 3. Subject from message or conversation
  if (!subject) {
    subject = extractSubject(userMessage, conversation);
  }

  // 4. Default to CADS (core 2nd-year BVC subject) and Unit 2 if nothing found
  return {
    subject: subject || 'CADS',
    unit: unit || 2,
  };
}

/**
 * Generates a clean Mermaid diagram representing the syllabus workflow.
 */
function buildMermaidWorkflow(subject: string, unit: number, topics: string[]): string {
  const safeSubject = subject.replace(/[^a-zA-Z0-9 ]/g, '');
  const topList = topics.slice(0, 6);

  if (topList.length === 0) {
    return [
      '```mermaid',
      'graph TD',
      `  Start(["🎓 ${safeSubject} Unit ${unit}"]) --> Concepts["Core Theoretical Foundations"]`,
      '  Concepts --> Implementation["Practical Algorithms & Applications"]',
      '  Implementation --> ExamKey["High-Yield Exam Topics"]',
      '```',
    ].join('\n');
  }

  const nodes: string[] = [];
  nodes.push(`  Root(["🎓 ${safeSubject} — Unit ${unit} Workflow"])`);

  topList.forEach((topic, idx) => {
    const id = `Node${idx + 1}`;
    const cleanTopic = topic.replace(/"/g, "'").replace(/[\[\]\(\)]/g, '');
    nodes.push(`  ${id}["${idx + 1}. ${cleanTopic}"]`);
  });

  const connections: string[] = [];
  connections.push(`  Root --> Node1`);
  for (let i = 1; i < topList.length; i++) {
    connections.push(`  Node${i} --> Node${i + 1}`);
  }

  return ['```mermaid', 'graph TD', ...nodes, ...connections, '```'].join('\n');
}

/**
 * Style-specific visual layout descriptions for image generation prompts.
 */
const STYLE_LAYOUT_INSTRUCTIONS: Record<VisualStyle, string> = {
  flowchart:
    'A high-contrast, modern technical flowchart with structured top-to-bottom concept nodes connected by glowing directional arrows. ' +
    'Nodes have rounded rectangular borders with vibrant neon cyan and emerald color coding. Background is dark slate (#0a0f1d) with a subtle blueprint grid. ' +
    'Each node contains crisp, highly legible typography with bold headings and 1-line subtext. Includes branching decision points and milestone badges.',

  mind_map:
    'A radial mind map with the central subject housed in an illuminated circular hub at the center. ' +
    'Primary topic branches radiate outward in distinct jewel-tone gradient lines (electric cyan, neon violet, amber gold, emerald green). ' +
    'Secondary concept nodes branch further with small vector iconography and crisp, high-legibility white text. Clean dark background (#090d16).',

  infographic:
    'A vertical educational infographic poster with a polished header banner at the top. ' +
    'Organized into distinct numbered module cards, featuring minimalist vector icons, flow arrows, and bulleted takeaways. ' +
    'Modern tech aesthetic, dark theme (#0b1120) with glowing teal and purple accents. Clean sans-serif typography with strong visual hierarchy.',

  timeline:
    'A chronological progression timeline with connected sequential milestone cards. ' +
    'Alternating left and right card layout with glowing connector lines. Color transition from deep blue to bright cyan. ' +
    'Each milestone clearly labels the concept, sequential dependencies, and prerequisites. Dark minimalist canvas.',

  concept_diagram:
    'An engineering architectural block diagram showing system modules and data flows. ' +
    'Solid rectangular concept blocks with labeled input/output connectors and dashed relationship boundaries. ' +
    'Technical blueprint aesthetic: navy canvas (#06101e) with sharp cyan and white vector linework and clean technical legends.',

  comparison_table:
    'A side-by-side comparative architectural visual showing concept properties across distinct cards. ' +
    'Color-coded comparison columns (neon cyan vs emerald green vs amber). Modern dark card aesthetic with vector checkmarks and property metrics.',

  hierarchy:
    'A structured tree hierarchy diagram cascading from a prominent root subject node at the top down to specialized algorithmic concepts below. ' +
    'Consistent node cards with descending visual weight. Dark slate background with clean vector connecting hierarchy lines.',
};

/**
 * Main function: Generates an AI image-generation prompt from the student's
 * study question and the academic context.
 */
export function generateVisualStudyPrompt(
  userMessage: string,
  chunks: RankedChunk[] = [],
  conversation?: Array<{ role: string; content: string }>
): VisualPromptResult {
  const style = detectVisualStyle(userMessage);
  let { subject, unit } = extractSubjectAndUnit(chunks, userMessage, conversation);

  // Extract topics from chunks
  let topics = extractTopicsFromChunks(chunks);

  // If chunks lacked topics, pull from authoritative BVC curriculum map
  const normalizedSubj = subject.toUpperCase();
  if (topics.length === 0 && BVC_CURRICULUM_TOPIC_MAP[normalizedSubj]?.[unit]) {
    topics = BVC_CURRICULUM_TOPIC_MAP[normalizedSubj][unit];
  } else if (topics.length === 0) {
    // Default fallback to CADS Unit 2 if nothing found
    topics = BVC_CURRICULUM_TOPIC_MAP['CADS'][unit] || BVC_CURRICULUM_TOPIC_MAP['CADS'][2];
  }

  const hasContext = topics.length > 0;
  const layoutInstruction = STYLE_LAYOUT_INSTRUCTIONS[style];
  const topicListFormatted = topics.map((t, i) => `${i + 1}. ${t}`).join('\n');
  const title = `${subject} Unit ${unit} — ${style.replace(/_/g, ' ').replace(/\b\w/g, (c) => c.toUpperCase())} Workflow`;
  const mermaidDiagram = buildMermaidWorkflow(subject, unit, topics);

  // Craft the exact, highly descriptive AI Image Generation Prompt
  const imagePrompt = [
    `Create a professional, high-resolution educational ${style.replace(/_/g, ' ')} workflow diagram for BVC Engineering College B.Tech syllabus: "${subject} — Unit ${unit}".`,
    '',
    `[Visual Layout & Architecture]:`,
    `${layoutInstruction}`,
    '',
    `[Primary Academic Nodes & Workflow Flow]:`,
    topicListFormatted,
    '',
    `[Technical Style & Graphic Guidelines]:`,
    `- Header Banner: Bold modern typography "${subject} • UNIT ${unit} STUDY WORKFLOW"`,
    `- Canvas: Premium deep dark theme (#0a0f1d) with subtle blueprint grid texture`,
    `- Color Palette: Cyber cyan (#00f2fe), emerald (#10b981), and electric purple accents`,
    `- Node Elements: Rounded rectangular glassmorphic cards with subtle glowing borders`,
    `- Connectors: Crisp directional arrows showing algorithmic flow and prerequisite relationships`,
    `- Typography: Ultra-sharp, highly legible sans-serif font (Inter / Outfit style)`,
    `- Details: Purely technical and educational diagram; no stock photos, no watermarks, no distorted gibberish text`,
    `- Aspect Ratio: 16:9 widescreen or 4:3 high-definition vector presentation quality`,
  ].join('\n');

  return {
    imagePrompt,
    title,
    style,
    subject,
    unit,
    topics,
    mermaidDiagram,
    hasContext,
  };
}

/**
 * Fallback visual prompt when no retrieved chunks are available.
 */
export function generateFallbackVisualPrompt(
  userMessage: string,
  conversation?: Array<{ role: string; content: string }>
): VisualPromptResult {
  return generateVisualStudyPrompt(userMessage, [], conversation);
}
