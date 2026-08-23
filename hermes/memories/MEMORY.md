Silvan's uConsole: clockworkpi (CM4 Debian 13 trixie + CM5 NixOS SD). CM5 NixOS auf 192.168.188.203. Key-SSH from Mac, passwordless sudo. Sway > labwc. CM4 DM: greetd+gtkgreet+cage. Scale nur 1.5.
§
User (Silvan) communicates in German, wants honest caveats.
§
uConsole repo: github.com/silly82/uconsole-dotfiles at ~/uconsole-dotfiles with Sway, Waybar, greetd configs. gh CLI installed+authenticated. Nerd Font Symbols in ~/.local/share/fonts/ for waybar icons. Scale 1.25 blurry on CM4 — use 1.5 only.
§
Silvan's Mac GallifreyM1 (MBP17,1 M1/16GB macOS 27.0 arm64). Determinate Nix + nix-darwin + home-manager + nix-homebrew. Flake ~/nixos-config#GallifreyM1. Aliases dr/drn, hms. Install-Pref: Nix > brew.
§
ESP32 PlatformIO via ~/.pio_venv. C3 Super Mini: GPIO8 LED active LOW, USB CDC, 400KB RAM. BDRG BMS JK (0xFFE0). WLAN LarsFunk, MQTT 192.168.24.213. **USB-Reset** bei Download-Mode (boot:0x7; ioreg Espressif JTAG, kein /dev/cu.usbmodem): BOOT halten, RESET kurz, BOOT los. XIAO C6: BOOT=GPIO9. arduino-cli Pfad in USER-Profil.
§
TrueNAS server 192.168.188.20 with truenas_admin user (SSH key‑based access). Apps run as 'apps' (UID 568). After group changes, restart app. Use chmod 2770 for group inheritance.
§
Dreamhost silly82@pdx1-shared-a1-13 = bristenblick.ch (+~10 weitere Domains als Dirs unter $HOME). Hermes-SSH-Key eingerichtet. Python 3.10.12, pip --user OK. Details + alle rsync/cron/.htaccess-Pitfalls: skill dreamhost-deploy. Cam: Canon EOS 2000D, 10-min JPGs, Nacht-Langzeitbelichtung. sillyWebcamView: Prod bristenblick.ch/timelapse/, repo github.com/silly82/sillyWebcamView.
§
Bitwarden CLI installed via Nix (bw in ~/.nix-profile/bin). Configured with self‑hosted server https://vault.zwx.ch. API‑key login works; SSH‑Key type is 5; private keys redacted in CLI output.
§
Mac browsers: Safari, Safari Tech Preview, Firefox, Opera, Tor, Vivaldi. No Chrome installed — browser_navigate fails; use curl or open -a Firefox.
§
Hermes Browser Engine: Chrome funktioniert (HeadlessChrome/151.0.0.0). Safari STP MCP Server konfiguriert, aber ChromeDriver MCP scheint nicht zu funktionieren (Connection failed).
§
Standard documents directory: D:\Benutzer\wasi\Documents\
§
Der Nutzer möchte D:\Benutzer\wasi\Documents als Standard-Arbeitsverzeichnis für Dokument- und Dateiaufgaben.
