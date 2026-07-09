#!/usr/bin/env python3
"""
YUNSH OS v1.0 — A/B Partition Updater
========================================
Downloads a firmware image from a GitHub Releases URL, verifies its SHA256
checksum, and writes it to the inactive A/B partition on the system.

Target hardware: Raspberry Pi (mmcblk0-based) with A/B slot boot scheme.

Usage:
    python3 yunsh-updater.py download <url> --sha256 <expected_hash>
    python3 yunsh-updater.py apply --image /tmp/yunsh-update.img
    python3 yunsh-updater.py auto              # read config & release info then apply

Dependencies: none beyond Python 3.8+ stdlib.
"""

import argparse
import hashlib
import json
import logging
import os
import re
import shutil
import subprocess
import sys
import time
import urllib.request
import urllib.error

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
RESULT_PATH = "/tmp/yunsh-update-result.json"
CONF_PATH = "/etc/yunsh/update.conf"
INFO_PATH = "/etc/yunsh/update-info.json"
DOWNLOAD_PATH = "/tmp/yunsh-update.img"
BLOCK_DEV = "/sys/block/mmcblk0"

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
logger = logging.getLogger("yunsh-updater")
logger.setLevel(logging.INFO)
fmt = logging.Formatter(
    "%(asctime)s [yunsh-updater] %(levelname)s %(message)s",
    datefmt="%Y-%m-%dT%H:%M:%S%z",
)
ch = logging.StreamHandler(sys.stdout)
ch.setFormatter(fmt)
logger.addHandler(ch)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
def _run(cmd: list[str], check: bool = True, capture: bool = True) -> subprocess.CompletedProcess:
    """Run a shell command and return the result."""
    logger.debug("Running: %s", " ".join(cmd))
    return subprocess.run(cmd, capture_output=capture, text=True, check=check)


def _write_json(path: str, data: dict):
    """Atomically write a JSON result file."""
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = path + ".tmp"
    with open(tmp, "w") as f:
        json.dump(data, f, indent=2)
        f.flush()
        os.fsync(f.fileno())
    os.replace(tmp, path)


def _read_json(path: str) -> dict:
    """Read a JSON file, returning empty dict on failure."""
    try:
        with open(path) as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return {}


def human_size(n: int) -> str:
    """Format bytes as human-readable."""
    for unit in ("B", "KB", "MB", "GB"):
        if n < 1024:
            return f"{n:.1f} {unit}"
        n /= 1024
    return f"{n:.1f} TB"


# ---------------------------------------------------------------------------
# Partition detection
# ---------------------------------------------------------------------------
def detect_boot_partition() -> tuple[str, str, str, str]:
    """
    Detect the current and inactive partitions.
    Returns (current_slot, current_dev, inactive_slot, inactive_dev).

    On Raspberry Pi with A/B scheme:
      - /proc/cmdline contains root=/dev/mmcblk0p2 (A) or root=/dev/mmcblk0p3 (B)
      - p2 → slot A, p3 → slot B
    """
    try:
        with open("/proc/cmdline") as f:
            cmdline = f.read()
    except FileNotFoundError:
        logger.warning("/proc/cmdline not found; assuming slot A")
        return "A", "/dev/mmcblk0p2", "B", "/dev/mmcblk0p3"

    match = re.search(r'root=(\S+)', cmdline)
    if not match:
        logger.warning("No root= in cmdline; assuming slot A")
        return "A", "/dev/mmcblk0p2", "B", "/dev/mmcblk0p3"

    root_dev = match.group(1)

    # Partition map for mmcblk0 (RPi typical layout)
    # p1: boot (FAT), p2: rootfs A, p3: rootfs B
    PART_MAP = {
        "/dev/mmcblk0p2": ("A", "/dev/mmcblk0p2", "B", "/dev/mmcblk0p3"),
        "/dev/mmcblk0p3": ("B", "/dev/mmcblk0p3", "A", "/dev/mmcblk0p2"),
        "/dev/mmcblk1p2": ("A", "/dev/mmcblk1p2", "B", "/dev/mmcblk1p3"),
        "/dev/mmcblk1p3": ("B", "/dev/mmcblk1p3", "A", "/dev/mmcblk1p2"),
        "/dev/sda2": ("A", "/dev/sda2", "B", "/dev/sda3"),
        "/dev/sda3": ("B", "/dev/sda3", "A", "/dev/sda2"),
    }

    result = PART_MAP.get(root_dev)
    if result:
        logger.info("Detected boot slot %s on %s", result[0], root_dev)
        return result

    # Fallback: scan block devices
    logger.warning("Unknown root device %s; scanning block devices", root_dev)
    return _fallback_scan(root_dev)


def _fallback_scan(root_dev: str) -> tuple[str, str, str, str]:
    """Scan /sys/block to infer slots when the root device isn't in our map."""
    base = root_dev.rstrip("0123456789")
    part_num = int(root_dev[len(base):]) if root_dev[len(base):].isdigit() else 2
    current_slot = "A" if part_num == 2 else "B"
    inactive_part = 3 if part_num == 2 else 2
    inactive_dev = f"{base}{inactive_part}"
    logger.info("Fallback: current=%s (%s), inactive=%s (%s)",
                current_slot, root_dev, inactive_slot := "B" if current_slot == "A" else "A", inactive_dev)
    return current_slot, root_dev, inactive_slot, inactive_dev


def detect_block_device() -> str:
    """Return the base block device (e.g. /dev/mmcblk0)."""
    # Prefer mmcblk0
    for dev in ("/dev/mmcblk0", "/dev/mmcblk1", "/dev/sda"):
        if os.path.exists(dev):
            return dev
    logger.warning("No block device found; falling back to mmcblk0")
    return "/dev/mmcblk0"


# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------
def load_config() -> dict:
    config = {
        "auto_update": False,
        "wifi_only": True,
        "update_channel": "stable",
    }
    try:
        with open(CONF_PATH) as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#") or "=" not in line:
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


# ---------------------------------------------------------------------------
# Download
# ---------------------------------------------------------------------------
def download_image(url: str, dest: str, expected_sha256: str = "") -> str:
    """
    Download a firmware image from *url* to *dest*.
    Shows progress percentage on stdout.
    Returns the path to the downloaded file.
    Raises on failure.
    """
    logger.info("Downloading: %s", url)
    logger.info("Destination: %s", dest)

    req = urllib.request.Request(url, headers={"User-Agent": "YUNSH-OS-Updater/1.0"})

    with urllib.request.urlopen(req, timeout=300) as resp:
        total = int(resp.headers.get("Content-Length", 0))
        downloaded = 0
        start = time.time()
        sha256 = hashlib.sha256()

        with open(dest, "wb") as f:
            while chunk := resp.read(65536):
                f.write(chunk)
                sha256.update(chunk)
                downloaded += len(chunk)

                if total > 0:
                    pct = downloaded / total * 100
                    elapsed = time.time() - start
                    speed = downloaded / elapsed if elapsed > 0 else 0
                    eta = (total - downloaded) / speed if speed > 0 else 0
                    sys.stdout.write(
                        f"\r  Progress: {pct:5.1f}%  "
                        f"({human_size(downloaded)} / {human_size(total)})  "
                        f"Speed: {human_size(speed)}/s  "
                        f"ETA: {eta:.0f}s  "
                    )
                    sys.stdout.flush()

        sys.stdout.write("\n")
        logger.info("Download complete: %s (%s)", dest, human_size(downloaded))

        actual_hash = sha256.hexdigest()
        if expected_sha256:
            logger.info("Verifying SHA256 checksum...")
            if actual_hash.lower() == expected_sha256.lower():
                logger.info("✓ SHA256 checksum matches: %s", actual_hash)
            else:
                error_msg = (
                    f"✗ SHA256 mismatch!\n"
                    f"  Expected: {expected_sha256}\n"
                    f"  Actual:   {actual_hash}"
                )
                logger.error(error_msg)
                os.remove(dest)
                raise ValueError(error_msg)
        else:
            logger.info("No expected SHA256 provided; actual hash: %s", actual_hash)

    return dest


# ---------------------------------------------------------------------------
# Apply update (A/B partition write)
# ---------------------------------------------------------------------------
def apply_update(image_path: str, inactive_dev: str) -> dict:
    """
    Write the downloaded image to the inactive partition using dd,
    then update the bootloader config.

    Returns a result dict with status info.
    """
    if not os.path.exists(image_path):
        error_msg = f"Image not found: {image_path}"
        logger.error(error_msg)
        return {"success": False, "error": error_msg}

    if not os.path.exists(inactive_dev):
        error_msg = f"Target partition not found: {inactive_dev}"
        logger.error(error_msg)
        return {"success": False, "error": error_msg}

    # Verify image file size
    img_size = os.path.getsize(image_path)
    logger.info("Image size: %s (%d bytes)", human_size(img_size), img_size)

    part_size = 0
    try:
        result = _run(["blockdev", "--getsize64", inactive_dev], check=True)
        part_size = int(result.stdout.strip())
    except (subprocess.CalledProcessError, ValueError):
        logger.warning("Could not determine partition size; proceeding anyway")

    if part_size and img_size > part_size:
        error_msg = (
            f"Image ({human_size(img_size)}) exceeds partition size ({human_size(part_size)})"
        )
        logger.error(error_msg)
        return {"success": False, "error": error_msg}

    # --- Write image to inactive partition ---
    logger.info("Writing image to %s (this may take a while)...", inactive_dev)

    # We use pv-like progress by wrapping dd with a progress reporter
    # On RPi, dd with direct I/O is faster for block devices
    try:
        bs = "4M"
        cmd = [
            "dd", f"if={image_path}", f"of={inactive_dev}",
            f"bs={bs}", "conv=fsync", "status=progress",
        ]
        logger.info("Running: %s", " ".join(cmd))
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=600)
        if result.returncode != 0:
            error_msg = f"dd failed (exit {result.returncode}): {result.stderr.strip()}"
            logger.error(error_msg)
            return {"success": False, "error": error_msg}
        logger.info("dd completed successfully")
    except subprocess.TimeoutExpired:
        error_msg = "dd timed out after 600 seconds"
        logger.error(error_msg)
        return {"success": False, "error": error_msg}
    except FileNotFoundError:
        # Fallback: use Python to write (slower but no dd dependency)
        logger.warning("dd not found; falling back to Python-based write")
        try:
            _write_image_python(image_path, inactive_dev)
        except Exception as exc:
            error_msg = f"Python write failed: {exc}"
            logger.error(error_msg)
            return {"success": False, "error": error_msg}

    # --- Verify write ---
    logger.info("Verifying written image...")
    verify_hash = _verify_partition(image_path, inactive_dev, img_size)
    if verify_hash:
        logger.info("✓ Write verified: %s", verify_hash)
    else:
        logger.warning("Could not verify image on partition")

    # --- Mark target as installed (skip firstboot + activation) ---
    _mark_target_installed(inactive_dev)

    # --- Update bootloader config ---
    success = update_bootloader(inactive_slot_for_boot=True)

    result = {
        "success": success,
        "image": image_path,
        "target": inactive_dev,
        "size_bytes": img_size,
        "timestamp": time.time(),
    }
    return result


def _mark_target_installed(dev: str):
    """
    Mount the newly-written partition and create .installed + .activated flags
    so firstboot.sh and activation wizard are skipped after OTA reboot.
    """
    import tempfile
    mount_point = tempfile.mkdtemp(prefix="yunsh-update-")
    try:
        result = _run(["mount", dev, mount_point], check=False, capture=True)
        if result.returncode != 0:
            logger.warning("Could not mount %s to flag as installed: %s", dev, result.stderr.strip())
            return
        # Create necessary directories and flag files
        etc_dir = os.path.join(mount_point, "etc", "yunsh")
        os.makedirs(etc_dir, exist_ok=True)
        # Mark firstboot as complete (skip yunsh-firstboot.sh)
        installed_flag = os.path.join(etc_dir, ".installed")
        open(installed_flag, "w").close()
        # Mark activation as complete (skip activation wizard)
        activated_flag = os.path.join(etc_dir, ".activated")
        open(activated_flag, "w").close()
        sync()
        logger.info("✓ Marked %s as installed (flags: .installed + .activated)", dev)
    except Exception as exc:
        logger.warning("Failed to set installed flag on %s: %s", dev, exc)
    finally:
        _run(["umount", mount_point], check=False)
        try:
            os.rmdir(mount_point)
        except OSError:
            pass


def _write_image_python(image_path: str, dest: str):
    """Python-level image write (fallback when dd is unavailable)."""
    bs = 4 * 1024 * 1024  # 4 MiB
    with open(image_path, "rb") as src, open(dest, "wb") as dst:
        total = os.path.getsize(image_path)
        written = 0
        while chunk := src.read(bs):
            dst.write(chunk)
            written += len(chunk)
            pct = written / total * 100 if total else 0
            sys.stdout.write(f"\r  Writing: {pct:5.1f}% ({human_size(written)})")
            sys.stdout.flush()
        sys.stdout.write("\n")
        dst.flush()
        os.fsync(dst.fileno())


def _verify_partition(image_path: str, part_dev: str, size: int) -> str | None:
    """Compare SHA256 of the first *size* bytes of part_dev with the image."""
    try:
        with open(image_path, "rb") as f:
            img_hash = hashlib.sha256(f.read()).hexdigest()
        with open(part_dev, "rb") as f:
            part_hash = hashlib.sha256(f.read(size)).hexdigest()
        if img_hash == part_hash:
            return img_hash
        logger.warning("Hash mismatch: image=%s partition=%s", img_hash, part_hash)
        return None
    except Exception as exc:
        logger.warning("Verification failed: %s", exc)
        return None


# ---------------------------------------------------------------------------
# Bootloader config
# ---------------------------------------------------------------------------
def update_bootloader(inactive_slot_for_boot: bool) -> bool:
    """
    Configure the bootloader to boot from the newly updated partition.
    On RPi this means updating config.txt or the U-Boot environment.

    Returns True on success.
    """
    current_slot, _, inactive_slot, _ = detect_boot_partition()

    boot_part = "boot_a" if inactive_slot == "A" else "boot_b"
    logger.info("Updating bootloader: switching to slot %s", inactive_slot)

    # Strategy 1: config.txt on the boot partition
    boot_mount = "/boot"
    config_paths = [
        os.path.join(boot_mount, "config.txt"),
        os.path.join(boot_mount, "boot", "config.txt"),
        "/boot/config.txt",
    ]

    written = False
    for cfg_path in config_paths:
        if not os.path.exists(cfg_path):
            continue
        try:
            # Read existing config, update root partition
            with open(cfg_path) as f:
                content = f.read()

            # Find and update the root partition argument
            if "root=/dev/mmcblk0p2" in content or "root=/dev/mmcblk0p3" in content:
                inactive_dev = f"/dev/mmcblk0p{3 if inactive_slot == 'B' else 2}"
                content_new = re.sub(
                    r'root=/dev/mmcblk0p[23]',
                    f'root={inactive_dev}',
                    content
                )
                with open(cfg_path, "w") as f:
                    f.write(content_new)
                logger.info("Updated %s: root → %s", cfg_path, inactive_dev)
                written = True
            else:
                # Could also have a slot= marker
                content_new = re.sub(
                    r'slot=[AB]',
                    f'slot={inactive_slot}',
                    content
                )
                if content_new != content:
                    with open(cfg_path, "w") as f:
                        f.write(content_new)
                    logger.info("Updated %s: slot → %s", cfg_path, inactive_slot)
                    written = True
        except OSError as exc:
            logger.warning("Could not write %s: %s", cfg_path, exc)

    if not written:
        logger.warning("No boot config file found; boot partition may not switch automatically")

    # Strategy 2: fw_setenv (U-Boot)
    try:
        _run(["fw_setenv", "boot_slot", inactive_slot.lower()], check=False)
        logger.info("fw_setenv boot_slot=%s", inactive_slot.lower())
    except FileNotFoundError:
        logger.debug("fw_setenv not available (non-U-Boot system)")

    return True


# ---------------------------------------------------------------------------
# Auto update
# ---------------------------------------------------------------------------
def auto_update():
    """Read config and release info, then download and apply if available."""
    config = load_config()
    info = _read_json(INFO_PATH)
    release_info = _read_json(INFO_PATH)

    latest_version = release_info.get("latest_version", "")
    download_url = release_info.get("download_url", "")
    expected_sha256 = release_info.get("sha256", "")

    if not latest_version or not download_url:
        logger.info("No update available (missing version or download URL)")
        _write_json(RESULT_PATH, {
            "success": False,
            "error": "no update available",
            "timestamp": time.time(),
        })
        return

    current_slot, current_dev, inactive_slot, inactive_dev = detect_boot_partition()
    logger.info("Current: slot %s (%s) | Inactive: slot %s (%s)",
                current_slot, current_dev, inactive_slot, inactive_dev)

    # Download
    try:
        download_image(download_url, DOWNLOAD_PATH, expected_sha256)
    except (ValueError, urllib.error.URLError, OSError) as exc:
        logger.error("Download failed: %s", exc)
        _write_json(RESULT_PATH, {
            "success": False,
            "error": str(exc),
            "stage": "download",
            "timestamp": time.time(),
        })
        return

    # Apply
    result = apply_update(DOWNLOAD_PATH, inactive_dev)
    result["version"] = latest_version
    result["from_slot"] = current_slot
    result["to_slot"] = inactive_slot
    result["timestamp"] = time.time()

    _write_json(RESULT_PATH, result)

    # Cleanup
    try:
        os.remove(DOWNLOAD_PATH)
        logger.info("Cleaned up temporary image")
    except OSError:
        pass

    if result["success"]:
        logger.info("✓ Update to v%s complete! Reboot to apply.", latest_version)
    else:
        logger.error("✗ Update failed: %s", result.get("error", "unknown"))


# ---------------------------------------------------------------------------
# Main CLI
# ---------------------------------------------------------------------------
def main():
    parser = argparse.ArgumentParser(
        description="YUNSH OS A/B Partition Updater",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s download https://example.com/os.img --sha256 abc123...
  %(prog)s apply --image /tmp/yunsh-update.img
  %(prog)s auto
""",
    )
    sub = parser.add_subparsers(dest="command", required=True)

    # download
    dl = sub.add_parser("download", help="Download an OS image")
    dl.add_argument("url", help="Download URL")
    dl.add_argument("--sha256", default="", help="Expected SHA256 checksum")
    dl.add_argument("--dest", default=DOWNLOAD_PATH, help="Destination path")

    # apply
    ap = sub.add_parser("apply", help="Write an image to the inactive partition")
    ap.add_argument("--image", default=DOWNLOAD_PATH, help="Path to the image file")

    # auto
    sub.add_parser("auto", help="Auto-update: read config, download & apply if available")

    # detect
    dt = sub.add_parser("detect", help="Detect current boot partition and exit")

    args = parser.parse_args()

    if args.command == "download":
        download_image(args.url, args.dest, args.sha256)
        logger.info("Image saved to %s", args.dest)

    elif args.command == "apply":
        current_slot, _, inactive_slot, inactive_dev = detect_boot_partition()
        logger.info("Current: slot %s | Target: slot %s (%s)",
                    current_slot, inactive_slot, inactive_dev)
        result = apply_update(args.image, inactive_dev)
        _write_json(RESULT_PATH, result)
        if result["success"]:
            logger.info("✓ Update written. Reboot to boot from slot %s.", inactive_slot)
        else:
            logger.error("✗ Update failed: %s", result.get("error", "unknown"))
            sys.exit(1)

    elif args.command == "auto":
        auto_update()

    elif args.command == "detect":
        current_slot, current_dev, inactive_slot, inactive_dev = detect_boot_partition()
        print(f"Current boot slot: {current_slot}  ({current_dev})")
        print(f"Inactive slot:     {inactive_slot}  ({inactive_dev})")
        print(f"Block device:      {detect_block_device()}")


if __name__ == "__main__":
    main()
