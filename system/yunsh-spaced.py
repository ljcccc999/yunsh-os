#!/usr/bin/env python3
"""Encrypted local-network receiver for YUNSH SpaceCapsule offers."""

import base64
import hashlib
import hmac
import http.client
import json
import os
import re
import socket
import ssl
import subprocess
import tempfile
import threading
import time
import uuid
from urllib.parse import parse_qs, urlparse
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

HOST = "0.0.0.0"
PORT = int(os.environ.get("YUNSH_SPACE_PORT", "8594"))
CONFIG_DIR = os.environ.get("YUNSH_CONFIG_DIR", "/etc/yunsh")
INBOX_DIR = os.environ.get("YUNSH_SPACE_INBOX_DIR", "/var/lib/yunsh/space-inbox")
CAPSULE_DIR = os.environ.get(
    "YUNSH_SPACE_CAPSULE_DIR", "/home/yunsh/Downloads"
)
PAIRING_PATH = os.environ.get(
    "YUNSH_LINK_PAIRING_PATH", "/run/yunsh/link-pairing.json"
)
CERT_PATH = os.path.join(CONFIG_DIR, "space-transfer.crt")
KEY_PATH = os.path.join(CONFIG_DIR, "space-transfer.key")
MAX_BODY = 1024 * 1024
FLOW_MAX_BODY = 35 * 1024 * 1024
FLOW_MAX_FILE = 24 * 1024 * 1024
FLOW_DIR = os.environ.get(
    "YUNSH_FLOW_DIR", "/home/yunsh/Downloads/YUNSH Flow"
)
FLOW_CLIPBOARD_PATH = os.environ.get(
    "YUNSH_FLOW_CLIPBOARD_PATH", "/run/yunsh/flow-clipboard.json"
)
ALLOWED_APPS = {
    "settings", "browser", "terminal", "photos", "appstore",
    "files", "update", "about", "network", "bluetooth", "display",
    "systeminfo", "updatehistory", "spacecapsule", "comfortdna", "screenrelay",
}
RATE_LOCK = threading.Lock()
RATE_BUCKETS = {}
ORBIT_ROUTES = {
    "/v1/phone/orbit/status": ("GET", "/v1/status"),
    "/v1/phone/orbit/chat": ("POST", "/v1/chat"),
    "/v1/phone/orbit/config": ("POST", "/v1/config"),
    "/v1/phone/orbit/approve": ("POST", "/v1/approve"),
}


def atomic_write_json(path, payload):
    directory = os.path.dirname(path)
    os.makedirs(directory, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix=os.path.basename(path) + ".", dir=directory)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            json.dump(payload, handle, ensure_ascii=False, sort_keys=True, indent=2)
            handle.write("\n")
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary, path)
    except Exception:
        try:
            os.unlink(temporary)
        except OSError:
            pass
        raise


def ensure_certificate():
    os.makedirs(CONFIG_DIR, exist_ok=True)
    if os.path.isfile(CERT_PATH) and os.path.isfile(KEY_PATH):
        return
    hostname = re.sub(r"[^A-Za-z0-9.-]", "-", socket.gethostname())[:63] or "yunsh-os"
    command = [
        "openssl", "req", "-x509", "-newkey", "rsa:2048", "-sha256",
        "-nodes", "-days", "3650", "-subj", f"/CN={hostname}",
        "-keyout", KEY_PATH, "-out", CERT_PATH,
    ]
    result = subprocess.run(command, capture_output=True, text=True, timeout=30)
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or "Could not create transfer certificate")
    os.chmod(KEY_PATH, 0o600)
    os.chmod(CERT_PATH, 0o644)


def certificate_fingerprint():
    with open(CERT_PATH, "r", encoding="utf-8") as handle:
        der = ssl.PEM_cert_to_DER_cert(handle.read())
    return hashlib.sha256(der).hexdigest()


def validate_capsule(capsule):
    if not isinstance(capsule, dict):
        return None
    if capsule.get("format") != "yunsh-space-capsule" or capsule.get("schemaVersion") != 1:
        return None
    raw_windows = capsule.get("windows")
    if not isinstance(raw_windows, list) or not raw_windows or len(raw_windows) > 20:
        return None
    for window in raw_windows:
        if not isinstance(window, dict) or window.get("appId") not in ALLOWED_APPS:
            return None
    clean = dict(capsule)
    clean["name"] = re.sub(r"[\x00-\x1f/\\\\]+", " ", str(capsule.get("name", ""))).strip()[:48] or "收到的空间"
    clean["windows"] = raw_windows
    return clean


def rate_allowed(address):
    now = time.monotonic()
    with RATE_LOCK:
        recent = [stamp for stamp in RATE_BUCKETS.get(address, []) if now - stamp < 60]
        if len(recent) >= 10:
            RATE_BUCKETS[address] = recent
            return False
        recent.append(now)
        RATE_BUCKETS[address] = recent
        return True


def phone_authorized(key):
    record = read_record_path(PAIRING_PATH)
    stored = str(record.get("code", "")).upper()
    supplied = str(key or "").strip().upper()
    return (
        record.get("used") is True
        and len(stored) == 6
        and hmac.compare_digest(stored, supplied)
    )


def orbit_proxy(method, path, payload=None):
    expected_method, upstream_path = ORBIT_ROUTES[path]
    if method != expected_method:
        return 405, {"success": False, "error": "Method not allowed"}
    body = None
    headers = {}
    if payload is not None:
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        headers["Content-Type"] = "application/json"
    connection = http.client.HTTPConnection("127.0.0.1", 8597, timeout=85)
    try:
        connection.request(method, upstream_path, body=body, headers=headers)
        response = connection.getresponse()
        raw = response.read(MAX_BODY + 1)
        if len(raw) > MAX_BODY:
            raise ValueError("Orbit response too large")
        return response.status, json.loads(raw or b"{}")
    except (OSError, ValueError, http.client.HTTPException) as exc:
        return 502, {"success": False, "error": f"Orbit unavailable: {exc}"}
    finally:
        connection.close()


def read_record_path(path):
    try:
        with open(path, "r", encoding="utf-8") as handle:
            return json.load(handle)
    except (OSError, ValueError):
        return {}


def capsule_path(filename):
    name = os.path.basename(str(filename or ""))
    if name != filename or not name.endswith(".yunshspace"):
        return None
    base = os.path.realpath(CAPSULE_DIR)
    path = os.path.realpath(os.path.join(base, name))
    return path if path.startswith(base + os.sep) else None


def phone_capsules():
    result = []
    try:
        filenames = os.listdir(CAPSULE_DIR)
    except OSError:
        return result
    for filename in filenames:
        path = capsule_path(filename)
        if not path:
            continue
        try:
            if os.path.getsize(path) > MAX_BODY:
                continue
            data = read_record_path(path)
        except OSError:
            continue
        capsule = validate_capsule(data)
        if capsule:
            result.append(
                {
                    "filename": filename,
                    "name": capsule["name"],
                    "windowCount": len(capsule["windows"]),
                    "createdAt": str(capsule.get("createdAt", "")),
                }
            )
    result.sort(key=lambda item: item["createdAt"], reverse=True)
    return result[:50]


def flow_path(filename):
    name = os.path.basename(str(filename or ""))
    if (
        name != filename
        or not name
        or len(name) > 128
        or not re.fullmatch(r"[^/\\\\\x00-\x1f]+", name)
    ):
        return None
    base = os.path.realpath(FLOW_DIR)
    path = os.path.realpath(os.path.join(base, name))
    return path if path.startswith(base + os.sep) else None


def flow_files():
    result = []
    try:
        names = os.listdir(FLOW_DIR)
    except OSError:
        return result
    for name in names:
        path = flow_path(name)
        try:
            if not path or not os.path.isfile(path):
                continue
            size = os.path.getsize(path)
            if size > FLOW_MAX_FILE:
                continue
            result.append({
                "filename": name,
                "size": size,
                "modifiedAt": os.path.getmtime(path),
            })
        except OSError:
            continue
    result.sort(key=lambda item: item["modifiedAt"], reverse=True)
    return result[:100]


def save_flow_upload(payload):
    name = str(payload.get("filename", ""))
    path = flow_path(name)
    encoded = payload.get("dataBase64")
    if not path or not isinstance(encoded, str):
        raise ValueError("Invalid Flow upload")
    try:
        data = base64.b64decode(encoded, validate=True)
    except (ValueError, TypeError) as exc:
        raise ValueError("Invalid Flow file data") from exc
    if not data or len(data) > FLOW_MAX_FILE:
        raise ValueError("Flow files must be 24 MB or smaller")
    os.makedirs(FLOW_DIR, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix=".flow-", dir=FLOW_DIR)
    try:
        with os.fdopen(fd, "wb") as handle:
            handle.write(data)
            handle.flush()
            os.fsync(handle.fileno())
        os.chmod(temporary, 0o600)
        os.replace(temporary, path)
    finally:
        try:
            os.unlink(temporary)
        except FileNotFoundError:
            pass
    return {"success": True, "filename": name, "size": len(data)}


def clipboard_text():
    for command in (["wl-paste", "--no-newline"], ["xclip", "-selection", "clipboard", "-o"]):
        try:
            result = subprocess.run(command, capture_output=True, text=True, timeout=3)
            if result.returncode == 0:
                return result.stdout[:20000]
        except (OSError, subprocess.TimeoutExpired):
            pass
    return str(read_record_path(FLOW_CLIPBOARD_PATH).get("text", ""))[:20000]


def set_clipboard_text(payload):
    text = str(payload.get("text", ""))
    if not text or len(text) > 20000 or "\x00" in text:
        raise ValueError("Clipboard text must contain 1–20000 characters")
    copied = False
    for command in (["wl-copy"], ["xclip", "-selection", "clipboard"]):
        try:
            result = subprocess.run(
                command, input=text, capture_output=True, text=True, timeout=3
            )
            if result.returncode == 0:
                copied = True
                break
        except (OSError, subprocess.TimeoutExpired):
            pass
    atomic_write_json(FLOW_CLIPBOARD_PATH, {"text": text, "updatedAt": time.time()})
    return {"success": True, "clipboardUpdated": copied}


class Handler(BaseHTTPRequestHandler):
    server_version = "YUNSHSpace/2.0"

    def send_json(self, status, payload):
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def read_json(self, max_length=MAX_BODY):
        try:
            length = int(self.headers.get("Content-Length", "0"))
        except ValueError:
            return None
        if length <= 0 or length > max_length:
            return None
        try:
            return json.loads(self.rfile.read(length))
        except (ValueError, OSError):
            return None

    def do_GET(self):
        parsed = urlparse(self.path)
        if parsed.path == "/v1/info":
            fingerprint = certificate_fingerprint()
            self.send_json(
                200,
                {
                    "success": True,
                    "name": socket.gethostname(),
                    "product": "YUNSH OS",
                    "version": "2.0.2",
                    "deviceId": fingerprint[:16],
                    "fingerprint": fingerprint,
                },
            )
            return
        if parsed.path == "/v1/phone/capsules":
            if not phone_authorized(self.headers.get("X-YUNSH-Key")):
                self.send_json(403, {"success": False, "error": "Paired phone required"})
                return
            self.send_json(200, {"success": True, "capsules": phone_capsules()})
            return
        if parsed.path == "/v1/phone/orbit/status":
            if not phone_authorized(self.headers.get("X-YUNSH-Key")):
                self.send_json(403, {"success": False, "error": "Paired phone required"})
                return
            status, result = orbit_proxy("GET", parsed.path)
            self.send_json(status, result)
            return
        if parsed.path == "/v1/phone/flow/files":
            if not phone_authorized(self.headers.get("X-YUNSH-Key")):
                self.send_json(403, {"success": False, "error": "Paired phone required"})
                return
            self.send_json(200, {"success": True, "files": flow_files()})
            return
        if parsed.path == "/v1/phone/flow/file":
            if not phone_authorized(self.headers.get("X-YUNSH-Key")):
                self.send_json(403, {"success": False, "error": "Paired phone required"})
                return
            filename = parse_qs(parsed.query).get("filename", [""])[0]
            path = flow_path(filename)
            try:
                if not path or os.path.getsize(path) > FLOW_MAX_FILE:
                    raise OSError("not found")
                with open(path, "rb") as handle:
                    body = handle.read(FLOW_MAX_FILE + 1)
            except OSError:
                self.send_json(404, {"success": False, "error": "Flow file not found"})
                return
            self.send_response(200)
            self.send_header("Content-Type", "application/octet-stream")
            self.send_header("Content-Disposition", f'attachment; filename="{filename}"')
            self.send_header("Content-Length", str(len(body)))
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            self.wfile.write(body)
            return
        if parsed.path == "/v1/phone/flow/clipboard":
            if not phone_authorized(self.headers.get("X-YUNSH-Key")):
                self.send_json(403, {"success": False, "error": "Paired phone required"})
                return
            self.send_json(200, {"success": True, "text": clipboard_text()})
            return
        if parsed.path == "/v1/phone/capsule":
            if not phone_authorized(self.headers.get("X-YUNSH-Key")):
                self.send_json(403, {"success": False, "error": "Paired phone required"})
                return
            filename = parse_qs(parsed.query).get("filename", [""])[0]
            path = capsule_path(filename)
            try:
                if not path or os.path.getsize(path) > MAX_BODY:
                    raise OSError("not found")
                with open(path, "rb") as handle:
                    body = handle.read(MAX_BODY + 1)
                if len(body) > MAX_BODY or validate_capsule(json.loads(body)) is None:
                    raise ValueError("invalid")
            except (OSError, ValueError):
                self.send_json(404, {"success": False, "error": "SpaceCapsule not found"})
                return
            self.send_response(200)
            self.send_header("Content-Type", "application/vnd.yunsh.space+json")
            self.send_header("Content-Disposition", f'attachment; filename="{filename}"')
            self.send_header("Content-Length", str(len(body)))
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            self.wfile.write(body)
            return
        if parsed.path.startswith("/v1/offers/"):
            offer_id = parsed.path.rsplit("/", 1)[-1]
            if not re.fullmatch(r"[a-f0-9]{32}", offer_id):
                self.send_json(400, {"success": False, "error": "Invalid offer"})
                return
            record = read_record(offer_id)
            if not record:
                self.send_json(404, {"success": False, "error": "Offer not found"})
                return
            self.send_json(200, {"success": True, "status": record.get("status", "pending")})
            return
        self.send_json(404, {"success": False, "error": "Not found"})

    def do_POST(self):
        if self.path in {
            "/v1/phone/flow/upload",
            "/v1/phone/flow/clipboard",
        }:
            if not phone_authorized(self.headers.get("X-YUNSH-Key")):
                self.send_json(403, {"success": False, "error": "Paired phone required"})
                return
            if not rate_allowed(self.client_address[0]):
                self.send_json(429, {"success": False, "error": "Too many Flow requests"})
                return
            payload = self.read_json(
                FLOW_MAX_BODY if self.path.endswith("/upload") else MAX_BODY
            )
            if not isinstance(payload, dict):
                self.send_json(400, {"success": False, "error": "Invalid request"})
                return
            try:
                result = (
                    save_flow_upload(payload)
                    if self.path.endswith("/upload")
                    else set_clipboard_text(payload)
                )
                self.send_json(200, result)
            except ValueError as exc:
                self.send_json(400, {"success": False, "error": str(exc)})
            except OSError as exc:
                self.send_json(500, {"success": False, "error": str(exc)})
            return
        if self.path in {
            "/v1/phone/orbit/chat",
            "/v1/phone/orbit/config",
            "/v1/phone/orbit/approve",
        }:
            if not phone_authorized(self.headers.get("X-YUNSH-Key")):
                self.send_json(403, {"success": False, "error": "Paired phone required"})
                return
            if not rate_allowed(self.client_address[0]):
                self.send_json(429, {"success": False, "error": "Too many Orbit requests"})
                return
            payload = self.read_json()
            if not isinstance(payload, dict):
                self.send_json(400, {"success": False, "error": "Invalid request"})
                return
            status, result = orbit_proxy("POST", self.path, payload)
            self.send_json(status, result)
            return
        if self.path != "/v1/offers":
            self.send_json(404, {"success": False, "error": "Not found"})
            return
        if not rate_allowed(self.client_address[0]):
            self.send_json(429, {"success": False, "error": "Too many offers"})
            return
        payload = self.read_json()
        if not isinstance(payload, dict):
            self.send_json(400, {"success": False, "error": "Invalid request"})
            return
        capsule = validate_capsule(payload.get("capsule"))
        if capsule is None:
            self.send_json(400, {"success": False, "error": "Invalid SpaceCapsule"})
            return
        offer_id = uuid.uuid4().hex
        record = {
            "offerId": offer_id,
            "status": "pending",
            "senderName": str(payload.get("senderName", "Nearby YUNSH"))[:64],
            "senderAddress": self.client_address[0],
            "receivedAt": datetime.now(timezone.utc).isoformat(),
            "capsule": capsule,
        }
        try:
            atomic_write_json(os.path.join(INBOX_DIR, offer_id + ".json"), record)
        except OSError as exc:
            self.send_json(500, {"success": False, "error": str(exc)})
            return
        self.send_json(202, {"success": True, "offerId": offer_id, "status": "pending"})

    def log_message(self, _format, *_args):
        return


def read_record(offer_id):
    try:
        with open(os.path.join(INBOX_DIR, offer_id + ".json"), "r", encoding="utf-8") as handle:
            return json.load(handle)
    except (OSError, ValueError):
        return None


def advertise(fingerprint):
    command = [
        "avahi-publish-service",
        socket.gethostname(),
        "_yunsh-space._tcp",
        str(PORT),
        f"id={fingerprint[:16]}",
        f"fp={fingerprint}",
        "version=2.0.2",
        "transport=tls",
    ]
    try:
        return subprocess.Popen(
            command,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True,
        )
    except OSError:
        return None


if __name__ == "__main__":
    ensure_certificate()
    fingerprint = certificate_fingerprint()
    advertiser = advertise(fingerprint)
    server = ThreadingHTTPServer((HOST, PORT), Handler)
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    context.minimum_version = ssl.TLSVersion.TLSv1_2
    context.load_cert_chain(CERT_PATH, KEY_PATH)
    server.socket = context.wrap_socket(server.socket, server_side=True)
    try:
        server.serve_forever()
    finally:
        if advertiser is not None:
            advertiser.terminate()
