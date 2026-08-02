# PlatformIO + Nix Troubleshooting

## Problem

Auf NixOS/nix-darwin läuft PlatformIO mit dem Nix-eigenem Python.  
`esptool` (Python-Paket) benötigt `rich_click`, das in Nix-Python nicht per `pip` installiert werden kann (externally managed / PEP 668).

Zusätzlich versucht PlatformIO v6 das `tool-esptoolpy`-Paket per `uv pip install` in den Nix-Python zu installieren, scheitert, und hinterlässt einen korrupten Python-Zustand.

## Symptom

```
Fatal Python error: init_sys_streams: can't initialize sys standard streams
ImportError: cannot import name 'text_encoding' from 'io'
*** [.pio/build/esp32dev/bootloader.bin] Error 1
```

Oder beim Upload:

```
esptool: error: argument --before: invalid choice: 'default-reset'
```

## Lösung: Sauberes venv (funktioniert zuverlässig)

```bash
# 1. venv mit Python 3.11+ anlegen
python3.11 -m venv ~/.pio_venv

# 2. platformio + esptool in die venv installieren
~/.pio_venv/bin/pip install platformio esptool

# 3. pio über venv-Pfad nutzen
~/.pio_venv/bin/pio run
~/.pio_venv/bin/pio run -t upload --upload-port /dev/cu.usbserial-10
```

### Builder main.py patchen

Der Espressif32-Plattform-Builder setzt `OBJCOPY='esptool'` (bare command).  
Die venv-esptool findet PIO nicht automatisch → Pfad hardcoden:

**Datei:** `~/.platformio/platforms/espressif32@<hash>/builder/main.py`

```python
# Zeile ~701
OBJCOPY='/Users/<user>/.pio_venv/bin/esptool',
```

Gleiches für Upload (Zeile ~964):

```python
UPLOADER='/Users/<user>/.pio_venv/bin/esptool',
```

**Wichtig:** Beim Patchen auch die `--before`/`--after`-Flags von v4- auf v5-Syntax ändern, sonst erscheint `error: argument --before: invalid choice: 'default-reset'`:

```python
# --before Wert (Zeile ~975)
board.get("upload.before_reset", "default_reset"),   # statt "default-reset"
# --after Wert (Zeile ~977)
board.get("upload.after_reset", "hard_reset"),       # statt "hard-reset"
```

### esptool v5 Flag-Änderungen

In esptool v5 wurden `--before`/`--after`-Werte von Underscore auf Dash geändert:

| v4 | v5 | deprecated seit |
|----|----|-----------------|
| `--before default_reset` | `--before default-reset` | v5.0 |
| `--after hard_reset` | `--after hard-reset` | v5.0 |

Der Builder verwendet noch die v4-Namen → bei Patch gleich auf v5 ändern, sonst `error: argument --before: invalid choice: 'default-reset'`.

### extra_scripts Alternative

Statt dem Builder-Patch kann auch ein SCons-Script (extra_scripts) das Problem lösen:

```python
# fix_esptool.py – env.Replace(OBJCOPY=...) und subprocess.run()
Import("env")
env.Replace(OBJCOPY="/Users/<user>/.pio_venv/bin/esptool")
```

Dann in `platformio.ini`:
```ini
extra_scripts = pre:fix_esptool.py
```

Nachteil: Nur Build, nicht Upload – dafür ist der Builder-Patch nötig.

### partition huge_app

BLE + WiFi + ArduinoJson + PubSubClient → Firmware >1.3MB (Standard-Partition).  
In `platformio.ini`:

```ini
board_build.partitions = huge_app   # 3MB für App
```

## ESP32-C3 / riscv32

Anders als ESP32 (Xtensa) nutzt der C3 einen **RISC-V-Kern**.

### Serial DTR-Falle (natives USB)

ESP32-C3 mit nativem USB triggert beim Öffnen von `/dev/cu.usbmodem*` einen **DTR-Impuls**, der den Chip sofort in **Download-Mode** (`boot:0x7`) versetzt. Jeder Serial-Port-Open = Hardware-Reset + Download-Warten.

**Workarounds:**
1. Nach dem Flashen den Port nicht direkt öffnen – MQTT-Retained-Nachrichten als Debug-Kanal nutzen
2. `/dev/tty.usbmodem*` statt `cu.` verwenden (tty-Device hat weniger DTR-Effekte, aber Garantie gibt's keine)
3. Upload macht Hard-Reset → **5-10s warten** vor dem Serial-Open
4. Für richtiges Serial-Debugging: `pio device monitor` oder `screen` starten VOR dem USB-Einstecken

### PubSubClient RAM auf C3

PubSubClient default Buffer (256+ Bytes) kann den C3 überlasten. Buffer explizit verkleinern:

```cpp
WiFiClient wc;
PubSubClient mqtt(wc);
mqtt.setBufferSize(128);  // Minimum für MQTT-Connect + Publish
```

### MQTT Retained-Trap

MQTT-`connected`-Nachrichten werden mit `retain=true` gepublished. Nach einem ESP-Crash bleibt die alte "online"-Nachricht beim Broker erhalten – beim Debuggen täuscht sie einen laufenden ESP vor.

**Lösungen:**
- `retain=false` für Status-Nachrichten verwenden (nur `publishRaw` ohne retain)
- LWT (Last Will Testament) setzen: `mqtt.connect("id", "user", "pass", "bms/bdrg/connected", 1, true, "offline")`
- Beim MQTT-Subscribe immer prüfen, ob die Nachricht retained ist (`msg.retain`)

### platformio.ini für C3

```ini
[env:esp32-c3-devkitm-1]
platform = espressif32
board = esp32-c3-devkitm-1
framework = arduino
monitor_speed = 115200
board_build.mcu = esp32c3
board_build.flash_mode = dio
board_build.f_cpu = 160000000L       # C3: 160MHz statt 240MHz

lib_deps =
    bblanchon/ArduinoJson @ ^7.0.0
    knolleary/PubSubClient @ ^2.8

board_build.partitions = huge_app.csv  # 3MB App-Partition
```

### Upload-Port

C3 hat **natives USB** (USB-Serial-JTAG) → `/dev/cu.usbmodem*` (nicht `usbserial`).  
Kein CH340/CP2102 nötig – DTR/RTS läuft über USB-Serial-JTAG-Protokoll.

```bash
# Port erkennen
ls /dev/cu.usbmodem*  # C3 native USB
```

### Toolchain

Wird automatisch von PlatformIO gewählt (riscv32-esp-elf statt xtensa-esp-32-elf).  
Der Builder-Patch für `OBJCOPY`/`UPLOADER` funktioniert gleich – die venv-esptool ist chip-unabhängig.

### Partition

C3 mit 4MB Flash: `huge_app` gibt 3MB App-Partition (wie ESP32).  
Standard-Partition wäre zu klein für BLE + WiFi + ArduinoJson + PubSubClient.

CH340  → `/dev/cu.usbserial-*`  
CP2102 → `/dev/cu.SLAB_USBtoUART*`  
FT232  → `/dev/cu.usbserial-*` (abweichender Treiber)

```bash
ls -la /dev/cu.* /dev/tty.* | grep -i "usb\\|serial"
```

## CH340 Upload-Probleme

Bei CH340 oft Verbindungsprobleme mit 921600 Baud. Lösung:

```ini
upload_speed = 115200
```

in `platformio.ini`. Oder manuell:

```bash
~/.pio_venv/bin/esptool --chip esp32 --port /dev/cu.usbserial-10 \
  --baud 115200 --before default-reset write-flash -z \
  0x10000 .pio/build/esp32dev/firmware.bin
```