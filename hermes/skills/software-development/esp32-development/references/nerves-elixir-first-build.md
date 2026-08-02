# Nerves / Phoenix Elixir Project — First-Build Pitfalls (macOS + Nix)

Patterns from getting `mix phx.server` running for the first time on a Nerves-targeted Elixir project, with Elixir+Erlang installed via Nix (Determinate Nix 3.20.0).

## Toolchain Install (Nix preferred over brew)

```bash
nix profile add nixpkgs#elixir nixpkgs#erlang
command -v elixir  # /Users/<user>/.nix-profile/bin/elixir
elixir --version  # Elixir 1.18.x (compiled with Erlang/OTP 28)
```

`brew install elixir` works but is slower and conflicts with Nix-managed OTP versions. **Nix gives you reproducible builds.**

## Hex Bootstrap Problem

After `mix deps.get` on a Nerves project, you get:
```
** (Mix) Your project is using Nerves bootstrap but doesn't depend on Nerves.
```

**Fix:** `nerves_bootstrap` archive checks for a `nerves` dep on the host too, even if you set `targets: :rpi4`. Either:
- Remove the `targets:` filter from the `nerves` dep (simplest): `{:nerves, "~> 1.10", runtime: false}`
- Or install the archive manually: `mix archive.install hex nerves_bootstrap`

## First `mix compile` Errors (typical Nerves+Phoenix bugs)

The project compiles only after fixing these in order:

1. **`<<<` / `|||` undefined** — bitwise operators need explicit import in Elixir 1.14+:
   ```elixir
   import Bitwise
   ```
2. **`HerzSchwarmWeb.live_view/0` undefined** — Phoenix.LiveView requires a macro in the web module:
   ```elixir
   def live_view do
     quote do
       use Phoenix.LiveView, layout: {HerzSchwarmWeb.Layouts, :root}
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
3. **`Gettext` not loaded** — even if `use Gettext` is in code, the dep must be in `mix.exs`:
   ```elixir
   {:gettext, "~> 0.26"},
   ```
4. **`:telemetry_poller` undefined at boot** — `HerzSchwarmWeb.Telemetry` uses it but dep missing:
   ```elixir
   {:telemetry_poller, "~> 1.0"},
   ```
5. **Elixir operator-precedence bug in pipelines**:
   ```elixir
   # WRONG — `|>` has lower precedence than `<>`, so this parses as:
   # `"#" <> (Integer.to_string(r, 16) |> String.pad_leading(2, "0") <> ...)`
   # which fails with: `cannot pipe ... into <>, the :<> operator can only take two arguments`
   "#" <>
     Integer.to_string(r, 16) |> String.pad_leading(2, "0") <>
     Integer.to_string(g, 16) |> String.pad_leading(2, "0") <>
     Integer.to_string(b, 16) |> String.pad_leading(2, "0")

   # RIGHT — bind to local vars first
   r_hex = r |> Integer.to_string(16) |> String.pad_leading(2, "0")
   g_hex = g |> Integer.to_string(16) |> String.pad_leading(2, "0")
   b_hex = b |> Integer.to_string(16) |> String.pad_leading(2, "0")
   "#" <> r_hex <> g_hex <> b_hex
   ```
6. **Grouped handle_cast clauses** — Elixir wants all `def handle_cast/2` clauses together. If you insert a `defp` between them, you get `clauses with the same name and arity should be grouped together`. Move helpers to the bottom of the module.
7. **GenServer race with mailbox messages** — `Process.cancel_timer/1` cancels a future message, but a message already in the mailbox will still arrive. Use selective receive to drain:
   ```elixir
   defp cancel_beat_timer(state) do
     case state.beat_timer do
       nil -> state
       ref ->
         Process.cancel_timer(ref)
         receive do
           :beat_tick -> :ok
         after 0 -> :ok
         end
         %{state | beat_timer: nil}
     end
   end
   ```

## UART auto-detect for Mac Dev

`config/dev.exs` default for `/dev/ttyUSB0` doesn't work on Mac. Auto-detect:

**Important: `defp` doesn't work in config files.** Config files are loaded as scripts (not compiled modules), so `defp herz_schwarm_default_uart_device do ... end` is invisible to the `config :app, key, foo()` call below it. You get `undefined function foo/0` at config-load time, NOT at app boot. **Inline the logic at the call site:**

```elixir
config :herz_schwarm, :uart_device,
  (case System.get_env("UART_DEVICE") do
     nil ->
       cond do
         match?({:win32, _}, :os.type()) -> "COM3"
         true ->
           case Path.wildcard("/dev/cu.usbserial-*") do
             [first | _] -> first
             [] ->
               case Path.wildcard("/dev/cu.SLAB_USBtoUART") do
                 [first | _] -> first
                 [] ->
                   case Path.wildcard("/dev/cu.usbmodem*") do
                     [first | _] -> first
                     [] -> "/dev/ttyUSB0"
                   end
               end
           end
       end
     dev -> dev
   end)
```

Why `Path.wildcard` over `File.exists?`:
- `File.exists?("/dev/cu.usbserial-1410")` only matches the literal path; if the actual XIAO-ESP32 enumerates as `usbserial-1430` (different USB address), detection fails
- `Path.wildcard("/dev/cu.usbserial-*")` returns the first matching device, more robust across hot-plug events

**Order matters** — put the most-common path on top. On Mac with XIAO-ESP32C6, `cu.usbmodem*` matches first. On Waveshare ESP32-S3 with native USB, `cu.usbserial-*` is the actual path (NOT `cu.usbmodem*`).

**Override at runtime:** `UART_DEVICE=/dev/cu.usbmodem101 mix phx.server`

**Critical: plattform-spezifischer Default-Fallback.** The `[] -> "/dev/ttyUSB0"` Linux fallback works fine on Linux dev hosts but **silently returns a wrong path on macOS when no C6/S3 is attached** — and `Application.get_env` happily returns that bogus path, so the bridge starts a silent reconnect-loop on `/dev/ttyUSB0: enoent` instead of crashing loudly. Fix: plattform-spezifisch — on darwin, return `nil` from `first_found/1` and let `init/1` raise loud with a helpful message; on Linux, defaulting to `/dev/ttyUSB0` is fine.

```elixir
cond do
  match?({:win32, _}, :os.type()) -> "COM3"
  match?({:unix, :darwin}, :os.type()) ->
    first_found(["/dev/cu.usbserial-*", "/dev/cu.SLAB_USBtoUART", "/dev/cu.usbmodem*"])
    # nil if no device → init/1 raises loud
  true ->
    first_found(["/dev/ttyUSB*", "/dev/ttyACM*"]) || "/dev/ttyUSB0"
end
```

Combined with `Application.fetch_env!` (no default) or `case` with explicit `raise`, you get a clean crash with a useful message when the C6 is not connected, instead of a 30-minute reconnect-loop debugging session.

## Why `mix phx.server` and `mix run` Differ on Config

A confusing gotcha: `mix phx.server` loads `config/dev.exs` automatically; `mix run --no-start -e '...'` does NOT. If you debug-config with `mix run` you'll see `nil` for `Application.get_env` even though `mix phx.server` resolves it correctly. Use `mix phx.server` for end-to-end testing of config-resolved code, or manually run `Mix.Task.run("loadconfig", [])` after `Mix.start()` in ad-hoc elixir scripts.

`mix run` only loads `config.exs`. `mix phx.server` loads `config.exs` + `dev.exs` (or `prod.exs` / `test.exs` for the env).

## XIAO ESP32C6 vs Waveshare ESP32-S3 USB-CDC Port Names

When auto-detecting `/dev/cu.*` on macOS, the actual device path varies by chip and board:

| Board | USB-CDC path | Notes |
|-------|---------------|-------|
| XIAO ESP32C6 | `/dev/cu.usbmodem*` | Native USB-CDC, Espressif USB JTAG/serial debug unit |
| Waveshare ESP32-S3-Matrix (badge) | `/dev/cu.usbmodem*` or `/dev/cu.usbserial-*` | Native USB-CDC, varies by firmware |
| ESP32 (classic) with CH340 | `/dev/cu.usbmodem*` (e.g. `usbmodem14101`) | Most common Chinese clones |
| ESP32 with CP2102 | `/dev/cu.SLAB_USBtoUART` | Silicon Labs chip |
| ESP32 with CH340 (alt) | `/dev/cu.wchusbserial*` | WCH-IC designation |
| Linux (any) | `/dev/ttyUSB0` (CH340/CP2102) or `/dev/ttyACM0` (native USB-CDC) | No `cu.` prefix |

**Detection script for unknown board:**
```bash
ls -la /dev/cu.usbmodem* /dev/cu.usbserial-* /dev/cu.SLAB* /dev/cu.wchusbserial* 2>/dev/null
ioreg -p IOUSB -l 2>&1 | grep -B1 -A2 "Espressif" | grep -E "idVendor|idProduct|USB Serial Number"
# If idProduct=0x1001 → ROM bootloader, no serial port will appear
# If idProduct=0x1002+ → running app, /dev/cu.usbmodem* should exist
```

## Mix.lock + .gitignore

`mix.lock` is **gitignored** by default. For reproducible builds, force-track it:
```gitignore
# Allow mix.lock in repo
!mix.lock
```

## Nerves Build for rpi4 (Production)

```bash
export MIX_TARGET=rpi4
mix deps.get
mix firmware    # → ./_build/rpi4/dev/nerves/images/herz_schwarm.fw
mix burn        # writes to SD card
```

On Mac dev, never set `MIX_TARGET=rpi4` — compilation will try to cross-compile to aarch64 Linux and fail. Default host target is fine for `mix phx.server`.

## Exponentially-Backed Reconnect (don't log spam)

Default 2s reconnect on bridge-detect failure floods logs forever:
```elixir
@reconnect_ms_initial 2_000
@reconnect_ms_max 30_000

defp next_backoff(current), do: min(current * 2, @reconnect_ms_max)

def handle_info(:connect, state) do
  # ...try connect, on failure:
  schedule_reconnect(%{state | reconnect_ms: next_backoff(state.reconnect_ms)})
end

# On successful connect, reset:
{:noreply, %{state | uart_pid: pid, connected: true, reconnect_ms: @reconnect_ms_initial}}
```

## LiveView "Bridge not connected" Self-Heal

A `pong` from the bridge implies the bridge is alive. Don't wait for an explicit `:connected` event — set `bridge_connected: true` on pong too:
```elixir
def handle_info({:bridge, %{"evt" => "pong"} = pong}, state) do
  state = %{state | bridge_connected: true, peer_count: pong["peers"] || 0, last_pong: pong}
  broadcast_status(state)
  {:noreply, state}
end
```

## Pitfall Summary (Nerves+Elixir 1.18+OTP28)

1. `nerves_bootstrap` requires `nerves` dep on host too — drop `targets: :rpi4` from the `nerves` line in `mix.exs`
2. `import Bitwise` for `<<<` and `|||`
3. `Phoenix.LiveView` requires a `live_view/0` macro in the web module
4. `gettext` and `telemetry_poller` are not transitively included by `phoenix` — add explicitly
5. `<>` and `|>` don't mix in expressions — bind to local vars
6. Group `handle_cast` clauses — put helpers at the bottom of the module
7. `Process.cancel_timer/1` doesn't drain already-queued messages — use selective receive
8. Default UART path `/dev/ttyUSB0` doesn't exist on Mac — auto-detect with `Path.wildcard` (or use env var)
9. **Don't set `MIX_TARGET=rpi4` on Mac dev** — only for production firmware builds
10. Reset reconnect backoff on success — otherwise logs spam after one failure
11. **`defp` is invisible in `config/*.exs`** — config files are loaded as scripts, not modules. Inline the logic or use `defmodule ... do def ... end` (with explicit module name) if you need a helper. Don't put a `defp` above a `config :app, key, defp_result()` call.
12. **`mix run` does NOT load `dev.exs`** — only `mix phx.server` does. To test config resolution in a one-off script, use `mix phx.server` or manually `Mix.Task.run("loadconfig", [])` after `Mix.start()`.
13. **XIAO ESP32C6 stays in ROM bootloader after `arduino-cli upload`** — the C6 doesn't auto-reset like S3 does. After upload, manually reset (BOOT+RESET sequence or USB cycle) to get the running app's CDC-ACM port to appear at `/dev/cu.usbmodem*`. Detection: `ioreg` shows `idProduct=0x1001` (ROM) vs `0x1002+` (running app).
14. **Plattform-spezifischer UART-Default-Fallback (`/dev/ttyUSB0`)** — siehe Pitfall 8. Auf macOS ohne angeschlossenes C6 fällt `Path.wildcard` auf `[]`, der finale `"/dev/ttyUSB0"`-Fallback ist ein Linux-Pfad, der auf Mac nicht existiert — Bridge reconnectet endlos statt loud zu crashen. Fix: `cond` mit `match?({:unix, :darwin}, :os.type())` und `nil`-return (kein Linux-Fallback) auf Mac; auf Linux ist `ttyUSB0` OK.
