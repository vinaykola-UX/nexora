/**
 * ============================================================================
 * Nexora AI — High-Performance In-Memory Sliding Window Rate Limiter & Abuse Guard
 * ============================================================================
 * Protects Cloudflare Worker endpoints from runaway loops, bot abuse,
 * provider quota exhaustion, and endpoint enumeration.
 * ============================================================================
 */

export interface RateLimitResult {
  allowed: boolean;
  limit: number;
  remaining: number;
  retryAfterSeconds: number;
}

export interface RateLimitConfig {
  maxRequests: number;
  windowSeconds: number;
}

export const RATE_LIMIT_TIERS = {
  // /chat & /ask
  CHAT_AUTHENTICATED: { maxRequests: 30, windowSeconds: 60 },
  CHAT_ANONYMOUS: { maxRequests: 10, windowSeconds: 60 },
  CHAT_WEB_SEARCH: { maxRequests: 6, windowSeconds: 60 },

  // /search
  SEARCH_PUBLIC: { maxRequests: 30, windowSeconds: 60 },
  SEARCH_AUTHENTICATED: { maxRequests: 60, windowSeconds: 60 },

  // Notifications test
  NOTIF_TEST: { maxRequests: 2, windowSeconds: 60 },

  // Admin routes
  ADMIN_GENERAL: { maxRequests: 60, windowSeconds: 60 },
} as const;

export class RateLimiter {
  // Map of rate limit key -> array of request timestamps (epoch ms)
  private static tracker = new Map<string, number[]>();
  private static lastCleanup = Date.now();
  private static readonly CLEANUP_INTERVAL_MS = 60 * 1000; // 1 minute
  private static readonly MAX_ENTRIES = 10000;

  /**
   * Check whether a request under `key` is allowed within `windowSeconds`.
   *
   * @param key Unique identifier (e.g. `chat:uid:user_123` or `search:ip:1.2.3.4`)
   * @param maxRequests Maximum allowed requests in the window
   * @param windowSeconds Window length in seconds (default 60s)
   */
  public static check(
    key: string,
    maxRequests: number,
    windowSeconds = 60
  ): RateLimitResult {
    const now = Date.now();
    const windowMs = windowSeconds * 1000;
    const windowStart = now - windowMs;

    // Periodic garbage collection of expired keys
    if (now - this.lastCleanup > this.CLEANUP_INTERVAL_MS || this.tracker.size > this.MAX_ENTRIES) {
      this.cleanup(windowStart);
    }

    let timestamps = this.tracker.get(key);
    if (!timestamps) {
      timestamps = [];
      this.tracker.set(key, timestamps);
    }

    // Filter out timestamps older than the sliding window
    timestamps = timestamps.filter((t) => t > windowStart);

    if (timestamps.length >= maxRequests) {
      const oldestInWindow = timestamps[0];
      const retryAfterSeconds = Math.max(1, Math.ceil((oldestInWindow + windowMs - now) / 1000));
      this.tracker.set(key, timestamps);
      return {
        allowed: false,
        limit: maxRequests,
        remaining: 0,
        retryAfterSeconds,
      };
    }

    // Record this request
    timestamps.push(now);
    this.tracker.set(key, timestamps);

    return {
      allowed: true,
      limit: maxRequests,
      remaining: Math.max(0, maxRequests - timestamps.length),
      retryAfterSeconds: 0,
    };
  }

  /**
   * Reset rate limit for a specific key or all keys (useful for testing)
   */
  public static reset(key?: string): void {
    if (key) {
      this.tracker.delete(key);
    } else {
      this.tracker.clear();
    }
  }

  /**
   * Remove keys whose timestamps are all expired
   */
  private static cleanup(windowStart: number): void {
    this.lastCleanup = Date.now();
    for (const [k, timestamps] of this.tracker.entries()) {
      const active = timestamps.filter((t) => t > windowStart);
      if (active.length === 0) {
        this.tracker.delete(k);
      } else {
        this.tracker.set(k, active);
      }
    }
  }
}

/**
 * Extracts client IP from Cloudflare or proxy headers with fallback.
 */
export function getClientIp(request: Request): string {
  const cfIp = request.headers.get('cf-connecting-ip');
  if (cfIp && cfIp.trim().length > 0) return cfIp.trim();

  const xForwardedFor = request.headers.get('x-forwarded-for');
  if (xForwardedFor) {
    const first = xForwardedFor.split(',')[0].trim();
    if (first.length > 0) return first;
  }

  const xRealIp = request.headers.get('x-real-ip');
  if (xRealIp && xRealIp.trim().length > 0) return xRealIp.trim();

  return '127.0.0.1';
}

/**
 * Constructs a safe standard HTTP 429 response without leaking internal configuration.
 */
export function createRateLimitResponse(result: RateLimitResult): Response {
  return new Response(
    JSON.stringify(
      {
        error: 'rate_limited',
        message: 'Too many requests. Please try again later.',
        retry_after: result.retryAfterSeconds,
      },
      null,
      2
    ),
    {
      status: 429,
      headers: {
        'Content-Type': 'application/json',
        'Retry-After': String(result.retryAfterSeconds),
        'X-RateLimit-Limit': String(result.limit),
        'X-RateLimit-Remaining': String(result.remaining),
        'Access-Control-Allow-Origin': '*',
        'X-Content-Type-Options': 'nosniff',
        'X-Frame-Options': 'DENY',
      },
    }
  );
}
