import json
import urllib.request

url = 'https://ybmxpmsiihtasyjwxtol.supabase.co/rest/v1'
key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InlibXhwbXNpaWh0YXN5and4dG9sIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE5MDExNTEsImV4cCI6MjA4NzQ3NzE1MX0.dOoJWDf4j_etF0NTq4uuaVG47e0y_pDe-AdgDRhWI68'

headers = {
    'apikey': key,
    'Authorization': f'Bearer {key}',
    'Content-Type': 'application/json'
}

# Find all customers matching 'cochin colors' case insensitively
req = urllib.request.Request(f"{url}/customers?select=id,company_name&company_name=ilike.cochin%20colors", headers=headers)
with urllib.request.urlopen(req) as response:
    customers = json.loads(response.read().decode())
    
print("Found customers:", customers)

for c in customers:
    # Check how many tickets this customer has
    req2 = urllib.request.Request(f"{url}/tickets?select=id,title&customer_id=eq.{c['id']}", headers=headers)
    with urllib.request.urlopen(req2) as res2:
        tickets = json.loads(res2.read().decode())
        print(f"Customer {c['id']} has {len(tickets)} tickets.")
