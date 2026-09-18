/**
 * ============================================================================
 * Firebase Auth Guard for Cloudflare Workers (Cryptographically Hardened)
 * ============================================================================
 * Validates Firebase ID tokens passed via Authorization: Bearer <token>.
 *
 * Security Guarantees:
 * 1. Cryptographic RSA256 signature verification against Google's official JWKS.
 * 2. Token expiration (exp) and issued-at (iat) verification with clock skew margin.
 * 3. Strict Audience (aud) validation matching Firebase Project ID ("nexorabvcai").
 * 4. Issuer (iss) validation ("https://securetoken.google.com/nexorabvcai").
 * 5. Safe-by-default environment checks (dev tokens blocked unless explicitly dev/test).
 * 6. Explicit separation between generic Firebase authentication and BVC domain authorization.
 * ============================================================================
 */

export interface AuthenticatedFirebaseUser {
  uid: string;
  email?: string;
  emailVerified?: boolean;
}

export interface AuthOptions {
  environment?: string;
  requireBvcDomain?: boolean;
}

export const FIREBASE_PROJECT_ID = 'nexorabvcai';
export const ALLOWED_EMAIL_DOMAIN = 'bvcgroup.in';
export const GOOGLE_JWKS_URL = 'https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com';

export interface GoogleJWK {
  kty: string;
  alg: string;
  use: string;
  kid: string;
  n: string;
  e: string;
}

// In-memory cached Google JWKS with TTL
let cachedJWKS: { keys: GoogleJWK[]; expiresAt: number } | null = null;
let testJWKSOverride: GoogleJWK[] | null = null;
const JWKS_CACHE_TTL_MS = 60 * 60 * 1000; // 1 hour

/**
 * Fetch and cache Google's public JWKS for Firebase Auth token verification.
 */
async function getGoogleJWKS(forceRefresh = false): Promise<GoogleJWK[]> {
  if (testJWKSOverride) {
    return testJWKSOverride;
  }

  const now = Date.now();
  if (!forceRefresh && cachedJWKS && cachedJWKS.expiresAt > now) {
    return cachedJWKS.keys;
  }

  try {
    const res = await fetch(GOOGLE_JWKS_URL, {
      headers: { Accept: 'application/json' },
    });
    if (!res.ok) {
      throw new Error(`Google JWKS HTTP ${res.status}`);
    }
    const data = (await res.json()) as { keys?: GoogleJWK[] };
    if (!data?.keys || !Array.isArray(data.keys)) {
      throw new Error('Malformed JWKS response from Google');
    }

    cachedJWKS = {
      keys: data.keys,
      expiresAt: now + JWKS_CACHE_TTL_MS,
    };
    return data.keys;
  } catch (err) {
    console.warn('[FirebaseAuthGuard] Error fetching Google JWKS:', err);
    if (cachedJWKS?.keys) {
      return cachedJWKS.keys;
    }
    return [];
  }
}

/**
 * Converts a base64url string to Uint8Array for Web Crypto APIs.
 */
function base64UrlToUint8Array(base64Url: string): Uint8Array {
  const base64 = base64Url.replace(/-/g, '+').replace(/_/g, '/');
  const padLen = (4 - (base64.length % 4)) % 4;
  const padded = base64 + '='.repeat(padLen);
  const binary = atob(padded);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes;
}

export class FirebaseAuthGuard {
  /**
   * Reset JWKS cache (useful for testing)
   */
  public static resetJWKSCache(): void {
    cachedJWKS = null;
  }

  /**
   * Override JWKS for isolated unit and security testing
   */
  public static setTestJWKS(keys: GoogleJWK[] | null): void {
    testJWKSOverride = keys;
  }

  /**
   * Checks whether an authenticated user belongs to the authorized BVC email domain.
   */
  public static authorizeBvcDomain(user: AuthenticatedFirebaseUser | null | undefined): boolean {
    if (!user || !user.email) return false;
    const emailLower = user.email.trim().toLowerCase();
    const domain = emailLower.split('@')[1];
    return domain === ALLOWED_EMAIL_DOMAIN;
  }

  /**
   * Extracts and cryptographically validates the Firebase user identity from the request.
   * Safe-by-default: Dev tokens are REJECTED unless environment is explicitly 'development' or 'test'.
   */
  public static async authenticate(
    request: Request,
    envOrOptions?: string | AuthOptions
  ): Promise<AuthenticatedFirebaseUser | null> {
    const authHeader = request.headers.get('Authorization') || '';
    if (!authHeader.startsWith('Bearer ')) {
      return null;
    }

    const token = authHeader.substring(7).trim();
    if (!token) return null;

    let environment: string | undefined;
    let requireBvcDomain = false;

    if (typeof envOrOptions === 'string') {
      environment = envOrOptions;
    } else if (envOrOptions && typeof envOrOptions === 'object') {
      environment = envOrOptions.environment;
      requireBvcDomain = Boolean(envOrOptions.requireBvcDomain);
    }

    // Safe by default: Only permit dev test tokens in explicit non-production test/development environments.
    // If environment is undefined, omitted, null, or 'production', dev tokens are strictly REJECTED.
    const isDevAllowed =
      Boolean(environment) &&
      ['development', 'test', 'local'].includes(String(environment).trim().toLowerCase());

    if (token.startsWith('dev_test_uid_') || token.startsWith('test_uid_')) {
      if (!isDevAllowed) {
        console.warn('[FirebaseAuthGuard] Rejected dev test token: dev tokens only allowed in explicit development/test environments.');
        return null;
      }
      const uid = token;
      const user: AuthenticatedFirebaseUser = {
        uid,
        email: `${uid}@${ALLOWED_EMAIL_DOMAIN}`,
        emailVerified: true,
      };
      if (requireBvcDomain && !this.authorizeBvcDomain(user)) {
        return null;
      }
      return user;
    }

    try {
      // Split JWT into header, payload, and signature
      const parts = token.split('.');
      if (parts.length !== 3) {
        console.warn('[FirebaseAuthGuard] Malformed JWT: expected 3 parts.');
        return null;
      }

      // 1. Decode and validate Header
      const headerJson = atob(parts[0].replace(/-/g, '+').replace(/_/g, '/'));
      const header = JSON.parse(headerJson);

      if (header.alg !== 'RS256' || !header.kid || typeof header.kid !== 'string') {
        console.warn('[FirebaseAuthGuard] Unsupported algorithm or missing kid:', header?.alg);
        return null;
      }

      // 2. Decode and validate Payload
      const payloadBase64 = parts[1].replace(/-/g, '+').replace(/_/g, '/');
      const payloadJson = atob(payloadBase64);
      const claims = JSON.parse(payloadJson);

      const nowSeconds = Math.floor(Date.now() / 1000);

      // Verify expiration (with 30-second leeway for clock skew)
      if (typeof claims.exp !== 'number' || claims.exp < (nowSeconds - 30)) {
        console.warn('[FirebaseAuthGuard] Token expired at', claims.exp, 'now is', nowSeconds);
        return null;
      }

      // Verify issued-at time (iat) cannot be in the future (allowing 60s clock skew)
      if (typeof claims.iat !== 'number' || claims.iat > (nowSeconds + 60)) {
        console.warn('[FirebaseAuthGuard] Token issued in the future (iat:', claims.iat, 'now:', nowSeconds, ')');
        return null;
      }

      // 3. Strict Audience verification: MUST strictly equal FIREBASE_PROJECT_ID
      if (claims.aud !== FIREBASE_PROJECT_ID) {
        console.warn('[FirebaseAuthGuard] Invalid token audience:', claims.aud);
        return null;
      }

      // 4. Strict Issuer verification: https://securetoken.google.com/<FIREBASE_PROJECT_ID>
      const expectedIssuer = `https://securetoken.google.com/${FIREBASE_PROJECT_ID}`;
      if (claims.iss !== expectedIssuer) {
        console.warn('[FirebaseAuthGuard] Invalid token issuer:', claims.iss);
        return null;
      }

      // 5. Subject verification (Firebase UID)
      const uid = claims.sub || claims.user_id;
      if (!uid || typeof uid !== 'string' || !uid.trim()) {
        console.warn('[FirebaseAuthGuard] Missing or invalid subject (sub) claim.');
        return null;
      }

      // 6. Cryptographic Signature Verification using Web Crypto (RSASSA-PKCS1-v1_5 SHA-256)
      let jwks = await getGoogleJWKS(false);
      let keyData = jwks.find((k) => k.kid === header.kid);

      // If key not found in cache, force a one-time refresh in case of key rotation
      if (!keyData) {
        jwks = await getGoogleJWKS(true);
        keyData = jwks.find((k) => k.kid === header.kid);
      }

      if (!keyData) {
        console.warn('[FirebaseAuthGuard] Key ID not found in Google JWKS:', header.kid);
        return null;
      }

      // Import the RSA public key into Web Crypto
      const cryptoKey = await crypto.subtle.importKey(
        'jwk',
        keyData,
        { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
        false,
        ['verify']
      );

      // Verify the signature against the signed data (header.payload)
      const signedData = new TextEncoder().encode(`${parts[0]}.${parts[1]}`);
      const signatureBytes = base64UrlToUint8Array(parts[2]);

      const isSignatureValid = await crypto.subtle.verify(
        'RSASSA-PKCS1-v1_5',
        cryptoKey,
        signatureBytes as unknown as BufferSource,
        signedData
      );

      if (!isSignatureValid) {
        console.warn('[FirebaseAuthGuard] Cryptographic signature verification failed.');
        return null;
      }

      const user: AuthenticatedFirebaseUser = {
        uid: String(uid).trim(),
        email: claims.email ? String(claims.email).trim() : undefined,
        emailVerified: Boolean(claims.email_verified),
      };

      // 7. Optional BVC Domain Authorization check
      if (requireBvcDomain && !this.authorizeBvcDomain(user)) {
        console.warn('[FirebaseAuthGuard] BVC domain authorization failed for email:', user.email);
        return null;
      }

      return user;
    } catch (err: any) {
      console.warn('[FirebaseAuthGuard] Cryptographic validation error:', err?.message || err);
      return null;
    }
  }
}
