---
name: nixos-uconsole
category: hardware
description: Flashing, configuring, and customising NixOS on ClockworkPi uConsole CM4/CM5 — from SD card imager to Sway+greetd GUI setup
triggers:
  - uConsole
  - cm5
  - cm4
  - clockworkpi
  - nixos sd card
  - rpiboot
  - dsi display
  - greetd
  - tuigreet
---

# NixOS uConsole CM4/CM5 Setup

Setup and configure NixOS on a ClockworkPi uConsole (CM4 or CM5).

## Flashing a Pre-built Image

```bash
# Download from GitHub Releases:
#   CM4: nixos-uconsole-cm4-*.img.zst
#   CM5: nixos-uconsole-cm5-*.img.zst (experimental)

# Decompress
zstd -d nixos-uconsole-cm5-*.img.zst

# Flash to SD card (replace diskX with your device)
sudo dd if=nixos-uconsole-cm5-*.img of=/dev/rdiskX bs=4m status=progress
sync
```

> **macOS note:** On macOS >27 Homebrew may lack bottles. Use `nix shell nixpkgs#zstd -c unzstd` instead.

## First Boot

- Default login: **root / changeme** (password change enforced on first login)
- Connect WiFi: `nmtui`

## Resize Root Partition (if not auto-expanded)

```bash
sudo parted /dev/mmcblk0 resizepart 2 100%
sudo resize2fs /dev/mmcblk0p2
```

## Custom NixOS Configuration

Create `/etc/nixos/flake.nix`:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixos-uconsole.url = "github:nixos-uconsole/nixos-uconsole";
  };
  outputs = { nixpkgs, nixos-uconsole, ... }: {
    nixosConfigurations.uconsole = nixos-uconsole.lib.mkUConsoleSystem {
      variant = "cm5"; # or "cm4"
      modules = [ ./configuration.nix ];
    };
  };
}
```

Then `configuration.nix` with your settings and `nixos-rebuild switch --flake .#uconsole`.

### Recommended CM5 Overlay Parameters

```nix
hardware.raspberry-pi.config.cm5."dt-overlays".clockworkpi-uconsole-cm5.params = {
  no_rp1eth.enable = true;
  no_sound_switch.enable = true;
  energy_full_design_uwh.enable = true;
  energy_full_design_uwh.value = "24790000";
  charge_full_design_uah.enable = true;
  charge_full_design_uah.value = "6700000";
};
```

### User Setup with Sudo

```nix
users.users.silly82 = {
  isNormalUser = true;
  extraGroups = [ "wheel" "networkmanager" "dialout" "video" "input" ];
  openssh.authorizedKeys.keys = [ "ssh-ed25519 ..." ];
  initialPassword = "changeme";
};
security.sudo.extraRules = [
  { groups = [ "wheel" ];
    commands = [ { command = "ALL"; options = [ "NOPASSWD" ]; } ];
  }
];
```

## Sway + GUI on uConsole

### Important: Display Name Differs Between CM4 and CM5

- **CM4**: Display is `DSI-1`
- **CM5**: Display is **`DSI-2`** (NOT DSI-1!)

Always verify with `ls /sys/class/drm/` before writing config — look for `card*-DSI-*`.

### NixOS Sway Config

```nix
programs.sway = {
  enable = true;
  wrapperFeatures.gtk = true;
  extraPackages = with pkgs; [
    waybar foot fuzzel mako swaylock swayidle brightnessctl wl-clipboard
  ];
};

environment.etc."sway/config".text = ''
  set $mod Mod1
  output DSI-2 transform 90 scale 1.5
  set $term foot
  set $menu fuzzel
  bindsym $mod+Return exec $term
  bindsym $mod+d exec $menu
  bindsym $mod+Shift+q kill
  bindsym $mod+Shift+c reload
  bindsym $mod+Shift+e exec swaynag -t warning -m "Exit Sway?" -b "Yes" "swaymsg exit"
  bindsym XF86MonBrightnessDown exec brightnessctl set 1-
  bindsym XF86MonBrightnessUp exec brightnessctl set +1
  bindsym XF86AudioRaiseVolume exec pactl set-sink-volume @DEFAULT_SINK@ +5%
  bindsym XF86AudioLowerVolume exec pactl set-sink-volume @DEFAULT_SINK@ -5%
  bindsym XF86AudioMute exec pactl set-sink-mute @DEFAULT_SINK@ toggle
  default_border pixel 2
  gaps inner 4
  smart_gaps on
  smart_borders on
  focus_follows_mouse no
  exec_always killall waybar 2>/dev/null
  exec_always waybar
  output * bg #1a1b26 solid_color
  exec swayidle -w \
    timeout 300 'swaylock -f' \
    timeout 600 'swaymsg "output * dpms off"' \
    resume 'swaymsg "output * dpms on"'
  exec mako
'';

> **CRITICAL:** Do NOT put waybar inside `bar { status_command waybar; }` — that treats waybar as a text-outputting status program (like i3status). Waybar is a **standalone GUI bar** and must be started via `exec_always waybar`. Using `status_command waybar` produces `error reading from status command` in the red swaynag bar.

> Waybar also needs a **config file** or it fails silently. Create `/etc/xdg/waybar/config.jsonc` (see below) and `/etc/xdg/waybar/style.css`. Use `exec_always` (not `exec`) so waybar restarts on `$mod+Shift+c` — otherwise font/icon changes require a full logout.
```

### Other GUI Packages

```nix
environment.systemPackages = with pkgs; [
  networkmanagerapplet nemo imv mpv pavucontrol font-awesome
];
services.pipewire = { enable = true; alsa.enable = true; pulse.enable = true; };
```

### Display Manager: greetd + tuigreet

```nix
services.greetd = {
  enable = true;
  settings = {
    default_session = {
      command = "${pkgs.tuigreet}/bin/tuigreet \
        --greeting 'uConsole CM5 - waehle Session' \
        --sessions /etc/greetd/sessions \
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

## Binary Cache

The flake pre-configures [Cachix](https://app.cachix.org/cache/nixos-clockworkpi-uconsole). Do NOT override with `nixpkgs.follows` to unstable — that breaks cache hits and forces local kernel rebuild.

## Pitfalls

- **Waybar is NOT a `status_command`** — never put it in Sway's `bar { status_command waybar; }` block. That treats waybar as a text-status program. Use `exec_always waybar` instead. Wrong syntax causes `error reading from status command` in the red swaynag bar.
- **Waybar needs a config file** or it starts but produces no visible bar. Create `/etc/xdg/waybar/config.jsonc` and `/etc/xdg/waybar/style.css`. See `templates/waybar-config.jsonc` and `templates/waybar-style.css`.
- **Sway uses `font` (singular), not `fonts`** — `fonts pango:monospace 10` is an invalid command that prints `invalid command fonts` on the swaynag bar.
- **CM5 display is DSI-2** — checking `/sys/class/drm/` before writing the Sway config saves debugging time.
- **No touchscreen input device** on CM5 (unlike CM4). Remove any input sections from Sway config.
- **`tuigreet`** is a top-level package, not `greetd.tuigreet` (deprecated alias).
- **Rebuild is fast** on CM5 due to binary cache — no need to build on a more powerful machine.
- **macOS >27 Homebrew** may not have bottles for zstd — use `nix shell nixpkgs#zstd` instead.
- **Disable `services.getty.autologinUser`** when using greetd, or they conflict.
- **`iwgetid` is not available on NixOS** — use `iw dev wlan0 info | awk '/ssid/ {print $2}'` instead for getting the SSID in a status bar script.
- **Avoid `${var}` in bash scripts inside Nix `''...''` strings** — Nix interpolates `${}` even in indented strings, producing `undefined variable 'var'`. Use `$var` (no braces) instead, or rename to avoid ambiguity (e.g. `$cap` instead of `$batt%` where `%` after the brace causes the issue).

## Verification

After setup, verify with:

```bash
# Config was applied
grep dtoverlay /boot/firmware/config.txt | grep uconsole

# Display detected
cat /sys/class/drm/card*/status

# Greetd running
systemctl status greetd
```