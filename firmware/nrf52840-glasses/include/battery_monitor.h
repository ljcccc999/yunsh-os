#pragma once

#include <Arduino.h>

class BatteryMonitor {
 public:
  void begin();
  bool poll(uint32_t nowMs, bool force = false);

  bool valid() const { return valid_; }
  bool usbPowered() const { return usbPowered_; }
  bool charging() const { return charging_; }
  bool low() const { return low_; }
  uint16_t millivolts() const { return millivolts_; }
  uint8_t percent() const { return percent_; }

 private:
  uint16_t sampleMedianMillivolts();
  bool readUsbPower() const;
  bool readChargingStatus() const;

  uint32_t lastPollMs_ = 0;
  float filteredMillivolts_ = 0.0f;
  uint16_t millivolts_ = 0;
  uint8_t percent_ = 0;
  bool initialized_ = false;
  bool valid_ = false;
  bool usbPowered_ = false;
  bool charging_ = false;
  bool low_ = false;
};

