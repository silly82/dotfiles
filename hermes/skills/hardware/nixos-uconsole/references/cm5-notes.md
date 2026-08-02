# CM5 Session Debugging Notes (2026-07-14)

## Display Output Names

On the CM5 with `vc4-kms-v3d-pi5` overlay, the internal DSI display is **DSI-2**:

```
$ ls /sys/class/drm/
card0  card0-HDMI-A-1  card0-Writeback-1  card0-Writeback-2
card1  card1-DSI-2     card2              renderD128  version

$ cat /sys/class/drm/card1-DSI-2/status
connected

$ cat /sys/class/drm/card0-HDMI-A-1/status
disconnected
```

**CM4** uses DSI-1. This is the most common gotcha when migrating from CM4 to CM5.

## Input Devices on CM5

No separate touchscreen input device exists. Devices found under `/proc/bus/input/devices`:

- ClockworkPI uConsole Keyboard (usb)
- ClockworkPI uConsole Mouse (usb)
- ClockworkPI uConsole Consumer Control (usb)
- axp20x-pek (power button)
- pwr_button (GPIO power button)
- vc4-hdmi-0 (HDMI CEC/audio)
- python-uinput (virtual)

No Melfas touchscreen (present on CM4).

## Sway Config Error Diagnosis

If swaynag shows a red error bar at the top on boot:
1. The most likely cause is a wrong display output name.
2. Check with `cat /sys/class/drm/*/status` to find the `connected` DSI output.
3. Update `output DSI-X transform 90 scale 1.5` in `/etc/sway/config`.
4. Reload with `Mod+Shift+c` or restart greetd: `sudo systemctl restart greetd`.

## Binary Cache Status

`nixos-rebuild switch --flake .#uconsole` completed in ~3 minutes on CM5. All 500+ packages from cache (Cachix + cache.nixos.org). No local compilation needed unless nixpkgs is overridden.

## Partition Layout (post-flash, 32GB SD)

```
Device         Start      End  Sectors  Size Type
mmcblk0p1      16384  2113535  2097152    1G W95 FAT32  (boot/firmware)
mmcblk0p2    2113536 11863695  9750160  4.6G Linux       (ext4 /)
```

## Status Bar: Sway Native Bar with Shell Script (Fallback)

When Waybar or i3status have issues, the simplest reliable status bar is Sway's native bar with a shell script:

```
bar {
  position top
  status_command sh /etc/sway/status
  font pango:monospace 10
}
```

The script at `/etc/sway/status`:

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

Note: `iwgetid` is not available on NixOS (no wireless-tools package). Use `iw dev wlan0 info | awk '/ssid/ {print $2}'` instead.

## Nix `''` String Gotcha

When embedding bash scripts in Nix `environment.etc."..."` indented strings (`''...''`), Nix still interpolates `${variable}`. To avoid `undefined variable 'var'` errors:

- **BAD**: `echo "  $ssid  |  ${batt}%  |  $time"` → Nix sees `${batt}` and fails
- **GOOD**: `echo "  $ssid  |  $cap%  |  $now"` → no `${}` braces, no Nix interpolation

The `%` after the variable makes `${batt}%` particularly ambiguous because the closing `}` is before `%`. Simple `$var` references (no braces) are safe.