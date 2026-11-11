"""Shipping container (1.0 x 0.8 x 1.9, origin at the bottom centre, doors facing -z).

Run: blender -b --python tools/blender/container.py
All surfaces use one game shader (tinted per colour); the vertex colour carries
baked AO, with the steel frame and door hardware pre-darkened.
"""
import sys

sys.path.insert(0, __file__.rsplit("/", 1)[0])
import lib  # noqa: E402

OUT = __file__.rsplit("/tools/", 1)[0] + "/assets/models/"
W, H, L = 1.0, 0.8, 1.9
P = 0.07          # frame/post thickness
DEPTH = 0.022     # corrugation depth
INSET = 0.02      # wall panels sit just inside the frame


def corrugated_side(sign):
    """Side wall (x = sign * W/2) with vertical trapezoid corrugations along z."""
    x0 = sign * (W * 0.5 - INSET)
    z0, z1 = -L * 0.5 + P, L * 0.5 - P
    y0, y1 = P, H - P
    n = 11
    pitch = (z1 - z0) / n
    prof = []
    for i in range(n):
        zs = z0 + i * pitch
        prof += [(zs, 0.0), (zs + pitch * 0.18, DEPTH), (zs + pitch * 0.5, DEPTH), (zs + pitch * 0.68, 0.0)]
    prof.append((z1, 0.0))
    verts, faces = [], []
    for (z, d) in prof:
        verts.append((x0 + sign * d, y0, z))
        verts.append((x0 + sign * d, y1, z))
    for i in range(len(prof) - 1):
        a = 2 * i
        faces.append([a, a + 2, a + 3, a + 1])
    return lib.mesh_from(verts, faces, "Body", "side", outward=lambda c: (sign, 0.0, 0.0))


def corrugated_end():
    """Front end wall (+z) with horizontal-pitch corrugations along x."""
    z0 = L * 0.5 - INSET
    x0, x1 = -W * 0.5 + P, W * 0.5 - P
    y0, y1 = P, H - P
    n = 6
    pitch = (x1 - x0) / n
    prof = []
    for i in range(n):
        xs = x0 + i * pitch
        prof += [(xs, 0.0), (xs + pitch * 0.18, DEPTH), (xs + pitch * 0.5, DEPTH), (xs + pitch * 0.68, 0.0)]
    prof.append((x1, 0.0))
    verts, faces = [], []
    for (x, d) in prof:
        verts.append((x, y0, z0 + d))
        verts.append((x, y1, z0 + d))
    for i in range(len(prof) - 1):
        a = 2 * i
        faces.append([a, a + 2, a + 3, a + 1])
    return lib.mesh_from(verts, faces, "Body", "end", outward=lambda c: (0.0, 0.0, 1.0))


def single_material(ob):
    """Frame/door/hardware shading now lives in the vertex colours, so one material is enough."""
    me = ob.data
    body = lib.mat("Body")
    for p in me.polygons:
        p.material_index = 0
    me.materials.clear()
    me.materials.append(body)


def build_lod():
    """Low-detail container for buried boxes: frame and doors only, ~250 tris."""
    lib.reset()
    o = []
    o.append(lib.box((0, H * 0.5, 0), (W - 2 * INSET, H - 0.02, L - 2 * INSET), "Body"))
    # painted-on ribs (three raised strips per side keep the corrugated read)
    for sx in (-1, 1):
        for k in range(6):
            z = -L * 0.5 + 0.25 + k * (L - 0.5) / 5
            o.append(lib.box((sx * (W * 0.5 - INSET + 0.008), H * 0.5, z), (0.016, H - 2 * P, 0.08), "Body"))
    for sx in (-1, 1):
        for sz in (-1, 1):
            o.append(lib.box((sx * (W - P) * 0.5, H * 0.5, sz * (L - P) * 0.5), (P, H, P), "Frame"))
    for y in (P * 0.5, H - P * 0.5):
        for sx in (-1, 1):
            o.append(lib.box((sx * (W - P) * 0.5, y, 0), (P, P, L - 0.1), "Frame"))
    dz = -L * 0.5 + 0.035
    for sx in (-1, 1):
        o.append(lib.box((sx * 0.215, H * 0.5, dz), (0.42, H - 2 * P, 0.025), "Door"))
    for bx in (-0.33, -0.1, 0.1, 0.33):
        o.append(lib.box((bx, H * 0.5, dz - 0.03), (0.024, H - 0.12, 0.024), "Hardware"))
    ob = lib.join(o, "container_lod")
    lib.auto_smooth(ob, 30)
    lib.bake_ao(ob, ground=True, distance=0.22, samples=16, max_len=0)
    attr = ob.data.color_attributes["AO"]
    for d in attr.data:
        c = d.color
        d.color = (0.45 + 0.55 * c[0], 0.45 + 0.55 * c[1], 0.45 + 0.55 * c[2], 1.0)
    lib.tint_faces(ob, lambda c, m: m == "Frame", 0.74)
    lib.tint_faces(ob, lambda c, m: m == "Hardware", 0.5)
    lib.tint_faces(ob, lambda c, m: m == "Door", 0.93)
    single_material(ob)
    lib.export(ob, OUT + "container_lod.glb")


def build():
    lib.reset()
    o = [corrugated_side(1), corrugated_side(-1), corrugated_end()]
    # roof with shallow ribs, floor underside
    o.append(lib.box((0, H - 0.03, 0), (W - 2 * INSET, 0.03, L - 2 * INSET), "Body"))
    for k in range(9):
        z = -L * 0.5 + 0.2 + k * (L - 0.4) / 8
        o.append(lib.box((0, H - 0.012, z), (W - 0.16, 0.012, 0.05), "Body"))
    o.append(lib.box((0, 0.03, 0), (W - 2 * INSET, 0.04, L - 2 * INSET), "Frame"))
    # frame: corner posts, side rails, end headers and sills
    for sx in (-1, 1):
        for sz in (-1, 1):
            o.append(lib.box((sx * (W - P) * 0.5, H * 0.5, sz * (L - P) * 0.5), (P, H, P), "Frame", bevel=0.008))
            # corner castings
            for y in (0.045, H - 0.045):
                o.append(lib.box((sx * (W * 0.5 - 0.045), y, sz * (L * 0.5 - 0.045)), (0.1, 0.09, 0.1), "Casting", bevel=0.01))
    for y in (P * 0.5, H - P * 0.5):
        for sx in (-1, 1):
            o.append(lib.box((sx * (W - P) * 0.5, y, 0), (P, P, L - 0.1), "Frame"))
        for sz in (-1, 1):
            o.append(lib.box((0, y, sz * (L - P) * 0.5), (W - 0.1, P * (1.25 if sz < 0 else 1.0), P), "Frame"))
    # doors on the -z end: two leaves, recessed slightly, with locking bars
    dz = -L * 0.5 + 0.035
    for sx in (-1, 1):
        o.append(lib.box((sx * 0.215, H * 0.5, dz), (0.42, H - 2 * P, 0.025), "Door", bevel=0.004))
        # door panel ribs
        for y in (0.22, 0.4, 0.58):
            o.append(lib.box((sx * 0.215, y, dz - 0.016), (0.36, 0.035, 0.012), "Door"))
    for bx in (-0.33, -0.1, 0.1, 0.33):
        o.append(lib.cylinder((bx, H * 0.5, dz - 0.035), 0.012, H - 0.12, "Hardware", segs=6))
        for y in (0.14, H - 0.14):
            o.append(lib.box((bx, y, dz - 0.03), (0.05, 0.04, 0.03), "Hardware"))
        o.append(lib.box((bx + 0.035, H * 0.48, dz - 0.05), (0.07, 0.02, 0.02), "Hardware"))
    # hinges
    for sx in (-1, 1):
        for y in (0.15, 0.4, 0.65):
            o.append(lib.box((sx * 0.44, y, dz - 0.02), (0.05, 0.04, 0.03), "Hardware"))
    # fork pockets on the long sides
    for sx in (-1, 1):
        for z in (-0.45, 0.45):
            o.append(lib.box((sx * (W * 0.5 - 0.005), 0.05, z), (0.03, 0.05, 0.25), "Hardware"))
    ob = lib.join(o, "container")
    lib.auto_smooth(ob, 30)
    lib.bake_ao(ob, ground=True, distance=0.22, samples=24, max_len=0)
    attr = ob.data.color_attributes["AO"]
    for d in attr.data:
        c = d.color
        d.color = (0.45 + 0.55 * c[0], 0.45 + 0.55 * c[1], 0.45 + 0.55 * c[2], 1.0)
    # darker steel for frame, door hardware and castings (the game tints the whole box)
    lib.tint_faces(ob, lambda c, m: m == "Frame", 0.74)
    lib.tint_faces(ob, lambda c, m: m == "Casting", 0.6)
    lib.tint_faces(ob, lambda c, m: m == "Hardware", 0.5)
    lib.tint_faces(ob, lambda c, m: m == "Door", 0.93)
    single_material(ob)
    lib.export(ob, OUT + "container.glb")


build()
build_lod()
