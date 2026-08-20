#!/usr/bin/env python3
"""
YUNSH OS App Launcher Daemon v1.0
Listens on localhost:8590 for app launch requests from QML UI.
"""

import json
import os
import shutil
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
UI_STATE_PATH = os.environ.get("YUNSH_UI_STATE_PATH", "/tmp/yunsh-ui-state.json")
BOOT_LOCK_PATH = os.environ.get("YUNSH_BOOT_LOCK_PATH", "/etc/yunsh/boot-lock")

# Map internal app IDs to launch actions
APP_MAP = {
    "appstore": {
        "type": "waydroid",
        "name": "F-Droid",
        "command": "launch-store",
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
        elif action == "install_linux_file":
            result = self.install_linux_file(req.get("path", ""))
        elif action == "delete_download":
            result = self.delete_download(req.get("path", ""))
        elif action == "android_apps":
            result = self.android_apps()
        elif action == "system_settings":
            result = self.system_settings()
        elif action == "system_info":
            result = self.system_info()
        elif action == "delete_screenshot":
            result = self.manage_screenshot(req.get("path", ""), req.get("mode", "trash"))
        elif action == "screen_recording":
            result = self.screen_recording(req.get("command", "status"))
        elif action == "system_action":
            result = self.system_action(req.get("command", ""))
        elif action == "set_ui_state":
            result = self.set_ui_state(req.get("state", {}))

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

    def screen_recording(self, command):
        if command not in {"start", "stop", "status"}:
            return {"status": "error", "message": "Invalid recording command"}
        try:
            result = subprocess.run(
                ["/usr/bin/yunsh-recordingd", command],
                capture_output=True, text=True, timeout=45,
            )
            payload = json.loads(result.stdout or "{}")
            if result.returncode != 0:
                payload.setdefault(
                    "message", result.stderr.strip() or "Recording command failed"
                )
                payload["status"] = "error"
            return payload
        except (OSError, ValueError, subprocess.TimeoutExpired) as exc:
            return {"status": "error", "message": str(exc)}

    def system_action(self, command):
        commands = {
            "restart": ["/usr/bin/systemctl", "reboot"],
            "shutdown": ["/usr/bin/systemctl", "poweroff"],
            "factory_reset": ["/usr/bin/yunsh-factory-reset"],
        }
        if command not in commands:
            return {"status": "error", "message": "Invalid system action"}
        try:
            # Reboot and poweroff must never return directly to an unlocked
            # desktop. The launcher also writes this marker on every normal
            # boot, covering power loss and hardware resets.
            if command in {"restart", "shutdown"}:
                os.makedirs(os.path.dirname(BOOT_LOCK_PATH), exist_ok=True)
                temporary = f"{BOOT_LOCK_PATH}.tmp.{os.getpid()}"
                with open(temporary, "w", encoding="utf-8") as handle:
                    handle.write("required\n")
                os.chmod(temporary, 0o600)
                os.replace(temporary, BOOT_LOCK_PATH)
            subprocess.Popen(
                ["/bin/bash", "-c", "sleep 1; exec \"$@\"", "yunsh-system-action"]
                + commands[command],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                start_new_session=True,
            )
            return {"status": "ok", "accepted": command}
        except OSError as exc:
            return {"status": "error", "message": str(exc)}

    def set_ui_state(self, state):
        if not isinstance(state, dict):
            return {"status": "error", "message": "Invalid UI state"}
        allowed = {
            "activeAppId": str(state.get("activeAppId", ""))[:64],
            "homeVisible": state.get("homeVisible") is True,
            "appIconsVisible": state.get("appIconsVisible") is True,
            "appIconsManuallyHidden": state.get("appIconsManuallyHidden") is True,
            "worldVisible": state.get("worldVisible") is True,
            "focusMode": state.get("focusMode") is True,
            "recording": state.get("recording") is True,
            "openApps": [
                str(item)[:64] for item in state.get("openApps", [])[:32]
            ] if isinstance(state.get("openApps"), list) else [],
            "updatedAt": time.time(),
        }
        temporary = UI_STATE_PATH + ".tmp"
        try:
            with open(temporary, "w", encoding="utf-8") as handle:
                json.dump(allowed, handle)
                handle.flush()
                os.fsync(handle.fileno())
            os.replace(temporary, UI_STATE_PATH)
            return {"status": "ok"}
        except OSError as exc:
            return {"status": "error", "message": str(exc)}

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

    def install_linux_file(self, requested_path):
        """Install or launch a native Linux application from Downloads."""
        try:
            path = os.path.realpath(str(requested_path))
            if (
                os.path.commonpath((DOWNLOAD_DIR, path)) != DOWNLOAD_DIR
                or not os.path.isfile(path)
            ):
                return {"status": "error", "message": "Only files in Downloads can be opened"}

            lower = path.lower()
            if lower.endswith(".deb"):
                result = subprocess.run(
                    ["/usr/bin/apt-get", "install", "-y", "--no-install-recommends",
                     "./" + os.path.basename(path)],
                    cwd=DOWNLOAD_DIR,
                    capture_output=True,
                    text=True,
                    timeout=600,
                )
                if result.returncode != 0:
                    return {
                        "status": "error",
                        "message": result.stderr.strip() or "Linux package installation failed",
                    }
                return {"status": "ok", "message": "Linux application installed"}

            if lower.endswith(".appimage"):
                os.chmod(path, os.stat(path).st_mode | 0o111)
                env = os.environ.copy()
                env.update({
                    "HOME": "/home/yunsh",
                    "USER": "yunsh",
                    "LOGNAME": "yunsh",
                    "XDG_RUNTIME_DIR": "/run/yunsh-runtime",
                    "WAYLAND_DISPLAY": "wayland-0",
                    "XDG_SESSION_TYPE": "wayland",
                })
                subprocess.Popen(
                    [path], cwd=DOWNLOAD_DIR, env=env,
                    stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                    start_new_session=True,
                )
                return {"status": "ok", "message": "Linux AppImage is launching"}

            return {"status": "error", "message": "支持的 Linux 文件格式：.deb、.AppImage"}
        except (OSError, ValueError, subprocess.TimeoutExpired) as exc:
            return {"status": "error", "message": str(exc)}

    def delete_download(self, requested_path):
        """Delete one browser download, restricted to the Downloads folder."""
        try:
            path = os.path.realpath(str(requested_path))
            if (os.path.commonpath((DOWNLOAD_DIR, path)) != DOWNLOAD_DIR
                    or path == DOWNLOAD_DIR or not os.path.isfile(path)):
                return {"status": "error", "message": "Invalid download path"}
            os.remove(path)
            return {"status": "ok"}
        except OSError as exc:
            return {"status": "error", "message": str(exc)}

    def android_apps(self):
        try:
            result = subprocess.run(
                ["/usr/bin/yunsh-android", "list-apps-json"],
                capture_output=True,
                text=True,
                timeout=15,
            )
            data = json.loads(result.stdout or "{}")
            apps = data.get("apps", [])
            if not isinstance(apps, list):
                apps = []
            data["apps"] = apps[:48]
            data["status"] = "ok" if result.returncode == 0 else "error"
            return data
        except (OSError, ValueError, subprocess.TimeoutExpired) as exc:
            return {"status": "error", "ready": False, "apps": [], "message": str(exc)}

    def system_settings(self):
        def read_values(path):
            values = {}
            try:
                with open(path, encoding="utf-8") as handle:
                    for raw in handle:
                        if "=" not in raw:
                            continue
                        key, value = raw.split("=", 1)
                        values[key.strip()] = value.strip()
            except OSError:
                pass
            return values

        version = read_values("/etc/yunsh/version.conf").get("VERSION", "v4.0")
        language = read_values("/etc/yunsh/language.conf")
        return {
            "status": "ok",
            "version": version,
            "language": language.get("language", "简体中文"),
            "keyboard": language.get("keyboard", "拼音"),
        }

    def system_info(self):
        def read_text(path):
            try:
                with open(path, encoding="utf-8", errors="replace") as handle:
                    return handle.read()
            except OSError:
                return ""

        def read_values(path):
            values = {}
            for raw in read_text(path).splitlines():
                if "=" in raw:
                    key, value = raw.split("=", 1)
                    values[key.strip()] = value.strip()
            return values

        def human_size(value):
            units = ("B", "KB", "MB", "GB", "TB")
            size = float(max(0, value))
            index = 0
            while size >= 1024 and index < len(units) - 1:
                size /= 1024
                index += 1
            return f"{size:.1f} {units[index]}" if index else f"{int(size)} {units[index]}"

        version = read_values("/etc/yunsh/version.conf")
        mem_total = mem_available = 0
        for raw in read_text("/proc/meminfo").splitlines():
            key, _, value = raw.partition(":")
            fields = value.split()
            if key == "MemTotal" and fields:
                mem_total = int(fields[0]) * 1024
            elif key == "MemAvailable" and fields:
                mem_available = int(fields[0]) * 1024
        try:
            disk = os.statvfs("/")
            storage_total = disk.f_blocks * disk.f_frsize
            storage_free = disk.f_bavail * disk.f_frsize
        except OSError:
            storage_total = storage_free = 0
        cpu_name = ""
        for raw in read_text("/proc/cpuinfo").splitlines():
            key, separator, value = raw.partition(":")
            label = key.strip()
            if separator and (label.lower() in {"model name", "hardware"} or label == "Processor"):
                cpu_name = value.strip()
                if cpu_name:
                    break
        model = read_text("/proc/device-tree/model").replace("\x00", "").strip()
        return {
            "status": "ok",
            "version": version.get("VERSION", "v4.0"),
            "build": version.get("BUILD", ""),
            "model": model or "Raspberry Pi",
            "cpu": f"{cpu_name or 'ARM processor'} × {os.cpu_count() or 1}",
            "memoryTotal": human_size(mem_total),
            "memoryUsed": human_size(max(0, mem_total - mem_available)),
            "memoryPct": (max(0, mem_total - mem_available) / mem_total) if mem_total else 0,
            "storageTotal": human_size(storage_total),
            "storageUsed": human_size(max(0, storage_total - storage_free)),
            "storagePct": (max(0, storage_total - storage_free) / storage_total) if storage_total else 0,
            "kernel": os.uname().release,
        }

    def manage_screenshot(self, requested_path, mode="trash"):
        try:
            value = str(requested_path)
            if value.startswith("file:"):
                value = unquote(urlparse(value).path)
            path = os.path.realpath(value)
            screenshot_root = os.path.realpath(SCREENSHOT_DIR)
            trash_root = os.path.join(screenshot_root, ".RecentlyDeleted")
            hidden_root = os.path.join(screenshot_root, ".Hidden")
            allowed_roots = (screenshot_root, trash_root, hidden_root)
            if (
                not any(os.path.commonpath((root, path)) == root for root in allowed_roots)
                or not path.lower().endswith((".png", ".jpg", ".jpeg", ".webp"))
                or not os.path.isfile(path)
            ):
                return {"status": "error", "message": "Invalid screenshot path"}
            if mode == "permanent":
                if os.path.commonpath((trash_root, path)) != trash_root:
                    return {"status": "error", "message": "Only recently deleted photos can be erased permanently"}
                os.remove(path)
                return {"status": "ok", "message": "Photo permanently deleted"}
            if mode == "restore":
                destination_root = screenshot_root
            elif mode == "hide":
                destination_root = hidden_root
            elif mode == "unhide":
                destination_root = screenshot_root
            else:
                destination_root = trash_root
            os.makedirs(destination_root, mode=0o700, exist_ok=True)
            destination = os.path.join(destination_root, os.path.basename(path))
            if os.path.exists(destination):
                stem, extension = os.path.splitext(destination)
                destination = f"{stem}-{int(time.time())}{extension}"
            shutil.move(path, destination)
            return {"status": "ok", "message": "Photo updated", "path": destination}
        except (OSError, ValueError) as exc:
            return {"status": "error", "message": str(exc)}

    def launch_app(self, app_id):
        if app_id.startswith("android:"):
            import re
            package = app_id.split(":", 1)[1]
            if not re.fullmatch(r"[A-Za-z][A-Za-z0-9_]*(?:\.[A-Za-z][A-Za-z0-9_]*)+", package):
                return {"status": "error", "message": "Invalid Android package"}
            try:
                status = self.android_status()
                if not status.get("ready"):
                    self.android_retry()
                    return {"status": "preparing", "message": status.get("message", "Android is being prepared")}
                with open("/var/log/yunsh-android.log", "a", encoding="utf-8") as log:
                    subprocess.Popen(
                        ["/usr/bin/yunsh-android", "launch-package", package],
                        stdout=log, stderr=subprocess.STDOUT,
                        start_new_session=True,
                    )
                return {"status": "ok", "message": "Launching Android app"}
            except OSError as exc:
                return {"status": "error", "message": str(exc)}
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
                with open("/var/log/yunsh-android.log", "a", encoding="utf-8") as log:
                    subprocess.Popen(
                        ["/usr/bin/yunsh-android", app["command"]],
                        stdout=log, stderr=subprocess.STDOUT,
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
