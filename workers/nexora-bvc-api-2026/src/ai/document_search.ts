/**
 * ============================================================================
 * BVC Nexora — Deterministic Document & PDF Retrieval Engine
 * ============================================================================
 *
 * Direct, authoritative retrieval partner for original college documents stored
 * in Cloudflare D1.
 *
 * RULES:
 * 1. ZERO AI hallucination: Never generate fake PDFs or replacement files.
 * 2. ZERO URL fabrication: Never create fake download links.
 * 3. Exact URL validation:
 *    - CASE 1 (Real URL): file_url starts with http:// or https:// -> isAvailable = true
 *    - CASE 2 (Citation): file_url has citation/source string -> isAvailable = false, source = file_url
 *    - CASE 3 (Null/empty): file_url is null/empty -> isAvailable = false, fileUrl = null
 * 4. Deterministic scoring across title, subject, unit, and verified metadata.
 * ============================================================================
 */

export interface D1DocumentRecord {
  id: number;
  title: string;
  subject: string;
  unit: number;
  file_url: string | null;
  created_at?: string;
}

export interface NexoraDocumentInfoPayload {
  id: number;
  title: string;
  subject: string;
  unit: number;
  fileUrl: string | null;
  source: string | null;
  isAvailable: boolean;
}

export interface DocumentSearchResult {
  status: 'single_match' | 'multiple_matches' | 'no_match';
  document?: NexoraDocumentInfoPayload;
  documents: NexoraDocumentInfoPayload[];
  answer: string;
}

export class DocumentSearchEngine {
  private static instance: DocumentSearchEngine | null = null;

  public static getInstance(): DocumentSearchEngine {
    if (!DocumentSearchEngine.instance) {
      DocumentSearchEngine.instance = new DocumentSearchEngine();
    }
    return DocumentSearchEngine.instance;
  }

  /**
   * Parse and validate file_url strictly according to the 3 production cases:
   * - CASE 1: Real URL (http:// or https://)
   * - CASE 2: Source citation (metadata text, not a direct URL)
   * - CASE 3: Null / empty
   */
  public parseFileUrl(rawUrl: string | null): {
    fileUrl: string | null;
    source: string | null;
    isAvailable: boolean;
  } {
    if (!rawUrl || typeof rawUrl !== 'string' || rawUrl.trim().length === 0) {
      return {
        fileUrl: null,
        source: null,
        isAvailable: false,
      };
    }

    const trimmed = rawUrl.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return {
        fileUrl: trimmed,
        source: null,
        isAvailable: true,
      };
    }

    // Source citation / archival reference metadata
    return {
      fileUrl: null,
      source: trimmed,
      isAvailable: false,
    };
  }

  /**
   * Extract target unit number from user query (e.g. "unit 2", "unit ii", "2nd unit")
   */
  public extractTargetUnit(query: string): number | null {
    const q = query.toLowerCase();
    
    // Arabic numerals
    const arabicMatch = q.match(/\b(?:unit|u)[-\s]*(\d+)\b/i) || q.match(/\b(\d+)(?:st|nd|rd|th)?\s+unit\b/i);
    if (arabicMatch) {
      const num = parseInt(arabicMatch[1], 10);
      if (!isNaN(num) && num > 0 && num <= 10) return num;
    }

    // Roman numerals
    const romanMap: Record<string, number> = {
      i: 1,
      ii: 2,
      iii: 3,
      iv: 4,
      v: 5,
      vi: 6,
      vii: 7,
      viii: 8,
      ix: 9,
      x: 10,
    };

    const romanMatch = q.match(/\b(?:unit|u)[-\s]+(i|ii|iii|iv|v|vi|vii|viii|ix|x)\b/i);
    if (romanMatch) {
      const rom = romanMatch[1].toLowerCase();
      if (romanMap[rom]) return romanMap[rom];
    }

    return null;
  }

  /**
   * Search authoritative D1 documents table deterministically
   */
  public async searchDocuments(
    db: any,
    query: string
  ): Promise<DocumentSearchResult> {
    const rawQuery = (query || '').trim();
    const q = rawQuery.toLowerCase();

    // 1. Fetch authoritative documents from D1
    let documents: D1DocumentRecord[] = [];
    if (db) {
      try {
        const { results } = await db.prepare(
          'SELECT id, title, subject, unit, file_url, created_at FROM documents ORDER BY id DESC'
        ).all();
        documents = results || [];
      } catch (err: any) {
        console.error('[DocumentSearchEngine] D1 fetch error:', err?.message || err);
      }
    }

    if (!documents || documents.length === 0) {
      return {
        status: 'no_match',
        documents: [],
        answer: `I searched the official BVC repository, but no verified matching document or PDF was found for "${rawQuery}". I cannot fabricate or generate replacement documents.`,
      };
    }

    const targetUnit = this.extractTargetUnit(q);

    // Stopwords to ignore during token scoring
    const stopWords = new Set([
      'the', 'a', 'an', 'and', 'or', 'for', 'of', 'in', 'to', 'is', 'are', 'on', 'at',
      'give', 'me', 'send', 'show', 'need', 'i', 'can', 'you', 'please', 'get', 'download',
      'pdf', 'document', 'documents', 'notes', 'material', 'materials', 'study', 'handout',
      'official', 'original', 'bvc', 'college', 'file', 'tell', 'about',
    ]);

    const queryTokens = q
      .replace(/[^a-z0-9\s]/g, ' ')
      .split(/\s+/)
      .filter((t) => t.length > 1 && !stopWords.has(t));

    // 2. Score candidate documents deterministically
    const scoredDocs: Array<{
      doc: D1DocumentRecord;
      score: number;
      parsed: { fileUrl: string | null; source: string | null; isAvailable: boolean };
    }> = [];

    for (const doc of documents) {
      let score = 0;
      const titleLower = (doc.title || '').toLowerCase();
      const subjectLower = (doc.subject || '').toLowerCase();
      const fileUrlLower = (doc.file_url || '').toLowerCase();

      // A. Unit Matching
      if (targetUnit !== null) {
        if (doc.unit === targetUnit) {
          score += 30; // Strong match for matching requested unit
        } else {
          score -= 50; // Heavy penalty if student asked for a specific unit and this is not it
        }
      }

      // B. Subject Keyword Matching
      // ADS / Advanced Data Structures
      if (
        (q.includes('ads') || q.includes('advanced data structure')) &&
        (subjectLower.includes('advanced data structure') || titleLower.includes('advanced data structure'))
      ) {
        score += 35;
      }
      // Standard Data Structures (only if not specifically asking for ADS when ADS exists)
      if (
        (q.includes('data structure') || q.includes('ds')) &&
        !q.includes('ads') &&
        (subjectLower === 'data structures' || titleLower.includes('data structures -'))
      ) {
        score += 35;
      }
      // Software Engineering / Java
      if (
        (q.includes('software engineering') || q.includes('se') || q.includes('java')) &&
        (subjectLower.includes('software engineering') || titleLower.includes('software engineering') || titleLower.includes('java'))
      ) {
        score += 35;
      }
      // College Profile / About
      if (
        (q.includes('college') || q.includes('profile') || q.includes('bvc')) &&
        (titleLower.includes('collage') || titleLower.includes('profile') || fileUrlLower.includes('profile'))
      ) {
        score += 25;
      }

      // C. Topic / Concept Matching
      if (q.includes('syllabus') && (titleLower.includes('syllabus') || fileUrlLower.includes('syllabus'))) {
        score += 40;
      }
      if ((q.includes('linked list') || q.includes('linked lists')) && titleLower.includes('linked list')) {
        score += 40;
      }
      if ((q.includes('hash') || q.includes('hashing') || q.includes('dictionary') || q.includes('dictionaries')) &&
          (titleLower.includes('hash') || titleLower.includes('dictionar'))) {
        score += 40;
      }
      if ((q.includes('inheritance') || q.includes('polymorphism')) && titleLower.includes('inheritance')) {
        score += 40;
      }

      // D. General Token Overlap
      for (const token of queryTokens) {
        if (titleLower.includes(token)) score += 10;
        if (subjectLower.includes(token)) score += 8;
        if (fileUrlLower.includes(token)) score += 6;
      }

      const parsed = this.parseFileUrl(doc.file_url);

      // Only consider if score > 0
      if (score > 0) {
        scoredDocs.push({ doc, score, parsed });
      }
    }

    // Sort descending by score
    scoredDocs.sort((a, b) => b.score - a.score);

    // 3. Evaluate results
    if (scoredDocs.length === 0 || scoredDocs[0].score <= 0) {
      return {
        status: 'no_match',
        documents: [],
        answer: `I searched the official BVC repository, but no verified matching document or PDF was found for "${rawQuery}". I cannot fabricate or generate replacement documents.`,
      };
    }

    const topItem = scoredDocs[0];
    const topScore = topItem.score;

    // Check for multiple viable matches:
    // If student asked a broad query (e.g. "Give me Unit 2 PDFs", "Give me notes")
    // or if the second match is strong and within 70% of top score
    const runnerUps = scoredDocs.slice(1).filter((item) => item.score >= 25 && item.score >= topScore * 0.7);

    // A request is only broad if no specific subject or topic was requested
    const hasSubjectOrTopic =
      q.includes('ads') ||
      q.includes('advanced data structure') ||
      q.includes('data structure') ||
      q.includes('software engineering') ||
      q.includes('java') ||
      q.includes('se') ||
      q.includes('syllabus') ||
      q.includes('linked list') ||
      q.includes('hash') ||
      q.includes('inheritance') ||
      q.includes('collage') ||
      q.includes('profile');

    const isBroadRequest = targetUnit !== null && !hasSubjectOrTopic;

    if (runnerUps.length > 0 && (isBroadRequest || (runnerUps.length >= 2 && !hasSubjectOrTopic))) {
      const allMatches = [topItem, ...runnerUps].slice(0, 4);
      const payloadDocs: NexoraDocumentInfoPayload[] = allMatches.map((m) => ({
        id: m.doc.id,
        title: m.doc.title,
        subject: m.doc.subject,
        unit: m.doc.unit,
        fileUrl: m.parsed.fileUrl,
        source: m.parsed.source,
        isAvailable: m.parsed.isAvailable,
      }));

      const docListLines = payloadDocs.map((d, idx) => {
        const availText = d.isAvailable ? '✓ Direct Download Available' : (d.source ? '• Source Available' : '• PDF Not Currently Available');
        return `${idx + 1}. **${d.title}** (${d.subject} — Unit ${d.unit}) [${availText}]`;
      });

      return {
        status: 'multiple_matches',
        document: payloadDocs[0],
        documents: payloadDocs,
        answer: `I found ${payloadDocs.length} matching official documents in the verified BVC repository:\n\n${docListLines.join('\n')}`,
      };
    }

    // Single match
    const singleDocPayload: NexoraDocumentInfoPayload = {
      id: topItem.doc.id,
      title: topItem.doc.title,
      subject: topItem.doc.subject,
      unit: topItem.doc.unit,
      fileUrl: topItem.parsed.fileUrl,
      source: topItem.parsed.source,
      isAvailable: topItem.parsed.isAvailable,
    };

    let answerText = '';
    if (singleDocPayload.isAvailable && singleDocPayload.fileUrl) {
      answerText = `I found the original document in the verified BVC knowledge base: **${singleDocPayload.title}** (${singleDocPayload.subject} — Unit ${singleDocPayload.unit}). Tap 'Open PDF' to view or download the original file.`;
    } else if (singleDocPayload.source) {
      answerText = `I found the document source in the verified BVC knowledge base: **${singleDocPayload.title}** (${singleDocPayload.subject} — Unit ${singleDocPayload.unit}).

${singleDocPayload.source}

The document source is available in Nexora, but the original PDF is not currently available for direct download.`;
    } else {
      answerText = `I found the document record in the verified BVC knowledge base: **${singleDocPayload.title}** (${singleDocPayload.subject} — Unit ${singleDocPayload.unit}), but the original PDF file is not currently available for direct download.`;
    }

    return {
      status: 'single_match',
      document: singleDocPayload,
      documents: [singleDocPayload],
      answer: answerText,
    };
  }
}
