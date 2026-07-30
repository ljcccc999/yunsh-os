#!/usr/bin/env python3
"""Download, verify, and safely install a YUNSH OS OTA application bundle."""

import argparse
import hashlib
import json
import logging
import os
import shutil
import subprocess
import sys
import tarfile
import tempfile
import time
import urllib.error
import urllib.request

# The defaults are the production locations.  Overrides make the installer
# testable against a staged root without ever writing to the host system.
RESULT_PATH = os.environ.get("YUNSH_OTA_RESULT_PATH", "/tmp/yunsh-update-result.json")
STATUS_PATH = os.environ.get("YUNSH_OTA_STATUS_PATH", "/tmp/yunsh-update-status.json")
INFO_PATH = os.environ.get("YUNSH_OTA_INFO_PATH", "/etc/yunsh/update-info.json")
DOWNLOAD_PATH = os.environ.get("YUNSH_OTA_DOWNLOAD_PATH", "/var/lib/yunsh-update/update.ota.tar.gz")
BACKUP_ROOT = os.environ.get("YUNSH_OTA_BACKUP_ROOT", "/var/lib/yunsh-update/backups")
INSTALL_ROOT = os.environ.get("YUNSH_OTA_ROOT", "/")

ALLOWED_PREFIXES = (
    "usr/bin/",
    "usr/share/yunsh/",
    "etc/systemd/system/",
    "etc/yunsh/version.conf",
)

logger = logging.getLogger("yunsh-updater")
logger.setLevel(logging.INFO)
handler = logging.StreamHandler(sys.stdout)
handler.setFormatter(logging.Formatter(
    "%(asctime)s [yunsh-updater] %(levelname)s %(message)s",
    datefmt="%Y-%m-%dT%H:%M:%S%z",
))
logger.addHandler(handler)


def _write_json(path: str, data: dict):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as handle:
        json.dump(data, handle, indent=2)
        handle.flush()
        os.fsync(handle.fileno())
    os.replace(tmp, path)


def _read_json(path: str) -> dict:
    try:
        with open(path, encoding="utf-8") as handle:
            return json.load(handle)
    except (OSError, ValueError):
        return {}


def _status(**fields):
    data = _read_json(STATUS_PATH)
    data.update(fields)
    _write_json(STATUS_PATH, data)


def download_bundle(url: str, dest: str, expected_sha256: str = "",
                    api_download: bool = False) -> str:
    """Download an OTA bundle and verify its release checksum."""
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    headers = {"User-Agent": "YUNSH-OS-Updater/1.0"}
    if api_download:
        headers["Accept"] = "application/octet-stream"
    request = urllib.request.Request(url, headers=headers)
    temp_dest = dest + ".part"
    digest = hashlib.sha256()
    downloaded = 0

    try:
        with urllib.request.urlopen(request, timeout=300) as response:
            total = int(response.headers.get("Content-Length", 0))
            with open(temp_dest, "wb") as output:
                while True:
                    chunk = response.read(1024 * 256)
                    if not chunk:
                        break
                    output.write(chunk)
                    digest.update(chunk)
                    downloaded += len(chunk)
                    progress = int(downloaded * 100 / total) if total else 0
                    _status(
                        state="downloading",
                        progress_pct=progress,
                        downloaded_bytes=downloaded,
                        total_bytes=total,
                    )
                output.flush()
                os.fsync(output.fileno())
    except Exception:
        try:
            os.remove(temp_dest)
        except OSError:
            pass
        raise

    actual = digest.hexdigest()
    if not expected_sha256:
        os.remove(temp_dest)
        raise ValueError("release does not provide an OTA SHA256 checksum")
    if actual.lower() != expected_sha256.lower():
        os.remove(temp_dest)
        raise ValueError(f"OTA SHA256 mismatch: expected {expected_sha256}, got {actual}")
    os.replace(temp_dest, dest)
    return dest


def _safe_members(archive: tarfile.TarFile):
    members = archive.getmembers()
    names = {member.name.rstrip("/") for member in members}
    if "manifest.json" not in names:
        raise ValueError("OTA bundle is missing manifest.json")
    for member in members:
        name = member.name
        if name.startswith("/") or ".." in name.split("/"):
            raise ValueError(f"unsafe OTA path: {name}")
        if member.issym() or member.islnk() or member.isdev():
            raise ValueError(f"unsupported OTA entry: {name}")
        if name == "manifest.json" or name == "payload" or name.startswith("payload/"):
            continue
        raise ValueError(f"unexpected OTA entry: {name}")
    return members


def _payload_files(root: str):
    payload = os.path.join(root, "payload")
    for current, _dirs, files in os.walk(payload):
        for filename in files:
            source = os.path.join(current, filename)
            relative = os.path.relpath(source, payload).replace(os.sep, "/")
            if not any(relative == prefix or relative.startswith(prefix)
                       for prefix in ALLOWED_PREFIXES):
                raise ValueError(f"OTA destination is not allowed: /{relative}")
            yield source, relative


def install_bundle(bundle_path: str) -> dict:
    """Validate and atomically replace only YUNSH-owned system files."""
    if not os.path.isfile(bundle_path):
        return {"success": False, "error": f"bundle not found: {bundle_path}"}

    _status(state="installing", progress_pct=100)
    try:
        with tempfile.TemporaryDirectory(prefix="yunsh-ota-") as temp_dir:
            with tarfile.open(bundle_path, "r:gz") as archive:
                members = _safe_members(archive)
                archive.extractall(temp_dir, members=members)

            with open(os.path.join(temp_dir, "manifest.json"), encoding="utf-8") as handle:
                manifest = json.load(handle)
            if manifest.get("format") != "yunsh-ota-v1":
                raise ValueError("unsupported OTA bundle format")
            version = str(manifest.get("version", "")).lstrip("v")
            build = str(manifest.get("build", ""))
            if not version:
                raise ValueError("OTA manifest has no version")

            files = list(_payload_files(temp_dir))
            if not files:
                raise ValueError("OTA payload is empty")
            expected_files = manifest.get("files", {})
            for source, relative in files:
                expected = expected_files.get(relative, "")
                with open(source, "rb") as handle:
                    actual = hashlib.sha256(handle.read()).hexdigest()
                if not expected or actual != expected:
                    raise ValueError(f"OTA payload checksum mismatch: {relative}")
            if set(expected_files) != {relative for _source, relative in files}:
                raise ValueError("OTA manifest and payload file list differ")

            backup = os.path.join(BACKUP_ROOT, time.strftime("%Y%m%d-%H%M%S"))
            staged = []
            installed = []
            new_destinations = set()
            try:
                # Stage every file before changing the running system. This
                # prevents a missing directory or copy failure from leaving a
                # partially installed release.
                for source, relative in files:
                    destination = os.path.join(INSTALL_ROOT, relative)
                    os.makedirs(os.path.dirname(destination), exist_ok=True)
                    temporary = destination + ".yunsh-new"
                    shutil.copy2(source, temporary)
                    if relative.startswith("usr/bin/"):
                        os.chmod(temporary, 0o755)
                    elif relative.startswith("etc/systemd/system/"):
                        os.chmod(temporary, 0o644)
                    staged.append((temporary, destination, relative))

                for _temporary, destination, relative in staged:
                    if os.path.exists(destination):
                        backup_file = os.path.join(backup, relative)
                        os.makedirs(os.path.dirname(backup_file), exist_ok=True)
                        shutil.copy2(destination, backup_file)
                    else:
                        new_destinations.add(destination)

                for temporary, destination, relative in staged:
                    os.replace(temporary, destination)
                    installed.append((destination, relative))
            except Exception:
                # Roll back any destination already replaced. Files which did
                # not exist before this update are removed.
                for destination, relative in reversed(installed):
                    backup_file = os.path.join(backup, relative)
                    if os.path.exists(backup_file):
                        shutil.copy2(backup_file, destination)
                    elif destination in new_destinations:
                        try:
                            os.remove(destination)
                        except OSError:
                            pass
                for temporary, _destination, _relative in staged:
                    try:
                        os.remove(temporary)
                    except OSError:
                        pass
                raise

            try:
                subprocess.run(["systemctl", "daemon-reload"], check=False)
                for unit in (
                    "orbit.service",
                    "orbit-voice-setup.service",
                    "yunsh-media-setup.service",
                ):
                    if os.path.exists(os.path.join("/etc/systemd/system", unit)):
                        subprocess.run(["systemctl", "enable", unit], check=False)
            except FileNotFoundError:
                logger.warning("systemctl is unavailable; daemon reload deferred to reboot")
            result = {
                "success": True,
                "version": version,
                "build": build,
                "files_installed": len(files),
                "backup": backup,
                "reboot_required": True,
                "timestamp": time.time(),
            }
            _write_json(RESULT_PATH, result)
            _status(
                state="restart_required",
                progress_pct=100,
                current_version=version,
                current_build=build,
                update_available=False,
                error=None,
                reboot_required=True,
            )
            return result
    except Exception as exc:
        result = {"success": False, "error": str(exc), "timestamp": time.time()}
        _write_json(RESULT_PATH, result)
        _status(state="error", error=str(exc))
        return result


def auto_update() -> dict:
    info = _read_json(INFO_PATH)
    url = info.get("download_url", "")
    expected = info.get("sha256", "")
    version = info.get("latest_version", "")
    if not url or not version:
        result = {"success": False, "error": "no compatible OTA update available"}
        _write_json(RESULT_PATH, result)
        return result

    try:
        download_bundle(
            url,
            DOWNLOAD_PATH,
            expected,
            api_download=bool(info.get("api_download")) or url.startswith("https://api.github.com/"),
        )
        result = install_bundle(DOWNLOAD_PATH)
    except (OSError, ValueError, urllib.error.URLError) as exc:
        result = {"success": False, "error": str(exc), "timestamp": time.time()}
        _write_json(RESULT_PATH, result)
        _status(state="error", error=str(exc))
    finally:
        try:
            os.remove(DOWNLOAD_PATH)
        except OSError:
            pass
    return result


def main():
    parser = argparse.ArgumentParser(description="YUNSH OS signed OTA bundle updater")
    subparsers = parser.add_subparsers(dest="command", required=True)
    download = subparsers.add_parser("download")
    download.add_argument("url")
    download.add_argument("--sha256", required=True)
    download.add_argument("--dest", default=DOWNLOAD_PATH)
    install = subparsers.add_parser("install")
    install.add_argument("--bundle", default=DOWNLOAD_PATH)
    subparsers.add_parser("auto")
    args = parser.parse_args()

    if args.command == "download":
        download_bundle(args.url, args.dest, args.sha256)
    elif args.command == "install":
        result = install_bundle(args.bundle)
        if not result.get("success"):
            raise SystemExit(1)
    else:
        result = auto_update()
        if not result.get("success"):
            raise SystemExit(1)


if __name__ == "__main__":
    main()
