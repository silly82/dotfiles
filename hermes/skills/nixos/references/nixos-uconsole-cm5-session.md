# NixOS uConsole CM5 Setup Session (2026-07-14)

## Hardware
- ClockworkPi uConsole with **CM5** module (not CM4)
- 31.3 GB SD card (mmcblk0 via USB reader on Mac)
- **CM5 display is DSI-2** (NOT DSI-1 as on CM4)
- External foil antenna connected (dtparam=ant2=on in firmware config.txt)
- Two network interfaces: **enu1u2** (USB/RP1, 192.168.188.203) + **wlan0** (WiFi, 192.168.188.199)

## Image Used
`nixos-uconsole-cm5-v1.1.1.img.zst` → `nixos-uconsole-cm5-v1.1.1.img` (6.07 GB)
- Source: https://github.com/nixos-uconsole/nixos-uconsole/releases
- Partition: 1 GB FAT32 (FIRMWARE) + 4.6 GB ext4 root (auto-expanded to full SD)
- Kernel: linux_rpi-bcm2712 6.12.47
- NixOS: 25.11.20260526.25f5383

## Flashing on macOS
```bash
nix shell nixpkgs#zstd -c unzstd -v nixos-uconsole-cm5-*.img.zst
sudo dd if=nixos-uconsole-cm5-*.img of=/dev/rdisk12 bs=4m status=progress
```

## First Boot
- **IP changed**: initially 192.168.188.203, then 192.168.188.199 after reboot
- **Login**: root / changeme (must change on first login)
- **SSH**: enabled by default

## Sway Setup Journey

### 1. DSI-2 discovery
CM5 uses **DSI-2** not DSI-1. Verify: `ls /sys/class/drm/ | grep DSI`. Using DSI-1 in Sway config produced no visible error but the display didn't work.

### 2. `fonts` → `font`
Sway bar block uses `font` (singular). `fonts pango:monospace 10` gives `invalid command fonts` on the swaynag red bar.

### 3. Waybar architecture
Waybar is a **standalone GUI bar**, not a `status_command` program.
- **WRONG**: `bar { status_command waybar; }` — Sway reads stdout as status text → "error reading from status command"
- **CORRECT**: `exec waybar` without any bar { } block
- Waybar also needs `/etc/xdg/waybar/config.jsonc` + `style.css` or it produces no visible bar

### 4. i3status 2.15: `clock` → `tztime local`
i3status v2.15 removed the `clock` module. Must use `tztime local`. The battery module also has a known issue with fixed paths (expects `%d` placeholder).

### 5. Shell script status bar (final approach)
After Waybar and i3status issues, settled on a simple shell script at `/etc/sway/status`:
```sh
#!/bin/sh
while true; do
  ssid=$(iw dev wlan0 info 2>/dev/null | awk '/ssid/ {print $2}')
  [ -z "$ssid" ] && ssid="-"
  cap=$(cat /sys/class/power_supply/axp20x-battery/capacity 2>/dev/null || echo "?")
  now=$(date +%H:%M)
  echo "  $ssid  |  $cap%  |  $now"
  sleep 2
done
```
Used in Sway as `status_command sh /etc/sway/status` inside a native `bar {}` block.
**Important**: Use `$var` (no braces) in Nix `''...''` strings — `${var}` triggers Nix interpolation!

### 6. WiFi SSID detection
`iwgetid` is NOT available on NixOS. Use: `iw dev wlan0 info | awk '/ssid/ {print $2}'`

## VNC (wayvnc)
- Installed via `wayvnc` in systemPackages
- Autostart: `exec wayvnc --output=DSI-2 0.0.0.0 5900`
- NixOS firewall blocks port 5900 by default — must add `networking.firewall.allowedTCPPorts = [ 5900 ];`
- wayvnc **ignores Sway's `transform 90`** — mouse coordinates are rotated 90°. `--output=DSI-2` helps but doesn't fully fix it. Known wayvnc limitation.
- VNC over USB interface (enu1u2 @ .203) is stable; WiFi @ .199 is unreliable

## greetd Change
1. Started with **tuigreet** session chooser (Sway or Bash/CLI)
2. Switched to **auto-login** (no greeter): `services.greetd.settings.default_session = { command = "${pkgs.sway}/bin/sway"; user = "silly82"; };`

## Cyberpunk Pink Theme
- **Foot terminal**: dark bg, pink/magenta/cayan/Matrix-green palette
- **Sway bar**: pink (#ff2a6d) text on black (#0d0d0d), focused workspace pink highlight
- **Sway colors**: client.focused pink, focused_inactive magenta, unfocused grey
- Wallpaper: custom 1280x720 PNG with shortcut list, generated via Python/Pillow

## Display Scale Toggle
```sway
bindsym $mod+z exec swaymsg "output DSI-2 scale 2.0"       # Zoom in (large UI)
bindsym $mod+Shift+z exec swaymsg "output DSI-2 scale 1.0" # Normal (small UI)
```

## Wallpaper with Shortcuts
Generated with Python/Pillow — 1280x720 PNG showing all Sway keybindings in 2 columns on a cyberpunk dark grid background. Created on Mac and SCP'd to the uConsole at `/tmp/wallpaper.png`. Sway config: `output * bg /tmp/wallpaper.png fill`.

## NixOS Configuration File
Full final configuration.nix is referenced in `templates/cm5-full-configuration.nix` — includes:
- CM5 overlay params (no_rp1eth, no_sound_switch, battery capacity)
- User silly82 (wheel/networkmanager/dialout/video/input groups, sudo NOPASSWD)
- Sway with display DSI-2, scale toggle, waybar, cyberpunk theme
- PipeWire audio
- Foot terminal with cyberpunk colors
- greetd auto-login to Sway
- wayvnc autostart with port 5900 open in firewall
- Nix timezone Europe/Zurich
- Custom wallpaper