---
name: victron-venusos-bms-bridge
description: "Bridge any BLE Battery Management System (BMS) to Victron VenusOS (Cerbo GX / GX devices) using an ESP32 as BLE→MQTT gateway and a Python daemon for D-Bus integration. Covers JBD, Daly, JK, Seplos, and similar BMS types."
version: 1.0.0
author: Agent-created
license: MIT
platforms: [linux]
metadata:
  tags: [victron, venusos, cerbo, bms, battery, ble, mqtt, dbus, esp32, jbd]
---

# Victron VenusOS BMS Bridge (BLE → ESP32 → MQTT → D-Bus)

Bridge any Bluetooth LE Battery Management System to Victron VenusOS,
so the battery appears as a native device in the Cerbo GX / GX device UI
without requiring a Victron SmartShunt or serial cable.

## Architecture

```
BLE BMS (Akku)      ESP32 (BLE→MQTT)        Cerbo GX / VenusOS
┌──────────────┐   ┌──────────────────┐   ┌──────────────────────────┐
│ JBD / Daly   │◄─►│ esp32_ble_mqtt   │──►│ dbus_mqtt_battery.py    │
│ JK / Seplos  │BLE│ .ino             │MQT│ (Python systemd daemon) │
│ ANT / Renogy │   │ NimBLE + PubSub  │   │   ↓                      │
└──────────────┘   └──────────────────┘   │ Victron D-Bus            │
                                          │   ↓                      │
                                          │ VenusOS UI / VRM Portal  │
                                          └──────────────────────────┘
```

Alternative (wenn kein ESP32 verfügbar): Python auf einem Linux-Host mit
BLE-Adapter + `aiobmsble` → MQTT (siehe references/aiobmsble-usage.md).

## When to load this skill

- User wants to display a third-party BMS battery in VenusOS
- User has a BLE-enabled BMS (JBD, Daly, JK, Seplos, ANT, etc.)
- User asks about integrating a battery without Victron hardware
- User has an ESP32 available as BLE-MQTT gateway

## Components

### 1. ESP32 Firmware (`esp32_ble_mqtt.ino`)

Connects to BMS via BLE, polls sensor data, publishes JSON via MQTT.

**Required libraries (PlatformIO):**
- `NimBLE-Arduino` (preferred) or `ESP32 BLE Arduino`
- `PubSubClient`
- `ArduinoJson`

**Key configuration (set before flashing):**
```cpp
const char* WIFI_SSID  = "DEIN_WLAN";
const char* WIFI_PASS  = "DEIN_WLAN_PASS";
const char* MQTT_HOST  = "192.168.1.100";  // Cerbo GX or MQTT broker IP
```

**BLE connection flow:**
1. Scan for BMS by name pattern (JBD-*, DL-*, etc.) or OUI
2. Connect to BLE service (usually 0xFF00 or vendor-specific)
3. Register notification callback on RX characteristic
4. Send init sequence if required by BMS
5. Poll data commands in sequence with short delays between
6. Publish JSON to MQTT topic (e.g. `bms/jbd/data`)

### 2. VenusOS DBus Daemon (`dbus_mqtt_battery.py`)

Python systemd service on Cerbo GX that subscribes to MQTT and
writes data to Victron's D-Bus using `velib_python`.

**Install path:** `/data/dbus-mqtt-battery/`
**Service file:** `/data/etc/systemd/system/dbus-mqtt-battery.service`

**Key D-Bus paths written:**
| Path | Description |
|------|-------------|
| `/Dc/0/Voltage` | Battery voltage (V) |
| `/Dc/0/Current` | Current (A, positive = charging) |
| `/Dc/0/Power` | Power (W) |
| `/Dc/0/Temperature` | Temperature (°C) |
| `/Soc` | State of Charge (%) |
| `/Capacity` | Capacity (Ah) |
| `/ConsumedAmphours` | Consumed Ah |
| `/Connected` | 1 = online, 0 = offline |
| `/Info/MaxChargeCurrent` | Max charge current (A) |
| `/Info/MaxDischargeCurrent` | Max discharge current (A) |

**Watchdog:** If no MQTT data arrives within POLL_TIMEOUT (default 60s),
sets `/Connected` to 0 so VenusOS marks the battery offline.

### 3. Node-RED Flow (optional)

For dashboarding, debugging, or InfluxDB logging. Subscribe to the
same MQTT topic, parse JSON, and create dashboard widgets.

## Workflow

1. **Identify BMS type** — determine BLE service UUIDs and
   communication protocol. Check the BMS's Bluetooth name pattern
   and vendor documentation.

2. **Flash ESP32** with BLE→MQTT firmware tailored to your BMS.
   - Configure WiFi credentials
   - Set MQTT broker IP (Cerbo GX or dedicated broker)
   - Test BLE connection and data parsing

3. **Install DBus daemon on Cerbo GX** via SSH:
   ```bash
   scp cerbo/* root@<cerbo-ip>:/data/dbus-mqtt-battery/
   ssh root@<cerbo-ip>
   chmod +x /data/dbus-mqtt-battery/install.sh
   /data/dbus-mqtt-battery/install.sh
   ```

4. **Verify VenusOS shows the battery** — check Remote Console → Device List.

## Pitfalls

- **BMS not connectable:** The BMS may have a paired app connected.
  Disconnect the phone app first. Some BMSs (JBD) handle only one BLE
  connection at a time.
- **BLE init sequence required:** Some BMSs (JBD, Daly) require a
  handshake/init command before data requests. Without it, they ignore
  commands.
- **CRC/sanity checks:** Most BMS frames include a CRC or checksum.
  Parse/validate them — don't trust raw bytes.
- **Polling interval:** 30s is standard. Shorter intervals may overload
  the BMS or cause disconnects. Longer intervals work but data updates
  are slower.
- **D-Bus service name collision:** Use a unique instance ID (default 256)
  to avoid conflicting with real Victron devices. If 256 is taken, try 257+.
- **velib_python installed:** The Cerbo GX has it at
  `/opt/victronenergy/dbus-systemcalc-py/ext/velib_python/`. The daemon
  must add this to `sys.path`.
- **BMS goes to sleep:** Some BMSs (Elektronicz, Lithtech) turn off BLE
  when current is zero. Data will show as unavailable during idle periods.
- **ESP32 BLE stack:** Standard `BLEDevice` has a 223-byte MTU limit.
  `NimBLE` handles larger frames better and is more reliable.

## Verification

1. Check MQTT: `mosquitto_sub -h <broker> -t "bms/<type>/data"`
2. Check daemon logs: `journalctl -u dbus-mqtt-battery -f`
3. Check D-Bus: `dbus-spy` or `grep -r "com.victronenergy.battery" /var/log/`
4. Check VenusOS: Remote Console → Geräte → Batterie sollte auftauchen

## BMS Protocol Quick Reference

Common BLE service UUIDs for supported BMS types:
- **JBD:** 0xFF00 (chars ff01 RX, ff02 TX)
- **Daly:** 0xFFE0 (chars FFE1)
- **JK:** vendor-specific UUIDs
- **Seplos:** 0xFFE0

See `references/jbd-protocol.md` for detailed JBD frame structure.

## Related

- `clockworkpi-uconsole` — if running the MQTT/ESP32 toolchain on uConsole
- aiobmsble: https://github.com/patman15/aiobmsble
- dbus-serialbattery: https://github.com/mr-manuel/venus-os_dbus-serialbattery
- Victron DBus API: https://github.com/victronenergy/venus/wiki/dbus
