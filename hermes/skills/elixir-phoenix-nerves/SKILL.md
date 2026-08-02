---
name: elixir-phoenix-nerves
description: "Build and run Phoenix 1.7+ LiveView apps on Elixir 1.18/OTP 28, especially with Nerves for embedded targets (Raspberry Pi) and Mac dev hosts. Load when starting a new Phoenix+Nerves project, when `mix compile` or `mix phx.server` misbehaves, when config files fail to load, or when `Application.get_env` returns stale values."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [macos, linux]
metadata:
  hermes:
    tags: [elixir, phoenix, liveview, nerves, embedded, configuration, otp28, build-troubleshooting]
    related_skills: [ad-hoc-verification, plan, esp32-development, systematic-debugging]
---

# Elixir / Phoenix / Nerves

Patterns and pitfalls for Phoenix 1.7+ LiveView apps on Elixir 1.18 / OTP 28, especially Nerves projects (Raspberry Pi as target, Mac as dev host).

## When to Use

- New Phoenix+Nerves project setup
- `mix compile` or `mix phx.server` errors with `undefined function` / deprecation warnings
- Nerves-bootstrap check: "Your project is using Nerves bootstrap but doesn't depend on Nerves"
- Plug.Cowboy `Translator.translate/4 undefined` on Elixir 1.18 / OTP 28
- Config files (`config/dev.exs`) returning stale or nil values
- `Application.get_env` returns hardcoded default despite dev.exs override

## Compatibility Matrix (verified 2026-Q3)

| Component | Version | Status on Elixir 1.18.4 / OTP 28 |
|-----------|----------|----------------------------------|
| Phoenix | 1.7 | ✓ works, but needs live_view/live_component macros in `herz_schwarm_web.ex` |
| Phoenix LiveView | 0.20+ | ✓ works |
| Nerves | 1.10+ | ✓ works, but bootstrap requires `:nerves` as dep (not only `targets:`) |
| Plug.Cowboy | 2.6 - 2.9.0 | ⚠️ `Plug.Cowboy.Translator.translate/4 undefined` — sporadic crash with Logger notices |
| Bandit | latest | ✓ recommended (Phoenix 1.7+ default, replaces plug_cowboy) |
| Gettext | 0.26+ | ⚠️ `use Gettext, otp_app: ...` deprecated — use `use Gettext.Backend, otp_app: :my_app` instead |
| telemetry_poller | 1.0+ | ✓ needed for `Telemetry.Poller` in `lib/*/telemetry.ex` |

## Pitfall 1: Plug.Cowboy 2.9.0 crashes on Logger notices

**Trigger:** Phoenix 1.7+ project with Elixir 1.18 / OTP 28, `plug_cowboy ~> 2.6` in `mix.exs`.

**Failure:** Sporadic `UndefinedFunctionError: function Plug.Cowboy.Translator.translate/4 is undefined`. Triggers when Logger receives a `:notice` level message (e.g. application shutdown, application_controller exit).

**Fix:** Either:
1. Remove `{:plug_cowboy, "~> 2.6"}` from `mix.exs` deps entirely (recommended for Phoenix 1.7+ which uses Bandit by default)
2. Pin to a version known to work with OTP 28 (varies)

Configure Bandit in `config.exs`:
```elixir
config :my_app, MyAppWeb.Endpoint,
  adapter: Bandit.PhoenixAdapter
```

Add `{:bandit, "~> 1.0"}` if not already there. Phoenix 1.7+ already pulls it as a transitive dep.

## Pitfall 2: Nerves bootstrap check fails when `:nerves` is targets-only

**Trigger:** `mix.exs` has:
```elixir
{:nerves, "~> 1.10", runtime: false, targets: :rpi4}
```

**Failure:** When running on `MIX_TARGET=host` (Mac dev), `mix deps.get` succeeds but the Nerves bootstrap step fails:
```
** (Mix) Your project is using Nerves bootstrap but doesn't depend on Nerves.
```

**Reason:** Nerves's bootstrap script checks if `:nerves` is a declared dep *at all*, regardless of `targets:`. Mac dev still needs to load Nerves' code to compile the project.

**Fix:** Drop the `targets: :rpi4` from `:nerves`:
```elixir
{:nerves, "~> 1.10", runtime: false},  # NOT targets: :rpi4
{:nerves_system_rpi4, "~> 1.27", targets: :rpi4},
{:nerves_runtime, "~> 0.13", targets: :rpi4},
```

Only the system/runtime/pack deps are target-specific.

## Pitfall 3: `defp` in `config/*.exs` files fails with `undefined function`

**Trigger:** Sharing logic in `config/dev.exs`:
```elixir
defp herz_schwarm_default_uart_device do
  case System.get_env("UART_DEVICE") do
    nil -> ...
    dev -> dev
  end
end

config :my_app, :uart_device, herz_schwarm_default_uart_device()
```

**Failure:** Compile-Error `undefined function herz_schwarm_default_uart_device/0`.

**Reason:** Config files are loaded as **scripts**, not as modules. `defp` defines a private function in a module — but there's no module here.

**Fix:** Inline the logic, or define the helper in a real module:

```elixir
# Inline (simplest)
config :my_app, :uart_device,
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

# Or extract to a real module
defmodule MyApp.Config do
  def uart_device do
    case System.get_env("UART_DEVICE") do
      nil -> ...
      dev -> dev
    end
  end
end
config :my_app, :uart_device, MyApp.Config.uart_device()
```

## Pitfall 4: `Application.get_env` with hardcoded default hides config bugs

**Trigger:**
```elixir
def init(_opts) do
  port = Application.get_env(:my_app, :uart_device, "/dev/ttyUSB0")
  ...
end
```

**Failure:** Bridge/GenServer components silently fall back to a wrong path. On macOS, `/dev/ttyUSB0` doesn't exist, leading to silent reconnect loops. The dev.exs `:uart_device` setting is **silently ignored** because of caching or init-time order.

**Fix (Layer 1 — fail loud):** Use explicit `case` with `raise`:
```elixir
def init(_opts) do
  port =
    case Application.get_env(:my_app, :uart_device) do
      nil ->
        raise """
        :my_app, :uart_device not configured.
        Set in config/dev.exs or pass UART_DEVICE=... env var.
        """

      p when is_binary(p) -> p

      other ->
        raise ":uart_device must be a binary, got: #{inspect(other)}"
    end

  ...
end
```

The `raise` with a clear message is **infinitely more debuggable** than a silent fallback. Tests that exercise `init/1` with `nil` config and a valid binary will catch this.

**Fix (Layer 2 — fallback resolution when Mix 1.18 timing misses dev.exs):**

Even with Layer 1, on Elixir 1.18 / OTP 28 you may hit a real timing bug: `Application.get_env/3` returns `nil` during `GenServer.init/1` even when `config/dev.exs` sets the value via `import_config` — the supervisor can start the child before `dev.exs` runs. `elixir -e 'Mix.start(); Mix.Task.run("loadconfig"); ...'` will show the right value, but `mix phx.server` will pass `nil`.

Solution: in `init/1`, fall back to inline resolution before raising:

```elixir
def init(_opts) do
  port =
    case Application.get_env(:my_app, :uart_device) do
      nil -> resolve_uart_device() || raise_uart_not_configured!()
      p when is_binary(p) -> p
      other -> raise ":uart_device must be a binary, got: #{inspect(other)}"
    end
  ...
end

# Fallback: check env-var, then Path.wildcard on common USB-serial patterns
defp resolve_uart_device do
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

defp raise_uart_not_configured! do
  raise """
  :my_app, :uart_device is not configured and no USB-serial
  device could be auto-detected.

  Fix: Set UART_DEVICE env var to your ESP32 bridge:
    UART_DEVICE=/dev/cu.usbmodem101 mix phx.server
  """
end
```

**Why this works even with the timing bug:** `Path.wildcard/1` is a direct filesystem call, not affected by Elixir's app-env resolution order. The fallback finds the C6/ESP32/CH340 device even if `dev.exs` hasn't run yet.

**Test that exercises all 3 branches:**

```elixir
test = fn label ->
  try do
    result = MyApp.Bridge.init([])
    port = case result do
      {:ok, state} -> state.port
      state when is_map(state) -> Map.get(state, :port, "?")
    end
    IO.puts("INIT_OK: " <> port)
  rescue
    e -> IO.puts("CRASH: " <> String.slice(Exception.message(e), 0..100))
  end
end

Application.put_env(:my_app, :uart_device, nil)
test.("T1: nil → Wildcard fallback")
Application.put_env(:my_app, :uart_device, "/dev/cu.usbmodem101")
test.("T2: set → App-env")
Application.put_env(:my_app, :uart_device, 42)
test.("T3: wrong type → raise")
```

Use `mix run --no-start -e '...'` not bare `elixir -e` (see Pitfall 5 for why).

## Pitfall 5: `mix phx.server` vs `mix run` vs `elixir -e` load different config

These three commands load config in different orders and contexts:

| Command | Loads `config.exs`? | Loads `dev.exs`? | Application started? |
|---------|----------------------|------------------|---------------------|
| `elixir -e "..."` | only if you call `Mix.start` + `Mix.Task.run("loadconfig", [])` | NO | NO |
| `mix run --no-start` | YES | YES (with `MIX_ENV=dev`) | NO |
| `mix phx.server` | YES | YES | YES, Phoenix-Endpoint first |

**Trigger:** You test config resolution with `elixir -e 'Mix.start(); Application.get_env(:my_app, :key) |> IO.inspect'` and see the right value. Then you run `mix phx.server` and the value is wrong (or default).

**Fix:** Always test config with the *exact same command* you'll use in production. If "right in `mix run` but wrong in `mix phx.server`", suspect a **caching/timing issue** — fix by reading the config in a request handler (lazy) or moving the dev.exs value into `runtime.exs`.

**For test scripts:** use `mix run --no-start -e '...'` not bare `elixir -e`. Bare `elixir` doesn't know about `_build/`, so `Code.ensure_loaded` returns `{:error, :nofile}` for any local module.

## Pitfall 6: `Code.ensure_loaded/1` returns a 2-tuple in Elixir 1.14+

```elixir
# BROKEN on 1.18
{:module, mod, _, _} = Code.ensure_loaded(MyMod)

# WORKS (1.14+, 1.18)
case Code.ensure_loaded(MyMod) do
  {:module, mod} -> :ok
  {:error, _} -> :not_loaded
end
```

The 4-tuple pattern was correct in Elixir 1.13. In 1.14+ it returns `{:module, mod}` or `{:error, :nofile}`. Using the old pattern triggers `MatchError`, not a clean error.

## Pitfall 7: `import Bitwise` required for `<<<` and `|||` in 1.14+

```elixir
# BROKEN
def handle_cast({:trigger, mode, opts}, state) do
  ...
  beat_counter =
    case mode do
      7 -> (r <<< 16) ||| (g <<< 8) ||| b
      ...
    end
end

# WORKS
use GenServer
import Bitwise  # ← required
```

Elixir 1.14+ moved bitwise operators to `Bitwise` module. `import Bitwise` at the top of the module, or `use Bitwise` for the DSL.

## Pitfall 8: Gettext deprecation on Elixir 1.18

```elixir
# DEPRECATED on 1.18
defmodule MyAppWeb.Gettext do
  use Gettext, otp_app: :my_app
end

# NEW
defmodule MyAppWeb.Gettext do
  use Gettext.Backend, otp_app: :my_app
end
```

The old `use Gettext, otp_app: ...` triggers a compiler warning. Fix: use `Gettext.Backend`. The change is in the new `gettext` versions (0.26+).

## Pitfall 9: Mix `aliases/0` warning when targets-only is used

If you have `@all_targets = [:rpi4]` and only use it in `targets: @all_targets`, the compiler warns:
```
warning: module attribute @all_targets was set but never used
```

**Fix:** Either inline `targets: :rpi4` everywhere, or actually use `@all_targets` in a `for` loop:
```elixir
defp deps do
  for target <- [:rpi4] do
    [{:nerves_system_rpi4, "~> 1.27", targets: target}, ...]
  end
  |> List.flatten()
end
```

If the list is static, just inline `:rpi4` and drop `@all_targets`.

## Pitfall 10: Compile-Error during Nerves bootstrap on host

**Trigger:** Running `mix phx.server` on Mac when `mix.lock` was generated on the rpi4 target, or vice versa.

**Failure:** `mix compile` fails with cryptic errors about missing Nerves targets.

**Fix:** Delete `_build/` and `mix.lock`, run `mix deps.get`:
```bash
rm -rf _build deps
mix deps.get
```

If still broken: check `MIX_TARGET` env var matches your target (unset it for Mac):
```bash
unset MIX_TARGET
mix phx.server
```

## Pitfall 11: `color_to_hex` operator-precedence bug

**Trigger:** Elixir Heex templates with chained `<>` and `|>`:
```elixir
defp color_to_hex({r, g, b}) do
  "#" <>
    Integer.to_string(r, 16) |> String.pad_leading(2, "0") <>
    Integer.to_string(g, 16) |> String.pad_leading(2, "0") <>
    Integer.to_string(b, 16) |> String.pad_leading(2, "0")
end
```

**Failure:** `ArgumentError: cannot pipe ("#" <> Integer.to_string(r, 16)) |> String.pad_leading(2, "0") into String.pad_leading(2, "0") <> Integer.to_string(b, 16), the :<> operator can only take two arguments`.

**Reason:** The `<>` operator is right-associative, but `|>` has lower precedence. The chain parses wrong.

**Fix:** Bind intermediate values:
```elixir
defp color_to_hex({r, g, b}) do
  r_hex = r |> Integer.to_string(16) |> String.pad_leading(2, "0")
  g_hex = g |> Integer.to_string(16) |> String.pad_leading(2, "0")
  b_hex = b |> Integer.to_string(16) |> String.pad_leading(2, "0")
  "#" <> r_hex <> g_hex <> b_hex
end
```

## Pitfall 12: Dev-host UART detection needs `Path.wildcard` for multiple ports

**Trigger:** Auto-detect ESP32 / ESP32-S3 / XIAO ESP32-C6 connected via USB on Mac. Multiple `/dev/cu.usbmodem*` exist.

**Wrong:**
```elixir
File.exists?("/dev/cu.usbmodem101") -> "/dev/cu.usbmodem101"  # only matches one exact path
```

**Right:**
```elixir
case Path.wildcard("/dev/cu.usbmodem*") do
  [first | _] -> first
  [] -> ... # fallback
end
```

`File.exists?/1` only matches an exact path. `Path.wildcard/1` does shell-glob expansion, so `/dev/cu.usbmodem*` matches `usbmodem101`, `usbmodem14101`, `usbmodem1101`, etc.

## Pitfall 13: Compiling from the wrong working directory

**Trigger:** You run `mix compile` from `herz_schwarm_nerves/` but the deps were resolved for a different `mix.exs` (e.g. the umbrella `apps/web/`).

**Failure:** `UndefinedFunctionError` or `Module not loaded` for modules that exist in the project.

**Fix:** Always `cd` into the app root (where `mix.exs` lives) before running `mix`. Verify with `pwd` and `ls mix.exs`.

## Pitfall 14: `defp` inside `defmodule` order matters for warnings

**Trigger:** Multiple `handle_cast/2` clauses scattered between `defp` helpers.

**Failure:** Compiler warning:
```
warning: clauses with the same name and arity (number of arguments) should be grouped together, "def handle_cast/2" was previously defined
```

**Fix:** Group all `handle_cast/2` clauses together, then put `defp` helpers after:
```elixir
def handle_cast({:foo, ...}, state) do ... end
def handle_cast({:bar, ...}, state) do ... end
def handle_cast({:baz, ...}, state) do ... end

defp my_helper(state) do ... end
defp other_helper(state) do ... end
```

## Testing Phoenix apps without a real test suite

If you have no `mix test` suite (e.g. just `mix compile` works), use `mix run --no-start` for behavioral tests:

```bash
TEST=$(mktemp /tmp/test-init-XXXXXX.exs)
cat > "$TEST" <<'EOF'
Application.put_env(:my_app, :key, nil)
try do
  MyMod.init([])
  IO.puts("NO_CRASH")
rescue
  e -> IO.puts("CRASH:" <> Exception.message(e))
end
EOF
MIX_ENV=dev mix run --no-start "$TEST" 2>&1 | grep "^OK\|^CRASH"
```

This avoids the `elixir -e` issues (no `_build/` knowledge, no config auto-load) and gives you a real `init/1` test with full GenServer semantics.

## Required Dependencies (Mac dev host)

```elixir
defp deps do
  [
    # Phoenix stack
    {:phoenix, "~> 1.7"},
    {:phoenix_html, "~> 3.3"},
    {:phoenix_live_view, "~> 0.20"},
    {:gettext, "~> 0.26"},
    {:plug_cowboy, "~> 2.6"},  # OR remove and use Bandit
    {:bandit, "~> 1.0"},

    # Nerves (only targets: :rpi4 for system/runtime/pack)
    {:nerves, "~> 1.10", runtime: false},  # NO targets — see Pitfall 2
    {:nerves_system_rpi4, "~> 1.27", targets: :rpi4},
    {:nerves_runtime, "~> 0.13", targets: :rpi4},
    {:nerves_pack, "~> 0.7", targets: :rpi4},

    # Telemetry
    {:telemetry_poller, "~> 1.0"},

    # JSON / UART
    {:jason, "~> 1.4"},
    {:circuits_uart, "~> 1.5"},

    # Dev
    {:phoenix_live_reload, "~> 1.4", only: :dev},
    {:esbuild, "~> 0.8", runtime: Mix.env() == :dev},
    {:tailwind, "~> 0.2", runtime: Mix.env() == :dev},
  ]
end
```

## Setup (Mac dev host, Nerves target = rpi4)

```bash
# Install Elixir
nix profile add nixpkgs#elixir nixpkgs#erlang
# or
brew install elixir

# First-time project setup
cd herz_schwarm_nerves  # or your Nerves app
mix deps.get
mix compile

# Run dev
MIX_ENV=dev mix phx.server

# Run on rpi4 (Nerves image build)
MIX_TARGET=rpi4 mix firmware
mix burn  # to SD card
```

## Common commands

```bash
# Check Mix version
elixir --version
# Elixir 1.18.4 (compiled with Erlang/OTP 28)

# List compiled deps
ls _build/dev/lib/

# Force recompile
mix compile --force

# Re-resolve deps
mix deps.get

# IEx with app loaded
iex -S mix phx.server

# In IEx, exercise the app:
alias MyApp.{Bridge, EffectEngine}
Bridge.connected?()
```

## Related

- `ad-hoc-verification` — for verifying Phoenix changes when there's no test suite
- `plan` — for planning multi-file Phoenix+Nerves refactors
- `esp32-development` — for the embedded side of the bridge
- `systematic-debugging` — for actual bug hunting (e.g. reconnect loops, undefined functions)

## Support Files

- `references/phoenix-elixir-1.18-pitfalls.md` — Detailed versions of all 14 pitfalls with concrete code samples, error messages, and reproductions.
