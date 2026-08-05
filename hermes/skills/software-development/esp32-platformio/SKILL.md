---
name: esp32-platformio
description: ESP32 Entwicklung mit PlatformIO – Setup, Build, Flash, Debug auf macOS mit und ohne Nix
---

# ESP32 + PlatformIO (macOS/Nix)

Builds, flashed, und debuggt ESP32-Firmware mit PlatformIO. Deckt
Nix-Inkompatibilitäten, ESP32-C3-Besonderheiten und BLE-BMS-Protokolle ab.

## Setup

### Neuinstallation (empfohlen: venv)

```bash
python3 -m venv ~/.pio_venv
~/.pio_venv/bin/pip install platformio esptool
~/.pio_venv/bin/pio
```

Alias in `~/.zshrc`:

```bash
alias pio='~/.pio_venv/bin/pio'
```

### Nix (oft problematisch)

Nix PlatformIO (via nix profile oder nix-darwin) installiert esptoolpy korrekt,
scheitert aber am `uv pip install` für Python-Dependencies → PEP 668 blockiert.
**Lösung:** venv nutzen (siehe oben).

## Builder-Patch für esptool

Der PlatformIO Builder für ESP32 (`main.py`) setzt `OBJCOPY='esptool'` und
`UPLOADER='esptool'`. Dadurch wird das interne (kaputte) tool-esptoolpy verwendet.
Patch auf venv-esptool:

```python
# In ~/.platformio/platforms/espressif32@*/builder/main.py:
OBJCOPY='/Users/silvanwalker/.pio_venv/bin/esptool',
...
UPLOADER='/Users/silvanwalker/.pio_venv/bin/esptool',
```

Und `--before`/`--after` Flags für esptool v5 (underscores statt dashes):

```python
board.get("upload.before_reset", "default_reset"),
board.get("upload.after_reset", "hard_reset"),
```

## Partitionen

Bei großen Firmwares (BLE+WiFi+ArduinoJson) das Standard-Partitionsschema
(1.3MB App) sprengen. `huge_app` nutzen (3MB App):

```ini
board_build.partitions = huge_app.csv
```

## ESP32-C3 Besonderheiten

### USB-CDC Serial

ESP32-C3 hat natives USB-CDC (kein CH340). DTR/RTS-Open triggert **Download-Mode**
→ kein normaler Serial-Read möglich. Lösungen:

- **Upload + Read kombinieren:** Während des `pio run -t upload` öffnet der
  Hardware-Reset kurz das USB, danach kann man lesen.
- **Python lesen nach Upload:** `sleep 5; serial.open()` ohne DTR-Toggle.
- **Background Upload:** `terminal(background=True)` → dann serial lesen.

### RAM-Limit (400KB)

ESP32-C3 hat nur 400KB SRAM. BLE + WiFi gleichzeitig überfordert den Chip oft.
Strategien:

- BLE **vor** WiFi initialisieren (mehr RAM verfügbar)
- NimBLE statt Bluedroid: `build_flags = -DCONFIG_BT_NIMBLE_ENABLED=1`
- Minimale Buffer (`BUFFER_SIZE=256` statt 512)
- Wenn beides nicht geht: klassischen ESP32 (520KB RAM) verwenden

### Board-Definitionen

| Board | `board =` | LED |
|-------|-----------|-----|
| ESP32 DevKit | `esp32dev` | GPIO2 (active HIGH) |
| ESP32-C3 Super Mini | `esp32-c3-devkitm-1` | GPIO8 (active LOW) |
| ESP32-C3-DevKit | `esp32-c3-devkitm-1` | GPIO8 |

LED active LOW bei C3 → `digitalWrite(pin, LOW)` = an, `HIGH` = aus.

## BLE BMS Protokolle

### JK BMS (und BDRG-Clones)

Service `0xFFE0`, Characteristic `0xFFE1`. JK sendet periodische Notifications.
BDRG BMS (z.B. BDRG12100) nutzt dasselbe Protokoll.

BLE-Name: `R-12100BNNH19-C01278` oder `JK-BMS*`.

```cpp
BMS_DEVICE_NAME = "R-12100BNNH19-C01278";
// oder MAC-Adresse:
BMS_MAC_ADDRESS = "C8:47:80:70:44:D6";
```

### JBD BMS (Xiaoxiang/Overkill)

Nordic UART Service (NUS) `6e400001-...`, Request/Response-Protokoll.
Commands: `0x03` = Basic Info, `0x04` = Cell Voltages.

## MQTT Pitfalls

- **Retained Messages:** `mqtt.publish(topic, payload, true)` bleibt beim Broker,
  auch wenn der ESP offline ist. Nie auf retained als "ESP lebt"-Indikator
  verlassen. Immer einen frischen unretained Ping/Publish erwarten.
- **Topic-Design:** `bms/<herstelller>/status` für BMS-Daten,
  `bms/<hersteller>/connected` für Status (retained).

## Fehlersuche Serial auf C3

```python
# Nach Upload lesen (während Chip läuft)
import serial, time
ser = serial.Serial()
ser.port = '/dev/cu.usbmodem101'
ser.baudrate = 115200
ser.dtr = False
ser.rts = False
ser.open()
# read...
```

## Projekt-Struktur Template

```
project/
├── platformio.ini       # board, lib_deps, partitions
├── src/
│   ├── main.cpp         # entry point
│   ├── config.h         # WiFi, MQTT, BMS-Konfig
│   ├── bms_data.h       # shared data struct
│   ├── jk_bms.h/.cpp    # JK/BDRG BLE protocol
│   ├── jbd_bms.h/.cpp   # JBD BLE protocol
│   └── mqtt_helper.h/.cpp # MQTT + JSON publish
└── README.md
```

## Pitfalls

- **`BLEDevice::init()` nur einmal aufrufen.** Doppelter Aufruf kann auf C3
  zu Guru Meditation führen.
- **ESP32-C3: BLE+WiFi gleichzeitg oft zu RAM-intensiv.** BLE zuerst init,
  dann WiFi. Oder NimBLE erzwingen.
- **`connectMqtt()` retained Message** → nicht als "ESP läuft" interpretieren.
- **CH340 vs native USB:** `/dev/cu.usbserial-*` = CH340 (externer UART),
  `/dev/cu.usbmodem*` = native USB-CDC (C3/S3/S2).
- **`pio device monitor` crasht auf macOS** mit termios error → stattdessen
  Python-Script oder screen/cu nutzen.