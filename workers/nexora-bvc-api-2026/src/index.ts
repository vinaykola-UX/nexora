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

export interface Env extends EnvAIConfig {
  ENVIRONMENT?: string;
  ADMIN_SECRET?: string;
  DB?: D1Database;
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
const ALLOWED_HOSTS = new Set([
  'bvcec.edu.in',
  'www.bvcec.edu.in',
  'bvcecautonomous.com',
  'www.bvcecautonomous.com',
]);

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

async function searchOfficialSources(rawQuery: string): Promise<{
  results: SearchResult[];
  sources: SourceInfo[];
}> {
  const query = rawQuery.trim();
  const activeSources: SourceInfo[] = [];
  const results: SearchResult[] = [];
  const encodedQuery = encodeURIComponent(query);

  const primaryUrls = [
    `https://bvcec.edu.in/wp-json/wp/v2/posts?search=${encodedQuery}&per_page=5`,
    `https://bvcec.edu.in/wp-json/wp/v2/pages?search=${encodedQuery}&per_page=5`,
  ];

  const keywords = extractSearchKeywords(query);
  const keywordUrls: string[] = [];
  if (keywords !== query && keywords.length > 0) {
    const encodedKeywords = encodeURIComponent(keywords);
    keywordUrls.push(
      `https://bvcec.edu.in/wp-json/wp/v2/posts?search=${encodedKeywords}&per_page=5`,
      `https://bvcec.edu.in/wp-json/wp/v2/pages?search=${encodedKeywords}&per_page=5`
    );
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

  const processEndpoint = async (urlStr: string) => {
    try {
      const resp = await fetchWithTimeout(urlStr);
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
        const title = decodeHtmlEntities(rawTitle).trim() || 'BVC Engineering College Notice';
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
          source: 'BVC Engineering College',
          snippet: snippet.length > 280 ? `${snippet.substring(0, 277)}...` : snippet,
          publishedDate,
        });

        if (results.length >= MAX_RESULTS) break;
      }
    } catch (_) {}
  };

  await Promise.all(primaryUrls.map(processEndpoint));

  if (results.length === 0 && keywordUrls.length > 0) {
    await Promise.all(keywordUrls.map(processEndpoint));
  }

  const queryLower = query.toLowerCase();
  const isExamQuery =
    queryLower.includes('exam') ||
    queryLower.includes('fee') ||
    queryLower.includes('result') ||
    queryLower.includes('grade') ||
    queryLower.includes('notification') ||
    queryLower.includes('br23');

  if (isExamQuery) {
    const examCellUrl = 'https://www.bvcecautonomous.com';
    if (!results.some((r) => r.url.includes('bvcecautonomous.com'))) {
      results.unshift({
        title: 'BVC Autonomous Examination Portal & Notifications',
        url: examCellUrl,
        source: 'BVC Autonomous Examination Cell',
        snippet:
          'Official autonomous examinations portal for BVC Engineering College students. Access end examination fee schedules, last date notifications, results, student logins, and academic grade sheets directly from the Examination Cell.',
        publishedDate: null,
      });
    }
  }

  if (results.some((r) => r.url.includes('bvcec.edu.in'))) {
    activeSources.push({
      title: 'BVC Engineering College Official Portal',
      url: 'https://bvcec.edu.in',
      source: 'BVC Engineering College',
    });
  }
  if (results.some((r) => r.url.includes('bvcecautonomous.com'))) {
    activeSources.push({
      title: 'BVC Autonomous Examination & Results Portal',
      url: 'https://www.bvcecautonomous.com',
      source: 'BVC Autonomous Examination Cell',
    });
  }

  return {
    results: results.slice(0, MAX_RESULTS),
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
          version: '2.1.0',
          status: 'online',
          message: 'Nexora BVC AI & RAG Knowledge Base Retrieval Service',
        });
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
            { method: 'GET', path: '/search?q=<query>', description: 'Search across all study chunks in D1 database' },
            { method: 'POST', path: '/admin/upload', description: 'Upload and chunk new study material into D1 (Admin)' },
            { method: 'DELETE', path: '/admin/document/:id', description: 'Delete a document and its chunks from D1 (Admin)' },
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

        // Step 1: Query Cloudflare D1 across ALL documents
        if (env.DB) {
          try {
            const term = `%${trimmedQuery}%`;
            const { results: d1Rows } = await env.DB.prepare(
              `SELECT c.content, d.title, d.subject, d.unit, c.chunk_index
               FROM chunks c
               JOIN documents d ON c.document_id = d.id
               WHERE c.content LIKE ? OR d.title LIKE ? OR d.subject LIKE ?
               ORDER BY d.unit ASC, c.chunk_index ASC
               LIMIT 10`
            )
              .bind(term, term, term)
              .all<D1ChunkRow>();

            if (d1Rows && d1Rows.length > 0) {
              return jsonResponse({
                query: trimmedQuery,
                results: d1Rows.map((r) => ({
                  content: r.content,
                  title: r.title,
                  subject: r.subject,
                  unit: r.unit,
                })),
              });
            }

            // Also try keyword fallback search in D1
            const keywords = extractSearchKeywords(trimmedQuery);
            if (keywords && keywords.toLowerCase() !== trimmedQuery.toLowerCase()) {
              const kwTerm = `%${keywords}%`;
              const { results: kwRows } = await env.DB.prepare(
                `SELECT c.content, d.title, d.subject, d.unit, c.chunk_index
                 FROM chunks c
                 JOIN documents d ON c.document_id = d.id
                 WHERE c.content LIKE ? OR d.title LIKE ? OR d.subject LIKE ?
                 ORDER BY d.unit ASC, c.chunk_index ASC
                 LIMIT 10`
              )
                .bind(kwTerm, kwTerm, kwTerm)
                .all<D1ChunkRow>();

              if (kwRows && kwRows.length > 0) {
                return jsonResponse({
                  query: trimmedQuery,
                  results: kwRows.map((r) => ({
                    content: r.content,
                    title: r.title,
                    subject: r.subject,
                    unit: r.unit,
                  })),
                });
              }
            }
          } catch (d1Err: any) {
            console.error('[Nexora Worker] D1 Search Error:', d1Err?.message || d1Err);
          }
        }

        // Step 2: Fallback search against official BVC College portals
        const { results: portalResults, sources } = await searchOfficialSources(trimmedQuery);

        if (portalResults.length > 0) {
          return jsonResponse({
            success: true,
            query: trimmedQuery,
            results: portalResults,
            sources,
          });
        }

        return jsonResponse({
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
              message: 'Invalid JSON body. Required: { title, subject, unit, content, topic? }',
            },
            400
          );
        }

        const title = (body?.title || '').trim();
        const subject = (body?.subject || '').trim();
        const unit = parseInt(String(body?.unit || ''), 10);
        const topic = (body?.topic || '').trim();
        const content = (body?.content || '').trim();

        if (!title || !subject || isNaN(unit) || !content) {
          return jsonResponse(
            {
              success: false,
              error: 'Validation Error',
              message: 'All fields (title, subject, unit, content) are required and cannot be empty.',
            },
            400
          );
        }

        if (unit < 1 || unit > 10) {
          return jsonResponse(
            {
              success: false,
              error: 'Validation Error',
              message: 'Unit must be a valid number between 1 and 10.',
            },
            400
          );
        }

        // Deterministic chunking (800 - 1400 chars per chunk)
        const chunks = chunkStudyContent(content, { subject, unit, topic, title });

        if (chunks.length === 0) {
          return jsonResponse(
            {
              success: false,
              error: 'Empty Content',
              message: 'Content could not be parsed into valid chunks.',
            },
            400
          );
        }

        if (env.DB) {
          try {
            // 1. Insert into documents table
            const insertDoc = await env.DB.prepare(
              `INSERT INTO documents (title, subject, unit, file_url, created_at)
               VALUES (?, ?, ?, ?, CURRENT_TIMESTAMP)`
            )
              .bind(title, subject, unit, topic || null)
              .run();

            const documentId =
              insertDoc.meta?.last_row_id ||
              (insertDoc as any).lastRowId ||
              insertDoc.meta?.changes ||
              Date.now();

            // 2. Insert all chunks into chunks table
            const chunkStatements = chunks.map((chunkText, idx) =>
              env.DB!.prepare(
                `INSERT INTO chunks (document_id, content, chunk_index, created_at)
                 VALUES (?, ?, ?, CURRENT_TIMESTAMP)`
              ).bind(documentId, chunkText, idx)
            );

            await env.DB.batch(chunkStatements);

            return jsonResponse({
              success: true,
              documentId,
              title,
              subject,
              unit,
              topic: topic || undefined,
              chunksCreated: chunks.length,
              message: `Successfully processed and indexed ${chunks.length} chunks into Nexora knowledge base.`,
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
          chunksCreated: chunks.length,
          previewChunks: chunks.slice(0, 3),
          message: `Processed ${chunks.length} chunks successfully (D1 preview mode).`,
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

      // 9. Grounded AI Generation Route (POST /ask)
      if (request.method === 'POST' && path === '/ask') {
        let body: any;
        try {
          body = await request.json();
        } catch {
          return jsonResponse(
            {
              success: false,
              error: 'Bad Request',
              message: 'Invalid JSON body. Please provide a JSON object with a "question" field.',
            },
            400
          );
        }

        const question = body?.question;
        if (typeof question !== 'string' || question.trim().length === 0) {
          return jsonResponse(
            {
              success: false,
              error: 'Bad Request',
              message: 'The "question" field is required and cannot be empty.',
            },
            400
          );
        }

        if (question.length > MAX_QUESTION_LENGTH) {
          return jsonResponse(
            {
              success: false,
              error: 'Bad Request',
              message: `The question exceeds the maximum allowed length of ${MAX_QUESTION_LENGTH} characters.`,
            },
            400
          );
        }

        const trimmedQuestion = question.trim();

        // 1. Try D1 RAG chunks first
        let retrievalContext = '';
        const d1Sources: SourceInfo[] = [];

        if (env.DB) {
          try {
            const term = `%${trimmedQuestion}%`;
            const { results: d1Rows } = await env.DB.prepare(
              `SELECT c.content, d.title, d.subject, d.unit
               FROM chunks c
               JOIN documents d ON c.document_id = d.id
               WHERE c.content LIKE ? OR d.title LIKE ?
               LIMIT 4`
            ).bind(term, term).all<D1ChunkRow>();

            if (d1Rows && d1Rows.length > 0) {
              retrievalContext = d1Rows
                .map((r, i) => `[Study Chunk ${i + 1}] (${r.subject} Unit ${r.unit} - ${r.title}):\n${r.content}`)
                .join('\n\n');

              d1Rows.forEach((r) => {
                if (!d1Sources.some((s) => s.title === r.title)) {
                  d1Sources.push({ title: `${r.subject} • Unit ${r.unit}: ${r.title}`, url: '#' });
                }
              });
            }
          } catch (_) {}
        }

        // 2. If D1 has no context, search portal
        let portalSources: SourceInfo[] = [];
        if (!retrievalContext) {
          const { results: portalResults, sources } = await searchOfficialSources(trimmedQuestion);
          if (portalResults.length > 0) {
            retrievalContext = portalResults
              .map(
                (r, i) =>
                  `[Source ${i + 1}] Title: ${r.title}\nSource: ${r.source}\nURL: ${r.url}\nExcerpt: ${r.snippet}`
              )
              .join('\n\n');
            portalSources = sources;
          }
        }

        if (!retrievalContext) {
          return jsonResponse({
            success: true,
            question: trimmedQuestion,
            answer:
              "I couldn't find enough verified information from the currently configured official BVC sources or knowledge base to answer this accurately.",
            sources: [],
          });
        }

        // 3. Generate answer
        try {
          const { apiKey, aiBinding } = aiService.resolveActiveProvider(env);

          if (!apiKey && !aiBinding) {
            return jsonResponse({
              success: true,
              question: trimmedQuestion,
              answer: retrievalContext,
              sources: d1Sources.length > 0 ? d1Sources : portalSources,
            });
          }

          const aiResult = await aiService.generateGroundedAnswer({
            question: trimmedQuestion,
            officialContext: retrievalContext,
            env,
          });

          return jsonResponse({
            success: true,
            question: trimmedQuestion,
            answer: aiResult.answer,
            sources: d1Sources.length > 0 ? d1Sources : portalSources,
          });
        } catch (aiErr: any) {
          return jsonResponse({
            success: true,
            question: trimmedQuestion,
            answer: retrievalContext,
            sources: d1Sources.length > 0 ? d1Sources : portalSources,
          });
        }
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
      return jsonResponse(
        {
          success: false,
          error: 'Internal Server Error',
          message: 'An unexpected error occurred while processing your request.',
        },
        500
      );
    }
  },
};
