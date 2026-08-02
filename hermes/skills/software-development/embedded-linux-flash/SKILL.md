---
name: embedded-linux-flash
description: Flash embedded Linux images (Raspberry Pi, uConsole, etc.) on macOS — decompress, mount, inspect, dd, and do initial NixOS provisioning via SSH.
---

# Embedded Linux Flash & Provision

Flash an embedded Linux .img to SD/eMMC on macOS and optionally do first-boot NixOS setup.

## Prerequisites

- `zstd` — use `nix shell nixpkgs#zstd` if brew is unavailable (macOS pre-release)
- `hdiutil` / `diskutil` (built-in on macOS)
- SD card reader connected via USB

## Step 1: Decompress

```bash
nix shell nixpkgs#zstd -c unzstd -v path/to/image.img.zst
```

## Step 2: Inspect (optional)

```bash
# Show partition layout
nix shell nixpkgs#util-linux -c fdisk -l path/to/image.img

# Mount FIRMWARE partition to inspect config.txt / boot files
hdiutil attach path/to/image.img
# → /Volumes/FIRMWARE  (FAT32 partition)
# → /dev/disk13s2      (Linux root = ext4 — not readable on macOS natively)

hdiutil detach /dev/disk13   # unmount when done
```

## Step 3: Flash to SD/eMMC

```bash
# Identify target device
diskutil list
# → e.g. /dev/disk12  (external, physical, 31.3 GB)

# Unmount
diskutil unmountDisk /dev/disk12

# Write (use rdisk for speed)
sudo dd if=path/to/image.img of=/dev/rdisk12 bs=4m status=progress
```

**Pitfall:** `disk12` via USB is a USB SD card reader, NOT the CM4/CM5 internal eMMC. Internal eMMC requires `rpiboot` USB boot mode.

## Step 4: Find IP on LAN

After boot, scan:

```bash
arp-scan --localnet
```

Or check router DHCP leases.

## Step 5: First SSH — NixOS

Default credentials per image README: `root` / `changeme`

```bash
# Add your SSH key
ssh root@<ip> "mkdir -p ~/.ssh && echo '<your-pubkey>' >> ~/.ssh/authorized_keys"
```

## Step 6: NixOS Flake Setup (remote)

Create `/etc/nixos/flake.nix`:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixos-uconsole.url = "github:nixos-uconsole/nixos-uconsole";
  };
  outputs = { nixpkgs, nixos-uconsole, ... }: {
    nixosConfigurations.uconsole = nixos-uconsole.lib.mkUConsoleSystem {
      variant = "cm5";  # or "cm4"
      modules = [ ./configuration.nix ];
    };
  };
}
```

Create `/etc/nixos/configuration.nix` with:
- Overlay parameters (dtparams)
- Hostname
- Non-root user (`isNormalUser`, `extraGroups = [ "wheel" "networkmanager" ]`, SSH key, `initialPassword`)
- Root SSH key (fallback)
- `security.sudo.extraRules` for NOPASSWD wheel

Rebuild:

```bash
nixos-rebuild switch --flake /etc/nixos#uconsole
```

## User Preferences (Silvan)

- Communicates in short German phrases (keep replies concise, command-ready)
- Wants practical, copy-paste command blocks with clear next steps — no long explanations
- Prefers to handle passwords/security manually (don't set passwords for them)
- Uses SSH key auth from MacBook to uConsole
- Appreciates honest caveats about hardware limitations (antenna, display, performance)
- Willing to test multiple approaches iteratively — give one solution at a time, not a menu of choices unless asked

## uConsole CM5 Recommended Overlay Params

```nix
hardware.raspberry-pi.config.cm5."dt-overlays".clockworkpi-uconsole-cm5.params = {
  no_rp1eth.enable = true;
  no_sound_switch.enable = true;
  energy_full_design_uwh = { enable = true; value = "24790000"; };
  charge_full_design_uah = { enable = true; value = "6700000"; };
};
```

## NixOS GUI Setup (Sway)

After basic NixOS provisioning, add a Wayland desktop with Sway.

### Minimal Sway + greetd + Bar Config

```nix
programs.sway = {
  enable = true;
  wrapperFeatures.gtk = true;
  extraPackages = with pkgs; [
    waybar foot fuzzel mako swaylock swayidle brightnessctl wl-clipboard
  ];
};

environment.systemPackages = with pkgs; [
  networkmanagerapplet nemo imv mpv pavucontrol
  i3status                     # for native bar status_command
];

services.pipewire = {
  enable = true;
  alsa.enable = true;
  pulse.enable = true;
};

# === Display output — CRITICAL: CM4 uses DSI-1, CM5 uses DSI-2 ===
environment.etc."sway/config".text = ''
  set $mod Mod1
  output DSI-2 transform 90 scale 1.5   # CM5: DSI-2, CM4: DSI-1

  set $term foot
  set $menu fuzzel
  bindsym $mod+Return exec $term
  bindsym $mod+d exec $menu
  bindsym $mod+Shift+q kill
  bindsym $mod+Shift+c reload
  bindsym $mod+Shift+e exec swaynag -t warning -m "Exit Sway?" -b "Yes" "swaymsg exit"
  bindsym $mod+1..5 workspace 1..5

  bindsym XF86MonBrightnessDown exec brightnessctl set 1-
  bindsym XF86MonBrightnessUp exec brightnessctl set +1
  bindsym XF86AudioRaiseVolume exec pactl set-sink-volume @DEFAULT_SINK@ +5%
  bindsym XF86AudioLowerVolume exec pactl set-sink-volume @DEFAULT_SINK@ -5%
  bindsym XF86AudioMute exec pactl set-sink-mute @DEFAULT_SINK@ toggle

  default_border pixel 2
  gaps inner 4
  smart_gaps on
  focus_follows_mouse no
  output * bg #1a1b26 solid_color

  # Use NATIVE sway bar with i3status (NOT waybar as status_command!)
  bar {
    position top
    status_command i3status -c /etc/i3status.conf
    font pango:monospace 10
    colors {
      background #1a1b26
      statusline #c0caf5
    }
  }

  # Waybar (if preferred) is started standalone, not via status_command:
  # exec waybar

  # Scale toggle (Mod+z = 2.0 zoomed in, Mod+Shift+z = 1.0 native)\n  bindsym $mod+z exec swaymsg "output DSI-2 scale 2.0"\n  bindsym $mod+Shift+z exec swaymsg "output DSI-2 scale 1.0"\n\n  # nmtui Wi-Fi manager\n  bindsym $mod+Shift+w exec $term -e nmtui\n\n  exec swayidle -w \\\n    timeout 300 'swaylock -f' \\\n    timeout 600 'swaymsg "output * dpms off"' \\\n    resume 'swaymsg "output * dpms on"'
  exec mako
'';

# i3status config (clock → tztime local in v2.15+!)
environment.etc."i3status.conf".text = ''
  general { colors = true; interval = 2; }
  order += "wireless _first_"
  order += "battery all"
  order += "volume master"
  order += "tztime local"

  wireless _first_ {
    format_up = "W: %ip (%essid)"
    format_down = "W: down"
  }

  battery all {
    format = "%status %percentage"
    path = "/sys/class/power_supply/axp20x-battery/uevent"
    low_threshold = 15
  }

  volume master { format = "VOL %volume"; format_muted = "VOL MUTED"; }

  tztime local { format = "%H:%M"; }
'';

# === greetd login manager with session selection ===
services.greetd = {
  enable = true;
  settings = {
    default_session = {
      command = "${pkgs.tuigreet}/bin/tuigreet \\
        --greeting 'uConsole - waehle Session' \\
        --sessions /etc/greetd/sessions \\
        --user-menu --remember --time";
      user = "greeter";
    };
  };
};

environment.etc."greetd/sessions/sway.desktop".text = ''
  [Desktop Entry]
  Name=Sway
  Comment=Wayland Compositor
  Exec=sway
  Type=Application
'';

environment.etc."greetd/sessions/bash.desktop".text = ''
  [Desktop Entry]
  Name=Bash (CLI)
  Comment=Terminal only
  Exec=foot
  Type=Application
'';
```

### Bar Implementation Notes

| Approach | How | Status |
|----------|-----|--------|
| **Sway native bar + i3status** | `bar { status_command i3status -c /etc/i3status.conf }` | ✅ Reliable, simple, always works |
| **Waybar standalone** | `exec waybar` (NOT inside `bar {}`) | ✅ Works if config exists at `~/.config/waybar/` or `/etc/xdg/waybar/` |
| **Sway native bar custom script** | `bar { status_command stdbuf -oL sh -c 'while ...; done' }` | ⚠️ Works but fragile — buffering issues |
| **Waybar as status_command** | `bar { status_command waybar }` | ❌ **Does NOT work** — waybar is a GUI window, not a text status provider |

### Battery Module: Path Pitfall

The `battery all` module's `path` option in i3status 2.15 expects a `%d` placeholder for the battery number. If you set:

```nix
battery all {
  path = "/sys/class/power_supply/axp20x-battery/uevent";
}
```

i3status outputs `no '%d' in battery path` as the battery field text (it's in stdout, not stderr), and the battery shows as garbage.

**Fix:** Replace the i3status battery module with a custom status script that reads battery directly:

```bash
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

Reference this in the bar: `status_command sh /path/to/status.sh`

### `iwgetid` Not Available

On minimal NixOS images, `iwgetid` (from `wireless-tools`) is not installed. Use `iw` instead:

```bash
# Instead of: iwgetid -r
iw dev wlan0 info 2>/dev/null | awk '/ssid/ {print $2}'
```

### WiFi Signal Strength Debugging

When the uConsole has poor or flaky connectivity, check the signal:

```bash
# Current connection status
iw dev wlan0 link

# Key metrics: signal (-dBm), bitrate, frequency
# -30 dBm = excellent, -67 dBm = good, -80 dBm = poor, -90+ dBm = unusable

# Scan visible APs
iw dev wlan0 scan | grep -E 'BSS|SSID|freq|signal'
```

**Common CM5 WiFi issues:**

| Symptom | Likely cause | Check |
|---------|-------------|-------|
| All signals < -80 dBm | Antenna not seated / damaged | Re-seat U.FL connector on CM5 module |
| Channel errors (`brcmfmac_set_channel: fail, reason -52`) | 5GHz channel not supported by antenna/driver | Force 2.4GHz: `nmcli con modify <SSID> 802-11-wireless.band bg` |
| Signal fluctuates wildly | Antenna cable pinched in case | Check cable routing between board and lid |
| Only 2.4GHz APs visible | 5GHz antenna port empty or wrong | CM5 has 2 antenna ports — verify correct port is connected |

**Force 2.4GHz only:**
```bash
nmcli con modify "TimeAndRelative" 802-11-wireless.band bg
nmcli radio wifi off && sleep 2 && nmcli radio wifi on
```

### Nix String Interpolation Gotcha

In Nix `''...''` (indented strings), **`${}` IS interpolated** — just like in `"..."` strings.

To include literal `${}` in a bash script inside a Nix `''` string, either:
- Avoid `${}` syntax entirely: use `$var` (no braces) in bash — bash accepts both `$var` and `${var}`
- Escape with `''${var}`

**Bad:**
```nix
environment.etc."sway/status".text = ''
  echo "  ${batt}%"
'';
# → Nix error: undefined variable 'batt'
```

**Good:**
```nix
environment.etc."sway/status".text = ''
  echo "  $batt%"
'';
```

### Cyberpunk Pink Theme for Sway + Foot

Full terminal + bar colorscheme example (add to configuration.nix):

```nix
# Foot terminal colors
environment.etc."foot/foot.ini".text = ''
  [main]
  font=Iosevka:size=10,monospace:size=10
  term=xterm-256color

  [colors]
  background=0d0d0d
  foreground=ffb8d0
  cursor=ff0066 0d0d0d
  regular0=1a0a1e    regular1=ff0066    regular2=00ff41
  regular3=ffd700    regular4=00d4ff    regular5=ff00ff
  regular6=00ffcc    regular7=bfbfbf
  bright0=404040     bright1=ff2a6d     bright2=66ff99
  bright3=ffeb3b     bright4=05d9e8     bright5=ff66ff
  bright6=00ffcc     bright7=ffffff
'';

# Sway bar — Cyberpunk Pink
# (inside bar { } block in sway config)
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

### i3status Module Naming

i3status 2.15+ renamed several modules:

| Old name | New name (v2.15+) |
|----------|-------------------|
| `clock` | `tztime local` |
| `wireless` | `wireless _first_` (or specific iface) |
| `battery` | `battery all` (or `0`, `1`) |

If you get `no such option 'clock'`, replace `clock` with `tztime local`.

## Pitfalls

- `brew install zstd` fails on macOS 27 (no bottle) — use `nix shell nixpkgs#zstd` instead
- ext4 partition (`disk13s2`) is NOT readable on macOS without macFUSE — don't try
- `initrd` and kernel are under `/boot/firmware/nixos/default/` on NixOS
- `nix flake show` can time out on slow CM5 network — use specific commands instead
- NixOS binary cache from nixos-uconsole / Cachix makes rebuilds fast (~3 min) even on CM5
- "uptime 571 days" on freshly flashed image is bogus — it's the kernel build timestamp anomaly
- **DSI output name differs:** CM4 uses `DSI-1`, CM5 uses `DSI-2` — check `/sys/class/drm/*/status` for the right name
- **Sway bar** uses `font` (singular), NOT `fonts` (plural) — `fonts` is invalid syntax
- **greetd auto-login** conflicts with `services.getty.autologinUser` — disable one or the other