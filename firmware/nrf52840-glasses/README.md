# YUNSH V1 Glasses Controller Firmware

Production-oriented firmware for a Seeed XIAO nRF52840-compatible board and a
BNO085/BNO080 motion module. It streams fused 3DoF orientation to either YUNSH
Link on iPhone or YUNSH OS on Raspberry Pi, while reporting real battery
voltage/percentage and receiving persistent display-brightness control.

## Hardware

- XIAO nRF52840-compatible board with an Adafruit nRF52-compatible bootloader
- BNO085 or BNO080 breakout configured for I2C address `0x4A`
- Single-cell protected LiPo
- Two 470 kΩ 1% divider resistors and one 100 nF capacitor for battery sensing
- Optional momentary pairing button
- Display driver with a 3.3 V-compatible PWM brightness input

### Wiring

| XIAO | BNO085 | Notes |
| --- | --- | --- |
| `3V3` | `VCC` | Do not use 5 V |
| `GND` | `GND` | Common ground |
| `D4 / SDA` | `SDA` | I2C |
| `D5 / SCL` | `SCL` | I2C |

Battery measurement:

```text
LiPo BAT+ ---- 470 kΩ ----+---- A0
                          |
                        470 kΩ
                          |
GND ----------------------+---- GND
                          |
                        100 nF
                          |
GND ----------------------+
```

Display and pairing:

| XIAO | Destination |
| --- | --- |
| `D3` | Display-driver PWM brightness input |
| `D1` | Optional button to GND |

The pictured GY-BNO08x board cannot normally be plugged directly onto a XIAO
pin-for-pin. Use four short wires or a small carrier PCB. A custom carrier can
place both boards back-to-back without a loose cable.

> **Mandatory calibration:** compatible boards, resistor tolerances and ADC
> references vary. Before trusting the voltage or percentage, measure BAT+ with
> a multimeter, run the `status` serial command, then change
> `kBatteryCalibrationPpm` in `include/hardware_config.h`. For example, if the
> meter reads 4.08 V but firmware reads 4.00 V, use approximately
> `1000000 × 4080 / 4000 = 1020000`. Never connect BAT+ directly to A0.

## Implemented behavior

- `YUNSH V1 (Glasses)` BLE identity and UUIDs compatible with YUNSH Link/YUNSH OS
- 50 Hz BNO085 Game Rotation Vector, normalized and sent as Float32 `w,x,y,z`
- Sensor-not-found, report-failure, reset-recovery and stale-stream states
- Nine-sample ADC median filter followed by EMA smoothing
- Divider/calibration conversion to battery millivolts
- Piecewise single-cell LiPo voltage-to-percentage mapping
- Standard Battery Service plus voltage, USB, charge-likely and low-battery status
- Persistent 0–100% PWM brightness with delayed flash writes
- One active Central, up to two explicitly enrolled bonded hosts
- First-boot/physical-button pairing window; unknown hosts rejected otherwise
- Lower BNO report rate and slower advertising while idle
- Optional Nordic/Adafruit BLE DFU maintenance mode

## Build

Install PlatformIO, then:

```bash
cd firmware/nrf52840-glasses
pio run
pio test -e native
python3 tools/verify_compatibility.py
```

The Seeed-supported PlatformIO board package is pinned through `platformio.ini`.
The first build downloads the board support package and Adafruit BNO08x
library. A successful target build exports versioned `.uf2`, `.hex`, BLE-DFU
`.zip`, and `SHA256SUMS` files to `dist/`.

## USB flashing

1. Connect the XIAO with a data-capable USB-C cable.
2. Double-press Reset so the bootloader drive appears.
3. Run `pio run -t upload`, or copy
   `dist/YUNSH-Glasses-nRF52840-v1.0.0.uf2` to the bootloader drive.
4. Open a 115200 baud serial monitor and run `status`.

Clone boards must actually contain an Adafruit-compatible bootloader. If upload
fails, use SWD/J-Link once to install the correct XIAO nRF52840 bootloader.

## Pairing and host switching

- With no trusted host, power-on opens pairing for 120 seconds.
- Hold the D1 button for 2 seconds to open another 120-second pairing window.
- Hold it for 8 seconds to erase the allowlist and Bluefruit peripheral bonds.
- The same actions are available over USB serial as `pair` and `clear`.
- At most one host is connected: Phone Mode uses iPhone directly; YUNSH OS Mode
  disconnects the phone and uses the Raspberry Pi.

The board has no display or keyboard, so BLE uses encrypted bonded “Just Works”
pairing without MITM authentication. The physical pairing window and saved
identity allowlist prevent unattended enrollment; pair away from untrusted
devices.

## BLE DFU / OTA

Hold D1 while powering or resetting the board. The firmware then exposes the
Adafruit/Nordic DFU service for that boot only. Use nRF Connect or Bluefruit LE
Connect with a package built for the matching bootloader. Normal boots do not
expose DFU.

USB UF2 remains the recovery path. BLE DFU depends on the clone having a
compatible Adafruit nRF52 bootloader and must be verified on the exact board
before field use.

## Serial diagnostics

At 115200 baud:

- `status` — voltage, percentage, sensor state and trusted-host count
- `pair` — open pairing for 120 seconds
- `clear` — erase trusted hosts and BLE bonds
- `tare` — restart the sensor stream; recentering is performed by the host

## Limits

This is 3DoF orientation firmware. A camera cannot be connected to this design
to obtain standalone 6DoF: camera capture, calibration and visual-inertial
fusion must run on Raspberry Pi or another capable processor. Hardware behavior
still requires validation on the exact compatible board, BNO085 module, battery
divider and display driver.
