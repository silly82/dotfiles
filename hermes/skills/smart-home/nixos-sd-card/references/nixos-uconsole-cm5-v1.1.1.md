# nixos-uconsole CM5 v1.1.1 — Session Inspection Notes

File: `nixos-uconsole-cm5-v1.1.1.img.zst` (1.5 GB compressed, 6.07 GB decompressed)
Source: https://github.com/nixos-uconsole/nixos-uconsole

## Partition Layout

```
Disk label: dos (MBR)
Total sectors: 11863696 (5.66 GiB)

Partition 1: Start 16384, Size 2097152 sectors (1 GB), FAT32 — FIRMWARE
Partition 2: Start 2113536, Size 9750160 sectors (4.6 GB), Linux — NixOS root (ext4)
```

## Firmware Partition (FAT32) — Mount Point `/Volumes/FIRMWARE`

### config.txt [cm5] section
```ini
[cm5]
dtparam=pciex1=off
dtoverlay=clockworkpi-uconsole-cm5
dtoverlay=dwc2
dtparam=dr_mode=host
dtoverlay=vc4-kms-v3d-pi5
dtparam=cma-384=on
dtparam=nohdmi1=off
```

### cmdline.txt
```
console=serial0,115200n8 console=tty1 8250.nr_uarts=1 console=tty1
nohibernate loglevel=7 lsm=landlock,yama,bpf
init=/nix/store/5abw7z0sxn2lpsw945i6232fya8691bj-nixos-system-nixos-sd-card-25.11.20260526.25f5383/init
```

### Kernel
Store path: `/nix/store/m7zbm8dl9zcs4mm7lh8cxd97w4zm5x9p-linux_rpi-bcm2712-6.12.47-stable_20250916/Image`

### System closure
Store path: `/nix/store/5abw7z0sxn2lpsw945i6232fya8691bj-nixos-system-nixos-sd-card-25.11.20260526.25f5383`

### Key DTBs present
- `bcm2712-rpi-cm5-cm5io.dtb`
- `bcm2712-rpi-cm5-cm4io.dtb`
- `bcm2712-rpi-cm5l-cm4io.dtb`
- `bcm2712-rpi-cm5l-cm5io.dtb`
- `bcm2712-rpi-5-b.dtb`
- `bcm2712-d-rpi-5-b.dtb`

### uConsole overlays
- `clockworkpi-uconsole-cm5.dtbo`
- `clockworkpi-uconsole.dtbo` (CM3/CM4 variant)
- `clockworkpi-uconsole-cm3.dtbo`
- `clockworkpi-uconsole-sound-switch.dtbo`

### Boot firmware
Standard Raspberry Pi 5 bootchain: `bootcode.bin`, `start4.elf`, `start4cd.elf`, `start4db.elf`, `start4x.elf`, `fixup4.dat`, `fixup4cd.dat`, `fixup4db.dat`, `fixup4x.dat`.

## NixOS Version
25.11.20260526 (unstable branch, snapshot from 2026-05-26)

## Flash Results
- Written to `/dev/rdisk12` (SD card via USB reader, 31.3 GB, mmcblk0)
- Transfer: 6,074,212,352 bytes in ~152 seconds at ~40 MB/s
- `conv=fsync` used for safe flush

## Network (after boot)
DHCP subnet: 192.168.188.0/24
- IP: 192.168.188.203 (reachable, SSH port 22 open)
- IP: 192.168.188.199 (timed out, likely another device)
- SSH default creds `root`/`changeme` — password auth rejected (already changed on first login)

## Host machine
macOS 27.0 (pre-release, "Gallifrey")
- `zstd` extracted via `nix shell nixpkgs#zstd` (Homebrew had no bottle)
- Image mounted via `diskutil image attach` (hdiutil deprecated)
- No macFUSE → ext4 root not read
- SD card: USB SD card reader at `/dev/disk12` (31.3 GB, mmcblk0 Media)