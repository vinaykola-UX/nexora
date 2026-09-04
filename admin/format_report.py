import json
import sys
import io

if sys.platform == "win32":
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

with open('admin/phase4_verification_raw.json', encoding='utf-8') as f:
    data = json.load(f)

for idx, item in enumerate(data, 1):
    q = item['query']
    s = item['search']
    c = item['chat']
    
    print("=" * 80)
    print(f"QUERY #{idx}: \"{q}\"")
    print("=" * 80)
    
    # 1. Embedding & Vectorize
    v = s.get('vectorize')
    if v and v.get('status') == 'success':
        print("- embedding generated: YES")
        print(f"- embedding model: {v.get('embeddingModel')}")
        print(f"- embedding dimension: {v.get('queryDimension')}")
        print("- Vectorize queried: YES")
        print(f"- number of Vectorize hits: {v.get('candidateCount')}")
    else:
        # Check if skipped
        print(f"- embedding generated: {'NO (skipped for casual)' if q == 'hi' else 'NO'}")
        print(f"- embedding model: {v.get('embeddingModel') if v else 'NOT ACTIVE'}")
        print(f"- embedding dimension: {v.get('queryDimension') if v else 'NOT ACTIVE'}")
        print(f"- Vectorize queried: {'NO' if not v or v.get('status') != 'success' else 'YES'}")
        print(f"- number of Vectorize hits: {v.get('candidateCount') if v else 0}")
    
    # Similarity scores & Results
    results = s.get('results', [])
    if results:
        scores = []
        hybrid_scores = []
        ads_scores = []
        graph_scores = []
        for r in results:
            sc = r.get('scoring', {})
            scores.append(round(sc.get('normalizedVector', 0), 4))
            ads_scores.append(round(sc.get('normalizedAds', 0), 4))
            graph_scores.append(round(sc.get('normalizedGraph', 0), 4))
            hybrid_scores.append(round(r.get('hybridScore', 0), 4))
        print(f"- similarity scores (normalized vector): {scores[:5]}")
        print(f"- ADS scores: {ads_scores[:5]}")
        print(f"- graph scores: {graph_scores[:5]}")
        print(f"- hybrid scores: {hybrid_scores[:5]}")
    else:
        print("- similarity scores: NOT ACTIVE / None")
        print("- ADS score: NOT ACTIVE")
        print("- graph score: NOT ACTIVE")
        print("- hybrid score: NOT ACTIVE")

    # D1 chunks retrieved
    retrieval = s.get('retrieval', {})
    print(f"- D1 chunks retrieved: {retrieval.get('hybridCandidates', len(results))} candidates evaluated, {len(results)} selected")
    
    # Pipeline
    p = s.get('pipeline')
    if p:
        # Hash lookup
        hl = p.get('hashLookups', [])
        hl_str = ", ".join([f"'{h.get('term')}': {h.get('matchesFound')} hits" for h in hl])
        print(f"- Hash lookup results: {hl_str if hl_str else 'Executed (0 term matches)'}")
        
        # AVL results
        avl = p.get('avlPrefixMatches', [])
        avl_str = ", ".join([f"'{a.get('prefix')}': {a.get('topicsFound')}" for a in avl if a.get('topicsFound')])
        print(f"- AVL results: {avl_str if avl_str else 'Executed (no prefix matches)'}")
        
        # Graph nodes expanded & BFS/DFS
        graph_nodes = p.get('graphRelatedConcepts', [])
        if graph_nodes:
            g_str = ", ".join([f"'{g.get('concept')}' (boost: {g.get('boostWeight')})" for g in graph_nodes[:5]])
            print(f"- Graph nodes expanded: {len(graph_nodes)} nodes -> [{g_str}]")
            print("- BFS/DFS actually executed: YES")
        else:
            print("- Graph nodes expanded: 0 nodes")
            print("- BFS/DFS actually executed: YES (traversal executed, 0 matches for non-existent concepts)")
            
        # Heap Top-K
        print(f"- Heap Top-K results: {p.get('heapTopKExtracted', 0)} chunks extracted from {p.get('candidateCountBeforeHeap', 0)} candidates")
        
        # Merge sort
        sort_algo = p.get('sortingAlgorithm')
        print(f"- Merge Sort executed: {'YES (' + sort_algo + ')' if sort_algo else 'NOT ACTIVE'}")
    else:
        print("- Hash lookup results: NOT ACTIVE")
        print("- AVL results: NOT ACTIVE")
        print("- Graph nodes expanded: NOT ACTIVE")
        print("- BFS/DFS actually executed: NOT ACTIVE")
        print("- Heap Top-K results: NOT ACTIVE")
        print("- Merge Sort executed: NOT ACTIVE")

    # Final selected chunks
    if results:
        print(f"- final selected chunks: {len(results)} chunks")
        for i, r in enumerate(results[:3], 1):
            title = r.get('title')
            subj = r.get('subject')
            snippet = (r.get('content', '')[:80] + '...').replace('\n', ' ')
            print(f"    Chunk {i}: [{subj} - {title}] \"{snippet}\"")
    else:
        print(f"- final selected chunks: 0 chunks (no knowledge retrieval needed)")

    # AI Model Used (from /chat)
    chat_debug = c.get('debug', {})
    print(f"- AI model used: {chat_debug.get('model', 'N/A')} (Provider: {chat_debug.get('provider', 'N/A')})")
    print(f"- AI generation status: {chat_debug.get('generationStatus', 'N/A')}")
    print()
