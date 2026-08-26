/**
 * AI Provider Abstraction Interface for Nexora BVC AI Backend
 *
 * Designed to be completely provider-agnostic, allowing seamless swapping
 * between Google Gemini, Groq, OpenAI, Cloudflare Workers AI, Claude, etc.
 * without altering public API contracts or frontend Flutter code.
 */

export interface GeneratedAnswer {
  answer: string;
  model: string;
  provider: string;
}

export interface GenerateParams {
  question: string;
  officialContext: string;
  systemPrompt: string;
  apiKey?: string;
  model?: string;
  aiBinding?: any;
}

export interface AIProvider {
  readonly name: string;
  readonly defaultModel: string;

  generateAnswer(params: GenerateParams): Promise<GeneratedAnswer>;
}
