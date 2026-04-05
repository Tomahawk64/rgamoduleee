"""
Serves Flutter web build via Python HTTP server and exposes it via pyngrok.
Run: python serve_ngrok.py
"""
import http.server
import socketserver
import threading
import os
import sys
from pyngrok import ngrok, conf

PORT = 8080
WEB_DIR = os.path.join(os.path.dirname(__file__), "build", "web")

# ── Configure ngrok auth token (already saved to ngrok.yml, this is a no-op) ──
conf.get_default().auth_token = "31BcPoGKonvtMIQQGRnfWp6QlNm_2FQPt3unr8nQNSU7whN3h"

class SpaHandler(http.server.SimpleHTTPRequestHandler):
    """Serve index.html for any path not found (SPA routing)."""

    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=WEB_DIR, **kwargs)

    def do_GET(self):
        # Try to serve the requested file; fall back to index.html for SPA routes
        file_path = os.path.join(WEB_DIR, self.path.lstrip("/"))
        if not os.path.isfile(file_path):
            self.path = "/index.html"
        return super().do_GET()

    def log_message(self, format, *args):
        # Suppress noisy access logs; only show errors
        if args and str(args[1]) not in ("200", "304"):
            super().log_message(format, *args)


def start_server():
    with socketserver.TCPServer(("", PORT), SpaHandler) as httpd:
        httpd.allow_reuse_address = True
        print(f"  Python HTTP server listening on http://localhost:{PORT}")
        httpd.serve_forever()


if __name__ == "__main__":
    if not os.path.isdir(WEB_DIR):
        print(f"ERROR: Web build not found at {WEB_DIR}")
        print("Run:  flutter build web --release")
        sys.exit(1)

    # Start HTTP server in a background thread
    t = threading.Thread(target=start_server, daemon=True)
    t.start()

    # Open ngrok tunnel
    print("  Opening ngrok tunnel...")
    tunnel = ngrok.connect(PORT, "http")
    public_url = tunnel.public_url
    # Prefer https
    if public_url.startswith("http://"):
        public_url = public_url.replace("http://", "https://", 1)

    print()
    print("=" * 60)
    print(f"  PUBLIC URL:  {public_url}")
    print("=" * 60)
    print()
    print("  Share the URL above to access the Flutter app.")
    print("  Press Ctrl+C to stop.")
    print()

    try:
        ngrok_process = ngrok.get_ngrok_process()
        ngrok_process.proc.wait()
    except KeyboardInterrupt:
        print("\n  Shutting down...")
        ngrok.kill()
