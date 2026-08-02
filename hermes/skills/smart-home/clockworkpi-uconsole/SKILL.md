---
name: clockworkpi-uconsole
description: Configure a ClockworkPi uConsole/DevTerm (CM4/CM5) handheld running Raspberry Pi OS, Debian, or NixOS — Sway/Wayland compositor setup, DSI panel rotation, image flashing, first-boot SSH access, audio/WLAN/BT verification, and remote administration. Load when the user mentions uConsole, DevTerm, ClockworkPi, or configuring a Pi handheld's display/compositor.
---

# ClockworkPi uConsole / DevTerm configuration

The uConsole is a handheld with a Compute Module (CM3/CM4/CM5). Its DSI panel is
physically PORTRAIT (720x1280) and MUST be rotated by the compositor to appear
landscape. Getting rotation and scale right is the whole game for a usable Sway setup.
everything below assumes SSH access to the device.

## NixOS CM5 — Quick Start (pre-built image)

This section covers the NixOS uConsole workflow. The repository lives at
https://github.com/nixos-uconsole/nixos-uconsole — pre-built images for CM4
and CM5 are published as GitHub Releases.

### Decompressing the image

```bash
# macOS — prefer nix shell when brew lacks a bottle for current macOS
nix shell nixpkgs#zstd -c unzstd nixos-uconsole-cm5-*.img.zst
```

If `brew install zstd` fails with `no bottle available!` (pre-release macOS),
`nix shell nixpkgs#zstd` is the reliable fallback. Use `unzstd -v` to see
progress.

### Verifying the image layout

```bash
# Mount the FAT32 boot partition on macOS:
hdiutil attach nixos-uconsole-cm5-*.img
# → /Volumes/FIRMWARE with config.txt, kernel.img, DTBs, overlays/
# The ext4 root is NOT readable on macOS without macFUSE.

# Check partition table:
nix shell nixpkgs#util-linux -c fdisk -l nixos-uconsole-cm5-*.img
```

MBR layout:
- Partition 1: FAT32, ~1 GB (boot firmware, kernel, overlays)
- Partition 2: ext4, ~4.6 GB (NixOS root)

### Flashing to SD / eMMC

```bash
diskutil list                          # identify device
sudo dd if=nixos-uconsole-cm5-*.img of=/dev/rdiskX bs=4m status=progress
sync
```

Use `rdiskX` (raw disk) on macOS for ~40 MB/s throughput.

### First boot — default credentials

**User: `root` / Password: `changeme`** (per README; must be changed on
first login). SSH is auto-enabled. Connect to WiFi with `nmtui`, then
find the IP with `ip -4 a`.

### Partition auto-expansion

NixOS SD card images auto-resize the root partition on first boot — no
separate `resize2fs` step needed. Verify with `parted /dev/mmcblk0 print`:
partition 2 should fill the entire disk.

### Setting up SSH key access

When the user provides a temporary password, use `sshpass` from the Mac to
install your public key:

```bash
sshpass -p '<temp-pw>' ssh -o PreferredAuthentications=password \
  -o PubkeyAuthentication=no root@<ip> \
  "mkdir -p ~/.ssh && chmod 700 ~/.ssh && \
   echo '<pubkey>' >> ~/.ssh/authorized_keys && \
   chmod 600 ~/.ssh/authorized_keys"
```

After key login works, remind the user the password is in the chat
transcript — they should `passwd` on the uConsole.

### CM5 config.txt (pre-configured in image)

Relevant `[cm5]` section of `/boot/firmware/config.txt`:
- `dtoverlay=clockworkpi-uconsole-cm5` — display, buttons, battery, audio
- `dtoverlay=vc4-kms-v3d-pi5` — GPU/display stack
- `dtparam=pciex1=off` — free PCIe lane for 4G module
- `dtoverlay=dwc2` with `dtparam=dr_mode=host` — USB host mode

## Establish access first
See references/remote-ssh-admin.md for the connect + key-copy recipe and the
critical sudo-password constraint. TL;DR: use `ssh-copy-id` for passwordless key
login, but Hermes BLOCKS piping passwords into `sudo -S` on the remote host — so
either the user grants NOPASSWD sudo, or you restrict work to the home dir
(`~/.config/...`), which needs no sudo and covers all compositor config.

## Step 1 — Snapshot the current state (never guess, read the machine)
Run these read-only probes over SSH before changing anything:
- `systemctl get-default` and `loginctl` — is a graphical target/DM active?
- `ls /usr/share/wayland-sessions/` — which sessions the DM offers (sway.desktop, labwc.desktop, ...).
- `cat /boot/firmware/config.txt` — the uConsole dtoverlays (NOT /boot/config.txt, which is a stub redirect on Debian 13/trixie).
- `cat /boot/firmware/cmdline.txt` — look for `fbcon=rotate:1` (rotates the TEXT console only, not the compositor).
- Audio: `systemctl --user is-active pipewire pipewire-pulse wireplumber` (modern stack; ideal for Wayland).
- Net: `nmcli -t -f STATE general` and `nmcli connection show --active`.
- GPU: `ls /dev/dri/` — expect card0/card1 + renderD128 when vc4-kms-v3d is live.

## Step 2 — CRITICAL: discover panel rotation, don't guess
The single most important trick: if labwc (the ClockworkPi default DE) is already
installed and the display looks correct there, READ ITS ROTATION VALUES and reuse
them for Sway. Check in order:
- `~/.config/kanshi/config` — labwc drives outputs via kanshi. Look for a line like:
  `output DSI-1 enable scale 1.500000 mode 720x1280@59.901 position 0,0 transform 270`
  Those exact values (transform + scale + mode) are what Sway needs.
- `~/.config/labwc/rc.xml` — fallback if kanshi isn't used.

For the CM4 uConsole common values are: `scale 1.5`, `transform 270` *or* `transform 90`,
output name `DSI-1`. That yields an effective ~853x480 landscape (1280/1.5 x 720/1.5).
**Do not blindly assume one or the other** — the correct transform depends on how the
DSI ribbon cable is routed in that specific unit. Some need 90° clockwise (`transform 90`),
others need 270° clockwise (`transform 270`). These are exact opposites (180° apart), so
guessing the wrong one produces an upside-down display. Always read the existing config.
CM5 may report the panel as `DSI-2`. Confirm the output name with `swaymsg -t get_outputs`
inside a running Sway, or from the kanshi config.

## Step 3 — Write the Sway config (home dir, no sudo)
Copy templates/sway-uconsole-config to `~/.config/sway/config` and adjust the
`output` line to the discovered name/transform/scale. It sets small fonts/gaps for
the tiny screen and binds uConsole volume/brightness keys (wireplumber + brightnessctl).
`sway.desktop` already exists in /usr/share/wayland-sessions/, so lightdm CAN offer
Sway — but on stock ClockworkPi images the default greeter hides the chooser (see Step 3b).

### Waybar restart on Sway reload
By default, Sway's `exec waybar` only starts waybar on first login. `$mod+Shift+c` (reload)
does NOT restart waybar, so config/font/icon changes in waybar won't appear until the user
manually kills and re-launches it. Fix this by using `exec_always`:

```ini
exec_always killall waybar 2>/dev/null
exec_always waybar
```

This kills any old waybar process and starts a fresh one on every Sway start AND reload.
The user can then test waybar changes by pressing `$mod+Shift+c` instead of having to
open a terminal and type `killall waybar; waybar &`.

### Display scaling limitations on CM4 (vc4-kms-v3d)
The Raspberry Pi CM4 uses the **Pixman** software renderer by default. Sway's
`renderer gles2` produces `error: invalid renderer` — the vc4-kms-v3d stack
on the CM4 does not expose a GLES2 renderer to Sway. As a result, **fractional
scaling** (e.g. `scale 1.25`) produces noticeably **blurry** output because
Pixman cannot anti-alias non-integer scale factors cleanly.

Stick with one of these scale values for a crisp image:
- `scale 1.0` — native 1280x720 effective (very small UI; compensate with
  larger font sizes in Sway's `font pango:...` line)
- `scale 1.5` — effective ~853x480 (recommended; sharp and readable)

Do NOT set a `renderer` directive in the Sway config at all — Pixman is the
only working option on this hardware, and it handles integer-approximate
scales fine once you avoid fractional scale values.

### Installing Nerd Font icons for waybar
The Liberation Mono font on stock Debian has no icon glyphs for waybar modules (battery,
wifi, volume, logout). Install the Nerd Font Symbols package headless:

```bash
mkdir -p ~/.local/share/fonts
cd ~/.local/share/fonts
curl -sL 'https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/NerdFontsSymbolsOnly.zip' \
  -o symbols.zip && unzip -qo symbols.zip '*.ttf' && rm symbols.zip
fc-cache -fv
```

Then in `~/.config/waybar/style.css`, set `font-family: "Fira Code", "Symbols Nerd Font", monospace;`
(or your preferred body font) so waybar can render Nerd Font icons like `\uf011` (power-off),
`\uf1eb` (wifi), `\uf028` (volume-high), `\uf240` (battery-full). See
`references/waybar-icons-nerdfont.md` for common icon codepoints used on the uConsole.
Remember: after adding fonts, waybar must be restarted — use the `exec_always` approach above
so `$mod+Shift+c` handles it automatically.

### greetd/gtkgreet/cage transform quirk
If Sway uses `transform 90` and the login screen (cage+gtkgreet) appears
180° rotated (upside-down), check whether the `wlr-randr` in the greetd
runner actually fired. Cage initializes outputs at 0° by default, and a
`sleep 0.4` before `wlr-randr` may be too short — try `sleep 1` first.
If that doesn't help, flip the runner to `transform 270` (the opposite
of Sway's value) and test. The underlying cause (cage compositor quirk
vs wlr-randr race condition) is not fully understood — iterate with the
user.

### The Super key: uConsole has NO Win/Super key
The uConsole keyboard has two Alt keys and no dedicated Super/Win key, so the
default Sway `$mod Mod4` (Super) is unreachable. Fix it IN the Sway config by
remapping left Alt to Super via xkb — do not tell the user to reach for Fn combos:
```
input type:keyboard {
    xkb_options altwin:swap_lalt_lwin
}
set $mod Mod4
```
`altwin:swap_lalt_lwin` swaps Left Alt with Left Win; since the uConsole has no
physical Win key, the left-Alt position ends up sending Super_L while the RIGHT Alt
stays a normal Alt (for apps, Alt+Tab, terminal Meta). Result: left Alt = your Sway
`$mod`. Confirm the option exists on the box first:
`grep -i altwin /usr/share/X11/xkb/rules/base.lst`. Plan B if left-Alt still doesn't
send Super (some keyboard firmware quirks): `altwin:alt_win` makes BOTH Alt keys
also act as Super. Verify headless: the Step 4 sway syntax-check must show no
`xkb`/`keymap`/`invalid` errors.

## Step 3b — CRITICAL: make lightdm show a session chooser WITHOUT crashing X
On stock ClockworkPi/RPi-OS images `/etc/lightdm/lightdm.conf` sets
`greeter-session=pi-greeter-labwc` (or `pi-greeter`). That greeter shows ONLY
password + Login + Shutdown — NO session-selection menu — and the image usually
also has `autologin-session=rpd-labwc`, which skips the login screen entirely. So
the user CANNOT pick Sway.

DO NOT just switch `greeter-session` to `lightdm-gtk-greeter`. On the uConsole this
FAILS: the plain gtk-greeter's `.desktop` has no `X-LightDM-Session-Type=wayland`
marker, so lightdm launches it under Xorg, and Xorg cannot init the DSI/vc4-kms
panel (`x-0.log`: `AddScreen/ScreenInit failed for driver 0` → X exits 1 →
`greeter display server failed to start` → lightdm restart-loops until
`start-request-repeated-too-quickly`). The whole Pi setup is Wayland; X is a dead end.

CORRECT fix: run the gtk-greeter (which HAS the session gear) INSIDE labwc/Wayland,
mirroring how `pi-greeter-labwc` runs. Recipe (needs sudo; back up first):
1. `sudo cp /etc/lightdm/lightdm.conf /etc/lightdm/lightdm.conf.bak.$(date +%s)`
2. Clone the working labwc-greeter dir:
   `sudo cp -rn /etc/xdg/labwc-greeter /etc/xdg/labwc-gtk-greeter`
3. Edit `/etc/xdg/labwc-gtk-greeter/autostart` so it launches the gtk-greeter instead
   of pi-greeter — keep the wlr-randr/kanshi rotation lines, and use the ABSOLUTE
   path: the binary is at `/usr/sbin/lightdm-gtk-greeter` (NOT /usr/bin — it is NOT
   on PATH, so a bare `lightdm-gtk-greeter &` yields `not found`). See
   templates/labwc-gtk-greeter-autostart.
4. Create `/usr/share/xgreeters/gtk-greeter-labwc.desktop` with
   `Exec=/usr/bin/labwc -C /etc/xdg/labwc-gtk-greeter/` and, crucially,
   `X-LightDM-Session-Type=wayland`. See templates/gtk-greeter-labwc.desktop.
5. In lightdm.conf set `greeter-session=gtk-greeter-labwc` and comment out
   `autologin-session=...`.
6. Optionally tune `/etc/lightdm/lightdm-gtk-greeter.conf` `[greeter]` with
   `indicators=~session;~spacer;~clock;~spacer;~power` so the session chooser is
   clearly visible.
The gtk-greeter may now render under labwc/Wayland with a visible session menu.
BUT BEWARE: on at least some CM4 uConsole images this STILL fails — the gtk-greeter
2.0.9 is a GTK/X11 app that starts under Wayland but cannot size its window: the log
shows `Gtk-WARNING Drawing a gadget with negative dimensions ... GreeterMenuBar`
followed by `Gdk-CRITICAL gdk_x11_window_get_xid`, and the panel shows ONLY A MOUSE
CURSOR on a black screen (window never becomes visible). These are NOT harmless —
they mean the gtk-greeter is unusable under labwc. If you see only a cursor, abandon
the gtk-greeter path and use greetd + gtkgreet + cage instead (Step 3c), which is the
robust native-Wayland answer and is the RECOMMENDED approach for a reliable session
chooser on this hardware.

## Step 3c — RECOMMENDED reliable session chooser: greetd + gtkgreet + cage
When you need a dependable graphical login WITH a session menu on the uConsole, the
clean native-Wayland stack is `greetd` (login daemon) + `gtkgreet` (GTK greeter that
speaks greetd) running inside `cage` (a minimal wlroots kiosk compositor). This
runs on the same wlroots stack as Sway/labwc, so no X, no invisible-window bug.
Needs sudo. Recipe (see templates/greetd-config.toml, templates/greetd-gtkgreet-run,
templates/greetd-environments):
1. `sudo apt-get install -y greetd gtkgreet cage` (the greetd postinst warns that
   display-manager.service is still a symlink to lightdm — expected; you switch it last).
2. Write `/usr/local/bin/greetd-gtkgreet-run` (755): rotates the panel then execs
   gtkgreet — see `templates/greetd-gtkgreet-run`. **Cage has no `--transform` flag** — it
   only accepts `-s` (VT switching) and `-m` (multi-output mode). Rotation must be done
   entirely via wlr-randr inside the cage session. The `sleep 1` is deliberate: cage takes
   ~1 second to initialise the output, and `sleep 0.4` is often too short, leaving the
   panel at the default 0° rotation until wlr-randr catches up.
3. Write `/etc/greetd/config.toml`: `[default_session] command = "cage -s -- /usr/local/bin/greetd-gtkgreet-run"`, `user = "_greetd"`, `[terminal] vt = 7`.
4. Write `/etc/greetd/environments` listing the selectable session commands, one per
   line: `sway`, `labwc`, `bash`. gtkgreet reads this to build the session dropdown
   (with no `-c` flag gtkgreet asks which environment to launch).
5. CRITICAL — grant `_greetd` the device groups or cage gets no GPU/keyboard and you
   get a black screen with just a cursor: `sudo usermod -aG video,input,render _greetd`
   (fresh `_greetd` is in NO extra groups by default — always check `id _greetd`).
6. Switch the display manager:
   - First disable lightdm: `sudo systemctl disable lightdm`. If `sudo systemctl stop lightdm`
     **hangs** (it often does when holding DRM), use `sudo systemctl kill lightdm` first,
     THEN `sudo systemctl stop lightdm`.
   - Repoint the symlink: `sudo ln -sf /lib/systemd/system/greetd.service
     /etc/systemd/system/display-manager.service`
   - `sudo systemctl daemon-reload && sudo systemctl enable --now greetd`
   - **Verify no competing DMs:** run `systemctl is-active lightdm greetd` and confirm
     lightdm is `inactive` and greetd is `active`. If BOTH are active, they fight for
     the display and the user sees unpredictable behaviour (wrong greeter, blank screen).
     In that case stop+disable lightdm as above, then restart greetd.
   - Keep lightdm INSTALLED as a fallback.
7. Verify: `systemctl is-active greetd` = active; `journalctl -u greetd` should show
   `session opened for user _greetd` (greeter shown) then, after login, `session
   opened for user <you>`; then `pgrep -a sway` (or labwc) confirms the chosen session
   plus its autostart (waybar/mako) are running. The greeter/cage processes exit once
   login hands off — that's normal, not a crash.
Harmless log noise under this stack: `Failed to parse EDID`, AT-SPI/dbind warnings,
`unknown output DSI-2` — ignore.

Do config edits as ONE ssh heredoc; if the connection drops mid-run (WLAN handhelds
flake), re-probe the file state with grep BEFORE re-running — never blindly repeat
sed on a config you may have already edited.

### Recovering from a lightdm restart-loop
If a greeter change loops lightdm, it usually leaves an ORPHANED display server
holding the panel. Before any restart succeeds you must free DRM:
`sudo fuser -v /dev/dri/card1` shows the culprit (e.g. a stray `Xorg :1 vt7`). Then:
`sudo systemctl stop lightdm; sudo pkill -9 Xorg; sudo pkill -9 -f lightdm;
sudo systemctl reset-failed lightdm; sudo systemctl start lightdm`. Confirm with
`systemctl show lightdm -p NRestarts --value` (want 0) and `pgrep -a labwc`.
Note: the systemd `NRestarts`/journal only says `exited status=1` — the real reason
is in `/var/log/lightdm/lightdm.log`, `/var/log/lightdm/x-0.log`, and
`/var/log/lightdm/seat0-greeter.log`. Always read those three, not just journalctl.

## 4G/LTE Modul (SIMCOM SIM7600G-H)

The uConsole CM4 has an optional LTE Cat-4 module (SIM7600G-H) connected via
internal Mini-PCIe. It is controlled via GPIO and managed by ModemManager.

### Prerequisites

```bash
sudo apt-get install -y modemmanager
```

### Power control

The module is powered off by default to save battery. Control via GPIO:

```bash
# Einschalten
sudo uconsole-4g enable
# ~20s später — Modem sollte da sein:
mmcli -L
mmcli -m 0

# Ausschalten (Akku sparen)
sudo uconsole-4g disable
```

The `uconsole-4g` wrapper calls `/usr/local/bin/uconsole-4g-cm4.sh` which
toggles GPIO 24 (power) and GPIO 15 (PWRKEY) via `pinctrl`.

### What you see when it works

After `enable`, the modem appears as:
- **USB:** `1e0e:9001 Qualcomm / Option SimTech, Incorporated`
- **TTYs:** `/dev/ttyUSB0-4` (AT commands, GPS, audio)
- **Network:** `wwan0` (QMI via `qmi_wwan` driver)
- **ModemManager:** Modem 0 with SIMCOM_SIM7600G-H

Probe with:
```bash
mmcli -L                              # list modems
mmcli -m 0                            # full status
mmcli -m 0 --set-primary-sim-slot=1   # activate SIM slot
```

### Troubleshooting: sim-missing

```
failed reason: sim-missing
```

Meaning the modem HW is detected but no SIM card is present or recognised.
Check:
1. Is a SIM physically inserted in the slot on the back of the 4G module?
2. Is it properly seated? Try reseating.
3. ModemManager shows `sim slot paths: slot 1: none (active)` if empty.

Once the SIM is detected, `mmcli -m 0` will show:
```
state: registered
operator name: <provider>
signal quality: <percent>
```

### NetworkManager connection (QMI)

```bash
# APN anpassen! Typisch: internet, telekom, web.vodafone, o2, ...
sudo nmcli connection add type gsm ifname cdc-wdm0 con-name "4G" apn "internet"
sudo nmcli connection up "4G"
```

For `ifname`, use the wdm port (usually `cdc-wdm0`) — NOT `wwan0`.
The `qmi_wwan` kernel driver handles upstream; NetworkManager talks to
ModemManager via the cdc-wdm QMI port.

### Note for CM5

The CM4-to-CM5 overlay files exist in `/usr/lib/linux-image-*/overlays/`:
`clockworkpi-uconsole-cm4.dtbo`, `clockworkpi-uconsole-cm5.dtbo`. GPIO
assignments for 4G power may differ on CM5 — the uconsole-4g tool has
separate `enable` / `disable` handlers for each core variant.

## WiFi GUI — iwgtk (requires iwd) vs nmtui (NetworkManager)

The uConsole's small display makes terminal-based WiFi selection
uncomfortable. Two GUI options exist, depending on which WiFi backend
is active.

### Option A: iwgtk (requires iwd)

iwgtk (196 KB, Wayland-native, no X11 deps) is a GUI frontend for
iwd (iNet Wireless Daemon). If the system uses NetworkManager
with wpa_supplicant (the standard Debian setup), iwd is NOT running by
default and iwgtk will fail silently or show no networks.

To use iwgtk:
```bash
sudo apt-get install -y iwgtk iwd
sudo systemctl disable wpa_supplicant   # stop the default backend
sudo systemctl enable --now iwd         # start iwd instead
sudo systemctl restart NetworkManager   # NM auto-detects iwd backend
```

Then bind it to the Waybar network module:
```jsonc
// In ~/.config/waybar/config.jsonc
"network": {
    // ... existing fields ...
    "on-click": "iwgtk"
}
```

After restarting waybar (see exec_always pattern above), clicking the
wifi icon opens iwgtk showing available networks, connection status, and
quick connect/disconnect.

**CRITICAL:** If iwd is not active, iwgtk will NOT work. Check first:
```bash
systemctl is-active iwd
```
If it returns inactive, do NOT set on-click to iwgtk without also
installing and enabling iwd as above. Install both together or choose
Option B.

### Option B: nmtui (works with any NetworkManager backend)

If the system uses standard NetworkManager (wpa_supplicant or iwd), the
simpler option is nmtui — a terminal-based NetworkManager UI:

```bash
# nmtui is usually installed with NetworkManager itself
which nmtui || sudo apt-get install -y nmtui
```

Bind it to the Waybar network module — it launches inside foot terminal:

```jsonc
// In ~/.config/waybar/config.jsonc
"network": {
    // ... existing fields ...
    "on-click": "foot -e nmtui"
}
```

nmtui offers connect/disconnect, saved network management, and works
with both wpa_supplicant and iwd backends. No backend migration needed.

## App launcher — fuzzel

Recommended replacement for `wmenu-run` on the small display — fuzzy search,
Wayland-native, compact:

```bash
sudo apt-get install -y fuzzel
```

Then in Sway config:
```ini
set $menu fuzzel
```

After Sway reload (`$mod+Shift+c`), `$mod+d` opens fuzzel instead of
wmenu-run. It works well with `scale 1.5` — text is readable and the
window doesn't overflow the 853x480 effective area.

## Dotfile versioning — commit after every config change

This user expects every config change to its uConsole to be committed
and pushed to `~/uconsole-dotfiles/` (GitHub: silly82/uconsole-dotfiles).
See `references/dotfiles-version-control.md` for the exact copy+commit+push
commands. Always do this as the final step of any config change session.
## Step 4 — Validate configs over SSH (before asking the user to log in)

You cannot launch a real Sway session over plain SSH (no seat/TTY). Do NOT trust
`sway --validate -c <file>` over SSH: it still tries to open a DRM session and
spews alarming but HARMLESS errors (`libseat ... Could not open target tty`,
`Timeout waiting session to become active`, `Unable to create backend`). Those are
NOT config errors. To actually syntax-check each config headless over SSH:
- Sway:   `WLR_BACKENDS=headless WLR_LIBINPUT_NO_DEVICES=1 timeout 5 sway -c ~/.config/sway/config 2>&1 | grep -iE 'error|invalid|unknown|expected' | grep -viE 'wlr|backend|drm|seat|dbus|xdg|udev|render|Could not'`
  If nothing config-related prints, sway parsed the file through to the autostart execs — it's clean.
- waybar:  `timeout 3 waybar -c <cfg> -s <style> 2>&1 | grep -iE 'error|invalid|json'` — "Using configuration file" with no JSON error = good. AT-SPI/dbind warnings are harmless headless noise.
- foot:    `foot --check-config` — prints "config OK" or the error.

## Step 5 — Verify + hand off
- `swaymsg -t get_outputs` → confirm the panel is active, correct transform, not blank.
- Tell the user to select Sway at the lightdm login and confirm the image is landscape and readable.
- Be honest: configs are only syntax-validated over SSH; the real proof is the first on-device Sway login. Ask the user to report exactly what they see if anything's off.
- Optional comfort packages (need sudo): `waybar mako-notifier wl-clipboard cliphist fuzzel`.
  After installing fuzzel, set it as the app launcher in Sway config:
  `set $menu fuzzel` (replaces wmenu-run). Then `$mod+d` opens fuzzel with
  fuzzy search — much nicer on a small screen than wmenu-run.
- For a ready-made handheld status bar, copy templates/waybar-uconsole-config.jsonc (Workspaces | clock | volume/backlight/wifi/battery) — uses the uConsole hardware paths: battery `axp20x-battery`, backlight device `backlight@0`. Discover them with `ls /sys/class/power_supply/` and `brightnessctl -l`.

## Pitfalls
- **WiFi signal weakness: `dtparam=ant2` and power save.** Stock uConsole
  firmware uses `dtparam=ant2` (U.FL antenna port). If the IPEX cable is loose
  or the chassis antenna disconnected, signal drops to -70 dBm or worse at short
  range. Try `dtparam=ant1` (onboard PCB antenna) to compare. Also: the
  `brcmfmac` driver enables power save by default, reducing TX power. Disable
  with `sudo /usr/sbin/iw dev wlan0 set power_save off` or via
  NetworkManager config (`/etc/NetworkManager/conf.d/powersave.conf` with
  `wifi.powersave = 2`). See `references/wifi-signal-troubleshooting.md`.
- **Waybar network module shows wifi "off" even when Ethernet is connected.** The Waybar network module tracks the first network interface by default. If wlan0 (wifi) exists but is disconnected, it shows format-disconnected ("off") even when eth1 (Ethernet) is fully up. Fix: either (a) connect wifi too so both interfaces are up, (b) set `"interface": "eth1"` in the waybar network config to pin it to Ethernet, or (c) use `"interface-type": "wifi"` to always show wifi state. Without an explicit interface, waybar picks the first one NetworkManager reports — usually wlan0 if it exists.
- **Emoji/Unicode SSIDs fail with nmcli:** SSIDs containing emoji characters or Unicode variation selectors (e.g. `✂️Figaro✂️`) often produce `Error: No network with SSID '...' found` even when the network is visible in `nmcli d wifi list`. The SSID match fails due to how nmcli handles multi-byte characters. Workarounds: (a) connect to a non-emoji variant AP from the same mesh network (e.g. `figaro` instead of `✂️Figaro✂️`), (b) use `sudo nmcli d wifi connect <BSSID> password <password>` to connect by BSSID instead of SSID (no `bssid` keyword — the BSSID replaces the SSID argument directly), or (c) use `sudo nmtui` which handles the SSID correctly via its interactive interface. Check `nmcli -f SSID,BSSID,SIGNAL d wifi list | grep -i <keyword>` for alternative SSIDs from the same vendor. **Important:** `nmcli d wifi connect` without `sudo` fails with `Not authorized to control networking` unless PolicyKit is configured — always prefix with `sudo` when connecting a new network.
- **`/usr/sbin/` not in PATH on Debian trixie.** Commands like `iw`, `ip`, and other admin tools live in `/usr/sbin/` which is NOT in the default user PATH. Always use full paths (`/usr/sbin/iw`) or `sudo` with absolute paths when running diagnostic commands over SSH. The terminal tool's default shell is a non-login shell that inherits this restricted PATH.
- **`renderer gles2` is NOT available on CM4 vc4-kms-v3d.** Setting it in Sway
  config produces `error: invalid renderer` on the next Sway start/reload. The
  only working renderer is Pixman (default). Do not set any `renderer` line.
  Pixman handles `scale 1.5` fine but makes fractional scaling (1.25, 1.33)
  look blurry — stick with integer-friendly scales (see "Display scaling
  limitations" above).
- **`swaymsg` does not work over SSH.** Running `swaymsg exec 'killall waybar; waybar'` from an SSH session returns `Unable to retrieve socket path` — the Sway socket is only accessible from within the display session. To restart waybar or reload Sway remotely, you must either (a) give the user a terminal command to type, (b) add a Sway keybinding (`exec_always` pattern), or (c) ask them to log out and back in. Do not attempt `swaymsg` over SSH and expect it to reach the running compositor.
- The uConsole keyboard has NO Super/Win key — remap left Alt via `xkb_options altwin:swap_lalt_lwin` in Sway's `input type:keyboard` block (see Step 3). Don't leave `$mod Mod4` unreachable.
- **Transform mismatch between greeter and Sway = 180° rotation.** The greeter (labwc via `/etc/xdg/labwc-greeter/autostart` or greetd via `/usr/local/bin/greetd-gtkgreet-run`) calls `wlr-randr --output DSI-1 --transform <N>` to rotate the login screen. If Sway's config uses a *different* transform value, the login screen will be exactly 180° rotated relative to the Sway desktop — the user sees it upside down even though each compositor alone looks fine. Always read BOTH values before declaring an orientation problem:
  - Greeter (labwc): `grep transform /etc/xdg/labwc-greeter/autostart`
  - Greeter (greetd): `grep transform /usr/local/bin/greetd-gtkgreet-run`
  - Sway: `grep transform ~/.config/sway/config`
  - Fix: make them match. `sudo sed -i 's/--transform 270/--transform 90/g' /etc/xdg/labwc-greeter/autostart` (or vice versa) then `sudo systemctl restart lightdm` to apply. For greetd, edit the runner script then `sudo systemctl restart greetd`.
  - Note: `transform 90` (clockwise) and `transform 270` (counter-clockwise) are exact opposites. Some uConsole CM4 panels need 90, some 270 — depends on how the ribbon cable is routed. What matters is that greeter and Sway agree.
- Stock ClockworkPi lightdm uses `pi-greeter-labwc`, which shows NO session chooser and often auto-logs into labwc. For a RELIABLE chooser, prefer greetd + gtkgreet + cage (Step 3c) — it is native Wayland and just works. The gtk-greeter-inside-labwc approach (Step 3b) sometimes renders only a mouse cursor (`Drawing a gadget with negative dimensions` → invisible window) and is a GTK/X11 app fighting Wayland; treat it as a fallback, not the first choice. NEVER point `greeter-session` at bare `lightdm-gtk-greeter`: that runs under X, and Xorg cannot init the DSI/vc4-kms panel (`AddScreen/ScreenInit failed`), looping lightdm.
- greetd's `_greetd` user is in NO extra groups on a fresh install — cage needs `video,input,render` or you get a black screen + cursor only. `sudo usermod -aG video,input,render _greetd` and re-check `id _greetd` before switching the DM.
- **Competing display managers:** greetd and lightdm can both be `systemctl is-active` simultaneously. This produces unpredictable behaviour — the wrong greeter shows, or the display flickers between them. After switching to greetd, ALWAYS verify: `systemctl is-active lightdm greetd`. If lightdm is still active, `sudo systemctl kill lightdm; sudo systemctl stop lightdm; sudo systemctl disable lightdm`, then `sudo systemctl restart greetd`. The `stop` alone may hang on DRM — `kill` first, then `stop`.
- **Writing greetd runner scripts over SSH:** The runner script contains `&` (backgrounding the wlr-randr sleep). The terminal tool rejects foreground commands containing `&`. Workaround: use `sudo bash -c 'printf "..." > target'` with `\n` for newlines, or transport via base64, or write the script in two parts (write without `&`, then `sed` to insert it).
- Switching display managers = repoint `/etc/systemd/system/display-manager.service` symlink AND `systemctl disable lightdm; enable greetd`. Keep lightdm installed as a fallback in case greetd misbehaves.
- The gtk-greeter binary lives in `/usr/sbin/lightdm-gtk-greeter`, not /usr/bin, and is NOT on PATH — labwc autostart must use the absolute path or it silently fails with `not found`.
- A failed greeter swap can leave an orphaned Xorg/labwc holding `/dev/dri/card1`, which blocks EVERY subsequent lightdm start. Free it: `sudo fuser -v /dev/dri/card1`, then pkill the stray server before restarting lightdm (see Step 3b recovery).
- lightdm's journal/`NRestarts` only says `exited status=1`. The real cause is in /var/log/lightdm/{lightdm,x-0,seat0-greeter}.log — read those.
- Editing /boot/config.txt does nothing on Debian 13 — it's a redirect stub to /boot/firmware/config.txt.
- `fbcon=rotate:1` in cmdline.txt only rotates the tty console. The compositor still needs its own transform.
- If the DSI panel reports 720x1280 but the image is landscape, rotation is already happening in the compositor (kanshi/labwc) — Sway will NOT inherit it; you must set `transform` in Sway's own config.
- Don't set rotation in config.txt display_rotate for KMS/vc4 panels — it's ignored under vc4-kms-v3d. Rotate in the compositor.
- Passwords typed into the chat land in the session transcript in cleartext. After key login works, remind the user they can rotate the password.

## Raspberry Pi Connect — Remote Access
See references/rpi-connect.md for setup and usage of the rpi-connect service
(systemd user service, sign-in via connect.raspberrypi.com, VNC/shell access).
Installed as `rpi-connect` (package) and starts automatically `--user` on login.
No port-forwarding needed.

### VNC Maus-Probleme bei Sway transform 90
Wenn Sway `transform 90` verwendet und die VNC-Maus via Raspberry Pi Connect
in die falsche Richtung läuft: Das Problem liegt bei wayvnc, das die
Mauskoordinaten im schon transformierten Raum sendet. Fix ist ein
systemd-Override mit `--transient-seat -o DSI-1`. Details in
`references/rpi-connect.md` unter "Bekanntes Problem".

## Sway Shortcuts Wallpaper — cheatsheet hintergrund
See scripts/sway-shortcuts-wallpaper.py for a Python/Pillow script that
generates a dark-themed 1280x720 PNG showing all Sway keybindings. The script
supports two layout modes:
- **Single-column** (default fonts: 22pt title, 13pt headings, 11pt text)
- **Two-column / double-size** (44pt title, 26pt headings, 22pt text) — edit
  the font size constants and sections layout at the top of the script.
Transfer to `~/.config/sway/wallpaper.png`, set `output * bg .../wallpaper.png fill` in
Sway config, reload with `$mod+Shift+C`. Layout is optimised for the uConsole's
small DSI display (853x480 effective with scale 1.5). Uses python3-pil
(Pillow) which ships in the default Debian RPi image. ImageMagick (convert)
is NOT available on the RPi — use Pillow instead.

## WiFi signal weakness — reference
See references/wifi-signal-troubleshooting.md for uConsole-specific WiFi
diagnosis (antenna selection, power save, 5 GHz vs 2.4 GHz, signal-level
expected ranges). Key pitfalls captured in the Pitfalls section below.

## uConsole config.txt reference
See references/config-txt-overlays.md for the meaning of each dtoverlay line
(uconsole overlay, vc4-kms-v3d-pi4 cma-384, audremap audio, dwc2 host, ant2 WLAN antenna).
