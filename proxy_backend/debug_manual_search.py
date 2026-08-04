import json
import os
import re

# Mirror the logic from main.py
def search_manual(query: str) -> dict:
    manual_path = r"c:\Users\user\StudioProjects\ticketing_system1\ticketing_system\assets\tally_manual.json"
    with open(manual_path, 'r', encoding='utf-8') as f:
        manual_data = json.load(f)
    
    tutorials = manual_data.get("tutorials", [])
    query_terms = query.lower().split()
    
    best_tutorial = None
    max_score = 0
    matched_term = ""

    for tutorial in tutorials:
        score = 0
        title = tutorial.get("title", "").lower()
        learning = tutorial.get("learning", "").lower()
        
        # Scoring logic from main.py (simplified matches)
        current_matched = ""
        for term in query_terms:
            if term in title:
                score += 10
                current_matched = term
            if term in learning:
                score += 1
                if not current_matched:
                    current_matched = term
        
        if score > max_score:
            max_score = score
            best_tutorial = tutorial
            matched_term = current_matched

    if best_tutorial and max_score >= 1:
        content = best_tutorial['learning']
        idx = content.lower().find(matched_term.lower())
        if idx != -1:
            start = max(0, idx - 1250)
            end = min(len(content), idx + 1250)
            snippet = content[start:end]
            return {
                "title": best_tutorial['title'],
                "learning": snippet,
                "score": max_score,
                "matched_term": matched_term
            }
    return None

if __name__ == "__main__":
    queries = ["invoice not generating", "invoice", "sales voucher"]
    for q in queries:
        print(f"\n--- Query: {q} ---")
        res = search_manual(q)
        if res:
            print(f"Title: {res['title']}")
            print(f"Score: {res['score']}")
            print(f"Snippet Length: {len(res['learning'])}")
            print(f"Snippet Content Start:\n{res['learning'][:500]}")
        else:
            print("No results found.")
