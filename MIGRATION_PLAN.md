# Migration Plan: Dotfiles Consolidation

**Created:** 2026-08-23 · **Status:** in progress — Steps 0–3, 5 done on `dotfiles`; Step 6 is N/A (CM4 hardware retired, see below); Steps 7–8 need user confirmation.

## Goal

End state: exactly **two** repos, no permanent branches-per-machine.

- `nixos-config` — declarative Nix/system config. **Untouched by this plan** (see revised finding below).
- `dotfiles` — plain files, manually symlinked in (existing pattern, see `README.md`). Absorbs `uconsole-dotfiles`.

`uconsole-dotfiles` is retired (archived, not deleted) once its content is verified merged.

**Workflow:** done on a short-lived feature branch `dotfiles-consolidation` in `dotfiles` (pushed to `origin`), not directly on `main` and not in a new repo. Originally gated on verifying the change on the actual CM4 device before touching `main` — moot now that the CM4 module has been physically replaced by CM5 (see Step 6). The branch still gets merged to `main` and deleted once you confirm — it was just never meant to be a permanent parallel branch.

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

### Step 6 — ~~Test on the actual uConsole CM4 device~~ — N/A, hardware retired

**Confirmed 2026-08-23 (user):** there is no CM4 card to swap back to — the uConsole's compute module was physically upgraded to CM5, and only the NixOS/CM5 card exists now. The CM4/Debian setup this branch's `uconsole-cm4/` content describes no longer runs anywhere; nothing is left to boot-test. `uconsole-cm4/` in `dotfiles` is now a **historical/archival record** of that retired setup (useful if the module is ever downgraded again, or just for reference), not a live deployment target.

This removes the original reason for gating `main` behind a device test (a bad edit breaking boot on a device that no longer exists in that configuration). Steps 7–8 can proceed without a device-verification gate — but still only with your go-ahead, since both still touch shared/remote state (`main`, and archiving a public repo).

### Step 7 — Merge to `main` — needs user confirmation first

No device test to wait for anymore (see Step 6) — this can happen as soon as you say go:

```bash
cd ~/dotfiles
git checkout main && git pull
git merge dotfiles-consolidation
git push
git branch -d dotfiles-consolidation
git push origin --delete dotfiles-consolidation
```

No device to switch back to `main` on — the CM4 hardware no longer exists (see Step 6). This is purely a repo-side merge.

### Step 8 — Retire `uconsole-dotfiles` — needs user confirmation first

Once Step 7 is done: **ask the user** before archiving `uconsole-dotfiles` on GitHub (Settings → Archive repository). This is a visible, remote action — do not do it unattended. Do not delete the repo.

## Notes for whichever Claude session executes this

- Steps 0, 1, 2, 3, 5 are done (2026-08-23, from the Mac) — verify with `git log --oneline -3 origin/dotfiles-consolidation` in `~/dotfiles` before redoing any of them.
- Step 6 is N/A — the CM4 module was physically replaced by CM5, confirmed by the user 2026-08-23. Don't try to find or SSH into a CM4 device; it no longer exists. `192.168.7.194` / hostname `uconsole-cm5` is the same physical shell, now NixOS-only.
- Steps 7 (merge to `main`) and 8 (archive `uconsole-dotfiles`) remain, both require explicit user confirmation before running — these affect shared/remote state.
- `nixos-config` and the uConsole **CM5**/NixOS host are unaffected by this plan — do not touch them here.
- Leave `hermes/` alone; it is not part of this plan.

---

# Migrationsplan: Dotfiles-Konsolidierung (Deutsch)

**Erstellt:** 2026-08-23 · **Status:** in Arbeit — Schritte 0–3, 5 in `dotfiles` erledigt; Schritt 6 entfällt (CM4-Hardware stillgelegt, siehe unten); Schritte 7–8 brauchen deine Bestätigung.

## Ziel

Zielzustand: genau **zwei** Repos, keine dauerhaften Branches pro Rechner.

- `nixos-config` — deklarative Nix-/System-Konfiguration. **Von diesem Plan unberührt** (siehe korrigierter Befund unten).
- `dotfiles` — reine Dateien, manuell verlinkt (bestehendes Muster, siehe `README.md`). Nimmt `uconsole-dotfiles` auf.

`uconsole-dotfiles` wird stillgelegt (archiviert, nicht gelöscht), sobald der Inhalt nachweislich übernommen ist.

**Vorgehen:** über einen kurzlebigen Feature-Branch `dotfiles-consolidation` in `dotfiles` (auf `origin` gepusht) — nicht direkt auf `main`, und nicht in einem neuen Repo. Ursprünglich daran geknüpft, die Änderung erst auf dem echten CM4-Gerät zu verifizieren, bevor `main` angefasst wird — hinfällig, seit das CM4-Modul physisch durch CM5 ersetzt wurde (siehe Schritt 6). Der Branch wird trotzdem nach deiner Freigabe in `main` gemergt und gelöscht — er war nie als dauerhafter Parallel-Branch gedacht.

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

### Schritt 6 — ~~Auf dem echten uConsole-CM4-Gerät testen~~ — entfällt, Hardware stillgelegt

**Bestätigt am 23.08.2026 (Nutzer):** es gibt keine CM4-Karte mehr zum Zurückwechseln — das Compute-Modul der uConsole wurde physisch auf CM5 aufgerüstet, es existiert nur noch die NixOS/CM5-Karte. Das CM4/Debian-Setup, das der Inhalt von `uconsole-cm4/` in diesem Branch beschreibt, läuft nirgends mehr; es gibt nichts mehr zum Boot-Testen. `uconsole-cm4/` in `dotfiles` ist jetzt ein **historisches Archiv** dieses stillgelegten Setups (nützlich, falls das Modul je wieder zurückgerüstet wird, oder einfach als Referenz), kein aktives Deployment-Ziel mehr.

Damit entfällt der ursprüngliche Grund, `main` hinter einem Geräte-Test zurückzuhalten (eine falsche Änderung könnte sonst den Boot eines Geräts zerlegen, das es in dieser Konfiguration gar nicht mehr gibt). Schritte 7–8 können ohne Geräte-Verifikations-Gate weitergehen — aber weiterhin nur mit deiner Freigabe, da beide gemeinsamen/remote State betreffen (`main`, und das Archivieren eines öffentlichen Repos).

### Schritt 7 — Merge nach `main` — braucht vorher deine Bestätigung

Kein Geräte-Test mehr abzuwarten (siehe Schritt 6) — das kann passieren, sobald du grünes Licht gibst:

```bash
cd ~/dotfiles
git checkout main && git pull
git merge dotfiles-consolidation
git push
git branch -d dotfiles-consolidation
git push origin --delete dotfiles-consolidation
```

Kein Gerät mehr, das auf `main` zurückwechseln müsste — die CM4-Hardware existiert nicht mehr (siehe Schritt 6). Das ist ein reiner Repo-seitiger Merge.

### Schritt 8 — `uconsole-dotfiles` stilllegen — braucht vorher deine Bestätigung

Sobald Schritt 7 abgeschlossen ist: **vor dem Archivieren von `uconsole-dotfiles` auf GitHub den Nutzer fragen** (Settings → Archive repository). Das ist eine sichtbare, remote wirksame Aktion — nicht unbeaufsichtigt ausführen. Das Repo nicht löschen.

## Hinweise für die ausführende Claude-Session

- Schritte 0, 1, 2, 3, 5 sind erledigt (23.08.2026, vom Mac aus) — vor erneuter Ausführung mit `git log --oneline -3 origin/dotfiles-consolidation` in `~/dotfiles` prüfen.
- Schritt 6 entfällt — das CM4-Modul wurde physisch durch CM5 ersetzt, bestätigt vom Nutzer am 23.08.2026. Nicht versuchen, ein CM4-Gerät zu finden oder sich per SSH draufzuverbinden — existiert nicht mehr. `192.168.7.194` / Hostname `uconsole-cm5` ist dieselbe physische Hülle, jetzt nur noch NixOS.
- Schritte 7 (Merge nach `main`) und 8 (Archivieren von `uconsole-dotfiles`) stehen noch aus, beide brauchen vorherige explizite Nutzerbestätigung — beide betreffen gemeinsamen/remote State.
- `nixos-config` und der uConsole-**CM5**/NixOS-Host sind von diesem Plan nicht betroffen — hier nicht anfassen.
- `hermes/` bleibt unangetastet, ist nicht Teil dieses Plans.
