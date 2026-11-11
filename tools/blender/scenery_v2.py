"""Background scenery, second generation (1.12): town houses, trees, palms
and warehouses. Same file names and footprints as before, so world.gd places
them exactly as it did.

blender -b --python tools/blender/scenery_v2.py

Art direction: a whitewashed Mediterranean hill town (think Tetouan / the
Moroccan north coast) -- white and pale walls, green and blue shutters, tiled
door bands, roof terraces with water tanks, stair huts, plants and laundry;
feathery palms, layered round trees and slim cypresses; warehouses with
corrugated metal roofs, roof units and loading docks.
"""
import math
import pathlib
import random
import sys

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import lib  # noqa: E402
import premium_models as P  # noqa: E402
import solstice_models as S  # noqa: E402

B, C, E = S.roundbox, P.C, P.E
P.PALETTE.update({
    'Wall': (250, 246, 238), 'WallWarm': (247, 236, 214), 'WallPink': (246, 222, 208), 'WallBlue': (214, 232, 244),
    'Roof': (236, 228, 212), 'Parapet': (244, 238, 226), 'Shadow': (64, 74, 82),
    'Green': (38, 132, 92), 'Blue': (46, 112, 176), 'Teal': (36, 130, 140), 'Terracotta': (204, 104, 72),
    'Tile': (40, 120, 150), 'TileLight': (232, 196, 96), 'Wood': (150, 98, 58), 'Iron': (48, 54, 60),
    'Pot': (196, 98, 64), 'Flower': (232, 70, 96), 'FlowerY': (250, 196, 70),
    'Leaf': (64, 150, 92), 'LeafLight': (116, 186, 102), 'LeafDark': (34, 112, 86), 'LeafDry': (170, 160, 92),
    'Bark': (128, 92, 62), 'BarkLight': (176, 136, 92), 'Olive': (128, 160, 112),
    'Metal': (196, 204, 210), 'MetalDark': (150, 160, 168), 'Cloth1': (238, 120, 96), 'Cloth2': (110, 170, 220),
    'Cloth3': (250, 226, 120),
})
rng = random.Random(7)


def arch(cx, y, w, h, z, mat, facing=-1):
    """Flat arched panel on a wall facing -z (facing=-1) or +z."""
    r = w / 2
    pts = [(cx - r, y, z), (cx + r, y, z), (cx + r, y + h - r, z)]
    for i in range(1, 13):
        a = math.pi * i / 12
        pts.append((cx + r * math.cos(a), y + h - r + r * math.sin(a), z))
    return lib.mesh_from(pts, [list(range(len(pts)))], mat, 'arch', outward=lambda c: (0, 0, facing))


def window(o, x, y, z, accent, shutters=True, grille=True, box=False):
    """A deep window on a -z wall: frame, glass, shutters, grille, sill, flower box."""
    o.append(B((x, y, z - 0.012), (0.42, 0.52, 0.03), 'Parapet', 0.012, 1))
    o.append(B((x, y, z - 0.02), (0.32, 0.42, 0.02), 'Shadow'))
    if grille:
        for k in (-1, 0, 1):
            o.append(B((x + k * 0.09, y, z - 0.04), (0.015, 0.42, 0.015), 'Iron'))
        o.append(B((x, y + 0.05, z - 0.04), (0.32, 0.015, 0.015), 'Iron'))
    if shutters:
        for s in (-1, 1):
            o.append(B((x + s * 0.27, y, z - 0.03), (0.13, 0.48, 0.03), accent, 0.01, 1))
            for k in range(4):
                o.append(B((x + s * 0.27, y - 0.17 + k * 0.11, z - 0.048), (0.11, 0.012, 0.008), 'Shadow'))
    o.append(B((x, y - 0.28, z - 0.06), (0.48, 0.04, 0.12), 'Parapet', 0.01, 1))
    if box:
        o.append(B((x, y - 0.33, z - 0.1), (0.4, 0.08, 0.1), accent, 0.01, 1))
        for k in range(4):
            o.append(P.blob((x - 0.15 + k * 0.1, y - 0.27, z - 0.1), (0.06, 0.055, 0.05),
                            'Flower' if k % 2 == 0 else 'LeafLight', 1))


def door(o, x, z, accent, w=0.56, h=1.0):
    o.append(arch(x, 0.0, w + 0.18, h + 0.12, z - 0.006, 'Tile'))          # zellige-tiled frame
    o.append(arch(x, 0.0, w + 0.08, h + 0.06, z - 0.012, 'TileLight'))
    o.append(arch(x, 0.03, w, h, z - 0.02, accent))
    for k in range(3):
        o.append(B((x, 0.2 + k * 0.28, z - 0.03), (w * 0.8, 0.02, 0.01), 'Shadow'))
    o.append(C((x + w * 0.3, 0.5, z - 0.04), 0.022, 0.02, 'TileLight', 8, 'z'))
    o.append(B((x, 0.03, z - 0.18), (w + 0.3, 0.06, 0.3), 'Parapet', 0.02, 1))


def parapet(o, cx, cz, w, d, y, crenel=False):
    for s in (-1, 1):
        o.append(B((cx + s * (w / 2 - 0.05), y + 0.12, cz), (0.1, 0.24, d), 'Parapet', 0.02, 1))
        o.append(B((cx, y + 0.12, cz + s * (d / 2 - 0.05)), (w, 0.24, 0.1), 'Parapet', 0.02, 1))
    if crenel:
        n = int(w / 0.3)
        for k in range(n):
            o.append(B((cx - w / 2 + 0.15 + k * (w - 0.3) / max(1, n - 1), y + 0.28, cz - d / 2 + 0.05),
                       (0.12, 0.09, 0.1), 'Parapet', 0.01, 1))


def roof_life(o, cx, cz, w, d, y, kind):
    """Things people keep on a roof terrace."""
    # water tank on a stand
    tx, tz = cx + w * 0.28, cz + d * 0.22
    o.append(B((tx, y + 0.08, tz), (0.42, 0.16, 0.42), 'MetalDark', 0.02, 1))
    o.append(C((tx, y + 0.34, tz), 0.19, 0.36, 'Wall', 14))
    o.append(C((tx, y + 0.54, tz), 0.2, 0.04, 'Blue' if kind % 2 else 'Green', 14))
    # potted plants along the front parapet
    for k in range(2 + kind % 2):
        px = cx - w * 0.32 + k * 0.32
        o.append(C((px, y + 0.1, cz - d * 0.33), 0.08, 0.2, 'Pot', 8, rt=0.1))
        o.append(P.blob((px, y + 0.3, cz - d * 0.33), (0.15, 0.16, 0.15), 'Leaf' if k % 2 else 'LeafLight', 1))
    if kind in (0, 2):
        # laundry line
        a, b = (cx - w * 0.35, y + 0.55, cz + d * 0.05), (cx + w * 0.05, y + 0.55, cz + d * 0.05)
        for p in (a, b):
            o.append(C((p[0], y + 0.28, p[2]), 0.015, 0.56, 'Iron', 5))
        o.append(E(a, b, 0.012, 'Iron'))
        for k, m in enumerate(('Cloth1', 'Cloth2', 'Cloth3')):
            t = 0.2 + k * 0.28
            o.append(B((a[0] + (b[0] - a[0]) * t, y + 0.43, a[2]), (0.16, 0.22, 0.01), m))
    if kind == 3:
        # satellite dish
        o.append(C((cx - w * 0.3, y + 0.2, cz + d * 0.3), 0.02, 0.4, 'Iron', 5))
        o.append(C((cx - w * 0.3, y + 0.42, cz + d * 0.27), 0.17, 0.03, 'Metal', 12, 'z'))


def house(kind):
    lib.reset()
    o = []
    # footprint (w, d), storeys, wall colour, accent, special
    w, d, h, wall, accent = [
        (2.2, 2.0, 1.7, 'Wall', 'Green'),
        (2.6, 2.2, 2.5, 'WallWarm', 'Blue'),
        (1.9, 1.9, 2.1, 'WallBlue', 'Teal'),
        (2.8, 2.4, 1.5, 'WallPink', 'Green'),
    ][kind]
    f = -d / 2
    o.append(B((0, h / 2, 0), (w, h, d), wall, 0.03, 2))
    # painted plinth band (Chefchaouen-style blue on some houses)
    o.append(B((0, 0.2, 0), (w + 0.02, 0.4, d + 0.02), 'WallBlue' if kind in (0, 3) else 'Roof', 0.015, 1))
    o.append(B((0, h + 0.02, 0), (w - 0.1, 0.04, d - 0.1), 'Roof'))
    parapet(o, 0, 0, w, d, h, crenel=kind in (1, 3))
    door(o, -w * 0.24, f, accent)
    if h > 2.2:
        window(o, w * 0.22, 0.8, f, accent, box=True)
        window(o, w * 0.22, 1.85, f, accent, grille=False, box=True)
        window(o, -w * 0.24, 1.85, f, accent)
        # little balcony
        o.append(B((-w * 0.24, 1.48, f - 0.2), (0.7, 0.05, 0.38), 'Parapet', 0.015, 1))
        for k in range(6):
            o.append(B((-w * 0.24 - 0.3 + k * 0.12, 1.62, f - 0.38), (0.015, 0.26, 0.015), 'Iron'))
        o.append(B((-w * 0.24, 1.75, f - 0.38), (0.72, 0.02, 0.02), 'Iron'))
    else:
        window(o, w * 0.22, h * 0.52, f, accent, box=kind != 2)
    # side windows (seen from the elevated camera)
    for s in (-1, 1):
        o.append(B((s * (w / 2 + 0.01), h * 0.6, -d * 0.12), (0.02, 0.38, 0.3), 'Shadow'))
        o.append(B((s * (w / 2 + 0.02), h * 0.6, -d * 0.12 - 0.22), (0.02, 0.4, 0.12), accent, 0.01, 1))
        o.append(B((s * (w / 2 + 0.02), h * 0.6, -d * 0.12 + 0.22), (0.02, 0.4, 0.12), accent, 0.01, 1))
    # roof additions
    if kind == 1:
        # whitewashed stair hut with a small arched door
        o.append(B((-w * 0.25, h + 0.38, d * 0.18), (0.8, 0.76, 0.8), wall, 0.03, 2))
        o.append(B((-w * 0.25, h + 0.78, d * 0.18), (0.88, 0.05, 0.88), 'Parapet', 0.01, 1))
        o.append(arch(-w * 0.25, h, 0.36, 0.6, d * 0.18 - 0.41, accent))
    if kind == 3:
        o.append(C((w * 0.22, h + 0.12, d * 0.2), 0.42, 0.24, wall, 20))
        o.append(P.blob((w * 0.22, h + 0.3, d * 0.2), (0.42, 0.36, 0.42), 'Green', 3))
        o.append(C((w * 0.22, h + 0.72, d * 0.2), 0.022, 0.16, 'TileLight', 8))
    roof_life(o, 0, 0, w, d, h + 0.04, kind)
    # a climbing bougainvillea on one corner
    if kind in (0, 2):
        for k in range(5):
            o.append(P.blob((w / 2 - 0.05, 0.3 + k * h * 0.17, f - 0.05 + 0.03 * (k % 2)),
                            (0.14, 0.13, 0.1), 'Flower' if k % 2 else 'Leaf', 1))
    S.finish(o, 'house_' + chr(97 + kind), ao=0.38)


# ------------------------------------------------------------------ trees

def frond(base, yaw, length, droop, mat, leaflets=11, width=0.36):
    """Pinnate palm frond: a curving rachis with V-angled leaflets."""
    dx, dz = math.cos(yaw), math.sin(yaw)
    px, pz = -dz, dx
    vs, fs = [], []
    pts = []
    for k in range(leaflets + 1):
        t = k / leaflets
        reach = length * t
        y = base[1] + 0.32 * math.sin(t * math.pi * 0.8) - droop * t * t
        pts.append((base[0] + dx * reach, y, base[2] + dz * reach))
    for k in range(leaflets):
        a, b = pts[k], pts[k + 1]
        t = (k + 0.5) / leaflets
        lw = width * math.sin(math.pi * min(1.0, t * 1.15)) ** 0.6 + 0.04
        for s in (-1, 1):
            tip = (a[0] + (b[0] - a[0]) * 1.9 + s * px * lw, a[1] - 0.12 - 0.08 * t, a[2] + (b[2] - a[2]) * 1.9 + s * pz * lw)
            i = len(vs)
            vs += [a, b, tip]
            fs += [[i, i + 1, i + 2], [i + 2, i + 1, i]]
        # rachis
        i = len(vs)
        vs += [(a[0], a[1] + 0.02, a[2]), (b[0], b[1] + 0.02, b[2]), (b[0], b[1] - 0.02, b[2]), (a[0], a[1] - 0.02, a[2])]
        fs += [[i, i + 1, i + 2, i + 3], [i + 3, i + 2, i + 1, i]]
    return lib.mesh_from(vs, fs, mat, 'frond')


def palm():
    lib.reset()
    o = []
    n = 12
    pts = [(0.5 * (k / n) ** 2, 3.0 * k / n, 0.05 * math.sin(k * 0.6)) for k in range(n + 1)]
    for k in range(n):
        a, b = pts[k], pts[k + 1]
        r0 = 0.13 - 0.04 * k / n
        mid = tuple((a[i] + b[i]) / 2 for i in range(3))
        o.append(C(mid, r0, 3.0 / n * 1.02, 'Bark' if k % 2 else 'BarkLight', 9, 'y', r0 * 0.86))
        o.append(C((a[0], a[1] + 0.01, a[2]), r0 * 1.12, 0.05, 'BarkLight', 9))
    top = pts[-1]
    o.append(P.blob((top[0], top[1] + 0.05, top[2]), (0.17, 0.2, 0.17), 'LeafDark', 1))
    for j in range(12):
        yaw = j * math.tau / 12 + (0.15 if j % 2 else 0)
        dry = j in (3, 8)
        o.append(frond((top[0], top[1] + 0.04, top[2]), yaw, 1.35 + 0.35 * ((j * 7) % 3) / 2, 0.9 if not dry else 1.6,
                       'LeafDry' if dry else ('LeafLight' if j % 3 == 0 else ('Leaf' if j % 3 == 1 else 'LeafDark'))))
    for x, z in ((0.1, 0.12), (0.06, -0.1), (-0.09, 0.03)):
        o.append(P.blob((top[0] + x, top[1] - 0.12, top[2] + z), (0.09, 0.1, 0.09), 'Wood', 1))
    S.finish(o, 'palm', ao=0.35)


def tree_round():
    lib.reset()
    o = []
    o.append(C((0, 0.42, 0), 0.08, 0.84, 'Bark', 8, rt=0.055))
    for a, b in (((0, 0.7, 0), (0.28, 1.05, 0.08)), ((0, 0.75, 0), (-0.25, 1.1, -0.06)), ((0, 0.8, 0), (0.02, 1.2, -0.24))):
        o.append(E(a, b, 0.05, 'Bark'))
    # layered canopy: darker underside, lighter sunlit top
    clumps = [((0, 1.28, 0), (0.62, 0.48, 0.58), 'LeafDark'),
              ((0.34, 1.32, 0.12), (0.4, 0.36, 0.38), 'Leaf'), ((-0.34, 1.34, -0.1), (0.42, 0.37, 0.4), 'Leaf'),
              ((0.05, 1.36, -0.34), (0.4, 0.34, 0.36), 'Leaf'), ((-0.05, 1.33, 0.34), (0.38, 0.33, 0.36), 'Leaf'),
              ((0.12, 1.62, 0.05), (0.42, 0.34, 0.4), 'LeafLight'), ((-0.18, 1.6, -0.08), (0.34, 0.3, 0.32), 'LeafLight'),
              ((0.02, 1.84, 0.0), (0.26, 0.22, 0.25), 'LeafLight')]
    for c, s, m in clumps:
        o.append(P.blob(c, s, m, 2))
    S.finish(o, 'tree_round', ao=0.32)


def cypress():
    lib.reset()
    o = [C((0, 0.2, 0), 0.06, 0.4, 'Bark', 7)]
    layers = [((0, 0.75, 0), (0.33, 0.55, 0.32), 'LeafDark'), ((0.02, 1.22, 0.01), (0.29, 0.5, 0.28), 'Leaf'),
              ((0.03, 1.66, 0.0), (0.23, 0.45, 0.22), 'Leaf'), ((0.05, 2.04, 0.0), (0.15, 0.35, 0.15), 'LeafLight'),
              ((0.06, 2.3, 0.0), (0.07, 0.16, 0.07), 'LeafLight')]
    for c, s, m in layers:
        o.append(P.blob(c, s, m, 2))
    S.finish(o, 'cypress', ao=0.3)


# ------------------------------------------------------------------ warehouses

def warehouse(name, accent):
    lib.reset()
    o = []
    w, d, h = 7.2, 5.0, 3.2
    f = -2.5
    o.append(B((0, h / 2, 0), (w, h, d), 'WallWarm', 0.05, 2))
    o.append(B((0, 0.2, 0), (w + 0.1, 0.4, d + 0.1), 'Roof', 0.03, 1))
    # pilasters and a coloured fascia band
    for x in (-3.5, -1.1, 1.1, 3.5):
        o.append(B((x, h / 2 + 0.05, f - 0.03), (0.18, h - 0.1, 0.16), accent, 0.02, 1))
    o.append(B((0, h - 0.18, f - 0.05), (w + 0.04, 0.32, 0.1), accent, 0.03, 2))
    # Flat roof terrace: the harbour projects (cafe, pool, fountain, solar,
    # flags) stand on it at y=3.43, so it must stay flat and clear in the middle.
    o.append(B((0, h + 0.1, 0), (w + 0.2, 0.2, d + 0.2), accent, 0.04, 2))          # roof slab edge
    o.append(B((0, h + 0.215, 0), (w - 0.04, 0.03, d - 0.04), 'Roof'))               # membrane, top = 3.43
    for x in (-2.4, -1.2, 0.0, 1.2, 2.4):
        o.append(B((x, h + 0.232, 0), (0.02, 0.006, d - 0.1), 'MetalDark'))           # seams
    for s in (-1, 1):
        o.append(B((s * (w / 2 + 0.02), h + 0.32, 0), (0.12, 0.22, d + 0.24), 'Parapet', 0.03, 2))
        o.append(B((0, h + 0.32, s * (d / 2 + 0.02)), (w + 0.24, 0.22, 0.12), 'Parapet', 0.03, 2))
    # low skylights where the old ones were (projects were placed around them)
    for x in (-2.35, 0.0, 2.35):
        o.append(B((x, h + 0.29, 0.4), (1.48, 0.12, 2.6), 'Parapet', 0.04, 2))
        o.append(B((x, h + 0.36, 0.4), (1.32, 0.04, 2.42), 'Glass', 0.02, 1))
        for z in (-0.4, 0.4, 1.2):
            o.append(B((x, h + 0.385, z), (1.3, 0.012, 0.04), 'Parapet'))
    # roof units tucked into the back corners
    for x in (-3.15, 3.15):
        o.append(B((x, h + 0.42, 2.05), (0.6, 0.4, 0.5), 'MetalDark', 0.03, 1))
        o.append(C((x, h + 0.64, 2.05), 0.16, 0.05, 'Iron', 10))
    # downpipes on the front corners
    for x in (-3.55, 3.55):
        o.append(C((x, h / 2, f - 0.1), 0.05, h, accent, 8))
    # roller doors with a loading dock
    for x in (-2.18, 0.3):
        o.append(B((x, 1.2, f - 0.04), (2.0, 2.4, 0.08), 'Iron', 0.04, 1))
        o.append(B((x, 1.18, f - 0.08), (1.8, 2.3, 0.04), 'Metal', 0.02, 1))
        for k in range(10):
            o.append(B((x, 0.2 + k * 0.22, f - 0.11), (1.78, 0.03, 0.015), 'MetalDark'))
        o.append(B((x, 2.48, f - 0.2), (2.2, 0.12, 0.38), accent, 0.03, 1))
        for s in (-1, 1):
            o.append(B((x + s * 0.9, 0.32, f - 0.16), (0.14, 0.5, 0.14), 'Iron', 0.03, 1))
            o.append(C((x + s * 1.08, 0.36, f - 0.34), 0.05, 0.72, 'TileLight', 8))
    # office door, windows and a port emblem
    o.append(B((2.62, 1.0, f - 0.06), (0.8, 2.0, 0.07), 'Iron', 0.02, 1))
    o.append(B((2.62, 1.05, f - 0.1), (0.64, 1.8, 0.03), accent, 0.015, 1))
    o.append(B((2.62, 1.55, f - 0.12), (0.46, 0.42, 0.02), 'Glass', 0.01, 1))
    o.append(B((2.62, 2.15, f - 0.3), (1.15, 0.08, 0.6), accent, 0.02, 1))
    for x in (-2.75, -1.85, -0.95, -0.05, 0.85, 1.75):
        o.append(B((x, 2.68, f - 0.07), (0.62, 0.22, 0.03), 'Glass', 0.01, 1))
    o.append(C((2.62, 2.66, f - 0.1), 0.2, 0.04, 'Wall', 16, 'z'))
    o.append(C((2.62, 2.66, f - 0.13), 0.13, 0.02, accent, 16, 'z'))
    S.finish(o, name, ao=0.55)


if __name__ == '__main__':
    P.finish = S.finish
    P.B = S.roundbox
    for k in range(4):
        house(k)
    palm()
    tree_round()
    cypress()
    warehouse('warehouse_a', 'Terracotta')
    warehouse('warehouse_b', 'Teal')
    print('SCENERY_V2', [(r['name'], r['triangles']) for r in S.REPORT], flush=True)
