import base64
import hashlib
import json
import os
import secrets
import sys
import urllib.parse
import urllib.request
import webbrowser
from http.server import HTTPServer, BaseHTTPRequestHandler

REDIRECT_URI = "http://localhost:8080/callback"
AUTH_ENDPOINT = "https://api.graphify.com/oauth/authorize"
TOKEN_ENDPOINT = "https://api.graphify.com/oauth/token"
REGISTER_ENDPOINT = "https://api.graphify.com/oauth/register"

def base64url_encode(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).decode('utf-8').replace('=', '')

def generate_pkce():
    verifier = base64url_encode(secrets.token_bytes(32))
    digest = hashlib.sha256(verifier.encode('utf-8')).digest()
    challenge = base64url_encode(digest)
    return verifier, challenge

def register_client():
    req = urllib.request.Request(
        REGISTER_ENDPOINT,
        data=json.dumps({
            "client_name": "Antigravity Graphify Client",
            "redirect_uris": [REDIRECT_URI]
        }).encode('utf-8'),
        headers={"Content-Type": "application/json"}
    )
    with urllib.request.urlopen(req) as resp:
        data = json.loads(resp.read().decode('utf-8'))
        return data["client_id"]

auth_code = None
auth_error = None

class CallbackHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        global auth_code, auth_error
        parsed = urllib.parse.urlparse(self.path)
        if parsed.path == "/callback":
            params = urllib.parse.parse_qs(parsed.query)
            if "code" in params:
                auth_code = params["code"][0]
                self.send_response(200)
                self.send_header("Content-Type", "text/html")
                self.end_headers()
                self.wfile.write(b"<html><body style='font-family:sans-serif;text-align:center;padding:50px;'><h1>Authentication Successful!</h1><p>You can close this tab and return to the assistant.</p></body></html>")
            elif "error" in params:
                auth_error = params.get("error_description", params["error"])[0]
                self.send_response(400)
                self.send_header("Content-Type", "text/html")
                self.end_headers()
                self.wfile.write(f"<html><body><h1>Authentication Failed</h1><p>{auth_error}</p></body></html>".encode())
            else:
                self.send_response(404)
                self.end_headers()
        else:
            self.send_response(404)
            self.end_headers()

    def log_message(self, format, *args):
        pass # Suppress server logging

def main():
    print("1. Registering OAuth client with Graphify...")
    client_id = register_client()
    print(f"   Registered Client ID: {client_id}")

    verifier, challenge = generate_pkce()
    state = secrets.token_hex(16)

    params = {
        "response_type": "code",
        "client_id": client_id,
        "redirect_uri": REDIRECT_URI,
        "scope": "graphify:query offline_access",
        "code_challenge": challenge,
        "code_challenge_method": "S256",
        "state": state
    }
    auth_url = f"{AUTH_ENDPOINT}?{urllib.parse.urlencode(params)}"

    server = HTTPServer(("localhost", 8080), CallbackHandler)
    server.timeout = 180 # 3 minutes timeout

    print("\n2. Launching browser for Graphify authentication...")
    print(f"\nAUTH_URL: {auth_url}\n")
    sys.stdout.flush()

    try:
        webbrowser.open(auth_url)
    except Exception as e:
        print(f"Could not open browser automatically: {e}")

    print("Waiting for callback on http://localhost:8080/callback ...")
    sys.stdout.flush()

    while auth_code is None and auth_error is None:
        server.handle_request()

    if auth_error:
        print(f"Error during authorization: {auth_error}")
        return

    print("3. Authorization code received! Exchanging for Access Token...")
    token_req_data = {
        "grant_type": "authorization_code",
        "client_id": client_id,
        "code": auth_code,
        "redirect_uri": REDIRECT_URI,
        "code_verifier": verifier
    }
    req = urllib.request.Request(
        TOKEN_ENDPOINT,
        data=urllib.parse.urlencode(token_req_data).encode('utf-8'),
        headers={"Content-Type": "application/x-www-form-urlencoded"}
    )
    with urllib.request.urlopen(req) as resp:
        token_data = json.loads(resp.read().decode('utf-8'))

    token_file = r"C:\Users\BISWAPRIYA\.gemini\config\graphify_token.json"
    with open(token_file, "w") as f:
        json.dump(token_data, f, indent=2)

    print(f"SUCCESS: Access token saved to {token_file}")
    access_token = token_data.get("access_token")
    print(f"Token (preview): {access_token[:15]}... expires in {token_data.get('expires_in')}s")

if __name__ == "__main__":
    main()
