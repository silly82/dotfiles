---
name: victron-battery-integration
description: "Integrate third-party BMS batteries into Victron VenusOS (Cerbo GX, Raspberry Pi) — BLE bridge via ESP32, MQTT pipeline, DBus driver with velib_python, Node-RED monitoring"
version: 1.0.0
author: Hermes Agent
tags: [victron, venusos, cerbo-gx, bms, battery, ble, esp32, mqtt, dbus, node-red]
---

# Victron Battery Integration (Third-Party BMS → VenusOS)

Get any BLE BMS battery displayed in Victron VenusOS — without a Victron SmartShunt.

## Architecture Pattern

```
BLE BMS → Bridge (ESP32/ESPHome/Python) → MQTT → VenusOS DBus Driver → D-Bus → VenusOS UI
                                                  ↓
                                             Node-RED (Dashboard/Logging)
```

The bridge reads BMS data over BLE and publishes JSON to MQTT. A Python daemon on the Cerbo GX subscribes and publishes to Victron's D-Bus using `velib_python`. Node-RED is optional for monitoring.

## Trigger Conditions

Load this skill when the user wants to:
- Display a non-Victron battery in VenusOS
- Bridge a BLE BMS (JBD, Daly, JK, Seplos, ANT, etc.) to a Cerbo GX
- Write a custom VenusOS battery driver
- Use Node-RED to push sensor data into Victron's D-Bus

## Key Components

### 1. ESP32 BLE→MQTT Bridge

The ESP32 reads the BMS via BLE and publishes JSON to MQTT.

**Required Libraries (PlatformIO):**
```ini
lib_deps =
    h2zero/NimBLE-Arduino@^1.4.2   # BLE
    knolleary/PubSubClient@^2.8    # MQTT
    bblanchon/ArduinoJson@^7.3     # JSON
```

**BLE Protocol Pattern (varies by BMS type):**
- Connect to BLE service
- Register notification on RX characteristic
- Send commands on TX characteristic
- Parse binary response frames
- CRC/checksum validation
- See `references/jbd-ble-protocol.md` for a concrete example (JBD/Jiabaida).

**MQTT JSON Output:**
```json
{
  "voltage": 13.25,
  "current": 5.02,
  "power": 66.5,
  "soc": 78,
  "temperatures": [22.5, 23.1],
  "cell_voltages": [3.312, 3.315, 3.308],
  "charging": true
}
```

### 2. VenusOS DBus Driver (Python)

A Python daemon on the Cerbo GX subscribes to MQTT and publishes to Victron's D-Bus.

**Requirements:**
- `velib_python` (pre-installed at `/opt/victronenergy/dbus-systemcalc-py/ext/velib_python/`)
- `paho-mqtt` for MQTT subscribe
- Runs as a `systemd` service

**Key D-Bus Paths (battery device):**

| DBus Path | Type | Description |
|-----------|------|-------------|
| `/Dc/0/Voltage` | Double | Battery voltage (V) |
| `/Dc/0/Current` | Double | Current (A, positive=charging) |
| `/Dc/0/Power` | Double | Power (W) |
| `/Dc/0/Temperature` | Double | Temperature (°C) |
| `/Soc` | Double | State of Charge (0-100%) |
| `/Capacity` | Double | Nominal capacity (Ah) |
| `/ConsumedAmphours` | Double | Consumed Ah |
| `/History/DischargeCycles` | Int32 | Cycle count |
| `/Info/MaxChargeCurrent` | Double | Max charge current (A) |
| `/Info/MaxDischargeCurrent` | Double | Max discharge current (A) |
| `/Connected` | Int32 | 1=online, 0=offline |
| `/ProductId` | Int32 | 0xB000 (generic battery) |

**velib_python usage pattern:**
```python
sys.path.insert(1, "/opt/victronenergy/dbus-systemcalc-py/ext/velib_python")
from vedbus import VeBusService, VeBusItem

service = VeBusService("com.victronenergy.battery.jbd", dbus_name="com.victronenergy.battery", device_instance=256)
VeBusItem(service, "/Dc/0/Voltage", initial=0.0)
VeBusItem(service, "/Connected", initial=1)
# ... then set values in the main loop:
item = getattr(service, path, None)
if item: item.set_value(value)
```

**Service file pattern:**
```ini
[Unit]
Description=Victron DBus Battery Bridge
After=dbus.service dbus.socket
Wants=dbus.service

[Service]
Type=simple
User=root
WorkingDirectory=/data/dbus-mqtt-battery
ExecStart=/usr/bin/python3 /data/dbus-mqtt-battery/driver.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

**Installation on Cerbo GX:**
```bash
scp driver.py root@<cerbo-ip>:/data/dbus-mqtt-battery/
scp driver.service root@<cerbo-ip>:/data/etc/systemd/system/
systemctl daemon-reload && systemctl enable driver && systemctl start driver
```

### 3. Node-RED Flow (Optional)

For debugging, dashboard, InfluxDB logging. Import `flows.json` into Node-RED.

**Flow structure:**
- MQTT input node → JSON parse → function mapping → dashboard outputs
- Status node per data source (green/yellow/red)
- Optional InfluxDB output for historical data

## Pitfalls

- **Cerbo GX has no BLE.** Must use an external BLE bridge (ESP32, ESPHome proxy, or a device with BLE like uConsole).
- **BMS BLE protocol is vendor-specific.** Service UUIDs, command formats, CRC algorithms differ between Daly, JBD, JK, Seplos, ANT. Read the aiobmsble library source for each type.
- **Single MQTT connection.** BMS allows only one BLE connection at a time — disconnect the phone app before testing.
- **RSSI matters.** BLE range is limited. ESP32 should be within 5-10m of the BMS. Below -80 dBm causes frequent disconnects.
- **D-Bus instance conflicts.** If `DBUS_INSTANCE` overlaps with an existing device, VenusOS won't show the battery. Start with 256+.
- **Watchdog needed.** If MQTT data stops, the DBus driver should set `/Connected=0` after a timeout (~60s), otherwise VenusOS shows stale values.
- **velib_python import paths.** On newer VenusOS versions the path may differ. Check `/opt/victronenergy/` for the actual location.

## Verification

After installation:
```bash
# Check MQTT data flow
mosquitto_sub -h localhost -t bms/jbd/data

# Check DBus service is registered
dbus-send --system --dest=org.freedesktop.DBus --type=method_call \
  --print-reply /org/freedesktop/DBus org.freedesktop.DBus.ListNames | grep victronenergy.battery

# Check systemd service
systemctl status dbus-mqtt-battery

# Monitor log
journalctl -u dbus-mqtt-battery -f
```

## References

- [aiobmsble](https://github.com/patman15/aiobmsble) — Python BLE library for 40+ BMS types (protocol reference)
- [BMS_BLE-HA](https://github.com/patman15/BMS_BLE-HA) — Home Assistant counterpart
- [dbus-serialbattery](https://github.com/mr-manuel/venus-os_dbus-serialbattery) — Serial battery driver for VenusOS (reference architecture)
- [velib_python](https://github.com/victronenergy/velib_python) — Victron D-Bus bindings
- [VenusOS DBus API](https://github.com/victronenergy/venus/wiki/dbus) — Official documentation
- Full working example: [github.com/silly82/jbd-ble-victron-bridge](https://github.com/silly82/jbd-ble-victron-bridge)