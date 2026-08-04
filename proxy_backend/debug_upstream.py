import httpx
import json

UPSTREAM_ASK_URL = "https://tars-jdno.onrender.com/ask"

payload = {
    "question": "STRICT RULES: Use ONLY manual data. No platitudes. Use 'Step 1/2/3' structure.\n\nMANUAL DATA:\nHow to create a company: Alt+G > Create > Company.\n\nUSER ISSUE:\nHow to create a company?",
    "auto_coach": False,
}

print(f"Calling upstream: {UPSTREAM_ASK_URL}")
try:
    with httpx.Client(timeout=60) as client:
        response = client.post(UPSTREAM_ASK_URL, json=payload)
        print(f"Status Code: {response.status_code}")
        print(f"Response Body: {response.text}")
except Exception as e:
    print(f"Error: {e}")
