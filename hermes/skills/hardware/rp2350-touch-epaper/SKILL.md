---
name: rp2350-touch-epaper
description: >-
  Build, flash, and debug C/C++ firmware for the Waveshare RP2350-Touch-ePaper-1.54
  board (RP2350 + 1.54" ePaper + FT6336U capacitive touch).
  Covers Pico SDK project setup, correct pinout, I2C touch, and macOS+nix cross-compilation.
---

# RP2350 / Waveshare Touch ePaper 1.54

## Board Overview

- **MCU:** RP2350A (dual-core ARM Cortex-M33 or RISC-V Hazard3)
- **Display:** 1.54" ePaper, 200×200, SSD1681 driver (EPD_1in54_V2)
- **Touch:** FT6336U capacitive touch controller via I2C
- **Flash:** 16MB NOR-Flash
- **LED:** Onboard green LED on GP25 (active low)

## Critical Pinout (Waveshare RP2350-Touch-ePaper-1.54)

| Function | GPIO | Notes |
|----------|------|-------|
| **EPD_CS**  | GP9  | SPI1 chip select |
| **EPD_SCLK** | GP10 | SPI1 SCK |
| **EPD_MOSI** | GP11 | SPI1 TX |
| **EPD_DC**   | GP12 | Data/Command |
| **EPD_PWR**  | GP13 | Display power (0=ON, 1=OFF) |
| **EPD_RST**  | GP14 | Reset |
| **EPD_BUSY** | GP15 | Busy (1=busy, 0=idle) |
| **Touch_INT** | GP8  | Touch IRQ (active low) |
| **Touch_RST** | GP16 | Touch reset |
| **I2C SDA**  | GP6  | I2C1 data |
| **I2C SCL**  | GP7  | I2C1 clock |
| **LED**      | GP25 | Onboard green LED (0=ON) |
| **BAT_ADC**  | GP29 | Battery voltage ADC (channel 3) |
| **BAT_EN**   | GP28 | Battery ADC enable |
| **PWR_KEY**  | GP24 | Power button input |

**Display uses SPI1** (not SPI0). Touch uses **I2C1** (not SPI).

## Pico SDK Version

Use **SDK 2.2.0 or later** for RP2350. Earlier versions (2.0.0) may produce
UF2 files that fail to boot on some boards. Waveshare's examples use 2.2.0.

```cmake
# In CMakeLists.txt
set(PICO_BOARD pico2 CACHE STRING "Board type")
include(pico_sdk_import.cmake)
```

## Project Structure

```
project/
├── CMakeLists.txt          # pico2, SDK 2.2.0+
├── pico_sdk_import.cmake   # from SDK
├── pico_post_init.cmake    # optional: pico_set_flash_size(…)
└── src/
    ├── main.c
    ├── epaper/
    │   ├── DEV_Config.{c,h}    # Waveshare: GPIO, SPI1, I2C1, ADC, PWM
    │   ├── Debug.h
    │   └── EPD_1in54_V2.{c,h}  # Waveshare: 1.54" ePaper V2 driver
    └── touch/
        └── FT6336U.{c,h}       # Waveshare: I2C capacitive touch driver
```

Get the Waveshare library files from:
`https://github.com/waveshareteam/RP2350-Touch-ePaper-1.54.git`

Copy from `examples/C/03_GUI/lib/`:
- `Config/DEV_Config.h`, `Config/DEV_Config.c`, `Config/Debug.h`
- `LCD/EPD_1in54_V2.h`, `LCD/EPD_1in54_V2.c`
- From `04_LVGL/lib/Touch/`: `FT6336U.h`, `FT6336U.c`

## CMakeLists.txt Essentials

```cmake
cmake_minimum_required(VERSION 3.20)
include(pico_sdk_import.cmake)
project(myapp C CXX ASM)
set(PICO_BOARD pico2)
pico_sdk_init()

add_executable(myapp
    src/main.c
    src/epaper/DEV_Config.c
    src/epaper/EPD_1in54_V2.c
    src/touch/FT6336U.c
)

target_include_directories(myapp PRIVATE
    src src/epaper src/touch
)

target_link_libraries(myapp PRIVATE
    pico_stdlib hardware_spi hardware_i2c hardware_gpio
    hardware_timer hardware_adc hardware_pwm hardware_clocks
    pico_time pico_printf
)

pico_add_extra_outputs(myapp)
pico_enable_stdio_usb(myapp 1)
pico_enable_stdio_uart(myapp 1)
```

## Flashing

1. Hold **BOOTSEL** + press **Reset** (or plug USB while holding BOOTSEL)
2. Board appears as `RP2350` mass-storage drive
3. Copy `.uf2` file onto the drive
4. Board auto-reboots when copy completes

Alternative: `picotool load -f build/myapp.uf2 && picotool reboot`

## macOS + Nix Cross-Compilation

```bash
# One-time: clone Pico SDK
git clone --depth 1 --branch 2.2.0 https://github.com/raspberrypi/pico-sdk.git
cd pico-sdk && git submodule update --init

# Build
nix shell nixpkgs#cmake nixpkgs#gcc-arm-embedded -c bash -c '
  export PICO_SDK_PATH=/path/to/pico-sdk
  export CMAKE_POLICY_VERSION_MINIMUM=3.5
  cd project && mkdir -p build && cd build
  cmake -DPICO_SDK_PATH=$PICO_SDK_PATH -DPICO_BOARD=pico2 ..
  make -j4
'
```

## ePaper Display Modes

The `EPD_1in54_V2` driver supports two modes:

| Mode | Function | Use Case | Speed |
|------|----------|----------|-------|
| **Full refresh** | `EPD_1IN54_V2_Display()` | Initial full-screen draw | ~2-3s |
| **Partial refresh** | `EPD_1IN54_V2_DisplayPart()` | Touch interaction, fast updates | <1s |

Proper partial refresh workflow:
```c
// 1. Draw full image
memset(fb, 0xFF, img_size);
draw_content(fb);
EPD_1IN54_V2_Display(fb);

// 2. Set as base image for partial mode
EPD_1IN54_V2_DisplayPartBaseImage(fb);

// 3. Switch to partial mode waveform
EPD_1IN54_V2_Init_Partial();

// 4. Subsequent updates use partial refresh
update_content(fb);
EPD_1IN54_V2_DisplayPart(fb);
```

## Onboard Sensors & Peripherals

All drivers from the Waveshare GitHub repo at `examples/C/04_LVGL/lib/`:

| Component | Driver | Interface | Address | Path |
|-----------|--------|-----------|---------|------|
| **FT6336U** Capacitive Touch | `FT6336U.c/.h` | I2C1 (GP6/7) | `0x38` | Touch/ |
| **PCF85063** RTC | `pcf85063.c/.h` | I2C1 | `0x51` | PCF85063/ |
| **SHTC3** Temp/Humidity | `SHTC3.c/.h` | I2C1 | `0x70` | SHTC3/ |
| **ES8311** Audio Codec | `es8311.c/.h` + `audio_pio` | I2C1 + PIO I2S | `0x18` | audio/es8311/ |
| **Battery ADC** | `ADCBattery.c/.h` | ADC (GP29, ch3) | — | battery/ADCBattery/ |

### ES8311 Audio (PIO I2S)

Requires PIO header generation in CMake. Additional `pico_sdk_import.cmake`
links to `hardware_pio` and `hardware_dma`.

```cmake
# Must come before add_library or add_executable
pico_generate_pio_header(myapp ${CMAKE_CURRENT_SOURCE_DIR}/src/audio/audio_pio/audio_pio.pio)

target_link_libraries(myapp PRIVATE
    hardware_pio hardware_dma hardware_i2c
)
```

Files to copy:
- `audio/audio_pio/audio_pio.{c,h,pio}` — PIO state machine for I2S
- `audio/audio_data/audio_data.{c,h}` — audio sample buffer
- `audio/es8311/es8311.{c,h}` — codec driver
- `audio/music.h` — sample audio data

Audio API (from `audio_pio.h`):
- `Sine_440hz_out()` — play 440Hz sine wave
- `Happy_birthday_out()` — play melody
- `Music_out()` — play stored music
- `Loopback_test()` — mic→speaker loopback (needs PIO_DIN pin)

### SHTC3 / PCF85063 Initialisation

```c
#include "pcf85063.h"
#include "SHTC3.h"

pcf85063_init();
struct tm t;
pcf85063_get_time(&t);   // UTC time
printf("%02d:%02d:%02d\n", t.tm_hour, t.tm_min, t.tm_sec);

SHTC3_Init();
float temp, hum;
SHTC3_Measurement(&temp, &hum);  // blocks ~50ms
```

### Battery ADC

```c
#include "ADCBattery.h"
battery_init();
float voltage;
uint16_t adc_raw;
battery_read(&voltage, &adc_raw);   // voltage in V
```

## Build Script (macOS + Nix)

```bash
#!/usr/bin/env bash
set -e
export PICO_SDK_PATH=/tmp/pico-sdk
export CMAKE_POLICY_VERSION_MINIMUM=3.5
export PATH="/nix/store/…-gcc-arm-embedded-15.2.rel1/bin:$PATH"
cd /path/to/project
mkdir -p build && cd build
cmake -DPICO_SDK_PATH=$PICO_SDK_PATH -DPICO_BOARD=pico2 ..
make -j4
```

Run via: `nix shell nixpkgs#cmake nixpkgs#gcc-arm-embedded -c /path/to/build.sh`

## Pitfalls

- **Wrong pinout is the #1 issue.** The Waveshare board does NOT use the
  default Pico 2 pinout. Always refer to `DEV_Config.h` for the actual
  pins.
- **SDK 2.0.0 may produce non-booting UF2** on some RP2350 boards.
  Use SDK 2.2.0+. The board's ROM bootloader writes the UF2 but the
  stage2/ARM firmware doesn't start. Symptoms: drive disappears after
  flash but LED never blinks, no serial output.
- **ePaper retains image** after power-off. If the display shows old
  content, the firmware might be running but the display update failed.
  Add LED blink early in `main()` to verify the chip actually runs
  your code.
- **FT6336U is I2C, not SPI.** Do not use an XPT2046 driver.
  I2C address: `0x38`.
- **GP25 LED is active low** (0 = ON, 1 = OFF).
- **Display power (GP13) must be set LOW** (0) to enable the display.
  This is done in `DEV_GPIO_Init()` → `DEV_LCD_Power_GPIO_Init()`.
- The `CMAKE_POLICY_VERSION_MINIMUM=3.5` env var is needed when
  building with CMake ≥4.0 on macOS to avoid mbedtls compat errors.
- **Flash size:** Waveshare board has 16MB, not 4MB like a standard Pico 2.
  Set `pico_set_flash_size(target 16M)` in CMakeLists.txt or a post-init
  cmake file.
- **PIO .pio file required** even if `audio_pio.pio.h` is present. The
  cmake `pico_generate_pio_header()` step needs the `.pio` source to
  pass to `pioasm`. Without it the build fails with:
  `No rule to make target 'audio_pio.pio'`.