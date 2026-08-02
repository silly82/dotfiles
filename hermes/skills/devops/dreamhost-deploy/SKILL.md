---
name: dreamhost-deploy
description: Deploy to Dreamhost Shared via rsync/SSH with retry.
version: 1.0.0
---

# Dreamhost Shared Hosting — Deploy & Manage

Silvan hosts multiple domains on one Dreamhost shared account (user `silly82`, host `pdx1-shared-a1-13`, SSH alias `silly82@bristenblick.ch`). Each domain is a directory directly under `$HOME` (e.g. `~/bristenblick.ch/`, `~/anathol.ch/`).

## SSH Access

- Key: `~/.ssh/hermes_dreamhost` (ed25519, authorized on the account). Always call with:
  `ssh -o IdentitiesOnly=yes -o IdentityFile=~/.ssh/hermes_dreamhost -o PasswordAuthentication=no -o BatchMode=yes silly82@bristenblick.ch "..."`
- The shared server throttles/drops SSH frequently. Silvan's mandated rule: **mindestens 3 Versuche bei Fehler, 10 s Pause dazwischen** — bake this helper into any script that calls ssh (deploy scripts, sync jobs):
  ```bash
  ssh_retry() {
    local max=3 delay=10 i
    for i in $(seq 1 $max); do
      if ssh -o ConnectTimeout=10 -o IdentitiesOnly=yes -o IdentityFile=~/.ssh/hermes_dreamhost \
           -o PasswordAuthentication=no -o BatchMode=yes "$@"; then return 0; fi
      echo "SSH attempt $i/$max failed, waiting ${delay}s..." >&2; sleep $delay
    done; echo "SSH failed after $max attempts" >&2; return 1
  }
  ```
  Keep remote commands short; on timeout sleep ~10 s and retry — it usually recovers. Long heredocs and `crontab`-editing via SSH often hang — prefer piping a local file (`cat local.txt | ssh ... "cat | crontab -"`).
- If the key isn't yet authorized on a new shell-user: `sshpass -p '<temp-password>' ssh ... "mkdir -p ~/.ssh && chmod 700 ~/.ssh && echo '<pubkey>' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"` (ask user for temp password; never store it).

## rsync Deploy — Critical Pitfalls

1. **NEVER use `--delete` when syncing INTO a docroot that also holds server-side data** (e.g. `data/` written by cron). A second `rsync -avz --delete web/ $DEST` wiped the entire app including `data/`, `scripts/`, `LICENSE`. Pattern that works: separate rsync calls per source dir, WITHOUT `--delete` on the docroot sync:
   ```bash
   rsync -avz --exclude='__pycache__/' scripts/ "$REMOTE:$DEST/scripts/"
   rsync -avz --exclude='.DS_Store' web/ "$REMOTE:$DEST"   # flat into docroot, no --delete
   ```
2. **`~` in an rsync DEST expands to the LOCAL home**, not remote. `rsync ... "$REMOTE:~/path"` failed with `mkdir "/Users/silvan/..." failed`. Use a relative remote path (`bristenblick.ch/timelapse/`) or absolute (`/home/silly82/...`).
3. After rsync, Apache may 403: re-apply permissions — docroot `755`, html `644`, asset dirs `755`, files inside `644`. Exclude `.DS_Store`.

## Cron on Dreamhost

- Panel-created jobs run as `/usr/bin/setlock -n /tmp/cronlock.* sh -c '<cmd>'` — that is **dash, not bash**, and `$HOME` inside the single-quoted command is NOT expanded. Use absolute paths in the crontab entry (`bash -c "/home/silly82/site/scripts/run.sh"`), or make scripts pure POSIX (`#!/bin/sh`, no `pipefail`, no `[[ ]]`). Verify with `dash -n script.sh` locally.
- **`~/logs/` is owned by `dhapache` and NOT writable** by the user. Log inside the site dir instead (`data/logs/webcam.log`), `mkdir -p` it in the runner script first.
- Dreamhost manages the block between `###--- BEGIN/END DREAMHOST BLOCK` markers in `crontab -l`; keep a copy of the full crontab in the repo (see references) and install it by piping: `cat crontab.txt | ssh ... "cat | crontab -"`. DANGER: this REPLACES the entire crontab. Always `crontab -l` first and make sure the file contains every existing job — in this session a bare `echo '<one job>' | crontab -` wiped the pre-existing Bitzi watchdog job and it had to be rebuilt by hand.

## Web/Apache Quirks

- Domain root `.htaccess` may RewriteRule ALL traffic into a default subdir (bristenblick.ch → `/weather/`). Any new app subdir needs its own exclusion line: `RewriteCond %{REQUEST_URI} !^/<subdir>/`.
- **WebP is not served with a MIME type by default** — browsers refuse to render `<img>` webp. Drop a `.htaccess` in the app dir: `AddType image/webp .webp`.
- **Frontend assets must use RELATIVE paths** (`css/site.css`, `js/app.js`, `data/...`) when the app lives in a subdirectory. Absolute `/css/...` `/data/...` paths resolve against the domain root and 404. This bug appeared in HTML (src/href), in JS fetch() calls, AND in fetch() calls inside loop bodies — grep the whole frontend for `"/` + `'/` + `` `/ `` before deploying to a subdir.

## Python on Dreamhost

- Server has `/usr/bin/python3` = 3.10; install deps per-user: `python3 -m pip install --user pillow`. Check WebP support: `python3 -c "from PIL import features; print(features.check('webp'))"`.
- Silvan's Mac system python is 3.9 — write code compatible with BOTH: no `dict | None` union syntax (use plain annotations), no `datetime.fromisoformat()` with trailing `Z` (use `strptime(s, "%Y-%m-%dT%H-%M-%SZ")`).
- Webcam/upstream JPEGs can arrive TRUNCATED (partial download). Pillow then crashes deep inside `thumbnail()` with `OSError: image file is truncated (N bytes not processed)`. Always `im = Image.open(src); im.load()` inside `try/except (OSError, SyntaxError)` and SKIP the file (return None, count skipped) — one corrupt frame must not stop the whole thumb/manifest pipeline. Delete the corrupt source so the next cron run re-fetches it cleanly.

## Typical Layout for a Site-App (e.g. bristenblick.ch/timelapse)

```
~/<domain>/<app>/
  index.html, favs.html, css/, js/      # webroot (deployed from repo web/, flat)
  scripts/                              # python + sh runners (deployed)
  data/                                 # SERVER-SIDE ONLY, never rsync --delete, never in git
    archive/ thumbs/ manifest/ logs/
```

See `references/dreamhost-quirks.md` for session detail (crontab block format, error transcripts, sshpass bootstrap).
