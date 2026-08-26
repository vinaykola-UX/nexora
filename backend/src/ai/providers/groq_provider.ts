import { AIProvider, GeneratedAnswer, GenerateParams } from '../ai_provider';

/**
 * Groq Provider Implementation (Ultra-fast Llama 3.3 / 3.1 inference)
 */
export class GroqProvider implements AIProvider {
  readonly name = 'groq';
  readonly defaultModel = 'llama-3.3-70b-versatile';

  async generateAnswer(params: GenerateParams): Promise<GeneratedAnswer> {
    const { question, officialContext, systemPrompt, apiKey } = params;
    const model = params.model || this.defaultModel;

    if (!apiKey || apiKey.trim().length === 0) {
      throw new Error('GROQ_API_KEY is not configured on the Cloudflare Worker.');
    }

    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 12000);

    try {
      const response = await fetch('https://api.groq.com/openai/v1/chat/completions', {
        method: 'POST',
        signal: controller.signal,
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${apiKey.trim()}`,
        },
        body: JSON.stringify({
          model,
          messages: [
            { role: 'system', content: systemPrompt },
            {
              role: 'user',
              content: `OFFICIAL BVC CONTEXT:\n${officialContext}\n\nSTUDENT QUESTION:\n${question}`,
            },
          ],
          temperature: 0.2,
          max_tokens: 1024,
        }),
      });

      clearTimeout(timeoutId);

      if (!response.ok) {
        const errorBody = await response.text();
        console.error(`[GroqProvider] API Error (${response.status}):`, errorBody);
        throw new Error(`Groq API returned status ${response.status}`);
      }

      const data = (await response.json()) as any;
      const content = data?.choices?.[0]?.message?.content;

      if (!content || typeof content !== 'string') {
        throw new Error('Empty or invalid response from Groq API.');
      }

      return {
        answer: content.trim(),
        model,
        provider: this.name,
      };
    } catch (err: any) {
      clearTimeout(timeoutId);
      if (err.name === 'AbortError') {
        throw new Error('Groq API call timed out.');
      }
      throw err;
    }
  }
}
