#!/usr/bin/env python3
"""Rota app icon — pixel-art eighth note, black on white, one accent pixel.

Renders logo.svg with headless Chromium, then builds the full macOS iconset.
Usage:  python3 design/gen_icon.py  [path/to/chrome]
"""
import math, os, shutil, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
CHROME = sys.argv[1] if len(sys.argv) > 1 else (
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome")

INK = "#141416"
ACCENT = "#5B4BFF"
ACCENT_CELL = (13, 2)          # (row, col) in the grid below

# 16x16 grid: '#' = a pixel of the note
GRID = [
    "................",
    "................",
    "........#####...",
    "........######..",
    "........##.####.",
    "........##..###.",
    "........##..##..",
    "........##......",
    "........##......",
    "........##......",
    "........##......",
    "..#####.##......",
    ".#########......",
    ".########.......",
    "..######........",
    "................",
]
COLS = 16


def squircle(cx, cy, a, n=4.8, steps=360):
    pts = []
    for i in range(steps):
        t = 2 * math.pi * i / steps
        c, s = math.cos(t), math.sin(t)
        pts.append((cx + a * math.copysign(abs(c) ** (2 / n), c),
                    cy + a * math.copysign(abs(s) ** (2 / n), s)))
    return "M %.2f %.2f " % pts[0] + " ".join("L %.2f %.2f" % p for p in pts[1:]) + " Z"


def blocks():
    box, rows = 712.0, len(GRID)
    cell = box / COLS
    gap, r = cell * 0.10, cell * 0.16
    x0, y0 = 512 - box / 2, 512 - rows * cell / 2
    out = []
    for ri, row in enumerate(GRID):
        for ci, ch in enumerate(row):
            if ch != "#":
                continue
            fill = ACCENT if (ri, ci) == ACCENT_CELL else INK
            out.append(
                f'<rect x="{x0 + ci * cell + gap / 2:.1f}" y="{y0 + ri * cell + gap / 2:.1f}" '
                f'width="{cell - gap:.1f}" height="{cell - gap:.1f}" rx="{r:.1f}" fill="{fill}"/>')
    return "\n".join(out)


SQ = squircle(512, 512, 412)
SVG = f'''<svg width="1024" height="1024" viewBox="0 0 1024 1024" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="w" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#FFFFFF"/><stop offset="1" stop-color="#EDEDF0"/>
    </linearGradient>
  </defs>
  <path d="{SQ}" fill="url(#w)"/>
{blocks()}
  <path d="{SQ}" fill="none" stroke="#000000" stroke-opacity="0.10" stroke-width="4"/>
</svg>
'''

svg_path = os.path.join(HERE, "logo.svg")
open(svg_path, "w").write(SVG)
print("wrote", svg_path)

png1024 = os.path.join(HERE, "logo_1024.png")
subprocess.run([CHROME, "--headless", "--no-sandbox", "--disable-gpu",
                "--force-device-scale-factor=1", "--default-background-color=00000000",
                "--window-size=1024,1024", f"--screenshot={png1024}", f"file://{svg_path}"],
               check=True, capture_output=True)

from PIL import Image
img = Image.open(png1024).convert("RGBA")
iconset = os.path.join(HERE, "AppIcon.iconset")
shutil.rmtree(iconset, ignore_errors=True)
os.makedirs(iconset)
for name, size in {
    "icon_16x16.png": 16, "icon_16x16@2x.png": 32, "icon_32x32.png": 32,
    "icon_32x32@2x.png": 64, "icon_128x128.png": 128, "icon_128x128@2x.png": 256,
    "icon_256x256.png": 256, "icon_256x256@2x.png": 512, "icon_512x512.png": 512,
    "icon_512x512@2x.png": 1024,
}.items():
    (img if size == 1024 else img.resize((size, size), Image.LANCZOS)).save(
        os.path.join(iconset, name))
img.resize((512, 512), Image.LANCZOS).save(os.path.join(HERE, "logo.png"))
os.remove(png1024)
print("iconset + logo.png done")
