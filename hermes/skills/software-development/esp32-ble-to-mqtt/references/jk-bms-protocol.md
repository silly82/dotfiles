# JK / BDRG BMS BLE Protocol (Service 0xFFE0)

## Service UUIDs
- Service: `0000ffe0-0000-1000-8000-00805f9b34fb`
- Characteristic: `0000ffe1-0000-1000-8000-00805f9b34fb` (notify/write)

## Known Devices
| Brand | Name Pattern | Examples |
|-------|-------------|---------|
| JK BMS | `JK-BMS`, `JK_*` | JK-B2A24S |
| BDRG | `R-<model>-<serial>` | R-12100BNNH19-C01278 |

## Frame Format
```
[header(2)] [length(2)] [record_type(1)] [payload(n)] [crc16(2)]
```

- Header: `0x55 0xAA` or `0xAA 0x55`
- Length: Little-endian uint16 (payload-only length)
- CRC16: Modbus (polynomial 0xA001)

## Record Types
| Type | Content | Payload |
|------|---------|---------|
| 0x01 | Basic info | Voltage, current, SOC, capacities, temps, flags |
| 0x02 | Cell voltages | N × 2 bytes (mV per cell) |
| 0x03 | Status | Error flags (2 bytes) |

## Basic Info Record (0x01)
Offset | Size | Field | Unit
-------|------|-------|-----
0 | 2 | Total voltage | mV/10 (i.e. raw/10 = mV)
2 | 2 | Current | mA (signed int16)
4 | 2 | Remaining capacity | mAh
6 | 2 | Nominal capacity | mAh
8 | 1 | SOC | %
9 | 1 | Cycle count (low) | 
10-11 | 2 | Cycle count (full) |
12 | 1 | BMS temperature | °C (signed int8)
13 | 1 | MOS temperature | °C (signed int8)
14 | 1 | Cell count | bits 0-4
15 | 1 | Status flags | bit0=charging, bit1=discharging, bit4=balancer

*Note: exact offset varies by JK firmware version*

## Device Discovery via BLE Advertisement
- Manufacturer Data `[0x585A]`: 6 bytes = MAC address
- Contains Service UUID `0xFFE0` in advertisement
- Device is connectable