---
name: web-bug-debugging
description: "Debug live web JS via browser MCP. Use when site crashes."
version: 1.0.0
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [debugging, browser, web, javascript, mcp, safari, chrome, qa]
    related_skills: [dogfood, systematic-debugging]
---

# Web Bug Debugging via Browser MCP

## Overview

You are debugging a live website that you don't own. You can't add `console.log`, can't attach source maps, can't read the original repo. You have browser MCP tools (Safari or Chrome) and your job is to find the root cause and report it honestly — including the parts you couldn't reproduce.

This is **forensic debugging**, not TDD. You build probes (`evaluate_javascript`), form hypotheses, and test them against a live page. The recipe below is the short version; detailed probes and patterns are in `references/safari-mcp-debugging.md`.

## When to use

Use when ANY of these apply:

- User reports "X crashes / breaks / reloads" on a specific website (e.g., `https://example.com/page`).
- You don't own the source code but suspect a client-side JS issue.
- You need to find a line number in a vendor JS file and report the root cause to the site's owner.
- Browser-only repro — the bug only happens in Safari/Chrome and you don't have a Node REPL for the code.

Don't use when:

- You own the source and can add `console.log` (use `systematic-debugging` instead).
- The bug is server-side (HTTP error, 500, JSON shape) — use the terminal directly.
- The user just wants visual screenshots with no JS diagnosis (use `dogfood`).

## Workflow

### Phase 1: Confirm the symptom

1. Set viewport to match the reported device:
   - Safari MCP: navigate first, THEN `set_viewport_size` (it fails on "No active tab" otherwise).
   - Chrome MCP / generic browser: viewport setting works either before or after navigation.
2. Clear the console buffer (`browser_console_messages(clear=true)` or `browser_console(clear=true)`).
3. Navigate to the URL.
4. Reproduce the failing interaction. For text input with debounced handlers, `browser_type` may not fire keyup reliably — see "Triggering interactions" below.
5. Read the console. Silent JS errors here are the highest-value signal.

### Phase 2: Extract the handler

- **jQuery sites:** `$._data(el, 'events')` returns `{ eventType: [{ handler, namespace, ... }] }`. The top handler is often a `debounce` wrapper; the inner fn is what you need.
- **Vanilla DOM:** `getEventListeners()` is Chrome-only and not exposed via evaluate. Search the vendor JS for the input id and event name:
  ```bash
  curl -s https://site.example/static/js/main.js | grep -n -i 'quicksearch\|button-group'
  ```
- Read the source: `read_file` with offset/limit to navigate the bundled file.

### Phase 3: Form hypotheses + test with probes

Set up probes BEFORE triggering the bug, so you capture the first failure cleanly.

Common bug patterns to check first (full list in `references/safari-mcp-debugging.md`):

| Pattern | Symptom | Diagnostic |
|---|---|---|
| `new RegExp(userInput, 'gi')` without escaping | Search stops working on `(`, `*`, `[`, etc.; possible tab reload | Hook `RegExp` constructor, look for thrown errors |
| Isotope/MixItUp filter without incremental update | Lag, dropped frames, mobile crash | Hook `$grid.isotope`, count calls + time them |
| Autoplay slider running during user interaction | Page jank, possible OOM on mobile | MutationObserver, count `.swiper-slide` style mutations |
| Unbounded event listener on input | Typing causes O(n²) on large lists | Profile with `performance.now()` around the handler |

### Phase 4: Honest reporting

If you confirm the root cause but cannot reproduce the exact user-reported symptom (e.g., page reload), say so. Mobile Safari's reload-on-error depends on iOS version, framework error boundaries, ServiceWorker state, and trusted-vs-untrusted event handler context — none of which are observable from desktop Safari MCP.

Format your report as:

> **Root cause confirmed:** `[file.js:line]` throws `[error]` whenever the user types `[trigger]`.
> **Exact symptom (page reload) not reproduced** in this environment — likely depends on `[env factor]`. Recommend the maintainer verify on a real device with the offending input.
> **Suggested fix:** `[concrete code change]`.

## Triggering interactions reliably

For inputs with debounced handlers, use `evaluate_javascript` to set the value AND dispatch a real KeyboardEvent:

```js
const inp = document.getElementById('quicksearch');
inp.focus();
inp.value = 'Arnold';
inp.dispatchEvent(new KeyboardEvent('keyup', { key: 'd', bubbles: true }));
```

Wait 200–500ms (covers most debounce thresholds), then read state.

For invalid-regex repros:

```js
inp.value = '(';
inp.dispatchEvent(new KeyboardEvent('keyup', { key: '(', bubbles: true }));
```

## Probes (full code in references)

- **Hook `RegExp`** to catch which user inputs produce invalid patterns.
- **Hook library methods** (e.g., `$grid.isotope`) to count calls.
- **Global `window.onerror` + `unhandledrejection`** to capture escaping errors.
- **MutationObserver** scoped to `style`/`class` to reveal runaway repaints.
- **`performance.memory`** (Chrome only) to track heap pressure during the failing interaction.

## Tool differences

| Tool family | Notes |
|---|---|
| Safari MCP (`mcp__safari_stp__*`) | `set_viewport_size` requires active tab; `page_interactions.type` doesn't reliably fire debounced handlers; `get_page_content` truncates large pages to file |
| Chrome MCP (`browser_*`) | `getEventListeners` available in evaluate context; `performance.memory` exposed |
| Generic browser | Most recipes apply; check the tool's actual names |

## Configuration notes

- **Chrome browser engine**: Set `browser.engine: chrome` in `~/.hermes/config.yaml` via `hermes config set browser.engine chrome`. This uses Headless Chrome (via ChromeDriver) for `browser_navigate`, `browser_click`, etc.
- **Safari Technology Preview MCP**: Already configured via `mcp_servers.safari-stp` with command `/Applications/Safari Technology Preview.app/Contents/MacOS/safaridriver` and args `--mcp`. Works alongside Chrome browser engine.
- **Chromium on macOS**: Not available via nixpkgs (Linux only). Use Homebrew (`brew install --cask chromium`) or install Chrome via Homebrew Cask.
- **ChromeDriver MCP server**: `chromedriver --mcp` may fail to connect; prefer using the built-in browser engine instead.

## Linked references

- `references/safari-mcp-debugging.md` — full Safari MCP gotchas, probe code snippets, and bug-pattern table.