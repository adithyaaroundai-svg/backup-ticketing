import json
import os
from typing import Optional

# Mock the search_manual logic from main.py to verify it works without running a full server
MANUAL_PATH = os.path.join(os.path.dirname(__file__), "..", "assets", "tally_manual.json")
TALLY_MANUAL = {"tutorials": []}

def load_manual():
    global TALLY_MANUAL
    try:
        if os.path.exists(MANUAL_PATH):
            with open(MANUAL_PATH, "r", encoding="utf-8") as f:
                TALLY_MANUAL = json.load(f)
            print(f"Loaded manual with {len(TALLY_MANUAL.get('tutorials', []))} tutorials.")
    except Exception as e:
        print(f"Failed to load manual: {e}")

load_manual()

def search_manual(query: str) -> Optional[dict]:
    if not query:
        return None
    
    query_terms = [t for t in query.lower().replace(",", " ").split() if len(t) > 2]
    if not query_terms:
        query_terms = [query.lower().strip()]
        
    best_tutorial = None
    max_score = 0
    matched_term = None
    
    for tutorial in TALLY_MANUAL.get("tutorials", []):
        score = 0
        title = tutorial.get("title", "").lower()
        learning = tutorial.get("learning", "").lower()
        
        current_matched_term = None
        for term in query_terms:
            if term in title:
                score += 5
                current_matched_term = term
            if term in learning:
                score += 1
                if not current_matched_term:
                    current_matched_term = term
                
        if score > max_score:
            max_score = score
            best_tutorial = tutorial
            matched_term = current_matched_term
            
    if best_tutorial and max_score >= 1:
        content = best_tutorial['learning']
        if matched_term:
            idx = content.lower().find(matched_term.lower())
            if idx != -1:
                start = max(0, idx - 2500)
                end = min(len(content), idx + 2500)
                snippet = content[start:end]
                if start > 0: snippet = "..." + snippet
                if end < len(content): snippet = snippet + "..."
                return {
                    "title": best_tutorial['title'],
                    "learning": snippet,
                    "score": max_score,
                    "matched": matched_term,
                    "start": start,
                    "end": end
                }
        return {
            "title": best_tutorial['title'],
            "learning": content[:5000],
            "score": max_score,
            "matched": "None (fallback)"
        }
    return None

# Test cases
tests = [
    "Getting error 'No accounting entries' while saving sales voucher in Tally Prime.",
    "GST reports",
    "edit log",
]

print("-" * 50)
for t in tests:
    res = search_manual(t)
    if res:
        print(f"Query: '{t}'")
        print(f"  FOUND: {res['title']} (Score: {res['score']})")
        print(f"  Matched Term: {res['matched']}")
        print(f"  Learning Length: {len(res['learning'])}")
        print(f"  Learning Preview: {res['learning'][:100]}...")
    else:
        print(f"Query: '{t}' -> NOT FOUND")
    print("-" * 50)
