#!/usr/bin/env python3
"""
Phase 4 Production Verification Script
Tests the live production /search and /chat endpoints with debug=true
Queries:
 1. "How does inheritance work in Java?"
 2. "How does a linked list connect its nodes?"
 3. "What is linear probing in hashing?"
 4. "What is the difference between singly and doubly linked lists?"
 5. "hi"
"""

import sys
import io
if sys.platform == "win32":
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8', errors='replace')

import requests
import json
import time

BASE_URL = "https://nexora-bvc-api-2026.vkola306.workers.dev"

QUERIES = [
    "How does inheritance work in Java?",
    "How does a linked list connect its nodes?",
    "What is linear probing in hashing?",
    "What is the difference between singly and doubly linked lists?",
    "hi",
]

def create_session():
    s = requests.Session()
    s.headers.update({
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        "Accept": "application/json",
    })
    return s

def verify_all():
    session = create_session()
    print(f"Connecting to {BASE_URL}...\n")
    
    # 1. Check health
    try:
        r_health = session.get(f"{BASE_URL}/health", timeout=30)
        print(f"Health: {r_health.json()}\n")
    except Exception as e:
        print(f"Health check failed: {e}\n")
    
    # 2. Check D1 documents count
    try:
        r_docs = session.get(f"{BASE_URL}/documents", timeout=30)
        docs = r_docs.json()
        print(f"D1 Documents: {len(docs)} documents registered\n")
    except Exception as e:
        print(f"Docs check failed: {e}\n")
    
    report_data = []

    for q in QUERIES:
        print(f"============================================================")
        print(f"TESTING QUERY: '{q}'")
        print(f"============================================================")
        
        # Test /search
        search_data = {}
        search_time = 0
        for attempt in range(3):
            t0 = time.time()
            try:
                r_search = session.get(f"{BASE_URL}/search", params={"q": q, "debug": "true"}, timeout=60)
                search_time = round((time.time() - t0) * 1000)
                if r_search.status_code == 200:
                    search_data = r_search.json()
                    break
                else:
                    search_data = {"status_code": r_search.status_code, "text": r_search.text}
            except Exception as e:
                search_data = {"error": str(e)}
                time.sleep(2)
        
        # Test /chat
        chat_data = {}
        chat_time = 0
        for attempt in range(3):
            t1 = time.time()
            try:
                r_chat = session.post(f"{BASE_URL}/chat", json={"message": q, "debug": True}, timeout=60)
                chat_time = round((time.time() - t1) * 1000)
                if r_chat.status_code == 200:
                    chat_data = r_chat.json()
                    break
                else:
                    chat_data = {"status_code": r_chat.status_code, "text": r_chat.text}
            except Exception as e:
                chat_data = {"error": str(e)}
                time.sleep(2)

        entry = {
            "query": q,
            "search": search_data,
            "search_time_ms": search_time,
            "chat": chat_data,
            "chat_time_ms": chat_time
        }
        report_data.append(entry)
        
        print(f"  /search status: {r_search.status_code if 'r_search' in locals() else 'error'} ({search_time}ms)")
        print(f"  /chat   status: {r_chat.status_code if 'r_chat' in locals() else 'error'} ({chat_time}ms)")
        print()

    # Save complete raw output
    with open("admin/phase4_verification_raw.json", "w", encoding="utf-8") as f:
        json.dump(report_data, f, indent=2, ensure_ascii=False)
        
    print("Verification data captured successfully to admin/phase4_verification_raw.json")

if __name__ == "__main__":
    verify_all()
