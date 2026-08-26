import worker from './src/index.ts';

async function runTests() {
  console.log('====================================================');
  console.log('Testing Nexora BVC Worker Official Retrieval System');
  console.log('====================================================\n');

  const testCases = [
    { name: '1. Health Check (GET /health)', url: 'http://localhost:8787/health' },
    { name: '2. API Discovery (GET /api)', url: 'http://localhost:8787/api' },
    { name: '3. Official Search BR23 (GET /search?q=BR23)', url: 'http://localhost:8787/search?q=BR23' },
    { name: '4. Official Search Exam Fee (GET /search?q=exam%20fee%20last%20date)', url: 'http://localhost:8787/search?q=exam%20fee%20last%20date' },
    { name: '5. Empty Query Validation (GET /search?q=)', url: 'http://localhost:8787/search?q=' },
    { name: '6. Unknown Route 404 (GET /unknown-route)', url: 'http://localhost:8787/unknown-route' }
  ];

  for (const tc of testCases) {
    console.log(`\n--- TEST CASE: ${tc.name} ---`);
    const req = new Request(tc.url, { method: 'GET' });
    try {
      const res = await worker.fetch(req, {}, {} as any);
      const status = res.status;
      const json = await res.json();
      console.log(`Status: ${status}`);
      console.log('Response JSON:');
      console.log(JSON.stringify(json, null, 2));
    } catch (err) {
      console.error('Test error:', err);
    }
  }
}

runTests();
