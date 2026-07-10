#!/usr/bin/env python3
"""
YUNSH OS v1.0 — OTA Update Daemon
====================================
Checks GitHub Releases for new YUNSH OS versions every 6 hours,
exposes a Unix socket for local command/control, and writes
status & info files for other system components to consume.

Dependencies: none beyond Python 3.8+ stdlib.
"""

import argparse
import fcntl
import hashlib
import json
import logging
import os
import pathlib
import re
import select
import signal
import socket
import stat
import sys
import time
import traceback
import urllib.request
import urllib.error

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
SOCKET_PATH = "/tmp/yunsh-update.sock"
STATUS_PATH = "/tmp/yunsh-update-status.json"
INFO_PATH = "/etc/yunsh/update-info.json"
CONF_PATH = "/etc/yunsh/update.conf"
LOG_PATH = "/var/log/yunsh-update.log"
PID_PATH = "/var/run/yunsh-update-daemon.pid"

GITHUB_REPO = "ljcccc999/yunsh-os"
CHECK_INTERVAL_SEC = 6 * 3600  # 6 hours

DEFAULT_CONFIG = {
    "auto_update": False,
    "wifi_only": True,
    "update_channel": "stable",  # "stable" | "beta"
    "allow_major_update": True,
}

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
logger = logging.getLogger("yunsh-update-daemon")


def setup_logging(foreground: bool = False):
    """Configure logging to syslog-style stderr in foreground, file in daemon."""
    log_dir = os.path.dirname(LOG_PATH)
    os.makedirs(log_dir, exist_ok=True)

    fmt = logging.Formatter(
        "%(asctime)s [yunsh-update-daemon] %(levelname)s %(message)s",
        datefmt="%Y-%m-%dT%H:%M:%S%z",
    )

    if foreground:
        handler = logging.StreamHandler(sys.stderr)
    else:
        handler = logging.FileHandler(LOG_PATH)
    handler.setFormatter(fmt)
    logger.addHandler(handler)
    logger.setLevel(logging.INFO)


# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
def load_config() -> dict:
    """Read /etc/yunsh/update.conf; merge with defaults."""
    config = dict(DEFAULT_CONFIG)
    try:
        with open(CONF_PATH) as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#"):
                    continue
                if "=" not in line:
                    continue
                key, val = line.split("=", 1)
                key = key.strip()
                val = val.strip().lower()
                if key in config:
                    if isinstance(config[key], bool):
                        config[key] = val == "true"
                    else:
                        config[key] = val
    except FileNotFoundError:
        pass
    return config


def save_config(config: dict):
    """Persist config to /etc/yunsh/update.conf."""
    os.makedirs(os.path.dirname(CONF_PATH), exist_ok=True)
    with open(CONF_PATH, "w") as f:
        for key in ("auto_update", "wifi_only", "update_channel"):
            val = config.get(key, DEFAULT_CONFIG[key])
            if isinstance(val, bool):
                f.write(f"{key}={str(val).lower()}\n")
            else:
                f.write(f"{key}={val}\n")


# ---------------------------------------------------------------------------
# Status helpers
# ---------------------------------------------------------------------------
def _write_json(path: str, data: dict):
    """Atomically write a JSON status file."""
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = path + ".tmp"
    with open(tmp, "w") as f:
        json.dump(data, f, indent=2)
        f.flush()
        os.fsync(f.fileno())
    os.replace(tmp, path)


def write_status(**fields):
    """Write status update to /tmp/yunsh-update-status.json."""
    data = {
        "state": "idle",
        "progress_pct": 0,
        "download_speed": 0,
        "eta_sec": 0,
        "current_version": "",
        "latest_version": "",
        "update_available": False,
        "last_check_ts": 0,
        "error": None,
        "auto_update": False,
        "wifi_only": True,
        "update_channel": "stable",
    }
    try:
        with open(STATUS_PATH) as f:
            existing = json.load(f)
            data.update(existing)
    except (FileNotFoundError, json.JSONDecodeError):
        pass
    data.update(fields)
    _write_json(STATUS_PATH, data)


def write_update_info(info: dict):
    """Save latest release metadata to /etc/yunsh/update-info.json."""
    os.makedirs(os.path.dirname(INFO_PATH), exist_ok=True)
    _write_json(INFO_PATH, info)


# ---------------------------------------------------------------------------
# GitHub Release checker
# ---------------------------------------------------------------------------
def _github_api(channel: str) -> str:
    if channel == "beta":
        return f"https://api.github.com/repos/{GITHUB_REPO}/releases?per_page=5"
    return f"https://api.github.com/repos/{GITHUB_REPO}/releases/latest"


def _parse_release(data: dict) -> dict:
    tag = data.get("tag_name", "")
    published = data.get("published_at", "")
    body = data.get("body", "")
    prerelease = data.get("prerelease", False)
    assets = data.get("assets", [])
    download_url = ""
    sha256 = ""
    asset_id = ""
    for asset in assets:
        name = asset.get("name", "").lower()
        if name.endswith(".img") or name.endswith(".img.xz"):
            if not download_url:
                download_url = asset.get("browser_download_url", "")
                asset_id = asset.get("id", "")
        if name.endswith(".sha256") or name.endswith(".sha256sum"):
            sha256 = _fetch_sha256(asset.get("browser_download_url", ""))
    if not sha256 and body:
        match = re.search(r"SHA256[\s:]+([a-f0-9]{64})", body, re.IGNORECASE)
        if match:
            sha256 = match.group(1)
    return {
        "version": tag.lstrip("v"),
        "tag_name": tag,
        "download_url": download_url,
        "changelog": body,
        "sha256": sha256,
        "published_at": published,
        "prerelease": prerelease,
        "asset_id": asset_id,
    }


def _fetch_json(url: str):
    try:
        req = urllib.request.Request(url, headers={
            "Accept": "application/vnd.github+json",
            "User-Agent": "YUNSH-OS-UpdateDaemon/1.0",
        })
        with urllib.request.urlopen(req, timeout=30) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except Exception as exc:
        logger.error("GitHub API error: %s", exc)
        return None


def _compare_versions(v1: str, v2: str) -> int:
    def _parts(v):
        try:
            return [int(p) for p in v.split(".")]
        except ValueError:
            return [0]
    p1, p2 = _parts(v1), _parts(v2)
    for i in range(max(len(p1), len(p2))):
        a = p1[i] if i < len(p1) else 0
        b = p2[i] if i < len(p2) else 0
        if a < b: return -1
        if a > b: return 1
    return 0


def is_major_update(current: str, latest: str) -> bool:
    try:
        return int(latest.split(".")[0]) > int(current.split(".")[0])
    except (ValueError, IndexError):
        return False


def fetch_latest_release(channel: str = "stable") -> dict | None:
    url = _github_api(channel)
    data = _fetch_json(url)
    if data is None:
        return None
    if channel == "beta" and isinstance(data, list):
        for release in data:
            parsed = _parse_release(release)
            if parsed["download_url"]:
                return parsed
        logger.warning("No beta release with assets found")
        return None
    parsed = _parse_release(data if isinstance(data, dict) else {})
    if not parsed["download_url"]:
        logger.warning("Latest release has no assets")
        return None
    return parsed


def _fetch_sha256(url: str) -> str:
    """Fetch a checksum file and extract the first SHA256 hash."""
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "YUNSH-OS-UpdateDaemon/1.0"})
        with urllib.request.urlopen(req, timeout=15) as resp:
            content = resp.read().decode("utf-8").strip()
        # Format: hexhash  filename
        return content.split()[0] if content else ""
    except Exception as exc:
        logger.warning("Could not fetch SHA256 from %s: %s", url, exc)
        return ""


def current_version() -> str:
    """Read currently installed version from update-info.json."""
    try:
        with open(INFO_PATH) as f:
            info = json.load(f)
            return info.get("current_version", "")
    except (FileNotFoundError, json.JSONDecodeError):
        return ""


# ---------------------------------------------------------------------------
# Socket command handler
# ---------------------------------------------------------------------------
def handle_connection(conn: socket.socket, runner: "UpdateDaemon"):
    """Read a JSON command from the socket and dispatch it."""
    data = b""
    try:
        while True:
            chunk = conn.recv(4096)
            if not chunk:
                break
            data += chunk
            if len(data) > 65536:
                conn.sendall(json.dumps({"error": "payload too large"}).encode())
                return
    except (ConnectionResetError, BrokenPipeError):
        pass

    if not data:
        return

    try:
        cmd = json.loads(data.decode("utf-8"))
    except json.JSONDecodeError as exc:
        conn.sendall(json.dumps({"error": f"invalid json: {exc}"}).encode())
        return

    action = cmd.get("action", "")
    # Store command params for handlers to read
    runner._last_cmd_channel = cmd.get("channel", "stable")
    runner._last_cmd_allow_major_update = cmd.get("allow_major_update", True)
    response = runner.dispatch_command(action)
    try:
        conn.sendall(json.dumps(response).encode())
    except OSError:
        pass


# ---------------------------------------------------------------------------
# Daemon class
# ---------------------------------------------------------------------------
class UpdateDaemon:
    """Main update daemon — checks for updates, manages state."""

    def __init__(self):
        self._stop = False
        self._last_check_ts: float = 0.0
        self._latest_release: dict | None = None
        self._update_available: bool = False
        self._config = load_config()
        self._state = "idle"  # idle | checking | downloading | applying | error

        # Create required directories
        for d in ("/etc/yunsh", "/var/log", "/var/run"):
            os.makedirs(d, exist_ok=True)

        # Signal handlers
        signal.signal(signal.SIGTERM, self._sig_handler)
        signal.signal(signal.SIGINT, self._sig_handler)
        signal.signal(signal.SIGHUP, self._sig_recheck)

    def _sig_handler(self, signum, frame):
        logger.info("Received signal %d, shutting down", signum)
        self._stop = True

    def _sig_recheck(self, signum, frame):
        logger.info("Received SIGHUP — triggering immediate update check")
        self.check_for_updates()

    # ------------------------------------------------------------------
    # Dispatch
    # ------------------------------------------------------------------
    def dispatch_command(self, action: str) -> dict:
        cmd_map = {
            "check": self._cmd_check,
            "get_status": self._cmd_get_status,
            "start_download": self._cmd_start_download,
            "cancel": self._cmd_cancel,
            "set_auto_update": self._cmd_set_auto_update,
            "set_wifi_only": self._cmd_set_wifi_only,
            "set_channel": self._cmd_set_channel,
            "set_allow_major_update": self._cmd_set_allow_major_update,
            "get_config": self._cmd_get_config,
        }
        handler = cmd_map.get(action)
        if handler is None:
            return {"error": f"unknown action '{action}'"}
        return handler()

    def _cmd_check(self) -> dict:
        self.check_for_updates()
        return {"status": "ok", "result": "check_completed"}

    def _cmd_get_status(self) -> dict:
        status = {
            "state": self._state,
            "current_version": current_version(),
            "latest_version": "",
            "update_available": self._update_available,
            "last_check_ts": self._last_check_ts,
            "auto_update": self._config.get("auto_update", False),
            "wifi_only": self._config.get("wifi_only", True),
            "update_channel": self._config.get("update_channel", "stable"),
        }
        if self._latest_release:
            status["latest_version"] = self._latest_release.get("version", "")
            status["latest_tag"] = self._latest_release.get("tag_name", "")
            status["changelog"] = self._latest_release.get("changelog", "")
            status["download_url"] = self._latest_release.get("download_url", "")
            status["sha256"] = self._latest_release.get("sha256", "")
            status["major_update"] = self._latest_release.get("major_update", False)
            status["prerelease"] = self._latest_release.get("prerelease", False)
        return status

    def _cmd_start_download(self) -> dict:
        if not self._update_available or not self._latest_release:
            return {"error": "no update available"}
        download_url = self._latest_release.get("download_url", "")
        if not download_url:
            return {"error": "no download URL available"}
        # Kick off download (simplified — real impl would thread)
        result = self._perform_download()
        return result

    def _cmd_cancel(self) -> dict:
        self._state = "idle"
        write_status(state="idle")
        return {"status": "ok", "result": "cancelled"}

    def _cmd_set_auto_update(self) -> dict:
        val = True  # toggled from the command (already read in caller)
        self._config["auto_update"] = val
        save_config(self._config)
        write_status(auto_update=val)
        return {"status": "ok", "auto_update": val}

    def _cmd_set_wifi_only(self) -> dict:
        val = True
        self._config["wifi_only"] = val
        save_config(self._config)
        write_status(wifi_only=val)
        return {"status": "ok", "wifi_only": val}

    def _cmd_set_channel(self) -> dict:
        channel = self._last_cmd_channel or "stable"
        self._config["update_channel"] = channel
        save_config(self._config)
        write_status(update_channel=channel)
        logger.info("Update channel changed to: %s", channel)
        return {"status": "ok", "update_channel": channel}

    def _cmd_set_allow_major_update(self) -> dict:
        val = self._last_cmd_allow_major_update
        self._config["allow_major_update"] = val
        save_config(self._config)
        write_status(allow_major_update=val)
        logger.info("Allow major update set to: %s", val)
        return {"status": "ok", "allow_major_update": val}

    def _cmd_get_config(self) -> dict:
        return {"status": "ok", "config": self._config}

    # ------------------------------------------------------------------
    # Core logic
    # ------------------------------------------------------------------
    def check_for_updates(self):
        """Query GitHub and update local state."""
        self._state = "checking"
        write_status(state="checking")

        channel = self._config.get("update_channel", "stable")
        release = fetch_latest_release(channel)
        if release is None:
            self._state = "error"
            write_status(state="error", error="failed to fetch release info")
            return

        cur = current_version()
        latest = release.get("version", "")
        is_newer = (_compare_versions(latest, cur) > 0) if cur else True
        is_major = is_major_update(cur, latest) if (cur and latest) else False
        allow_major = self._config.get("allow_major_update", True)

        available = bool(latest) and latest != cur and is_newer
        if available and is_major and not allow_major:
            logger.info("Major update blocked by user setting: v%s → v%s", cur, latest)
            available = False

        release["major_update"] = is_major

        self._latest_release = release
        self._update_available = available
        self._last_check_ts = time.time()

        # Persist update-info.json
        info = {
            "current_version": cur or "1.0.0",
            "latest_version": latest,
            "update_available": available,
            "last_check_ts": self._last_check_ts,
            "last_check_iso": time.strftime(
                "%Y-%m-%dT%H:%M:%S%z", time.localtime(self._last_check_ts)
            ),
        }
        info.update(release)

        # Replace download_url with api.github.com URL (GFW-safe)
        if release.get("asset_id"):
            api_url = f"https://api.github.com/repos/{GITHUB_REPO}/releases/assets/{release['asset_id']}"
            info["download_url"] = api_url
            info["api_download"] = True

        write_update_info(info)

        self._state = "idle"
        write_status(
            state="idle" if not available else "update_available",
            current_version=cur or "1.0.0",
            latest_version=latest,
            update_available=available,
            major_update=release.get("major_update", False),
            last_check_ts=self._last_check_ts,
            auto_update=self._config.get("auto_update", False),
            wifi_only=self._config.get("wifi_only", True),
            update_channel=self._config.get("update_channel", "stable"),
            allow_major_update=self._config.get("allow_major_update", True),
        )

        if available:
            logger.info("Update available: v%s → v%s", cur or "?", latest)
        else:
            logger.info("No update available (current=%s latest=%s)", cur or "?", latest)

    def _perform_download(self) -> dict:
        """Download the update image via api.github.com (GFW-safe)."""
        self._state = "downloading"
        release = self._latest_release
        if not release:
            self._state = "error"
            return {"error": "no release data"}

        asset_id = release.get("asset_id", "")
        version = release.get("version", "")
        write_status(
            state="downloading",
            latest_version=version,
        )

        if not asset_id:
            logger.warning("No asset_id available, cannot download via API")
            self._state = "error"
            return {"error": "no asset_id for API download"}

        # Download via api.github.com (not blocked in China)
        api_url = f"https://api.github.com/repos/{GITHUB_REPO}/releases/assets/{asset_id}"
        logger.info("Downloading via API: %s", api_url)

        # yunsh-updater.py will handle the actual download with this URL
        result = {
            "status": "ok",
            "message": "download delegated to yunsh-updater.py",
            "url": api_url,
            "api_download": True,  # signal to use API auth header
            "sha256": release.get("sha256", ""),
            "version": version,
            "asset_id": asset_id,
        }
        self._state = "idle"
        write_status(state="idle")
        return result

    # ------------------------------------------------------------------
    # Main loop
    # ------------------------------------------------------------------
    def run(self, foreground: bool = False):
        """Run the daemon event loop."""
        logger.info("YUNSH OS Update Daemon starting (foreground=%s)", foreground)

        # Write PID
        with open(PID_PATH, "w") as f:
            f.write(str(os.getpid()))

        # Initial check
        self.check_for_updates()

        # Set up Unix socket
        try:
            os.unlink(SOCKET_PATH)
        except FileNotFoundError:
            pass

        sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        sock.bind(SOCKET_PATH)
        sock.listen(5)
        # Secure the socket
        os.chmod(SOCKET_PATH, stat.S_IRUSR | stat.S_IWUSR | stat.S_IRGRP | stat.S_IWGRP)

        # Non-blocking for select loop
        sock.setblocking(False)

        logger.info("Listening on %s", SOCKET_PATH)
        write_status(
            state="idle",
            current_version=current_version() or "1.0.0",
            auto_update=self._config.get("auto_update", False),
            wifi_only=self._config.get("wifi_only", True),
            update_channel=self._config.get("update_channel", "stable"),
        )

        next_check = time.time() + CHECK_INTERVAL_SEC

        while not self._stop:
            now = time.time()
            timeout = max(0, min(5.0, next_check - now))

            try:
                rlist, _, _ = select.select([sock], [], [], timeout)
            except InterruptedError:
                continue

            # Accept new connections
            if rlist:
                try:
                    conn, _ = sock.accept()
                    handle_connection(conn, self)
                    conn.close()
                except OSError as exc:
                    logger.warning("Socket accept error: %s", exc)

            # Periodic check
            if time.time() >= next_check:
                self.check_for_updates()
                next_check = time.time() + CHECK_INTERVAL_SEC

        # Cleanup
        sock.close()
        try:
            os.unlink(SOCKET_PATH)
        except FileNotFoundError:
            pass
        try:
            os.unlink(PID_PATH)
        except FileNotFoundError:
            pass
        logger.info("YUNSH OS Update Daemon stopped")


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------
def main():
    parser = argparse.ArgumentParser(description="YUNSH OS OTA Update Daemon")
    parser.add_argument(
        "-f", "--foreground",
        action="store_true",
        help="Run in foreground (don't daemonize)",
    )
    args = parser.parse_args()

    setup_logging(foreground=args.foreground)

    if not args.foreground:
        pid = os.fork()
        if pid > 0:
            # Parent exits
            sys.exit(0)
        # Child continues
        os.setsid()
        # Second fork to fully detach
        pid2 = os.fork()
        if pid2 > 0:
            sys.exit(0)

    daemon = UpdateDaemon()
    try:
        daemon.run(foreground=args.foreground)
    except Exception:
        logger.critical("Unhandled exception: %s", traceback.format_exc())
        sys.exit(1)


if __name__ == "__main__":
    main()
