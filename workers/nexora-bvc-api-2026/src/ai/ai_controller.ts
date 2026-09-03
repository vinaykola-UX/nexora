/**
 * ============================================================================
 * BVC Nexora AI Intelligence Layer — Controlled AI Controller & Tone Engine
 * Phase 5A: Personality Foundation + Invisible Intent/Tone Engine
 * ============================================================================
 * 
 * ARCHITECTURE:
 * Student Message
 *     ↓
 * Conversation Context
 *     ↓
 * Intent Classification (IntentDetector)
 *     ↓
 * Personality Policy (PersonalityPolicyEngine)
 *     ↓
 * Allowed Tool Selection
 *     ↓
 * Existing ADS Search Pipeline (Hash, AVL, Graph, Max-Heap, Merge Sort)
 *     ↓
 * Grounded D1 Knowledge Context
 *     ↓
 * Workers AI Model (Llama 3.2 3B with Candidate Fallbacks)
 *     ↓
 * Response Validation & Code Line Limit Enforcement
 *     ↓
 * Natural, Grounded Nexora Response
 * 
 * INVISIBLE PERSONALITY RULES:
 * 1. The student should NEVER see internal mode names or personality decisions.
 * 2. Academic grounding is the highest priority.
 * 3. NO ROASTING, NO MOCKING, NO SARCASM for stressed students.
 * 4. Never invent college dates, circulars, or policies.
 * 5. No fake human emotions ("I missed you", "I have feelings").
 * ============================================================================
 */

import { ADSSearchPipeline, RankedChunk } from '../ads/pipeline';
import { IntentDetector, ExtendedUserIntent } from './intent_detector';
import { PersonalityPolicyEngine, PersonalityPolicy } from './personality_policy';

export const AI_LIMITS = {
  MAX_TOOL_CALLS: 3,
  MAX_RETRIEVED_CHUNKS: 8,
  MAX_RESPONSE_TOKENS: 1000,
  MAX_CODE_LINES_DEFAULT: 50,
  MAX_CODE_LINES_HARD: 100,
  MAX_WEB_SEARCHES: 1,
  DEFAULT_MODEL: '@cf/meta/llama-3.2-3b-instruct',
};

export type AIToolType =
  | 'knowledge_search'
  | 'explain'
  | 'code_generator'
  | 'code_explainer'
  | 'summarizer'
  | 'quiz_generator'
  | 'study_notes'
  | 'web_search';

export type UserIntent = ExtendedUserIntent | 'GENERAL_ACADEMIC' | 'EXPLAIN' | 'CODE_GENERATION' | 'CODE_EXPLANATION' | 'SUMMARIZE' | 'WEB_SEARCH';

export interface ChatSource {
  title: string;
  subject: string;
  unit: number;
  topic?: string;
  source?: string;
  page_info?: string;
}

export interface ChatResponse {
  answer: string;
  tool: AIToolType;
  sources: ChatSource[];
  debug?: {
    detectedIntent: UserIntent;
    selectedTool: AIToolType;
    allowedTools: AIToolType[];
    retrievedChunkCount: number;
    model: string;
    codeLineCount: number;
    generationStatus: string;
    personality?: {
      tone: string;
      humorLevel: string;
      teasingLevel: string;
      academicPriority: string;
      supportive: boolean;
    };
    timingsMs: {
      intentDetection: number;
      adsRetrieval: number;
      aiGeneration: number;
      total: number;
    };
    adsPipelineStatus: string;
  };
}

export class AIController {
  private static instance: AIController | null = null;
  private readonly intentDetector = IntentDetector.getInstance();
  private readonly personalityEngine = PersonalityPolicyEngine.getInstance();

  public static getInstance(): AIController {
    if (!AIController.instance) {
      AIController.instance = new AIController();
    }
    return AIController.instance;
  }

  /**
   * Classify user question intent using the lightweight deterministic detector
   */
  public detectIntent(
    question: string,
    conversation: Array<{ role: string; content: string }> = [],
    webAccessEnabled = false
  ): UserIntent {
    return this.intentDetector.detect(question, conversation, webAccessEnabled).intent;
  }

  /**
   * Tool Permission Matrix: Resolves allowed tools for a given intent
   */
  public getAllowedTools(intent: UserIntent, webAccessEnabled = false): AIToolType[] {
    switch (intent) {
      case 'PROGRAMMING':
      case 'CODE_GENERATION':
        return ['knowledge_search', 'code_generator', 'code_explainer'];
      case 'CODE_EXPLANATION':
        return ['knowledge_search', 'code_explainer'];
      case 'QUIZ':
        return ['knowledge_search', 'quiz_generator'];
      case 'SUMMARY':
      case 'SUMMARIZE':
        return ['knowledge_search', 'summarizer'];
      case 'STUDY_NOTES':
        return ['knowledge_search', 'study_notes'];
      case 'COLLEGE_INFO':
        return webAccessEnabled ? ['knowledge_search', 'web_search'] : ['knowledge_search', 'explain'];
      case 'WEB_SEARCH':
        return webAccessEnabled ? ['knowledge_search', 'web_search'] : ['knowledge_search', 'explain'];
      case 'GREETING':
      case 'CASUAL':
      case 'SMALL_TALK':
      case 'STRESSED_STUDENT':
      case 'EXAM_PREP':
      case 'ACADEMIC':
      case 'EXPLAIN':
      case 'GENERAL_ACADEMIC':
      case 'UNKNOWN':
      default:
        return ['knowledge_search', 'explain', 'study_notes'];
    }
  }

  /**
   * Selects the primary tool to execute based on intent and allowed tools
   */
  public selectPrimaryTool(intent: UserIntent, allowedTools: AIToolType[]): AIToolType {
    if ((intent === 'PROGRAMMING' || intent === 'CODE_GENERATION') && allowedTools.includes('code_generator')) {
      return 'code_generator';
    }
    if (intent === 'CODE_EXPLANATION' && allowedTools.includes('code_explainer')) {
      return 'code_explainer';
    }
    if (intent === 'QUIZ' && allowedTools.includes('quiz_generator')) {
      return 'quiz_generator';
    }
    if ((intent === 'SUMMARY' || intent === 'SUMMARIZE') && allowedTools.includes('summarizer')) {
      return 'summarizer';
    }
    if (intent === 'STUDY_NOTES' && allowedTools.includes('study_notes')) {
      return 'study_notes';
    }
    if ((intent === 'COLLEGE_INFO' || intent === 'WEB_SEARCH') && allowedTools.includes('web_search')) {
      return 'web_search';
    }
    if (allowedTools.includes('explain')) {
      return 'explain';
    }
    return 'knowledge_search';
  }

  /**
   * Constructs the grounded context string from retrieved ADS ranked chunks
   */
  public buildGroundedContext(chunks: RankedChunk[]): {
    contextText: string;
    sources: ChatSource[];
  } {
    const limitedChunks = chunks.slice(0, AI_LIMITS.MAX_RETRIEVED_CHUNKS);
    const sources: ChatSource[] = [];
    const contextLines: string[] = [];

    for (let i = 0; i < limitedChunks.length; i++) {
      const c = limitedChunks[i];

      // Extract metadata header fields if present
      let sourceName = 'BVC Academic Base';
      let pageInfo = 'Page N/A';
      let topic = '';

      const srcMatch = c.content.match(/SOURCE:\s*([^|\n]+)/i);
      if (srcMatch) sourceName = srcMatch[1].trim();

      const pageMatch = c.content.match(/PAGES?:\s*([^|\n]+)/i);
      if (pageMatch) pageInfo = pageMatch[1].trim();

      const topicMatch = c.content.match(/TOPIC:\s*([^|\n]+)/i);
      if (topicMatch) topic = topicMatch[1].trim();

      sources.push({
        title: c.title,
        subject: c.subject,
        unit: c.unit,
        topic: topic || undefined,
        source: sourceName,
        page_info: pageInfo,
      });

      contextLines.push(
        `[CHUNK #${i + 1} | ${c.subject} Unit ${c.unit} | Topic: ${topic || c.title} | Source: ${sourceName} (${pageInfo})]\n${c.content}`
      );
    }

    return {
      contextText: contextLines.join('\n\n'),
      sources,
    };
  }

  /**
   * Generates specialized prompt instructions based on the selected tool
   */
  private getToolInstruction(tool: AIToolType): string {
    switch (tool) {
      case 'code_generator':
        return `The student requested code. Provide a concise, clean implementation strictly under ${AI_LIMITS.MAX_CODE_LINES_DEFAULT} lines. Follow this format:\n1. Brief approach explanation (1-2 sentences)\n2. Complete, self-contained Code block (max ${AI_LIMITS.MAX_CODE_LINES_DEFAULT} lines)\n3. Time and Space complexity analysis. Never put jokes inside code.`;
      case 'code_explainer':
        return `Explain the code clearly, detailing what each class/method does and explaining its execution flow without unnecessary jokes.`;
      case 'quiz_generator':
        return `Generate 3 multiple-choice practice quiz questions (MCQs) based strictly on the provided context, including options A, B, C, D and the correct answer with brief explanation for each.`;
      case 'summarizer':
        return `Provide a concise 3-4 bullet point summary capturing the core concepts and definitions from the provided academic context.`;
      case 'study_notes':
        return `Format the answer as clean, structured revision notes with headings, key definitions, important formulas/principles, and exam tips based on the retrieved context.`;
      case 'web_search':
        return `Summarize the official portal notice accurately, clearly advising students to check the original link for official updates.`;
      case 'explain':
      case 'knowledge_search':
      default:
        return `Provide a clear, direct, and structured explanation answering the student's question based on the retrieved academic context.`;
    }
  }

  /**
   * Main controlled generation method incorporating Invisible Personality & Tone Policy
   */
  public async handleChat(params: {
    message: string;
    conversation?: Array<{ role: string; content: string }>;
    webAccessEnabled?: boolean;
    debug?: boolean;
    env: any;
    allChunks: any[];
  }): Promise<ChatResponse> {
    const tStart = performance.now();
    const { message, conversation = [], webAccessEnabled = false, debug = false, env, allChunks } = params;

    // 1. Intent Detection & Personality Policy Resolution
    const tIntentStart = performance.now();
    const detectedIntent = this.intentDetector.detect(message, conversation, webAccessEnabled).intent;
    const policy = this.personalityEngine.getPolicy(detectedIntent, conversation);
    const allowedTools = this.getAllowedTools(detectedIntent, webAccessEnabled);
    const selectedTool = this.selectPrimaryTool(detectedIntent, allowedTools);
    const tIntentEnd = performance.now();

    // 2. Candidate Retrieval via existing ADS Search Pipeline
    const tAdsStart = performance.now();
    let retrievedChunks: RankedChunk[] = [];
    let adsPipelineStatus = 'skipped_for_casual';

    // Only run intensive retrieval if grounding is required or the message has academic intent
    const needsRetrieval =
      policy.requiresGrounding ||
      detectedIntent === 'ACADEMIC' ||
      detectedIntent === 'EXAM_PREP' ||
      detectedIntent === 'PROGRAMMING' ||
      detectedIntent === 'CODE_EXPLANATION' ||
      detectedIntent === 'QUIZ' ||
      detectedIntent === 'SUMMARY' ||
      detectedIntent === 'STUDY_NOTES' ||
      detectedIntent === 'COLLEGE_INFO';

    if (needsRetrieval && allChunks && allChunks.length > 0) {
      const pipeline = ADSSearchPipeline.getInstance();
      pipeline.buildIndex(allChunks);
      const adsSearchResult = pipeline.search(message, AI_LIMITS.MAX_RETRIEVED_CHUNKS, debug);
      retrievedChunks = adsSearchResult.results;
      adsPipelineStatus = 'executed';
    }
    const tAdsEnd = performance.now();

    // 3. Grounded Context Construction
    const { contextText, sources } = this.buildGroundedContext(retrievedChunks);
    const hasContext = contextText.length > 0 && retrievedChunks.length > 0;

    // 4. Grounding Validation & Strict Fallback Handling
    // If a college info inquiry was made but no verified circulars/dates exist:
    if (detectedIntent === 'COLLEGE_INFO' && !hasContext) {
      return {
        answer:
          "I don't have the verified schedule or official notification for that in the Nexora database yet. Please check the official BVC Engineering College noticeboard or website (bvcec.edu.in) for confirmed dates and circulars.",
        tool: selectedTool,
        sources: [],
        debug: debug
          ? {
              detectedIntent,
              selectedTool,
              allowedTools,
              retrievedChunkCount: 0,
              model: env.AI_MODEL || AI_LIMITS.DEFAULT_MODEL,
              codeLineCount: 0,
              generationStatus: 'unverified_college_info',
              personality: {
                tone: policy.tone,
                humorLevel: policy.humorLevel,
                teasingLevel: policy.teasingLevel,
                academicPriority: policy.academicPriority,
                supportive: policy.supportive,
              },
              timingsMs: {
                intentDetection: Math.round((tIntentEnd - tIntentStart) * 100) / 100,
                adsRetrieval: Math.round((tAdsEnd - tAdsStart) * 100) / 100,
                aiGeneration: 0,
                total: Math.round((performance.now() - tStart) * 100) / 100,
              },
              adsPipelineStatus: 'zero_matches',
            }
          : undefined,
      };
    }

    // 5. Construct Invisible System Instruction
    const toolInstruction = this.getToolInstruction(selectedTool);
    const systemInstruction = this.personalityEngine.buildSystemInstruction(policy, toolInstruction, hasContext);

    // Multi-turn message history integration (last 4 turns for context awareness)
    const recentMessages = (conversation || [])
      .slice(-4)
      .filter((m) => m && m.role && m.content)
      .map((m) => ({
        role: m.role === 'assistant' ? 'assistant' : 'user',
        content: String(m.content).slice(0, 500),
      }));

    // Current turn user prompt
    const currentUserPrompt = hasContext
      ? `VERIFIED ACADEMIC CONTEXT:\n${contextText}\n\nSTUDENT QUESTION:\n${message}`
      : `STUDENT QUESTION:\n${message}\n(Provide a precise, comprehensive, and accurate academic explanation based on standard computer science / engineering principles.)`;

    const candidateModels = [
      env.AI_MODEL,
      '@cf/meta/llama-3.2-3b-instruct',
      '@cf/meta/llama-3.2-1b-instruct',
      '@cf/meta/llama-3-8b-instruct',
      '@cf/mistral/mistral-7b-instruct-v0.2',
      '@cf/qwen/qwen1.5-7b-chat',
    ].filter(Boolean) as string[];

    let activeModel = candidateModels[0] || '@cf/meta/llama-3.2-3b-instruct';
    let generatedText = '';
    const tAiStart = performance.now();
    let aiErrorMessage = '';

    // 6. Workers AI Invocation with candidate model fallback
    if (env.AI && typeof env.AI.run === 'function') {
      for (const candidate of candidateModels) {
        try {
          const response = await env.AI.run(candidate, {
            messages: [
              { role: 'system', content: systemInstruction },
              ...recentMessages,
              { role: 'user', content: currentUserPrompt },
            ],
            temperature: policy.humorLevel === 'moderate' ? 0.4 : 0.2,
            max_tokens: AI_LIMITS.MAX_RESPONSE_TOKENS,
          });

          if (response?.response && typeof response.response === 'string' && response.response.trim().length > 0) {
            generatedText = response.response.trim();
            activeModel = candidate;
            aiErrorMessage = '';
            break;
          }
        } catch (aiErr: any) {
          aiErrorMessage = aiErr?.message || String(aiErr);
          console.warn(`[AIController] Model ${candidate} returned:`, aiErrorMessage);
        }
      }
    }

    // 7. Deterministic Fallback if Workers AI is offline or unreachable
    if (!generatedText) {
      if (detectedIntent === 'GREETING') {
        generatedText = policy.suggestedOpeningPhrases?.[0] || 'Hey! What subject are we tackling today?';
      } else if (detectedIntent === 'CASUAL') {
        generatedText = policy.suggestedOpeningPhrases?.[0] || 'Standing by to rescue your GPA. What are you working on?';
      } else if (detectedIntent === 'SMALL_TALK') {
        generatedText = policy.suggestedOpeningPhrases?.[0] || 'Glad one of us is having fun. Now, what are we actually studying?';
      } else if (detectedIntent === 'STRESSED_STUDENT') {
        generatedText =
          "Take a breath — you're not out of options yet. Tell me what subject and unit you have, and we will focus on the most important, high-scoring topics first.";
      } else if (hasContext) {
        const primaryChunk = retrievedChunks[0];
        const cleanContent = primaryChunk.content.replace(/^SUBJECT:[^\n]+\n\n/, '');

        if (selectedTool === 'code_generator') {
          generatedText = `Based on verified Nexora syllabus for ${primaryChunk.subject} (Unit ${primaryChunk.unit}):\n\n\`\`\`java\n${cleanContent}\n\`\`\`\n\n**Complexity Analysis:**\n- Time Complexity: O(1) for member access\n- Space Complexity: O(1) auxiliary stack space`;
        } else if (selectedTool === 'quiz_generator') {
          generatedText = `Practice Quiz on ${primaryChunk.subject} (Unit ${primaryChunk.unit}):\n\n1. What concept is highlighted in this unit?\n   A) Single Inheritance\n   B) Binary Search\n   C) Operator Overloading\n   D) Dynamic Scoping\n   *Correct Answer: A*`;
        } else if (selectedTool === 'study_notes') {
          generatedText = `### Revision Study Notes: ${primaryChunk.subject} (Unit ${primaryChunk.unit})\n\n**Topic:** ${primaryChunk.title}\n\n**Key Points:**\n- ${cleanContent.substring(0, 300)}...`;
        } else if (selectedTool === 'summarizer') {
          generatedText = `### Summary of ${primaryChunk.subject} (Unit ${primaryChunk.unit})\n- ${cleanContent.substring(0, 200)}...`;
        } else {
          generatedText = `Based on verified Nexora knowledge base for ${primaryChunk.subject} (Unit ${primaryChunk.unit}):\n\n${cleanContent}`;
        }
      } else {
        generatedText = "I'm here to help with your BVC Engineering studies. Ask me about your subjects, units, or code implementations.";
      }
    }
    const tAiEnd = performance.now();

    // 8. Sanitize Invisible Personality Violations (Post-processing guardrail)
    // Strip accidental mode announcement leaks if an LLM outputs them
    const sanitizedText = this.sanitizeModeAnnouncements(generatedText);

    // 9. Code Line Limit Enforcement (MAX_CODE_LINES_HARD = 100)
    let totalCodeLines = 0;
    const validatedText = this.enforceCodeLimits(sanitizedText, (lineCount) => {
      totalCodeLines = lineCount;
    });

    const totalEnd = performance.now();

    return {
      answer: validatedText.trim(),
      tool: selectedTool,
      sources,
      debug: debug
        ? {
            detectedIntent,
            selectedTool,
            allowedTools,
            retrievedChunkCount: retrievedChunks.length,
            model: activeModel,
            codeLineCount: totalCodeLines,
            generationStatus: aiErrorMessage ? `fallback: ${aiErrorMessage}` : 'workers_ai_success',
            personality: {
              tone: policy.tone,
              humorLevel: policy.humorLevel,
              teasingLevel: policy.teasingLevel,
              academicPriority: policy.academicPriority,
              supportive: policy.supportive,
            },
            timingsMs: {
              intentDetection: Math.round((tIntentEnd - tIntentStart) * 100) / 100,
              adsRetrieval: Math.round((tAdsEnd - tAdsStart) * 100) / 100,
              aiGeneration: Math.round((tAiEnd - tAiStart) * 100) / 100,
              total: Math.round((totalEnd - tStart) * 100) / 100,
            },
            adsPipelineStatus,
          }
        : undefined,
    };
  }

  /**
   * Post-processing guardrail: Removes any inadvertent internal mode announcements
   */
  private sanitizeModeAnnouncements(text: string): string {
    const forbiddenPatterns = [
      /^(I'm|I am) switching to (study|teacher|roast|casual) mode[.:!]?\s*/i,
      /^(Teacher|Study|Roast|Casual) mode (activated|enabled)[.:!]?\s*/i,
      /^(No roasting for this one|I'm being serious now)[.:!]?\s*/i,
      /^(Intent detected|Tone selected):[^\n]+\n*/i,
      /^(My personality mode is)[^\n]+\n*/i,
    ];

    let cleaned = text;
    for (const pattern of forbiddenPatterns) {
      cleaned = cleaned.replace(pattern, '');
    }
    return cleaned;
  }

  /**
   * Enforces strict code length limits on any code blocks in the generated response
   */
  private enforceCodeLimits(text: string, onCount?: (lines: number) => void): string {
    const codeBlockRegex = /```([a-zA-Z]*)\n([\s\S]*?)```/g;
    let totalCodeLines = 0;

    const processed = text.replace(codeBlockRegex, (match, lang, code) => {
      const lines = code.split('\n');
      totalCodeLines += lines.length;

      if (lines.length > AI_LIMITS.MAX_CODE_LINES_HARD) {
        const constrainedLines = lines.slice(0, AI_LIMITS.MAX_CODE_LINES_HARD);
        return `\`\`\`${lang}\n${constrainedLines.join('\n')}\n// [Constrained to ${AI_LIMITS.MAX_CODE_LINES_HARD} lines per Nexora safety limits]\n\`\`\``;
      }
      return match;
    });

    if (onCount) onCount(totalCodeLines);
    return processed;
  }
}
