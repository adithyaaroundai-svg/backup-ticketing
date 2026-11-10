import urllib.request
import json

SUPABASE_URL = 'https://ybmxpmsiihtasyjwxtol.supabase.co'
ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InlibXhwbXNpaWh0YXN5and4dG9sIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE5MDExNTEsImV4cCI6MjA4NzQ3NzE1MX0.dOoJWDf4j_etF0NTq4uuaVG47e0y_pDe-AdgDRhWI68'

url = f'{SUPABASE_URL}/rest/v1/tasks?select=id,description,task_date,expected_finish,created_at,pending&order=id.desc&limit=30'
url += '&apikey=' + ANON_KEY

req = urllib.request.Request(url, headers={
    'Authorization': f'Bearer {ANON_KEY}',
    'apikey': ANON_KEY,
    'Accept-Profile': 'aroundtally',
    'Content-Profile': 'aroundtally',
    'Content-Type': 'application/json',
})

with urllib.request.urlopen(req) as resp:
    data = json.loads(resp.read())

print(f"{'ID':<6} {'created_at':<25} {'task_date':<14} {'expected_finish':<16} {'pending':<8} description")
print("-" * 100)
for t in data:
    print(f"{t['id']:<6} {str(t.get('created_at','NULL')):<25} {str(t.get('task_date','NULL')):<14} {str(t.get('expected_finish','NULL')):<16} {str(t.get('pending','NULL')):<8} {t['description'][:40]}")
