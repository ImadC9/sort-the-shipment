"""Interface art for the Toy Harbour look.

Writes into assets/ui:
  btn*.png, card.png, pill.png, chip.png, well.png   nine-patch surfaces
  coin.png, star.png, star_empty.png, crate*.png     full-colour sprites
  icons/*.svg                                        white line icons (tinted in game)
"""
import math
import os
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from art_palette import rgb  # noqa: E402

UI = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "ui")
S = 4


def rr(size, box, r, fill):
    im = Image.new("RGBA", size, (0, 0, 0, 0))
    ImageDraw.Draw(im).rounded_rectangle(box, r, fill=fill)
    return im


def shadow(size, box, r, col, blur, dy):
    m = Image.new("L", size, 0)
    ImageDraw.Draw(m).rounded_rectangle([box[0], box[1] + dy, box[2], box[3] + dy], r, fill=col[3])
    m = m.filter(ImageFilter.GaussianBlur(blur))
    out = Image.new("RGBA", size, col[:3] + (0,))
    out.putalpha(m)
    return out


def vgrad(size, box, r, top, bot):
    """Rounded rect with a vertical gradient."""
    w, h = size
    g = Image.new("RGBA", size, (0, 0, 0, 0))
    px = g.load()
    y0, y1 = int(box[1]), int(box[3])
    for y in range(max(0, y0), min(h, y1 + 1)):
        t = (y - y0) / max(1, y1 - y0)
        c = tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(4))
        for x in range(w):
            px[x, y] = c
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(box, r, fill=255)
    g.putalpha(ImageChops.multiply(g.getchannel("A"), mask))
    return g


def surface(name, w, h, r, face_top, face_bot, lip_col, lip, pad, sh=(18, 38, 66, 70), sh_blur=7, sh_dy=5, press=0,
            inner=None):
    """A raised surface: soft shadow, a darker lip under a gradient face.
    pad = transparent margin round the shape (room for the shadow)."""
    W, H = (w + pad * 2) * S, (h + pad * 2 + lip) * S
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    x0, y0, x1 = pad * S, (pad + press) * S, (pad + w) * S
    y1 = (pad + h) * S
    yl = (pad + h + lip) * S
    if sh[3] > 0:
        im.alpha_composite(shadow((W, H), [x0, y0, x1, yl], r * S, sh, sh_blur * S, sh_dy * S))
    if lip - press > 0:
        im.alpha_composite(rr((W, H), [x0, y0 + 8 * S, x1, yl], r * S, lip_col))
    im.alpha_composite(vgrad((W, H), [x0, y0, x1, y1 + press * S], r * S, face_top, face_bot))
    if inner:
        # a hairline of light just inside the top edge
        hl = rr((W, H), [x0 + 3 * S, y0 + 3 * S, x1 - 3 * S, y1 + press * S - 3 * S], (r - 3) * S, inner)
        cut = rr((W, H), [x0 + 3 * S, y0 + 6 * S, x1 - 3 * S, y1 + press * S + 6 * S], (r - 3) * S, (0, 0, 0, 255))
        a = ImageChops.subtract(hl.getchannel("A"), cut.getchannel("A"))
        hl.putalpha(a)
        im.alpha_composite(hl)
    im = im.resize((W // S, H // S), Image.LANCZOS)
    im.save(os.path.join(UI, name + ".png"))
    return im.size


def surfaces():
    paper, paper2, edge = rgb("#fffdf7"), rgb("#fff6e6"), rgb("#e3d5ba")
    # tintable buttons: greys that are multiplied by the button colour in game
    g = lambda v, a=255: (v, v, v, a)
    surface("btn", 80, 72, 30, g(255), g(226), g(160), 10, 12, inner=None)
    surface("btn_down", 80, 72, 30, g(236), g(214), g(160), 10, 12, press=6, sh=(18, 38, 66, 40), sh_blur=4, sh_dy=2)
    surface("btn_s", 56, 50, 20, g(255), g(226), g(160), 7, 10, sh_blur=5, sh_dy=4)
    surface("btn_s_down", 56, 50, 20, g(236), g(214), g(160), 7, 10, press=4, sh=(18, 38, 66, 40), sh_blur=3, sh_dy=2)
    # paper surfaces (final colours)
    surface("paper_btn", 80, 72, 28, paper, paper2, edge, 9, 12, inner=(255, 255, 255, 255))
    surface("paper_btn_down", 80, 72, 28, paper2, rgb("#f6ead4"), edge, 9, 12, press=6, sh=(18, 38, 66, 40), sh_blur=4, sh_dy=2)
    surface("card", 120, 120, 44, paper, paper2, edge, 12, 28, sh=(14, 34, 62, 90), sh_blur=16, sh_dy=10, inner=(255, 255, 255, 255))
    surface("pill", 72, 60, 30, paper, paper2, edge, 6, 10, sh=(18, 38, 66, 60), sh_blur=6, sh_dy=4, inner=(255, 255, 255, 255))
    surface("chip", 44, 40, 18, paper, paper2, edge, 4, 8, sh=(18, 38, 66, 50), sh_blur=4, sh_dy=3)
    surface("nav", 120, 80, 40, paper, paper, edge, 0, 24, sh=(14, 34, 62, 70), sh_blur=14, sh_dy=-6)
    # a sunken well inside a card
    W = H = 64 * S
    im = rr((W, H), [0, 0, W - 1, H - 1], 20 * S, rgb("#f3e9d6"))
    inner = rr((W, H), [0, 5 * S, W - 1, H - 1 + 5 * S], 20 * S, rgb("#f8f0e0"))
    inner.putalpha(ImageChops.multiply(inner.getchannel("A"), im.getchannel("A")))
    im.alpha_composite(inner)
    im.resize((64, 64), Image.LANCZOS).save(os.path.join(UI, "well.png"))
    # tintable flat badge (counter bubbles)
    im = rr((48 * S, 48 * S), [0, 0, 48 * S - 1, 48 * S - 1], 24 * S, (255, 255, 255, 255))
    im.resize((48, 48), Image.LANCZOS).save(os.path.join(UI, "dot.png"))


def star_pts(cx, cy, r1, r2, n=5, rot=-90):
    pts = []
    for i in range(n * 2):
        a = math.radians(rot + 180.0 * i / n)
        r = r1 if i % 2 == 0 else r2
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


def soft_poly(size, pts, round_px):
    m = Image.new("L", size, 0)
    ImageDraw.Draw(m).polygon(pts, fill=255)
    m = m.filter(ImageFilter.GaussianBlur(round_px)).point(lambda v: 255 if v > 127 else 0)
    return m.filter(ImageFilter.GaussianBlur(S * 0.5))


def tint(mask, col):
    im = Image.new("RGBA", mask.size, col[:3] + (0,))
    im.putalpha(mask.point(lambda v: v * col[3] // 255))
    return im


def star(name, face, face2, lip, shine):
    n = 192 * S
    im = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    base = soft_poly((n, n), star_pts(n / 2, n * 0.53, n * 0.47, n * 0.255), 6 * S)
    im.alpha_composite(tint(ImageChops.offset(base, 0, int(n * 0.035)), lip))
    body = soft_poly((n, n), star_pts(n / 2, n * 0.5, n * 0.47, n * 0.255), 6 * S)
    grad = vgrad((n, n), [0, n * 0.05, n, n * 0.95], 0, face, face2)
    grad.putalpha(body)
    im.alpha_composite(grad)
    if shine:
        inner = soft_poly((n, n), star_pts(n / 2, n * 0.5, n * 0.3, n * 0.165), 5 * S)
        im.alpha_composite(tint(inner, shine))
        # glint
        g = Image.new("L", (n, n), 0)
        ImageDraw.Draw(g).ellipse([n * 0.36, n * 0.27, n * 0.47, n * 0.36], fill=235)
        im.alpha_composite(tint(g.filter(ImageFilter.GaussianBlur(S)), (255, 255, 255, 255)))
    im.resize((192, 192), Image.LANCZOS).save(os.path.join(UI, name + ".png"))


def coin():
    n = 128 * S
    im = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.ellipse([n * 0.06, n * 0.12, n * 0.94, n * 1.0], fill=rgb("#d98a10"))
    d.ellipse([n * 0.06, n * 0.04, n * 0.94, n * 0.92], fill=rgb("#ffc533"))
    g = vgrad((n, n), [0, n * 0.12, n, n * 0.84], 0, rgb("#ffe07a"), rgb("#ffc02c"))
    m = Image.new("L", (n, n), 0)
    ImageDraw.Draw(m).ellipse([n * 0.15, n * 0.13, n * 0.85, n * 0.83], fill=255)
    g.putalpha(m)
    im.alpha_composite(g)
    d = ImageDraw.Draw(im)
    d.ellipse([n * 0.15, n * 0.13, n * 0.85, n * 0.83], outline=rgb("#eda71c"), width=int(n * 0.03))
    # anchor emblem
    c = rgb("#e79a12")
    w = int(n * 0.07)
    cx, cy = n * 0.5, n * 0.48
    d.line([cx, cy - n * 0.14, cx, cy + n * 0.2], fill=c, width=w)
    d.line([cx - n * 0.1, cy - n * 0.05, cx + n * 0.1, cy - n * 0.05], fill=c, width=w)
    d.ellipse([cx - n * 0.065, cy - n * 0.26, cx + n * 0.065, cy - n * 0.13], outline=c, width=int(w * 0.8))
    d.arc([cx - n * 0.2, cy - n * 0.14, cx + n * 0.2, cy + n * 0.22], 20, 160, fill=c, width=w)
    for sx in (-1, 1):
        d.ellipse([cx + sx * n * 0.19 - w / 2, cy + n * 0.09 - w / 2, cx + sx * n * 0.19 + w / 2, cy + n * 0.09 + w / 2], fill=c)
    # shine
    sh = Image.new("L", (n, n), 0)
    ImageDraw.Draw(sh).ellipse([n * 0.24, n * 0.2, n * 0.42, n * 0.33], fill=210)
    im.alpha_composite(tint(sh.filter(ImageFilter.GaussianBlur(S * 1.5)), (255, 255, 255, 255)))
    im.resize((128, 128), Image.LANCZOS).save(os.path.join(UI, "coin.png"))


def crate(opened):
    n = 160 * S
    im = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    wood, wood2, dark, gold, gold2 = rgb("#e0a563"), rgb("#cf9150"), rgb("#a86c35"), rgb("#ffc533"), rgb("#e79a12")
    bx = [n * 0.12, n * 0.42, n * 0.88, n * 0.94]
    d.rounded_rectangle([bx[0], bx[1] + n * 0.03, bx[2], bx[3] + n * 0.03], n * 0.06, fill=dark)
    d.rounded_rectangle(bx, n * 0.06, fill=wood)
    for k in range(1, 3):
        y = bx[1] + (bx[3] - bx[1]) * k / 3
        d.line([bx[0] + n * 0.03, y, bx[2] - n * 0.03, y], fill=wood2, width=int(n * 0.02))
    d.rectangle([n * 0.44, bx[1], n * 0.56, bx[3]], fill=gold)
    if opened:
        glow = Image.new("L", (n, n), 0)
        ImageDraw.Draw(glow).ellipse([n * 0.14, n * 0.08, n * 0.86, n * 0.62], fill=200)
        im.alpha_composite(tint(glow.filter(ImageFilter.GaussianBlur(n * 0.05)), (255, 226, 120, 255)))
        d = ImageDraw.Draw(im)
        for i, (px, py) in enumerate([(0.3, 0.3), (0.5, 0.2), (0.7, 0.3), (0.4, 0.36), (0.6, 0.37)]):
            d.ellipse([n * (px - 0.085), n * (py - 0.085) + n * 0.012, n * (px + 0.085), n * (py + 0.085) + n * 0.012], fill=gold2)
            d.ellipse([n * (px - 0.085), n * (py - 0.085), n * (px + 0.085), n * (py + 0.085)], fill=gold)
        d.rounded_rectangle([n * 0.1, n * 0.4, n * 0.9, n * 0.5], n * 0.03, fill=dark)
    else:
        lid = [n * 0.07, n * 0.24, n * 0.93, n * 0.46]
        d.rounded_rectangle([lid[0], lid[1] + n * 0.025, lid[2], lid[3] + n * 0.025], n * 0.06, fill=dark)
        d.rounded_rectangle(lid, n * 0.06, fill=rgb("#ecb675"))
        d.rectangle([n * 0.44, lid[1], n * 0.56, lid[3]], fill=gold)
        d.rounded_rectangle([n * 0.41, n * 0.4, n * 0.59, n * 0.56], n * 0.03, fill=gold2)
        d.ellipse([n * 0.47, n * 0.45, n * 0.53, n * 0.51], fill=rgb("#8a5a1c"))
    im.resize((160, 160), Image.LANCZOS).save(os.path.join(UI, "crate_open.png" if opened else "crate.png"))


# ------------------------------------------------------------------ icons
SVG = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 96 96" width="96" height="96" fill="none" stroke="#fff" stroke-width="9" stroke-linecap="round" stroke-linejoin="round">%s</svg>'
F = 'fill="#fff" stroke="none"'

ICONS = {
    "pause": '<rect x="24" y="20" width="16" height="56" rx="7" %s/><rect x="56" y="20" width="16" height="56" rx="7" %s/>' % (F, F),
    "play": '<path d="M32 20 L76 48 L32 76 Z" fill="#fff" stroke-width="8"/>',
    "close": '<path d="M26 26 L70 70 M70 26 L26 70" stroke-width="12"/>',
    "check": '<path d="M20 50 L40 70 L78 28" stroke-width="13"/>',
    "plus": '<path d="M48 22 V74 M22 48 H74" stroke-width="13"/>',
    "undo": '<path d="M34 24 L16 42 L34 60" stroke-width="10"/><path d="M18 42 H54 a22 22 0 0 1 0 44 H34" stroke-width="10"/>',
    "retry": '<path d="M76 48 a28 28 0 1 1 -9 -20.5" stroke-width="10"/><path d="M70 10 V30 H50" stroke-width="10"/>',
    "hint": '<path d="M48 12 a25 25 0 0 0 -14 45.5 V64 h28 v-6.5 A25 25 0 0 0 48 12 Z" fill="#fff" stroke-width="6"/><path d="M38 76 H58 M42 87 H54" stroke-width="8"/>',
    "settings": '<circle cx="48" cy="48" r="13" stroke-width="10"/><path d="M48 12 V22 M48 74 V84 M12 48 H22 M74 48 H84 M22.5 22.5 L29.6 29.6 M66.4 66.4 L73.5 73.5 M22.5 73.5 L29.6 66.4 M66.4 29.6 L73.5 22.5" stroke-width="12"/>',
    "home": '<path d="M14 46 L48 16 L82 46" stroke-width="10"/><path d="M24 44 V78 H40 V58 H56 V78 H72 V44" fill="#fff" stroke-width="6"/>',
    "map": '<path d="M12 26 L36 16 L60 26 L84 16 V70 L60 80 L36 70 L12 80 Z" stroke-width="8"/><path d="M36 16 V70 M60 26 V80" stroke-width="7"/>',
    "anchor": '<circle cx="48" cy="20" r="8" stroke-width="8"/><path d="M48 28 V82 M30 42 H66" stroke-width="9"/><path d="M16 56 a32 28 0 0 0 64 0" stroke-width="9"/>',
    "lock": '<rect x="20" y="42" width="56" height="42" rx="10" %s/><path d="M32 42 V32 a16 16 0 0 1 32 0 V42" stroke-width="10"/>' % F,
    "music": '<path d="M36 68 V22 L74 14 V60" stroke-width="9"/><circle cx="26" cy="70" r="11" %s/><circle cx="64" cy="62" r="11" %s/>' % (F, F),
    "sound": '<path d="M14 38 H30 L50 20 V76 L30 58 H14 Z" fill="#fff" stroke-width="6"/><path d="M62 34 a20 20 0 0 1 0 28 M72 22 a36 36 0 0 1 0 52" stroke-width="8"/>',
    "vibrate": '<rect x="32" y="14" width="32" height="68" rx="8" stroke-width="8"/><path d="M16 34 V62 M80 34 V62" stroke-width="8"/>',
    "motion": '<circle cx="62" cy="48" r="20" %s/><path d="M10 34 H30 M6 48 H28 M10 62 H30" stroke-width="8"/>' % F,
    "ad": '<rect x="10" y="20" width="76" height="52" rx="10" stroke-width="8"/><path d="M40 34 L60 46 L40 58 Z" fill="#fff" stroke-width="5"/><path d="M34 84 H62" stroke-width="8"/>',
    "ship": '<path d="M10 54 H86 L76 80 H22 Z" fill="#fff" stroke-width="6"/><rect x="24" y="30" width="20" height="20" rx="3" %s/><rect x="50" y="38" width="24" height="12" rx="3" %s/><path d="M34 30 V16" stroke-width="8"/>' % (F, F),
    "star": '<path d="M48 10 L59 36 L87 38 L65 56 L72 84 L48 68 L24 84 L31 56 L9 38 L37 36 Z" fill="#fff" stroke-width="6"/>',
    "gift": '<rect x="14" y="40" width="68" height="42" rx="6" stroke-width="8"/><path d="M10 28 H86 V40 H10 Z M48 28 V82" stroke-width="8"/><path d="M48 28 C36 8 20 18 30 28 M48 28 C60 8 76 18 66 28" stroke-width="7"/>',
    # harbour projects
    "p_lighthouse": '<path d="M36 84 L42 34 H54 L60 84 Z" fill="#fff" stroke-width="6"/><path d="M38 34 L48 16 L58 34 Z" fill="#fff" stroke-width="6"/><path d="M26 84 H70" stroke-width="8"/><path d="M14 22 L30 28 M82 22 L66 28" stroke-width="7"/>',
    "p_bunting": '<path d="M8 22 Q48 46 88 22" stroke-width="6"/><path d="M18 30 L30 34 L22 50 Z M40 38 L56 38 L48 56 Z M66 34 L78 30 L74 50 Z" fill="#fff" stroke-width="4"/>',
    "p_cafe": '<path d="M18 36 H66 V58 a18 18 0 0 1 -18 18 H36 a18 18 0 0 1 -18 -18 Z" fill="#fff" stroke-width="6"/><path d="M66 42 h6 a10 10 0 0 1 0 20 h-6" stroke-width="8"/><path d="M32 12 q6 8 0 14 M48 12 q6 8 0 14" stroke-width="6"/>',
    "p_planters": '<circle cx="48" cy="34" r="9" %s/><circle cx="48" cy="16" r="9" %s/><circle cx="31" cy="27" r="9" %s/><circle cx="65" cy="27" r="9" %s/><circle cx="37" cy="47" r="9" %s/><circle cx="59" cy="47" r="9" %s/><path d="M48 56 V84 M48 74 q-16 0 -18 -12 M48 74 q16 0 18 -12" stroke-width="7"/>' % (F, F, F, F, F, F),
    "p_fireworks": '<path d="M48 12 V30 M48 66 V84 M12 48 H30 M66 48 H84 M22 22 L35 35 M61 61 L74 74 M22 74 L35 61 M61 35 L74 22" stroke-width="9"/><circle cx="48" cy="48" r="7" %s/>' % F,
    "p_fountain": '<path d="M12 62 H84 a36 22 0 0 1 -72 0 Z" fill="#fff" stroke-width="6"/><path d="M48 60 V28 M48 28 q-18 -14 -22 10 M48 28 q18 -14 22 10" stroke-width="8"/>',
    "p_clocktower": '<circle cx="48" cy="48" r="34" stroke-width="9"/><path d="M48 28 V48 L62 58" stroke-width="9"/>',
    "p_cranes": '<path d="M24 86 V20 H82 M24 34 L44 20 M70 20 V46" stroke-width="9"/><rect x="60" y="48" width="20" height="16" rx="3" %s/><path d="M12 86 H40" stroke-width="9"/>' % F,
    "p_solar": '<circle cx="48" cy="48" r="16" %s/><path d="M48 10 V20 M48 76 V86 M10 48 H20 M76 48 H86 M21 21 L28 28 M68 68 L75 75 M21 75 L28 68 M68 28 L75 21" stroke-width="9"/>' % F,
    "p_lamps": '<path d="M48 86 V44 M34 86 H62" stroke-width="9"/><path d="M30 44 H66 L60 16 H36 Z" fill="#fff" stroke-width="6"/>',
    "p_flags": '<path d="M24 88 V12" stroke-width="9"/><path d="M24 16 H78 L64 34 L78 52 H24 Z" fill="#fff" stroke-width="6"/>',
    "p_pool": '<path d="M10 40 q10 -12 19 0 t19 0 t19 0 t19 0 M10 60 q10 -12 19 0 t19 0 t19 0 t19 0 M10 80 q10 -12 19 0 t19 0 t19 0 t19 0" stroke-width="8"/>',
    "p_gardens": '<circle cx="48" cy="36" r="26" %s/><path d="M48 50 V88" stroke-width="10"/>' % F,
    "p_icecream": '<path d="M30 46 L48 88 L66 46 Z" fill="#fff" stroke-width="6"/><circle cx="48" cy="30" r="20" %s/>' % F,
    "p_fairylights": '<path d="M48 8 L54 30 L76 36 L54 42 L48 64 L42 42 L20 36 L42 30 Z" fill="#fff" stroke-width="4"/><path d="M74 58 L77 68 L87 71 L77 74 L74 84 L71 74 L61 71 L71 68 Z" fill="#fff" stroke-width="3"/>',
    "p_monument": '<path d="M30 14 H66 V34 a18 18 0 0 1 -36 0 Z" fill="#fff" stroke-width="6"/><path d="M30 20 H16 a14 14 0 0 0 16 20 M66 20 H80 a14 14 0 0 1 -16 20 M48 52 V70 M30 82 H66 M36 70 H60" stroke-width="7"/>',
    "p_liveries": '<path d="M14 60 L50 24 L72 46 L36 82 H14 Z" fill="#fff" stroke-width="6"/><path d="M58 16 L80 38" stroke-width="10"/>',
}


def icons():
    for name, body in ICONS.items():
        with open(os.path.join(UI, "icons", name + ".svg"), "w") as f:
            f.write(SVG % body)


if __name__ == "__main__":
    surfaces()
    star("star", rgb("#ffd95a"), rgb("#ffb81f"), rgb("#e08a00"), (255, 232, 140, 255))
    star("star_empty", rgb("#e3e9ef"), rgb("#d2dae3"), rgb("#b4c0cc"), None)
    coin()
    crate(False)
    crate(True)
    icons()
    print("ui art written")
