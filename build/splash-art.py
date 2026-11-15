#!/usr/bin/env python3
# ==============================================================================
# TEBIAN SPLASH ART
# Draws the boot splash's two pictures from the wordmark (assets/logo/
# tebian.svg, the one on tebian.org):
#   title.png   the letters
#   glow.png    a soft white halo of the same letters, same size, so the
#               splash can lay one over the other and let the halo breathe
# Plymouth can only show ready-made pictures, so they are committed; run
# this again only when the wordmark changes:
#   python3 build/splash-art.py
# Needs python3-gi and the SVG loader for gdk-pixbuf (librsvg2-common),
# both on any Tebian desktop. build/ is left out of the ISO.
# ==============================================================================
import os, sys, gi
gi.require_version("GdkPixbuf", "2.0")
from gi.repository import GdkPixbuf, GLib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
svg = os.path.join(ROOT, "assets/logo/tebian.svg")
outdir = os.path.join(ROOT, "assets/plymouth/tebian")

# Letters this wide, with room around them for the halo to fade out in.
# tebian.script scales the pictures down to the screen; MARGIN is repeated
# there (title_part) to know how much of the picture is letters.
W, MARGIN = 1200, 140
src = open(svg).read().replace("currentColor", "#ffffff")
loader = GdkPixbuf.PixbufLoader.new_with_type("svg")
H = round(W * 101.5 / 709.85)
loader.set_size(W, H); loader.write(src.encode()); loader.close()
pb = loader.get_pixbuf()
assert pb.get_has_alpha() and pb.get_width() == W
cw, ch = W + 2 * MARGIN, H + 2 * MARGIN
px, rs = pb.get_pixels(), pb.get_rowstride()
alpha = [[0.0] * cw for _ in range(ch)]
for y in range(H):
    row = alpha[y + MARGIN]
    for x in range(W):
        row[x + MARGIN] = px[y * rs + x * 4 + 3] / 255.0

def box(rows, r):          # one horizontal box blur, radius r, sliding window
    out = []
    n = 2 * r + 1
    for row in rows:
        acc = sum(row[:r + 1]); o = [0.0] * len(row)
        for x in range(len(row)):
            o[x] = acc / n
            if x + r + 1 < len(row): acc += row[x + r + 1]
            if x - r >= 0: acc -= row[x - r]
        out.append(o)
    return out
def blur(rows, r):         # three box passes each way ~ a gaussian
    for _ in range(3): rows = box(rows, r)
    rows = [list(c) for c in zip(*rows)]
    for _ in range(3): rows = box(rows, r)
    return [list(c) for c in zip(*rows)]

tight, wide = blur(alpha, 7), blur(alpha, 26)
def save(name, a_of, rgb):
    buf = bytearray(cw * ch * 4)
    for y in range(ch):
        for x in range(cw):
            i = (y * cw + x) * 4
            buf[i], buf[i+1], buf[i+2] = rgb
            buf[i+3] = max(0, min(255, round(a_of(x, y) * 255)))
    GdkPixbuf.Pixbuf.new_from_bytes(GLib.Bytes.new(bytes(buf)), GdkPixbuf.Colorspace.RGB, True, 8, cw, ch, cw * 4).savev(f"{outdir}/{name}", "png", ["compression"], ["9"])
save("title.png", lambda x, y: alpha[y][x], (238, 241, 255))
save("glow.png", lambda x, y: min(1.0, 0.55 * tight[y][x] + 0.9 * wide[y][x]), (255, 255, 255))
print(f"{outdir}: title.png, glow.png ({cw}x{ch})")
