import { AIProvider, GeneratedAnswer, GenerateParams } from '../ai_provider';

/**
 * Google Gemini Provider Implementation
 * Supports Gemini 1.5 Flash / Gemini 2.0 Flash with system instructions and strict grounding.
 */
export class GeminiProvider implements AIProvider {
  readonly name = 'gemini';
  readonly defaultModel = 'gemini-1.5-flash';

  async generateAnswer(params: GenerateParams): Promise<GeneratedAnswer> {
    const { question, officialContext, systemPrompt, apiKey } = params;
    const model = params.model || this.defaultModel;

    if (!apiKey || apiKey.trim().length === 0) {
      throw new Error('GEMINI_API_KEY is not configured on the Cloudflare Worker.');
    }

    const endpoint = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${encodeURIComponent(
      apiKey.trim()
    )}`;

    const userPrompt = `OFFICIAL BVC CONTEXT:
${officialContext}

STUDENT QUESTION:
${question}

Provide a concise, clear, and accurately grounded answer using strictly the official BVC context provided above.`;

    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 12000);

    try {
      const response = await fetch(endpoint, {
        method: 'POST',
        signal: controller.signal,
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          system_instruction: {
            parts: [{ text: systemPrompt }],
          },
          contents: [
            {
              role: 'user',
              parts: [{ text: userPrompt }],
            },
          ],
          generationConfig: {
            temperature: 0.2, // Low temperature for high factual precision and grounding
            maxOutputTokens: 1024,
          },
        }),
      });

      clearTimeout(timeoutId);

      if (!response.ok) {
        const errorBody = await response.text();
        console.error(`[GeminiProvider] API Error (${response.status}):`, errorBody);
        throw new Error(`Gemini API returned status ${response.status}`);
      }

      const data = (await response.json()) as any;
      const candidate = data?.candidates?.[0];
      const text = candidate?.content?.parts?.[0]?.text;

      if (!text || typeof text !== 'string' || text.trim().length === 0) {
        throw new Error('Empty or invalid response from Gemini API.');
      }

      return {
        answer: text.trim(),
        model,
        provider: this.name,
      };
    } catch (err: any) {
      clearTimeout(timeoutId);
      if (err.name === 'AbortError') {
        throw new Error('Gemini API call timed out.');
      }
      throw err;
    }
  }
}
