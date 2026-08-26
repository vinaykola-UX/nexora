/**
 * Nexora BVC AI — Cloudflare Worker Backend (Phase 2)
 * Service: nexora-bvc-api-2026
 *
 * Provides:
 * - Official BVC source retrieval
 * - Provider-agnostic grounded AI generation via POST /ask
 * - Health check & API discovery
 */

import { AIService, EnvAIConfig } from './ai/ai_service';

export interface Env extends EnvAIConfig {
  ENVIRONMENT?: string;
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

// Standard CORS headers for cross-origin app requests
const CORS_HEADERS: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Requested-With',
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
  cleaned = cleaned.replace(/<svg\b[^<]*(?:(?!<\/svg>)<[^<]*)*<\/svg>/gi, ' ');
  cleaned = cleaned.replace(/<nav\b[^<]*(?:(?!<\/nav>)<[^<]*)*<\/nav>/gi, ' ');
  cleaned = cleaned.replace(/<header\b[^<]*(?:(?!<\/header>)<[^<]*)*<\/header>/gi, ' ');
  cleaned = cleaned.replace(/<footer\b[^<]*(?:(?!<\/footer>)<[^<]*)*<\/footer>/gi, ' ');
  cleaned = cleaned.replace(/<aside\b[^<]*(?:(?!<\/aside>)<[^<]*)*<\/aside>/gi, ' ');
  cleaned = cleaned.replace(/<[^>]+class="[^"]*(?:elementor-nav-menu|nav-menu|menu-item|rank-math-breadcrumb|breadcrumb|site-header|site-footer|widget-area|sidebar|post-meta-author)[^"]*"[^>]*>[\s\S]*?<\/[^>]+>/gi, ' ');
  cleaned = cleaned.replace(/NIRF\s+Home\s+About\s+Us\s+About\s+BVCEC\s+Vision\s+&\s+Mission\s+Quality\s+Policy\s+Academic\s+Council/gi, ' ');
  cleaned = cleaned.replace(/BVC\s+ENGINEERING\s+COLLEGE\s+\(AUTONOMOUS\)\s+ODALAREVU/gi, ' ');

  return cleaned;
}

function extractMainContent(rawHtml: string): string {
  if (!rawHtml) return '';
  const filteredHtml = removeBoilerplateHtml(rawHtml);
  const contentContainerRegexes = [
    /<article\b[^>]*>([\s\S]*?)<\/article>/i,
    /<main\b[^>]*>([\s\S]*?)<\/main>/i,
    /<div[^>]+class="[^"]*(?:entry-content|post-content|article-content|main-content)[^"]*"[^>]*>([\s\S]*?)<\/div>/i,
    /<div[^>]+class="[^"]*elementor-widget-text-editor[^"]*"[^>]*>([\s\S]*?)<\/div>/i,
  ];

  for (const regex of contentContainerRegexes) {
    const match = filteredHtml.match(regex);
    if (match && match[1] && match[1].replace(/<[^>]+>/g, '').trim().length > 30) {
      return match[1];
    }
  }

  return filteredHtml;
}

function cleanToPlainText(rawHtml: string): string {
  if (!rawHtml) return '';
  const mainHtml = extractMainContent(rawHtml);
  const noTags = mainHtml.replace(/<[^>]+>/g, ' ');
  const decoded = decodeHtmlEntities(noTags);
  return decoded.replace(/\s+/g, ' ').trim();
}

function buildRelevantSnippet(
  contentHtml: string,
  query: string,
  pageTitle: string,
  minLen = 300,
  maxLen = 600
): string {
  const fullText = cleanToPlainText(contentHtml);

  if (!fullText || fullText.length < 25) {
    return `Official BVC Engineering College portal information for "${pageTitle}". Access official announcements, examination circulars, academic regulations, and student resources.`;
  }

  const queryTokens = query
    .toLowerCase()
    .split(/\s+/)
    .map((w) => w.replace(/[^a-z0-9]/g, ''))
    .filter((w) => w.length >= 2);

  if (fullText.length <= maxLen) {
    return fullText;
  }

  const sentences = fullText.match(/[^.!?]+[.!?]+(\s+|$)|[^.!?]+$/g) || [fullText];
  let bestIndex = 0;
  let highestScore = -1;

  for (let i = 0; i < sentences.length; i++) {
    const sLower = sentences[i].toLowerCase();
    let score = 0;
    for (const token of queryTokens) {
      if (sLower.includes(token)) {
        score += 2;
      }
    }
    if (score > highestScore) {
      highestScore = score;
      bestIndex = i;
    }
  }

  let snippet = '';
  let start = Math.max(0, bestIndex - 1);

  for (let i = start; i < sentences.length; i++) {
    const nextSentence = sentences[i].trim();
    if (!nextSentence) continue;

    if (snippet.length + nextSentence.length > maxLen && snippet.length >= minLen) {
      break;
    }
    snippet += (snippet.length > 0 ? ' ' : '') + nextSentence;
  }

  if (!snippet || snippet.length < 50) {
    snippet = fullText.substring(0, maxLen);
  }

  if (snippet.length > maxLen) {
    const trimmed = snippet.substring(0, maxLen);
    const lastSpace = trimmed.lastIndexOf(' ');
    snippet = (lastSpace > 100 ? trimmed.substring(0, lastSpace) : trimmed) + '...';
  }

  return snippet.trim();
}

function isValidOfficialUrl(urlStr: string): boolean {
  try {
    const parsed = new URL(urlStr);
    if (parsed.protocol !== 'http:' && parsed.protocol !== 'https:') {
      return false;
    }
    return ALLOWED_HOSTS.has(parsed.hostname.toLowerCase());
  } catch {
    return false;
  }
}

function formatDate(dateStr: string | null): string | null {
  if (!dateStr) return null;
  try {
    const d = new Date(dateStr);
    if (isNaN(d.getTime())) return dateStr;
    return d.toLocaleDateString('en-US', {
      year: 'numeric',
      month: 'long',
      day: 'numeric',
    });
  } catch {
    return dateStr;
  }
}

// ---------------------------------------------------------------------------
// Official Retrieval Logic
// ---------------------------------------------------------------------------

async function safeFetchJson<T>(url: string): Promise<T | null> {
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), FETCH_TIMEOUT_MS);

  try {
    const res = await fetch(url, {
      signal: controller.signal,
      headers: {
        'User-Agent': USER_AGENT,
        Accept: 'application/json',
      },
    });
    clearTimeout(timeoutId);
    if (!res.ok) {
      console.error(`[Nexora Worker] Fetch failed for ${url} with status: ${res.status}`);
      return null;
    }
    return (await res.json()) as T;
  } catch (err: unknown) {
    clearTimeout(timeoutId);
    const errorName = err instanceof Error ? err.name : 'UnknownError';
    console.error(`[Nexora Worker] Error fetching ${url}: ${errorName}`);
    return null;
  }
}

interface WpPostItem {
  id?: number;
  date?: string;
  link?: string;
  title?: { rendered?: string };
  content?: { rendered?: string };
  excerpt?: { rendered?: string };
}

function extractSearchKeywords(query: string): string {
  const stopWords = new Set([
    'what', 'is', 'the', 'a', 'an', 'are', 'how', 'to', 'can', 'i', 'for', 'of',
    'in', 'on', 'at', 'by', 'with', 'about', 'tell', 'me', 'please', 'give', 'details',
    'information', 'process', 'when', 'where', 'which', 'who', 'why', 'do', 'does',
    'did', 'will', 'would', 'should', 'could', 'my', 'your', 'our', 'all'
  ]);

  const clean = query
    .toLowerCase()
    .replace(/[^\w\s]/g, ' ')
    .split(/\s+/)
    .filter((w) => w.length > 1 && !stopWords.has(w));

  return clean.length > 0 ? clean.join(' ') : query;
}

async function searchOfficialSources(rawQuery: string): Promise<{
  results: SearchResult[];
  sources: SourceInfo[];
}> {
  const query = rawQuery.trim();
  const encodedQuery = encodeURIComponent(query);
  const results: SearchResult[] = [];
  const seenUrls = new Set<string>();
  const activeSources: SourceInfo[] = [];

  // Query WordPress Posts and Pages in parallel
  let [postsData, pagesData] = await Promise.all([
    safeFetchJson<WpPostItem[]>(
      `https://bvcec.edu.in/wp-json/wp/v2/posts?search=${encodedQuery}&per_page=5`
    ),
    safeFetchJson<WpPostItem[]>(
      `https://bvcec.edu.in/wp-json/wp/v2/pages?search=${encodedQuery}&per_page=5`
    ),
  ]);

  // If exact query returns no results, try keyword-extracted query
  const keywords = extractSearchKeywords(query);
  if (
    (!Array.isArray(postsData) || postsData.length === 0) &&
    (!Array.isArray(pagesData) || pagesData.length === 0) &&
    keywords !== query &&
    keywords.length > 0
  ) {
    const encodedKeywords = encodeURIComponent(keywords);
    const [kwPosts, kwPages] = await Promise.all([
      safeFetchJson<WpPostItem[]>(
        `https://bvcec.edu.in/wp-json/wp/v2/posts?search=${encodedKeywords}&per_page=5`
      ),
      safeFetchJson<WpPostItem[]>(
        `https://bvcec.edu.in/wp-json/wp/v2/pages?search=${encodedKeywords}&per_page=5`
      ),
    ]);
    if (Array.isArray(kwPosts) && kwPosts.length > 0) postsData = kwPosts;
    if (Array.isArray(kwPages) && kwPages.length > 0) pagesData = kwPages;
  }

  const addResult = (
    titleRaw: string,
    urlRaw: string,
    contentRaw: string,
    excerptRaw: string,
    dateRaw: string | null,
    sourceName: string
  ) => {
    if (!urlRaw || !isValidOfficialUrl(urlRaw)) return;
    const cleanUrl = urlRaw.split('?')[0].replace(/\/$/, '') + '/';
    if (seenUrls.has(cleanUrl)) return;
    seenUrls.add(cleanUrl);

    const title = decodeHtmlEntities(cleanToPlainText(titleRaw));
    if (!title) return;

    const sourceHtml = contentRaw || excerptRaw || '';
    const snippet = buildRelevantSnippet(sourceHtml, query, title);

    results.push({
      title,
      url: urlRaw,
      source: sourceName,
      snippet,
      publishedDate: formatDate(dateRaw),
    });
  };

  if (Array.isArray(postsData)) {
    for (const post of postsData) {
      if (results.length >= MAX_RESULTS) break;
      const title = post.title?.rendered || '';
      const url = post.link || '';
      const content = post.content?.rendered || '';
      const excerpt = post.excerpt?.rendered || '';
      const date = post.date || null;
      addResult(title, url, content, excerpt, date, 'BVC Engineering College');
    }
  }

  if (Array.isArray(pagesData)) {
    for (const page of pagesData) {
      if (results.length >= MAX_RESULTS) break;
      const title = page.title?.rendered || '';
      const url = page.link || '';
      const content = page.content?.rendered || '';
      const excerpt = page.excerpt?.rendered || '';
      const date = page.date || null;
      addResult(title, url, content, excerpt, date, 'BVC Engineering College');
    }
  }

  const lowerQuery = query.toLowerCase();
  const isExamOrResults =
    lowerQuery.includes('result') ||
    lowerQuery.includes('exam') ||
    lowerQuery.includes('autonomous') ||
    lowerQuery.includes('hall ticket') ||
    lowerQuery.includes('revaluation') ||
    lowerQuery.includes('fee') ||
    lowerQuery.includes('grade');

  if (isExamOrResults && results.length < MAX_RESULTS) {
    const autonomousUrl = 'https://www.bvcecautonomous.com';
    if (!seenUrls.has(autonomousUrl)) {
      seenUrls.add(autonomousUrl);
      results.push({
        title: 'BVC Autonomous Examination & Results Portal',
        url: autonomousUrl,
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
          version: '2.0.0',
          status: 'online',
          message: 'Nexora BVC AI Backend (Phase 2 Grounded Retrieval & AI API)',
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
          version: '2.0.0',
          description:
            'Nexora official BVC Engineering College AI & retrieval API. Generates grounded answers using verified academic, syllabus, and examination sources.',
          endpoints: [
            {
              method: 'GET',
              path: '/health',
              description: 'Service health check',
            },
            {
              method: 'GET',
              path: '/api',
              description: 'API discovery and endpoint documentation',
            },
            {
              method: 'GET',
              path: '/search?q=<query>',
              description:
                'Search verified official BVC college sources (regulations, syllabus, exams, announcements, results)',
            },
            {
              method: 'POST',
              path: '/ask',
              description:
                'Ask a question and receive a grounded AI answer synthesized from official BVC College sources',
              requestBody: {
                question: 'What is the BR23 internal assessment process?',
              },
            },
          ],
          allowedSources: Array.from(ALLOWED_HOSTS),
        });
      }

      // 4. Official Search Route (GET /search?q=...)
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
        const { results, sources } = await searchOfficialSources(trimmedQuery);

        if (results.length === 0) {
          return jsonResponse({
            success: true,
            query: trimmedQuery,
            results: [],
            sources: [],
            message:
              'No relevant information was found from the currently configured official BVC sources.',
          });
        }

        return jsonResponse({
          success: true,
          query: trimmedQuery,
          results,
          sources,
        });
      }

      // 5. Grounded AI Generation Route (POST /ask)
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

        // Step 1: Run official BVC source retrieval
        const { results, sources } = await searchOfficialSources(trimmedQuestion);

        // Step 2: Handle empty retrieval (no relevant BVC sources found)
        if (results.length === 0) {
          return jsonResponse({
            success: true,
            question: trimmedQuestion,
            answer:
              "I couldn't find enough verified information from the currently configured official BVC sources to answer this accurately. Please check the official college portal at https://bvcec.edu.in or the autonomous examination portal at https://www.bvcecautonomous.com for details.",
            sources: [],
          });
        }

        // Step 3: Build structured official context
        const officialContext = results
          .map(
            (r, i) =>
              `[Source ${i + 1}] Title: ${r.title}\nSource: ${r.source}\nURL: ${r.url}\nExcerpt: ${r.snippet}`
          )
          .join('\n\n');

        // Step 4: Generate grounded AI response
        try {
          const { apiKey, aiBinding } = aiService.resolveActiveProvider(env);

          // If no AI key or binding is configured, return clean retrieval synthesis
          if (!apiKey && !aiBinding) {
            const synthesizedSummary = results
              .map((r) => `• **${r.title}**: ${r.snippet}`)
              .join('\n\n');

            return jsonResponse({
              success: true,
              question: trimmedQuestion,
              answer: `Here is the official information retrieved from BVC College sources for "${trimmedQuestion}":\n\n${synthesizedSummary}`,
              sources: results.map((r) => ({
                title: r.title,
                url: r.url,
                source: r.source,
              })),
            });
          }

          const aiResult = await aiService.generateGroundedAnswer({
            question: trimmedQuestion,
            officialContext,
            env,
          });

          return jsonResponse({
            success: true,
            question: trimmedQuestion,
            answer: aiResult.answer,
            sources: results.map((r) => ({
              title: r.title,
              url: r.url,
              source: r.source,
            })),
          });
        } catch (aiErr: any) {
          console.error('[Nexora Worker] AI Generation error:', aiErr?.message || aiErr);

          // Fallback to grounded summary if AI provider encounters a temporary failure
          const fallbackSummary = results
            .map((r) => `• **${r.title}**: ${r.snippet}`)
            .join('\n\n');

          return jsonResponse({
            success: true,
            question: trimmedQuestion,
            answer: `Here is the official information retrieved from BVC College sources for "${trimmedQuestion}":\n\n${fallbackSummary}`,
            sources: results.map((r) => ({
              title: r.title,
              url: r.url,
              source: r.source,
            })),
          });
        }
      }

      // 6. Unknown routes or unsupported methods
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
