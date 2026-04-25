# dotfiles

Persönliche Konfiguration, versioniert. In dieser Datei: keine Zugangsdaten, keine Tokens, keine persönlichen Kontaktdaten.

## Ghostty (macOS)

### Speicherorte (wo Ghostty auf macOS liest)

| Rolle | Pfad |
|--------|------|
| Hauptkonfiguration | `~/Library/Application Support/com.mitchellh.ghostty/config` |
| Themes, Shader, ggf. weiteres (XDG) | `~/.config/ghostty/` (Unterordner `themes/`, `shaders/`, …) |

Dieses Repo hält die **Quelldateien** unter `ghostty/`. An den obigen Stellen liegen **Symlinks** ins Repo, damit Ghostty unverändert funktioniert.

### Struktur im Repo

- `ghostty/app-support/config` → Ziel: App-Support-Pfad (siehe Tabelle)
- `ghostty/xdg/` → Inhalt spiegelt `~/.config/ghostty` (z. B. `themes/`, `shaders/`)

### Neu aufsetzen (neuer Mac, kein altes `~/`-Backup nötig)

1. [Ghostty](https://ghostty.org) installieren.
2. Dieses Repository klonen, z. B.:
   - `git clone <Repository-URL> ~/dotfiles`
3. Zielverzeichnisse anlegen, falls nicht vorhanden:
   - `mkdir -p ~/Library/Application\ Support/com.mitchellh.ghostty`
   - `mkdir -p ~/.config`
4. **Keine** bestehende Konfiguration überschreiben, ohne es zu wollen. Falls an den Standardpfaden schon Dateien/Ordner liegen, zuerst sichern oder entfernen, dann:
   - Symlink zur Haupt-Config:
     - `ln -sf "$HOME/dotfiles/ghostty/app-support/config" "$HOME/Library/Application Support/com.mitchellh.ghostty/config"`
   - Symlink für `~/.config/ghostty` (nur wenn der Pfad frei ist oder ersetzen soll):
     - `ln -sfn "$HOME/dotfiles/ghostty/xdg" "$HOME/.config/ghostty"`
5. Pfade in `config` (Schriften, Theme-Namen) an die neue Umgebung anpassen, falls nötig.

**Git:** Commit-Autor in der Historie hängt von deiner lokalen `git config` ab — dazu gehört kein Muss, das hier zu dokumentieren.
