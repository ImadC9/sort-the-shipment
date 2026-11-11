"""Quay props: yard light mast and terminal tractor with a skeletal trailer.

Run: blender -b --python tools/blender/props.py
"""
import math
import sys

sys.path.insert(0, __file__.rsplit("/", 1)[0])
import lib  # noqa: E402

OUT = __file__.rsplit("/tools/", 1)[0] + "/assets/models/"


def finish(objs, name, distance=0.5, lift=0.3):
    ob = lib.join(objs, name)
    lib.auto_smooth(ob, 40)
    lib.bake_ao(ob, ground=True, distance=distance, samples=20, max_len=0.5)
    attr = ob.data.color_attributes["AO"]
    for d in attr.data:
        c = d.color
        d.color = (lift + (1 - lift) * c[0], lift + (1 - lift) * c[1], lift + (1 - lift) * c[2], 1.0)
    lib.collapse_fixed_materials(ob, set(), {
        "Concrete": (217, 210, 196), "Metal": (195, 204, 212), "Dark": (58, 63, 71), "Lamp": (255, 243, 196),
        "Yellow": (255, 197, 61), "Glass": (47, 111, 153), "White": (255, 255, 255), "Orange": (255, 122, 26),
        "Black": (42, 45, 51), "Red": (239, 75, 92)})
    lib.export(ob, OUT + name + ".glb")


def light_mast():
    lib.reset()
    o = []
    o.append(lib.cylinder((0, 0.15, 0), 0.32, 0.3, "Concrete", segs=12))
    o.append(lib.cylinder((0, 4.2, 0), 0.07, 8.0, "Metal", segs=10, radius_top=0.05))
    # lamp head ring with floodlights pointing at the yard
    o.append(lib.box((0, 8.25, 0), (1.3, 0.08, 0.5), "Metal"))
    for x in (-0.45, -0.15, 0.15, 0.45):
        o.append(lib.box((x, 8.15, -0.18), (0.24, 0.16, 0.12), "Dark", bevel=0.01))
        o.append(lib.box((x, 8.13, -0.245), (0.2, 0.12, 0.01), "Lamp"))
    # service ladder
    o.append(lib.beam((0.12, 0.3, 0.0), (0.1, 7.9, 0.0), 0.02, "Metal"))
    finish(o, "light_mast", distance=0.6)


def tractor():
    lib.reset()
    o = []
    # terminal tractor (short cab-over truck), facing -z
    o.append(lib.box((0, 0.42, -1.55), (0.9, 0.36, 1.1), "Yellow", bevel=0.03))
    o.append(lib.box((-0.12, 0.9, -1.75), (0.62, 0.6, 0.62), "Yellow", bevel=0.04, segments=2))
    o.append(lib.box((-0.12, 0.98, -2.065), (0.54, 0.34, 0.02), "Glass"))
    o.append(lib.box((0.195, 0.98, -1.75), (0.02, 0.3, 0.5), "Glass"))
    o.append(lib.box((-0.43, 0.98, -1.75), (0.02, 0.3, 0.5), "Glass"))
    o.append(lib.box((-0.12, 1.22, -1.75), (0.64, 0.05, 0.64), "White"))
    o.append(lib.cylinder((-0.12, 1.3, -1.75), 0.06, 0.06, "Orange", segs=8))
    o.append(lib.cylinder((0.3, 1.0, -1.35), 0.04, 0.7, "Dark", segs=8))
    o.append(lib.box((0, 0.6, -1.0), (0.7, 0.06, 0.5), "Dark"))
    for z in (-1.85, -1.15):
        for x in (-0.42, 0.42):
            o.append(lib.cylinder((x, 0.2, z), 0.2, 0.18, "Black", segs=14, axis="x"))
            o.append(lib.cylinder((x * 1.05, 0.2, z), 0.1, 0.19, "Metal", segs=10, axis="x"))
    # skeletal trailer
    o.append(lib.box((0, 0.55, 0.45), (0.12, 0.1, 2.3), "Dark"))
    for x in (-0.42, 0.42):
        o.append(lib.box((x, 0.6, 0.45), (0.08, 0.08, 2.3), "Dark"))
    for z in (-0.6, 0.45, 1.5):
        o.append(lib.box((0, 0.6, z), (0.95, 0.07, 0.1), "Dark"))
    for z in (1.15, 1.5):
        for x in (-0.42, 0.42):
            o.append(lib.cylinder((x, 0.2, z), 0.2, 0.18, "Black", segs=14, axis="x"))
    o.append(lib.box((0, 0.55, 1.62), (1.0, 0.1, 0.04), "Red"))
    finish(o, "tractor", distance=0.4)


light_mast()
tractor()
