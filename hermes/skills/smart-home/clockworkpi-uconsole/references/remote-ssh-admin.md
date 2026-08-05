# Remote SSH administration of a Pi / uConsole

## Connect + passwordless key login
1. Check what's local: `ls -la ~/.ssh/`, inspect `~/.ssh/known_hosts` for the Pi's IP,
   and `~/.ssh/config`. A key like `~/.ssh/id_ed25519` is what you'll copy.
2. Reachability + does the key already work:
   `ssh -o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=accept-new USER@IP "echo CONNECTED; whoami; hostname"`
   - `No route to host` → device off or wrong subnet/IP (known_hosts entries can be stale).
   - `Permission denied (publickey,password)` → key not yet installed for that user.
3. Install the key. If you have the password, install `sshpass` locally
   (`brew install hudochenkov/sshpass/sshpass` on macOS — the main formula is gone),
   then:
   `sshpass -p 'PW' ssh-copy-id -o StrictHostKeyChecking=accept-new -i ~/.ssh/id_ed25519.pub USER@IP`
   Cleaner alternative that keeps the password out of the transcript: have the USER
   run `ssh-copy-id -i ~/.ssh/id_ed25519.pub USER@IP` themselves.
4. Verify: `ssh -o BatchMode=yes USER@IP whoami` should succeed with no prompt.

## CRITICAL sudo constraint on remote hosts
Hermes BLOCKS piping a password into `sudo -S` — e.g.
`echo PW | sudo -S apt-get install ...` is refused as a brute-force vector
("BLOCKED: sudo password guessing via stdin"). This is intentional; do not try to
work around it.

Check whether passwordless sudo exists first:
`ssh USER@IP 'sudo -n true 2>&1 && echo YES || echo NEEDS_PASSWORD'`

If it needs a password, you have two paths — offer both to the user:
- **Home-dir-only work (no sudo):** all Wayland/Sway compositor config lives under
  `~/.config/` and needs no root. You can fully configure the compositor this way.
  Only package installs and /boot edits need sudo.
- **Grant NOPASSWD sudo:** the user runs, in their own terminal,
  `echo "USER ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/USER-nopasswd`
  after which you can install packages and edit /boot/firmware/config.txt yourself.

## Running multi-line remote scripts
Pipe a heredoc to remote bash for a batch of probes in one round-trip:
`ssh USER@IP 'bash -s' <<'EOF' ... EOF`
Quote the heredoc marker (`<<'EOF'`) so local shell doesn't expand `$VARS`.
