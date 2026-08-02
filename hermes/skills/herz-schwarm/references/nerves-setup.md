# Nerves/Elixir Setup auf Mac — Known-Bug-Liste und Lessons

Diese Datei sammelt die **konkreten Bugs**, die beim ersten echten Mac-Setup von `herz_schwarm_nerves/` gefunden wurden (Stand: 2026-07-21, Commit `ce930d8` + Nachfolger). Jeder Eintrag zeigt Symptom → Fix → warum.

## 1. `<<<` und `|||` undefined in `effect_engine.ex`

**Symptom:**
```
error: undefined function <<</2
  112 │           (r <<< 16) ||| (g <<< 8) ||| b
```

**Ursache:** Elixir 1.14+ hat Bitwise-Operatoren, aber sie sind nicht in `Kernel` enthalten. Müssen explizit importiert werden.

**Fix:**
```elixir
use GenServer
require Logger
import Bitwise  # <<< HINZUFÜGEN
```

**Lesson:** Immer wenn man `<<<`, `>>>`, `|||`, `&&&` in Elixir benutzt, fehlt `import Bitwise`.

## 2. `HerzSchwarmWeb.live_view/0` undefined

**Symptom:**
```
** (UndefinedFunctionError) function HerzSchwarmWeb.live_view/0 is undefined
  lib/herz_schwarm_web/live/dashboard_live.ex:2:
```

**Ursache:** `dashboard_live.ex` macht `use HerzSchwarmWeb, :live_view`, aber `live_view/0` war nicht in `herz_schwarm_web.ex` definiert (nur Phoenix-Standard-Skelett, kein Phoenix-generierter Code).

**Fix in `lib/herz_schwarm_web.ex`:**
```elixir
def live_view do
  quote do
    use Phoenix.LiveView,
      layout: {HerzSchwarmWeb.Layouts, :root}
    unquote(html_helpers())
  end
end

def live_component do
  quote do
    use Phoenix.LiveComponent
    unquote(html_helpers())
  end
end
```

**Lesson:** Phoenix-`mix phx.new`-Generator erzeugt diese Macros automatisch. Bei handgeschriebenen/extrahierten Projekten fehlen sie oft.

## 3. `Gettext` module not loaded

**Symptom:**
```
error: module Gettext is not loaded
  lib/herz_schwarm_web/gettext.ex:2: use Gettext, otp_app: :herz_schwarm
```

**Ursache:** Phoenix 1.7+ braucht `:gettext` als explizite Dependency. War in `mix.exs` nicht gelistet.

**Fix in `mix.exs`:**
```elixir
{:gettext, "~> 0.26"},
```

## 4. Nerves-Bootstrap-Error: "doesn't depend on Nerves"

**Symptom:**
```
** (Mix) Your project is using Nerves bootstrap but doesn't depend on Nerves.
```

**Ursache:** Wenn Nerves-Bootstrap-Archiv installiert ist, prüft es, ob `:nerves` als Dep im `mix.exs` steht. Mit `targets: :rpi4` ist Nerves auf dem Mac-Dev-Host (`MIX_TARGET=host`) **nicht** in den deps, Bootstrap meckert.

**Fix:** `targets: :rpi4` entfernen, sodass Nerves auch auf host geladen wird (aber nichts tut):
```elixir
{:nerves, "~> 1.10", runtime: false},  # kein targets: :rpi4
{:nerves_system_rpi4, "~> 1.27", targets: :rpi4},  # bleibt
```

**Lesson:** Auch wenn Nerves nur auf rpi4 zielt, muss `{:nerves, ...}` selbst auf jedem Target verfügbar sein, sonst greift der Bootstrap-Check.

## 5. `:telemetry_poller` not found beim App-Start

**Symptom:**
```
** (EXIT) The module :telemetry_poller was given as a child to a supervisor but it does not exist
```

**Ursache:** `telemetry_poller` wird in `HerzSchwarmWeb.Telemetry` als Child benutzt, war aber nicht in `mix.exs`.

**Fix:**
```elixir
{:telemetry_poller, "~> 1.0"},
```

**Lesson:** Phoenix-1.7-Telemetry-Template bringt telemetry_poller **nicht** automatisch als dep mit. Muss explizit gelistet werden.

## 6. `color_to_hex/1` Operator-Precedence

**Symptom:**
```
** (ArgumentError) cannot pipe ("#" <> Integer.to_string(r, 16)) |> ... into String.pad_leading(2, "0") <> Integer.to_string(b, 16)
  the :<> operator can only take two arguments
```

**Ursache:** `|>` hat höhere Precedence als `<>`. Der Code war:
```elixir
"#" <>
  Integer.to_string(r, 16) |> String.pad_leading(2, "0") <>   # pipe bindet nur an pad_leading, <> rechts davon war nicht in der Pipe
  ...
```

**Fix:** Jedes Pipe-Result in eigene Variable:
```elixir
defp color_to_hex({r, g, b}) do
  r_hex = r |> Integer.to_string(16) |> String.pad_leading(2, "0")
  g_hex = g |> Integer.to_string(16) |> String.pad_leading(2, "0")
  b_hex = b |> Integer.to_string(16) |> String.pad_leading(2, "0")
  "#" <> r_hex <> g_hex <> b_hex
end
```

**Lesson:** Bei Kombination `<>` + `|>` immer Klammern oder Zwischen-Variablen. Faustregel: `|>` immer links von allem `<>` halten.

## 7. `handle_cast` Grouping-Warning

**Symptom:**
```
warning: clauses with the same name and arity (number of arguments) should be grouped together
"def handle_cast/2" was previously defined (lib/herz_schwarm/effect_engine.ex:105)
  165 │   def handle_cast(:tap_beat, state) do
```

**Ursache:** `defp cancel_beat_timer` zwischen `handle_cast` für `:set_bpm` und `handle_cast` für `:tap_beat` durchbrochen. Elixir will alle `handle_cast` zusammen.

**Fix:** Helper ans Ende verschieben, nach allen `handle_cast`/`handle_info`-Blöcken.

**Lesson:** In Elixir ist `def`-Reihenfolge innerhalb eines Moduls Stil-Konvention: alle Pattern-Matches desselben Funktionsnamens zusammen, dann Helper. Compiler-Warning ist ein starker Hinweis.

## 8. Hex-Archiv inkompatibel mit neuem OTP 28

**Symptom:**
```
error: please re-compile this module with an Erlang/OTP 28 compiler
```

**Ursache:** Alte Hex-Archiv-`.ez`-Dateien sind mit älterem OTP kompiliert. Nach Nix-Profile-Update auf OTP 28 inkompatibel.

**Fix:**
```bash
mix local.hex --force
mix local.rebar --force
mix archive.install hex nerves_bootstrap
```

**Lesson:** Nach jeder Erlang/OTP-Version-Update: `mix local.hex --force` und `mix local.rebar --force` laufen lassen, sonst Crash beim ersten Mix-Start.

## 9. Config-Warning: quoted keyword ohne Notwendigkeit

**Symptom:**
```
warning: found quoted keyword "usb0" but the quotes are not required
```

**Ursache:** `config :nerves_network, :ifname, "usb0": [mode: :dhcpd]` — `"usb0"` ist als Atom nutzlos gequotet.

**Fix:**
```elixir
config :nerves_network, :ifname,
  usb0: [mode: :dhcpd]
```

**Lesson:** Keywords (`name:`) sind immer Atoms; Quotes nur wenn Zeichen keine alphanumerischen/underscore-Zeichen sind. `"usb0"` braucht keine Quotes, `:usb0` schon gar nicht.

## 10. Phoenix `0.0.0.0:4000` nicht erreichbar auf Mac

**Symptom:** `mix phx.server` läuft, loggt "Access at http://localhost", aber `curl http://127.0.0.1:4000/` → Connection refused.

**Status:** Nicht gelöst in dieser Session (Tool-Limit erreicht). Vermutlich Bandit-spezifisch oder Mac-Sandboxing.

**Workaround für nächste Session:**
- Andere Ports testen (z. B. 4001, 8080)
- Phoenix-Endpoint-Config explizit prüfen
- `lsof -nP -iTCP:<port>` direkt nach `mix phx.server`-Start
- Eventuell `{:http, [ip: {127, 0, 0, 1}, port: 4000]}` statt `{0, 0, 0, 0}`

## 11. `pause()`-Bug im TUI-E2E-Test

**Symptom:** `printf '1\n\n4\nq\n' | python3 scripts/flash_gui.py` — die `4` wird **nicht** als Menü-Auswahl erkannt.

**Ursache:** `pause()` (= `input("Weiter mit Enter…")`) liest zeilenweise aus stdin. Bei `1\n\n4\n`:
- `1\n` → Menü-Auswahl = "1" (Ports scannen)
- `\n` → Pause-Eingabe = "" (Enter)
- `4\n` → nächste `input()`-Eingabe

Sollte funktionieren — **aber** wenn die Pause-Prompt erst nach `pause()` ausgegeben wird, **wenn das Menü schon gerendert ist**, kann das `\n` für die `pause()` und `4` für die Menü-Eingabe verwechselt werden.

**Fix (im Test-Skript, nicht im Code):**
- Ein zusätzliches `\n` einfügen: `printf '1\n\n1\n4\nq\n'` — das `1` ist die Pause-Bestätigung
- Oder `pause()` umbauen: nur Enter konsumieren, ohne Anzeige, dann zum Menü zurück

**Lesson:** E2E-Tests von TUI via stdin sind fragil. Jede `input()`-Pause schluckt eine Zeile. Test-Skripte müssen die genaue Reihenfolge der `input()`-Aufrufe kennen.

## 12. Heisen-Bug: `pause()` zwischen Aktionen

Generelles Pattern: **jede `pause()` im TUI ist ein `input()`, das im Test eine Zeile schluckt.** Bei E2E-Tests:
1. Liste alle `input()`-Aufrufe in Code-Reihenfolge
2. Liste alle `input()`-Aufrufe aus `pause()`-Statements
3. Test-Script-`printf` muss exakt diese Reihenfolge + Anzahl haben
4. Sonderzeichen (`'`, Backticks) escapen oder echo-statement statt printf

## 13. Mix-Projekt-Warnings: `@all_targets unused`

**Symptom:**
```
warning: module attribute @all_targets was set but never used
```

**Ursache:** `@all_targets [:rpi4]` wurde definiert, aber alle Vorkommen direkt auf `:rpi4` umgestellt.

**Fix:** Variable löschen, nicht nur die Vorkommen umstellen.

**Lesson:** Nach großen Refactors (wie der Mac-Compatibilität) prüfen, ob Helper-Variablen noch referenziert werden.

## 14. `aliases/0` ist false-positive Warning

**Symptom:**
```
warning: function aliases/0 is unused
  defp aliases do
```

**Ursache:** Der Mix-Compiler warnt vor ungenutzten privaten Funktionen, **aber** `aliases/0` wird über das `aliases:`-Feld in `project/0` referenziert, was der Compiler nicht sieht.

**Fix:** Keiner — Warning ignorieren. Alternative: `def` (öffentlich) statt `defp`.

**Lesson:** Einige Mix-Compiler-Warnings sind false positives. Verifizieren, ob die Funktion wirklich tot ist, bevor man etwas ändert.

## 15. Nix statt brew auf GallifreyM1

**Lektion:** Determinate Nix 3.20.0 ist installiert und schnell genug für Tool-Installation:
```bash
nix profile add nixpkgs#elixir nixpkgs#erlang
# Erlang 28.5.0.3 + Elixir 1.18.4
# Binaries unter ~/.nix-profile/bin/
```

`brew install elixir` wurde abgebrochen (zu langsam). Nix war deutlich schneller.

**Pattern für zukünftige Sessions:** Bei Tooling-Setup auf GallifreyM1 immer `nix profile add` versuchen, bevor `brew install` läuft.
