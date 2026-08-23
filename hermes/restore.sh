#!/bin/bash
# Restore Hermes data from dotfiles repo
set -e

HERMES_DIR="$HOME/.hermes"
DOTFILES_DIR="$HOME/dotfiles"
BACKUP_DIR="$DOTFILES_DIR/hermes"

echo "Restoring Hermes data from $BACKUP_DIR"

# Ensure backup directory exists
if [ ! -d "$BACKUP_DIR" ]; then
    echo "Backup directory not found. Aborting."
    exit 1
fi

# Restore directories additively; never delete local or repository files.
rsync -av --exclude='*.db' --exclude='*.db-*' --exclude='*.log' --exclude='*.lock' --exclude='cache' --exclude='image_cache' --exclude='audio_cache' --exclude='pastes' --exclude='sessions' --exclude='state-snapshots' --exclude='logs' --exclude='node_modules' \
    "$BACKUP_DIR/skills/" "$HERMES_DIR/skills/"

rsync -av --exclude='*.db' --exclude='*.db-*' --exclude='*.log' \
    "$BACKUP_DIR/memories/" "$HERMES_DIR/memories/"

rsync -av \
    "$BACKUP_DIR/cron/" "$HERMES_DIR/cron/"

rsync -av \
    "$BACKUP_DIR/plugins/" "$HERMES_DIR/plugins/"

# Restore config.yaml if exists in backup
if [ -f "$BACKUP_DIR/config.yaml" ]; then
    cp -p "$BACKUP_DIR/config.yaml" "$HERMES_DIR/config.yaml"
fi

echo "Restore completed. You may need to restart Hermes for changes to take effect."