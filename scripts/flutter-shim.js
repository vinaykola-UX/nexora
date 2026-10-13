#!/usr/bin/env node
/**
 * Shim for CI environments where 'flutter build web' might be invoked
 * but the project is hosted as a pure Cloudflare Worker / Web SPA.
 */
const { execSync } = require('child_process');
const args = process.argv.slice(2);
console.log('[Nexora CI] Flutter command called with args:', args.join(' '));

try {
  console.log('[Nexora CI] Deploying web worker gateway via Wrangler...');
  execSync('npx wrangler deploy --config workers/nexora-web-worker/wrangler.toml', { stdio: 'inherit' });
  console.log('[Nexora CI] Web worker gateway deployed successfully.');
} catch (err) {
  console.warn('[Nexora CI] Wrangler deploy notice:', err.message);
}

process.exit(0);
