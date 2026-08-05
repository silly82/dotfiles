# uConsole WiFi signal troubleshooting

## Symptoms
- Signal is **-70 dBm or worse** despite being <4 m from AP with line of sight.
- Normal indoor expectation at that range: **-30 to -55 dBm**.
- `Available Antennas: TX 0 RX 0` shows in `iw phy` output.

## Root causes (uConsole-specific)

### 1. dtparam=ant2 (secondary antenna)
Stock ClockworkPi image sets `dtparam=ant2` in `/boot/firmware/config.txt`. On a CM4:
- `ant1` = onboard PCB trace antenna (on the CM4 module itself)
- `ant2` = U.FL/IPEX connector on the CM4 → cable → uConsole chassis antenna

If the IPEX cable is loose, damaged, or the uConsole antenna isn't connected
properly, `ant2` gives very weak signal because the antenna port literally
has no radiating element.

**Check:**
```
grep dtparam.ant /boot/firmware/config.txt
```

**Test fix (requires reboot):**
Edit `/boot/firmware/config.txt` and change `dtparam=ant2` to `dtparam=ant1`,
then reboot. This uses the CM4's own PCB antenna. Compare signal levels.

### 2. Power Save enabled
The Broadcom driver (`brcmfmac`) enables power saving by default:
```
kernel: brcmf_cfg80211_set_power_mgmt: power save enabled
```

This reduces TX power and can cause signal fluctuations.

**Disable it at runtime:**
```
sudo /usr/sbin/iw dev wlan0 set power_save off
```
Note: `iw` lives in `/usr/sbin/` which is NOT in the default user PATH on
Debian trixie. Always use the full path or `sudo` with absolute path.

**Make it persistent:**
Create `/etc/NetworkManager/conf.d/powersave.conf`:
```
[connection]
wifi.powersave = 2    # 0=default, 1=ignore, 2=disable
```
Then `sudo systemctl restart NetworkManager`.

### 3. 5 GHz vs 2.4 GHz band
5 GHz (802.11ac/ax) has shorter range and is more attenuated by the uConsole's
metal/plastic chassis. The same AP often broadcasts on both bands with the
same SSID; the client may auto-connect to the weaker 5 GHz signal.

**Check signal per band:**
```
sudo /usr/sbin/iw dev wlan0 scan | grep -E 'SSID: <YOUR_SSID>|signal|freq'
```

**Force 2.4 GHz for a specific connection:**
```
nmcli connection modify <SSID> 802-11-wireless.band bg
```
(`bg` = 2.4 GHz only, `a` = 5 GHz only, omit = auto)

After changing, reconnect:
```
nmcli connection down <SSID> && nmcli connection up <SSID>
```

### 4. Available Antennas: TX 0 RX 0
This appears in `iw phy <phy> info` output on some Broadcom firmware
configurations. It doesn't necessarily mean zero antennas are connected —
it can also mean the firmware didn't report antenna count. But combined
with weak signal, it's a strong indicator that `dtparam=ant1` should be
tried.

## Diagnostic commands

```
# Signal level of current connection
/usr/sbin/iw dev wlan0 link

# Full scan with signal per SSID/freq
sudo /usr/sbin/iw dev wlan0 scan | grep -E 'SSID:|signal:|freq:'

# Current phy antenna info
/usr/sbin/iw phy | grep -A2 Antenna

# Power save status (kernel log)
dmesg | grep power_save

# Current config.txt antenna setting
grep dtparam.ant /boot/firmware/config.txt
```

## Quick reference: signal levels

| dBm | Quality | Typical range |
|-----|---------|--------------|
| -30 to -50 | Excellent | Same room, LOS |
| -50 to -60 | Good | Same room, some obstacles |
| -60 to -70 | Fair | One wall/floors |
| -70 to -80 | Weak | Multiple walls, distance |
| -80 to -90 | Very weak | Barely usable |