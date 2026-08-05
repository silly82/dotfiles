---
name: pico-sdk-development
category: software-development
description: Raspberry Pi Pico SDK (RP2040/RP2350) firmware development on macOS — cross-compile, flash, debug.
tags: [pico, rp2040, rp2350, pico-sdk, cmake, arm, embedded, firmware, waveshare]
triggers: [rp2350, pico 2, pico-sdk, picotool, .uf2, pico_board, waveshare, ft6336u, epd_1in54_v2]
---

# Pico SDK Development (RP2040 / RP2350)

Cross-compile, flash, and debug RP2040 (Pico 1) and RP2350 (Pico 2) firmware on macOS.

## Prerequisites

Use **nix shell** to get the toolchain — no brew install needed:

```bash
# Cross-compiler (ARM Cortex-M) + cmake
nix shell nixpkgs#gcc-arm-embedded nixpkgs#cmake

# Pico SDK 2.x (einmalig holen — 2.2.0+ recommended for RP2350!)
git clone --depth 1 --branch 2.2.0 https://github.com/raspberrypi/pico-sdk.git
cd pico-sdk && git submodule update --init
```

> **⚠️ SDK 2.0.0 bootet NICHT auf RP2350!**  
> Pico SDK 2.0.0 erzeugt .uf2-Dateien die vom RP2350 zwar akzeptiert werden (Bootloader schreibt sie), aber die Firmware startet nicht – keine LED, kein Serial, nichts.  
> **Mindestens SDK 2.2.0 verwenden** (oder neuer). Waveshare verwendet SDK 2.2.0 für ihre RP2350-Boards.  
> Symptom: Laufwerk verschwindet nach Flash, aber Code läuft nicht. Einziger Hinweis: keine LED.

## Quickstart Build (nix shell on macOS)

```bash
# 1. SDK 2.2.0+ (2.0.0 bootet NICHT auf RP2350!)
git clone --depth 1 --branch 2.2.0 https://github.com/raspberrypi/pico-sdk.git
cd pico-sdk && git submodule update --init
cd ..

# 2. Build script (avoid multiline issues in nix shell)
cat > build.sh << 'SCRIPT'
#!/usr/bin/env bash
set -e
export PICO_SDK_PATH=/tmp/pico-sdk
export CMAKE_POLICY_VERSION_MINIMUM=3.5
cd /path/to/LarsMiniTouch
mkdir -p build && cd build
cmake -DPICO_SDK_PATH=$PICO_SDK_PATH -DPICO_BOARD=pico2 -DCMAKE_BUILD_TYPE=Debug ..
make -j4
SCRIPT

chmod +x build.sh
nix shell nixpkgs#cmake nixpkgs#gcc-arm-embedded -c ./build.sh
```

## Project Setup

```bash
mkdir my-project && cd my-project
```

### CMakeLists.txt

```cmake
cmake_minimum_required(VERSION 3.20)
include(pico_sdk_import.cmake)
project(my-project C CXX ASM)
set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 17)

# RP2350 (Pico 2) = pico2, RP2040 (Pico 1) = pico
set(PICO_BOARD pico2 CACHE STRING "Pico board variant")

pico_sdk_init()

add_executable(my-project src/main.c ...)
target_link_libraries(my-project PRIVATE pico_stdlib hardware_spi hardware_gpio)
pico_add_extra_outputs(my-project)
pico_enable_stdio_usb(my-project 1)
pico_enable_stdio_uart(my-project 1)
```

Include `pico_sdk_import.cmake` from the SDK:
```bash
curl -sL https://raw.githubusercontent.com/raspberrypi/pico-sdk/2.2.0/external/pico_sdk_import.cmake > pico_sdk_import.cmake
```

## Build

```bash
export PICO_SDK_PATH=/path/to/pico-sdk

# In nix shell:
cmake -B build -DPICO_SDK_PATH=$PICO_SDK_PATH -DPICO_BOARD=pico2 -DCMAKE_BUILD_TYPE=Debug -DCMAKE_POLICY_VERSION_MINIMUM=3.5 ..
cmake --build build -j4
```

Output: `build/my-project.uf2` + `build/my-project.elf`

## Flash

1. Pico 2 in Bootloader: **BOOTSEL-Taste gedrückt halten → USB einstecken → loslassen**
2. Laufwerk `RP2350` (Pico 2) oder `RPI-RP2` (Pico 1) erscheint
3. UF2 kopieren:
   ```bash
   cp build/my-project.uf2 /Volumes/RP2350/
   ```
4. Laufwerk verschwindet automatisch → Firmware läuft

## Pico 2 (RP2350) specifics

| Property | Value |
|----------|-------|
| Board name | `pico2` |
| Family ID | `0xe48bff57` (ARM) / `0xe48bff58` (RISC-V) |
| Flash size | 4 MB (default), 16 MB (Waveshare board) |
| Core | ARM Cortex-M33 dual-core |
| XIP base | `0x10000000` |
| **Min. SDK** | **2.2.0** (2.0.0 bootet nicht!) |

## Troubleshooting

### Firmware bootet nicht (LED blinkt nicht, kein Serial)

**Häufigste Ursache: SDK-Version zu alt!**

Symptom:
1. UF2 wird vom Bootloader akzeptiert (Laufwerk verschwindet)
2. Aber keine LED, kein Serial, nichts
3. Board scheint tot – aber Bootloader kommt beim nächsten BOOTSEL+Reset wieder

→ **Fix: Pico SDK auf 2.2.0+ upgraden.**  
SDK 2.0.0 erzeugt UF2-Dateien die der RP2350 nicht booten kann, obwohl sie vom Bootloader akzeptiert werden.

**Minimal-Test (ohne Peripherie):**
```c
#include "pico/stdlib.h"
int main() {
    gpio_init(PICO_DEFAULT_LED_PIN);
    gpio_set_dir(PICO_DEFAULT_LED_PIN, GPIO_OUT);
    while (1) {
        gpio_put(PICO_DEFAULT_LED_PIN, 0); // an
        sleep_ms(200);
        gpio_put(PICO_DEFAULT_LED_PIN, 1); // aus
        sleep_ms(200);
    }
}
```
→ LED blinkt → Chip läuft, Problem liegt im Peripherie-Code.  
→ LED blinkt nicht → Chip bootet nicht (SDK-Version prüfen!).

**Boot-Ablauf-Diagnose mit LED vor Init:**
```c
gpio_init(PICO_DEFAULT_LED_PIN);
gpio_set_dir(PICO_DEFAULT_LED_PIN, GPIO_OUT);
for (int i = 0; i < 3; i++) {
    gpio_put(PICO_DEFAULT_LED_PIN, 0); sleep_ms(200);
    gpio_put(PICO_DEFAULT_LED_PIN, 1); sleep_ms(200);
}
// erst dann Hardware-Inits...
```

### Onboard sensors (SHTC3, PCF85063, ES8311)

The Waveshare RP2350 boards have several additional sensors on I2C1 (GP6-7):
- **SHTC3** (temp/humidity, 0x70) — `lib/SHTC3/` in Waveshare LVGL example
- **PCF85063** (RTC, 0x51) — `lib/PCF85063/` in Waveshare LVGL example
- **ES8311** (audio codec, 0x18) — `lib/audio/es8311/` + PIO I2S driver
- **Battery ADC** (GP29, channel 3) — via `hardware/adc.h`

See `references/epaper-touch-drivers.md` for full API and integration notes.

### Waveshare RP2350-Touch-ePaper-1.54

This board has **different wiring than a generic Pico 2 + ePaper module**:

- **SPI1** (GP9-11), not SPI0 (GP16-19)
- **Touch is FT6336U on I2C1** (GP6-7), not XPT2046 on SPI
- **PWR pin (GP13)** must be driven HIGH for display power
- Use Waveshare's own `EPD_1in54_V2` driver (not raw SSD1681)
- See `references/epaper-touch-drivers.md` for full pinout, code, and pitfalls

### UF2 kopiert, Laufwerk verschwindet, aber kein Serial

→ **Firmware hängt in Initialisierung.** Typische Ursachen:

- **ePaper BUSY-Pin wartet ewig** – `epd_wait_idle()` hängt wenn Display anders/nicht angeschlossen. Timeout einbauen!
- **SPI-Init schlägt fehl** – falsche GPIOs im Pinout.
- **TinyUSB braucht ms** – Serial kommt erst nach 1-2s.

**Minimal-Test ohne Peripherie:**
```c
#include "pico/stdlib.h"
int main() {
    stdio_init_all();
    gpio_init(PICO_DEFAULT_LED_PIN);
    gpio_set_dir(PICO_DEFAULT_LED_PIN, GPIO_OUT);
    while (1) {
        gpio_put(PICO_DEFAULT_LED_PIN, 1);
        sleep_ms(500);
        gpio_put(PICO_DEFAULT_LED_PIN, 0);
        sleep_ms(500);
        printf("LED blinks\n");
    }
}
```

**LED-Blink vor Display-Init (Debugging):**
Wenn das Display nicht reagiert, LED blinken lassen **bevor** die Hardware-Init läuft, um zu sehen ob der Chip überhaupt bootet:
```c
gpio_init(PICO_DEFAULT_LED_PIN);
gpio_set_dir(PICO_DEFAULT_LED_PIN, GPIO_OUT);
for (int i = 0; i < 3; i++) {
    gpio_put(PICO_DEFAULT_LED_PIN, 0); sleep_ms(200);
    gpio_put(PICO_DEFAULT_LED_PIN, 1); sleep_ms(200);
}
```
→ LED blinkt 3× → Chip läuft, Problem liegt im Peripherie-Code.
→ LED blinkt nicht → Chip bootet nicht (UF2 falsch, Bootloader-Problem).

### `cp: could not copy extended attributes`

→ Die Datei wurde trotzdem kopiert. Das Laufwerk ist FAT16 — extended attributes werden nicht unterstützt. Ignorieren.

### Build Error: `CMAKE_POLICY_VERSION_MINIMUM`

```bash
export CMAKE_POLICY_VERSION_MINIMUM=3.5
cmake -B build ...
```

### Kein `arm-none-eabi-gcc` in nix shell

```bash
# Nach nix shell nixpkgs#gcc-arm-embedded die Binaries finden:
ls $(nix build nixpkgs#gcc-arm-embedded --print-out-paths 2>/dev/null)/bin/
```

## Verzeichnisstruktur (empfohlen)

```
my-project/
├── CMakeLists.txt
├── pico_sdk_import.cmake
├── pico_post_init.cmake    # Optional: pico_set_flash_size(...)
├── .gitignore
├── README.md
└── src/
    ├── main.c
    ├── drivers/     # Display, Touch, Sensoren, etc.
    │   ├── epaper/
    │   └── touch/
    └── fonts/       # Bitmap-Fonts
```