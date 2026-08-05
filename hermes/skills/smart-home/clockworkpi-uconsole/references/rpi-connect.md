# Raspberry Pi Connect — Remote Access für die uConsole

Raspberry Pi Connect (rpi-connect) ermöglicht Remote-Zugriff auf die uConsole
via VNC (Screen-Sharing) und Remote Shell über connect.raspberrypi.com – ohne
Port-Forwarding oder DynDNS. Läuft als systemd User-Service und startet
automatisch beim Login.

## Installation & Einrichtung

```bash
# Prüfen ob installiert
dpkg -l | grep rpi-connect

# Falls nicht: Installieren
sudo apt-get install -y rpi-connect
```

Der Dienst ist ein **User-Service** (`systemctl --user`) – er startet und läuft
im Kontext des eingeloggten Benutzers (silly82), zusammen mit der Sway-Session.

## Sign-In

```bash
rpi-connect signin
```

Öffnet einen Browser-Link für OAuth-Login mit dem Raspberry Pi Account
(connect.raspberrypi.com). Nach erfolgreichem Login erscheint die uConsole
im Web-Dashboard und ist von überall erreichbar.

## Status prüfen

```bash
# Dienst-Status
systemctl --user status rpi-connect

# Sign-In Status
rpi-connect status
```

Beim ersten erfolgreichen Login startet automatisch eine Proxy-Session:
```
rpi-connect[6946]: INFO [<uuid>] [vnc]: Proxy session started
```

## Wichtige Befehle

| Befehl | Funktion |
|---|---|
| `rpi-connect on` | Service starten + autostart aktivieren |
| `rpi-connect off` | Service stoppen + autostart deaktivieren |
| `rpi-connect signin` | Mit Raspberry Pi Account verbinden |
| `rpi-connect signout` | Verbindung trennen |
| `rpi-connect status` | Status anzeigen |
| `rpi-connect doctor` | System auf Probleme prüfen |
| `rpi-connect vnc on/off` | Screen-Sharing erlauben/verbieten |
| `rpi-connect shell on/off` | Remote-Shell Zugriff erlauben/verbieten |

## Autostart

Der Dienst ist als User-Service angelegt und startet automatisch mit
der Benutzersession (Sway/Greetd):

```
● rpi-connect.service - Raspberry Pi Connect
     Loaded: loaded (/usr/lib/systemd/user/rpi-connect.service; enabled; preset: enabled)
```

Keine extra Konfiguration nötig – nach dem Sign-In und einem Neustart der
Session läuft es im Hintergrund.

## Bekanntes Problem: Maus-Koordinaten bei Sway transform 90

**Problem:** Wenn Sway `transform 90` für den DSI-1 Panel verwendet, werden
VNC-Mauskoordinaten von wayvnc nicht korrekt zurückgerechnet. Die Maus
bewegt sich in die falsche Richtung (z.B. nach oben statt nach links).

**Ursache:** wayvnc 0.9.1 kanalisiert Maus-Input über den Standard-Seat, wo
Sway die Koordinaten bereits transformiert hat – eine doppelte Transformation.

**Fix:** systemd-Override für `rpi-connect-wayvnc.service` mit zwei Flags:

```ini
# ~/.config/systemd/user/rpi-connect-wayvnc.service.d/override.conf
[Service]
# DSI-1 als Output fixieren, transient-seat für korrektes Eingabe-Mapping
ExecStart=
ExecStart=/usr/bin/rpi-connect-env /usr/bin/wayvnc \
  --config /etc/rpi-connect/wayvnc.config \
  --render-cursor --unix-socket \
  --transient-seat -o DSI-1 \
  --socket=%t/rpi-connect-wayvnc-ctl.sock %t/rpi-connect-wayvnc.sock
```

- `--transient-seat` erzeugt einen separaten virtuellen Seat für VNC, sodass
  Sway die Mauskoordinaten nicht doppelt transformiert.
- `-o DSI-1` erfasst explizit den rotierten Output (statt der default-Auswahl).

Anwenden:
```bash
mkdir -p ~/.config/systemd/user/rpi-connect-wayvnc.service.d/
# Datei wie oben erstellen, dann:
systemctl --user daemon-reload
systemctl --user restart rpi-connect-wayvnc.service
```

Nach dem Neustart verbinden und testen. Der fixierte Dienst-Start sieht dann so aus:
```
/usr/bin/wayvnc --config /etc/rpi-connect/wayvnc.config --render-cursor
  --unix-socket --transient-seat -o DSI-1 --socket=.../rpi-connect-wayvnc-ctl.sock
  .../rpi-connect-wayvnc.sock
```

## Remote-Zugriff

Nach erfolgreichem Login: [https://connect.raspberrypi.com](https://connect.raspberrypi.com)
– dort die uConsole auswählen und per VNC (Screen) oder Shell verbinden.

## Hinweise

- Funktioniert nur wenn der Benutzer eingeloggt ist (Sway-Session aktiv).
  Die uConsole darf nicht im Greeter/Login-Screen hängen.
- Verbraucht etwas Hintergrund-CPU/Netz – bei Bedarf mit `rpi-connect off`
  deaktivieren (z.B. unterwegs mit 4G-Modem um Daten zu sparen).
- wayvnc wird via rpi-connect-wayvnc.service gestartet (nicht standalone).
  Eigenständige wayvnc-Config (`~/.config/wayvnc/config`) wird ignoriert,
  weil rpi-connect das Flag `--config /etc/rpi-connect/wayvnc.config` setzt
  (leere Datei im Default).