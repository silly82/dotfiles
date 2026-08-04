# SisLink Gondelflotte — Korrelationsanalyse (Beispiel)

Dieses Referenzdokument dokumentiert die konkrete Analyse, die im Juli 2026 für eine SisLink-Gondelflotte durchgeführt wurde. Es dient als vollständiges Beispiel für den `exploratory-data-analysis`-Workflow.

## Datenquellen

| Quelle | Format | Schlüsselfelder |
|--------|--------|-----------------|
| `sislink-gateway.log` (25k Zeilen) | JSON im Log-Text | device, batPercentage, batV, extV, solarV, temperature, totalTrips, audioTest |
| `FzLog/Berg/01-07-26/plots/summary.csv` | CSV | device, rssi_mean, rssi_min, gps_fixes, strecke_m |
| `FzLog/Berg/01-07-26/counter_check/counter_summary.csv` | CSV | device, fahrten_pro_h, zaehlungen, ungerade, verworfene_spruenge |

## Join-Key

`device` (z.B. `sll003`, `sll064`) — 42 Geräte in allen 3 Quellen.

## Top-Korrelationen

| x | y | r | Interpretation |
|---|---|---|---|
| Temperatur | Batterie% | **+0.895** | Ladeerwärmung: laden → wärmer + mehr Batterie (3. Faktor) |
| extV (Ladespannung) | batV (Batteriespannung) | **+0.839** | Direkte Kausalität: Ladekontakt hebt Spannung |
| Temperatur | extV (Ladespannung) | **+0.763** | Ladeelektronik wird warm |
| RSSI (Signalstärke) | Strecke (GPS) | **-0.569** | Längere Strecke = schlechterer Empfang |
| Ladeanteil (binär) | Batterie% | Cluster | Ladend: 93.7%, Nicht-ladend: 88.3% |

## Kritischer Fund

**sll064**: 32 Fahrten, extV=0mV (kein Ladekontakt), Batterie nur 85%. Entlädt sich ohne Nachladung — sollte geprüft werden.

## Dashboard

Erzeugt mit `_plot_dashboard.py` → `correlation_dashboard.png` (4-Plot 2×2, dark theme).

## Technische Hürden & Lösungen

1. **Regex für JSON-in-Log**: `({.*}) \(deviceStatus:` statt `({.*?})` — greedy notwendig wegen nested JSON
2. **numpy/PIL mismatch**: Python 3.13 hatte numpy für 3.11 installiert → `python3` versagte, `python` (3.11) funktionierte
3. **Zu wenige Datenpunkte pro Device**: Nur 1-2 Readings pro Gerät → cross-sectional (Geräte vergleichen) statt time-series