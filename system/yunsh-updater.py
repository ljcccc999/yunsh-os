#!/usr/bin/env python3
"""Download, verify, and safely install a YUNSH OS OTA application bundle."""

import argparse
import fcntl
import hashlib
import json
import logging
import os
import re
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
LOCK_PATH = os.environ.get("YUNSH_OTA_LOCK_PATH", "/run/lock/yunsh-update.lock")
BACKUP_ROOT = os.environ.get("YUNSH_OTA_BACKUP_ROOT", "/var/lib/yunsh-update/backups")
HISTORY_PATH = os.environ.get("YUNSH_OTA_HISTORY_PATH", "/var/lib/yunsh-update/history.json")
INSTALL_ROOT = os.environ.get("YUNSH_OTA_ROOT", "/")
MANIFEST_PATH = os.environ.get("YUNSH_OTA_MANIFEST_PATH", "/var/lib/yunsh-update/update.manifest.json")

ALLOWED_PREFIXES = (
    "usr/bin/",
    "usr/share/yunsh/",
    "etc/systemd/system/",
    "etc/yunsh/android.conf",
    "etc/yunsh/openxr.conf",
    "etc/yunsh/version.conf",
    "etc/yunsh/update.conf",
    "etc/yunsh/display.conf",
)

logger = logging.getLogger("yunsh-updater")
logger.setLevel(logging.INFO)
handler = logging.StreamHandler(sys.stdout)
handler.setFormatter(logging.Formatter(
    "%(asctime)s [yunsh-updater] %(levelname)s %(message)s",
    datefmt="%Y-%m-%dT%H:%M:%S%z",
))
logger.addHandler(handler)


def _version_parts(value: str):
    match = re.fullmatch(r"v?(\d+(?:\.\d+)*)", str(value).strip())
    if not match:
        return None
    return tuple(int(part) for part in match.group(1).split("."))


def _compare_versions(left: str, right: str) -> int:
    left_parts = _version_parts(left)
    right_parts = _version_parts(right)
    if left_parts is None or right_parts is None:
        raise ValueError(f"invalid OTA version: {left!r} or {right!r}")
    length = max(len(left_parts), len(right_parts))
    left_padded = left_parts + (0,) * (length - len(left_parts))
    right_padded = right_parts + (0,) * (length - len(right_parts))
    return (left_padded > right_padded) - (left_padded < right_padded)


def _installed_version() -> str:
    path = os.path.join(INSTALL_ROOT, "etc/yunsh/version.conf")
    try:
        with open(path, encoding="utf-8") as handle:
            for line in handle:
                if line.startswith("VERSION="):
                    return line.split("=", 1)[1].strip().lstrip("v")
    except OSError:
        pass
    return ""


def _validate_compatibility(manifest: dict, target_version: str) -> str:
    current_version = _installed_version()
    if not current_version:
        raise ValueError("cannot determine installed YUNSH OS version")
    min_base = str(manifest.get("min_base_version", "")).lstrip("v")
    max_base = str(manifest.get("max_base_version", "")).lstrip("v")
    if not min_base or not max_base:
        raise ValueError("OTA manifest has no base-version compatibility range")
    if _compare_versions(target_version, current_version) < 0:
        raise ValueError(f"OTA downgrade is not allowed: {current_version} -> {target_version}")
    if _compare_versions(current_version, min_base) < 0:
        raise ValueError(f"OTA requires base >= {min_base}; installed {current_version}")
    if _compare_versions(current_version, max_base) > 0:
        raise ValueError(f"OTA supports base <= {max_base}; installed {current_version}")
    current_major = _version_parts(current_version)[0]
    target_major = _version_parts(target_version)[0]
    major_delta = target_major - current_major
    if major_delta > 1:
        raise ValueError(
            f"unsupported cross-major OTA jump: {current_version} -> {target_version}; "
            "install the intermediate major version first"
        )
    upgrade_class = manifest.get("upgrade_class", "")
    if major_delta == 1 and upgrade_class != "major-bridge":
        raise ValueError("cross-major OTA requires upgrade_class=major-bridge")
    if major_delta == 0 and upgrade_class not in {"same-major", "major-bridge"}:
        raise ValueError("same-major OTA has an invalid upgrade class")
    return current_version


def acquire_update_lock():
    """Allow only one OTA process to download/install at a time."""
    os.makedirs(os.path.dirname(LOCK_PATH), exist_ok=True)
    handle = open(LOCK_PATH, "w", encoding="utf-8")
    try:
        fcntl.flock(handle.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        handle.close()
        return None
    return handle


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


def _append_history(result: dict):
    history = _read_json(HISTORY_PATH)
    entries = history if isinstance(history, list) else history.get("entries", [])
    if not isinstance(entries, list):
        entries = []
    entry = {
        "version": result.get("version", ""),
        "build": result.get("build", ""),
        "installed_at": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
        "success": bool(result.get("success")),
    }
    entries = [entry] + [item for item in entries if item.get("version") != entry["version"]]
    _write_json(HISTORY_PATH, {"entries": entries[:20]})


def _status(**fields):
    data = _read_json(STATUS_PATH)
    data.update(fields)
    _write_json(STATUS_PATH, data)


def auto_reboot_enabled() -> bool:
    """Read the image policy without affecting isolated OTA test roots."""
    config_path = os.path.join(INSTALL_ROOT, "etc/yunsh/update.conf")
    try:
        with open(config_path, encoding="utf-8") as handle:
            for line in handle:
                key, separator, value = line.strip().partition("=")
                if separator and key.strip() == "auto_reboot":
                    return value.strip().lower() == "true"
    except OSError:
        pass
    return False


def schedule_reboot() -> bool:
    """Reboot only after a verified, atomic OTA install has completed."""
    try:
        subprocess.Popen(
            ["systemctl", "reboot", "--no-wall"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True,
        )
        _status(state="rebooting", progress_pct=100,
                reboot_required=True, error=None)
        return True
    except OSError as exc:
        logger.error("Could not schedule automatic reboot: %s", exc)
        _status(state="restart_required", reboot_required=True, error=str(exc))
        return False


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


def _range_download(url: str, offset: int, length: int, api_download: bool = False) -> bytes:
    if offset < 0 or length <= 0:
        raise ValueError("invalid OTA chunk range")
    headers = {
        "User-Agent": "YUNSH-OS-Updater/1.0",
        "Range": f"bytes={offset}-{offset + length - 1}",
    }
    if api_download:
        headers["Accept"] = "application/octet-stream"
    request = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(request, timeout=300) as response:
        data = response.read()
        status = getattr(response, "status", response.getcode())
        if status != 206 and len(data) != length:
            raise ValueError(
                f"OTA server did not honor byte range {offset}:{offset + length - 1} "
                f"(HTTP {status}, {len(data)} bytes)"
            )
    if len(data) != length:
        raise ValueError(f"OTA chunk length mismatch: expected {length}, got {len(data)}")
    return data


def _atomic_install(file_sources, version: str, build: str, from_version: str,
                    modes=None) -> dict:
    """Stage and atomically replace only the changed YUNSH-owned files."""
    backup = os.path.join(BACKUP_ROOT, time.strftime("%Y%m%d-%H%M%S"))
    staged = []
    installed = []
    new_destinations = set()
    modes = modes or {}
    try:
        for source, relative in file_sources:
            destination = os.path.join(INSTALL_ROOT, relative)
            os.makedirs(os.path.dirname(destination), exist_ok=True)
            temporary = destination + ".yunsh-new"
            shutil.copy2(source, temporary)
            if relative in modes:
                os.chmod(temporary, modes[relative])
            elif relative.startswith("usr/bin/"):
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
            "yunsh-grow-root.service", "orbit.service", "orbit-voice-setup.service",
            "yunsh-media-setup.service", "yunsh-time-sync.service",
        ):
            if os.path.exists(os.path.join(INSTALL_ROOT, "etc/systemd/system", unit)):
                subprocess.run(["systemctl", "enable", unit], check=False)
    except FileNotFoundError:
        logger.warning("systemctl is unavailable; daemon reload deferred to reboot")

    result = {
        "success": True,
        "version": version,
        "from_version": from_version,
        "build": build,
        "files_installed": len(file_sources),
        "backup": backup,
        "reboot_required": True,
        "timestamp": time.time(),
    }
    _write_json(RESULT_PATH, result)
    _status(state="restart_required", progress_pct=100,
            current_version=version, current_build=build,
            update_available=False, error=None, reboot_required=True)
    return result


def install_delta(manifest_path: str, chunks_url: str, api_download: bool = False) -> dict:
    """Build only changed files from a content-addressed, range-readable store."""
    if not os.path.isfile(manifest_path):
        return {"success": False, "error": f"manifest not found: {manifest_path}"}
    _status(state="planning", progress_pct=0)
    try:
        with open(manifest_path, encoding="utf-8") as handle:
            manifest = json.load(handle)
        if manifest.get("format") != "yunsh-ota-delta-v1":
            raise ValueError("unsupported delta OTA manifest format")
        version = str(manifest.get("version", "")).lstrip("v")
        build = str(manifest.get("build", ""))
        if not version or not chunks_url:
            raise ValueError("delta OTA manifest or chunk URL is incomplete")
        from_version = _validate_compatibility(manifest, version)
        files = manifest.get("files", {})
        if not isinstance(files, dict) or not files:
            raise ValueError("delta OTA manifest has no files")
        store_size = int(manifest.get("chunk_store_size", 0))
        if store_size <= 0:
            raise ValueError("delta OTA manifest has no chunk store size")

        with tempfile.TemporaryDirectory(prefix="yunsh-delta-ota-") as temp_dir:
            changed = []
            modes = {}
            total_chunks = sum(len(item.get("chunks", [])) for item in files.values())
            downloaded_chunks = 0
            for relative, item in sorted(files.items()):
                if not any(relative == prefix or relative.startswith(prefix)
                           for prefix in ALLOWED_PREFIXES):
                    raise ValueError(f"OTA destination is not allowed: /{relative}")
                target = os.path.join(INSTALL_ROOT, relative)
                target_hash = str(item.get("sha256", ""))
                target_size = int(item.get("size", -1))
                chunks = item.get("chunks", [])
                if not target_hash or target_size < 0 or not isinstance(chunks, list):
                    raise ValueError(f"invalid delta file entry: {relative}")

                if os.path.isfile(target) and os.path.getsize(target) == target_size:
                    with open(target, "rb") as handle:
                        if hashlib.sha256(handle.read()).hexdigest() == target_hash:
                            continue

                output = os.path.join(temp_dir, "payload", relative)
                os.makedirs(os.path.dirname(output), exist_ok=True)
                digest = hashlib.sha256()
                written = 0
                with open(output, "wb") as handle:
                    for chunk in chunks:
                        offset = int(chunk.get("offset", -1))
                        length = int(chunk.get("length", -1))
                        chunk_hash = str(chunk.get("sha256", ""))
                        if offset < 0 or length <= 0 or offset + length > store_size:
                            raise ValueError(f"invalid chunk range: {relative}")
                        data = None
                        if os.path.isfile(target) and os.path.getsize(target) >= written + length:
                            with open(target, "rb") as old:
                                old.seek(written)
                                candidate = old.read(length)
                            if hashlib.sha256(candidate).hexdigest() == chunk_hash:
                                data = candidate
                        if data is None:
                            data = _range_download(chunks_url, offset, length, api_download)
                            downloaded_chunks += 1
                            if hashlib.sha256(data).hexdigest() != chunk_hash:
                                raise ValueError(f"OTA chunk checksum mismatch: {relative}")
                        handle.write(data)
                        digest.update(data)
                        written += len(data)
                        _status(state="downloading", downloaded_chunks=downloaded_chunks,
                                total_chunks=total_chunks,
                                progress_pct=int(downloaded_chunks * 100 / max(total_chunks, 1)))
                if written != target_size or digest.hexdigest() != target_hash:
                    raise ValueError(f"delta OTA file checksum mismatch: {relative}")
                changed.append((output, relative))
                modes[relative] = int(item.get("mode", 0o644)) & 0o7777

            result = _atomic_install(changed, version, build, from_version, modes)
            result["chunks_downloaded"] = downloaded_chunks
            _write_json(RESULT_PATH, result)
            return result
    except Exception as exc:
        result = {"success": False, "error": str(exc), "timestamp": time.time()}
        _write_json(RESULT_PATH, result)
        _status(state="error", error=str(exc))
        return result


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
                    "yunsh-grow-root.service",
                    "orbit.service",
                    "orbit-voice-setup.service",
                    "yunsh-media-setup.service",
                    "yunsh-time-sync.service",
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
    lock = acquire_update_lock()
    if lock is None:
        result = {"success": False, "already_running": True,
                  "error": "another OTA update is already in progress"}
        _write_json(RESULT_PATH, result)
        return result
    info = _read_json(INFO_PATH)
    url = info.get("download_url", "")
    expected = info.get("sha256", "")
    manifest_url = info.get("manifest_url", "")
    chunks_url = info.get("chunks_url", "")
    version = info.get("latest_version", "")
    if (not manifest_url and not url) or not version:
        result = {"success": False, "error": "no compatible OTA update available"}
        _write_json(RESULT_PATH, result)
        fcntl.flock(lock.fileno(), fcntl.LOCK_UN)
        lock.close()
        return result

    try:
        if manifest_url:
            manifest_sha256 = info.get("manifest_sha256", "")
            download_bundle(
                manifest_url,
                MANIFEST_PATH,
                manifest_sha256,
                api_download=bool(info.get("manifest_api_download"))
                or manifest_url.startswith("https://api.github.com/"),
            )
            result = install_delta(
                MANIFEST_PATH,
                chunks_url,
                api_download=bool(info.get("chunks_api_download"))
                or chunks_url.startswith("https://api.github.com/"),
            )
        else:
            download_bundle(
                url,
                DOWNLOAD_PATH,
                expected,
                api_download=bool(info.get("api_download")) or url.startswith("https://api.github.com/"),
            )
            result = install_bundle(DOWNLOAD_PATH)
        if result.get("success"):
            _append_history(result)
            if auto_reboot_enabled():
                result["reboot_scheduled"] = schedule_reboot()
            _write_json(RESULT_PATH, result)
    except (OSError, ValueError, urllib.error.URLError) as exc:
        result = {"success": False, "error": str(exc), "timestamp": time.time()}
        _write_json(RESULT_PATH, result)
        _status(state="error", error=str(exc))
    finally:
        try:
            os.remove(DOWNLOAD_PATH)
        except OSError:
            pass
        try:
            os.remove(MANIFEST_PATH)
        except OSError:
            pass
        try:
            fcntl.flock(lock.fileno(), fcntl.LOCK_UN)
            lock.close()
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
