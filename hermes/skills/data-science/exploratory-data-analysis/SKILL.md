---
name: exploratory-data-analysis
description: "Explore an unknown data folder, parse multiple file formats, cross-reference sources, find correlations, and produce clean visualizations."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [eda, correlation, data-analysis, visualization, csv, log-parsing, cross-reference, dashboard]
    related_skills: [jupyter-live-kernel, spike]
---

# Exploratory Data Analysis (EDA)

Use this skill when the user gives you a data folder and asks you to "see what's in it", "find correlations", "analyse the data", "find patterns", or "make sense of the data". The territory is unstructured: you don't know the schema or relationships ahead of time.

## Core Method

```
explore → parse → cross-reference → correlate → visualize → report
```

### 1. Explore the folder structure

Start with `search_files` or `terminal ls -la` to get the full tree. Categorise what you find:

- **Log files** (`.log`, `.txt`) — often contain JSON, structured lines, or raw telemetry
- **CSV files** — potentially structured data, check headers with `head -5`
- **Python/R scripts** — read the first 30-50 lines to understand what analysis already exists
- **PNG/images** — existing visualisations the user already generated
- **Subdirectories** — groupings by date, location, or type (e.g. `Berg/`, `Tal/`, `All/`)

**Pitfall:** Don't assume one file tells the whole story. Logs are often rotated (`.1`, `.2`, `.log.1`). CSVs may be split across subdirectories.

### 2. Parse the data sources

For each data source, extract the key fields:

**CSV files:** Use `csv.DictReader` in Python. Check for:
- Delimiter (not always comma — sometimes `;` or tab)
- Header row presence
- Missing values (`N/A`, empty, `1970-01-01` sentinel dates)

**Log files with embedded JSON:** Use regex to extract the JSON payload. Watch out for:
- Trailing text after the JSON (e.g. `{"key":"val"} (annotation after JSON)` )
- Nested JSON objects — use greedy `{.*}` NOT non-greedy `{.*?}` when JSON is followed by non-JSON text
- Timestamps in the log line for time-series analysis

**Pattern for gateway-log style lines with JSON + trailing annotation:**
```python
pattern = re.compile(
    r'\[(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d+)\].*?'
    r'Publishing device status to topic [^/]+/[^/]+/(\w+)/status/deviceStatus payload ({.*}) \(deviceStatus:'
)
```

### 3. Cross-reference by common key

**If the data sources share a key (e.g. device ID, sensor ID, user ID), join on that key.** This is the most important step — each source in isolation tells a partial story.

Build a merged dict:
```python
merged = {}
for dev in common_devices:
    merged[dev] = {
        **source_a[dev],  # battery data
        **source_b[dev],  # signal quality data
        **source_c[dev],  # trip counter data
    }
```

**Pitfall:** Only include devices that appear in ALL sources you want to cross-reference. Otherwise correlations are misleading.

### 4. Choose analysis approach

**Cross-sectional analysis** (comparing entities at one point in time): Use when each entity has only 1-2 data points. Compare devices against each other. Compute Pearson correlation between paired arrays.

**Time-series analysis** (tracking one entity over time): Use when each entity has many timestamped data points. Compute per-device correlations first, then look at the distribution across the fleet.

**Decision rule:** If median data points per entity < 5, use cross-sectional.

```python
def pearson(x, y):
    if len(x) < 4: return 0.0
    mx, my = statistics.mean(x), statistics.mean(y)
    sx, sy = statistics.stdev(x), statistics.stdev(y)
    if sx == 0 or sy == 0: return 0.0
    return sum((xi-mx)*(yi-my) for xi,yi in zip(x,y)) / ((len(x)-1)*sx*sy)
```

### 5. Interpret correlations — distinguish correlation from causality

For every pairwise correlation, ask: **"Is there a plausible causal mechanism?"**

| r value | Strength | Interpretation |
|---------|----------|---------------|
| 0.0–0.15 | None | No linear relationship |
| 0.15–0.30 | Weak | Possible but noisy |
| 0.30–0.50 | Moderate | Worth noting |
| 0.50–0.70 | Strong | Likely meaningful |
| 0.70–1.00 | Very strong | Almost certainly causal or confounded |

**Common causal patterns in telemetry data:**
- **Direct causality:** extV (charging voltage) → batV (battery voltage) rises. No other explanation.
- **Third-factor causality:** Temperature correlates with battery %. Cause: charging generates heat AND charging raises battery level. Temperature itself doesn't cause battery gain.
- **Physical constraint:** RSSI degrades with distance. Signal strength drops over longer cable/gondola tracks.
- **Spurious correlation:** Always consider confounding variables before declaring a relationship.

### 6. Visualise with a dark-theme dashboard

Use a 2×2 matplotlib subplot layout for a compact dashboard showing the top 4 relationships:

**Style:**
```python
plt.style.use('dark_background')
fig.patch.set_facecolor('#1a1a2e')
ax.set_facecolor('#16213e')
```

**Encoding choices:**
- **Color** = categorical grouping (e.g. charging status: red=never, yellow=partial, green=always)
- **Size** = magnitude (e.g. number of trips, total distance)
- **Colormap** = continuous variable (e.g. RSSI with RdYlGn_r)

**Each plot should include:**
- Scatter plot of the two variables
- Linear trendline (dashed, `np.polyfit(x, y, 1)`)
- Pearson r value in the title
- Key outliers annotated with device ID
- Grid for readability

**Pitfall:** Don't put more than ~50 labelled points in a single scatter plot — it becomes unreadable. Annotate only the 3-5 most interesting outliers.

### 7. Report findings

Structure the report as:

1. **Overview** — what data sources exist, how many entities, time range
2. **Strongest correlations** — r > 0.5 with causal interpretation
3. **Anomalies** — outliers that break the pattern (e.g. device with many trips but no charging)
4. **Cluster differences** — compare groups (e.g. charging vs non-charging devices)
5. **Recommended visualisation** — point to the dashboard image

## Handling Python environment issues

On Windows with multiple Python versions, matplotlib/numpy can have version conflicts:

- `python3` may point to Python 3.13+ with incompatible numpy C extensions
- `python` may point to Python 3.11 which works
- Check with: `python -c "import matplotlib; print('OK')"` before running plotting scripts
- If matplotlib fails with `_multiarray_umath` errors, try the other Python binary
- Set `MPLBACKEND=Agg` environment variable when no display is available

## Support files in this skill

- `references/sislink-correlation-example.md` — Full worked example of the EDA pipeline on a real 42-device gondola fleet (SisLink). Covers data sources, join keys, top correlations, outliers, and environment gotchas.
- `templates/correlation_dashboard.py` — Reusable scaffold for a dark-theme 2×2 correlation dashboard. Adjust the DATA dict, axis labels, and colour/size functions for your own dataset.

## Pitfalls

- **Log parsing:** Greedy vs non-greedy regex matters when JSON is followed by text. Use `{.*}` with a trailing anchor, not `{.*?}`.
- **Missing data:** `N/A` strings, `1970-01-01` sentinel timestamps, and `extV=0` all mean "no data" — document these, don't drop them silently.
- **Per-device time series:** If each device has only 1-2 readings, per-device correlations are meaningless (all r=0.000). Switch to cross-sectional.
- **Overplotting:** Annotate only the most extreme outliers, not every point.
- **numpy/PIL version mismatch:** On Windows, Python 3.13 may have numpy for 3.11 installed. Use `python` (3.11) not `python3` (3.13) for matplotlib scripts.