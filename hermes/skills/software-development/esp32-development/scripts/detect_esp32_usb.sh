#!/usr/bin/env bash
# Detect an ESP32-family board connected to macOS via USB-CDC.
# Works for XIAO ESP32C6, ESP32-S3, classic ESP32 with CH340/CP2102.
# Distinguishes "running app" (idProduct != 0x1001) from "ROM bootloader" (0x1001).

set -e

echo "=== USB-Serial-Pfade ==="
ls -la /dev/cu.usbmodem* /dev/cu.usbserial-* /dev/cu.SLAB_USBtoUART /dev/cu.wchusbserial* 2>/dev/null | grep -v "No such" || true

echo
echo "=== ioreg: Espressif-Devices ==="
ioreg -p IOUSB -l 2>&1 | awk '
  /USB JTAG\/serial debug unit/ { capture=1 }
  capture && /idVendor|idProduct|USB Serial Number/ { print; if (/USB Serial Number/) capture=0 }
  /"USB Vendor Name" = "Espressif"/ { print }
' | head -20

echo
echo "=== arduino-cli board list (Espressif) ==="
arduino-cli board list 2>&1 | grep -E "espressif|ESP32" | head -5

echo
echo "=== Diagnose ==="
# Heuristic: if any cu.usbmodem* exists, that's likely the running app
# (after auto-reset). If only ioreg shows Espressif with idProduct=0x1001, it's ROM.
if ls /dev/cu.usbmodem* 2>/dev/null | head -1 | grep -q .; then
  PORT=$(ls -t /dev/cu.usbmodem* 2>/dev/null | head -1)
  echo "STATUS: Running app detected on $PORT"
  echo "UART_DEVICE=$PORT"
elif ls /dev/cu.usbserial* 2>/dev/null | head -1 | grep -q .; then
  PORT=$(ls -t /dev/cu.usbserial* 2>/dev/null | head -1)
  echo "STATUS: Running app detected on $PORT"
  echo "UART_DEVICE=$PORT"
elif ls /dev/cu.SLAB_USBtoUART 2>/dev/null | grep -q .; then
  echo "STATUS: Running app detected on /dev/cu.SLAB_USBtoUART"
  echo "UART_DEVICE=/dev/cu.SLAB_USBtoUART"
else
  ROM=$(ioreg -p IOUSB -l 2>&1 | grep -B1 -A1 "idProduct = 4097" | grep "idVendor = 12346" | head -1)
  if [ -n "$ROM" ]; then
    echo "STATUS: ROM bootloader only (idProduct=0x1001) - no CDC port"
    echo "FIX: Flash via arduino-cli (esptool talks ROM directly):"
    echo "  arduino-cli upload -p /dev/cu.usbmodem1101 --fqbn esp32:esp32:esp32c6:CDCOnBoot=cdc --input-dir /tmp/build <sketch>"
    echo "AFTER FLASH: XIAO-C6 stays in ROM. Manual reset:"
    echo "  - Hold B (Boot=GPIO9), tap R (Reset), release B -> second R -> running app"
    echo "  - Or unplug/replug USB cable"
  else
    echo "STATUS: No ESP32 device detected"
  fi
fi
