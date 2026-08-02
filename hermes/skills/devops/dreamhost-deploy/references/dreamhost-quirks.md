# Dreamhost Quirks — Session Detail (sillyWebcamView deploy, 2026-07-25)

Concrete artifacts and error transcripts from deploying a static+python app to `bristenblick.ch/timelapse/`.

## Account / Host

- SSH: `silly82@bristenblick.ch` (also answers on `pdx1-shared-a1-13.dreamhost.com`)
- Home: `/home/silly82/` with one dir per domain: `anathol.ch/`, `bristenblick.ch/`, `figaro-der-frisurenladen.ch/`, `hellgass.ch/`, `urnernerd.ch/`, `grammophon.me/`, `prisil.net/`
- Disk: 18T total, ~1.6T free — storage is a non-issue; Dreamhost "Unlimited" AUP still disallows pure file-archive usage, so server-side retention policy (e.g. originals roll off after 30d, thumbnails stay) is the safe pattern.
- Python: `/usr/bin/python3` = 3.10.12. `pip install --user` works. Pillow wheel includes WebP.

## bristenblick.ch root .htaccess (pre-existing)

```apache
RewriteEngine on
RewriteBase /
RewriteCond %{REQUEST_URI} !^/weather/
RewriteCond %{REQUEST_URI} !^/camview/
RewriteCond %{REQUEST_URI} !^/bitzicam/
RewriteCond %{REQUEST_URI} !^/timelapse/    # <-- added for the app
RewriteCond %{HTTP_HOST} ^(www\.)?bristenblick\.
RewriteRule ^(.*)$ /weather/$1 [L]
```
Every request not matching an excluded subdir is rewritten into `/weather/`. New apps MUST add their exclusion before going live, else everything 404s silently into the weather app.

## App-dir .htaccess (timelapse/)

```apache
AddType image/webp .webp
```
Without it, `.webp` is served with no Content-Type and browsers show "Bild konnte nicht geladen werden" even though HTTP 200 + correct bytes.

## Crontab block format (Dreamhost-managed)

```
###--- BEGIN DREAMHOST BLOCK
###--- Changes made to this part of the file WILL be destroyed!
# Bitzi trigger watchdog
MAILTO="siliwalker@gmail.com"
*/10 * * * * /usr/bin/setlock -n /tmp/cronlock.3784550962.432417 sh -c '/bin/bash -lc '\''...'\'''
# cron für bristenblick
MAILTO=""
*/10 * * * * /usr/bin/setlock -n /tmp/cronlock.3784550962.452599 bash -c "/home/silly82/bristenblick.ch/timelapse/scripts/run_update.sh"
###--- You can make changes below the next line and they will be preserved!
###--- END DREAMHOST BLOCK
```
Canonical copy lives in the sillyWebcamView repo at `scripts/crontab.txt`. Install: `cat scripts/crontab.txt | ssh ... "cat | crontab -"`. Note: piping replaces the WHOLE crontab — the file must contain every job (including pre-existing ones like the bitzi watchdog).

## Errors hit (verbatim) and fixes

1. `rsync: [Receiver] mkdir "/Users/silvanwalker/bristenblick.ch/timelapse" failed: No such file or directory` — `~` in DEST expanded locally. Fix: relative DEST.
2. `Too many authentication failures` — ssh-agent offered other keys first. Fix: `-o IdentitiesOnly=yes -o IdentityFile=~/.ssh/hermes_dreamhost`.
3. `bash: /home/silly82/.ssh/authorized_keys: No such file or directory` — `.ssh` dir didn't exist on the account (created 2011, never used with keys). Fix: `mkdir -p ~/.ssh && chmod 700 ~/.ssh` first.
4. 403 Forbidden after rsync/mv — permissions. Fix: `chmod 755 . css js data data/*; chmod 644 *.html css/* js/*`.
5. Cron silently not running — (a) `$HOME` unexpanded inside `sh -c '...'`; (b) `~/logs/webcam.log` not writable (`~/logs/` is `dr-xr-x--- silly82:dhapache`). Fix: absolute path + `bash -c` in crontab; log to `data/logs/` with `mkdir -p` in runner.
6. Alpine.js showed "0 Frames" despite manifest being fine — fetch() used absolute `/data/manifest/...` which resolved to domain root (rewritten into /weather/ → 404). Absolute paths hid in THREE places: `init()`, `loadRange()` loop, and `thumbUrl()`/`originalUrl()`. Grep ALL of them.
7. `rsync -avz --delete web/ $DEST` run AFTER the general code sync deleted everything not in `web/`: `data/` (with the first archived frame), `scripts/`, `LICENSE`, `dreamhost_deploy.sh`. Recovery: re-deploy scripts, `mkdir -p data/{archive,thumbs,manifest}`, re-run fetch manually. Rule: `--delete` only ever on trees that are 100% code.
8. Pillow crash mid-pipeline: `OSError: image file is truncated (38 bytes not processed)` in `ImageFile.load` — the 10:30 frame was only 281 KB (partial download, likely cron fetch interrupted). The unhandled exception in `make_thumb` killed `build_all`, so NO thumbs were built for subsequent good frames either, and the player showed broken-image for those timestamps. Fix in `build_thumbs.py`: wrap `Image.open(src)` + `im.load()` in `try/except (OSError, SyntaxError)`, `return None` on failure, count skipped in `build_all` (`built N thumbs, skipped M corrupt`). Then delete the corrupt jpg + its `.exif.json` sidecar and re-run thumbs+manifest.

## SSH instability pattern

Bursts of `Connection timed out during banner exchange` and commands hanging 15-60s, alternating with working windows. Successful approach: `-o ConnectTimeout=10`, short single-purpose commands, `sleep 5-10` between retries, avoid multi-line heredocs over ssh (write file locally, pipe it).
