#!/usr/bin/env bash
# Synchronisiert sichere Hermes-Dateien von Windows ins Dotfiles-Repo und pusht Änderungen.
set -Eeuo pipefail

HERMES_DIR="/c/Users/wasi/AppData/Local/hermes"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
BACKUP_DIR="$REPO_DIR/hermes"

if [[ ! -d "$HERMES_DIR" ]]; then
  echo "FEHLER: Hermes-Verzeichnis nicht gefunden: $HERMES_DIR" >&2
  exit 1
fi
if [[ ! -d "$REPO_DIR/.git" ]]; then
  echo "FEHLER: Git-Repository nicht gefunden: $REPO_DIR" >&2
  exit 1
fi

mkdir -p "$BACKUP_DIR/skills" "$BACKUP_DIR/memories" "$BACKUP_DIR/cron" "$BACKUP_DIR/plugins" "$BACKUP_DIR/skins"

# Nur gemeinsam nutzbare Daten synchronisieren. Keine Secrets, Sessions, Logs oder Caches.
rm -rf "$BACKUP_DIR/skills" "$BACKUP_DIR/memories" "$BACKUP_DIR/cron" "$BACKUP_DIR/plugins" "$BACKUP_DIR/skins"
mkdir -p "$BACKUP_DIR/skills" "$BACKUP_DIR/memories" "$BACKUP_DIR/cron" "$BACKUP_DIR/plugins" "$BACKUP_DIR/skins"
cp -a "$HERMES_DIR/skills/." "$BACKUP_DIR/skills/"
[[ -d "$HERMES_DIR/memories" ]] && cp -a "$HERMES_DIR/memories/." "$BACKUP_DIR/memories/" || true
[[ -d "$HERMES_DIR/cron" ]] && cp -a "$HERMES_DIR/cron/." "$BACKUP_DIR/cron/" || true
[[ -d "$HERMES_DIR/plugins" ]] && cp -a "$HERMES_DIR/plugins/." "$BACKUP_DIR/plugins/" || true
[[ -d "$HERMES_DIR/skins" ]] && cp -a "$HERMES_DIR/skins/." "$BACKUP_DIR/skins/" || true
cp -f "$HERMES_DIR/config.yaml" "$BACKUP_DIR/config.yaml"

cat > "$BACKUP_DIR/.gitignore" <<'EOF'
.env
auth.json
auth.lock
*.db
*.db-*
*.lock
sessions/
logs/
cache/
audio_cache/
image_cache/
bootstrap-cache/
models_dev_cache.json
provider_models_cache.json
# User-defined Hermes skins are safe to version

update_info.json
EOF

cd "$REPO_DIR"
git add hermes/
if git diff --cached --quiet; then
  echo "Keine Änderungen zum Committen."
else
  git commit -m "Sync Hermes Windows $(date '+%Y-%m-%d %H:%M:%S')"
  git push origin main
  echo "Synchronisierung und Push erfolgreich."
fi

echo
echo "Repo-Status:"
git status --short --branch
read -r -p "Enter drücken zum Schließen..." _

trap 'echo; echo "FEHLER bei Zeile $LINENO. Die Änderungen wurden nicht automatisch zurückgerollt."; read -r -p "Enter drücken zum Schließen..." _' ERR

git status --short --branch >/dev/null
