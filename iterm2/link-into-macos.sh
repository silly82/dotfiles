#!/bin/sh
# Symlinks die .itermcolors ins iTerm2 Application Support, damit Import/Pfad
# stabil neben dem Repo bleibt (Doppelklick auf die Datei → iTerm2-Import).
set -e
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
DEST="${HOME}/Library/Application Support/iTerm2/ColorSchemes"
mkdir -p "$DEST"
for f in "Hard Neon Pink Dark.itermcolors" "Hard Neon Pink Light.itermcolors"; do
	ln -sfn "$REPO_DIR/$f" "$DEST/$f"
	printf '%s\n' "→ $DEST/$f"
done
