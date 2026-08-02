---
name: macos-storage-management
description: macOS storage analysis and cleanup for large files.
---

# macOS Storage Management

Skills for analyzing storage usage on macOS, identifying space hogs, and performing targeted cleanup with clear decision logic.

## Quick Storage Analysis

### System Overview
```bash
df -h /
```

### Top Directories in Home
```bash
du -sh ~/* | sort -hr | head -10
```

### Library Breakdown
```bash
du -sh ~/Library/* | sort -hr | head -10
```

### Application Support Details
```bash
du -sh ~/Library/Application\ Support/* | sort -hr | head -极
```

## Common Large Items

### Downloads Folder
- Large image files (.img, .iso, .dmg) often accumulate
- Check: `du -sh ~/Downloads/* | sort -hr | head -10`

### Documents Folder  
- GitHub clones, Arduino projects, audio/video files
- Check: `du -sh ~/Documents/* | sort极hr | head -10`

## Claude Desktop Storage

**Location:** `~/Library/Application Support/Claude/`

### Typical Structure & Sizes
- `vm_bundles/` (5-6GB) – VM images for Claude Code sandbox
- `Cache/` (700MB-1GB) – Browser caches
- `claude-code/` (~250MB) – Application data
- `claude-code-vm/` (~250MB) – VM configurations

### Decision Logic

**If user only uses `claude-cli`/Hermes Agent:**
- VM bundles can be safely deleted (5-6GB recovery)
- Cache can be cleared (700MB+ recovery)
- App data (~500MB) should be kept for desktop functionality

**If user occasionally uses Claude Desktop with Code features:**
- Cache can be cleared
- VM bundles should be kept (will be re-downloaded if needed)

### Cleanup Commands
```bash
# Clear Claude cache (safe)
rm -rf ~/Library/Application\ Support/Claude/Cache

# Remove VM bundles (if not using Claude Code)
rm -rf ~/Library/Application\ Support/Claude/vm_bundles
```

## Other Common Space Hogs

### Xcode Developer Files
- `~/Library/Developer/Xcode/` (10GB+)
- `~/Library/Developer/CoreSimulator/` (5GB+)
- Use Xcode's built-in cleanup tools or manually remove old simulators

### Arduino PlatformIO
- `~/Library/Arduino15/staging/` (8GB+) – Temporary downloads, safe to delete
- `~/Library/Arduino15/packages/` (7GB+) – Contains:
  - `esp32/tools/` (5.2GB) – Compilers, debuggers for 12+ ESP32 variants
  - `rp2040/tools/` (1.2GB) – Raspberry Pi Pico toolchain
  - `arduino/` (514MB) – Core Arduino tools
  - `builtin/` (27MB) – Built-in libraries
- **CLI vs GUI**: Both use same packages, CLI gives more control over installations

## OpenEmu Game Analysis

### List Games by Platform
Use this Python script to get clean game listings:

```python
import os

roms_path = "~/Library/Application Support/OpenEmu/Game Library/roms"
roms_path = os.path.expanduser(roms_path)

platform_names = {
    "Arcade": "Arcade",
    "Game Boy Advance": "Game Boy Advance", 
    "Nintendo 64": "Nintendo 64",
    "Sony PlayStation": "PlayStation",
    "Sony PSP": "PSP",
    "Super Nintendo (SNES)": "Super Nintendo (SNES)",
    "Virtual Boy": "Virtual Boy"
}

for platform in sorted(os.listdir(roms_path)):
    platform_path = os.path.join(roms_path, platform)
    if not os.path.isdir(platform_path):
        continue
        
    print(f"{platform_names.get(platform, platform)}:")
    
    games = set()
    for root, dirs, files in os.walk(platform_path):
        for file in files:
            lower = file.lower()
            if any(lower.endswith(ext) for ext in ['.zip', '.nes', '.sfc', '.smc', '.gb', '.gbc', '.gba', 
                                                   '.nds', '.iso', '.bin', '.md', '.gen', '.sms', '.gg', 
                                                   '.pce', '.32x', '.a26', '.lnx', '.ws', '.wsc', '.ngp', '.ngc']):
                if file.lower().endswith('.cue'):
                    continue
                
                name = file
                for ext in ['.zip', '.nes', '.sfc', '.smc', '.gb', '.gbc', '.gba', '.nds', '.iso', 
                           '.bin', '.md', '.gen', '.sms', '.gg', '.pce', '.32x', '.a26', '.lnx', 
                           '.ws', '.wsc', '.ngp', '.ngc']:
                    if name.lower().endswith(ext):
                        name = name[:-len(ext)]
                        break
                
                import re
                name = re.sub(r'\s*\([^)]*\)', '', name).strip()
                name = re.sub(r'^\d+\s*-\s*', '', name)
                
                if name:
                    games.add(name)
    
    if not games:
        print("  (keine Spiele)")
    else:
        for game in sorted(games):
            print(f"  • {game}")
    print()
```

### Cleanup Decisions
- **PlayStation/PSP games**: 3.2GB each, often largest – safe to delete if not playing
- **Retro games**: SNES/N64/GBA much smaller (MB range) – keep if actively used
- **Other data**: PPSSPP cache (881MB) can be cleared, emulator cores (359MB) should be kept

### Browser Caches
- `~/Library/Caches/` – Check vscode-cpptools, arduino, Homebrew
- Use `du -sh ~/Library/Caches/* | sort -hr | head -10`

## Workflow Pattern

1. **Assess** – Run system overview and top directory scans
2. **Identify** – Drill into large directories with detailed `du` commands
3. **Analyze** – Understand what each large item contains (VM bundles, caches, downloads)
4. **Decide** – Apply user-specific logic (e.g., "only uses CLI" → delete VM bundles)
5. **Execute** – Remove with confirmation, verify space recovery
6. **Verify** – Check `df -h /` for updated available space

## Communication Style

- **User preference**: German language, concise answers with minimal explanations
- **Provide lists**: Top items with sizes, not verbose explanations – user wants "was mach die Arduino umgebung so gross" not detailed breakdowns
- **Clear decisions**: State what can be deleted and why in bullet points
- **Verification**: Always show before/after space metrics with `df -h /`
- **Action-oriented**: When user says "löschen" or similar, execute immediately with confirmation

## Pitfalls

1. **Permission errors**: Some Library subdirectories have SIP restrictions – skip "Operation not permitted" entries
2. **VM bundle regeneration**: If user later needs Claude Code, bundles will re-download (~5.6GB)
3. **Cache regrowth**: Browser/application caches will rebuild over time
4. **Time-based accumulation**: Downloads folder should be checked regularly for large files