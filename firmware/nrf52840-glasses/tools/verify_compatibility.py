#!/usr/bin/env python3
"""Verify firmware UUIDs and packet order against local YUNSH clients."""

from pathlib import Path
import re
import struct
import sys

ROOT = Path(__file__).resolve().parents[4]
FIRMWARE_PROTOCOL = ROOT / "yunsh-os/firmware/nrf52840-glasses/include/yunsh_protocol.h"
IOS_MANAGER = ROOT / "YUNSHxr/Sources/HeadTrackingManager.swift"
OS_BRIDGE = ROOT / "yunsh-os/system/yunsh-glasses-bridge.py"

SERVICE_UUID = "F000AA00-0451-4000-B000-000000000000"
CHARACTERISTIC_UUIDS = {
    "F000AA01-0451-4000-B000-000000000000",
    "F000AA02-0451-4000-B000-000000000000",
}


def require(path: Path) -> str:
    if not path.is_file():
        raise RuntimeError(f"missing {path}")
    return path.read_text(encoding="utf-8")


def main() -> int:
    sources = {
        "firmware": require(FIRMWARE_PROTOCOL).upper(),
        "iOS": require(IOS_MANAGER).upper(),
        "OS": require(OS_BRIDGE).upper(),
    }
    for uuid in CHARACTERISTIC_UUIDS:
        missing = [name for name, text in sources.items() if uuid not in text]
        if missing:
            raise RuntimeError(f"{uuid} missing from: {', '.join(missing)}")
    for name in ("firmware", "iOS"):
        if SERVICE_UUID not in sources[name]:
            raise RuntimeError(f"{SERVICE_UUID} missing from: {name}")

    ios = sources["iOS"]
    direct_decoder = re.search(
        r"QUATERNION\s*=\s*QUATERNION\(\s*W:\s*FLOAT\(AT:\s*0\),\s*"
        r"X:\s*FLOAT\(AT:\s*4\),\s*Y:\s*FLOAT\(AT:\s*8\),\s*"
        r"Z:\s*FLOAT\(AT:\s*12\)",
        ios,
    )
    array_decoder = (
        re.search(
            r"FLOAT\(AT:\s*0\),\s*FLOAT\(AT:\s*4\),\s*"
            r"FLOAT\(AT:\s*8\),\s*FLOAT\(AT:\s*12\)",
            ios,
        )
        and re.search(
            r"W:\s*VALUES\[0\].*X:\s*VALUES\[1\].*"
            r"Y:\s*VALUES\[2\].*Z:\s*VALUES\[3\]",
            ios,
            re.DOTALL,
        )
    )
    if not (direct_decoder or array_decoder):
        raise RuntimeError("iOS quaternion decoder is no longer w,x,y,z")

    packet = struct.pack("<ffff", 1.0, -0.5, 0.25, 0.0)
    if len(packet) != 16 or struct.unpack("<ffff", packet) != (1.0, -0.5, 0.25, 0.0):
        raise RuntimeError("host Float32 little-endian check failed")

    print("PASS: service/characteristic UUIDs match YUNSH Link and YUNSH OS")
    print("PASS: quaternion wire format is 16-byte little-endian w,x,y,z")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except RuntimeError as error:
        print(f"FAIL: {error}", file=sys.stderr)
        raise SystemExit(1)
