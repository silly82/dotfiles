# VenusOS DBus Battery Driver Pattern

Basierend auf `dbus-serialbattery` (Louisvdw / mr-manuel) und `velib_python`.

## Python-Daemon Struktur

```
/data/dbus-mqtt-battery/
├── dbus_mqtt_battery.py       ← Hauptscript
├── dbus_mqtt_battery.service  ← systemd Unit
├── install.sh                 ← Erstinstallation
└── dbus_mqtt_battery.log      ← Log (auto-rotated)
```

## MQTT→DBus Daten-Mapping

| MQTT JSON Key | DBus Path | Typ | Einheit |
|--------------|-----------|-----|---------|
| `voltage` | `/Dc/0/Voltage` | float | V |
| `current` | `/Dc/0/Current` | float | A (positiv = laden) |
| `power` | `/Dc/0/Power` | float | W |
| `temperatures[0]` | `/Dc/0/Temperature` | float | °C |
| `soc` | `/Soc` | float | % |
| `capacity` | `/Capacity` | float | Ah |
| (calculated) | `/ConsumedAmphours` | float | Ah = capacity × (100-soc)/100 |
| `cycles` | `/History/DischargeCycles` | int | # |
| — | `/Info/MaxChargeCurrent` | float | A (capacity × 0.5) |
| — | `/Info/MaxDischargeCurrent` | float | A (capacity × 0.5) |
| — | `/Connected` | int | 1 = online, 0 = offline |

## velib_python Grundgerüst

```python
import sys
sys.path.insert(1, "/opt/victronenergy/dbus-systemcalc-py/ext/velib_python")

from vedbus import VeBusService, VeBusItem

# Service registrieren
service = VeBusService(
    "com.victronenergy.battery.http_256",
    dbus_name="com.victronenergy.battery",
    device_instance=256
)

# Paths definieren
VeBusItem(service, "/Dc/0/Voltage", initial=0.0)
VeBusItem(service, "/Soc", initial=0.0)
# ...

# Werte setzen
item = getattr(service, "/Dc/0/Voltage", None)
if item is not None:
    item.set_value(13.25)
```

## Wichtige Pfade (Victron D-Bus Battery API)

```
/Dc/0/Voltage        — Spannung (V)
/Dc/0/Current        — Strom (A)
/Dc/0/Power          — Leistung (W)
/Dc/0/Temperature    — Temperatur (°C)
/Dc/0/MidVoltage     — Mittelpunktspannung (optional)
/Soc                 — State of Charge (%)
/Capacity            — Kapazität (Ah)
/ConsumedAmphours    — Verbrauchte Ah
/ProductId           — 0xB000 = generic battery
/DeviceType          — 0 = generic
/Connected           — 0/1
/AutoSelected        — 0/1
/Info/MaxChargeCurrent      — Max Ladestrom (A)
/Info/MaxDischargeCurrent   — Max Entladestrom (A)
/Info/ChargeRequest         — 1
/Info/BatteryLowVoltage     — Unterspannungsschwelle (V)
/History/DischargeCycles    — Zyklen
/History/TotalDischarge     — Gesamtentladung (Ah)
/Mgmt/ProductName           — Anzeigename
/Mgmt/Connection            — Verbindungstyp
/Mgmt/DeviceInstance        — Instanz-ID
/Mgmt/FirmwareVersion       — FW-Version
/Mgmt/SerialNumber          — Seriennummer
```

## Fehlerbehandlung

- **D-Bus Service nicht startbar:** `velib_python` Pfad prüfen
  (`/opt/victronenergy/dbus-systemcalc-py/ext/velib_python/`)
- **Battery taucht nicht in VenusOS auf:** Instance-ID prüfen (nicht von
  anderem Gerät belegt). In VenusOS → Geräte → Neu laden.
- **Watchdog schlägt an:** MQTT-Datenfluss prüfen mit `mosquitto_sub`
- **Service crasht:** Log lesen: `journalctl -u dbus-mqtt-battery -f`