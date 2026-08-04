import requests
import json
import time

PROXY_URL = "http://localhost:8000/ask"

def test_robustness(name, payload, expected_substring):
    print(f"\n--- Testing: {name} ---")
    try:
        start_time = time.time()
        response = requests.post(PROXY_URL, json=payload, timeout=130)
        end_time = time.time()
        
        print(f"Status Code: {response.status_code}")
        print(f"Latency: {end_time - start_time:.2f}s")
        
        if response.status_code == 200:
            data = response.json()
            answer = data.get("answer", "")
            print(f"Answer Sample: {answer[:100]}...")
            
            # Check for keys
            has_keys = all(k in data for k in ["answer", "reply", "next_question"])
            print(f"Has all keys: {has_keys}")
            
            if has_keys and expected_substring in answer:
                print("SUCCESS: Unified fallback received.")
            elif not has_keys:
                print("FAILURE: Missing keys in response.")
            else:
                print("FAILURE: Unexpected answer content.")
        else:
            print(f"FAILURE: HTTP {response.status_code}")
            
    except Exception as e:
        print(f"EXCEPTION: {e}")

if __name__ == "__main__":
    # 1. Invalid URL (Manually set in main.py or just use a bogus payload if we can't change env)
    # Since we can't easily change the proxy's ENV without restarting, we'll test the logic.
    
    # 2. auto_coach = True with valid query
    payload_coach = {
        "customer_issue": "invoice",
        "ticket_id": 123,
        "auto_coach": True
    }
    test_robustness("Auto Coach Enabled", payload_coach, "👋")

    # 3. auto_coach = False with valid query
    payload_no_coach = {
        "customer_issue": "invoice",
        "ticket_id": 123,
        "auto_coach": False
    }
    test_robustness("Auto Coach Disabled", payload_no_coach, "Step 1")
