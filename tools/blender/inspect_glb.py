"""Quick GLB sanity check: primitives, triangle counts, vertex-colour (AO) range."""
import json
import struct
import sys

import numpy as np

COMP = {5120: np.int8, 5121: np.uint8, 5122: np.int16, 5123: np.uint16, 5125: np.uint32, 5126: np.float32}
NCOMP = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}


def read(path):
    data = open(path, "rb").read()
    jlen = struct.unpack("<I", data[12:16])[0]
    js = json.loads(data[20:20 + jlen])
    bin_off = 20 + jlen + 8
    return js, data[bin_off:]


def accessor(js, binb, idx):
    a = js["accessors"][idx]
    bv = js["bufferViews"][a["bufferView"]]
    dt = COMP[a["componentType"]]
    n = NCOMP[a["type"]]
    off = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
    arr = np.frombuffer(binb, dtype=dt, count=a["count"] * n, offset=off).reshape(a["count"], n)
    if a.get("normalized"):
        arr = arr.astype(np.float32) / np.iinfo(dt).max
    return arr


for path in sys.argv[1:]:
    js, binb = read(path)
    total = 0
    for m in js["meshes"]:
        for p in m["primitives"]:
            mat = js["materials"][p["material"]]["name"] if "material" in p else "-"
            tris = js["accessors"][p["indices"]]["count"] // 3
            total += tris
            col = ""
            if "COLOR_0" in p["attributes"]:
                c = accessor(js, binb, p["attributes"]["COLOR_0"])
                col = f"AO min={c[:, :3].min():.2f} mean={c[:, :3].mean():.2f} max={c[:, :3].max():.2f}"
            print(f"  {mat:12s} tris={tris:5d} {col}")
    pos = []
    for m in js["meshes"]:
        for p in m["primitives"]:
            pos.append(accessor(js, binb, p["attributes"]["POSITION"]))
    allp = np.concatenate(pos)
    print(f"{path.split('/')[-1]}: {total} tris, bounds min={allp.min(0).round(2)} max={allp.max(0).round(2)}")
