# Elixir / Phoenix / Nerves — Detailed Pitfalls

Companion to the main SKILL.md. Each pitfall here has the **full reproduction**, **error message**, and **detailed fix with code samples**. Cross-reference with the main file's pitfall numbers.

## Pitfall 1: Plug.Cowboy 2.9.0 crashes on Logger notices

**Reproduction:**
```bash
# Setup
mix new my_app --module MyApp
cd my_app
# Add {:plug_cowboy, "~> 2.6"} to mix.exs deps
mix deps.get
mix phx.server  # starts fine
# Wait for any :notice level log message
# (e.g. after a clean shutdown of another GenServer, or after 60s uptime)
```

**Error message:**
```
** (UndefinedFunctionError) function Plug.Cowboy.Translator.translate/4 is undefined (module Plug.Cowboy.Translator is not available)
    (plug_cowboy 2.9.0) Plug.Cowboy.Translator.translate(:debug, :notice, :report, ...)
    (logger 1.18.4) lib/logger/utils.ex:47: Logger.Utils.translate/5
    ...
```

**Why it crashes:** Plug.Cowboy 2.9.0's `Plug.Cowboy.Translator` module was rewritten for OTP 27's logger system. The `translate/4` callback was renamed to a different arity in OTP 28, but `plug_cowboy 2.9.0` still calls the old 4-arity.

**Fix (recommended for Phoenix 1.7+):** Remove `plug_cowboy` from deps entirely. Phoenix 1.7+ uses Bandit by default.

```elixir
# In mix.exs deps:
[
  # {:plug_cowboy, "~> 2.6"},  # DELETE
  {:bandit, "~> 1.0"},          # Phoenix 1.7+ default
  ...
]
```

Configure Bandit in `config.exs`:
```elixir
config :my_app, MyAppWeb.Endpoint,
  url: [host: "my-app.local"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: MyAppWeb.ErrorHTML, json: MyAppWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: MyApp.PubSub,
  live_view: [signing_salt: "myappLV"]
```

**Fix (if you must keep plug_cowboy):** Pin to a version that works with OTP 28, or apply a local patch.

**Verification:** Start the server, then trigger a `:notice` log by stopping another GenServer cleanly, e.g.:
```bash
mix phx.server &
SERVER_PID=$!
sleep 5
# Kill another app to trigger a notice
# OR: send SIGTERM to a child process
# OR: just wait 60s — periodic notices
```

If no crash in 5 minutes, you're good. Repeat the verification with `mix run --no-start` for a quick smoke test:
```bash
mix run --no-start -e 'Application.put_env(:logger, :default_handler, false); :ok = MyApp.Application.start(:normal, []); IO.puts("started"); Process.sleep(:infinity)'
```

## Pitfall 2: Nerves bootstrap check fails when `:nerves` is targets-only

**Reproduction:**
```elixir
# mix.exs
defp deps do
  [
    {:nerves, "~> 1.10", runtime: false, targets: :rpi4},  # ← targets: :rpi4
    {:nerves_system_rpi4, "~> 1.27", targets: :rpi4},
    ...
  ]
end
```

```bash
unset MIX_TARGET  # Mac dev
mix deps.get
```

**Error message:**
```
** (Mix) Your project is using Nerves bootstrap but doesn't depend on Nerves.

Please check the dependency section of your mix.exs.
```

**Why it fails:** Nerves' bootstrap archive runs a check at deps-resolve time: "does this project depend on `:nerves`?" It looks at the raw `deps` list and ignores `targets:`. So even with `targets: :rpi4`, if the Mac is the host, the check fails.

**Fix:**
```elixir
defp deps do
  [
    # NO targets: — Mac dev needs this code to compile
    {:nerves, "~> 1.10", runtime: false},
    # These are target-specific — they only make sense on rpi4
    {:nerves_system_rpi4, "~> 1.27", targets: :rpi4},
    {:nerves_runtime, "~> 0.13", targets: :rpi4},
    {:nerves_pack, "~> 0.7", targets: :rpi4},
    ...
  ]
end
```

**Why this works:** On `MIX_TARGET=host` (Mac), Nerves' compile-time code is still loaded (so the bootstrap check passes), but the target-specific deps are skipped (no rpi4 system to build for). On `MIX_TARGET=rpi4`, all are loaded.

## Pitfall 3: `defp` in `config/*.exs` files fails with `undefined function`

**Reproduction:**
```elixir
# config/dev.exs
defp herz_schwarm_default_uart_device do
  case System.get_env("UART_DEVICE") do
    nil -> "/dev/cu.usbmodem101"
    dev -> dev
  end
end

config :herz_schwarm, :uart_device, herz_schwarm_default_uart_device()
```

```bash
mix run --no-start
```

**Error message:**
```
error: undefined function herz_schwarm_default_uart_device/0 (there is no such import)
    │
 22 │ config :herz_schwarm, :uart_device, herz_schwarm_default_uart_device()
    │                                                     ^
    │
    └─ config/dev.exs:22
```

**Why it fails:** Config files are loaded as **Elixir scripts**, not as modules. `defp` defines a private function in a module, but there's no module here. The compiler sees a top-level `defp` call, which is illegal.

**Fix (inline):**
```elixir
# config/dev.exs
config :herz_schwarm, :uart_device,
  (case System.get_env("UART_DEVICE") do
     nil ->
       cond do
         match?({:win32, _}, :os.type()) -> "COM3"
         true ->
           case Path.wildcard("/dev/cu.usbserial-*") do
             [first | _] -> first
             [] -> "/dev/ttyUSB0"
           end
       end
     dev -> dev
   end)
```

**Fix (extract to module):**
```elixir
# lib/my_app/config.ex
defmodule MyApp.Config do
  def uart_device do
    case System.get_env("UART_DEVICE") do
      nil -> ...
      dev -> dev
    end
  end
end

# config/dev.exs
config :my_app, :uart_device, MyApp.Config.uart_device()
```

## Pitfall 4: `Application.get_env` with hardcoded default hides config bugs

**Reproduction:**
```elixir
# lib/my_app/bridge.ex
def init(_opts) do
  port = Application.get_env(:my_app, :uart_device, "/dev/ttyUSB0")
  {:ok, _} = UART.open(...)
  ...
end
```

```bash
# config/dev.exs
config :my_app, :uart_device, "/dev/cu.usbmodem101"
```

```bash
mix phx.server
# Output:
# [warning] Failed to open /dev/ttyUSB0: :enoent
# [debug] Reconnect scheduled in 2000ms
# ... infinite loop ...
```

**Why it fails:** `Application.get_env` with a hardcoded default is "safe but silent". If config resolution order is wrong (e.g. dev.exs hasn't loaded yet at the time of the GenServer's `init/1`), the default wins. The user has no way to know their dev.exs setting is being ignored.

**Fix:**
```elixir
def init(_opts) do
  port =
    case Application.get_env(:my_app, :uart_device) do
      nil ->
        raise """
        :my_app, :uart_device not configured.
        Set in config/dev.exs or pass UART_DEVICE=... env var to mix phx.server.
        """

      p when is_binary(p) ->
        p

      other ->
        raise ":uart_device must be a binary path, got: #{inspect(other)}"
    end

  ...
end
```

**Verification:** Run a quick behavioral test:
```bash
TEST=$(mktemp /tmp/test-init-XXXXXX.exs)
cat > "$TEST" <<'EOF'
Application.put_env(:my_app, :uart_device, nil)
try do
  MyApp.Bridge.init([])
  IO.puts("FAIL_NIL")
rescue
  e -> IO.puts("OK_NIL:" <> String.slice(Exception.message(e), 0..60))
end
EOF
mix run --no-start "$TEST" 2>&1 | grep "^OK_NIL"  # must succeed
```

## Pitfall 5: `mix phx.server` vs `mix run` vs `elixir -e` load different config

| Command | Loads `config.exs`? | Loads `dev.exs`? | Application started? |
|---------|----------------------|------------------|---------------------|
| `elixir -e "..."` | only if you call `Mix.start` + `Mix.Task.run("loadconfig", [])` | NO | NO |
| `mix run --no-start` | YES | YES (with `MIX_ENV=dev`) | NO |
| `mix phx.server` | YES | YES | YES, Phoenix-Endpoint first |

**Reproduction:**
```bash
# Test 1: bare elixir (fails)
elixir -e 'Mix.start(); IO.inspect(Application.get_env(:my_app, :key))'
# key: nil   ← dev.exs NOT loaded

# Test 2: mix run (works)
MIX_ENV=dev mix run --no-start -e 'IO.inspect(Application.get_env(:my_app, :key))'
# key: "/dev/cu.usbmodem101"  ← dev.exs loaded

# Test 3: mix phx.server (cache issue?)
mix phx.server
# ... [warning] Failed to open /dev/ttyUSB0 ...
```

**Why it differs:** Each Mix command goes through a slightly different code path. `mix phx.server` may start the application children before the full config has been resolved, leading to `init/1` running with stale or default values.

**Fix:** If `mix run` shows the right value but `mix phx.server` shows the wrong one, suspect a caching/timing issue. Solutions:

```elixir
# Option 1: Read config lazily (in a request handler, not in init/1)
def handle_call({:get_port}, _from, state) do
  port = Application.get_env(:my_app, :uart_device, raise_if_missing: true)
  {:reply, port, state}
end

# Option 2: Move dev.exs values into runtime.exs
# config/runtime.exs (runs at app start, not compile time)
if config_env() == :dev do
  config :my_app, :uart_device, resolve_uart_device()
end
```

**Verification:** Test config with the exact same command as production. If they differ, you have a caching issue.

## Pitfall 6: `Code.ensure_loaded/1` returns a 2-tuple in Elixir 1.14+

**Reproduction:**
```elixir
{:module, mod, _, _} = Code.ensure_loaded(MyMod)
```

**Error message:**
```
** (MatchError) no match of right hand side value: {:module, MyMod}
```

**Why it fails:** In Elixir 1.13 and earlier, `Code.ensure_loaded/1` returned `{:module, mod, beam, _}`. In 1.14+ (and 1.18) it returns `{:module, mod}` or `{:error, :nofile}`.

**Fix:**
```elixir
# Old (1.13)
{:module, mod, _, _} = Code.ensure_loaded(MyMod)

# New (1.14+, 1.18)
case Code.ensure_loaded(MyMod) do
  {:module, mod} -> :ok
  {:error, :nofile} -> :not_loaded
end

# Or just boolean
if Code.ensure_loaded?(MyMod), do: ...
```

**Also:** Bare `elixir` doesn't know about `_build/`, so `Code.ensure_loaded` returns `{:error, :nofile}` for any local module. Use `mix run --no-start` for behavioral tests:

```bash
mix run --no-start -e 'IO.inspect(Code.ensure_loaded(MyApp.MyMod))'
# {:module, MyApp.MyMod}

# NOT:
elixir -e 'IO.inspect(Code.ensure_loaded(MyApp.MyMod))'
# {:error, :nofile}  ← because _build/ is not in path
```

## Pitfall 7: `import Bitwise` required for `<<<` and `|||` in 1.14+

**Reproduction:**
```elixir
defmodule MyApp.EffectEngine do
  use GenServer

  def handle_cast({:trigger, mode, opts}, state) do
    ...
    beat_counter =
      case mode do
        7 -> (r <<< 16) ||| (g <<< 8) ||| b
        ...
      end
  end
end
```

**Error message:**
```
error: undefined function <<</2 (expected MyApp.EffectEngine to define such a function or for it to be imported, but none are available)
    │
112 │           (r <<< 16) ||| (g <<< 8) ||| b
    │              ^^^
```

**Why it fails:** Elixir 1.14+ moved bitwise operators to the `Bitwise` module. They're not in the default import.

**Fix:**
```elixir
defmodule MyApp.EffectEngine do
  use GenServer
  import Bitwise  # ← required

  def handle_cast({:trigger, mode, opts}, state) do
    ...
  end
end
```

Or use `use Bitwise` for the DSL:
```elixir
use Bitwise
```

## Pitfall 8: Gettext deprecation on Elixir 1.18

**Reproduction:**
```elixir
defmodule MyAppWeb.Gettext do
  use Gettext, otp_app: :my_app
end
```

**Error message (warning):**
```
warning: defining a Gettext backend by calling

    use Gettext, otp_app: ...

is deprecated. To define a backend, call:

    use Gettext.Backend, otp_app: :my_app

Then, instead of importing your backend, call this in your module:

    use Gettext, backend: MyApp.Gettext
```

**Fix:**
```elixir
defmodule MyAppWeb.Gettext do
  use Gettext.Backend, otp_app: :my_app
end
```

The old `use Gettext, otp_app: ...` still works but is deprecated. Phoenix 1.7+'s default generator already uses `Gettext.Backend`.

## Pitfall 9: Mix `aliases/0` warning when targets-only is used

**Reproduction:**
```elixir
defmodule MyApp.MixProject do
  @app :my_app
  @all_targets [:rpi4]
  ...
end
```

**Error message (warning):**
```
warning: module attribute @all_targets was set but never used
    │
  6 │   @all_targets [:rpi4]
    │   ~~~~~~~~~~~~~~~~~~~~
```

**Why it warns:** `@all_targets` is defined but never used in the module (Mix doesn't use module attributes for target detection).

**Fix (simplest):** drop the attribute, inline `:rpi4`:
```elixir
defmodule MyApp.MixProject do
  @app :my_app
  @version "0.1.0"
  # NO @all_targets
  ...
end
```

**Fix (if you need a list):** actually use it in deps:
```elixir
defp deps do
  for target <- [:rpi4] do
    [
      {:nerves_system_rpi4, "~> 1.27", targets: target},
      {:nerves_runtime, "~> 0.13", targets: target},
      ...
    ]
  end
  |> List.flatten()
end
```

## Pitfall 10: Compile-Error during Nerves bootstrap on host

**Reproduction:**
```bash
# On a different host (e.g. CI with Ubuntu)
git clone <repo>
cd herz_schwarm_nerves
mix deps.get
# Or:
unset MIX_TARGET
mix compile
```

**Error message:**
```
** (Mix) Nerves environment
  MIX_TARGET:   host
  MIX_ENV:      dev

Checking for prebuilt Nerves artifacts...
[hangs or cryptic target errors]
```

**Fix:** Wipe everything and re-resolve:
```bash
cd herz_schwarm_nerves
rm -rf _build deps
mix deps.get
mix compile
```

If still broken, check `MIX_TARGET`:
```bash
unset MIX_TARGET  # for Mac dev
echo $MIX_TARGET  # should be empty
```

## Pitfall 11: `color_to_hex` operator-precedence bug

**Reproduction:**
```elixir
defp color_to_hex({r, g, b}) do
  "#" <>
    Integer.to_string(r, 16) |> String.pad_leading(2, "0") <>
    Integer.to_string(g, 16) |> String.pad_leading(2, "0") <>
    Integer.to_string(b, 16) |> String.pad_leading(2, "0")
end
```

**Error message:**
```
** (ArgumentError) cannot pipe ("#" <> Integer.to_string(r, 16)) |> String.pad_leading(2, "0") into String.pad_leading(2, "0") <> Integer.to_string(b, 16), the :<> operator can only take two arguments
    (elixir 1.18.4) lib/macro.ex:329: Macro.pipe/3
    (stdlib 7.3) lists.erl:2466: :lists.foldl/3
```

**Why it fails:** The `<>` operator is right-associative with very high precedence, but `|>` has lower precedence. The chain parses wrong — `|>` binds to the entire left expression, not the immediate sub-expression.

**Fix (intermediate bindings):**
```elixir
defp color_to_hex({r, g, b}) do
  r_hex = r |> Integer.to_string(16) |> String.pad_leading(2, "0")
  g_hex = g |> Integer.to_string(16) |> String.pad_leading(2, "0")
  b_hex = b |> Integer.to_string(16) |> String.pad_leading(2, "0")
  "#" <> r_hex <> g_hex <> b_hex
end
```

**Fix (all parentheses):**
```elixir
defp color_to_hex({r, g, b}) do
  ("#" <>
    (r |> Integer.to_string(16) |> String.pad_leading(2, "0")) <>
    (g |> Integer.to_string(16) |> String.pad_leading(2, "0")) <>
    (b |> Integer.to_string(16) |> String.pad_leading(2, "0")))
end
```

## Pitfall 12: Dev-host UART detection needs `Path.wildcard` for multiple ports

**Reproduction:**
```elixir
# config/dev.exs
def herz_schwarm_default_uart_device do
  cond do
    File.exists?("/dev/cu.usbmodem101") -> "/dev/cu.usbmodem101"  # only matches ONE path
    File.exists?("/dev/cu.SLAB_USBtoUART") -> "/dev/cu.SLAB_USBtoUART"
    true -> "/dev/ttyUSB0"
  end
end
```

**Why it fails:** `File.exists?/1` matches an exact path only. On a Mac with multiple XIAO C6s connected, `usbmodem101` might not exist, but `usbmodem14101` does. The detection fails to find any port.

**Fix:**
```elixir
defp herz_schwarm_default_uart_device do
  case System.get_env("UART_DEVICE") do
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
  end
end
```

`Path.wildcard/1` does shell-glob expansion, so `/dev/cu.usbmodem*` matches all variants.

## Pitfall 13: Compiling from the wrong working directory

**Reproduction:**
```bash
# Wrong: you're in a subdirectory
cd my_app/apps/web/  # if it's an umbrella
mix compile
# ** (CompileError) ... cannot find module MyApp.Repo
```

**Fix:** Always `cd` into the app root:
```bash
cd my_app  # the directory with mix.exs
pwd  # verify
ls mix.exs
mix compile
```

For umbrella projects, run from the umbrella root or from each app's directory.

## Pitfall 14: `handle_cast/2` clauses scattered between `defp` helpers

**Reproduction:**
```elixir
def handle_cast({:set_bpm, 0}, state) do
  ...
end

def handle_cast({:set_bpm, bpm}, state) do
  ...
end

defp cancel_beat_timer(state) do  # ← in the middle!
  ...
end

def handle_cast(:tap_beat, state) do  # ← scattered
  ...
end
```

**Error message (warning):**
```
warning: clauses with the same name and arity (number of arguments) should be grouped together, "def handle_cast/2" was previously defined (lib/my_app/effect_engine.ex:105)
    │
165 │   def handle_cast(:tap_beat, state) do
    │       ^
```

**Why it warns:** Elixir compiler prefers all clauses of the same function to be visually grouped. It still works, but the warning is noise.

**Fix:** Put all `handle_cast/2` clauses first, then `defp` helpers:
```elixir
def handle_cast({:set_bpm, 0}, state) do
  ...
end

def handle_cast({:set_bpm, bpm}, state) do
  ...
end

def handle_cast(:tap_beat, state) do
  ...
end

def handle_cast({:set_color, r, g, b}, state) do
  ...
end

def handle_cast(:stop_all, state) do
  ...
end

@impl true
def handle_info(:beat_tick, state) do
  ...
end

# All defp helpers after all def clauses
defp cancel_beat_timer(state) do
  ...
end

defp broadcast_state(state) do
  ...
end
```

## Telemetry poller missing in 1.18+ projects

**Reproduction:**
```elixir
# lib/my_app/telemetry.ex
defmodule MyAppWeb.Telemetry do
  use Supervisor

  def init(_arg) do
    children = [
      {:telemetry_poller, measurements: periodic_measurements(), period: 10_000}
    ]
    Supervisor.init(children, strategy: :one_for_one)
  end
end
```

```bash
mix phx.server
```

**Error message:**
```
** (ArgumentError) The module :telemetry_poller was given as a child to a supervisor but it does not exist
```

**Why it fails:** `telemetry_poller` is a separate Hex package; not pulled in by Phoenix.

**Fix:** Add to `mix.exs` deps:
```elixir
{:telemetry_poller, "~> 1.0"},
```

## Summary: The 5-Minute Phoenix+Nerves Setup Checklist

```bash
# 1. Setup
nix profile add nixpkgs#elixir nixpkgs#erlang
# or brew install elixir
elixir --version  # should be 1.18+

# 2. Phoenix+Nerves deps (mix.exs)
{:phoenix, "~> 1.7"},
{:phoenix_live_view, "~> 0.20"},
{:gettext, "~> 0.26"},
{:bandit, "~> 1.0"},  # not plug_cowboy
{:telemetry_poller, "~> 1.0"},
{:nerves, "~> 1.10", runtime: false},  # NOT targets-only
{:nerves_system_rpi4, "~> 1.27", targets: :rpi4},

# 3. First run
mix deps.get
mix compile  # should be clean

# 4. Verify config loads
MIX_ENV=dev mix run --no-start -e 'IO.inspect(Application.get_env(:my_app, :some_key))'

# 5. Start
mix phx.server
# Should see: [info] Access MyAppWeb.Endpoint at http://localhost
# Should NOT see: [warning] Failed to open /dev/ttyUSB0
```

If any of these fail, check the corresponding pitfall above.
