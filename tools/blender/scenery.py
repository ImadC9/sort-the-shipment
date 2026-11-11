"""Port backdrop: warehouses, medina houses, trees, palms and street props.

Every model folds all its colours into the vertex colours (material "Fixed"),
so the game's static-scenery merge turns the whole backdrop into one or two
draw calls. Poly counts are kept small for phones.

Run: blender -b --python tools/blender/scenery.py
"""
import math
import random
import sys

sys.path.insert(0, __file__.rsplit("/", 1)[0])
import lib  # noqa: E402

OUT = __file__.rsplit("/tools/", 1)[0] + "/assets/models/"


def finish(objs, name, palette, distance=0.6, lift=0.35, max_len=0.6, samples=16, smooth=40):
    ob = lib.join(objs, name)
    lib.auto_smooth(ob, smooth)
    lib.bake_ao(ob, ground=True, distance=distance, samples=samples, max_len=max_len)
    attr = ob.data.color_attributes["AO"]
    for d in attr.data:
        c = d.color
        d.color = (lift + (1 - lift) * c[0], lift + (1 - lift) * c[1], lift + (1 - lift) * c[2], 1.0)
    lib.collapse_fixed_materials(ob, set(), palette)
    lib.export(ob, OUT + name + ".glb")


def panel(points, z, material, name="panel"):
    """Flat polygon on a wall facing -z (points are (x, y) pairs)."""
    verts = [(x, y, z) for x, y in points]
    return lib.mesh_from(verts, [list(range(len(verts)))], material, name, outward=lambda c: (0, 0, -1))


def arch(cx, y0, w, h, z, material, segs=8):
    """Arched opening: rectangle with a semicircular top."""
    r = w * 0.5
    pts = [(cx - r, y0), (cx + r, y0), (cx + r, y0 + h - r)]
    for k in range(1, segs):
        a = math.pi * k / segs
        pts.append((cx + r * math.cos(a), y0 + h - r + r * math.sin(a)))
    pts.append((cx - r, y0 + h - r))
    return panel(pts, z, material)


# ---------------------------------------------------------------- warehouse

WAREHOUSE_W = 7.2
WAREHOUSE_D = 5.0
WAREHOUSE_H = 3.2
ROOF_Y = 3.43


def warehouse(name, wall, accent, sign):
    lib.reset()
    o = []
    w, d, h = WAREHOUSE_W, WAREHOUSE_D, WAREHOUSE_H
    fz = -d * 0.5
    # body and concrete plinth
    o.append(lib.box((0, h * 0.5, 0), (w, h, d), "Wall"))
    o.append(lib.box((0, 0.18, 0), (w + 0.08, 0.36, d + 0.08), "Plinth"))
    # vertical cladding ribs on the front and sides
    x = -w * 0.5 + 0.12
    while x < w * 0.5 - 0.05:
        o.append(lib.box((x, h * 0.5 + 0.2, fz - 0.025), (0.05, h - 0.4, 0.05), "WallRib"))
        x += 0.24
    for sx in (-1, 1):
        z = -d * 0.5 + 0.2
        while z < d * 0.5:
            o.append(lib.box((sx * (w * 0.5 + 0.025), h * 0.5 + 0.2, z), (0.05, h - 0.4, 0.05), "WallRib"))
            z += 0.3
    # roof slab with a coloured parapet / fascia
    o.append(lib.box((0, h + 0.1, 0), (w + 0.2, 0.2, d + 0.2), "Fascia"))
    o.append(lib.box((0, ROOF_Y - 0.015, 0), (w, 0.03, d), "Roof"))
    for sx in (-1, 1):
        o.append(lib.box((sx * (w * 0.5 + 0.06), ROOF_Y + 0.07, 0), (0.12, 0.14, d + 0.24), "Fascia"))
    for sz in (-1, 1):
        o.append(lib.box((0, ROOF_Y + 0.07, sz * (d * 0.5 + 0.06)), (w + 0.24, 0.14, 0.12), "Fascia"))
    # standing seams across the roof
    x = -w * 0.5 + 0.3
    while x < w * 0.5:
        o.append(lib.box((x, ROOF_Y + 0.012, 0), (0.04, 0.025, d - 0.05), "RoofSeam"))
        x += 0.45
    # skylights and plant on the rear half (the front half stays clear for roof projects)
    for sx in (-2.4, 0.0, 2.4):
        o.append(lib.box((sx, ROOF_Y + 0.06, 1.5), (1.3, 0.1, 0.7), "SkyFrame"))
        o.append(lib.box((sx, ROOF_Y + 0.115, 1.5), (1.18, 0.02, 0.58), "Glass"))
    hv = (-2.9, 1.9) if name.endswith("a") else (2.9, 1.9)
    o.append(lib.box((hv[0], ROOF_Y + 0.28, hv[1] - 0.9), (0.9, 0.55, 0.7), "Plant", bevel=0.02))
    o.append(lib.cylinder((hv[0], ROOF_Y + 0.57, hv[1] - 0.9), 0.24, 0.04, "Dark", segs=12))
    o.append(lib.cylinder((-hv[0] * 0.5, ROOF_Y + 0.2, 2.1), 0.1, 0.4, "Metal", segs=8))
    o.append(lib.cylinder((-hv[0] * 0.5, ROOF_Y + 0.42, 2.1), 0.16, 0.06, "Metal", segs=8))
    # gutter and downpipes
    o.append(lib.box((0, h - 0.05, fz - 0.09), (w + 0.1, 0.1, 0.12), "Fascia"))
    for sx in (-1, 1):
        o.append(lib.cylinder((sx * (w * 0.5 - 0.12), h * 0.5, fz - 0.12), 0.045, h, "Fascia", segs=6))
    # two roller doors with slats, frames and hoods
    for dx in (-1.9, 1.3):
        dw, dh = 2.0, 2.3
        o.append(lib.box((dx, dh * 0.5 + 0.02, fz - 0.03), (dw + 0.24, dh + 0.14, 0.06), "Frame"))
        o.append(lib.box((dx, dh * 0.5, fz - 0.06), (dw, dh, 0.02), "Door"))
        y = 0.12
        while y < dh:
            o.append(lib.box((dx, y, fz - 0.075), (dw, 0.03, 0.015), "DoorSlat"))
            y += 0.16
        o.append(lib.box((dx, dh + 0.2, fz - 0.12), (dw + 0.3, 0.26, 0.22), "Frame", bevel=0.02))
        # rubber dock bumpers and a yellow kerb
        for bx in (-dw * 0.5 + 0.1, dw * 0.5 - 0.1):
            o.append(lib.box((dx + bx, 0.45, fz - 0.12), (0.14, 0.3, 0.14), "Dark"))
        o.append(lib.box((dx, 0.02, fz - 0.35), (dw + 0.2, 0.04, 0.12), "Kerb"))
        # wall lamp
        o.append(lib.box((dx, dh + 0.55, fz - 0.1), (0.28, 0.1, 0.16), "Dark"))
        o.append(lib.box((dx, dh + 0.5, fz - 0.12), (0.22, 0.02, 0.12), "Lamp"))
    # personnel door with a canopy
    o.append(lib.box((3.05, 1.0, fz - 0.03), (0.72, 1.98, 0.05), "Frame"))
    o.append(lib.box((3.05, 0.98, fz - 0.06), (0.6, 1.9, 0.02), "Accent"))
    o.append(lib.box((3.05, 2.12, fz - 0.25), (0.9, 0.05, 0.5), "Accent"))
    # high window band
    o.append(lib.box((0, 2.86, fz - 0.035), (w - 0.6, 0.34, 0.04), "Frame"))
    x = -w * 0.5 + 0.6
    while x < w * 0.5 - 0.6:
        o.append(lib.box((x, 2.86, fz - 0.06), (0.44, 0.26, 0.02), "Glass"))
        x += 0.52
    # company sign: colour board with white stripes (no text)
    o.append(lib.box((-0.3, 2.48, fz - 0.07), (2.6, 0.34, 0.05), sign))
    for k in range(3):
        o.append(lib.box((-1.2 + k * 0.5, 2.48, fz - 0.1), (0.3, 0.1, 0.02), "White"))
    palette = {
        "Wall": wall, "WallRib": tuple(int(c * 0.9) for c in wall), "Plinth": (176, 170, 160),
        "Fascia": accent, "Roof": (196, 204, 210), "RoofSeam": (168, 178, 186), "SkyFrame": (226, 230, 234),
        "Glass": (86, 150, 196), "Plant": (214, 220, 226), "Dark": (58, 63, 71), "Metal": (180, 188, 196),
        "Frame": (120, 132, 146), "Door": (198, 208, 216), "DoorSlat": (160, 172, 184), "Kerb": (255, 197, 61),
        "Lamp": (255, 243, 196), "Accent": accent, "White": (255, 255, 255),
        "SignBlue": (61, 143, 232), "SignGreen": (56, 193, 114),
    }
    finish(o, name, palette, distance=0.8, lift=0.45, max_len=1.6, samples=16)


# ---------------------------------------------------------------- medina houses

def house(name, w, d, h, wall, trim, rng, extras):
    lib.reset()
    o = []
    fz = -d * 0.5
    # body runs up through the parapet; the roof is a shallow recessed floor
    o.append(lib.box((0, (h + 0.24) * 0.5, 0), (w, h + 0.24, d), "Wall"))
    o.append(lib.box((0, h + 0.245, 0), (w - 0.2, 0.012, d - 0.2), "RoofFloor"))
    # painted base band (Chefchaouen blue on some houses)
    if "band" in extras:
        o.append(lib.box((0, 0.3, fz - 0.012), (w + 0.01, 0.6, 0.02), "Band"))
    # arched door and windows with shutters
    dx = rng.uniform(-w * 0.2, w * 0.2)
    o.append(arch(dx, 0.0, 0.5, 0.95, fz - 0.02, "Trim"))
    o.append(arch(dx, 0.04, 0.38, 0.85, fz - 0.03, "DoorWood"))
    rows = 2 if h > 1.9 else 1
    for r in range(rows):
        y = 1.25 + r * 0.8
        if y + 0.3 > h:
            break
        for wx in ((-w * 0.28, w * 0.28) if w > 1.8 else (w * 0.25,)):
            if abs(wx - dx) < 0.45 and r == 0 and y < 1.3:
                continue
            o.append(arch(wx, y, 0.3, 0.46, fz - 0.02, "Window"))
            o.append(lib.box((wx - 0.24, y + 0.2, fz - 0.03), (0.12, 0.42, 0.02), "Trim"))
            o.append(lib.box((wx + 0.24, y + 0.2, fz - 0.03), (0.12, 0.42, 0.02), "Trim"))
    if "balcony" in extras and h > 1.9:
        o.append(lib.box((0, 1.72, fz - 0.2), (0.9, 0.06, 0.4), "Wall"))
        o.append(lib.box((0, 1.86, fz - 0.39), (0.9, 0.22, 0.03), "Trim"))
    # rooftop life
    h = h + 0.25
    if "tank" in extras:
        tx, tz = w * 0.25, d * 0.18
        for lx in (-0.14, 0.14):
            o.append(lib.box((tx + lx, h + 0.15, tz), (0.04, 0.3, 0.3), "Metal"))
        o.append(lib.cylinder((tx, h + 0.42, tz), 0.2, 0.36, "Tank", segs=10, axis="x"))
    if "dish" in extras:
        o.append(lib.cylinder((-w * 0.3, h + 0.15, d * 0.25), 0.02, 0.3, "Metal", segs=6))
        o.append(lib.cylinder((-w * 0.3, h + 0.32, d * 0.2), 0.17, 0.04, "Dish", segs=12, axis="z", radius_top=0.12))
    if "stair" in extras:
        o.append(lib.box((-w * 0.25, h + 0.35, d * 0.2), (0.6, 0.7, 0.6), "Wall"))
        o.append(arch(-w * 0.25, h, 0.28, 0.5, d * 0.2 - 0.31, "DoorWood"))
    if "laundry" in extras:
        o.append(lib.beam((-w * 0.4, h + 0.45, 0.0), (w * 0.4, h + 0.45, 0.0), 0.015, "Metal"))
        cols = ["Cloth1", "Cloth2", "Cloth3"]
        for k in range(4):
            cx = -w * 0.3 + k * w * 0.2
            o.append(lib.box((cx, h + 0.32, 0.0), (0.16, 0.24, 0.015), cols[k % 3]))
    if "plants" in extras:
        for k in range(3):
            px = -w * 0.3 + k * w * 0.3
            o.append(lib.box((px, h + 0.08, -d * 0.3), (0.2, 0.16, 0.2), "Pot"))
            o.append(lib.box((px, h + 0.24, -d * 0.3), (0.26, 0.18, 0.26), "Leaf", bevel=0.05, segments=1))
    if "dome" in extras:
        bm_obj = lib.cylinder((w * 0.15, h + 0.3, 0.1), 0.45, 0.6, "Dome", segs=12, radius_top=0.05)
        o.append(bm_obj)
    palette = {
        "Wall": wall, "RoofFloor": tuple(int(c * 0.86) for c in wall), "Band": (127, 182, 236),
        "Trim": trim, "DoorWood": (139, 98, 64), "Window": (44, 70, 96), "Metal": (150, 158, 166),
        "Tank": (90, 110, 130), "Dish": (236, 238, 240), "Cloth1": (239, 75, 92), "Cloth2": (255, 197, 61),
        "Cloth3": (61, 143, 232), "Pot": (196, 112, 70), "Leaf": (72, 176, 92), "Dome": (46, 154, 90),
    }
    finish(o, name, palette, distance=0.5, lift=0.55, max_len=0.7, samples=14)


# ---------------------------------------------------------------- plants

def tree(name, kind):
    lib.reset()
    o = []
    if kind == "round":
        o.append(lib.cylinder((0, 0.45, 0), 0.07, 0.9, "Bark", segs=7, radius_top=0.05))
        for (x, y, z, r) in ((0, 1.25, 0, 0.55), (0.25, 1.05, 0.1, 0.38), (-0.22, 1.1, -0.12, 0.4), (0.05, 1.6, 0.05, 0.36)):
            o.append(blob((x, y, z), r, "Leaf"))
    else:  # cypress
        o.append(lib.cylinder((0, 0.15, 0), 0.06, 0.3, "Bark", segs=6))
        o.append(lib.cylinder((0, 1.05, 0), 0.32, 1.7, "LeafDark", segs=9, radius_top=0.06))
        o.append(blob((0, 0.42, 0), 0.3, "LeafDark"))
    finish(o, name, {"Bark": (139, 106, 69), "Leaf": (91, 191, 114), "LeafDark": (52, 140, 82)},
           distance=0.4, max_len=0.4, samples=14, smooth=60)


def blob(c, r, material):
    import bmesh
    from mathutils import Vector
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=1, radius=r)
    rnd = random.Random(int(c[0] * 100 + c[1] * 37))
    for v in bm.verts:
        v.co *= rnd.uniform(0.88, 1.1)
        v.co.z *= 0.85
    bmesh.ops.translate(bm, verts=bm.verts, vec=lib.g2b(*c))
    me = lib.bpy.data.meshes.new("blob")
    bm.to_mesh(me)
    bm.free()
    ob = lib.bpy.data.objects.new("blob", me)
    lib.bpy.context.collection.objects.link(ob)
    me.materials.append(lib.mat(material))
    return ob


def palm():
    """Curved trunk with rings and drooping, serrated fronds."""
    lib.reset()
    o = []
    height = 3.0
    segs = 9
    pts = []
    for k in range(segs + 1):
        t = k / segs
        pts.append((0.55 * t * t, height * t, 0.0))
    for k in range(segs):
        a, b = pts[k], pts[k + 1]
        r0 = 0.13 - 0.04 * k / segs
        o.append(lib.cylinder(((a[0] + b[0]) * 0.5, (a[1] + b[1]) * 0.5, 0), r0, height / segs * 1.02, "Bark" if k % 2 == 0 else "Bark2", segs=7, radius_top=r0 * 0.92))
    top = pts[-1]
    o.append(blob((top[0], top[1] + 0.02, 0), 0.16, "Coconut"))
    fronds = 9
    for f in range(fronds):
        yaw = f * math.tau / fronds + (0.2 if f % 2 else 0.0)
        length = 1.7 if f % 2 == 0 else 1.45
        o.append(frond(top, yaw, length, "Leaf" if f % 3 else "Leaf2"))
    finish(o, "palm", {"Bark": (156, 116, 72), "Bark2": (128, 92, 56), "Coconut": (110, 140, 60),
                       "Leaf": (63, 178, 92), "Leaf2": (48, 150, 76)}, distance=0.5, max_len=0.5, samples=14, smooth=70)


def frond(top, yaw, length, material):
    """A leaf as a drooping strip with zigzag leaflets along both edges."""
    n = 7
    verts = []
    faces = []
    dx, dz = math.cos(yaw), math.sin(yaw)
    px, pz = -dz, dx
    spine = []
    for k in range(n + 1):
        t = k / n
        out = length * t
        droop = 0.55 * t * t * length - 0.25 * t
        spine.append((top[0] + dx * out, top[1] - droop, top[2] + dz * out))
    for k, s in enumerate(spine):
        t = k / n
        width = 0.34 * math.sin(math.pi * min(1.0, t * 1.1)) + 0.02
        tooth = 0.08 if k % 2 else 0.0
        verts.append((s[0] + px * (width + tooth), s[1] - 0.05 * t, s[2] + pz * (width + tooth)))
        verts.append(s)
        verts.append((s[0] - px * (width + tooth), s[1] - 0.05 * t, s[2] - pz * (width + tooth)))
    for k in range(n):
        a = k * 3
        b = (k + 1) * 3
        faces.append([a, b, b + 1, a + 1])
        faces.append([a + 1, b + 1, b + 2, a + 2])
    # double-sided: add the back faces too
    back = [list(reversed(f)) for f in faces]
    return lib.mesh_from(verts, faces + back, material, "frond")


# ---------------------------------------------------------------- street props

def car(name, body):
    lib.reset()
    o = []
    o.append(lib.box((0, 0.3, 0), (0.78, 0.3, 1.7), "Body", bevel=0.06, segments=2))
    o.append(lib.box((0, 0.56, 0.08), (0.68, 0.26, 0.9), "Body", bevel=0.06, segments=2))
    o.append(lib.box((0, 0.57, -0.38), (0.6, 0.2, 0.02), "Glass"))
    o.append(lib.box((0, 0.57, 0.54), (0.6, 0.2, 0.02), "Glass"))
    for sx in (-1, 1):
        o.append(lib.box((sx * 0.345, 0.57, 0.08), (0.02, 0.18, 0.76), "Glass"))
        for z in (-0.55, 0.55):
            o.append(lib.cylinder((sx * 0.37, 0.15, z), 0.15, 0.12, "Tyre", segs=10, axis="x"))
    o.append(lib.box((0, 0.36, -0.86), (0.5, 0.06, 0.02), "Light"))
    finish(o, name, {"Body": body, "Glass": (60, 110, 150), "Tyre": (40, 42, 46), "Light": (255, 243, 196)},
           distance=0.35, max_len=0.35, samples=14)


def main():
    rng = random.Random(7)
    warehouse("warehouse_a", (246, 246, 242), (224, 122, 95), "SignBlue")
    warehouse("warehouse_b", (220, 236, 248), (61, 143, 232), "SignGreen")
    walls = [(255, 255, 255), (251, 246, 236), (246, 240, 228), (236, 244, 251)]
    trims = [(61, 143, 232), (46, 123, 214), (56, 193, 114), (224, 122, 95)]
    variants = [
        ("house_a", 2.2, 2.0, 1.6, ["tank", "laundry", "band"]),
        ("house_b", 2.6, 2.2, 2.4, ["dish", "stair", "balcony"]),
        ("house_c", 1.9, 1.9, 2.0, ["plants", "tank"]),
        ("house_d", 2.8, 2.4, 1.4, ["dome", "laundry", "band"]),
    ]
    for i, (n, w, d, h, ex) in enumerate(variants):
        house(n, w, d, h, walls[i], trims[i], rng, ex)
    tree("tree_round", "round")
    tree("cypress", "cypress")
    palm()
    car("car_red", (239, 75, 92))
    car("car_blue", (61, 143, 232))


main()
