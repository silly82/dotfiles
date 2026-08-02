# Safari MCP Debugging Recipes

Concrete techniques for finding client-side JS bugs in live websites using the Safari browser MCP (`mcp__safari_stp__*`) and the generic browser toolset. Use when the user reports a bug on a site you don't own the source for, and you need to find the root cause from a desktop browser.

## Safari MCP gotchas

| Gotcha | Fix |
|---|---|
| `set_viewport_size` fails with "No active tab" | Call `navigate_to_url` first (it auto-creates a tab), then `set_viewport_size`. |
| `page_interactions.type` doesn't reliably trigger debounced handlers | Set `inp.value` and dispatch a real `KeyboardEvent('keyup')` via `evaluate_javascript`. |
| `get_page_content` truncated to file when too large | Read the saved file with `read_file` and parse with `json.loads`. |
| Console messages are buffered per-tab | `browser_console_messages(clear=true)` before triggering the bug, read after. |

## Extracting the JS handler that owns a behavior

### jQuery event handlers

```js
const inp = document.getElementById('quicksearch');
const events = window.jQuery._data(inp, 'events');
// events.keyup = [{ handler: fn, namespace, ... }]
```

The top-level handler is often a `debounce` wrapper. `fn.toString()` shows the wrapper. To see the **inner** function, fetch the static asset:

```bash
curl -s https://site.example/static/js/scripts.js | grep -n -i 'quicksearch'
```

### Vanilla DOM listeners

Chrome DevTools exposes `getEventListeners(el)` — not available via evaluate. For vanilla handlers, search the JS source for the input id and the event name.

### Common bug patterns

| Pattern | Symptom | Root cause | Fix |
|---|---|---|---|
| `new RegExp(userInput, 'gi')` | Search silently stops working when user types `(`, `*`, `[`, etc. | Unescaped regex metacharacters throw `SyntaxError` | Escape: `userInput.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')` |
| `$grid.isotope()` re-runs ALL filters on every keyup | Lag, dropped frames, possible mobile crash | No incremental filter; full re-layout on every keystroke | Filter items manually first, only call isotope on changed set |
| MutationObserver sees 1000+ style mutations/sec on `.swiper-slide` | Page feels janky during interaction | Autoplay slider running concurrently with user search | Pause autoplay when search field is focused |
| `addEventListener('input', ...)` without debounce | Typing causes O(n²) work on large lists | Handler runs synchronously on every char | Wrap handler in debounce/throttle |

## Probes to set up before triggering the bug

### Hook `RegExp` constructor

```js
const orig = RegExp;
window.__regexErrors = [];
window.RegExp = function(p, f) {
  try { return new orig(p, f); }
  catch (e) { window.__regexErrors.push({ pattern: String(p), error: e.message }); throw e; }
};
window.RegExp.prototype = orig.prototype;
```

### Hook a library function (Isotope example)

```js
const $grid = window.jQuery('.isotope_container > .mitarbeiter');
const orig = $grid.isotope;
window.__isoCalls = [];
$grid.isotope = function(...args) {
  window.__isoCalls.push({ at: Date.now(), n: args.length });
  return orig.apply(this, args);
};
```

### Hook global error handlers

```js
window.__errors = [];
window.addEventListener('error', e => window.__errors.push({
  msg: e.message, src: e.filename, line: e.lineno, col: e.colno
}));
window.__rejections = [];
window.addEventListener('unhandledrejection', e => window.__rejections.push(String(e.reason)));
```

### MutationObserver for runaway repaints

```js
window.__muts = [];
new MutationObserver(muts => {
  for (const m of muts) {
    if (m.type === 'attributes') {
      window.__muts.push({ attr: m.attributeName, target: m.target.className });
    }
  }
}).observe(document.body, { subtree: true, attributes: true, attributeFilter: ['style', 'class'] });
```

After the suspected interaction, count `__muts.length` and group by `target`. If `swiper-slide` dominates, autoplay is running wild.

## Triggering the failing interaction reliably

```js
const inp = document.getElementById('quicksearch');
inp.focus();
inp.value = 'Arnold';                  // realistic input
inp.dispatchEvent(new KeyboardEvent('keyup', { key: 'd', bubbles: true }));

// For invalid-regex repro:
inp.value = '(';
inp.dispatchEvent(new KeyboardEvent('keyup', { key: '(', bubbles: true }));
```

Wait 200–500ms (covers most debounce thresholds), then read state.

## Reading the results

```js
({
  value: document.getElementById('quicksearch').value,
  filteredVisible: document.querySelectorAll('.item:not(.isotope-hidden)').length,
  filteredHidden:   document.querySelectorAll('.item.isotope-hidden').length,
  regexErrors: window.__regexErrors,
  isoCalls: window.__isoCalls.length,
  unhandledErrors: window.__errors,
  mutationCount: window.__muts.length,
  mutationByTarget: window.__muts.reduce((acc, m) => {
    const k = (m.target || '').slice(0, 40);
    acc[k] = (acc[k] || 0) + 1; return acc;
  }, {})
})
```

## Honest reporting when the user-reported symptom doesn't reproduce

Mobile Safari's reload-on-JS-error behavior depends on iOS version, framework error boundaries, ServiceWorker state, and whether the error originates inside a trusted vs untrusted event handler. None of those are observable from desktop Safari MCP.

If you confirm the root cause (e.g., a `SyntaxError` in a keyup handler) but cannot reproduce the exact user-reported symptom (e.g., "the page reloads"), say so explicitly. Report:

> **Root cause confirmed:** `[file.js:line]` throws `[error]` whenever the user types a regex metacharacter.
> **Exact symptom (page reload) not reproduced** in this environment — likely depends on iOS version / WebKit error boundary. Recommend the maintainer verify on a real device with the offending input.
> **Suggested fix:** `qsRegex = new RegExp(val.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'gi');`

This is more useful than guessing or fabricating the missing piece.