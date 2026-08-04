import requests
import json
import time

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

# 1. Valid Request (Text Only) - Using 'question' field (populate_by_name)
payload_1 = {
    "question": "My GST returns are showing a mismatch in Voucher 102.",
    "ticket_id": 999,
    "context": {
        "screen_name": "GST Report",
        "active_field": "Voucher",
        "field_values": {}
    }
}

# 2. Valid Request (Text Only) - Using 'customer_issue' alias
payload_2 = {
    "customer_issue": "Tally not opening on startup",
    "ticket_id": 888,
    "auto_coach": True,
    "context": {
        "field_values": {"issue": "Tally not opening"}
    }
}

# 3. Missing Ticket ID (Should Fail)
payload_3 = {
    "question": "This should fail",
    # "ticket_id": missing
}

if __name__ == "__main__":
    print("Verifying Backend Refactor...")
    test_payload("Standard Request", payload_1)
    test_payload("Alias Request + Auto Coach", payload_2)
    test_payload("Missing Ticket ID", payload_3, expected_status=422)
