---
name: nixos-uconsole-cm5
description: NixOS setup & configuration for ClockworkPi uConsole CM5 – Sway, Wayland, display, WiFi, VNC, non-Nix binaries
---

# NixOS uConsole CM5

Setup and maintain NixOS on the ClockworkPi uConsole with CM5 compute module.

## Key Hardware Facts

| Component | Detail |
|-----------|--------|
| **Display** | DSI-2 (NOT DSI-1 like CM4) – 720×1280 portrait, transform 90 for landscape |
| **WiFi** | `wlan0`, Broadcom brcmfmac, external antenna via `dtparam=ant2=on` |
| **USB/LAN** | `enu1u2` interface (USB Ethernet gadget) at separate IP |
| **Audio** | PipeWire, `axp20x-battery` for power management |

## Sway / Display

### Output Configuration
```
output DSI-2 transform 90 scale 1.5
```

### Scale Toggle (useful for small displays)
```
bindsym $mod+z exec swaymsg "output DSI-2 scale 2.0"
bindsym $mod+Shift+z exec swaymsg "output DSI-2 scale 1.0"
```

### Status Bar
Waybar needs a proper config in `/etc/xdg/waybar/` or `~/.config/waybar/`. Without config, sway shows "error reading from status command".

**Fallback — Sway native bar with i3status:**
```
bar {
  position top
  status_command i3status -c /etc/i3status.conf
}
```

**i3status 2.15 notes:**
- `clock` does NOT exist → use `tztime local` instead
- Battery module has `path = "/sys/class/power_supply/%d/uevent"` or remove it
- ALSA errors on stderr are harmless

**Fallback — simple shell script (no i3status needed):**
```
status_command sh -c 'while true; do echo "  $(cat /sys/class/power_supply/axp20x-battery/capacity 2>/dev/null)%  |  $(date +%H:%M)"; sleep 2; done'
```

WiFi in status bar — `iwgetid` is NOT available on CM5. Use instead:
```bash
ssid=$(iw dev wlan0 info 2>/dev/null | awk '/ssid/ {print $2}')
```

## VNC (wayvnc)

wayvnc **does NOT handle** Sway's `transform 90` — mouse coordinates will be rotated.

**Start command:**
```
wayvnc --output=DSI-2 0.0.0.0 5900
```

**Firewall:** NixOS blocks port 5900 by default. Open it:
```nix
networking.firewall.allowedTCPPorts = [ 5900 ];
```

**Workarounds for rotated mouse:**
1. Use TigerVNC client (`brew install tiger-vnc`) which may handle rotation
2. Remove `transform 90` and use portrait mode natively

## Greetd Auto-Login

Skip login screen, boot directly to Sway:
```nix
services.greetd = {
  enable = true;
  settings = {
    default_session = {
      command = "${pkgs.sway}/bin/sway";
      user = "silly82";
    };
  };
};
```

## Running Non-Nix Binaries (e.g. Zen Browser)

NixOS cannot run dynamically linked binaries directly. Use `programs.nix-ld`:

```nix
programs.nix-ld = {
  enable = true;
  libraries = with pkgs; [
    gtk3 glib pango cairo gdk-pixbuf atk nspr nss
    dbus alsa-lib libxkbcommon libglvnd pipewire
    freetype fontconfig stdenv.cc.cc.lib libpng libjpeg
    xorg.libX11 xorg.libxcb xorg.libXcursor
    xorg.libXcomposite xorg.libXdamage xorg.libXext
    xorg.libXfixes xorg.libXrandr xorg.libXtst
  ];
};
```

Then create a wrapper script:
```bash
export LD_LIBRARY_PATH=/opt/zen:/opt/zen/browser:$LD_LIBRARY_PATH
exec /opt/zen/zen "$@"
```

## Cyberpunk Pink Theme

### Foot Terminal Colors
```nix
environment.etc.\"foot/foot.ini\".text = ''
  [main]
  font=Iosevka:size=12,monospace:size=12
  term=xterm-256color
  [colors]
  background=0d0d0d
  foreground=ffb8d0
  cursor=ff0066 0d0d0d
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
'';
```

### Sway Bar Colors
```nix
bar {
  colors {
    background #0d0d0d
    statusline #ff2a6d
    separator #ff00ff
    focused_workspace #ff2a6d #0d0d0d #ffb8d0
    active_workspace #1a0a1e #1a0a1e #ff66ff
    inactive_workspace #0d0d0d #0d0d0d #404040
    urgent_workspace #ff0066 #0d0d0d #ffffff
    binding_mode #ff00ff #0d0d0d #ffffff
  }
}
```

### Sway Client Colors
```nix
client.focused #ff0066 #ff0066 #ffffff #ff00ff
client.focused_inactive #1a0a1e #1a0a1e #ff66ff #ff00ff
client.unfocused #0d0d0d #0d0d0d #404040 #0d0d0d
client.urgent #ff0066 #ff0066 #ffffff #ff0066
```

## Keybindings

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
| **Mod+↑↓←→** | **Window focus direction** |
| **Mod+Tab** | **Toggle last workspace** |
| Mod+1-5 | Switch workspace |
| Mod+Shift+1-5 | Move window to workspace |

## Screenshots (grim)

```bash
# Install temporarily
nix shell nixpkgs#grim -c sudo -u silly82 \
  WAYLAND_DISPLAY=wayland-1 XDG_RUNTIME_DIR=/run/user/1000 \
  grim -o DSI-2 /tmp/screenshot.png
```

## Gnome Keyring (for apps needing password storage)

Required for apps like Tuba (Mastodon client) that need to store OAuth credentials:

```nix
services.gnome.gnome-keyring.enable = true;
environment.systemPackages = with pkgs; [ gnome-keyring ];
```

## Sway Config Pitfalls

| Symptom | Cause | Fix |
|---------|-------|-----|
| `error: fonts invalid command` | `fonts` (plural) in bar block | Use `font` (singular) |
| `error reading from status command` | Waybar has no config OR bar uses `status_command waybar` instead of `exec waybar` | Provide config or use i3status/shell script instead |
| `error reading from status command` | Status command exits immediately | Ensure it loops with `while true; do ...; sleep 2; done` |
| No WiFi SSID in bar | `iwgetid` not available on CM5 | Use `iw dev wlan0 info \| awk '/ssid/ {print $2}'` |

## WiFi Antenna

Enable external antenna on CM5:
```nix
# In config.txt via Nix:
hardware.raspberry-pi.config.all.dtparam.ant2 = "on";
```

Current signal: `iw dev wlan0 link | grep signal`