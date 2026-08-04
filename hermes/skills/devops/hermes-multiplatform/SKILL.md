---
name: hermes-multiplatform
description: "Hermes cross-platform config sync and migration."
version: 1.0.0
author: hermes-curator
---

# Hermes Multi-Platform Sync

Use when: managing Hermes settings across multiple OSes, migrating between Mac/Windows/Linux, or setting up dotfile-driven config sync with proper platform isolation.

## Problem

Hermes uses `~/.hermes/` as its home directory. Different platforms have different path conventions, binary formats, and runtime artifacts. Naive cloning/syncing causes breakage from stale databases, wrong path separators, and locked files.

## Solution: Two-Layer Separation

### Layer 1 — Share via Dotfiles (Git)

These files are platform-agnostic text configs: safe to version-control and sync freely.

| File | What it contains |
|------|-----------------|
| `config.yaml` | Model, agent, display, memory, toolset settings |
| `.env` | API keys, provider credentials |
| `skills/` | All SKILL.md, references/, scripts/, templates/ |
| `desktop-plugins/` | UI plugin source files |
| `cron/` | Recurring job definitions (but NOT executions.db!) |
| `memories/MEMORY.md`, `USER.md` | Persistent memory content |

### Layer 2 — Local Only (`.gitignore`)

These MUST stay on each machine. Never commit, never overwrite from remote.

```
state.db*                    # Session store (SQLite + WAL)
kanban.db*                   # Kanban board state
projects.db                  # Named project workspace registry
verification_evidence.db     # Verification proofs
sessions/*                   # Chat transcripts
logs/*                       # Runtime logs
cache/*                      # Model, image, update caches
audio_cache/*                # TTS audio output
image_cache/*                # Processed images
bootstrap-cache/*            # Installer cache
bin/*                        # Platform-specific binaries (.exe, etc.)
auth.json                    # OAuth tokens (session-scoped)
pairing/*                    # Device pairing info
pastes/*                     # Clipboard temp data
desktop/*                    # Desktop app build state
*.lock                       # Lock files
.DS_Store                    # macOS trash
Thumbs.db                    # Windows trash
*.db-wal *.db-shm            # SQLite journal files
models_*.json                # Provider model caches
update_check                 # Update state
*-build-stamp.json           # Build completion markers
```

## Migration Steps

### Pre-flight: Inventory both sides

```bash
# On Mac:
ls -la ~/.hermes/
find ~/.hermes/skills/ -maxdepth 1 -type d | sort

# On target platform:
ls -la $HOME/AppData/Local/hermes/   # Windows
# or
ls -la ~/.hermes/                    # Linux
```

### Step 1: Create .gitignore FIRST

Before adding ANY Hermes files to Git, ensure the gitignore filters local-only files. Use the template in `references/gitignore-template.md`.

### Step 2: Merge config.yaml

Compare the shared config files line by line. Key cross-platform concerns:

- **`terminal.cwd`**: Mac may use Unix paths (`~/Projects`), Windows needs native (`C:\Users\...`). Either set to `.` (current dir) or use platform-aware values. A broken value like `.D:\Benutzer\...` will crash the terminal toolset.
- **`browser.engine`**: Mac likely has Chrome/Safari; Windows also supports Chrome but paths differ for MCP servers.
- **`MCP servers`**: Safari/Chrome debug endpoints use absolute paths that are platform-specific. Comment out platform-incompatible MCP entries.
- **`timezone`**: May need per-platform override (`MEZ` vs `America/New_York`).
- **`known_plugin_toolsets`**: Plugin availability varies per platform. Remove unavailable plugins.

### Step 3: Copy skills selectively

Not all skills work on every platform. Apple-specific skills (`apple/apple-notes`, `apple/imessage`, `apple/findmy`) only work on macOS. Filter them out for Windows/Linux targets. Check each skill's `SKILL.md` for platform metadata.

### Step 4: Copy .env carefully

API keys are generally platform-neutral. However:
- Local model paths (Ollama, local Whisper) may differ
- Docker-related env vars may not apply on Windows without WSL/Docker Desktop
- Review any `HOME`, `PATH`, or filesystem-root overrides

### Step 5: Do NOT copy runtime state

NEVER copy: `state.db`, `sessions/`, `logs/`, `cache/`, `auth.json`. These are local to each machine and contain session-specific data.

### Step 6: Restore/backup on target

After merging, run:
```bash
hermes doctor          # Health check the merged config
hermes config check    # Report sections missing from newer versions
hermes --continue      # Verify sessions load cleanly
```

## Common Pitfalls

- **Broken `terminal.cwd`**: Value with mixed prefix like `.D:\...` — the `.` prepended accidentally or via a shell expansion bug. Fix: set to `.` or the correct absolute path for the platform.
- **SQLite database corruption**: If you accidentally copy `state.db` from another platform, the new instance may fail to read old sessions. The fix is to delete the copied DB and start fresh (old sessions live in `$HERMES_HOME/sessions/*.jsonl` if needed).
- **MCP server paths**: `/Applications/Safari Technology Preview...` on Mac won't work on Windows. Comment out or conditionally enable.
- **Line endings**: YAML on Windows may get CRLF line endings. Ensure consistent LF endings for reproducibility. Use `git config core.autocrlf true` (Windows → LF in repo).
- **Hidden files**: Many lock/state files start with `.` (e.g., `.curator_backups`, `.hub`, `.usage.json`). Decide per-file whether they should be tracked (usually not).

## Cron Job Safety

When syncing cron configs between machines:
- `executions.db` and `ticker_*` files are runtime state — DO NOT SYNC
- Only the cron definition files (if any plain-text configs exist alongside) should be synced
- Cron jobs with platform-specific scripts or paths will fail on the other platform

## Memory & Profile Sync

Memory files (`memories/MEMORY.md`, `memories/USER.md`) ARE safe to sync — they're plain markdown text with no platform dependencies. Profile directories (`profiles/<name>/`) follow the same rule: their `config.yaml` is shared-safe, but their `state.db` and `sessions/` subdirectories are not.
