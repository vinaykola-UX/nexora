/**
 * Nexora AI — Public Cloudflare Web Gateway Worker
 * Production URL: https://nexora.vkola306.workers.dev
 */

interface Env {
  PAGES_ORIGIN?: string;
}

export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    const url = new URL(request.url);
    const pagesOrigin = env.PAGES_ORIGIN || 'https://nexora-a8m.pages.dev';

    // Handle CORS preflight
    if (request.method === 'OPTIONS') {
      return new Response(null, {
        status: 204,
        headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, HEAD, OPTIONS',
          'Access-Control-Allow-Headers': '*',
        },
      });
    }

    // Serve static web application from Pages origin
    const targetPagesUrl = new URL(url.pathname + url.search, pagesOrigin);
    let pageResponse = await fetch(targetPagesUrl.toString(), {
      method: request.method,
      headers: request.headers,
      redirect: 'follow',
    });

    // SPA fallback: if not found and HTML requested, serve index.html
    if (pageResponse.status === 404 && !url.pathname.includes('.')) {
      const indexUrl = new URL('/index.html', pagesOrigin);
      pageResponse = await fetch(indexUrl.toString(), {
        method: request.method,
        headers: request.headers,
      });
    }

    const responseHeaders = new Headers(pageResponse.headers);
    responseHeaders.set('Access-Control-Allow-Origin', '*');
    responseHeaders.set('X-Served-By', 'Nexora-Cloudflare-Worker');

    // Add caching headers for static assets
    if (url.pathname.match(/\.(css|js|png|jpg|jpeg|svg|webp|woff2|ico)$/)) {
      responseHeaders.set('Cache-Control', 'public, max-age=86400, stale-while-revalidate=604800');
    }

    return new Response(pageResponse.body, {
      status: pageResponse.status,
      statusText: pageResponse.statusText,
      headers: responseHeaders,
    });
  },
};
