config.load_autoconfig(False)

_cheatsheet = "file:///home/silly82/.config/qutebrowser/cheatsheet.html"
c.url.start_pages  = [_cheatsheet]
c.url.default_page = _cheatsheet

# --- Display: uConsole CM5, DSI-2, scale 2.0 → ~960×240 logisch ---

c.zoom.default = "100%"
c.scrolling.smooth = True
c.scrolling.bar = "never"

# Tabs nur bei mehreren Tabs anzeigen — spart ~25px Höhe
c.tabs.show = "multiple"
c.tabs.position = "top"
c.tabs.title.format = "{index}: {current_title}"
c.tabs.title.format_pinned = "{index}"

# Statusleiste nur im aktiven Modus (Command, Insert) — spart ~20px
c.statusbar.show = "in-mode"

# Dark Mode für Webseiten
config.set("colors.webpage.darkmode.enabled", True)
config.set("colors.webpage.darkmode.policy.images", "never")
config.set("colors.webpage.preferred_color_scheme", "dark")

# --- Fonts ---
c.fonts.default_family = ["Iosevka", "monospace"]
c.fonts.default_size = "12pt"
c.fonts.tabs.selected = "10pt Iosevka"
c.fonts.tabs.unselected = "10pt Iosevka"
c.fonts.statusbar = "10pt Iosevka"
c.fonts.completion.entry = "11pt Iosevka"
c.fonts.completion.category = "bold 11pt Iosevka"
c.fonts.hints = "bold 10pt Iosevka"

# --- Farben: uConsole Sway-Theme ---
bg       = "#0d0d0d"
bg2      = "#1a0a1e"
fg       = "#ffb8d0"
accent   = "#ff2a6d"
purple   = "#ff00ff"
cyan     = "#00ffcc"
green    = "#00ff41"
red      = "#ff0066"
gray     = "#404040"
white    = "#ffffff"

c.colors.tabs.bar.bg             = bg
c.colors.tabs.selected.odd.bg    = bg2
c.colors.tabs.selected.odd.fg    = fg
c.colors.tabs.selected.even.bg   = bg2
c.colors.tabs.selected.even.fg   = fg
c.colors.tabs.odd.bg             = bg
c.colors.tabs.odd.fg             = gray
c.colors.tabs.even.bg            = bg
c.colors.tabs.even.fg            = gray
c.colors.tabs.indicator.start    = accent
c.colors.tabs.indicator.stop     = cyan
c.colors.tabs.indicator.error    = red
c.colors.tabs.pinned.selected.odd.bg  = bg2
c.colors.tabs.pinned.selected.odd.fg  = fg
c.colors.tabs.pinned.selected.even.bg = bg2
c.colors.tabs.pinned.selected.even.fg = fg
c.colors.tabs.pinned.odd.bg      = bg
c.colors.tabs.pinned.odd.fg      = gray
c.colors.tabs.pinned.even.bg     = bg
c.colors.tabs.pinned.even.fg     = gray

c.colors.statusbar.normal.bg     = bg
c.colors.statusbar.normal.fg     = accent
c.colors.statusbar.command.bg    = bg
c.colors.statusbar.command.fg    = fg
c.colors.statusbar.insert.bg     = bg2
c.colors.statusbar.insert.fg     = cyan
c.colors.statusbar.passthrough.bg = bg2
c.colors.statusbar.passthrough.fg = purple
c.colors.statusbar.url.fg        = fg
c.colors.statusbar.url.success.http.fg  = green
c.colors.statusbar.url.success.https.fg = cyan
c.colors.statusbar.url.error.fg  = red
c.colors.statusbar.url.warn.fg   = "#ffd700"
c.colors.statusbar.url.hover.fg  = purple
c.colors.statusbar.progress.bg   = accent

c.colors.completion.fg           = [fg, fg, fg]
c.colors.completion.odd.bg       = bg
c.colors.completion.even.bg      = bg2
c.colors.completion.category.fg  = accent
c.colors.completion.category.bg  = bg
c.colors.completion.category.border.top    = bg
c.colors.completion.category.border.bottom = bg
c.colors.completion.item.selected.bg              = bg2
c.colors.completion.item.selected.fg              = white
c.colors.completion.item.selected.border.top      = accent
c.colors.completion.item.selected.border.bottom   = accent
c.colors.completion.match.fg     = purple
c.colors.completion.scrollbar.fg = accent
c.colors.completion.scrollbar.bg = bg

c.colors.hints.bg        = accent
c.colors.hints.fg        = bg
c.colors.hints.match.fg  = white

c.colors.messages.error.bg   = red
c.colors.messages.error.fg   = white
c.colors.messages.warning.bg = "#7a4000"
c.colors.messages.warning.fg = fg
c.colors.messages.info.bg    = bg2
c.colors.messages.info.fg    = fg

c.colors.prompts.bg          = bg2
c.colors.prompts.fg          = fg
c.colors.prompts.border      = accent
c.colors.prompts.selected.bg = accent
c.colors.prompts.selected.fg = bg

c.colors.keyhint.bg          = bg2
c.colors.keyhint.fg          = fg
c.colors.keyhint.suffix.fg   = accent

# --- Keybindings ---
# Tab-Navigation
config.bind("J", "tab-prev")
config.bind("K", "tab-next")

# Schnelles Zoomen für uConsole-Display
config.bind("<Alt+=>", "zoom-in")
config.bind("<Alt+->", "zoom-out")
config.bind("<Alt+0>", "zoom")

# Reader-/Leseansicht (mehr vertikaler Platz)
config.bind(",r", "config-cycle colors.webpage.darkmode.enabled true false")

# Neue Tab-Suche
config.bind(",t", "open -t")

# Downloads
c.downloads.location.directory = "~/Downloads"
c.downloads.position = "bottom"
c.downloads.remove_finished = 5000

# Sonstiges
c.auto_save.session = False
c.content.javascript.clipboard = "access"
