#!/usr/bin/env python3
"""Encrypted local-network receiver for YUNSH SpaceCapsule offers."""

import hashlib
import hmac
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
ALLOWED_APPS = {
    "settings", "browser", "terminal", "photos", "appstore",
    "files", "update", "about", "network", "bluetooth", "display",
    "systeminfo", "updatehistory", "spacecapsule", "comfortdna", "screenrelay",
}
RATE_LOCK = threading.Lock()
RATE_BUCKETS = {}


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

    def read_json(self):
        try:
            length = int(self.headers.get("Content-Length", "0"))
        except ValueError:
            return None
        if length <= 0 or length > MAX_BODY:
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
                    "version": "2.0.1",
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
        "version=2.0.1",
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
