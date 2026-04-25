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

## kitty (macOS, XDG)

| Rolle | Pfad |
|--------|------|
| Konfigurationsverzeichnis (Standard) | `~/.config/kitty/` |

In diesem Repo: **`kitty/xdg/`** = Inhalt des Kitty-Config-Ordners (u. a. `kitty.conf`).

- **Farben** entsprechen **Ghostty „Hard Neon Pink“** (Dark/Light), inkl. 16-ANSI-Farben, Hintergrund/Deckkraft, Blur, Cursor, Selektion, Tab-Leiste, sowie `text_fg_override_threshold` (Parallele zu `minimum-contrast` in Ghostty: 3.5 / 3.0 `ratio`).
- **Kitty 0.38+:** `dark-theme.auto.conf` / `light-theme.auto.conf` wechseln mit **macOS Hell/Dunkel**; `no-preference-theme.auto.conf` inkludiert derzeit dasselbe wie Dark.
- `kitty.conf`: Schrift (JetBrains Mono, 15), Padding 14, Tasten, `mouse_hide_wait -1` (Maus blendet beim Tippen ein), kein doppelter Farb-Block in der Hauptdatei (Farben in den `*-theme.auto.conf`).

### Neu aufsetzen

1. [kitty](https://sw.kovidgoyal.net/kitty/) installieren.
2. Repo wie oben klonen.
3. Evtl. altes `~/.config/kitty` sichern, dann:  
   `ln -sfn "$HOME/dotfiles/kitty/xdg" "$HOME/.config/kitty"`
4. Ghostty-Repo ist die Referenz: Änderungen an `ghostty/…/Hard Neon Pink *` ggf. hier nachziehen (Dark-Datei `dark-theme.auto.conf`, Light-Datei `light-theme.auto.conf`).

## Shell (zsh / macOS `ls`)

Für farbiges `ls` nutzt macOS **`LSCOLORS`** (nicht `LS_COLORS`). Das System-Default enthält **braun** (`d`) als Farbe — wirkt oft wie schmutzige Flächen. Anpassung: `shell/macos-lscolors.zsh` (wird von `~/.zshrc` gesourct, Pfad zu `~/dotfiles`).
