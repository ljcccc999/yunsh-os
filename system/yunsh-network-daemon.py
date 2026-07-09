#!/usr/bin/env python3
"""
YUNSH OS v1.0 - Network/Wi-Fi Management Daemon
Provides Wi-Fi scanning, connection management via NetworkManager/nmcli
Listens on /tmp/yunsh-network.sock for commands
"""

import json
import logging
import os
import signal
import socket
import subprocess
import sys
import threading
import time

SOCKET_PATH = "/tmp/yunsh-network.sock"
STATUS_PATH = "/tmp/yunsh-network-status.json"
LOG_PATH = "/var/log/yunsh-network.log"

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[
        logging.FileHandler(LOG_PATH),
        logging.StreamHandler()
    ]
)
log = logging.getLogger("yunsh-network")


def run_nmcli(args, timeout=15):
    """Run nmcli command and return (success, output)"""
    try:
        result = subprocess.run(
            ["nmcli"] + args,
            capture_output=True, text=True, timeout=timeout
        )
        if result.returncode == 0:
            return True, result.stdout
        else:
            return False, result.stderr
    except subprocess.TimeoutExpired:
        return False, "Command timed out"
    except FileNotFoundError:
        return False, "nmcli not found - NetworkManager not installed"


def nmcli_json(args, timeout=15):
    """Run nmcli with JSON output"""
    success, output = run_nmcli(args + ["--output", "json"], timeout)
    if success:
        try:
            return True, json.loads(output)
        except json.JSONDecodeError:
            return False, {"error": "Failed to parse nmcli output", "raw": output}
    return False, {"error": output}


def scan_wifi():
    """Scan Wi-Fi networks"""
    success, result = nmcli_json(["-f", "SSID,SIGNAL,SECURITY,BARS,MODE,CHAN", "device", "wifi", "list"])
    if success:
        networks = []
        if isinstance(result, dict):
            for entry in result.get("wifi-networks", []):
                for ap in entry.get("access-points", [entry]):
                    ssid = ap.get("ssid", "")
                    if ssid:
                        networks.append({
                            "ssid": ssid,
                            "signal": ap.get("signal", 0),
                            "security": ap.get("security", ""),
                            "bars": ap.get("bars", ""),
                            "chan": ap.get("chan", 0)
                        })
        # Sort by signal strength
        networks.sort(key=lambda n: n["signal"], reverse=True)
        return {"success": True, "networks": networks}
    # Fallback: parse text output
    success, text = run_nmcli(["-f", "SSID,SIGNAL,SECURITY,BARS", "device", "wifi", "list"])
    if success:
        networks = []
        for line in text.strip().split("\n")[1:]:  # Skip header
            parts = line.split()
            if len(parts) >= 3:
                networks.append({
                    "ssid": parts[0],
                    "signal": int(parts[1]) if parts[1].isdigit() else 0,
                    "security": parts[2],
                    "bars": parts[3] if len(parts) > 3 else ""
                })
        networks.sort(key=lambda n: n["signal"], reverse=True)
        return {"success": True, "networks": networks}
    return {"success": False, "error": text}


def get_status():
    """Get current Wi-Fi connection status"""
    success, data = nmcli_json(["-t", "connection", "show", "--active"])
    wifi_connected = False
    ssid = ""
    ip = ""
    
    # Check specific wifi status
    s2, d2 = run_nmcli(["-t", "-f", "ACTIVE,SSID,SIGNAL,SECURITY", "device", "wifi"])
    if s2:
        for line in d2.strip().split("\n"):
            parts = line.split(":")
            if len(parts) >= 4 and parts[0] == "yes":
                wifi_connected = True
                ssid = parts[1]
    
    # Get IP
    s3, d3 = run_nmcli(["-t", "-f", "DEVICE,IP4", "device", "show"])
    if s3:
        for line in d3.strip().split("\n"):
            if ":" in line:
                dev, ipinfo = line.split(":", 1)
                if ipinfo and "wlan" in dev.lower():
                    ip = ipinfo.strip()
    
    return {
        "connected": wifi_connected,
        "ssid": ssid,
        "ip_address": ip,
        "interface": "wlan0"
    }


def connect_wifi(ssid, password=None):
    """Connect to a Wi-Fi network"""
    if password:
        success, output = run_nmcli([
            "device", "wifi", "connect", ssid,
            "password", password
        ])
    else:
        success, output = run_nmcli([
            "device", "wifi", "connect", ssid
        ])
    return {
        "success": success,
        "message": output.strip() if not success else f"Connected to {ssid}"
    }


def disconnect():
    """Disconnect current Wi-Fi"""
    status = get_status()
    if status["ssid"]:
        success, output = run_nmcli(["connection", "down", status["ssid"]])
        return {"success": success, "message": "Disconnected" if success else output.strip()}
    return {"success": True, "message": "Not connected"}


def save_status():
    """Write current status to status file"""
    try:
        status = get_status()
        with open(STATUS_PATH, "w") as f:
            json.dump(status, f)
        return status
    except Exception as e:
        log.error(f"Failed to save status: {e}")
        return {"error": str(e)}


def handle_command(cmd_data):
    """Process a command from the socket"""
    cmd = cmd_data.get("command", "")
    log.info(f"Command: {cmd}")
    
    if cmd == "scan":
        result = scan_wifi()
    elif cmd == "status":
        result = get_status()
    elif cmd == "connect":
        result = connect_wifi(
            cmd_data.get("ssid", ""),
            cmd_data.get("password")
        )
    elif cmd == "disconnect":
        result = disconnect()
    else:
        result = {"success": False, "error": f"Unknown command: {cmd}"}
    
    return result


def socket_server():
    """Unix socket server for commands"""
    try:
        os.unlink(SOCKET_PATH)
    except FileNotFoundError:
        pass
    
    server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    server.bind(SOCKET_PATH)
    server.listen(5)
    os.chmod(SOCKET_PATH, 0o777)
    
    log.info(f"Listening on {SOCKET_PATH}")
    
    while True:
        try:
            conn, addr = server.accept()
            data = conn.recv(4096)
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


def main():
    log.info("YUNSH Network Daemon starting...")
    
    # Initial status save
    save_status()
    
    # Start socket server in thread
    server_thread = threading.Thread(target=socket_server, daemon=True)
    server_thread.start()
    
    # Periodic status update every 30 seconds
    while True:
        time.sleep(30)
        try:
            save_status()
        except Exception as e:
            log.error(f"Status update error: {e}")


def handle_signal(sig, frame):
    log.info("Shutting down...")
    try:
        os.unlink(SOCKET_PATH)
    except FileNotFoundError:
        pass
    sys.exit(0)


if __name__ == "__main__":
    signal.signal(signal.SIGTERM, handle_signal)
    signal.signal(signal.SIGINT, handle_signal)
    
    if "--daemon" in sys.argv:
        # Double fork
        pid = os.fork()
        if pid > 0:
            sys.exit(0)
        os.setsid()
        pid = os.fork()
        if pid > 0:
            sys.exit(0)
    
    main()
