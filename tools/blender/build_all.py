"""Builds every 3D model of the Toy Harbour kit into assets/models.

    python3 tools/blender/build_all.py            # everything
    python3 tools/blender/build_all.py ship crane # only names containing these words
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit  # noqa: E402
from kit import Model  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "models")

# ------------------------------------------------------------------ palette
# One shared world palette, so every model belongs to the same toy set.
P = {
    "White": "#fbf7ee", "Cream": "#f3e7d0", "Sand": "#e6d6b8", "Stone": "#d9cdb8",
    "Navy": "#2c4763", "NavyDark": "#22364d", "Glass": "#3f7896", "GlassLight": "#8fd3e8",
    "Steel": "#c5d0d8", "SteelDark": "#8d9aa6", "Rubber": "#39424e",
    "Yellow": "#ffc533", "YellowDark": "#f0a81c", "Coral": "#f2685c", "CoralDark": "#d9544b",
    "Mint": "#9fdcc8", "Sky": "#a9d8ee", "Orange": "#ff8a3c", "Red": "#ef5361",
    "Leaf": "#52c27c", "LeafDark": "#35a566", "LeafLight": "#84d98f", "Trunk": "#c08d5e", "TrunkDark": "#a67447",
    "Wood": "#cf9a62", "Lamp": "#fff0b8", "Gold": "#ffcc3d", "GoldDark": "#eaa81e",
    "Bottom": "#c9574f", "Boot": "#fbf7ee",
    # tinted by the game
    "Hull": ("Hull", 1.0), "HullDark": ("Hull", 0.78), "Deck": ("Deck", 1.0), "Hatch": ("Hatch", 1.0),
    "Funnel": ("Funnel", 1.0), "Trim": ("Funnel", 0.9),
}


def save(ob, name):
    kit.export(ob, os.path.join(OUT, name + ".glb"))


# ---------------------------------------------------------------- container
CW, CH, CL = 1.0, 0.8, 1.9


def _container_mask(pname):
    # G = frame mask (frame can turn gold in the shader), B = bare metal mask
    return (1.0 if pname == "Frame" else 0.0, 1.0 if pname == "Metal" else 0.0)


def container(detail=True):
    m = Model("container" if detail else "container_lod")
    p = 0.095                      # frame member size
    m.box((0, CH / 2, 0), (CW - 0.10, CH - 0.08, CL - 0.10), "Body", bevel=0.012, seg=1)
    for sx in (-1, 1):
        for sz in (-1, 1):
            m.box((sx * (CW - p) / 2, CH / 2, sz * (CL - p) / 2), (p, CH, p), "Frame", bevel=0.024, seg=2 if detail else 1)
        for y in (0.04, CH - 0.04):
            m.box((sx * (CW - p) / 2, y, 0), (p, 0.08, CL - p), "Frame", bevel=0.024, seg=2 if detail else 1)
    for sz in (-1, 1):
        for y in (0.04, CH - 0.04):
            m.box((0, y, sz * (CL - p) / 2), (CW - p, 0.08, p), "Frame", bevel=0.024, seg=2 if detail else 1)
    if detail:
        # chunky corrugation on the long sides and the back end
        n = 6
        for sx in (-1, 1):
            for i in range(n):
                z = (i - (n - 1) / 2) * 0.262
                m.box((sx * 0.462, CH / 2, z), (0.045, CH - 0.2, 0.15), "Body", bevel=0.02, seg=1)
        for i in range(3):
            x = (i - 1) * 0.25
            m.box((x, CH / 2, 0.912), (0.14, CH - 0.2, 0.045), "Body", bevel=0.02, seg=1)
        # door hardware: two small latches under the symbol
        for sx in (-1, 1):
            m.box((sx * 0.3, 0.105, -0.905), (0.11, 0.045, 0.03), "Metal", bevel=0.012, seg=1)
    ob = m.finish({"Body": ("Body", 1.0), "Frame": ("Body", 0.80), "Metal": ("Body", 0.62)},
                  ao_distance=0.5, ao_strength=0.85, mask=_container_mask, sharp_deg=50)
    save(ob, m.name)


def container_tarp():
    """Covered cargo: a canvas sheet strapped over the box."""
    m = Model("container_tarp")
    # the sheet: a soft, slightly flared box
    import bmesh
    from mathutils import Matrix, noise, Vector
    tmp = bmesh.new()
    bmesh.ops.create_cube(tmp, size=1.0)
    for v in tmp.verts:
        v.co.x *= CW + 0.03
        v.co.y *= CL + 0.03
        v.co.z *= CH + 0.01
    bmesh.ops.subdivide_edges(tmp, edges=list(tmp.edges), cuts=5, use_grid_fill=True)
    bmesh.ops.bevel(tmp, geom=[e for e in tmp.edges if e.calc_face_angle(0.0) > 0.5], offset=0.07, segments=3, profile=0.5, affect="EDGES")
    for v in tmp.verts:
        # sag between the straps and soft folds down the sides
        side = 1.0 - min(1.0, max(0.0, (v.co.z + 0.25) / 0.6))
        fold = math.sin(v.co.y * 9.0 + math.sin(v.co.x * 5.0)) * 0.012 + math.sin(v.co.x * 14.0 + v.co.y * 3.0) * 0.008
        nrm = Vector((v.co.x, v.co.y * 0.3, 0)).normalized() if abs(v.co.z) < 0.38 else Vector((0, 0, 1))
        v.co += nrm * fold * (0.4 + side)
        if v.co.z < -0.3:
            flare = (-0.3 - v.co.z) * 0.22
            v.co.x *= 1.0 + flare
            v.co.y *= 1.0 + flare * 0.5
        if v.co.z > 0.38:
            v.co.z -= 0.012 * (1 + math.cos(v.co.y * 6.6)) * (1.0 - abs(v.co.x) * 1.6)
    m._absorb(tmp, "Canvas", Matrix.Translation(kit.g2b((0, CH / 2 + 0.002, 0))))
    # two lashing straps with buckles
    for z in (-0.5, 0.5):
        m.box((0, CH / 2 + 0.006, z), (CW + 0.075, CH + 0.03, 0.085), "Strap", bevel=0.03, seg=2)
        m.box((0, CH + 0.03, z), (0.13, 0.03, 0.12), "Buckle", bevel=0.012, seg=1)
    ob = m.finish({"Canvas": ("Body", 1.0), "Strap": ("Body", 0.55), "Buckle": ("Body", 0.75)},
                  ao_distance=0.5, ao_strength=0.9, mask=lambda n: (1.0 if n == "Strap" else 0.0, 1.0 if n == "Buckle" else 0.0),
                  sharp_deg=60)
    save(ob, m.name)


def calib():
    """Colour check: three flat swatches with known values."""
    m = Model("calib")
    m.box((-1.2, 0.5, 0), (1, 1, 1), "A", bevel=0)
    m.box((0, 0.5, 0), (1, 1, 1), "B", bevel=0)
    m.box((1.2, 0.5, 0), (1, 1, 1), "C", bevel=0)
    ob = m.finish({"A": "#f2685c", "B": "#808080", "C": ("Hull", 0.5)}, ao=False)
    save(ob, m.name)


# -------------------------------------------------------------------- ships
SHIP_DECK = 0.95
SLOT_X = (-1.15, -0.05, 1.05)


def _hull_outline():
    """Plan outline as (x, z) going round; transom stern, rounded bow."""
    W = 1.3

    def w(x):
        if x < -2.2:
            t = (-2.2 - x) / 0.47
            return W * (1.0 - 0.2 * t ** 2.4)
        if x <= 1.2:
            return W
        t = (x - 1.2) / 1.43
        return W * max(0.0, 1.0 - t ** 2.3) ** 0.6

    xs = [-2.67, -2.6, -2.5, -2.36, -2.2, -1.6, -1.0, -0.4, 0.2, 0.8, 1.2, 1.45, 1.7, 1.92, 2.12, 2.3, 2.44, 2.54, 2.6]
    side = [(x, w(x)) for x in xs]
    pts = side + [(2.63, 0.0)] + [(x, -z) for x, z in reversed(side)]
    return pts


def _inset(pts, d):
    """Offset a closed outline inwards by d."""
    n = len(pts)
    cx = sum(p[0] for p in pts) / n
    cz = sum(p[1] for p in pts) / n
    out = []
    for i in range(n):
        a = pts[i - 1]
        b = pts[(i + 1) % n]
        tx, tz = b[0] - a[0], b[1] - a[1]
        ln = math.hypot(tx, tz) or 1.0
        nx, nz = -tz / ln, tx / ln
        px, pz = pts[i]
        if (cx - px) * nx + (cz - pz) * nz < 0:
            nx, nz = -nx, -nz
        out.append((px + nx * d, pz + nz * d))
    return out


def _hull(m):
    base = _hull_outline()

    def sheer(x):
        t = max(0.0, (x - 0.9) / 1.73)
        return 0.2 * t * t

    def level(y, d, lift=0.0):
        return [(x, y + lift * sheer(base[i][0]), z) for i, (x, z) in enumerate(_inset(base, d))]

    levels = [
        level(-0.64, 0.5), level(-0.3, 0.2), level(0.02, 0.08),      # underwater
        level(0.12, 0.06), level(0.2, 0.045),                        # white boot stripe
        level(0.62, 0.0), level(1.02, 0.0, 1.0),                     # painted side
        level(1.2, 0.0, 1.0), level(1.2, 0.11, 1.0),                 # white rail: outer, top
        level(SHIP_DECK, 0.11),                                      # inner wall down to the deck
    ]
    m.rings(levels, ["Bottom", "Bottom", "Boot", "Boot", "Hull", "Hull", "White", "White", "HullDark"],
            cap_bottom="Bottom", cap_top="Deck")
    for x in SLOT_X:
        m.box((x, SHIP_DECK + 0.024, 0), (1.045, 0.052, 1.96), "Hatch", bevel=0.018, seg=1)
    # bow: winch, bollards and a little jack staff
    m.box((2.0, SHIP_DECK + 0.1, 0), (0.3, 0.2, 0.5), "Steel", bevel=0.04)
    m.cyl((2.0, SHIP_DECK + 0.14, 0), 0.085, 0.62, "Navy", seg=10, axis="z")
    for z in (-0.42, 0.42):
        m.cyl((1.86, SHIP_DECK + 0.09, z), 0.05, 0.18, "Navy", seg=8)
        m.cyl((1.86, SHIP_DECK + 0.19, z), 0.075, 0.04, "Navy", seg=8)
    m.tube([(2.36, SHIP_DECK, 0), (2.36, 1.95, 0)], 0.022, "White", seg=6)
    m.sphere((2.36, 1.97, 0), 0.05, "Yellow", seg=8, rings=5)
    # rubber fenders along both sides
    for z in (-1.31, 1.31):
        for x in (-1.5, -0.2, 1.0):
            m.cyl((x, 0.52, z), 0.11, 0.34, "Rubber", seg=10, bevel=0.03)


def _windows(m, cx, y, cz, sx, sz, h=0.2, glass="Glass"):
    """A dark glazed band wrapped round a block of size (sx, sz)."""
    e = 0.012
    m.box((cx + sx / 2 + e, y, cz), (0.03, h, sz - 0.2), glass, bevel=0.01, seg=1)
    m.box((cx - sx / 2 - e, y, cz), (0.03, h, sz - 0.2), glass, bevel=0.01, seg=1)
    for s in (-1, 1):
        m.box((cx, y, cz + s * (sz / 2 + e)), (sx - 0.2, h, 0.03), glass, bevel=0.01, seg=1)


def _funnel(m, x, y, z, r=0.2, h=0.72, lean=0.0):
    m.cyl((x, y + h / 2, z), r, h, "Funnel", seg=14, r_top=r * 0.92)
    m.cyl((x, y + h * 0.62, z), r * 0.99, 0.13, "White", seg=14)
    m.cyl((x, y + h + 0.03, z), r * 0.98, 0.09, "NavyDark", seg=14, bevel=0.02, bseg=1)


def ship(kind):
    name = ["ship_feeder", "ship_tanker", "ship_coaster"][kind]
    m = Model(name)
    _hull(m)
    D = SHIP_DECK
    hx = -2.13            # house centre
    if kind == 0:
        # feeder: tall bridge with wings and one funnel
        m.box((hx, D + 0.55, 0), (0.78, 1.1, 2.06), "White", bevel=0.07, seg=3)
        _windows(m, hx, D + 0.72, 0, 0.78, 2.06, 0.2)
        m.box((hx, D + 1.14, 0), (0.92, 0.09, 2.5), "Trim", bevel=0.035)
        m.box((hx + 0.03, D + 1.5, 0), (0.66, 0.62, 1.36), "White", bevel=0.07, seg=3)
        _windows(m, hx + 0.03, D + 1.56, 0, 0.66, 1.36, 0.26)
        m.box((hx + 0.03, D + 1.85, 0), (0.78, 0.08, 1.5), "Cream", bevel=0.035)
        _funnel(m, hx - 0.14, D + 1.88, 0)
        m.tube([(hx + 0.24, D + 1.88, 0), (hx + 0.24, D + 2.5, 0)], 0.024, "White", seg=6)
        m.box((hx + 0.24, D + 2.42, 0), (0.05, 0.05, 0.5), "White", bevel=0.015, seg=1)
        for z in (-0.92, 0.92):
            m.cyl((hx, D + 0.32, z + (0.13 if z > 0 else -0.13)), 0.17, 0.07, "Orange", seg=12, axis="z")
    elif kind == 1:
        # wide low bridge across the beam with twin funnels
        m.box((hx, D + 0.42, 0), (0.78, 0.84, 2.16), "White", bevel=0.07, seg=3)
        _windows(m, hx, D + 0.52, 0, 0.78, 2.16, 0.18)
        m.box((hx, D + 0.88, 0), (0.9, 0.09, 2.36), "Trim", bevel=0.035)
        m.box((hx + 0.02, D + 1.2, 0), (0.7, 0.56, 1.96), "White", bevel=0.07, seg=3)
        _windows(m, hx + 0.02, D + 1.25, 0, 0.7, 1.96, 0.24)
        m.box((hx + 0.02, D + 1.52, 0), (0.82, 0.08, 2.08), "Cream", bevel=0.035)
        for z in (-0.5, 0.5):
            _funnel(m, hx - 0.12, D + 1.55, z, r=0.165, h=0.62)
        m.tube([(hx + 0.2, D + 1.55, 0), (hx + 0.2, D + 2.3, 0)], 0.024, "White", seg=6)
        m.sphere((hx + 0.2, D + 2.32, 0), 0.07, "Orange", seg=8, rings=5)
    else:
        # coaster: slim tower, round-topped wheelhouse, offset funnel, lifeboat
        m.box((hx, D + 0.4, 0), (0.78, 0.8, 2.1), "White", bevel=0.07, seg=3)
        _windows(m, hx, D + 0.5, 0, 0.78, 2.1, 0.16)
        m.box((hx, D + 0.84, 0), (0.88, 0.08, 2.2), "Trim", bevel=0.035)
        m.box((hx + 0.02, D + 1.3, -0.22), (0.7, 0.9, 1.2), "White", bevel=0.07, seg=3)
        _windows(m, hx + 0.02, D + 1.5, -0.22, 0.7, 1.2, 0.26)
        m.cyl((hx + 0.02, D + 1.75, -0.22), 0.36, 1.2, "Cream", seg=16, axis="z", bevel=0.03, bseg=1)
        _funnel(m, hx - 0.08, D + 0.88, 0.68, r=0.19, h=0.95)
        m.cyl((hx + 0.05, D + 1.0, -0.2 + 1.28), 0.13, 0.5, "Orange", seg=10, axis="x", bevel=0.05)
        m.tube([(hx + 0.2, D + 2.0, -0.22), (hx + 0.2, D + 2.6, -0.22)], 0.024, "White", seg=6)
        m.box((hx + 0.2, D + 2.5, -0.22), (0.05, 0.05, 0.46), "White", bevel=0.015, seg=1)
    ob = m.finish(P, ao_distance=0.9, ao_strength=0.75, sharp_deg=38)
    save(ob, name)


# -------------------------------------------------------------------- crane
def crane(gold=False):
    """Ship-to-shore gantry: legs on the two quay rails (z = -2.75 and 0.05),
    boom reaching over the water."""
    m = Model("crane_gold" if gold else "crane")
    main = "Gold" if gold else "White"
    dark = "GoldDark" if gold else "Navy"
    acc = "White" if gold else "Yellow"
    zf, zb = -2.75, 0.05
    hw = 1.25
    for sx in (-1, 1):
        for z in (zf, zb):
            m.box((sx * hw, 0.16, z), (0.62, 0.32, 0.5), dark, bevel=0.06)          # bogie
            m.box((sx * hw, 3.2, z), (0.3, 5.9, 0.3), main, bevel=0.05)             # leg
        m.box((sx * hw, 2.3, (zf + zb) / 2), (0.22, 0.22, zb - zf), main, bevel=0.04)       # sill beam
        m.box((sx * hw, 6.1, -0.6), (0.32, 0.4, 6.4), main, bevel=0.06)             # portal girder
        # diagonal brace
        m.tube([(sx * hw, 2.4, zf + 0.05), (sx * hw, 5.9, zb - 0.05)], 0.07, main, seg=6)
    for z in (zf, zb):
        m.box((0, 6.1, z), (2 * hw, 0.32, 0.3), main, bevel=0.05)
        m.box((0, 0.34, z), (2 * hw + 0.3, 0.1, 0.16), acc, bevel=0.02, seg=1)
    # boom over the sea and the back reach
    m.box((0, 6.55, -3.0), (0.62, 0.5, 11.4), main, bevel=0.08)
    m.box((0, 6.86, -3.0), (0.2, 0.1, 11.2), acc, bevel=0.02, seg=1)
    m.box((0, 6.55, -8.72), (0.7, 0.58, 0.16), dark, bevel=0.05)
    # machinery house and A-frame
    m.box((0, 7.25, 1.6), (1.5, 0.9, 1.9), dark, bevel=0.1, seg=3)
    m.box((0, 7.3, 0.64), (1.2, 0.34, 0.03), "GlassLight", bevel=0.01, seg=1)
    for sx in (-1, 1):
        m.tube([(sx * 0.5, 6.8, -2.75), (0, 9.7, -1.4), (sx * 0.5, 6.8, 0.05)], 0.09, main, seg=6)
    m.tube([(0, 9.7, -1.4), (0, 6.85, -7.9)], 0.045, dark, seg=5)
    m.tube([(0, 9.7, -1.4), (0, 7.7, 2.3)], 0.045, dark, seg=5)
    m.sphere((0, 9.74, -1.4), 0.16, "Coral", seg=10, rings=6)
    # trolley and cab under the boom
    m.box((0, 6.2, -4.6), (0.8, 0.24, 0.9), dark, bevel=0.05)
    m.box((0, 5.72, -4.2), (0.74, 0.72, 0.8), acc, bevel=0.1, seg=3)
    m.box((0, 5.72, -4.615), (0.56, 0.4, 0.03), "Glass", bevel=0.01, seg=1)
    ob = m.finish(P, ao_distance=1.2, ao_strength=0.7)
    save(ob, m.name)


# ---------------------------------------------------------------- buildings
def warehouse(variant):
    """Quayside shed with a flat roof terrace (floor at y = 3.43). The front
    faces -z (towards the camera). Footprint x +-3.72, z -3.1 .. 2.62."""
    m = Model("warehouse_" + variant)
    wall, door, doord, base = (("WallA", "DoorA", "DoorAD", "BaseA") if variant == "a"
                               else ("WallB", "DoorB", "DoorBD", "BaseB"))
    zc, depth = -0.24, 5.72
    m.box((0, 1.715, zc), (7.44, 3.43, depth), wall, bevel=0.08, seg=2)
    m.box((0, 0.2, zc), (7.56, 0.4, depth + 0.12), base, bevel=0.05)
    m.box((0, 3.44, zc), (7.0, 0.03, depth - 0.44), "RoofFloor", bevel=0.0)
    # parapet with a white cap
    t = 0.24
    for z in (zc - depth / 2 + t / 2, zc + depth / 2 - t / 2):
        m.box((0, 3.62, z), (7.44, 0.42, t), wall, bevel=0.04)
        m.box((0, 3.85, z), (7.54, 0.07, t + 0.1), "White", bevel=0.025)
    for x in (-3.72 + t / 2, 3.72 - t / 2):
        m.box((x, 3.62, zc), (t, 0.42, depth), wall, bevel=0.04)
        m.box((x, 3.85, zc), (t + 0.1, 0.07, depth + 0.1), "White", bevel=0.025)
    zf = -3.1
    # three arched loading doors with white surrounds
    for x in (-2.35, 0.0, 2.35):
        m.box((x, 0.95, zf - 0.02), (1.74, 1.9, 0.1), "White", bevel=0.03)
        m.cyl((x, 1.9, zf - 0.02), 0.87, 0.1, "White", seg=20, axis="z")
        m.box((x, 0.92, zf - 0.06), (1.46, 1.84, 0.08), door, bevel=0.02, seg=1)
        m.cyl((x, 1.84, zf - 0.06), 0.73, 0.08, door, seg=20, axis="z")
        for k in range(4):
            m.box((x, 0.36 + k * 0.4, zf - 0.105), (1.3, 0.05, 0.02), doord, bevel=0.0)
        m.sphere((x + 0.5, 0.95, zf - 0.12), 0.06, "Gold", seg=8, rings=5)
        # porthole above
        m.cyl((x, 3.0, zf - 0.02), 0.2, 0.08, "White", seg=14, axis="z")
        m.cyl((x, 3.0, zf - 0.05), 0.14, 0.06, "Glass", seg=14, axis="z")
    # lanterns between the doors
    for x in (-1.175, 1.175):
        m.box((x, 2.25, zf - 0.08), (0.1, 0.34, 0.1), "Navy", bevel=0.02, seg=1)
        m.box((x, 2.08, zf - 0.2), (0.2, 0.26, 0.2), "Lamp", bevel=0.05)
        m.box((x, 2.24, zf - 0.2), (0.26, 0.06, 0.26), "Navy", bevel=0.02, seg=1)
    # corner pilasters
    for x in (-3.6, 3.6):
        m.box((x, 1.9, zf - 0.03), (0.3, 3.0, 0.12), "White", bevel=0.04)
    pal = dict(P)
    # painted harbour-front colours: salmon with sea-green doors, butter with blue
    pal.update({"WallA": "#f8b9a0", "BaseA": "#e08f72", "DoorA": "#3f9c98", "DoorAD": "#32837f",
                "WallB": "#fbe6ac", "BaseB": "#ecc876", "DoorB": "#5a8fcb", "DoorBD": "#4878b2",
                "RoofFloor": "#e8d7b6"})
    ob = m.finish(pal, ao_distance=1.6, ao_strength=0.55, densify=0.9)
    save(ob, m.name)


def lighthouse(restored=True):
    m = Model("lighthouse" if restored else "lighthouse_ruin")
    m.cyl((0, 0.2, 0), 0.72, 0.4, "Stone", seg=18, bevel=0.06)
    tiers = 5 if restored else 4
    h = 0.78
    for i in range(tiers):
        r0 = 0.5 - i * 0.045
        if restored:
            paint = "White" if i % 2 == 0 else "Red"
        else:
            paint = "RuinA" if i % 2 == 0 else "RuinB"
        m.cyl((0, 0.4 + h * (i + 0.5), 0), r0, h, paint, seg=18, r_top=r0 - 0.045)
    top = 0.4 + tiers * h
    if restored:
        m.cyl((0, top + 0.05, 0), 0.5, 0.1, "Navy", seg=18, bevel=0.03, bseg=1)
        m.cyl((0, top + 0.4, 0), 0.25, 0.6, "Lamp", seg=14)
        for k in range(6):
            a = math.tau * k / 6
            m.tube([(0.27 * math.cos(a), top + 0.1, 0.27 * math.sin(a)), (0.27 * math.cos(a), top + 0.7, 0.27 * math.sin(a))], 0.022, "Navy", seg=5)
        m.cyl((0, top + 0.86, 0), 0.36, 0.34, "Red", seg=18, r_top=0.04)
        m.sphere((0, top + 1.06, 0), 0.07, "Yellow", seg=8, rings=5)
        m.box((0, 0.75, -0.47), (0.26, 0.5, 0.06), "Navy", bevel=0.03)
    else:
        m.cyl((0, top + 0.04, 0), 0.34, 0.08, "RuinB", seg=12)
        for x in (-0.68, 0.68):
            for z in (-0.68, 0.68):
                m.tube([(x, 0, z), (x, 3.0, z)], 0.04, "Wood", seg=5)
        for y in (1.0, 2.0, 2.9):
            for z in (-0.68, 0.68):
                m.box((0, y, z), (1.5, 0.07, 0.07), "Wood", bevel=0.015, seg=1)
            for x in (-0.68, 0.68):
                m.box((x, y, 0), (0.07, 0.07, 1.4), "Wood", bevel=0.015, seg=1)
    pal = dict(P)
    pal.update({"RuinA": "#d3ccc0", "RuinB": "#bbb3a6"})
    ob = m.finish(pal, ao_distance=1.0, ao_strength=0.6)
    save(ob, m.name)


# -------------------------------------------------------------------- props
def palm():
    m = Model("palm")
    path = [(0.0, 0.0, 0.0), (0.06, 0.7, 0.0), (0.18, 1.4, 0.02), (0.36, 2.1, 0.05), (0.56, 2.75, 0.08)]
    m.tube(path, 0.17, "Trunk", seg=8, r_end=0.1)
    for i, p in enumerate(path[1:-1]):
        m.cyl(p, 0.17 - i * 0.02, 0.07, "TrunkDark", seg=8)
    top = path[-1]
    n = 7
    for k in range(n):
        a = math.tau * k / n + 0.3
        dx, dz = math.cos(a), math.sin(a)
        droop = 0.55 + 0.12 * (k % 2)
        # each frond: two tapered slabs, the outer one hanging down
        m.box((top[0] + dx * 0.5, top[1] + 0.14, top[2] + dz * 0.5), (1.0, 0.07, 0.42),
              "Leaf" if k % 2 == 0 else "LeafDark", bevel=0.03, seg=1, rot=(0, -a, 0.28), taper=(1.0, 0.6))
        m.box((top[0] + dx * 1.22, top[1] + 0.02 - droop * 0.2, top[2] + dz * 1.22), (0.74, 0.06, 0.34),
              "Leaf" if k % 2 == 0 else "LeafDark", bevel=0.03, seg=1, rot=(0, -a, -droop), taper=(1.0, 0.5))
    m.sphere((top[0], top[1] + 0.1, top[2]), 0.2, "LeafDark", seg=10, rings=6)
    for a in (0.5, 2.6, 4.4):
        m.sphere((top[0] + 0.16 * math.cos(a), top[1] - 0.08, top[2] + 0.16 * math.sin(a)), 0.085, "TrunkDark", seg=8, rings=5)
    ob = m.finish(P, ao_distance=0.8, ao_strength=0.55)
    save(ob, "palm")


def tree_round():
    m = Model("tree_round")
    m.tube([(0, 0, 0), (0, 0.9, 0)], 0.1, "Trunk", seg=7, r_end=0.07)
    m.ico((0, 1.35, 0), 0.62, "Leaf", sub=2, scale=(1, 0.92, 1))
    m.ico((0.3, 1.72, 0.1), 0.36, "LeafLight", sub=2)
    m.ico((-0.28, 1.6, -0.18), 0.34, "LeafDark", sub=2)
    ob = m.finish(P, ao_distance=0.8, ao_strength=0.5, sharp_deg=80)
    save(ob, "tree_round")


def cypress():
    m = Model("cypress")
    m.tube([(0, 0, 0), (0, 0.4, 0)], 0.07, "Trunk", seg=6)
    m.ico((0, 1.35, 0), 0.34, "LeafDark", sub=2, scale=(0.92, 3.3, 0.92))
    ob = m.finish(P, ao_distance=0.8, ao_strength=0.5, sharp_deg=80)
    save(ob, "cypress")


def buoy():
    m = Model("navigation_buoy")
    m.cyl((0, 0.06, 0), 0.3, 0.2, "Hull", seg=14, bevel=0.06)
    m.cyl((0, 0.3, 0), 0.2, 0.32, "White", seg=12, r_top=0.12)
    m.cyl((0, 0.56, 0), 0.12, 0.2, "Hull", seg=12, r_top=0.09)
    m.sphere((0, 0.74, 0), 0.085, "Lamp", seg=10, rings=6)
    ob = m.finish(P, ao_distance=0.5, ao_strength=0.5, ground=False)
    save(ob, "navigation_buoy")


def bollard():
    m = Model("mooring_bollard")
    m.cyl((0, 0.03, 0), 0.2, 0.06, "NavyDark", seg=12)
    m.cyl((0, 0.16, 0), 0.11, 0.24, "Navy", seg=12)
    m.cyl((0, 0.31, 0), 0.17, 0.09, "Yellow", seg=12, bevel=0.03, bseg=2)
    ob = m.finish(P, ao_distance=0.4, ao_strength=0.6)
    save(ob, "mooring_bollard")


def light_mast():
    m = Model("light_mast")
    m.cyl((0, 0.2, 0), 0.26, 0.4, "Stone", seg=12, bevel=0.05)
    m.tube([(0, 0.4, 0), (0, 7.6, 0)], 0.09, "White", seg=8, r_end=0.06)
    m.box((0, 7.65, 0), (1.3, 0.12, 0.16), "Navy", bevel=0.04)
    for x in (-0.48, 0.0, 0.48):
        m.box((x, 7.5, -0.06), (0.36, 0.2, 0.3), "Navy", bevel=0.05)
        m.box((x, 7.42, -0.1), (0.28, 0.05, 0.22), "Lamp", bevel=0.01, seg=1)
    ob = m.finish(P, ao_distance=0.8, ao_strength=0.5)
    save(ob, "light_mast")


def tractor():
    """Yard truck with an empty trailer; nose towards -z."""
    m = Model("tractor")
    m.box((0, 0.42, 0.1), (0.9, 0.16, 3.5), "Navy", bevel=0.04)                   # chassis
    m.box((0, 0.98, -1.38), (0.98, 0.98, 0.9), "Yellow", bevel=0.14, seg=3)       # cab
    m.box((0, 1.12, -1.84), (0.78, 0.44, 0.04), "Glass", bevel=0.01, seg=1)
    for sx in (-1, 1):
        m.box((sx * 0.495, 1.12, -1.42), (0.03, 0.4, 0.5), "Glass", bevel=0.01, seg=1)
    m.box((0, 0.6, -1.86), (0.9, 0.2, 0.08), "White", bevel=0.03)
    m.box((0, 0.56, 0.6), (1.0, 0.12, 2.5), "Steel", bevel=0.03)                  # trailer bed
    for z in (-1.38, 0.9, 1.5):
        for sx in (-1, 1):
            m.cyl((sx * 0.46, 0.25, z), 0.25, 0.2, "Rubber", seg=12, axis="x", bevel=0.05)
            m.cyl((sx * 0.565, 0.25, z), 0.1, 0.02, "Steel", seg=8, axis="x")
    m.sphere((0.3, 1.5, -1.3), 0.07, "Orange", seg=8, rings=5)
    ob = m.finish(P, ao_distance=0.7, ao_strength=0.6)
    save(ob, "tractor")


def spreader():
    m = Model("spreader")
    m.box((0, 0.07, 0), (0.34, 0.14, CL - 0.1), "Yellow", bevel=0.04)
    for sz in (-1, 1):
        m.box((0, 0.07, sz * (CL / 2 - 0.08)), (CW - 0.04, 0.14, 0.16), "Yellow", bevel=0.04)
        for sx in (-1, 1):
            m.box((sx * (CW / 2 - 0.07), 0.03, sz * (CL / 2 - 0.08)), (0.11, 0.1, 0.13), "Navy", bevel=0.02, seg=1)
    m.box((0, 0.17, 0), (0.46, 0.1, 0.5), "Navy", bevel=0.03)
    ob = m.finish(P, ao_distance=0.4, ao_strength=0.5, ground=False)
    save(ob, "spreader")


def quay_segment():
    """2.6 m of quay wall; z = 0 is the wall face, the sea is towards -z."""
    m = Model("quay_segment")
    m.box((0, -1.5, 0.4), (2.6, 3.0, 0.8), "QuayWall", bevel=0.0)
    m.box((0, -0.02, 0.2), (2.58, 0.3, 0.52), "White", bevel=0.06, seg=3)      # kerb
    m.box((1.3, -1.3, -0.03), (0.24, 2.3, 0.1), "QuayPier", bevel=0.04)
    m.cyl((0, -0.42, -0.1), 0.27, 0.24, "Rubber", seg=14, axis="z", bevel=0.07, bseg=2)
    m.cyl((0, -0.42, -0.2), 0.11, 0.08, "SteelDark", seg=10, axis="z")
    pal = dict(P)
    pal.update({"QuayWall": "#d8c7a6", "QuayPier": "#c9b792"})
    ob = m.finish(pal, ao_distance=0.8, ao_strength=0.6, ground=False,
                  shade=lambda c, n: 1.0 - 0.3 * min(1.0, max(0.0, (-c[1] - 0.2) / 0.9)) if n in ("QuayWall", "QuayPier") else 1.0)
    save(ob, "quay_segment")


def padlock():
    m = Model("padlock")
    m.box((0, 0.0, 0), (0.36, 0.3, 0.12), "Gold", bevel=0.05, seg=3)
    path = []
    for k in range(9):
        a = math.pi * k / 8
        path.append((0.105 * math.cos(a), 0.2 + 0.11 * math.sin(a), 0))
    path = [(0.105, 0.1, 0)] + path + [(-0.105, 0.1, 0)]
    m.tube(path, 0.036, "Steel", seg=8)
    m.cyl((0, 0.01, -0.062), 0.04, 0.012, "GoldDark", seg=10, axis="z")
    ob = m.finish(P, ao=False)
    save(ob, "padlock")


def cloud():
    m = Model("cloud")
    for c, r in (((0, 0.2, 0), 1.5), ((1.6, 0.0, 0.2), 1.1), ((-1.7, -0.05, -0.1), 1.2), ((0.6, 0.7, -0.2), 1.05), ((-0.8, 0.55, 0.3), 0.95)):
        m.ico(c, r, "White", sub=2, scale=(1.15, 0.8, 0.9), flat_bottom=-0.42 * r)
    ob = m.finish({"White": "#ffffff"}, ao=False, sharp_deg=80, weld=False)
    save(ob, "cloud")


BUILDERS = {
    "calib": calib,
    "container": lambda: container(True),
    "container_lod": lambda: container(False),
    "container_tarp": container_tarp,
    "ship_feeder": lambda: ship(0),
    "ship_tanker": lambda: ship(1),
    "ship_coaster": lambda: ship(2),
    "crane": lambda: crane(False),
    "crane_gold": lambda: crane(True),
    "warehouse_a": lambda: warehouse("a"),
    "warehouse_b": lambda: warehouse("b"),
    "lighthouse": lambda: lighthouse(True),
    "lighthouse_ruin": lambda: lighthouse(False),
    "palm": palm,
    "tree_round": tree_round,
    "cypress": cypress,
    "navigation_buoy": buoy,
    "mooring_bollard": bollard,
    "light_mast": light_mast,
    "tractor": tractor,
    "spreader": spreader,
    "padlock": padlock,
    "quay_segment": quay_segment,
    "cloud": cloud,
}

if __name__ == "__main__":
    want = sys.argv[1:]
    for name, fn in BUILDERS.items():
        if name == "calib" and "calib" not in want:
            continue
        if want and not any(w in name for w in want):
            continue
        kit.reset()
        fn()
