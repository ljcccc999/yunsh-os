#!/usr/bin/env python3
"""
YUNSH OS App Launcher Daemon v1.0
Listens on localhost:8590 for app launch requests from QML UI.
"""

import json
import os
import subprocess
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import unquote, urlparse

PORT = 8590
SCREENSHOT_DIR = os.environ.get(
    "YUNSH_SCREENSHOT_DIR", "/home/yunsh/Pictures/Screenshots"
)
DOWNLOAD_DIR = os.path.realpath(
    os.environ.get("YUNSH_DOWNLOAD_DIR", "/home/yunsh/Downloads")
)

# Map internal app IDs to launch actions
APP_MAP = {
    "appstore": {
        "type": "waydroid",
        "name": "Android Apps",
        "command": "launch-store",
    },
    "files": {
        "type": "waydroid",
        "name": "Files",
        "command": "launch-files",
    },
}


class AppHandler(BaseHTTPRequestHandler):

    def do_POST(self):
        content_length = int(self.headers.get('Content-Length', 0))
        if content_length < 0 or content_length > 1_048_576:
            self.send_error(413, "Request body too large")
            return
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
        elif action == "android_status":
            result = self.android_status()
        elif action == "android_retry":
            result = self.android_retry()
        elif action == "install_apk":
            result = self.install_apk(req.get("path", ""))
        elif action == "delete_screenshot":
            result = self.delete_screenshot(req.get("path", ""))

        self._send_json(result)

    def do_OPTIONS(self):
        self.send_response(204)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.send_header("Content-Length", "0")
        self.end_headers()

    def _send_json(self, result):
        body = json.dumps(result).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(body)

    def crop_screenshot(self, req):
        source = os.path.realpath(str(req.get("source", "")))
        temp_root = os.path.realpath("/tmp")
        if (
            os.path.commonpath((temp_root, source)) != temp_root
            or not os.path.basename(source).startswith(
                "yunsh-screenshot-region-full-"
            )
            or not source.lower().endswith(".png")
            or not os.path.isfile(source)
        ):
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
                if x >= right or y >= bottom:
                    return {
                        "status": "error",
                        "message": "Screenshot region is outside the display",
                    }
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
                    ["/usr/bin/yunsh-screenshotd", "region", str(x), str(y), str(w), str(h)],
                    capture_output=True, text=True, timeout=30
                )
            else:
                result = subprocess.run(
                    ["/usr/bin/yunsh-screenshotd", "full"],
                    capture_output=True, text=True, timeout=30
                )

            if result.returncode == 0:
                return {
                    "status": "ok",
                    "message": "Screenshot saved",
                    "path": result.stdout.strip().splitlines()[-1]
                    if result.stdout.strip() else "",
                }
            else:
                return {"status": "error", "message": result.stderr.strip()}
        except subprocess.TimeoutExpired:
            return {"status": "error", "message": "Timeout capturing screenshot"}
        except Exception as e:
            return {"status": "error", "message": str(e)}

    def android_status(self):
        try:
            result = subprocess.run(
                ["/usr/bin/yunsh-android", "status-json"],
                capture_output=True,
                text=True,
                timeout=5,
            )
            if result.returncode != 0:
                return {
                    "status": "error",
                    "state": "error",
                    "ready": False,
                    "message": result.stderr.strip() or "Android status is unavailable",
                }
            data = json.loads(result.stdout)
            data["status"] = "ok"
            return data
        except (OSError, ValueError, subprocess.TimeoutExpired) as exc:
            return {
                "status": "error",
                "state": "error",
                "ready": False,
                "message": str(exc),
            }

    def android_retry(self):
        try:
            result = subprocess.run(
                ["/usr/bin/yunsh-android", "retry"],
                capture_output=True,
                text=True,
                timeout=10,
            )
            if result.returncode == 0:
                return {
                    "status": "ok",
                    "state": "pending",
                    "ready": False,
                    "message": "Android setup retry started",
                }
            return {
                "status": "error",
                "state": "error",
                "ready": False,
                "message": result.stderr.strip() or "Could not start Android setup",
            }
        except (OSError, subprocess.TimeoutExpired) as exc:
            return {
                "status": "error",
                "state": "error",
                "ready": False,
                "message": str(exc),
            }

    def install_apk(self, requested_path):
        try:
            path = os.path.realpath(str(requested_path))
            if (
                os.path.commonpath((DOWNLOAD_DIR, path)) != DOWNLOAD_DIR
                or not path.lower().endswith(".apk")
                or not os.path.isfile(path)
            ):
                return {
                    "status": "error",
                    "message": "Only downloaded APK files can be installed",
                }
            result = subprocess.run(
                ["/usr/bin/yunsh-android", "install-apk", path],
                capture_output=True,
                text=True,
                timeout=180,
            )
            if result.returncode == 0:
                return {"status": "ok", "message": "Android app installed"}
            return {
                "status": "error",
                "message": result.stderr.strip() or "Android app installation failed",
            }
        except (OSError, ValueError, subprocess.TimeoutExpired) as exc:
            return {"status": "error", "message": str(exc)}

    def delete_screenshot(self, requested_path):
        try:
            value = str(requested_path)
            if value.startswith("file:"):
                value = unquote(urlparse(value).path)
            path = os.path.realpath(value)
            screenshot_root = os.path.realpath(SCREENSHOT_DIR)
            if (
                os.path.commonpath((screenshot_root, path)) != screenshot_root
                or not path.lower().endswith((".png", ".jpg", ".jpeg", ".webp"))
                or not os.path.isfile(path)
            ):
                return {"status": "error", "message": "Invalid screenshot path"}
            os.remove(path)
            return {"status": "ok", "message": "Screenshot deleted"}
        except (OSError, ValueError) as exc:
            return {"status": "error", "message": str(exc)}

    def launch_app(self, app_id):
        if app_id not in APP_MAP:
            return {"status": "error", "message": f"Unknown app: {app_id}"}

        app = APP_MAP[app_id]
        try:
            if app["type"] == "waydroid":
                status = self.android_status()
                if not status.get("ready"):
                    self.android_retry()
                    return {
                        "status": "preparing",
                        "state": status.get("state", "pending"),
                        "message": status.get("error") or status.get(
                            "message", "Android is being prepared"
                        ),
                    }
                subprocess.Popen(
                    ["/usr/bin/yunsh-android", app["command"]],
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                    start_new_session=True,
                )
                return {
                    "status": "ok",
                    "message": f"Launching {app['name']}",
                }
            else:
                return {"status": "error", "message": f"Unknown type: {app['type']}"}
        except Exception as e:
            return {"status": "error", "message": str(e)}

    def log_message(self, format, *args):
        pass  # Suppress HTTP request logs


def main():
    server = ThreadingHTTPServer(("127.0.0.1", PORT), AppHandler)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
