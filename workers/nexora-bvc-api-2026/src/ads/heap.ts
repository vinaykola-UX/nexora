/**
 * ============================================================================
 * BVC Nexora ADS Engine — Component 4: Max-Heap (Priority Queue)
 * ============================================================================
 * 
 * ADS VIVA SPECIFICATION:
 * - What it is:
 *   A complete binary tree stored compactly in an array where every parent node
 *   has a key/priority greater than or equal to its children (Max-Heap Property).
 * 
 * - Why Nexora uses it:
 *   Efficiently ranks candidate chunks retrieved across all D1 documents.
 *   Instead of sorting all N candidates, the Max-Heap extracts the Top-K
 *   most relevant study chunks in O(k log n) time.
 * 
 * - Complexity:
 *   - Peek (Max element): O(1)
 *   - Insert: O(log n) using Sift-Up
 *   - Extract-Max: O(log n) using Sift-Down
 *   - Top-K Extraction: O(k log n) where k <= n
 *   - Space: O(n) array backing
 * 
 * - Array Index Properties:
 *   For an element at index i (0-based):
 *   - Parent: floor((i - 1) / 2)
 *   - Left Child: 2*i + 1
 *   - Right Child: 2*i + 2
 * ============================================================================
 */

export interface HeapNode<T> {
  score: number;
  data: T;
}

export class MaxHeap<T> {
  private heap: HeapNode<T>[] = [];

  constructor() {
    this.heap = [];
  }

  /**
   * Insert a candidate with its calculated relevance score.
   * Time Complexity: O(log n)
   */
  public insert(data: T, score: number): void {
    const node: HeapNode<T> = { score, data };
    this.heap.push(node);
    this.siftUp(this.heap.length - 1);
  }

  /**
   * Sift-Up (Bubble-Up) restores heap order after insertion at leaf.
   */
  private siftUp(index: number): void {
    let current = index;
    while (current > 0) {
      const parent = Math.floor((current - 1) / 2);
      if (this.heap[current].score > this.heap[parent].score) {
        this.swap(current, parent);
        current = parent;
      } else {
        break;
      }
    }
  }

  /**
   * Extract the candidate with the highest relevance score.
   * Time Complexity: O(log n)
   */
  public extractMax(): HeapNode<T> | null {
    if (this.heap.length === 0) return null;
    if (this.heap.length === 1) return this.heap.pop()!;

    const max = this.heap[0];
    this.heap[0] = this.heap.pop()!;
    this.siftDown(0);
    return max;
  }

  /**
   * Sift-Down (Bubble-Down) restores heap order after root replacement.
   */
  private siftDown(index: number): void {
    let current = index;
    const length = this.heap.length;

    while (true) {
      const left = 2 * current + 1;
      const right = 2 * current + 2;
      let largest = current;

      if (left < length && this.heap[left].score > this.heap[largest].score) {
        largest = left;
      }

      if (right < length && this.heap[right].score > this.heap[largest].score) {
        largest = right;
      }

      if (largest !== current) {
        this.swap(current, largest);
        current = largest;
      } else {
        break;
      }
    }
  }

  /**
   * Peek at the maximum element without removing it.
   * Time Complexity: O(1)
   */
  public peek(): HeapNode<T> | null {
    return this.heap.length > 0 ? this.heap[0] : null;
  }

  /**
   * Extract Top-K candidates.
   * Time Complexity: O(k log n)
   */
  public extractTopK(k: number): Array<HeapNode<T>> {
    const results: Array<HeapNode<T>> = [];
    const count = Math.min(k, this.heap.length);

    for (let i = 0; i < count; i++) {
      const max = this.extractMax();
      if (max) results.push(max);
    }

    return results;
  }

  public size(): number {
    return this.heap.length;
  }

  public isEmpty(): boolean {
    return this.heap.length === 0;
  }

  private swap(i: number, j: number): void {
    const temp = this.heap[i];
    this.heap[i] = this.heap[j];
    this.heap[j] = temp;
  }
}
