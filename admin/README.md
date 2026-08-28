# 📚 Nexora Admin Dashboard — Knowledge Base & RAG Manager

A static web dashboard for managing academic study materials in the Nexora Cloudflare D1 knowledge base.

---

## 🌟 Key Features

1. **Academic Content Upload & Indexing**:
   - Add study notes for any **Subject** and **Unit (1 to 5)**.
   - Attach `.pdf`, `.txt`, or `.md` files.
   - **Client-side PDF text extraction** with PDF.js (no backend PDF parsing or R2 storage needed).
   - Real-time **deterministic chunking preview** (800–1400 character chunks with semantic subject & unit headers).

2. **D1 Knowledge Base Management**:
   - View all indexed documents, units, and chunk counts (`GET /documents`).
   - Inspect chunk details modal (`GET /admin/document/:id`).
   - Secure document & chunk deletion (`DELETE /admin/document/:id`).

3. **Live RAG Retrieval Tester**:
   - Test student queries directly in the dashboard (`GET /search?q=...`) to verify that newly uploaded units are immediately retrievable.

4. **100% Static & Lightweight**:
   - Built with pure HTML5, CSS3, and modern JavaScript.
   - Zero server requirements, no build steps, deployable to **GitHub Pages**, **Cloudflare Pages**, **Vercel**, or **Netlify**.

---

## 🚀 How to Deploy

### Option 1: Cloudflare Pages (Recommended)
1. Go to your [Cloudflare Dashboard](https://dash.cloudflare.com/) > **Workers & Pages** > **Create application** > **Pages**.
2. Connect your GitHub repository (`vinaykola-UX/nexora`).
3. Set the **Build output directory** to `admin`.
4. Click **Save and Deploy**.

### Option 2: GitHub Pages
1. Push this folder to your repository.
2. In your GitHub repo settings, go to **Pages**.
3. Under **Branch**, select `master` and `/admin` (or `/docs`) folder.
4. Your admin portal will be live at `https://<username>.github.io/nexora/admin/`.

### Option 3: Local Use (Instant)
Simply open `index.html` in Google Chrome, Microsoft Edge, or Firefox:
```bash
# Windows
start C:\Users\Admin\Desktop\final nexora\admin\index.html
```

---

## 🔒 Security & Admin Secret Token

- The Admin API is protected by a Bearer token (`Authorization: Bearer ADMIN_SECRET`).
- Default Token configured in Cloudflare Worker: `nexora-admin-secure-key-2026`.
- In the Admin dashboard, click **Settings** (top right) to change the API Base URL or Secret Key. Tokens are persisted safely in the browser's `localStorage`.

---

## 📡 Cloudflare Worker Endpoints

| Method | Endpoint | Description | Auth |
| :--- | :--- | :--- | :--- |
| `GET` | `/health` | Service health status | Public |
| `GET` | `/documents` | List all documents in D1 | Public |
| `GET` | `/search?q=QUERY` | Search D1 chunks across all documents | Public |
| `POST` | `/admin/upload` | Upload & chunk study notes into D1 | `Bearer <ADMIN_SECRET>` |
| `DELETE` | `/admin/document/:id` | Delete document & all associated chunks | `Bearer <ADMIN_SECRET>` |
| `GET` | `/admin/document/:id` | Inspect document & its chunks | `Bearer <ADMIN_SECRET>` |
