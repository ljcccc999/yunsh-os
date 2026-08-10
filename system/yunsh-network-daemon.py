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
import re

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


def configure_wifi_country():
    """Set the persisted regulatory domain and clear Raspberry Pi soft block."""
    country = os.environ.get("YUNSH_WIFI_COUNTRY", "")
    try:
        if not country:
            with open("/etc/yunsh/wifi-country.conf", encoding="utf-8") as handle:
                for line in handle:
                    if line.startswith("COUNTRY="):
                        country = line.split("=", 1)[1].strip()
                        break
    except OSError:
        pass
    country = country.upper() or "CN"
    if not re.fullmatch(r"[A-Z]{2}", country):
        country = "CN"
    try:
        os.makedirs("/etc/yunsh", exist_ok=True)
        with open("/etc/yunsh/wifi-country.conf.tmp", "w", encoding="utf-8") as handle:
            handle.write(f"COUNTRY={country}\n")
        os.replace(
            "/etc/yunsh/wifi-country.conf.tmp", "/etc/yunsh/wifi-country.conf"
        )
    except OSError as exc:
        log.warning("Could not persist Wi-Fi country: %s", exc)
    for command in (
        ["raspi-config", "nonint", "do_wifi_country", country],
        ["iw", "reg", "set", country],
        ["rfkill", "unblock", "wifi"],
    ):
        try:
            subprocess.run(command, capture_output=True, timeout=15, check=False)
        except (OSError, subprocess.TimeoutExpired):
            pass
    return country


def run_nmcli(args, timeout=15):
    """Run nmcli command and return (success, output)"""
    try:
        environment = dict(os.environ)
        environment["LC_ALL"] = "C"
        result = subprocess.run(
            ["nmcli"] + args, capture_output=True, text=True,
            timeout=timeout, env=environment,
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


def split_nmcli(line):
    """Split nmcli terse output while preserving escaped ':' and '\\'."""
    fields = []
    current = []
    escaped = False
    for char in line:
        if escaped:
            current.append(char)
            escaped = False
        elif char == "\\":
            escaped = True
        elif char == ":":
            fields.append("".join(current))
            current = []
        else:
            current.append(char)
    fields.append("".join(current))
    return fields


def scan_wifi():
    """Scan Wi-Fi networks"""
    run_nmcli(["radio", "wifi", "on"], timeout=10)
    success, text = run_nmcli([
        "-t", "-e", "yes", "-f", "SSID,SIGNAL,SECURITY,BARS,CHAN",
        "device", "wifi", "list", "--rescan", "yes",
    ], timeout=25)
    if success:
        networks = []
        seen = set()
        for line in text.strip().splitlines():
            parts = split_nmcli(line)
            if len(parts) >= 5 and parts[0] and parts[0] not in seen:
                seen.add(parts[0])
                networks.append({
                    "ssid": parts[0],
                    "signal": int(parts[1]) if parts[1].isdigit() else 0,
                    "security": parts[2],
                    "bars": parts[3],
                    "chan": int(parts[4]) if parts[4].isdigit() else 0,
                })
        networks.sort(key=lambda n: n["signal"], reverse=True)
        return {"success": True, "networks": networks}
    return {"success": False, "error": text}


def get_status():
    """Get current Wi-Fi connection status"""
    wifi_connected = False
    wifi_enabled = False
    ssid = ""
    ip = ""
    ethernet_connected = False
    ethernet_interface = ""
    ethernet_ip = ""
    
    radio_ok, radio_state = run_nmcli(["radio", "wifi"])
    if radio_ok:
        wifi_enabled = radio_state.strip().lower() == "enabled"

    # Check specific wifi status
    s2, d2 = run_nmcli(["-t", "-e", "yes", "-f", "ACTIVE,SSID,SIGNAL,SECURITY", "device", "wifi"])
    if s2:
        for line in d2.strip().split("\n"):
            parts = split_nmcli(line)
            if len(parts) >= 4 and parts[0] == "yes":
                wifi_connected = True
                ssid = parts[1]
    
    # Resolve the active Wi-Fi interface first, then query its first IPv4
    # address. Device names are not assumed to be wlan0.
    interface = ""
    s3, d3 = run_nmcli([
        "-t", "-e", "yes", "-f", "DEVICE,TYPE,STATE", "device", "status"
    ])
    if s3:
        for line in d3.strip().splitlines():
            parts = split_nmcli(line)
            if (
                len(parts) >= 3
                and parts[1] == "wifi"
                and parts[2] in {"connected", "connected (externally)"}
            ):
                interface = parts[0]
            elif (
                len(parts) >= 3
                and parts[1] in {"ethernet", "802-3-ethernet"}
                and parts[2] in {"connected", "connected (externally)"}
            ):
                ethernet_connected = True
                ethernet_interface = parts[0]
    if interface:
        s4, d4 = run_nmcli(["-g", "IP4.ADDRESS", "device", "show", interface])
        if s4 and d4.strip():
            ip = d4.strip().splitlines()[0].split("/", 1)[0]
    if ethernet_interface:
        s5, d5 = run_nmcli([
            "-g", "IP4.ADDRESS", "device", "show", ethernet_interface
        ])
        if s5 and d5.strip():
            ethernet_ip = d5.strip().splitlines()[0].split("/", 1)[0]
    
    return {
        "connected": wifi_connected,
        "online": wifi_connected or ethernet_connected,
        "enabled": wifi_enabled,
        "ssid": ssid,
        "ip_address": ip,
        "interface": interface,
        "connection_type": "ethernet" if ethernet_connected else (
            "wifi" if wifi_connected else "none"
        ),
        "ethernet_connected": ethernet_connected,
        "ethernet_interface": ethernet_interface,
        "ethernet_ip_address": ethernet_ip,
    }


def set_powered(on=True):
    """Enable or disable the Wi-Fi radio through NetworkManager."""
    success, output = run_nmcli(["radio", "wifi", "on" if on else "off"])
    status = get_status()
    actual = bool(status.get("enabled"))
    return {
        "success": success and actual == on,
        "enabled": actual,
        "message": "Wi-Fi enabled" if actual else (
            "Wi-Fi disabled" if success else output.strip()
        ),
    }


def connect_wifi(ssid, password=None):
    """Connect to a Wi-Fi network"""
    if (
        not isinstance(ssid, str)
        or not ssid
        or len(ssid.encode("utf-8")) > 32
        or any(character in ssid for character in "\r\n\x00")
    ):
        return {"success": False, "message": "SSID is required"}
    if password is not None and not isinstance(password, str):
        return {"success": False, "message": "Password must be text"}

    run_nmcli(["radio", "wifi", "on"], timeout=10)
    # Refresh scan results before connecting. NetworkManager otherwise may
    # report a correct nearby SSID as unavailable when its cache is stale.
    run_nmcli(["device", "wifi", "rescan"], timeout=20)

    interface = ""
    ok, devices = run_nmcli([
        "-t", "-e", "yes", "-f", "DEVICE,TYPE,STATE", "device", "status"
    ])
    if ok:
        for line in devices.splitlines():
            fields = split_nmcli(line)
            if len(fields) >= 2 and fields[1] == "wifi":
                interface = fields[0]
                break
    if not interface:
        return {"success": False, "message": "No Wi-Fi adapter was detected"}

    command = ["device", "wifi", "connect", ssid, "ifname", interface]
    if password:
        command += ["password", password]
    success, output = run_nmcli(command, timeout=45)
    if not success:
        # A profile created by an earlier failed password attempt can retain
        # stale credentials. Remove only the profile whose connection id is
        # exactly the selected SSID, then make one clean retry.
        profile_ok, profiles = run_nmcli([
            "-t", "-e", "yes", "-f", "NAME,TYPE", "connection", "show"
        ])
        if profile_ok:
            for line in profiles.splitlines():
                fields = split_nmcli(line)
                if len(fields) >= 2 and fields[0] == ssid and fields[1] in {
                    "wifi", "802-11-wireless"
                }:
                    run_nmcli(["connection", "delete", "id", ssid], timeout=15)
                    success, output = run_nmcli(command, timeout=45)
                    break

    if success:
        # nmcli can return before DHCP has supplied an address. Verify the
        # selected SSID instead of showing a false success in activation.
        for _ in range(15):
            status = get_status()
            if status.get("connected") and status.get("ssid") == ssid:
                save_status()
                return {
                    "success": True,
                    "message": f"Connected to {ssid}",
                    "ssid": ssid,
                    "ip_address": status.get("ip_address", ""),
                }
            time.sleep(1)
        success = False
        output = "Connection activated but IP configuration did not complete"
    return {
        "success": success,
        "message": output.strip() if not success else f"Connected to {ssid}"
    }


def disconnect():
    """Disconnect current Wi-Fi"""
    status = get_status()
    if status["interface"]:
        success, output = run_nmcli(["device", "disconnect", status["interface"]])
        return {"success": success, "message": "Disconnected" if success else output.strip()}
    return {"success": True, "message": "Not connected"}


def save_status():
    """Write current status to status file"""
    try:
        status = get_status()
        temporary = STATUS_PATH + ".tmp"
        with open(temporary, "w") as f:
            json.dump(status, f)
            f.flush()
            os.fsync(f.fileno())
        os.replace(temporary, STATUS_PATH)
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
    elif cmd == "power":
        result = set_powered(bool(cmd_data.get("enabled", True)))
    elif cmd == "power_on":
        result = set_powered(True)
    elif cmd == "power_off":
        result = set_powered(False)
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
    os.chmod(SOCKET_PATH, 0o666)
    
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
    country = configure_wifi_country()
    log.info("Wi-Fi regulatory country: %s", country)
    run_nmcli(["radio", "wifi", "on"], timeout=10)
    
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
    
    # Systemd Type=simple: just run in foreground (systemd handles daemonization).
    # Double-fork only when explicitly requested via --fork, not via --daemon
    # to avoid confusing systemd's service manager.
    if "--fork" in sys.argv:
        # Manual double-fork (for non-systemd usage)
        pid = os.fork()
        if pid > 0:
            sys.exit(0)
        os.setsid()
        pid = os.fork()
        if pid > 0:
            sys.exit(0)
    
    main()
