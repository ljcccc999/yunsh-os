#pragma once

#include <stddef.h>
#include <stdint.h>
#include <string.h>

namespace YunshProtocol {

constexpr char kGlassesServiceUuid[] =
    "F000AA00-0451-4000-B000-000000000000";
constexpr char kQuaternionUuid[] =
    "F000AA01-0451-4000-B000-000000000000";
constexpr char kBrightnessUuid[] =
    "F000AA02-0451-4000-B000-000000000000";
constexpr char kStatusUuid[] =
    "F000AA03-0451-4000-B000-000000000000";

constexpr uint16_t kBatteryServiceUuid = 0x180F;
constexpr uint16_t kBatteryLevelUuid = 0x2A19;
constexpr size_t kQuaternionPacketSize = 16;
constexpr size_t kStatusPacketSize = 12;
constexpr uint8_t kProtocolVersion = 1;

enum StatusFlag : uint8_t {
  kSensorReady = 1u << 0,
  kBatteryValid = 1u << 1,
  kUsbPowered = 1u << 2,
  kCharging = 1u << 3,
  kLowBattery = 1u << 4,
  kSecuredConnection = 1u << 5,
  kPairingWindowOpen = 1u << 6,
  kDfuMode = 1u << 7,
};

enum class SensorState : uint8_t {
  kReady = 0,
  kNotFound = 1,
  kReportConfigurationFailed = 2,
  kStale = 3,
  kRecoveringAfterReset = 4,
};

struct StatusFields {
  uint8_t flags;
  SensorState sensorState;
  uint8_t brightnessPercent;
  uint8_t batteryPercent;
  uint16_t batteryMillivolts;
  uint8_t reportRateHz;
  uint8_t trustedHostCount;
  uint16_t droppedSamples;
};

inline void writeU16Le(uint16_t value, uint8_t* output) {
  output[0] = static_cast<uint8_t>(value & 0xFFu);
  output[1] = static_cast<uint8_t>((value >> 8) & 0xFFu);
}

inline uint16_t readU16Le(const uint8_t* input) {
  return static_cast<uint16_t>(input[0]) |
         static_cast<uint16_t>(input[1]) << 8;
}

inline void writeFloatLe(float value, uint8_t* output) {
  static_assert(sizeof(float) == 4, "YUNSH BLE protocol requires Float32");
  uint32_t raw = 0;
  memcpy(&raw, &value, sizeof(raw));
  output[0] = static_cast<uint8_t>(raw & 0xFFu);
  output[1] = static_cast<uint8_t>((raw >> 8) & 0xFFu);
  output[2] = static_cast<uint8_t>((raw >> 16) & 0xFFu);
  output[3] = static_cast<uint8_t>((raw >> 24) & 0xFFu);
}

inline float readFloatLe(const uint8_t* input) {
  const uint32_t raw =
      static_cast<uint32_t>(input[0]) |
      static_cast<uint32_t>(input[1]) << 8 |
      static_cast<uint32_t>(input[2]) << 16 |
      static_cast<uint32_t>(input[3]) << 24;
  float value = 0.0f;
  memcpy(&value, &raw, sizeof(value));
  return value;
}

// Existing YUNSH Link and YUNSH OS clients expect w, x, y, z in this order.
inline void encodeQuaternion(float w, float x, float y, float z,
                             uint8_t output[kQuaternionPacketSize]) {
  writeFloatLe(w, output + 0);
  writeFloatLe(x, output + 4);
  writeFloatLe(y, output + 8);
  writeFloatLe(z, output + 12);
}

inline void encodeStatus(const StatusFields& fields,
                         uint8_t output[kStatusPacketSize]) {
  output[0] = kProtocolVersion;
  output[1] = fields.flags;
  output[2] = static_cast<uint8_t>(fields.sensorState);
  output[3] = fields.brightnessPercent;
  output[4] = fields.batteryPercent;
  writeU16Le(fields.batteryMillivolts, output + 5);
  output[7] = fields.reportRateHz;
  output[8] = fields.trustedHostCount;
  output[9] = 0;
  writeU16Le(fields.droppedSamples, output + 10);
}

}  // namespace YunshProtocol

