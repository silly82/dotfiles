# Firmware Versioning: A.B.C.D Schema with Git-Tag-Only Build Counter

A versioning scheme for embedded/firmware projects where you want SemVer-like semantics but need a per-commit build number (typical when you want to know "exactly which commit is on a device" without bumping a code define on every commit).

## The Problem

Classic SemVer (MAJOR.MINOR.PATCH) and Arduino's `FW_VERSION_MAJOR/MINOR/PATCH` only give you three slots. For firmware you often want:

- **A** = breaking change (rare, explicit)
- **B** = large feature (new protocol, new mode, big UI)
- **C** = small feature / refactor / bugfix
- **D** = build number — which exact commit is on the chip

If you put D in the code, every commit needs a recompile, and the firmware version stamp becomes noise. If you don't track D, you can't answer "what commit is on badge #5?"

**Solution:** A.B.C lives in the code (via `#define`), D lives in Git tags only.

## Schema

| Field | Source | When to bump |
|-------|--------|--------------|
| **A** `FW_VERSION_MAJOR` | Sketch `#define` | Only on explicit request (breaking change, protocol overhaul) |
| **B** `FW_VERSION_MINOR` | Sketch `#define` | Large feature (e.g. new ESP-NOW mode, new protocol) — discuss before merge |
| **C** `FW_VERSION_PATCH` | Sketch `#define` | Small feature, refactor, bugfix — discuss before merge, max 99 |
| **D** | **Git tag only** — `v1.2.0.5` = 5 commits since `v1.2.0.0` | Auto-incremented on every commit, encoded in the tag suffix |

The code stays at `1.2.0`. Git tags carry the build number: `v1.2.0.0` is the first tag at this A.B.C, `v1.2.0.1` is the next commit, etc.

## Wire Format Constraint

ESP-NOW / BLE / LoRa packets are tiny. If you broadcast a 4-byte version stamp, the four bytes are precious — usually you only have room for A, B, C plus a debug-flag byte:

```c
struct __attribute__((packed)) SyncPacket {
    uint32_t magic_id;
    uint32_t beatCounter;
    uint32_t virusID;
    uint8_t  mode;
    uint8_t  ver_major;   // A
    uint8_t  ver_minor;   // B
    uint8_t  ver_rel;     // C (release), or 0 if debug
    uint8_t  ver_dbg;     // DEBUG_BUILD (1..99) or 0 if release
    // D=BUILD is NOT in the packet — it's a Git-tag concept
};
```

Document the omission in the packet comment: `// D (Build) wird NICHT per Funk gesendet — nur in Git-Tags gefuehrt (Platz + Kabel-Last).`

## Display Rules

- **Release build** (`ENABLE_SERIAL_DEBUG=0`): show `M.N.C` — e.g. `1.2.0`
- **Debug build** (`ENABLE_SERIAL_DEBUG=1`): show `M.N.DD+debug` — e.g. `1.2.05+debug` (DD = zero-padded `FW_DEBUG_BUILD`, 01..99)
- **Git tag** for this A.B.C release: `vA.B.C.D` — e.g. `v1.2.0.0` is the first tag at A.B.C=1.2.0, `v1.2.0.5` is the 6th commit (D counts from 0)

The `M.N.DD+debug` format is the standard pattern in Arduino projects: it uses the **same M.N slot** but replaces PATCH with the debug counter, and signals debug status with the `+debug` suffix.

## Versioning Helper Script (`scripts/version.sh`)

A small bash helper that reads A.B.C from the `.ino` and manages the D-counter via Git tags. Reusable pattern — copy and adapt the `read_ino_define` function for any sketch that uses `FW_VERSION_MAJOR/MINOR/PATCH`.

```bash
#!/usr/bin/env bash
# scripts/version.sh — A.B.C.D Versions-Helper
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKETCH="${REPO_ROOT}/Herz_Schwarm_CCC_V.ino"

read_ino_define() {
  local key="$1"
  awk -F'[[:space:]]+' "/^#define[[:space:]]+${key}[[:space:]]+/ {print \$3; exit}" "$SKETCH" | tr -d '\r'
}

current_abc() {
  local maj min pat
  maj=$(read_ino_define FW_VERSION_MAJOR)
  min=$(read_ino_define FW_VERSION_MINOR)
  pat=$(read_ino_define FW_VERSION_PATCH)
  echo "${maj}.${min}.${pat}"
}

last_abc_tag() {
  git tag --list "v${1}.*" --sort=-version:refname | head -1
}

next_tag() {
  local abc="$1"
  local last
  last=$(last_abc_tag "$abc")
  if [[ -z "$last" ]]; then
    echo "v${abc}.0"
    return
  fi
  local d="${last##*.}"
  echo "v${abc}.$((d + 1))"
}

case "${1:-}" in
  current)    current_abc ;;
  next-tag)   next_tag "$(current_abc)" ;;
  since)
    [[ -z "${2:-}" ]] && { echo "Usage: scripts/version.sh since v1.2.0.0" >&2; exit 1; }
    git log --oneline "${2}..HEAD" | wc -l | tr -d ' '
    ;;
  tag)
    local abc; abc=$(current_abc)
    local tag; tag=$(next_tag "$abc")
    git tag -a "$tag" -m "Release $tag (A.B.C = $abc)"
    ;;
  -h|--help) cat <<'USAGE'
Usage: scripts/version.sh {current|next-tag|since REF|tag}
USAGE
    ;;
  *) echo "Unknown: ${1:-}" >&2; exit 1 ;;
esac
```

**Usage:**

```bash
scripts/version.sh current       # → 1.2.0
scripts/version.sh next-tag      # → v1.2.0.5  (5 commits since v1.2.0.0)
scripts/version.sh since v1.1.0  # → 17
scripts/version.sh tag           # creates v1.2.0.N annotated tag
git push origin v1.2.0.5
```

## Migration From Existing SemVer

If you already have tags like `v1.0.0` and `v1.1.0` (no D), pick the latest as the baseline and treat it as the implicit `v1.1.0.0`:

1. Read the current A.B.C from the sketch
2. Run `scripts/version.sh tag` — it creates `v1.2.0.0` (or whatever A.B.C is current)
3. Going forward, every release gets a `vA.B.C.D` tag

The old `v1.0.0` / `v1.1.0` tags stay valid — they're just `vA.B.C.0` tags with D=0 implicit.

## Decision Tree for Bumping

```
Code change ready to merge?
|
+-- Architecture overhaul / breaking protocol change
|   -> bump A. Set A=2, B=C=0. Next tag: v2.0.0.0
|
+-- New ESP-NOW mode / new effect / new protocol
|   -> bump B. Set B=N+1, C=0. Next tag: vN.0.0.0
|
+-- New small feature / refactor
|   -> bump C. Set C=current+1, B unchanged. Next tag: vM.N.C.0
|
+-- Bugfix / typo
    -> no bump in code, but tag still increments D
    -> git tag vM.N.C.(D+1) and push
```

Discuss before merge: A and B. C is OK on the fly as long as it's tracked. D never needs discussion — it's just the commit count.

## Common Pitfalls

1. **Don't put D in `#define`.** Either you recompile on every commit (annoying), or the code-defined D drifts from the Git tag (confusing). Let Git own D.
2. **Don't mix `vA.B.C` and `vA.B.C.D` tags.** Pick one format and stick to it. The helper script enforces `vA.B.C.D` for new tags.
3. **Don't reset D manually.** D is monotonically increasing per A.B.C. When you bump A or B, D naturally resets to 0 with the new tag.
4. **Debug-build counter (`FW_DEBUG_BUILD`) is separate from D.** Debug builds keep their own 01..99 counter for the same A.B.C. Don't conflate the two.
5. **README version table must show the current A.B.C, not A.B.C.D** — readers care about feature level, not commit count.
