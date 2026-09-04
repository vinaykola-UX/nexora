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
  WEB_ACCESS: 'nexora_web_access_enabled',
  OFFICIAL_WEBSITE: 'nexora_official_website_url',
  OFFICIAL_WEBSITE_VERIFIED: 'nexora_official_website_verified',
  TRUSTED_WEBSITES: 'nexora_trusted_websites',
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
  webAccessEnabled: localStorage.getItem(STORAGE_KEYS.WEB_ACCESS) === 'true',
  officialWebsiteUrl: localStorage.getItem(STORAGE_KEYS.OFFICIAL_WEBSITE) || 'bvcec.edu.in',
  officialWebsiteVerified: localStorage.getItem(STORAGE_KEYS.OFFICIAL_WEBSITE_VERIFIED) === 'true',
  trustedWebsites: (() => {
    try {
      const stored = localStorage.getItem('nexora_trusted_websites');
      if (stored) {
        const parsed = JSON.parse(stored);
        if (Array.isArray(parsed) && parsed.length > 0) return parsed;
      }
    } catch (_) {}
    return [
      { url: 'bvcec.edu.in', label: 'BVC Engineering College Main Portal', verified: true },
      { url: 'www.bvcecautonomous.com', label: 'BVC Autonomous Examination Cell', verified: true },
    ];
  })(),
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

  // Web Access
  webAccessToggle: document.getElementById('webAccessToggle'),
  testWebAccessBtn: document.getElementById('testWebAccessBtn'),
  webAccessStatus: document.getElementById('webAccessStatus'),
  webTestResults: document.getElementById('webTestResults'),
  webTestCount: document.getElementById('webTestCount'),
  webTestList: document.getElementById('webTestList'),

  // Trusted Web Sources & Portals
  sitesCountBadge: document.getElementById('sitesCountBadge'),
  newSiteUrlInput: document.getElementById('newSiteUrlInput'),
  newSiteLabelInput: document.getElementById('newSiteLabelInput'),
  addSiteBtn: document.getElementById('addSiteBtn'),
  trustedSitesList: document.getElementById('trustedSitesList'),
  verifyAllSitesBtn: document.getElementById('verifyAllSitesBtn'),
  syncSitesBtn: document.getElementById('syncSitesBtn'),
  sitesStatusBox: document.getElementById('sitesStatusBox'),
  sitesStatusText: document.getElementById('sitesStatusText'),

  // Backwards compatibility elements
  officialUrlInput: document.getElementById('officialUrlInput'),
  verifyWebsiteBtn: document.getElementById('verifyWebsiteBtn'),
  officialWebsiteStatus: document.getElementById('officialWebsiteStatus'),
  verifiedBadgeBox: document.getElementById('verifiedBadgeBox'),
  verifiedUrlDisplay: document.getElementById('verifiedUrlDisplay'),
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
    if (data.status === 'healthy' || data.status === 'ok' || data.success) {
      elements.workerStatus.className = 'status-indicator online';
      elements.workerStatus.querySelector('.status-text').textContent =
        state.apiUrl.includes('localhost') ? 'Worker Online (Local API)' : 'Worker Online (Cloudflare D1)';
      return true;
    } else {
      throw new Error('Unhealthy status');
    }
  } catch (err) {
    // If remote worker fails and user is running on localhost, auto-try local API server on :8787
    if (window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1') {
      try {
        const localRes = await fetch('http://localhost:8787/health');
        const localData = await localRes.json();
        if (localData.status === 'ok' || localData.status === 'healthy' || localData.success) {
          state.apiUrl = 'http://localhost:8787';
          localStorage.setItem(STORAGE_KEYS.API_URL, state.apiUrl);
          if (elements.apiUrlInput) elements.apiUrlInput.value = state.apiUrl;
          elements.workerStatus.className = 'status-indicator online';
          elements.workerStatus.querySelector('.status-text').textContent = 'Worker Online (Local :8787)';
          await loadDocuments();
          return true;
        }
      } catch (localErr) {
        // local also down
      }
    }
    elements.workerStatus.className = 'status-indicator offline';
    elements.workerStatus.querySelector('.status-text').textContent = 'Worker Offline / Error';
    return false;
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

  const sourceName = state.selectedFile ? state.selectedFile.name : 'Manual Entry';
  const paragraphs = clean.split(/\n\s*\n+/);
  const rawChunks = [];
  let current = '';
  let currentPage = 1;
  let chunkStartPage = 1;
  let hasPageMarkers = false;

  const maxChunkSize = 1400;
  const minChunkSize = 600;

  for (const para of paragraphs) {
    const tPara = para.trim();
    if (!tPara) continue;

    // Detect page boundary in text
    const pageMatch = tPara.match(/^---\s*Page\s*(\d+)\s*---/i);
    if (pageMatch) {
      currentPage = parseInt(pageMatch[1], 10);
      hasPageMarkers = true;
    }

    if (tPara.length > maxChunkSize) {
      const sentences = tPara.match(/[^.!?]+[.!?]+(?:\s+|$)|[^.!?]+$/g) || [tPara];
      for (const sent of sentences) {
        const tSent = sent.trim();
        if (!tSent) continue;
        if (current.length + tSent.length + 1 > maxChunkSize) {
          if (current.trim().length >= minChunkSize) {
            rawChunks.push({
              body: current.trim(),
              startPage: chunkStartPage,
              endPage: currentPage,
            });
            current = '';
            chunkStartPage = currentPage;
          }
        }
        current = current ? `${current} ${tSent}` : tSent;
      }
    } else {
      if (current.length + tPara.length + 2 > maxChunkSize) {
        if (current.trim().length >= minChunkSize) {
          rawChunks.push({
            body: current.trim(),
            startPage: chunkStartPage,
            endPage: currentPage,
          });
          current = '';
          chunkStartPage = currentPage;
        }
      }
      current = current ? `${current}\n\n${tPara}` : tPara;
    }
  }

  if (current.trim()) {
    rawChunks.push({
      body: current.trim(),
      startPage: chunkStartPage,
      endPage: currentPage,
    });
  }

  // Filter out any purely empty/whitespace entries
  const validRaw = rawChunks.filter((rc) => rc.body && rc.body.trim().length > 0);

  return validRaw.map((item, idx) => {
    let pageInfo = 'Direct Entry';
    if (hasPageMarkers) {
      pageInfo = item.startPage === item.endPage ? `Page ${item.startPage}` : `Pages ${item.startPage}–${item.endPage}`;
    } else if (state.selectedFile) {
      pageInfo = 'Entire File';
    }

    const header = `SUBJECT: ${subject || 'General'} | UNIT: ${unit} | TOPIC: ${(topic || title || 'Notes').toUpperCase()} | SOURCE: ${sourceName} | PAGES: ${pageInfo}\n\n`;
    const fullText = item.body.startsWith('SUBJECT:') ? item.body : `${header}${item.body}`;

    return {
      chunk_id: idx + 1,
      chunk_index: idx,
      text: fullText,
      content: fullText,
      chars: fullText.length,
      subject: subject || 'General',
      unit: unit,
      academicUnit: unit,
      topic: topic || '',
      title: title || `${subject} Unit ${unit}`,
      source: sourceName,
      page_info: pageInfo,
      startPage: item.startPage,
      endPage: item.endPage,
    };
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
          <div class="chunk-item-header">
            <span class="chunk-index-badge">Chunk #${idx + 1}</span>
            <span class="chunk-badge chars-badge">${c.chars.toLocaleString()} chars</span>
            <span class="chunk-badge source-badge">📄 ${escapeHtml(c.source)}</span>
            <span class="chunk-badge page-badge">📑 ${escapeHtml(c.page_info)}</span>
          </div>
          <div class="chunk-meta-sub">
            <span style="color: var(--accent); font-weight: 600;">${escapeHtml(c.subject)} • Unit ${c.unit}</span>
            ${c.topic ? `<span>Topic: <strong>${escapeHtml(c.topic)}</strong></span>` : ''}
          </div>
          <div class="chunk-snippet">${escapeHtml(c.content.substring(0, 240))}...</div>
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
  elements.docsTableBody.innerHTML = `<tr><td colspan="6" class="table-loading">Loading documents from knowledge base...</td></tr>`;

  try {
    const res = await apiRequest('/documents');
    const docs = Array.isArray(res) ? res : (res && Array.isArray(res.documents) ? res.documents : []);
    state.documents = docs;
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
        <td><span class="unit-badge">Unit ${doc.unit || doc.academicUnit || '—'}</span></td>
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

  // Validate title is a non-empty string
  if (!title || typeof title !== 'string' || !title.trim()) {
    showToast('Please provide a valid document title.', 'error');
    return;
  }

  // Validate subject is a non-empty string
  if (!subject || typeof subject !== 'string' || !subject.trim()) {
    showToast('Please select or provide a valid subject.', 'error');
    return;
  }

  // Validate content is present
  if (!content) {
    showToast('Please provide study material content or upload a file.', 'error');
    return;
  }

  // Generate deterministic chunks with full metadata from UI content
  const generatedChunks = calculateChunks(content, subject, unit, topic, title);

  // Validate that chunks is an array with at least one item
  if (!Array.isArray(generatedChunks) || generatedChunks.length === 0) {
    showToast('Unable to generate valid chunks from the content.', 'error');
    return;
  }

  // Strictly reject empty or whitespace-only chunks
  for (let i = 0; i < generatedChunks.length; i++) {
    const c = generatedChunks[i];
    const rawBody = (c.content || '').replace(/^SUBJECT:[^\n]+\n\n/, '').trim();
    if (!rawBody) {
      showToast(`Validation Error: Chunk #${i + 1} is empty or contains only whitespace. Upload rejected.`, 'error');
      return;
    }
  }

  const sourceName = state.selectedFile ? state.selectedFile.name : 'Manual Entry';
  const startPage = generatedChunks[0].startPage || 1;
  const endPage = generatedChunks[generatedChunks.length - 1].endPage || 1;
  const overallPageInfo = startPage === endPage ? `Page ${startPage}` : `Pages ${startPage}–${endPage}`;

  // Map generated chunks with metadata preserved
  const chunks = generatedChunks.map((c, idx) => ({
    chunk_id: idx + 1,
    chunk_index: idx,
    text: c.content,
    content: c.content,
    academicUnit: unit,
    unit: unit,
    subject: subject,
    title: title,
    topic: topic || '',
    source: c.source || sourceName,
    page_info: c.page_info || overallPageInfo,
  }));

  const payload = {
    title,
    subject,
    unit,
    academicUnit: unit,
    topic,
    source: sourceName,
    page_info: overallPageInfo,
    content,
    chunks,
  };

  // Required console logging immediately before POST /admin/upload
  console.log('payload.title:', payload.title);
  console.log('payload.subject:', payload.subject);
  console.log('payload.chunks.length:', payload.chunks.length);

  setUploadLoading(true);

  try {
    const result = await apiRequest('/admin/upload', {
      method: 'POST',
      auth: true,
      body: JSON.stringify(payload),
    });

    if (result.success) {
      const addedCount = result.chunkCount || result.chunksCreated || result.chunks?.length || payload.chunks.length;
      showToast(`Success! Added ${addedCount} chunks to knowledge base for ${subject} Unit ${unit}.`, 'success');
      clearUploadForm();
      await loadDocuments();
    } else {
      throw new Error(result.message || result.error || 'Upload failed');
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
    const sitesQuery = (state.trustedWebsites || []).map((s) => s.url).join(',');
    const result = await apiRequest(`/search?q=${encoded}&sites=${encodeURIComponent(sitesQuery)}`);

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

    // Partition results into D1 academic knowledge vs live portal web results
    const d1Chunks = results.filter((r) => !r.url);
    const webItems = results.filter((r) => !!r.url);

    let html = '';

    // Section 1: Permanent D1 Knowledge Chunks
    if (d1Chunks.length > 0) {
      html += `
        <div style="margin-bottom: 1rem;">
          <div style="font-size: 0.8rem; font-weight: 700; color: var(--accent); margin-bottom: 0.5rem; display: flex; align-items: center; gap: 6px;">
            <span>📚 Verified D1 Academic Knowledge</span>
            <span class="badge-accent" style="font-size: 0.68rem;">${d1Chunks.length} Chunk(s)</span>
          </div>
          ${d1Chunks
            .map(
              (r, i) => `
              <div class="retrieved-chunk-card" style="margin-bottom: 0.5rem;">
                <div class="retrieved-chunk-meta">
                  <span>#${i + 1} ${escapeHtml(r.subject || 'Academic')} • Unit ${r.unit || '—'}</span>
                  <span>${escapeHtml(r.title || '')}</span>
                </div>
                <div style="white-space: pre-wrap; font-family: var(--font-mono); font-size: 0.76rem; color: var(--text-secondary);">
                  ${escapeHtml(r.content || '')}
                </div>
              </div>
            `
            )
            .join('')}
        </div>
      `;
    }

    // Section 2: External Web / Portal Results (Only if Web Access is enabled)
    if (webItems.length > 0) {
      if (state.webAccessEnabled) {
        html += `
          <div>
            <div style="font-size: 0.8rem; font-weight: 700; color: #38bdf8; margin-bottom: 0.5rem; display: flex; align-items: center; gap: 6px;">
              <span>🌐 Live Web / Official Portal (External — Not Saved in D1)</span>
              <span class="badge-info" style="font-size: 0.68rem;">${webItems.length} Result(s)</span>
            </div>
            ${webItems
              .map(
                (r, i) => `
                <div class="retrieved-chunk-card" style="border-left: 3px solid #38bdf8; margin-bottom: 0.5rem;">
                  <div class="retrieved-chunk-meta">
                    <span style="color: #38bdf8;">🌐 ${escapeHtml(r.source || 'Portal Notice')}</span>
                    <a href="${escapeHtml(r.url || '#')}" target="_blank" rel="noopener noreferrer" style="color: var(--accent); font-size: 0.72rem; text-decoration: none;">View Portal ↗</a>
                  </div>
                  <div style="font-weight: 600; font-size: 0.82rem; color: var(--text-main); margin-bottom: 4px;">
                    ${escapeHtml(r.title || 'Official Notice')}
                  </div>
                  <div style="white-space: pre-wrap; font-family: var(--font-mono); font-size: 0.76rem; color: var(--text-secondary);">
                    ${escapeHtml(r.content || r.snippet || '')}
                  </div>
                </div>
              `
              )
              .join('')}
          </div>
        `;
      } else {
        html += `
          <div style="padding: 0.75rem 1rem; background: var(--bg-surface); border-radius: var(--radius-sm); border: 1px dashed var(--border-color); font-size: 0.75rem; color: var(--text-muted); margin-top: 0.5rem;">
            ℹ️ Live Web Search is currently <strong>Disabled</strong> in Admin controls. ${webItems.length} portal result(s) omitted to keep results strictly local.
          </div>
        `;
      }
    }

    if (!html) {
      elements.testResultsList.innerHTML = `
        <div class="table-empty">
          No matching knowledge found for "${escapeHtml(q)}".
        </div>
      `;
      return;
    }

    elements.testResultsList.innerHTML = html;
  } catch (err) {
    elements.testResultsList.innerHTML = `<div class="table-loading" style="color: var(--error)">Search Error: ${err.message}</div>`;
  }
}

// ---------------------------------------------------------------------------
// Web Access Controls
// ---------------------------------------------------------------------------
function initWebAccessState() {
  if (elements.webAccessToggle) {
    elements.webAccessToggle.checked = state.webAccessEnabled;
  }
  if (elements.officialUrlInput) {
    elements.officialUrlInput.value = state.officialWebsiteUrl;
  }
  renderTrustedWebsites();
  // Fetch remote portals from Worker in background to synchronize
  fetchRemoteTrustedWebsites();
}

function toggleWebAccess() {
  state.webAccessEnabled = elements.webAccessToggle.checked;
  localStorage.setItem(STORAGE_KEYS.WEB_ACCESS, state.webAccessEnabled ? 'true' : 'false');
  showToast(
    state.webAccessEnabled
      ? 'Web Access enabled — portal results across all configured sites will be included in searches.'
      : 'Web Access disabled — only D1 knowledge base results will be shown.',
    'info'
  );
}

async function testWebAccess() {
  const statusEl = elements.webAccessStatus;
  statusEl.className = 'control-status testing';
  statusEl.querySelector('.status-text').textContent = 'Testing portals...';

  elements.webTestResults.style.display = 'none';

  try {
    const sitesQuery = (state.trustedWebsites || []).map((s) => s.url).join(',');
    const result = await apiRequest(`/search?q=bvc+college+notifications&sites=${encodeURIComponent(sitesQuery)}`);
    const results = result.results || [];

    // Check if any result has a URL (web results have urls, D1 chunks don't)
    const webResults = results.filter((r) => r.url || r.source);

    if (webResults.length > 0) {
      statusEl.className = 'control-status success';
      statusEl.querySelector('.status-text').textContent = `Connected — ${webResults.length} portal result(s) across sites`;

      elements.webTestResults.style.display = 'block';
      elements.webTestCount.textContent = `${webResults.length} results`;
      elements.webTestList.innerHTML = webResults
        .map((r) => `
          <div class="web-result-item">
            <div class="result-title">${escapeHtml(r.title || 'Untitled')}</div>
            <div class="result-source">${escapeHtml(r.url || r.source || '')}</div>
            ${r.snippet || r.content ? `<div class="result-snippet">${escapeHtml((r.snippet || r.content || '').substring(0, 200))}...</div>` : ''}
          </div>
        `)
        .join('');
    } else if (results.length > 0) {
      statusEl.className = 'control-status success';
      statusEl.querySelector('.status-text').textContent = 'Connected — D1 results only (no portal notices)';
    } else {
      statusEl.className = 'control-status error';
      statusEl.querySelector('.status-text').textContent = 'No results returned';
    }
  } catch (err) {
    statusEl.className = 'control-status error';
    statusEl.querySelector('.status-text').textContent = `Error: ${err.message}`;
  }
}

// ---------------------------------------------------------------------------
// Multi-Website & Trusted Portals Management
// ---------------------------------------------------------------------------
function saveTrustedWebsites() {
  localStorage.setItem(STORAGE_KEYS.TRUSTED_WEBSITES, JSON.stringify(state.trustedWebsites));
  if (state.trustedWebsites.length > 0) {
    state.officialWebsiteUrl = state.trustedWebsites[0].url;
    localStorage.setItem(STORAGE_KEYS.OFFICIAL_WEBSITE, state.officialWebsiteUrl);
  }
}

function renderTrustedWebsites() {
  if (!elements.trustedSitesList) return;

  const sites = state.trustedWebsites || [];
  if (elements.sitesCountBadge) {
    elements.sitesCountBadge.textContent = `${sites.length} Active ${sites.length === 1 ? 'Site' : 'Sites'}`;
  }

  if (sites.length === 0) {
    elements.trustedSitesList.innerHTML = `
      <div class="empty-sites-placeholder">
        No trusted websites configured. Add a website or select a preset above to enable AI web grounding.
      </div>
    `;
    return;
  }

  elements.trustedSitesList.innerHTML = sites
    .map((s, idx) => {
      const isVerified = s.verified === true;
      const statusClass = isVerified ? 'verified' : 'unverified';
      const statusText = isVerified ? 'Verified' : 'Active';
      const fullUrl = s.url.startsWith('http') ? s.url : `https://${s.url}`;

      return `
        <div class="site-item-card" data-index="${idx}" data-url="${escapeHtml(s.url)}">
          <div class="site-item-info">
            <div class="site-item-icon">
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <circle cx="12" cy="12" r="10"></circle>
                <line x1="2" y1="12" x2="22" y2="12"></line>
                <path d="M12 2a15.3 15.3 0 0 1 4 10 15.3 15.3 0 0 1-4 10 15.3 15.3 0 0 1-4-10 15.3 15.3 0 0 1 4-10z"></path>
              </svg>
            </div>
            <div class="site-item-details">
              <div class="site-item-domain-row">
                <a href="${escapeHtml(fullUrl)}" target="_blank" rel="noopener noreferrer" class="site-item-domain" title="Open website in new tab">
                  ${escapeHtml(s.url)}
                </a>
                <span class="site-status-pill ${statusClass}" id="sitePill-${idx}">
                  ${isVerified ? '✓ ' : ''}${statusText}
                </span>
              </div>
              <div class="site-item-label">${escapeHtml(s.label || s.url)}</div>
            </div>
          </div>
          <div class="site-item-actions">
            <button type="button" class="site-action-btn verify-single-btn" data-url="${escapeHtml(s.url)}" data-index="${idx}" title="Check reachability">
              <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"></path>
                <polyline points="22 4 12 14.01 9 11.01"></polyline>
              </svg>
              Verify
            </button>
            <button type="button" class="site-action-btn delete-btn delete-site-btn" data-url="${escapeHtml(s.url)}" title="Remove website">
              <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <polyline points="3 6 5 6 21 6"></polyline>
                <path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"></path>
              </svg>
              Delete
            </button>
          </div>
        </div>
      `;
    })
    .join('');

  // Attach dynamic row events
  elements.trustedSitesList.querySelectorAll('.delete-site-btn').forEach((btn) => {
    btn.addEventListener('click', (e) => {
      e.stopPropagation();
      const url = btn.getAttribute('data-url');
      if (url) removeTrustedWebsite(url);
    });
  });

  elements.trustedSitesList.querySelectorAll('.verify-single-btn').forEach((btn) => {
    btn.addEventListener('click', (e) => {
      e.stopPropagation();
      const url = btn.getAttribute('data-url');
      const idx = parseInt(btn.getAttribute('data-index'), 10);
      if (url) verifySingleWebsite(url, idx);
    });
  });
}

async function addTrustedWebsite(rawUrl, rawLabel = '') {
  if (!rawUrl) {
    showToast('Please enter a website URL.', 'error');
    return false;
  }

  // Sanitize and clean URL
  const cleanUrl = rawUrl.trim().replace(/^https?:\/\//i, '').replace(/\/+$/, '');
  if (!cleanUrl || cleanUrl.includes(' ') || !cleanUrl.includes('.')) {
    showToast('Invalid website format. Please enter a valid domain (e.g. bvcec.edu.in).', 'error');
    return false;
  }

  // Prevent duplicate additions
  const exists = state.trustedWebsites.some((s) => s.url.toLowerCase() === cleanUrl.toLowerCase());
  if (exists) {
    showToast(`Website "${cleanUrl}" is already in your trusted list.`, 'info');
    return false;
  }

  const label = (rawLabel || '').trim() || cleanUrl;
  const newSite = { url: cleanUrl, label, verified: false };
  state.trustedWebsites.push(newSite);
  saveTrustedWebsites();
  renderTrustedWebsites();

  showToast(`Added trusted portal: https://${cleanUrl}`, 'success');

  // Clear inputs
  if (elements.newSiteUrlInput) elements.newSiteUrlInput.value = '';
  if (elements.newSiteLabelInput) elements.newSiteLabelInput.value = '';

  // Auto-sync with backend in background
  syncSitesWithBackend(false);
  return true;
}

async function removeTrustedWebsite(urlToRemove) {
  const prevCount = state.trustedWebsites.length;
  state.trustedWebsites = state.trustedWebsites.filter(
    (s) => s.url.toLowerCase() !== urlToRemove.toLowerCase()
  );

  if (state.trustedWebsites.length < prevCount) {
    saveTrustedWebsites();
    renderTrustedWebsites();
    showToast(`Removed trusted website: ${urlToRemove}`, 'info');

    // Notify backend
    try {
      await apiRequest(`/admin/sites?url=${encodeURIComponent(urlToRemove)}`, {
        method: 'DELETE',
      });
    } catch (_) {
      // Best-effort backend deletion
    }
  }
}

async function verifySingleWebsite(url, idx) {
  const pill = document.getElementById(`sitePill-${idx}`);
  if (pill) {
    pill.className = 'site-status-pill testing';
    pill.textContent = 'Checking...';
  }

  try {
    // Check reachability via search endpoint
    const res = await apiRequest(`/search?q=${encodeURIComponent(url)}&sites=${encodeURIComponent(url)}`);
    const site = state.trustedWebsites.find((s) => s.url.toLowerCase() === url.toLowerCase());
    if (site) {
      site.verified = true;
      saveTrustedWebsites();
    }
    if (pill) {
      pill.className = 'site-status-pill verified';
      pill.textContent = '✓ Verified';
    }
    showToast(`✅ Verified: https://${url} is reachable by AI scraper.`, 'success');
  } catch (err) {
    if (pill) {
      pill.className = 'site-status-pill unverified';
      pill.textContent = 'Reachable';
    }
    showToast(`Site check: ${url} (${err.message})`, 'info');
  }
}

async function verifyAllWebsites() {
  if (state.trustedWebsites.length === 0) {
    showToast('No trusted websites to verify.', 'info');
    return;
  }

  showToast(`Verifying ${state.trustedWebsites.length} configured portal(s)...`, 'info');
  for (let i = 0; i < state.trustedWebsites.length; i++) {
    const s = state.trustedWebsites[i];
    await verifySingleWebsite(s.url, i);
  }
  showToast('All website verifications complete!', 'success');
}

async function syncSitesWithBackend(showNotification = true) {
  const statusBox = elements.sitesStatusBox;
  const statusText = elements.sitesStatusText;
  if (statusBox) statusBox.className = 'control-status testing';
  if (statusText) statusText.textContent = 'Syncing...';

  try {
    const resp = await apiRequest('/admin/sites', {
      method: 'POST',
      body: JSON.stringify({ sites: state.trustedWebsites }),
    });

    if (resp && resp.success) {
      if (statusBox) statusBox.className = 'control-status success';
      if (statusText) statusText.textContent = `Synced (${state.trustedWebsites.length} Portals)`;
      if (showNotification) {
        showToast(`✅ Synced ${state.trustedWebsites.length} trusted portals with Cloudflare AI Worker!`, 'success');
      }
    } else {
      throw new Error(resp?.message || 'Sync failed');
    }
  } catch (err) {
    if (statusBox) statusBox.className = 'control-status error';
    if (statusText) statusText.textContent = 'Sync Error';
    if (showNotification) {
      showToast(`Sync with AI backend notice: ${err.message}`, 'error');
    }
  }
}

async function fetchRemoteTrustedWebsites() {
  try {
    const resp = await apiRequest('/admin/sites');
    if (resp && resp.success && Array.isArray(resp.sites) && resp.sites.length > 0) {
      // Merge remote sites into local list
      let changed = false;
      for (const rSite of resp.sites) {
        if (!state.trustedWebsites.some((s) => s.url.toLowerCase() === rSite.url.toLowerCase())) {
          state.trustedWebsites.push({
            url: rSite.url,
            label: rSite.label || rSite.url,
            verified: true,
          });
          changed = true;
        }
      }
      if (changed) {
        saveTrustedWebsites();
        renderTrustedWebsites();
      }
      if (elements.sitesStatusBox) elements.sitesStatusBox.className = 'control-status success';
      if (elements.sitesStatusText) {
        elements.sitesStatusText.textContent = `Active & Ready (${state.trustedWebsites.length} Portals)`;
      }
    }
  } catch (_) {
    // Offline or D1 table not yet initialized; local state remains active
  }
}

// Backwards compatibility wrappers
function showVerifiedBadge(url) {
  if (elements.verifiedBadgeBox) elements.verifiedBadgeBox.style.display = 'flex';
  if (elements.verifiedUrlDisplay) elements.verifiedUrlDisplay.textContent = `https://${url}`;
}

function hideVerifiedBadge() {
  if (elements.verifiedBadgeBox) elements.verifiedBadgeBox.style.display = 'none';
}

async function verifyOfficialWebsite() {
  const rawUrl = (elements.officialUrlInput?.value || '').trim();
  if (rawUrl) {
    await addTrustedWebsite(rawUrl);
    await verifyAllWebsites();
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

  // Web Access Events
  if (elements.webAccessToggle) {
    elements.webAccessToggle.addEventListener('change', toggleWebAccess);
  }
  if (elements.testWebAccessBtn) {
    elements.testWebAccessBtn.addEventListener('click', testWebAccess);
  }

  // Official Website & Multi-Website Events
  if (elements.verifyWebsiteBtn) {
    elements.verifyWebsiteBtn.addEventListener('click', verifyOfficialWebsite);
  }
  if (elements.addSiteBtn) {
    elements.addSiteBtn.addEventListener('click', () => {
      const url = elements.newSiteUrlInput ? elements.newSiteUrlInput.value : '';
      const label = elements.newSiteLabelInput ? elements.newSiteLabelInput.value : '';
      addTrustedWebsite(url, label);
    });
  }
  if (elements.newSiteUrlInput) {
    elements.newSiteUrlInput.addEventListener('keydown', (e) => {
      if (e.key === 'Enter') {
        const url = elements.newSiteUrlInput.value;
        const label = elements.newSiteLabelInput ? elements.newSiteLabelInput.value : '';
        addTrustedWebsite(url, label);
      }
    });
  }
  if (elements.verifyAllSitesBtn) {
    elements.verifyAllSitesBtn.addEventListener('click', verifyAllWebsites);
  }
  if (elements.syncSitesBtn) {
    elements.syncSitesBtn.addEventListener('click', () => syncSitesWithBackend(true));
  }

  // Quick preset chips
  document.querySelectorAll('.preset-chip').forEach((chip) => {
    chip.addEventListener('click', () => {
      const url = chip.getAttribute('data-url');
      const label = chip.getAttribute('data-label');
      if (url) addTrustedWebsite(url, label);
    });
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
  initWebAccessState();
  checkWorkerHealth();
  loadDocuments();
});

// ---------------------------------------------------------------------------
// Phase N: Smart Notifications & Result Ingestion Handlers
// ---------------------------------------------------------------------------

function switchAdminTab(tab) {
  const kTab = document.getElementById('knowledgeTabContent');
  const nTab = document.getElementById('notificationsTabContent');
  const kBtn = document.getElementById('tabBtnKnowledge');
  const nBtn = document.getElementById('tabBtnNotifications');

  if (tab === 'notifications') {
    if (kTab) kTab.style.display = 'none';
    if (nTab) nTab.style.display = 'block';
    if (kBtn) kBtn.classList.remove('active');
    if (nBtn) nBtn.classList.add('active');
    loadNotificationStats();
  } else {
    if (kTab) kTab.style.display = 'block';
    if (nTab) nTab.style.display = 'none';
    if (kBtn) kBtn.classList.add('active');
    if (nBtn) nBtn.classList.remove('active');
  }
}

async function loadNotificationStats() {
  try {
    const res = await fetch(`${state.apiUrl}/admin/notifications/stats`, {
      headers: {
        'Authorization': `Bearer ${state.adminSecret}`,
        'X-Admin-Key': state.adminSecret,
      }
    });
    if (res.ok) {
      const data = await res.json();
      if (data.stats) {
        document.getElementById('statNotifTotal').textContent = data.stats.total_notifications ?? 0;
        document.getElementById('statNotifToday').textContent = data.stats.sent_today ?? 0;
        document.getElementById('statActiveDevices').textContent = data.stats.active_devices ?? 0;
        document.getElementById('statUnreadNotifs').textContent = data.stats.unread_notifications ?? 0;
      }
    }
  } catch (err) {
    console.warn('[Admin] Failed to load notification stats:', err);
  }
}

// Result Ingestion Sample Loader
document.addEventListener('DOMContentLoaded', () => {
  const loadSampleBtn = document.getElementById('loadSampleResultsBtn');
  if (loadSampleBtn) {
    loadSampleBtn.addEventListener('click', () => {
      const sample = [
        {
          "roll_number": "25221A0569",
          "semester": 2,
          "subject_code": "CS201",
          "subject_name": "Data Structures",
          "grade": "A+",
          "credits": 3,
          "grade_points": 10,
          "sgpa": 8.5,
          "status": "PASS",
          "exam_month_year": "MAY 2026"
        },
        {
          "roll_number": "25221A0570",
          "semester": 2,
          "subject_code": "CS201",
          "subject_name": "Data Structures",
          "grade": "A",
          "credits": 3,
          "grade_points": 9,
          "sgpa": 8.0,
          "status": "PASS",
          "exam_month_year": "MAY 2026"
        }
      ];
      document.getElementById('resultJsonInput').value = JSON.stringify(sample, null, 2);
    });
  }

  // Handle Result Upload Button
  const uploadResultsBtn = document.getElementById('uploadResultsBtn');
  if (uploadResultsBtn) {
    uploadResultsBtn.addEventListener('click', async () => {
      const rawJson = document.getElementById('resultJsonInput').value.trim();
      if (!rawJson) {
        alert('Please paste or load result JSON records.');
        return;
      }

      let parsed;
      try {
        parsed = JSON.parse(rawJson);
      } catch (e) {
        alert('Invalid JSON format: ' + e.message);
        return;
      }

      const records = Array.isArray(parsed) ? parsed : (parsed.records || []);
      if (records.length === 0) {
        alert('No result records found in JSON.');
        return;
      }

      uploadResultsBtn.disabled = true;
      uploadResultsBtn.textContent = 'Ingesting & Matching...';

      try {
        const res = await fetch(`${state.apiUrl}/admin/results/upload`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${state.adminSecret}`,
            'X-Admin-Key': state.adminSecret,
          },
          body: JSON.stringify({ records })
        });

        const data = await res.json();
        const reportBox = document.getElementById('resultReportBox');
        const metricsBox = document.getElementById('reportMetrics');
        const detailsBox = document.getElementById('reportDetails');

        if (data.success && data.report) {
          const r = data.report;
          reportBox.style.display = 'block';
          metricsBox.innerHTML = `
            <div class="report-metric-item"><div class="report-metric-num">${r.total_processed}</div><div class="report-metric-label">Processed</div></div>
            <div class="report-metric-item"><div class="report-metric-num" style="color:#10B981">${r.matched_students}</div><div class="report-metric-label">Matched Profiles</div></div>
            <div class="report-metric-item"><div class="report-metric-num" style="color:#6366F1">${r.notifications_queued}</div><div class="report-metric-label">Notifs Queued</div></div>
            <div class="report-metric-item"><div class="report-metric-num" style="color:#F59E0B">${r.unmatched_roll_numbers?.length || 0}</div><div class="report-metric-label">Unmatched</div></div>
            <div class="report-metric-item"><div class="report-metric-num" style="color:#94A3B8">${r.duplicates_skipped}</div><div class="report-metric-label">Duplicates Skipped</div></div>
          `;

          let detailsHtml = `<strong>Matched Students:</strong><br/>`;
          if (r.matched_profiles && r.matched_profiles.length > 0) {
            detailsHtml += r.matched_profiles.map(p => `• ${p.roll_number} (${p.name || 'Verified Student'} - ${p.branch || 'B.Tech'})`).join('<br/>');
          } else {
            detailsHtml += `None (No registered students found matching these roll numbers)<br/>`;
          }

          if (r.unmatched_roll_numbers && r.unmatched_roll_numbers.length > 0) {
            detailsHtml += `<br/><strong>Unmatched Roll Numbers (Saved in D1 Authoritative Store):</strong><br/>` +
              r.unmatched_roll_numbers.join(', ');
          }

          detailsBox.innerHTML = detailsHtml;
          loadNotificationStats();
        } else {
          alert('Upload failed: ' + (data.message || data.error));
        }
      } catch (err) {
        alert('Network error during result upload: ' + err.message);
      } finally {
        uploadResultsBtn.disabled = false;
        uploadResultsBtn.innerHTML = '<span class="icon">🚀</span> Ingest & Auto-Notify Students';
      }
    });
  }

  // Handle Target Scope changes
  const scopeSelect = document.getElementById('notifScopeSelect');
  const scopeFilterRow = document.getElementById('scopeFilterRow');
  const scopeBranchGroup = document.getElementById('scopeBranchGroup');
  const scopeYearGroup = document.getElementById('scopeYearGroup');

  if (scopeSelect) {
    scopeSelect.addEventListener('change', () => {
      const val = scopeSelect.value;
      if (val === 'BRANCH') {
        scopeFilterRow.style.display = 'flex';
        scopeBranchGroup.style.display = 'block';
        scopeYearGroup.style.display = 'none';
      } else if (val === 'YEAR') {
        scopeFilterRow.style.display = 'flex';
        scopeBranchGroup.style.display = 'none';
        scopeYearGroup.style.display = 'block';
      } else if (val === 'BRANCH_YEAR') {
        scopeFilterRow.style.display = 'flex';
        scopeBranchGroup.style.display = 'block';
        scopeYearGroup.style.display = 'block';
      } else {
        scopeFilterRow.style.display = 'none';
      }
    });
  }

  // Handle Send Broadcast Button
  const sendBroadcastBtn = document.getElementById('sendBroadcastBtn');
  if (sendBroadcastBtn) {
    sendBroadcastBtn.addEventListener('click', async () => {
      const title = document.getElementById('notifTitleInput').value.trim();
      const message = document.getElementById('notifBodyInput').value.trim();
      const type = document.getElementById('notifTypeSelect').value;
      const scope = document.getElementById('notifScopeSelect').value;
      const branch = document.getElementById('scopeBranchSelect').value;
      const year = document.getElementById('scopeYearSelect').value;
      const statusDiv = document.getElementById('broadcastStatusMsg');

      if (!title || !message) {
        alert('Please provide a title and message.');
        return;
      }

      sendBroadcastBtn.disabled = true;
      sendBroadcastBtn.textContent = 'Sending Broadcast...';
      statusDiv.innerHTML = '';

      try {
        const res = await fetch(`${state.apiUrl}/admin/notifications/send`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${state.adminSecret}`,
            'X-Admin-Key': state.adminSecret,
          },
          body: JSON.stringify({
            title,
            message,
            type,
            scope,
            branch: (scope === 'BRANCH' || scope === 'BRANCH_YEAR') ? branch : null,
            year: (scope === 'YEAR' || scope === 'BRANCH_YEAR') ? year : null,
          })
        });

        const data = await res.json();
        if (data.success) {
          statusDiv.innerHTML = `<span style="color:#10B981;font-weight:600;">✓ Broadcast dispatched! Targets resolved: ${data.targets_resolved}, Queued: ${data.notifications_queued}, Duplicates skipped: ${data.duplicates_skipped}.</span>`;
          document.getElementById('notifTitleInput').value = '';
          document.getElementById('notifBodyInput').value = '';
          loadNotificationStats();
        } else {
          statusDiv.innerHTML = `<span style="color:#EF4444;font-weight:600;">Failed: ${data.message || data.error}</span>`;
        }
      } catch (err) {
        statusDiv.innerHTML = `<span style="color:#EF4444;">Network error: ${err.message}</span>`;
      } finally {
        sendBroadcastBtn.disabled = false;
        sendBroadcastBtn.innerHTML = '<span class="icon">📤</span> Send Broadcast Notification';
      }
    });
  }
});
