---
name: cross-platform-hermes-sync
description: "Sync Hermes config/skills between Mac and Windows."
version: 1.0.0
---

# Cross-Platform Hermes Sync

Use when: syncing Hermes settings between machines (macOS ↔ Windows), migrating a dotfiles/hermes repo across platforms, or setting up a second machine with existing Mac config.

## Step 1 — Identify What to Share vs Keep Local

### SHARED (safe to copy):
- `config.yaml` — all settings EXCEPT platform-specific keys (see below)
- `.env` — API keys are platform-independent
- `skills/` — entirely platform-agnostic (Markdown + Python scripts)
- `cron/` — job definitions (but not execution history)
- `memories/` — USER.md + MEMORY.md

### NEVER SYNC (local-only per machine):
```
state.db                          ← Chat history (SQLite)
sessions/                         ← All conversations
logs/                             ← Log files
cache/ audio_cache/ image_cache/  ← Regeneratable binaries
auth.json                         ← OAuth tokens, session-scoped
kanban.db projects.db             ← State databases
*.lock                            ← File locks
pairing/                          ← Device pairings
pastes/                           ← Clipboard transfers
docker-config*                    ← Machine-specific Docker state
```

### Create a proper .gitignore:
```
.env
auth.json
auth.lock
state.db
state.db-shm
state.db-wal
verification_evidence.db
projects.db
kanban.db
kanban.db.init.lock
sessions/
logs/
cache/
audio_cache/
image_cache/
bootstrap-cache/
models_dev_cache.json
provider_models_cache.json
update_info.json
.update_check
.update_exit_code
.pairing/pairing-state.jsonl
*paste*.jsonl
*.lock
.DS_Store
Thumbs.db
desktop/
bin/hermes-setup.exe
```

## Step 2 — Handle Platform-Specific Differences

In `config.yaml`, these keys differ between OS:

| Key | macOS value | Windows fix |
|-----|-------------|-------------|
| `terminal.cwd` | `.` or `/Users/x/Projekte` | Use absolute Windows path like `C:\Users\wasi\Documents` OR just `.` to avoid MSYS translation issues |
| `browser.engine` | May have extra engines (safari-stp) | Remove non-Windows browser engines |
| `base_url` (model) | Varies by provider | Keep as-is unless switching providers |
| `command_allowlist` | Security rules — keep same | No change needed |
| `mcp_servers` | Blender/Safari/Chrome paths break | **Remove platform-specific servers**; add only Windows-compatible ones |

## Step 3 — Apply Config Changes

**DO NOT directly write to `config.yaml`.** The security guard blocks it. Instead:

```bash
hermes config set model.default "your-model"
hermes config set model.base_url "https://example.com"
hermes config set model.provider "openai"
hermes config set terminal.cwd "C:\\Users\\wasi\\Documents"
```

To see what changed: read `~/.hermes/config.yaml` before and after each call, or use `diff`.

## Step 4 — Copy Missing Skills from Source Repo

When the source Mac has skills not yet on target Windows:

```python
# 1. Clone / download the dotfiles tarball
curl -L https://github.com/<owner>/dotfiles/archive/refs/heads/main.tar.gz > /tmp/dotfiles.tar.gz

# 2. Extract it
tar xzf /tmp/dotfiles.tar.gz -C /tmp/

# 3. Find and copy missing skills
SRC_EXTRACTED=/tmp/dotfiles-main/hermes/skills
DST_BASE=~/.hermes/skills  # or C:\Users\wasi\AppData\Local\hermes\skills

for skill_dir in "$SRC_EXTRACTED"/*/; do
    name=$(basename "$skill_dir")
    if [ ! -d "$DST_BASE/$name" ]; then
        cp -rp "$skill_dir" "$DST_BASE/"
        echo "Installed: $name"
    fi
done
```

List missing skills first with diff:
```bash
diff <(cd mac_skills && find . -type d | sort) \
     <(cd win_skills && find . -type d | sort) | grep "^<"
```

## Pitfalls

1. **terminal.cwd on Windows is often broken** — values like `.D:\...` or mixed Unix/Windows paths cause `Exit 126` errors. Use clean absolute `C:\Users\xxx` paths or `.`.
2. **`.gitignore` is usually too sparse** on macOS dotfiles repos (often just `.DS_Store`). Add state.db, sessions/, caches/, *.lock, etc. before committing to git.
3. **MCP servers with hardcoded paths** (e.g., Safari driver on `/Applications/`) will fail silently on other platforms. Comment them out or remove before sharing.
4. **Skills with shell scripts** may need shebang adjustments (`#!/bin/bash` → WSL/bash compatibility). Check any `scripts/` dirs in copied skills.
5. **Don't mix profiles** — each profile in `profiles/<name>/` is independent. Only merge config.yaml and skills at the root level, not per-profile state.

## Verification

After sync, run:
```bash
hermes doctor          # health check
hermes config check    # report missing/extra sections
ls ~/.hermes/skills/   # verify new skills landed
```
