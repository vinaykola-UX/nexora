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

// ---------------------------------------------------------------------------
// Advanced Content Extraction & Cleaning Utilities
// ---------------------------------------------------------------------------

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

/**
 * Strips boilerplate HTML containers (headers, navs, menus, footers, scripts, sidebars)
 */
function removeBoilerplateHtml(html: string): string {
  if (!html) return '';
  let cleaned = html;

  // 1. Remove script, style, noscript, svg, iframe tags
  cleaned = cleaned.replace(/<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/gi, ' ');
  cleaned = cleaned.replace(/<style\b[^<]*(?:(?!<\/style>)<[^<]*)*<\/style>/gi, ' ');
  cleaned = cleaned.replace(/<noscript\b[^<]*(?:(?!<\/noscript>)<[^<]*)*<\/noscript>/gi, ' ');
  cleaned = cleaned.replace(/<svg\b[^<]*(?:(?!<\/svg>)<[^<]*)*<\/svg>/gi, ' ');

  // 2. Remove semantic layout / navigation elements
  cleaned = cleaned.replace(/<nav\b[^<]*(?:(?!<\/nav>)<[^<]*)*<\/nav>/gi, ' ');
  cleaned = cleaned.replace(/<header\b[^<]*(?:(?!<\/header>)<[^<]*)*<\/header>/gi, ' ');
  cleaned = cleaned.replace(/<footer\b[^<]*(?:(?!<\/footer>)<[^<]*)*<\/footer>/gi, ' ');
  cleaned = cleaned.replace(/<aside\b[^<]*(?:(?!<\/aside>)<[^<]*)*<\/aside>/gi, ' ');

  // 3. Remove common navigation, menu, breadcrumb, and widget classes
  cleaned = cleaned.replace(/<[^>]+class="[^"]*(?:elementor-nav-menu|nav-menu|menu-item|rank-math-breadcrumb|breadcrumb|site-header|site-footer|widget-area|sidebar|post-meta-author)[^"]*"[^>]*>[\s\S]*?<\/[^>]+>/gi, ' ');

  // 4. Remove common repetitive college header navigation phrases
  cleaned = cleaned.replace(/NIRF\s+Home\s+About\s+Us\s+About\s+BVCEC\s+Vision\s+&\s+Mission\s+Quality\s+Policy\s+Academic\s+Council/gi, ' ');
  cleaned = cleaned.replace(/BVC\s+ENGINEERING\s+COLLEGE\s+\(AUTONOMOUS\)\s+ODALAREVU/gi, ' ');

  return cleaned;
}

/**
 * Extracts main content from targeted containers (article, entry-content, main)
 */
function extractMainContent(rawHtml: string): string {
  if (!rawHtml) return '';

  // First remove boilerplate tags
  const filteredHtml = removeBoilerplateHtml(rawHtml);

  // Attempt to target preferred content containers
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

/**
 * Cleans and normalizes plain text from HTML
 */
function cleanToPlainText(rawHtml: string): string {
  if (!rawHtml) return '';
  const mainHtml = extractMainContent(rawHtml);
  // Strip all HTML tags
  const noTags = mainHtml.replace(/<[^>]+>/g, ' ');
  // Decode HTML entities
  const decoded = decodeHtmlEntities(noTags);
  // Normalize whitespace
  return decoded.replace(/\s+/g, ' ').trim();
}

/**
 * Generates a high-quality 300–600 character snippet prioritizing query keyword matches
 */
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

  // Tokenize query words (excluding short words)
  const queryTokens = query
    .toLowerCase()
    .split(/\s+/)
    .map((w) => w.replace(/[^a-z0-9]/g, ''))
    .filter((w) => w.length >= 2);

  // If text is already within optimal bounds, return it
  if (fullText.length <= maxLen) {
    return fullText;
  }

  // Split into sentences / meaningful chunks
  const sentences = fullText.match(/[^.!?]+[.!?]+(\s+|$)|[^.!?]+$/g) || [fullText];

  // Score sentences based on query keyword matches
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

  // Assemble snippet starting from the best matching sentence or surrounding window
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

  // Clean trailing punctuation / words
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

    // Use content if available, falling back to excerpt
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

  // 1. Process Posts (Exam notifications, circulars, time tables, results)
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

  // 2. Process Pages (Regulations, Syllabus, Departments, Academic Calendars)
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

  // 3. Autonomous Results / Exam Portal contextual entry
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
