#!/usr/bin/env python3
"""Generates the Rota app icon (vinyl 'wheel') as SVG + full macOS iconset."""
import math
import os
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
CHROME = "/opt/pw-browsers/chromium_headless_shell-1194/chrome-linux/headless_shell"

S = 1024.0
CX = CY = S / 2


def superellipse_path(cx, cy, a, n, steps=256):
    """Apple-style squircle as a closed polygon path."""
    pts = []
    for i in range(steps):
        t = 2 * math.pi * i / steps
        c, s = math.cos(t), math.sin(t)
        x = cx + a * math.copysign(abs(c) ** (2 / n), c)
        y = cy + a * math.copysign(abs(s) ** (2 / n), s)
        pts.append((x, y))
    d = "M %.2f %.2f " % pts[0] + " ".join("L %.2f %.2f" % p for p in pts[1:]) + " Z"
    return d


def polar(cx, cy, r, deg):
    rad = math.radians(deg)
    return cx + r * math.cos(rad), cy + r * math.sin(rad)


def arc_path(cx, cy, r, a0, a1):
    x0, y0 = polar(cx, cy, r, a0)
    x1, y1 = polar(cx, cy, r, a1)
    large = 1 if (a1 - a0) % 360 > 180 else 0
    return f"M {x0:.2f} {y0:.2f} A {r:.2f} {r:.2f} 0 {large} 1 {x1:.2f} {y1:.2f}"


SQUIRCLE = superellipse_path(CX, CY, 412, 4.8)

# --- grooves -----------------------------------------------------------------
grooves = "\n".join(
    f'    <circle cx="{CX}" cy="{CY}" r="{r}" fill="none" '
    f'stroke="#FFFFFF" stroke-opacity="0.05" stroke-width="2"/>'
    for r in range(158, 290, 13)
)

# --- beamed eighth-note glyph -------------------------------------------------
# Two note heads, two stems, one slanted beam. Centered on the label.
SLOPE = -0.16  # beam slope (dy/dx)


def note_group(fill, dy=0.0, opacity=1.0, extra=""):
    h1x, h1y = 455, 585 + dy
    h2x, h2y = 552, 570 + dy
    rx, ry = 26, 19
    stem_w = 12
    s1x = h1x + rx - stem_w + 1
    s2x = h2x + rx - stem_w + 1
    beam_top_y_at = lambda x: 452 + SLOPE * (x - s1x) + dy
    beam_h = 30
    bx0, bx1 = s1x, s2x + stem_w
    beam = (
        f"M {bx0} {beam_top_y_at(bx0):.2f} "
        f"L {bx1} {beam_top_y_at(bx1):.2f} "
        f"L {bx1} {beam_top_y_at(bx1) + beam_h:.2f} "
        f"L {bx0} {beam_top_y_at(bx0) + beam_h:.2f} Z"
    )
    s1top = beam_top_y_at(s1x + stem_w / 2) + beam_h - 2
    s2top = beam_top_y_at(s2x + stem_w / 2) + beam_h - 2
    return f"""    <g fill="{fill}" opacity="{opacity}" {extra}>
      <path d="{beam}"/>
      <rect x="{s1x}" y="{s1top:.2f}" width="{stem_w}" height="{h1y - s1top:.2f}" rx="3"/>
      <rect x="{s2x}" y="{s2top:.2f}" width="{stem_w}" height="{h2y - s2top:.2f}" rx="3"/>
      <ellipse cx="{h1x}" cy="{h1y}" rx="{rx}" ry="{ry}" transform="rotate(-16 {h1x} {h1y})"/>
      <ellipse cx="{h2x}" cy="{h2y}" rx="{rx}" ry="{ry}" transform="rotate(-16 {h2x} {h2y})"/>
    </g>"""


SVG = f"""<svg width="1024" height="1024" viewBox="0 0 1024 1024" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#38446F"/>
      <stop offset="0.52" stop-color="#1D2347"/>
      <stop offset="1" stop-color="#0D102A"/>
    </linearGradient>
    <radialGradient id="glow" cx="0.30" cy="0.18" r="0.95">
      <stop offset="0" stop-color="#7F8CD9" stop-opacity="0.5"/>
      <stop offset="0.45" stop-color="#46528F" stop-opacity="0.14"/>
      <stop offset="1" stop-color="#000000" stop-opacity="0"/>
    </radialGradient>
    <radialGradient id="disc" cx="0.5" cy="0.5" r="0.5">
      <stop offset="0" stop-color="#1A1D33"/>
      <stop offset="0.55" stop-color="#111424"/>
      <stop offset="0.9" stop-color="#0A0C19"/>
      <stop offset="1" stop-color="#161A30"/>
    </radialGradient>
    <linearGradient id="label" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#9B85FF"/>
      <stop offset="0.55" stop-color="#5F6CFF"/>
      <stop offset="1" stop-color="#3D8BFF"/>
    </linearGradient>
    <filter id="soft" x="-60%" y="-60%" width="220%" height="220%">
      <feGaussianBlur stdDeviation="14"/>
    </filter>
    <filter id="soft2" x="-60%" y="-60%" width="220%" height="220%">
      <feGaussianBlur stdDeviation="7"/>
    </filter>
    <clipPath id="clip"><path d="{SQUIRCLE}"/></clipPath>
  </defs>

  <path d="{SQUIRCLE}" fill="url(#bg)"/>
  <g clip-path="url(#clip)">
    <rect width="1024" height="1024" fill="url(#glow)"/>

    <!-- vinyl drop shadow -->
    <circle cx="{CX}" cy="{CY + 16}" r="300" fill="#04050C" opacity="0.6" filter="url(#soft)"/>

    <!-- vinyl body -->
    <circle cx="{CX}" cy="{CY}" r="298" fill="url(#disc)"/>
{grooves}

    <!-- light reflections on the vinyl -->
    <path d="{arc_path(CX, CY, 224, -168, -110)}" fill="none" stroke="#C0C9FF"
          stroke-opacity="0.20" stroke-width="88" stroke-linecap="round" filter="url(#soft)"/>
    <path d="{arc_path(CX, CY, 224, 16, 58)}" fill="none" stroke="#8FA0E8"
          stroke-opacity="0.12" stroke-width="70" stroke-linecap="round" filter="url(#soft)"/>
    <path d="{arc_path(CX, CY, 268, -160, -122)}" fill="none" stroke="#FFFFFF"
          stroke-opacity="0.20" stroke-width="4" stroke-linecap="round" filter="url(#soft2)"/>
    <path d="{arc_path(CX, CY, 268, 24, 50)}" fill="none" stroke="#FFFFFF"
          stroke-opacity="0.12" stroke-width="4" stroke-linecap="round" filter="url(#soft2)"/>

    <!-- label -->
    <circle cx="{CX}" cy="{CY}" r="136" fill="url(#label)"/>
    <circle cx="{CX}" cy="{CY}" r="136" fill="none" stroke="#000000" stroke-opacity="0.25" stroke-width="5"/>
    <circle cx="{CX}" cy="{CY}" r="129" fill="none" stroke="#FFFFFF" stroke-opacity="0.30" stroke-width="2"/>

    <!-- note -->
{note_group("#0A0D2A", dy=7, opacity=0.35, extra='filter="url(#soft2)"')}
{note_group("#FFFFFF")}

    <!-- glass sweep across the top of the icon -->
    <path d="M 0 0 H 1024 V 300 C 700 420 324 420 0 300 Z" fill="#FFFFFF" opacity="0.045"/>
  </g>
  <path d="{SQUIRCLE}" fill="none" stroke="#FFFFFF" stroke-opacity="0.08" stroke-width="5"/>
</svg>
"""

svg_path = os.path.join(HERE, "logo.svg")
with open(svg_path, "w") as f:
    f.write(SVG)
print("wrote", svg_path)

# --- render -------------------------------------------------------------------
png1024 = os.path.join(HERE, "logo_1024.png")
subprocess.run(
    [
        CHROME,
        "--headless",
        "--no-sandbox",
        "--disable-gpu",
        "--force-device-scale-factor=1",
        "--default-background-color=00000000",
        f"--window-size=1024,1024",
        f"--screenshot={png1024}",
        f"file://{svg_path}",
    ],
    check=True,
    capture_output=True,
)
print("rendered", png1024)

from PIL import Image

img = Image.open(png1024).convert("RGBA")
assert img.size == (1024, 1024), img.size

iconset = os.path.join(HERE, "AppIcon.iconset")
shutil.rmtree(iconset, ignore_errors=True)
os.makedirs(iconset)

MAP = {
    "icon_16x16.png": 16,
    "icon_16x16@2x.png": 32,
    "icon_32x32.png": 32,
    "icon_32x32@2x.png": 64,
    "icon_128x128.png": 128,
    "icon_128x128@2x.png": 256,
    "icon_256x256.png": 256,
    "icon_256x256@2x.png": 512,
    "icon_512x512.png": 512,
    "icon_512x512@2x.png": 1024,
}
for name, size in MAP.items():
    scaled = img if size == 1024 else img.resize((size, size), Image.LANCZOS)
    scaled.save(os.path.join(iconset, name))
print("iconset done:", sorted(os.listdir(iconset)))

img.resize((512, 512), Image.LANCZOS).save(os.path.join(HERE, "logo.png"))
os.remove(png1024)
print("logo.png done")
