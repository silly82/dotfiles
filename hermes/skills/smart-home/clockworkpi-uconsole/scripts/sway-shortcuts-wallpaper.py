#!/usr/bin/env python3
"""
Generate a dark-themed Sway shortcut cheatsheet wallpaper for the uConsole.

Creates a 1280x720 PNG at ~/.config/sway/wallpaper.png with all relevant
keybindings, then updates Sway config to use it as background.

Usage:
    python3 /path/to/sway-shortcuts-wallpaper.py
    # Then reload Sway: $mod+Shift+C

Requirements: python3-pil (Pillow), any bold + regular TTF font.

Layout: Two columns, double-size font (22pt text, 26pt headings, 44pt title).
Optimised for the uConsole's small DSI display (853x480 effective with scale 1.5).
"""

from PIL import Image, ImageDraw, ImageFont
import os

W, H = 1280, 720
BG = "#1e1e2e"
FG = "#cdd6f4"
ACCENT = "#89b4fa"
HEADING = "#a6e3a1"
DIM = "#6c7086"

OUT = os.path.expanduser("~/.config/sway/wallpaper.png")

img = Image.new("RGB", (W, H), BG)
draw = ImageDraw.Draw(img)

# ── Fonts — double size ─────────────────────────────────────────────────
# Try common Debian font paths; fall back to any Bold/Regular pair.
fbold_paths = [
    "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
    "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf",
    "/usr/share/fonts/truetype/noto/NotoSans-Bold.ttf",
]
freg_paths = [
    "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
    "/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf",
    "/usr/share/fonts/truetype/noto/NotoSans-Regular.ttf",
]

for paths in [fbold_paths, freg_paths]:
    for p in paths:
        if os.path.exists(p):
            paths[0] = p
            break
    if not os.path.exists(paths[0]):
        for root, dirs, files in os.walk("/usr/share/fonts/truetype/"):
            for f in files:
                if "Bold" in f and f.endswith(".ttf") and paths is fbold_paths:
                    paths[0] = os.path.join(root, f)
                    break
                elif f.endswith(".ttf") and "Regular" in f and paths is freg_paths:
                    paths[0] = os.path.join(root, f)
                    break

title_font = ImageFont.truetype(fbold_paths[0], 44)
h_font = ImageFont.truetype(fbold_paths[0], 26)
text_font = ImageFont.truetype(freg_paths[0], 22)
dim_font = ImageFont.truetype(freg_paths[0], 16)

# ── Layout: two columns ─────────────────────────────────────────────────
col1_x = 40
col2_x = 660
line_h = 32

# Title
draw.text((W // 2, 30), "Sway Shortcuts  —  $mod = Linke Alt", fill=ACCENT,
          font=title_font, anchor="mt")

sections_left = [
    ("Fenster & Navigation", [
        ("$mod + Enter", "Terminal (foot)"),
        ("$mod + D", "App-Launcher (fuzzel)"),
        ("$mod + Shift+Q", "Fenster schliessen"),
        ("$mod + F", "Vollbild"),
        ("$mod + V / B", "Vertikal / Horizontal"),
        ("$mod + S / W", "Stacking / Tabs"),
        ("$mod + Shift+Space", "Floating umschalten"),
    ]),
    ("Fokus & Verschieben", [
        ("$mod + h/j/k/l", "Fokus (links/runter/hoch/rechts)"),
        ("$mod + Pfeiltasten", "Fokus (alternativ)"),
        ("$mod + Shift+h/j/k/l", "Fenster verschieben"),
        ("$mod + Shift+Pfeile", "Fenster verschieben (alt)"),
    ]),
    ("Resize", [
        ("$mod + R", "Resize-Modus"),
        ("  h/j/k/l", "Grosse anpassen"),
        ("  Escape", "Modus verlassen"),
    ]),
]

sections_right = [
    ("Workspaces", [
        ("$mod + 0-9", "Workspace wechseln"),
        ("$mod + Shift+0-9", "Fenster zu WS verschieben"),
        ("$mod + minus", "Scratchpad"),
    ]),
    ("System", [
        ("$mod + Shift+C", "Config neuladen"),
        ("$mod + Shift+E", "Sway beenden"),
    ]),
]


def draw_section(x, y, title, items):
    draw.text((x, y), title, fill=HEADING, font=h_font)
    y += 36
    for key, desc in items:
        indent = x + 20 if key.startswith("  ") else x
        draw.text((indent, y), f"{key.strip()}  {desc}", fill=FG, font=text_font)
        y += line_h
    return y


y = 95
for title, items in sections_left:
    y = draw_section(col1_x, y, title, items)
    y += 16

y = 95
for title, items in sections_right:
    y = draw_section(col2_x, y, title, items)
    y += 16

# Footer
draw.text((W - 25, H - 25), "uConsole CM4  ·  Sway 1.10", fill=DIM,
          font=dim_font, anchor="rs")

# ── Write ──────────────────────────────────────────────────────────────
os.makedirs(os.path.dirname(OUT), exist_ok=True)
img.save(OUT)
print(f"Wallpaper saved: {OUT}")
print("Reload Sway with $mod+Shift+C to apply.")