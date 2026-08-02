---
name: go-arm-optimization
description: "Optimize Go network applications for ARM/Linux targets (Raspberry Pi) — code review patterns, dead code removal, thread safety, multicast/network stack tuning, and config-driven hardware adaptation."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux, macos]
metadata:
  hermes:
    tags: [go, arm, raspberry-pi, optimization, networking, multicast, performance]
    related_skills: [requesting-code-review, simplify-code, systematic-debugging]
---

# Go ARM/Linux Optimization

Code review and optimization patterns for Go projects targeting ARM-based embedded Linux (Raspberry Pi 4/5, uConsole, etc.).

## When to Use

- User asks to "optimize code" for a Go project targeting Pi/ARM
- Code review requested on a Go networking/streaming project
- User reports performance issues (dropped packets, buffer underruns, clock sync failures) on Pi
- Preparing a Go application for ARM deployment (Pi 4/5, uConsole)
- Configuring multicast/RTP streaming for embedded targets

## Step 1 — Code Review: Go Project Health

Check these patterns in order. Report findings before making changes.

### 1a — Dead / Duplicate Code

```bash
# Find unused functions and dead code paths
grep -r "func.*\w\+(" internal/ | sort
```

**Common Go dead-code patterns:**
- Two parallel implementation paths where only one is called (e.g., FFmpeg vs go-mp3 decoder)
- `SetupMQTTClient()` that returns nil / is a no-op
- Duplicate message handlers in both streamer.go and mqtt.go
- Functions that only `log.Printf("Would send %d bytes", n)` — commented-out real logic
- Orphaned `stream()` / `handleStream()` methods never called from `Start()`

**Remove dead code** — don't comment it out, delete it. It's dead weight that confuses future readers and increases binary size.

### 1b — Thread Safety (sync.RWMutex)

**Pattern to look for:**
- `Metadata`, `Status`, or shared state accessed from multiple goroutines (heartbeat ticker, ICY metadata background fetch, /api/status handler)
- Fields like `running`, `currentStation`, `metadata` read/written in different goroutines

**Fix:**
```go
type Streamer struct {
    // ...
    mu       sync.RWMutex
    metadata Metadata
}
```

- Use `s.mu.RLock()` / `s.mu.RUnlock()` for reads (CurrentStatus, publishHeartbeat)
- Use `s.mu.Lock()` / `s.mu.Unlock()` for writes (metadata updates, Start/Stop state transitions)
- Be careful with `Stop()`: release the lock before blocking operations (close(stopCh), wait for streamDone), reacquire after

### 1c — Race Conditions in Start/Stop

**Common bug:** `Start()` checks `s.running`, then calls `s.Stop()` (which acquires lock), then expects a consistent state after. 

**Fix:** Release lock before `s.Stop()`, sleep, then reacquire:
```go
s.mu.Lock()
if s.running {
    if s.currentStation == station.Name {
        s.mu.Unlock()
        return nil
    }
    s.mu.Unlock()
    s.Stop()
    time.Sleep(200 * time.Millisecond)
    s.mu.Lock()
}
s.station = station
s.currentStation = station.Name
s.mu.Unlock()
```

### 1d — ICY Metadata / Heartbeat

Check for:
- Metadata set without lock in background goroutine (`updateMetadataAsync`)
- JSON string building with `fmt.Sprintf` + escaped quotes — prefer raw string literals with backticks
- Inconsistent field names between heartbeat JSON and documented payloads
- `meta_updated` vs `timestamp` inconsistency

## Step 2 — Network Stack Tuning for Pi

### 2a — Interface Binding (Critical for dual-networking Pi)

On Pi with both `eth0` (Ethernet) and `wlan0` (WiFi), multicast MUST go out the correct interface:

```go
type NetConfig struct {
    BindInterface string  // e.g., "eth0", "wlan0"
    TTL           int     // default 32
    UDPBufferSize int     // default 1048576 (1 MiB)
}

func setupMulticastSocket(multicastAddr string, netCfg NetConfig) (*net.UDPConn, error) {
    conn, err := net.DialUDP("udp", nil, addr)
    // ...
    p := ipv4.NewPacketConn(conn)
    p.SetMulticastTTL(netCfg.TTL)
    conn.SetWriteBuffer(netCfg.UDPBufferSize)
    p.SetMulticastLoopback(false)  // don't receive own multicast
    p.SetMulticastInterface(iface) // IP_MULTICAST_IF — bind to specific interface
    return conn, nil
}
```

### 2b — Config-Driven Network Stack

Create a `NetConfig` struct passed to the streamer constructor. Parse from config file:

```
# streamer.conf (Pi 5 optimised)
multicast_address=239.69.250.171:5004
bind_interface=eth0
ttl=1                         # same-subnet only
udp_buffer_size=4194304       # 4 MiB for Pi 5 Gigabit Ethernet
```

**Config parser pattern:**
```go
type StreamerConfig struct {
    MulticastAddress string
    BindInterface    string
    TTL              int
    UDPBufferSize    int
}

const DefaultTTL = 32
const DefaultUDPBufferSize = 1048576

func LoadStreamerConfig(path string) (*StreamerConfig, error) {
    cfg := &StreamerConfig{
        MulticastAddress: DefaultMulticastAddress,
        TTL:              DefaultTTL,
        UDPBufferSize:    DefaultUDPBufferSize,
    }
    // scan key=value lines, switch on key
}
```

### 2c — Socket Options Summary

| Option | Go API | Effect |
|--------|--------|--------|
| Interface binding | `ipv4.PacketConn.SetMulticastInterface(iface)` | Route multicast via specific NIC |
| TTL | `ipv4.PacketConn.SetMulticastTTL(n)` | 1 = subnet, 32 = default, 255 = global |
| Send buffer | `net.UDPConn.SetWriteBuffer(n)` | Reduce drops under load |
| Loopback | `ipv4.PacketConn.SetMulticastLoopback(false)` | Don't receive own stream |
| REUSEPORT | raw syscall (not in ipv4) or kernel default | For fast restarts |

### 2d — Pi 5-Specific Tuning

Pi 5 has native Gigabit Ethernet (not USB-based like Pi 4) — can handle larger buffers and lower latency:

- `udp_buffer_size=4194304` (4 MiB) — Pi 5 can sustain higher throughput
- `ttl=1` for local subnet only (reduce unnecessary network hops)
- Always set `bind_interface` if both Ethernet and WiFi are active

### 2e — Config Test Patterns

When adding config fields, always write tests for:
- **Happy path** — valid values parse correctly
- **Defaults** — empty/missing file uses defaults for all fields
- **Invalid values** — out-of-range values fall back to defaults (e.g. TTL > 255)
- **Boundary values** — min/max for integers
- **String fields** — empty strings vs meaningful values

```go
func TestLoadStreamerConfig_Pi5Opts(t *testing.T) {
    content := []byte(`bind_interface=eth0\nttl=1\nudp_buffer_size=4194304\n`)
    // ... create tempfile, write, parse, assert
}

func TestLoadStreamerConfig_InvalidTTL(t *testing.T) {
    content := []byte("ttl=999\n")  // >255, should use default
    // ... assert cfg.TTL == DefaultTTL
}
```

## Step 3 — Clock Synchronization (RTP/AES67)

**On Pi without RTC, clock problems are common:**

1. **NTP is mandatory** — Pi has no hardware RTC, clock is wrong at boot
   ```bash
   sudo apt install -y ntp
   sudo systemctl enable --now ntp
   ```

2. **No HW PTP on Pi** — Standard Pi Ethernet/WiFi don't have IEEE 1588-2002 timestamping
   - `a=ts-refclk:localmac=...` is the correct default
   - Some AES67 hardware receivers REQUIRE PTP and will reject `localmac` streams
   - Fix: run a PTP grandmaster on the network and set `ptp_ref_clock` in config

3. **RTP timestamp from wall clock** — `time.Now()` scaled to 48kHz:
   ```go
   timestamp := uint32(now.Unix()*48000 + int64(now.Nanosecond())*48000/1_000_000_000)
   ```
   Without NTP, timestamps jump at boot → receivers reject or audio glitches.

### PTP Grandmaster Realities (wichtig für AES67-Hardware)

**Pi kann NICHT als PTP GM** — weder Pi 4 noch Pi 5 haben HW-PTP-Timestamping im Ethernet:
- Pi 4: USB-Ethernet (LAN7515/9500) → kein PTP
- Pi 5: RP1-PCIe-Ethernet → ebenfalls kein PTP
- `ptp4l` im Software-Mode hat Mikrosekunden-Jitter → für AES67 unbrauchbar

**Was als PTP GM funktioniert:**
- Intel I210/I350 NIC in x86-Rechner + `ptp4l -i eth0 -m` (ca. 15€ auf eBay)
- Netgear M4250/M4300 Managed Switch (PTP BC + GM)
- Dedizierte PTP-Grandmaster (Meinberg, Oscilloquartz)

**Was NICHT als PTP GM funktioniert:**
- FortiGate 60F/80F/100F (kein PTP im SOC)
- FortiSwitch 100er/200er/400er (kein PTP)
- FortiGate 400F+ / FortiSwitch 5000+ sind nur TC/BC, kein GM
- Raspberry Pi (jedes Modell)

**Receiver-Kompatibilitätstabelle:**

| Empfänger | Ohne PTP (`localmac`) | Mit PTP GM |
|-----------|----------------------|------------|
| ffplay/VLC (Software) | ✅ Läuft | ✅ |
| Dante Via (Free-Run) | ⚠️ Wenn konfiguriert | ✅ |
| Merging HAPI / DirectOut | ❌ Verweigert | ✅ |
| RME Digiface AVB | ❌ Verweigert | ✅ |
| Lawo / Broadcast | ❌ Erzwingt PTP | ✅ |

**Praktische Empfehlung:**
1. Erst Software-Empfänger testen (ffplay, VLC) — das läuft sofort auf dem Pi
2. Falls Hardware-Receiver nötig: Intel I210-NIC in NUC/ThinClient + `ptp4l` als GM
3. `ptp_ref_clock` in `streamer.conf` vom GM übernehmen

## Step 4 — Build Verification

```bash
# Clean build
CGO_ENABLED=0 go build -o radio-streamer ./cmd

# All tests fresh (no cache)
go clean -testcache
go test -count=1 -v ./...

# Smoke test: binary starts and API responds
./radio-streamer &
PID=$!
sleep 1
curl -sf http://localhost:8080/api/status
kill $PID 2>/dev/null; wait $PID 2>/dev/null
```

## Pitfalls

- **Dead code with imports** — when removing functions, check if their imports are still used elsewhere. `go build ./...` catches unused imports.
- **Stop() reentrancy** — `Stop()` closes channels and waits for goroutines. Ensure the stopCh is re-created after stop (`s.stopCh = make(chan struct{})`) so the next `Start()` doesn't write to a closed channel.
- **FFmpeg not on PATH** — Pi deployment: `sudo apt install -y ffmpeg`. The binary silently fails without it.
- **Multicast in WiFi** — Most WiFi APs drop or rate-limit multicast. Prefer Ethernet for AES67/RTP streams.
- **Config file path** — On Pi systemd service, WorkingDirectory must be set correctly or config files won't be found.
- **PTP GM auf Pi — unmöglich** — Kein Raspberry Pi hat HW-PTP-Timestamping im Ethernet. `ptp4l` im Software-Mode ist zu ungenau für AES67. Für Hardware-Receiver brauchst du einen separaten GM (Intel I210-NIC, Netgear M4250, etc.). Sag dem User direkt Bescheid, sonst probiert er stundenlang `ptp4l` auf dem Pi.
- **FFmpeg URL mit .m3u** — Manche Radiosender liefern M3U-Playlists statt direkter Stream-URLs. Der Code muss die M3U parsen (`http.Get` + erste Zeile die mit `http` beginnt). Teste mit dem tatsächlichen URL-Format der Sender.