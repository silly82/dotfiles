# ESP32 Board Detection on macOS — USB-CDC Paths, ROM Bootloader vs Running App

Re-runnable detection: `scripts/detect_esp32_usb.sh` (in this skill).

## Why detection is non-trivial

ESP32 chips with native USB (ESP32-S2, S3, C6) enumerate differently from classic ESP32 with USB-serial bridges (CH340, CP2102). The same chip can show different paths depending on firmware state. A chip stuck in ROM bootloader shows up as `iProduct = "USB JTAG/serial debug unit"` with no `/dev/cu.*` port at all — `arduino-cli board list` shows nothing new, but the chip IS reachable via `esptool` directly over USB.

## VID/PID matrix (Espressif)

| VID | PID | Mode | macOS path | Recoverable? |
|-----|-----|------|-----------|------|
| 0x303A | 0x1001 | **ROM bootloader** | none (no CDC-ACM) | Yes — flash via arduino-cli |
| 0x303A | 0x1002+ | Running app | `/dev/cu.usbmodem*` | Yes — manual reset (C6) |
| 0x303A | 0x0002 | ESP32-S2/S3 CDC | `/dev/cu.usbmodem*` | n/a |

`idVendor` always 0x303A (Espressif). The `idProduct` is the state indicator.

## Detection: ioreg

```bash
ioreg -p IOUSB -l 2>&1 | grep -B1 -A3 "Espressif" | head -20
```

Look for:
- `idVendor = 0x303A` (30346 decimal) — Espressif
- `idProduct = 0x1001` (4097) — ROM bootloader (no CDC port)
- `idProduct != 0x1001` — running app, expect `/dev/cu.usbmodem*`
- `USB Serial Number = "AA:BB:CC:DD:EE:FF"` — chip's MAC

## Common port patterns (macOS)

| Pattern | Matches |
|----------|---------|
| `/dev/cu.usbmodem*` | XIAO ESP32C6, ESP32-S3 native USB, CH340, most Chinese clones |
| `/dev/cu.usbserial-*` | Waveshare ESP32-S3-Matrix native USB, CP2102 |
| `/dev/cu.SLAB_USBtoUART` | Silicon Labs CP210x |
| `/dev/cu.wchusbserial*` | WCH CH340 (alt designation) |
| `/dev/ttyUSB0` | Linux (CH340/CP2102), **not macOS** |

## XIAO ESP32C6 specific gotcha: stays in ROM after upload

C6 is unique in that **`arduino-cli upload` does NOT auto-reset to the running app** like S3/C3 do. The C6 stays in ROM bootloader (`idProduct=0x1001`, no CDC port) until manually reset.

**Reset sequence (XIAO ESP32C6, buttons labeled `B` and `R`):**
1. Hold `B` (Boot=GPIO9), tap `R` (Reset), release `B` → enters download mode (won't help if you want to run app)
2. For normal boot: just tap `R` (no `B`) → clean reset → running app → `/dev/cu.usbmodem*` appears
3. Or unplug + replug USB cable — most reliable, no button gymnastics

After reset, `ioreg` shows `idProduct=0x1002+` (or higher) and `/dev/cu.usbmodem*` appears.

## arduino-cli flash to ROM-bootloader-only chip

```bash
ARDUINO_CLI="/Applications/Arduino IDE.app/Contents/Resources/app/lib/backend/resources/arduino-cli"

# Compile
$ARDUINO_CLI compile --fqbn esp32:esp32:esp32c6:CDCOnBoot=cdc \
  --build-path /tmp/build <sketch_dir>

# Upload — esptool talks to ROM bootloader directly over USB
$ARDUINO_CLI upload -p /dev/cu.usbmodem1101 \
  --fqbn esp32:esp32:esp32c6:CDCOnBoot=cdc \
  --input-dir /tmp/build <sketch_dir>
```

`arduino-cli` will pick up the `usbmodem*` path even if you pass it as a hint, or auto-detect the chip on `iProduct`. After upload, watch for `New upload port: /dev/cu.usbmodem1101 (serial)` — if the port name doesn't change, the chip is still in download mode.

## Re-runnable detection script

`scripts/detect_esp32_usb.sh` automates the above. Outputs:
- All `/dev/cu.*` paths present
- ioreg dump for any Espressif device
- `arduino-cli board list` filtered to ESP32
- Status: running-app-found, rom-bootloader-only, or no-device-detected
- Concrete fix command for the current state

Run after plugging in or unplugging an ESP32 board. Use the output to set `UART_DEVICE` for `mix phx.server` or as `arduino-cli upload -p <path>`.

## Re-entering download mode on ESP32-S3 (for comparison)

ESP32-S3 **does** auto-reset from ROM after upload. If you need to reflash:
- Hold BOOT, tap RESET, release BOOT → download mode → flash → auto-reset to running

XIAO-C6 is the **exception**, not the rule, in needing manual reset. Don't waste time trying S3-style reset on C6.
