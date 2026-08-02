---
name: TrueNAS App Permission Management
title: TrueNAS App Permission Management
description: Fix 403 errors when TrueNAS apps move files.
tags:
  - truenas
  - permissions
  - filebrowser
  - apps
  - linux
  - filesystem
---

# TrueNAS App Permission Management

## When to use
- TrueNAS apps (File Browser, qBittorrent, Radarr, Sonarr, Jellyfin) cannot write to mounted directories
- 403 Forbidden errors when moving files between datasets (e.g., `/mnt/HDDs/Download` → `/mnt/HDDs/Movies`)
- Apps run as user `apps` (UID 568) but need access to directories owned by other users/groups
- After adding a user to a group, the app still cannot write (process doesn't pick up new group membership)

## Core concepts

### TrueNAS app architecture
- Apps run as non-root user `apps` (UID 568) by default
- Each app runs in a container with bind mounts to host directories
- File permissions on host directories determine app access

### Common directory structure
```
/mnt/HDDs/Download    # Download folder (often owned by apps:apps)
/mnt/HDDs/Movies      # Media library (often owned by root:media)
/mnt/HDDs/Shows       # Media library (often owned by root:media)
```

### Key groups
- `apps` (GID 568) – default app group
- `media` (GID 3001) – custom group for media directories
- `www-data` (GID 33) – web server group (for TrueNAS web UI)

## Step-by-step fix

### 1. Check current permissions
```bash
ssh truenas_admin@192.168.188.20
ls -ld /mnt/HDDs/Movies /mnt/HDDs/Shows /mnt/HDDs/Download
getfacl /mnt/HDDs/Movies
```

### 2. Ensure `apps` user is in the correct group
```bash
# Add apps to media group (if not already)
sudo usermod -a -G media apps

# Verify
id apps
# Should show: groups=568(apps),3001(media)
```

### 3. Set correct ownership and permissions
```bash
# Set group ownership to apps (or media, depending on your setup)
sudo chgrp -R apps /mnt/HDDs/Movies /mnt/HDDs/Shows /mnt/HDDs/Download

# Set permissions to 2770 (rwx for owner and group + setgid)
sudo chmod -R 2770 /mnt/HDDs/Movies /mnt/HDDs/Shows /mnt/HDDs/Download

# Verify
ls -ld /mnt/HDDs/Movies
# Should show: drwxrws--- (note the 's' in group execute position)
```

### 4. Restart the app to pick up new group membership
**Critical:** Running processes don't automatically get new group memberships. You must restart the app:

```bash
# Via TrueNAS CLI
midclt call app.stop filebrowser
midclt call app.start filebrowser

# Or via web UI: Apps → File Browser → Stop, then Start
```

### 5. Verify app process has the group
```bash
# Find app PID
pgrep -f filebrowser

# Check groups
cat /proc/<PID>/status | grep Groups
# Should include both 568 (apps) and 3001 (media)
```

## Common pitfalls

### Pitfall: Group membership not effective
**Symptom:** `apps` is in group `media` but app still can't write.
**Cause:** Process started before group membership change.
**Fix:** Restart the app container/process.

### Pitfall: Missing setgid bit
**Symptom:** New files created in directory don't inherit group ownership.
**Fix:** Use `chmod 2770` not `2770`. The `s` in `drwxrws---` ensures new files inherit the directory's group.

### Pitfall: ZFS ACL interference
**Symptom:** Permissions seem correct but still get "Operation not permitted".
**Check:** `zfs get aclmode,aclinherit HDDs`
**Fix:** Set to passthrough:
```bash
sudo zfs set aclmode=passthrough HDDs
sudo zfs set aclinherit=passthrough HDDs
```

### Pitfall: Multiple apps with different users
If you have multiple apps (File Browser, qBittorrent, Radarr) that need to share files:
1. Create a common group (e.g., `media`)
2. Add all relevant users to that group (`apps`, `www-data`, etc.)
3. Set directory group to `media` with `chgrp -R media /path`
4. Set permissions to `2770`

## Quick diagnostic commands

```bash
# Check directory permissions
ls -ld /mnt/HDDs/*

# Check user groups
id apps
id www-data

# Check process groups
cat /proc/$(pgrep -f filebrowser)/status | grep Groups

# Test write access as apps user
sudo -u apps touch /mnt/HDDs/Movies/test_write && sudo -u apps rm /mnt/HDDs/Movies/test_write

# Check ZFS ACL settings
zfs get aclmode,aclinherit HDDs
```

## For File Browser specific issues

File Browser runs as `apps` user with these bind mounts (check via `midclt call app.query`):
- `/mnt/HDDs/Download` → `/data/mnt/Download`
- `/mnt/HDDs/Movies` → `/data/mnt/Movies`
- `/mnt/HDDs/Shows` → `/data/mnt/Shows`

If 403 persists after fixing permissions:
1. Check app is actually running: `ps aux | grep filebrowser`
2. Restart via TrueNAS web UI or CLI
3. Check app logs in TrueNAS UI

## User preferences (Silvan)
- Prefers German language but technical commands in English
- Wants direct solutions without excessive explanation
- Appreciates clear command blocks to copy/paste
- Values practical fixes over theoretical background