---
name: nixos-sd-card
description: Download, extract, mount, inspect, and flash NixOS SD card images for Raspberry Pi / CM4 / CM5 / uConsole on macOS and Linux. Covers .zst decompression fallbacks, macOS disk image attachment, ext4 root inspection, and flashing using dd.
---

# NixOS SD Card Image Handling

Pre-built NixOS SD card images for Raspberry Pi and Compute Modules (CM4, CM5, CM3) are distributed as `.img.zst` files. This skill covers the full workflow: decompressing, mounting, inspecting the boot partition, and writing to a physical SD card.

## Prerequisites

- **zstd** — for decompressing `.zst` files. On macOS, Homebrew often has no bottle for pre-release versions. Fallback to **Nix**:
  ```bash
  nix shell nixpkgs#zstd -c unzstd -v image.img.zst
  ```
  This unpacks the `.zst` to a `.img` file in the same directory (the `.zst` source is deleted on success by default).

## Step 1 — Inspect the Downloaded Image

After decompression, check the partition layout:

```bash
nix shell nixpkgs#util-linux -c fdisk -l nixos-uconsole-*.img
```

Typical layout for Raspberry Pi / CM images:
| Partition | Size  | Type   | Content                          |
|-----------|-------|--------|----------------------------------|
| 1         | 1 GB  | FAT32  | FIRMWARE — boot firmware, DTBs, config.txt, kernel |
| 2         | ~4-5 GB | Linux (ext4) | NixOS root filesystem |

## Step 2 — Mount and Inspect on macOS

### FAT32 Boot Partition

Use `diskutil image attach` (the modern replacement for the deprecated `hdiutil attach`):

```bash
diskutil image attach nixos-uconsole-cm5-v1.1.1.img
```

This mounts the FAT32 partition at `/Volumes/FIRMWARE/`. Key files to inspect:

- **`config.txt`** — Raspberry Pi firmware configuration. Look for `[cm5]`, `[cm4]`, `[all]` sections with `dtoverlay`, kernel, and GPU settings. uConsole-specific: `clockworkpi-uconsole-cm5.dtbo`, `vc4-kms-v3d-pi5`, `dwc2` (USB host mode).
- **`nixos/default/cmdline.txt`** — kernel command line. Contains the NixOS store path for `init=`.
- **`nixos/default/kernel-link`** — symlink content pointing to `/nix/store/.../Image` (the actual kernel).
- **`nixos/default/system-link`** — symlink content pointing to the NixOS system path.
- **`nixos/default/*.dtb`** — device tree blobs for various Pi models (bcm2712-rpi-cm5-cm5io.dtb, etc.).
- **`bootcode.bin`, `start*.elf`, `fixup*.dat`** — Raspberry Pi boot firmware files.

### ext4 Root Partition (macOS)

macOS cannot natively mount Linux ext4 partitions. Two options:

1. **macFUSE + ext4fuse** (if installed): `ext4fuse /dev/diskXs2 /mnt/nixos -o allow_other`
2. **`fdisk -l` on the .img file** (see Step 1) to view the partition layout without mounting.
3. On Linux (physical or VM): mount with `mount -t ext4 /dev/sdX2 /mnt`.

The root partition contains the **NixOS system closure** at a path like `/nix/store/...-nixos-system-nixos-sd-card-<version>/`. This is a read-only store; local configs are at `/etc/nixos/`.

### Detach the image when done:

```bash
diskutil eject /Volumes/FIRMWARE
# or
hdiutil detach /dev/diskX
```

## Step 3 — Write to SD Card

### Identify the SD card

```bash
diskutil list
```

Look for an external, removable disk of the right size (e.g. 31.3 GB, no filesystem). Double-check the device node (e.g. `/dev/disk12`).

### Write the image

```bash
sudo dd if=nixos-uconsole-cm5-v1.1.1.img of=/dev/rdiskX bs=4m status=progress conv=fsync
```

- Use **`rdisk`** (raw disk) instead of `disk` — much faster on macOS.
- `conv=fsync` ensures data is flushed before the command exits.
- The image is typically ~6 GB; writing takes 1-3 minutes on a UHS-I SD card reader.

### Verify

The SD card will not mount on macOS after writing (NixOS uses ext4 + FAT32 which macOS partially recognises). To verify the boot partition is intact:

```bash
diskutil list  # confirm the newly written partitions exist
```

Or on the target device: the NixOS system boots with serial console output on the default uConsole UART pins.

## Post-Flash: Resize Root Partition

After writing to an SD card (especially one larger than ~6 GB), the root partition only uses as much space as the original image. Expand it to fill the card:

```bash
# Identify the SD card device
diskutil list

# Resize partition 2 to 100% (Linux parted via nix)
nix shell nixpkgs#parted -c "sudo parted /dev/diskX resizepart 2 100%"

# Resize the ext4 filesystem
nix shell nixpkgs#e2fsprogs -c "sudo resize2fs /dev/diskXs2"
```

Or simpler, boot the NixOS system and run from the device itself:
```bash
sudo parted /dev/mmcblk0 resizepart 2 100%
sudo resize2fs /dev/mmcblk0p2
```

## First Boot & Initial Setup

### Default Credentials

The pre-built images from [nixos-uconsole/nixos-uconsole](https://github.com/nixos-uconsole/nixos-uconsole) use:
- **User:** `root`
- **Password:** `changeme` (mandatory password change on first login)

### Connect to WiFi

```bash
nmtui
```

Select "Activate a connection", pick your SSID, enter the password. NixOS uses NetworkManager by default — no extra config needed.

On CM5 with a keyboard: the key combo is functional out of the box for `nmtui` navigation.

### Find the IP

If you don't have a screen connected:

1. **Serial console** — connect via UART and watch the boot log:
   ```bash
   screen /dev/tty.usbserial-* 115200
   ```
2. **Network scan** — from another machine on the same subnet:
   ```bash
   arp-scan --localnet          # if available
   nmap -sn 192.168.1.0/24      # or use your subnet
   ```
3. **Router DHCP lease** — check your router's connected-devices page.

On the uConsole itself (if the display works):
```bash
ip -4 a show wlan0
```

### SSH Access

SSH is enabled by default. Connect from another machine:

```bash
ssh root@<ip-address>
```

With the default password still set, you can automate login via `sshpass`:
```bash
sshpass -p changeme ssh root@<ip-address>
```
The first SSH login triggers a forced password change — `sshpass` will fail after that.

### Essential Post-Boot Steps

```bash
passwd                    # change root password (mandatory on first login)
nmtui                     # connect to WiFi (if not done already)
timedatectl set-ntp true  # wait ~30s for NTP sync (no RTC on Pi)
nixos-version             # verify running version
```

## NixOS uConsole-Specific Configuration

The `config.txt` on a uConsole CM5 image typically includes:

```ini
[cm5]
dtparam=pciex1=off                                  # disable PCIe lane (uses GPIOs instead)
dtoverlay=clockworkpi-uconsole-cm5                  # uConsole DSI panel, keyboard, battery
dtoverlay=dwc2                                      # USB controller (dual-role)
dtparam=dr_mode=host                                 # USB in host mode (keyboard/mouse/4G)
dtoverlay=vc4-kms-v3d-pi5                           # VC4 KMS display driver for CM5
dtparam=cma-384=on                                   # CMA memory allocator size
dtparam=nohdmi1=off
```

### NixOS system details from `cmdline.txt`:

The `init=` path points into the Nix store and encodes the exact NixOS generation:
```
init=/nix/store/<hash>-nixos-system-nixos-sd-card-<nixpkgs-date>/init
```

This tells you:
- **NixOS version** (e.g. `25.11.20260526` = 25.11 unstable from 2026-05-26)
- **Kernel** (e.g. `linux_rpi-bcm2712-6.12.47-stable_20250916` — CM5 compatible)

## Pitfalls

- **macOS 27 (pre-release) + Homebrew:** Homebrew has no bottles for pre-release macOS versions. `zstd` cannot be installed via brew. Always fall back to `nix shell nixpkgs#zstd` on such systems.
- **`hdiutil attach` is deprecated** on recent macOS — use `diskutil image attach` instead. The old command still works but prints a deprecation warning.
- **No macFUSE** → ext4 root partition cannot be mounted on a default macOS install. The boot (FAT32) partition is sufficient for inspection.
- **SD card shows no filesystem in `diskutil list`** after writing a NixOS image — this is normal! macOS doesn't recognise the ext4 + MBR partition combo. The card is not "empty".
- **Writing to the wrong disk** (`/dev/disk0` = internal SSD) will destroy your macOS install. Always triple-check the disk size and identifier from `diskutil list`.
- **The `rdisk` variant** (`/dev/rdiskX` vs `/dev/diskX`) uses raw I/O and is 10-100x faster on macOS. Use it.
- **CM5 vs CM4 images are NOT interchangeable.** The kernel (`bcm2712` for CM5 vs `bcm2711` for CM4), device tree overlays, and config.txt `[cm5]` vs `[cm4]` sections differ. Verify the filename (`cm4`/`cm5` in the image name).