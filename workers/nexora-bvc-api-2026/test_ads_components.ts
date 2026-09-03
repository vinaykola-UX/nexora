/**
 * BVC Nexora ADS Engine — Comprehensive Component Unit Test Suite
 */

import { CustomHashTable } from './src/ads/hash_table';
import { AVLTree } from './src/ads/avl_tree';
import { KnowledgeGraph } from './src/ads/graph';
import { MaxHeap } from './src/ads/heap';
import { mergeSort } from './src/ads/sorting';
import { ADSSearchPipeline } from './src/ads/pipeline';

function assert(condition: boolean, msg: string) {
  if (!condition) {
    throw new Error(`[ASSERTION FAILED]: ${msg}`);
  }
}

console.log("==================================================");
console.log("   BVC NEXORA ADS ALGORITHM ENGINE — UNIT TESTS   ");
console.log("==================================================");

// ----------------------------------------------------
// 1. HASH TABLE TESTS
// ----------------------------------------------------
console.log("\n[TEST 1] Custom Hash Table (FNV-1a + Linear Probing)");
const ht = new CustomHashTable<string>(11);

// Test insertion & search
ht.set("inheritance", "SE-Unit2");
ht.set("polymorphism", "SE-Unit2");
ht.set("hashing", "ADS-Unit1");
ht.set("linked_list", "DS-Unit2");

assert(ht.get("inheritance") === "SE-Unit2", "Failed to retrieve 'inheritance'");
assert(ht.get("hashing") === "ADS-Unit1", "Failed to retrieve 'hashing'");
assert(ht.has("polymorphism") === true, "has('polymorphism') should be true");
assert(ht.get("non_existent") === undefined, "Missing key should return undefined");

// Test update behavior
ht.set("inheritance", "SE-Unit2-Updated");
assert(ht.get("inheritance") === "SE-Unit2-Updated", "Update existing key failed");

// Test collision handling & resizing (insert 20 elements to force rehash)
for (let i = 0; i < 20; i++) {
  ht.set(`key_${i}`, `value_${i}`);
}
assert(ht.size() === 24, `Size should be 24, got ${ht.size()}`);
assert(ht.get("key_15") === "value_15", "Collision retrieval failed after rehash");

// Test deletion with tombstones
ht.delete("key_15");
assert(!ht.has("key_15"), "Deleted key should return false for has()");
assert(ht.get("key_16") === "value_16", "Linear probing broken after tombstone deletion");

console.log(`  PASS: Hash Table verified (Size: ${ht.size()}, Capacity: ${ht.getCapacity()})`);

// ----------------------------------------------------
// 2. AVL TREE TESTS (LL, RR, LR, RL ROTATIONS)
// ----------------------------------------------------
console.log("\n[TEST 2] Custom AVL Tree (Self-Balancing BST)");

// Test LL Rotation: insert 30, 20, 10
const avlLL = new AVLTree<number>();
avlLL.insert("30", 30);
avlLL.insert("20", 20);
avlLL.insert("10", 10);
assert(avlLL.isBalanced(), "AVL LL rotation failed to balance tree");
assert(avlLL.rotationStats.ll > 0, "LL rotation was not recorded");

// Test RR Rotation: insert 10, 20, 30
const avlRR = new AVLTree<number>();
avlRR.insert("10", 10);
avlRR.insert("20", 20);
avlRR.insert("30", 30);
assert(avlRR.isBalanced(), "AVL RR rotation failed to balance tree");
assert(avlRR.rotationStats.rr > 0, "RR rotation was not recorded");

// Test LR Rotation: insert 30, 10, 20
const avlLR = new AVLTree<number>();
avlLR.insert("30", 30);
avlLR.insert("10", 10);
avlLR.insert("20", 20);
assert(avlLR.isBalanced(), "AVL LR rotation failed to balance tree");
assert(avlLR.rotationStats.lr > 0, "LR rotation was not recorded");

// Test RL Rotation: insert 10, 30, 20
const avlRL = new AVLTree<number>();
avlRL.insert("10", 10);
avlRL.insert("30", 30);
avlRL.insert("20", 20);
assert(avlRL.isBalanced(), "AVL RL rotation failed to balance tree");
assert(avlRL.rotationStats.rl > 0, "RL rotation was not recorded");

// Test In-Order Traversal (Alphabetical)
const avlMain = new AVLTree<string>();
const keywords = ["single inheritance", "abstract classes", "super keyword", "polymorphism", "dictionaries", "linked lists"];
for (const kw of keywords) {
  avlMain.insert(kw, `ref_${kw}`);
}
assert(avlMain.isBalanced(), "Main AVL tree should remain balanced");
const sorted = avlMain.inOrder();
for (let i = 1; i < sorted.length; i++) {
  assert(sorted[i - 1].key <= sorted[i].key, "In-order traversal is not sorted!");
}

// Test Prefix Search
const prefixHits = avlMain.searchPrefix("poly");
assert(prefixHits.length === 1 && prefixHits[0].key === "polymorphism", "Prefix search failed for 'poly'");

console.log(`  PASS: AVL Tree verified (Nodes: ${avlMain.size()}, Height: ${avlMain.treeHeight()}, Balanced: ${avlMain.isBalanced()})`);
console.log(`        Rotations triggered: LL=${avlLL.rotationStats.ll}, RR=${avlRR.rotationStats.rr}, LR=${avlLR.rotationStats.lr}, RL=${avlRL.rotationStats.rl}`);

// ----------------------------------------------------
// 3. KNOWLEDGE GRAPH TESTS (BFS & DFS)
// ----------------------------------------------------
console.log("\n[TEST 3] Academic Knowledge Graph (Adjacency List + BFS/DFS)");
const graph = new KnowledgeGraph();

// BFS traversal from 'topic:single_inheritance'
const bfsNeighbors = graph.bfs("topic:single_inheritance", 2);
assert(bfsNeighbors.length > 0, "BFS returned 0 neighbors");
const neighborLabels = bfsNeighbors.map((n) => n.node.label);
assert(neighborLabels.includes("Multilevel Inheritance"), "BFS failed to reach 'Multilevel Inheritance'");
assert(neighborLabels.includes("Super Keyword"), "BFS failed to reach 'Super Keyword'");

// DFS traversal from 'topic:singly_linked_list'
const dfsPath = graph.dfs("topic:singly_linked_list", 3);
assert(dfsPath.length > 0, "DFS returned 0 nodes");

// Concept expansion
const boosts = graph.getRelatedConcepts(["inheritance"]);
assert(boosts.has("single inheritance"), "getRelatedConcepts should boost 'single inheritance'");

const stats = graph.getStats();
console.log(`  PASS: Knowledge Graph verified (Vertices: ${stats.vertices}, Edges: ${stats.edges})`);
console.log(`        BFS reached ${bfsNeighbors.length} concepts within 2 hops.`);
console.log(`        DFS traversed prerequisite chain of length ${dfsPath.length}.`);

// ----------------------------------------------------
// 4. MAX-HEAP PRIORITY QUEUE TESTS
// ----------------------------------------------------
console.log("\n[TEST 4] Max-Heap (Priority Queue & Top-K Ranking)");
const heap = new MaxHeap<string>();

heap.insert("Chunk A (Low)", 5);
heap.insert("Chunk B (High)", 25);
heap.insert("Chunk C (Medium)", 15);
heap.insert("Chunk D (Max)", 40);
heap.insert("Chunk E (Min)", 2);

assert(heap.peek()?.data === "Chunk D (Max)", "Peek did not return maximum element");

// Extract top 3 candidates
const top3 = heap.extractTopK(3);
assert(top3.length === 3, "Top-3 should return 3 elements");
assert(top3[0].data === "Chunk D (Max)", "Top #1 should be Chunk D (Score 40)");
assert(top3[1].data === "Chunk B (High)", "Top #2 should be Chunk B (Score 25)");
assert(top3[2].data === "Chunk C (Medium)", "Top #3 should be Chunk C (Score 15)");

console.log("  PASS: Max-Heap verified (Ordering and Top-K extraction correct)");

// ----------------------------------------------------
// 5. STABLE MERGE SORT TESTS
// ----------------------------------------------------
console.log("\n[TEST 5] Stable Merge Sort");

// Test empty array & single element
assert(mergeSort([], (a, b) => a - b).length === 0, "Empty array failed");
assert(mergeSort([42], (a, b) => a - b)[0] === 42, "Single element failed");

// Test normal ordering
const nums = [8, 3, 2, 9, 7, 1, 5, 4, 6];
const sortedNums = mergeSort(nums, (a, b) => a - b);
for (let i = 1; i < sortedNums.length; i++) {
  assert(sortedNums[i - 1] <= sortedNums[i], "Numbers not sorted correctly");
}

// Test stability: items with identical scores must preserve input order
interface Item { id: number; score: number; }
const items: Item[] = [
  { id: 1, score: 10 },
  { id: 2, score: 20 },
  { id: 3, score: 10 },
  { id: 4, score: 20 },
  { id: 5, score: 10 },
];
const stableSorted = mergeSort(items, (a, b) => b.score - a.score);
// For score 20: id 2 should come before id 4
// For score 10: id 1 before id 3 before id 5
const score20 = stableSorted.filter((i) => i.score === 20);
assert(score20[0].id === 2 && score20[1].id === 4, "Merge sort stability violated for score 20!");

const score10 = stableSorted.filter((i) => i.score === 10);
assert(score10[0].id === 1 && score10[1].id === 3 && score10[2].id === 5, "Merge sort stability violated for score 10!");

console.log("  PASS: Merge Sort verified (Time O(n log n), Stability guaranteed)");

console.log("\n==================================================");
console.log("      ALL ADS UNIT COMPONENT TESTS PASSED!        ");
console.log("==================================================");
