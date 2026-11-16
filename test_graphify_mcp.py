import json
import urllib.request

TOKEN_PATH = r"C:\Users\BISWAPRIYA\.gemini\config\graphify_token.json"
MCP_URL = "https://api.graphify.com/mcp"

with open(TOKEN_PATH, "r") as f:
    token_data = json.load(f)

access_token = token_data["access_token"]
headers = {
    "Authorization": f"Bearer {access_token}",
    "Content-Type": "application/json",
    "Accept": "application/json, text/event-stream"
}

def send_mcp_request(method, params=None, req_id=1):
    payload = {
        "jsonrpc": "2.0",
        "id": req_id,
        "method": method
    }
    if params is not None:
        payload["params"] = params
    
    req = urllib.request.Request(
        MCP_URL,
        data=json.dumps(payload).encode('utf-8'),
        headers=headers,
        method="POST"
    )
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            content = resp.read().decode('utf-8')
            return content
    except urllib.error.HTTPError as e:
        return f"HTTPError {e.code}: {e.read().decode('utf-8')}"
    except Exception as e:
        return f"Error: {e}"

print("--- 1. Initialize MCP ---")
init_params = {
    "protocolVersion": "2024-11-05",
    "capabilities": {},
    "clientInfo": {"name": "Antigravity", "version": "1.0.0"}
}
print(send_mcp_request("initialize", init_params, 1))

print("\n--- 2. List Tools ---")
print(send_mcp_request("tools/list", {}, 2))

print("\n--- 3. List Workspaces ---")
print(send_mcp_request("tools/call", {"name": "list_workspaces", "arguments": {}}, 3))

print("\n--- 4. Set Workspace to biswapriya-s-workspace ---")
print(send_mcp_request("tools/call", {"name": "set_workspace", "arguments": {"workspace": "biswapriya-s-workspace"}}, 4))

print("\n--- 5. List Repositories ---")
print(send_mcp_request("tools/call", {"name": "list_repositories", "arguments": {}}, 5))
