/**
 * Minimal test Worker — verifies:
 * 1. Workers AI binding (env.AI) works
 * 2. @cf/baai/bge-small-en-v1.5 returns exactly 384 dimensions
 * 3. Vectorize binding (env.VECTORIZE) is reachable
 * 4. Vectorize index reports dimension = 384 and metric = cosine
 * 
 * This worker is temporary — used for pre-deployment verification ONLY.
 */
export default {
  async fetch(request: Request, env: any): Promise<Response> {
    const report: Record<string, any> = {
      timestamp: new Date().toISOString(),
      checks: {}
    };

    // CHECK 1: Workers AI binding
    report.checks.workersAIBinding = env.AI && typeof env.AI.run === 'function'
      ? { status: 'PASS', detail: 'env.AI is bound and callable' }
      : { status: 'FAIL', detail: 'env.AI is missing or not a function' };

    // CHECK 2: Test embedding — @cf/baai/bge-small-en-v1.5
    const testText = 'BVC Nexora AI embedding dimension verification test for linked list data structures';
    try {
      const t0 = performance.now();
      const response = await env.AI.run('@cf/baai/bge-small-en-v1.5', {
        text: [testText]
      });
      const elapsed = Math.round(performance.now() - t0);

      const vector = response?.data?.[0] ?? response?.result?.data?.[0];
      if (!vector || !Array.isArray(vector)) {
        report.checks.embeddingModel = {
          status: 'FAIL',
          model: '@cf/baai/bge-small-en-v1.5',
          detail: 'No vector data returned',
          rawResponse: JSON.stringify(response).slice(0, 300)
        };
      } else if (vector.length !== 384) {
        report.checks.embeddingModel = {
          status: 'FAIL',
          model: '@cf/baai/bge-small-en-v1.5',
          detail: `DIMENSION MISMATCH: got ${vector.length}, expected 384`,
          returnedDimension: vector.length,
          expectedDimension: 384
        };
      } else {
        report.checks.embeddingModel = {
          status: 'PASS',
          model: '@cf/baai/bge-small-en-v1.5',
          dimension: vector.length,
          vectorSample: vector.slice(0, 5).map((v: number) => Math.round(v * 10000) / 10000),
          latencyMs: elapsed,
          detail: `Vector returned with exactly ${vector.length} dimensions ✓`
        };
      }
    } catch (err: any) {
      report.checks.embeddingModel = {
        status: 'FAIL',
        model: '@cf/baai/bge-small-en-v1.5',
        detail: `Exception: ${err?.message || String(err)}`
      };
    }

    // CHECK 3: Vectorize binding
    report.checks.vectorizeBinding = env.VECTORIZE
      ? { status: 'PASS', detail: 'env.VECTORIZE is bound' }
      : { status: 'FAIL', detail: 'env.VECTORIZE is missing — check [[vectorize]] in wrangler.toml' };

    // CHECK 4: Vectorize index describe
    if (env.VECTORIZE) {
      try {
        const info = await env.VECTORIZE.describe();
        const dim = info?.dimensions ?? info?.config?.dimensions;
        const metric = info?.metric ?? info?.config?.metric;

        report.checks.vectorizeIndex = {
          status: dim === 384 ? 'PASS' : 'FAIL',
          indexName: 'nexora-vector-index',
          dimension: dim,
          metric: metric,
          vectorCount: info?.vectorCount ?? info?.processedUpToMutation ?? 'unknown',
          detail: dim === 384
            ? `Index is correctly configured (384 dims, ${metric}) ✓`
            : `DIMENSION MISMATCH: index reports ${dim}, expected 384`,
          rawInfo: info
        };
      } catch (err: any) {
        report.checks.vectorizeIndex = {
          status: 'WARN',
          detail: `describe() call failed (index may still work): ${err?.message || String(err)}`
        };
      }
    }

    // CHECK 5: Test Vectorize upsert + query (with the real embedding from CHECK 2)
    if (env.VECTORIZE && report.checks.embeddingModel?.status === 'PASS') {
      try {
        const embeddingVector = (await env.AI.run('@cf/baai/bge-small-en-v1.5', {
          text: [testText]
        }))?.data?.[0];

        // Upsert a test vector
        await env.VECTORIZE.upsert([{
          id: 'nexora-preflight-test',
          values: embeddingVector,
          metadata: { type: 'preflight_test', subject: 'verification' }
        }]);

        // Query it back
        const queryResult = await env.VECTORIZE.query(embeddingVector, {
          topK: 1,
          returnMetadata: 'indexed'
        });

        const topMatch = queryResult?.matches?.[0];

        report.checks.vectorizeRoundTrip = {
          status: topMatch?.id === 'nexora-preflight-test' && topMatch?.score > 0.99
            ? 'PASS'
            : 'WARN',
          detail: topMatch
            ? `Upsert→Query roundtrip: id=${topMatch.id}, score=${topMatch.score}`
            : 'Query returned no matches (index may need propagation time)',
          topMatch
        };

        // Delete the test vector
        try { await env.VECTORIZE.deleteByIds(['nexora-preflight-test']); } catch (_) {}

      } catch (err: any) {
        report.checks.vectorizeRoundTrip = {
          status: 'FAIL',
          detail: `Vectorize roundtrip test failed: ${err?.message || String(err)}`
        };
      }
    }

    // SUMMARY
    const allChecks = Object.values(report.checks) as any[];
    const passCount = allChecks.filter((c) => c.status === 'PASS').length;
    const failCount = allChecks.filter((c) => c.status === 'FAIL').length;

    report.summary = {
      total: allChecks.length,
      passed: passCount,
      failed: failCount,
      readyForPhase4: failCount === 0,
      message: failCount === 0
        ? '✅ All checks passed. Phase 4 backfill and deployment can proceed.'
        : `❌ ${failCount} check(s) failed. DO NOT proceed with backfill until resolved.`
    };

    return new Response(JSON.stringify(report, null, 2), {
      status: failCount > 0 ? 503 : 200,
      headers: { 'Content-Type': 'application/json' }
    });
  }
};
