# uConsole /boot/firmware/config.txt overlay reference

On Debian 13 (trixie) / recent Raspberry Pi OS the real file is
`/boot/firmware/config.txt`. `/boot/config.txt` is just a stub that says the file
moved — editing it does nothing.

The file is split into per-model sections; only the section matching the installed
CM is applied. A CM4 uConsole uses the `[pi4]` section plus `[all]`.

## Known-good CM4 uConsole config (annotated)
```
[pi4]
dtoverlay=clockworkpi-uconsole      # the uConsole board overlay (panel, keyboard, etc.)
dtoverlay=vc4-kms-v3d-pi4,cma-384   # KMS GPU driver + 384MB CMA for the framebuffer/GPU
dtparam=spi=on                      # SPI bus (used by some HATs/expansion)
enable_uart=1                       # serial console on GPIO
dtparam=pciex1                      # PCIe x1 lane (CM4 has one; used by expansion/NVMe)

[all]
ignore_lcd=1                        # ignore the legacy LCD detection
max_framebuffers=2
disable_overscan=1
dtparam=audio=on                    # enable onboard audio
dtoverlay=audremap,pins_12_13       # route PWM audio to GPIO 12/13 (uConsole speaker/jack)
dtoverlay=dwc2,dr_mode=host         # USB in host mode
dtparam=ant2                        # select the external/second WLAN+BT antenna (important on uConsole)
```

Notes:
- `[pi3]` uses `clockworkpi-uconsole-cm3`; `[pi5]` uses `clockworkpi-uconsole-cm5`
  and `kernel=kernel8.img`. Only touch the section for the CM you actually have.
- DO NOT add `display_rotate=` here for the DSI panel — under vc4-kms-v3d it's
  ignored. Rotate in the Wayland compositor instead (see SKILL.md Step 2).
- `dtparam=ant2` selects the correct antenna path — if WLAN/BT is weak, this is a
  prime suspect.
