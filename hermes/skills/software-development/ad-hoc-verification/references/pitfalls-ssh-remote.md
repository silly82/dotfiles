# Real-World Pitfalls — SSH & Remote Access

## 22. `ssh-askpass` / `Too many authentication failures` on macOS with multiple SSH keys

**Trigger:** You have multiple SSH keys in `~/.ssh/` (e.g., `id_ed25519` for GitHub, `hermes_dreamhost` for a specific server). macOS `ssh` tries every key plus agent identities before falling back to password.

**Failure:**
```
ssh_askpass: exec(/usr/X11R6/bin/ssh-askpass): No such file or directory
...
Received disconnect from <ip> port 22:2: Too many authentication failures
```

The server sees 3-4 key attempts and disconnects. The correct key never gets tried.

**Fix:**
```bash
ssh -o IdentitiesOnly=yes \
    -o IdentityFile=~/.ssh/<specific-key> \
    -o PasswordAuthentication=no \
    -o BatchMode=yes \
    user@host "command"
```

- `IdentitiesOnly=yes` — only use the specified key, ignore agent and other files
- `IdentityFile=...` — exact path to the private key
- `PasswordAuthentication=no` — skip password fallback (fails fast)
- `BatchMode=yes` — never prompt, fail immediately if auth fails

**Prevention:** For any non-interactive SSH (scripts, rsync, deploy), always set these four options. Never rely on default key resolution when multiple keys exist.

## 23. `sshpass` not installed on macOS — one-time password-based key bootstrap

**Trigger:** You need to install a public key on a remote server but don't have key-based auth yet. You have the password and want to automate the bootstrap.

**Failure:**
```bash
sshpass -p 'password' ssh ...
# zsh: command not found: sshpass
```

`sshpass` is not in macOS base and installing it via Homebrew is discouraged (it encourages password automation).

**Fix (manual one-liner):**
```bash
cat ~/.ssh/<key>.pub
# copy the line, then on the remote host:
ssh user@host "mkdir -p ~/.ssh && chmod 700 ~/.ssh && echo 'PASTE_PUBKEY_HERE' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
```

Enter the password once when prompted. After that, key-based auth works.

**Fix (if you must automate):**
Use `expect` (macOS has it):
```bash
expect -c '
spawn ssh user@host "mkdir -p ~/.ssh && echo \"ssh-ed25519 AAAA...\" >> ~/.ssh/authorized_keys"
expect "password:"
send "PASSWORD\r"
expect eof
'
```

**Security note:** Never store passwords in scripts. The expect method is for one-time bootstrap only. After key installation, use `-o BatchMode=yes` for all future connections.

## 24. SSH hangs after rsync success — Dreamhost shared host throttling

**Trigger:** After a successful rsync deploy to a Dreamhost shared host, subsequent SSH commands time out.

**Failure:**
```
rsync ... ✓ deployed
ssh user@host "next command"
# [Command timed out after 15s]
```

Dreamhost shared hosts limit concurrent SSH connections per user. The rsync connection may have exhausted the MaxSessions/MaxAuthTries limit, or the server is rate-limiting new connections.

**Fix:**
1. Wait 30-60 seconds before retrying.
2. Use `-o ConnectTimeout=10` to fail fast instead of hanging.
3. Combine multiple commands into one SSH call:
```bash
ssh user@host "cmd1 && cmd2 && cmd3"
```
instead of:
```bash
ssh user@host "cmd1"
ssh user@host "cmd2"
ssh user@host "cmd3"
```

**Prevention:** For deploy scripts, batch remote commands into a single SSH session. If you need multiple sequential commands, use a heredoc or write a small remote script and execute it.

## 25. rsync `~` expansion is LOCAL, not remote

**Trigger:** You write `rsync -avz ./ user@host:~/path/` expecting the remote home directory.

**Failure:**
```
rsync: [Receiver] mkdir "/Users/localuser/path" failed: No such file or directory
```

`~` expands to the *local* home directory (`/Users/localuser`), not the remote one. The remote rsync process receives the literal expanded path and tries to create it locally.

**Fix:** Use relative paths without `~`:
```bash
rsync -avz ./ user@host:path/        # resolves to ~user/path on remote
```
Or use the absolute remote path:
```bash
rsync -avz ./ user@host:/home/user/path/
```

**Prevention:** In deploy scripts, never use `~` in the destination. Use `$HOME` only if you explicitly export it as part of the remote command (e.g., `ssh user@host "rsync ... $HOME/path/"` — but this is fragile). Prefer relative paths.
