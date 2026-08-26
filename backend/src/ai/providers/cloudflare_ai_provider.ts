import { AIProvider, GeneratedAnswer, GenerateParams } from '../ai_provider';

/**
 * Cloudflare Workers AI Native Provider
 * Uses Cloudflare edge GPU model binding (e.g. @cf/meta/llama-3.1-8b-instruct)
 */
export class CloudflareAIProvider implements AIProvider {
  readonly name = 'cloudflare-ai';
  readonly defaultModel = '@cf/meta/llama-3.1-8b-instruct';

  async generateAnswer(params: GenerateParams): Promise<GeneratedAnswer> {
    const { question, officialContext, systemPrompt, aiBinding } = params;
    const model = params.model || this.defaultModel;

    if (!aiBinding || typeof aiBinding.run !== 'function') {
      throw new Error('Cloudflare Workers AI binding (env.AI) is not configured.');
    }

    try {
      const response = await aiBinding.run(model, {
        messages: [
          { role: 'system', content: systemPrompt },
          {
            role: 'user',
            content: `OFFICIAL BVC CONTEXT:\n${officialContext}\n\nSTUDENT QUESTION:\n${question}`,
          },
        ],
        temperature: 0.2,
        max_tokens: 1024,
      });

      const text = response?.response;
      if (!text || typeof text !== 'string') {
        throw new Error('Empty or invalid response from Cloudflare Workers AI.');
      }

      return {
        answer: text.trim(),
        model,
        provider: this.name,
      };
    } catch (err: any) {
      console.error('[CloudflareAIProvider] Execution Error:', err);
      throw err;
    }
  }
}
