/**
 * ============================================================================
 * Focused Security Test Suite for FirebaseAuthGuard
 * ============================================================================
 * Proves cryptographic and authorization invariants:
 * 1. Valid signed Firebase token -> ACCEPTED
 * 2. Forged JWT -> REJECTED
 * 3. Correct payload + fake signature -> REJECTED
 * 4. Modified UID + original signature -> REJECTED
 * 5. Modified email + original signature -> REJECTED
 * 6. Wrong kid -> REJECTED
 * 7. Unknown kid -> REJECTED after JWKS refresh attempt
 * 8. Audience mismatch (strict aud check) -> REJECTED
 * 9. Dev test token with undefined/production environment -> REJECTED
 * 10. Dev test token with explicit development environment -> ACCEPTED
 * 11. Generic Firebase user (outsider domain) -> ACCEPTED for generic, REJECTED for BVC-only
 * ============================================================================
 */

import { FirebaseAuthGuard, FIREBASE_PROJECT_ID, ALLOWED_EMAIL_DOMAIN } from './src/bvc/firebase_auth_guard.ts';

interface GoogleJWK {
  kty: string;
  alg: string;
  use: string;
  kid: string;
  n: string;
  e: string;
}

function base64UrlEncode(strOrBytes: string | Uint8Array): string {
  let binary = '';
  if (typeof strOrBytes === 'string') {
    binary = btoa(strOrBytes);
  } else {
    for (let i = 0; i < strOrBytes.length; i++) {
      binary += String.fromCharCode(strOrBytes[i]);
    }
    binary = btoa(binary);
  }
  return binary.replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

async function runSecurityTests() {
  console.log('\n🔒 Starting Focused Cryptographic & Security Verification Suite...\n');
  let passed = 0;
  let total = 0;

  function assert(condition: boolean, testName: string, detail?: string) {
    total++;
    if (condition) {
      console.log(`  ✅ [PASS] ${testName}`);
      passed++;
    } else {
      console.error(`  ❌ [FAIL] ${testName}`);
      if (detail) console.error(`     Reason: ${detail}`);
    }
  }

  // Generate a real RSASSA-PKCS1-v1_5 2048-bit keypair for testing
  const keyPair = await crypto.subtle.generateKey(
    {
      name: 'RSASSA-PKCS1-v1_5',
      modulusLength: 2048,
      publicExponent: new Uint8Array([1, 0, 1]),
      hash: 'SHA-256',
    },
    true,
    ['sign', 'verify']
  );

  const jwkPublic = (await crypto.subtle.exportKey('jwk', keyPair.publicKey)) as GoogleJWK;
  const KEY_ID = 'bvc-test-key-id-001';
  jwkPublic.kid = KEY_ID;
  jwkPublic.use = 'sig';
  jwkPublic.alg = 'RS256';

  // Configure test JWKS inside guard
  FirebaseAuthGuard.setTestJWKS([jwkPublic]);

  // Helper to build and sign JWTs
  async function createSignedToken(headerOverrides = {}, payloadOverrides = {}, customSignKey?: CryptoKey) {
    const now = Math.floor(Date.now() / 1000);
    const header = {
      alg: 'RS256',
      kid: KEY_ID,
      typ: 'JWT',
      ...headerOverrides,
    };
    const payload = {
      iss: `https://securetoken.google.com/${FIREBASE_PROJECT_ID}`,
      aud: FIREBASE_PROJECT_ID,
      auth_time: now - 10,
      user_id: 'firebase_student_real_123',
      sub: 'firebase_student_real_123',
      iat: now - 10,
      exp: now + 3600,
      email: `student@${ALLOWED_EMAIL_DOMAIN}`,
      email_verified: true,
      ...payloadOverrides,
    };

    const headerB64 = base64UrlEncode(JSON.stringify(header));
    const payloadB64 = base64UrlEncode(JSON.stringify(payload));
    const signingInput = `${headerB64}.${payloadB64}`;

    const sig = await crypto.subtle.sign(
      'RSASSA-PKCS1-v1_5',
      customSignKey || keyPair.privateKey,
      new TextEncoder().encode(signingInput)
    );

    const sigB64 = base64UrlEncode(new Uint8Array(sig));
    return `${signingInput}.${sigB64}`;
  }

  // --------------------------------------------------------------------------
  // TEST 1: Valid signed Firebase token -> accepted
  // --------------------------------------------------------------------------
  const validToken = await createSignedToken();
  const req1 = new Request('https://api.nexora.bvc/chat', {
    headers: { Authorization: `Bearer ${validToken}` },
  });
  const res1 = await FirebaseAuthGuard.authenticate(req1, 'production');
  assert(
    res1 !== null && res1.uid === 'firebase_student_real_123' && res1.email === `student@${ALLOWED_EMAIL_DOMAIN}`,
    'Valid signed Firebase token -> accepted'
  );

  // --------------------------------------------------------------------------
  // TEST 2: Forged JWT (malformed or garbage signature) -> rejected
  // --------------------------------------------------------------------------
  const forgedToken = 'eyJhbGciOiJSUzI1NiJ9.eyJzdWIiOiIxMjMifQ.TotallyBogusSignatureString';
  const req2 = new Request('https://api.nexora.bvc/chat', {
    headers: { Authorization: `Bearer ${forgedToken}` },
  });
  const res2 = await FirebaseAuthGuard.authenticate(req2, 'production');
  assert(res2 === null, 'Forged JWT -> rejected');

  // --------------------------------------------------------------------------
  // TEST 3: Correct payload + fake signature -> rejected
  // --------------------------------------------------------------------------
  const parts1 = validToken.split('.');
  const fakeSig = base64UrlEncode(new Uint8Array(256).fill(42));
  const fakeSigToken = `${parts1[0]}.${parts1[1]}.${fakeSig}`;
  const req3 = new Request('https://api.nexora.bvc/chat', {
    headers: { Authorization: `Bearer ${fakeSigToken}` },
  });
  const res3 = await FirebaseAuthGuard.authenticate(req3, 'production');
  assert(res3 === null, 'Correct payload + fake signature -> rejected');

  // --------------------------------------------------------------------------
  // TEST 4: Modified UID + original signature -> rejected
  // --------------------------------------------------------------------------
  const tamperedPayloadUid = JSON.parse(atob(parts1[1].replace(/-/g, '+').replace(/_/g, '/')));
  tamperedPayloadUid.sub = 'firebase_admin_attacker_999';
  tamperedPayloadUid.user_id = 'firebase_admin_attacker_999';
  const tamperedUidB64 = base64UrlEncode(JSON.stringify(tamperedPayloadUid));
  const tamperedUidToken = `${parts1[0]}.${tamperedUidB64}.${parts1[2]}`;
  const req4 = new Request('https://api.nexora.bvc/chat', {
    headers: { Authorization: `Bearer ${tamperedUidToken}` },
  });
  const res4 = await FirebaseAuthGuard.authenticate(req4, 'production');
  assert(res4 === null, 'Modified UID + original signature -> rejected');

  // --------------------------------------------------------------------------
  // TEST 5: Modified email + original signature -> rejected
  // --------------------------------------------------------------------------
  const tamperedPayloadEmail = JSON.parse(atob(parts1[1].replace(/-/g, '+').replace(/_/g, '/')));
  tamperedPayloadEmail.email = 'principal@bvcgroup.in';
  const tamperedEmailB64 = base64UrlEncode(JSON.stringify(tamperedPayloadEmail));
  const tamperedEmailToken = `${parts1[0]}.${tamperedEmailB64}.${parts1[2]}`;
  const req5 = new Request('https://api.nexora.bvc/chat', {
    headers: { Authorization: `Bearer ${tamperedEmailToken}` },
  });
  const res5 = await FirebaseAuthGuard.authenticate(req5, 'production');
  assert(res5 === null, 'Modified email + original signature -> rejected');

  // --------------------------------------------------------------------------
  // TEST 6: Wrong kid (key not in JWKS) -> rejected
  // --------------------------------------------------------------------------
  const wrongKidToken = await createSignedToken({ kid: 'unknown-random-kid-xyz' });
  const req6 = new Request('https://api.nexora.bvc/chat', {
    headers: { Authorization: `Bearer ${wrongKidToken}` },
  });
  const res6 = await FirebaseAuthGuard.authenticate(req6, 'production');
  assert(res6 === null, 'Wrong kid -> rejected');

  // --------------------------------------------------------------------------
  // TEST 7: Unknown kid -> rejected after JWKS refresh attempt
  // --------------------------------------------------------------------------
  FirebaseAuthGuard.resetJWKSCache();
  const unknownKidToken = await createSignedToken({ kid: 'never-seen-kid-999' });
  const req7 = new Request('https://api.nexora.bvc/chat', {
    headers: { Authorization: `Bearer ${unknownKidToken}` },
  });
  const res7 = await FirebaseAuthGuard.authenticate(req7, 'production');
  assert(res7 === null, 'Unknown kid -> rejected after JWKS refresh');

  // --------------------------------------------------------------------------
  // TEST 8: Strict Audience verification (aud !== FIREBASE_PROJECT_ID) -> rejected
  // --------------------------------------------------------------------------
  const wrongAudToken = await createSignedToken({}, { aud: 'other-firebase-app' });
  const req8 = new Request('https://api.nexora.bvc/chat', {
    headers: { Authorization: `Bearer ${wrongAudToken}` },
  });
  const res8 = await FirebaseAuthGuard.authenticate(req8, 'production');
  assert(res8 === null, 'Audience mismatch (strict aud check) -> rejected');

  // --------------------------------------------------------------------------
  // TEST 9: Dev test token when environment is undefined or production -> rejected
  // --------------------------------------------------------------------------
  const req9a = new Request('https://api.nexora.bvc/chat', {
    headers: { Authorization: 'Bearer dev_test_uid_malicious' },
  });
  const res9a = await FirebaseAuthGuard.authenticate(req9a, undefined);
  const res9b = await FirebaseAuthGuard.authenticate(req9a, 'production');
  assert(res9a === null && res9b === null, 'Dev test token with undefined/production environment -> rejected');

  // --------------------------------------------------------------------------
  // TEST 10: Dev test token when environment is explicitly development/test -> accepted
  // --------------------------------------------------------------------------
  const req10 = new Request('https://api.nexora.bvc/chat', {
    headers: { Authorization: 'Bearer dev_test_uid_tester' },
  });
  const res10 = await FirebaseAuthGuard.authenticate(req10, 'development');
  assert(
    res10 !== null && res10.uid === 'dev_test_uid_tester',
    'Dev test token with explicit development environment -> accepted'
  );

  // --------------------------------------------------------------------------
  // TEST 11: Generic Firebase vs BVC domain authorization
  // --------------------------------------------------------------------------
  const outsiderToken = await createSignedToken({}, { email: 'guest@externalcompany.com' });
  const req11 = new Request('https://api.nexora.bvc/chat', {
    headers: { Authorization: `Bearer ${outsiderToken}` },
  });
  // Generic authentication accepts valid Firebase user
  const res11Generic = await FirebaseAuthGuard.authenticate(req11, { environment: 'production', requireBvcDomain: false });
  // BVC student authorization rejects non-BVC domain
  const res11Student = await FirebaseAuthGuard.authenticate(req11, { environment: 'production', requireBvcDomain: true });
  assert(
    res11Generic !== null &&
    res11Generic.email === 'guest@externalcompany.com' &&
    res11Student === null,
    'Generic Firebase user accepted for general auth, rejected for BVC-only routes'
  );

  console.log(`\n📊 Security Test Results: ${passed} / ${total} passed (${Math.round((passed / total) * 100)}%)\n`);

  if (passed !== total) {
    process.exit(1);
  }
}

runSecurityTests().catch((err) => {
  console.error('Fatal test error:', err);
  process.exit(1);
});
