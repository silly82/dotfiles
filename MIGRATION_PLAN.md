# Migration Plan: Dotfiles Consolidation

**Created:** 2026-08-23 · **Status:** in progress — Steps 0–3, 5 done on `dotfiles`; Steps 6–8 need the real uConsole CM4 device / user confirmation.

## Goal

End state: exactly **two** repos, no permanent branches-per-machine.

- `nixos-config` — declarative Nix/system config. **Untouched by this plan** (see revised finding below).
- `dotfiles` — plain files, manually symlinked in (existing pattern, see `README.md`). Absorbs `uconsole-dotfiles`.

`uconsole-dotfiles` is retired (archived, not deleted) once its content is verified merged.

**Workflow:** done on a short-lived feature branch `dotfiles-consolidation` in `dotfiles` (pushed to `origin`), not directly on `main` and not in a new repo. Reason: the target device (uConsole CM4) needs to be verified working — including surviving an actual reboot — before `main` reflects the change. Only the Mac authored commits; the CM4 device only fetches the branch to test, it never pushes its own state. Once verified, the branch is merged to `main` and deleted — this is not a permanent parallel branch.

## Non-goals (explicitly out of scope for this plan)

- Restructuring or moving `hermes/` inside `dotfiles` — unrelated agent-runtime state, separate concern.
- Converting Ghostty/kitty/iterm2 to Home Manager — staying with the existing manual-symlink pattern documented in `README.md`.
- Any change to the Mac (`GallifreyM1`), the Linux desktop (`nixos`), or the **uConsole CM5 / NixOS** host.

## Current state

| Repo | Owns | Status |
|---|---|---|
| `nixos-config` | System config for `GallifreyM1`, `nixos`, and **uConsole CM5** (NixOS: direct `sway` via `services.greetd`, no cage/gtkgreet, declared inline in `hosts/uconsole-cm5/configuration.nix`). | Not touched by this plan — see finding below. |
| `dotfiles` | Ghostty/kitty/iterm2/shell (Mac) + now `uconsole-cm4/` (sway, waybar, greetd, systemd — see below). Also an unrelated `hermes/` dir (out of scope). | `uconsole-cm4/` merged in on branch `dotfiles-consolidation`, pushed to `origin`. Not yet in `main`. |
| `uconsole-dotfiles` | `sway/`, `waybar/`, `greetd/`, `systemd/user/` for the **uConsole CM4** (Debian 13 trixie, apt-managed, greetd+cage+gtkgreet login). | Content fully copied into `dotfiles/uconsole-cm4/`. Repo itself not yet archived (Step 8). |

**Key finding — this plan's original premise was wrong, corrected 2026-08-23 after actually reading the content:** `uconsole-dotfiles` is *not* a stale duplicate of `nixos-config`'s uConsole host. There are **two separate physical uConsole devices**:

- **CM4** (Raspberry Pi Compute Module 4), Debian 13 trixie, apt-managed packages, `greetd` + `cage` + `gtkgreet` login manager, Mod4 as `$mod`, display DSI-1 @ scale 1.5. This is what `uconsole-dotfiles` configures. **Not managed by Nix at all.**
- **CM5** (Compute Module 5), NixOS, `sway` launched directly via `services.greetd` (no cage/gtkgreet), Mod1 as `$mod`, display DSI-2 @ scale 2.0. This is `hosts/uconsole-cm5/configuration.nix` in `nixos-config`.

Different hardware, different OS, different config mechanism, zero overlap. **`nixos-config` needs no changes for this migration** — the original plan's Step 4 (wallpaper path) was a red herring caused by comparing the wrong device's config; it was already fixed upstream for CM5 anyway (`nixos-config` commit `6a8735f`) and was never related to CM4.

## Target end state

```
nixos-config/                  unchanged — not part of this migration

dotfiles/
  ghostty/…                    unchanged
  kitty/…                      unchanged
  iterm2/…                     unchanged
  shell/…                      unchanged
  hermes/…                     untouched, out of scope
  uconsole-cm4/                 NEW — done, on branch dotfiles-consolidation
    sway/config
    sway/wallpapers/wallpaper.png
    waybar/config.jsonc
    waybar/style.css
    greetd/config.toml
    greetd/environments
    greetd/greetd-gtkgreet-run
    systemd/user/rpi-connect-wayvnc.service.d/override.conf
  README.md                    new "uConsole CM4 (Debian 13 trixie, Sway/Wayland)" section — done

uconsole-dotfiles/              archived on GitHub once verified on-device — Step 8
```

## Steps

### Step 0 — Prerequisites — DONE

Cloned `uconsole-dotfiles` to `/tmp/uconsole-dotfiles-migrate`, created branch `dotfiles-consolidation` in `dotfiles`. (Also briefly created one in `nixos-config`, deleted again once it turned out nothing needed to change there.)

### Step 1 — Compare content before assuming anything is stale — DONE, assumption overturned

Reading `uconsole-dotfiles`'s actual `sway/config` (header comment: `### Sway config — ClockworkPI uConsole (CM4) ###`) and `greetd/config.toml` (`cage -s -- /usr/local/bin/greetd-gtkgreet-run`, user `_greetd`) showed this is CM4/Debian config, unrelated to `nixos-config`'s CM5/NixOS host. See "Key finding" above. Nothing needed porting into `nixos-config` — it was never a duplicate.

### Step 2 — Copy everything into `dotfiles/uconsole-cm4/` — DONE

```bash
cd ~/dotfiles
mkdir -p uconsole-cm4/sway/wallpapers uconsole-cm4/waybar uconsole-cm4/greetd uconsole-cm4/systemd/user
cp /tmp/uconsole-dotfiles-migrate/sway/config uconsole-cm4/sway/config
cp /tmp/uconsole-dotfiles-migrate/sway/wallpapers/wallpaper.png uconsole-cm4/sway/wallpapers/wallpaper.png
cp /tmp/uconsole-dotfiles-migrate/waybar/config.jsonc uconsole-cm4/waybar/config.jsonc
cp /tmp/uconsole-dotfiles-migrate/waybar/style.css uconsole-cm4/waybar/style.css
cp /tmp/uconsole-dotfiles-migrate/greetd/config.toml uconsole-cm4/greetd/config.toml
cp /tmp/uconsole-dotfiles-migrate/greetd/environments uconsole-cm4/greetd/environments
cp /tmp/uconsole-dotfiles-migrate/greetd/greetd-gtkgreet-run uconsole-cm4/greetd/greetd-gtkgreet-run
cp -r /tmp/uconsole-dotfiles-migrate/systemd/user/rpi-connect-wayvnc.service.d uconsole-cm4/systemd/user/
```

Unlike the original plan (which only migrated waybar/systemd/wallpaper), **everything** was copied — sway and greetd included — since none of it was actually superseded.

### Step 3 — Document it in `dotfiles/README.md` — DONE

New section `## uConsole CM4 (Debian 13 trixie, Sway/Wayland)` added, German only (matching this README's actual convention — no English mirror exists in this file, unlike `nixos-config`'s README). Explicitly calls out the CM4-vs-CM5 distinction. Contains the apt install list, the symlink/copy setup commands, the `_greetd` group fix, and the greetd/lightdm display-manager switch-over — ported from `uconsole-dotfiles`'s own README.

### Step 4 — ~~n/a~~

Dropped. Was based on the wrong assumption that `nixos-config` needed a wallpaper-path edit for this migration; it didn't (see Key finding).

### Step 5 — Commit and push the branch — DONE

```bash
cd ~/dotfiles
git add uconsole-cm4 README.md
git commit -m "Merge uconsole-dotfiles (CM4) into this repo under uconsole-cm4/"
git push -u origin dotfiles-consolidation
```

Pushed to `origin/dotfiles-consolidation` on `github.com/silly82/dotfiles`. `nixos-config` needed no commit — confirmed clean (`git status` empty) and its temporary branch was deleted.

### Step 6 — Test on the actual uConsole CM4 device — NOT DONE (needs the physical device)

```bash
# on the uConsole CM4:
cd ~/dotfiles && git fetch && git checkout dotfiles-consolidation   # clone fresh if not present yet

# back up anything currently at these paths first if it's not already a symlink into this repo
ln -sfn ~/dotfiles/uconsole-cm4/sway ~/.config/sway
ln -sfn ~/dotfiles/uconsole-cm4/waybar ~/.config/waybar
sudo cp ~/dotfiles/uconsole-cm4/greetd/greetd-gtkgreet-run /usr/local/bin/
sudo cp ~/dotfiles/uconsole-cm4/greetd/config.toml /etc/greetd/
sudo cp ~/dotfiles/uconsole-cm4/greetd/environments /etc/greetd/
mkdir -p ~/.config/systemd/user
ln -sfn ~/dotfiles/uconsole-cm4/systemd/user/rpi-connect-wayvnc.service.d ~/.config/systemd/user/rpi-connect-wayvnc.service.d
systemctl --user daemon-reload
systemctl --user restart rpi-connect-wayvnc.service
```

Verify: Sway starts via greetd/cage/gtkgreet as before, waybar renders with icons, wallpaper shows, `$mod` (Alt) shortcuts work, wayvnc via Raspberry Pi Connect still reachable. **Reboot the device at least once** and re-check before declaring this done — that's the whole point of testing on the branch first. If the device previously ran directly off `uconsole-dotfiles` clone rather than symlinks, note where that old clone lived so it can be retired after Step 8.

### Step 7 — Merge to `main` — needs user confirmation first

Only after Step 6's reboot test passes:

```bash
cd ~/dotfiles
git checkout main && git pull
git merge dotfiles-consolidation
git push
git branch -d dotfiles-consolidation
git push origin --delete dotfiles-consolidation
```

Then on the CM4 device, switch back to `main`:

```bash
cd ~/dotfiles && git checkout main && git pull
```

(No further action needed — content is identical to what was already tested on the branch.)

### Step 8 — Retire `uconsole-dotfiles` — needs user confirmation first

Once Step 7 is done: **ask the user** before archiving `uconsole-dotfiles` on GitHub (Settings → Archive repository). This is a visible, remote action — do not do it unattended. Do not delete the repo.

## Notes for whichever Claude session executes this

- Steps 0, 1, 2, 3, 5 are done (2026-08-23, from the Mac) — verify with `git log --oneline -3 origin/dotfiles-consolidation` in `~/dotfiles` before redoing any of them.
- Steps 6, 7, 8 remain. Step 6 needs to run on the physical uConsole CM4 (or a session with SSH access to it) — it cannot be done from the Mac.
- Steps 7 (merge to `main`) and 8 (archive `uconsole-dotfiles`) both require explicit user confirmation before running — these affect shared/remote state.
- `nixos-config` and the uConsole **CM5**/NixOS host are unaffected by this plan — do not touch them here.
- Leave `hermes/` alone; it is not part of this plan.

---

# Migrationsplan: Dotfiles-Konsolidierung (Deutsch)

**Erstellt:** 2026-08-23 · **Status:** in Arbeit — Schritte 0–3, 5 in `dotfiles` erledigt; Schritte 6–8 brauchen das echte uConsole-CM4-Gerät bzw. deine Bestätigung.

## Ziel

Zielzustand: genau **zwei** Repos, keine dauerhaften Branches pro Rechner.

- `nixos-config` — deklarative Nix-/System-Konfiguration. **Von diesem Plan unberührt** (siehe korrigierter Befund unten).
- `dotfiles` — reine Dateien, manuell verlinkt (bestehendes Muster, siehe `README.md`). Nimmt `uconsole-dotfiles` auf.

`uconsole-dotfiles` wird stillgelegt (archiviert, nicht gelöscht), sobald der Inhalt nachweislich übernommen ist.

**Vorgehen:** über einen kurzlebigen Feature-Branch `dotfiles-consolidation` in `dotfiles` (auf `origin` gepusht) — nicht direkt auf `main`, und nicht in einem neuen Repo. Grund: das Zielgerät (uConsole CM4) muss erst als funktionierend verifiziert werden, inklusive echtem Reboot-Test, bevor `main` den neuen Stand bekommt. Nur der Mac hat Commits erzeugt; das CM4-Gerät holt sich den Branch nur zum Testen, es pusht nie seinen eigenen Stand. Nach erfolgreicher Verifikation wird der Branch in `main` gemergt und gelöscht — kein dauerhafter Parallel-Branch.

## Nicht-Ziele (bewusst ausserhalb dieses Plans)

- Umstrukturierung oder Verschieben von `hermes/` innerhalb von `dotfiles` — unabhängiger Agent-Laufzeit-State, eigenes Thema.
- Umstellung von Ghostty/kitty/iterm2 auf Home Manager — bleibt beim bestehenden manuellen Symlink-Muster aus `README.md`.
- Jegliche Änderung an `GallifreyM1` (Mac), `nixos` (Linux-Desktop) oder dem **uConsole-CM5/NixOS**-Host.

## Ist-Zustand

| Repo | Zuständig für | Status |
|---|---|---|
| `nixos-config` | System-Konfig für `GallifreyM1`, `nixos` und **uConsole CM5** (NixOS: `sway` direkt via `services.greetd`, kein cage/gtkgreet, inline in `hosts/uconsole-cm5/configuration.nix`). | Von diesem Plan nicht angefasst — siehe Befund unten. |
| `dotfiles` | Ghostty/kitty/iterm2/Shell (Mac) + neu `uconsole-cm4/` (Sway, Waybar, greetd, systemd — siehe unten). Zusätzlich ein unabhängiger `hermes/`-Ordner (ausserhalb des Plans). | `uconsole-cm4/` auf Branch `dotfiles-consolidation` gemerged, auf `origin` gepusht. Noch nicht in `main`. |
| `uconsole-dotfiles` | `sway/`, `waybar/`, `greetd/`, `systemd/user/` für die **uConsole CM4** (Debian 13 trixie, apt-verwaltet, greetd+cage+gtkgreet-Login). | Inhalt vollständig nach `dotfiles/uconsole-cm4/` übernommen. Repo selbst noch nicht archiviert (Schritt 8). |

**Kernbefund — die ursprüngliche Prämisse dieses Plans war falsch, korrigiert am 23.08.2026 nach tatsächlichem Lesen des Inhalts:** `uconsole-dotfiles` ist **kein** veraltetes Duplikat des NixOS-Hosts in `nixos-config`. Es gibt **zwei getrennte physische uConsole-Geräte**:

- **CM4** (Raspberry Pi Compute Module 4), Debian 13 trixie, apt-verwaltete Pakete, `greetd` + `cage` + `gtkgreet` als Login-Manager, Mod4 als `$mod`, Display DSI-1 @ Scale 1.5. Das konfiguriert `uconsole-dotfiles`. **Gar nicht Nix-verwaltet.**
- **CM5** (Compute Module 5), NixOS, `sway` direkt via `services.greetd` gestartet (kein cage/gtkgreet), Mod1 als `$mod`, Display DSI-2 @ Scale 2.0. Das ist `hosts/uconsole-cm5/configuration.nix` in `nixos-config`.

Unterschiedliche Hardware, unterschiedliches OS, unterschiedlicher Konfigurationsweg, keine Überschneidung. **`nixos-config` braucht für diese Migration keine Änderungen** — der ursprüngliche Schritt 4 (Wallpaper-Pfad) war eine falsche Fährte durch den Vergleich mit dem falschen Gerät; er war für CM5 ohnehin längst upstream gefixt (`nixos-config`-Commit `6a8735f`) und hatte mit CM4 nie etwas zu tun.

## Zielstruktur

```
nixos-config/                  unverändert — nicht Teil dieser Migration

dotfiles/
  ghostty/…                    unverändert
  kitty/…                      unverändert
  iterm2/…                     unverändert
  shell/…                      unverändert
  hermes/…                     unangetastet, ausserhalb des Plans
  uconsole-cm4/                 NEU — erledigt, auf Branch dotfiles-consolidation
    sway/config
    sway/wallpapers/wallpaper.png
    waybar/config.jsonc
    waybar/style.css
    greetd/config.toml
    greetd/environments
    greetd/greetd-gtkgreet-run
    systemd/user/rpi-connect-wayvnc.service.d/override.conf
  README.md                    neuer Abschnitt "uConsole CM4 (Debian 13 trixie, Sway/Wayland)" — erledigt

uconsole-dotfiles/              auf GitHub archiviert, sobald auf dem Gerät verifiziert — Schritt 8
```

## Schritte

### Schritt 0 — Voraussetzungen — ERLEDIGT

`uconsole-dotfiles` nach `/tmp/uconsole-dotfiles-migrate` geklont, Branch `dotfiles-consolidation` in `dotfiles` angelegt. (Kurz auch einen in `nixos-config` angelegt, wieder gelöscht, nachdem klar war, dass dort nichts zu ändern ist.)

### Schritt 1 — Inhalt vergleichen, bevor irgendwas als veraltet gilt — ERLEDIGT, Annahme widerlegt

Beim Lesen von `uconsole-dotfiles`s tatsächlicher `sway/config` (Kommentar-Header: `### Sway config — ClockworkPI uConsole (CM4) ###`) und `greetd/config.toml` (`cage -s -- /usr/local/bin/greetd-gtkgreet-run`, Benutzer `_greetd`) zeigte sich: das ist CM4/Debian-Config, unabhängig vom CM5/NixOS-Host in `nixos-config`. Siehe "Kernbefund" oben. Nichts musste nach `nixos-config` nachgezogen werden — es war nie ein Duplikat.

### Schritt 2 — Alles nach `dotfiles/uconsole-cm4/` kopieren — ERLEDIGT

```bash
cd ~/dotfiles
mkdir -p uconsole-cm4/sway/wallpapers uconsole-cm4/waybar uconsole-cm4/greetd uconsole-cm4/systemd/user
cp /tmp/uconsole-dotfiles-migrate/sway/config uconsole-cm4/sway/config
cp /tmp/uconsole-dotfiles-migrate/sway/wallpapers/wallpaper.png uconsole-cm4/sway/wallpapers/wallpaper.png
cp /tmp/uconsole-dotfiles-migrate/waybar/config.jsonc uconsole-cm4/waybar/config.jsonc
cp /tmp/uconsole-dotfiles-migrate/waybar/style.css uconsole-cm4/waybar/style.css
cp /tmp/uconsole-dotfiles-migrate/greetd/config.toml uconsole-cm4/greetd/config.toml
cp /tmp/uconsole-dotfiles-migrate/greetd/environments uconsole-cm4/greetd/environments
cp /tmp/uconsole-dotfiles-migrate/greetd/greetd-gtkgreet-run uconsole-cm4/greetd/greetd-gtkgreet-run
cp -r /tmp/uconsole-dotfiles-migrate/systemd/user/rpi-connect-wayvnc.service.d uconsole-cm4/systemd/user/
```

Anders als im ursprünglichen Plan (der nur Waybar/systemd/Wallpaper migrieren wollte) wurde **alles** kopiert — Sway und greetd inklusive — da nichts davon tatsächlich überholt war.

### Schritt 3 — In `dotfiles/README.md` dokumentieren — ERLEDIGT

Neuer Abschnitt `## uConsole CM4 (Debian 13 trixie, Sway/Wayland)` ergänzt, nur auf Deutsch (entspricht der tatsächlichen Konvention dieses READMEs — anders als bei `nixos-config` gibt es hier keine englische Spiegelung). Stellt die CM4-vs-CM5-Unterscheidung explizit klar. Enthält die apt-Installationsliste, die Symlink/Kopier-Setup-Befehle, den `_greetd`-Gruppen-Fix und den greetd/lightdm-Display-Manager-Wechsel — übernommen aus `uconsole-dotfiles`s eigenem README.

### Schritt 4 — ~~entfällt~~

Gestrichen. Basierte auf der falschen Annahme, `nixos-config` bräuchte für diese Migration einen Wallpaper-Pfad-Fix; das war nicht der Fall (siehe Kernbefund).

### Schritt 5 — Committen und Branch pushen — ERLEDIGT

```bash
cd ~/dotfiles
git add uconsole-cm4 README.md
git commit -m "Merge uconsole-dotfiles (CM4) into this repo under uconsole-cm4/"
git push -u origin dotfiles-consolidation
```

Auf `origin/dotfiles-consolidation` bei `github.com/silly82/dotfiles` gepusht. `nixos-config` brauchte keinen Commit — `git status` war leer, der temporäre Branch dort wieder gelöscht.

### Schritt 6 — Auf dem echten uConsole-CM4-Gerät testen — NICHT ERLEDIGT (braucht das physische Gerät)

```bash
# auf der uConsole CM4:
cd ~/dotfiles && git fetch && git checkout dotfiles-consolidation   # bei Bedarf frisch klonen

# vorher alles an diesen Pfaden sichern, das noch kein Symlink in dieses Repo ist
ln -sfn ~/dotfiles/uconsole-cm4/sway ~/.config/sway
ln -sfn ~/dotfiles/uconsole-cm4/waybar ~/.config/waybar
sudo cp ~/dotfiles/uconsole-cm4/greetd/greetd-gtkgreet-run /usr/local/bin/
sudo cp ~/dotfiles/uconsole-cm4/greetd/config.toml /etc/greetd/
sudo cp ~/dotfiles/uconsole-cm4/greetd/environments /etc/greetd/
mkdir -p ~/.config/systemd/user
ln -sfn ~/dotfiles/uconsole-cm4/systemd/user/rpi-connect-wayvnc.service.d ~/.config/systemd/user/rpi-connect-wayvnc.service.d
systemctl --user daemon-reload
systemctl --user restart rpi-connect-wayvnc.service
```

Prüfen: Sway startet wie gewohnt über greetd/cage/gtkgreet, Waybar zeigt Icons, Wallpaper wird angezeigt, `$mod`-Shortcuts (Alt) funktionieren, wayvnc via Raspberry Pi Connect weiterhin erreichbar. **Das Gerät mindestens einmal neu starten** und danach erneut prüfen — genau dafür ist der Test auf dem Branch da. Falls das Gerät bisher direkt von einem `uconsole-dotfiles`-Klon lief statt von Symlinks: notieren, wo dieser alte Klon liegt, damit er nach Schritt 8 stillgelegt werden kann.

### Schritt 7 — Merge nach `main` — braucht vorher deine Bestätigung

Erst nachdem der Reboot-Test aus Schritt 6 bestanden ist:

```bash
cd ~/dotfiles
git checkout main && git pull
git merge dotfiles-consolidation
git push
git branch -d dotfiles-consolidation
git push origin --delete dotfiles-consolidation
```

Danach auf dem CM4-Gerät zurück auf `main` wechseln:

```bash
cd ~/dotfiles && git checkout main && git pull
```

(Nichts weiter nötig — der Inhalt ist identisch zu dem, was bereits auf dem Branch getestet wurde.)

### Schritt 8 — `uconsole-dotfiles` stilllegen — braucht vorher deine Bestätigung

Sobald Schritt 7 abgeschlossen ist: **vor dem Archivieren von `uconsole-dotfiles` auf GitHub den Nutzer fragen** (Settings → Archive repository). Das ist eine sichtbare, remote wirksame Aktion — nicht unbeaufsichtigt ausführen. Das Repo nicht löschen.

## Hinweise für die ausführende Claude-Session

- Schritte 0, 1, 2, 3, 5 sind erledigt (23.08.2026, vom Mac aus) — vor erneuter Ausführung mit `git log --oneline -3 origin/dotfiles-consolidation` in `~/dotfiles` prüfen.
- Schritte 6, 7, 8 stehen noch aus. Schritt 6 muss auf der physischen uConsole CM4 laufen (oder einer Session mit SSH-Zugriff darauf) — vom Mac aus nicht möglich.
- Schritt 7 (Merge nach `main`) und Schritt 8 (Archivieren von `uconsole-dotfiles`) brauchen beide vorherige explizite Nutzerbestätigung — beide betreffen gemeinsamen/remote State.
- `nixos-config` und der uConsole-**CM5**/NixOS-Host sind von diesem Plan nicht betroffen — hier nicht anfassen.
- `hermes/` bleibt unangetastet, ist nicht Teil dieses Plans.
