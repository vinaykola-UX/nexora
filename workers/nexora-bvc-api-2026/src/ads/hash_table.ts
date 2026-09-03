/**
 * ============================================================================
 * BVC Nexora ADS Engine — Component 1: Custom Hash Table
 * ============================================================================
 * 
 * ADS VIVA SPECIFICATION:
 * - What it is:
 *   An associative array data structure that maps keys to values using a 
 *   deterministic hash function, storing entries in an internal fixed-size array
 *   resolved via Open Addressing with Linear Probing.
 * 
 * - Why Nexora uses it:
 *   Provides instant O(1) average lookup for tokenized query keywords to their
 *   candidate chunk and document IDs in the knowledge base without scanning D1.
 * 
 * - Complexity:
 *   - Search: Average O(1), Worst O(n) during high clustering
 *   - Insertion: Average O(1), Worst O(n) during table resize/rehash
 *   - Deletion: Average O(1) using tombstone markers
 *   - Space: O(capacity) = O(N) where N is the number of distinct indexed terms
 * 
 * - Nexora Example:
 *   The term "inheritance" hashes to bucket index 42 via FNV-1a. Bucket 42
 *   stores the posting list of chunk IDs [8, 9, 10] from Unit 2.
 * ============================================================================
 */

export interface HashEntry<V> {
  key: string;
  value: V;
  deleted?: boolean;
}

export class CustomHashTable<V> {
  private buckets: (HashEntry<V> | null)[];
  private capacity: number;
  private count: number;
  private readonly maxLoadFactor = 0.70;

  constructor(initialCapacity = 31) {
    this.capacity = this.nextPrime(initialCapacity);
    this.buckets = new Array(this.capacity).fill(null);
    this.count = 0;
  }

  /**
   * FNV-1a 32-bit Hash Function
   * Fast, uniform distribution minimizing primary clustering in linear probing.
   */
  private hash(key: string): number {
    let hash = 0x811c9dc5; // 2166136261 (FNV offset basis)
    for (let i = 0; i < key.length; i++) {
      hash ^= key.charCodeAt(i);
      // 32-bit FNV prime multiply: hash * 16777619
      hash = Math.imul(hash, 0x01000193);
    }
    return (hash >>> 0) % this.capacity;
  }

  /**
   * Insert or update a key-value pair using linear probing for collisions.
   * Time Complexity: Average O(1), Worst O(n)
   */
  public set(key: string, value: V): void {
    if ((this.count + 1) / this.capacity > this.maxLoadFactor) {
      this.rehash();
    }

    const normKey = key.toLowerCase().trim();
    let index = this.hash(normKey);
    let firstTombstone = -1;

    for (let i = 0; i < this.capacity; i++) {
      const probeIdx = (index + i) % this.capacity;
      const entry = this.buckets[probeIdx];

      if (entry === null) {
        // Empty slot found
        const targetIdx = firstTombstone !== -1 ? firstTombstone : probeIdx;
        this.buckets[targetIdx] = { key: normKey, value, deleted: false };
        this.count++;
        return;
      }

      if (entry.deleted) {
        if (firstTombstone === -1) firstTombstone = probeIdx;
      } else if (entry.key === normKey) {
        // Update existing key
        entry.value = value;
        return;
      }
    }

    if (firstTombstone !== -1) {
      this.buckets[firstTombstone] = { key: normKey, value, deleted: false };
      this.count++;
      return;
    }

    // Edge-case table saturation
    this.rehash();
    this.set(normKey, value);
  }

  /**
   * Search for a key using open addressing.
   * Time Complexity: Average O(1), Worst O(n)
   */
  public get(key: string): V | undefined {
    const normKey = key.toLowerCase().trim();
    const index = this.hash(normKey);

    for (let i = 0; i < this.capacity; i++) {
      const probeIdx = (index + i) % this.capacity;
      const entry = this.buckets[probeIdx];

      if (entry === null) {
        return undefined; // Not in table
      }

      if (!entry.deleted && entry.key === normKey) {
        return entry.value;
      }
    }

    return undefined;
  }

  /**
   * Check if key exists.
   */
  public has(key: string): boolean {
    return this.get(key) !== undefined;
  }

  /**
   * Delete key using tombstone marker to preserve linear probing chains.
   */
  public delete(key: string): boolean {
    const normKey = key.toLowerCase().trim();
    const index = this.hash(normKey);

    for (let i = 0; i < this.capacity; i++) {
      const probeIdx = (index + i) % this.capacity;
      const entry = this.buckets[probeIdx];

      if (entry === null) return false;

      if (!entry.deleted && entry.key === normKey) {
        entry.deleted = true;
        this.count--;
        return true;
      }
    }

    return false;
  }

  /**
   * Rehash all elements into a new bucket array when load factor exceeds threshold.
   */
  private rehash(): void {
    const oldBuckets = this.buckets;
    this.capacity = this.nextPrime(this.capacity * 2);
    this.buckets = new Array(this.capacity).fill(null);
    this.count = 0;

    for (const entry of oldBuckets) {
      if (entry !== null && !entry.deleted) {
        this.set(entry.key, entry.value);
      }
    }
  }

  /**
   * Returns total active elements.
   */
  public size(): number {
    return this.count;
  }

  /**
   * Returns current internal capacity for viva / diagnostic verification.
   */
  public getCapacity(): number {
    return this.capacity;
  }

  /**
   * Returns all active entries.
   */
  public entries(): [string, V][] {
    const res: [string, V][] = [];
    for (const entry of this.buckets) {
      if (entry !== null && !entry.deleted) {
        res.push([entry.key, entry.value]);
      }
    }
    return res;
  }

  /**
   * Helper: Calculate next prime number to prevent harmonic collision cycles.
   */
  private nextPrime(n: number): number {
    let candidate = n % 2 === 0 ? n + 1 : n;
    while (!this.isPrime(candidate)) {
      candidate += 2;
    }
    return candidate;
  }

  private isPrime(n: number): boolean {
    if (n <= 1) return false;
    if (n <= 3) return true;
    if (n % 2 === 0 || n % 3 === 0) return false;
    for (let i = 5; i * i <= n; i += 6) {
      if (n % i === 0 || n % (i + 2) === 0) return false;
    }
    return true;
  }
}
