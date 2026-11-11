"""Builds assets/textures/cargo_symbols.png: the eight colour symbols plus "?"
in a 3x3 grid of 128 px cells. R = glyph fill, G = soft outline.
The container shader paints them on the roof and the door end (no Label3D).

Usage: python3 tools/make_symbol_atlas.py
"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy import ndimage

ROOT = Path(__file__).resolve().parent.parent
SYMBOLS = ["●", "■", "▲", "★", "◆", "♥", "✚", "⬟", "?"]   # = Pal.SYMBOL + covered
CELL = 128
font = ImageFont.truetype(str(ROOT / "assets/fonts/DejaVuSans-Bold.ttf"), 96)
fill = np.zeros((CELL * 3, CELL * 3))
for i, s in enumerate(SYMBOLS):
    img = Image.new("L", (CELL * 4, CELL * 4), 0)
    d = ImageDraw.Draw(img)
    d.text((CELL * 2, CELL * 2), s, font=font, fill=255, anchor="mm")
    a = np.asarray(img, dtype=float) / 255
    ys, xs = np.nonzero(a > 0.05)
    cy, cx = (ys.min() + ys.max()) / 2, (xs.min() + xs.max()) / 2
    a = ndimage.shift(a, (CELL * 2 - cy, CELL * 2 - cx), order=1)
    gx, gy = i % 3, i // 3
    fill[gy * CELL:(gy + 1) * CELL, gx * CELL:(gx + 1) * CELL] = a[CELL * 2 - CELL // 2:CELL * 2 + CELL // 2, CELL * 2 - CELL // 2:CELL * 2 + CELL // 2]
outline = np.clip(ndimage.gaussian_filter(ndimage.grey_dilation(fill, size=(9, 9)), 2.0) * 1.2, 0, 1)
rgba = np.stack([fill, outline, np.zeros_like(fill), np.ones_like(fill)], -1)
out = ROOT / "assets/textures/cargo_symbols.png"
Image.fromarray((rgba * 255).astype(np.uint8), "RGBA").save(out, optimize=True)
print("wrote", out)
