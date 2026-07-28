#pragma once

#include <stddef.h>
#include <stdint.h>

namespace YunshBattery {

struct CurvePoint {
  uint16_t millivolts;
  uint8_t percent;
};

// Approximate resting-voltage curve for a single 4.2 V LiPo cell. Voltage
// under load varies by cell, temperature and current; calibration is mandatory.
constexpr CurvePoint kLiPoCurve[] = {
    {4200, 100}, {4150, 95}, {4110, 90}, {4070, 85}, {4020, 80},
    {3980, 75},  {3950, 70}, {3910, 60}, {3870, 50}, {3830, 40},
    {3790, 30},  {3750, 20}, {3710, 15}, {3670, 10}, {3550, 5},
    {3300, 0},
};

inline uint8_t millivoltsToPercent(uint16_t millivolts) {
  constexpr size_t count = sizeof(kLiPoCurve) / sizeof(kLiPoCurve[0]);
  if (millivolts >= kLiPoCurve[0].millivolts) {
    return kLiPoCurve[0].percent;
  }
  if (millivolts <= kLiPoCurve[count - 1].millivolts) {
    return kLiPoCurve[count - 1].percent;
  }

  for (size_t index = 1; index < count; ++index) {
    const CurvePoint high = kLiPoCurve[index - 1];
    const CurvePoint low = kLiPoCurve[index];
    if (millivolts >= low.millivolts) {
      const uint32_t voltageSpan = high.millivolts - low.millivolts;
      const uint32_t percentSpan = high.percent - low.percent;
      const uint32_t offset = millivolts - low.millivolts;
      return static_cast<uint8_t>(
          low.percent + (offset * percentSpan + voltageSpan / 2) / voltageSpan);
    }
  }
  return 0;
}

template <size_t N>
inline uint16_t median(uint16_t (&values)[N]) {
  static_assert(N > 0 && (N % 2) == 1, "Median requires an odd sample count");
  for (size_t i = 1; i < N; ++i) {
    const uint16_t value = values[i];
    size_t j = i;
    while (j > 0 && values[j - 1] > value) {
      values[j] = values[j - 1];
      --j;
    }
    values[j] = value;
  }
  return values[N / 2];
}

inline uint16_t rawAdcToBatteryMillivolts(uint16_t raw,
                                         uint16_t adcMaximum,
                                         uint16_t referenceMillivolts,
                                         uint32_t topOhms,
                                         uint32_t bottomOhms,
                                         uint32_t calibrationPpm) {
  if (adcMaximum == 0 || bottomOhms == 0) {
    return 0;
  }
  uint64_t scaled = static_cast<uint64_t>(raw) * referenceMillivolts;
  scaled *= (static_cast<uint64_t>(topOhms) + bottomOhms);
  scaled *= calibrationPpm;
  const uint64_t divisor =
      static_cast<uint64_t>(adcMaximum) * bottomOhms * 1000000ULL;
  scaled = (scaled + divisor / 2) / divisor;
  return scaled > 65535 ? 65535 : static_cast<uint16_t>(scaled);
}

}  // namespace YunshBattery

