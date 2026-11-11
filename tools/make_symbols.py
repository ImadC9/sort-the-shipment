"""Cargo symbols: one soft, rounded shape per colour (colour-blind aid).

Writes
  assets/textures/cargo_symbols.png   3x3 atlas for the container shader
                                      (R = fill, G = soft drop shadow)
  assets/ui/sym/sym_N.png             white shapes for the 2D UI
  assets/ui/sym/badge_N.png           round ship badges (white disc, coloured symbol)
"""
import math
import os
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from art_palette import CARGO, rgb  # noqa: E402

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
S = 4                 # supersampling
CELL = 256


def poly(pts, round_px):
    """Filled polygon with rounded corners (blur + threshold), size CELL*S, mode L."""
    n = CELL * S
    im = Image.new("L", (n, n), 0)
    ImageDraw.Draw(im).polygon([(x * n, y * n) for x, y in pts], fill=255)
    if round_px > 0:
        im = im.filter(ImageFilter.GaussianBlur(round_px * S))
        im = im.point(lambda v: 255 if v > 127 else 0)
        im = im.filter(ImageFilter.GaussianBlur(S * 0.6))
    return im


def ngon(n, r, rot=-90.0, cx=0.5, cy=0.5):
    return [(cx + r * math.cos(math.radians(rot + 360.0 * i / n)), cy + r * math.sin(math.radians(rot + 360.0 * i / n))) for i in range(n)]


def star(r1, r2, cy=0.52):
    pts = []
    for i in range(10):
        a = math.radians(-90 + 36 * i)
        r = r1 if i % 2 == 0 else r2
        pts.append((0.5 + r * math.cos(a), cy + r * math.sin(a)))
    return pts


def shape(i):
    n = CELL * S
    if i == 0:      # circle
        im = Image.new("L", (n, n), 0)
        ImageDraw.Draw(im).ellipse([n * 0.16, n * 0.16, n * 0.84, n * 0.84], fill=255)
        return im.filter(ImageFilter.GaussianBlur(S * 0.6))
    if i == 1:      # square
        return poly([(0.2, 0.2), (0.8, 0.2), (0.8, 0.8), (0.2, 0.8)], 9)
    if i == 2:      # triangle
        return poly(ngon(3, 0.42, cy=0.56), 9)
    if i == 3:      # star
        return poly(star(0.42, 0.2), 6)
    if i == 4:      # diamond
        return poly([(0.5, 0.1), (0.86, 0.5), (0.5, 0.9), (0.14, 0.5)], 9)
    if i == 5:      # heart
        im = Image.new("L", (n, n), 0)
        d = ImageDraw.Draw(im)
        r = 0.2
        d.ellipse([n * (0.33 - r), n * (0.37 - r), n * (0.33 + r), n * (0.37 + r)], fill=255)
        d.ellipse([n * (0.67 - r), n * (0.37 - r), n * (0.67 + r), n * (0.37 + r)], fill=255)
        d.polygon([(n * 0.145, n * 0.45), (n * 0.855, n * 0.45), (n * 0.5, n * 0.88)], fill=255)
        im = im.filter(ImageFilter.GaussianBlur(5 * S)).point(lambda v: 255 if v > 127 else 0)
        return im.filter(ImageFilter.GaussianBlur(S * 0.6))
    if i == 6:      # plus
        a, b = 0.37, 0.63
        return poly([(a, 0.14), (b, 0.14), (b, a), (0.86, a), (0.86, b), (b, b), (b, 0.86), (a, 0.86), (a, b), (0.14, b), (0.14, a), (a, a)], 7)
    if i == 7:      # pentagon
        return poly(ngon(5, 0.38, cy=0.52), 9)
    # 8: question mark for covered cargo
    im = Image.new("L", (n, n), 0)
    f = ImageFont.truetype(os.path.join(ROOT, "assets/fonts/Fredoka-Bold.ttf"), int(n * 0.78))
    d = ImageDraw.Draw(im)
    box = d.textbbox((0, 0), "?", font=f)
    d.text(((n - (box[2] - box[0])) / 2 - box[0], (n - (box[3] - box[1])) / 2 - box[1]), "?", font=f, fill=255)
    return im


def main():
    atlas = Image.new("RGB", (CELL * 3, CELL * 3), (0, 0, 0))
    for i in range(9):
        big = shape(i)
        fill = big.resize((CELL, CELL), Image.LANCZOS)
        # soft shadow: blurred copy pushed down a little
        sh = ImageChops.offset(big, 0, int(CELL * S * 0.035)).filter(ImageFilter.GaussianBlur(CELL * S * 0.03))
        sh = sh.resize((CELL, CELL), Image.LANCZOS)
        cell = Image.merge("RGB", (fill, sh, Image.new("L", (CELL, CELL), 0)))
        atlas.paste(cell, ((i % 3) * CELL, (i // 3) * CELL))
        # UI sprite, white on transparent, tight 160 px
        ui = Image.new("RGBA", (CELL, CELL), (255, 255, 255, 0))
        ui.putalpha(fill)
        ui.resize((160, 160), Image.LANCZOS).save(os.path.join(ROOT, "assets/ui/sym/sym_%d.png" % i))
        if i < 8:
            badge(i, big)
    atlas.save(os.path.join(ROOT, "assets/textures/cargo_symbols.png"))
    print("symbols written")


def badge(i, big):
    """Ship badge: white disc, coloured ring and symbol, soft drop shadow."""
    n = 256
    s = 4
    col = rgb(CARGO[i])
    im = Image.new("RGBA", (n * s, n * s), (0, 0, 0, 0))
    sh = Image.new("L", (n * s, n * s), 0)
    ImageDraw.Draw(sh).ellipse([n * s * 0.1, n * s * 0.14, n * s * 0.9, n * s * 0.94], fill=110)
    sh = sh.filter(ImageFilter.GaussianBlur(n * s * 0.025))
    im.paste((20, 40, 70, 255), (0, 0), sh)
    d = ImageDraw.Draw(im)
    d.ellipse([n * s * 0.09, n * s * 0.07, n * s * 0.91, n * s * 0.89], fill=(255, 255, 255, 255))
    d.ellipse([n * s * 0.135, n * s * 0.115, n * s * 0.865, n * s * 0.845], fill=col)
    d.ellipse([n * s * 0.175, n * s * 0.155, n * s * 0.825, n * s * 0.805], fill=(255, 255, 255, 255))
    symn = int(n * s * 0.5)
    sym = big.resize((symn, symn), Image.LANCZOS)
    im.paste(col, (int(n * s * 0.5 - symn / 2), int(n * s * 0.48 - symn / 2)), sym)
    im.resize((n, n), Image.LANCZOS).save(os.path.join(ROOT, "assets/ui/sym/badge_%d.png" % i))


if __name__ == "__main__":
    main()
