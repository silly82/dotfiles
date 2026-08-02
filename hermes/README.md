# Hermes Backup

Dieses Verzeichnis enthält Skripte zum Sichern und Wiederherstellen von Hermes-Daten (Skills, Memories, Cron, Plugins, Config) im Dotfiles-Repository.

## Skripte

- `backup.sh`: Synchronisiert Hermes-Daten von `~/.hermes/` in dieses Verzeichnis, committed und pushed Änderungen.
- `restore.sh`: Stellt die gesicherten Daten zurück in `~/.hermes/`.

## Verwendung

### Backup manuell ausführen
```bash
cd /Users/silvanwalker/dotfiles
./hermes/backup.sh
```

### Wiederherstellung
```bash
cd /Users/silvanwalker/dotfiles
./hermes/restore.sh
```

**Achtung:** Das Restore-Skript überschreibt lokale Hermes-Daten mit der Backup-Version. Nur ausführen, wenn Sie die lokalen Änderungen verlieren möchten.

## Automatisches tägliches Backup einrichten

### Option 1: System-Cronjob (empfohlen)
Fügen Sie folgende Zeile Ihrer crontab hinzu (`crontab -e`):

```
0 3 * * * /Users/silvanwalker/dotfiles/hermes/backup.sh >> /Users/silvanwalker/dotfiles/hermes/backup.log 2>&1
```

Dadurch wird das Backup täglich um 3 Uhr morgens ausgeführt und Logs in `backup.log` geschrieben.

### Option 2: Hermes‑interner Cronjob (experimentell)
Sie können einen Hermes‑Cronjob erstellen, der das Skript ausführt. Dazu den Befehl `hermes cron create` verwenden (siehe Hermes‑Dokumentation).

## Was wird gesichert?
- `skills/` (alle Skills)
- `memories/` (persistente Erinnerungen)
- `cron/` (geplante Jobs)
- `plugins/` (Plugins)
- `config.yaml` (Konfiguration)

Sensible Daten wie `auth.json` oder Caches werden ausgeschlossen.

## Wiederherstellung auf einem neuen System
1. Dotfiles‑Repository klonen.
2. `hermes/restore.sh` ausführen.
3. Hermes neu starten, damit die Änderungen wirksam werden.

## Hinweise
- Stellen Sie sicher, dass der SSH‑Key für GitHub im Dotfiles‑Repository funktioniert, damit `git push` automatisch klappt.
- Bei Problemen prüfen Sie die Ausgabe des Skripts oder die Log‑Datei.