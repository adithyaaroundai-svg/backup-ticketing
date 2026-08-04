import sys
import os
from unittest.mock import patch, AsyncMock

# Add the parent directory to sys.path to make the import work
current_dir = os.path.dirname(os.path.abspath(__file__))
parent_dir = os.path.dirname(current_dir)
sys.path.insert(0, parent_dir)

from fastapi.testclient import TestClient
from proxy_backend.main import app

client = TestClient(app)

def test_partial_upstream_response():
    """Test what happens when upstream returns only an acknowledgement."""
    print("Testing Partial Upstream Response...")
    payload = {"question": "tally not opening"}
    
    partial_response = "Issue Acknowledgement: I see you have a problem with Tally."
    
    with patch("proxy_backend.main.fetch_upstream_answer", new_callable=AsyncMock) as mock_fetch:
        mock_fetch.return_value = partial_response
        
        response = client.post("/ask", json=payload)
        data = response.json()
        answer = data["answer"]
        
        print("Response received:")
        print("-" * 20)
        print(answer)
        print("-" * 20)
        
        # Check if Solution section is malformed (contains the Ack from upstream) or missing content
        if "Solution:\nIssue Acknowledgement:" in answer:
             print("FAILURE: Upstream partial response was blindly dumped into Solution section.")
             return False
        
        if "Solution:" not in answer:
             print("FAILURE: Response missing Solution section.")
             return False
             
        # Check if Solution has actual steps
        if "- Step 1:" not in answer:
             print("FAILURE: Solution section does not contain expected steps.")
             return False

        print("SUCCESS: Response repaired correctly.")
        return True

if __name__ == "__main__":
    if test_partial_upstream_response():
        sys.exit(0)
    else:
        sys.exit(1)
