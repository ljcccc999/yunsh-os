#include <cmath>
#include <cstdint>

#include <unity.h>

#include "battery_curve.h"
#include "yunsh_protocol.h"

void test_quaternion_is_little_endian_wxyz() {
  uint8_t packet[YunshProtocol::kQuaternionPacketSize] = {};
  YunshProtocol::encodeQuaternion(1.0f, -0.5f, 0.25f, 0.0f, packet);
  TEST_ASSERT_EQUAL_HEX8(0x00, packet[0]);
  TEST_ASSERT_EQUAL_HEX8(0x00, packet[1]);
  TEST_ASSERT_EQUAL_HEX8(0x80, packet[2]);
  TEST_ASSERT_EQUAL_HEX8(0x3F, packet[3]);
  TEST_ASSERT_FLOAT_WITHIN(0.00001f, 1.0f,
                           YunshProtocol::readFloatLe(packet));
  TEST_ASSERT_FLOAT_WITHIN(0.00001f, -0.5f,
                           YunshProtocol::readFloatLe(packet + 4));
  TEST_ASSERT_FLOAT_WITHIN(0.00001f, 0.25f,
                           YunshProtocol::readFloatLe(packet + 8));
}

void test_status_contains_voltage_and_drop_count() {
  const YunshProtocol::StatusFields fields{
      static_cast<uint8_t>(YunshProtocol::kSensorReady |
                           YunshProtocol::kBatteryValid |
                           YunshProtocol::kLowBattery),
      YunshProtocol::SensorState::kReady,
      73,
      8,
      3542,
      50,
      2,
      513,
  };
  uint8_t packet[YunshProtocol::kStatusPacketSize] = {};
  YunshProtocol::encodeStatus(fields, packet);
  TEST_ASSERT_EQUAL_UINT8(1, packet[0]);
  TEST_ASSERT_EQUAL_UINT8(73, packet[3]);
  TEST_ASSERT_EQUAL_UINT8(8, packet[4]);
  TEST_ASSERT_EQUAL_UINT16(3542, YunshProtocol::readU16Le(packet + 5));
  TEST_ASSERT_EQUAL_UINT8(50, packet[7]);
  TEST_ASSERT_EQUAL_UINT8(2, packet[8]);
  TEST_ASSERT_EQUAL_UINT16(513, YunshProtocol::readU16Le(packet + 10));
}

void test_lipo_curve_boundaries_and_interpolation() {
  TEST_ASSERT_EQUAL_UINT8(100, YunshBattery::millivoltsToPercent(4250));
  TEST_ASSERT_EQUAL_UINT8(0, YunshBattery::millivoltsToPercent(3200));
  TEST_ASSERT_EQUAL_UINT8(50, YunshBattery::millivoltsToPercent(3870));
  TEST_ASSERT_UINT8_WITHIN(1, 45, YunshBattery::millivoltsToPercent(3850));
}

void test_adc_divider_conversion() {
  // 2866 / 4095 * 3.0 V * 2.0 = approximately 4.2 V.
  const uint16_t millivolts = YunshBattery::rawAdcToBatteryMillivolts(
      2866, 4095, 3000, 470000, 470000, 1000000);
  TEST_ASSERT_UINT16_WITHIN(2, 4200, millivolts);
}

void test_median_rejects_outliers() {
  uint16_t values[9] = {2000, 1999, 2001, 50, 2002, 4095, 1998, 2000, 2001};
  TEST_ASSERT_EQUAL_UINT16(2000, YunshBattery::median(values));
}

int main(int argc, char** argv) {
  UNITY_BEGIN();
  RUN_TEST(test_quaternion_is_little_endian_wxyz);
  RUN_TEST(test_status_contains_voltage_and_drop_count);
  RUN_TEST(test_lipo_curve_boundaries_and_interpolation);
  RUN_TEST(test_adc_divider_conversion);
  RUN_TEST(test_median_rejects_outliers);
  return UNITY_END();
}

