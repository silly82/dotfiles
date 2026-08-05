# ESP32 BLE→MQTT Bridge Template

## Minimales PlatformIO Projekt

```
project/
├── platformio.ini
├── src/
│   └── main.cpp          ← Kopie von esp32_jbd_ble_mqtt.ino
```

### platformio.ini

```ini
[env:esp32dev]
platform = espressif32
board = esp32dev
framework = arduino
monitor_speed = 115200

lib_deps =
    bblanchon/ArduinoJson @ ^7.0.0
    knolleary/PubSubClient @ ^2.8
    h2zero/NimBLE-Arduino @ ^1.4.0
```

## BLE Verbindungsablauf (generisch)

```cpp
// 1. Scanner starten
NimBLEScan* pScan = NimBLEDevice::getScan();
pScan->setActiveScan(true);
std::vector<NimBLEAdvertisedDevice*> devices = pScan->getResults(10);

// 2. BMS nach Name-Pattern finden
// (JBD-*, DL-*, ANT-*, etc. — je nach BMS-Typ)

// 3. Verbinden
NimBLEClient* pClient = NimBLEDevice::createClient();
pClient->connect(targetDevice);

// 4. Service + Charakteristiken finden
NimBLERemoteService* pSvc = pClient->getService("0000ff00-...");
NimBLERemoteCharacteristic* pRx = pSvc->getCharacteristic("0000ff01-...");
NimBLERemoteCharacteristic* pTx = pSvc->getCharacteristic("0000ff02-...");

// 5. Notification registrieren
pRx->subscribe(true, notifyCallback);

// 6. Init senden (falls BMS erforderlich)
pTx->writeValue(initFrame, len, false);

// 7. Daten-Command senden
pTx->writeValue(cmdFrame, len, false);

// 8. Auf Notification warten
// (in notifyCallback: data parsen und JSON bauen)
```

## MQTT JSON Payload (Standardformat)

```json
{
  "voltage": 13.25,
  "current": 5.02,
  "power": 66.5,
  "soc": 78,
  "charge": 98.5,
  "capacity": 120,
  "cycles": 42,
  "temp_count": 2,
  "temperatures": [22.5, 23.1],
  "cells": 4,
  "cell_voltages": [3.312, 3.315, 3.308, 3.310],
  "charging": true,
  "chrg_mosfet": true,
  "dischrg_mosfet": true,
  "max_charge_current": 60.0,
  "max_discharge_current": 60.0
}
```

## Topic-Konvention

```
bms/<hersteller>/data     — Sensordaten
bms/<hersteller>/status   — Online/Offline
bms/<hersteller>/cmd      — Steuerbefehle (optional)
dashboard/bms/<wert>      — Node-RED Dashboard (optional)
```