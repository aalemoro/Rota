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

def progress(draw, x, y, w, frac, h=4, knob=False):
    h*=SS
    draw.rounded_rectangle([x, y, x+w, y+h], radius=h//2, fill=(255,255,255,46))
    fw = max(2*SS, int(w*frac))
    draw.rounded_rectangle([x, y, x+fw, y+h], radius=h//2, fill=ACCENT)
    if knob:
        kx = x+fw
        ky = y+h//2
        kr = int(7*SS)
        # glow
        draw.ellipse([kx-kr-2*SS, ky-kr-2*SS, kx+kr+2*SS, ky+kr+2*SS], fill=(ACCENT[0],ACCENT[1],ACCENT[2],80))
        draw.ellipse([kx-kr, ky-kr, kx+kr, ky+kr], fill=(250,250,252,255), outline=ACCENT, width=2*SS)

def draw_shuffle(draw, cx, cy, s, col):
    # two crossing arrows
    w = 2*SS
    draw.line([(cx-s, cy-s), (cx+s, cy+s)], fill=col, width=w)
    draw.line([(cx-s, cy+s), (cx+s, cy-s)], fill=col, width=w)
    for ex, ey in [(cx+s, cy+s), (cx+s, cy-s)]:
        sy = -1 if ey<cy else 1
        draw.polygon([(ex, ey), (ex-int(s*0.5), ey), (ex, ey-sy*int(s*0.5))], fill=col)

def draw_repeat(draw, cx, cy, s, col, one=False):
    w = 2*SS
    draw.arc([cx-s, cy-s, cx+s, cy+s], 300, 210, fill=col, width=w)
    # arrowhead at top-right
    draw.polygon([(cx+s, cy-int(s*0.2)), (cx+int(s*0.4), cy-s), (cx+int(s*1.0), cy-s)], fill=col)
    if one:
        text(draw, (cx, cy+int(s*0.05)), "1", font(9, bold=True), col, "mm")

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

def transport(draw, cx, cy, kind, size, playing=True, active=False, circle=True):
    s = int(size*0.22)
    if kind in ("shuffle", "repeat", "repeat1"):
        col = ACCENT if active else WHITE
        gs = int(size*0.34)
        if kind=="shuffle":
            draw_shuffle(draw, cx, cy, gs, col)
        else:
            draw_repeat(draw, cx, cy, gs, col, one=(kind=="repeat1"))
        return
    if circle:
        r = size//2
        draw.ellipse([cx-r,cy-r,cx+r,cy+r], fill=(255,255,255,26), outline=(255,255,255,36), width=SS)
    col = ACCENT if kind=="pp" else WHITE
    t = int(size*0.30)   # triangle half-height for skip glyphs
    if kind=="prev":
        # double triangle (skip back)
        draw.polygon([(cx,cy-t),(cx-t,cy),(cx,cy+t)], fill=col)
        draw.polygon([(cx+t,cy-t),(cx,cy),(cx+t,cy+t)], fill=col)
    elif kind=="next":
        draw.polygon([(cx,cy-t),(cx+t,cy),(cx,cy+t)], fill=col)
        draw.polygon([(cx-t,cy-t),(cx,cy),(cx-t,cy+t)], fill=col)
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
    progress(d,12*SS,h-30*SS,w-70*SS,0.6,knob=True)
    transport(d,w-28*SS,h-26*SS,"pp",30*SS,True)
    c.resize((w//SS,h//SS),Image.LANCZOS).save("docs_out/widget_small.png")
    print("wrote widget_small")

def render_medium():
    w,h=360*SS,170*SS
    c=widget_bg(w,h,24*SS)
    paste_rounded(c,album_art(92*SS,2),(16*SS,16*SS,92*SS,92*SS),12*SS,border=(255,255,255,30),shadow=False)
    d=ImageDraw.Draw(c,"RGBA")
    tx=124*SS
    text(d,(tx,20*SS),"Dancin (Krono Remix)",font(14,bold=True),WHITE,"la")
    text(d,(tx,40*SS),"Aaron Smith · feat. Luvli",font(11),SECON,"la")
    pw=w-tx-18*SS
    progress(d,tx,72*SS,pw,0.2,knob=True)
    cyb=h-32*SS
    left=tx
    right=w-18*SS
    xs=[left, left+(right-left)*0.25, (left+right)/2, left+(right-left)*0.75, right]
    transport(d,int(xs[0]),cyb,"shuffle",22*SS,active=False)
    transport(d,int(xs[1]),cyb,"prev",26*SS,circle=False)
    transport(d,int(xs[2]),cyb,"pp",34*SS,True,circle=False)
    transport(d,int(xs[3]),cyb,"next",26*SS,circle=False)
    transport(d,int(xs[4]),cyb,"repeat",22*SS,active=True)
    c.resize((w//SS,h//SS),Image.LANCZOS).save("docs_out/widget_medium.png")
    print("wrote widget_medium")

def render_large():
    w,h=360*SS,360*SS
    c=widget_bg(w,h,28*SS)
    paste_rounded(c,album_art(150*SS,0),((w-150*SS)//2,20*SS,150*SS,150*SS),16*SS,border=(255,255,255,30),shadow=False)
    d=ImageDraw.Draw(c,"RGBA")
    cx=w//2
    text(d,(cx,186*SS),"Dancin (Krono Remix)",font(16,bold=True),WHITE,"ma")
    text(d,(cx,209*SS),"Aaron Smith · feat. Luvli",font(12),SECON,"ma")
    progress(d,30*SS,258*SS,w-60*SS,0.2,knob=True)
    cyb=312*SS
    left=40*SS; right=w-40*SS
    xs=[left, left+(right-left)*0.25, (left+right)/2, left+(right-left)*0.75, right]
    transport(d,int(xs[0]),cyb,"shuffle",24*SS,active=False)
    transport(d,int(xs[1]),cyb,"prev",32*SS,circle=False)
    transport(d,int(xs[2]),cyb,"pp",46*SS,True,circle=False)
    transport(d,int(xs[3]),cyb,"next",32*SS,circle=False)
    transport(d,int(xs[4]),cyb,"repeat",24*SS,active=True)
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

def neon_text(base, s, cx, cy, f, glow_col, core=(255,255,255)):
    """Draw glowing neon-style text centred at (cx,cy)."""
    layer = Image.new("RGBA", base.size, (0,0,0,0))
    dl = ImageDraw.Draw(layer)
    dl.text((cx, cy), s, font=f, fill=(glow_col[0],glow_col[1],glow_col[2],255), anchor="mm")
    glow = layer.filter(ImageFilter.GaussianBlur(6*SS))
    base.alpha_composite(glow)
    base.alpha_composite(glow)
    d = ImageDraw.Draw(base)
    d.text((cx, cy), s, font=f, fill=glow_col, anchor="mm")

def neon_cover(size):
    """A stylised neon album cover echoing the reference art."""
    img = diag_grad(size, size, (46,20,30), (28,14,20)).convert("RGBA")
    d = ImageDraw.Draw(img, "RGBA")
    # warm vignette
    for r in range(int(size*0.7), 0, -6):
        a = int(40*(1-r/(size*0.7)))
        d.ellipse([size*0.5-r, size*0.35-r, size*0.5+r, size*0.35+r], fill=(120,40,60,a))
    img = img.filter(ImageFilter.GaussianBlur(size*0.01))
    neon_text(img, "DANCIN", size*0.5, size*0.40, font(int(size*0.115), bold=True), (245,240,70))
    neon_text(img, "KRONO REMIX", size*0.5, size*0.53, font(int(size*0.062), bold=True), (245,240,70))
    neon_text(img, "AARON SMITH · FEAT LUVLI", size*0.5, size*0.64, font(int(size*0.038), bold=True), (232,72,212))
    return img.convert("RGB")

def traffic_lights(draw, x, y, r=6):
    for i,col in enumerate([(255,95,86),(255,189,46),(39,201,63)]):
        cx=x+i*(r*2+6*SS)
        draw.ellipse([cx-r, y-r, cx+r, y+r], fill=col)

def render_miniplayer():
    W,H=340*SS,360*SS
    canvas=Image.new("RGBA",(W,H),(0,0,0,0))
    cover=neon_cover(W).resize((W,H),Image.LANCZOS).convert("RGBA")
    m=rounded_mask(W,H,26*SS)
    canvas.paste(cover,(0,0),m)
    # glass scrim bottom
    scrim=Image.new("RGBA",(W,H),(0,0,0,0))
    sp=scrim.load()
    for y in range(H):
        t=y/(H-1)
        a=int(255*max(0,(t-0.35))/0.65*0.86) if t>0.35 else 0
        for x in range(W):
            sp[x,y]=(0,0,0,a)
    scrim2=Image.new("RGBA",(W,H),(0,0,0,0))
    scrim2.paste(scrim,(0,0),m)
    canvas.alpha_composite(scrim2)
    d=ImageDraw.Draw(canvas,"RGBA")
    # border
    d.rounded_rectangle([0,0,W-1,H-1],radius=26*SS,outline=(255,255,255,36),width=SS)
    # traffic lights
    traffic_lights(d, 22*SS, 24*SS, r=6*SS)
    # top-right glass buttons (dark translucent glass, white icons)
    GLASS=(15,15,18,120); GLASS_B=(255,255,255,55)
    by=24*SS; br=15*SS
    # volume (far right circle)
    vx=W-30*SS
    d.ellipse([vx-br,by,vx+br,by+2*br], fill=GLASS, outline=GLASS_B, width=SS)
    d.polygon([(vx-6*SS,by+br-4*SS),(vx-2*SS,by+br-4*SS),(vx+2*SS,by+br-8*SS),(vx+2*SS,by+br+8*SS),(vx-2*SS,by+br+4*SS),(vx-6*SS,by+br+4*SS)], fill=WHITE)
    d.arc([vx+3*SS,by+br-7*SS,vx+11*SS,by+br+7*SS], -60,60, fill=WHITE, width=2*SS)
    # lyrics + list pill
    d.rounded_rectangle([W-118*SS, by, W-52*SS, by+2*br], radius=br, fill=GLASS, outline=GLASS_B, width=SS)
    # lyrics quote bubble
    qx=W-101*SS
    d.rounded_rectangle([qx-8*SS, by+br-7*SS, qx+8*SS, by+br+4*SS], radius=3*SS, fill=WHITE)
    d.polygon([(qx-4*SS,by+br+3*SS),(qx-4*SS,by+br+8*SS),(qx+1*SS,by+br+3*SS)], fill=WHITE)
    d.text((qx-4*SS, by+br-6*SS), "”", font=font(10,bold=True), fill=GLASS[:3], anchor="lm")
    # list icon
    lx=W-77*SS
    for i in range(3):
        yy=by+br-6*SS+i*6*SS
        d.line([(lx, yy),(lx+12*SS, yy)], fill=WHITE, width=2*SS)
        d.ellipse([lx-6*SS, yy-2*SS, lx-2*SS, yy+2*SS], fill=WHITE)
    # title / artist (marquee-like)
    ty=H-116*SS
    text(d,(20*SS, ty),"Dancin (Krono Remix)",font(15,bold=True),WHITE,"la")
    text(d,(20*SS, ty+22*SS),"Aaron Smith · feat. Luvli",font(11),(225,225,230),"la")
    # star + ...
    for i,(gx,gl) in enumerate([(W-58*SS,"★"),(W-26*SS,"···")]):
        d.ellipse([gx-13*SS, ty+2*SS, gx+13*SS, ty+28*SS], fill=GLASS, outline=GLASS_B, width=SS)
        text(d,(gx, ty+15*SS - (3*SS if gl=="···" else 0)), gl, font(11,bold=True), WHITE, "mm")
    # progress with knob
    py=H-70*SS
    progress(d, 20*SS, py, W-40*SS, 0.09, knob=True)
    text(d,(20*SS, py+12*SS),"0:17",font(9,mono=True),(215,215,220),"la")
    text(d,(W-20*SS, py+12*SS),"-3:01",font(9,mono=True),(215,215,220),"ra")
    # transport row — plain white glyphs, no circles (matches reference)
    cyb=H-32*SS
    left=32*SS; right=W-32*SS
    xs=[left, left+(right-left)*0.25, (left+right)/2, left+(right-left)*0.75, right]
    transport(d,int(xs[0]),cyb,"shuffle",22*SS,active=False)
    transport(d,int(xs[1]),cyb,"prev",26*SS,circle=False)
    # plain pause glyph, larger
    d.rectangle([int(xs[2])-9*SS, cyb-13*SS, int(xs[2])-2*SS, cyb+13*SS], fill=WHITE)
    d.rectangle([int(xs[2])+2*SS, cyb-13*SS, int(xs[2])+9*SS, cyb+13*SS], fill=WHITE)
    transport(d,int(xs[3]),cyb,"next",26*SS,circle=False)
    transport(d,int(xs[4]),cyb,"repeat",22*SS,active=False)

    out=canvas.resize((W//SS,H//SS),Image.LANCZOS)
    out.save("docs_out/mini_player.png")
    print("wrote docs_out/mini_player.png")

render_app()
render_miniplayer()
render_small()
render_medium()
render_large()
compose_widgets()
print("done")
