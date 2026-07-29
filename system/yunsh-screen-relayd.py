#!/usr/bin/env python3
"""Encrypted, user-authorized iPhone screen-frame receiver for YUNSH OS."""

import hmac
import json
import os
import socket
import ssl
import subprocess
import tempfile
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

HOST = "0.0.0.0"
PORT = int(os.environ.get("YUNSH_SCREEN_RELAY_PORT", "8596"))
CONFIG_DIR = os.environ.get("YUNSH_CONFIG_DIR", "/etc/yunsh")
PAIRING_PATH = os.environ.get(
    "YUNSH_LINK_PAIRING_PATH", "/run/yunsh/link-pairing.json"
)
FRAME_PATH = os.environ.get(
    "YUNSH_SCREEN_FRAME_PATH", "/run/yunsh/screen-relay.jpg"
)
STATUS_PATH = os.environ.get(
    "YUNSH_SCREEN_STATUS_PATH", "/run/yunsh/screen-relay-status.json"
)
CERT_PATH = os.path.join(CONFIG_DIR, "space-transfer.crt")
KEY_PATH = os.path.join(CONFIG_DIR, "space-transfer.key")
MAX_FRAME = 3 * 1024 * 1024
RATE_LOCK = threading.Lock()
LAST_FRAME_BY_ADDRESS = {}


def read_json(path):
    try:
        with open(path, encoding="utf-8") as handle:
            return json.load(handle)
    except (OSError, ValueError):
        return {}


def atomic_write(path, data, mode="wb"):
    directory = os.path.dirname(path)
    os.makedirs(directory, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix=os.path.basename(path) + ".", dir=directory)
    try:
        with os.fdopen(fd, mode) as handle:
            handle.write(data)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary, path)
    except Exception:
        try:
            os.unlink(temporary)
        except OSError:
            pass
        raise


def authorized(key):
    record = read_json(PAIRING_PATH)
    stored = str(record.get("code", "")).upper()
    supplied = str(key or "").strip().upper()
    return (
        record.get("used") is True
        and len(stored) == 6
        and hmac.compare_digest(stored, supplied)
    )


def rate_allowed(address):
    now = time.monotonic()
    with RATE_LOCK:
        previous = LAST_FRAME_BY_ADDRESS.get(address, 0)
        if now - previous < 1 / 16:
            return False
        LAST_FRAME_BY_ADDRESS[address] = now
        return True


class Handler(BaseHTTPRequestHandler):
    server_version = "YUNSHScreenRelay/2.0"

    def send_json(self, status, payload):
        body = json.dumps(payload, separators=(",", ":")).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path == "/v1/status":
            state = read_json(STATUS_PATH)
            last_frame = float(state.get("lastFrame", 0) or 0)
            self.send_json(
                200,
                {
                    "success": True,
                    "live": time.time() - last_frame < 3,
                    "lastFrame": last_frame,
                    "width": state.get("width"),
                    "height": state.get("height"),
                },
            )
            return
        self.send_json(404, {"success": False})

    def do_POST(self):
        if self.path != "/v1/frame":
            self.send_json(404, {"success": False})
            return
        if not authorized(self.headers.get("X-YUNSH-Key")):
            self.send_json(403, {"success": False, "error": "Pairing key required"})
            return
        if not rate_allowed(self.client_address[0]):
            self.send_json(429, {"success": False, "error": "Frame rate limited"})
            return
        try:
            length = int(self.headers.get("Content-Length", "0"))
        except ValueError:
            length = 0
        if length < 4 or length > MAX_FRAME:
            self.send_json(413, {"success": False, "error": "Invalid frame size"})
            return
        frame = self.rfile.read(length)
        if not (frame.startswith(b"\xff\xd8") and frame.endswith(b"\xff\xd9")):
            self.send_json(400, {"success": False, "error": "JPEG frame required"})
            return
        try:
            atomic_write(FRAME_PATH, frame)
            state = {
                "live": True,
                "lastFrame": time.time(),
                "sender": self.client_address[0],
                "width": self.headers.get("X-YUNSH-Width"),
                "height": self.headers.get("X-YUNSH-Height"),
            }
            atomic_write(
                STATUS_PATH,
                (json.dumps(state, separators=(",", ":")) + "\n").encode(),
            )
            self.send_json(202, {"success": True})
        except OSError as exc:
            self.send_json(500, {"success": False, "error": str(exc)})

    def log_message(self, _format, *_args):
        return


def advertise():
    try:
        return subprocess.Popen(
            [
                "avahi-publish-service",
                socket.gethostname(),
                "_yunsh-screen._tcp",
                str(PORT),
                "version=2.0.0",
                "transport=tls-jpeg",
            ],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True,
        )
    except OSError:
        return None


if __name__ == "__main__":
    if not (os.path.isfile(CERT_PATH) and os.path.isfile(KEY_PATH)):
        raise SystemExit("YUNSH Drop certificate is not ready")
    publisher = advertise()
    server = ThreadingHTTPServer((HOST, PORT), Handler)
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    context.minimum_version = ssl.TLSVersion.TLSv1_2
    context.load_cert_chain(CERT_PATH, KEY_PATH)
    server.socket = context.wrap_socket(server.socket, server_side=True)
    try:
        server.serve_forever()
    finally:
        if publisher is not None:
            publisher.terminate()
