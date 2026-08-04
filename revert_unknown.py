import json
import urllib.request

url = 'https://ybmxpmsiihtasyjwxtol.supabase.co/rest/v1'
key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InlibXhwbXNpaWh0YXN5and4dG9sIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE5MDExNTEsImV4cCI6MjA4NzQ3NzE1MX0.dOoJWDf4j_etF0NTq4uuaVG47e0y_pDe-AdgDRhWI68'

headers = {
    'apikey': key,
    'Authorization': f'Bearer {key}',
    'Content-Type': 'application/json'
}

data = json.dumps({'company_name': 'UNKNOWN'}).encode('utf-8')
req = urllib.request.Request(f"{url}/customers?id=eq.e6045124-8ec6-48f3-8376-f57377c9517c", data=data, headers=headers, method='PATCH')

with urllib.request.urlopen(req) as response:
    print(f"Update response status: {response.status}")
