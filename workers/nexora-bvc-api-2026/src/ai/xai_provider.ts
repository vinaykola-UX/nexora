/**
 * ============================================================================
 * BVC Nexora AI — Phase 5C: xAI Grok LLM Provider
 * ============================================================================
 * 
 * Production LLM text-generation provider interfacing with xAI API (https://api.x.ai/v1).
 * 
 * KEY FEATURES:
 * 1. Default model: grok-4.20-0309-non-reasoning (configurable via XAI_MODEL env var)
 * 2. Controlled Dual-Key Failover:
 *    - Attempt 1: XAI_API_KEY_1
 *    - Attempt 2: XAI_API_KEY_2 (only on recoverable failure: 429, 5xx, 401/403, network error)
 *    - No simultaneous calls, no duplicate successful requests.
 * 3. Cost & Usage Tracking: captures tokens, duration, model, and cost_in_usd_ticks if provided.
 * 4. Safe Error Handling: never leaks API keys, authorization headers, or raw provider traces.
 * ============================================================================
 */

export const XAI_DEFAULTS = {
  BASE_URL: 'https://api.x.ai/v1',
  DEFAULT_MODEL: 'grok-4.20-0309-non-reasoning',
  MAX_TOKENS: 1000,
  REQUEST_TIMEOUT_MS: 15000,
};

export interface XAIMessage {
  role: 'system' | 'user' | 'assistant';
  content: string;
}

export interface XAIUsageInfo {
  promptTokens?: number;
  completionTokens?: number;
  totalTokens?: number;
  costInUsdTicks?: number;
}

export interface XAIGenerationResult {
  text: string;
  model: string;
  provider: 'xai' | 'fallback';
  attempt: number;
  statusCode: number;
  durationMs: number;
  usage?: XAIUsageInfo;
  error?: string;
}

export interface LLMProvider {
  generateChatCompletion(params: {
    messages: XAIMessage[];
    model?: string;
    temperature?: number;
    maxTokens?: number;
    apiKey1?: string;
    apiKey2?: string;
  }): Promise<XAIGenerationResult>;
}

export class XAIProvider implements LLMProvider {
  private static instance: XAIProvider | null = null;

  public static getInstance(): XAIProvider {
    if (!XAIProvider.instance) {
      XAIProvider.instance = new XAIProvider();
    }
    return XAIProvider.instance;
  }

  /**
   * Generates a chat completion with strict dual-key failover and usage tracking
   */
  public async generateChatCompletion(params: {
    messages: XAIMessage[];
    model?: string;
    temperature?: number;
    maxTokens?: number;
    apiKey1?: string;
    apiKey2?: string;
  }): Promise<XAIGenerationResult> {
    const {
      messages,
      model = XAI_DEFAULTS.DEFAULT_MODEL,
      temperature = 0.2,
      maxTokens = XAI_DEFAULTS.MAX_TOKENS,
      apiKey1,
      apiKey2,
    } = params;

    const keysToTry: Array<{ key: string; attemptNumber: number }> = [];
    if (apiKey1 && apiKey1.trim().length > 0) {
      keysToTry.push({ key: apiKey1.trim(), attemptNumber: 1 });
    }
    if (apiKey2 && apiKey2.trim().length > 0) {
      // Only add key 2 if distinct from key 1
      if (!apiKey1 || apiKey1.trim() !== apiKey2.trim()) {
        keysToTry.push({ key: apiKey2.trim(), attemptNumber: 2 });
      }
    }

    // If no xAI keys configured in environment
    if (keysToTry.length === 0) {
      return {
        text: '',
        model,
        provider: 'fallback',
        attempt: 0,
        statusCode: 0,
        durationMs: 0,
        error: 'No xAI API keys configured in environment.',
      };
    }

    const endpoint = `${XAI_DEFAULTS.BASE_URL}/chat/completions`;
    const requestPayload = {
      messages,
      model,
      temperature,
      max_tokens: maxTokens,
      stream: false,
    };

    let lastError = '';
    let lastStatusCode = 0;
    const overallStart = performance.now();

    for (let i = 0; i < keysToTry.length; i++) {
      const { key, attemptNumber } = keysToTry[i];
      const attemptStart = performance.now();

      try {
        const controller = new AbortController();
        const timeoutId = setTimeout(() => controller.abort(), XAI_DEFAULTS.REQUEST_TIMEOUT_MS);

        const response = await fetch(endpoint, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            Authorization: `Bearer ${key}`,
            'User-Agent': 'NexoraAI-Backend/2026',
          },
          body: JSON.stringify(requestPayload),
          signal: controller.signal,
        });

        clearTimeout(timeoutId);
        const durationMs = Math.round(performance.now() - attemptStart);
        lastStatusCode = response.status;

        if (response.ok) {
          const data: any = await response.json();
          const choice = data?.choices?.[0];
          const text = choice?.message?.content || '';

          if (text.trim().length > 0) {
            const usage = data?.usage;
            return {
              text: text.trim(),
              model: data?.model || model,
              provider: 'xai',
              attempt: attemptNumber,
              statusCode: response.status,
              durationMs,
              usage: usage
                ? {
                    promptTokens: usage.prompt_tokens,
                    completionTokens: usage.completion_tokens,
                    totalTokens: usage.total_tokens,
                    costInUsdTicks: usage.cost_in_usd_ticks,
                  }
                : undefined,
            };
          }
        }

        // Handle provider errors (HTTP non-200)
        let errorDetails = '';
        try {
          const errJson: any = await response.json();
          errorDetails = errJson?.error?.message || errJson?.message || JSON.stringify(errJson);
        } catch {
          errorDetails = await response.text().catch(() => '');
        }

        // Sanitize error: strip any accidental key echoes
        const sanitizedErr = this.sanitizeErrorMessage(errorDetails);
        lastError = `HTTP ${response.status}: ${sanitizedErr.slice(0, 200)}`;
        console.warn(`[XAIProvider] Key ${attemptNumber} failed with status ${response.status}`);

        // Check if error is recoverable and we have another key to try
        const isRecoverable =
          response.status === 429 || // Rate limited
          response.status === 401 || // Auth issue on key 1
          response.status === 403 || // Permission issue on key 1
          (response.status >= 500 && response.status < 600); // Temporary provider 5xx

        if (!isRecoverable && i === 0 && keysToTry.length > 1) {
          // If non-recoverable (e.g. 400 bad request), trying key 2 won't help unless key-related
          break;
        }
      } catch (fetchErr: any) {
        const durationMs = Math.round(performance.now() - attemptStart);
        const errMsg = fetchErr?.name === 'AbortError' ? 'Timeout (15s exceeded)' : fetchErr?.message || String(fetchErr);
        lastError = `Network/Timeout error on Key ${attemptNumber}: ${errMsg}`;
        console.warn(`[XAIProvider] Key ${attemptNumber} fetch exception:`, errMsg);
        // Transient network failure is recoverable: loop continues to key 2
      }
    }

    const totalDuration = Math.round(performance.now() - overallStart);
    return {
      text: '',
      model,
      provider: 'fallback',
      attempt: keysToTry.length,
      statusCode: lastStatusCode,
      durationMs: totalDuration,
      error: lastError || 'All xAI key attempts exhausted.',
    };
  }

  /**
   * Sanitizes error messages to ensure no sensitive bearer tokens or secrets leak
   */
  private sanitizeErrorMessage(msg: string): string {
    if (!msg) return '';
    return msg
      .replace(/Bearer\s+[A-Za-z0-9_\-\.]+/gi, 'Bearer [REDACTED]')
      .replace(/xai-[A-Za-z0-9_\-\.]+/gi, '[REDACTED_KEY]')
      .replace(/[a-zA-Z0-9]{32,}/g, '[REDACTED_HASH]');
  }
}
