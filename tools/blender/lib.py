"""Shared helpers for building the game's 3D models in Blender from Python.

Conventions
- Geometry is authored in Blender axes (Z up). The glTF exporter converts to
  Godot axes: Godot X = Blender X, Godot Y = Blender Z, Godot Z = -Blender Y.
  Helpers here take *Godot* coordinates (x, y, z) and convert, so numbers match
  the gameplay code (Meshes.CW, SHIP_DECK, slot positions...).
- Every model is joined into one object. Materials are named; the game replaces
  them at load time (so hull colours can be tinted per ship).
- Ambient occlusion is baked into the vertex colour attribute "AO" (linear).
"""
import math
import bmesh
import bpy
from mathutils import Vector, Matrix


def g2b(x, y, z):
    """Godot coordinates -> Blender coordinates."""
    return Vector((x, -z, y))


_mats = {}


def reset():
    _mats.clear()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 24
    scene.cycles.use_denoising = False
    if scene.world is None:
        scene.world = bpy.data.worlds.new("World")


def mat(name):
    if name not in _mats or _mats[name].name not in bpy.data.materials:
        m = bpy.data.materials.new(name)
        _mats[name] = m
    return _mats[name]


def _obj_from_bm(bm, name, material):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(ob)
    me.materials.append(mat(material))
    return ob


def box(center, size, material, bevel=0.0, segments=1, name="box", rot_y=0.0):
    """Axis-aligned box in Godot coordinates (optionally rotated about Godot Y)."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    sx, sy, sz = size
    for v in bm.verts:
        v.co = Vector((v.co.x * sx, v.co.y * sz, v.co.z * sy))
    if rot_y:
        bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(rot_y, 3, "Z"))
    bmesh.ops.translate(bm, verts=bm.verts, vec=g2b(*center))
    if bevel > 0:
        bmesh.ops.bevel(bm, geom=bm.edges[:], offset=bevel, segments=segments, profile=0.5, affect="EDGES", clamp_overlap=True)
    return _obj_from_bm(bm, name, material)


def cylinder(center, radius, height, material, segs=12, axis="y", radius_top=None, name="cyl"):
    """Cylinder along a Godot axis ('x', 'y' or 'z'), centred at center."""
    bm = bmesh.new()
    rt = radius if radius_top is None else radius_top
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=segs, radius1=radius, radius2=rt, depth=height)
    if axis == "x":
        bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(math.pi / 2, 3, "Y"))
    elif axis == "z":
        bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(math.pi / 2, 3, "X"))
    bmesh.ops.translate(bm, verts=bm.verts, vec=g2b(*center))
    return _obj_from_bm(bm, name, material)


def beam(a, b, thickness, material, name="beam"):
    """Square beam between two Godot-space points."""
    pa, pb = g2b(*a), g2b(*b)
    d = pb - pa
    length = d.length
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * thickness, v.co.y * thickness, v.co.z * length))
    rot = Vector((0, 0, 1)).rotation_difference(d.normalized()).to_matrix()
    bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=rot)
    bmesh.ops.translate(bm, verts=bm.verts, vec=(pa + pb) * 0.5)
    return _obj_from_bm(bm, name, material)


def mesh_from(verts_g, faces, material, name="mesh", outward=None):
    """Arbitrary mesh from Godot-space vertices and face index lists.

    outward: optional function(face_centre_godot) -> desired normal (Godot space);
    each face is flipped if it points the other way.
    """
    bm = bmesh.new()
    vs = [bm.verts.new(g2b(*v)) for v in verts_g]
    for f in faces:
        idx = list(f)
        if len(set(tuple(round(c, 5) for c in verts_g[i]) for i in idx)) < 3:
            continue  # degenerate (collapsed at the bow tip)
        if outward is not None:
            pts = [Vector(verts_g[i]) for i in idx]
            centre = sum(pts, Vector((0, 0, 0))) / len(pts)
            n = Vector((0, 0, 0))
            for k in range(len(pts)):
                a, b = pts[k], pts[(k + 1) % len(pts)]
                n += Vector(((a.y - b.y) * (a.z + b.z), (a.z - b.z) * (a.x + b.x), (a.x - b.x) * (a.y + b.y)))
            want = Vector(outward(tuple(centre)))
            if n.dot(want) < 0:
                idx.reverse()
        try:
            bm.faces.new([vs[i] for i in idx])
        except ValueError:
            pass
    bm.normal_update()
    return _obj_from_bm(bm, name, material)


def join(objs, name):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
    ob.name = name
    # merge coincident verts per material island, recalc normals outward
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.remove_doubles(threshold=0.0005)
    bpy.ops.object.mode_set(mode="OBJECT")
    return ob


def auto_smooth(ob, angle_deg=35):
    """Flat-shaded hard edges with smooth curves (Blender 4.0 API)."""
    for p in ob.data.polygons:
        p.use_smooth = True
    try:
        bpy.context.view_layer.objects.active = ob
        bpy.ops.object.shade_smooth_by_angle(angle=math.radians(angle_deg))
    except Exception:
        try:
            ob.data.use_auto_smooth = True
            ob.data.auto_smooth_angle = math.radians(angle_deg)
        except Exception:
            pass
    # Blender 4.0: add "Smooth by Angle" equivalent via edge sharpness
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    for e in bm.edges:
        if len(e.link_faces) == 2:
            a = e.link_faces[0].normal.angle(e.link_faces[1].normal, 0)
            e.smooth = a < math.radians(angle_deg)
    bm.to_mesh(ob.data)
    bm.free()


def densify(ob, max_len=0.35, passes=3):
    """Split long edges so baked vertex AO has enough samples across big faces."""
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    for _ in range(passes):
        long_edges = [e for e in bm.edges if e.calc_length() > max_len]
        if not long_edges:
            break
        bmesh.ops.subdivide_edges(bm, edges=long_edges, cuts=1, use_grid_fill=True)
    bmesh.ops.triangulate(bm, faces=[f for f in bm.faces if len(f.verts) > 4])
    bm.to_mesh(ob.data)
    bm.free()


def bake_ao(ob, ground=True, distance=1.0, samples=24, max_len=0.35):
    """Bake ambient occlusion into a vertex colour attribute called AO."""
    if max_len:
        densify(ob, max_len)
    scene = bpy.context.scene
    scene.cycles.samples = samples
    floor = None
    if ground:
        bpy.ops.mesh.primitive_plane_add(size=60, location=(0, 0, -0.01))
        floor = bpy.context.active_object
    me = ob.data
    for a in list(me.color_attributes):
        me.color_attributes.remove(a)
    attr = me.color_attributes.new("AO", "FLOAT_COLOR", "CORNER")
    me.color_attributes.active_color = attr
    me.attributes.active_color = attr
    world = scene.world
    world.use_nodes = True
    world.light_settings.distance = distance
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    scene.render.bake.target = "VERTEX_COLORS"
    scene.render.bake.margin = 0
    bpy.ops.object.bake(type="AO", target="VERTEX_COLORS")
    if floor:
        bpy.data.objects.remove(floor, do_unlink=True)


def tint_faces(ob, predicate, factor):
    """Multiply the AO colour of faces matching predicate(center_godot, material_name)."""
    me = ob.data
    attr = me.color_attributes.get("AO")
    if attr is None:
        return
    for poly in me.polygons:
        c = poly.center
        cg = (c.x, c.z, -c.y)
        mname = me.materials[poly.material_index].name if me.materials else ""
        if predicate(cg, mname):
            for li in poly.loop_indices:
                col = attr.data[li].color
                attr.data[li].color = (col[0] * factor, col[1] * factor, col[2] * factor, col[3])


def export(ob, path):
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    common = dict(filepath=path, export_format="GLB", use_selection=True, export_apply=True,
                  export_normals=True, export_texcoords=False, export_materials="EXPORT", export_yup=True)
    try:   # Blender 4.2+
        bpy.ops.export_scene.gltf(export_vertex_color="ACTIVE", export_all_vertex_colors=False, **common)
    except TypeError:   # Blender 4.0/4.1
        bpy.ops.export_scene.gltf(export_colors=True, **common)
    tris = sum(len(p.vertices) - 2 for p in ob.data.polygons)
    print(f"EXPORTED {path} tris={tris} materials={[m.name for m in ob.data.materials]}")


def collapse_fixed_materials(ob, keep, palette, into="Fixed"):
    """Fold every material not in `keep` into one material, baking its base
    colour into the AO vertex colour (linear). keep: names the game tints."""
    me = ob.data
    attr = me.color_attributes.get("AO")

    def lin(c):
        out = []
        for x in c:
            v = x / 255.0
            out.append(((v + 0.055) / 1.055) ** 2.4 if v > 0.04045 else v / 12.92)
        return out

    names = [m.name for m in me.materials]
    new_names = [n for n in names if n in keep] + [into]
    # make sure the target material slots exist before reassigning faces
    for n in new_names:
        if n not in [m.name for m in me.materials]:
            me.materials.append(mat(n))
    slot = {m.name: i for i, m in enumerate(me.materials)}
    for poly in me.polygons:
        n = names[poly.material_index]
        if n in keep:
            poly.material_index = slot[n]
        else:
            rgb = lin(palette.get(n, (255, 0, 255)))
            for li in poly.loop_indices:
                c = attr.data[li].color
                attr.data[li].color = (c[0] * rgb[0], c[1] * rgb[1], c[2] * rgb[2], 1.0)
            poly.material_index = slot[into]
    # rebuild the slot list with only the kept materials; Blender's
    # materials.pop() also shifts face indices itself, so remap explicitly
    final = [n for n in new_names if any(p.material_index == slot[n] for p in me.polygons)]
    remap = {slot[n]: i for i, n in enumerate(final)}
    idx = [remap[p.material_index] for p in me.polygons]
    me.materials.clear()
    for n in final:
        me.materials.append(mat(n))
    for p, i in zip(me.polygons, idx):
        p.material_index = i
