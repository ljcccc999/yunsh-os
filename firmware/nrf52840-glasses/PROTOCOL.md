# YUNSH V1 Glasses BLE Protocol

All custom characteristics require an encrypted, bonded connection. The
peripheral accepts one Central at a time.

## Identity

- Advertising name: `YUNSH V1 (Glasses)`
- Glasses service: `F000AA00-0451-4000-B000-000000000000`
- Standard Battery service: `180F`

## Characteristics

| Characteristic | UUID | Access | Payload |
| --- | --- | --- | --- |
| Quaternion | `F000AA01-0451-4000-B000-000000000000` | Read, Notify | 16 bytes: little-endian Float32 `w, x, y, z` |
| Brightness | `F000AA02-0451-4000-B000-000000000000` | Read, Write, Notify | One byte, clamped to `0...100` |
| Controller status | `F000AA03-0451-4000-B000-000000000000` | Read, Notify | 12-byte versioned packet below |
| Battery level | `2A19` | Read, Notify | Standard one-byte percentage |

The quaternion layout exactly matches the existing YUNSH Link Swift decoder
and the YUNSH OS `yunsh-glasses-bridge.py` decoder.

## Controller status v1

| Offset | Size | Meaning |
| ---: | ---: | --- |
| 0 | 1 | Protocol version (`1`) |
| 1 | 1 | Flags |
| 2 | 1 | Sensor state |
| 3 | 1 | Brightness percent |
| 4 | 1 | Battery percent |
| 5 | 2 | Battery millivolts, little-endian |
| 7 | 1 | Measured sensor reports per second |
| 8 | 1 | Trusted-host count |
| 9 | 1 | Reserved |
| 10 | 2 | Dropped samples, saturating counter, little-endian |

Flags: bit 0 sensor ready, bit 1 battery valid, bit 2 USB VBUS present, bit 3
charging/charging-likely, bit 4 low battery, bit 5 connection secured, bit 6
pairing window open, bit 7 BLE DFU maintenance mode.

Sensor state: `0` ready, `1` not found, `2` report configuration failed, `3`
stale, `4` recovering after BNO reset.

## Connection model

Phone Mode and YUNSH OS Mode are mutually exclusive because the peripheral is
configured for one BLE Central. Up to two bonded identity addresses can be
trusted so an iPhone and one Raspberry Pi may be enrolled. Existing bonds
reconnect without interaction. A new host can pair only on first boot or while
the physical pairing window is open.

