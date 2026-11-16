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

def call_mcp_tool(tool_name, arguments, req_id=1):
    payload = {
        "jsonrpc": "2.0",
        "id": req_id,
        "method": "tools/call",
        "params": {
            "name": tool_name,
            "arguments": arguments
        }
    }
    req = urllib.request.Request(
        MCP_URL,
        data=json.dumps(payload).encode('utf-8'),
        headers=headers,
        method="POST"
    )
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            content = resp.read().decode('utf-8')
            for line in content.splitlines():
                if line.startswith("data: "):
                    return json.loads(line[6:])
            return json.loads(content)
    except Exception as e:
        return {"error": str(e)}

new_memories = [
    {
        "text": "3 Complete Powertrain Timelines: Timeline 1 (Rapid Racer, 3-5 days, ₹1880 incremental): 1x A2212 1400KV + 1x 80A Airplane ESC + 2-Ch Relay + Solid 8mm live axle (~585g RTR, 38.5 km/h, 16-18 min runtime). Timeline 2 (Twin Brute, 7-9 days, ₹4110 incremental): 2x A2212 1400KV + 2x SimonK 30A ESCs + 4-Ch Relay + Common 8mm solid axle (360W peak, ~785g RTR, 48-52 km/h). Timeline 3 (Vector Kart, 10-14 days, ₹4325 incremental): 2x A2212 1400KV + 2x SimonK 30A ESCs + Split dual 8mm stub axles + ESP32-S3 torque vectoring (active electronic differential, zero tire scrub, zero-radius barrier tank-turn unstick).",
        "tags": ["timelines", "powertrains", "comparison", "specs"]
    },
    {
        "text": "Subsystem Architectural Selections and Pros/Cons: Chassis: 2.5mm 6061-T6 Aluminum (indestructible over 2-5mm tile seams, heat dissipation, tapped threads) or 2.5mm FR4 fiberglass. Drivetrain: GT2 6mm synchronous timing belt (16T:64T 4:1 ratio) chosen over spur gears because loose redstone sand/grit jams and strips gears while rubber belts flex. Steering: +14 deg caster and +8 deg KPI direct linkage creates authentic kart jacking, lifting the inside rear tire 1.5-2.0mm off the ground to eliminate solid-axle understeer in 1.0m hairpins.",
        "tags": ["subsystems", "tradeoffs", "pros_cons", "chassis", "transmission"]
    }
]

for idx, m in enumerate(new_memories, start=10):
    res = call_mcp_tool("remember", {"text": m["text"], "tags": m["tags"]}, req_id=idx)
    print(f"Memory {idx} stored:", res)
