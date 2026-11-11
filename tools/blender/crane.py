"""Ship-to-shore gantry crane (decor at both ends of the quay).

Run: blender -b --python tools/blender/crane.py
Footprint matches the old procedural crane: legs at x = +-1.3, z = -2.75 (sea side)
and z = 0.05 (land side); boom along z from -8.5 (over water) to 3.4.
"""
import sys

sys.path.insert(0, __file__.rsplit("/", 1)[0])
import lib  # noqa: E402

OUT = __file__.rsplit("/tools/", 1)[0] + "/assets/models/"
H = 6.6
ZS, ZL = -2.75, 0.05
HX = 1.3
Z_FAR, Z_BACK = -8.5, 3.4
BOOM_LO, BOOM_HI = H + 0.05, H + 0.6


def truss(objs, x, z0, z1, y_lo, y_hi, step, mat_chord, mat_web, t=0.09):
    """Planar truss girder along z at a given x."""
    objs.append(lib.beam((x, y_lo, z0), (x, y_lo, z1), t * 1.4, mat_chord))
    objs.append(lib.beam((x, y_hi, z0), (x, y_hi, z1), t * 1.2, mat_chord))
    z = z0
    up = True
    while z < z1 - 1e-3:
        zn = min(z1, z + step)
        objs.append(lib.beam((x, y_lo, z), (x, y_lo + (y_hi - y_lo), z), t * 0.7, mat_web))
        if up:
            objs.append(lib.beam((x, y_lo, z), (x, y_hi, zn), t * 0.6, mat_web))
        else:
            objs.append(lib.beam((x, y_hi, z), (x, y_lo, zn), t * 0.6, mat_web))
        up = not up
        z = zn
    objs.append(lib.beam((x, y_lo, z1), (x, y_hi, z1), t * 0.7, mat_web))


def build(gold=False):
    lib.reset()
    o = []
    # legs with hazard stripes near the ground
    for x in (-HX, HX):
        for z in (ZS, ZL):
            o.append(lib.box((x, H * 0.5 + 0.35, z), (0.28, H - 0.7, 0.28), "Blue", bevel=0.02))
            for k in range(4):
                o.append(lib.box((x, 0.42 + k * 0.14, z), (0.3, 0.14, 0.3), "Yellow" if k % 2 == 0 else "Black"))
            # wheel bogie
            o.append(lib.box((x, 0.18, z), (0.42, 0.22, 0.78), "Dark", bevel=0.02))
            for dz in (-0.25, 0.0, 0.25):
                o.append(lib.cylinder((x, 0.12, z + dz), 0.1, 0.46, "Black", segs=10, axis="x"))
        # sill beam joining the bogies, and portal girders
        o.append(lib.box((x, 0.36, (ZS + ZL) * 0.5), (0.26, 0.2, ZL - ZS), "Blue"))
        o.append(lib.box((x, 2.5, (ZS + ZL) * 0.5), (0.2, 0.3, ZL - ZS), "Blue", bevel=0.01))
        o.append(lib.beam((x, 2.65, ZS), (x, H - 0.3, ZL), 0.12, "Blue"))
        o.append(lib.box((x, H - 0.15, (ZS + ZL) * 0.5), (0.26, 0.32, ZL - ZS + 0.3), "Blue", bevel=0.01))
    for z in (ZS, ZL):
        o.append(lib.box((0, H - 0.15, z), (2 * HX + 0.3, 0.32, 0.3), "Blue", bevel=0.01))
        o.append(lib.box((0, 2.5, z), (2 * HX, 0.24, 0.22), "Blue"))
    # boom: two lattice girders plus cross ties and a walkway
    for x in (-0.6, 0.6):
        truss(o, x, Z_FAR, Z_BACK, BOOM_LO, BOOM_HI, 0.85, "Light", "Light")
    z = Z_FAR
    while z <= Z_BACK + 1e-3:
        o.append(lib.beam((-0.6, BOOM_LO, z), (0.6, BOOM_LO, z), 0.06, "Light"))
        o.append(lib.beam((-0.6, BOOM_HI, z), (0.6, BOOM_HI, z), 0.05, "Light"))
        z += 1.7
    o.append(lib.box((0.75, BOOM_LO - 0.04, (Z_FAR + Z_BACK) * 0.5), (0.28, 0.03, Z_BACK - Z_FAR), "Metal"))
    # boom tip lights
    o.append(lib.box((0, BOOM_HI + 0.1, Z_FAR + 0.1), (0.5, 0.12, 0.12), "Red"))
    # A-frame and stays
    apex = (0.0, H + 3.4, (ZS + ZL) * 0.5 - 0.2)
    for x in (-HX, HX):
        o.append(lib.beam((x, H, ZS), (x * 0.25, apex[1], apex[2]), 0.16, "Blue"))
        o.append(lib.beam((x, H, ZL), (x * 0.25, apex[1], apex[2]), 0.16, "Blue"))
    o.append(lib.box((0, apex[1], apex[2]), (0.9, 0.22, 0.32), "Blue", bevel=0.02))
    for x in (-0.55, 0.55):
        o.append(lib.beam((x * 0.4, apex[1], apex[2]), (x, BOOM_HI, Z_FAR + 1.2), 0.05, "Light"))
        o.append(lib.beam((x * 0.4, apex[1], apex[2]), (x, BOOM_HI, Z_FAR + 3.8), 0.045, "Light"))
        o.append(lib.beam((x * 0.4, apex[1], apex[2]), (x, BOOM_HI, Z_BACK - 0.2), 0.05, "Light"))
    # machinery house over the back of the boom
    o.append(lib.box((0, BOOM_HI + 0.45, 1.75), (1.7, 0.85, 2.2), "Yellow", bevel=0.03))
    o.append(lib.box((0, BOOM_HI + 0.9, 1.75), (1.82, 0.08, 2.32), "White"))
    for z in (1.1, 1.75, 2.4):
        o.append(lib.box((0.86, BOOM_HI + 0.45, z), (0.02, 0.25, 0.4), "Dark"))
    o.append(lib.box((0, BOOM_HI + 1.02, 2.2), (0.5, 0.2, 0.5), "Metal"))
    # trolley, operator cab and spreader parked over the quay
    tz = -3.6
    o.append(lib.box((0, BOOM_LO - 0.15, tz), (1.3, 0.3, 0.9), "Yellow", bevel=0.02))
    o.append(lib.box((0.45, BOOM_LO - 0.6, tz + 0.2), (0.55, 0.55, 0.6), "White", bevel=0.03))
    o.append(lib.box((0.45, BOOM_LO - 0.6, tz - 0.105), (0.5, 0.32, 0.02), "Glass"))
    o.append(lib.box((0.45, BOOM_LO - 0.885, tz + 0.15), (0.45, 0.02, 0.45), "Glass"))
    for dx in (-0.3, 0.3):
        for dz in (-0.5, 0.5):
            o.append(lib.beam((dx, BOOM_LO - 0.3, tz + dz * 0.6), (dx * 1.2, 3.75, tz + dz * 1.2), 0.025, "Dark"))
    o.append(lib.box((0, 3.65, tz), (1.0, 0.16, 1.95), "Yellow", bevel=0.02))
    o.append(lib.box((0, 3.65, tz), (0.36, 0.26, 1.95), "Yellow"))
    # access stairs zig-zagging up the land-side leg
    y = 0.6
    side = 1
    while y < H - 1.0:
        o.append(lib.beam((HX + 0.25, y, ZL - 0.5 * side), (HX + 0.25, y + 0.9, ZL + 0.5 * side), 0.06, "Metal"))
        o.append(lib.box((HX + 0.25, y + 0.9, ZL + 0.5 * side), (0.3, 0.04, 0.3), "Metal"))
        side = -side
        y += 0.9
    # lamps
    for z in (ZS, ZL):
        o.append(lib.box((0, H + 0.12, z), (0.18, 0.1, 0.18), "Lamp"))
    ob = lib.join(o, "crane")
    lib.auto_smooth(ob, 40)
    lib.bake_ao(ob, ground=True, distance=0.8, samples=20, max_len=1.6)
    attr = ob.data.color_attributes["AO"]
    for d in attr.data:
        c = d.color
        d.color = (0.3 + 0.7 * c[0], 0.3 + 0.7 * c[1], 0.3 + 0.7 * c[2], 1.0)
    lib.collapse_fixed_materials(ob, set(), {
        "Blue": (240, 184, 40) if gold else (90, 169, 230), "Yellow": (239, 75, 92) if gold else (255, 197, 61), "Black": (42, 45, 51), "Dark": (58, 63, 71),
        "Light": (238, 243, 247), "Metal": (195, 204, 212), "Red": (239, 75, 92), "White": (255, 255, 255),
        "Glass": (47, 111, 153), "Lamp": (255, 243, 196)})
    lib.export(ob, OUT + ("crane_gold.glb" if gold else "crane.glb"))


build()
build(gold=True)
