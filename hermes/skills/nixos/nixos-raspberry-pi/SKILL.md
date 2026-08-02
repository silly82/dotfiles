---
name: nixos-raspberry-pi
description: Set up, configure, and manage NixOS on Raspberry Pi / CM4/CM5 devices (including uConsole). Flashing, flake configuration, overlay params, Sway on DSI display, display manager.
---

# NixOS on Raspberry Pi (CM4/CM5/uConsole)

## Trigger
User mentions NixOS on a Raspberry Pi, CM4, CM5, uConsole, or needs to flash a `.img.zst` to an SD card and configure it.

## Image Handling

### Extract .zst on macOS (when Homebrew has no bottle)
```bash
nix shell nixpkgs#zstd -c unzstd -v nixos-*-cm5-*.img.zst
```

### Mount a raw .img on macOS to inspect contents
```bash
hdiutil attach nixos-*-cm5-*.img
# Mounts FAT32 boot partition at /Volumes/FIRMWARE
```

### Write to SD card
```bash
diskutil unmountDisk /dev/diskX
sudo dd if=nixos-*-cm5-*.img of=/dev/rdiskX bs=4m status=progress
```

## NixOS Flake Setup (External Flake Pattern)

Use `mkUConsoleSystem` from `nixos-uconsole` for uConsole-specific configs:

**`/etc/nixos/flake.nix`:**
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

Rebuild live on device:
```bash
cd /etc/nixos && nixos-rebuild switch --flake .#uconsole
```

## CM5 Overlay Parameters (config.txt)
Recommended settings from the nixos-uconsole README:
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

## Sway on DSI Display (uConsole CM5)
Rotate 720×1280 portrait display to landscape:
```nix
# In configuration.nix:
programs.sway = {
  enable = true;
  wrapperFeatures.gtk = true;
  extraPackages = with pkgs; [ waybar foot fuzzel mako swaylock swayidle brightnessctl wl-clipboard ];
};

environment.etc."sway/config".text = ''
  set $mod Mod1
  output DSI-2 transform 90 scale 1.5   # CM5; use DSI-1 for CM4
  set $term foot
  set $menu fuzzel
  # ... keybindings ...

  # Scale toggle — zoom in/out without restarting Sway
  bindsym $mod+z exec swaymsg "output DSI-2 scale 2.0"       # Zoom in (large UI)
  bindsym $mod+Shift+z exec swaymsg "output DSI-2 scale 1.0" # Normal (small UI)

  # Waybar: standalone bar — uses exec (NOT bar { status_command })!
  exec killall waybar 2>/dev/null
  exec waybar

  # Fallback: Sway native bar (no waybar needed) — uncomment below instead of waybar exec:
  # bar {
  #   position top
  #   status_command sh /etc/sway/status
  #   font pango:monospace 10
  # }
'';
```

## Status Bar: Native Sway bar with i3status

Sway's native `bar {}` block with `status_command` is the most reliable path for small RPi displays. Two approaches:

### A) i3status (classic, structured output)

Install via `environment.systemPackages = with pkgs; [ i3status ];`.

**i3status.conf** (i3status v2.15+):
```
order += "wireless _first_"
order += "volume master"
order += "tztime local"           # NOT plain "clock" — clock was removed after v2.14

wireless _first_ {
  format_up = "%ip (%essid)"
  format_down = "down"
}
volume master {
  format = "%volume"
  format_muted = "MUTE"
}
tztime local { format = "%H:%M" }
```

**Battery module limitation**: i3status 2.15's battery module expects `%d` in the `path` value and produces `no '%d' in battery path` on stdout for fixed paths like `/sys/class/power_supply/axp20x-battery/uevent`. The warning renders as visible text in the bar. **Workaround**: skip the battery in i3status and prepend it via shell (approach B).

Sway bar block:
```
bar {
  position top
  status_command i3status -c /etc/i3status.conf
  font pango:monospace 10
}
```

Debug i3status config directly:
```bash
timeout 4 i3status -c /dev/stdin 2>/dev/null << 'EOF'
general { interval = 2; output_format = none; }
order += "tztime local"
tztime local { format = "%H:%M" }
EOF
```

### B) Shell script (bulletproof, includes battery)

Write a tiny status script at `environment.etc."sway/status".text`, then reference it:

```nix
environment.etc."sway/status".text = ''
  #!/bin/sh
  while true; do
    ssid=$(iw dev wlan0 info 2>/dev/null | awk '/ssid/ {print $2}')
    [ -z "$ssid" ] && ssid="-"
    cap=$(cat /sys/class/power_supply/axp20x-battery/capacity 2>/dev/null || echo "?")
    now=$(date +%H:%M)
    echo "  $ssid  |  $cap%  |  $now"
    sleep 2
  done
'';
```

Bar references the script (no `stdbuf` needed since it's not a pipe):
```
bar {
  position top
  status_command sh /etc/sway/status
  font pango:monospace 10
}
```

### C) Waybar (standalone bar, NOT status_command)

Waybar is a **standalone window**, NOT a `status_command` program. **Never** write:
```
bar { status_command waybar; }    # WRONG — Sway reads stdout as status text → "error reading from status command"
```

Instead:
```
exec waybar    # Starts Waybar as its own window. Requires config at /etc/xdg/waybar/config.jsonc + style.css
```

Waybar needs a proper config to show anything:
- `config.jsonc` at `/etc/xdg/waybar/config.jsonc` (system-wide) or `~/.config/waybar/` (per-user)
- `style.css` for visuals

### Pitfalls (status bar specific)

- **`fonts` → `font`**: Sway bar block uses `font` (singular). `fonts pango:monospace 10` gives `invalid command fonts` on the swaynag bar.
- **`clock` → `tztime local`**: i3status v2.15 removed the `clock` module. Use `tztime local`.
- **`exec waybar` not `bar { status_command }`**: Waybar is a standalone application, not a status text provider.
- **Waybar without a config is invisible**: Must provide `config.jsonc` + `style.css`.
- **Battery path**: Use a shell wrapper instead of i3status's `battery all` module to avoid the `%d` path warning on axp20x.
- **`timeout 4 i3status -c /dev/stdin`** is the fastest config debug loop — avoids writing/editing a temp file.

## Audio: PipeWire

```nix
services.pipewire = {
  enable = true;
  alsa.enable = true;
  pulse.enable = true;
};
```

## Auto-login to Sway via greetd+tuigreet (session chooser)
```nix
services.greetd = {
  enable = true;
  settings.default_session = {
    command = "${pkgs.tuigreet}/bin/tuigreet --greeting 'Login' --sessions /etc/greetd/sessions --user-menu --remember --time";
    user = "greeter";
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

## Pitfalls
- **Waybar is NOT a `status_command`** — never put it in `bar { status_command waybar; }`. Sway will read waybar's stdout as status text and complain `error reading from status command`. Use `exec waybar` instead (not `exec_always` — just `exec`).\n- **Waybar needs a config file** at `/etc/xdg/waybar/config.jsonc` + `style.css` or it produces no visible bar.\n- **Sway native bar needs `stdbuf -oL`** — the `status_command` shell pipeline buffers stdout by default and may show nothing. Prefix with `stdbuf -oL` for line-buffered output.\n- **Sway uses `font` (singular), not `fonts`** — `fonts pango:monospace 10` prints `invalid command fonts` on the swaynag bar.\n- **CM5 display is DSI-2** (CM4 is DSI-1). Verify with `ls /sys/class/drm/ | grep DSI` on the device.
- **`tuigreet` is a separate package** (not `greetd.tuigreet` which is deprecated). Use `${pkgs.tuigreet}`.
- **No nerd fonts** in nixpkgs 25.11 as `nerdfonts` (use `font-awesome` in systemPackages instead; nerd fonts are `pkgs.nerd-fonts.<name>` with hyphen).
- **CM5 config.txt** has a separate `[cm5]` section — don't apply CM4 overrides to it.
- **Binary cache** (Cachix) is pre-configured in the flake, but only works if you don't do `nixpkgs.follows` to unstable.
- **Do NOT use `focus_follows_mouse yes`** in Sway config — use `no` (safer on RPi, avoids potential parsing errors).
- **`services.getty.autologinUser` must be explicitly `mkForce null`** when switching to greetd, otherwise both compete for tty1.
- **`iwgetid` is not available on NixOS** — use `iw dev wlan0 info | awk '/ssid/ {print $2}'` instead in status scripts.
- **Avoid `${var}` in bash scripts inside Nix `''...''` strings** — Nix interpolates `${}` even in indented strings, producing `undefined variable` errors. Use `$var` (no braces) or escape as `''${var}`.
- **Wallpaper with text shortcuts** — Generating PNGs with readable text on the uConsole is hard (no Python/PIL, no ImageMagick). Generate on Mac with PIL and SCP to the device. On the uConsole, `nix shell nixpkgs#python3Packages.pillow` doesn't set PYTHONPATH correctly — use `nix shell` with `--command` or write a script and run it via `nix run`.
- **NixOS Firewall blocks non-SSH ports** — Default rules only allow SSH (22), Mosh (UDP 60000-61000), ICMP. Open VNC with `networking.firewall.allowedTCPPorts = [ 5900 ];` then `nixos-rebuild switch` reloads the firewall.
- **wayvnc VNC-Maus um 90° verdreht** — Wenn Sway `transform 90` verwendet, hilft `wayvnc --output=DSI-2 0.0.0.0 5900`. Ohne `--output` captured wayvnc den falschen Buffer und die Mauskoordinaten sind falsch.
- **CM5 duale Netzwerk-Interfaces** — CM5 hat `enu1u2` (USB/RP1, z.B. .203) und `wlan0` (.199). Beide im selben Subnetz. USB-Interface ist stabiler als WLAN für SSH/VNC.
- **Screenshot via grim über SSH** — grim benötigt Wayland-Env. Ausführen als user silly82: `sudo -u silly82 WAYLAND_DISPLAY=wayland-1 XDG_RUNTIME_DIR=/run/user/1000 grim -o DSI-2 /tmp/screenshot.png`
- **greetd Auto-Login (kein Greeter)** — Statt tuigreet direkt Sway starten: `services.greetd.settings.default_session = { command = "${pkgs.sway}/bin/sway"; user = "silly82"; };` — kein Login-Bildschirm, keine Session-Auswahl.

## See Also
- `references/nixos-uconsole-cm5-session.md` — full session transcript details (overlay params, Sway setup, specific file contents)