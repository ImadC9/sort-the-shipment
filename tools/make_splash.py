"""Builds the start-up splash (assets/ui/splash.png).

The same picture is used twice so the start feels like one screen:
  1. Godot's boot splash, shown by the engine while it starts;
  2. the in-game loading cover (scripts/loading_cover.gd), which adds a
     progress bar under the title while the harbour is built.
The edges are the flat boot-splash colour, so taller or wider phones simply
get more of the same colour around it.

Usage: python3 tools/make_splash.py   (needs Pillow; reads store/store_icon_512.png)
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
W, H = 1080, 1920
BG = (219, 240, 250)          # = application/boot_splash/bg_color
INK = (31, 51, 80)
INK_SOFT = (98, 120, 143)
ACCENT = (255, 138, 61)

# layout shared with scripts/loading_cover.gd (as fractions of the image)
BADGE = 460
BADGE_Y = 520                 # top of the icon badge
TITLE_Y = 1140                # baseline of "SORT THE"


def rounded_mask(size: int, radius: int) -> Image.Image:
    m = Image.new("L", (size, size), 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, size - 1, size - 1), radius, fill=255)
    return m


def main() -> None:
    img = Image.new("RGB", (W, H), BG)

    # soft light pool behind the badge
    glow = Image.new("L", (W, H), 0)
    ImageDraw.Draw(glow).ellipse((W / 2 - 430, BADGE_Y - 230, W / 2 + 430, BADGE_Y + BADGE + 330), fill=255)
    glow = glow.filter(ImageFilter.GaussianBlur(120))
    img = Image.composite(Image.new("RGB", (W, H), (246, 251, 254)), img, glow.point(lambda v: int(v * 0.85)))

    # drop shadow
    x0 = (W - BADGE) // 2
    sh = Image.new("L", (W, H), 0)
    ImageDraw.Draw(sh).rounded_rectangle((x0 + 6, BADGE_Y + 26, x0 + BADGE + 6, BADGE_Y + BADGE + 26), 110, fill=120)
    sh = sh.filter(ImageFilter.GaussianBlur(28))
    img = Image.composite(Image.new("RGB", (W, H), (120, 160, 190)), img, sh)

    # icon badge with a white rim
    rim = 14
    ImageDraw.Draw(img).rounded_rectangle((x0 - rim, BADGE_Y - rim, x0 + BADGE + rim, BADGE_Y + BADGE + rim), 110 + rim, fill=(255, 255, 255))
    icon = Image.open(ROOT / "store" / "store_icon_512.png").convert("RGB").resize((BADGE, BADGE), Image.LANCZOS)
    img.paste(icon, (x0, BADGE_Y), rounded_mask(BADGE, 110))

    # title
    d = ImageDraw.Draw(img)
    small = ImageFont.truetype(str(ROOT / "assets/fonts/Fredoka-Bold.ttf"), 92)
    big = ImageFont.truetype(str(ROOT / "assets/fonts/Fredoka-Bold.ttf"), 168)
    d.text((W / 2, TITLE_Y), "SORT THE", font=small, fill=INK_SOFT, anchor="ms")
    d.text((W / 2, TITLE_Y + 168), "SHIPMENT", font=big, fill=INK, anchor="ms",
           stroke_width=0)
    # a small orange underline, like the menu ribbons
    d.rounded_rectangle((W / 2 - 70, TITLE_Y + 226, W / 2 + 70, TITLE_Y + 240), 7, fill=ACCENT)

    out = ROOT / "assets" / "ui" / "splash.png"
    out.parent.mkdir(parents=True, exist_ok=True)
    img.save(out, optimize=True)
    print("wrote", out, img.size)


if __name__ == "__main__":
    main()
