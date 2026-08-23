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

## iTerm2 (Color Presets, wie Ghostty „Hard Neon Pink“)

| Datei im Repo | Entspricht |
|---------------|------------|
| `iterm2/Hard Neon Pink Dark.itermcolors` | `ghostty/.../Hard Neon Pink Dark` (ANSI, Hintergrund, Vordergrund, Cursor, Selektion) |
| `iterm2/Hard Neon Pink Light.itermcolors` | `.../Hard Neon Pink Light` |

**Lokales iTerm2-Verzeichnis (Symlinks ins Repo):** iTerm2 hat keinen offiziell überwachten Preset-Ordner; sinnvoll ist `~/Library/Application Support/iTerm2/ColorSchemes/`. Symlinks anlegen: `./iterm2/link-into-macos.sh` ausführen (legt die beiden `*.itermcolors` dorthin, zeigt ins Dotfiles-Repo). Danach: im Finder in diesen Ordner wechseln und eine Datei doppelklicken **oder** *Settings → Profile → Colors → Color Presets → Import…* und die Datei aus genau diesem Ordner wählen.

**Import:** *iTerm2* → *Einstellungen* / *Settings* → *Profile* → Reiter *Farben* / *Colors* → *Color Presets* → *Import…* → gewünschte `*.itermcolors` wählen → im gleichen Menü *Color Presets* das importierte Set auf das Profil anwenden.

**Hinweis:** Transparenz/Blur/Shader wie in Ghostty gibt es in iTerm2 **nicht 1:1**; ggf. unter *Fenster* / *Window* (Transparenz, Hintergrund unscharf) manuell annähern. **Schrift** separat: z. B. *JetBrains Mono* Größe **15** wie in `ghostty/app-support/config`.

## Shell (zsh / macOS `ls`)

Für farbiges `ls` nutzt macOS **`LSCOLORS`** (nicht `LS_COLORS`). Das System-Default enthält **braun** (`d`) als Farbe — wirkt oft wie schmutzige Flächen. Anpassung: `shell/macos-lscolors.zsh` (lokal: in `~/.zshrc` per `source` einbinden). **Vorlage:** `shell/zshrc.fragment` (Zeilen in die eigene `~/.zshrc` übernehmen).

## uConsole CM4 (Debian 13 trixie, Sway/Wayland)

Persönliche Sway/Wayland-Konfiguration für den ClockworkPi uConsole mit **Raspberry Pi CM4** (Debian, apt-verwaltet). **Nicht zu verwechseln** mit dem separaten uConsole-**CM5**-Gerät, das unter NixOS läuft und komplett im Repo `nixos-config` deklariert ist (`hosts/uconsole-cm5/configuration.nix`) — zwei unterschiedliche Geräte, zwei unterschiedliche Konfigurationswege (dieses hier: plain dotfiles + apt; CM5: deklarativ via Nix).

| Rolle | Pfad auf dem Gerät | Repo-Pfad |
|---|---|---|
| Sway-Config | `~/.config/sway/config` | `uconsole-cm4/sway/config` |
| Wallpaper (Shortcut-Übersicht) | `~/.config/sway/wallpaper.png` | `uconsole-cm4/sway/wallpapers/wallpaper.png` |
| Waybar-Config | `~/.config/waybar/` | `uconsole-cm4/waybar/` |
| greetd-Login (cage + gtkgreet) | `/etc/greetd/config.toml`, `/etc/greetd/environments`, `/usr/local/bin/greetd-gtkgreet-run` | `uconsole-cm4/greetd/` |
| Raspberry Pi Connect wayvnc-Override | `~/.config/systemd/user/rpi-connect-wayvnc.service.d/` | `uconsole-cm4/systemd/user/rpi-connect-wayvnc.service.d/` |

### Eckdaten

- Panel-Rotation: DSI-1, `transform 270` (cage) / `transform 90` (Sway), Scale 1.5 → ~853×480.
- Alt-Taste als Super (`$mod` = Mod4 via `altwin:swap_lalt_lwin`) — uConsole hat keine Win-Taste.
- Login-Screen: greetd + gtkgreet + cage, Session-Auswahl (sway, labwc, bash).
- Waybar mit Nerd-Font-Icons (WLAN, Lautstärke, Helligkeit, Akku); wird von Sway bei `$mod+Shift+c` automatisch mitneugestartet.

### Neu aufsetzen

Abhängigkeiten (apt, nicht Nix):

    sudo apt-get install -y sway waybar mako fuzzel foot brightnessctl pipewire \
                            greetd gtkgreet cage iwgtk network-manager
    mkdir -p ~/.local/share/fonts
    cd ~/.local/share/fonts
    curl -sL https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/NerdFontsSymbolsOnly.zip -o symbols.zip
    unzip -qo symbols.zip && fc-cache -fv

Configs übernehmen:

    ln -sfn ~/dotfiles/uconsole-cm4/sway ~/.config/sway
    ln -sfn ~/dotfiles/uconsole-cm4/waybar ~/.config/waybar
    sudo cp ~/dotfiles/uconsole-cm4/greetd/greetd-gtkgreet-run /usr/local/bin/
    sudo cp ~/dotfiles/uconsole-cm4/greetd/config.toml /etc/greetd/
    sudo cp ~/dotfiles/uconsole-cm4/greetd/environments /etc/greetd/
    mkdir -p ~/.config/systemd/user
    ln -sfn ~/dotfiles/uconsole-cm4/systemd/user/rpi-connect-wayvnc.service.d ~/.config/systemd/user/rpi-connect-wayvnc.service.d
    systemctl --user daemon-reload

`_greetd`-Benutzer berechtigen (wichtig!):

    sudo usermod -aG video,input,render _greetd

Display-Manager umstellen:

    sudo systemctl stop lightdm
    sudo systemctl disable lightdm
    sudo ln -sf /lib/systemd/system/greetd.service /etc/systemd/system/display-manager.service
    sudo systemctl daemon-reload
    sudo systemctl enable --now greetd

Details zu 4G/LTE-Modul, WLAN-Signalverbesserung, SD-Karten-Automount etc.: siehe Git-Historie von `github.com/silly82/uconsole-dotfiles` (archiviert, Inhalt hier übernommen).
