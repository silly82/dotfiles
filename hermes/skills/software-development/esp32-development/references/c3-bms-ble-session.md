# ESP32-C3 BLE BMS Bridge — Session Reference

## Build Output (Successful)
```
RAM:   19.3% (63368 / 327680 bytes)
Flash: 55.3% (1740595 / 3145728 bytes)
firmware.bin (1700 KB)
bootloader.bin (23 KB)
```

## C3 USB Serial — Boot Mode States
| Boot code | Mode | Cause |
|-----------|------|-------|
| `boot:0xf` | SPI_FAST_FLASH_BOOT | Normal boot from flash |
| `boot:0x7` | DOWNLOAD(USB/UART0/1) | GPIO0 low or USB download request (DTR toggle) |

## C3 Crash — Guru Meditation (BLE double-init)
```
[  7142][E][BLEDevice.cpp:241] getScan(): BLE is not initialized. Call BLEDevice::init() first
Guru Meditation Error: Core 0 panic'ed (Load access fault).
```
Fix: call `BLEDevice::init("")` once globally BEFORE any BLE operations. If the BMS class also calls init() internally, remove that call.

## BDRG BMS BLE Advertisement (from phone scanner)
- Local Name: `R-12100BNNH19-C01278`
- Service UUID: `0xFFE0` → JK protocol (NOT JBD/NUS)
- Manufacturer Data `[0x585A]`: `C8:47:80:70:44:D6` → MAC address
- Final attempt: direct connection via MAC `C8:47:80:70:44:D6` bypasses scan

## MQTT State (ESP online, BLE silent)
```
bms/bdrg/connected: {"status":"online","ip":"192.168.24.221","rssi":-41}
```
This message was RETAINED — persisted across reboots. Gave false impression ESP was working fine when it was actually crashing on BLE init.

## Key Lessons
1. ESP32-C3 (400KB RAM) cannot run BLE + WiFi simultaneously without careful ordering
2. Native USB-CDC on C3 resets chip via DTR when opening port → download mode
3. BDRG BMS uses JK protocol (0xFFE0), NOT JBD/NUS despite similar branding
4. MQTT retained messages = false positives after crash; use heartbeat topic without retain