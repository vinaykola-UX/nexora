import { NotificationStorage } from './notifications/notification_storage';
import { TargetingEngine } from './notifications/targeting_engine';
import { ResultProcessor } from './notifications/result_processor';
import { FCMV1Service } from './notifications/fcm_v1_service';
import { NotificationTarget, RawResultInputRecord } from './notifications/notification_types';
/**
 * Nexora BVC AI — Cloudflare Worker Backend & RAG Management API
 * Service: nexora-bvc-api-2026
 *
 * Endpoints:
 * - GET    /health                     : Health check
 * - GET    /api                        : Endpoint discovery
 * - GET    /documents                  : List all documents in D1 knowledge base
 * - GET    /search?q=QUERY             : Multi-document RAG search across D1 chunks
 * - POST   /admin/upload               : Admin upload & deterministic chunking into D1
 * - DELETE /admin/document/:id         : Admin delete document & associated chunks
 * - GET    /admin/document/:id         : Admin get document details & chunks
 * - POST   /ask                        : Grounded AI generation
 */

import { AIService, EnvAIConfig } from './ai/ai_service';
import { ADSSearchPipeline } from './ads/pipeline';
import { AIController } from './ai/ai_controller';
import { semanticSearch } from './rag/semantic_search';
import { mergeRetrievalSignals, calculateHybridScores } from './rag/hybrid_ranker';
import { backfillChunksToVectorize, syncChunkToVectorize } from './rag/vector_sync';
import { EMBEDDING_CONFIG } from './rag/embedding_service';
import { FirebaseAuthGuard } from './bvc/firebase_auth_guard';
import { BVCService } from './bvc/bvc_service';
import { BVCStorage } from './bvc/bvc_storage';
import { BVCNormalizer } from './bvc/bvc_normalizer';

export interface Env extends EnvAIConfig {
  ENVIRONMENT?: string;
  ADMIN_SECRET?: string;
  DB?: D1Database;
  VECTORIZE?: VectorizeIndex;
  EMBEDDING_MODEL?: string;
  AI_MODEL?: string;
  XAI_MODEL?: string;
  XAI_API_KEY_1?: string;
  XAI_API_KEY_2?: string;
}

interface SearchResult {
  title: string;
  url: string;
  source: string;
  snippet: string;
  publishedDate: string | null;
}

interface SourceInfo {
  title: string;
  url: string;
  source?: string;
}

interface D1DocumentRow {
  id: number;
  title: string;
  subject: string;
  unit: number;
  file_url?: string | null;
  created_at?: string;
  chunk_count?: number;
}

interface D1ChunkRow {
  id: number;
  document_id: number;
  content: string;
  chunk_index: number;
  created_at?: string;
  title?: string;
  subject?: string;
  unit?: number;
}

// ---------------------------------------------------------------------------
// Security & Allowlist Configuration
// ---------------------------------------------------------------------------
export interface TrustedSite {
  id?: number;
  url: string;
  label?: string;
  verified?: boolean;
  created_at?: string;
}

const DEFAULT_TRUSTED_SITES: TrustedSite[] = [
  { url: 'bvcec.edu.in', label: 'BVC Engineering College Main Portal', verified: true },
  { url: 'www.bvcecautonomous.com', label: 'BVC Autonomous Examination Cell', verified: true },
];

const ALLOWED_HOSTS = new Set([
  'bvcec.edu.in',
  'www.bvcec.edu.in',
  'bvcecautonomous.com',
  'www.bvcecautonomous.com',
]);

async function ensureTrustedSitesTable(env?: Env): Promise<void> {
  if (!env?.DB) return;
  try {
    await env.DB.prepare(
      `CREATE TABLE IF NOT EXISTS trusted_sites (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        url TEXT UNIQUE NOT NULL,
        label TEXT,
        verified INTEGER DEFAULT 1,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )`
    ).run();

    const countRow = await env.DB.prepare(`SELECT COUNT(*) as count FROM trusted_sites`).first<{ count: number }>();
    if (!countRow || countRow.count === 0) {
      for (const site of DEFAULT_TRUSTED_SITES) {
        await env.DB.prepare(
          `INSERT OR IGNORE INTO trusted_sites (url, label, verified) VALUES (?, ?, 1)`
        ).bind(site.url, site.label).run();
      }
    }
  } catch (e) {
    console.warn('[Nexora Worker] ensureTrustedSitesTable warning:', e);
  }
}

async function getActiveTrustedSites(
  env?: Env,
  customSites?: Array<string | TrustedSite>
): Promise<TrustedSite[]> {
  if (Array.isArray(customSites) && customSites.length > 0) {
    return customSites
      .map((s) => {
        if (typeof s === 'string') {
          const clean = s.trim().replace(/^https?:\/\//i, '').replace(/\/+$/, '');
          return { url: clean, label: clean, verified: true };
        }
        const clean = (s?.url || '').trim().replace(/^https?:\/\//i, '').replace(/\/+$/, '');
        return {
          url: clean,
          label: s?.label || clean,
          verified: s?.verified !== false,
        };
      })
      .filter((s) => s.url.length > 0);
  }

  if (env?.DB) {
    try {
      await ensureTrustedSitesTable(env);
      const { results } = await env.DB.prepare(
        `SELECT id, url, label, verified, created_at FROM trusted_sites ORDER BY id ASC`
      ).all<TrustedSite>();

      if (results && results.length > 0) {
        return results.map((r) => ({
          id: r.id,
          url: r.url,
          label: r.label || r.url,
          verified: Boolean(r.verified),
          created_at: r.created_at,
        }));
      }
    } catch (e) {
      console.warn('[Nexora Worker] getActiveTrustedSites error:', e);
    }
  }

  return [...DEFAULT_TRUSTED_SITES];
}

const USER_AGENT =
  'NexoraBot/1.0 (+https://bvcec.edu.in; BVC Engineering College AI Assistant)';
const FETCH_TIMEOUT_MS = 7500;
const MAX_RESULTS = 5;
const MAX_QUESTION_LENGTH = 500;
const DEFAULT_ADMIN_SECRET = 'nexora-admin-secure-key-2026';

// Standard CORS headers for cross-origin app and admin webpage requests
const CORS_HEADERS: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, DELETE, PUT, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Admin-Key, X-Requested-With, Accept',
  'Access-Control-Max-Age': '86400',
};

const aiService = new AIService();

// ---------------------------------------------------------------------------
// Helper Utilities
// ---------------------------------------------------------------------------

function jsonResponse(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data, null, 2), {
    status,
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
      ...CORS_HEADERS,
    },
  });
}

function verifyAdminAuth(request: Request, env: Env): boolean {
  const expectedSecret = env.ADMIN_SECRET?.trim() || DEFAULT_ADMIN_SECRET;

  const authHeader = request.headers.get('Authorization') || '';
  if (authHeader.startsWith('Bearer ')) {
    const token = authHeader.substring(7).trim();
    if (token === expectedSecret) return true;
  }

  const keyHeader = request.headers.get('X-Admin-Key') || '';
  if (keyHeader.trim() === expectedSecret) return true;

  return false;
}

/**
 * Deterministic chunking utility: splits study text into 800 - 1500 character chunks
 * preserving paragraph and sentence boundaries.
 */
function chunkStudyContent(
  text: string,
  metadata: { subject: string; unit: number; topic?: string; title: string },
  minChunkSize = 600,
  maxChunkSize = 1400
): string[] {
  const cleanText = text.replace(/\r\n/g, '\n').trim();
  if (!cleanText) return [];

  const paragraphs = cleanText.split(/\n\s*\n+/);
  const chunks: string[] = [];
  let currentChunk = '';

  const headerPrefix = metadata.topic?.trim()
    ? `SUBJECT: ${metadata.subject} | UNIT: ${metadata.unit} | TOPIC: ${metadata.topic.trim().toUpperCase()}\n\n`
    : `SUBJECT: ${metadata.subject} | UNIT: ${metadata.unit} | TITLE: ${metadata.title.trim()}\n\n`;

  for (const para of paragraphs) {
    const trimmedPara = para.trim();
    if (!trimmedPara) continue;

    if (trimmedPara.length > maxChunkSize) {
      // Split large paragraph into sentences
      const sentences = trimmedPara.match(/[^.!?]+[.!?]+(?:\s+|$)|[^.!?]+$/g) || [trimmedPara];
      for (const sentence of sentences) {
        const trimmedSentence = sentence.trim();
        if (!trimmedSentence) continue;

        if (currentChunk.length + trimmedSentence.length + 1 > maxChunkSize) {
          if (currentChunk.trim().length >= minChunkSize) {
            chunks.push(currentChunk.trim());
            currentChunk = '';
          }
        }
        currentChunk = currentChunk ? `${currentChunk} ${trimmedSentence}` : trimmedSentence;
      }
    } else {
      if (currentChunk.length + trimmedPara.length + 2 > maxChunkSize) {
        if (currentChunk.trim().length >= minChunkSize) {
          chunks.push(currentChunk.trim());
          currentChunk = '';
        }
      }
      currentChunk = currentChunk ? `${currentChunk}\n\n${trimmedPara}` : trimmedPara;
    }
  }

  if (currentChunk.trim()) {
    chunks.push(currentChunk.trim());
  }

  return chunks.map((chunk) => {
    // If chunk does not already have a unit or subject header, add it
    if (
      !chunk.toUpperCase().includes('UNIT ') &&
      !chunk.toUpperCase().includes(metadata.subject.toUpperCase())
    ) {
      return `${headerPrefix}${chunk}`;
    }
    return chunk;
  });
}

function decodeHtmlEntities(str: string): string {
  if (!str) return '';
  return str
    .replace(/&#8211;/g, '–')
    .replace(/&#8212;/g, '—')
    .replace(/&#8216;/g, "‘")
    .replace(/&#8217;/g, "’")
    .replace(/&#8220;/g, '“')
    .replace(/&#8221;/g, '”')
    .replace(/&#038;/g, '&')
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&#039;/g, "'")
    .replace(/&#39;/g, "'")
    .replace(/&nbsp;/g, ' ')
    .replace(/&#\d+;/g, (match) => {
      const num = parseInt(match.replace(/&#|;/g, ''), 10);
      return !isNaN(num) ? String.fromCharCode(num) : '';
    });
}

function removeBoilerplateHtml(html: string): string {
  if (!html) return '';
  let cleaned = html;
  cleaned = cleaned.replace(/<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/gi, ' ');
  cleaned = cleaned.replace(/<style\b[^<]*(?:(?!<\/style>)<[^<]*)*<\/style>/gi, ' ');
  cleaned = cleaned.replace(/<noscript\b[^<]*(?:(?!<\/noscript>)<[^<]*)*<\/noscript>/gi, ' ');
  cleaned = cleaned.replace(/<nav\b[^<]*(?:(?!<\/nav>)<[^<]*)*<\/nav>/gi, ' ');
  cleaned = cleaned.replace(/<footer\b[^<]*(?:(?!<\/footer>)<[^<]*)*<\/footer>/gi, ' ');
  cleaned = cleaned.replace(/<header\b[^<]*(?:(?!<\/header>)<[^<]*)*<\/header>/gi, ' ');
  cleaned = cleaned.replace(/<[^>]+>/g, ' ');
  cleaned = decodeHtmlEntities(cleaned);
  cleaned = cleaned.replace(/\s+/g, ' ').trim();
  return cleaned;
}

function cleanExcerpt(excerpt: string): string {
  if (!excerpt) return '';
  return removeBoilerplateHtml(excerpt);
}

function extractSearchKeywords(query: string): string {
  const stopWords = new Set([
    'what', 'is', 'the', 'a', 'an', 'for', 'in', 'of', 'and', 'to', 'how',
    'why', 'when', 'where', 'who', 'can', 'i', 'get', 'my', 'me', 'please',
    'tell', 'about', 'bvcec', 'bvc', 'engineering', 'college', 'b.tech', 'btech',
  ]);

  const words = query
    .toLowerCase()
    .replace(/[^a-z0-9\s]/g, ' ')
    .split(/\s+/)
    .filter((w) => w.length > 1 && !stopWords.has(w));

  return words.length > 0 ? words.join(' ') : query;
}

// ---------------------------------------------------------------------------
// External Portal Scraper
// ---------------------------------------------------------------------------

async function searchOfficialSources(
  rawQuery: string,
  customSites?: Array<string | TrustedSite>,
  env?: Env
): Promise<{
  results: SearchResult[];
  sources: SourceInfo[];
}> {
  const query = rawQuery.trim();
  const activeSources: SourceInfo[] = [];
  const results: SearchResult[] = [];
  const encodedQuery = encodeURIComponent(query);

  const trustedSites = await getActiveTrustedSites(env, customSites);

  // Dynamically expand ALLOWED_HOSTS so external results from all configured portals pass security checks
  for (const s of trustedSites) {
    const host = s.url.toLowerCase();
    ALLOWED_HOSTS.add(host);
    if (!host.startsWith('www.')) {
      ALLOWED_HOSTS.add(`www.${host}`);
    } else {
      ALLOWED_HOSTS.add(host.replace(/^www\./, ''));
    }
  }

  // Construct search endpoints across all configured websites (WordPress posts & pages API)
  const endpointsToFetch: Array<{ url: string; sourceTitle: string; sourceHost: string }> = [];
  for (const s of trustedSites) {
    const cleanHost = s.url.replace(/^https?:\/\//i, '').replace(/\/+$/, '');
    const label = s.label || cleanHost;
    endpointsToFetch.push(
      { url: `https://${cleanHost}/wp-json/wp/v2/posts?search=${encodedQuery}&per_page=5`, sourceTitle: label, sourceHost: cleanHost },
      { url: `https://${cleanHost}/wp-json/wp/v2/pages?search=${encodedQuery}&per_page=5`, sourceTitle: label, sourceHost: cleanHost }
    );
  }

  const keywords = extractSearchKeywords(query);
  if (keywords !== query && keywords.length > 0) {
    const encodedKeywords = encodeURIComponent(keywords);
    for (const s of trustedSites) {
      const cleanHost = s.url.replace(/^https?:\/\//i, '').replace(/\/+$/, '');
      const label = s.label || cleanHost;
      endpointsToFetch.push(
        { url: `https://${cleanHost}/wp-json/wp/v2/posts?search=${encodedKeywords}&per_page=5`, sourceTitle: label, sourceHost: cleanHost },
        { url: `https://${cleanHost}/wp-json/wp/v2/pages?search=${encodedKeywords}&per_page=5`, sourceTitle: label, sourceHost: cleanHost }
      );
    }
  }

  const fetchWithTimeout = async (urlStr: string): Promise<Response | null> => {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), FETCH_TIMEOUT_MS);
    try {
      const resp = await fetch(urlStr, {
        headers: {
          'User-Agent': USER_AGENT,
          Accept: 'application/json',
        },
        signal: controller.signal,
      });
      clearTimeout(timeout);
      return resp;
    } catch {
      clearTimeout(timeout);
      return null;
    }
  };

  const processEndpoint = async (ep: { url: string; sourceTitle: string; sourceHost: string }) => {
    try {
      const resp = await fetchWithTimeout(ep.url);
      if (!resp || !resp.ok) return;

      const items = (await resp.json()) as any[];
      if (!Array.isArray(items)) return;

      for (const item of items) {
        if (!item || typeof item !== 'object') continue;
        const itemUrl: string = item.link || '';
        try {
          const parsed = new URL(itemUrl);
          if (!ALLOWED_HOSTS.has(parsed.hostname)) continue;
        } catch {
          continue;
        }

        if (results.some((r) => r.url === itemUrl)) continue;

        const rawTitle: string = item.title?.rendered || item.title || '';
        const title = decodeHtmlEntities(rawTitle).trim() || `${ep.sourceTitle} Notice`;
        const rawContent: string = item.content?.rendered || item.excerpt?.rendered || '';
        const snippet = cleanExcerpt(rawContent) || cleanExcerpt(rawTitle);
        const publishedDate: string | null = item.date
          ? new Date(item.date).toLocaleDateString('en-US', {
              year: 'numeric',
              month: 'long',
              day: 'numeric',
            })
          : null;

        results.push({
          title,
          url: itemUrl,
          source: ep.sourceTitle,
          snippet: snippet.length > 280 ? `${snippet.substring(0, 277)}...` : snippet,
          publishedDate,
        });

        if (results.length >= MAX_RESULTS * 2) break;
      }
    } catch (_) {}
  };

  await Promise.all(endpointsToFetch.map(processEndpoint));

  const queryLower = query.toLowerCase();
  const isExamQuery =
    queryLower.includes('exam') ||
    queryLower.includes('fee') ||
    queryLower.includes('result') ||
    queryLower.includes('grade') ||
    queryLower.includes('notification') ||
    queryLower.includes('circular') ||
    queryLower.includes('timetable') ||
    queryLower.includes('br23');

  if (isExamQuery) {
    const examSite = trustedSites.find(
      (s) => s.url.includes('autonomous') || s.url.includes('exam') || (s.label || '').toLowerCase().includes('exam')
    ) || { url: 'www.bvcecautonomous.com', label: 'BVC Autonomous Examination Cell' };

    const examCellUrl = examSite.url.startsWith('http') ? examSite.url : `https://${examSite.url}`;
    if (!results.some((r) => r.url.includes('autonomous'))) {
      results.unshift({
        title: `${examSite.label || 'Autonomous Examination'} Portal & Notifications`,
        url: examCellUrl,
        source: examSite.label || 'BVC Autonomous Examination Cell',
        snippet:
          'Official autonomous examinations portal. Access end examination fee schedules, last date notifications, results, student logins, and academic grade sheets directly from the Examination Cell.',
        publishedDate: null,
      });
    }
  }

  // Include active sources for all configured sites
  for (const s of trustedSites) {
    const fullUrl = s.url.startsWith('http') ? s.url : `https://${s.url}`;
    activeSources.push({
      title: s.label || s.url,
      url: fullUrl,
      source: s.label || s.url,
    });
  }

  return {
    results: results.slice(0, MAX_RESULTS * 2),
    sources: activeSources,
  };
}

// ---------------------------------------------------------------------------
// Worker Request Router
// ---------------------------------------------------------------------------

export default {
  async fetch(request: Request, env: Env, _ctx: ExecutionContext): Promise<Response> {
    // Handle CORS preflight
    if (request.method === 'OPTIONS') {
      return new Response(null, {
        status: 204,
        headers: CORS_HEADERS,
      });
    }

    const url = new URL(request.url);
    const path = url.pathname.replace(/\/$/, '') || '/';

    try {
      // 1. Root route
      if (request.method === 'GET' && path === '/') {
        return jsonResponse({
          success: true,
          service: 'nexora-bvc-api-2026',
          version: '3.1.0',
          status: 'online',
          message: 'Nexora BVC AI — Hybrid Semantic RAG + ADS Engine + Invisible Tone Engine',
        });
      }

      // 1b. Preflight verification route (GET /preflight) — billing/model safety check
      if (request.method === 'GET' && path === '/preflight') {
        const report: Record<string, any> = { timestamp: new Date().toISOString(), checks: {} };

        // Check 1: Workers AI binding
        report.checks.workersAI = env.AI && typeof env.AI.run === 'function'
          ? { status: 'PASS', detail: 'env.AI bound and callable' }
          : { status: 'FAIL', detail: 'env.AI missing — check [ai] binding in wrangler.toml' };

        // Check 2: Embedding model returns exactly 384 dimensions
        const embModel = env.EMBEDDING_MODEL || '@cf/baai/bge-small-en-v1.5';
        if (env.AI && typeof env.AI.run === 'function') {
          try {
            const t0 = performance.now();
            const resp = await env.AI.run(embModel, { text: ['BVC Nexora preflight embedding verification'] });
            const vec: number[] | undefined = resp?.data?.[0] ?? resp?.result?.data?.[0];
            const elapsed = Math.round(performance.now() - t0);
            if (!vec || !Array.isArray(vec)) {
              report.checks.embeddingModel = { status: 'FAIL', model: embModel, detail: 'No vector returned', raw: JSON.stringify(resp).slice(0, 200) };
            } else if (vec.length !== 384) {
              report.checks.embeddingModel = { status: 'FAIL', model: embModel, dimension: vec.length, expected: 384, detail: `DIMENSION MISMATCH: ${vec.length} !== 384. STOP — do not proceed with backfill.` };
            } else {
              report.checks.embeddingModel = { status: 'PASS', model: embModel, dimension: 384, latencyMs: elapsed, sample: vec.slice(0, 4).map((v: number) => +v.toFixed(6)) };
            }
          } catch (e: any) {
            report.checks.embeddingModel = { status: 'FAIL', model: embModel, detail: e?.message || String(e) };
          }
        } else {
          report.checks.embeddingModel = { status: 'SKIP', detail: 'Workers AI unavailable, cannot test' };
        }

        // Check 3: Vectorize binding
        report.checks.vectorize = env.VECTORIZE
          ? { status: 'PASS', detail: 'env.VECTORIZE bound' }
          : { status: 'FAIL', detail: 'env.VECTORIZE missing — check [[vectorize]] in wrangler.toml' };

        // Check 4: Vectorize index describe
        if (env.VECTORIZE) {
          try {
            const info = await (env.VECTORIZE as any).describe();
            const dim = info?.dimensions ?? info?.config?.dimensions;
            const metric = info?.metric ?? info?.config?.metric ?? 'cosine';
            report.checks.vectorizeIndex = {
              status: dim === 384 ? 'PASS' : (dim ? 'FAIL' : 'WARN'),
              indexName: 'nexora-vector-index', dimension: dim, metric, vectorCount: info?.vectorCount ?? 0,
              detail: dim === 384 ? '384 dims cosine — matches embedding model ✓' : `dim=${dim}, expected 384`
            };
          } catch (e: any) {
            report.checks.vectorizeIndex = { status: 'WARN', detail: `describe() failed: ${e?.message}` };
          }
        }

        // Check 5: Vectorize roundtrip upsert+query
        if (env.VECTORIZE && report.checks.embeddingModel?.status === 'PASS') {
          try {
            const tv = (await env.AI.run(embModel, { text: ['nexora roundtrip test'] }))?.data?.[0];
            await env.VECTORIZE.upsert([{ id: 'nexora-preflight-test', values: tv, metadata: { type: 'test' } }]);
            const qr = await env.VECTORIZE.query(tv, { topK: 1, returnMetadata: 'indexed' });
            const match = qr?.matches?.[0];
            report.checks.vectorizeRoundTrip = {
              status: match?.id === 'nexora-preflight-test' ? 'PASS' : 'WARN',
              detail: match ? `upsert→query: id=${match.id}, score=${match.score?.toFixed(6)}` : 'No match returned (may propagate shortly)'
            };
            try { await env.VECTORIZE.deleteByIds(['nexora-preflight-test']); } catch (_) {}
          } catch (e: any) {
            report.checks.vectorizeRoundTrip = { status: 'FAIL', detail: e?.message };
          }
        }

        const checks = Object.values(report.checks) as any[];
        const fails = checks.filter((c) => c.status === 'FAIL').length;
        report.billing = {
          workersAI: 'Free tier: 10,000 neurons/day. BGE-small embeddings use ~1 neuron per call. 15 chunks + queries = well within free limits.',
          vectorize: 'Free tier: 5,000,000 vectors stored, 30,000,000 queried/month. 15 vectors is negligible.',
          paidServicesRequired: false,
          note: 'No paid plan activation required for Phase 4 with current data volume (15 chunks).'
        };
        report.summary = {
          passed: checks.filter((c) => c.status === 'PASS').length,
          failed: fails,
          warned: checks.filter((c) => c.status === 'WARN').length,
          readyForPhase4Backfill: fails === 0,
          recommendation: fails === 0 ? 'PROCEED — all checks passed. Backfill is safe.' : 'STOP — resolve FAIL items before backfill.'
        };
        return jsonResponse(report, fails > 0 ? 503 : 200);
      }

      // 2. Health check route
      if (request.method === 'GET' && path === '/health') {
        return jsonResponse({
          status: 'healthy',
          service: 'nexora-bvc-api-2026',
          timestamp: new Date().toISOString(),
          uptime: 'operational',
        });
      }

      // 3. API documentation / discovery route
      if (request.method === 'GET' && path === '/api') {
        return jsonResponse({
          success: true,
          service: 'nexora-bvc-api-2026',
          version: '2.1.0',
          endpoints: [
            { method: 'GET', path: '/health', description: 'Service health check' },
            { method: 'GET', path: '/documents', description: 'List all documents in D1 knowledge base' },
            { method: 'GET', path: '/search?q=<query>', description: 'Search across all study chunks in D1 database using ADS Engine' },
            { method: 'POST', path: '/admin/upload', description: 'Upload and chunk new study material into D1 (Admin)' },
            { method: 'DELETE', path: '/admin/document/:id', description: 'Delete a document and its chunks from D1 (Admin)' },
            { method: 'POST', path: '/chat', description: 'Grounded AI with controlled tools & ADS retrieval' },
            { method: 'POST', path: '/ask', description: 'Grounded AI question answering' },
          ],
        });
      }

      // 4. List Documents Route (GET /documents)
      if (request.method === 'GET' && path === '/documents') {
        if (env.DB) {
          try {
            const { results } = await env.DB.prepare(
              `SELECT d.id, d.title, d.subject, d.unit, d.file_url, d.created_at, COUNT(c.id) as chunk_count
               FROM documents d
               LEFT JOIN chunks c ON d.id = c.document_id
               GROUP BY d.id
               ORDER BY d.id DESC`
            ).all<D1DocumentRow>();

            return jsonResponse(results || []);
          } catch (d1Err: any) {
            console.error('[Nexora Worker] D1 GET /documents error:', d1Err?.message || d1Err);
            // Fallback query without count
            try {
              const { results } = await env.DB.prepare(
                `SELECT id, title, subject, unit, file_url, created_at FROM documents ORDER BY id DESC`
              ).all<D1DocumentRow>();
              return jsonResponse(results || []);
            } catch (_) {}
          }
        }

        // Mock fallback if DB is not bound
        return jsonResponse([
          {
            id: 1,
            title: 'Data Structures - Unit II: Linked Lists',
            subject: 'Data Structures',
            unit: 2,
            chunk_count: 5,
            created_at: new Date().toISOString(),
          },
        ]);
      }

      // 5. Multi-Document Scalable Search Route (GET /search?q=...)
      if (request.method === 'GET' && path === '/search') {
        const query = url.searchParams.get('q');

        if (query === null || query.trim() === '') {
          return jsonResponse(
            {
              success: false,
              error: 'Bad Request',
              message: "Query parameter 'q' is required and cannot be empty.",
            },
            400
          );
        }

        const trimmedQuery = query.trim();
        const isDebug = url.searchParams.get('debug') === 'true';
        const limitParam = parseInt(url.searchParams.get('limit') || '10', 10);
        const topK = isNaN(limitParam) ? 10 : Math.max(1, Math.min(20, limitParam));

        // Step 1: Hybrid Search — ADS Engine + Vectorize Semantic + GraphRAG
        if (env.DB) {
          try {
            const { results: allRows } = await env.DB.prepare(
              `SELECT c.id, c.document_id, c.content, d.title, d.subject, d.unit, c.chunk_index
               FROM chunks c
               JOIN documents d ON c.document_id = d.id
               ORDER BY d.unit ASC, c.chunk_index ASC`
            ).all<D1ChunkRow>();

            if (allRows && allRows.length > 0) {
              // Stage A: ADS Pipeline (Hash Table → AVL → Graph → Heap → Merge Sort)
              const pipeline = ADSSearchPipeline.getInstance();
              pipeline.buildIndex(allRows as any);
              const { results: adsRankedResults, debug: adsDebugInfo } = pipeline.search(
                trimmedQuery,
                topK * 2,
                isDebug
              );

              // Stage B: Vectorize Semantic Search
              let vectorResult: any = null;
              let vectorAvailable = false;
              try {
                vectorResult = await semanticSearch(trimmedQuery, topK * 2, env);
                vectorAvailable = vectorResult.vectorStatus === 'success';
              } catch (vecErr: any) {
                console.warn('[Nexora Worker] Vectorize search error (falling back to ADS-only):', vecErr?.message);
              }

              // Build chunk ID → row lookup
              const chunkIdToRow = new Map<number, typeof allRows[0]>();
              for (const row of allRows) {
                if (row.id) chunkIdToRow.set(row.id, row);
              }

              // ADS results mapped by chunk ID with scores
              const adsSignals: Array<{ chunkId: number; adsScore: number }> = [];
              for (const r of adsRankedResults) {
                // Find chunk ID from allRows by matching content
                for (const row of allRows) {
                  if (row.content === r.content && row.id) {
                    adsSignals.push({ chunkId: row.id, adsScore: r.relevanceScore });
                    break;
                  }
                }
              }

              // Vector candidates
              const vectorSignals: Array<{ chunkId: number; vectorScore: number }> = [];
              if (vectorAvailable && vectorResult?.candidates) {
                for (const c of vectorResult.candidates) {
                  vectorSignals.push({ chunkId: c.chunkId, vectorScore: c.score });
                }
              }

              // Stage C: Hybrid Ranking
              const mergedSignals = mergeRetrievalSignals(adsSignals, vectorSignals);
              const hybridScores = calculateHybridScores(mergedSignals, {
                vectorAvailable,
                graphAvailable: true,
              });

              // Sort by hybrid score descending, take topK
              hybridScores.sort((a, b) => b.hybridScore - a.hybridScore);
              const topHybrid = hybridScores.slice(0, topK);

              // Resolve chunk content from D1 rows
              const hybridResults = topHybrid
                .map((h) => {
                  const row = chunkIdToRow.get(h.chunkId);
                  if (!row) return null;
                  return {
                    content: row.content,
                    title: row.title || '',
                    subject: row.subject || '',
                    unit: row.unit || 0,
                    hybridScore: h.hybridScore,
                    ...(isDebug ? {
                      scoring: {
                        normalizedAds: h.normalizedAds,
                        normalizedVector: h.normalizedVector,
                        normalizedGraph: h.normalizedGraph,
                        weights: h.weightsUsed,
                      }
                    } : {}),
                  };
                })
                .filter(Boolean);

              if (hybridResults.length > 0) {
                return jsonResponse({
                  query: trimmedQuery,
                  results: hybridResults,
                  retrieval: {
                    mode: vectorAvailable ? 'hybrid_semantic_ads' : 'ads_only',
                    adsResultCount: adsSignals.length,
                    vectorResultCount: vectorSignals.length,
                    hybridCandidates: mergedSignals.length,
                  },
                  ...(isDebug ? {
                    pipeline: adsDebugInfo,
                    vectorize: vectorResult ? {
                      status: vectorResult.vectorStatus,
                      embeddingModel: vectorResult.embeddingModel,
                      queryDimension: vectorResult.queryDimension,
                      timingMs: vectorResult.timingMs,
                      candidateCount: vectorResult.candidates?.length || 0,
                    } : null,
                  } : {}),
                });
              }

              // Fallback: if hybrid returned nothing, use ADS-only results
              if (adsRankedResults.length > 0) {
                return jsonResponse({
                  query: trimmedQuery,
                  results: adsRankedResults.slice(0, topK).map((r) => ({
                    content: r.content,
                    title: r.title,
                    subject: r.subject,
                    unit: r.unit,
                  })),
                  retrieval: { mode: 'ads_fallback' },
                  ...(isDebug && adsDebugInfo ? { pipeline: adsDebugInfo } : {}),
                });
              }
            }
          } catch (d1Err: any) {
            console.error('[Nexora Worker] Hybrid Search Error:', d1Err?.message || d1Err);
          }
        }

        // Step 2: Fallback search against configured trusted college portals (multi-site)
        const sitesParam = url.searchParams.get('sites');
        const customSites = sitesParam ? sitesParam.split(',').map((s) => s.trim()).filter(Boolean) : undefined;
        const { results: portalResults, sources } = await searchOfficialSources(trimmedQuery, customSites, env);

        if (portalResults.length > 0) {
          return jsonResponse({
            success: true,
            query: trimmedQuery,
            results: portalResults.map((p) => ({
              ...p,
              content: p.snippet || p.title,
            })),
            sources,
          });
        }

        return jsonResponse({
          success: true,
          query: trimmedQuery,
          results: [],
          message: 'No matching study chunks or portal notices were found for this query.',
        });
      }

      // 6. Admin Upload Study Material (POST /admin/upload)
      if (request.method === 'POST' && path === '/admin/upload') {
        if (!verifyAdminAuth(request, env)) {
          return jsonResponse(
            {
              success: false,
              error: 'Unauthorized',
              message: 'Invalid or missing admin authorization token. Pass Authorization: Bearer <ADMIN_SECRET>.',
            },
            401
          );
        }

        let body: any;
        try {
          body = await request.json();
        } catch {
          return jsonResponse(
            {
              success: false,
              error: 'Bad Request',
              message: 'Invalid JSON body. Required: { title, subject, chunks: [...] }',
            },
            400
          );
        }

        const title = (body?.title || '').trim();
        const subject = (body?.subject || '').trim();
        const unit = parseInt(String(body?.unit || body?.academicUnit || '1'), 10) || 1;
        const topic = (body?.topic || '').trim();
        const content = (body?.content || '').trim();
        const rawChunks = body?.chunks;

        if (!title || typeof title !== 'string' || !title.trim()) {
          return jsonResponse(
            {
              success: false,
              error: 'Validation Error',
              message: 'Title is required and cannot be empty.',
            },
            400
          );
        }

        if (!subject || typeof subject !== 'string' || !subject.trim()) {
          return jsonResponse(
            {
              success: false,
              error: 'Validation Error',
              message: 'Subject is required and cannot be empty.',
            },
            400
          );
        }

        let chunkTexts: string[] = [];
        if (Array.isArray(rawChunks) && rawChunks.length > 0) {
          // Reject payload if any item in chunks is null or empty/whitespace
          for (let i = 0; i < rawChunks.length; i++) {
            const c = rawChunks[i];
            const text = (typeof c === 'string' ? c : (c && typeof c === 'object' ? (c.text || c.content) : '')) || '';
            if (typeof text !== 'string' || !text.trim()) {
              return jsonResponse(
                {
                  success: false,
                  error: 'Validation Error',
                  message: `Chunk #${i + 1} is empty or whitespace-only. All chunks must contain valid content.`,
                },
                400
              );
            }
            chunkTexts.push(text.trim());
          }
        } else if (content) {
          chunkTexts = chunkStudyContent(content, { subject, unit, topic, title });
        }

        if (chunkTexts.length === 0) {
          return jsonResponse(
            {
              success: false,
              error: 'Empty Content',
              message: 'Invalid payload: title, subject, and chunks[] are required and cannot be empty.',
            },
            400
          );
        }

        // Composite metadata descriptor for document table
        const sourceName = (body?.source || '').trim();
        const pageInfo = (body?.page_info || '').trim();
        const metaParts = [
          sourceName ? `Source: ${sourceName}` : null,
          pageInfo ? `Pages: ${pageInfo}` : null,
          topic ? `Topic: ${topic}` : null,
        ].filter(Boolean);
        const fileUrlMeta = metaParts.length > 0 ? metaParts.join(' | ') : (topic || null);

        if (env.DB) {
          try {
            // 1. Insert into documents table with preserved metadata
            const insertDoc = await env.DB.prepare(
              `INSERT INTO documents (title, subject, unit, file_url, created_at)
               VALUES (?, ?, ?, ?, CURRENT_TIMESTAMP)`
            )
              .bind(title, subject, unit, fileUrlMeta)
              .run();

            const documentId =
              insertDoc.meta?.last_row_id ||
              (insertDoc as any).lastRowId ||
              insertDoc.meta?.changes ||
              Date.now();

            // 2. Insert all chunks into chunks table
            const chunkStatements = chunkTexts.map((chunkText, idx) =>
              env.DB!.prepare(
                `INSERT INTO chunks (document_id, content, chunk_index, created_at)
                 VALUES (?, ?, ?, CURRENT_TIMESTAMP)`
              ).bind(documentId, chunkText, idx)
            );

            await env.DB.batch(chunkStatements);

            // 3. Embed and upsert to Vectorize (best-effort, non-blocking failure)
            let vectorizeStatus = 'skipped';
            let vectorizedCount = 0;
            if (env.VECTORIZE && env.AI) {
              try {
                // Fetch the newly inserted chunk IDs
                const { results: newChunks } = await env.DB.prepare(
                  `SELECT id, document_id, content, chunk_index FROM chunks WHERE document_id = ? ORDER BY chunk_index ASC`
                ).bind(documentId).all<{ id: number; document_id: number; content: string; chunk_index: number }>();

                if (newChunks && newChunks.length > 0) {
                  const syncInputs = newChunks.map((c) => ({
                    chunkId: c.id,
                    documentId: c.document_id,
                    content: c.content,
                    title,
                    subject,
                    unit,
                    chunkIndex: c.chunk_index,
                    topic: topic || undefined,
                    source: sourceName || undefined,
                    page_info: pageInfo || undefined,
                  }));
                  const syncResult = await backfillChunksToVectorize(syncInputs, env);
                  vectorizeStatus = syncResult.vectorStatus;
                  vectorizedCount = syncResult.vectorized;
                }
              } catch (vecErr: any) {
                console.error('[Nexora Worker] Vectorize sync error (D1 insert succeeded):', vecErr?.message);
                vectorizeStatus = 'error';
              }
            }

            return jsonResponse({
              success: true,
              documentId,
              title,
              subject,
              unit,
              topic: topic || undefined,
              chunksCreated: chunkTexts.length,
              chunkCount: chunkTexts.length,
              vectorize: { status: vectorizeStatus, vectorized: vectorizedCount },
              message: `Successfully processed and indexed ${chunkTexts.length} chunks into Nexora knowledge base.`,
            });
          } catch (dbErr: any) {
            console.error('[Nexora Worker] D1 Upload Error:', dbErr?.message || dbErr);
            return jsonResponse(
              {
                success: false,
                error: 'Database Error',
                message: `Failed to insert chunks into D1: ${dbErr?.message || dbErr}`,
              },
              500
            );
          }
        }

        // If running in preview mode without D1 binding
        return jsonResponse({
          success: true,
          documentId: Date.now(),
          title,
          subject,
          unit,
          topic,
          chunksCreated: chunkTexts.length,
          previewChunks: chunkTexts.slice(0, 3),
          message: `Processed ${chunkTexts.length} chunks successfully (D1 preview mode).`,
        });
      }

      // 7. Admin Delete Document (DELETE /admin/document/:id)
      if (request.method === 'DELETE' && path.startsWith('/admin/document/')) {
        if (!verifyAdminAuth(request, env)) {
          return jsonResponse(
            {
              success: false,
              error: 'Unauthorized',
              message: 'Invalid or missing admin authorization token.',
            },
            401
          );
        }

        const idStr = path.replace('/admin/document/', '').trim();
        const docId = parseInt(idStr, 10);

        if (isNaN(docId) || docId <= 0) {
          return jsonResponse(
            {
              success: false,
              error: 'Bad Request',
              message: 'A valid numeric document ID is required.',
            },
            400
          );
        }

        if (env.DB) {
          try {
            await env.DB.batch([
              env.DB.prepare('DELETE FROM chunks WHERE document_id = ?').bind(docId),
              env.DB.prepare('DELETE FROM documents WHERE id = ?').bind(docId),
            ]);

            return jsonResponse({
              success: true,
              documentId: docId,
              message: `Document #${docId} and all associated chunks were successfully deleted from D1.`,
            });
          } catch (delErr: any) {
            console.error('[Nexora Worker] D1 Delete Error:', delErr?.message || delErr);
            return jsonResponse(
              {
                success: false,
                error: 'Database Error',
                message: `Failed to delete document from D1: ${delErr?.message || delErr}`,
              },
              500
            );
          }
        }

        return jsonResponse({
          success: true,
          documentId: docId,
          message: `Document #${docId} marked for deletion (D1 preview mode).`,
        });
      }

      // 8. Admin View Document Details & Chunks (GET /admin/document/:id)
      if (request.method === 'GET' && path.startsWith('/admin/document/')) {
        if (!verifyAdminAuth(request, env)) {
          return jsonResponse(
            {
              success: false,
              error: 'Unauthorized',
              message: 'Invalid or missing admin authorization token.',
            },
            401
          );
        }

        const idStr = path.replace('/admin/document/', '').trim();
        const docId = parseInt(idStr, 10);

        if (isNaN(docId) || docId <= 0) {
          return jsonResponse({ success: false, error: 'Invalid document ID' }, 400);
        }

        if (env.DB) {
          try {
            const doc = await env.DB.prepare(
              'SELECT * FROM documents WHERE id = ?'
            ).bind(docId).first<D1DocumentRow>();

            if (!doc) {
              return jsonResponse({ success: false, error: 'Document not found' }, 404);
            }

            const { results: chunks } = await env.DB.prepare(
              'SELECT id, content, chunk_index, created_at FROM chunks WHERE document_id = ? ORDER BY chunk_index ASC'
            ).bind(docId).all<D1ChunkRow>();

            return jsonResponse({
              success: true,
              document: doc,
              chunks: chunks || [],
            });
          } catch (err: any) {
            return jsonResponse({ success: false, error: err?.message || 'Database error' }, 500);
          }
        }

        return jsonResponse({
          success: true,
          document: { id: docId, title: 'Sample Doc', subject: 'Data Structures', unit: 2 },
          chunks: [],
        });
      }

      // 8b. Admin Backfill Vectorize (POST /admin/backfill)
      if (request.method === 'POST' && path === '/admin/backfill') {
        if (!verifyAdminAuth(request, env)) {
          return jsonResponse({ success: false, error: 'Unauthorized' }, 401);
        }

        if (!env.DB) {
          return jsonResponse({ success: false, error: 'D1 database not available' }, 503);
        }
        if (!env.VECTORIZE) {
          return jsonResponse({ success: false, error: 'Vectorize binding not available. Check wrangler.toml [[vectorize]].' }, 503);
        }
        if (!env.AI) {
          return jsonResponse({ success: false, error: 'Workers AI binding not available.' }, 503);
        }

        try {
          // Fetch ALL chunks from D1 with document metadata
          const { results: allChunks } = await env.DB.prepare(
            `SELECT c.id, c.document_id, c.content, c.chunk_index, d.title, d.subject, d.unit, d.file_url
             FROM chunks c
             JOIN documents d ON c.document_id = d.id
             ORDER BY c.id ASC`
          ).all<any>();

          if (!allChunks || allChunks.length === 0) {
            return jsonResponse({ success: true, message: 'No chunks found in D1. Nothing to backfill.', totalChunks: 0 });
          }

          const syncInputs = allChunks.map((c: any) => {
            // Parse topic/source/page_info from file_url metadata
            const fileUrl = c.file_url || '';
            let topic = '';
            let source = '';
            let page_info = '';
            if (fileUrl.includes('Topic:')) {
              topic = fileUrl.split('Topic:')[1]?.split('|')[0]?.trim() || '';
            }
            if (fileUrl.includes('Source:')) {
              source = fileUrl.split('Source:')[1]?.split('|')[0]?.trim() || '';
            }
            if (fileUrl.includes('Pages:')) {
              page_info = fileUrl.split('Pages:')[1]?.split('|')[0]?.trim() || '';
            }

            return {
              chunkId: c.id,
              documentId: c.document_id,
              content: c.content,
              title: c.title || '',
              subject: c.subject || '',
              unit: c.unit || 0,
              chunkIndex: c.chunk_index || 0,
              topic,
              source,
              page_info,
            };
          });

          const result = await backfillChunksToVectorize(syncInputs, env);

          return jsonResponse({
            success: true,
            message: `Backfill complete: ${result.vectorized}/${result.totalChunks} chunks embedded and upserted to Vectorize.`,
            totalChunks: result.totalChunks,
            vectorized: result.vectorized,
            failed: result.failed,
            vectorStatus: result.vectorStatus,
            embeddingModel: EMBEDDING_CONFIG.MODEL,
            indexName: EMBEDDING_CONFIG.INDEX_NAME,
            dimension: EMBEDDING_CONFIG.DIMENSION,
            results: result.results,
          });
        } catch (err: any) {
          console.error('[Nexora Worker] Backfill Error:', err?.message || err);
          return jsonResponse({ success: false, error: 'Backfill failed', detail: err?.message || String(err) }, 500);
        }
      }

      // 8c. Admin Manage Trusted Websites & Live Portals (GET, POST, DELETE /admin/sites)
      if (path === '/admin/sites' || path.startsWith('/admin/sites/')) {
        if (request.method === 'OPTIONS') {
          return new Response(null, { status: 204, headers: CORS_HEADERS });
        }

        // GET /admin/sites - List active trusted websites
        if (request.method === 'GET') {
          const sites = await getActiveTrustedSites(env);
          return jsonResponse({
            success: true,
            sites,
            total: sites.length,
          });
        }

        // POST /admin/sites - Add single site or bulk sync list
        if (request.method === 'POST') {
          if (!verifyAdminAuth(request, env)) {
            return jsonResponse({ success: false, error: 'Unauthorized', message: 'Admin authentication required' }, 401);
          }

          let body: any;
          try {
            body = await request.json();
          } catch {
            return jsonResponse({ success: false, error: 'Bad Request', message: 'Invalid JSON body' }, 400);
          }

          if (env.DB) {
            await ensureTrustedSitesTable(env);

            // Bulk synchronization
            if (Array.isArray(body?.sites)) {
              for (const s of body.sites) {
                const rawUrl = typeof s === 'string' ? s : s?.url;
                const rawLabel = typeof s === 'object' ? s?.label : '';
                const clean = (rawUrl || '').trim().replace(/^https?:\/\//i, '').replace(/\/+$/, '');
                if (clean && clean.includes('.')) {
                  await env.DB.prepare(
                    `INSERT OR REPLACE INTO trusted_sites (url, label, verified) VALUES (?, ?, 1)`
                  ).bind(clean, rawLabel || clean).run();
                }
              }
            } else if (body?.url) {
              const clean = (body.url || '').trim().replace(/^https?:\/\//i, '').replace(/\/+$/, '');
              const label = (body.label || '').trim() || clean;
              if (!clean || !clean.includes('.')) {
                return jsonResponse({ success: false, error: 'Invalid URL format' }, 400);
              }
              await env.DB.prepare(
                `INSERT OR REPLACE INTO trusted_sites (url, label, verified) VALUES (?, ?, 1)`
              ).bind(clean, label).run();
            }

            const updatedSites = await getActiveTrustedSites(env);
            return jsonResponse({
              success: true,
              sites: updatedSites,
              message: `Successfully synchronized ${updatedSites.length} trusted websites in D1 database.`,
            });
          }

          return jsonResponse({ success: true, message: 'Updated (preview mode)' });
        }

        // DELETE /admin/sites - Delete a site by url query, body, or id
        if (request.method === 'DELETE') {
          if (!verifyAdminAuth(request, env)) {
            return jsonResponse({ success: false, error: 'Unauthorized' }, 401);
          }

          let targetUrl = url.searchParams.get('url');
          let targetId = url.searchParams.get('id');

          if (!targetUrl && path.startsWith('/admin/sites/')) {
            const pathParam = decodeURIComponent(path.replace('/admin/sites/', '').trim());
            if (/^\d+$/.test(pathParam)) targetId = pathParam;
            else targetUrl = pathParam;
          }

          if (!targetUrl && !targetId) {
            try {
              const b: any = await request.json();
              targetUrl = b?.url;
              targetId = b?.id;
            } catch (_) {}
          }

          if (env.DB) {
            await ensureTrustedSitesTable(env);
            if (targetId) {
              await env.DB.prepare(`DELETE FROM trusted_sites WHERE id = ?`).bind(parseInt(targetId, 10)).run();
            } else if (targetUrl) {
              const clean = targetUrl.trim().replace(/^https?:\/\//i, '').replace(/\/+$/, '');
              await env.DB.prepare(`DELETE FROM trusted_sites WHERE url = ?`).bind(clean).run();
            }
            const updatedSites = await getActiveTrustedSites(env);
            return jsonResponse({
              success: true,
              sites: updatedSites,
              message: 'Website removed successfully.',
            });
          }

          return jsonResponse({ success: true, message: 'Removed (preview mode)' });
        }
      }

      // 8d. Private Student BVC Academic Profile Routes
      
        // POST /admin/results/upload - Admin result dataset ingestion & auto-matching
        if (request.method === 'POST' && path === '/admin/results/upload') {
          if (!verifyAdminAuth(request, env)) {
            return jsonResponse({ success: false, error: 'Unauthorized', message: 'Admin authentication required.' }, 401);
          }
          if (!env.DB) {
            return jsonResponse({ success: false, error: 'Database Unavailable' }, 503);
          }

          let body: any;
          try {
            body = await request.json();
          } catch {
            return jsonResponse({ success: false, error: 'Bad Request', message: 'Invalid JSON body. Expected array of records or { records: [...] }' }, 400);
          }

          let records: RawResultInputRecord[] = [];
          if (Array.isArray(body)) {
            records = body;
          } else if (Array.isArray(body?.records)) {
            records = body.records;
          } else {
            return jsonResponse({ success: false, error: 'Validation Error', message: 'No valid records array found in request body.' }, 400);
          }

          try {
            const report = await ResultProcessor.processResultUpload(env.DB, env, records);
            return jsonResponse({
              success: true,
              message: `Processed ${report.total_processed} records. Matched ${report.matched_students} students, queued ${report.notifications_queued} notifications.`,
              report,
            });
          } catch (procErr: any) {
            return jsonResponse({ success: false, error: 'Processing Error', message: procErr?.message || String(procErr) }, 500);
          }
        }

        // POST /admin/notifications/send - Send targeted announcement
        if (request.method === 'POST' && path === '/admin/notifications/send') {
          if (!verifyAdminAuth(request, env)) {
            return jsonResponse({ success: false, error: 'Unauthorized' }, 401);
          }
          if (!env.DB) {
            return jsonResponse({ success: false, error: 'Database Unavailable' }, 503);
          }

          let body: any;
          try { body = await request.json(); } catch {
            return jsonResponse({ success: false, error: 'Bad Request', message: 'Invalid JSON body.' }, 400);
          }

          const { title, message, scope, branch, year, semester, section, customRollNumbers, type } = body || {};
          if (!title || !message) {
            return jsonResponse({ success: false, error: 'Validation Error', message: 'Title and message are required.' }, 400);
          }

          const notifType = type || 'CIRCULAR';
          const target: NotificationTarget = {
            scope: scope || 'ALL',
            branch: branch || null,
            year: year ? parseInt(String(year), 10) : null,
            semester: semester ? parseInt(String(semester), 10) : null,
            section: section || null,
            custom_roll_numbers: Array.isArray(customRollNumbers) ? customRollNumbers : [],
          };

          const targetUids = await TargetingEngine.resolveTargetUids(env.DB, target);
          let queuedCount = 0;
          let duplicateCount = 0;
          const broadcastRef = `BROADCAST:${Date.now()}`;

          for (const uid of targetUids) {
            const notifRes = await NotificationStorage.createNotificationIdempotent(env.DB, {
              firebase_uid: uid,
              type: notifType,
              title,
              body: message,
              data_json: JSON.stringify({ type: notifType, route: '/notifications' }),
              reference_id: `${broadcastRef}:${uid}`,
            });

            if (notifRes.created) queuedCount++;
            else if (notifRes.duplicate) duplicateCount++;
          }

          // Fetch active tokens and batch send push
          if (targetUids.length > 0) {
            const devices = await NotificationStorage.getActiveDeviceTokens(env.DB, targetUids);
            if (devices.length > 0) {
              const pushItems = devices.map((d) => ({
                fcm_token: d.fcm_token,
                title,
                body: message,
                type: notifType,
                route: '/notifications',
              }));
              await FCMV1Service.batchSend(env, pushItems);
            }
          }

          return jsonResponse({
            success: true,
            target_scope: target.scope,
            targets_resolved: targetUids.length,
            notifications_queued: queuedCount,
            duplicates_skipped: duplicateCount,
          });
        }

        // POST /admin/notifications/event - Send event notification
        if (request.method === 'POST' && path === '/admin/notifications/event') {
          if (!verifyAdminAuth(request, env)) {
            return jsonResponse({ success: false, error: 'Unauthorized' }, 401);
          }
          if (!env.DB) {
            return jsonResponse({ success: false, error: 'Database Unavailable' }, 503);
          }

          let body: any;
          try { body = await request.json(); } catch {
            return jsonResponse({ success: false, error: 'Bad Request' }, 400);
          }

          const { title, description, venue, eventDate, eventTime, scope, branch, year, semester, section } = body || {};
          if (!title || !description) {
            return jsonResponse({ success: false, error: 'Validation Error', message: 'title and description are required.' }, 400);
          }

          const target: NotificationTarget = {
            scope: scope || 'ALL',
            branch: branch || null,
            year: year ? parseInt(String(year), 10) : null,
            semester: semester ? parseInt(String(semester), 10) : null,
            section: section || null,
          };

          const targetUids = await TargetingEngine.resolveTargetUids(env.DB, target);
          const eventRef = `EVENT:${Date.now()}`;
          let queuedCount = 0;

          const dataJson = JSON.stringify({
            type: 'EVENT',
            venue: venue || null,
            event_date: eventDate || null,
            event_time: eventTime || null,
            route: '/events',
          });

          for (const uid of targetUids) {
            const notifRes = await NotificationStorage.createNotificationIdempotent(env.DB, {
              firebase_uid: uid,
              type: 'EVENT',
              title,
              body: description,
              data_json: dataJson,
              reference_id: `${eventRef}:${uid}`,
            });
            if (notifRes.created) queuedCount++;
          }

          if (targetUids.length > 0) {
            const devices = await NotificationStorage.getActiveDeviceTokens(env.DB, targetUids);
            if (devices.length > 0) {
              const pushItems = devices.map((d) => ({
                fcm_token: d.fcm_token,
                title: `Event: ${title}`,
                body: description,
                type: 'EVENT',
                route: '/events',
              }));
              await FCMV1Service.batchSend(env, pushItems);
            }
          }

          return jsonResponse({
            success: true,
            targets_resolved: targetUids.length,
            notifications_queued: queuedCount,
          });
        }

        // GET /admin/notifications/stats - Notification aggregate statistics
        if (request.method === 'GET' && path === '/admin/notifications/stats') {
          if (!verifyAdminAuth(request, env)) {
            return jsonResponse({ success: false, error: 'Unauthorized' }, 401);
          }
          if (!env.DB) {
            return jsonResponse({ success: false, error: 'Database Unavailable' }, 503);
          }

          const stats = await NotificationStorage.getNotificationStats(env.DB);
          return jsonResponse({ success: true, stats });
        }


      if (path.startsWith('/student/')) {
        const studentUser = await FirebaseAuthGuard.authenticate(request);
        if (!studentUser) {
          return jsonResponse(
            {
              success: false,
              error: 'Unauthorized',
              message: 'Valid Firebase student authentication required. Pass Authorization: Bearer <Firebase_ID_Token>.',
            },
            401
          );
        }

        if (!env.DB) {
          return jsonResponse({ success: false, error: 'Database Unavailable', message: 'D1 database binding is required.' }, 503);
        }

        // POST /student/bvc/connect - Link BVC Roll Number & Sync
        if (request.method === 'POST' && path === '/student/bvc/connect') {
          let bBody: any;
          try {
            bBody = await request.json();
          } catch {
            return jsonResponse({ success: false, error: 'Bad Request', message: 'Invalid JSON body. Required: { rollNumber }' }, 400);
          }

          const rawRoll = bBody?.rollNumber;
          if (!rawRoll || typeof rawRoll !== 'string') {
            return jsonResponse({ success: false, error: 'Validation Error', message: 'rollNumber is required and must be a string.' }, 400);
          }

          const normalizedRoll = BVCNormalizer.normalizeRollNumber(rawRoll);
          if (!BVCNormalizer.isValidRollNumber(normalizedRoll)) {
            return jsonResponse({
              success: false,
              error: 'Invalid Roll Number',
              message: `The roll number '${rawRoll}' does not match the valid BVC format (e.g. 25221A0568).`,
            }, 400);
          }

          try {
            const syncResult = await BVCService.syncStudent({
              firebaseUid: studentUser.uid,
              rollNumber: normalizedRoll,
              password: bBody?.password,
              useLiveClient: bBody?.useLiveClient === true,
              db: env.DB,
            });

            return jsonResponse({
              success: true,
              message: `BVC Academic Profile connected for ${normalizedRoll}.`,
              sync: syncResult,
            });
          } catch (syncErr: any) {
            return jsonResponse({ success: false, error: 'Connection Error', message: syncErr?.message || String(syncErr) }, 500);
          }
        }

        // POST /student/bvc/sync - Re-sync with latest BVC data
        if (request.method === 'POST' && path === '/student/bvc/sync') {
          const profile = await BVCStorage.getStudentProfile(env.DB, studentUser.uid);
          if (!profile || !profile.connected) {
            return jsonResponse({ success: false, error: 'Not Connected', message: 'No linked BVC profile found. Please connect your profile first.' }, 404);
          }

          try {
            let bBody: any = {};
            try { bBody = await request.json(); } catch (_) {}

            const syncResult = await BVCService.syncStudent({
              firebaseUid: studentUser.uid,
              rollNumber: profile.roll_number,
              password: bBody?.password,
              useLiveClient: bBody?.useLiveClient === true,
              db: env.DB,
            });

            return jsonResponse({
              success: true,
              message: `BVC Academic Profile refreshed successfully.`,
              sync: syncResult,
            });
          } catch (syncErr: any) {
            return jsonResponse({ success: false, error: 'Sync Error', message: syncErr?.message || String(syncErr) }, 500);
          }
        }

        // DELETE /student/bvc/disconnect - Unlink BVC account
        if (request.method === 'DELETE' && path === '/student/bvc/disconnect') {
          await BVCStorage.disconnectStudent(env.DB, studentUser.uid);
          return jsonResponse({
            success: true,
            message: 'BVC academic profile disconnected successfully and private records cleared.',
          });
        }

        // GET /student/profile - Retrieve personal profile
        if (request.method === 'GET' && path === '/student/profile') {
          const profile = await BVCStorage.getStudentProfile(env.DB, studentUser.uid);
          if (!profile) {
            return jsonResponse({ success: false, connected: false, message: 'No BVC profile linked.' });
          }
          return jsonResponse({ success: true, connected: Boolean(profile.connected), profile });
        }

        // GET /student/attendance - Retrieve personal attendance
        if (request.method === 'GET' && path === '/student/attendance') {
          const attendance = await BVCStorage.getStudentAttendance(env.DB, studentUser.uid);
          return jsonResponse({ success: true, attendance });
        }

        // GET /student/results - Retrieve semester marks & results
        if (request.method === 'GET' && path === '/student/results') {
          const results = await BVCStorage.getStudentResults(env.DB, studentUser.uid);
          return jsonResponse({ success: true, results });
        }

        // GET /student/subjects - Retrieve enrolled subjects
        if (request.method === 'GET' && path === '/student/subjects') {
          const subjects = await BVCStorage.getStudentSubjects(env.DB, studentUser.uid);
          return jsonResponse({ success: true, subjects });
        }

        // GET /student/timetable - Retrieve weekly timetable
        if (request.method === 'GET' && path === '/student/timetable') {
          const timetable = await BVCStorage.getStudentTimetable(env.DB, studentUser.uid);
          return jsonResponse({ success: true, timetable });
        }

        // GET /student/fees - Retrieve fee records
        if (request.method === 'GET' && path === '/student/fees') {
          const fees = await BVCStorage.getStudentFees(env.DB, studentUser.uid);
          return jsonResponse({ success: true, fees });
        }
      
        // POST /student/devices/register - Register FCM Device Token
        if (request.method === 'POST' && path === '/student/devices/register') {
          let bBody: any;
          try { bBody = await request.json(); } catch {
            return jsonResponse({ success: false, error: 'Bad Request', message: 'Invalid JSON body. Required: { fcm_token }' }, 400);
          }

          const fcmToken = bBody?.fcm_token || bBody?.fcmToken;
          if (!fcmToken || typeof fcmToken !== 'string') {
            return jsonResponse({ success: false, error: 'Validation Error', message: 'fcm_token is required.' }, 400);
          }

          const success = await NotificationStorage.registerDevice(env.DB, {
            firebase_uid: studentUser.uid,
            fcm_token: fcmToken.trim(),
            platform: bBody?.platform || 'android',
            device_name: bBody?.device_name || bBody?.deviceName,
            app_version: bBody?.app_version || bBody?.appVersion,
          });

          return jsonResponse({ success, message: success ? 'Device token registered successfully.' : 'Failed to register device.' });
        }

        // POST /student/devices/unregister - Unregister FCM Device Token
        if (request.method === 'POST' && path === '/student/devices/unregister') {
          let bBody: any;
          try { bBody = await request.json(); } catch {
            return jsonResponse({ success: false, error: 'Bad Request' }, 400);
          }

          const fcmToken = bBody?.fcm_token || bBody?.fcmToken;
          if (!fcmToken) {
            return jsonResponse({ success: false, error: 'Validation Error', message: 'fcm_token is required.' }, 400);
          }

          const success = await NotificationStorage.unregisterDevice(env.DB, studentUser.uid, fcmToken.trim());
          return jsonResponse({ success, message: 'Device token deactivated.' });
        }

        // GET /student/notifications - Fetch In-App Notifications
        if (request.method === 'GET' && path === '/student/notifications') {
          const limit = parseInt(url.searchParams.get('limit') || '50', 10);
          const offset = parseInt(url.searchParams.get('offset') || '0', 10);
          const unreadOnly = url.searchParams.get('unread') === 'true';

          const notifs = await NotificationStorage.getStudentNotifications(env.DB, studentUser.uid, limit, offset, unreadOnly);
          return jsonResponse({ success: true, count: notifs.length, notifications: notifs });
        }

        // POST /student/notifications/:id/read - Mark Single Notification Read
        if (request.method === 'POST' && path.startsWith('/student/notifications/') && path.endsWith('/read')) {
          const idStr = path.replace('/student/notifications/', '').replace('/read', '');
          const notifId = parseInt(idStr, 10);
          if (isNaN(notifId)) {
            return jsonResponse({ success: false, error: 'Invalid ID' }, 400);
          }

          const success = await NotificationStorage.markAsRead(env.DB, studentUser.uid, notifId);
          return jsonResponse({ success, message: success ? 'Notification marked as read.' : 'Notification not found or already read.' });
        }

        // POST /student/notifications/read-all - Mark All Read
        if (request.method === 'POST' && path === '/student/notifications/read-all') {
          const marked = await NotificationStorage.markAllAsRead(env.DB, studentUser.uid);
          return jsonResponse({ success: true, marked_count: marked, message: `Marked ${marked} notifications as read.` });
        }

        // GET /student/notification-count - Get Unread Count Badge
        if (request.method === 'GET' && path === '/student/notification-count') {
          const counts = await NotificationStorage.getUnreadCount(env.DB, studentUser.uid);
          return jsonResponse({ success: true, ...counts });
        }
      }

      // 9. Grounded Conversational AI Route
      if (request.method === 'POST' && (path === '/chat' || path === '/ask')) {
        let body: any;
        try {
          body = await request.json();
        } catch {
          return jsonResponse(
            {
              success: false,
              error: 'Bad Request',
              message: 'Invalid JSON body. Please provide a JSON object with a "message" or "question" field.',
            },
            400
          );
        }

        const rawMessage = body?.message || body?.question;
        if (typeof rawMessage !== 'string' || rawMessage.trim().length === 0) {
          return jsonResponse(
            {
              success: false,
              error: 'Bad Request',
              message: 'The "message" (or "question") field is required and cannot be empty.',
            },
            400
          );
        }

        if (rawMessage.length > MAX_QUESTION_LENGTH) {
          return jsonResponse(
            {
              success: false,
              error: 'Bad Request',
              message: `The message exceeds the maximum allowed length of ${MAX_QUESTION_LENGTH} characters.`,
            },
            400
          );
        }

        const trimmedMessage = rawMessage.trim();
        const isDebug = url.searchParams.get('debug') === 'true' || body?.debug === true;
        const webAccess = body?.webAccessEnabled === true;
        const customSites = body?.trustedSites || body?.sites;

        const controller = AIController.getInstance();
        const detectedIntent = controller.detectIntent(trimmedMessage, body?.conversation || [], webAccess);

        // DETERMINISTIC GREETING & CASUAL BYPASS:
        // Casual greetings, small-talk, pleasantries must NOT trigger academic RAG,
        // D1 database scans, Vectorize queries, or embedding generation.
        const isCasual =
          detectedIntent === 'GREETING' ||
          detectedIntent === 'CASUAL' ||
          detectedIntent === 'SMALL_TALK';

        // Fetch D1 chunks ONLY when academic retrieval is needed
        let allRows: any[] = [];
        if (!isCasual && env.DB) {
          try {
            const { results } = await env.DB.prepare(
              `SELECT c.id, c.document_id, c.content, d.title, d.subject, d.unit, c.chunk_index
               FROM chunks c
               JOIN documents d ON c.document_id = d.id
               ORDER BY d.unit ASC, c.chunk_index ASC`
            ).all<D1ChunkRow>();
            allRows = results || [];
          } catch (d1Err: any) {
            console.error('[Nexora Worker] D1 Fetch Error for AI Chat:', d1Err?.message || d1Err);
          }
        }

        // Live Multi-Website Search Grounding
        let portalResults: SearchResult[] = [];
        let portalSources: SourceInfo[] = [];
        const activeTrustedSites = await getActiveTrustedSites(env, customSites);

        if (!isCasual && (webAccess || detectedIntent === 'COLLEGE_INFO' || detectedIntent === 'WEB_SEARCH')) {
          try {
            const portalSearch = await searchOfficialSources(trimmedMessage, activeTrustedSites, env);
            portalResults = portalSearch.results || [];
            portalSources = portalSearch.sources || [];
          } catch (pErr: any) {
            console.warn('[Nexora Worker] Live Portal Search Error in chat:', pErr?.message || pErr);
          }
        }

        const chatResponse = await controller.handleChat({
          message: trimmedMessage,
          conversation: body?.conversation || [],
          webAccessEnabled: webAccess,
          debug: isDebug,
          env,
          allChunks: allRows,
          portalResults,
          portalSources,
          trustedSites: activeTrustedSites,
        });

        // Maintain backwards compatibility for legacy /ask callers
        if (path === '/ask') {
          return jsonResponse({
            success: true,
            question: trimmedMessage,
            answer: chatResponse.answer,
            tool: chatResponse.tool,
            sources: chatResponse.sources,
            ...(chatResponse.debug ? { debug: chatResponse.debug } : {}),
          });
        }

        return jsonResponse(chatResponse);
      }

      // 10. Unknown routes (404)
      return jsonResponse(
        {
          success: false,
          error: 'Not Found',
          message: `The requested route '${request.method} ${url.pathname}' does not exist on this server.`,
        },
        404
      );
    } catch (err: unknown) {
      console.error('[Nexora Worker] Uncaught handler exception:', err);
      const isDebug = url.searchParams.get('debug') === 'true';
      return jsonResponse(
        {
          success: false,
          error: 'Internal Server Error',
          message: 'An unexpected error occurred while processing your request.',
          ...(isDebug && err instanceof Error ? { debugDetail: `${err.name}: ${err.message}`, stack: err.stack } : {}),
        },
        500
      );
    }
  },
};
