#include "settings_store.h"

#include <Adafruit_LittleFS.h>
#include <InternalFileSystem.h>

using namespace Adafruit_LittleFS_Namespace;
using namespace YunshHardware;

constexpr char SettingsStore::kPath[];
constexpr char SettingsStore::kTempPath[];

bool SettingsStore::begin() {
  if (!InternalFS.begin()) {
    resetDefaults();
    return false;
  }

  File file(InternalFS);
  if (!file.open(kPath, FILE_O_READ)) {
    resetDefaults();
    return save();
  }

  const size_t readCount =
      file.read(reinterpret_cast<uint8_t*>(&data_), sizeof(data_));
  file.close();
  const uint32_t expectedCrc =
      crc32(reinterpret_cast<const uint8_t*>(&data_),
            sizeof(data_) - sizeof(data_.crc));
  if (readCount != sizeof(data_) || data_.magic != kMagic ||
      data_.version != kVersion ||
      data_.hostCount > kMaximumTrustedHosts || data_.crc != expectedCrc) {
    resetDefaults();
    return save();
  }
  return true;
}

bool SettingsStore::isTrusted(const ble_gap_addr_t& address) const {
  for (uint8_t index = 0; index < data_.hostCount; ++index) {
    if (addressEquals(data_.hosts[index], address)) {
      return true;
    }
  }
  return false;
}

bool SettingsStore::addTrusted(const ble_gap_addr_t& address) {
  if (isTrusted(address)) {
    return true;
  }
  if (data_.hostCount >= kMaximumTrustedHosts) {
    return false;
  }
  StoredAddress& destination = data_.hosts[data_.hostCount++];
  destination.type = address.addr_type;
  memcpy(destination.bytes, address.addr, sizeof(destination.bytes));
  dirty_ = true;
  dirtySinceMs_ = millis();
  return flushIfDue(millis(), true);
}

void SettingsStore::setBrightness(uint8_t brightness) {
  if (data_.brightness == brightness) {
    return;
  }
  data_.brightness = brightness;
  dirty_ = true;
  dirtySinceMs_ = millis();
}

bool SettingsStore::flushIfDue(uint32_t nowMs, bool force) {
  if (!dirty_) {
    return true;
  }
  if (!force &&
      static_cast<uint32_t>(nowMs - dirtySinceMs_) < kBrightnessSaveDelayMs) {
    return false;
  }
  return save();
}

bool SettingsStore::clearTrustedHosts() {
  data_.hostCount = 0;
  memset(data_.hosts, 0, sizeof(data_.hosts));
  dirty_ = true;
  dirtySinceMs_ = millis();
  return flushIfDue(millis(), true);
}

void SettingsStore::resetDefaults() {
  memset(&data_, 0, sizeof(data_));
  data_.magic = kMagic;
  data_.version = kVersion;
  data_.brightness = kDefaultBrightness;
  dirty_ = true;
  dirtySinceMs_ = millis();
}

bool SettingsStore::save() {
  data_.crc = crc32(reinterpret_cast<const uint8_t*>(&data_),
                    sizeof(data_) - sizeof(data_.crc));

  File file(InternalFS);
  if (!file.open(kTempPath, FILE_O_WRITE)) {
    return false;
  }
  const size_t written =
      file.write(reinterpret_cast<const uint8_t*>(&data_), sizeof(data_));
  file.close();
  if (written != sizeof(data_)) {
    InternalFS.remove(kTempPath);
    return false;
  }

  InternalFS.remove(kPath);
  if (!InternalFS.rename(kTempPath, kPath)) {
    return false;
  }
  dirty_ = false;
  return true;
}

uint32_t SettingsStore::crc32(const uint8_t* data, size_t length) {
  uint32_t crc = 0xFFFFFFFFu;
  for (size_t index = 0; index < length; ++index) {
    crc ^= data[index];
    for (uint8_t bit = 0; bit < 8; ++bit) {
      crc = (crc >> 1) ^ (0xEDB88320u & (0u - (crc & 1u)));
    }
  }
  return ~crc;
}

bool SettingsStore::addressEquals(const StoredAddress& stored,
                                  const ble_gap_addr_t& address) {
  return stored.type == address.addr_type &&
         memcmp(stored.bytes, address.addr, sizeof(stored.bytes)) == 0;
}

