#!/usr/bin/env python3
"""
Rota — README mockups.
Faithful renders of the app window and the three widget sizes, matching the
SwiftUI layout, so the README has real-looking screenshots. Rendered with 2x
supersampling and LANCZOS downscale.
"""
import math, os
from PIL import Image, ImageDraw, ImageFilter, ImageFont

SS = 2
ACCENT = (255, 92, 96)
WHITE = (255, 255, 255)
SECON = (168, 170, 178)
TERT = (120, 122, 130)

os.makedirs("docs_out", exist_ok=True)

def font(size, bold=False, mono=False):
    paths_bold = [
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
    ]
    paths_reg = [
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
    ]
    paths_mono = ["/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf"]
    cand = paths_mono if mono else (paths_bold if bold else paths_reg)
    for p in cand:
        if os.path.exists(p):
            return ImageFont.truetype(p, size * SS)
    return ImageFont.load_default()

def lerp(a, b, t): return a + (b - a) * t
def mix(c1, c2, t): return tuple(int(round(lerp(c1[i], c2[i], t))) for i in range(3))

def vgrad(w, h, top, bot):
    img = Image.new("RGB", (w, h))
    px = img.load()
    for y in range(h):
        c = mix(top, bot, y/(h-1))
        for x in range(w):
            px[x, y] = c
    return img

def diag_grad(w, h, tl, br):
    img = Image.new("RGB", (w, h))
    px = img.load()
    for y in range(h):
        for x in range(w):
            t = (x/(w-1) + y/(h-1)) / 2
            px[x, y] = mix(tl, br, t)
    return img

def rounded_mask(w, h, r):
    m = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(m)
    d.rounded_rectangle([0, 0, w-1, h-1], radius=r, fill=255)
    return m

def album_art(size, seed=0):
    """A stylised album cover so mockups don't look empty."""
    palettes = [
        [(41, 50, 98), (120, 60, 140), (230, 90, 110)],
        [(20, 30, 40), (10, 90, 120), (60, 200, 190)],
        [(60, 20, 40), (200, 70, 90), (250, 180, 90)],
    ]
    pal = palettes[seed % len(palettes)]
    img = diag_grad(size, size, pal[0], pal[2])
    d = ImageDraw.Draw(img, "RGBA")
    # soft circles
    for i in range(3):
        cx = int(size * (0.3 + 0.2*i))
        cy = int(size * (0.7 - 0.15*i))
        rr = int(size * (0.28 - 0.05*i))
        col = pal[1] if i % 2 else pal[2]
        d.ellipse([cx-rr, cy-rr, cx+rr, cy+rr], fill=(col[0], col[1], col[2], 90))
    img = img.filter(ImageFilter.GaussianBlur(size*0.02))
    return img

def paste_rounded(base, img, box, radius, border=(255,255,255,30), shadow=True):
    x, y, w, h = box
    img = img.resize((w, h), Image.LANCZOS).convert("RGBA")
    m = rounded_mask(w, h, radius)
    if shadow:
        sh = Image.new("RGBA", base.size, (0,0,0,0))
        sd = ImageDraw.Draw(sh)
        sd.rounded_rectangle([x, y+int(6*SS), x+w, y+h+int(6*SS)], radius=radius, fill=(0,0,0,120))
        sh = sh.filter(ImageFilter.GaussianBlur(10*SS))
        base.alpha_composite(sh)
    base.paste(img, (x, y), m)
    if border:
        bd = ImageDraw.Draw(base)
        bd.rounded_rectangle([x, y, x+w-1, y+h-1], radius=radius, outline=border, width=max(1,SS))

def text(draw, pos, s, f, fill, anchor="la"):
    draw.text((pos[0]*1, pos[1]*1), s, font=f, fill=fill, anchor=anchor)

def progress(draw, x, y, w, frac, h=4):
    h*=SS
    draw.rounded_rectangle([x, y, x+w, y+h], radius=h//2, fill=(255,255,255,46))
    fw = max(2*SS, int(w*frac))
    draw.rounded_rectangle([x, y, x+fw, y+h], radius=h//2, fill=ACCENT)

# ---------------------------------------------------------------------------
# APP WINDOW  (iPod)
# ---------------------------------------------------------------------------
def render_app():
    W, H = 340*SS, 560*SS
    canvas = vgrad(W, H, (31, 31, 36), (10, 10, 15)).convert("RGBA")
    # coral radial top-right
    glow = Image.new("RGBA", (W, H), (0,0,0,0))
    gd = ImageDraw.Draw(glow)
    for r in range(int(320*SS), 0, -6*SS):
        a = int(30 * (1 - r/(320*SS))**2)
        gd.ellipse([W-r, -r, W+r, r], fill=(ACCENT[0], ACCENT[1], ACCENT[2], a))
    canvas.alpha_composite(glow)

    # iPod body
    bx, by = 26*SS, 24*SS
    bw, bh = W-52*SS, H-48*SS
    body = vgrad(bw, bh, (52, 53, 60), (17, 18, 23)).convert("RGBA")
    bmask = rounded_mask(bw, bh, 34*SS)
    # shadow
    sh = Image.new("RGBA", (W, H), (0,0,0,0))
    ImageDraw.Draw(sh).rounded_rectangle([bx, by+8*SS, bx+bw, by+bh+8*SS], radius=34*SS, fill=(0,0,0,150))
    sh = sh.filter(ImageFilter.GaussianBlur(18*SS))
    canvas.alpha_composite(sh)
    canvas.paste(body, (bx, by), bmask)
    ImageDraw.Draw(canvas).rounded_rectangle([bx, by, bx+bw-1, by+bh-1], radius=34*SS, outline=(255,255,255,26), width=SS)

    draw = ImageDraw.Draw(canvas, "RGBA")

    # SCREEN
    sx, sy = bx+24*SS, by+26*SS
    sw, sh_ = bw-48*SS, 272*SS
    draw.rounded_rectangle([sx, sy, sx+sw, sy+sh_], radius=16*SS, fill=(0,0,0,170))
    draw.rounded_rectangle([sx, sy, sx+sw, sy+sh_], radius=16*SS, outline=(255,255,255,32), width=SS)

    # album art
    art_s = 136*SS
    ax = sx + (sw-art_s)//2
    ay = sy + 16*SS
    paste_rounded(canvas, album_art(art_s, 0), (ax, ay, art_s, art_s), 10*SS, border=(255,255,255,30))
    draw = ImageDraw.Draw(canvas, "RGBA")

    # title/artist
    cx = sx + sw//2
    text(draw, (cx, ay+art_s+16*SS), "Midnight City", font(14, bold=True), WHITE, "ma")
    text(draw, (cx, ay+art_s+37*SS), "M83", font(12), SECON, "ma")
    text(draw, (cx, ay+art_s+54*SS), "Hurry Up, We're Dreaming", font(11), TERT, "ma")

    # progress
    pmx = sx+18*SS
    pw = sw-36*SS
    py = sy+sh_-28*SS
    progress(draw, pmx, py, pw, 0.42)
    text(draw, (pmx, py+10*SS), "1:42", font(9, mono=True), SECON, "la")
    text(draw, (pmx+pw, py+10*SS), "-2:22", font(9, mono=True), SECON, "ra")

    # CLICK WHEEL
    wsz = 210*SS
    wx = bx + (bw-wsz)//2
    wy = sy + sh_ + 26*SS
    wcx, wcy = wx+wsz//2, wy+wsz//2
    # ring
    ring = Image.new("RGBA", (wsz, wsz), (0,0,0,0))
    rl = ring.load()
    ro, ri = wsz*0.5, wsz*0.19
    for y in range(wsz):
        for x in range(wsz):
            d = math.hypot(x-wsz/2, y-wsz/2)
            if ri <= d <= ro:
                ang = math.atan2(y-wsz/2, x-wsz/2)
                light = 0.5+0.5*math.cos(ang+math.radians(125))
                base = mix((72,74,82),(38,39,46), 1-light)
                a = 240
                if d > ro-2*SS: a = int(a*(ro-d)/(2*SS))
                if d < ri+2*SS: a = int(a*(d-ri)/(2*SS))
                rl[x,y] = (base[0],base[1],base[2], max(0,a))
    canvas.alpha_composite(ring, (wx, wy))
    draw = ImageDraw.Draw(canvas, "RGBA")
    # specular arc
    spec = Image.new("RGBA",(W,H),(0,0,0,0))
    ImageDraw.Draw(spec).arc([wx+6*SS, wy+6*SS, wx+wsz-6*SS, wy+wsz-6*SS], 185, 300, fill=(255,255,255,150), width=3*SS)
    spec = spec.filter(ImageFilter.GaussianBlur(2*SS))
    canvas.alpha_composite(spec)
    draw = ImageDraw.Draw(canvas, "RGBA")

    # labels
    text(draw, (wcx, wy+int(wsz*0.11)), "MENU", font(11, bold=True), SECON, "ma")
    # prev/next/playpause glyphs
    def glyph_prev(cx, cy, s):
        draw.polygon([(cx+s,cy-s),(cx-s,cy),(cx+s,cy+s)], fill=SECON)
        draw.rectangle([cx-s-3*SS, cy-s, cx-s, cy+s], fill=SECON)
    def glyph_next(cx, cy, s):
        draw.polygon([(cx-s,cy-s),(cx+s,cy),(cx-s,cy+s)], fill=SECON)
        draw.rectangle([cx+s, cy-s, cx+s+3*SS, cy+s], fill=SECON)
    gs = int(wsz*0.045)
    glyph_prev(wx+int(wsz*0.135), wcy, gs)
    glyph_next(wx+int(wsz*0.865), wcy, gs)
    # playpause bottom
    by2 = wy+int(wsz*0.865)
    draw.rectangle([wcx-6*SS, by2-6*SS, wcx-2*SS, by2+6*SS], fill=SECON)
    draw.polygon([(wcx+1*SS,by2-6*SS),(wcx+8*SS,by2),(wcx+1*SS,by2+6*SS)], fill=SECON)

    # center button
    cbr = int(wsz*0.17)
    cb = Image.new("RGBA",(cbr*2,cbr*2),(0,0,0,0))
    cbl = cb.load()
    for y in range(cbr*2):
        for x in range(cbr*2):
            d = math.hypot(x-cbr,y-cbr)
            if d<=cbr:
                t=y/(cbr*2); col=mix((58,60,68),(24,25,30),t); a=255
                if d>cbr-2*SS: a=int(255*(cbr-d)/(2*SS))
                cbl[x,y]=(col[0],col[1],col[2],max(0,a))
    canvas.alpha_composite(cb,(wcx-cbr,wcy-cbr))
    draw = ImageDraw.Draw(canvas, "RGBA")
    # play glyph accent on center
    draw.polygon([(wcx-4*SS,wcy-7*SS),(wcx-4*SS,wcy+7*SS),(wcx+8*SS,wcy)], fill=ACCENT)

    out = canvas.resize((W//SS, H//SS), Image.LANCZOS)
    out.save("docs_out/app_window.png")
    print("wrote docs_out/app_window.png")

# ---------------------------------------------------------------------------
# WIDGETS
# ---------------------------------------------------------------------------
def widget_bg(w, h, r):
    img = vgrad(w, h, (30,30,36),(9,9,13)).convert("RGBA")
    m = rounded_mask(w,h,r)
    out = Image.new("RGBA",(w,h),(0,0,0,0))
    out.paste(img,(0,0),m)
    ImageDraw.Draw(out).rounded_rectangle([0,0,w-1,h-1],radius=r,outline=(255,255,255,24),width=SS)
    return out

def transport(draw, cx, cy, kind, size, playing=True):
    r = size//2
    draw.ellipse([cx-r,cy-r,cx+r,cy+r], fill=(255,255,255,26), outline=(255,255,255,36), width=SS)
    col = ACCENT if kind=="pp" else WHITE
    s = int(size*0.22)
    if kind=="prev":
        draw.polygon([(cx+s,cy-s),(cx-s,cy),(cx+s,cy+s)], fill=col)
        draw.rectangle([cx-s-2*SS,cy-s,cx-s,cy+s], fill=col)
    elif kind=="next":
        draw.polygon([(cx-s,cy-s),(cx+s,cy),(cx-s,cy+s)], fill=col)
        draw.rectangle([cx+s,cy-s,cx+s+2*SS,cy+s], fill=col)
    else:
        if playing:
            draw.rectangle([cx-s, cy-s, cx-2*SS, cy+s], fill=col)
            draw.rectangle([cx+2*SS, cy-s, cx+s, cy+s], fill=col)
        else:
            draw.polygon([(cx-s,cy-s),(cx-s,cy+s),(cx+s,cy)], fill=col)

def render_small():
    w,h=170*SS,170*SS
    c=widget_bg(w,h,24*SS)
    d=ImageDraw.Draw(c,"RGBA")
    paste_rounded(c,album_art(56*SS,1),(12*SS,12*SS,56*SS,56*SS),8*SS,border=(255,255,255,30),shadow=False)
    d=ImageDraw.Draw(c,"RGBA")
    text(d,(12*SS,78*SS),"Nightcall",font(12,bold=True),WHITE,"la")
    text(d,(12*SS,95*SS),"Kavinsky",font(10),SECON,"la")
    progress(d,12*SS,h-30*SS,w-70*SS,0.6)
    transport(d,w-28*SS,h-26*SS,"pp",30*SS,True)
    c.resize((w//SS,h//SS),Image.LANCZOS).save("docs_out/widget_small.png")
    print("wrote widget_small")

def render_medium():
    w,h=360*SS,170*SS
    c=widget_bg(w,h,24*SS)
    paste_rounded(c,album_art(92*SS,2),(16*SS,16*SS,92*SS,92*SS),12*SS,border=(255,255,255,30),shadow=False)
    d=ImageDraw.Draw(c,"RGBA")
    tx=124*SS
    text(d,(tx,22*SS),"Midnight City",font(15,bold=True),WHITE,"la")
    text(d,(tx,44*SS),"M83",font(12),SECON,"la")
    text(d,(tx,62*SS),"Hurry Up, We're Dreaming",font(11),TERT,"la")
    progress(d,tx,104*SS,w-tx-18*SS,0.42)
    cyb=h-34*SS
    ccx=tx+(w-tx-18*SS)//2
    transport(d,ccx-40*SS,cyb,"prev",30*SS)
    transport(d,ccx,cyb,"pp",40*SS,True)
    transport(d,ccx+40*SS,cyb,"next",30*SS)
    c.resize((w//SS,h//SS),Image.LANCZOS).save("docs_out/widget_medium.png")
    print("wrote widget_medium")

def render_large():
    w,h=360*SS,360*SS
    c=widget_bg(w,h,28*SS)
    paste_rounded(c,album_art(150*SS,0),((w-150*SS)//2,20*SS,150*SS,150*SS),16*SS,border=(255,255,255,30),shadow=False)
    d=ImageDraw.Draw(c,"RGBA")
    cx=w//2
    text(d,(cx,186*SS),"Midnight City",font(17,bold=True),WHITE,"ma")
    text(d,(cx,210*SS),"M83",font(13),SECON,"ma")
    text(d,(cx,230*SS),"Hurry Up, We're Dreaming",font(12),TERT,"ma")
    progress(d,30*SS,268*SS,w-60*SS,0.42)
    cyb=316*SS
    transport(d,cx-64*SS,cyb,"prev",34*SS)
    transport(d,cx,cyb,"pp",52*SS,True)
    transport(d,cx+64*SS,cyb,"next",34*SS)
    c.resize((w//SS,h//SS),Image.LANCZOS).save("docs_out/widget_large.png")
    print("wrote widget_large")

def compose_widgets():
    small=Image.open("docs_out/widget_small.png").convert("RGBA")
    med=Image.open("docs_out/widget_medium.png").convert("RGBA")
    large=Image.open("docs_out/widget_large.png").convert("RGBA")
    pad=28
    leftw=max(small.width, med.width)
    lefth=small.height+pad+med.height
    W=pad*3+leftw+large.width
    H=pad*2+max(lefth, large.height)
    bg=vgrad(W,H,(22,22,27),(12,12,16)).convert("RGBA")
    # left column: small + medium stacked
    bg.alpha_composite(small,(pad, pad))
    bg.alpha_composite(med,(pad, pad+small.height+pad))
    # right: large
    bg.alpha_composite(large,(pad*2+leftw, pad))
    bg.save("docs_out/widgets.png")
    print("wrote docs_out/widgets.png")

render_app()
render_small()
render_medium()
render_large()
compose_widgets()
print("done")
