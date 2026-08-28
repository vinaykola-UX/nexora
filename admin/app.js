/**
 * Nexora Admin Dashboard — Knowledge Base & RAG Retrieval Manager
 *
 * Handles:
 * - LocalStorage configuration of Worker URL and Admin Secret Token
 * - Client-side PDF text extraction using PDF.js
 * - Real-time deterministic chunk calculation & preview
 * - POST /admin/upload to D1 knowledge base
 * - GET /documents and live table rendering
 * - DELETE /admin/document/:id
 * - Live RAG search tester against GET /search?q=...
 */

// Configure PDF.js worker
if (typeof pdfjsLib !== 'undefined') {
  pdfjsLib.GlobalWorkerOptions.workerSrc =
    'https://cdnjs.cloudflare.com/ajax/libs/pdf.js/3.11.174/pdf.worker.min.js';
}

const STORAGE_KEYS = {
  API_URL: 'nexora_admin_api_url',
  ADMIN_SECRET: 'nexora_admin_secret_token',
};

const DEFAULT_CONFIG = {
  API_URL: 'https://nexora-bvc-api-2026.vkola306.workers.dev',
  ADMIN_SECRET: 'nexora-admin-secure-key-2026',
};

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------
const state = {
  apiUrl: localStorage.getItem(STORAGE_KEYS.API_URL) || DEFAULT_CONFIG.API_URL,
  adminSecret: localStorage.getItem(STORAGE_KEYS.ADMIN_SECRET) || DEFAULT_CONFIG.ADMIN_SECRET,
  documents: [],
  selectedFile: null,
  isExtractingPdf: false,
  isUploading: false,
};

// ---------------------------------------------------------------------------
// DOM Elements
// ---------------------------------------------------------------------------
const elements = {
  workerStatus: document.getElementById('workerStatus'),
  statDocCount: document.getElementById('statDocCount'),
  statChunkCount: document.getElementById('statChunkCount'),
  statSubjectCount: document.getElementById('statSubjectCount'),

  // Upload Form
  uploadForm: document.getElementById('uploadForm'),
  subjectInput: document.getElementById('subjectInput'),
  topicInput: document.getElementById('topicInput'),
  titleInput: document.getElementById('titleInput'),
  contentInput: document.getElementById('contentInput'),
  charCount: document.getElementById('charCount'),
  wordCount: document.getElementById('wordCount'),
  estChunkCount: document.getElementById('estChunkCount'),

  // File Dropzone
  fileDropzone: document.getElementById('fileDropzone'),
  fileInput: document.getElementById('fileInput'),
  dropzoneEmpty: document.getElementById('dropzoneEmpty'),
  filePreview: document.getElementById('filePreview'),
  fileName: document.getElementById('fileName'),
  fileSize: document.getElementById('fileSize'),
  fileIcon: document.getElementById('fileIcon'),
  extractProgress: document.getElementById('extractProgress'),
  progressFill: document.getElementById('progressFill'),
  progressLabel: document.getElementById('progressLabel'),
  removeFileBtn: document.getElementById('removeFileBtn'),

  // Chunk Preview
  chunkPreviewBox: document.getElementById('chunkPreviewBox'),
  toggleChunkPreview: document.getElementById('toggleChunkPreview'),
  chunkList: document.getElementById('chunkList'),
  chunkCountNum: document.getElementById('chunkCountNum'),

  // Form Buttons
  clearFormBtn: document.getElementById('clearFormBtn'),
  submitBtn: document.getElementById('submitBtn'),
  btnSpinner: document.getElementById('btnSpinner'),
  btnText: document.getElementById('btnText'),

  // Documents Table
  docsTableBody: document.getElementById('docsTableBody'),
  refreshDocsBtn: document.getElementById('refreshDocsBtn'),
  filterInput: document.getElementById('filterInput'),

  // Tester
  testQueryInput: document.getElementById('testQueryInput'),
  testQueryBtn: document.getElementById('testQueryBtn'),
  testResultsArea: document.getElementById('testResultsArea'),
  testResultsSummary: document.getElementById('testResultsSummary'),
  testResultCount: document.getElementById('testResultCount'),
  testResultsList: document.getElementById('testResultsList'),

  // Settings Modal
  openSettingsBtn: document.getElementById('openSettingsBtn'),
  settingsModal: document.getElementById('settingsModal'),
  closeSettingsBtn: document.getElementById('closeSettingsBtn'),
  cancelSettingsBtn: document.getElementById('cancelSettingsBtn'),
  saveSettingsBtn: document.getElementById('saveSettingsBtn'),
  apiUrlInput: document.getElementById('apiUrlInput'),
  adminSecretInput: document.getElementById('adminSecretInput'),
  togglePwdBtn: document.getElementById('togglePwdBtn'),
  testConnectionBtn: document.getElementById('testConnectionBtn'),
  testResultMsg: document.getElementById('testResultMsg'),

  // Inspect Modal
  inspectModal: document.getElementById('inspectModal'),
  inspectDocTitle: document.getElementById('inspectDocTitle'),
  inspectDocMeta: document.getElementById('inspectDocMeta'),
  inspectChunksList: document.getElementById('inspectChunksList'),
  closeInspectBtn: document.getElementById('closeInspectBtn'),
  closeInspectFooterBtn: document.getElementById('closeInspectFooterBtn'),

  toastContainer: document.getElementById('toastContainer'),
};

// ---------------------------------------------------------------------------
// Notifications
// ---------------------------------------------------------------------------
function showToast(message, type = 'info') {
  const toast = document.createElement('div');
  toast.className = `toast ${type}`;
  toast.innerHTML = `
    <span>${type === 'success' ? '✅' : type === 'error' ? '❌' : 'ℹ️'}</span>
    <span>${message}</span>
  `;
  elements.toastContainer.appendChild(toast);

  setTimeout(() => {
    toast.style.opacity = '0';
    toast.style.transform = 'translateY(12px)';
    setTimeout(() => toast.remove(), 250);
  }, 4000);
}

// ---------------------------------------------------------------------------
// API Helper
// ---------------------------------------------------------------------------
async function apiRequest(endpoint, options = {}) {
  const url = `${state.apiUrl.replace(/\/$/, '')}${endpoint}`;
  const headers = {
    Accept: 'application/json',
    'Content-Type': 'application/json',
    ...(options.auth ? { Authorization: `Bearer ${state.adminSecret}` } : {}),
    ...(options.headers || {}),
  };

  try {
    const response = await fetch(url, {
      ...options,
      headers,
    });

    const isJson = response.headers.get('content-type')?.includes('application/json');
    const data = isJson ? await response.json() : await response.text();

    if (!response.ok) {
      const errMsg = (data && data.message) || (data && data.error) || `HTTP error ${response.statusCode}`;
      throw new Error(errMsg);
    }

    return data;
  } catch (error) {
    console.error(`[API Error] ${endpoint}:`, error);
    throw error;
  }
}

// ---------------------------------------------------------------------------
// Worker Health Check
// ---------------------------------------------------------------------------
async function checkWorkerHealth() {
  elements.workerStatus.className = 'status-indicator';
  elements.workerStatus.querySelector('.status-text').textContent = 'Connecting...';

  try {
    const data = await apiRequest('/health');
    if (data.status === 'healthy' || data.success) {
      elements.workerStatus.className = 'status-indicator online';
      elements.workerStatus.querySelector('.status-text').textContent = 'Worker Online (D1 Ready)';
    } else {
      throw new Error('Unhealthy status');
    }
  } catch (err) {
    elements.workerStatus.className = 'status-indicator offline';
    elements.workerStatus.querySelector('.status-text').textContent = 'Worker Offline / Error';
  }
}

// ---------------------------------------------------------------------------
// Auto-Generate Title from Subject, Unit, and Topic
// ---------------------------------------------------------------------------
function updateAutoTitle() {
  const subject = elements.subjectInput.value.trim();
  const topic = elements.topicInput.value.trim();
  const selectedUnit = document.querySelector('input[name="unit"]:checked')?.value || '1';

  const romanUnits = { '1': 'I', '2': 'II', '3': 'III', '4': 'IV', '5': 'V' };
  const roman = romanUnits[selectedUnit] || selectedUnit;

  if (subject && topic) {
    elements.titleInput.value = `${subject} - Unit ${roman}: ${topic}`;
  } else if (subject) {
    elements.titleInput.value = `${subject} - Unit ${roman}`;
  }
}

// ---------------------------------------------------------------------------
// Client-Side Deterministic Chunking Calculation & Preview
// ---------------------------------------------------------------------------
function calculateChunks(text, subject, unit, topic, title) {
  const clean = text.replace(/\r\n/g, '\n').trim();
  if (!clean) return [];

  const paragraphs = clean.split(/\n\s*\n+/);
  const chunks = [];
  let current = '';
  const maxChunkSize = 1400;
  const minChunkSize = 600;

  const header = topic
    ? `SUBJECT: ${subject || 'Data Structures'} | UNIT: ${unit} | TOPIC: ${topic.toUpperCase()}\n\n`
    : `SUBJECT: ${subject || 'Data Structures'} | UNIT: ${unit} | TITLE: ${title || 'Unit Notes'}\n\n`;

  for (const para of paragraphs) {
    const tPara = para.trim();
    if (!tPara) continue;

    if (tPara.length > maxChunkSize) {
      const sentences = tPara.match(/[^.!?]+[.!?]+(?:\s+|$)|[^.!?]+$/g) || [tPara];
      for (const sent of sentences) {
        const tSent = sent.trim();
        if (!tSent) continue;
        if (current.length + tSent.length + 1 > maxChunkSize) {
          if (current.trim().length >= minChunkSize) {
            chunks.push(current.trim());
            current = '';
          }
        }
        current = current ? `${current} ${tSent}` : tSent;
      }
    } else {
      if (current.length + tPara.length + 2 > maxChunkSize) {
        if (current.trim().length >= minChunkSize) {
          chunks.push(current.trim());
          current = '';
        }
      }
      current = current ? `${current}\n\n${tPara}` : tPara;
    }
  }

  if (current.trim()) chunks.push(current.trim());

  return chunks.map((c) => {
    if (!c.toUpperCase().includes('UNIT ') && !c.toUpperCase().includes((subject || '').toUpperCase())) {
      return `${header}${c}`;
    }
    return c;
  });
}

function updateContentStats() {
  const text = elements.contentInput.value;
  const chars = text.length;
  const words = text.trim() ? text.trim().split(/\s+/).length : 0;

  const subject = elements.subjectInput.value.trim();
  const topic = elements.topicInput.value.trim();
  const title = elements.titleInput.value.trim();
  const unit = document.querySelector('input[name="unit"]:checked')?.value || '1';

  const chunks = calculateChunks(text, subject, unit, topic, title);

  elements.charCount.textContent = `${chars.toLocaleString()} chars`;
  elements.wordCount.textContent = `${words.toLocaleString()} words`;
  elements.estChunkCount.textContent = `~${chunks.length} chunks`;

  if (chunks.length > 0) {
    elements.chunkPreviewBox.style.display = 'block';
    elements.chunkCountNum.textContent = chunks.length;
    elements.chunkList.innerHTML = chunks
      .map(
        (c, idx) => `
        <div class="chunk-item">
          <div class="chunk-item-title">Chunk #${idx + 1} (${c.length} chars)</div>
          <div>${escapeHtml(c.substring(0, 200))}...</div>
        </div>
      `
      )
      .join('');
  } else {
    elements.chunkPreviewBox.style.display = 'none';
  }
}

// ---------------------------------------------------------------------------
// Client-Side PDF & File Processing
// ---------------------------------------------------------------------------
async function handleFileSelected(file) {
  if (!file) return;

  state.selectedFile = file;
  elements.dropzoneEmpty.style.display = 'none';
  elements.filePreview.style.display = 'flex';
  elements.fileName.textContent = file.name;
  elements.fileSize.textContent = `${(file.size / 1024).toFixed(1)} KB`;

  const isPdf = file.name.toLowerCase().endsWith('.pdf');
  elements.fileIcon.textContent = isPdf ? '📕' : '📄';

  if (isPdf) {
    await extractTextFromPdf(file);
  } else {
    // Text / Markdown file
    const reader = new FileReader();
    reader.onload = (e) => {
      elements.contentInput.value = e.target.result || '';
      updateContentStats();
      showToast(`Loaded ${file.name} (${(file.size / 1024).toFixed(1)} KB)`, 'success');
    };
    reader.readAsText(file);
  }
}

async function extractTextFromPdf(file) {
  if (typeof pdfjsLib === 'undefined') {
    showToast('PDF.js library is not loaded. Please paste text directly.', 'error');
    return;
  }

  elements.extractProgress.style.display = 'flex';
  elements.progressFill.style.width = '0%';
  elements.progressLabel.textContent = 'Parsing PDF...';

  try {
    const arrayBuffer = await file.arrayBuffer();
    const loadingTask = pdfjsLib.getDocument({ data: arrayBuffer });
    const pdf = await loadingTask.promise;
    const numPages = pdf.numPages;

    let fullText = '';

    for (let pageNum = 1; pageNum <= numPages; pageNum++) {
      elements.progressLabel.textContent = `Extracting page ${pageNum} of ${numPages}...`;
      elements.progressFill.style.width = `${Math.round((pageNum / numPages) * 100)}%`;

      const page = await pdf.getPage(pageNum);
      const textContent = await page.getTextContent();
      const pageText = textContent.items.map((item) => item.str).join(' ');

      if (pageText.trim()) {
        fullText += `\n\n--- Page ${pageNum} ---\n${pageText}`;
      }
    }

    elements.contentInput.value = fullText.trim();
    updateContentStats();

    elements.progressLabel.textContent = `Extracted ${numPages} pages`;
    showToast(`Successfully extracted text from ${numPages} PDF pages!`, 'success');
  } catch (err) {
    console.error('PDF Extraction Error:', err);
    showToast('Failed to extract selectable text from PDF. You can paste notes directly.', 'error');
    elements.progressLabel.textContent = 'Extraction failed';
  }
}

function removeSelectedFile() {
  state.selectedFile = null;
  elements.fileInput.value = '';
  elements.dropzoneEmpty.style.display = 'block';
  elements.filePreview.style.display = 'none';
  elements.extractProgress.style.display = 'none';
}

// ---------------------------------------------------------------------------
// Document List & D1 Operations
// ---------------------------------------------------------------------------
async function loadDocuments() {
  elements.docsTableBody.innerHTML = `<tr><td colspan="6" class="table-loading">Loading documents from D1...</td></tr>`;

  try {
    const docs = await apiRequest('/documents');
    state.documents = Array.isArray(docs) ? docs : [];
    renderDocumentsTable(state.documents);
    updateOverviewStats(state.documents);
  } catch (err) {
    elements.docsTableBody.innerHTML = `<tr><td colspan="6" class="table-loading" style="color: var(--error)">Failed to load documents: ${err.message}</td></tr>`;
  }
}

function renderDocumentsTable(docs) {
  if (docs.length === 0) {
    elements.docsTableBody.innerHTML = `<tr><td colspan="6" class="table-empty">No documents found in knowledge base. Add your first unit notes on the left!</td></tr>`;
    return;
  }

  elements.docsTableBody.innerHTML = docs
    .map((doc) => {
      const dateStr = doc.created_at
        ? new Date(doc.created_at).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })
        : '—';

      return `
      <tr data-id="${doc.id}">
        <td><strong>#${doc.id}</strong></td>
        <td>
          <div style="font-weight: 600; color: var(--text-main);">${escapeHtml(doc.title)}</div>
          ${doc.file_url ? `<div style="font-size: 0.72rem; color: var(--text-muted);">Topic: ${escapeHtml(doc.file_url)}</div>` : ''}
        </td>
        <td><span style="color: var(--text-secondary);">${escapeHtml(doc.subject || '—')}</span></td>
        <td><span class="unit-badge">Unit ${doc.unit || '—'}</span></td>
        <td><span class="chunks-badge">${doc.chunk_count || '—'} chunks</span></td>
        <td>
          <div class="action-btn-group">
            <button class="btn-table-action" onclick="inspectDocument(${doc.id})">Inspect</button>
            <button class="btn-table-action delete" onclick="deleteDocument(${doc.id}, '${escapeHtml(doc.title)}')">Delete</button>
          </div>
        </td>
      </tr>
    `;
    })
    .join('');
}

function updateOverviewStats(docs) {
  elements.statDocCount.textContent = docs.length;
  const totalChunks = docs.reduce((acc, d) => acc + (d.chunk_count || 0), 0);
  elements.statChunkCount.textContent = totalChunks || '—';

  const subjects = new Set(docs.map((d) => d.subject).filter(Boolean));
  elements.statSubjectCount.textContent = subjects.size;
}

// ---------------------------------------------------------------------------
// Upload Flow (POST /admin/upload)
// ---------------------------------------------------------------------------
async function handleUploadSubmit() {
  const subject = elements.subjectInput.value.trim();
  const topic = elements.topicInput.value.trim();
  const title = elements.titleInput.value.trim();
  const content = elements.contentInput.value.trim();
  const unit = parseInt(document.querySelector('input[name="unit"]:checked')?.value || '1', 10);

  if (!subject || !topic || !title || !content) {
    showToast('Please fill in all required fields (Subject, Topic, Title, Content).', 'error');
    return;
  }

  setUploadLoading(true);

  try {
    const payload = {
      title,
      subject,
      unit,
      topic,
      content,
    };

    const result = await apiRequest('/admin/upload', {
      method: 'POST',
      auth: true,
      body: JSON.stringify(payload),
    });

    if (result.success) {
      showToast(`Success! Added ${result.chunksCreated} chunks to D1 for ${subject} Unit ${unit}.`, 'success');
      clearUploadForm();
      await loadDocuments();
    } else {
      throw new Error(result.message || 'Upload failed');
    }
  } catch (err) {
    showToast(`Upload Error: ${err.message}`, 'error');
  } finally {
    setUploadLoading(false);
  }
}

function setUploadLoading(isLoading) {
  state.isUploading = isLoading;
  elements.submitBtn.disabled = isLoading;
  elements.btnSpinner.style.display = isLoading ? 'inline-block' : 'none';
  elements.btnText.textContent = isLoading ? 'Chunking & Indexing D1...' : 'Process & Add to Nexora';
}

function clearUploadForm() {
  elements.uploadForm.reset();
  elements.contentInput.value = '';
  removeSelectedFile();
  updateContentStats();
  updateAutoTitle();
}

// ---------------------------------------------------------------------------
// Delete Document (DELETE /admin/document/:id)
// ---------------------------------------------------------------------------
window.deleteDocument = async function (id, title) {
  const confirmed = confirm(
    `Are you sure you want to delete Document #${id}: "${title}"?\n\nThis will remove the document row and all its indexed chunks from Cloudflare D1.`
  );

  if (!confirmed) return;

  try {
    const result = await apiRequest(`/admin/document/${id}`, {
      method: 'DELETE',
      auth: true,
    });

    if (result.success) {
      showToast(`Deleted Document #${id} and associated chunks.`, 'success');
      await loadDocuments();
    } else {
      throw new Error(result.message || 'Delete failed');
    }
  } catch (err) {
    showToast(`Delete Error: ${err.message}`, 'error');
  }
};

// ---------------------------------------------------------------------------
// Inspect Document Chunks (GET /admin/document/:id)
// ---------------------------------------------------------------------------
window.inspectDocument = async function (id) {
  elements.inspectModal.style.display = 'flex';
  elements.inspectDocTitle.textContent = `Loading Document #${id}...`;
  elements.inspectDocMeta.textContent = 'Fetching D1 chunks...';
  elements.inspectChunksList.innerHTML = '<div class="table-loading">Loading chunk details from D1...</div>';

  try {
    const result = await apiRequest(`/admin/document/${id}`, { auth: true });
    if (result.success && result.document) {
      elements.inspectDocTitle.textContent = result.document.title;
      elements.inspectDocMeta.textContent = `${result.document.subject} • Unit ${result.document.unit} • ${result.chunks?.length || 0} Chunks in D1`;

      if (result.chunks && result.chunks.length > 0) {
        elements.inspectChunksList.innerHTML = result.chunks
          .map(
            (c, i) => `
            <div class="chunk-item">
              <div class="chunk-item-title">Chunk #${i + 1} (Index: ${c.chunk_index})</div>
              <div style="white-space: pre-wrap;">${escapeHtml(c.content)}</div>
            </div>
          `
          )
          .join('');
      } else {
        elements.inspectChunksList.innerHTML = '<div class="table-empty">No chunk details returned for this document.</div>';
      }
    }
  } catch (err) {
    elements.inspectChunksList.innerHTML = `<div class="table-loading" style="color: var(--error)">Error: ${err.message}</div>`;
  }
};

// ---------------------------------------------------------------------------
// Live RAG Retrieval Tester (GET /search?q=...)
// ---------------------------------------------------------------------------
async function runRetrievalTest(query) {
  const q = (query || elements.testQueryInput.value).trim();
  if (!q) {
    showToast('Please enter a query to test.', 'error');
    return;
  }

  elements.testResultsArea.style.display = 'block';
  elements.testResultsSummary.textContent = `Searching for: "${q}"...`;
  elements.testResultCount.textContent = 'Searching...';
  elements.testResultsList.innerHTML = '<div class="table-loading">Querying Cloudflare D1 RAG backend...</div>';

  try {
    const encoded = encodeURIComponent(q);
    const result = await apiRequest(`/search?q=${encoded}`);

    const results = result.results || [];
    elements.testResultsSummary.textContent = `Results for: "${q}"`;
    elements.testResultCount.textContent = `${results.length} Chunks`;

    if (results.length === 0) {
      elements.testResultsList.innerHTML = `
        <div class="table-empty">
          No relevant chunks found in the current Nexora knowledge base for "${escapeHtml(q)}".
        </div>
      `;
      return;
    }

    elements.testResultsList.innerHTML = results
      .map(
        (r, i) => `
        <div class="retrieved-chunk-card">
          <div class="retrieved-chunk-meta">
            <span>#${i + 1} ${escapeHtml(r.subject || 'BVC')} • Unit ${r.unit || '—'}</span>
            <span>${escapeHtml(r.title || '')}</span>
          </div>
          <div style="white-space: pre-wrap; font-family: var(--font-mono); font-size: 0.76rem; color: var(--text-secondary);">
            ${escapeHtml(r.content || r.snippet || '')}
          </div>
        </div>
      `
      )
      .join('');
  } catch (err) {
    elements.testResultsList.innerHTML = `<div class="table-loading" style="color: var(--error)">Search Error: ${err.message}</div>`;
  }
}

// ---------------------------------------------------------------------------
// Event Listeners
// ---------------------------------------------------------------------------
function initEvents() {
  // Input Auto Title & Stats
  elements.subjectInput.addEventListener('input', () => { updateAutoTitle(); updateContentStats(); });
  elements.topicInput.addEventListener('input', () => { updateAutoTitle(); updateContentStats(); });
  elements.contentInput.addEventListener('input', updateContentStats);
  document.querySelectorAll('input[name="unit"]').forEach((r) => {
    r.addEventListener('change', () => { updateAutoTitle(); updateContentStats(); });
  });

  // Dropzone Events
  elements.fileDropzone.addEventListener('click', (e) => {
    if (e.target !== elements.removeFileBtn) elements.fileInput.click();
  });

  elements.fileInput.addEventListener('change', (e) => {
    if (e.target.files?.length) handleFileSelected(e.target.files[0]);
  });

  elements.fileDropzone.addEventListener('dragover', (e) => {
    e.preventDefault();
    elements.fileDropzone.classList.add('dragover');
  });

  elements.fileDropzone.addEventListener('dragleave', () => {
    elements.fileDropzone.classList.remove('dragover');
  });

  elements.fileDropzone.addEventListener('drop', (e) => {
    e.preventDefault();
    elements.fileDropzone.classList.remove('dragover');
    if (e.dataTransfer.files?.length) handleFileSelected(e.dataTransfer.files[0]);
  });

  elements.removeFileBtn.addEventListener('click', (e) => {
    e.stopPropagation();
    removeSelectedFile();
  });

  // Form Submit
  elements.uploadForm.addEventListener('submit', (e) => {
    e.preventDefault();
    handleUploadSubmit();
  });

  elements.clearFormBtn.addEventListener('click', clearUploadForm);

  // Table Filter
  elements.filterInput.addEventListener('input', (e) => {
    const term = e.target.value.toLowerCase().trim();
    const filtered = state.documents.filter(
      (d) =>
        d.title.toLowerCase().includes(term) ||
        (d.subject && d.subject.toLowerCase().includes(term)) ||
        String(d.unit).includes(term)
    );
    renderDocumentsTable(filtered);
  });

  elements.refreshDocsBtn.addEventListener('click', loadDocuments);

  // Tester
  elements.testQueryBtn.addEventListener('click', () => runRetrievalTest());
  elements.testQueryInput.addEventListener('keydown', (e) => {
    if (e.key === 'Enter') runRetrievalTest();
  });

  document.querySelectorAll('.chip').forEach((chip) => {
    chip.addEventListener('click', () => {
      const q = chip.getAttribute('data-query');
      elements.testQueryInput.value = q;
      runRetrievalTest(q);
    });
  });

  // Settings Modal
  elements.openSettingsBtn.addEventListener('click', () => {
    elements.apiUrlInput.value = state.apiUrl;
    elements.adminSecretInput.value = state.adminSecret;
    elements.testResultMsg.textContent = '';
    elements.settingsModal.style.display = 'flex';
  });

  const closeSettings = () => (elements.settingsModal.style.display = 'none');
  elements.closeSettingsBtn.addEventListener('click', closeSettings);
  elements.cancelSettingsBtn.addEventListener('click', closeSettings);

  elements.togglePwdBtn.addEventListener('click', () => {
    const isPwd = elements.adminSecretInput.type === 'password';
    elements.adminSecretInput.type = isPwd ? 'text' : 'password';
    elements.togglePwdBtn.textContent = isPwd ? '🔒' : '👁';
  });

  elements.saveSettingsBtn.addEventListener('click', () => {
    const newUrl = elements.apiUrlInput.value.trim() || DEFAULT_CONFIG.API_URL;
    const newSecret = elements.adminSecretInput.value.trim() || DEFAULT_CONFIG.ADMIN_SECRET;

    state.apiUrl = newUrl;
    state.adminSecret = newSecret;
    localStorage.setItem(STORAGE_KEYS.API_URL, newUrl);
    localStorage.setItem(STORAGE_KEYS.ADMIN_SECRET, newSecret);

    closeSettings();
    showToast('Settings saved successfully!', 'success');
    checkWorkerHealth();
    loadDocuments();
  });

  elements.testConnectionBtn.addEventListener('click', async () => {
    elements.testResultMsg.textContent = 'Testing...';
    elements.testResultMsg.style.color = 'var(--text-muted)';

    try {
      const testUrl = elements.apiUrlInput.value.trim() || DEFAULT_CONFIG.API_URL;
      const resp = await fetch(`${testUrl.replace(/\/$/, '')}/health`);
      if (resp.ok) {
        elements.testResultMsg.textContent = '✅ Connected successfully!';
        elements.testResultMsg.style.color = 'var(--success)';
      } else {
        elements.testResultMsg.textContent = `❌ HTTP ${resp.status}`;
        elements.testResultMsg.style.color = 'var(--error)';
      }
    } catch (e) {
      elements.testResultMsg.textContent = '❌ Failed to reach worker';
      elements.testResultMsg.style.color = 'var(--error)';
    }
  });

  // Inspect Modal Close
  const closeInspect = () => (elements.inspectModal.style.display = 'none');
  elements.closeInspectBtn.addEventListener('click', closeInspect);
  elements.closeInspectFooterBtn.addEventListener('click', closeInspect);

  // Close modals on escape key or clicking backdrop
  window.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') {
      closeSettings();
      closeInspect();
    }
  });

  elements.settingsModal.addEventListener('click', (e) => {
    if (e.target === elements.settingsModal) closeSettings();
  });
  elements.inspectModal.addEventListener('click', (e) => {
    if (e.target === elements.inspectModal) closeInspect();
  });
}

function escapeHtml(str) {
  if (!str) return '';
  return String(str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;');
}

// ---------------------------------------------------------------------------
// Initialization
// ---------------------------------------------------------------------------
document.addEventListener('DOMContentLoaded', () => {
  initEvents();
  checkWorkerHealth();
  loadDocuments();
});
