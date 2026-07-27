#!/usr/bin/env python3
"""BLE central bridge: YUNSH OS <-> YUNSH V1 glasses controller.

The paired glasses address is stored in /etc/yunsh/glasses.conf by the normal
Bluetooth pairing flow.  The bridge reads standard Battery Service data and
the YUNSH brightness characteristic, then writes a compact status file for
the YUNSH Link peripheral service.  It deliberately does not expose raw BLE
objects to the phone.
"""

import json
import math
import os
import socket
import struct
import time

import dbus
import dbus.mainloop.glib
from gi.repository import GLib

BLUEZ = "org.bluez"
OM_IFACE = "org.freedesktop.DBus.ObjectManager"
PROPS_IFACE = "org.freedesktop.DBus.Properties"
DEVICE_IFACE = "org.bluez.Device1"
GATT_CHAR_IFACE = "org.bluez.GattCharacteristic1"
CONF_PATH = "/etc/yunsh/glasses.conf"
STATUS_PATH = "/tmp/yunsh-glasses-status.json"
CONTROL_PATH = "/tmp/yunsh-glasses-control.json"
BATTERY_UUID = "00002a19-0000-1000-8000-00805f9b34fb"
BRIGHTNESS_UUID = "f000aa02-0451-4000-b000-000000000000"
QUATERNION_UUID = "f000aa01-0451-4000-b000-000000000000"
HEADTRACKING_ADDR = ("127.0.0.1", 8595)


def read_address():
    try:
        for line in open(CONF_PATH, encoding="utf-8"):
            key, _, value = line.partition("=")
            if key.strip() == "address":
                return value.strip().upper()
    except OSError:
        pass
    return ""


class GlassesBridge:
    def __init__(self):
        self.bus = dbus.SystemBus()
        self.address = read_address()
        self.device_path = None
        self.battery_char = None
        self.brightness_char = None
        self.quaternion_char = None
        self.characteristics_ready = False
        self.last_control_mtime = 0
        self.state = {"connected": False, "battery": None, "brightness": None, "updated": 0}
        self.bus.add_signal_receiver(self.properties_changed, dbus_interface=PROPS_IFACE, signal_name="PropertiesChanged", path_keyword="path")

    def objects(self):
        return dbus.Interface(self.bus.get_object(BLUEZ, "/"), OM_IFACE).GetManagedObjects()

    def find_device(self, objects):
        for path, interfaces in objects.items():
            props = interfaces.get(DEVICE_IFACE, {})
            if str(props.get("Address", "")).upper() == self.address:
                return str(path), bool(props.get("Connected", False))
        return None, False

    def discover_characteristics(self, objects):
        self.battery_char = None
        self.brightness_char = None
        self.quaternion_char = None
        for path, interfaces in objects.items():
            if not self.device_path or not str(path).startswith(self.device_path + "/"):
                continue
            props = interfaces.get(GATT_CHAR_IFACE, {})
            uuid = str(props.get("UUID", "")).lower()
            if uuid == BATTERY_UUID:
                self.battery_char = str(path)
            elif uuid == BRIGHTNESS_UUID:
                self.brightness_char = str(path)
            elif uuid == QUATERNION_UUID:
                self.quaternion_char = str(path)
        for path in (self.battery_char, self.brightness_char, self.quaternion_char):
            if path:
                try:
                    dbus.Interface(self.bus.get_object(BLUEZ, path), GATT_CHAR_IFACE).StartNotify()
                    self.read_value(path)
                except dbus.DBusException:
                    pass

    def read_value(self, path):
        try:
            value = bytes(dbus.Interface(self.bus.get_object(BLUEZ, path), GATT_CHAR_IFACE).ReadValue({}))
            self.consume_value(path, value)
        except dbus.DBusException:
            pass

    def consume_value(self, path, value):
        if not value:
            return
        if path == self.battery_char:
            self.state["battery"] = int(value[0])
        elif path == self.brightness_char:
            self.state["brightness"] = int(value[0])
        elif path == self.quaternion_char and len(value) >= 16:
            w, x, y, z = struct.unpack("<ffff", value[:16])
            self.forward_quaternion(w, x, y, z)
            return
        self.write_status()

    def forward_quaternion(self, w, x, y, z):
        """BNO085 Game Rotation Vector -> YUNSH OS headtracking input."""
        yaw = math.degrees(math.atan2(2 * (w * z + x * y), 1 - 2 * (y * y + z * z)))
        pitch = math.degrees(math.asin(max(-1.0, min(1.0, 2 * (w * y - z * x)))))
        roll = math.degrees(math.atan2(2 * (w * x + y * z), 1 - 2 * (x * x + y * y)))
        try:
            with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as udp:
                udp.sendto(json.dumps({"yaw": yaw, "pitch": pitch, "roll": roll}).encode(), HEADTRACKING_ADDR)
        except OSError:
            pass

    def properties_changed(self, interface, changed, _invalidated, path=None):
        if interface != GATT_CHAR_IFACE or path not in (self.battery_char, self.brightness_char, self.quaternion_char):
            return
        if "Value" in changed:
            self.consume_value(path, bytes(changed["Value"]))

    def write_status(self):
        self.state["updated"] = int(time.time())
        tmp = STATUS_PATH + ".tmp"
        with open(tmp, "w", encoding="utf-8") as handle:
            json.dump(self.state, handle)
        os.replace(tmp, STATUS_PATH)

    def apply_control(self):
        try:
            mtime = os.stat(CONTROL_PATH).st_mtime_ns
            if mtime == self.last_control_mtime:
                return
            self.last_control_mtime = mtime
            command = json.load(open(CONTROL_PATH, encoding="utf-8"))
            value = max(0, min(100, int(command.get("brightness"))))
            if self.brightness_char:
                dbus.Interface(self.bus.get_object(BLUEZ, self.brightness_char), GATT_CHAR_IFACE).WriteValue(dbus.Array([dbus.Byte(value)], signature="y"), {})
        except (OSError, ValueError, TypeError, dbus.DBusException):
            pass

    def tick(self):
        self.address = read_address()
        if not self.address:
            self.state.update({"connected": False, "battery": None, "brightness": None})
            self.write_status()
            return True
        objects = self.objects()
        self.device_path, connected = self.find_device(objects)
        if self.device_path and not connected:
            try:
                dbus.Interface(self.bus.get_object(BLUEZ, self.device_path), DEVICE_IFACE).Connect()
            except dbus.DBusException:
                pass
        self.state["connected"] = connected
        if connected:
            if not self.characteristics_ready:
                self.discover_characteristics(objects)
                self.characteristics_ready = bool(self.battery_char or self.brightness_char or self.quaternion_char)
            self.apply_control()
        else:
            self.characteristics_ready = False
        self.write_status()
        return True


def main():
    dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
    bridge = GlassesBridge()
    GLib.timeout_add_seconds(2, bridge.tick)
    bridge.tick()
    GLib.MainLoop().run()


if __name__ == "__main__":
    main()
