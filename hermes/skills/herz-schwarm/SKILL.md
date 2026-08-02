---
name: herz-schwarm
description: "Herz-Schwarm CCC — ESP32-S3 LED-Badge-Schwarm (Firmware, TUI-Flasher, Versionsschema, Build-Pfade). Load when working on Herz_Schwarm_CCC_V repo, flashing badges, TUI tooling, or A.B.C.D versioning."
version: 1.2.1
author: silly82 (Silvan)
license: MIT
platforms: [macos, linux]
metadata:
  hermes:
    tags: [esp32, arduino, herz-schwarm, ccc, led-badge, swarm, esp-now, version, tui, pyserial, arduino-cli, nerves, elixir, phoenix]
    related_skills: [ad-hoc-verification, plan, esp32-development, esp32-platformio, dogfood, arduino-esp32-batch-flasher, nix-install]
---

# Herz-Schwarm CCC — Repo Skill

Synchronisierter LED-Badge-Schwarm für CCC (Waveshare ESP32-S3-Matrix).
ESP-NOW-basiert, Kanal 13, MAGIC_ID `0x421337CC`, 8x8 GRB-Matrix auf GPIO 14,
BOOT-Button auf GPIO 0. Beinhaltet: Badge-Firmware, Basisstation (ESP32-S3 +
W5500), Nerves-Controller (Elixir/Phoenix), TUI-Flasher (Python).

## Quick-Start für AI-Agents

```bash
cd /Users/silvanwalker/Documents/Arduino/Herz_Schwarm_CCC_V

# Versionsschema A.B.C.D siehe unten
./scripts/version.sh current          # aktuelle A.B.C aus .ino
./scripts/version.sh next-tag         # naechster Git-Tag (D = Commits)
./scripts/version.sh tag              # annotierten Tag setzen

# TUI-Flasher (effekt-Steuerung laeuft NICHT hier, nur ueber Basisstation)
python3 scripts/flash_gui.py
# oder automatisch via Bash-Skript (TTY + pyserial vorhanden)
./scripts/batch_flash_herz_schwarm.sh

# Tests
cd scripts && python3 -m pytest flashlib/tests/ -v   # 25/25 gruen

# Build verifizieren
arduino-cli compile --fqbn esp32:esp32:esp32s3:CDCOnBoot=cdc --build-path build_basestation .
```

## Versionsschema A.B.C.D (seit v1.2.0)

| Stufe | Define | Wann | Wo sichtbar |
|-------|--------|------|-------------|
| **A** MAJOR | `FW_VERSION_MAJOR` | Breaking Change | Code + Tag |
| **B** MINOR | `FW_VERSION_MINOR` | Großes Feature | Code + Tag |
| **C** PATCH | `FW_VERSION_PATCH` | Kleines Feature | Code + Tag |
| **D** BUILD | — (kein Define) | **Jeder Commit** | **Nur Git-Tag** (`v1.2.0.5` = 5 Commits) |

**D ist NICHT im Code** — würde Neukompilation bei jedem Commit erfordern.
Tag-Format: `vA.B.C.D` (`scripts/version.sh` rechnet D automatisch).

**SyncPacket hat nur 17 Byte** — überträgt nur A.B.C + DEBUG_BUILD-Flag, kein D.

## Repo-Layout

```
Herz_Schwarm_CCC_V.ino             # Badge-Firmware (Waveshare ESP32-S3-Matrix)
Herz_Schwarm_BaseStation/          # Basisstation (ESP32-S3 + W5500 Ethernet)
  └─ Herz_Schwarm_BaseStation.ino
herz_schwarm_nerves/               # Nerves/Elixir/Phoenix Controller
  ├─ lib/herz_schwarm/              # Bridge, EffectEngine, PeerTracker
  ├─ lib/herz_schwarm_web/          # LiveView Dashboard
  ├─ MAC_SETUP.md                   # Dev-Setup auf Mac
  └─ firmware/esp32_bridge/        # USB-Serial-JSON-Adapter
scripts/
  ├─ batch_flash_herz_schwarm.sh    # Bash-Flasher (default: TUI auto-launch)
  ├─ flash_gui.py                   # TUI Pseudo-GUI (ANSI, pyserial)
  ├─ flashlib/                      # Geteilte Python-Library
  │   ├─ ports.py                   # Port-Discovery (arduino-cli + glob-Fallback)
  │   ├─ build.py                   # arduino-cli wrapper (compile/upload_capture)
  │   ├─ mac.py                     # MAC-Parser (write-flash + read_mac)
  │   ├─ log.py                     # CSV + MD Append-only Logger
  │   └─ firmware.py                # A.B.C aus .ino parsen
  └─ version.sh                     # A.B.C.D Versions-Helper
firmware_update_log.csv / .md       # Flash-Audit-Trail (alle Tools, append-only)
build_basestation/ build_debug/     # Build-Artefakte (gitignored)
build_batch_gui/                    # TUI-Build-Cache (gitignored)
```

## Effekt-Steuerung: NICHT im TUI

- TUI-Flasher: nur Compile / Upload / MAC-Read / Log
- Effekte (Modes 1-8: Virus, Regenbogen, Primzahl, Welle, Beat, Zone, Ambient, Strobe):
  - **Web-UI** der Basisstation: `http://<basestation-ip>/` (Port 80)
  - **MQTT**: konfiguriert in NVS der Basisstation, Subscribe auf `herzschwarm/base/cmd/virus`
  - **Nerves-Controller** (Phoenix/LiveView auf Mac/Pi): `mix phx.server` → `http://localhost:4000`
- TUI hat **keinen ESP-NOW-Adapter** — bewusst keine Effekt-Steuerung
- Steuereinheit läuft auf **GallifreyM1 (Mac)** via USB-ESP-Bridge

## Hardware-Setup (Waveshare ESP32-S3-Matrix)

- **Pinout**: interne LED-Matrix = GPIO 14, BOOT-Taste = GPIO 0
- **LED-Reihenfolge**: GRB (FastLED konfiguriert)
- **Backside**: offene Kontakte → **Kapton-Tape Pflicht** vor Inbetriebnahme
- **FQBN**: `esp32:esp32:esp32s3:CDCOnBoot=cdc` (für USB-Serial-Debug)
- **arduino-cli-Pfad** (macOS): `/Applications/Arduino IDE.app/Contents/Resources/app/lib/backend/resources/arduino-cli`
  - `flashlib/build.py` und `ports.py` haben PATH-Fallback auf diese Bundle-Pfade

## Bash → TUI-Transition

`scripts/batch_flash_herz_schwarm.sh`:
- **TTY + pyserial installiert** → startet TUI automatisch
- `--no-gui` → erzwingt Bash-Modus
- `--gui` → erzwingt TUI (Fehler wenn nicht möglich)
- `--debug` → CDC + Serial-Debug-Build (`ENABLE_SERIAL_DEBUG=1`)
- `--all-usb` → USB-Heuristik statt `arduino-cli board list`

## Known Issues / Pitfalls

- **TUI-User drückt [4] ohne [3]**: führt zu `upload_failed`, weil `build_batch_gui/<sketch>.bin` fehlt.
  Fix in `flash_gui.py::action_flash()`: vor `upload()` prüfen ob `.bin` existiert, sonst automatisch `compile()`. Niemals User zwingen, manuell `[3]` zu drücken.
- **ESP32-S3 Bootloader-Reset nach Upload**: `esptool read_mac` im separaten Aufruf schlägt fehl, weil Port noch busy. Fix: MAC direkt aus `arduino-cli upload`-Output parsen (`flashlib/mac._parse_mac`). Spart ~3s pro Board und eliminiert Race-Condition. `upload_capture()` in `flashlib/build.py` gibt `(success, stdout+stderr)` zurück.
- **arduino-cli nicht im PATH** (macOS Arduino IDE Bundle): `flashlib/build._cli()` und `flashlib/ports._find_cli()` haben Fallback-Listen. Ohne Fallback → stille `None`-Returns.
- **argv[0] muss "compile"/"upload" sein**, nicht "arduino-cli" (sonst: `unknown command "arduino-cli"`). `subprocess.run([cli] + argv)` prependet den Binary-Pfad, also muss argv mit dem **Sub-Command** starten.
- **TUI-E2E-Test via stdin**: `pause()` (= `input("Weiter mit Enter…")`) schluckt das nächste Zeichen als Enter. Beim Test mit `printf '1\n\n4\nq\n'` wird `[4]` nicht als Menü-Auswahl erkannt. Workaround: zusätzliches Newline nach `pause()`, oder `pause()` so umbauen dass es nur ein einzelnes Enter konsumiert.
- **MQTT retained messages** können täuschen — `log.append()` nutzt lokale Zeitstempel.
- **Nerves auf Mac-Dev**: 8+ Elixir-Compiler-Bugs wurden 2026-07 beim ersten echten Setup gefunden — `import Bitwise` fehlt, `live_view/0` nicht in `herz_schwarm_web.ex`, fehlende `gettext`/`telemetry_poller` deps, Nerves-Bootstrap-Check bei `targets: :rpi4`, `color_to_hex`-Operator-Precedence, `handle_cast`-Grouping, Config-quoted-keyword. **Vollständige Liste mit Fixes**: siehe `references/nerves-setup.md`.

## Test-Strategie

- **25/25 Unit-Tests** in `scripts/flashlib/tests/` (pytest)
- **Ad-hoc-Verifikation** per Skript unter `/tmp/hermes-verify-*.sh` (Cleanup nach Lauf)
- **Hardware-Tests**: nur mit echtem ESP32-S3 möglich
  - Flash-Vergleich: 944 KB App + 19 KB Bootloader + 8 KB Partitions = 971 KB
  - RAM: 46 KB (14% von 320 KB Heap)
  - Mehrere erfolgreiche Test-Flashes dokumentiert in `firmware_update_log.csv` (FW 1.1.0, 1.2.0)

## Build-Artefakte und gitignore

`build_debug/`, `build_batch/`, `build_basestation/`, `build_bridge/`, `build_batch_gui/`
sind Build-Caches → **alle in `.gitignore`**. `firmware_update_log.{csv,md}` wird
**getrackt** (Audit-Trail), `.bak`-Dateien sind ignored.

## Häufige Befehle

```bash
# Version
scripts/version.sh current         # A.B.C
scripts/version.sh next-tag        # vA.B.C.D-Vorschlag
scripts/version.sh tag             # Tag setzen + pushen

# Build
arduino-cli compile --fqbn esp32:esp32:esp32s3:CDCOnBoot=cdc --build-path build_basestation .
arduino-cli compile --fqbn esp32:esp32:esp32s3 --build-path build_basestation .  # Release (kein Debug)

# Test
cd scripts && python3 -m pytest flashlib/tests/ -v

# Flash
python3 scripts/flash_gui.py       # TUI (empfohlen)
./scripts/batch_flash_herz_schwarm.sh --no-gui --debug  # Bash + Debug-Build

# Verifikation
git log --oneline -10
git tag -l --sort=-version:refname | head -5
tail -5 firmware_update_log.csv
```

## Workflow für neue Features

1. **Plan** in `.hermes/plans/YYYY-MM-DD_HHMMSS-<slug>.md` schreiben (skill: `plan`)
2. TDD: erst Tests in `scripts/flashlib/tests/`, dann Implementierung
3. Build verifizieren: `arduino-cli compile ...`
4. Bei echtem Feature → `B` (MINOR) hoch, z. B. `1.2.0 → 1.3.0`
5. Bei kleinem Fix → `C` (PATCH) hoch, z. B. `1.2.0 → 1.2.1`
6. **Ad-hoc-Verifikation** vor jedem Commit (skill: `ad-hoc-verification`)
7. Commit + `./scripts/version.sh tag` → push

## Cross-Skill Hinweise

- **`arduino-esp32-batch-flasher`** — class-level Pattern (Extract & Share, flashlib-Architektur, A.B.C.D, MAC aus Upload-Output, TTY-Test-Pitfall)
- **`nix-install`** — Determinate Nix 3.20.0 auf GallifreyM1 ist schneller als brew für Tool-Installation (Elixir/Erlang-Stack)
- **`ad-hoc-verification`**: nach jedem Code-Change ein `/tmp/hermes-verify-*.sh`-Skript
- **`plan`**: bei größeren Refactors/Features (mehrere Dateien, mehrere Tage)
- **`esp32-development`**: ESP-IDF/PlatformIO/Arduino-CLI-Builds
- **`dogfood`**: TUI selbst testen mit `printf 'q\n' | python3 scripts/flash_gui.py`
- **`requesting-code-review`**: vor Merge in main

## Wichtige Constraints

- **macOS first** (GallifreyM1, arm64), Linux secondary (x86_64)
- **Windows**: v0.2.0 (COM-Ports, VT-Mode aktivieren)
- **Effekt-Steuerung läuft NUR über Basisstation** (Web-UI / MQTT), nie im TUI
- **Steuereinheit läuft auf GallifreyM1** (Mac) — ESP32-S3 als USB-Bridge sendet via ESP-NOW
- **Single-source-of-truth für Version**: `Herz_Schwarm_CCC_V.ino` Defines → gelesen von allen Tools
- **Logs append-only**: nie `firmware_update_log.csv` überschreiben

## Wann NICHT weiterarbeiten

- Frag nach, bevor `A` (MAJOR) erhöht wird
- Frag nach, bevor `B` (MINOR) ohne Diskussion erhöht wird
- Bei Effekt-Steuerung: verweisen auf Basisstation (Web/MQTT) oder Nerves-Controller, nicht TUI
- Bei Breaking Change am SyncPacket: 13-Byte-Legacy-Support erhalten

## References

- `references/nerves-setup.md` — 15 dokumentierte Elixir-Compiler-Bugs mit Symptom/Fix/Lesson, inkl. Nix-vs-brew-Empfehlung für GallifreyM1, `pause()`-E2E-Pitfall, Phoenix-`0.0.0.0:4000`-Bind-Problem (ungelöst).