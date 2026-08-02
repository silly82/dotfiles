---
name: pico-sdk
description: Set up and build Raspberry Pi Pico SDK 2.x (RP2040/RP2350) C/C++ projects — CMake, cross-compilation, flashing, and common peripheral drivers.
---

# Pico SDK Project Setup

Build RP2040/RP2350 embedded firmware on macOS using Pico SDK 2.x.

## Prerequisites (macOS)

```bash
# Cross-compiler (ARM only — the nixpkgs gcc-arm-embedded doesn't support RISC-V)
nix shell nixpkgs#gcc-arm-embedded -c 'echo ready'

# Or via brew (no bottle for arm64 macOS — build from source)
brew install --build-from-source arm-none-eabi-gcc

# cmake + ninja
nix shell nixpkgs#cmake nixpkgs#ninja -c 'echo ready'
```

Avoid CMake policy errors with Pico SDK subprojects (mbedtls):
```bash
export CMAKE_POLICY_VERSION_MINIMUM=3.5
```

## Project Template

Minimal `CMakeLists.txt` for RP2350 (Pico 2, ARM Cortex-M33):

```cmake
cmake_minimum_required(VERSION 3.20)
include(pico_sdk_import.cmake)
project(MyProject C CXX ASM)
set(PICO_BOARD pico2)              # pico2 = ARM, pico2_riscv = RISC-V
pico_sdk_init()
add_executable(MyProject src/main.c)
target_link_libraries(MyProject PRIVATE pico_stdlib hardware_spi hardware_gpio)
pico_add_extra_outputs(MyProject)
pico_enable_stdio_usb(MyProject 1)
pico_enable_stdio_uart(MyProject 1)
```

Flash size override in `pico_post_init.cmake`:
```cmake
pico_set_flash_size(MyProject 4M)
```

## Build

```bash
mkdir build && cd build
cmake -DPICO_SDK_PATH=/path/to/pico-sdk -DPICO_BOARD=pico2 ..
make -j4
# → build/MyProject.uf2  (72-200 KB depending on features)
```

With nix on macOS (one-liner):
```bash
nix shell nixpkgs#cmake nixpkgs#gcc-arm-embedded -c \
  sh -c 'export CMAKE_POLICY_VERSION_MINIMUM=3.5; cmake -B build -DPICO_SDK_PATH=/tmp/pico-sdk && make -C build -j4'
```

## Pico SDK Include Layout

Key directories when SDK is at `$PICO_SDK_PATH`:
```
$PICO_SDK_PATH/src/common/pico_stdlib_headers/include  → pico/stdlib.h
$PICO_SDK_PATH/src/rp2_common/hardware_spi/include     → hardware/spi.h
$PICO_SDK_PATH/src/rp2040/hardware_regs/include        → hardware/regs/* (RP2040)
$PICO_SDK_PATH/src/rp2350/hardware_regs/include        → RP2350 register defs
$PICO_SDK_PATH/src/boards/include                      → boards/pico.h etc.
```

Generated headers (created by cmake configure):
- `pico/version.h` — SDK version macros
- `pico/config.h` — board-specific config
- Include via `-I$BUILD_DIR/generated/pico_base`

## Flashing (UF2)

1. Hold BOOTSEL button on Pico 2, connect USB
2. Release BOOTSEL — appears as `RPI-RP2` mass storage
3. Copy `.uf2` file to the device
4. Device auto-ejects and reboots

Alternative: `picotool` (from Pico SDK extras):
```bash
picotool load -f build/MyProject.uf2
picotool reboot
```

## Board Variants

| Board         | PICO_BOARD    | CPU                       | Notes                  |
|---------------|---------------|---------------------------|------------------------|
| Pico 1        | pico          | RP2040, Cortex-M0+        | Original, 264KB SRAM   |
| Pico 2        | pico2         | RP2350, Cortex-M33        | Dual-core, 520KB SRAM  |
| Pico 2 RISC-V | pico2_riscv   | RP2350, Hazard3 (RISC-V)  | Same chip, different ISA |

## Peripheral Drivers (common)

### SSD1681 ePaper (200×200, 1.54", SPI)
- B/W 1bpp framebuffer (200×200/8 = 5000 bytes)
- Full refresh only (partial refresh not implemented here)
- Commands: SW_RESET(0x12), DRIVER_OUTPUT_CONTROL(0x01), DATA_ENTRY_MODE(0x11), WRITE_RAM_BW(0x24), MASTER_ACTIVATION(0x20)
- Pinout: BUSY, RST, DC, CS, SCK, MOSI (all on same SPI)

### XPT2046 Touch Controller (SPI, 12-bit ADC)
- Commands: X=0xD0, Y=0x90 (differential mode)
- 4-sample averaging discarding worst outlier
- Calibration: x_min/x_max, y_min/y_max, swap_xy, invert_x, invert_y
- IRQ pin (active-low) for touch detection

### 8×12 Monospace Bitmap Font
- ASCII 0x20–0x7E (95 glyphs), 12 bytes/glyph
- MSB = leftmost pixel, 1 = black
- Storage: 1140 bytes in flash

## Pitfalls

- **Pico SDK on macOS**: cmake 4.x breaks mbedtls subproject — set `CMAKE_POLICY_VERSION_MINIMUM=3.5` env var
- **gcc-arm-embedded via nix**: no RISC-V support — use `-mcpu=cortex-m33` for ARM mode only
- **brew arm-none-eabi-gcc**: no bottle for aarch64-darwin — must `--build-from-source` (slow, ~30min)
- **pico/stdlib.h includes generated headers**: `pico/version.h` and `pico/config.h` are created during cmake configure — manual syntax checking requires generating them first
- **Flash size**: default is 2MB — override with `pico_set_flash_size` for larger binaries

## References

- `references/pico-sdk-build-macos.md` — full nix-based build recipe for macOS

<!-- Use delegate_task for large build verification; keep main turn for code authoring -->