#pragma once

#include <Arduino.h>
#include <bluefruit.h>

#include "hardware_config.h"

class SettingsStore {
 public:
  bool begin();
  uint8_t brightness() const { return data_.brightness; }
  uint8_t trustedHostCount() const { return data_.hostCount; }
  bool isTrusted(const ble_gap_addr_t& address) const;
  bool addTrusted(const ble_gap_addr_t& address);
  void setBrightness(uint8_t brightness);
  bool flushIfDue(uint32_t nowMs, bool force = false);
  bool clearTrustedHosts();

 private:
  struct __attribute__((packed)) StoredAddress {
    uint8_t type;
    uint8_t bytes[6];
  };

  struct __attribute__((packed)) StoredData {
    uint32_t magic;
    uint8_t version;
    uint8_t brightness;
    uint8_t hostCount;
    uint8_t reserved;
    StoredAddress hosts[YunshHardware::kMaximumTrustedHosts];
    uint32_t crc;
  };

  static constexpr uint32_t kMagic = 0x48534E59;  // "YNSH" little-endian
  static constexpr uint8_t kVersion = 1;
  static constexpr char kPath[] = "/yunsh-glasses.bin";
  static constexpr char kTempPath[] = "/yunsh-glasses.tmp";

  void resetDefaults();
  bool save();
  static uint32_t crc32(const uint8_t* data, size_t length);
  static bool addressEquals(const StoredAddress& stored,
                            const ble_gap_addr_t& address);

  StoredData data_{};
  bool dirty_ = false;
  uint32_t dirtySinceMs_ = 0;
};

