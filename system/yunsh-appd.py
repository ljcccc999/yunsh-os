#!/usr/bin/env python3
"""
YUNSH OS App Launcher Daemon v1.0
Listens on localhost:8590 for app launch requests from QML UI.
"""

import json
import subprocess
import time
from http.server import HTTPServer, BaseHTTPRequestHandler

PORT = 8590

# Map internal app IDs to launch actions
APP_MAP = {
    "appstore": {
        "type": "waydroid",
        "package": "com.tencent.android.qqdownloader",
        "name": "应用宝"
    },
}


class AppHandler(BaseHTTPRequestHandler):

    def do_POST(self):
        content_length = int(self.headers.get('Content-Length', 0))
        body = self.rfile.read(content_length)

        try:
            req = json.loads(body)
        except json.JSONDecodeError:
            self.send_error(400, "Invalid JSON")
            return

        action = req.get("action", "")
        result = {"status": "error", "message": "unknown action"}

        if action == "launch":
            app_id = req.get("appId", "")
            result = self.launch_app(app_id)
        elif action == "ping":
            result = {"status": "ok", "message": "pong"}

        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(json.dumps(result).encode())

    def launch_app(self, app_id):
        if app_id not in APP_MAP:
            return {"status": "error", "message": f"Unknown app: {app_id}"}

        app = APP_MAP[app_id]
        try:
            if app["type"] == "waydroid":
                # Ensure Waydroid session is running
                subprocess.run(
                    ["waydroid", "session", "start"],
                    capture_output=True, timeout=30
                )
                time.sleep(1)
                result = subprocess.run(
                    ["waydroid", "app", "launch", app["package"]],
                    capture_output=True, text=True, timeout=30
                )
            else:
                return {"status": "error", "message": f"Unknown type: {app['type']}"}

            if result.returncode == 0:
                return {"status": "ok", "message": f"Launched {app['name']}"}
            else:
                return {
                    "status": "error",
                    "message": result.stderr.strip()
                }
        except subprocess.TimeoutExpired:
            return {"status": "error", "message": "Timeout launching app"}
        except Exception as e:
            return {"status": "error", "message": str(e)}

    def log_message(self, format, *args):
        pass  # Suppress HTTP request logs


def main():
    server = HTTPServer(("127.0.0.1", PORT), AppHandler)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
