# uConsole dotfiles — version control workflow

This user (silly82) maintains their uConsole config as a public GitHub repo:

**Repo:** `https://github.com/silly82/uconsole-dotfiles`
**Local path:** `~/uconsole-dotfiles/` on the device
**Branch:** `main`

## After every config change on the uConsole

When you modify any of these files on the device, **commit and push the changes immediately**:

| File to copy | Repo destination |
|---|---|
| `~/.config/sway/config` | `sway/config` |
| `~/.config/waybar/config.jsonc` | `waybar/config.jsonc` |
| `~/.config/waybar/style.css` | `waybar/style.css` |
| `/usr/local/bin/greetd-gtkgreet-run` | `greetd/greetd-gtkgreet-run` (chown before copying) |
| `/etc/greetd/config.toml` | `greetd/config.toml` (chown before copying) |
| `/etc/greetd/environments` | `greetd/environments` (chown before copying) |

## Commit pattern

```bash
cp ~/.config/sway/config ~/uconsole-dotfiles/sway/config
cp ~/.config/waybar/config.jsonc ~/uconsole-dotfiles/waybar/
cp ~/.config/waybar/style.css ~/uconsole-dotfiles/waybar/
sudo cp /usr/local/bin/greetd-gtkgreet-run ~/uconsole-dotfiles/greetd/
sudo chown silly82:silly82 ~/uconsole-dotfiles/greetd/*
cd ~/uconsole-dotfiles
git add -A
git commit -m "sway: scale 1.5, renderer note"   # descriptive message
git push
```

The user explicitly requested "immer nachdokumentieren" — make this a habit, not an afterthought.
