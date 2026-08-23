# Migration Plan: Dotfiles Consolidation

**Created:** 2026-08-23 · **Status:** not started

## Goal

End state: exactly **two** repos, no permanent branches-per-machine.

- `nixos-config` — declarative Nix/system config (unchanged in structure, one small fix below).
- `dotfiles` — plain files, manually symlinked in (existing pattern, see `README.md`). Absorbs `uconsole-dotfiles`.

`uconsole-dotfiles` is retired (archived, not deleted) once its content is verified merged.

**Workflow:** done on a short-lived feature branch `dotfiles-consolidation` in both `dotfiles` and `nixos-config`, not directly on `main` and not in a new repo. Reason: the uConsole is the one host where a bad edit (sway/greetd) can break boot, so it needs to be verified there — including surviving an actual reboot — before `main` (the branch `nixos-rebuild` normally tracks) reflects the change. Only one machine (wherever Step 0–5 run, e.g. the Mac) authors commits; the uConsole only fetches the branch to test, it never pushes its own state. Once verified, the branch is merged to `main` in both repos and deleted — this is not a permanent parallel branch.

## Non-goals (explicitly out of scope for this plan)

- Restructuring or moving `hermes/` inside `dotfiles` — unrelated agent-runtime state, separate concern.
- Converting Ghostty/kitty/iterm2 to Home Manager — staying with the existing manual-symlink pattern documented in `README.md`.
- Any change to the Mac (`GallifreyM1`) or Linux-desktop (`nixos`) hosts.

## Current state (verify before executing — this may have drifted)

| Repo | Owns | Last updated (at plan creation) |
|---|---|---|
| `nixos-config` | System config for all 3 hosts. For `uconsole-cm5`: sway config, greetd config, foot.ini — all declared inline as `environment.etc."...".text` in `hosts/uconsole-cm5/configuration.nix` | 2026-08-22 |
| `dotfiles` | Ghostty/kitty/iterm2/shell configs (Mac), each with a documented manual `ln -sf` setup in `README.md`; also an unrelated `hermes/` dir (out of scope, see above) | 2026-08-05 |
| `uconsole-dotfiles` | `sway/`, `waybar/`, `greetd/`, `systemd/user/` — for the *same* uConsole device already partly covered by `nixos-config` | 2026-07-13 |

**Key finding:** `nixos-config` is the newer, actively-maintained source for sway/greetd/foot on the uConsole. `uconsole-dotfiles`'s `sway/config` and `greetd/config.toml` are very likely stale duplicates that lost the merge. **Waybar config and the wayvnc systemd override are not declared anywhere in `nixos-config`** — those are the only pieces of `uconsole-dotfiles` not already superseded, and are what actually needs migrating.

**Update 2026-08-23:** the local Mac clone of `nixos-config` was 4 commits behind `origin/main` (stale uncommitted draft found in the working tree, stashed — not lost — and fast-forwarded to `origin/main`). Those missed commits already fixed the wallpaper bug (now points at `/home/silly82/.config/sway/wallpaper.png`, matching what Step 4 below used to propose) and added sops-nix-based WiFi PSK management for the uConsole. **Step 4 (wallpaper path fix) is therefore already done upstream — skip it.** Always re-fetch/pull all three repos before trusting this plan's "current state" section.

## Target end state

```
nixos-config/                  (unchanged, one edit — Step 4)

dotfiles/
  ghostty/…                    (unchanged)
  kitty/…                      (unchanged)
  iterm2/…                     (unchanged)
  shell/…                      (unchanged)
  hermes/…                     (untouched, out of scope)
  waybar/xdg/
    config.jsonc
    style.css
  systemd/user/
    rpi-connect-wayvnc.service.d/override.conf
  wallpaper/
    uconsole-wallpaper.png
  README.md                    (new "uConsole (NixOS, Wayland)" section)

uconsole-dotfiles/              (archived on GitHub once verified — Step 7)
```

## Steps

### Step 0 — Prerequisites

`uconsole-dotfiles` is a public repo and does not need to already be cloned on the uConsole to do this merge — clone it wherever you're running this plan from (e.g. the Mac, which already has `~/nixos-config` and `~/dotfiles`):

```bash
git clone https://github.com/silly82/uconsole-dotfiles.git /tmp/uconsole-dotfiles-migrate

cd ~/dotfiles     && git checkout -b dotfiles-consolidation
cd ~/nixos-config && git checkout -b dotfiles-consolidation
```

### Step 1 — Verify the "stale duplicate" assumption before discarding anything

Compare `/tmp/uconsole-dotfiles-migrate/sway/config` and `/tmp/uconsole-dotfiles-migrate/greetd/config.toml` against the inline text in `~/nixos-config/hosts/uconsole-cm5/configuration.nix` (`environment.etc."sway/config".text` and `services.greetd.settings`). A manual read-through is fine — the point is to confirm nixos-config's version is a superset/newer before treating the `uconsole-dotfiles` copies as safe to drop.

- If confirmed stale → **do not** copy `sway/` or `greetd/` into `dotfiles`. `nixos-config` stays sole owner.
- If `uconsole-dotfiles` has something nixos-config is missing → port that piece into `hosts/uconsole-cm5/configuration.nix` first, then proceed as if confirmed stale.

### Step 2 — Copy the non-duplicated pieces into `dotfiles`

```bash
cd ~/dotfiles
mkdir -p waybar/xdg systemd/user wallpaper
cp /tmp/uconsole-dotfiles-migrate/waybar/config.jsonc waybar/xdg/
cp /tmp/uconsole-dotfiles-migrate/waybar/style.css waybar/xdg/
cp -r /tmp/uconsole-dotfiles-migrate/systemd/user/rpi-connect-wayvnc.service.d systemd/user/
cp /tmp/uconsole-dotfiles-migrate/sway/wallpapers/wallpaper.png wallpaper/uconsole-wallpaper.png
```

### Step 3 — Document it in `dotfiles/README.md`

Add a new section, English first then the Swiss-German mirror (same structure the file already uses for Ghostty/kitty/iterm2):

```markdown
## uConsole (NixOS, Wayland)

Sway, greetd and the foot terminal are declared **in `nixos-config`**
(`hosts/uconsole-cm5/configuration.nix`, inline as `environment.etc.*.text`) —
not in this repo. This repo only holds what NixOS does not declare for that host:

| Role | Path on device | Path in repo |
|---|---|---|
| Waybar config | `~/.config/waybar/` | `waybar/xdg/` |
| wayvnc systemd override | `~/.config/systemd/user/rpi-connect-wayvnc.service.d/` | `systemd/user/rpi-connect-wayvnc.service.d/` |
| Wallpaper | `~/.config/sway/wallpaper.png` | `wallpaper/uconsole-wallpaper.png` |

### Setup (new uConsole, or reinstall)

    ln -sfn ~/dotfiles/waybar/xdg ~/.config/waybar
    mkdir -p ~/.config/systemd/user
    ln -sfn ~/dotfiles/systemd/user/rpi-connect-wayvnc.service.d ~/.config/systemd/user/rpi-connect-wayvnc.service.d
    mkdir -p ~/.config/sway
    ln -sf ~/dotfiles/wallpaper/uconsole-wallpaper.png ~/.config/sway/wallpaper.png
    systemctl --user daemon-reload
```

(German mirror: translate 1:1 into Swiss High German — "ss" not "ß" — same as the rest of `README.md`.)

### Step 4 — ~~Fix the wallpaper path in `nixos-config`~~ (already done upstream, skip)

Already fixed on `origin/main` as of `nixos-config` commit `6a8735f` — `environment.etc."sway/config".text` already points at `/home/silly82/.config/sway/wallpaper.png`. Nothing to do here; keep going to Step 5.

### Step 5 — Commit and push the branch (not `main`)

```bash
cd ~/dotfiles
git add waybar systemd wallpaper README.md
git commit -m "Merge uconsole-dotfiles: waybar, wayvnc systemd override, wallpaper"
git push -u origin dotfiles-consolidation
```

`nixos-config`'s branch is only relevant if Step 1 found something to port over — with Step 4 now a no-op, that's probably nothing. If `git status` on `~/nixos-config` shows no changes, skip pushing that branch and delete it locally (`git checkout main && git branch -d dotfiles-consolidation`). If Step 1 did turn something up:

```bash
cd ~/nixos-config
git add hosts/uconsole-cm5/configuration.nix
git commit -m "uconsole-cm5: point sway wallpaper at a persistent path"
git push -u origin dotfiles-consolidation
```

Review `git diff main` on both before pushing.

### Step 6 — Test on the uConsole device, on the branch (not `main`)

```bash
# on the uConsole:
cd ~/nixos-config && git fetch && git checkout dotfiles-consolidation
sudo nixos-rebuild switch --flake ~/nixos-config#uconsole-cm5

cd ~/dotfiles && git fetch && git checkout dotfiles-consolidation   # clone fresh if not present yet
# then run the Step 3 setup commands above
systemctl --user restart rpi-connect-wayvnc.service
```

Verify: waybar renders, wallpaper survives an actual reboot (not just this session), wayvnc still reachable on port 5900. **Reboot the uConsole at least once** and re-check before declaring this step done — that's the whole point of testing on the branch first.

### Step 7 — Merge to `main`, both repos

Only after Step 6's reboot test passes. Can be done from any machine with push access:

```bash
cd ~/dotfiles
git checkout main && git pull
git merge dotfiles-consolidation
git push
git branch -d dotfiles-consolidation
git push origin --delete dotfiles-consolidation

cd ~/nixos-config
git checkout main && git pull
git merge dotfiles-consolidation
git push
git branch -d dotfiles-consolidation
git push origin --delete dotfiles-consolidation
```

Then on every machine that had the branch checked out (the uConsole), switch back to `main`:

```bash
cd ~/nixos-config && git checkout main && git pull
cd ~/dotfiles      && git checkout main && git pull
```

(No rebuild needed here — content is identical to what was already tested on the branch.)

### Step 8 — Retire `uconsole-dotfiles` (ask first)

Once Step 7 is done: **ask the user** before archiving `uconsole-dotfiles` on GitHub (Settings → Archive repository). This is a visible, remote action — do not do it unattended. Do not delete the repo.

## Notes for whichever Claude session executes this

- This file may be stale by the time it runs — re-check the "Current state" table (`git log -1` in all three repos) before trusting it, and check whether a `dotfiles-consolidation` branch already exists (partial progress).
- Work through the steps in order; commit after each so a bad step is easy to isolate or revert.
- Steps 7 (merge to `main`) and 8 (archive `uconsole-dotfiles`) both require explicit user confirmation before running — these affect shared/remote state.
- Leave `hermes/` alone; it is not part of this plan.

---

# Migrationsplan: Dotfiles-Konsolidierung (Deutsch)

**Erstellt:** 2026-08-23 · **Status:** nicht begonnen

## Ziel

Zielzustand: genau **zwei** Repos, keine dauerhaften Branches pro Rechner.

- `nixos-config` — deklarative Nix-/System-Konfiguration (Struktur unverändert, eine kleine Korrektur weiter unten).
- `dotfiles` — reine Dateien, manuell verlinkt (bestehendes Muster, siehe `README.md`). Nimmt `uconsole-dotfiles` auf.

`uconsole-dotfiles` wird stillgelegt (archiviert, nicht gelöscht), sobald der Inhalt nachweislich übernommen ist.

**Vorgehen:** über einen kurzlebigen Feature-Branch `dotfiles-consolidation` in `dotfiles` UND `nixos-config` — nicht direkt auf `main`, und nicht in einem neuen Repo. Grund: die uConsole ist der einzige Host, bei dem eine falsche Änderung (Sway/greetd) den Boot zerlegen kann — das muss dort erst verifiziert werden, inklusive echtem Reboot-Test, bevor `main` (worauf `nixos-rebuild` normalerweise zeigt) den neuen Stand bekommt. Nur eine Maschine (dort wo Schritt 0–5 laufen, z. B. der Mac) erzeugt Commits; die uConsole holt sich den Branch nur zum Testen, sie pusht nie ihren eigenen Stand. Nach erfolgreicher Verifikation wird der Branch in beide `main`s gemergt und gelöscht — kein dauerhafter Parallel-Branch.

## Nicht-Ziele (bewusst ausserhalb dieses Plans)

- Umstrukturierung oder Verschieben von `hermes/` innerhalb von `dotfiles` — unabhängiger Agent-Laufzeit-State, eigenes Thema.
- Umstellung von Ghostty/kitty/iterm2 auf Home Manager — bleibt beim bestehenden manuellen Symlink-Muster aus `README.md`.
- Jegliche Änderung an den Hosts `GallifreyM1` (Mac) oder `nixos` (Linux-Desktop).

## Ist-Zustand (vor Ausführung prüfen — kann inzwischen abgewichen sein)

| Repo | Zuständig für | Letztes Update (bei Planerstellung) |
|---|---|---|
| `nixos-config` | System-Konfig aller 3 Hosts. Für `uconsole-cm5`: Sway-Config, greetd-Config, foot.ini — alles inline als `environment.etc."...".text` in `hosts/uconsole-cm5/configuration.nix` deklariert | 22.08.2026 |
| `dotfiles` | Ghostty/kitty/iterm2/Shell-Configs (Mac), je mit dokumentiertem manuellem `ln -sf`-Setup im `README.md`; zusätzlich ein unabhängiger `hermes/`-Ordner (ausserhalb des Plans) | 05.08.2026 |
| `uconsole-dotfiles` | `sway/`, `waybar/`, `greetd/`, `systemd/user/` — für dasselbe uConsole-Gerät, teilweise bereits durch `nixos-config` abgedeckt | 13.07.2026 |

**Kernbefund:** `nixos-config` ist die neuere, aktiv gepflegte Quelle für Sway/greetd/foot auf der uConsole. `uconsole-dotfiles`s `sway/config` und `greetd/config.toml` sind mit hoher Wahrscheinlichkeit veraltete Duplikate, die den Merge verpasst haben. **Waybar-Config und der wayvnc-systemd-Override sind nirgends in `nixos-config` deklariert** — das sind die einzigen Teile von `uconsole-dotfiles`, die tatsächlich noch migriert werden müssen.

**Update 23.08.2026:** der lokale Mac-Klon von `nixos-config` lag 4 Commits hinter `origin/main` (veralteter, uncommitteter Entwurf im Arbeitsverzeichnis gefunden, gestasht — nicht verloren — und per Fast-Forward auf `origin/main` gebracht). Diese verpassten Commits enthielten bereits den Wallpaper-Fix (zeigt jetzt auf `/home/silly82/.config/sway/wallpaper.png`, genau das, was Schritt 4 unten vorschlug) sowie eine sops-nix-basierte WiFi-PSK-Verwaltung für die uConsole. **Schritt 4 (Wallpaper-Pfad-Fix) ist damit bereits upstream erledigt — überspringen.** Vor Vertrauen in den "Ist-Zustand" dieses Plans immer alle drei Repos frisch fetchen/pullen.

## Zielstruktur

```
nixos-config/                  (unverändert, eine Änderung — Schritt 4)

dotfiles/
  ghostty/…                    (unverändert)
  kitty/…                      (unverändert)
  iterm2/…                     (unverändert)
  shell/…                      (unverändert)
  hermes/…                     (unangetastet, ausserhalb des Plans)
  waybar/xdg/
    config.jsonc
    style.css
  systemd/user/
    rpi-connect-wayvnc.service.d/override.conf
  wallpaper/
    uconsole-wallpaper.png
  README.md                    (neuer Abschnitt "uConsole (NixOS, Wayland)")

uconsole-dotfiles/              (auf GitHub archiviert, sobald verifiziert — Schritt 7)
```

## Schritte

### Schritt 0 — Voraussetzungen

`uconsole-dotfiles` ist ein öffentliches Repo und muss für diesen Merge nicht schon auf der uConsole liegen — einfach dort klonen, wo dieser Plan ausgeführt wird (z. B. am Mac, wo `~/nixos-config` und `~/dotfiles` schon vorhanden sind):

```bash
git clone https://github.com/silly82/uconsole-dotfiles.git /tmp/uconsole-dotfiles-migrate

cd ~/dotfiles     && git checkout -b dotfiles-consolidation
cd ~/nixos-config && git checkout -b dotfiles-consolidation
```

### Schritt 1 — Annahme "veraltetes Duplikat" verifizieren, bevor irgendwas verworfen wird

`/tmp/uconsole-dotfiles-migrate/sway/config` und `/tmp/uconsole-dotfiles-migrate/greetd/config.toml` gegen den Inline-Text in `~/nixos-config/hosts/uconsole-cm5/configuration.nix` vergleichen (`environment.etc."sway/config".text` und `services.greetd.settings`). Ein manueller Durchgang reicht — es geht darum, zu bestätigen, dass die nixos-config-Version eine neuere/vollständigere Version ist, bevor die `uconsole-dotfiles`-Kopien verworfen werden.

- Bestätigt veraltet → `sway/` und `greetd/` **nicht** nach `dotfiles` kopieren. `nixos-config` bleibt alleinige Quelle.
- Falls `uconsole-dotfiles` etwas enthält, das in nixos-config fehlt → das zuerst in `hosts/uconsole-cm5/configuration.nix` nachziehen, dann weiter wie bei "bestätigt veraltet".

### Schritt 2 — Die nicht-duplizierten Teile nach `dotfiles` kopieren

```bash
cd ~/dotfiles
mkdir -p waybar/xdg systemd/user wallpaper
cp /tmp/uconsole-dotfiles-migrate/waybar/config.jsonc waybar/xdg/
cp /tmp/uconsole-dotfiles-migrate/waybar/style.css waybar/xdg/
cp -r /tmp/uconsole-dotfiles-migrate/systemd/user/rpi-connect-wayvnc.service.d systemd/user/
cp /tmp/uconsole-dotfiles-migrate/sway/wallpapers/wallpaper.png wallpaper/uconsole-wallpaper.png
```

### Schritt 3 — In `dotfiles/README.md` dokumentieren

Neuen Abschnitt ergänzen, Englisch zuerst, dann die deutsche Fassung (gleiche Struktur wie die bestehenden Abschnitte zu Ghostty/kitty/iterm2). Inhalt siehe englischer Teil oben — 1:1 ins Schweizer Hochdeutsch übertragen ("ss" statt "ß"), wie im restlichen `README.md`.

### Schritt 4 — ~~Wallpaper-Pfad in `nixos-config` korrigieren~~ (bereits upstream erledigt, überspringen)

Bereits gefixt auf `origin/main`, `nixos-config`-Commit `6a8735f` — `environment.etc."sway/config".text` zeigt schon auf `/home/silly82/.config/sway/wallpaper.png`. Nichts zu tun, weiter mit Schritt 5.

### Schritt 5 — Committen und Branch pushen (nicht `main`)

```bash
cd ~/dotfiles
git add waybar systemd wallpaper README.md
git commit -m "Merge uconsole-dotfiles: waybar, wayvnc systemd override, wallpaper"
git push -u origin dotfiles-consolidation
```

Der `nixos-config`-Branch ist nur relevant, falls Schritt 1 etwas zum Nachziehen gefunden hat — da Schritt 4 jetzt entfällt, ist das vermutlich nichts. Zeigt `git status` in `~/nixos-config` keine Änderungen, Branch überspringen und lokal wieder löschen (`git checkout main && git branch -d dotfiles-consolidation`). Falls Schritt 1 doch etwas ergeben hat:

```bash
cd ~/nixos-config
git add hosts/uconsole-cm5/configuration.nix
git commit -m "<passende Commit-Message>"
git push -u origin dotfiles-consolidation
```

Vor dem Push `git diff main` in beiden Repos prüfen.

### Schritt 6 — Auf der uConsole testen, auf dem Branch (nicht `main`)

```bash
# auf der uConsole:
cd ~/nixos-config && git fetch && git checkout dotfiles-consolidation
sudo nixos-rebuild switch --flake ~/nixos-config#uconsole-cm5

cd ~/dotfiles && git fetch && git checkout dotfiles-consolidation   # bei Bedarf frisch klonen
# danach die Setup-Befehle aus Schritt 3 ausführen
systemctl --user restart rpi-connect-wayvnc.service
```

Prüfen: Waybar wird angezeigt, Wallpaper übersteht einen echten Neustart (nicht nur die laufende Session), wayvnc ist weiterhin auf Port 5900 erreichbar. **Die uConsole mindestens einmal neu starten** und danach erneut prüfen — genau dafür ist der Test auf dem Branch da.

### Schritt 7 — Merge nach `main`, beide Repos

Erst nachdem der Reboot-Test aus Schritt 6 bestanden ist. Kann von jeder Maschine mit Push-Zugriff aus gemacht werden:

```bash
cd ~/dotfiles
git checkout main && git pull
git merge dotfiles-consolidation
git push
git branch -d dotfiles-consolidation
git push origin --delete dotfiles-consolidation

cd ~/nixos-config
git checkout main && git pull
git merge dotfiles-consolidation
git push
git branch -d dotfiles-consolidation
git push origin --delete dotfiles-consolidation
```

Danach auf jeder Maschine, die den Branch ausgecheckt hatte (die uConsole), zurück auf `main` wechseln:

```bash
cd ~/nixos-config && git checkout main && git pull
cd ~/dotfiles      && git checkout main && git pull
```

(Kein Rebuild nötig — der Inhalt ist identisch zu dem, was bereits auf dem Branch getestet wurde.)

### Schritt 8 — `uconsole-dotfiles` stilllegen (vorher nachfragen)

Sobald Schritt 7 abgeschlossen ist: **vor dem Archivieren von `uconsole-dotfiles` auf GitHub den Nutzer fragen** (Settings → Archive repository). Das ist eine sichtbare, remote wirksame Aktion — nicht unbeaufsichtigt ausführen. Das Repo nicht löschen.

## Hinweise für die ausführende Claude-Session

- Diese Datei kann bei Ausführung veraltet sein — die Tabelle "Ist-Zustand" vor Vertrauen erneut prüfen (`git log -1` in allen drei Repos), und prüfen, ob ein `dotfiles-consolidation`-Branch schon existiert (Teilfortschritt).
- Schritte der Reihe nach abarbeiten; nach jedem Schritt committen, damit ein fehlerhafter Schritt leicht isolierbar/revertierbar ist.
- Schritt 7 (Merge nach `main`) und Schritt 8 (Archivieren von `uconsole-dotfiles`) brauchen beide vorherige explizite Nutzerbestätigung — beide betreffen gemeinsamen/remote State.
- `hermes/` bleibt unangetastet, ist nicht Teil dieses Plans.
