import requests
import json

URL = "http://127.0.0.1:8000/ask"

def test_payload(name, payload, expected_status=200):
    print(f"\n--- Testing: {name} ---")
    print(f"Payload: {json.dumps(payload, indent=2)}")
    try:
        response = requests.post(URL, json=payload, timeout=65)
        print(f"Status: {response.status_code}")
        if response.status_code == expected_status:
            print("✅ Status Code Match")
            if expected_status == 200:
                data = response.json()
                answer = data.get('answer', '')
                print(f"Response Answer Length: {len(answer)}")
                if "Solution:" in answer and len(answer) > 100:
                     print("✅ Valid Solution Detected")
                else:
                     print("❌ Solution Missing or Too Short")
                     print(f"Full Answer: {answer[:300]}...")
                print(f"Debug Header: {response.headers.get('X-Issue-Detected')}")
        else:
            print(f"❌ Status Code Mismatch! Expected {expected_status}, got {response.status_code}")
            print(f"Response Body: {response.text}")
    except Exception as e:
        print(f"❌ Exception: {e}")

# 1. User Desired Request (Simplified)
# Logic check: 'context' is missing, backend should auto-inject defaults for upstream.
payload_user = {
  "customer_issue": "Tally not opening on startup",
  "ticket_id": 12345,
  "auto_coach": True
}

if __name__ == "__main__":
    print("Verifying Simplified Payload Support...")
    test_payload("User Simplified Request", payload_user)
