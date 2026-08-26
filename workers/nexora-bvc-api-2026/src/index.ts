/**
 * Nexora BVC AI — Cloudflare Worker Official Retrieval Backend
 * Service: nexora-bvc-api-2026
 *
 * Exclusively retrieves student academic, examination, regulation, and syllabus information
 * from approved official BVC Engineering College sources.
 */

export interface Env {
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

// Standard CORS headers for cross-origin app requests
const CORS_HEADERS: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Requested-With',
  'Access-Control-Max-Age': '86400',
};

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
    .replace(/&nbsp;/g, ' ')
    .replace(/&#\d+;/g, (match) => {
      const num = parseInt(match.replace(/&#|;/g, ''), 10);
      return !isNaN(num) ? String.fromCharCode(num) : '';
    });
}

function cleanText(rawHtml: string): string {
  if (!rawHtml) return '';
  // Remove script and style tags and their contents
  const noScript = rawHtml.replace(/<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/gi, '');
  const noStyle = noScript.replace(/<style\b[^<]*(?:(?!<\/style>)<[^<]*)*<\/style>/gi, '');
  // Strip all remaining HTML tags
  const noTags = noStyle.replace(/<[^>]+>/g, ' ');
  // Decode HTML entities
  const decoded = decodeHtmlEntities(noTags);
  // Normalize whitespace
  return decoded.replace(/\s+/g, ' ').trim();
}

function truncateSnippet(text: string, maxLength = 220): string {
  if (!text) return '';
  const clean = cleanText(text);
  if (clean.length <= maxLength) return clean;
  const truncated = clean.substring(0, maxLength);
  const lastSpace = truncated.lastIndexOf(' ');
  return (lastSpace > 50 ? truncated.substring(0, lastSpace) : truncated) + '...';
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
  const [postsData, pagesData] = await Promise.all([
    safeFetchJson<WpPostItem[]>(
      `https://bvcec.edu.in/wp-json/wp/v2/posts?search=${encodedQuery}&per_page=5`
    ),
    safeFetchJson<WpPostItem[]>(
      `https://bvcec.edu.in/wp-json/wp/v2/pages?search=${encodedQuery}&per_page=5`
    ),
  ]);

  const addResult = (
    titleRaw: string,
    urlRaw: string,
    contentRaw: string,
    dateRaw: string | null,
    sourceName: string
  ) => {
    if (!urlRaw || !isValidOfficialUrl(urlRaw)) return;
    const cleanUrl = urlRaw.split('?')[0].replace(/\/$/, '') + '/';
    if (seenUrls.has(cleanUrl)) return;
    seenUrls.add(cleanUrl);

    const title = decodeHtmlEntities(cleanText(titleRaw));
    if (!title) return;

    let snippet = cleanText(contentRaw);
    if (!snippet || snippet.length < 15) {
      snippet = `Official BVC Engineering College portal information for "${title}".`;
    }

    results.push({
      title,
      url: urlRaw,
      source: sourceName,
      snippet: truncateSnippet(snippet),
      publishedDate: formatDate(dateRaw),
    });
  };

  // 1. Process Posts (Exam notifications, circulars, time tables, results)
  if (Array.isArray(postsData)) {
    for (const post of postsData) {
      if (results.length >= MAX_RESULTS) break;
      const title = post.title?.rendered || '';
      const url = post.link || '';
      const snippet = post.excerpt?.rendered || post.content?.rendered || '';
      const date = post.date || null;
      addResult(title, url, snippet, date, 'BVC Engineering College');
    }
  }

  // 2. Process Pages (Regulations, Syllabus, Departments, Academic Calendars)
  if (Array.isArray(pagesData)) {
    for (const page of pagesData) {
      if (results.length >= MAX_RESULTS) break;
      const title = page.title?.rendered || '';
      const url = page.link || '';
      const snippet = page.excerpt?.rendered || page.content?.rendered || '';
      const date = page.date || null;
      addResult(title, url, snippet, date, 'BVC Engineering College');
    }
  }

  // 3. Autonomous Results / Exam Portal contextual entry
  const lowerQuery = query.toLowerCase();
  const isExamOrResults =
    lowerQuery.includes('result') ||
    lowerQuery.includes('exam') ||
    lowerQuery.includes('autonomous') ||
    lowerQuery.includes('hall ticket') ||
    lowerQuery.includes('revaluation') ||
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
          'Official autonomous examinations portal for BVC Engineering College students. Check end examination results, supplementary schedules, student logins, and academic grade sheets.',
        publishedDate: null,
      });
    }
  }

  // Populate verified sources array
  if (results.some((r) => r.url.includes('bvcec.edu.in'))) {
    activeSources.push({
      title: 'BVC Engineering College Official Portal',
      url: 'https://bvcec.edu.in',
    });
  }
  if (results.some((r) => r.url.includes('bvcecautonomous.com'))) {
    activeSources.push({
      title: 'BVC Autonomous Examination & Results Portal',
      url: 'https://www.bvcecautonomous.com',
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
  async fetch(request: Request, _env: Env, _ctx: ExecutionContext): Promise<Response> {
    // Handle CORS preflight
    if (request.method === 'OPTIONS') {
      return new Response(null, {
        status: 204,
        headers: CORS_HEADERS,
      });
    }

    // Only allow GET requests for these endpoints
    if (request.method !== 'GET') {
      return jsonResponse(
        {
          success: false,
          error: 'Method Not Allowed',
          message: `Method ${request.method} is not supported.`,
        },
        405
      );
    }

    const url = new URL(request.url);
    const path = url.pathname.replace(/\/$/, '') || '/';

    try {
      // 1. Root route
      if (path === '/') {
        return jsonResponse({
          success: true,
          service: 'nexora-bvc-api-2026',
          version: '1.0.0',
          status: 'online',
          message: 'Nexora BVC AI Backend Retrieval API',
        });
      }

      // 2. Health check route
      if (path === '/health') {
        return jsonResponse({
          status: 'healthy',
          service: 'nexora-bvc-api-2026',
          timestamp: new Date().toISOString(),
          uptime: 'operational',
        });
      }

      // 3. API documentation / discovery route
      if (path === '/api') {
        return jsonResponse({
          success: true,
          service: 'nexora-bvc-api-2026',
          version: '1.0.0',
          description:
            'Nexora official BVC Engineering College retrieval API. Queries verified academic, syllabus, and examination sources.',
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
          ],
          allowedSources: Array.from(ALLOWED_HOSTS),
        });
      }

      // 4. Official Search Route
      if (path === '/search') {
        const query = url.searchParams.get('q');

        // Validation: q must be present and non-empty
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

      // 5. Unknown routes
      return jsonResponse(
        {
          success: false,
          error: 'Not Found',
          message: `The requested endpoint '${url.pathname}' does not exist on this server.`,
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
