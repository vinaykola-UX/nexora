/**
 * Nexora AI — Verified Source & PDF Download Helper
 * Ensures all external links, campus PDFs, and academic circulars
 * open reliably and download cleanly without errors.
 */

class NexoraResourceHelper {
  /**
   * Safely open any external URL in a new window/tab
   * @param {string} url - Target URL
   */
  static openLink(url) {
    if (!url) return;
    let cleanUrl = url.trim();
    if (!cleanUrl.startsWith('http://') && !cleanUrl.startsWith('https://')) {
      cleanUrl = 'https://' + cleanUrl;
    }

    try {
      const win = window.open(cleanUrl, '_blank', 'noopener,noreferrer');
      if (!win) {
        // If popup blocker intervened, fallback to simulated anchor click
        const a = document.createElement('a');
        a.href = cleanUrl;
        a.target = '_blank';
        a.rel = 'noopener noreferrer';
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
      }
    } catch (e) {
      console.warn('[Nexora Helper] Failed to open window directly, falling back:', e);
      window.location.href = cleanUrl;
    }
  }

  /**
   * Determine if a URL represents a PDF document
   * @param {string} url
   * @returns {boolean}
   */
  static isPdfUrl(url) {
    if (!url) return false;
    const clean = url.toLowerCase().split('?')[0].split('#')[0];
    return clean.endsWith('.pdf') || url.includes('/pdf/') || url.includes('.pdf?');
  }

  /**
   * Downloads a PDF file to the user's local disk cleanly
   * Strategy 1: Fetch as Blob and create object URL (instant trigger with custom filename)
   * Strategy 2: Direct Anchor download attribute
   * Strategy 3: Open in new tab for browser native save
   * @param {string} url - The target PDF URL
   * @param {string} suggestedTitle - Optional suggested filename
   */
  static async downloadPdf(url, suggestedTitle) {
    if (!url) return;
    let cleanUrl = url.trim();
    if (!cleanUrl.startsWith('http://') && !cleanUrl.startsWith('https://')) {
      cleanUrl = 'https://' + cleanUrl;
    }

    const filename = this.deriveFilename(cleanUrl, suggestedTitle);

    // Strategy 1: Fetch as Blob (ideal for cross-origin or local proxy)
    try {
      const response = await fetch(cleanUrl, {
        method: 'GET',
        mode: 'cors',
      });

      if (response.ok) {
        const blob = await response.blob();
        const blobUrl = window.URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.style.display = 'none';
        a.href = blobUrl;
        a.download = filename;
        document.body.appendChild(a);
        a.click();
        window.URL.revokeObjectURL(blobUrl);
        document.body.removeChild(a);
        return { success: true, method: 'blob', filename };
      }
    } catch (fetchErr) {
      console.warn('[Nexora Helper] Blob download failed (possibly CORS), attempting direct anchor:', fetchErr);
    }

    // Strategy 2: Direct Anchor download
    try {
      const a = document.createElement('a');
      a.href = cleanUrl;
      a.download = filename;
      a.target = '_blank';
      a.rel = 'noopener noreferrer';
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      return { success: true, method: 'anchor', filename };
    } catch (anchorErr) {
      console.warn('[Nexora Helper] Anchor download failed, falling back to tab open:', anchorErr);
    }

    // Strategy 3: Open PDF directly in new tab so user can print / save locally
    this.openLink(cleanUrl);
    return { success: true, method: 'open_tab', filename };
  }

  /**
   * Derives a clean filename ending with .pdf
   */
  static deriveFilename(url, title) {
    if (title && title.trim().length > 0) {
      const sanitized = title.replace(/[^a-zA-Z0-9_\-\s]/g, '').trim().replace(/\s+/g, '_');
      return sanitized.toLowerCase().endsWith('.pdf') ? sanitized : `${sanitized}.pdf`;
    }

    try {
      const urlObj = new URL(url);
      const pathname = urlObj.pathname;
      const parts = pathname.split('/');
      const last = parts[parts.length - 1];
      if (last && last.toLowerCase().endsWith('.pdf')) {
        return last;
      }
    } catch (_) {}

    return `nexora_bvc_document_${Date.now()}.pdf`;
  }
}

// Make accessible globally
window.NexoraResourceHelper = NexoraResourceHelper;
