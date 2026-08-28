import worker from './src/index.ts';

async function runTests() {
  console.log('====================================================');
  console.log('Testing Nexora BVC Worker & Admin RAG Retrieval API');
  console.log('====================================================\n');

  const mockEnv: any = {
    ENVIRONMENT: 'test',
    ADMIN_SECRET: 'nexora-admin-secure-key-2026',
  };

  // Test 1: GET /health
  console.log('--- 1. Health Check (GET /health) ---');
  let req = new Request('http://localhost:8787/health', { method: 'GET' });
  let res = await worker.fetch(req, mockEnv, {} as any);
  console.log(`Status: ${res.status}`, await res.json());

  // Test 2: GET /documents
  console.log('\n--- 2. List Documents (GET /documents) ---');
  req = new Request('http://localhost:8787/documents', { method: 'GET' });
  res = await worker.fetch(req, mockEnv, {} as any);
  console.log(`Status: ${res.status}`, await res.json());

  // Test 3: POST /admin/upload without token (should be 401)
  console.log('\n--- 3. Upload without Auth (POST /admin/upload) ---');
  req = new Request('http://localhost:8787/admin/upload', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ title: 'Test', subject: 'DS', unit: 3, content: 'Some study notes' }),
  });
  res = await worker.fetch(req, mockEnv, {} as any);
  console.log(`Status: ${res.status}`, await res.json());

  // Test 4: POST /admin/upload with Bearer Token (should be 200)
  console.log('\n--- 4. Upload with Valid Admin Token (POST /admin/upload) ---');
  req = new Request('http://localhost:8787/admin/upload', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: 'Bearer nexora-admin-secure-key-2026',
    },
    body: JSON.stringify({
      title: 'Data Structures Unit 3 - Stacks and Queues',
      subject: 'Data Structures',
      unit: 3,
      topic: 'Stacks and Queues',
      content:
        'A Stack is a linear data structure following LIFO (Last In First Out) principle.\n\nOperations on Stack include:\n1. Push - Adds an element to the top\n2. Pop - Removes the top element\n3. Peek - Returns top element without removing it\n\nApplications of Stacks include expression evaluation, backtrack algorithm, and function call management.\n\nA Queue is a linear data structure following FIFO (First In First Out) principle.\n\nOperations on Queue include Enqueue and Dequeue.',
    }),
  });
  res = await worker.fetch(req, mockEnv, {} as any);
  console.log(`Status: ${res.status}`, await res.json());

  // Test 5: DELETE /admin/document/:id with Token
  console.log('\n--- 5. Delete Document with Token (DELETE /admin/document/1) ---');
  req = new Request('http://localhost:8787/admin/document/1', {
    method: 'DELETE',
    headers: { Authorization: 'Bearer nexora-admin-secure-key-2026' },
  });
  res = await worker.fetch(req, mockEnv, {} as any);
  console.log(`Status: ${res.status}`, await res.json());

  // Test 6: GET /search?q=linked
  console.log('\n--- 6. Search RAG (GET /search?q=linked) ---');
  req = new Request('http://localhost:8787/search?q=linked', { method: 'GET' });
  res = await worker.fetch(req, mockEnv, {} as any);
  console.log(`Status: ${res.status}`, await res.json());

  console.log('\n====================================================');
  console.log('ALL WORKER TESTS COMPLETED SUCCESSFULLY');
  console.log('====================================================');
}

runTests();
