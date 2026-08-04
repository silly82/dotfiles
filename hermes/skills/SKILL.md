---
name: arduino-esp32-batch-flasher
description: "Build a Python TUI + CLI pseudo-GUI to flash multiple ESP32 (or other Arduino-CLI boards) in batch, with port discovery, auto-build, MAC-read from upload output, and append-only audit log. Load when user wants a flasher for many boards, batch production, or interactive terminal UI for ESP32 / Arduino."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [macos, linux]
metadata:
  hermes:
    tags: [esp32, arduino, arduino-cli, batch-flash, tui, pyserial, esptool, mac-read, swarming, led-badge]
    related_skills: [ad-hoc-verification, plan, esp32-development, esp32-platformio, systematic-debugging]
---

# Arduino / ESP32 Batch-Flasher (Python TUI + Bash-Frontend)

Wiederverwendbares Pattern für: viele Boards (10+, 100+) programmiert flashen, mit
Audit-Trail, interaktivem TUI für gelegentliche Flashes, und einem Bash-Frontend
für CI/Headless-Use.

## Architektur-Entscheidung: Extract & Share

Eine Python-Library `flashlib/` (oder gleichnamig) enthält die Logik. Genutzt von:
- TUI (`flash_gui.py`) — interaktiv
- Bash-Skript (`batch_flash_*.sh`) — headless / CI, ruft Library via `python3 -m`

Library-Module (alle ohne externe Deps außer `pyserial`):
- **`ports.py`** — `discover_ports(include_all_usb)` mit Arduino-CLI + Glob-Fallback
- **`build.py`** — `compile(...)` und `upload_capture(...)` (gibt stdout+stderr zurück)
- **`mac.py`** — `_parse_mac(text)` Regex, erkennt `MAC: aa:...` und `MAC:    aa:...`
- **`log.py`** — `Log(csv_path, md_path).append(...)` (append-only CSV + MD)
- **`firmware.py`** — `read_firmware_version(ino_path)` (MAJOR/MINOR/PATCH/DEBUG_BUILD)

Plus Versions-Helper (siehe `arduino-firmware-versioning` pitfall unten).

## Pitfall 1: arduino-cli nicht im PATH (macOS)

`arduino-cli` ist im Arduino-IDE-Bundle, **nicht** im Standard-PATH. Symptom:
`which arduino-cli` → `None`, alle Builds/Flashes fail.

**Fix in `build.py` und `ports.py`:**

```python
_FALLBACK_PATHS = [
    "/Applications/Arduino IDE.app/Contents/Resources/app/lib/backend/resources/arduino-cli",
    "/usr/local/bin/arduino-cli",
    "/opt/homebrew/bin/arduino-cli",
    os.path.expanduser("~/Arduino/bin/arduino-cli"),
    os.path.expanduser("~/.local/bin/arduino-cli"),
]

def _cli() -> Optional[str]:
    p = shutil.which("arduino-cli")
    if p: return p
    for path in _FALLBACK_PATHS:
        if os.path.isfile(path) and os.access(path, os.X_OK):
            return path
    return None
```

## Pitfall 2: argv[0] darf nicht "arduino-cli" sein

Wenn `subprocess.run([cli] + argv)` und argv[0] = `"arduino-cli"`, dann wird
`"arduino-cli"` als Sub-Command interpretiert → `unknown command "arduino-cli"`.

**Fix:** argv beginnt mit dem **Sub-Command** (`"compile"`, `"upload"`, `"board"`, etc.),
nicht mit dem Binary-Namen.

```python
# FALSCH
argv = ["arduino-cli", "compile", "--fqbn", fqbn, "--build-path", p]
# RICHTIG
argv = ["compile", "--fqbn", fqbn, "--build-path", p]
```

## Pitfall 3: MAC-Read Race-Condition nach Upload

Versuchtes Pattern: nach `ardu-cli upload` direkt `esptool read_mac` aufrufen.
**Race:** der ESP32-S3 ist noch im Bootloader-Reset, Port ist busy, `read_mac`
failt trotz 3s Sleep.

**Bessere Lösung:** MAC steht **schon im Upload-Output**:

```
Connected to ESP32-S3 on /dev/cu.usbmodem1101:
MAC:                3c:0f:02:e4:61:00
```

**Fix:** `subprocess.run(... stdout=PIPE, stderr=STDOUT)` → `upload_capture()`,
dann Regex `_parse_mac(output)`. Kein zweiter esptool-Aufruf, kein Sleep, kein
Race. Spart ~3s pro Board.

**Regex erkennt beide Formate:**

```python
_MAC_RE = re.compile(r"(?:Base\s+)?MAC:\s*([0-9a-fA-F:]{17})")
# matched: "MAC: aa:bb:..." und "MAC:                aa:bb:..."
```

## Pitfall 4: TUI-User drückt direkt [4] ohne [3]

Ohne Auto-Build führt `action_flash()` zu `upload_failed`, weil `build_*/<sketch>.bin`
fehlt. User sieht nur `✗ Upload fehlgeschlagen` ohne Erklärung.

**Fix:** vor `upload()` prüfen ob `.bin` existiert, sonst `compile()`:

```python
bin_path = Path(BUILD_PATH) / f"{INO_PATH.stem}.ino.bin"
if not bin_path.exists():
    print("⚠ Kein Build gefunden — kompiliere zuerst…")
    ok = do_compile(...)
    if not ok: return  # bail, kein Flash
```

## Pitfall 5: TTY-Test-Scripting via stdin

Beim E2E-Test via `printf '1\n\n4\nq\n' | python3 tui.py` schluckt `pause()`
(=`input("Weiter mit Enter…")`) das nächste Zeichen als Enter. Folge: `[4]`
wird nicht als Menü-Auswahl erkannt.

**Workaround im Test:** ein zusätzliches Newline zwischen Pause und Aktion:
`printf '1\nall\n\n4\nq\n'`. Oder: `pause()` so umbauen dass es nur ein einzelnes
Enter konsumiert (z. B. via TTY-Mode).

## Bash → TUI Auto-Launch

Bash-Skript erkennt interaktives TTY und pyserial-Verfügbarkeit:

```bash
if [[ -t 1 ]] && [[ -z "${NO_GUI:-}" ]]; then
  if python3 -c "import serial" 2>/dev/null; then
    exec python3 scripts/flash_gui.py "$@"
  fi
fi
```

Mit `--no-gui` (env `NO_GUI=1`) erzwingt Bash-Modus. Mit `--gui` (`NO_GUI=0`)
erzwingt TUI, Fehler wenn nicht möglich.

## Logs append-only, nie überschreiben

Audit-Trail in `firmware_update_log.csv` (Semikolon-getrennt) + `.md` (Tabelle).
Header nur schreiben wenn Datei neu. Pro Lauf eine Zeile. **Committen** —
Build-Caches in `.gitignore`, Logs nicht.

## Ad-hoc-Verifikation: Pflicht nach jedem Patch

Für jeden Code-Change ein `/tmp/hermes-verify-*.sh`-Skript:
- Statische Checks (grep nach Code-Mustern)
- Build-Compile (`arduino-cli compile …`)
- Unit-Tests (`pytest flashlib/tests/`)
- HW-Evidenz (letzte Log-Einträge in `firmware_update_log.csv`)

Cleanup am Ende: `rm /tmp/hermes-verify-*.sh`. 11-19 Checks pro Run.

## Versionsschema A.B.C.D (speziell für Arduino-Firmware)

**Nicht** klassisches SemVer. A=Breaking, B=großes Feature, C=klein, D nur in
Git-Tags. Begründung in der `arduino-firmware-versioning`-Pitfall.

**D=NICHT im Code** — würde Neukompilation bei jedem Commit erzwingen. Nur als
`v1.2.0.5` (5 Commits seit `v1.2.0`). Tag-Format: `vA.B.C.D`.

**SyncPacket bleibt klein** (z. B. 17 Byte ESP-NOW) — überträgt nur A.B.C +
DEBUG_BUILD-Flag, kein D.

## Required Dependencies

- `pyserial` (`pip3 install --user pyserial`)
- `arduino-cli` (im IDE-Bundle oder Homebrew)
- `esptool.py` (`brew install esptool`)

## Quick-Start-Template

```bash
# Repo-Layout
scripts/
├─ batch_flash_X.sh          # Bash-Frontend
├─ flash_gui.py              # TUI
├─ flashlib/
│  ├─ __init__.py
│  ├─ ports.py               # arduino-cli + glob-Fallback
│  ├─ build.py               # arduino-cli wrapper
│  ├─ mac.py                 # MAC-Parser (write-flash + read_mac)
│  ├─ log.py                 # CSV + MD Logger
│  ├─ firmware.py            # A.B.C aus .ino
│  └─ tests/                 # pytest
└─ version.sh                # A.B.C.D Helper
```

Unit-Tests mit pytest, kein Framework nötig. `subprocess.run` mit
`capture_output=True` für Tests, `stream=True` für Live-UI.

## Effekt-Steuerung läuft NIE im Flasher

Wenn das Projekt nebenbei Effekte/Steuerung hat (LED-Badges, Motoren, etc.):
Flasher-Tool ist **nur** für **Flash-Operationen**. Effekt-Steuerung über das
eigentliche Runtime-Tool (Web-UI, MQTT, etc.). Begründung: Flasher hat keinen
Netzwerk-Adapter, wäre sonst ein zweites Steuerungs-Tool.
