# Common ePaper + Touch Driver Reference

## Waveshare RP2350-Touch-ePaper-1.54

**All-in-One Board:** RP2350A + 1.54" ePaper (EPD_1in54_V2) + FT6336U Touch (I2C) + SHTC3 (temp/hum) + PCF85063 (RTC) + ES8311 (audio) + ADC battery

### Pinout

| Component | Signal | GPIO | Notes |
|-----------|--------|------|-------|
| **ePaper** | CS | GP9 | SPI1 |
| | SCK | GP10 | SPI1 SCK |
| | MOSI | GP11 | SPI1 TX |
| | DC | GP12 | 0=cmd, 1=data |
| | PWR | GP13 | **active-LOW** — 0=ON, 1=OFF |
| | RST | GP14 | Active-low reset |
| | BUSY | GP15 | Input, 1=busy |
| | | | |
| **Touch FT6336U** | SDA | GP6 | I2C1 data (shared with SHTC3) |
| | SCL | GP7 | I2C1 clock (shared with SHTC3) |
| | INT | GP8 | Interrupt (active-low) |
| | RST | GP16 | Active-low reset |
| | | | |
| **SHTC3** (temp/hum) | SDA | GP6 | I2C1, addr 0x70 |
| | SCL | GP7 | |
| | | | |
| **PCF85063** (RTC) | SDA | GP6 | I2C1, addr 0x51 |
| | SCL | GP7 | |
| | | | |
| **ES8311** (audio) | SDA | GP6 | I2C1, addr 0x18 |
| | SCL | GP7 | |
| | | | + PIO I2S (see audio section) |
| **Other** | LED | GP25 | Onboard, active-low (0=on) |
| | BAT_ADC | GP29 | ADC channel 3 |
| | BAT_EN | GP28 | Enable battery ADC |
| | POWER_KEY | GP24 | Power button input |

### Quickstart Build (nix shell on macOS)

```bash
# Einmalig: SDK 2.2.0+ klonen (2.0.0 bootet NICHT auf RP2350!)
git clone --depth 1 --branch 2.2.0 https://github.com/raspberrypi/pico-sdk.git
cd pico-sdk && git submodule update --init
cd ..

# Projekt bauen via nix shell
cat > build.sh << 'EOF'
#!/usr/bin/env bash
set -e
export PICO_SDK_PATH=/path/to/pico-sdk
export CMAKE_POLICY_VERSION_MINIMUM=3.5
cd /path/to/LarsMiniTouch
mkdir -p build && cd build
cmake -DPICO_SDK_PATH=$PICO_SDK_PATH -DPICO_BOARD=pico2 -DCMAKE_BUILD_TYPE=Debug ..
make -j4
EOF
chmod +x build.sh

nix shell nixpkgs#cmake nixpkgs#gcc-arm-embedded -c ./build.sh
```

### pico_sdk_import.cmake

From the SDK:
```bash
curl -sL https://raw.githubusercontent.com/raspberrypi/pico-sdk/2.2.0/external/pico_sdk_import.cmake > pico_sdk_import.cmake
```

### CMakeLists.txt essentials

```cmake
target_link_libraries(my-project PRIVATE
    pico_stdlib
    hardware_spi          # for display
    hardware_i2c          # for touch + sensors
    hardware_adc          # for battery ADC
    hardware_pwm          # for backlight (optional)
    hardware_clocks       # for sys clock config
)

# Waveshare lib files (from GitHub repo):
add_executable(my-project
    src/main.c
    src/epaper/DEV_Config.c    # GPIO+SPI+I2C+ADC init
    src/epaper/EPD_1in54_V2.c  # 1.54" ePaper driver
    src/touch/FT6336U.c         # I2C touch driver
)

target_include_directories(my-project PRIVATE
    src/epaper
    src/touch
)
```

**For 16 MB flash (Waveshare board):**
```cmake
# in pico_post_init.cmake
pico_set_flash_size(LarsMiniTouch 16M)
```

### ePaper Driver: EPD_1in54_V2

Waveshare's own driver (custom waveform LUTs). From their GitHub repo:
```bash
git clone https://github.com/waveshareteam/RP2350-Touch-ePaper-1.54.git
```

**Init sequence:**
```c
DEV_Module_Init();          // GPIO + SPI1(4MHz) + I2C1(400kHz) + ADC + Display-Power(PWR=0)
EPD_1IN54_V2_Init();        // Custom waveform from LUT
EPD_1IN54_V2_Clear();       // Full clear to white
```

**Framebuffer:** 1bpp, 200×200 = 5000 bytes, MSB=left, 1=black

**Display modes:**

| Mode | Function | Speed | Use Case |
|------|----------|-------|----------|
| Full refresh | `EPD_1IN54_V2_Display(fb)` | 2-3s | Initial draw, major changes |
| Partial refresh | `EPD_1IN54_V2_DisplayPart(fb)` | <1s | Touch updates, dynamic content |

**Partial refresh workflow:**
```c
// 1. Full init + base image
EPD_1IN54_V2_Init();
EPD_1IN54_V2_Display(fb);              // show initial content
EPD_1IN54_V2_DisplayPartBaseImage(fb); // store as base for diff

// 2. Switch to partial mode
EPD_1IN54_V2_Init_Partial();

// 3. Fast updates
while (1) {
    // modify fb ...
    EPD_1IN54_V2_DisplayPart(fb);      // <1s refresh
}
```

### Touch Driver: FT6336U (I2C, addr 0x38)

**NOT XPT2046!** Unlike most touch ePaper boards, this board uses a capacitive touch controller over I2C.

```c
FT6336U_Init(FT6336U_Point_Mode);
uint8_t n = FT6336U_ReadState(FT6336U_FINGER_NUMBER);
if (n > 0) {
    FT6336U_Get_Point();
    uint16_t x = FT6336U.touch1_x;  // 0-200
    uint16_t y = FT6336U.touch1_y;  // 0-200
}
```

### SHTC3 Temperature/Humidity (I2C, addr 0x70)

```c
#include "SHTC3.h"

float temp, hum;
SHTC3_Init();
SHTC3_Measurement(&temp, &hum);  // temp in °C, hum in %RH
```

**Library location:** `examples/C/04_LVGL/lib/SHTC3/` in Waveshare repo.

### PCF85063 RTC (I2C, addr 0x51)

```c
#include "pcf85063.h"

struct tm now_tm;
pcf85063_init();
pcf85063_get_time(&now_tm);  // fills tm_sec, tm_min, tm_hour, tm_mday, tm_mon, tm_year

// Set time:
pcf85063_set_time(&now_tm);
```

**Library location:** `examples/C/04_LVGL/lib/PCF85063/` in Waveshare repo.

### ES8311 Audio Codec (I2C + PIO I2S)

The ES8311 communicates via I2C for control and uses PIO-based I2S for audio data.

```c
#include "es8311.h"
#include "audio_pio.h"

pico_audio_t pico_audio;
pico_audio_init(&pico_audio);
es8311_init(pico_audio);
es8311_voice_volume_set(80);
```

**Library locations:**
- `lib/audio/es8311/` — ES8311 I2C control
- `lib/audio/audio_pio/` — PIO I2S driver
- `lib/audio/audio_data/` — Audio data buffers

**Pitfalls:**
- PIO I2S needs PIO program loaded at init
- Requires audio data files (WAV converted to C arrays)
- Speaker needs PA_CTRL (GP0) enabled: `DEV_PA_Ctrl()`

### Battery ADC

```c
#include "hardware/adc.h"
adc_init();
adc_gpio_init(29);        // BAT_ADC_PIN
adc_select_input(3);       // BAT_CHANNEL
uint16_t raw = adc_read();  // 0-4095 = 0-3.3V

// Enable battery measurement:
gpio_init(28);              // BAT_EN_PIN
gpio_set_dir(28, GPIO_OUT);
gpio_put(28, 1);            // enable
```

### Debug Workflow: LED Before Init

When the board boots but display stays blank, confirm the chip is running:
```c
gpio_init(PICO_DEFAULT_LED_PIN);
gpio_set_dir(PICO_DEFAULT_LED_PIN, GPIO_OUT);
for (int i = 0; i < 3; i++) {
    gpio_put(PICO_DEFAULT_LED_PIN, 0); sleep_ms(200);
    gpio_put(PICO_DEFAULT_LED_PIN, 1); sleep_ms(200);
}
// → LED blinkt 3× → Chip läuft, Problem im Peripherie-Code
```

### Pico SDK Version Requirement

⚠️ **SDK 2.2.0+ is REQUIRED for RP2350!**

SDK 2.0.0: UF2 wird vom Bootloader akzeptiert (Laufwerk verschwindet), aber **Firmware startet nicht**. Keine LED. Der RP2350 erscheint tot.

Waveshare verwendet SDK 2.2.0 für alle C-Beispiele.

### One-Liner: Waveshare pre-built UF2 flashen (Hardware-Test)

```bash
git clone --depth 1 https://github.com/waveshareteam/RP2350-Touch-ePaper-1.54.git
cp RP2350-Touch-ePaper-1.54/firmware/C/03_GUI.uf2 /Volumes/RP2350/
```

Läuft die GUI-Demo → Hardware OK, SDK-Version ist das Problem.

### Pitfalls

- **PWR pin active-LOW:** GP13=0 → display ON. `DEV_Module_Init()` setzt das automatisch.
- **SPI1, not SPI0:** Standard Pico SPI-Pins (GP16-19) sind hier falsch.
- **FT6336U capacitive, NOT resistive:** Kein XPT2046. Touch über I2C (GP6-7), nicht SPI.
- **LED active-low:** `gpio_put(25, 0)` = an.
- **16 MB Flash:** Standard Pico 2 hat 4 MB. `pico_set_flash_size(my-project 16M)` setzen.
- **BUSY hang:** `EPD_1IN54_V2_ReadBusy()` looped ewig wenn BUSY nie LOW wird. Timeout einbauen:
  ```c
  // Mod in EPD_1IN54_V2.c:
  static void EPD_1IN54_V2_ReadBusy(void) {
      uint32_t timeout = 100000;
      while(DEV_Digital_Read(LCD_BUSY_PIN) == 1 && --timeout)
          DEV_Delay_ms(1);
      if (!timeout) printf("EPD: BUSY timeout!\n");
  }
  ```
- **cp xattr warning:** `cp: could not copy extended attributes` — ignorieren, Datei wurde trotzdem kopiert (FAT16 Volumen).
- **Full refresh ist langsam (2-3s):** Für Touch-Interaktionen `EPD_1IN54_V2_Init_Partial()` + `EPD_1IN54_V2_DisplayPart()` verwenden.

---

## Generic 1.54" 200×200 ePaper (SSD1681)

For generic Pico 2 + separate ePaper module (not Waveshare all-in-one).

### Pinout

| Signal | GPIO | Notes |
|--------|------|-------|
| BUSY | GP14 | Input, 1=busy |
| RST | GP15 | Active-low |
| DC | GP16 | 0=cmd, 1=data |
| CS | GP17 | Active-low |
| SCK | GP18 | SPI0 SCK |
| MOSI | GP19 | SPI0 TX |

### SSD1681 Init

```c
epd_write_cmd(0x12);              // SW_RESET
epd_write_cmd(0x01);              // DRIVER_OUTPUT_CONTROL
epd_write_data((HEIGHT-1) & 0xFF);
epd_write_data(((HEIGHT-1) >> 8) & 0xFF);
epd_write_data(0x00);
epd_write_cmd(0x11);              // DATA_ENTRY_MODE → 0x03
epd_write_cmd(0x3C);              // BORDER_WAVEFORM → 0x05
epd_write_cmd(0x18);              // TEMPERATURE_CONTROL → 0x80
epd_write_cmd(0x2C);              // WRITE_VCOM → 0x28
```

### Full Refresh

```c
epd_write_cmd(0x24);  // WRITE_RAM_BW
// send 5000 bytes framebuffer
epd_write_cmd(0x26);  // WRITE_RAM_RED (send 0x00 for B/W)
epd_write_cmd(0x22);  // DISPLAY_UPDATE_CTRL_2 → 0xF7
epd_write_cmd(0x20);  // MASTER_ACTIVATION
// wait BUSY low (with timeout!)
```

### Framebuffer

- 1bpp, 200×200 = 5000 bytes
- 1=black, 0=white
- MSB=leftmost pixel

## XPT2046 Touch Controller (generic resistive touch)

Use when you have a separate resistive touch panel (not the Waveshare all-in-one board).

### Pinout

| Signal | GPIO | Notes |
|--------|------|-------|
| CS | GP13 | Active-low |
| SCK | GP10 | SPI1 SCK |
| MOSI | GP11 | SPI1 TX |
| MISO | GP12 | SPI1 RX |
| IRQ | GP22 | Active-low, 0=touched |

### Commands

- X position: `0xD0` → 12-bit ADC
- Y position: `0x90` → 12-bit ADC

### Averaging

Read 4 samples, discard min+max, average middle 2.

### Calibration

```c
px = (rx - x_min) * WIDTH  / (x_max - x_min);
py = (ry - y_min) * HEIGHT / (y_max - y_min);
// Default: 200-3800 range
```