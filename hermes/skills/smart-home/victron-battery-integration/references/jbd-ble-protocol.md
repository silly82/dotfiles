# JBD / Jiabaida BLE Protocol Reference

Based on reverse-engineering from [aiobmsble](https://github.com/patman15/aiobmsble) (`jbd_bms.py`).

## BLE Service & Characteristics

| UUID | Type | Purpose |
|------|------|---------|
| `0000ff00-0000-1000-8000-00805f9b34fb` | Service | JBD BMS service |
| `0000ff01-0000-1000-8000-00805f9b34fb` | RX (Notify) | BMS → client data |
| `0000ff02-0000-1000-8000-00805f9b34fb` | TX (Write) | Client → BMS commands |

## Device Name Patterns

JBD BMS advertises under names matching: `JBD-*`, `DWF*`, `LSG-*`, `SX1*`, `SBL-*`, `OGR-*`, `TZ-H*`.

Also identified by OUI prefixes: `10:A5:62`, `A4:C1:37`, `A4:C1:38`, `A5:C2:37`, `A5:C2:39`, `A5:C2:3A`, `AA:C2:37`, `70:3E:97`.

## Frame Format

All frames follow this structure:

```
[Header] [Cmd] [Len] [Data...] [CRC16] [Tail]
```

| Field | Size | Description |
|-------|------|-------------|
| Header | 1-2 bytes | `0xFF 0xAA` (init) or `0xDD 0xA5` (command) |
| Cmd | 1 byte | Command/response type |
| Len | 1 byte | Data length (bytes) |
| Data | Len bytes | Payload |
| CRC16 | 2 bytes | `0x10000 - sum(cmd + len + data)` |
| Tail | 1 byte | `0x77` |

## Commands

### Init Sequence

Sent first to establish connection (only needed if `secret` is set):

```
FF AA 15 01 <checksum>
```

Where `checksum = (0x15 + 0x01 + sum(secret_bytes)) & 0xFF`.

Response:
```
FF AA 15 01 <status>
```
where `status=0x00` = OK.

### Command 0x03 — Basic Info

Request: `DD A5 03 00 <CRC16> 77`

Response data fields (positions relative to start of data section, after Len byte):

| Offset | Size | Type | Description | Scale |
|--------|------|------|-------------|-------|
| 0-3 | 4 | — | Header info, skip | |
| 4 | 2 | uint16 | Voltage (mV) | ÷100 = V |
| 6 | 2 | int16 | Current (mA) | ÷100 = A; positive = charging |
| 8 | 2 | uint16 | Cycle charge (cAh) | ÷100 = Ah |
| 10 | 2 | uint16 | Design capacity | ÷100 = Ah |
| 12 | 2 | uint16 | Cycles | raw |
| 16 | 4 | uint32 | Balancer bitmask (swap32) | bitmask |
| 20 | 2 | uint16 | Problem code | 0 = OK |
| 23 | 1 | uint8 | Battery level | % |
| 24 | 1 | uint8 | MOSFET status | bit 0 = charge, bit 1 = discharge |
| 26 | 1 | uint8 | Temp sensor count | N |
| 27 | N×2 | uint16[] | Temperature values | (raw − 2731) ÷ 10 = °C |

### Command 0x04 — Cell Voltages

Request: `DD A5 04 00 <CRC16> 77`

Response: data starts at offset 4, each cell = 2 bytes uint16, ÷1000 = V.

`cell_count = data_len / 2`

### Command 0x05 — Device Info (Firmware/HW)

Request: `DD A5 05 00 <CRC16> 77`

Response contains a string at offset 4 with `len` bytes. Typically hardware/firmware version.

## Example: Parsing Basic Info

If response data (after `DD 03 00`) is:
```
00 00 0E 10 00 FA 00 00 00 00 00 00 00 00 00 00 4E 01 1A 00 00 00 28 02 01 8B 09 D7 09
```

Decoded:
- Voltage: bytes 4-5 = `0x0E10` = 3600 → 36.00 V
- Current: bytes 6-7 = `0x00FA` = 250 → 2.50 A
- SoC: byte 23 = `0x4E` = 78%
- Chg MOSFET: byte 24 = `0x02` → bit 1 set = discharge enabled
- Temp: bytes 27-28 = `0x08B` = 2259 → (2259−2731)/10 = −47.2°C (sensor unconnected)
- Temp: bytes 29-30 = `0x09D7` = 2519 → (2519−2731)/10 = −21.2°C (sensor unconnected)

## CRC Calculation

```c
uint16_t jbd_crc(const uint8_t* data, size_t len) {
    uint32_t sum = 0;
    for (size_t i = 0; i < len; i++) sum += data[i];
    return (uint16_t)(0x10000 - sum);
}
```

CRC covers: `cmd_byte + len_byte + data_bytes` (3 bytes minimum).

## ESP32 Implementation Notes

- Use NimBLE for better memory efficiency (saves ~50KB heap vs standard BLE)
- Wait 200ms+ between command 0x03 and 0x04 requests
- Notification timeout: 5 seconds
- Reconnect strategy: exponential backoff (10s → 120s max)
- RSSI should be > −75 dBm for stable connection
- Use a watchdog: set BMS data to zero/offline after N seconds without MQTT update