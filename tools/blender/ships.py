"""Builds the three ship types as GLB files.

Run: blender -b --python tools/blender/ships.py

Gameplay contract (must match scripts/ship.gd and scripts/meshes.gd):
- origin at the waterline, length along X (stern -2.6, bow ~+2.5), beam along Z (+-1.18)
- main deck at y = 0.95, hatch plates 0.05 thick under the three cargo slots
- cargo slots centred at x = -1.15, -0.05, 1.05, each 1.0 (x) by 1.9 (z): keep clear
- superstructure lives behind x = -1.72

Materials (re-created in the game): Hull (tinted per ship), HullWhite, BootTop,
Bottom, Deck (tinted pale), Hatch, House, Glass, Roof, Funnel (tinted), FunnelTop,
Metal, Orange, Dark.
"""
import math
import sys

sys.path.insert(0, __file__.rsplit("/", 1)[0])
import bmesh  # noqa: E402
import bpy  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

import lib  # noqa: E402

OUT = __file__.rsplit("/tools/", 1)[0] + "/assets/models/"
DECK = 0.95
BEAM = 1.18
SLOTS = [-1.15, -0.05, 1.05]
LEVELS = [DECK, 0.9, 0.74, 0.5, 0.25, 0.06, -0.03, -0.25, -0.45, -0.6, -0.7]


def away_from_keel(c):
    """Outward direction for hull plating: away from the ship's centre line."""
    x, y, z = c
    return (0.0, (y - 0.1) * 0.3, z) if abs(z) > 0.02 else (1.0 if x > 0 else -1.0, 0.0, 0.0)


def up(_c):
    return (0.0, 1.0, 0.0)


def down(_c):
    return (0.0, -1.0, 0.0)


def material_for_y(y):
    if y > 0.9:
        return "HullWhite"
    if y > 0.06:
        return "Hull"
    if y > -0.03:
        return "BootTop"
    return "Bottom"


def hull(style):
    """Lofted hull. style: 'raked' (bulbous, raked stem), 'tanker' (full, rounded), 'straight' (vertical stem)."""
    bow_start = 1.5 if style != "tanker" else 1.75
    tip_deck = 2.58 if style != "straight" else 2.45

    def x_tip(y):
        if style == "straight":
            return tip_deck - 0.05 * (DECK - y)
        # raked stem: tip moves aft lower down
        return tip_deck - 0.32 * (DECK - y) / (DECK + 0.7)

    def x_stern(y):
        return -2.6 + (0.12 if y < 0.0 else 0.0) * (-y / 0.7)

    def bilge(y):
        if y >= -0.25:
            return 1.0
        t = (-0.25 - y) / 0.45
        return 1.0 - 0.2 * (1 - math.cos(t * math.pi / 2)) ** 0.8

    def half_width(x, y):
        w = BEAM * bilge(y)
        xt = x_tip(y)
        if x > bow_start:
            t = min(1.0, (x - bow_start) / max(0.05, xt - bow_start))
            power = 1.6 if style != "tanker" else 2.4
            w *= max(0.0, 1.0 - t ** power) ** 0.62
        # gentle narrowing at the transom
        xs = x_stern(y)
        if x < xs + 0.4:
            w *= 0.94 + 0.06 * max(0.0, (x - xs) / 0.4)
        return w

    stations = []
    n = 34
    for i in range(n + 1):
        # denser near the bow
        u = i / n
        x = -2.6 + (2.62 + 2.6) * (u ** 0.85)
        stations.append(x)

    verts = []
    faces = []
    mats = []
    rings = []
    for x in stations:
        ring = []
        for y in LEVELS:
            xs, xt = x_stern(y), x_tip(y)
            xc = min(max(x, xs), xt)
            w = half_width(xc, y) if xc < xt else 0.0
            ring.append((xc, y, w))
        rings.append(ring)
    # side surfaces, both sides
    for side in (1, -1):
        base = len(verts)
        for ring in rings:
            for (x, y, w) in ring:
                verts.append((x, y, side * w))
        L = len(LEVELS)
        for i in range(len(rings) - 1):
            for k in range(L - 1):
                a = base + i * L + k
                b = base + (i + 1) * L + k
                c = base + (i + 1) * L + k + 1
                d = base + i * L + k + 1
                f = [a, b, c, d] if side > 0 else [a, d, c, b]
                faces.append(f)
                mats.append(material_for_y((LEVELS[k] + LEVELS[k + 1]) * 0.5))
    objs = []
    by_mat = {}
    for f, m in zip(faces, mats):
        by_mat.setdefault(m, []).append(f)
    for m, fs in by_mat.items():
        objs.append(lib.mesh_from(verts, fs, m, "hull_" + m, outward=away_from_keel))
    # transom (stern plate)
    tv = []
    for (x, y, w) in rings[0]:
        tv.append((x, y, w))
    for (x, y, w) in reversed(rings[0]):
        tv.append((x, y, -w))
    tf = []
    L = len(LEVELS)
    for k in range(L - 1):
        tf.append([k, k + 1, 2 * L - 2 - k, 2 * L - 1 - k])
    objs.append(lib.mesh_from(tv, tf, "HullWhite", "transom", outward=lambda c: (-1.0, 0.0, 0.0)))
    # deck and bottom caps (fans from the centre line)
    for level_idx, mname in ((0, "Deck"), (L - 1, "Bottom")):
        dv = [(0.0, LEVELS[level_idx], 0.0)]
        outline = [(r[level_idx][0], LEVELS[level_idx], r[level_idx][2]) for r in rings]
        outline += [(x, y, -w) for (x, y, w) in reversed(outline)]
        dv += outline
        df = []
        for i in range(len(outline)):
            j = (i + 1) % len(outline)
            df.append([0, i + 1, j + 1] if level_idx == 0 else [0, j + 1, i + 1])
        objs.append(lib.mesh_from(dv, df, mname, "cap", outward=up if level_idx == 0 else down))
    if style == "raked":
        # bulbous bow
        bm = bmesh.new()
        bmesh.ops.create_uvsphere(bm, u_segments=12, v_segments=8, radius=1.0)
        bmesh.ops.scale(bm, vec=(0.42, 0.17, 0.2), verts=bm.verts)
        bmesh.ops.translate(bm, vec=lib.g2b(2.28, -0.42, 0.0), verts=bm.verts)
        me = bpy.data.meshes.new("bulb")
        bm.to_mesh(me)
        bm.free()
        ob = bpy.data.objects.new("bulb", me)
        bpy.context.collection.objects.link(ob)
        me.materials.append(lib.mat("Bottom"))
        objs.append(ob)
    return objs, half_width


def deck_details(half_width, style):
    objs = []
    # hatch plates under each cargo slot
    for x in SLOTS:
        objs.append(lib.box((x, DECK + 0.025, 0), (1.06, 0.05, 1.98), "Hatch", bevel=0.01))
    # walkway strips between hatches
    for x in (-0.6, 0.5):
        objs.append(lib.box((x, DECK + 0.006, 0), (0.08, 0.012, 2.0), "Metal"))
    # railings along both sides of the cargo deck and around the bow
    for side in (1, -1):
        xs = [-1.7 + 0.32 * i for i in range(14)]
        prev = None
        for x in xs:
            w = half_width(x, DECK) - 0.05
            if w < 0.1:
                break
            p = (x, DECK + 0.1, side * w)
            objs.append(lib.box(p, (0.025, 0.2, 0.025), "Metal"))
            top = (x, DECK + 0.2, side * w)
            if prev:
                objs.append(lib.beam(prev, top, 0.025, "Metal"))
            prev = top
    # forecastle: raised bow deck with a bulwark
    fx0 = 1.62
    pts = []
    x = fx0
    while x < 2.6:
        w = half_width(x, DECK)
        if w < 0.03:
            break
        pts.append((x, w))
        x += 0.08
    if len(pts) > 2:
        top_y = DECK + 0.2
        verts = []
        for (px, w) in pts:
            verts.append((px, DECK, w))
            verts.append((px, top_y, w))
        tip = (pts[-1][0] + 0.06, 0.0)
        side_faces = []
        for i in range(len(pts) - 1):
            a, b = 2 * i, 2 * (i + 1)
            side_faces.append([a, b, b + 1, a + 1])
        objs.append(lib.mesh_from(verts, side_faces, "Hull", "fc_s1", outward=away_from_keel))
        verts2 = [(vx, vy, -vz) for (vx, vy, vz) in verts]
        objs.append(lib.mesh_from(verts2, side_faces, "Hull", "fc_s2", outward=away_from_keel))
        topv = [(fx0, top_y, 0.0)] + [(px, top_y, w) for (px, w) in pts] + [(px, top_y, -w) for (px, w) in reversed(pts)]
        tf = [[0, i + 1, i + 2] for i in range(len(topv) - 2)]
        objs.append(lib.mesh_from(topv, tf, "Deck", "fc_top", outward=up))
        objs.append(lib.box((fx0, DECK + 0.1, 0), (0.04, 0.2, 2 * pts[0][1]), "HullWhite"))
        # windlass and mooring bitts
        objs.append(lib.cylinder((2.0, top_y + 0.07, 0.25), 0.07, 0.3, "Dark", segs=10, axis="z"))
        objs.append(lib.cylinder((2.0, top_y + 0.07, -0.25), 0.07, 0.3, "Dark", segs=10, axis="z"))
        for z in (0.55, -0.55):
            objs.append(lib.cylinder((1.78, top_y + 0.06, z), 0.045, 0.12, "Dark", segs=8))
        # foremast with a light
        objs.append(lib.cylinder((2.12, top_y + 0.45, 0), 0.03, 0.9, "Metal", segs=8))
        objs.append(lib.box((2.12, top_y + 0.92, 0), (0.08, 0.06, 0.08), "Orange"))
    # anchors on the bow flare
    for side in (1, -1):
        w = half_width(2.0, 0.6)
        objs.append(lib.box((2.0, 0.62, side * (w + 0.01)), (0.16, 0.2, 0.04), "Dark", bevel=0.01))
    # mooring bitts aft
    for z in (0.9, -0.9):
        objs.append(lib.cylinder((-1.62, DECK + 0.06, z), 0.045, 0.12, "Dark", segs=8))
    if style == "tanker":
        # deck pipework along the sides
        for z in (1.04, -1.04):
            objs.append(lib.cylinder((-0.1, DECK + 0.06, z), 0.035, 3.3, "Metal", segs=8, axis="x"))
            objs.append(lib.cylinder((-0.1, DECK + 0.06, z * 0.93), 0.025, 3.3, "Orange", segs=6, axis="x"))
        for x in (-1.6, -0.6, 0.5, 1.5):
            for z in (1.04, -1.04):
                objs.append(lib.box((x, DECK + 0.04, z), (0.05, 0.08, 0.14), "Metal"))
    return objs


def house_feeder():
    o = []
    # three-tier accommodation block
    o.append(lib.box((-2.17, DECK + 0.27, 0), (0.84, 0.54, 2.0), "House", bevel=0.02))
    o.append(lib.box((-2.2, DECK + 0.74, 0), (0.74, 0.4, 1.82), "House", bevel=0.02))
    o.append(lib.box((-2.15, DECK + 1.1, 0), (0.7, 0.34, 2.44), "House", bevel=0.02))
    o.append(lib.box((-2.15, DECK + 1.3, 0), (0.78, 0.06, 2.52), "Roof"))
    # windows: front faces look forward (+x)
    o.append(lib.box((-1.745, DECK + 0.32, 0), (0.02, 0.12, 1.7), "Glass"))
    o.append(lib.box((-1.825, DECK + 0.76, 0), (0.02, 0.12, 1.5), "Glass"))
    o.append(lib.box((-1.795, DECK + 1.12, 0), (0.02, 0.17, 2.3), "Glass"))
    for z in (1.21, -1.21):
        o.append(lib.box((-2.15, DECK + 1.12, z), (0.5, 0.12, 0.02), "Glass"))
    # mast and radar
    o.append(lib.cylinder((-2.2, DECK + 1.75, 0), 0.03, 0.9, "Metal", segs=8))
    o.append(lib.box((-2.2, DECK + 1.62, 0), (0.06, 0.04, 0.7), "Metal"))
    o.append(lib.box((-2.2, DECK + 2.02, 0), (0.05, 0.03, 0.5), "Dark"))
    # funnel behind the bridge
    o.append(lib.box((-2.43, DECK + 1.55, 0), (0.34, 0.5, 0.42), "Funnel", bevel=0.05, segments=2))
    o.append(lib.box((-2.43, DECK + 1.83, 0), (0.36, 0.08, 0.44), "FunnelTop", bevel=0.02))
    o.append(lib.box((-2.43, DECK + 1.52, 0), (0.355, 0.08, 0.435), "HullWhite", bevel=0.03))
    # lifeboats on davits
    for z in (1.04, -1.04):
        o.append(lib.box((-2.2, DECK + 0.66, z), (0.46, 0.14, 0.16), "Orange", bevel=0.05, segments=2))
        for x in (-2.38, -2.02):
            o.append(lib.box((x, DECK + 0.72, z * 0.94), (0.03, 0.22, 0.03), "Metal"))
    return o, (-2.43, DECK + 1.9, 0.0)


def house_tanker():
    o = []
    # rounded, stepped superstructure
    o.append(lib.box((-2.15, DECK + 0.32, 0), (0.88, 0.64, 2.1), "House", bevel=0.08, segments=3))
    o.append(lib.box((-2.18, DECK + 0.86, 0), (0.78, 0.44, 1.9), "House", bevel=0.08, segments=3))
    o.append(lib.box((-2.12, DECK + 1.22, 0), (0.62, 0.3, 2.3), "House", bevel=0.06, segments=2))
    o.append(lib.box((-1.82, DECK + 1.24, 0), (0.02, 0.15, 2.1), "Glass"))
    o.append(lib.box((-1.72, DECK + 0.4, 0), (0.02, 0.12, 1.8), "Glass"))
    o.append(lib.box((-1.8, DECK + 0.88, 0), (0.02, 0.12, 1.6), "Glass"))
    o.append(lib.box((-2.12, DECK + 1.4, 0), (0.66, 0.05, 2.36), "Roof"))
    # twin slim funnels
    for z in (0.3, -0.3):
        o.append(lib.cylinder((-2.45, DECK + 1.6, z), 0.11, 0.7, "Funnel", segs=12))
        o.append(lib.cylinder((-2.45, DECK + 1.98, z), 0.115, 0.08, "FunnelTop", segs=12))
    o.append(lib.cylinder((-2.1, DECK + 1.8, 0), 0.03, 0.8, "Metal", segs=8))
    o.append(lib.box((-2.1, DECK + 2.05, 0), (0.05, 0.03, 0.45), "Dark"))
    # rescue boat on the side
    o.append(lib.box((-2.25, DECK + 0.72, 1.07), (0.4, 0.13, 0.15), "Orange", bevel=0.05, segments=2))
    o.append(lib.box((-2.25, DECK + 0.72, -1.07), (0.4, 0.13, 0.15), "Orange", bevel=0.05, segments=2))
    return o, (-2.45, DECK + 2.0, 0.3)


def house_coaster():
    o = []
    # tall boxy block with a sloped bridge front and full-width wings
    o.append(lib.box((-2.17, DECK + 0.42, 0), (0.84, 0.84, 2.1), "House", bevel=0.02))
    o.append(lib.box((-2.2, DECK + 1.06, 0), (0.72, 0.44, 2.5), "House", bevel=0.02))
    # sloped window band
    v = [(-1.84, DECK + 0.86, 1.2), (-1.84, DECK + 0.86, -1.2), (-1.78, DECK + 1.24, -1.2), (-1.78, DECK + 1.24, 1.2)]
    o.append(lib.mesh_from(v, [[0, 1, 2, 3]], "Glass", "slope", outward=lambda c: (1.0, 0.3, 0.0)))
    o.append(lib.box((-2.2, DECK + 1.3, 0), (0.8, 0.06, 2.58), "Roof"))
    o.append(lib.box((-1.745, DECK + 0.5, 0), (0.02, 0.12, 1.7), "Glass"))
    # tall square funnel offset to one side
    o.append(lib.box((-2.45, DECK + 1.62, -0.55), (0.3, 0.7, 0.3), "Funnel", bevel=0.03))
    o.append(lib.box((-2.45, DECK + 2.0, -0.55), (0.32, 0.08, 0.32), "FunnelTop"))
    o.append(lib.box((-2.45, DECK + 1.6, -0.55), (0.31, 0.1, 0.31), "HullWhite"))
    # radar mast frame
    o.append(lib.box((-2.25, DECK + 1.6, 0.35), (0.04, 0.6, 0.04), "Metal"))
    o.append(lib.box((-2.25, DECK + 1.6, -0.1), (0.04, 0.6, 0.04), "Metal"))
    o.append(lib.box((-2.25, DECK + 1.92, 0.12), (0.06, 0.05, 0.6), "Metal"))
    o.append(lib.box((-2.25, DECK + 2.0, 0.12), (0.04, 0.03, 0.5), "Dark"))
    # stern ramp (raised)
    o.append(lib.box((-2.66, DECK - 0.1, 0), (0.07, 0.75, 1.5), "Metal", bevel=0.01))
    for z in (0.7, -0.7):
        o.append(lib.box((-2.6, DECK + 0.32, z), (0.1, 0.1, 0.1), "Dark"))
    return o, (-2.45, DECK + 2.04, -0.55)


HOUSE_LIFT = 1.35

# sRGB colours for the untinted materials (kept in sync with scripts/model_mats.gd)
FIXED = {
    "HullWhite": (246, 246, 242), "BootTop": (255, 255, 255), "Bottom": (196, 71, 63),
    "Hatch": (167, 183, 194), "House": (251, 251, 247), "Glass": (47, 111, 153),
    "Roof": (201, 209, 216), "FunnelTop": (43, 47, 54), "Metal": (195, 204, 212),
    "Orange": (255, 122, 26), "Dark": (58, 63, 71),
}


def lift_house(objs):
    """Stretch the superstructure upward so it reads from the game's high camera."""
    for ob in objs:
        for v in ob.data.vertices:
            # Blender Z == Godot Y
            if v.co.z > DECK:
                v.co.z = DECK + (v.co.z - DECK) * HOUSE_LIFT


def build(name, style, house_fn):
    lib.reset()
    objs, hw = hull(style)
    objs += deck_details(hw, style)
    house, funnel_top = house_fn()
    lift_house(house)
    funnel_top = (funnel_top[0], DECK + (funnel_top[1] - DECK) * HOUSE_LIFT, funnel_top[2])
    objs += house
    ob = lib.join(objs, name)
    lib.auto_smooth(ob, 40)
    lib.bake_ao(ob, ground=False, distance=0.6, samples=20, max_len=0.55)
    # lighten AO a touch so colours stay bright on phones
    attr = ob.data.color_attributes["AO"]
    for d in attr.data:
        c = d.color
        d.color = (0.25 + 0.75 * c[0], 0.25 + 0.75 * c[1], 0.25 + 0.75 * c[2], 1.0)
    lib.collapse_fixed_materials(ob, {"Hull", "Funnel", "Deck"}, FIXED)
    lib.export(ob, OUT + name + ".glb")
    print(f"FUNNEL {name} {funnel_top}")


build("ship_feeder", "raked", house_feeder)
build("ship_tanker", "tanker", house_tanker)
build("ship_coaster", "straight", house_coaster)
