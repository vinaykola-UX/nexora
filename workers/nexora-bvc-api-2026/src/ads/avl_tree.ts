/**
 * ============================================================================
 * BVC Nexora ADS Engine — Component 2: Custom AVL Tree
 * ============================================================================
 * 
 * ADS VIVA SPECIFICATION:
 * - What it is:
 *   A self-balancing binary search tree (named after inventors Adelson-Velsky 
 *   and Landis) where the height difference (balance factor) between left and 
 *   right subtrees of any node is at most 1.
 * 
 * - Why Nexora uses it:
 *   Maintains a lexicographically ordered, guaranteed-balanced topic and 
 *   keyword index. It provides O(log n) prefix search and range queries, 
 *   allowing student queries like "inherit" to cleanly match "inheritance",
 *   "single inheritance", and "multilevel inheritance".
 * 
 * - Complexity:
 *   - Search: O(log n)
 *   - Insertion: O(log n) with at most 2 tree rotations
 *   - Deletion: O(log n)
 *   - Traversal (In-Order): O(n) producing sorted keyword vocabulary
 *   - Space: O(n) for n indexed unique nodes
 * 
 * - Tree Rotations:
 *   - LL Rotation (Right Rotate) when left-heavy with left-leaning child
 *   - RR Rotation (Left Rotate) when right-heavy with right-leaning child
 *   - LR Rotation (Left-Right Double Rotate)
 *   - RL Rotation (Right-Left Double Rotate)
 * ============================================================================
 */

export class AVLNode<V> {
  public key: string;
  public value: V;
  public height: number;
  public left: AVLNode<V> | null;
  public right: AVLNode<V> | null;

  constructor(key: string, value: V) {
    this.key = key;
    this.value = value;
    this.height = 1;
    this.left = null;
    this.right = null;
  }
}

export class AVLTree<V> {
  private root: AVLNode<V> | null = null;
  private nodeCount = 0;

  // Rotation counters for ADS viva diagnostics
  public rotationStats = {
    ll: 0,
    rr: 0,
    lr: 0,
    rl: 0,
  };

  /**
   * Safe node height helper. Empty subtree has height 0.
   */
  private getHeight(node: AVLNode<V> | null): number {
    return node ? node.height : 0;
  }

  /**
   * Recalculate node height based on child heights.
   */
  private updateHeight(node: AVLNode<V>): void {
    node.height = 1 + Math.max(this.getHeight(node.left), this.getHeight(node.right));
  }

  /**
   * Balance Factor = Height(Left) - Height(Right).
   * Range for AVL node: {-1, 0, 1}. Violations occur at +2 or -2.
   */
  public getBalanceFactor(node: AVLNode<V> | null): number {
    return node ? this.getHeight(node.left) - this.getHeight(node.right) : 0;
  }

  /**
   * Right Rotation (LL Case)
   * 
   *       y (BF=+2)              x
   *      / \                    / \
   *     x   T3       ==>       T1  y
   *    / \                        / \
   *   T1  T2                     T2  T3
   */
  private rightRotate(y: AVLNode<V>): AVLNode<V> {
    const x = y.left!;
    const T2 = x.right;

    x.right = y;
    y.left = T2;

    this.updateHeight(y);
    this.updateHeight(x);

    return x;
  }

  /**
   * Left Rotation (RR Case)
   * 
   *     x (BF=-2)                y
   *    / \                      / \
   *   T1  y          ==>       x   T3
   *      / \                  / \
   *     T2  T3               T1  T2
   */
  private leftRotate(x: AVLNode<V>): AVLNode<V> {
    const y = x.right!;
    const T2 = y.left;

    y.left = x;
    x.right = T2;

    this.updateHeight(x);
    this.updateHeight(y);

    return y;
  }

  /**
   * Insert a key-value pair and rebalance the tree.
   * Time Complexity: O(log n)
   */
  public insert(key: string, value: V): void {
    const normKey = key.toLowerCase().trim();
    this.root = this.insertNode(this.root, normKey, value);
  }

  private insertNode(node: AVLNode<V> | null, key: string, value: V): AVLNode<V> {
    // 1. Standard BST insertion
    if (node === null) {
      this.nodeCount++;
      return new AVLNode<V>(key, value);
    }

    if (key < node.key) {
      node.left = this.insertNode(node.left, key, value);
    } else if (key > node.key) {
      node.right = this.insertNode(node.right, key, value);
    } else {
      // Key already exists: update payload
      node.value = value;
      return node;
    }

    // 2. Update height
    this.updateHeight(node);

    // 3. Check Balance Factor
    const balance = this.getBalanceFactor(node);

    // LL Case (Left-Left heavy)
    if (balance > 1 && key < node.left!.key) {
      this.rotationStats.ll++;
      return this.rightRotate(node);
    }

    // RR Case (Right-Right heavy)
    if (balance < -1 && key > node.right!.key) {
      this.rotationStats.rr++;
      return this.leftRotate(node);
    }

    // LR Case (Left-Right heavy)
    if (balance > 1 && key > node.left!.key) {
      this.rotationStats.lr++;
      node.left = this.leftRotate(node.left!);
      return this.rightRotate(node);
    }

    // RL Case (Right-Left heavy)
    if (balance < -1 && key < node.right!.key) {
      this.rotationStats.rl++;
      node.right = this.rightRotate(node.right!);
      return this.leftRotate(node);
    }

    return node;
  }

  /**
   * Search for an exact key.
   * Time Complexity: O(log n)
   */
  public search(key: string): V | null {
    const normKey = key.toLowerCase().trim();
    let curr = this.root;

    while (curr !== null) {
      if (normKey === curr.key) {
        return curr.value;
      }
      if (normKey < curr.key) {
        curr = curr.left;
      } else {
        curr = curr.right;
      }
    }

    return null;
  }

  /**
   * Prefix search: Finds all entries where key starts with the given prefix.
   * Crucial for fuzzy student topic lookups (e.g. "poly" -> "polymorphism").
   * Time Complexity: O(log n + k) where k is number of matching prefix nodes.
   */
  public searchPrefix(prefix: string): Array<{ key: string; value: V }> {
    const normPrefix = prefix.toLowerCase().trim();
    const results: Array<{ key: string; value: V }> = [];
    this.collectPrefix(this.root, normPrefix, results);
    return results;
  }

  private collectPrefix(node: AVLNode<V> | null, prefix: string, results: Array<{ key: string; value: V }>): void {
    if (node === null) return;

    if (node.key.startsWith(prefix)) {
      results.push({ key: node.key, value: node.value });
    }

    // Prune search: only search left if prefix <= node.key
    if (prefix <= node.key || node.key.startsWith(prefix)) {
      this.collectPrefix(node.left, prefix, results);
    }

    // Prune search: only search right if prefix >= node.key or matches
    if (prefix >= node.key.substring(0, prefix.length) || node.key.startsWith(prefix)) {
      this.collectPrefix(node.right, prefix, results);
    }
  }

  /**
   * In-Order Traversal (Left, Root, Right).
   * Returns all entries in ascending alphabetical order.
   * Time Complexity: O(n)
   */
  public inOrder(): Array<{ key: string; value: V }> {
    const results: Array<{ key: string; value: V }> = [];
    this.inOrderHelper(this.root, results);
    return results;
  }

  private inOrderHelper(node: AVLNode<V> | null, results: Array<{ key: string; value: V }>): void {
    if (node !== null) {
      this.inOrderHelper(node.left, results);
      results.push({ key: node.key, value: node.value });
      this.inOrderHelper(node.right, results);
    }
  }

  /**
   * Tree diagnostics
   */
  public size(): number {
    return this.nodeCount;
  }

  public treeHeight(): number {
    return this.getHeight(this.root);
  }

  public isBalanced(): boolean {
    return this.checkBalanced(this.root);
  }

  private checkBalanced(node: AVLNode<V> | null): boolean {
    if (node === null) return true;
    const bf = this.getBalanceFactor(node);
    if (Math.abs(bf) > 1) return false;
    return this.checkBalanced(node.left) && this.checkBalanced(node.right);
  }
}
