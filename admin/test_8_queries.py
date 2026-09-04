#!/usr/bin/env python3
import sys, io
if sys.platform == "win32":
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8', errors='replace')

import requests, json

BASE_URL = "https://nexora-bvc-api-2026.vkola306.workers.dev"

QUERIES = [
    # Casual 1-5
    "hi",
    "hello",
    "hey",
    "thanks",
    "how are you",
    # Academic 6-8
    "what is a singly linked list?",
    "explain linear probing",
    "what is Java inheritance?",
]

def main():
    print("=" * 80)
    print("NEXORA AI — VERIFYING 8 USER QUERIES AGAINST LIVE /chat")
    print("=" * 80)
    
    session = requests.Session()
    session.headers.update({
        "Content-Type": "application/json",
        "User-Agent": "Nexora-Verification-Suite/1.0"
    })
    
    for idx, q in enumerate(QUERIES, 1):
        print(f"\n[{idx}/8] USER: {q}")
        try:
            r = session.post(f"{BASE_URL}/chat", json={"message": q, "debug": True}, timeout=30)
            if r.status_code == 200:
                data = r.json()
                answer = data.get("answer", "")
                sources = data.get("sources", [])
                debug = data.get("debug", {})
                
                print(f"  Status Code: {r.status_code}")
                print(f"  Intent: {debug.get('detectedIntent')}")
                print(f"  RAG Pipeline: {debug.get('adsPipelineStatus')}")
                print(f"  Retrieved Chunks: {debug.get('retrievedChunkCount')}")
                print(f"  Sources: {len(sources)} sources")
                print(f"  ASSISTANT ANSWER:")
                print(f"    {answer}")
                
                # Check for raw syllabus leak
                has_leak = "SUBJECT:" in answer or "UNIT:" in answer or "TOPIC:" in answer or "SINGLY LINKED LIST  A singly" in answer
                if has_leak:
                    print(f"  ⚠️ WARNING: Raw syllabus leak detected!")
                else:
                    print(f"  ✅ Clean natural response (no raw chunk leak)")
            else:
                print(f"  Error: HTTP {r.status_code} - {r.text}")
        except Exception as e:
            print(f"  Exception: {e}")

if __name__ == "__main__":
    main()
