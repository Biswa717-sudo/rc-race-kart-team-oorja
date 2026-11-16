import json
import urllib.request

TOKEN_PATH = r"C:\Users\BISWAPRIYA\.gemini\config\graphify_token.json"
MCP_URL = "https://api.graphify.com/mcp"
REPO_ID = "Biswa717-sudo/rc-race-kart-team-oorja"

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

memories = [
    {
        "text": "Team Oorja F1 RC Race (Division B) strict rules: Maximum fully charged battery voltage is 8.4V (2S LiPo / 2S Li-ion only; 3S is strictly prohibited). Track footprint is 12m x 7.4m with 0.6m track width and 1.0m radius hairpins. Track surface is outdoor redstone tiles with 2-5mm gaps. Minimum ground clearance is 12mm (our kart is set to 15mm clearance). Minimum wheel diameter is 50mm (our kart uses 65mm rubber slicks). Automatic failsafe is mandatory (must cut throttle within 250ms of signal loss).",
        "tags": ["rules", "regulations", "dimensions", "track"]
    },
    {
        "text": "Selected Powertrain (Timeline 1 - The Rapid Racer): Single A2212 1400KV brushless outrunner motor, E203950 80A Airplane ESC, 2-Channel 5V Optocoupler Relay module for electronic reverse (swapping Phase 1 and Phase 2), GT2 timing belt transmission (16T motor pulley to 64T axle pulley, 4:1 reduction), single 8mm precision ground stainless steel solid live rear axle supported by two F688ZZ flanged ball bearings. Battery is A3SD 2S (7.4V/8.4V) 2200mAh 80C LiPo with XT60 connector.",
        "tags": ["powertrain", "motor", "esc", "battery", "drivetrain"]
    },
    {
        "text": "Pure Go-Kart Cornering & Jacking Physics: Racing karts have zero suspension/springs and a solid locked rear live axle without differential. Cornering is achieved via 12-15 degree positive caster on the front kingpins plus Kingpin Inclination (KPI). Turning into a corner forces the outside front wheel down and inside front wheel up, creating a diagonal teeter-totter twist across the 2.5mm chassis waist that physically lifts the inside rear tire 1-2mm off the tiles. This eliminates wheel scrub and lets the kart pivot cleanly through 1.0m hairpins.",
        "tags": ["chassis", "physics", "suspension", "caster", "jacking", "steering"]
    },
    {
        "text": "ESP32-S3 Firmware & Pinout Architecture: Microcontroller is ESP32-S3. Pin GPIO 18 connects to 80A ESC Signal (50Hz PWM, 1000-2000us). Pin GPIO 19 connects to Relay IN1 (LOW = Forward Phasing, HIGH = Reverse Phasing). Pin GPIO 21 connects to MG90S metal-gear steering servo. Driving logic: Normal trigger push is 100% HARD BRAKE ONLY. Barrier unstick reverse requires double-tap or dedicated button, enforcing a mandatory 150ms dead-time delay for motor to reach 0 RPM before toggling relays.",
        "tags": ["firmware", "esp32-s3", "pinout", "relay", "safety", "failsafe"]
    },
    {
        "text": "80A ESC Programming Settings for A2212: 1. Cell Count: 2S Li-Po (6.0V cutoff). 2. Throttle Response: Auto Range + Hard Start. 3. Brake: Hard Brake (essential to stop motor in <120ms before relay reverse). 4. Direction & Cutoff: Soft Cutoff (reduces power to 50% on low battery rather than sudden cutoff). 5. Timing Mode: 15 degrees (mandatory for 14-pole A2212 outrunner to prevent stutter/desync). 6. PWM Frequency: 16 KHz (whisper-quiet, smooth low-speed hairpin control).",
        "tags": ["esc", "programming", "settings", "timing", "pwm"]
    }
]

print("Indexing memories into Graphify...")
for i, mem in enumerate(memories):
    args = {
        "repository_id": REPO_ID,
        "text": mem["text"],
        "tags": mem["tags"]
    }
    res = call_mcp_tool("remember", args, req_id=10+i)
    print(f"Memory {i+1} saved:", res.get("result", {}).get("structuredContent", res))

print("\nVerifying with Graphify recall query...")
recall_res = call_mcp_tool("recall", {"repository_id": REPO_ID, "query": "What are the track surface and ground clearance requirements?"}, 99)
print("Recall Result:")
print(json.dumps(recall_res.get("result", {}).get("structuredContent", recall_res), indent=2))
