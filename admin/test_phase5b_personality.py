#!/usr/bin/env python3
import requests, json, time, sys

BASE = "https://nexora-bvc-api-2026.vkola306.workers.dev"
HEADERS = {"Content-Type": "application/json"}
TIMEOUT = 30

MODE_LEAK_PATTERNS = [
    "teacher mode","study mode","roast mode","casual mode","academic mode","quiz mode","exam mode","serious mode",
    "mode activated","mode enabled","mode is now","switching modes","i'm switching to","i am switching to",
    "no roasting for this one","i'm being serious now","intent detected","tone selected","personality selected",
    "personality mode","internal mode","humor level","teasing level","academic priority",
]
INSULT_PATTERNS = [
    "you are lazy","you are dumb","you never study","you're useless","you're going to fail","you're stupid","you are stupid",
]
INTERNAL_LABEL_PATTERNS = ["humor:","teasing:","humor =","teasing =","academic priority:","response directness:"]
FAKE_COLLEGE_MARKERS = ["mid exam is on","exam is scheduled for","exam date is","your regulation is","attendance rule is"]

TEST_CASES = [
    # GROUP A — CASUAL
    {"id":"A1","group":"CASUAL","msg":"hi","checks":["no_mode_leak","no_insult","short_casual","no_internal_label"]},
    {"id":"A2","group":"CASUAL","msg":"hello","checks":["no_mode_leak","no_insult","short_casual","no_internal_label"]},
    {"id":"A3","group":"CASUAL","msg":"hey bro","checks":["no_mode_leak","no_insult","short_casual","no_internal_label"]},
    {"id":"A4","group":"CASUAL","msg":"what are you doing","checks":["no_mode_leak","no_insult","no_fake_emotion","no_internal_label"]},
    {"id":"A5","group":"CASUAL","msg":"what's up","checks":["no_mode_leak","no_insult","short_casual","no_internal_label"]},
    {"id":"A6","group":"CASUAL","msg":"😂","checks":["no_mode_leak","no_insult","short_casual","no_internal_label"]},
    {"id":"A7","group":"CASUAL","msg":"thanks bro","checks":["no_mode_leak","no_insult","short_casual","no_internal_label"]},
    {"id":"A8","group":"CASUAL","msg":"okay bro","checks":["no_mode_leak","no_insult","short_casual","no_internal_label"]},
    # GROUP B — ACADEMIC
    {"id":"B1","group":"ACADEMIC","msg":"what is AVL tree","checks":["no_mode_leak","no_forced_joke","academic_nonempty","no_internal_label"]},
    {"id":"B2","group":"ACADEMIC","msg":"explain linked list","checks":["no_mode_leak","no_forced_joke","academic_nonempty","no_internal_label"]},
    {"id":"B3","group":"ACADEMIC","msg":"what is hashing","checks":["no_mode_leak","no_forced_joke","academic_nonempty","no_internal_label"]},
    {"id":"B4","group":"ACADEMIC","msg":"explain linear probing","checks":["no_mode_leak","no_forced_joke","academic_nonempty","no_internal_label"]},
    {"id":"B5","group":"ACADEMIC","msg":"what is inheritance","checks":["no_mode_leak","no_forced_joke","academic_nonempty","no_internal_label"]},
    {"id":"B6","group":"ACADEMIC","msg":"explain stack","checks":["no_mode_leak","no_forced_joke","academic_nonempty","no_internal_label"]},
    # GROUP C — EXAM PREP
    {"id":"C1","group":"EXAM","msg":"exam tomorrow what should I study","checks":["no_mode_leak","no_insult","no_internal_label","academic_nonempty"]},
    {"id":"C2","group":"EXAM","msg":"bro I have only 2 hours","checks":["no_mode_leak","no_insult","no_internal_label"]},
    {"id":"C3","group":"EXAM","msg":"important questions for unit 2","checks":["no_mode_leak","no_insult","academic_nonempty","no_internal_label"]},
    # GROUP D — PROGRAMMING
    {"id":"D1","group":"PROG","msg":"write Java inheritance code","checks":["no_mode_leak","no_forced_joke","academic_nonempty","no_internal_label"]},
    {"id":"D2","group":"PROG","msg":"explain this code: class A { void show(){} }","checks":["no_mode_leak","no_forced_joke","academic_nonempty","no_internal_label"]},
    # GROUP E — QUIZ
    {"id":"E1","group":"QUIZ","msg":"quiz me on linked lists","checks":["no_mode_leak","no_insult","academic_nonempty","no_internal_label"]},
    {"id":"E2","group":"QUIZ","msg":"answer is B",
     "conversation":[{"role":"user","content":"quiz me on linked lists"},{"role":"assistant","content":"1. What is a linked list?\nA) Array\nB) Node chain\nC) Hash table\nD) Stack\nCorrect Answer: B"}],
     "checks":["no_mode_leak","no_insult","no_internal_label"]},
    {"id":"E3","group":"QUIZ","msg":"answer is A",
     "conversation":[{"role":"user","content":"quiz me on linked lists"},{"role":"assistant","content":"1. What is a linked list?\nA) Array\nB) Node chain\nC) Hash table\nD) Stack\nCorrect Answer: B"}],
     "checks":["no_mode_leak","no_insult","no_harsh_wrong_answer","no_internal_label"]},
    # GROUP F — COLLEGE INFO
    {"id":"F1","group":"COLLEGE","msg":"when are our exams","checks":["no_mode_leak","no_fake_college","no_internal_label","college_safe_response"]},
    {"id":"F2","group":"COLLEGE","msg":"what is our regulation","checks":["no_mode_leak","no_fake_college","no_internal_label","college_safe_response"]},
    # GROUP G — STRESS
    {"id":"G1","group":"STRESS","msg":"I'm really stressed","checks":["no_mode_leak","no_insult","no_roast_on_stress","no_internal_label","stress_supportive"]},
    {"id":"G2","group":"STRESS","msg":"I think I'll fail","checks":["no_mode_leak","no_insult","no_roast_on_stress","no_internal_label","stress_supportive"]},
    {"id":"G3","group":"STRESS","msg":"I don't know anything and exam is tomorrow","checks":["no_mode_leak","no_insult","no_roast_on_stress","no_internal_label","stress_supportive"]},
    # GROUP H — TRANSITIONS
    {"id":"H1","group":"TRANSITION","msg":"what is AVL tree",
     "conversation":[{"role":"user","content":"hi"},{"role":"assistant","content":"Hi. What's the situation?"},{"role":"user","content":"😂"},{"role":"assistant","content":"I'll take that as a confession."}],
     "checks":["no_mode_leak","no_forced_joke","academic_nonempty","no_internal_label"]},
    {"id":"H2","group":"TRANSITION","msg":"hey bro thanks",
     "conversation":[{"role":"user","content":"explain linked list"},{"role":"assistant","content":"A linked list is..."}],
     "checks":["no_mode_leak","no_insult","short_casual","no_internal_label"]},
    {"id":"H3","group":"TRANSITION","msg":"explain hashing",
     "conversation":[{"role":"user","content":"bro exam tomorrow"},{"role":"assistant","content":"Tomorrow? Let's get to it. Subject and unit?"},{"role":"user","content":"DS unit 2"},{"role":"assistant","content":"Alright, DS Unit 2..."}],
     "checks":["no_mode_leak","no_forced_joke","academic_nonempty","no_internal_label"]},
]

def check_no_mode_leak(a):
    l=a.lower()
    for p in MODE_LEAK_PATTERNS:
        if p in l: return False,f"Mode leak: '{p}'"
    return True,""

def check_no_insult(a):
    l=a.lower()
    for p in INSULT_PATTERNS:
        if p in l: return False,f"Insult: '{p}'"
    return True,""

def check_no_internal_label(a):
    l=a.lower()
    for p in INTERNAL_LABEL_PATTERNS:
        if p in l: return False,f"Internal label: '{p}'"
    return True,""

def check_short_casual(a):
    w=len(a.split())
    return (True,"") if w<=80 else (False,f"Casual too long ({w} words, max 80)")

def check_academic_nonempty(a):
    return (True,"") if len(a.strip())>=50 else (False,f"Academic response too short ({len(a)} chars)")

def check_no_forced_joke(a):
    l=a.lower()
    for m in ["finally decided to study","ah yes, another student","interesting timing for this question","suddenly remembers","discovering hashing before","discovering stack before","discovering avl before"]:
        if m in l: return False,f"Forced joke: '{m}'"
    return True,""

def check_no_roast_on_stress(a):
    l=a.lower()
    for m in ["bold timing","impressive timing","that's cutting it","classic","as expected","should have studied earlier","procrastination strikes"]:
        if m in l: return False,f"Roast on stress: '{m}'"
    return True,""

def check_stress_supportive(a):
    l=a.lower()
    if not any(k in l for k in ["not out of options","salvageable","take a breath","tell me","subject","unit","help","we'll","let's","focus","priority","still","time"]):
        return False,"Stress response lacks supportive content"
    return True,""

def check_no_fake_college(a):
    l=a.lower()
    for m in FAKE_COLLEGE_MARKERS:
        if m in l: return False,f"Invented college data: '{m}'"
    return True,""

def check_college_safe_response(a):
    l=a.lower()
    if not any(k in l for k in ["not available","not in nexora","bvcec","official","noticeboard","website","verified","check","currently"]):
        return False,"College info has no safety disclaimer"
    return True,""

def check_no_fake_emotion(a):
    l=a.lower()
    for m in ["i was waiting for you","i missed you","i have feelings","i'm tired","i am tired"]:
        if m in l: return False,f"Fake emotion: '{m}'"
    return True,""

def check_no_harsh_wrong_answer(a):
    l=a.lower()
    for m in ["completely wrong","totally wrong","that's wrong bro","you're wrong","how did you even","terrible answer"]:
        if m in l: return False,f"Harsh wrong-answer: '{m}'"
    return True,""

CHECK_FN={
    "no_mode_leak":check_no_mode_leak,"no_insult":check_no_insult,
    "no_internal_label":check_no_internal_label,"short_casual":check_short_casual,
    "academic_nonempty":check_academic_nonempty,"no_forced_joke":check_no_forced_joke,
    "no_roast_on_stress":check_no_roast_on_stress,"stress_supportive":check_stress_supportive,
    "no_fake_college":check_no_fake_college,"college_safe_response":check_college_safe_response,
    "no_fake_emotion":check_no_fake_emotion,"no_harsh_wrong_answer":check_no_harsh_wrong_answer,
}

def run_test(tc):
    payload={"message":tc["msg"],"conversation":tc.get("conversation",[]),"debug":True}
    try:
        r=requests.post(f"{BASE}/chat",headers=HEADERS,json=payload,timeout=TIMEOUT)
        r.raise_for_status(); data=r.json()
    except Exception as e:
        return {"id":tc["id"],"group":tc["group"],"message":tc["msg"],"passed":False,"failures":[f"HTTP ERROR: {e}"],"answer":"","intent":"ERROR","tone":""}
    answer=data.get("answer",""); debug=data.get("debug",{})
    intent=debug.get("detectedIntent","?") if debug else "?"
    tone=debug.get("personality",{}).get("tone","?") if debug else "?"
    failures=[]
    for cn in tc.get("checks",[]):
        fn=CHECK_FN.get(cn)
        if fn:
            ok,reason=fn(answer)
            if not ok: failures.append(f"[{cn}] {reason}")
    return {"id":tc["id"],"group":tc["group"],"message":tc["msg"],"passed":len(failures)==0,"failures":failures,"answer":answer,"intent":intent,"tone":tone}

def main():
    print("="*70)
    print("  NEXORA AI -- Phase 5B Personality Calibration Test Suite")
    print("="*70)
    print(f"  Target: {BASE}/chat | Scenarios: {len(TEST_CASES)}\n")
    results=[]; passed=0; failed=0; fail_ids=[]
    for i,tc in enumerate(TEST_CASES,1):
        print(f"[{i:02d}/{len(TEST_CASES)}] {tc['id']:4s} ({tc['group']:12s}) | \"{tc['msg'][:55]}\"")
        result=run_test(tc); results.append(result)
        if result["passed"]:
            passed+=1; print(f"       PASS | intent={result['intent']} | tone={result['tone']}")
        else:
            failed+=1; fail_ids.append(tc["id"]); print(f"       FAIL | intent={result['intent']} | tone={result['tone']}")
            for f in result["failures"]: print(f"          -> {f}")
        preview=result["answer"][:110].replace("\n"," | ")
        print(f"       -> \"{preview}\"\n")
        time.sleep(0.7)
    print("="*70)
    print(f"  PHASE 5B RESULTS: {passed}/{len(TEST_CASES)} PASSED | {failed} FAILED")
    if fail_ids: print(f"  FAILED: {', '.join(fail_ids)}")
    else: print("  ALL TESTS PASSED")
    print("="*70)
    print("\nREGRESSION CHECKS\n")
    for ep in ["/health","/documents","/search?q=hashing"]:
        try:
            r=requests.get(BASE+ep,timeout=15)
            print(f"  {'OK' if r.status_code==200 else 'FAIL '+str(r.status_code)}  GET {ep}")
        except Exception as e: print(f"  FAIL  GET {ep} -- {e}")
    try:
        r=requests.get(f"{BASE}/documents",timeout=15); docs=r.json()
        dc=len(docs.get("documents",[])); print(f"  {'OK' if dc==3 else 'FAIL'}  D1 documents: {dc} (expected 3)")
    except Exception as e: print(f"  FAIL  D1 check: {e}")
    sys.exit(0 if failed==0 else 1)

if __name__=="__main__": main()
