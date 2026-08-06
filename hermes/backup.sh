#!/bin/bash
# Backup Hermes data to dotfiles repo
set -e

HERMES_DIR="$HOME/.hermes"
DOTFILES_DIR="$HOME/dotfiles"
BACKUP_DIR="$DOTFILES_DIR/hermes"

echo "Backing up Hermes data to $BACKUP_DIR"

# Create backup directory structure
mkdir -p "$BACKUP_DIR"/{skills,memories,cron,plugins}

# Sync directories additively; never delete files from the repository.
rsync -av --exclude='*.db' --exclude='*.db-*' --exclude='*.log' --exclude='*.lock' --exclude='cache' --exclude='image_cache' --exclude='audio_cache' --exclude='pastes' --exclude='sessions' --exclude='state-snapshots' --exclude='logs' --exclude='node_modules' \
    "$HERMES_DIR/skills/" "$BACKUP_DIR/skills/"

rsync -av --exclude='*.db' --exclude='*.db-*' --exclude='*.log' \
    "$HERMES_DIR/memories/" "$BACKUP_DIR/memories/"

rsync -av \
    "$HERMES_DIR/cron/" "$BACKUP_DIR/cron/"

rsync -av \
    "$HERMES_DIR/plugins/" "$BACKUP_DIR/plugins/"

# Copy config.yaml if exists
if [ -f "$HERMES_DIR/config.yaml" ]; then
    cp -p "$HERMES_DIR/config.yaml" "$BACKUP_DIR/config.yaml"
fi

# Git operations
cd "$DOTFILES_DIR"
git add hermes/
if git diff --cached --quiet; then
    echo "No changes to commit."
else
    git commit -m "Hermes backup $(date '+%Y-%m-%d %H:%M:%S')"
    git push origin main
    echo "Backup committed and pushed."
fi