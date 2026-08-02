# uConsole CM5 Debugging Cheatsheet

## Display Output
```bash
# List DRM outputs
ls /sys/class/drm/ | grep -E 'DSI|HDMI'

# Check connection status
cat /sys/class/drm/card1-DSI-2/status   # → "connected" or "disconnected"

# Check edid (display info)
cat /sys/class/drm/card1-DSI-2/edid | strings | head -5
```

## WiFi
```bash
# Interface info
iw dev wlan0 info

# Connection status
iw dev wlan0 link

# Get SSID (instead of iwgetid)
iw dev wlan0 info | awk '/ssid/ {print $2}'

# Scan networks
iw dev wlan0 scan

# dmesg for brcmfmac errors
dmesg | grep -i brcm

# Force 2.4GHz
nmcli con modify "<SSID>" 802-11-wireless.band bg

# Restart WiFi
nmcli radio wifi off && sleep 2 && nmcli radio wifi on
```

## Sway
```bash
# Reload config (from inside Sway)
# Mod+Shift+c

# Validate config (from outside Sway, needs TTY)
sway --validate -c /etc/sway/config

# List outputs
swaymsg -t get_outputs

# Get Wayland socket path
ls /run/user/1000/wayland-*
```

## Foot Terminal
```bash
# Validate config
foot --config /etc/foot/foot.ini --check
```

## VNC
```bash
# Start wayvnc
wayvnc 0.0.0.0 5900 &

# Check if running
ss -tlnp | grep 5900

# Open firewall if needed
# Add to NixOS config:
# networking.firewall.allowedTCPPorts = [ 5900 ];
```

## NixOS
```bash
# Rebuild
cd /etc/nixos && nixos-rebuild switch --flake .#uconsole

# Check current generation
nixos-version
nix-env --list-generations -p /nix/var/nix/profiles/system

# Reboot
sudo reboot
```

## Screenshot (from SSH)
```bash
# Need to run as the user in the Sway session
sudo -u silly82 \
  WAYLAND_DISPLAY=wayland-1 \
  XDG_RUNTIME_DIR=/run/user/1000 \
  grim -o DSI-2 /tmp/screenshot.png
```