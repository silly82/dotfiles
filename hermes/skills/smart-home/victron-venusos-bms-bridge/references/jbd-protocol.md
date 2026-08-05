# JBD BMS BLE Protocol Reference

Aus aiobmsble (patman15) Quellcode extrahiert — kompakte Referenz
für den ESP32-Firmware-Bau.

## BLE Service/Charakteristiken

| Parameter | UUID | Beschreibung |
|-----------|------|-------------|
| Service UUID | `0000ff00-0000-1000-8000-00805f9b34fb` | JBD BLE Service |
| RX Char | `0000ff01-0000-1000-8000-00805f9b34fb` | Notify (BMS→Client) |
| TX Char | `0000ff02-0000-1000-8000-00805f9b34fb` | Write (Client→BMS) |

## BMS-Erkennung (Name-Patterns)

Der ESP scannt nach diesen BLE-Namen (Unix Wildcard):

```
JBD-*       — Standard JBD
DWF*        — Daren BMS / Docan
LSG-*       — Lossigy
SX1*        — Supervolt v3
SBL-*       — SBL
OGR-*       — OGRPHY
TZ-H*       — CERRNSS
N-?????BL*  — Nordström
```

Oder via OUI: `A4:C1:37/38`, `A5:C2:37/39/3A`, `AA:C2:37`, `70:3E:97`, `10:A5:62`

## Frame-Format

### Init-Sequenz (vor erstem Command nötig)

```
Send: FF AA 15 01 <checksum>
Checksum = (0x15 + 0x01) & 0xFF  →  FF AA 15 01 16
```

Response bei Erfolg: `FF AA 15 01 00 <crc>` (Status-Byte an Position 4 = 0x00)

### Data-Command

```
DD A5 <cmd> <len> <data...> <crc_hi> <crc_lo> 77
```

- cmd: 0x03 = Basic Info, 0x04 = Cell Voltages, 0x05 = Device Info (HW Version)
- len: Anzahl Datenbytes (0 wenn kein Payload)
- CRC: 0x10000 - sum(cmd + len + data) — 16 bit, Big Endian
- Tail: 0x77

### Basic Info (0x03) — Response

```
DD 03 00 <len> <data...byte 4..len+3> <crc_hi> <crc_lo> 77
```

| Offset | Bytes | Format | Wert | Beispiel |
|--------|-------|--------|------|----------|
| 4 | 2 | uint16, BE | Spannung (mV) | 1325 → 13.25V |
| 6 | 2 | int16, BE | Strom (0.01A) | 502 → 5.02A |
| 8 | 2 | uint16, BE | Ladekapazität (0.01Ah) | 9850 → 98.50Ah |
| 10 | 2 | uint16, BE | Design-Kapazität (0.01Ah) | 12000 → 120Ah* |
| 12 | 2 | uint16, BE | Zyklen (#) | 42 |
| 16 | 4 | uint32, BE | Balancer-Bitmask (swap32) | — |
| 20 | 2 | uint16, BE | Problem-Code | 0 = ok |
| 23 | 1 | uint8 | SoC (%) | 78 |
| 24 | 1 | uint8 | MOSFET Status | Bit0=chrg, Bit1=dischrg |
| 26 | 1 | uint8 | Temp-Sensoren (#) | 2 |
| 27+ | 2×N | uint16, BE | Temp-Werte (Kelvin×10 - 2731) / 10 → °C |

*\*Design-Capacity wird durch 100 geteilt (nicht 10000), also 12000 → 120Ah*

### Cell Voltages (0x04) — Response

```
DD 04 00 <len> <cell1_hi> <cell1_lo> <cell2_hi> <cell2_lo> ... <crc> <crc> 77
```

- Jede Zelle: 2 Byte, Big Endian, /1000 → Volt
- len = 2 × Anzahl Zellen
- Beispiel: 0x0CEC → 3.308V

## CRC-Berechnung

```c
uint16_t jbd_crc(const uint8_t* data, size_t len) {
    uint32_t sum = 0;
    for (size_t i = 0; i < len; i++) sum += data[i];
    return (uint16_t)(0x10000 - sum);
}
```

CRC wird über cmd(1) + len(1) + data(N) berechnet (ohne Header/Tail).

## Timing

- Init → Antwort: < 1s
- Command → Antwort: < 3s
- Zwischen Commands: 200ms Pause
- Polling-Intervall: 30s (Standard)
- Connection Timeout: 10s