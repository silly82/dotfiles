---
name: nixos-uconsole-deployment
description: Deploy, configure, and troubleshoot NixOS on ClockworkPi uConsole (CM4/CM5) — flash image, remote setup, Sway/Wayland config, WiFi, display, and theme.
---

# NixOS uConsole Deployment

Deploy NixOS on a ClockworkPi uConsole (CM4 or CM5) from a pre-built image, configure remotely via SSH, and set up Sway/Wayland with proper display settings.

## Prerequisites

- macOS or Linux host with `zstd`, `dd`
- uConsole with CM4 or CM5 module
- SD card (≥32 GB recommended) or eMMC flashing via rpiboot

## Quick Start: Flash Image

```bash
# Decompress the .zst image
unzstd nixos-uconsole-cm5-*.img.zst

# Write to SD card (disk12 in this example — VERIFY first!)
sudo dd if=nixos-uconsole-cm5-*.img of=/dev/rdisk12 bs=4m status=progress
```

## First Boot & Login

- Default credentials: **root / changeme** (must change on first login)
- SSH is enabled by default
- Connect to WiFi: `nmtui`

## Remote NixOS Configuration

### NixOS flake structure (`/etc/nixos/`):

```
/etc/nixos/
├── flake.nix          # Flake definition
├── flake.lock         # Auto-generated
└── configuration.nix  # Your config
```

### Minimal `flake.nix`:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixos-uconsole.url = "github:nixos-uconsole/nixos-uconsole";
  };

  outputs = { nixpkgs, nixos-uconsole, ... }: {
    nixosConfigurations.uconsole = nixos-uconsole.lib.mkUConsoleSystem {
      variant = "cm5";   # or "cm4"
      modules = [ ./configuration.nix ];
    };
  };
}
```

### Rebuild remotely:

```bash
ssh root@<IP> "cd /etc/nixos && nixos-rebuild switch --flake .#uconsole"
```

## Key CM5 Pitfalls

### 1. Display Output Name
- **CM4**: `DSI-1`
- **CM5**: `DSI-2` (NOT DSI-1!)
- Check: `ls /sys/class/drm/ | grep DSI`

### 2. i3status Battery Module
- `clock` was renamed to `tztime local` in i3status 2.15
- Battery module path with `%d` placeholder: `path = "/sys/class/power_supply/%d/uevent"`
- Or skip i3status entirely — use a simple shell script for the bar (recommended)

### 3. WiFi SSID Detection
- `iwgetid` is NOT available on NixOS minimal images
- Use instead: `iw dev wlan0 info | awk '/ssid/ {print $2}'`

### 4. Sway Bar — Waybar vs Native
- **Waybar** is a standalone bar — use `exec waybar` (NOT `status_command`)
- **`bar { status_command waybar }` causes "error reading from status command"** because Sway treats waybar as a stdout text-generator. Waybar is a GUI app that manages its own window — it must be started with `exec waybar`, NOT as a `status_command`.
- **Native sway bar** works with `status_command` using i3status or a shell script
- Native bar is simpler and more reliable for minimal setups

### 5. Sway Config Syntax — `font` vs `fonts`
- **WRONG**: `bar { fonts pango:monospace 10 }` — `fonts` is not a valid command
- **CORRECT**: `bar { font pango:monospace 10 }` — use `font` (singular)
- This causes a Sway config error with a red swaynag bar at top

### 6. greetd Login Manager
- Use `tuigreet` for TTY login with session selection
- Create `.desktop` files in `/etc/greetd/sessions/` for Sway and Bash
- **Auto-login** (no greeter): Set `command = "${pkgs.sway}/bin/sway"` and `user = "silly82"`
- greetd runs as `greetd.service` (NOT `display-manager.service`)
- Disable getty auto-login: `services.getty.autologinUser = lib.mkForce null;`

### 7. Nix `${}` Interpolation in `''` Strings
- **PITFALL**: `${var}` is interpolated by Nix even inside `''` (single-quoted) strings!
- Use `${var}` in `""` strings, but in `''` strings you must escape as `''${var}` OR avoid braces entirely: use `$var` instead of `${var}`
- **Safe approach**: use simple `$var` (no braces) for shell variables in Nix
  ```nix
  # WRONG — Nix tries to evaluate ${batt}
  echo "  ${batt}%"
  
  # CORRECT — bash variable, no Nix interpolation
  echo "  $batt%"
  ```

### 8. CM5 Dual Network Interfaces
- CM5 has **two** network interfaces:
  - `enu1u2` (USB, via RP1 chip) — typically gets `.203`
  - `wlan0` (WiFi) — typically gets `.199`
- Both are on the same subnet, so either IP may respond depending on routing
- VNC/SSH over the USB interface (enu1u2) is more stable than WiFi

### 8. NixOS Firewall Blocks Non-SSH Ports
- Default NixOS firewall only allows: SSH (22), Mosh (UDP 60000-61000), ICMP
- To open VNC port: `networking.firewall.allowedTCPPorts = [ 5900 ];`
- Firewall reloads with: `systemctl restart firewall` (or `nixos-rebuild switch`)

### 9. Wayland Socket Location
- Sway creates the Wayland socket at `/run/user/<UID>/wayland-1`
- For user silly82 (UID 1000): `/run/user/1000/wayland-1`
- Required env vars for wayvnc/grim from root: `WAYLAND_DISPLAY=wayland-1 XDG_RUNTIME_DIR=/run/user/1000`

### 10. Foot Terminal Config Validation
- Use `foot --config /etc/foot/foot.ini --check` to validate config
- Deprecated: `cursor.color` → use `colors.cursor` instead (under `[colors]` section)
- Font size recommendation for 5" 720x1280 display: size=12

### 11. CM5 brcmfmac WiFi Channel Errors
- dmesg shows: `brcmfmac: brcmf_set_channel: set chanspec 0xd02a fail, reason -52`
- These are 5GHz channel switching failures — the driver on CM5 struggles with 5GHz
- Workaround: force 2.4GHz only: `nmcli con modify "<SSID>" 802-11-wireless.band bg`
- Signal at -80 dBm or worse is common with the foil antenna — external antenna recommended

## Display Scaling Toggle

Add to Sway config for zoom toggle:

```sway
bindsym $mod+z exec swaymsg "output DSI-2 scale 2.0"    # Zoom in
bindsym $mod+Shift+z exec swaymsg "output DSI-2 scale 1.0"  # Normal
```

## Cyberpunk Pink Theme

### Foot Terminal Colors

```ini
[colors]
background=0d0d0d
foreground=ffb8d0
regular0=1a0a1e
regular1=ff0066
regular2=00ff41
regular3=ffd700
regular4=00d4ff
regular5=ff00ff
regular6=00ffcc
regular7=bfbfbf
bright0=404040
bright1=ff2a6d
bright2=66ff99
bright3=ffeb3b
bright4=05d9e8
bright5=ff66ff
bright6=00ffcc
bright7=ffffff
cursor=ff0066 0d0d0d
```

### Sway Bar Colors

```sway
bar {
  colors {
    background #0d0d0d
    statusline #ff2a6d
    focused_workspace #ff2a6d #0d0d0d #ffb8d0
    active_workspace #1a0a1e #1a0a1e #ff66ff
    inactive_workspace #0d0d0d #0d0d0d #404040
  }
}
```

## VNC Access

Install `wayvnc` for Wayland-compatible VNC:

```bash
wayvnc 0.0.0.0 5900 &
# Connect from another machine:
open vnc://<IP>:5900
```

## References

- [nixos-uconsole GitHub](https://github.com/nixos-uconsole/nixos-uconsole)
- [NixOS manual](https://nixos.org/manual/nixos/stable/)
- `references/complete-configuration.nix` — Full working NixOS config for CM5 (Sway + greetd + Cyberpunk theme + wayvnc)
- `references/debugging-cheatsheet.md` — Quick commands for display, WiFi, Sway, VNC, and screenshot troubleshooting