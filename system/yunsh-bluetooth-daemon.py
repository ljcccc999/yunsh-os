#!/usr/bin/env python3
"""
YUNSH OS v1.0 - Bluetooth Management Daemon
Manages Bluetooth via bluetoothctl (BlueZ)
Listens on /tmp/yunsh-bluetooth.sock for commands
"""

import json
import logging
import os
import re
import signal
import socket
import subprocess
import sys
import threading
import time

SOCKET_PATH = "/tmp/yunsh-bluetooth.sock"
STATUS_PATH = "/tmp/yunsh-bluetooth-status.json"
LOG_PATH = "/var/log/yunsh-bluetooth.log"

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[
        logging.FileHandler(LOG_PATH),
        logging.StreamHandler()
    ]
)
log = logging.getLogger("yunsh-bluetooth")


# ──────────────────────────────────────────────
# bluetoothctl helpers
# ──────────────────────────────────────────────

def btctl(args, timeout=15):
    """Run bluetoothctl with arguments and return (success, stdout)"""
    try:
        result = subprocess.run(
            ["bluetoothctl"] + args,
            capture_output=True, text=True, timeout=timeout
        )
        if result.returncode == 0:
            return True, result.stdout
        else:
            return True, result.stdout  # bluetoothctl often exits 0 even with errors
    except subprocess.TimeoutExpired:
        return False, "Command timed out"
    except FileNotFoundError:
        return False, "bluetoothctl not found - BlueZ not installed"


def btctl_stdin(commands, timeout=20):
    """Send multiple commands via stdin to bluetoothctl (for interactive sequences)"""
    try:
        proc = subprocess.Popen(
            ["bluetoothctl"],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )
        stdout, stderr = proc.communicate(input="\n".join(commands) + "\n", timeout=timeout)
        return True, stdout
    except subprocess.TimeoutExpired:
        proc.kill()
        return False, "Interactive command timed out"
    except FileNotFoundError:
        return False, "bluetoothctl not found - BlueZ not installed"


# ──────────────────────────────────────────────
# Bluetooth operations
# ──────────────────────────────────────────────

def get_controller_info():
    """Get Bluetooth controller info (powered, discovering, etc.)"""
    success, output = btctl(["show"])
    info = {
        "powered": False,
        "discovering": False,
        "controller_mac": "",
        "controller_name": "",
        "addressable": False
    }
    if success:
        for line in output.splitlines():
            line = line.strip()
            if "Powered:" in line:
                info["powered"] = "yes" in line.lower()
            elif "Discovering:" in line:
                info["discovering"] = "yes" in line.lower()
            elif "Controller" in line and not info["controller_mac"]:
                parts = line.split()
                if len(parts) >= 2:
                    info["controller_mac"] = parts[1]
            elif "Name:" in line:
                info["controller_name"] = line.split(":", 1)[-1].strip()
            elif "Class:" in line:
                info["addressable"] = True
    return info


def list_paired_devices():
    """List all paired Bluetooth devices with details"""
    success, output = btctl(["paired-devices"])
    devices = []
    if success:
        for line in output.splitlines():
            line = line.strip()
            match = re.match(r"Device\s+([0-9A-Fa-f:]+)\s+(.*)", line)
            if match:
                mac = match.group(1).upper()
                name = match.group(2).strip()
                # Get detailed info for each device
                info = get_device_info(mac)
                device = {
                    "mac": mac,
                    "name": name,
                    "paired": True,
                    "connected": info.get("connected", False),
                    "trusted": info.get("trusted", False),
                    "battery": info.get("battery", None),
                    "icon": info.get("icon", "input-keyboard"),
                    "device_type": info.get("device_type", "unknown")
                }
                devices.append(device)
    return devices


def list_devices():
    """List all known devices (paired + remembered)"""
    success, output = btctl(["devices"])
    devices = []
    if success:
        for line in output.splitlines():
            line = line.strip()
            match = re.match(r"Device\s+([0-9A-Fa-f:]+)\s+(.*)", line)
            if match:
                mac = match.group(1).upper()
                name = match.group(2).strip()
                info = get_device_info(mac)
                device = {
                    "mac": mac,
                    "name": name,
                    "paired": info.get("paired", False),
                    "connected": info.get("connected", False),
                    "trusted": info.get("trusted", False),
                    "battery": info.get("battery", None),
                    "icon": info.get("icon", "input-keyboard"),
                    "device_type": info.get("device_type", "unknown")
                }
                devices.append(device)
    return devices


def get_device_info(mac):
    """Get detailed info about a specific device"""
    success, output = btctl(["info", mac])
    info = {
        "connected": False,
        "paired": False,
        "trusted": False,
        "battery": None,
        "icon": None,
        "device_type": "unknown",
        "name": "",
        "alias": ""
    }
    if success:
        for line in output.splitlines():
            line = line.strip()
            if "Connected:" in line:
                info["connected"] = "yes" in line.lower()
            elif "Paired:" in line:
                info["paired"] = "yes" in line.lower()
            elif "Trusted:" in line:
                info["trusted"] = "yes" in line.lower()
            elif "Battery Percentage:" in line:
                match = re.search(r"(\d+)", line)
                if match:
                    info["battery"] = int(match.group(1))
            elif "Icon:" in line:
                info["icon"] = line.split(":", 1)[-1].strip()
            elif "Name:" in line:
                info["name"] = line.split(":", 1)[-1].strip()
            elif "Alias:" in line:
                info["alias"] = line.split(":", 1)[-1].strip()
            elif "Class:" in line:
                # Map Bluetooth class to device type
                bt_class = line.split(":", 1)[-1].strip()
                info["device_type"] = classify_device_class(bt_class)
    return info


def classify_device_class(bt_class):
    """Map Bluetooth class hex value to human-readable type"""
    # See Bluetooth Assigned Numbers for full class mapping
    try:
        cls_int = int(bt_class.strip(), 16)
        major_class = (cls_int >> 8) & 0x1F
        minor_class = (cls_int >> 2) & 0x3F
        
        major_map = {
            0x00: "misc",
            0x01: "computer",
            0x02: "phone",
            0x03: "lan",
            0x04: "audio",
            0x05: "peripheral",
            0x06: "imaging",
            0x07: "wearable",
            0x08: "toy",
            0x09: "health",
            0x1F: "uncategorized"
        }
        return major_map.get(major_class, "uncategorized")
    except (ValueError, TypeError):
        pass
    return "unknown"


def scan_devices(timeout=12):
    """Scan for discoverable Bluetooth devices nearby"""
    # Start discovery
    success, _ = btctl(["scan", "off"])  # Clear existing
    success, output = btctl_stdin(["scan on", f"sleep {timeout}", "scan off"])
    
    # Parse discovered devices
    devices = []
    if success:
        for line in output.splitlines():
            line = line.strip()
            match = re.match(
                r"\[NEW\]\s+Device\s+([0-9A-Fa-f:]+)\s+(.*)", line
            )
            if not match:
                match = re.match(
                    r"Device\s+([0-9A-Fa-f:]+)\s+(.*)", line
                )
            if match:
                mac = match.group(1).upper()
                name = match.group(2).strip()
                # Skip already paired devices
                info = get_device_info(mac)
                devices.append({
                    "mac": mac,
                    "name": name if name != mac else "Unknown",
                    "paired": info.get("paired", False),
                    "connected": info.get("connected", False),
                    "rssi": info.get("rssi", None),
                    "device_type": info.get("device_type", "unknown"),
                    "battery": info.get("battery", None)
                })
    
    # Deduplicate by MAC
    seen = set()
    unique = []
    for d in devices:
        if d["mac"] not in seen:
            seen.add(d["mac"])
            unique.append(d)
    
    return unique


def pair_device(mac):
    """Pair with a device by MAC address"""
    success, output = btctl_stdin([
        "pair " + mac,
        "trust " + mac,
    ])
    paired = "Pairing successful" in output or "successful" in output.lower()
    trusted = "trust succeeded" in output.lower()
    return {
        "success": paired or trusted,
        "paired": paired,
        "trusted": trusted,
        "message": "Paired successfully" if (paired or trusted) else "Pairing failed or timeout"
    }


def connect_device(mac):
    """Connect to a paired device by MAC address"""
    success, output = btctl_stdin([
        "connect " + mac,
    ])
    connected = "Connection successful" in output or "connected" in output.lower()
    return {
        "success": connected,
        "connected": connected,
        "message": "Connected successfully" if connected else "Connection failed or timeout"
    }


def disconnect_device(mac):
    """Disconnect a device by MAC address"""
    success, output = btctl(["disconnect", mac])
    disconnected = "Successful disconnected" in output or "disconnected" in output.lower()
    return {
        "success": disconnected,
        "message": "Disconnected" if disconnected else "Disconnect command sent"
    }


def unpair_device(mac):
    """Remove/unpair a device by MAC address"""
    # First disconnect if connected
    disconnect_device(mac)
    success, output = btctl(["remove", mac])
    removed = "Device has been removed" in output or "removed" in output.lower()
    return {
        "success": removed,
        "message": "Device removed" if removed else "Remove command sent"
    }


def set_powered(on=True):
    """Turn Bluetooth controller on or off"""
    state = "on" if on else "off"
    success, output = btctl(["power", state])
    return {
        "success": True,
        "powered": on,
        "message": f"Bluetooth turned {state}"
    }


# ──────────────────────────────────────────────
# Status management
# ──────────────────────────────────────────────

def get_full_status():
    """Get complete Bluetooth status"""
    controller = get_controller_info()
    paired = list_paired_devices()
    return {
        "powered": controller["powered"],
        "discovering": controller["discovering"],
        "controller_mac": controller.get("controller_mac", ""),
        "controller_name": controller.get("controller_name", "YUNSH-OS"),
        "paired_devices": paired,
        "connected_count": sum(1 for d in paired if d["connected"]),
        "paired_count": len(paired)
    }


def save_status():
    """Write current status to status JSON file"""
    try:
        status = get_full_status()
        with open(STATUS_PATH, "w") as f:
            json.dump(status, f, indent=2)
        return status
    except Exception as e:
        log.error(f"Failed to save status: {e}")
        return {"error": str(e)}


# ──────────────────────────────────────────────
# Socket command handler
# ──────────────────────────────────────────────

def handle_command(cmd_data):
    """Process a command received over the Unix socket"""
    cmd = cmd_data.get("command", "").lower()
    log.info(f"Command: {cmd}")
    
    if cmd == "scan":
        timeout = cmd_data.get("timeout", 12)
        devices = scan_devices(timeout)
        return {"success": True, "devices": devices}
    
    elif cmd == "list":
        paired = list_paired_devices()
        all_devices = list_devices()
        return {
            "success": True,
            "paired": paired,
            "all": all_devices
        }
    
    elif cmd == "status":
        return get_full_status()
    
    elif cmd == "power":
        state = cmd_data.get("state", True)
        return set_powered(state)
    
    elif cmd == "power_on":
        return set_powered(True)
    
    elif cmd == "power_off":
        return set_powered(False)
    
    elif cmd == "pair":
        mac = cmd_data.get("mac", "")
        if not mac:
            return {"success": False, "error": "MAC address required"}
        return pair_device(mac)
    
    elif cmd == "connect":
        mac = cmd_data.get("mac", "")
        if not mac:
            return {"success": False, "error": "MAC address required"}
        return connect_device(mac)
    
    elif cmd == "disconnect":
        mac = cmd_data.get("mac", "")
        if not mac:
            return {"success": False, "error": "MAC address required"}
        return disconnect_device(mac)
    
    elif cmd == "unpair" or cmd == "remove":
        mac = cmd_data.get("mac", "")
        if not mac:
            return {"success": False, "error": "MAC address required"}
        return unpair_device(mac)
    
    else:
        return {"success": False, "error": f"Unknown command: {cmd}"}


# ──────────────────────────────────────────────
# Socket server
# ──────────────────────────────────────────────

def socket_server():
    """Unix socket server - listens for JSON commands"""
    try:
        os.unlink(SOCKET_PATH)
    except FileNotFoundError:
        pass
    
    server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    server.bind(SOCKET_PATH)
    server.listen(5)
    os.chmod(SOCKET_PATH, 0o666)
    
    log.info(f"Listening on {SOCKET_PATH}")
    
    while True:
        try:
            conn, addr = server.accept()
            data = conn.recv(65536)
            if data:
                try:
                    cmd_data = json.loads(data.decode().strip())
                    result = handle_command(cmd_data)
                    response = json.dumps(result) + "\n"
                except json.JSONDecodeError:
                    response = json.dumps({"success": False, "error": "Invalid JSON"}) + "\n"
                conn.send(response.encode())
            conn.close()
        except Exception as e:
            log.error(f"Socket error: {e}")
            time.sleep(0.1)


# ──────────────────────────────────────────────
# Main daemon loop
# ──────────────────────────────────────────────

def main():
    log.info("YUNSH Bluetooth Daemon starting...")
    
    # Initial status dump
    save_status()
    
    # Start socket server in daemon thread
    server_thread = threading.Thread(target=socket_server, daemon=True)
    server_thread.start()
    
    # Periodic status update every 15 seconds
    while True:
        time.sleep(15)
        try:
            save_status()
        except Exception as e:
            log.error(f"Status update error: {e}")


def handle_signal(sig, frame):
    """Clean shutdown on SIGTERM/SIGINT"""
    log.info("Shutting down...")
    try:
        # Write final status
        save_status()
    except Exception:
        pass
    try:
        os.unlink(SOCKET_PATH)
    except FileNotFoundError:
        pass
    sys.exit(0)


if __name__ == "__main__":
    signal.signal(signal.SIGTERM, handle_signal)
    signal.signal(signal.SIGINT, handle_signal)
    
    if "--daemon" in sys.argv:
        # Double-fork daemonization
        pid = os.fork()
        if pid > 0:
            sys.exit(0)
        os.setsid()
        pid = os.fork()
        if pid > 0:
            sys.exit(0)
        # Redirect stdin/stdout/stderr
        sys.stdin.close()
    
    main()
