"""Bakes the container texture atlas (assets/textures/container_*.png).

The container mesh itself is a light chamfered box (scripts/meshes.gd,
about 60 triangles). All the detail -- corrugated walls, corner castings,
door locking bars, hinges, roof, stencilled codes -- lives in two textures
made here from a height field:

  container_normal.png  tangent-space normal map (OpenGL convention, +Y up)
  container_mask.png    R = ambient occlusion and grime
                        G = surface class: 1.0 panel paint, 0.5 frame paint, 0.0 bare steel
                        B = edge wear (raised edges catch light)
                        A = white stencil markings

The shader (shaders/cargo.gdshader) colours the panels with the cargo colour,
so one atlas serves every container.

Layout, 390 px per metre (container is 1.0 wide, 0.8 high, 1.9 long):
  side (1.9 x 0.8)   x 0..741    y 0..312     both long sides share it
  roof (1.9 x 1.0)   x 0..741    y 312..702
  door (1.0 x 0.8)   x 0..390    y 702..1014  the end facing the camera
  back (1.0 x 0.8)   x 390..780  y 702..1014
  frame swatch       x 800..1024 (plain frame paint, used by the chamfers)

Usage: python3 tools/make_container_tex.py
"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy import ndimage

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "textures"
D = 390                      # pixels per metre
N = 1024

H = np.zeros((N, N))         # height in metres (outward)
CLS = np.zeros((N, N))       # surface class
STEN = np.zeros((N, N))      # stencil
GRIME = np.ones((N, N))      # extra darkening multiplier


def px(m):
    return int(round(m * D))


def rect(arr, x0, y0, x1, y1, v, mode="set"):
    sl = (slice(max(0, y0), min(N, y1)), slice(max(0, x0), min(N, x1)))
    if mode == "set":
        arr[sl] = v
    elif mode == "max":
        arr[sl] = np.maximum(arr[sl], v)
    elif mode == "add":
        arr[sl] += v


def trapezoid_wave(t, pitch, depth, flat_out=0.42, slope=0.08):
    """Corrugation profile: flat outer, slope, flat inner, slope. t in metres."""
    u = (t / pitch) % 1.0
    out = np.zeros_like(u)
    a, b, c = flat_out, flat_out + slope, 1.0 - slope
    out = np.where(u < a, 0.0, out)
    out = np.where((u >= a) & (u < b), -(u - a) / slope, out)
    out = np.where((u >= b) & (u < c), -1.0, out)
    out = np.where(u >= c, -1.0 + (u - c) / slope, out)
    return out * depth


def casting(x0, y0, w, h):
    """Corner casting: raised block with an oval aperture."""
    rect(H, x0, y0, x0 + w, y0 + h, 0.012, "max")
    rect(CLS, x0, y0, x0 + w, y0 + h, 0.0)
    cy, cx = y0 + h / 2, x0 + w / 2
    yy, xx = np.ogrid[:N, :N]
    hole = ((xx - cx) / (w * 0.3)) ** 2 + ((yy - cy) / (h * 0.22)) ** 2 < 1
    H[hole & (H > 0.011)] = -0.006


def panel_region(x0, y0, w_m, h_m, pitch, depth, vertical_ribs=True, frame_tb=(0.07, 0.06), frame_lr=(0.055, 0.055)):
    """A corrugated wall inside a painted frame."""
    x1, y1 = x0 + px(w_m), y0 + px(h_m)
    # frame (flush) everywhere first
    rect(H, x0, y0, x1, y1, 0.0)
    rect(CLS, x0, y0, x1, y1, 0.5)
    ix0, ix1 = x0 + px(frame_lr[0]), x1 - px(frame_lr[1])
    iy0, iy1 = y0 + px(frame_tb[1]), y1 - px(frame_tb[0])
    ys, xs = np.mgrid[iy0:iy1, ix0:ix1]
    t = (xs - ix0) / D if vertical_ribs else (ys - iy0) / D
    H[iy0:iy1, ix0:ix1] = -0.004 + trapezoid_wave(t, pitch, depth)
    CLS[iy0:iy1, ix0:ix1] = 1.0
    # grime: the bottom of a wall gets dusty
    gy = np.linspace(0, 1, y1 - y0)[:, None]
    GRIME[y0:y1, x0:x1] *= 1.0 - 0.10 * np.clip((gy - 0.72) / 0.28, 0, 1) ** 1.5
    return (ix0, iy0, ix1, iy1)


def stencil(text, x, y, size, anchor="la", font="DejaVuSans-Bold.ttf", rotate=False):
    img = Image.new("L", (N, N), 0)
    d = ImageDraw.Draw(img)
    f = ImageFont.truetype(str(ROOT / "assets" / "fonts" / font), size)
    d.text((x, y), text, font=f, fill=255, anchor=anchor)
    a = np.asarray(img, dtype=float) / 255
    np.maximum(STEN, a, out=STEN)


# ------------------------------------------------------------------ side
SIDE = (0, 0, px(1.9), px(0.8))
panel_region(0, 0, 1.9, 0.8, pitch=0.085, depth=0.014)
for (cx, cy) in [(0, 0), (px(1.9) - px(0.07), 0), (0, px(0.8) - px(0.055)), (px(1.9) - px(0.07), px(0.8) - px(0.055))]:
    casting(cx, cy, px(0.07), px(0.055))
# forklift-free bottom rail detail: small cross-member bolts
for i in range(1, 12):
    x = int(i * px(1.9) / 12)
    rect(H, x - 2, px(0.8) - px(0.05), x + 2, px(0.8) - px(0.02), 0.004, "max")
stencil("STSU 402118 2", px(1.9) - px(0.12), px(0.12), 17, anchor="ra")
stencil("22G1", px(1.9) - px(0.12), px(0.12) + 22, 14, anchor="ra")
stencil("MAX GROSS 30,480 KG", px(0.12), px(0.8) - px(0.13), 9, anchor="la")

# ------------------------------------------------------------------ roof
ROOF_Y = px(0.8)
x0, y0, x1, y1 = 0, ROOF_Y, px(1.9), ROOF_Y + px(1.0)
rect(H, x0, y0, x1, y1, 0.0)
rect(CLS, x0, y0, x1, y1, 0.5)
ix0, ix1, iy0, iy1 = x0 + px(0.05), x1 - px(0.05), y0 + px(0.05), y1 - px(0.05)
ys, xs = np.mgrid[iy0:iy1, ix0:ix1]
# shallow transverse roof bows with a gentle dome
t = (xs - ix0) / D
H[iy0:iy1, ix0:ix1] = -0.003 + 0.45 * trapezoid_wave(t, 0.19, 0.012, 0.5, 0.18)
CLS[iy0:iy1, ix0:ix1] = 1.0
for (cx, cy) in [(x0, y0), (x1 - px(0.07), y0), (x0, y1 - px(0.06)), (x1 - px(0.07), y1 - px(0.06))]:
    casting(cx, cy, px(0.07), px(0.06))

# ------------------------------------------------------------------ door end
DY = ROOF_Y + px(1.0)
dx0, dy0 = 0, DY
dw, dh = px(1.0), px(0.8)
rect(H, dx0, dy0, dx0 + dw, dy0 + dh, 0.0)
rect(CLS, dx0, dy0, dx0 + dw, dy0 + dh, 0.5)
# two door leaves with fine vertical ribs, a seam between them
for leaf in range(2):
    lx0 = dx0 + px(0.06) + leaf * (dw // 2 - px(0.03))
    lx1 = lx0 + dw // 2 - px(0.09)
    ly0, ly1 = dy0 + px(0.07), dy0 + dh - px(0.08)
    ys, xs = np.mgrid[ly0:ly1, lx0:lx1]
    H[ly0:ly1, lx0:lx1] = -0.003 + 0.5 * trapezoid_wave((xs - lx0) / D, 0.06, 0.01, 0.5, 0.12)
    CLS[ly0:ly1, lx0:lx1] = 1.0
rect(H, dx0 + dw // 2 - 2, dy0 + px(0.06), dx0 + dw // 2 + 2, dy0 + dh - px(0.07), -0.008)
# four locking bars (round), with keepers and handles
yy = np.arange(N)[:, None]
for bx_m in (0.17, 0.36, 0.64, 0.83):
    cx = dx0 + px(bx_m)
    r = 4.5
    xs = np.arange(N)[None, :]
    prof = np.sqrt(np.clip(1 - ((xs - cx) / r) ** 2, 0, 1)) * 0.016
    band = (yy >= dy0 + px(0.03)) & (yy < dy0 + dh - px(0.03))
    mask = band & (np.abs(xs - cx) < r)
    H[mask] = np.maximum(H, prof)[mask]
    CLS[mask] = 0.0
    for ky in (dy0 + px(0.05), dy0 + dh - px(0.06)):
        rect(H, int(cx - 7), int(ky - 5), int(cx + 7), int(ky + 5), 0.018, "max")
        rect(CLS, int(cx - 7), int(ky - 5), int(cx + 7), int(ky + 5), 0.0)
    hy = dy0 + int(dh * 0.55)
    side = -1 if bx_m < 0.5 else 1
    rect(H, int(cx), hy - 3, int(cx + side * 22) if side > 0 else int(cx), hy + 3, 0.02, "max")
    if side < 0:
        rect(H, int(cx - 22), hy - 3, int(cx), hy + 3, 0.02, "max")
# hinges on the outer edges
for hy_m in (0.12, 0.31, 0.5, 0.68):
    for hx in (dx0 + px(0.035), dx0 + dw - px(0.035)):
        rect(H, hx - 6, dy0 + px(hy_m) - 4, hx + 6, dy0 + px(hy_m) + 4, 0.014, "max")
        rect(CLS, hx - 6, dy0 + px(hy_m) - 4, hx + 6, dy0 + px(hy_m) + 4, 0.0)
for (cx, cy) in [(dx0, dy0), (dx0 + dw - px(0.07), dy0), (dx0, dy0 + dh - px(0.055)), (dx0 + dw - px(0.07), dy0 + dh - px(0.055))]:
    casting(cx, cy, px(0.07), px(0.055))
stencil("STSU", dx0 + px(0.56), dy0 + px(0.13), 16, anchor="la")
stencil("402118 2", dx0 + px(0.56), dy0 + px(0.13) + 18, 13, anchor="la")
# CSC plate
rect(H, dx0 + px(0.06) + 10, dy0 + px(0.5), dx0 + px(0.06) + 34, dy0 + px(0.5) + 16, 0.003, "max")
rect(CLS, dx0 + px(0.06) + 10, dy0 + px(0.5), dx0 + px(0.06) + 34, dy0 + px(0.5) + 16, 0.0)
GRIME[dy0:dy0 + dh, dx0:dx0 + dw] *= 1.0 - 0.1 * np.clip((np.linspace(0, 1, dh)[:, None] - 0.75) / 0.25, 0, 1)

# ------------------------------------------------------------------ back end
bx0 = px(1.0)
ix0, iy0, ix1, iy1 = panel_region(bx0, DY, 1.0, 0.8, pitch=0.085, depth=0.014)
for (cx, cy) in [(bx0, DY), (bx0 + px(1.0) - px(0.07), DY), (bx0, DY + px(0.8) - px(0.055)), (bx0 + px(1.0) - px(0.07), DY + px(0.8) - px(0.055))]:
    casting(cx, cy, px(0.07), px(0.055))

# ------------------------------------------------------------------ frame swatch
rect(H, 800, 0, N, N, 0.0)
rect(CLS, 800, 0, N, N, 0.5)

# ------------------------------------------------------------------ bake
def bake():
    OUT.mkdir(parents=True, exist_ok=True)
    h = ndimage.gaussian_filter(H, 0.6)
    # normals: metres per pixel = 1/D
    gy, gx = np.gradient(h * D)
    strength = 1.0
    nx, ny, nz = -gx * strength, gy * strength, np.ones_like(h)
    ln = np.sqrt(nx * nx + ny * ny + nz * nz)
    nrm = np.stack([nx / ln, ny / ln, nz / ln], -1)
    Image.fromarray(((nrm * 0.5 + 0.5) * 255).astype(np.uint8)).save(OUT / "container_normal.png", optimize=True)

    # occlusion: how far below its surroundings a point sits, at two scales
    cav = 0.0
    for r, w in ((3, 0.6), (9, 0.4)):
        cav = cav + w * np.clip((ndimage.maximum_filter(h, size=r * 2 + 1) - h) / 0.016, 0, 1)
    ao = 1.0 - 0.42 * ndimage.gaussian_filter(cav, 1.2)
    ao *= GRIME
    # edge wear: crests of ridges and hardware
    crest = np.clip((h - ndimage.gaussian_filter(h, 2.5)) / 0.004, 0, 1)
    wear = ndimage.gaussian_filter(crest, 0.7)
    sten = ndimage.gaussian_filter(STEN, 0.4)
    # chunky stencil look: break the letters with a few gaps
    mask = np.stack([ao, CLS, wear, sten], -1)
    Image.fromarray((np.clip(mask, 0, 1) * 255).astype(np.uint8), "RGBA").save(OUT / "container_mask.png", optimize=True)
    print("wrote", OUT / "container_normal.png", OUT / "container_mask.png")


if __name__ == "__main__":
    bake()
