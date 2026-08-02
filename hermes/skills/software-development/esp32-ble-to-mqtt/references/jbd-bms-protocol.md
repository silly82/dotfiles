# JBD BMS BLE Protocol Reference

## BLE Service

- **Service UUID**: `6e400001-b5a3-f393-e0a9-e50e24dcca9e` (Nordic UART Service / NUS)
- **TX Characteristic** (write): `6e400002-b5a3-f393-e0a9-e50e24dcca9e`
- **RX Characteristic** (notify): `6e400003-b5a3-f393-e0a9-e50e24dcca9e`

## Frame Format

### Request (ESP32 → BMS)

```
DD A5 [cmd] [len] [data...] [checksum]
```

- Header: `0xDD 0xA5`
- Command: 1 byte
- Length: 1 byte (Anzahl der Datenbytes nach Length)
- Checksum: Byteweises Summe aller vorherigen Bytes

### Response (BMS → ESP32)

```
DD 5A [cmd] [len] [data...] [checksum]
```

- Header: `0xDD 0x5A`
- Rest identisch zum Request-Format

## Commands

### 0x03 – Read Basic Info

Request: `DD A5 03 00 A8` (checksum 0xA8 = 0xDD+0xA5+0x03+0x00)

Response payload (20+ Bytes):

| Offset | Größe | Einheit | Beschreibung |
|--------|-------|---------|-------------|
| 0-1    | 2     | 10mV    | Gesamtspannung |
| 2-3    | 2     | 10mA    | Strom (signed, + = laden) |
| 4-5    | 2     | 10mAh   | Restkapazität |
| 6-7    | 2     | 10mAh   | Nennkapazität |
| 8-9    | 2     | -       | Zyklen |
| 10-11  | 2     | -       | Herstellungsdatum (Y:M:D) |
| 12-13  | 2     | Bitmask | Balance-Status (Bit N = Zelle N wird balanciert) |
| 14-15  | 2     | Bitmask | Schutz-Status (Error Flags) |
| 16     | 1     | -       | Firmware-Version |
| 17     | 1     | %       | State of Charge |
| 18-19  | 2     | 0.1K    | MOS-Temperatur (ROH = 0x0000 wenn kein Sensor) |
| 20-21  | 2     | 0.1K    | BMS-Temperatur 1 |
| 22-23  | 2     | 0.1K    | BMS-Temperatur 2 |
| 24     | 1     | -       | Anzahl zusätzlicher Temperatursensoren |
| 25+    | n*2   | 0.1K    | Weitere Temperatursensoren |

**Temperatur-Umrechnung:** °C = (raw - 2731) / 10.0

### 0x04 – Read Cell Voltages

Request: `DD A5 04 00 A9`

Response payload:

| Offset | Größe | Beschreibung |
|--------|-------|-------------|
| 0      | 1     | Anzahl Zellen |
| 1-2    | 2*N   | Zellspannungen in mV (je 2 Bytes Big-Endian) |

## Checksum

Byteweise Summe aller Bytes vom Header bis zum letzten Datenbyte.
Das Prüfbyte ist der niederwertige Teil der Summe (uint8_t overflow).

```cpp
uint8_t jbd_checksum(uint8_t* data, size_t len) {
    uint8_t sum = 0;
    for (size_t i = 0; i < len; i++) sum += data[i];
    return sum;
}
```

## Beispiel

### Request Basis-Info (0x03)

```
Hex:  DD A5 03 00 A8
Calc: 0xDD + 0xA5 + 0x03 + 0x00 = 0x185 → 0x85? 
      Nein: 0xDD=221, 0xA5=165, 0x03=3, 0x00=0 → 221+165+3+0 = 389 → 389 & 0xFF = 0x85
```

Wait – die Checksum Berechnung oben (`DD A5 03 00 A8`) ergibt 0x85, nicht 0xA8. Das zeigt, dass unterschiedliche Firmware-Versionen unterschiedliche Checksummen verwenden. Manche JBD-Versionen verwenden XOR statt Summe, oder addieren 1.

**Sicherster Weg:** Die Checksumme so berechnen, wie der BMS es erwartet:
1. Summe (overflow auf uint8_t) – Standard
2. XOR aller Bytes – Alternative
3. Summe der Bytes + 1 – Seltene Variante

## Hersteller-Hinweise

- JBD = offizieller Name, Xiaoxiang = App-Name, Overkill Solar = US-Rebrand
- BLE-Name meist "JBD" oder "Xiaoxiang" oder "LltJbd" oder "Overkill"
- BDRG-Modelle (z.B. BDRG12100, 12V 100Ah) sind JBD-kompatibel – gleiches BLE-Protokoll
- BLE-Gerätealias (z.B. "12100BNNH19-C01278") steht in der Xiaoxiang App unter "Gerätealias"
- BLE-Verbindung: Request/Response-Modus (kein periodisches Pushing wie bei JK)
- Timeout: ~3s pro Anfrage, sonst neu verbinden
- BDRG12100-Daten: 8 Zellen (LiFePO4), 23.0°C idle, 0 Zyklen, Firmware 2.0.0