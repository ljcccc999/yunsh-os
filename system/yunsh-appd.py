#!/usr/bin/env python3
"""
YUNSH OS App Launcher Daemon v1.0
Listens on localhost:8590 for app launch requests from QML UI.
"""

import json
import os
import subprocess
import time
from http.server import HTTPServer, BaseHTTPRequestHandler

PORT = 8590
SCREENSHOT_DIR = os.environ.get(
    "YUNSH_SCREENSHOT_DIR", "/home/yunsh/Pictures/Screenshots"
)

# Map internal app IDs to launch actions
APP_MAP = {
    "appstore": {
        "type": "waydroid",
        "name": "Android Apps"
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
        elif action == "screenshot":
            result = self.take_screenshot(req)
        elif action == "crop":
            result = self.crop_screenshot(req)
        elif action == "ping":
            result = {"status": "ok", "message": "pong"}

        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(json.dumps(result).encode())

    def crop_screenshot(self, req):
        source = req.get("source", "")
        if not source.startswith("/tmp/yunsh-screenshot-region-full-"):
            return {"status": "error", "message": "Invalid screenshot source"}
        try:
            from PIL import Image
            x = max(0, int(req.get("x", 0)))
            y = max(0, int(req.get("y", 0)))
            w = max(1, int(req.get("w", 1)))
            h = max(1, int(req.get("h", 1)))
            target_dir = SCREENSHOT_DIR
            os.makedirs(target_dir, exist_ok=True)
            target = os.path.join(target_dir, f"Screenshot_{int(time.time() * 1000)}.png")
            with Image.open(source) as image:
                right = min(image.width, x + w)
                bottom = min(image.height, y + h)
                image.crop((x, y, right, bottom)).save(target)
            os.remove(source)
            return {"status": "ok", "path": target}
        except Exception as exc:
            return {"status": "error", "message": str(exc)}

    def take_screenshot(self, req):
        """Capture screenshot via yunsh-screenshotd script."""
        try:
            shot_type = req.get("type", "full")
            if shot_type == "region":
                x = req.get("x", 0)
                y = req.get("y", 0)
                w = req.get("w", 1920)
                h = req.get("h", 1080)
                result = subprocess.run(
                    ["yunsh-screenshotd", "region", str(x), str(y), str(w), str(h)],
                    capture_output=True, text=True, timeout=30
                )
            else:
                result = subprocess.run(
                    ["yunsh-screenshotd", "full"],
                    capture_output=True, text=True, timeout=30
                )

            if result.returncode == 0:
                return {"status": "ok", "message": "Screenshot saved"}
            else:
                return {"status": "error", "message": result.stderr.strip()}
        except subprocess.TimeoutExpired:
            return {"status": "error", "message": "Timeout capturing screenshot"}
        except Exception as e:
            return {"status": "error", "message": str(e)}

    def launch_app(self, app_id):
        if app_id not in APP_MAP:
            return {"status": "error", "message": f"Unknown app: {app_id}"}

        app = APP_MAP[app_id]
        try:
            if app["type"] == "waydroid":
                result = subprocess.run(
                    ["/usr/bin/yunsh-android", "launch-store"],
                    capture_output=True, text=True, timeout=120
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
