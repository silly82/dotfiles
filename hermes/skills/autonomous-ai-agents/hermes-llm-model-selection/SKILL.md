---
name: hermes-llm-model-selection
description: "Switch the Hermes default model safely."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [macos, linux, windows]
metadata:
  hermes:
    tags: [hermes, model, pricing, openrouter, deepseek, anthropic, configuration]
    related: [hermes-agent]
---

# Hermes LLM Model Selection

Evaluate live LLM prices, pick the best fit for a user, and switch `model.default` in Hermes without breaking things. Covers the full loop: pull live prices → score against user profile → switch via `hermes config set` → verify the switch landed in `config.yaml`.

## When to load

- User asks "best/cheapest model for Hermes" or "good price/performance ratio"
- User wants to switch from one model/provider to another
- User wants to evaluate a new model before committing
- User complains about cost per session

## The three-step loop

### 1. Pull live prices (don't trust cached knowledge)

OpenRouter exposes a public model catalog with current pricing:

```bash
curl -sS https://openrouter.ai/api/v1/models -H "User-Agent: hermes-cli/1.0" | python3 -c "
import json, sys
data = json.load(sys.stdin)['data']
for m in data:
    p = m.get('pricing', {}).get('prompt')
    c = m.get('pricing', {}).get('completion')
    if p and c:
        try:
            print(f\"{m['id']:<50} {float(p)*1e6:>8.3f}  {float(c)*1e6:>8.3f}  {m.get('context_length','?'):>8}\")
        except (ValueError, TypeError):
            pass
"
```

The catalog is ~360 models. Filter for what matters (code/tool-use, German, context window) and sort by weighted cost — `in*0.3 + out*0.7` works well because tool-trace output usually dominates.

### 2. Score against the user profile

For a Hermes user with heavy tool use, the deciding factors are:

- **Tool-call reliability** (don't pick a tiny model that hallucinates tool args)
- **Output price** (tool traces are output-heavy: logs, build output, MQTT payloads)
- **Context window** (long sessions need 100K+)
- **German quality** (if user is German-speaking)
- **Provider overhead** (direct API = 2x cheaper than going through OpenRouter for the same model)

For Silvan (ESP32/PlatformIO, German, heavy tool use): sweet spot is `deepseek/deepseek-v3.1-terminus` or `anthropic/claude-haiku-4.5`. Avoid anything <32B params for tool-orchestration work.

### 3. Switch safely

```bash
# CORRECT — non-interactive, persists to config.yaml
hermes config set model.default <model-id>

# Verify the switch
hermes config show | grep -A3 "^◆ Model"

# Inspect the file directly
grep -A5 "^model:" ~/.hermes/config.yaml
```

**Do NOT use `hermes model`** — it's an interactive picker, hangs in non-TTY.

**Do NOT hand-edit `config.yaml`** — `hermes config set` is the supported way and validates the indent.

## Pitfalls (all of these bit us)

### 1. Can't fully verify the switch from inside an agent spawn

`hermes chat -q "..."` from an agent's `terminal()` call will fail with
"Provider resolver returned an empty API key" — because the agent's subshell
inherits a different env than the user's interactive shell where `OPENROUTER_API_KEY`
is set (often in `.zshrc`/`.zprofile`/Nix shell config, not in `.env`).

**Fix:** Verify the switch landed in `config.yaml` (file inspection), not via a live test prompt. Tell the user "restart your shell session for the new model to take effect" — they can confirm the switch worked by running `hermes` and looking at the status line.

### 2. `hermes model` is interactive

The picker requires a TTY and lists ~360 models. In a non-interactive
agent context it hangs or returns nothing useful. Use `hermes config set` instead.

### 3. Two pricing tiers: direct vs aggregator

The same model can be 2x more expensive via OpenRouter than direct:

| Model | Direct $/1M in/out | via OpenRouter $/1M in/out |
|---|---|---|
| DeepSeek V3 | 0.14 / 0.28 | 0.25 / 0.95 |

When suggesting a switch, ask: aggregator (one key, many models) or direct (cheaper, model-locked)?

### 4. Provider change requires more than model.default

Switching from OpenRouter to direct DeepSeek changes three things:

```bash
hermes config set model.default deepseek-chat
hermes config set model.provider deepseek        # was: openrouter
hermes config set model.base_url https://api.deepseek.com/v1
# And DEEPSEEK_API_KEY in env (not OPENROUTER_API_KEY)
```

If you only change `model.default` while the provider stays "openrouter", requests hit OpenRouter with a wrong model id and 404.

### 5. `model.default` value is the model id, not a name

`hermes config set model.default deepseek-chat` → wrong (no provider prefix).
`hermes config set model.default deepseek/deepseek-chat-v3.1` → correct (full OpenRouter id).

For direct providers: `hermes config set model.default deepseek-chat` (no prefix).

## Verification checklist after a switch

```bash
# 1. file landed
grep "default:" ~/.hermes/config.yaml
# expected:   default: <new-model-id>

# 2. CLI sees it
hermes config show | grep "Model:"
# expected: Model: {'default': '<new-model-id>', ...}

# 3. User confirms in interactive shell
# (cannot do this from agent spawn — see Pitfall #1)
```

## Reference: 2026-07 price snapshot (deepseek-v3 era)

Top picks for tool-heavy users (in/out $/1M tokens via OpenRouter):

| Model | In | Out | When to pick |
|---|---|---|---|
| `qwen/qwen3-coder-30b-a3b` | 0.07 | 0.27 | Budget play, code-specific |
| `deepseek/deepseek-v3.2` | 0.27 | 0.40 | New default sweet spot |
| `deepseek/deepseek-chat-v3.1` | 0.25 | 0.95 | Proven workhorse |
| `minimax/minimax-m3` | 0.30 | 1.20 | Was Silvan's prior default |
| `anthropic/claude-haiku-4.5` | 1.00 | 5.00 | Best tool-use reliability |
| `anthropic/claude-sonnet-4.5` | 3.00 | 15.00 | Heavy multi-step reasoning |

Re-pull before any recommendation — prices drop every few weeks.
