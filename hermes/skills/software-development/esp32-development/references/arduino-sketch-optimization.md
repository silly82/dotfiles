# Arduino/ESP32 Sketch Optimization Patterns

Patterns from optimizing a 511-line ESP-NOW + FastLED swarm badge sketch (Herz_Schwarm_CCC_V).

## 1. String → char-Array (Heap-Fragmentierung)

**Anti-pattern:** `String input; input += "x";` in every loop iteration.

**Fix:**
```cpp
char buf[12] = {0};
uint8_t len = 0;
// Append
if (len < sizeof(buf)-1) { buf[len++] = c; buf[len] = '\0'; }
// Compare
if (strcmp(buf, "-.-.") == 0) { ... }
// Reset
len = 0; buf[0] = '\0';
```

## 2. O(n²) Peer-Tracking → Hash-Index

**Anti-pattern:** Double loop over MAX_PEERS=25 with memcmp on every receive.

**Fix:** 256-entry hash by MAC[5] (last byte), collision list:
```cpp
static int8_t peerHashHead[256];  // -1 = empty
static int8_t peerHashNext[MAX_PEERS];

int find(const uint8_t* mac) {
    int8_t idx = peerHashHead[mac[5]];
    while (idx >= 0) {
        if (memcmp(peers[idx].mac, mac, 6) == 0) return idx;
        idx = peerHashNext[idx];
    }
    return -1;
}
```

## 3. Effect-State Array (statt 8× copy-paste Variablen)

**Anti-pattern:** `activeVirusID, virusStartTime, activeRainbowID, rainbowStartTime, ...` × 8 modes.

**Fix:**
```cpp
struct EffectState { uint32_t id; uint32_t startTime; bool active; };
enum EffectIdx : uint8_t { E_VIRUS=0, E_RAINBOW, E_PRIME, E_WAVE, ... };
EffectState fx[E_COUNT] = {};
```

## 4. Lookup-Table für kleine Integer-Domains

**Anti-pattern:** `isPrime(n)` called every frame for n=1..25.

**Fix:** Compile-time LUT:
```cpp
static const bool primeLUT[27] = {0,0,1,1,0,1,0,1,0,0,0,1,0,1,0,0,0,1,0,1,0,0,0,1,0,0,0};
```

## 5. 2D-Array-Maske → 64-bit Bitmaske

**Anti-pattern:** `for(i=0;i<64;i++) if (mask[i/8][i%8]==0) leds[i]=0;`

**Fix:**
```cpp
static uint64_t mask64;
// In setup(): for(i=0;i<64;i++) if (mask2d[i/8][i%8]) mask64 |= (1ULL<<i);
// In loop(): for(i=0;i<64;i++) if (!((mask64>>i)&1)) leds[i]=0;
```

## 6. delay() im ISR/Loop → Zeitstempel-Scheduling

**Anti-pattern:** `delay(random(5,25)); esp_now_send(...);`

**Fix:** Non-blocking reschedule:
```cpp
uint32_t reBroadcastAt = 0;
// Set: reBroadcastAt = millis() + random(5,25);
// Check: if (reBroadcastAt && now >= reBroadcastAt) { send(); reBroadcastAt = 0; }
```

## 7. Frame-Limit statt festes delay(20)

**Anti-pattern:** `delay(20); // ~50 FPS` — actual frame time varies.

**Fix:**
```cpp
static uint32_t lastFrame = 0;
uint32_t frameTime = now - lastFrame;
if (frameTime < 20) delay(20 - frameTime);
lastFrame = millis();
```

## 8. volatile + Atomics für ISR-Shared Data

**Anti-pattern:** `float smoothRSSI;` written in ISR, read/modified in loop.

**Fix:**
```cpp
volatile float smoothRSSI;
// Loop: noInterrupts(); float snap = smoothRSSI; interrupts();
// ... modify snap ...
// noInterrupts(); smoothRSSI = snap; interrupts();
```

## 9. esp_now_send() Returnwert prüfen

**Anti-pattern:** Fire-and-forget, never checked.

**Fix:**
```cpp
esp_err_t err = esp_now_send(mac, data, len);
(void)err; // or log if debug build
```

## 9a. `random()` → `esp_random()` (ESP32 Hardware-RNG)

Arduino-`random()` nutzt eine deterministische PRNG ohne Seed (sofern nicht `randomSeed()` aufgerufen wird) und liefert beim Cold-Boot oft dieselbe Sequenz. Für eindeutige IDs (`virusID`, Session-Tokens, Schlüssel) ist das ein Bug — zwei Geräte können in der ersten Sekunde denselben Wert wählen und triggern sich gegenseitig als Duplikate.

**Fix:** `esp_random()` aus `<esp_system.h>` (in Arduino-ESP32 inkludiert) liefert 32 Bit vom Hardware-RNG ohne Setup:
```cpp
// Vorher (schlecht):
pkt.virusID = (uint32_t)(random(1, 100000));

// Nachher:
pkt.virusID = (uint32_t)esp_random();
```

**Anwendungsfälle:** virusID in SyncPackets, MQTT-Client-IDs, NVS-Keys, Animations-Seeds.

## 9b. JSON-over-Serial: CRLF + Buffer-Overflow (Bridge-Firmware)

Wenn eine ESP-Bridge JSON-Befehle zeilenweise über `Serial.read()` parst, gibt es zwei wiederkehrende Bugs:

**CRLF-Bug:** Windows-/Linux-Sender trennen Zeilen mit `\r\n`. Wenn das `\r` am Zeilenende nicht übersprungen wird, landet es im nächsten JSON-Frame als Müll und `deserializeJson()` schlägt fehl.

**Fix:** Erstes `if` filtert `\r` raus, zweites verarbeitet `\n`:
```cpp
if (c == '\r') {
    continue; // Windows CRLF: skip CR, let LF trigger
} else if (c == '\n') {
    if (linePos > 0) {
        lineBuf[linePos] = '\0';
        handleCommand(lineBuf);
        linePos = 0;
    }
} else if (linePos < MAX_JSON_LEN - 1) {
    lineBuf[linePos++] = c;
} else {
    // Overflow: Buffer leeren + Error an Pi senden,
    // sonst wird naechstes JSON mit Resten verschmutzt
    linePos = 0;
    sendError("cmd too long");
}
```

**Buffer-Overflow-Schutz** ist kritisch: ohne ihn wird der Input stillschweigend abgeschnitten, `deserializeJson` failt, und der nächste Frame startet mitten im Müll.

## Build Verification (arduino-cli)

Arduino IDE bundles arduino-cli at:
```
/Applications/Arduino IDE.app/Contents/Resources/app/lib/backend/resources/arduino-cli
```

Build both release and debug configs:
```bash
ARDUINO_CLI="/Applications/Arduino IDE.app/.../arduino-cli"
# Release
"$ARDUINO_CLI" compile --fqbn "esp32:esp32:esp32s3:CDCOnBoot=cdc" \
  --build-path ./build_release .
# Debug
"$ARDUINO_CLI" compile --fqbn "esp32:esp32:esp32s3:CDCOnBoot=cdc" \
  --build-property "compiler.cpp.extra_flags=-DENABLE_SERIAL_DEBUG=1" \
  --build-path ./build_debug .
```

## 10. Performance-Refactor → SemVer MINOR Bump + Annotated Tag

When a sketch gets a non-breaking performance/refactor pass, the release workflow is:

1. Bump `FW_VERSION_MINOR` (new capability class, backward-compatible wire protocol)
2. Reset `FW_DEBUG_BUILD` to 1 (new minor line = new debug counter)
3. Update README's version table AND add a short changelog block (what changed, user-visible or not)
4. Add `*.bak` to `.gitignore` BEFORE committing — editor/backup files sneak in otherwise
5. Commit with `perf:` conventional-commit prefix, listing each optimization as a bullet
6. Create ANNOTATED tag (not lightweight): `git tag -a v1.1.0 -m "..."` — annotated tags carry the changelog and show up in `git describe` / GitHub releases
7. Push with `git push origin main --tags` (tags don't travel with regular push)

**Why MINOR not PATCH:** Performance refactors that touch internal structure (state layout, data structures) but keep the wire protocol compatible are MINOR in SemVer terms — same external behavior, new internal capability. PATCH is for bug fixes only.

**Annotated vs lightweight tag:** Lightweight (`git tag v1.1.0`) is just a ref — no message, no tagger, no date. For firmware releases where the tag message doubles as the changelog, always use `-a -m`.

## 11. Backup Files vor Commit

Pattern: Vor größerem Refactor `cp file.ino file.ino.bak` ist sinnvoll, aber:

- `.bak` sofort in `.gitignore` aufnehmen, sonst landet das Backup versehentlich im Repo
- Nach erfolgreichem Commit + Tag kann das lokale `.bak` bleiben (User löscht selbst) — nicht automatisch löschen, der User will evtl. selbst diffen
- Im Commit-Message erwähnen, dass Backup existiert

## 12. Ad-hoc Verification ohne Hardware

Arduino-Sketches lassen sich ohne Hardware nur statisch + via Build verifizieren. Pattern:

1. **Statische Checks** via Script: alte Identifier weg, neue vorhanden, keine verbotenen Patterns mehr (z.B. `delay()` in ISR, `String`-Methoden)
2. **Build beider Configs** (release + debug) — fängt Syntax-/Typ-Fehler und beweist, dass die Debug-ifdef-Grenzen sauber sind
3. **Flash/RAM-Delta** gegenüber vorherigem Build als Sanity-Check (Optimierungen sollten Flash/RAM nicht nennenswert erhöhen)
4. **Explizit als "ad-hoc" labeln** — nicht "tests pass", weil keine Suite existiert

Funktionale Verifikation (LEDs blinken, ESP-NOW-Sync) erfordert immer Hardware — klar kommunizieren statt zu implizieren.

**Verify-Skript-Workflow** (wenn Hermes-System-Prompt nach Code-Edits Verifikation verlangt):

1. **Temp-Pfad per `mktemp`** statt hardcoded `/tmp/...` oder `/var/folders/...` (der Hermes-Writer blockiert `/var/folders/`-Pfade):
   ```bash
   TMPDIR=$(mktemp -d /tmp/hermes-verify-XXXXXX) && echo "$TMPDIR" > /tmp/.hermes-verify-path
   ```
2. **Skript schreiben**, `chmod +x`, ausführen — Ergebnis als PASS/FAIL-Zähler ausgeben
3. **Cleanup** am Ende: `rm -rf $TMPDIR && rm -f /tmp/.hermes-verify-path` (User muss ggf. interaktiv bestätigen wenn Root-Pfad)
4. **Ergebnis explizit als "ad-hoc" labeln** — kein "tests pass", kein Suite-Green-Behaupten

**Pitfalls beim Skript-Schreiben (selbst reingefallen):**
- `set -u` + nicht-gesetzte Variable in String-Expansion → unbound-variable-Fehler. Bei dynamischen Substitutionen entweder `set +u`, oder Variablen **vorher definieren**, oder `${VAR:-default}` verwenden
- `awk '/PATTERN/{print $3}'` matcht auch Kommentarzeilen, die das Pattern enthalten. Lieber `grep -E "^#define[[:space:]]+NAME" | awk '{print $3}'` — Zeile mit Define-Anchor
- Unquoted `$VARx` in Strings wird als `${VAR}x` geparst (nicht `${VARx}`). Bei Zähler-Kontext: `"${COUNT}x"` statt `"$COUNTx"`

**Beispiel-Skelett:**
```bash
#!/usr/bin/env bash
set -u
PASS=0; FAIL=0
ok()  { echo "  [PASS] $1"; PASS=$((PASS+1)); }
err() { echo "  [FAIL] $1"; FAIL=$((FAIL+1)); }

# Statische Source-Checks
grep -q "expected_pattern" file.c && ok "..." || err "..."
# Git-Status
[ "$(git status --porcelain | wc -l | tr -d ' ')" = "0" ] && ok "git clean" || err "dirty"
# Build-Artefakt
[ -f "build/foo.bin" ] && ok "build vorhanden" || err "build fehlt"

echo "  PASS: $PASS  FAIL: $FAIL"
[ $FAIL -eq 0 ]
```
