User Silvan (silly82), German. Short practical answers. BDRG12100 BMS (R-12100BNNH19-C01278, JK protocol 0xFFE0). WLAN LarsFunk, MQTT 192.168.24.213. Boards: ESP32-C3 (zu wenig RAM), XIAO ESP32C6, Seeeduino XIAO, klassischer ESP32. PlatformIO via ~/.pio_venv.
§
User workflow: Iterative Plan→Build→Verify→Commit→Tag→Push. Akzeptiert "ja" als Bestätigung, will kurze Status-Listen, fragt oft nach Hardware-Limitation ("kein hw test"). Bei Arduino/ESP32-Projekten: pyserial + arduino-cli + esptool als Standard-Toolchain. TUI/Dashboards will er explizit von Effect-Steuerung getrennt — Effekte über MQTT/Web-UI, TUI nur für Flash-Ops. Build-Outputs (build_debug, build_batch, build_bridge, build_basestation) immer in .gitignore.
§
GallifreyM1: arduino-cli lives at `/Applications/Arduino IDE.app/Contents/Resources/app/lib/backend/resources/arduino-cli` (NOT on PATH). Any Python script that shells out to arduino-cli must include a fallback list — `shutil.which('arduino-cli')` alone returns None. See scripts/flashlib/build.py `_cli()` for the reference pattern.
§
Silvan (silly82) — bevorzugt A.B.C.D-Firmware-Versionierung (TUI = großes Feature = B-Bump, nicht C). D=BUILD ist nur in Git-Tags, NICHT im Code (sonst Neukompilation bei jedem Commit). Helper-Skript scripts/version.sh macht Tag-Management. Schema gilt ab bestehendem v1.1.0.
§
User interessiert sich für ExpressLRS, insbesondere Unterstützung älterer STM32-Hardware und den 3.x.x-maintenance-Zweig.
§
User bevorzugt technische Netzwerkübersichten als skalierbare Vektorgrafik (SVG) und PDF, mit konkreten IP-/VLAN-/Tunnelpfaden und schrittweiser Anpassung an die reale Topologie.
