#!/usr/bin/env python3
"""YUNSH Link BLE companion service for the Raspberry Pi.

The Pi advertises as ``YUNSH V1`` with a small encrypted GATT service.  It
bridges update status and explicit update checks to the existing local update
daemon.  The update image itself is never transferred over Bluetooth: YUNSH OS
downloads it over its own Wi-Fi connection.

Protocol (all UUIDs are intentionally separate from the glasses controller):
  F000BB00-0451-4000-B000-000000000000  YUNSH OS service
  F000BB01-0451-4000-B000-000000000000  encrypted JSON command (write)
  F000BB02-0451-4000-B000-000000000000  encrypted JSON status  (read/notify)
"""

import json
import hmac
import os
import socket
import sys
import time

import dbus
import dbus.exceptions
import dbus.mainloop.glib
import dbus.service
from gi.repository import GLib

BLUEZ = "org.bluez"
OM_IFACE = "org.freedesktop.DBus.ObjectManager"
PROPS_IFACE = "org.freedesktop.DBus.Properties"
GATT_MANAGER_IFACE = "org.bluez.GattManager1"
AD_MANAGER_IFACE = "org.bluez.LEAdvertisingManager1"
SERVICE_IFACE = "org.bluez.GattService1"
CHAR_IFACE = "org.bluez.GattCharacteristic1"
AD_IFACE = "org.bluez.LEAdvertisement1"
AGENT_IFACE = "org.bluez.Agent1"
AGENT_MANAGER_IFACE = "org.bluez.AgentManager1"
UPDATE_SOCKET = "/tmp/yunsh-update.sock"
GLASSES_STATUS_PATH = "/tmp/yunsh-glasses-status.json"
POWER_STATUS_PATH = "/tmp/yunsh-power-status.json"
GLASSES_CONTROL_PATH = "/tmp/yunsh-glasses-control.json"
LINK_STATUS_PATH = "/tmp/yunsh-link-status.json"
UI_COMMAND_PATH = "/tmp/yunsh-ui-command.json"
LINK_PAIRING_PATH = "/run/yunsh/link-pairing.json"
LINK_TRUST_PATH = "/etc/yunsh/link-trust.json"
APP_PATH = "/top/yunsh/link"
AGENT_PATH = f"{APP_PATH}/agent"
SERVICE_UUID = "F000BB00-0451-4000-B000-000000000000"
COMMAND_UUID = "F000BB01-0451-4000-B000-000000000000"
STATUS_UUID = "F000BB02-0451-4000-B000-000000000000"
LAST_AUTHORIZED = False


def atomic_write_json(path: str, payload: dict) -> None:
    temporary = path + ".tmp"
    with open(temporary, "w", encoding="utf-8") as handle:
        json.dump(payload, handle, separators=(",", ":"))
        handle.flush()
        os.fsync(handle.fileno())
    os.replace(temporary, path)


def option_device(options=None) -> str:
    return str((options or {}).get("device", ""))


def trusted_device(device: str) -> bool:
    if not device:
        return False
    record = read_json(LINK_TRUST_PATH)
    return hmac.compare_digest(str(record.get("device", "")), device)


def verify_pairing_code(code, device: str) -> bool:
    if not device:
        return False
    record = read_json(LINK_PAIRING_PATH)
    try:
        valid = (
            not record.get("used")
            and float(record.get("expiresAt", 0)) > time.time()
            and hmac.compare_digest(
                str(record.get("code", "")).upper(),
                str(code).strip().upper(),
            )
        )
    except (TypeError, ValueError):
        valid = False
    if not valid:
        return False
    record["used"] = True
    atomic_write_json(LINK_PAIRING_PATH, record)
    os.makedirs(os.path.dirname(LINK_TRUST_PATH), exist_ok=True)
    atomic_write_json(
        LINK_TRUST_PATH,
        {"device": device, "pairedAt": time.time(), "method": "six-digit-key"},
    )
    os.chmod(LINK_TRUST_PATH, 0o600)
    return True


def note_link_activity(options=None, authorized=False) -> None:
    device = ""
    if options:
        device = str(options.get("device", ""))
    atomic_write_json(
        LINK_STATUS_PATH,
        {
            "connected": True,
            "device": device,
            "mode": "yunsh-os",
            "authenticated": bool(authorized),
            "lastActivity": time.time(),
        },
    )


def request_recenter() -> dict:
    command_id = f"{time.time_ns():x}"
    atomic_write_json(
        UI_COMMAND_PATH,
        {"id": command_id, "action": "recenter", "createdAt": time.time()},
    )
    return {"result": "recenter_requested"}


def update_command(action: str) -> dict:
    """Call the privileged local update daemon, never shelling user input."""
    try:
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as sock:
            sock.settimeout(15)
            sock.connect(UPDATE_SOCKET)
            sock.sendall((json.dumps({"action": action}) + "\n").encode())
            data = b""
            while not data.endswith(b"\n"):
                chunk = sock.recv(4096)
                if not chunk:
                    break
                data += chunk
        return json.loads(data.decode() or "{}")
    except Exception as exc:
        return {"error": str(exc)}


def read_json(path: str) -> dict:
    try:
        with open(path, encoding="utf-8") as handle:
            return json.load(handle)
    except (OSError, ValueError):
        return {}


def write_glasses_brightness(value) -> dict:
    level = max(0, min(100, int(value)))
    tmp = GLASSES_CONTROL_PATH + ".tmp"
    with open(tmp, "w", encoding="utf-8") as handle:
        json.dump({"brightness": level}, handle)
    os.replace(tmp, GLASSES_CONTROL_PATH)
    return {"result": "brightness_requested", "brightness": level}


def compact_status(result: dict) -> dict:
    """Use compact wire keys so notifications fit a normal iPhone ATT MTU."""
    glasses = read_json(GLASSES_STATUS_PATH)
    power = read_json(POWER_STATUS_PATH)
    detail = result.get("error") or result.get("result") or "Ready"
    return {
        "cv": result.get("current_version", "—"),
        "lv": result.get("latest_version", "—"),
        "ua": bool(result.get("update_available", False)),
        "s": result.get("state", "error" if result.get("error") else "ready"),
        "d": str(detail)[:24],
        "gc": bool(glasses.get("connected", False)),
        "gb": glasses.get("battery"),
        "gv": glasses.get("battery_mv"),
        "gl": glasses.get("brightness"),
        "hb": power.get("battery") if power.get("available") else None,
        "pa": bool(result.get("authorized", LAST_AUTHORIZED)),
    }


class PairingAgent(dbus.service.Object):
    """BlueZ Just Works agent for encrypted iPhone characteristics."""

    def __init__(self, bus):
        super().__init__(bus, AGENT_PATH)

    @dbus.service.method(AGENT_IFACE)
    def Release(self):
        pass

    @dbus.service.method(AGENT_IFACE, in_signature="o")
    def RequestAuthorization(self, _device):
        return

    @dbus.service.method(AGENT_IFACE, in_signature="os")
    def AuthorizeService(self, _device, _uuid):
        return

    @dbus.service.method(AGENT_IFACE)
    def Cancel(self):
        pass


class Application(dbus.service.Object):
    def __init__(self, bus):
        self.path = APP_PATH
        self.services = []
        super().__init__(bus, self.path)

    def add_service(self, service):
        self.services.append(service)

    def get_path(self):
        return dbus.ObjectPath(self.path)

    @dbus.service.method(OM_IFACE, out_signature="a{oa{sa{sv}}}")
    def GetManagedObjects(self):
        response = {}
        for service in self.services:
            response[service.get_path()] = service.get_properties()
            for characteristic in service.characteristics:
                response[characteristic.get_path()] = characteristic.get_properties()
        return response


class Service(dbus.service.Object):
    def __init__(self, bus, index, uuid):
        self.path = f"{APP_PATH}/service{index}"
        self.uuid = uuid
        self.primary = True
        self.characteristics = []
        super().__init__(bus, self.path)

    def get_path(self):
        return dbus.ObjectPath(self.path)

    def add_characteristic(self, characteristic):
        self.characteristics.append(characteristic)

    def get_properties(self):
        return {SERVICE_IFACE: {"UUID": self.uuid, "Primary": self.primary, "Characteristics": dbus.Array([c.get_path() for c in self.characteristics], signature="o")}}


class Characteristic(dbus.service.Object):
    def __init__(self, bus, index, uuid, service, flags):
        self.path = f"{service.path}/char{index}"
        self.uuid = uuid
        self.service = service
        self.flags = flags
        super().__init__(bus, self.path)

    def get_path(self):
        return dbus.ObjectPath(self.path)

    def get_properties(self):
        return {CHAR_IFACE: {"Service": self.service.get_path(), "UUID": self.uuid, "Flags": dbus.Array(self.flags, signature="s")}}

    @dbus.service.method(PROPS_IFACE, in_signature="s", out_signature="a{sv}")
    def GetAll(self, interface):
        if interface != CHAR_IFACE:
            raise dbus.exceptions.DBusException("org.freedesktop.DBus.Error.InvalidArgs", "Invalid interface")
        return self.get_properties()[CHAR_IFACE]


class StatusCharacteristic(Characteristic):
    def __init__(self, bus, index, service):
        super().__init__(bus, index, STATUS_UUID, service, ["encrypt-read", "notify"])
        self.notifying = False
        self.value = self._encode(update_command("get_status"))

    def _encode(self, result):
        return dbus.Array(json.dumps(compact_status(result), separators=(",", ":")).encode(), signature="y")

    def refresh(self, result=None):
        self.value = self._encode(result if result is not None else update_command("get_status"))
        if self.notifying:
            self.PropertiesChanged(CHAR_IFACE, {"Value": self.value}, [])

    @dbus.service.method(CHAR_IFACE, in_signature="a{sv}", out_signature="ay")
    def ReadValue(self, options):
        global LAST_AUTHORIZED
        LAST_AUTHORIZED = trusted_device(option_device(options))
        note_link_activity(options, LAST_AUTHORIZED)
        self.refresh({"authorized": LAST_AUTHORIZED, **update_command("get_status")})
        return self.value

    @dbus.service.method(CHAR_IFACE)
    def StartNotify(self):
        self.notifying = True
        self.refresh()

    @dbus.service.method(CHAR_IFACE)
    def StopNotify(self):
        self.notifying = False

    @dbus.service.signal(PROPS_IFACE, signature="sa{sv}as")
    def PropertiesChanged(self, interface, changed, invalidated):
        pass


class CommandCharacteristic(Characteristic):
    def __init__(self, bus, index, service, status):
        super().__init__(bus, index, COMMAND_UUID, service, ["encrypt-write"])
        self.status = status

    @dbus.service.method(CHAR_IFACE, in_signature="aya{sv}")
    def WriteValue(self, value, options):
        global LAST_AUTHORIZED
        try:
            payload = json.loads(bytes(value).decode())
            action = payload.get("action")
            device = option_device(options)
            authorized = trusted_device(device)
            if action == "pair_phone":
                authorized = verify_pairing_code(payload.get("code"), device)
                LAST_AUTHORIZED = authorized
                note_link_activity(options, authorized)
                self.status.refresh(
                    {
                        "authorized": authorized,
                        "result": "phone_paired" if authorized else "invalid_pairing_key",
                    }
                )
                return
            LAST_AUTHORIZED = authorized
            note_link_activity(options, authorized)
            if not authorized and action != "get_status":
                raise ValueError("phone pairing key required")
            if action == "recenter":
                self.status.refresh(request_recenter())
                return
            if action == "set_glasses_brightness":
                self.status.refresh(write_glasses_brightness(payload.get("value")))
                return
            if action == "install":
                self.status.refresh(update_command("start_download"))
                return
            if action not in {"get_status", "check"}:
                raise ValueError("unsupported command")
            self.status.refresh(update_command(action))
        except Exception as exc:
            self.status.refresh({"error": str(exc)})


class Advertisement(dbus.service.Object):
    def __init__(self, bus):
        self.path = f"{APP_PATH}/advertisement0"
        super().__init__(bus, self.path)

    def get_path(self):
        return dbus.ObjectPath(self.path)

    def get_properties(self):
        return {AD_IFACE: {"Type": "peripheral", "ServiceUUIDs": dbus.Array([SERVICE_UUID], signature="s"), "LocalName": "YUNSH V1"}}

    @dbus.service.method(PROPS_IFACE, in_signature="s", out_signature="a{sv}")
    def GetAll(self, interface):
        if interface != AD_IFACE:
            raise dbus.exceptions.DBusException("org.freedesktop.DBus.Error.InvalidArgs", "Invalid interface")
        return self.get_properties()[AD_IFACE]

    @dbus.service.method(AD_IFACE)
    def Release(self):
        pass


def find_adapter(bus):
    objects = dbus.Interface(bus.get_object(BLUEZ, "/"), OM_IFACE).GetManagedObjects()
    for path, interfaces in objects.items():
        if GATT_MANAGER_IFACE in interfaces and AD_MANAGER_IFACE in interfaces:
            return path
    raise RuntimeError("No BLE GATT-capable BlueZ adapter found")


def main():
    dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
    bus = dbus.SystemBus()
    adapter = find_adapter(bus)
    PairingAgent(bus)
    agent_manager = dbus.Interface(bus.get_object(BLUEZ, "/org/bluez"), AGENT_MANAGER_IFACE)
    try:
        agent_manager.RegisterAgent(AGENT_PATH, "NoInputNoOutput")
    except dbus.DBusException:
        pass
    try:
        agent_manager.RequestDefaultAgent(AGENT_PATH)
    except dbus.DBusException:
        pass
    app = Application(bus)
    service = Service(bus, 0, SERVICE_UUID)
    status = StatusCharacteristic(bus, 1, service)
    service.add_characteristic(CommandCharacteristic(bus, 0, service, status))
    # Keep each D-Bus object path unique: command is char0 and status is char1.
    service.add_characteristic(status)
    app.add_service(service)
    advertisement = Advertisement(bus)

    gatt = dbus.Interface(bus.get_object(BLUEZ, adapter), GATT_MANAGER_IFACE)
    advertising = dbus.Interface(bus.get_object(BLUEZ, adapter), AD_MANAGER_IFACE)
    gatt.RegisterApplication(app.get_path(), {}, reply_handler=lambda: None, error_handler=lambda err: sys.exit(f"GATT registration failed: {err}"))
    advertising.RegisterAdvertisement(advertisement.get_path(), {}, reply_handler=lambda: None, error_handler=lambda err: sys.exit(f"Advertisement failed: {err}"))

    def refresh_status():
        # Keep subscribed phones updated when battery/brightness changes even
        # if the phone is not actively issuing commands.
        status.refresh()
        return True

    GLib.timeout_add_seconds(2, refresh_status)
    GLib.MainLoop().run()


if __name__ == "__main__":
    main()
