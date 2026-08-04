---
name: teltonika-rutos
description: "Use when managing Teltonika RUTX/RUT series routers running RutOS via SSH/CLI. GPS status, ubus commands, filesystem layout, package management, and MQTT integration."
version: 1.0.0
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags: [teltonika, rutos, industrial-router, gps, mqtt, openwrt]
    related_skills: []
---

# Teltonika RutOS CLI Management

## Overview

Teltonika RutOS is an OpenWrt-based firmware for Teltonika industrial routers (RUTX11, RUT955, RUT240, etc.). Key differences from standard OpenWrt: the squashfs rootfs makes `/usr/bin/` read-only, ubus object names differ from published docs, and the default package feed only includes Teltonika-supported packages.

This skill covers CLI-based GPS status queries, MQTT integration, filesystem quirks, and common pitfalls when working on these devices.

## When to Use

- User asks about Teltonika router CLI commands (GPS, MQTT, services)
- User is SSH'd into a Teltonika RUTX/RUT/RUTM-series router
- User asks to publish GPS data to MQTT or forward NMEA data
- User hits read-only filesystem errors on a Teltonika router

## Ubus GPS Commands

Unlike older Teltonika documentation and community posts that reference `ubus call gps status`, RutOS firmware *RUTX_R_00.07.24+* uses the **`gpsd`** ubus object.

### Available `gpsd` methods

```
ubus -v list gpsd
'gpsd' @...
    "status":{}           → Daemon uptime
    "position":{}         → GPS fix: lat, lon, altitude, speed, bearing, hdop, satellites
    "nmea":{}             → Raw NMEA sentences
    "nmea_status":{}      → NMEA forwarding status
    "https_status":{}     → HTTPS server status
    "modman":{"wwan":"Boolean"}  → Modem manager control
```

### Common queries

```bash
# GPS fix data (position, satellites, speed, etc.)
ubus call gpsd position

# Daemon uptime
ubus call gpsd status

# Raw NMEA sentences
ubus call gpsd nmea

# Satellite view
ubus call gpsd position | jsonfilter -e '@.satellites'
```

### Example output

```json
{
    "latitude": 54.6871,
    "longitude": 25.2797,
    "altitude": 123.4,
    "speed": 0.5,
    "bearing": 180.0,
    "hdop": 1.2,
    "satellites": 12
}
```

- **`satellites`** → number of satellites in view
- **`hdop`** → horizontal dilution of precision (< 2 = good fix)
- Empty/`{}` means no fix yet (antenna needs clear sky)

## Filesystem Layout

Critical difference from standard OpenWrt or Linux:

| Path | Type | Writable? | Notes |
|------|------|-----------|-------|
| `/usr/bin/` | squashfs (part of `/dev/root`) | **NO** | System binaries, read-only |
| `/usr/sbin/` | squashfs | **NO** | System binaries |
| `/usr/local/bin/` | overlayfs (`/dev/ubi0_2`) | **YES** | Custom scripts go here |
| `/etc/` | overlayfs | **YES** | Config files |
| `/root/` | overlayfs (via /root -> /tmp/.root) | **YES** | Root home |
| `/tmp/` | tmpfs | **YES** | Volatile (lost on reboot) |
| `/data/` | may not exist | — | Not present on all models |

**Key rule:** Custom scripts belong in `/usr/local/bin/`. Do NOT try to write to `/usr/bin/` or `/sbin/` — you will get "Read-only file system" errors.

## MQTT Integration

### Built-in MQTT broker

The RUTX11 ships with `mosquitto-ssl` (Mosquitto 2.x) pre-installed and running on port 1883 (localhost only by default).

```bash
# Check if running
netstat -tlnp | grep 1883
ps | grep mosquitto
```

### Missing client tools

**Critical pitfall:** The default Teltonika opkg feed provides `mosquitto-ssl` (the broker) but **no** `mosquitto_pub` / `mosquitto_sub` client utilities. Running `mosquitto_pub` will fail with "not found".

### Solutions to get MQTT publishing

**Option A — OpenWrt feeds (unsupported but works):**

```bash
opkg install mosquitto-client-nossl \
  --force_feeds /etc/opkg/openwrt/distfeeds.conf
```

This installs `mosquitto_pub` and `mosquitto_sub` but is officially unsupported by Teltonika.

**Option B — Direct TCP socket (no client tools needed):**

```bash
# Publish via raw TCP to the MQTT broker
exec 3<>/dev/tcp/127.0.0.1/1883
# Connect packet + publish packet via echo/printf
# (Advanced — only if option A is impossible)
```

**Option C — Python (if installed):**

```bash
which python3 || which python
# Then use paho-mqtt or socket-based publish
```

### Cron-based GPS-to-MQTT publishing

Script location: `/usr/local/bin/gps2mqtt.sh`

```bash
#!/bin/sh
GPS_JSON=$(ubus call gpsd position 2>/dev/null)
if [ -n "$GPS_JSON" ] && [ "$GPS_JSON" != "{}" ]; then
    LAT=$(echo "$GPS_JSON" | jsonfilter -e '@.latitude')
    LON=$(echo "$GPS_JSON" | jsonfilter -e '@.longitude')
    mosquitto_pub -h 127.0.0.1 -p 1883 -t "rutx11/gps/position" -m "$GPS_JSON" -r
    mosquitto_pub -h 127.0.0.1 -t "rutx11/gps/latitude" -m "$LAT" -r
    mosquitto_pub -h 127.0.0.1 -t "rutx11/gps/longitude" -m "$LON" -r
fi
```

Cron (every 10s):
```bash
for i in 0 10 20 30 40 50; do
  echo "* * * * * sleep $i && /usr/local/bin/gps2mqtt.sh"
done >> /etc/crontabs/root
/etc/init.d/cron restart
```

## Package Management

### Default feed (Teltonika-supported only)

```bash
opkg update
opkg list | grep <search-term>
opkg install <package>
```

### OpenWrt community feed (unsupported)

```bash
opkg install <package> \
  --force_feeds /etc/opkg/openwrt/distfeeds.conf
```

### Listing installed packages

```bash
opkg list-installed | grep <search-term>
opkg files <package-name>   # List files owned by a package
```

## Common Pitfalls

1. **`ubus call gps status` fails with "Not found".** The ubus object is `gpsd`, not `gps`. Use `ubus call gpsd position`.

2. **`can't create ... : Read-only file system` when writing to `/usr/bin/`.** The rootfs is squashfs. Write custom scripts to `/usr/local/bin/` instead.

3. **`mosquitto_pub: not found` even though Mosquitto is running.** The default feed ships only the broker (`mosquitto-ssl`), not the client utilities. Install via OpenWrt feeds with `--force_feeds` or use an alternative method.

4. **`jsonfilter: not found`.** RutOS ships with `jsonfilter` — verify it exists first, or use `ubus call gpsd position | grep` as fallback.

5. **GPS always returns `{}` even when enabled.** Ensure the GPS antenna is connected and has clear sky view. First fix after cold start can take 30–60 seconds.

6. **`/data/` directory doesn't exist.** Not all Teltonika models have this. Use `/tmp/` for temporary data or `/usr/local/` for persistent custom files.

## Verification Checklist

- [ ] `ubus list | grep gpsd` confirms the daemon is registered
- [ ] `ubus call gpsd position` returns populated JSON (not `{}`)
- [ ] Custom scripts are placed in `/usr/local/bin/` (not `/usr/bin/`)
- [ ] MQTT publishing uses either OpenWr-feed `mosquitto_pub` or raw TCP
- [ ] Cron jobs use full paths (`/usr/local/bin/gps2mqtt.sh`, not relative)
- [ ] `mosquitto_sub` can confirm messages on the subscribed topic
