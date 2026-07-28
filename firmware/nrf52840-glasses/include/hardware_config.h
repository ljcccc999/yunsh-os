#pragma once

#include <Arduino.h>

// All board-specific choices live here. Measure the real divider with a
// multimeter and adjust kBatteryCalibrationPpm before trusting the percentage.
namespace YunshHardware {

constexpr char kDeviceName[] = "YUNSH V1 (Glasses)";
constexpr char kManufacturer[] = "YUNSH";
constexpr char kModel[] = "YUNSH V1 Glasses Controller";

// BNO085 / BNO080 over I2C. XIAO nRF52840: SDA=D4, SCL=D5.
constexpr uint8_t kBnoI2cAddress = 0x4A;
constexpr uint32_t kI2cClockHz = 400000;
constexpr uint32_t kConnectedReportIntervalUs = 20000;    // 50 Hz
constexpr uint32_t kIdleReportIntervalUs = 100000;        // 10 Hz
constexpr uint32_t kSensorStaleMs = 750;
constexpr uint32_t kSensorRetryMs = 5000;

// External single-cell LiPo divider:
// BAT+ -- 470k -- A0 -- 470k -- GND, with 100 nF from A0 to GND.
// Never connect a LiPo directly to an nRF52840 ADC pin.
constexpr uint32_t kBatteryAdcPin = A0;
constexpr uint32_t kBatteryTopOhms = 470000;
constexpr uint32_t kBatteryBottomOhms = 470000;
constexpr uint16_t kAdcReferenceMv = 3000;
constexpr uint16_t kAdcMaximum = 4095;                    // 12-bit
constexpr uint32_t kBatteryCalibrationPpm = 1000000;      // 1.000000x
constexpr uint8_t kBatteryMedianSamples = 9;              // must be odd
constexpr uint16_t kBatterySampleGapUs = 350;
constexpr float kBatteryEmaAlpha = 0.18f;
constexpr uint32_t kBatteryPollMs = 2000;
constexpr uint16_t kBatteryValidMinMv = 2500;
constexpr uint16_t kBatteryValidMaxMv = 4600;
constexpr uint16_t kLowBatteryMv = 3550;
constexpr uint8_t kLowBatteryPercent = 8;

// Optional charger status output. Leave -1 when the compatible board does not
// expose one. With -1, firmware reports a conservative "charging likely" flag
// when VBUS is present and a valid battery is below kChargeCompleteMv.
constexpr int8_t kChargeStatusPin = -1;
constexpr bool kChargeStatusActiveLow = true;
constexpr uint16_t kChargeCompleteMv = 4180;

// PWM output to a display-driver brightness input. Confirm the driver accepts
// 3.3 V PWM. Set kBrightnessOutputEnabled=false if brightness is handled by
// another board.
constexpr bool kBrightnessOutputEnabled = true;
constexpr uint32_t kBrightnessPwmPin = D3;
constexpr bool kBrightnessActiveHigh = true;
constexpr uint8_t kDefaultBrightness = 70;
constexpr uint32_t kBrightnessSaveDelayMs = 1500;

// Optional normally-open button from D1 to GND.
// Hold at boot for BLE DFU maintenance mode.
// Hold for 2 s while running to open a 120 s pairing window.
// Hold for 8 s to erase trusted hosts and Bluefruit peripheral bonds.
constexpr bool kPairingButtonEnabled = true;
constexpr uint32_t kPairingButtonPin = D1;
constexpr bool kPairingButtonActiveLow = true;
constexpr uint32_t kPairingButtonDebounceMs = 30;
constexpr uint32_t kOpenPairingHoldMs = 2000;
constexpr uint32_t kClearBondsHoldMs = 8000;
constexpr uint32_t kPairingWindowMs = 120000;
constexpr uint8_t kMaximumTrustedHosts = 2;               // iPhone + Raspberry Pi

// Nordic/Adafruit secure DFU service. It is exposed only when the pairing
// button is held during boot, reducing the normal attack surface.
constexpr bool kBleDfuSupported = true;
constexpr uint32_t kDfuBootButtonSampleMs = 600;

constexpr int8_t kBleTxPowerDbm = 0;
constexpr uint16_t kAdvertisingFastInterval = 32;         // 20 ms
constexpr uint16_t kAdvertisingSlowInterval = 320;        // 200 ms
constexpr uint8_t kAdvertisingFastTimeoutSeconds = 20;
constexpr uint16_t kConnectionIntervalMin = 12;           // 15 ms
constexpr uint16_t kConnectionIntervalMax = 24;           // 30 ms
constexpr uint16_t kConnectionSlaveLatency = 0;
constexpr uint16_t kConnectionSupervisionTimeoutMs = 4000;

static_assert(kBatteryMedianSamples >= 3 &&
                  (kBatteryMedianSamples % 2) == 1,
              "Battery median sample count must be odd and >= 3");
static_assert(kBatteryBottomOhms > 0, "Battery divider bottom resistor is zero");
static_assert(kMaximumTrustedHosts >= 1 && kMaximumTrustedHosts <= 4,
              "Trusted-host storage supports 1..4 entries");

}  // namespace YunshHardware
