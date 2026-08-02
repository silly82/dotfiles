# Full configuration.nix for uConsole CM5

This is the complete NixOS configuration built during the session. It includes:

## Key Bindings

| Keys | Action |
|------|--------|
| Mod+Return | Terminal (Foot) |
| Mod+d | App Launcher (Fuzzel) |
| Mod+Shift+q | Close window |
| Mod+Shift+c | Reload config |
| Mod+Shift+e | Exit Sway |
| Mod+Shift+w | WiFi (nmtui) |
| Mod+z | Scale 2.0 |
| Mod+Shift+z | Scale 1.0 |
| Mod+↑↓←→ | Window focus direction |
| Mod+Tab | Toggle last workspace |
| Mod+1-5 | Switch workspace |
| Mod+Shift+1-5 | Move window to workspace |

## Network

- WiFi: wlan0, DHCP
- USB Ethernet: enu1u2, DHCP (separate IP)
- VNC: port 5900 (use LAN/USB IP for stability)

## External Antenna

`dtparam=ant2=on` is set in the firmware config.txt `[all]` section to enable the external foil antenna. Verified working.

## Zen Browser (non-Nix binary)

Installation:
1. Download aarch64 release from GitHub
2. Extract to `/opt/zen/`
3. Enable `programs.nix-ld` with all needed libraries
4. Create wrapper script setting `LD_LIBRARY_PATH=/opt/zen:/opt/zen/browser`

## Tuba (Mastodon client)

Requires `gnome-keyring` for OAuth token storage. Start via `Mod+d` → `tuba`.