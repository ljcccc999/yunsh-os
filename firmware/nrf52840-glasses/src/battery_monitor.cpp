#include "battery_monitor.h"

#include <nrf.h>

#include "battery_curve.h"
#include "hardware_config.h"

using namespace YunshHardware;

void BatteryMonitor::begin() {
  analogReadResolution(12);
  analogReference(AR_INTERNAL_3_0);
  pinMode(kBatteryAdcPin, INPUT);
  if (kChargeStatusPin >= 0) {
    pinMode(static_cast<uint32_t>(kChargeStatusPin),
            kChargeStatusActiveLow ? INPUT_PULLUP : INPUT_PULLDOWN);
  }

  // Fill the EMA at startup instead of reporting a transient zero.
  poll(millis(), true);
}

bool BatteryMonitor::poll(uint32_t nowMs, bool force) {
  if (!force && static_cast<uint32_t>(nowMs - lastPollMs_) < kBatteryPollMs) {
    return false;
  }
  lastPollMs_ = nowMs;

  const uint16_t medianMv = sampleMedianMillivolts();
  if (!initialized_) {
    filteredMillivolts_ = medianMv;
    initialized_ = true;
  } else {
    filteredMillivolts_ +=
        kBatteryEmaAlpha * (static_cast<float>(medianMv) - filteredMillivolts_);
  }

  millivolts_ = static_cast<uint16_t>(filteredMillivolts_ + 0.5f);
  valid_ =
      millivolts_ >= kBatteryValidMinMv && millivolts_ <= kBatteryValidMaxMv;
  percent_ = valid_ ? YunshBattery::millivoltsToPercent(millivolts_) : 0;
  usbPowered_ = readUsbPower();
  charging_ = valid_ && usbPowered_ && readChargingStatus();
  low_ = valid_ &&
         (millivolts_ <= kLowBatteryMv || percent_ <= kLowBatteryPercent);
  return true;
}

uint16_t BatteryMonitor::sampleMedianMillivolts() {
  uint16_t readings[kBatteryMedianSamples] = {};

  // A high-impedance divider needs one discarded read after the mux settles.
  (void)analogRead(kBatteryAdcPin);
  delayMicroseconds(kBatterySampleGapUs);

  for (uint8_t index = 0; index < kBatteryMedianSamples; ++index) {
    readings[index] = static_cast<uint16_t>(analogRead(kBatteryAdcPin));
    delayMicroseconds(kBatterySampleGapUs);
  }

  const uint16_t rawMedian = YunshBattery::median(readings);
  return YunshBattery::rawAdcToBatteryMillivolts(
      rawMedian, kAdcMaximum, kAdcReferenceMv, kBatteryTopOhms,
      kBatteryBottomOhms, kBatteryCalibrationPpm);
}

bool BatteryMonitor::readUsbPower() const {
#if defined(POWER_USBREGSTATUS_VBUSDETECT_Msk)
  uint32_t status = 0;
  uint8_t softDeviceEnabled = 0;
  if (sd_softdevice_is_enabled(&softDeviceEnabled) == NRF_SUCCESS &&
      softDeviceEnabled &&
      sd_power_usbregstatus_get(&status) == NRF_SUCCESS) {
    return (status & POWER_USBREGSTATUS_VBUSDETECT_Msk) != 0;
  }
  return (NRF_POWER->USBREGSTATUS & POWER_USBREGSTATUS_VBUSDETECT_Msk) != 0;
#else
  return false;
#endif
}

bool BatteryMonitor::readChargingStatus() const {
  if (kChargeStatusPin >= 0) {
    const bool level =
        digitalRead(static_cast<uint32_t>(kChargeStatusPin)) == HIGH;
    return kChargeStatusActiveLow ? !level : level;
  }
  // No charge-status pin is available on many XIAO-compatible boards.
  // This is intentionally only a "charging likely" indication.
  return millivolts_ < kChargeCompleteMv;
}
