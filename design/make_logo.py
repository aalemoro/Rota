#!/usr/bin/env python3
"""
Rota — app icon generator.
Renders a sleek "click-wheel in Liquid Glass" mark at high supersampling,
then exports every size required by a macOS AppIcon set.

Design language: dark graphite squircle, a translucent glass wheel ring,
a domed center button with a play glyph. No flat "AI gradient" look — the
lighting is directional and restrained, the way an Apple icon reads.
"""
import math, os
from PIL import Image, ImageDraw, ImageFilter, ImageChops

SS = 4                      # supersample factor
BASE = 1024
S = BASE * SS              # working canvas

def lerp(a, b, t): return a + (b - a) * t
def mix(c1, c2, t): return tuple(int(round(lerp(c1[i], c2[i], t))) for i in range(len(c1)))

def superellipse_mask(size, radius_ratio=0.235, n=5.0):
    """Apple-style squircle mask (superellipse)."""
    m = Image.new("L", (size, size), 0)
    px = m.load()
    cx = cy = (size - 1) / 2.0
    a = size / 2.0
    # superellipse: (|x|/a)^n + (|y|/a)^n <= 1
    for y in range(size):
        for x in range(size):
            nx = abs(x - cx) / a
            ny = abs(y - cy) / a
            v = nx**n + ny**n
            if v <= 1.0:
                # soft edge
                edge = (1.0 - v) * a
                px[x, y] = 255 if edge > 1.5 else int(255 * min(1.0, edge / 1.5))
    return m

def vgradient(size, top, bottom):
    g = Image.new("RGB", (size, size))
    d = g.load()
    for y in range(size):
        t = y / (size - 1)
        # ease for a subtle sheen concentrated near the top
        te = t
        col = mix(top, bottom, te)
        for x in range(size):
            d[x, y] = col
    return g

def radial_light(size, center, inner_r, outer_r, color, max_alpha):
    """Additive soft radial highlight."""
    l = Image.new("L", (size, size), 0)
    d = l.load()
    cx, cy = center
    for y in range(size):
        for x in range(size):
            dist = math.hypot(x - cx, y - cy)
            if dist <= inner_r:
                a = max_alpha
            elif dist >= outer_r:
                a = 0
            else:
                t = (dist - inner_r) / (outer_r - inner_r)
                a = int(max_alpha * (1 - t) ** 2)
            d[x, y] = a
    tint = Image.new("RGB", (size, size), color)
    return tint, l

print("Building base icon at", S, "px ...")

# --- background squircle -------------------------------------------------
bg = vgradient(S, (58, 60, 66), (14, 15, 18))          # graphite -> near black
# top sheen
sheen_tint, sheen_a = radial_light(S, (S*0.5, S*0.12), S*0.02, S*0.75,
                                   (120, 124, 132), 90)
bg = Image.composite(sheen_tint, bg, sheen_a)

mask = superellipse_mask(S)

icon = Image.new("RGBA", (S, S), (0, 0, 0, 0))
icon.paste(bg, (0, 0), mask)

draw = ImageDraw.Draw(icon, "RGBA")

# --- inner rim light (glass edge of the squircle) ------------------------
rim = Image.new("L", (S, S), 0)
rd = ImageDraw.Draw(rim)
# derive rim from mask edge
edge = mask.filter(ImageFilter.FIND_EDGES)
edge = edge.filter(ImageFilter.GaussianBlur(S*0.004))
rim_tint = Image.new("RGB", (S, S), (150, 154, 162))
icon = Image.composite(Image.merge("RGBA", (*rim_tint.split(), edge.point(lambda v: int(v*0.5)))),
                       icon, edge.point(lambda v: int(v*0.5)))

draw = ImageDraw.Draw(icon, "RGBA")

# --- the click wheel -----------------------------------------------------
cx = cy = S / 2
wheel_outer = S * 0.335
wheel_inner = S * 0.145      # hole for center button

# wheel base ring (glass): draw filled circle then punch a hole with center btn later
# ring gradient: brighter top-left, darker bottom-right (directional light)
ring_layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
rl = ring_layer.load()
for y in range(int(cy - wheel_outer - 4), int(cy + wheel_outer + 4)):
    for x in range(int(cx - wheel_outer - 4), int(cx + wheel_outer + 4)):
        d = math.hypot(x - cx, y - cy)
        if wheel_inner <= d <= wheel_outer:
            # directional shade
            ang = math.atan2(y - cy, x - cx)
            light = 0.5 + 0.5 * math.cos(ang + math.radians(125))  # light from upper-left
            base = mix((236, 238, 242), (170, 174, 182), 1 - light)
            # radial falloff for slight doming
            rt = (d - wheel_inner) / (wheel_outer - wheel_inner)
            dome = 1.0 - 0.18 * (rt - 0.5) ** 2 * 4
            col = mix((0, 0, 0), base, max(0.0, min(1.0, dome)))
            # translucency (glass): alpha slightly under full
            a = 235
            # soft outer/inner edges
            if d > wheel_outer - 3:
                a = int(a * (wheel_outer - d) / 3)
            if d < wheel_inner + 3:
                a = int(a * (d - wheel_inner) / 3)
            rl[x, y] = (col[0], col[1], col[2], max(0, a))
# soft shadow under the wheel for depth
shadow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
sd = ImageDraw.Draw(shadow)
sd.ellipse([cx - wheel_outer, cy - wheel_outer + S*0.012,
            cx + wheel_outer, cy + wheel_outer + S*0.012],
           fill=(0, 0, 0, 120))
shadow = shadow.filter(ImageFilter.GaussianBlur(S*0.012))
icon = Image.alpha_composite(icon, shadow)
icon = Image.alpha_composite(icon, ring_layer)

draw = ImageDraw.Draw(icon, "RGBA")

# glass specular highlight arc on the wheel (upper-left)
spec = Image.new("RGBA", (S, S), (0, 0, 0, 0))
spd = ImageDraw.Draw(spec)
spd.arc([cx - wheel_outer + S*0.01, cy - wheel_outer + S*0.01,
         cx + wheel_outer - S*0.01, cy + wheel_outer - S*0.01],
        start=185, end=300, fill=(255, 255, 255, 210), width=int(S*0.012))
spec = spec.filter(ImageFilter.GaussianBlur(S*0.006))
icon = Image.alpha_composite(icon, spec)

# --- center button -------------------------------------------------------
btn_r = wheel_inner - S*0.012
cb = Image.new("RGBA", (S, S), (0, 0, 0, 0))
cbl = cb.load()
for y in range(int(cy - btn_r - 2), int(cy + btn_r + 2)):
    for x in range(int(cx - btn_r - 2), int(cx + btn_r + 2)):
        d = math.hypot(x - cx, y - cy)
        if d <= btn_r:
            # vertical glass gradient, brighter at top
            t = (y - (cy - btn_r)) / (2 * btn_r)
            col = mix((44, 46, 52), (18, 19, 23), t)
            a = 255
            if d > btn_r - 3:
                a = int(255 * (btn_r - d) / 3)
            cbl[x, y] = (col[0], col[1], col[2], max(0, a))
cb_highlight = Image.new("RGBA", (S, S), (0, 0, 0, 0))
ch = ImageDraw.Draw(cb_highlight)
ch.ellipse([cx - btn_r*0.7, cy - btn_r*0.85, cx + btn_r*0.7, cy - btn_r*0.1],
           fill=(255, 255, 255, 60))
cb_highlight = cb_highlight.filter(ImageFilter.GaussianBlur(S*0.01))
icon = Image.alpha_composite(icon, cb)
icon = Image.alpha_composite(icon, cb_highlight)

# play glyph in center button (accent color)
glyph = Image.new("RGBA", (S, S), (0, 0, 0, 0))
gd = ImageDraw.Draw(glyph)
tri = btn_r * 0.5
gx = cx + tri*0.12
pts = [(gx - tri*0.55, cy - tri*0.72),
       (gx - tri*0.55, cy + tri*0.72),
       (gx + tri*0.72, cy)]
# accent gradient (warm coral -> pink), Apple-ish vibrant
gd.polygon(pts, fill=(255, 92, 96, 255))
icon = Image.alpha_composite(icon, glyph)

# --- downscale & save master --------------------------------------------
master = icon.resize((BASE, BASE), Image.LANCZOS)
os.makedirs("out", exist_ok=True)
master.save("out/icon_1024.png")
# a version on transparent for docs
master.save("out/rota_icon_master.png")
print("Master saved: out/icon_1024.png")

# --- macOS AppIcon sizes -------------------------------------------------
# (pixel size, filename)
sizes = [16, 32, 64, 128, 256, 512, 1024]
for px in sizes:
    master.resize((px, px), Image.LANCZOS).save(f"out/icon_{px}.png")
    print(f"  wrote out/icon_{px}.png")
print("Done.")
