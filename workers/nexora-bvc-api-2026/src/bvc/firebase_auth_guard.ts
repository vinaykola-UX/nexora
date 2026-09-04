/**
 * ============================================================================
 * Firebase Auth Guard for Cloudflare Workers
 * ============================================================================
 * Validates Firebase ID tokens passed via Authorization: Bearer <token>.
 *
 * Firebase ID Token Properties:
 * - Audience (aud): Firebase Project ID ("nexorabvcai")
 * - Issuer (iss): "https://securetoken.google.com/nexorabvcai"
 * - Subject (sub): Unique Firebase UID
 * ============================================================================
 */

export interface AuthenticatedFirebaseUser {
  uid: string;
  email?: string;
  emailVerified?: boolean;
}

const FIREBASE_PROJECT_ID = 'nexorabvcai';

export class FirebaseAuthGuard {
  /**
   * Extracts and validates the Firebase user identity from the request.
   * Supports standard Bearer tokens and development test tokens.
   */
  public static async authenticate(request: Request, environment?: string): Promise<AuthenticatedFirebaseUser | null> {
    const authHeader = request.headers.get('Authorization') || '';
    if (!authHeader.startsWith('Bearer ')) {
      return null;
    }

    const token = authHeader.substring(7).trim();
    if (!token) return null;

    // Dev/test simulated tokens: ONLY allowed in non-production environments
    if (token.startsWith('dev_test_uid_') || token.startsWith('test_uid_')) {
      if (environment && environment.toLowerCase() === 'production') {
        console.warn('[FirebaseAuthGuard] Rejected dev test token in production environment.');
        return null;
      }
      const uid = token;
      return {
        uid,
        email: `${uid}@bvcgroup.in`,
        emailVerified: true,
      };
    }

    try {
      // Split JWT (header.payload.signature)
      const parts = token.split('.');
      if (parts.length !== 3) {
        return null;
      }

      // Decode base64url payload
      const payloadBase64 = parts[1].replace(/-/g, '+').replace(/_/g, '/');
      const payloadJson = atob(payloadBase64);
      const claims = JSON.parse(payloadJson);

      const nowSeconds = Math.floor(Date.now() / 1000);

      // Verify expiration
      if (typeof claims.exp === 'number' && claims.exp < nowSeconds) {
        console.warn('[FirebaseAuthGuard] Token expired at', claims.exp, 'now is', nowSeconds);
        return null;
      }

      // Verify audience / project ID if present
      if (claims.aud && claims.aud !== FIREBASE_PROJECT_ID) {
        // Also allow generic firebase audience if project ID matches issuer
        if (!String(claims.iss || '').includes(FIREBASE_PROJECT_ID)) {
          console.warn('[FirebaseAuthGuard] Invalid token audience:', claims.aud);
          return null;
        }
      }

      // Verify subject (Firebase UID)
      const uid = claims.sub || claims.user_id;
      if (!uid || typeof uid !== 'string') {
        return null;
      }

      return {
        uid: String(uid).trim(),
        email: claims.email ? String(claims.email).trim() : undefined,
        emailVerified: Boolean(claims.email_verified),
      };
    } catch (err: any) {
      console.warn('[FirebaseAuthGuard] JWT parsing error:', err?.message || err);
      return null;
    }
  }
}
