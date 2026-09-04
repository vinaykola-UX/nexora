/**
 * ============================================================================
 * BVC Nexora Phase 5A — Invisible Intent Detector
 * ============================================================================
 * 
 * Lightweight, deterministic intent classifier supporting natural student interactions:
 * - GREETING
 * - CASUAL
 * - SMALL_TALK
 * - ACADEMIC
 * - EXAM_PREP
 * - COLLEGE_INFO
 * - PROGRAMMING
 * - CODE_EXPLANATION
 * - QUIZ
 * - SUMMARY
 * - STUDY_NOTES
 * - STRESSED_STUDENT
 * - UNKNOWN
 * 
 * RULES:
 * - Deterministic & fast (sub-millisecond, no extra LLM call).
 * - Inspects message keywords, patterns, and conversation context.
 * - Stress signals take immediate precedence (safety & student well-being first).
 * - Personality decisions remain strictly internal and invisible.
 * ============================================================================
 */

export type ExtendedUserIntent =
  | 'DOCUMENT_SEARCH'
  | 'GREETING'
  | 'CASUAL'
  | 'SMALL_TALK'
  | 'ACADEMIC'
  | 'EXAM_PREP'
  | 'COLLEGE_INFO'
  | 'PROGRAMMING'
  | 'CODE_EXPLANATION'
  | 'QUIZ'
  | 'SUMMARY'
  | 'STUDY_NOTES'
  | 'STRESSED_STUDENT'
  | 'UNKNOWN';

export interface IntentDetectionResult {
  intent: ExtendedUserIntent;
  confidence: number;
  signals: string[];
  wantsExplanation?: boolean;
}

export class IntentDetector {
  private static instance: IntentDetector | null = null;

  public static getInstance(): IntentDetector {
    if (!IntentDetector.instance) {
      IntentDetector.instance = new IntentDetector();
    }
    return IntentDetector.instance;
  }

  /**
   * Primary classification method combining message signals and conversation context
   */
  public detect(
    message: string,
    conversation: Array<{ role: string; content: string }> = [],
    webAccessEnabled = false
  ): IntentDetectionResult {
    const raw = message.trim();
    const q = raw.toLowerCase();
    const cleanWord = q.replace(/[^\w\s]/g, '').trim();
    const signals: string[] = [];

    // 1. STRESSED STUDENT DETECTION (Highest priority — safety & empathy rule)
    const stressPatterns = [
      /\b(screwed|fucked|failing|failed|fail\b|gonna fail|going to fail|think i.?ll fail|think i will fail)\b/i,
      /\b(know nothing|don.?t know anything|dont know anything|haven't studied|havent studied|didn't study|didnt study|zero preparation|no preparation)\b/i,
      /\b(scared|panicking|panic\b|freaking out|crying|anxious|anxiety|hopeless|depressed|overwhelmed)\b/i,
      /\b(give up|giving up|ruined|save me|lost all hope|can't do this|cant do this|nothing to do now)\b/i,
      /\b(suicide|kill myself|end it all)\b/i, // Critical safety check
      /\b(really stressed|so stressed|very stressed|totally lost|completely lost)\b/i,
    ];

    for (const pattern of stressPatterns) {
      if (pattern.test(q)) {
        signals.push('stress_marker_detected');
        return { intent: 'STRESSED_STUDENT', confidence: 0.95, signals };
      }
    }

    // 1.5 DOCUMENT & PDF RETRIEVAL DETECTION (Authoritative BVC Document Delivery)
    // Matches student requests for original college PDFs, notes, syllabi, regulations, handouts, etc.
    const docKeywords = [
      'pdf', 'document', 'documents', 'syllabus', 'regulation', 'regulations',
      'question paper', 'question papers', 'lecture notes', 'unit notes', 'unit material',
      'study material', 'handout', 'handouts', 'curriculum', 'course copy',
    ];

    const docActionPhrases = [
      /\b(give me|send me|show me|get me|provide|share|download|open|view|find|need)\b.*\b(pdf|document|notes|syllabus|material|regulation|handout|paper)\b/i,
      /\b(can (i|you) (get|have|give|download|see|find))\b.*\b(pdf|document|notes|syllabus|material)\b/i,
      /\b(where (is|can i find))\b.*\b(pdf|document|notes|syllabus|material)\b/i,
      /\b(original (pdf|document|file)|official (pdf|document)|verified document)\b/i,
      /\b(download\s+[a-z0-9\s_-]+)\b/i,
      /\b([a-z0-9\s_-]+\s+(pdf|syllabus|notes|handout))\b/i,
    ];

    // Check if query is asking for a document
    const hasDocKeyword = docKeywords.some((kw) => {
      const regex = new RegExp(`\\b${kw}\\b`, 'i');
      return regex.test(q);
    });

    const matchesDocAction = docActionPhrases.some((pattern) => pattern.test(q));

    // Special check: pure unit notes / syllabus queries like "ADS Unit 2 PDF", "Send Java notes", "BVC syllabus"
    const isDocRequest = hasDocKeyword || matchesDocAction;

    if (isDocRequest) {
      signals.push('document_search_pattern');

      // Check if student ALSO wants an explanation (MODE C: Document + Explanation)
      const wantsExplanation =
        /\b(and explain|explain it|explain this|explain the|explain important|explain|tell me\b.*(topic|concept|important|about)|important topics|important questions|key topics|summarize|give summary|teach me|overview)\b/i.test(q);

      return {
        intent: 'DOCUMENT_SEARCH',
        confidence: 0.95,
        signals,
        wantsExplanation,
      };
    }

    // 2. EXAM PREP DETECTION (Urgent study/prep inquiries)
    const examPrepPatterns = [
      /\b(exam tomorrow|test tomorrow|mid tomorrow|mids tomorrow|exam today|test today)\b/i,
      /\b(exam in \d+|exam next week|finals coming|mid terms|internals coming)\b/i,
      /\b(what to study|what should i study|how to prepare|how to pass|important questions|frequently asked)\b/i,
      /\b(last minute prep|passing marks|important topics for exam|exam tips)\b/i,
      /\b(only \d+ hours?(left| to study| for exam| remaining)?)\b/i, // "only 2 hours left"
      /\b(bro exam|yaar exam|boss exam|sir exam)\b/i, // casual Indian exam urgency
    ];

    for (const pattern of examPrepPatterns) {
      if (pattern.test(q)) {
        signals.push('exam_prep_marker_detected');
        return { intent: 'EXAM_PREP', confidence: 0.9, signals };
      }
    }

    // 3. PROGRAMMING & CODE DETECTION
    const programmingPatterns = [
      /\b(write|create|implement|give|show|generate)\b.*\b(program|code|class|method|function|algorithm)\b/i,
      /\b(program|code|implementation|class)\b.*\b(for|to|of|in java|in c|in python)\b/i,
      /\b(source code|java code|python code|c\+\+ code)\b/i,
      /\b(write a program|write code|code for|implement in java)\b/i,
    ];

    for (const pattern of programmingPatterns) {
      if (pattern.test(q)) {
        signals.push('programming_pattern');
        return { intent: 'PROGRAMMING', confidence: 0.9, signals };
      }
    }

    if (
      q.includes('explain the code') ||
      q.includes('explain this program') ||
      q.includes('how does this code work') ||
      q.includes('trace the code') ||
      q.includes('line by line explanation')
    ) {
      signals.push('code_explanation_keyword');
      return { intent: 'CODE_EXPLANATION', confidence: 0.9, signals };
    }

    // 4. QUIZ, SUMMARY, STUDY NOTES
    if (q.includes('quiz') || q.includes('mcq') || q.includes('test me') || q.includes('practice questions')) {
      signals.push('quiz_keyword');
      return { intent: 'QUIZ', confidence: 0.9, signals };
    }

    // Quiz reply detection: if prior assistant turn had MCQ content and student is answering
    const isAnsweringQuiz = /^(answer is|my answer is|i think it.?s|option|choice)\s*[a-d]\b/i.test(q) ||
      /^[a-d]\s*[.\)]?\s*$/i.test(cleanWord);
    if (isAnsweringQuiz && conversation && conversation.length > 0) {
      const lastAssistant = [...conversation].reverse().find((m) => m.role === 'assistant')?.content || '';
      if (/\bA\).*\bB\).*\bC\)/s.test(lastAssistant) || lastAssistant.toLowerCase().includes('correct answer')) {
        signals.push('quiz_reply_detected');
        return { intent: 'QUIZ', confidence: 0.9, signals };
      }
    }

    if (
      q.includes('summarize') ||
      q.includes('summary of') ||
      q.includes('brief overview') ||
      q.includes('key takeaways') ||
      q.includes('in short')
    ) {
      signals.push('summary_keyword');
      return { intent: 'SUMMARY', confidence: 0.9, signals };
    }

    if (
      q.includes('notes') ||
      q.includes('revision notes') ||
      q.includes('study material') ||
      q.includes('cheat sheet') ||
      q.includes('quick revision')
    ) {
      signals.push('study_notes_keyword');
      return { intent: 'STUDY_NOTES', confidence: 0.9, signals };
    }

    // 5. COLLEGE / CAMPUS INFO
    const collegeInfoPatterns = [
      /\b(when are .*exams?|when is .*exams?)\b/i,
      /\b(dates? of (the)? .*exams?)\b/i,
      /\b(exam dates?|exam schedule|exam timetable|time table)\b/i,
      /\b(fee dates?|last date for fee|college fee|circular|notification)\b/i,
      /\b(bvcec|bvc|autonomous|hall ticket|attendance percentage|condonation|bus routes?)\b/i,
      /\b(principal|hod|faculty|holidays?|reopening date|college timings?)\b/i,
      /\b(mid exams?|semester exams?|supply exams?)\b/i,
    ];

    for (const pattern of collegeInfoPatterns) {
      if (pattern.test(q)) {
        signals.push('college_info_keyword');
        return { intent: 'COLLEGE_INFO', confidence: 0.85, signals };
      }
    }

    // 6. GREETINGS (Short, polite, opening phrases)
    const greetingMatches = [
      'hi', 'hello', 'hey', 'hey there', 'hi nexora', 'hello nexora', 'hey nexora',
      'good morning', 'good afternoon', 'good evening', 'yo', 'sup', 'howdy', 'namaste',
    ];
    // Exact or punctuated match ("hi!", "hello...", "hey bro")
    if (greetingMatches.includes(cleanWord) || /^(hi|hello|hey|yo|sup)\b/i.test(q) && q.split(/\s+/).length <= 3) {
      signals.push('greeting_match');
      return { intent: 'GREETING', confidence: 0.95, signals };
    }

    // 7. SMALL TALK & EMOJI REACTIONS
    // Pure emoji or short reactions like 😂, lol, haha, thanks, thanks bro, ok, cool
    const isEmojiOnly = raw.length > 0 && !/\w/.test(raw) && /[^\x00-\x7F]/.test(raw);
    const smallTalkPattern = /^(thanks|thank you|thx|cool|nice|ok|okay|lol|haha|lmao|great|awesome|got it|understood)(\s+(bro|nexora|sir|man|boss|dear))?[.!]?$/i;
    const smallTalkWords = ['😂', '🤣', 'lol', 'haha', 'lmao', 'nice', 'cool', 'thanks', 'thank you', 'ok', 'okay', 'cool bro', 'ok bro', 'k', 'great', 'awesome', 'good job', 'thanks bro', 'thx bro'];
    if (isEmojiOnly || smallTalkWords.includes(cleanWord) || smallTalkPattern.test(cleanWord)) {
      signals.push('small_talk_match');
      return { intent: 'SMALL_TALK', confidence: 0.9, signals };
    }

    // 8. CASUAL CONVERSATION (About Nexora, state, general banter)
    const casualPatterns = [
      /\b(what are you doing|what r u doing|what are u doing|what's up|whats up|wassup)\b/i,
      /\b(who are you|who r u|tell me about yourself|what can you do|are you a bot|are you ai|are you human)\b/i,
      /\b(what is your name|what.?s your name|who made you|who created you|who built you|what are you)\b/i,
      /\b(how are you|how r u|how are things|are you tired|are you awake|how.?s it going)\b/i,
      /\b(tell me a joke|bored|entertain me|roast me|sing a song)\b/i,
    ];

    for (const pattern of casualPatterns) {
      if (pattern.test(q)) {
        signals.push('casual_pattern');
        return { intent: 'CASUAL', confidence: 0.85, signals };
      }
    }

    // 9. ACADEMIC EXPLANATION / CONCEPT INQUIRY
    const academicIndicators = [
      'what is', 'what are', 'define', 'explain', 'how does', 'difference between',
      'working of', 'architecture of', 'types of', 'properties of', 'applications of',
      'advantages of', 'disadvantages of', 'complexity of', 'operations on',
    ];

    if (academicIndicators.some((ind) => q.includes(ind))) {
      signals.push('academic_indicator');
      return { intent: 'ACADEMIC', confidence: 0.85, signals };
    }

    // 10. Check conversation context if message is very short or ambiguous
    if (conversation && conversation.length > 0) {
      const lastUserMsg = [...conversation].reverse().find((m) => m.role === 'user')?.content?.toLowerCase() || '';
      if (lastUserMsg.includes('exam') || lastUserMsg.includes('test')) {
        signals.push('conversation_context_exam');
        return { intent: 'EXAM_PREP', confidence: 0.7, signals };
      }
    }

    // 11. Fallback heuristic: If question has academic length and structure, treat as ACADEMIC, else UNKNOWN
    if (q.split(/\s+/).length >= 3 && !q.includes('?')) {
      signals.push('implicit_academic');
      return { intent: 'ACADEMIC', confidence: 0.6, signals };
    }

    return { intent: 'UNKNOWN', confidence: 0.5, signals: ['ambiguous_input'] };
  }
}
