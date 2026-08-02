#!/bin/sh
# Sway bar status script for uConsole CM5
# Usage: bar { status_command sh /etc/sway/status }
# Shows: WiFi-SSID | Battery% | Time

while true; do
  # WiFi (iwgetid is NOT available on minimal NixOS, use iw)
  ssid=$(iw dev wlan0 info 2>/dev/null | awk '/ssid/ {print $2}')
  [ -z "$ssid" ] && ssid="-"

  # Optional: signal strength
  sig=$(iw dev wlan0 link 2>/dev/null | awk '/signal/ {print $2}' | sed 's/-//')
  [ -n "$sig" ] && sig="$sig dBm" || sig=""

  # Battery (direct sysfs read — i3status battery module has path bugs)
  cap=$(cat /sys/class/power_supply/axp20x-battery/capacity 2>/dev/null || echo "?")

  # Time
  now=$(date +%H:%M)

  # Format: SSID  [signal]  |  BAT%  |  HH:MM
  echo "  $ssid $sig  |  $cap%  |  $now"
  sleep 2
done