---
name: esp32-ble-to-mqtt
description: ESP32 BLE-zu-MQTT-Bridge für Sensoren und BMS – PlatformIO, BLE-Scan/Connect, binäre Protokoll-Parser, MQTT-JSON-Publish, Watchdog
tags: [esp32, ble, mqtt, platformio, arduino, iot, jbd-bms]
---

# ESP32 BLE → MQTT Bridge

PlatformIO-Projekt für ESP32, das per BLE Daten von einem Gerät (z.B. BMS) liest und als JSON per MQTT veröffentlicht.

## Projektstruktur

```
project/
├── platformio.ini
├── src/
│   ├── main.cpp              – Setup + Loop
│   ├── config.h              – WiFi, MQTT, BLE-Konfig
│   ├── bms_data.h            – Datenstruktur (Spannung, Strom, SOC, Zellen, Temps)
│   ├── jbd_bms.h / .cpp      – JBD-BLE-Protokoll (NUS)
│   ├── jk_bms.h / .cpp       – JK/BDRG-BLE-Protokoll (0xFFE0)
│   └── mqtt_helper.h/.cpp    – MQTT + JSON-Publish
└── README.md
```

## platformio.ini

```ini
[env:esp32dev]
platform = espressif32
board = esp32dev
framework = arduino
monitor_speed = 115200
board_build.flash_mode = dio
board_build.f_cpu = 240000000L
upload_speed = 115200

lib_deps =
    bblanchon/ArduinoJson @ ^7.0.0
    knolleary/PubSubClient @ ^2.8

board_build.partitions = huge_app   # 3MB App-Partition, nötig bei BLE+WiFi+Json
```

BLE-Bibliothek ist im ESP32-Arduino-Core enthalten (BLEDevice, BLEUtils, BLEClient, BLEAdvertisedDevice) – kein extra lib_dep nötig.

## BLE-Verbindungsablauf

1. `BLEDevice::init("")`
2. `BLEScan` → active scan, 5s, nach Gerätename oder MAC filtern
3. `BLEDevice::createClient()` → `client->connect(address)`
4. `client->getService(SERVICE_UUID)` → `service->getCharacteristic(CHAR_UUID)`
5. `characteristic->registerForNotify(callback)` für asynchrone Daten
6. `characteristic->writeValue(data, len, true)` für Request/Response

### BLE-Scan-Filter

```cpp
BLEScanResults* results = scan->start(5, false);
for (int i = 0; i < results->getCount(); i++) {
    BLEAdvertisedDevice dev = results->getDevice(i);
    String name = dev.haveName() ? String(dev.getName().c_str()) : "";
    if (name.indexOf("JBD") >= 0 || name.indexOf("Xiaoxiang") >= 0) {
        // gefunden
    }
}
```

## Ringpuffer für binäre Protokolle

BLE liefert asynchrone Notifications – Datenpakete können fragmentiert ankommen. Einfacher Ringpuffer:

```cpp
static const int BUFFER_SIZE = 512;
uint8_t buffer[BUFFER_SIZE];
int bufferLen = 0;

void processIncoming(uint8_t* data, size_t len) {
    if (bufferLen + len > BUFFER_SIZE) bufferLen = 0; // overflow
    memcpy(buffer + bufferLen, data, len);
    bufferLen += len;

    // Header suchen, Frame-Grenzen erkennen, Checksum prüfen
    // Komplette Frames aus dem Buffer extrahieren, Rest verschieben
}
```

## MQTT-Publish

- Topic: `prefix/status` (JSON), `prefix/connected` (online/offline)
- JSON: `{voltage, current, power, soc, cells, cell_voltages[...], temperatures[...], charging, discharging, balancer, error_flags}`
- Retained-Flag für Status

## Watchdog

- Timeout (z.B. 60s) ohne erfolgreiche BLE-Daten → disconnect + reconnect
- WiFi/MQTT-Loop in `loop()` per `mqtt.loop()`

## Häufige Fallstricke

- **BLE-Notify-Race**: Nach `registerForNotify` kurz warten (1-2s), bevor erste Anfrage gesendet wird
- **Checksum-Verwirrung**: JBD verwendet CRC8-Summe (Summe aller Bytes), JK verwendet CRC16/XMODEM
- **Temperaturen**: JBD liefert in 0.1K mit Offset 2731 → °C = (raw - 2731) / 10.0
- **BMS-Protokoll erkennen**: Nicht alle BMS nutzen JBD/NUS. BDRG (Modell R-12100BNN…) verwendet **JK-Protokoll** (Service 0xFFE0). Erkennbar an Service UUID im BLE Advertisement: `0xFFE0` = JK, NUS = JBD. Gerätename oft `R-<model>-<serial>`.
- **Firmware zu groß (>1.3MB)**: Standard-Partition gibt nur 1.3MB für App. Mit `board_build.partitions = huge_app` auf 3MB erhöhen
- **PlatformIO + Nix**: Nix-Python kann per `pip` nicht erweitert werden → esptool bricht ab. Siehe `references/platformio-nix-troubleshooting.md`
- **esptool v5 Flags**: `--before default-reset` und `--after hard-reset` (mit Bindestrich) – in v5 sind `default_reset`/`hard_reset` (mit Unterstrich) deprecated. Der Builder in `~/.platformio/platforms/espressif32*/builder/main.py` muss ggf. gepatcht werden. **Wichtig:** Sowohl `OBJCOPY` (Bootloader) als auch `UPLOADER` (Upload) müssen auf den venv-esptool-Pfad zeigen.
- **CH340 Upload-Port**: macOS zeigt CH340 als `/dev/cu.usbserial-10` an. Bei Verbindungsproblemen: `upload_speed = 115200` setzen (921600 ist oft zu schnell für CH340)
- **Builder-Patch für venv-esptool**: In `main.py`:
  - `OBJCOPY='esptool'` → `OBJCOPY='/Users/<user>/.pio_venv/bin/esptool'`
  - `UPLOADER="esptool"` → `UPLOADER="/Users/<user>/.pio_venv/bin/esptool"`
  - `--before default-reset` → `board.get("upload.before_reset", "default_reset")`
  - `--after hard-reset` → `board.get("upload.after_reset", "hard_reset")`
- **ESP32-C3 BLE+WiFi RAM**: C3 hat nur 400KB SRAM. BLE+WiFi gleichzeitig führt zu Abstürzen. Workaround: `BLEDevice::init()` + BMS-Connect VOR WiFi.begin() ausführen. CPU-Freq `160MHz` statt `240MHz`. Native USB = `/dev/cu.usbmodem*` (kein CH340). Toolchain automatisch riscv32. Kein DTR/RTS nötig – `default-reset` funktioniert via USB-Serial-JTAG
- **PubSubClient RAM auf C3**: Buffer von PubSubClient explizit auf 128 Bytes setzen: `mqtt.setBufferSize(128)`. Standard (256+) kann den C3 überlasten.
- **C3 Serial-DTR-Falle**: Auf ESP32-C3 mit nativem USB triggert jeder Serial-Port-Open (`/dev/cu.usbmodem*`) einen DTR-Impuls, der den Chip in **Download-Mode** (`boot:0x7`) versetzt. Nach dem Flashen nie direkt Serial öffnen – besser MQTT-Retained-Nachrichten für Debug nutzen, oder den Port mit `/dev/tty.usbmodem*` (tty-Device, weniger DTR) versuchen.
- **MQTT Retained-Trap**: MQTT-`connected`-Nachrichten werden mit `retain=true` gepublished. Nach einem ESP-Crash bleibt die alte "online"-Nachricht beim Broker erhalten. Beim Debuggen: `retain=false` für Status-Nachrichten oder aktiv auf LWT (Last Will Testament) setzen. Sonst täuscht die alte Nachricht einen laufenden ESP vor.
- **Upload-Port erkennen**: `ls -la /dev/cu.*` – CH340=`usbserial`, native USB=`usbmodem`

## Referenzen

- `references/jbd-bms-protocol.md` – Vollständige JBD-BLE-Protokollbeschreibung
- `references/jk-bms-protocol.md` – JK/BDRG-Protokoll (Service 0xFFE0)
- `references/platformio-nix-troubleshooting.md` – PlattformIO + Nix Python: esptool-Probleme und Workarounds