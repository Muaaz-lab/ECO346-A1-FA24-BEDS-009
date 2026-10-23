"""Question 5: reproduce the weighted age-band analysis in Python.

Run from the repository root: python scripts/04_second_language.py
Uses only the Python standard library, so no package installation or network is needed.
"""
from __future__ import annotations

import csv
import html
import math
import random
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "data"
FIGURES = ROOT / "figures"
FIGURES.mkdir(exist_ok=True)

VARIANT = 1
PROV = [2, 2, 3, 3, 1, 1, 4, 4][VARIANT]
AREA = [1, 2, 1, 2, 1, 2, 1, 2][VARIANT]

households: dict[str, tuple[float, int, int]] = {}
with (DATA / "pslm_hh_subset.csv").open(encoding="utf-8-sig", newline="") as file:
    for row in csv.DictReader(file):
        households[row["hhid"]] = (
            float(row["hhweight"]),
            int(row["prov_code"]),
            int(row["urban_rural"]),
        )

earners: list[tuple[int, float, float]] = []
with (DATA / "pslm_person_subset.csv").open(encoding="utf-8-sig", newline="") as file:
    for row in csv.DictReader(file):
        household = households.get(row["hhid"])
        if household is None:
            continue
        weight, province, area = household
        age = int(row["age"]) if row["age"] else 0
        earnings = float(row["earn_annual"]) if row["earn_annual"] else 0
        if 15 <= age <= 64 and earnings > 0 and province == PROV and area == AREA:
            earners.append((age, earnings, weight))

grouped: dict[int, list[tuple[int, float, float]]] = {}
for record in earners:
    band_start = (record[0] // 5) * 5
    grouped.setdefault(band_start, []).append(record)

bands = []
for start, records in sorted(grouped.items()):
    weight_total = sum(r[2] for r in records)
    mean = round(sum(r[1] * r[2] for r in records) / weight_total)
    bands.append({
        "start": start,
        "band": f"{start}-{start + 4}",
        "n": len(records),
        "wmean": mean,
        "thin": len(records) < 30,
        "mid": start + 2,
    })

with (FIGURES / "band_table_python.csv").open("w", encoding="utf-8", newline="") as file:
    writer = csv.writer(file, lineterminator="\n")
    writer.writerow(["band", "n", "wmean"])
    writer.writerows((b["band"], b["n"], b["wmean"]) for b in bands)

print("band,n,wmean")
for band in bands:
    print(f'{band["band"]},{band["n"]},{band["wmean"]}')

r_table = FIGURES / "band_table_R.csv"
if r_table.exists():
    with r_table.open(encoding="utf-8-sig", newline="") as file:
        r_rows = list(csv.DictReader(file))
    same = len(r_rows) == len(bands) and all(
        row["band"] == band["band"]
        and int(row["n"]) == band["n"]
        and int(row["wmean"]) == band["wmean"]
        for row, band in zip(r_rows, bands)
    )
    print("Band tables agree with R to the rupee:", same)
else:
    print("Run scripts/03_relationship.R first to compare with R.")

# Draw an editable, standards-based SVG scatterplot from the filtered records.
WIDTH, HEIGHT = 960, 600
LEFT, RIGHT, TOP, BOTTOM = 105, 34, 72, 112
PLOT_W, PLOT_H = WIDTH - LEFT - RIGHT, HEIGHT - TOP - BOTTOM
X_MIN, X_MAX = 14.5, 64.5
Y_MIN, Y_MAX = 4.0, 7.0

def sx(age: float) -> float:
    return LEFT + (age - X_MIN) / (X_MAX - X_MIN) * PLOT_W

def sy(value: float) -> float:
    return TOP + (Y_MAX - math.log10(value)) / (Y_MAX - Y_MIN) * PLOT_H

parts = [
    f'<svg xmlns="http://www.w3.org/2000/svg" width="{WIDTH}" height="{HEIGHT}" viewBox="0 0 {WIDTH} {HEIGHT}">',
    '<rect width="100%" height="100%" fill="white"/>',
    '<style>text{font-family:Arial,sans-serif;fill:#222}.tick{font-size:14px}.caption{font-size:12px;fill:#444}</style>',
]
parts.append(f'<text x="{LEFT}" y="34" font-size="22" font-weight="bold">Mean earnings rise with age and peak at {html.escape(max(bands, key=lambda b: b["wmean"])["band"])}</text>')

for power in range(4, 8):
    y = sy(10 ** power)
    label = f"Rs {10 ** power:,}"
    parts.append(f'<line x1="{LEFT}" y1="{y:.2f}" x2="{WIDTH-RIGHT}" y2="{y:.2f}" stroke="#dedede"/>')
    parts.append(f'<text class="tick" x="{LEFT-12}" y="{y+5:.2f}" text-anchor="end">{label}</text>')
for age in range(15, 66, 5):
    x = sx(age)
    parts.append(f'<line x1="{x:.2f}" y1="{TOP}" x2="{x:.2f}" y2="{TOP+PLOT_H}" stroke="#f0f0f0"/>')
    parts.append(f'<text class="tick" x="{x:.2f}" y="{TOP+PLOT_H+25}" text-anchor="middle">{age}</text>')

parts.append(f'<line x1="{LEFT}" y1="{TOP+PLOT_H}" x2="{WIDTH-RIGHT}" y2="{TOP+PLOT_H}" stroke="#333"/>')
parts.append(f'<line x1="{LEFT}" y1="{TOP}" x2="{LEFT}" y2="{TOP+PLOT_H}" stroke="#333"/>')
parts.append(f'<text x="{LEFT+PLOT_W/2:.2f}" y="{TOP+PLOT_H+52}" text-anchor="middle" font-size="16">Age (years)</text>')
parts.append(f'<text transform="translate(25 {TOP+PLOT_H/2}) rotate(-90)" text-anchor="middle" font-size="16">Annual earnings (log scale)</text>')

rng = random.Random(346)
for age, earnings, _weight in earners:
    if 1e4 <= earnings <= 1e7:
        x = sx(age + rng.uniform(-0.4, 0.4))
        y = sy(earnings)
        parts.append(f'<circle cx="{x:.2f}" cy="{y:.2f}" r="2.2" fill="#555" fill-opacity="0.18"/>')

line_points = " ".join(f'{sx(b["mid"]):.2f},{sy(b["wmean"]):.2f}' for b in bands)
parts.append(f'<polyline points="{line_points}" fill="none" stroke="#c0392b" stroke-width="3"/>')
for band in bands:
    fill = "white" if band["thin"] else "#c0392b"
    parts.append(f'<circle cx="{sx(band["mid"]):.2f}" cy="{sy(band["wmean"]):.2f}" r="6" fill="{fill}" stroke="#c0392b" stroke-width="2"/>')

top_band = max(bands, key=lambda b: b["wmean"])
off_axis = sum(value < 1e4 or value > 1e7 for _, value, _ in earners)
label_x = sx(top_band["mid"])
label_y = sy(top_band["wmean"]) - 74
label = f'Highest: ages {top_band["band"]} | Rs {top_band["wmean"]:,}'
parts.append(f'<line x1="{label_x:.2f}" y1="{label_y+10:.2f}" x2="{label_x:.2f}" y2="{sy(top_band["wmean"])-8:.2f}" stroke="#777"/>')
parts.append(f'<text x="{label_x:.2f}" y="{label_y:.2f}" text-anchor="middle" font-size="14" font-weight="bold">{html.escape(label)}</text>')
parts.append(f'<text class="caption" x="{LEFT}" y="{HEIGHT-42}">Source: PSLM 2019-20. Sample: earners aged 15-64 with earnings &gt; 0 in variant 1 (n = {len(earners)}). Weighted by hhweight (band means only).</text>')
parts.append(f'<text class="caption" x="{LEFT}" y="{HEIGHT-22}">Hollow markers: bands with fewer than 30 earners. {off_axis} points outside the axis range are not shown.</text>')
parts.append("</svg>")
(FIGURES / "relationship_python.svg").write_text("\n".join(parts), encoding="utf-8")
