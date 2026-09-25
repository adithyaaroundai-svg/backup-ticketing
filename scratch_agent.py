import requests

url = 'https://ybmxpmsiihtasyjwxtol.supabase.co/rest/v1/agents?select=*'
headers = {
    'apikey': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InlibXhwbXNpaWh0YXN5and4dG9sIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE5MDExNTEsImV4cCI6MjA4NzQ3NzE1MX0.dOoJWDf4j_etF0NTq4uuaVG47e0y_pDe-AdgDRhWI68'
}
response = requests.get(url, headers=headers)
agents = response.json()

for a in agents:
    if 'parvath' in str(a).lower() or '2f9066' in str(a):
        print(f"{a.get('id')}: {a.get('username')} / {a.get('full_name')} / {a.get('role')} / {a.get('department')}")
