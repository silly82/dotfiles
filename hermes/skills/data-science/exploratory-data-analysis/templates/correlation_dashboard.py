#!/usr/bin/env python3
"""
Template: Dark-theme 2×2 correlation dashboard.
Replace DATA with your own loaded data, then run:
    python correlation_dashboard.py

Dependencies: matplotlib, numpy
"""
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
import numpy as np

# ──────────────────────────────────────────────
# REPLACE THIS with your actual data loading
# Expected shape: one dict entry per entity, with
# keys for each metric you want to plot.
# ──────────────────────────────────────────────
data = {
    'dev001': {'metric_a': 88.0, 'metric_b': 10.5, 'metric_c': 0.0, 'metric_d': 0, 'metric_e': 4072, 'metric_f': 5585},
    'dev002': {'metric_a': 95.0, 'metric_b': 15.0, 'metric_c': 1.0, 'metric_d': 30, 'metric_e': 4150, 'metric_f': 18712},
}

# ──────────────────────────────────────────────
# CONFIGURATION — adjust these for your data
# ──────────────────────────────────────────────
X_LABELS = {
    'top_left':     'Temperatur (°C)',
    'top_right':    'Strecke (m)',
    'bottom_left':  'Externe Spannung (mV)',
    'bottom_right': 'Ladeanteil',
}
Y_LABELS = {
    'top_left':     'Batterie %',
    'top_right':    'RSSI (dBm)',
    'bottom_left':  'Batteriespannung (mV)',
    'bottom_right': 'Batterie %',
}
TITLES = {
    'top_left':     'Plot 1: Beschreibung (r = +0.XX)',
    'top_right':    'Plot 2: Beschreibung (r = -0.XX)',
    'bottom_left':  'Plot 3: Beschreibung (r = +0.XX)',
    'bottom_right': 'Plot 4: Cluster-Übersicht',
}

# Colour coding: one colour per category
# Example: 0=red (never), 0.5=yellow (partial), 1=green (always)
def get_colour(category_value):
    if category_value < 0.3:
        return '#ff6b6b'   # red
    elif category_value < 0.7:
        return '#ffd93d'   # yellow
    else:
        return '#6bcb77'   # green

# Size coding: scale by magnitude
def get_size(magnitude, base=30, scale=8):
    return base + magnitude * scale

# ──────────────────────────────────────────────
# BUILD THE DASHBOARD
# ──────────────────────────────────────────────
common = sorted(data.keys())
x1 = [data[d]['metric_b'] for d in common]  # e.g. temperature
y1 = [data[d]['metric_a'] for d in common]  # e.g. battery %
x2 = [data[d]['metric_d'] for d in common]  # e.g. distance
y2 = [data[d]['metric_c'] for d in common]  # e.g. RSSI-like
x3 = [data[d]['metric_f'] for d in common]  # e.g. extV
y3 = [data[d]['metric_e'] for d in common]  # e.g. batV
x4 = [data[d]['metric_c'] for d in common]  # e.g. charging ratio
y4 = [data[d]['metric_a'] for d in common]  # e.g. battery %

colours = [get_colour(data[d]['metric_c']) for d in common]
sizes   = [get_size(data[d]['metric_d']) for d in common]

plt.style.use('dark_background')
fig, ((ax1, ax2), (ax3, ax4)) = plt.subplots(2, 2, figsize=(16, 12))
fig.patch.set_facecolor('#1a1a2e')
fig.suptitle('Korrelations-Dashboard', fontsize=20, color='white', fontweight='bold', y=0.98)

for ax, x, y, xl, yl, title in [
    (ax1, x1, y1, X_LABELS['top_left'], Y_LABELS['top_left'], TITLES['top_left']),
    (ax2, x2, y2, X_LABELS['top_right'], Y_LABELS['top_right'], TITLES['top_right']),
    (ax3, x3, y3, X_LABELS['bottom_left'], Y_LABELS['bottom_left'], TITLES['bottom_left']),
    (ax4, x4, y4, X_LABELS['bottom_right'], Y_LABELS['bottom_right'], TITLES['bottom_right']),
]:
    ax.set_facecolor('#16213e')
    ax.scatter(x, y, c=colours, s=sizes, alpha=0.8, edgecolors='white', linewidth=0.5, zorder=5)
    # Trendline
    if len(x) >= 3:
        z = np.polyfit(x, y, 1)
        p = np.poly1d(z)
        ax.plot(sorted(x), p(sorted(x)), '--', color='cyan', alpha=0.6, linewidth=1.5)
    ax.set_xlabel(xl, color='white', fontsize=12)
    ax.set_ylabel(yl, color='white', fontsize=12)
    ax.set_title(title, color='white', fontsize=13, fontweight='bold')
    ax.grid(True, alpha=0.15)
    ax.tick_params(colors='white')

plt.tight_layout(rect=[0, 0, 1, 0.95])
plt.savefig('correlation_dashboard.png', dpi=150, bbox_inches='tight', facecolor='#1a1a2e')
print("OK: correlation_dashboard.png saved")