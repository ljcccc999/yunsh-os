#include <Adafruit_BNO08x.h>
#include <Arduino.h>
#include <Wire.h>
#include <bluefruit.h>

#include <cmath>

#include "battery_monitor.h"
#include "hardware_config.h"
#include "settings_store.h"
#include "yunsh_protocol.h"

#ifndef YUNSH_FIRMWARE_VERSION
#define YUNSH_FIRMWARE_VERSION "dev"
#endif

using namespace YunshHardware;
using namespace YunshProtocol;

namespace {

BLEService glassesService(kGlassesServiceUuid);
BLECharacteristic quaternionCharacteristic(kQuaternionUuid);
BLECharacteristic brightnessCharacteristic(kBrightnessUuid);
BLECharacteristic statusCharacteristic(kStatusUuid);
BLEService batteryService(kBatteryServiceUuid);
BLECharacteristic batteryLevelCharacteristic(kBatteryLevelUuid);
BLEDfu bleDfu;
BLEDis deviceInformation;

Adafruit_BNO08x bno085(-1);
sh2_SensorValue_t sensorValue;
BatteryMonitor battery;
SettingsStore settings;

SensorState sensorState = SensorState::kNotFound;
uint32_t lastSensorSampleMs = 0;
uint32_t lastSensorAttemptMs = 0;
uint32_t lastStatusNotifyMs = 0;
uint32_t sampleWindowStartedMs = 0;
uint16_t samplesThisWindow = 0;
uint16_t droppedSamples = 0;
uint8_t measuredReportRateHz = 0;
uint8_t brightnessPercent = kDefaultBrightness;
uint16_t activeConnectionHandle = BLE_CONN_HANDLE_INVALID;
bool activeConnectionSecured = false;
bool sensorInitialized = false;
bool dfuMode = false;
uint32_t pairingWindowUntilMs = 0;

bool buttonWasPressed = false;
bool buttonPairingOpened = false;
bool buttonClearTaken = false;
uint32_t buttonPressedAtMs = 0;
uint32_t lastButtonChangeMs = 0;

bool timeBefore(uint32_t now, uint32_t deadline) {
  return static_cast<int32_t>(deadline - now) > 0;
}

bool pairingWindowOpen(uint32_t now = millis()) {
  return timeBefore(now, pairingWindowUntilMs);
}

bool pairingButtonPressed() {
  if (!kPairingButtonEnabled) {
    return false;
  }
  const bool high = digitalRead(kPairingButtonPin) == HIGH;
  return kPairingButtonActiveLow ? !high : high;
}

void setPairingWindow(uint32_t durationMs) {
  pairingWindowUntilMs = millis() + durationMs;
  Serial.println("[security] Pairing window opened");
}

void disconnectActiveHost() {
  if (activeConnectionHandle == BLE_CONN_HANDLE_INVALID) {
    return;
  }
  BLEConnection* connection = Bluefruit.Connection(activeConnectionHandle);
  if (connection) {
    connection->disconnect();
  }
  activeConnectionHandle = BLE_CONN_HANDLE_INVALID;
  activeConnectionSecured = false;
}

void applyBrightness(uint8_t percent) {
  brightnessPercent = percent > 100 ? 100 : percent;
  if (kBrightnessOutputEnabled) {
    const uint16_t pwm =
        static_cast<uint16_t>((brightnessPercent * 255u + 50u) / 100u);
    analogWrite(kBrightnessPwmPin,
                kBrightnessActiveHigh ? pwm : static_cast<uint8_t>(255u - pwm));
  }
  settings.setBrightness(brightnessPercent);
  brightnessCharacteristic.write8(brightnessPercent);
  if (activeConnectionSecured) {
    brightnessCharacteristic.notify8(brightnessPercent);
  }
}

bool enableSensorReport(uint32_t intervalUs) {
  if (!sensorInitialized) {
    return false;
  }
  if (!bno085.enableReport(SH2_GAME_ROTATION_VECTOR, intervalUs)) {
    sensorState = SensorState::kReportConfigurationFailed;
    return false;
  }
  return true;
}

bool initializeSensor() {
  lastSensorAttemptMs = millis();
  Wire.begin();
  Wire.setClock(kI2cClockHz);

  if (!bno085.begin_I2C(kBnoI2cAddress, &Wire)) {
    sensorInitialized = false;
    sensorState = SensorState::kNotFound;
    Serial.println("[sensor] BNO085 not found");
    return false;
  }

  sensorInitialized = true;
  sensorState = SensorState::kRecoveringAfterReset;
  const bool enabled = enableSensorReport(
      activeConnectionHandle == BLE_CONN_HANDLE_INVALID
          ? kIdleReportIntervalUs
          : kConnectedReportIntervalUs);
  if (enabled) {
    sensorState = SensorState::kReady;
    lastSensorSampleMs = millis();
    Serial.println("[sensor] BNO085 Game Rotation Vector enabled");
  }
  return enabled;
}

void updateStatus(bool forceNotify = false) {
  const uint32_t now = millis();
  if (!forceNotify &&
      static_cast<uint32_t>(now - lastStatusNotifyMs) < 1000) {
    return;
  }
  lastStatusNotifyMs = now;

  uint8_t flags = 0;
  if (sensorState == SensorState::kReady) flags |= kSensorReady;
  if (battery.valid()) flags |= kBatteryValid;
  if (battery.usbPowered()) flags |= kUsbPowered;
  if (battery.charging()) flags |= kCharging;
  if (battery.low()) flags |= kLowBattery;
  if (activeConnectionSecured) flags |= kSecuredConnection;
  if (pairingWindowOpen(now)) flags |= kPairingWindowOpen;
  if (dfuMode) flags |= kDfuMode;

  const StatusFields fields{
      flags,
      sensorState,
      brightnessPercent,
      battery.percent(),
      battery.millivolts(),
      measuredReportRateHz,
      settings.trustedHostCount(),
      droppedSamples,
  };
  uint8_t packet[kStatusPacketSize] = {};
  encodeStatus(fields, packet);
  statusCharacteristic.write(packet, sizeof(packet));
  batteryLevelCharacteristic.write8(battery.percent());

  if (activeConnectionSecured) {
    statusCharacteristic.notify(packet, sizeof(packet));
    batteryLevelCharacteristic.notify8(battery.percent());
  }
}

void startAdvertising() {
  Bluefruit.Advertising.stop();
  Bluefruit.Advertising.clearData();
  Bluefruit.ScanResponse.clearData();
  Bluefruit.Advertising.addFlags(BLE_GAP_ADV_FLAGS_LE_ONLY_GENERAL_DISC_MODE);
  Bluefruit.Advertising.addTxPower();
  Bluefruit.Advertising.addService(glassesService);
  Bluefruit.ScanResponse.addName();
  if (dfuMode) {
    Bluefruit.ScanResponse.addService(bleDfu);
  }
  Bluefruit.Advertising.restartOnDisconnect(true);
  Bluefruit.Advertising.setInterval(kAdvertisingFastInterval,
                                    kAdvertisingSlowInterval);
  Bluefruit.Advertising.setFastTimeout(kAdvertisingFastTimeoutSeconds);
  Bluefruit.Advertising.start(0);
}

void brightnessWriteCallback(uint16_t connectionHandle,
                             BLECharacteristic* characteristic,
                             uint8_t* data, uint16_t length) {
  if (connectionHandle != activeConnectionHandle ||
      !activeConnectionSecured || length != 1) {
    return;
  }
  applyBrightness(data[0]);
  updateStatus(true);
}

void connectCallback(uint16_t connectionHandle) {
  if (activeConnectionHandle != BLE_CONN_HANDLE_INVALID &&
      activeConnectionHandle != connectionHandle) {
    BLEConnection* extra = Bluefruit.Connection(connectionHandle);
    if (extra) extra->disconnect();
    return;
  }

  activeConnectionHandle = connectionHandle;
  activeConnectionSecured = false;
  BLEConnection* connection = Bluefruit.Connection(connectionHandle);
  if (!connection) {
    return;
  }

  // Every connection is secured first. Bluefruit cannot know that an address
  // is bonded until the Central starts encryption, especially with iOS private
  // resolvable addresses. securedCallback validates the resolved identity
  // against the allowlist before enabling telemetry or controls.
  connection->requestPairing();
  enableSensorReport(kConnectedReportIntervalUs);
}

void disconnectCallback(uint16_t connectionHandle, uint8_t reason) {
  (void)reason;
  if (activeConnectionHandle == connectionHandle) {
    activeConnectionHandle = BLE_CONN_HANDLE_INVALID;
    activeConnectionSecured = false;
    enableSensorReport(kIdleReportIntervalUs);
    updateStatus(true);
  }
}

void securedCallback(uint16_t connectionHandle) {
  BLEConnection* connection = Bluefruit.Connection(connectionHandle);
  if (!connection || !connection->secured()) {
    if (connection) connection->requestPairing();
    return;
  }

  const ble_gap_addr_t identity = connection->getPeerAddr();
  if (!settings.isTrusted(identity)) {
    if (!pairingWindowOpen() || !settings.addTrusted(identity)) {
      Serial.println("[security] Secured host is not in allowlist");
      connection->removeBondKey();
      connection->disconnect();
      return;
    }
    Serial.println("[security] Trusted host saved");
  }

  activeConnectionSecured = true;
  updateStatus(true);
}

void pairingCompleteCallback(uint16_t connectionHandle, uint8_t authStatus) {
  if (authStatus != BLE_GAP_SEC_STATUS_SUCCESS) {
    Serial.print("[security] Pairing failed: ");
    Serial.println(authStatus);
    BLEConnection* connection = Bluefruit.Connection(connectionHandle);
    if (connection) connection->disconnect();
    return;
  }
  securedCallback(connectionHandle);
}

void configureGatt() {
  if (dfuMode) {
    bleDfu.begin();
  }

  deviceInformation.setManufacturer(kManufacturer);
  deviceInformation.setModel(kModel);
  deviceInformation.setHardwareRev("XIAO nRF52840 compatible");
  deviceInformation.setSoftwareRev(YUNSH_FIRMWARE_VERSION);
  deviceInformation.begin();

  glassesService.begin();

  quaternionCharacteristic.setProperties(CHR_PROPS_READ | CHR_PROPS_NOTIFY);
  quaternionCharacteristic.setPermission(SECMODE_ENC_NO_MITM,
                                          SECMODE_NO_ACCESS);
  quaternionCharacteristic.setFixedLen(kQuaternionPacketSize);
  quaternionCharacteristic.begin();

  brightnessCharacteristic.setProperties(CHR_PROPS_READ | CHR_PROPS_WRITE |
                                          CHR_PROPS_NOTIFY);
  brightnessCharacteristic.setPermission(SECMODE_ENC_NO_MITM,
                                          SECMODE_ENC_NO_MITM);
  brightnessCharacteristic.setFixedLen(1);
  brightnessCharacteristic.setWriteCallback(brightnessWriteCallback);
  brightnessCharacteristic.begin();

  statusCharacteristic.setProperties(CHR_PROPS_READ | CHR_PROPS_NOTIFY);
  statusCharacteristic.setPermission(SECMODE_ENC_NO_MITM, SECMODE_NO_ACCESS);
  statusCharacteristic.setFixedLen(kStatusPacketSize);
  statusCharacteristic.begin();

  batteryService.begin();
  batteryLevelCharacteristic.setProperties(CHR_PROPS_READ | CHR_PROPS_NOTIFY);
  batteryLevelCharacteristic.setPermission(SECMODE_ENC_NO_MITM,
                                            SECMODE_NO_ACCESS);
  batteryLevelCharacteristic.setFixedLen(1);
  batteryLevelCharacteristic.begin();
}

void serviceSensor() {
  const uint32_t now = millis();
  if (!sensorInitialized) {
    if (static_cast<uint32_t>(now - lastSensorAttemptMs) >= kSensorRetryMs) {
      initializeSensor();
    }
    return;
  }

  if (bno085.wasReset()) {
    sensorState = SensorState::kRecoveringAfterReset;
    if (!enableSensorReport(activeConnectionHandle == BLE_CONN_HANDLE_INVALID
                                ? kIdleReportIntervalUs
                                : kConnectedReportIntervalUs)) {
      sensorInitialized = false;
      if (droppedSamples != UINT16_MAX) ++droppedSamples;
      return;
    }
    sensorState = SensorState::kReady;
  }

  while (bno085.getSensorEvent(&sensorValue)) {
    if (sensorValue.sensorId != SH2_GAME_ROTATION_VECTOR) {
      continue;
    }
    lastSensorSampleMs = now;
    sensorState = SensorState::kReady;
    ++samplesThisWindow;

    const sh2_RotationVector_t& vector =
        sensorValue.un.gameRotationVector;
    const float magnitude =
        std::sqrt(vector.real * vector.real + vector.i * vector.i +
                  vector.j * vector.j + vector.k * vector.k);
    if (!std::isfinite(magnitude) || magnitude < 0.5f || magnitude > 1.5f) {
      if (droppedSamples != UINT16_MAX) ++droppedSamples;
      continue;
    }

    if (activeConnectionSecured) {
      uint8_t packet[kQuaternionPacketSize] = {};
      encodeQuaternion(vector.real / magnitude, vector.i / magnitude,
                       vector.j / magnitude, vector.k / magnitude, packet);
      if (!quaternionCharacteristic.notify(packet, sizeof(packet))) {
        if (droppedSamples != UINT16_MAX) ++droppedSamples;
      }
    }
  }

  if (static_cast<uint32_t>(now - lastSensorSampleMs) > kSensorStaleMs) {
    sensorState = SensorState::kStale;
  }
  if (static_cast<uint32_t>(now - sampleWindowStartedMs) >= 1000) {
    measuredReportRateHz =
        samplesThisWindow > 255 ? 255 : static_cast<uint8_t>(samplesThisWindow);
    samplesThisWindow = 0;
    sampleWindowStartedMs = now;
  }
}

void servicePairingButton() {
  if (!kPairingButtonEnabled) {
    return;
  }
  const uint32_t now = millis();
  const bool pressed = pairingButtonPressed();
  if (pressed != buttonWasPressed &&
      static_cast<uint32_t>(now - lastButtonChangeMs) >=
          kPairingButtonDebounceMs) {
    buttonWasPressed = pressed;
    lastButtonChangeMs = now;
    if (pressed) {
      buttonPressedAtMs = now;
      buttonPairingOpened = false;
      buttonClearTaken = false;
    } else {
      buttonPairingOpened = false;
      buttonClearTaken = false;
    }
  }

  if (!buttonWasPressed) {
    return;
  }
  const uint32_t heldMs = now - buttonPressedAtMs;
  if (heldMs >= kClearBondsHoldMs && !buttonClearTaken) {
    disconnectActiveHost();
    settings.clearTrustedHosts();
    Bluefruit.Periph.clearBonds();
    setPairingWindow(kPairingWindowMs);
    buttonClearTaken = true;
    Serial.println("[security] Trusted hosts and bonds cleared");
  } else if (heldMs >= kOpenPairingHoldMs && !buttonPairingOpened) {
    setPairingWindow(kPairingWindowMs);
    buttonPairingOpened = true;
  }
}

void serviceSerialConsole() {
  if (!Serial.available()) {
    return;
  }
  String command = Serial.readStringUntil('\n');
  command.trim();
  if (command == "pair") {
    setPairingWindow(kPairingWindowMs);
  } else if (command == "clear") {
    disconnectActiveHost();
    settings.clearTrustedHosts();
    Bluefruit.Periph.clearBonds();
    setPairingWindow(kPairingWindowMs);
    Serial.println("[security] Trusted hosts and bonds cleared");
  } else if (command == "tare") {
    if (sensorInitialized &&
        bno085.enableReport(SH2_GAME_ROTATION_VECTOR,
                            activeConnectionHandle == BLE_CONN_HANDLE_INVALID
                                ? kIdleReportIntervalUs
                                : kConnectedReportIntervalUs)) {
      Serial.println("[sensor] Stream restarted; use host-side recenter for 3DoF");
    }
  } else if (command == "status") {
    Serial.print("battery_mV=");
    Serial.print(battery.millivolts());
    Serial.print(" battery_pct=");
    Serial.print(battery.percent());
    Serial.print(" sensor=");
    Serial.print(static_cast<uint8_t>(sensorState));
    Serial.print(" hosts=");
    Serial.println(settings.trustedHostCount());
  }
}

}  // namespace

void setup() {
  Serial.begin(115200);

  if (kPairingButtonEnabled) {
    pinMode(kPairingButtonPin,
            kPairingButtonActiveLow ? INPUT_PULLUP : INPUT_PULLDOWN);
    delay(kDfuBootButtonSampleMs);
    dfuMode = kBleDfuSupported && pairingButtonPressed();
  }

  if (kBrightnessOutputEnabled) {
    pinMode(kBrightnessPwmPin, OUTPUT);
    analogWriteResolution(8);
  }

  settings.begin();
  brightnessPercent = settings.brightness();
  battery.begin();
  if (settings.trustedHostCount() == 0) {
    setPairingWindow(kPairingWindowMs);
  }

  Bluefruit.autoConnLed(false);
  Bluefruit.configPrphBandwidth(BANDWIDTH_HIGH);
  Bluefruit.begin(1, 0);
  Bluefruit.setTxPower(kBleTxPowerDbm);
  Bluefruit.setName(kDeviceName);
  Bluefruit.Periph.setConnectCallback(connectCallback);
  Bluefruit.Periph.setDisconnectCallback(disconnectCallback);
  Bluefruit.Periph.setConnInterval(kConnectionIntervalMin,
                                   kConnectionIntervalMax);
  Bluefruit.Periph.setConnSlaveLatency(kConnectionSlaveLatency);
  Bluefruit.Periph.setConnSupervisionTimeoutMS(
      kConnectionSupervisionTimeoutMs);
  Bluefruit.Security.setIOCaps(false, false, false);
  Bluefruit.Security.setMITM(false);
  Bluefruit.Security.setPairCompleteCallback(pairingCompleteCallback);
  Bluefruit.Security.setSecuredCallback(securedCallback);

  configureGatt();
  applyBrightness(brightnessPercent);
  initializeSensor();
  updateStatus(true);
  startAdvertising();

  Serial.println("YUNSH V1 (Glasses) ready");
  Serial.println("Console: status | pair | clear | tare");
}

void loop() {
  const uint32_t now = millis();
  serviceSensor();
  servicePairingButton();
  serviceSerialConsole();

  if (battery.poll(now)) {
    updateStatus(true);
  } else {
    updateStatus(false);
  }
  settings.flushIfDue(now);
  delay(1);
}
