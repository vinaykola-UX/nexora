import json
import urllib.request
import urllib.parse
import sys

API_URL = "https://nexora-bvc-api-2026.vkola306.workers.dev"
ADMIN_KEY = "nexora-admin-secure-key-2026"

import time

def request(path, method="GET", body=None, headers=None, retries=3):
    url = f"{API_URL}{path}"
    req_headers = {"User-Agent": "NexoraTest/1.0", "Connection": "close"}
    if headers:
        req_headers.update(headers)
    data = None
    if body is not None:
        data = json.dumps(body).encode("utf-8")
        req_headers["Content-Type"] = "application/json"
    
    for attempt in range(retries):
        try:
            req = urllib.request.Request(url, data=data, headers=req_headers, method=method)
            with urllib.request.urlopen(req, timeout=20) as resp:
                return resp.status, json.loads(resp.read().decode("utf-8"))
        except urllib.error.HTTPError as e:
            err_body = e.read().decode("utf-8")
            try:
                return e.code, json.loads(err_body)
            except:
                return e.code, {"raw": err_body}
        except (urllib.error.URLError, ConnectionResetError) as e:
            if attempt == retries - 1:
                raise
            time.sleep(1.5)

def run_tests():
    print("==================================================")
    print("NEXORA — UNLIMITED WEBSITES & PORTALS VERIFICATION")
    print("==================================================")

    # Test 1: GET /admin/sites
    print("\n[TEST 1] GET /admin/sites")
    status, res = request("/admin/sites")
    print(f"Status: {status}, Success: {res.get('success')}")
    sites = res.get("sites", [])
    print(f"Active Sites Count: {len(sites)}")
    for s in sites:
        print(f"  - {s.get('url')} ({s.get('label')})")
    assert status == 200, f"Expected 200, got {status}"
    assert len(sites) >= 2, "Expected at least 2 default sites"

    # Test 2: POST /admin/sites (Add new website)
    print("\n[TEST 2] POST /admin/sites (Add 'jntuk.edu.in')")
    post_body = {
        "url": "jntuk.edu.in",
        "label": "JNTUK Examination Board"
    }
    status, res = request(
        "/admin/sites",
        method="POST",
        body=post_body,
        headers={"Authorization": f"Bearer {ADMIN_KEY}"}
    )
    print(f"Status: {status}, Success: {res.get('success')}")
    updated_sites = res.get("sites", [])
    print(f"Total sites now: {len(updated_sites)}")
    found_jntuk = any(s.get("url") == "jntuk.edu.in" for s in updated_sites)
    print(f"Found 'jntuk.edu.in' in sites: {found_jntuk}")
    assert found_jntuk, "Expected jntuk.edu.in to be present in sites"

    # Test 3: Multi-site search query
    print("\n[TEST 3] GET /search with multi-site query")
    search_query = "exam fee notification"
    status, res = request(f"/search?q={urllib.parse.quote(search_query)}&sites=bvcec.edu.in,www.bvcecautonomous.com,jntuk.edu.in")
    print(f"Status: {status}, Success: {res.get('success')}")
    results = res.get("results", [])
    sources = res.get("sources", [])
    print(f"Returned portal results: {len(results)}")
    print(f"Configured sources returned: {len(sources)}")
    for s in sources:
        print(f"  - Source: {s.get('title')} ({s.get('url')})")
    for r in results[:2]:
        print(f"  - Result: {r.get('title')} | Source: {r.get('source')} | URL: {r.get('url')}")

    # Test 4: /chat with webAccessEnabled=true and custom sites
    print("\n[TEST 4] POST /chat with webAccessEnabled and multiple trusted sites")
    chat_body = {
        "message": "What is the official examination portal for BVC students?",
        "webAccessEnabled": True,
        "debug": True,
        "trustedSites": [
            {"url": "bvcec.edu.in", "label": "BVC Engineering College Main Portal"},
            {"url": "www.bvcecautonomous.com", "label": "BVC Autonomous Examination Cell"},
            {"url": "jntuk.edu.in", "label": "JNTUK Examination Board"}
        ]
    }
    status, res = request("/chat", method="POST", body=chat_body)
    print(f"Status: {status}")
    print(f"Answer:\n{res.get('answer')}")
    print(f"Sources cited: {res.get('sources')}")
    assert status == 200, f"Expected 200, got {status}"

    # Test 5: DELETE /admin/sites
    print("\n[TEST 5] DELETE /admin/sites?url=jntuk.edu.in")
    status, res = request(
        f"/admin/sites?url=jntuk.edu.in",
        method="DELETE",
        headers={"Authorization": f"Bearer {ADMIN_KEY}"}
    )
    print(f"Status: {status}, Success: {res.get('success')}")
    after_delete_sites = res.get("sites", [])
    print(f"Total sites after deletion: {len(after_delete_sites)}")
    assert not any(s.get("url") == "jntuk.edu.in" for s in after_delete_sites), "Expected jntuk.edu.in to be deleted"

    print("\n==================================================")
    print("ALL 5 TESTS PASSED SUCCESSFULLY! [PASS]")
    print("==================================================")

if __name__ == "__main__":
    run_tests()
