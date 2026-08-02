# Waybar Nerd Font Icons — uConsole Reference

Common Nerd Font codepoints used in waybar for the uConsole handheld display.
After installing the Nerd Font Symbols (see Step 3 in SKILL.md), use these
`\uXXXX` escapes in `config.jsonc` format strings.

## Power / Logout (custom module)

| Icon | Codepoint | Module |
|------|-----------|--------|
|  | `\uf011` | `custom/logout` — click to swaynag confirm |

## Network

| Icon | Codepoint | Label |
|------|-----------|-------|
|  | `\uf1eb` | Wi-Fi |
|  | `\uf6ff` | Ethernet |
| 睊 | `\u774a` | Disconnected (no wifi icon for this — use text) |

## Audio

| Icon | Codepoint | Label |
|------|-----------|-------|
|  | `\uf026` | Volume low |
|  | `\uf027` | Volume medium |
|  | `\uf028` | Volume high |
|  | `\uf466` | Muted |

## Backlight

| Icon | Codepoint | Label |
|------|-----------|-------|
|  | `\uf185` | Brightness |

## Battery

| Icon | Codepoint | Charge level |
|------|-----------|-------------|
|  | `\uf244` | Empty (0-10%) |
|  | `\uf243` | Low (11-30%) |
|  | `\uf242` | Medium (31-60%) |
|  | `\uf241` | High (61-90%) |
|  | `\uf240` | Full (91-100%) |

## style.css font-family

```css
* {
    font-family: "Fira Code", "Symbols Nerd Font", monospace;
}
```

The `"Symbols Nerd Font"` fallback is required — without it, the `\uf...`
codepoints render as empty boxes. Install via:
```bash
curl -sL 'https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/NerdFontsSymbolsOnly.zip' \
  -o /tmp/symbols.zip && unzip -qo /tmp/symbols.zip -d ~/.local/share/fonts '*.ttf' && rm /tmp/symbols.zip
fc-cache -fv
```

## Waybar logout module (clickable)

```jsonc
"custom/logout": {
    "format": "",
    "tooltip": "Sway beenden",
    "on-click": "swaynag -t warning -m 'Sway beenden?' -B 'Ja, beenden' 'swaymsg exit'",
    "interval": "once"
}
```

## Restart after changes

Waybar must be restarted to pick up config/font changes. The cleanest approach
is the `exec_always` pattern in the Sway config (see Step 3 in SKILL.md), then
press `$mod+Shift+c` to reload Sway. If you haven't set that up yet, run:
```bash
killall waybar; waybar &
```