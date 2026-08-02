# go-radio-streamer — Session Reference (v2, Juli 2026)

Refactoring done 2026-07-15 on `github.com/silly82/go-radio-streamer`.
Updated with PTP GM findings and README/docs push.

## Project Structure (after refactor v2)

```
cmd/main.go                    → Entrypoint (config load, MQTT, router setup)
internal/
├── config/config.go           → LoadStations, LoadMQTTConfig, LoadStreamerConfig (NetConfig fields)
├── config/config_test.go      → 6 tests (incl Pi5Opts, InvalidTTL, PTPRefClock)
├── api/handlers.go            → REST API (Gorilla Mux, 5 endpoints)
├── streamer/
│   ├── streamer.go            → Core: FFmpeg → RTP Multicast, NetConfig, sync.RWMutex
│   ├── metadata.go            → ICY Metadata Parser (thread-safe via mu)
│   └── streamer_test.go       → 5 tests
├── mqtt/mqtt.go               → MQTT Handler (Eclipse Paho)
└── web/
    ├── web.go                 → Serve static/index.html
    └── static/index.html      → Web UI (German labels)
pkg/aes67/
    ├── sdp.go                 → SDP Builder (L24/48000/2, ts-refclk supports ptp/localmac)
    ├── sap.go                 → SAP Announcer (239.255.255.255:9875)
    └── sdp_test.go            → 8 tests
stations.txt                   → 6 SRF stations (CH)
streamer.conf                  → multicast_address, ptp_ref_clock, bind_interface, ttl, udp_buffer_size
```

## What Was Removed (Dead Code)

- `stream()` + `handleStream()` (go-mp3 decoder path, never called from Start())
- `SetupMQTTClient()` (no-op returning nil)
- `mqttMessageHandler()` in streamer.go (duplicate of mqtt.go handler)
- Duplicate `SetPublishFunc` godoc comment

## What Was Added in v2

### NetConfig struct
```go
type NetConfig struct {
    BindInterface string
    TTL           int
    UDPBufferSize int
}
```

### Improved setupMulticastSocket
- Interface binding via `ipv4.PacketConn.SetMulticastInterface(iface)` — **critical** on dual-NIC Pi
- Configurable TTL (was hardcoded 32)
- Configurable send buffer (was `1 << 20`)
- `SetMulticastLoopback(false)` — added
- Better logging with socket params

### Thread Safety
- `sync.RWMutex` guarding `metadata` field
- All reads via `RLock`, writes via `Lock`
- `Stop()` releases lock before blocking ops, reacquires after

### Config File Format (v2)
```ini
# streamer.conf
multicast_address=239.69.250.171:5004
ptp_ref_clock=IEEE1588-2008:AA-BB-CC-DD-EE-FF-00-00:0
bind_interface=eth0         # Pi 5: force eth0 for multicast
ttl=1                       # subnet-only
udp_buffer_size=4194304      # 4 MiB für Pi 5 GigE
```

### Docs Updated
- `README.md` → v2.0, new config options, PTP section, Docker hint
- `RASPBERRY_PI_SETUP.md` → complete rewrite with Pi 4 vs Pi 5 table, streamer.conf network options, PTP limitation explained, Intel I210 GM setup guide

## Pi 5 Build & Run

```bash
cd /home/silly/go-radio-streamer
git pull
CGO_ENABLED=0 go build -o radio-streamer ./cmd

# Pi 5 optimized config
cat > streamer.conf << 'EOF'
bind_interface=eth0
ttl=1
udp_buffer_size=4194304
EOF

./radio-streamer
# → http://<pi-ip>:8080
```

## PTP Realities (Kernerkenntnisse dieser Session)

### Pi kann NICHT als PTP Grandmaster
- Pi 4: USB-Ethernet (LAN7515) → kein HW-PTP
- Pi 5: RP1-PCIe-Ethernet → ebenfalls kein HW-PTP
- `ptp4l` ohne Hardware-Timestamping hat Mikrosekunden-Jitter → für AES67 (Nanosekunden) unbrauchbar

### Was ALS PTP GM funktioniert
| Lösung | Aufwand | Kosten |
|--------|---------|--------|
| Intel I210/I350 NIC in NUC/ThinClient + `ptp4l -i eth0 -m` | 💻 eBay 15€ + Linux | ✅ Echte HW-PTP |
| Netgear M4250/M4300 Switch (BC + GM) | Switch 200-400€ | ✅ Kann GM |
| FortiGate/FortiSwitch | ❌ Kein GM-Modus | ❌ Nur TC/BC auf High-End-Modellen |

### Was nicht funktioniert (als GM)
- Raspberry Pi (jedes Modell) — kein HW-PTP im Ethernet
- FortiGate 60F/80F/100F — kein PTP im SOC
- FortiSwitch 100er/200er/400er — kein PTP
- Zweiter Pi als PTP GM — kein HW-Timestamping

### Receiver-Kompatibilität
| Empfänger | Ohne PTP (`localmac`) | Mit PTP GM |
|-----------|----------------------|------------|
| ffplay/VLC | ✅ Läuft | ✅ Läuft |
| Dante Via (Free-Run) | ✅ Wenn konfiguriert | ✅ |
| Merging HAPI / DirectOut / RME | ❌ Verweigert | ✅ |
| Lawo / professionelle Broadcast-Hardware | ❌ Erzwingt PTP | ✅ |

### Praktische Empfehlung
1. Erstmal Software-Empfänger testen (ffplay, VLC) — das läuft sofort
2. Falls Hardware-Receiver nötig: Intel I210-NIC in alten NUC/ThinClient + `ptp4l` als GM
3. `ptp_ref_clock` in streamer.conf vom GM übernehmen