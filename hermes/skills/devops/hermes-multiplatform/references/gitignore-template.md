# === Sensitive / Secrets ===
.env
auth.json
auth.lock

# === Database / State (platform-local) ===
state.db
state.db-shm
state.db-wal
verification_evidence.db
projects.db
kanban.db
kanban.db.init.lock

# === Session transcripts & logs ===
sessions/
logs/
session_backup_*.jsonl

# === Caches (large, regenerated) ===
cache/
audio_cache/
image_cache/
bootstrap-cache/
models_dev_cache.json
ollama_cloud_models_cache.json
provider_models_cache.json
update_info.json
.update_check
.update_exit_code
.desktop-build-stamp.json
.web-ui-build-stamp.json

# === Docker / Sandbox ===
bin/hermes-setup.exe

# === Pairing & Temporary files ===
pairing/
pastes/

# === Lock files (local-only) ===
*.lock

# === Platform-specific temp files ===
.DS_Store
Thumbs.db
desktop/
