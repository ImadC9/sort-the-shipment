"""Builds the app/store icons and the Play feature graphic from rendered art.

python3 tools/make_icons.py icon_art.png out_dir
- icon.png (512, the in-engine/project icon), store_icon_512.png (full square, Play masks it)
- adaptive_fg_432.png / adaptive_bg_432.png (Android adaptive launcher icon)
- feature_graphic_1024x500.png
"""
import math
import sys
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ART, OUT = sys.argv[1], sys.argv[2].rstrip("/")
ROOT = __file__.rsplit("/tools/", 1)[0]
FONT = ROOT + "/assets/fonts/Fredoka-Bold.ttf"
TOP, BOT = (112, 216, 246), (32, 128, 222)


def gradient(w, h, top=TOP, bot=BOT):
    im = Image.new("RGB", (w, h))
    d = ImageDraw.Draw(im)
    for y in range(h):
        t = y / max(1, h - 1)
        d.line([(0, y), (w, y)], fill=tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3)))
    return im


def rays(im, centre, n=16, alpha=34):
    w, h = im.size
    over = Image.new("RGBA", im.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(over)
    r = max(w, h) * 1.2
    for i in range(n):
        a0 = i * 2 * math.pi / n
        a1 = a0 + math.pi / n
        d.polygon([centre, (centre[0] + r * math.cos(a0), centre[1] + r * math.sin(a0)),
                   (centre[0] + r * math.cos(a1), centre[1] + r * math.sin(a1))], fill=(255, 255, 255, alpha))
    glow = Image.new("RGBA", im.size, (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse([centre[0] - w * 0.36, centre[1] - h * 0.36, centre[0] + w * 0.36, centre[1] + h * 0.36], fill=(255, 255, 255, 70))
    glow = glow.filter(ImageFilter.GaussianBlur(w * 0.08))
    base = im.convert("RGBA")
    base.alpha_composite(over)
    base.alpha_composite(glow)
    return base


def place_art(canvas, art, box_frac, centre_frac=(0.5, 0.54), shadow=True):
    w, h = canvas.size
    bb = art.getbbox()
    a = art.crop(bb)
    scale = min(w * box_frac / a.width, h * box_frac / a.height)
    a = a.resize((int(a.width * scale), int(a.height * scale)), Image.LANCZOS)
    x = int(w * centre_frac[0] - a.width / 2)
    y = int(h * centre_frac[1] - a.height / 2)
    if shadow:
        sh = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
        mask = a.split()[-1].point(lambda v: int(v * 0.35))
        sh.paste((10, 40, 90, 255), (x, y + int(h * 0.03)), mask)
        canvas.alpha_composite(sh.filter(ImageFilter.GaussianBlur(w * 0.02)))
    canvas.alpha_composite(a, (x, y))
    return canvas


art = Image.open(ART).convert("RGBA")
# full-square icon (Play applies its own rounded mask)
ic = rays(gradient(1024, 1024), (512, 540))
ic = place_art(ic, art, 0.78, (0.5, 0.52))
ic.convert("RGB").resize((512, 512), Image.LANCZOS).save(OUT + "/store_icon_512.png")
ic.convert("RGB").resize((512, 512), Image.LANCZOS).save(OUT + "/icon.png")
# adaptive launcher icon: art inside the 66% safe zone, separate background
fg = Image.new("RGBA", (1296, 1296), (0, 0, 0, 0))
fg = place_art(fg, art, 0.52, (0.5, 0.52))
fg.resize((432, 432), Image.LANCZOS).save(OUT + "/adaptive_fg_432.png")
bg = rays(gradient(1296, 1296), (648, 680))
bg.convert("RGB").resize((432, 432), Image.LANCZOS).save(OUT + "/adaptive_bg_432.png")
# feature graphic 1024x500
fgph = rays(gradient(2048, 1000), (1560, 520), n=20)
fgph = place_art(fgph, art, 0.86, (0.76, 0.53))
d = ImageDraw.Draw(fgph)
cols = [(242, 85, 101), (61, 142, 245), (255, 197, 51), (54, 193, 118)]
f1 = ImageFont.truetype(FONT, 170)
x = 110
for i, ch in enumerate("SORT"):
    box = [x, 170, x + 196, 400]
    d.rounded_rectangle([box[0], box[1] + 18, box[2], box[3] + 18], 40, fill=tuple(int(c * 0.72) for c in cols[i]))
    d.rounded_rectangle(box, 40, fill=cols[i])
    d.text((x + 98, 290), ch, font=f1, fill="white", anchor="mm")
    x += 214
f2 = ImageFont.truetype(FONT, 76)
d.text((130, 450), "THE", font=f2, fill=(255, 197, 61), stroke_width=10, stroke_fill=(31, 51, 80))
f3 = ImageFont.truetype(FONT, 176)
d.text((110, 520), "SHIPMENT", font=f3, fill="white", stroke_width=16, stroke_fill=(31, 51, 80))
f4 = ImageFont.truetype(FONT, 56)
d.text((126, 760), "Load the ships. Clear the yard.", font=f4, fill="white", stroke_width=7, stroke_fill=(31, 51, 80))
fgph.convert("RGB").resize((1024, 500), Image.LANCZOS).save(OUT + "/feature_graphic_1024x500.png")
print("icons written to", OUT)
