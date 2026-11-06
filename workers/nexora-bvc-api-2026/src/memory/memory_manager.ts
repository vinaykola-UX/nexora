/**
 * ============================================================================
 * Nexora AI — Production-Grade Memory Manager
 * ============================================================================
 * Orchestrates memory extraction, sanitization, deduplication, rolling summaries,
 * and automatic conversation title generation.
 * ============================================================================
 */

import {
  ExtractedMemory,
  MemoryExtractionResult,
  MemoryCategory,
  StudentMemory,
  MessageRecord,
} from './memory_types';

export class MemoryManager {
  // Regex patterns for sensitive information that must NEVER be stored as memory
  private static readonly SENSITIVE_PATTERNS: RegExp[] = [
    /password/i,
    /passwd/i,
    /api[_-]?key/i,
    /secret/i,
    /bearer\s+[a-zA-Z0-9._-]+/i,
    /firebase[_-]?token/i,
    /access[_-]?token/i,
    /refresh[_-]?token/i,
    /id[_-]?token/i,
    /\b[0-9]{4}[- ]?[0-9]{4}[- ]?[0-9]{4}[- ]?[0-9]{4}\b/, // Credit cards
    /\b[A-Za-z0-9+/]{30,}={0,2}\b/, // Base64 hashes / private keys
    /auth[_-]?code/i,
  ];

  /**
   * Sanitizes text to ensure no sensitive credentials, secrets, or tokens are recorded.
   */
  public static sanitizeText(text: string): { isClean: boolean; reason?: string } {
    if (!text || typeof text !== 'string') {
      return { isClean: false, reason: 'Empty text' };
    }

    for (const pattern of this.SENSITIVE_PATTERNS) {
      if (pattern.test(text)) {
        return { isClean: false, reason: `Matches sensitive pattern: ${pattern.toString()}` };
      }
    }

    return { isClean: true };
  }

  /**
   * Generates a clean, concise conversation title based on the first user query.
   * Examples: "AVL Tree Basics", "Java Inheritance", "Data Structures Revision".
   */
  public static generateTitle(firstUserMessage: string): string {
    if (!firstUserMessage || !firstUserMessage.trim()) {
      return 'New Conversation';
    }

    // Strip common conversational preamble
    let cleaned = firstUserMessage
      .replace(/^(hello|hi|hey|nexora|please|can you|could you|tell me about|explain|what is|how does|give me|write|describe)\s+/gi, '')
      .replace(/[?!.:;]+$/g, '')
      .trim();

    if (!cleaned) {
      cleaned = firstUserMessage.trim();
    }

    // Capitalize words
    const words = cleaned.split(/\s+/).slice(0, 5);
    const title = words
      .map((w) => w.charAt(0).toUpperCase() + w.slice(1).toLowerCase())
      .join(' ');

    if (title.length > 35) {
      return `${title.substring(0, 32)}...`;
    }

    return title || 'New Conversation';
  }

  /**
   * Selectively extracts durable, non-sensitive student memories.
   * Ephemeral questions ("What is stack?") are NOT remembered.
   * Explicit preferences ("I prefer C for code", "I am in 2nd year CSE", "Preparing for GATE") ARE remembered.
   */
  public static extractMemories(
    userMessage: string,
    aiResponse?: string
  ): MemoryExtractionResult {
    const text = userMessage.trim();
    if (!text) {
      return { shouldRemember: false, memories: [] };
    }

    // 1. Mandatory Sensitive Sanitization Check
    const sanitization = this.sanitizeText(text);
    if (!sanitization.isClean) {
      console.warn('[MemoryManager] Rejected candidate memory due to sensitivity:', sanitization.reason);
      return { shouldRemember: false, memories: [] };
    }

    const lower = text.toLowerCase();
    const extracted: ExtractedMemory[] = [];

    // 2. Pattern Rule A: Programming Language Preference
    const progMatch = lower.match(/(?:i prefer|i like|use|write in|code in|give (?:me )?examples in)\s+(c|c\+\+|cpp|java|python|dart|javascript|typescript|c#|rust|go)\b/i);
    if (progMatch) {
      const lang = progMatch[1].toUpperCase();
      extracted.push({
        text: `Student prefers ${lang} for programming examples and implementations.`,
        category: 'programming_preference',
        importance: 0.85,
      });
    }

    // 2. Pattern Rule B: Academic Year / Branch Context
    const yearMatch = lower.match(/(?:i am|i'm|im)(?: a)?\s+(1st|2nd|3rd|4th|first|second|third|fourth)\s+year\s+(?:student in\s+)?([a-z\s]+?)(?:branch|dept|department|\.|$)/i);
    if (yearMatch) {
      const year = yearMatch[1].toLowerCase();
      const branch = yearMatch[2].trim().toUpperCase();
      extracted.push({
        text: `Student is in ${year} year studying ${branch}.`,
        category: 'recurring_context',
        importance: 0.9,
      });
    }

    // 2. Pattern Rule C: Learning Goal / Exam Preparation
    const goalMatch = lower.match(/(?:i am|i'm|im)\s+preparing for\s+(gate|campus placements?|semester exams?|mid exams?|internships?|ads exam|jntuk exams?)/i);
    if (goalMatch) {
      const goal = goalMatch[1].toUpperCase();
      extracted.push({
        text: `Student is actively preparing for ${goal}.`,
        category: 'learning_goal',
        importance: 0.85,
      });
    }

    // 2. Pattern Rule D: Study / Explanation Preference
    if (
      lower.includes('explain in simple terms') ||
      lower.includes('explain like i am 5') ||
      lower.includes('eli5') ||
      lower.includes('keep explanations beginner friendly')
    ) {
      extracted.push({
        text: 'Student prefers beginner-friendly explanations with simple analogies.',
        category: 'study_preference',
        importance: 0.75,
      });
    } else if (
      lower.includes('use bullet points') ||
      lower.includes('i prefer bullet points') ||
      lower.includes('give summary notes')
    ) {
      extracted.push({
        text: 'Student prefers answers structured with concise bullet points and headings.',
        category: 'study_preference',
        importance: 0.75,
      });
    }

    // 2. Pattern Rule E: Subject / Topic Interest
    const interestMatch = lower.match(/(?:i want to master|i'm focusing on|i am focusing on|i love studying|my favorite subject is)\s+([a-z\s]{3,30})(?:\.|$)/i);
    if (interestMatch) {
      const subj = interestMatch[1].trim();
      extracted.push({
        text: `Student has an active interest in ${subj}.`,
        category: 'subject_interest',
        importance: 0.7,
      });
    }

    if (extracted.length === 0) {
      return { shouldRemember: false, memories: [] };
    }

    return {
      shouldRemember: true,
      memories: extracted,
    };
  }

  /**
   * Generates or updates a compact rolling summary for conversations with > 8 messages.
   * Keeps context bounded so token limits are never exceeded.
   */
  public static updateRollingSummary(
    messages: Array<{ role: string; content: string }>,
    existingSummary?: string | null
  ): string {
    if (!messages || messages.length <= 6) {
      return existingSummary || '';
    }

    // Messages that need to be summarized (all except the last 4 recent messages)
    const olderMessages = messages.slice(0, messages.length - 4);
    const topics: Set<string> = new Set();

    for (const msg of olderMessages) {
      if (msg.role !== 'user') continue;
      const lower = msg.content.toLowerCase();
      // Extract key academic concepts discussed
      const matches = lower.match(/\b(avl tree|linked list|binary search tree|stack|queue|graph|sorting|java|c programming|inheritance|polymorphism|recursion|database|sql|bvc|syllabus|attendance|br23|regulation|exam|placement)\b/gi);
      if (matches) {
        matches.forEach((m) => topics.add(m.toLowerCase()));
      }
    }

    const topicList = Array.from(topics);
    if (topicList.length === 0) {
      return existingSummary || 'The student previously discussed foundational concepts and questions.';
    }

    return `The student previously discussed and reviewed concepts including: ${topicList.slice(0, 5).join(', ')}.`;
  }
}
