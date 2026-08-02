---
name: mac-storage-cleanup
description: "Clean up macOS disk space: find and remove large files."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [macos]
metadata:
  hermes:
    tags: [macos, storage, cleanup, disk-space, maintenance]
    related_skills: [systematic-debugging]
---

# macOS Storage Cleanup

Identify and remove large files to free disk space on macOS. Focuses on common storage-intensive directories like `~/Library/`, `~/Downloads/`, and user data.

## Steps

1. **Check overall disk usage:**
   ```bash
   df -h /
   ```

2. **Scan large directories:**
   ```bash
   du -sh ~/Library/* | sort -hr | head -10
   du -sh ~/Downloads/* | sort -hr | head -10
   du -sh ~/Documents/* | sort -hr | head -10
   ```

3. **Drill into specific paths:**
   ```bash
   du -sh /path/to/directory/* | sort -hr  # e.g., ~/Library/Application Support/*
   ```

4. **Find files by type/name:**
   ```bash
   find /path -type f -name "*.iso" -o -name "*.img" -o -name "*.bin" | head -10
   find /path -type f -size +100M 2>/dev/null | head -10  # Large files
   ```

5. **Delete safely:**
   ```bash
   rm -rf /path/to/large/directory  # Use with caution!
   ```

6. **Verify after deletion:**
   ```bash
   df -h /  # Check free space change
   ```

## Common Targets

- **~/Library/Application Support/**: App data (Claude, OpenEmu, Arduino)
- **~/Library/Developer/**: Xcode and simulator data
- **~/Library/Caches/**: Temporary caches
- **~/Downloads/**: Large downloaded files
- **~/Documents/**: User projects and files

## Pitfalls

- Some directories require `sudo` or have permission issues
- Deleting system files can break applications
- Always verify paths before deleting
- Use `-i` flag with `rm` for interactive deletion if unsure

## Typical Savings (Recent Examples)

- **Claude Desktop**: 6–7GB (VM bundles + cache)
- **OpenEmu PlayStation/PSP games**: 3–4GB per title
- **Arduino staging area**: 8GB+ temporary downloads
- **Large disk images in Downloads**: 5–12GB each
- **Empty/near‑empty directories**: Minimal space, but clutter reduction

## References

- See `references/mac-cleanup-patterns.md` for session-specific examples and detailed patterns