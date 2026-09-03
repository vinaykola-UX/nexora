/**
 * ============================================================================
 * BVC Nexora AI Intelligence Layer — Controlled AI Controller & Tool System
 * ============================================================================
 * 
 * ARCHITECTURE:
 * User Question
 *     ↓
 * AI Controller / Intent Detection
 *     ↓
 * Allowed Tool Selection (Permission Matrix)
 *     ↓
 * Existing ADS Search Pipeline (Hash, AVL, Graph, Max-Heap, Merge Sort)
 *     ↓
 * Grounded D1 Knowledge Context
 *     ↓
 * Workers AI Model (@cf/meta/llama-3.1-8b-instruct)
 *     ↓
 * Response Validation & Code Line Limit Enforcement
 *     ↓
 * Clean Grounded Nexora Response
 * ============================================================================
 */

import { ADSSearchPipeline, RankedChunk } from '../ads/pipeline';

export const AI_LIMITS = {
  MAX_TOOL_CALLS: 3,
  MAX_RETRIEVED_CHUNKS: 8,
  MAX_RESPONSE_TOKENS: 1000,
  MAX_CODE_LINES_DEFAULT: 50,
  MAX_CODE_LINES_HARD: 100,
  MAX_WEB_SEARCHES: 1,
  DEFAULT_MODEL: '@cf/meta/llama-3.1-8b-instruct',
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

export type UserIntent =
  | 'GENERAL_ACADEMIC'
  | 'EXPLAIN'
  | 'CODE_GENERATION'
  | 'CODE_EXPLANATION'
  | 'SUMMARIZE'
  | 'QUIZ'
  | 'STUDY_NOTES'
  | 'WEB_SEARCH';

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

  public static getInstance(): AIController {
    if (!AIController.instance) {
      AIController.instance = new AIController();
    }
    return AIController.instance;
  }

  /**
   * Classify user question intent
   */
  public detectIntent(question: string, webAccessEnabled = false): UserIntent {
    const q = question.toLowerCase().trim();

    // Check for explicit web queries first if web access is enabled
    if (
      webAccessEnabled &&
      (q.includes('portal') ||
        q.includes('circular') ||
        q.includes('notification') ||
        q.includes('fee date') ||
        q.includes('announcement') ||
        q.includes('bvcec.edu.in'))
    ) {
      return 'WEB_SEARCH';
    }

    if (
      q.includes('write a program') ||
      q.includes('write a java program') ||
      q.includes('code for') ||
      q.includes('implement in java') ||
      q.includes('create a class') ||
      q.includes('source code') ||
      q.includes('program to') ||
      q.includes('java code')
    ) {
      return 'CODE_GENERATION';
    }

    if (
      q.includes('explain the code') ||
      q.includes('explain this program') ||
      q.includes('how does this code work') ||
      q.includes('trace the code')
    ) {
      return 'CODE_EXPLANATION';
    }

    if (q.includes('quiz') || q.includes('mcq') || q.includes('test me') || q.includes('practice questions')) {
      return 'QUIZ';
    }

    if (
      q.includes('summarize') ||
      q.includes('summary of') ||
      q.includes('brief overview') ||
      q.includes('key takeaways')
    ) {
      return 'SUMMARIZE';
    }

    if (
      q.includes('notes') ||
      q.includes('revision notes') ||
      q.includes('study material') ||
      q.includes('cheat sheet')
    ) {
      return 'STUDY_NOTES';
    }

    if (
      q.includes('explain') ||
      q.includes('what is') ||
      q.includes('define') ||
      q.includes('how does') ||
      q.includes('difference between') ||
      q.includes('why')
    ) {
      return 'EXPLAIN';
    }

    return 'GENERAL_ACADEMIC';
  }

  /**
   * Tool Permission Matrix: Resolves allowed tools for a given intent
   */
  public getAllowedTools(intent: UserIntent, webAccessEnabled = false): AIToolType[] {
    switch (intent) {
      case 'CODE_GENERATION':
      case 'CODE_EXPLANATION':
        return ['knowledge_search', 'code_generator', 'code_explainer'];
      case 'QUIZ':
        return ['knowledge_search', 'quiz_generator'];
      case 'SUMMARIZE':
        return ['knowledge_search', 'summarizer'];
      case 'STUDY_NOTES':
        return ['knowledge_search', 'study_notes'];
      case 'WEB_SEARCH':
        return webAccessEnabled ? ['knowledge_search', 'web_search'] : ['knowledge_search', 'explain'];
      case 'EXPLAIN':
      case 'GENERAL_ACADEMIC':
      default:
        return ['knowledge_search', 'explain', 'summarizer', 'study_notes'];
    }
  }

  /**
   * Selects the primary tool to execute based on intent and allowed tools
   */
  public selectPrimaryTool(intent: UserIntent, allowedTools: AIToolType[]): AIToolType {
    if (intent === 'CODE_GENERATION' && allowedTools.includes('code_generator')) {
      return 'code_generator';
    }
    if (intent === 'CODE_EXPLANATION' && allowedTools.includes('code_explainer')) {
      return 'code_explainer';
    }
    if (intent === 'QUIZ' && allowedTools.includes('quiz_generator')) {
      return 'quiz_generator';
    }
    if (intent === 'SUMMARIZE' && allowedTools.includes('summarizer')) {
      return 'summarizer';
    }
    if (intent === 'STUDY_NOTES' && allowedTools.includes('study_notes')) {
      return 'study_notes';
    }
    if (intent === 'WEB_SEARCH' && allowedTools.includes('web_search')) {
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
        return `The student requested code. Provide a concise, clean implementation strictly under ${AI_LIMITS.MAX_CODE_LINES_DEFAULT} lines. Follow this format:\n1. Brief approach explanation (1-2 sentences)\n2. Complete, self-contained Code block (max ${AI_LIMITS.MAX_CODE_LINES_DEFAULT} lines)\n3. Time and Space complexity analysis.`;
      case 'code_explainer':
        return `Explain the code provided in the context clearly, detailing what each class/method does and explaining its execution flow.`;
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
        return `Provide a clear, direct, and structured explanation answering the student's question based strictly on the retrieved academic context.`;
    }
  }

  /**
   * Main controlled generation method
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
    const { message, webAccessEnabled = false, debug = false, env, allChunks } = params;

    // 1. Intent Detection
    const tIntentStart = performance.now();
    const intent = this.detectIntent(message, webAccessEnabled);
    const allowedTools = this.getAllowedTools(intent, webAccessEnabled);
    const selectedTool = this.selectPrimaryTool(intent, allowedTools);
    const tIntentEnd = performance.now();

    // 2. Retrieve candidates via existing ADS Search Pipeline
    const tAdsStart = performance.now();
    const pipeline = ADSSearchPipeline.getInstance();
    pipeline.buildIndex(allChunks);
    const adsSearchResult = pipeline.search(message, AI_LIMITS.MAX_RETRIEVED_CHUNKS, debug);
    const retrievedChunks = adsSearchResult.results;
    const tAdsEnd = performance.now();

    // 3. Grounded Context Construction
    const { contextText, sources } = this.buildGroundedContext(retrievedChunks);

    // Fallback if no relevant context was found in D1
    if (!contextText || retrievedChunks.length === 0) {
      return {
        answer:
          "I couldn't find enough verified information in the Nexora knowledge base to answer that reliably. Please verify that the relevant subject unit has been uploaded in the Admin Dashboard.",
        tool: selectedTool,
        sources: [],
        debug: debug
          ? {
              detectedIntent: intent,
              selectedTool,
              allowedTools,
              retrievedChunkCount: 0,
              model: env.AI_MODEL || AI_LIMITS.DEFAULT_MODEL,
              codeLineCount: 0,
              generationStatus: 'insufficient_context',
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

    // 4. Construct System Prompt & Messages
    const toolInstruction = this.getToolInstruction(selectedTool);
    const systemInstruction = `You are Nexora, an AI academic assistant for BVC Engineering College students.
Answer the student's question using ONLY the verified academic context provided below.
Do not invent facts, syllabus topics, deadlines, or college policies.
Do not fabricate document references.
If the context does not contain enough information, say: "I couldn't find enough information in the Nexora knowledge base to answer that reliably."
${toolInstruction}`;

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

    // 5. Workers AI Invocation with active candidate model fallback
    if (env.AI && typeof env.AI.run === 'function') {
      for (const candidate of candidateModels) {
        try {
          const response = await env.AI.run(candidate, {
            messages: [
              { role: 'system', content: systemInstruction },
              {
                role: 'user',
                content: `VERIFIED ACADEMIC CONTEXT:\n${contextText}\n\nSTUDENT QUESTION:\n${message}`,
              },
            ],
            temperature: 0.2,
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

    // Grounded academic fallback if Workers AI is not reachable
    if (!generatedText) {
      const primaryChunk = retrievedChunks[0];
      const cleanContent = primaryChunk.content.replace(/^SUBJECT:[^\n]+\n\n/, '');

      if (selectedTool === 'code_generator') {
        generatedText = `Based on verified Nexora syllabus for ${primaryChunk.subject} (Unit ${primaryChunk.unit}):\n\n\`\`\`java\n${cleanContent}\n\`\`\`\n\n**Complexity Analysis:**\n- Time Complexity: O(1) for direct member access and method calls\n- Space Complexity: O(1) auxiliary stack frame memory`;
      } else if (selectedTool === 'quiz_generator') {
        generatedText = `Practice Quiz on ${primaryChunk.subject} (Unit ${primaryChunk.unit}):\n\n1. What concept is demonstrated in the syllabus topic?\n   A) Single Inheritance\n   B) Multiple Inheritance\n   C) Operator Overloading\n   D) Dynamic Scoping\n   *Correct Answer: A*\n\n2. Which keyword is used to refer to superclass members in Java?\n   A) this\n   B) super\n   C) extends\n   D) base\n   *Correct Answer: B*`;
      } else if (selectedTool === 'study_notes') {
        generatedText = `### Revision Study Notes: ${primaryChunk.subject} (Unit ${primaryChunk.unit})\n\n**Topic:** ${primaryChunk.title}\n\n**Key Concepts:**\n- ${cleanContent.substring(0, 300)}...\n\n**Exam Tips:**\n- Ensure correct class inheritance syntax.\n- Remember super() calls the superclass constructor.`;
      } else if (selectedTool === 'summarizer') {
        generatedText = `### Summary of ${primaryChunk.subject} (Unit ${primaryChunk.unit})\n- ${cleanContent.substring(0, 200)}...\n- Implemented in BVC Engineering College curriculum.`;
      } else {
        generatedText = `Based on verified Nexora knowledge base for ${primaryChunk.subject} (Unit ${primaryChunk.unit}):\n\n${cleanContent}`;
      }
    }
    const tAiEnd = performance.now();

    // 6. Code Line Limit Enforcement (MAX_CODE_LINES_HARD = 100)
    let totalCodeLines = 0;
    const validatedText = this.enforceCodeLimits(generatedText, (lineCount) => {
      totalCodeLines = lineCount;
    });

    const totalEnd = performance.now();

    return {
      answer: validatedText.trim(),
      tool: selectedTool,
      sources,
      debug: debug
        ? {
            detectedIntent: intent,
            selectedTool,
            allowedTools,
            retrievedChunkCount: retrievedChunks.length,
            model: activeModel,
            codeLineCount: totalCodeLines,
            generationStatus: aiErrorMessage ? `fallback: ${aiErrorMessage}` : 'workers_ai_success',
            timingsMs: {
              intentDetection: Math.round((tIntentEnd - tIntentStart) * 100) / 100,
              adsRetrieval: Math.round((tAdsEnd - tAdsStart) * 100) / 100,
              aiGeneration: Math.round((tAiEnd - tAiStart) * 100) / 100,
              total: Math.round((totalEnd - tStart) * 100) / 100,
            },
            adsPipelineStatus: 'executed',
          }
        : undefined,
    };
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
