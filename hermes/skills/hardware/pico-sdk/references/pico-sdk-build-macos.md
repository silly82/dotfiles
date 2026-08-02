# Pico SDK Build on macOS with Nix

Full build recipe for LarsMiniTouch (RP2350 + 1.54" touch ePaper).

## One-shot build with nix

```bash
pico_sdk=/tmp/pico-sdk
proj=/Users/silvanwalker/Documents/GitHub/LarsMiniTouch

# Clone SDK once
git clone --depth 1 --branch 2.0.0 https://github.com/raspberrypi/pico-sdk.git "$pico_sdk"
cd "$pico_sdk" && git submodule update --init && cd "$proj"

# Build
export CMAKE_POLICY_VERSION_MINIMUM=3.5
nix shell nixpkgs#cmake nixpkgs#gcc-arm-embedded -c \
  sh -c "cmake -B build -DPICO_SDK_PATH=$pico_sdk -DPICO_BOARD=pico2 .. && make -C build -j4"
```

## Why CMAKE_POLICY_VERSION_MINIMUM

Pico SDK 2.0.0 bundles mbedtls which calls `cmake_minimum_required(VERSION 2.6)` — cmake 4.x rejects this because compatibility with < 3.5 was removed. Setting the env var forces cmake to accept old projects.

## Generated headers for syntax checking

When doing `-fsyntax-only` without a full cmake configure, you need stub generated headers:

```c
// pico/version.h
#define PICO_SDK_VERSION_MAJOR    2
#define PICO_SDK_VERSION_MINOR    0
#define PICO_SDK_VERSION_REVISION 0
#define PICO_SDK_VERSION_STRING   "2.0.0"

// pico/config.h — minimal
#define PICO_STDIO_USB 1
#define PICO_STDIO_UART 1
```

Place them under `<some-dir>/pico/` and add `-I <some-dir>` to the compiler flags.

## Files created in this session

```
LarsMiniTouch/
├── CMakeLists.txt           # Pico SDK 2.x, RP2350
├── pico_sdk_import.cmake    # from SDK 2.0.0
├── pico_post_init.cmake     # flash size 4MB
├── src/
│   ├── main.c               # Demo: touch crosshair + coords
│   ├── epaper/              # SSD1681 200×200 driver (SPI)
│   ├── touch/               # XPT2046 driver (SPI, 12-bit)
│   └── fonts/               # 8×12 bitmap font (95 glyphs)
└── .github/workflows/build.yml  # GitHub Actions CI
```

Build output: 72 KB .uf2 (558 KB .elf).