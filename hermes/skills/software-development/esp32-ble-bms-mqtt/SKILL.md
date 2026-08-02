---
name: esp32-ble-bms-mqtt
description: BLE BMS (BDRG/JK/JBD) → MQTT Bridge auf ESP32, ESP32-C3, ESP32-C6 mit PlatformIO
---

# ESP32 BLE BMS → MQTT Bridge

## Hardware

| Board | RAM | BLE+WiFi | Hinweis |
|-------|-----|----------|---------|
| ESP32 (klassisch) | 520KB | ✅ stabil | Empfohlen für BLE + WiFi + MQTT |
| XIAO ESP32C6 | 512KB (320KB frei) | ⚠️ | Braucht NimBLE-Arduino |
| ESP32-C3 Super Mini | 400KB (320KB frei) | ❌ | Zu wenig RAM für BLE+WiFi+MQTT |

## BMS-Protokoll

BDRG BMS (Modell BDRG12100) nutzt **JK-Protokoll** (Service 0xFFE0, Char 0xFFE1), **nicht** JBD/NUS.

| BMS-Typ | Service | Protokoll | Erkennung |
|---------|---------|-----------|-----------|
| JK / BDRG | 0xFFE0 | JK | Name "JK-BMS", "R-12100BNN...", "BDRG..." |
| JBD / Xiaoxiang | NUS (6E40...) | JBD Request/Response | Name "JBD", "Xiaoxiang", "LltJbd" |

## PlatformIO Setup

Auf Nix-basierten Systemen: PlatformIO in venv statt Nix-Paket (Nix Python blockiert pip).

```bash
python3.11 -m venv ~/.pio_venv
~/.pio_venv/bin/pip install platformio esptool
```

Builder patchen (1x):
```python
# ~/.platformio/platforms/espressif32@*/builder/main.py
OBJCOPY='/Users/<user>/.pio_venv/bin/esptool'
UPLOADER='/Users/<user>/.pio_venv/bin/esptool'
```

## BLE-Bibliothek

| Board | Lib | Include |
|-------|-----|---------|
| ESP32 (klassisch) | Standard BLEDevice | `#include <BLEDevice.h>` |
| XIAO ESP32C6 / C3 | NimBLE-Arduino | `#include <NimBLEDevice.h>` |

**NimBLE-Arduino API-Unterschiede:**
- `NimBLEAddress()` statt `BLEAddress("")`
- `NimBLEDevice::init()` statt `BLEDevice::init()`
- `NimBLEClient::createClient()` statt `BLEDevice::createClient()`
- `scan->start(3, false)` → `NimBLEDevice::getScanResults()` (Rückgabetyp anders)
- `_char->subscribe(true, callback)` statt `registerForNotify()`
- Results: `const NimBLEAdvertisedDevice*` statt Wert-Typ

## JK BMS Protokoll

- BLE verbinden → Service 0xFFE0 → Char 0xFFE1 (notify)
- BMS sendet periodisch Notifications (kein Request nötig)
- Frame-Header: 0x55 0xAA oder 0xAA 0x55
- Frame: Header(2) + Length(2) + RecordType(1) + Payload + CRC16(2)
- Record 0x01: Basis-Daten (Spannung, Strom, SOC, Kapazität, Temp)
- Record 0x02: Zellspannungen
- Record 0x03: Status/Error Flags

## Fallstricke

- ESP32-C3: BLE-Init crasht bei <50KB freiem Heap → WiFi vor BLE oder BLE vor WiFi initialisieren
- C3 native USB: Port-Open triggert Download-Mode → `tty.*` statt `cu.*` oder DTR blocken
- XIAO ESP32C6: LED auf GPIO15 (aktiv HIGH), nicht GPIO2
- BDRG BLE-Name: "R-12100BNNH19-C01278" (mit R- Präfix)
- MQTT retained messages: bei Neustarts alte "connected"-Nachricht nicht löschen