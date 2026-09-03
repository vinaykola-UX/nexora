/**
 * ============================================================================
 * BVC Nexora ADS Engine — Component 5: Stable Merge Sort
 * ============================================================================
 * 
 * ADS VIVA SPECIFICATION:
 * - What it is:
 *   A divide-and-conquer comparison-based sorting algorithm that recursively 
 *   bisects an array into halves, sorts each half, and merges the sorted 
 *   subarrays back together in linear time.
 * 
 * - Why Nexora uses it:
 *   Guarantees STABLE final ordering for Top-K study chunks. When multiple 
 *   chunks have equal relevance scores, Merge Sort stably preserves curriculum 
 *   order (ascending academic unit, then ascending chunk index).
 * 
 * - Complexity:
 *   - Best Case: O(n log n)
 *   - Average Case: O(n log n)
 *   - Worst Case: O(n log n)
 *   - Space Complexity: O(n) auxiliary memory for merge buffer
 *   - Stability: Guaranteed (preserves original relative order of equal keys)
 * ============================================================================
 */

export type CompareFn<T> = (a: T, b: T) => number;

/**
 * Custom divide-and-conquer Merge Sort implementation.
 * Does NOT call native Array.prototype.sort().
 */
export function mergeSort<T>(items: T[], compare: CompareFn<T>): T[] {
  if (items.length <= 1) {
    return items.slice();
  }

  const mid = Math.floor(items.length / 2);
  const leftHalf = items.slice(0, mid);
  const rightHalf = items.slice(mid);

  const sortedLeft = mergeSort(leftHalf, compare);
  const sortedRight = mergeSort(rightHalf, compare);

  return merge(sortedLeft, sortedRight, compare);
}

/**
 * Merge two sorted subarrays in O(n) time while maintaining stability.
 */
function merge<T>(left: T[], right: T[], compare: CompareFn<T>): T[] {
  const result: T[] = [];
  let i = 0;
  let j = 0;

  while (i < left.length && j < right.length) {
    // compare(a, b) <= 0 preserves stability when keys are equal
    if (compare(left[i], right[j]) <= 0) {
      result.push(left[i]);
      i++;
    } else {
      result.push(right[j]);
      j++;
    }
  }

  // Append any remaining elements
  while (i < left.length) {
    result.push(left[i]);
    i++;
  }

  while (j < right.length) {
    result.push(right[j]);
    j++;
  }

  return result;
}
