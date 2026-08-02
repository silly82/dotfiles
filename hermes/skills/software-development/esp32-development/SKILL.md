---
name: esp32-development
description: ESP32 development with PlatformIO — setup, board-specific quirks, BLE, WiFi, build troubleshooting
---

# ESP32 Development

PlatformIO-based ESP32 development, covering setup, board-specific quirks, and common pitfalls.

## PlatformIO Setup (macOS + Nix)

**Nix PlatformIO is BROKEN** — the built-in `uv` tries to pip-install `tool-esptoolpy` into the immutable Nix Python store, triggering PEP 668 errors. The workaround:

```bash
# Clean venv with Python 3.11+
python3.11 -m venv ~/.pio_venv
~/.pio_venv/bin/pip install platformio esptool
```

Use `~/.pio_venv/bin/pio` for everything. The system `pio` from Nix must NOT be used.

### Builder Patch

The espressif32 platform builder sets `OBJCOPY='esptool'` and `UPLOADER='esptool'` in `~/.platformio/platforms/espressif32@*/builder/main.py`. Patch these to the venv path:

```python
# OBJCOPY:
OBJCOPY='/Users/<user>/.pio_venv/bin/esptool',
# UPLOADER:
UPLOADER="/Users/<user>/.pio_venv/bin/esptool",
```

Also fix `--before` / `--after` separator style for esptool v5 (underscores → dashes):
- `default_reset` → `default-reset`
- `hard_reset` → `hard-reset`

## Board-Specific Quirks

### ESP32-C3 Super Mini
- **CPU**: RISC-V single-core 160MHz, **400KB SRAM** (tight!)
- **LED**: GPIO8, **active LOW** (`digitalWrite(8, LOW)` = on)
- **BOOT button**: GPIO9
- **Serial**: Native USB CDC (`/dev/cu.usbmodem101`), **not** CH340/UART

### ESP32-C3 / C6 / S3 Stuck in ROM-Bootloader (Download-Mode)

After a fresh flash or aborted upload, the chip can stay in the ROM bootloader. macOS enumerates the USB device as `Espressif USB JTAG/serial debug unit` (iProduct=2) — but **NOT as a serial port**, so `arduino-cli board list` shows nothing new, and no `/dev/cu.usbmodem*` appears. The chip is identified by:
- `idVendor = 0x303A` (Espressif)
- `idProduct = 0x1001` (ROM bootloader; running app uses different PID like `0x1002`)
- Serial number = chip MAC (e.g. `8C:BF:EA:CB:AA:20`)

**Detection:**
```bash
ioreg -p IOUSB -l 2>&1 | grep -A2 "Espressif" | grep -E "idVendor|idProduct"
# If idProduct=0x1001 → ROM bootloader, no serial port will appear
# If idProduct=0x1002 (or similar) → running app with CDC-ACM, /dev/cu.usbmodem* should exist
```

**Workaround: Flash directly via arduino-cli (uses esptool internally)** — doesn't need a serial port, talks to ROM bootloader over USB:
```bash
ARDUINO_CLI="/Applications/Arduino IDE.app/Contents/Resources/app/lib/backend/resources/arduino-cli"
$ARDUINO_CLI compile --fqbn esp32:esp32:esp32c6:CDCOnBoot=cdc --build-path /tmp/build sketch_dir
$ARDUINO_CLI upload -p /dev/cu.usbmodem1101 --fqbn esp32:esp32:esp32c6:CDCOnBoot=cdc \
  --input-dir /tmp/build sketch_dir
# The upload uses esptool which auto-detects the ROM bootloader. After "Hard resetting
# via RTS pin", the chip may stay in download mode on C6 — see manual reset below.
```

**Manual reset to get back to running app (CDC-ACM port appears):**
1. **BOOT button hold + RESET tap + BOOT release → second RESET**: forces Download-Mode then back to normal boot
2. **Or USB cable cycle** (unplug + replug): most reliable, no button gymnastics
3. **Or just RESET button** (no BOOT): clean reset → running app → `/dev/cu.usbmodem*` appears

**For XIAO ESP32C6:** buttons are tiny, marked `B` (Boot=GPIO9) and `R` (Reset). Hold `B`, tap `R`, release `B` for download mode. Just tap `R` for normal reset.

**Symptom after upload that stayed in download mode:** `arduino-cli board list` shows the SAME ports as before, no new Espressif entry. The flash succeeded but the chip is still in ROM bootloader waiting for the next download.

**Tested:** flashed `esp32_bridge.ino` to a XIAO ESP32C6 in ROM-bootloader state using `arduino-cli upload -p /dev/cu.usbmodem1101` — worked. After upload, `New upload port: /dev/cu.usbmodem1101` confirms esptool reset successfully, but on C6 the chip often stays in download mode without a manual reset.

### ESP32-C3 Serial Access Problem
Opening `/dev/cu.usbmodem101` toggles DTR/RTS, which resets the C3 into **download mode** (`boot:0x7`). The chip then waits for esptool and never runs the firmware.

**Solutions**:
1. **Read serial during upload**: Open the port while `pio run -t upload` is still running (right after "Hard resetting via RTS pin"). The upload process holds DTR/RTS correctly.
2. **Verify via MQTT**: If the firmware publishes to MQTT, subscribe to the broker instead of reading serial.
3. **Use a UART bridge**: Wire a CH340/CP2102 to the C3's UART0 pins (GPIO20/21) for reliable serial access.

### ESP32-C3 BLE + WiFi RAM Constraint
**CRITICAL**: The C3 has only 400KB RAM. BLE (Bluedroid/NimBLE) + WiFi simultaneously exhausts heap and causes silent crashes ("Guru Meditation Error: Core 0 panic'ed").

**Fix**: Initialize BLE **before** WiFi, connect to BMS/peripheral, THEN start WiFi+MQTT:

```cpp
void setup() {
  // 1. BLE first
  BLEDevice::init("device-name");
  // connect to peripheral...
  
  // 2. WiFi/MQTT after BLE connect
  WiFi.begin(ssid, pass);
  mqtt.connect(broker);
}
```

Expected free heap on C3:
- Before BLE: ~250KB
- After BLE init: ~80KB
- After WiFi + BLE: ~30KB

## BLE BMS Bridge Patterns

### BMS Protocol Detection
Not all BMS brands use the same BLE service:
- **JBD / Xiaoxiang / Overkill**: Nordic UART Service (NUS) — `6e400001-b5a3-f393-e0a9-e50e24dcca9e`
- **JK BMS / BDRG**: Service `0xFFE0` / characteristic `0xFFE1`

### BDRG BMS Specifics
- Device name format: `R-<model>-<serial>` (e.g. `R-12100BNNH19-C01278`)
- Uses JK protocol (0xFFE0), **not** JBD/NUS
- Manufacturer data contains MAC: `[0x585A]` payload = 6-byte MAC

### JK BMS Protocol (0xFFE0)
- Service UUID: `0000ffe0-0000-1000-8000-00805f9b34fb`
- Characteristic: `0000ffe1-0000-1000-8000-00805f9b34fb` (notify)
- Device sends notification frames periodically (no request needed):
  - Frame header: `0x55 0xAA` or `0xAA 0x55`
  - Record type `0x01`: basic info (voltage, current, SOC, temps)
  - Record type `0x02`: cell voltages
  - Record type `0x03`: status/error flags
  - CRC16 (Modbus) at end

### JBD Protocol (NUS)
- Service: `6e400001-b5a3-f393-e0a9-e50e24dcca9e`
- TX: `6e400002-b5a3-f393-e0a9-e50e24dcca9e` (write)
- RX: `6e400003-b5a3-f393-e0a9-e50e24dcca9e` (notify)
- Request: `DD A5 <cmd> 00 <checksum>`
- Response: `DD 5A <cmd> <len> <data...> <checksum>`
- Checksum: sum of all bytes, not XOR

## Partition Tables

For firmware >1.3MB (common with BLE+WiFi+JSON), use `huge_app`:
```ini
board_build.partitions = huge_app.csv
```
Gives 3MB for app partition (address `0x10000`). Fits in 4MB flash.

## Arduino/ESP32 Sketch Optimization

For optimizing Arduino .ino sketches (ESP-NOW, FastLED, ISR-heavy code), see `references/arduino-sketch-optimization.md` for patterns:
- String → char-Array (heap fragmentation)
- O(n²) peer tracking → hash index
- Copy-paste state variables → EffectState array
- Small-domain computation → compile-time LUT
- 2D mask → 64-bit bitmask
- delay() → timestamp scheduling
- Fixed delay → adaptive frame limit
- ISR-shared data → volatile + atomics
- esp_now_send() return value handling
- **random() → esp_random()** for unique-ID generation
- **JSON-over-Serial CRLF + buffer-overflow** handling for bridge firmware
- arduino-cli build verification paths
- Performance-refactor → SemVer MINOR bump + annotated tag workflow
- .bak backup handling pre/post commit
- Ad-hoc verification without hardware (static + build, not "tests pass")
- Verify-Skript-Workflow mit `mktemp` und cleanup pattern

For building a Python TUI to flash multiple ESP32 boards (arduino-cli wrapper, portable port discovery, CSV/MD logger, FW-version parser, ANSI menus) — see `references/python-batch-flasher.md`. Key patterns: Extract-&-Share library layout, scope boundary (TUI = flash-only, NOT runtime effect control), `r"..."` regex pitfall in `terminal -c`, plan-mode "test from plan" violates TDD iron law, Bash→TUI `exec` bridge pattern for graceful dual-mode CLI, ad-hoc verification script patterns (`</dev/null` for non-TTY, /tmp + `cat <<'OUTER'` heredoc to avoid `/var/folders` block).

For firmware versioning with the A.B.C.D schema (where D is a per-commit build counter encoded only in Git tags, not in code) — see `references/firmware-versioning-abcd.md`.

For Nerves / Phoenix Elixir first-build on Mac (Nix-installed Elixir, `mix compile` errors, UART auto-detect, exponential reconnect backoff, LiveView macros) — see `references/nerves-elixir-first-build.md`.

For XIAO ESP32C6 / ESP32-S3 / classic ESP32 board detection on macOS — see `references/esp32-mac-usb-detection.md`. Use the re-runnable `scripts/detect_esp32_usb.sh` to enumerate `/dev/cu.*` paths, identify ROM-bootloader vs running-app via ioreg, and decide between arduino-cli upload (talks ROM directly) vs UART-bridge enumeration.

## Pitfalls

1. **Don't use Nix PlatformIO** — always use a pip venv with Python 3.11+
2. **ESP32-C3 can't run BLE+WiFi simultaneously** — init BLE first, WiFi after
3. **C3 native USB Serial resets chip on open** — use upload-time reading or MQTT for debug
4. **C3 Super Mini LED is active LOW on GPIO8** — `digitalWrite(8, LOW)` = on
5. **BDRG BMS is JK protocol, not JBD** — check Service UUID before implementing
6. **esptool v5 uses dashes in flags** (`default-reset`), not underscores like v4
7. **C3 BLE double-init crash**: Calling `BLEDevice::init()` twice (main + BMS class) crashes C3. Init once globally.
8. **MQTT retained false positive**: `connected` with `retain=true` persists after crash. Use non-retained heartbeat for liveness.
9. **C3/C6/S3 Serial via upload window**: Read serial WHILE `pio run -t upload` runs (after "Hard resetting via RTS pin"). Standalone open always gives `boot:0x7` download mode on C3. For C6/S3 the chip often stays in ROM bootloader after upload — manual reset or USB cycle needed. See "ESP32-C3 / C6 / S3 Stuck in ROM-Bootloader" above for the full detection + recovery pattern. **C6-specific**: even after a successful upload, C6 does NOT auto-reset like S3 does — it stays in `idProduct=0x1001`. Manual reset (BOOT+RESET sequence or USB cycle) required to see `/dev/cu.usbmodem*`. See `references/esp32-mac-usb-detection.md` for full detection script.
10. **Arduino String in loop = heap fragmentation** — use char-Array with manual length tracking
11. **ESP-NOW recv callback is ISR context** — no `Serial.printf`, no heap allocation, use `volatile` for shared data
12. **FastLED + delay() = jitter** — use timestamp-based scheduling for any timed sends, not `delay()`
13. **TUI scope boundary** — a batch-flasher TUI is for flash operations only. Runtime effect control (e.g. ESP-NOW modes 1-8) needs a radio adapter, not a flasher. Document the boundary in plan, menu header comment, and README. See `references/python-batch-flasher.md`.
14. **`r"..."` regex in `terminal -c "..."` calls** — shell double-escaping turns `\w+` into `\\w+`, the regex never matches, and "tests pass" vacuously. Write the test to a temp file with `write_file`, then run it. Or use `execute_code` for Python in-process testing.
15. **Plan-mode "test from plan" is not TDD** — when a plan includes "Step 1: write failing test" with full code, that test is a sketch. If both the test and the implementation are written from the same imagined interface, the test passes vacuously. Always run the test RED against the real file first. The plan's test tells you what to cover, not what to type.
16. **Arduino IDE bundle arduino-cli is not on PATH** — `shutil.which("arduino-cli")` returns `None` on a fresh macOS. Fall back to a known-paths list including `/Applications/Arduino IDE.app/Contents/Resources/app/lib/backend/resources/arduino-cli`, `/opt/homebrew/bin/arduino-cli`, etc. Verify with `PATH=/usr/bin:/bin python3 -c "_cli()"` in the verification script — must still resolve.
17. **`subprocess.run([cli] + argv)` double-prepends the binary** — argv builders must return the sub-command only (`["compile", ...]`), never `["arduino-cli", "compile", ...]`. Otherwise arduino-cli sees `["/path/arduino-cli", "arduino-cli", "compile", ...]` and errors with `unknown command "arduino-cli" for "arduino-cli"`. See `references/python-batch-flasher.md` §arduino-cli Wrapper.
18. **Separate `esptool read_mac` after upload is racy on ESP32-S3** — the chip is in bootloader-reset for 2-3s after `arduino-cli upload`. The second command races the reset and fails ~50% with 1.5s sleep, works with 3s but wastes time. **Better:** capture the upload output (`subprocess.run(..., stdout=PIPE, stderr=STDOUT, text=True)`) and parse the MAC from `MAC:                aa:bb:cc:dd:ee:ff` already in the write-flash output. Reliable and fast. **Verified on 3 real ESP32-S3 badges** — all `ok;<MAC>` entries in `firmware_update_log.csv`, no race, no extra sleep.
19. **TUI without auto-build fails on first flash** — legacy Bash always compiles first, so `build_batch/` is guaranteed to have a `.bin`. The TUI is action-driven: if the user hits `[4]` without `[3]`, the upload silently fails with `upload_failed` and the cause is hidden. Check `Path(BUILD_PATH) / f"{INO_PATH.stem}.ino.bin").exists()` at the top of `action_flash` and trigger `do_compile(..., stream=True)` if missing.
20. **Nerves `mix.exs` with `targets: @all_targets` causes "Nerves bootstrap but doesn't depend on Nerves" error** — `nerves` must be in `deps` without a `targets:` filter, or with `targets: :rpi4`. Even on the Mac dev host, Nerves is required as a dependency because the bootstrap checks for it. Fix: `{:nerves, "~> 1.10", runtime: false}` (no targets filter). The Nerves system/runtime/pack deps should stay with `targets: :rpi4`.
21. **Nerves dev.exs config: `defp` in config file = CompileError** — Elixir config files (.exs) are evaluated as scripts, not compiled into modules. `defp` defines a private function in the *script module* which works in the module but fails during `import_config`. Use inline `(case ... end)` expressions instead of helper functions. Error: `undefined function herz_schwarm_default_uart_device/0 (there is no such import)`. Solution: inline the logic in the `config :herz_schwarm, :uart_device, (case ... end)` expression.
22. **Plug.Cowboy 2.9.0 crashes with OTP 28 / Elixir 1.18** — `Plug.Cowboy.Translator.translate/4 is undefined` crashes sporadically when Logger events fire. `plug_cowboy` is not needed if `Bandit.PhoenixAdapter` is configured as the endpoint adapter. Fix: remove `{:plug_cowboy, "~> 2.6"}` from `mix.exs` deps. Alternatively, `mix.exs` should not list `plug_cowboy` at all since the adapter is Bandit, not Cowboy.
23. **Nerves UART Bridge `Application.get_env` returns hardcoded default at startup** — In `bridge.ex:45`, `Application.get_env(:herz_schwarm, :uart_device, "/dev/ttyUSB0")` returns the fallback value even when `dev.exs` correctly resolved a different port via `Path.wildcard`. This happens because `dev.exs` is a *config file* evaluated by Mix but the Application env may not be available at GenServer init time. **Workaround**: always pass `UART_DEVICE=/dev/cu.usbmodemXXX mix phx.server`. **Proper fix**: `Application.fetch_env!(:herz_schwarm, :uart_device)` (no default, fail loudly).
24. **XIAO ESP32C6 stays in ROM bootloader after upload even with `Hard resetting via RTS pin`** — `esptool` outputs `New upload port: /dev/cu.usbmodem1101` after the reset, but the C6 chip often does NOT complete the reset to application mode. The `idProduct` stays at `0x1001` (ROM bootloader) and no `/dev/cu.usbmodem*` appears in macOS's device list. This is a C6-specific behavior: S3 auto-resets to app mode, C6 doesn't. **Fix**: unplug + replug USB cable, or hold BOOT button + tap RESET + release BOOT. This is the most reliable way to get back to running firmware.
