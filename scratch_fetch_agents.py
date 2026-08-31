import requests
import json

url = 'https://ybmxpmsiihtasyjwxtol.supabase.co/rest/v1/agents'
headers = {
    'apikey': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InlibXhwbXNpaWh0YXN5and4dG9sIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE5MDExNTEsImV4cCI6MjA4NzQ3NzE1MX0.dOoJWDf4j_etF0NTq4uuaVG47e0y_pDe-AdgDRhWI68',
    'Authorization': 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InlibXhwbXNpaWh0YXN5and4dG9sIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE5MDExNTEsImV4cCI6MjA4NzQ3NzE1MX0.dOoJWDf4j_etF0NTq4uuaVG47e0y_pDe-AdgDRhWI68',
}

response = requests.get(url, headers=headers)
agents = response.json()

target_names = ['Saneesha', 'Anugraha', 'Swathy', 'Shahma', 'Vismaya', 'Akash']
found_agents = []

for agent in agents:
    if agent.get('username', '').lower() in [name.lower() for name in target_names] or agent.get('full_name', '').lower() in [name.lower() for name in target_names]:
        found_agents.append(f"{agent['username']} -> {agent['id']} (Role: {agent.get('role')})")

print("Found agents:")
for line in found_agents:
    print(line)

print("\nSupport Head roles:")
for agent in agents:
    role = agent.get('role', '')
    if role and 'head' in role.lower():
        print(f"{agent['username']} -> {agent['id']} (Role: {role})")
