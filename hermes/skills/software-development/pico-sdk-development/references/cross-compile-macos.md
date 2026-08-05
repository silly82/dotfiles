# Cross-Compiling Pico SDK on macOS (ARM64)

The macOS M1/M2/M3 host is aarch64 but the Pico target is ARM Cortex-M. Use nixpkgs for the cross-compiler.

## Toolchain via nix

```bash
# Fetch compiler + cmake (cached, ~1 GB unpacked)
nix shell nixpkgs#gcc-arm-embedded nixpkgs#cmake

# Inside the shell
export PICO_SDK_PATH=/path/to/pico-sdk
cmake -B build -DPICO_SDK_PATH=$PICO_SDK_PATH -DPICO_BOARD=pico2
cmake --build build -j$(nproc)
```

## Toolchain path (if nix shell fails)

Find the binaries:
```bash
nix build nixpkgs#gcc-arm-embedded --print-out-paths
# → /nix/store/...-gcc-arm-embedded-15.2.rel1
export PATH="/nix/store/...-gcc-arm-embedded-15.2.rel1/bin:$PATH"
```

## CMake on macOS — policy issues

macOS ships CMake 4.x. Pico SDK 2.0 bundles mbedtls with `cmake_minimum_required(2.x)` — this breaks with CMake 4.x:

```bash
export CMAKE_POLICY_VERSION_MINIMUM=3.5
```

## Build script pattern

```bash
#!/usr/bin/env bash
set -e
export PICO_SDK_PATH=/path/to/pico-sdk
export CMAKE_POLICY_VERSION_MINIMUM=3.5
export PATH="/nix/store/...-gcc-arm-embedded-15.2.rel1/bin:$PATH"
cd /path/to/project
rm -rf build
cmake -B build -DPICO_SDK_PATH=$PICO_SDK_PATH -DPICO_BOARD=pico2 -DCMAKE_BUILD_TYPE=Debug
cmake --build build -j4
```

## UF2 validation

```bash
file build/*.uf2
# → UF2 firmware image, family 0xe48bff57, address 0x10ffff00, 2 total blocks
# family 0xe48bff57 = RP2350 ARM, 0xe48bff56 = RP2040, 0xe48bff58 = RP2350 RISC-V
```

## Flashing notes

- `cp` on macOS FAT16 volumes: "could not copy extended attributes" is harmless
- The drive disappears immediately when the UF2 is accepted
- If the drive reappears after a few seconds: **bootloop** — firmware crashed
- If the drive disappears but no serial appears: **firmware is hanging** during init (BUSY, SPI, etc.)