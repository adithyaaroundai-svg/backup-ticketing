import httpx
import json

PROXY_URL = "http://localhost:8000/ask"
PAYLOAD = {
    "customer_issue": "sales voucher",
    "ticket_id": 80532603,
    "auto_coach": True
}

def test_truncation():
    print(f"Testing query: {PAYLOAD['customer_issue']}")
    try:
        with httpx.Client(timeout=130) as client:
            response = client.post(PROXY_URL, json=PAYLOAD)
            print(f"Status Code: {response.status_code}")
            data = response.json()
            answer = data.get("answer", "")
            print(f"Answer Length: {len(answer)}")
            print("--- Full Answer ---")
            print(answer)
            print("--- End Answer ---")
            
            if answer.endswith("**To") or len(answer) < 300:
                print("\n[WARNING] Response appears truncated or very short!")
            else:
                print("\n[INFO] Response seems complete.")
                
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    test_truncation()
