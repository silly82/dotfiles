# macOS Cleanup Patterns

Common large storage consumers on macOS and how to safely reclaim space.

## Application Data

### Claude Desktop
- **VM Bundles**: `~/Library/Application Support/Claude/vm_bundles/` (5–6GB)
  - Contains Linux VM images for Claude Code sandbox
  - Safe to delete if not using Claude Code IDE
  - Will be re-downloaded if needed
- **Cache**: `~/Library/Application Support/Claude/Cache/` (700MB+)
  - Browser cache, safe to delete

### OpenEmu
- **Game Library**: `~/Library/Application Support/OpenEmu/Game Library/roms/`
  - PlayStation games: 3+ GB each
  - PSP games: 1.5–2 GB each
  - Retro games (SNES, N64): <100MB each
- **PPSSPP Cache**: `~/Library/Application Support/OpenEmu/PPSSPP/` (800MB+)
  - Shader caches, safe to delete

### Arduino
- **Staging Area**: `~/Library/Arduino15/staging/` (8+ GB)
  - Temporary downloads for package installation
  - Safe to delete, will be recreated as needed
- **Toolchains**: `~/Library/Arduino15/packages/esp32/tools/` (5+ GB)
  - Compilers, debuggers, flashers for ESP32 variants
  - Keep if developing for ESP32
- **RP2040 Tools**: `~/Library/Arduino15/packages/rp2040/tools/` (1+ GB)
  - Raspberry Pi Pico toolchain

### Xcode & Developer Tools
- **Xcode**: `~/Library/Developer/Xcode/` (10+ GB)
  - DerivedData, Archives, iOS DeviceSupport can be cleared
- **CoreSimulator**: `~/Library/Developer/CoreSimulator/` (5+ GB)
  - Simulator devices, safe to delete unused versions

## User Directories

### Downloads
- Large disk images (`.img`, `.iso`, `.dmg`)
- Old installers, firmware files
- Use: `find ~/Downloads -type f -name "*.img" -o -name "*.iso" -size +500M`

### Documents
- Project repositories, media files
- Check `~/Documents/GitHub/`, `~/Documents/Arduino/`

## Quick Commands

```bash
# Top-level scan
du -sh ~/Library/* | sort -hr | head -10

# Application Support deep dive
du -sh ~/Library/Application\ Support/* | sort -hr | head -10

# Find large files
find ~ -type f -size +500M 2>/dev/null | head -20

# Check free space before/after
df -h /

# Estimate space recovery after cleanup
echo "Before: $(df -h / | awk 'NR==2 {print $3 " used, " $4 " free"})"
```

## Session-Specific Patterns (2026-08-02)

### Claude Desktop (6.8GB typical)
- **VM Bundles** (`~/Library/Application Support/Claude/vm_bundles/`): 5.6GB Linux VM for Claude Code sandbox. Safe to delete if only using `claude-cli`/Hermes Agent.
- **Cache** (`~/Library/Application Support/Claude/Cache/`): 700MB+ browser cache, always safe to delete.
- **Remaining app data**: ~500MB (IDE, configs). Keep unless uninstalling entirely.

### OpenEmu Game Library (7.8GB typical)
- **PlayStation/PSP games**: 3–4GB each (`.bin`/`.cue`/`.iso`). Delete if not playing.
- **Retro games (SNES, N64, GBA)**: <100MB each, often worth keeping.
- **PPSSPP cache**: 800MB+ shader cache, safe to delete.
- **BIOS files**: Small (2–20MB), keep for emulator compatibility.

### Arduino Environment (16GB typical)
- **Staging area** (`~/Library/Arduino15/staging/`): 8GB+ temporary downloads. Safe to delete; will be re‑downloaded when needed.
- **ESP32 toolchains** (`~/Library/Arduino15/packages/esp32/tools/`): 5GB+ compilers, debuggers, flashers for 12+ ESP32 variants. Keep if developing for ESP32.
- **RP2040 tools** (`~/Library/Arduino15/packages/rp2040/tools/`): 1GB+ Raspberry Pi Pico toolchain.
- **Core packages** (`~/Library/Arduino15/packages/esp32/hardware/`, `rp2040/hardware/`): ~500MB actual board support.

### Downloads Folder Cleanup
- **Large disk images**: ClockworkPi/NixOS `.img`, `.img.xz`, `.img.zst` (6–12GB each).
- **Empty/near‑empty directories**: Use `find ~/Downloads -type d -empty` to list, then `rm -rf` if confirmed safe.
- **Common candidates**:
  - `boxneu` (empty)
  - `$RECYCLE.BIN` (Windows recycle bin, safe)
  - `*.download` (incomplete downloads)
  - Game folders with only `.cue` files (no `.bin`/`.iso`)

### Space Recovery Estimation
After cleaning the above, expect:
- **Claude VM + Cache**: ~6GB
- **OpenEmu PlayStation/PSP games**: ~6GB per title
- **Arduino staging**: ~8GB
- **Large Downloads**: variable (check with `du -sh ~/Downloads/* | sort -hr`)

Total recovery often 20–30GB on a typical developer machine.

## Workflow
1. Scan with `du -sh` to identify largest consumers.
2. Drill down with `find` for specific file types.
3. Delete cautiously, verify with `df -h /` after each major removal.
4. Keep BIOS files and small retro games; remove large VM images and completed project archives.

## Safety Notes
- Always verify paths before deleting
- Some directories require `sudo` (use cautiously)
- System files in `~/Library/` are generally safe to delete if you understand the app
- Back up important data first