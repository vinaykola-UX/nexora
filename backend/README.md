# Nexora Backend Foundation

This directory contains the initial backend foundation for Nexora.

## Current status

This is the Phase 1 foundation layer only. It includes:

- Express API server
- health endpoint
- environment configuration
- database schema foundation for users, documents, conversations, and messages
- Cloudflare R2 storage abstraction
- basic route scaffolding for future integration

This does not include:

- production authentication
- RAG pipeline
- embedding/vector storage
- LLM integration
- real file uploads
- Firebase initialization

## Scripts

```bash
npm install
npm run dev
```

Then visit:

- http://localhost:3000/health
