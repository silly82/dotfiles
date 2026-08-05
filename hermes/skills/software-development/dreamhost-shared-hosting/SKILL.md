---
name: dreamhost-shared-hosting
description: Use when deploying to Dreamhost shared hosting.
version: 1.1.0
---

# Dreamhost Shared Hosting

Use when deploying code, setting up cron, or debugging SSH/Apache on Silvan's Dreamhost shared account (pdx1-shared-a1-13). Sites: bristenblick.ch, anathol.ch, figaro-der-frisurenladen.ch (+ mehrere Alt-Projekte im selben Home).

## SSH Access

- User `silly82`, host = domain (z.B. `silly82@bristenblick.ch`).
- Dedicated key: `~/.ssh/hermes_dreamhost` (ed25519, no passphrase). Pubkey lives in server `~/.ssh/authorized_keys`.
- ALWAYS pass `-o IdentitiesOnly=yes -o IdentityFile=~/.ssh/hermes_dreamhost -o BatchMode=yes -o PasswordAuthentication=no`. Without `IdentitiesOnly` the server disconnects with "Too many authentication failures" (agent has multiple keys; server gives up after a few offers).
- If `~/.ssh/authorized_keys` does not exist on the server: `mkdir -p ~/.ssh && chmod 700 ~/.ssh` first, then append, then `chmod 600 ~/.ssh/authorized_keys`.
- **Server is flaky**: commands randomly time out (banner exchange, mid-session hangs). Retry pattern: `sleep 5–15`, retry with `-o ConnectTimeout=10`. Retrying works — do not conclude the host is down.
- Pattern for ANY deploy/sync script: bake a `ssh_retry()` helper with 3 attempts and 10s pause between attempts. Long heredocs and `crontab` editing via SSH often hang — prefer piping a local file (`cat local.txt | ssh host "cat | crontab -"`).

## Webroot layout & Apache permissions

- Each domain = `~/domain.tld/`. Subsites = subdirs (e.g. `~/bristenblick.ch/timelapse/`).
- Root `.htaccess` may rewrite ALL requests into a default subdir (bristenblick.ch → `/weather/`). A new subdir MUST be excluded or it 404s/redirects: add `RewriteCond %{REQUEST_URI} !^/<subdir>/` alongside the existing conditions.
- After rsync/scp/mv, files often land as 600/700 → Apache answers **403 Forbidden**. Fix: `chmod 755` dirs, `chmod 644` files (`chmod -R u=rwX,go=rX .`). Also remove `.DS_Store`.
- **FIX THE DEPLOY SCRIPT** to do this automatically. Silvan's explicit frustration: "wieso machst du immer den 403 Fehler" — after the third deploy that needs the same `chmod 644 index.html favs.html && chmod 755 .`, put it in `dreamhost_deploy.sh` as the LAST step using `ssh_retry`. Don't expect the user to remember to SSH and re-chmod by hand.
- Verify every deploy with curl: HTTP 200 on `index.html`, one JS/CSS asset, and one data file. A 403 here means the chmod in the deploy script didn't run or Apache cached the old perm — run it again.

## Browser cache: Apache 30d default hides your frontend updates

Dreamhost Apache serves static assets with a **default `Cache-Control: max-age=2592000` (30 days)** for `.js`, `.css`, `.html`. After deploying a new `player.js`:
- `curl` sees the new file → looks fine
- Safari/Chrome/Firefox keep the cached version for 30 days → user sees old behaviour, fix appears "not working"
- `location.reload(true)` does not help, cache-bust query params are inconsistent

**Symptom:** A deployed fix passes `curl` check but the browser still loads the old file.

**Fix: drop a `.htaccess` in the app dir that overrides the cache per file type. Put this in the repo from the start**, not after the first "fix isn't working" debugging round.

```apache
AddType image/webp .webp
<IfModule mod_headers.c>
  # JSON manifests + status: never cache (browser must see new frames after cron tick)
  <FilesMatch "\.(json)$">
    Header set Cache-Control "no-cache, no-store, must-revalidate"
    Header set Pragma "no-cache"
    Header set Expires "0"
  </FilesMatch>
  # HTML: revalidate
  <FilesMatch "\.(html)$">
    Header set Cache-Control "no-cache, must-revalidate"
  </FilesMatch>
  # JS + CSS: explicit override of the 30d default so deploys are visible
  <FilesMatch "\.(js|css)$">
    Header set Cache-Control "no-cache, must-revalidate"
  </FilesMatch>
  # Thumbs + originals (filenames have timestamps): cache aggressively
  <FilesMatch "\.(webp|jpg)$">
    Header set Cache-Control "public, max-age=86400"
  </FilesMatch>
</IfModule>
```

Verify with `curl -sI <each file type> | grep -i cache-control`. JS/CSS MUST NOT show `max-age=2592000` after deploy. Add cache-busting verification to the deploy ad-hoc script:

```python
def fetch_cc(url): return urllib.request.urlopen(url, timeout=10).headers.get("Cache-Control","")
check("LIVE: JS no-cache", "no-cache" in fetch_cc(...js...))
check("LIVE: CSS no-cache", "no-cache" in fetch_cc(...css...))
check("LIVE: WebP public+86400", "public" in fetch_cc(...webp...) and "86400" in fetch_cc(...webp...))
```

## rsync deploy pitfalls (hard-won, cost us the data dir once)

1. **Never `~` in rsync DEST** — rsync expands `~` on the LOCAL side (`mkdir /Users/you/... failed`). Use a path relative to the remote home: `DEST=bristenblick.ch/timelapse/`.
2. **Never `--delete` on a sync whose target also holds server-side data** (`data/`, logs, uploads). One `--delete` run wiped archive+thumbs+manifest+status. Split into separate syncs per top-level dir; only use `--delete` on pure-code targets (e.g. `scripts/` → `scripts/`), never on the docroot when `data/` lives there too.
3. Keep `data/` out of git (`.gitignore`) AND out of deploy syncs — it is server-state, not code.
4. Pass `web/` flat to the docroot — if your repo is `web/index.html` and the server is `~/bristenblick.ch/timelapse/`, run `rsync web/ host:tld/timelapse/` (without `web/` in the destination) so files land at the docroot, not inside a `web/` subdir.
5. **End the deploy script with an `ssh_retry` to chmod** (`chmod 755 .`, `chmod 644 *.html *.json`, `chmod 755 css js data`). Almost every deploy leaves Apache-blocked files behind otherwise. Bake it in; don't expect the user to hand-fix per deploy.

## Cron on Dreamhost

- Panel-created jobs live in the managed `###--- BEGIN DREAMHOST BLOCK` section of the user crontab. **Replacing the whole crontab via `crontab -` silently deletes the other jobs** (we killed the bitzi watchdog once). Always: `crontab -l` → save full output → edit offline → push complete file back. Panel edits to the managed block get overwritten by the panel itself.
- Cron invokes commands via `sh` (dash), not bash. Inside `sh -c '...'` (single quotes) **`$HOME` is NOT expanded** — the crontab line must use the absolute path `/home/silly82/...`.
- Scripts must be POSIX: `#!/bin/sh`, no `pipefail`, no bashisms. Verify with `dash -n script.sh` locally.
- **`~/logs` is owned by `dhapache` and NOT writable by the user** — redirecting there hangs/fails the job. Log into the project dir instead (`mkdir -p data/logs` in the runner script, `>> data/logs/webcam.log 2>&1`).
- Enable the panel's "Use locking" (setlock) to prevent overlapping runs.
- Runner-script pattern: resolve own dir portably (`SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd); cd "$SCRIPT_DIR/.."`), then call the python steps.

## Python on the server

- Server: python3 3.10 (`/usr/bin/python3`). Mac system python3: 3.9. Code must run on BOTH:
  - No `X | None` union annotations (3.10+ only).
  - `datetime.fromisoformat` on 3.9 rejects many strings — use `datetime.strptime(s, "%Y-%m-%dT%H-%M-%SZ")`.
- `pip install --user pillow` works and includes WebP support on the server (`PIL.features.check("webp") == True`).

## Pillow crash on truncated JPGs (network-failed downloads)

Upstream JPEGs occasionally arrive truncated (interrupted download, network glitch). Pillow doesn't fail at `Image.open()` — it fails deep inside `im.thumbnail()` with `OSError: image file is truncated (N bytes not processed)`. That kills the whole thumb/manifest pipeline.

**Fix:** `im = Image.open(src); im.load()` inside `try/except (OSError, SyntaxError)`. Return None, count skipped — one corrupt frame must not stop the batch. Then delete the corrupt source file so the next cron tick re-fetches it cleanly.

## Static frontend in a subdirectory

If the site is served under `/subdir/`, ALL asset/fetch paths must be relative (`css/site.css`, `js/app.js`, `data/manifest.json`) — absolute paths (`/js/...`, `/data/...`) resolve against the domain root and 404. This bit twice in one session (data fetches AND static assets). Write relative from the start; grep for `(src|href)=\"/` before deploying.

Also: if the repo top-level has `web/index.html` but the server docroot is `~/.../timelapse/`, run `mv web/* .; rmdir web` on the remote after the first deploy (or restructure deploy to push `web/` contents flat into the docroot). Otherwise Apache serves a DirectoryListing instead of the index.

## Alpine.js / Vue-style frameworks: x-init vs x-model races

In Alpine.js, `x-init="init()"` runs at mount. The same component binding `x-model="rangeFrom"` on a date `<input>` will fire `@change` when Alpine links the prop. If `init()` sets `this.rangeFrom` and `this.rangeTo` *before* calling `loadRange()`, the `@change` on the date input may fire BEFORE `_ready` is true, OR `loadRange()` may be triggered twice (once by init, once by the date-input change-handler registration).

Symptoms:
- `frames` array has 2× the expected count (duplicate manifest entries)
- Status text or computed values flicker stale on first render

**Fixes (use both for safety):**
1. Set a `_ready = true` flag at the end of init, BEFORE any `await`, and `if (!this._ready) return` as first line of the handler that does the work. This stops most of the duplicate dispatches.
2. Reset stale state with explicit success handlers: `<img @load="error=''">` to clear any "Bild konnte nicht geladen werden" message from a transient initial-render error that wasn't actually a failure.
3. Test by checking array dedup rates (`new Set(...).size` vs `.length`) and force-reload through `location.reload(true)` — Safari is aggressive about caching JS even when you bust the query string.

## Session detail

- `references/sillywebcamview-deploy-2026-07.md` — full error transcripts, working crontab template (bitzi + timelapse jobs), .htaccess example (cache profile), flaky-SSH retry log, the `mv web/* .` to flatten the deployed tree.
