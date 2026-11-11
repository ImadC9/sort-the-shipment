"""Toy Harbour model kit (2.0 art direction).

Small modelling DSL on top of Blender's bmesh. Everything is authored in
*Godot* coordinates (x right, y up, z towards the land; the camera looks along
+z) and converted on the way in, so numbers match the gameplay code.

Colour space: the game uses Godot's Compatibility renderer, which shades in
sRGB space and passes vertex colours through untouched. So vertex colours are
stored here as plain sRGB values (not linear, as glTF would normally expect).

Look: chunky toy shapes with rounded bevels, weighted normals, ambient
occlusion baked into vertex colours and flat paint colours folded into the
same vertex colours. Parts the game tints (Hull, Deck, ...) keep their own
material name; everything else lands in one material called "Fixed".

Run with Blender's Python module:  python3 tools/blender/build_all.py
"""
import math

import bpy  # must come first: it provides bmesh and mathutils
import bmesh
from mathutils import Matrix, Vector


def g2b(p):
    """Godot (x, y, z) -> Blender (x, -z, y)."""
    return Vector((p[0], -p[2], p[1]))


def hex_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


def srgb_to_lin(c):
    return tuple(((v + 0.055) / 1.055) ** 2.4 if v > 0.04045 else v / 12.92 for v in c)


class Model:
    """Collects primitives; each face remembers a paint name."""

    def __init__(self, name):
        self.name = name
        self.bm = bmesh.new()
        self.paint = self.bm.faces.layers.int.new("paint")
        self.paints = []          # index -> name

    # ------------------------------------------------------------ plumbing
    def _pid(self, paint):
        if paint not in self.paints:
            self.paints.append(paint)
        return self.paints.index(paint)

    def _absorb(self, tmp, paint, matrix=None):
        """Move a temporary bmesh into the model."""
        pid = self._pid(paint)
        vmap = {}
        for v in tmp.verts:
            co = v.co.copy()
            if matrix is not None:
                co = matrix @ co
            vmap[v] = self.bm.verts.new(co)
        for f in tmp.faces:
            try:
                nf = self.bm.faces.new([vmap[v] for v in f.verts])
            except ValueError:
                continue
            nf[self.paint] = pid
            nf.smooth = True
        tmp.free()

    @staticmethod
    def _bevel(tmp, r, seg):
        if r <= 0:
            return
        bmesh.ops.bevel(tmp, geom=list(tmp.edges), offset=r, segments=seg, profile=0.5,
                        affect="EDGES", clamp_overlap=True)

    # ---------------------------------------------------------- primitives
    def box(self, c, s, paint, bevel=0.03, seg=2, rot=None, taper=None):
        """Box at centre c (Godot) with size s (Godot x, y, z).
        taper=(tx, tz): scale of the top face relative to the bottom."""
        tmp = bmesh.new()
        bmesh.ops.create_cube(tmp, size=1.0)
        for v in tmp.verts:
            v.co.x *= s[0]
            v.co.y *= s[2]
            v.co.z *= s[1]
            if taper and v.co.z > 0:
                v.co.x *= taper[0]
                v.co.y *= taper[1]
        self._bevel(tmp, min(bevel, min(s) * 0.45), seg)
        m = Matrix.Translation(g2b(c))
        if rot is not None:
            # rot = (rx, ry, rz) in Godot axes (radians)
            rm = (Matrix.Rotation(rot[1], 4, "Z") @ Matrix.Rotation(-rot[2], 4, "Y") @ Matrix.Rotation(rot[0], 4, "X"))
            m = m @ rm
        self._absorb(tmp, paint, m)

    def cyl(self, c, r, h, paint, seg=16, r_top=None, axis="y", bevel=0.0, bseg=2, cap=True):
        """Cylinder/cone centred at c, height h along a Godot axis."""
        tmp = bmesh.new()
        bmesh.ops.create_cone(tmp, cap_ends=cap, cap_tris=False, segments=seg,
                              radius1=r, radius2=r if r_top is None else r_top, depth=h)
        if bevel > 0:
            ring = [e for e in tmp.edges if abs(e.verts[0].co.z - e.verts[1].co.z) < 1e-6]
            bmesh.ops.bevel(tmp, geom=ring, offset=bevel, segments=bseg, profile=0.5, affect="EDGES")
        m = Matrix.Translation(g2b(c))
        if axis == "x":
            m = m @ Matrix.Rotation(math.pi / 2, 4, "Y")
        elif axis == "z":
            m = m @ Matrix.Rotation(math.pi / 2, 4, "X")
        self._absorb(tmp, paint, m)

    def sphere(self, c, r, paint, seg=14, rings=8, scale=(1, 1, 1)):
        tmp = bmesh.new()
        bmesh.ops.create_uvsphere(tmp, u_segments=seg, v_segments=rings, radius=r)
        for v in tmp.verts:
            v.co.x *= scale[0]
            v.co.y *= scale[2]
            v.co.z *= scale[1]
        self._absorb(tmp, paint, Matrix.Translation(g2b(c)))

    def ico(self, c, r, paint, sub=2, scale=(1, 1, 1), flat_bottom=None):
        tmp = bmesh.new()
        bmesh.ops.create_icosphere(tmp, subdivisions=sub, radius=r)
        for v in tmp.verts:
            v.co.x *= scale[0]
            v.co.y *= scale[2]
            v.co.z *= scale[1]
            if flat_bottom is not None and v.co.z < flat_bottom:
                v.co.z = flat_bottom
        self._absorb(tmp, paint, Matrix.Translation(g2b(c)))

    def rings(self, levels, paints, cap_bottom=None, cap_top=None):
        """Loft through closed outlines. levels: list of lists of Godot points
        (same count each). paints: one paint per band between levels."""
        bm = self.bm
        rows = [[bm.verts.new(g2b(p)) for p in lv] for lv in levels]
        n = len(rows[0])
        for k in range(len(rows) - 1):
            pid = self._pid(paints[k])
            for i in range(n):
                j = (i + 1) % n
                try:
                    f = bm.faces.new([rows[k][i], rows[k][j], rows[k + 1][j], rows[k + 1][i]])
                except ValueError:
                    continue
                f[self.paint] = pid
                f.smooth = True
        for cap, row, flip in ((cap_bottom, rows[0], True), (cap_top, rows[-1], False)):
            if cap is None:
                continue
            vs = list(reversed(row)) if flip else row
            try:
                f = bm.faces.new(vs)
                f[self.paint] = self._pid(cap)
                f.smooth = True
            except ValueError:
                pass

    def poly(self, pts, paint):
        vs = [self.bm.verts.new(g2b(p)) for p in pts]
        f = self.bm.faces.new(vs)
        f[self.paint] = self._pid(paint)
        f.smooth = True

    def extrude_outline(self, outline_xz, y0, y1, paint, bevel=0.0, seg=2):
        """Vertical prism from a 2D outline (list of (x, z) in Godot)."""
        tmp = bmesh.new()
        bot = [tmp.verts.new(g2b((x, y0, z))) for x, z in outline_xz]
        top = [tmp.verts.new(g2b((x, y1, z))) for x, z in outline_xz]
        n = len(bot)
        for i in range(n):
            j = (i + 1) % n
            tmp.faces.new([bot[i], bot[j], top[j], top[i]])
        tmp.faces.new(top)
        tmp.faces.new(list(reversed(bot)))
        bmesh.ops.recalc_face_normals(tmp, faces=list(tmp.faces))
        if bevel > 0:
            hor = [e for e in tmp.edges if abs(e.verts[0].co.z - e.verts[1].co.z) < 1e-6]
            bmesh.ops.bevel(tmp, geom=hor, offset=bevel, segments=seg, profile=0.5, affect="EDGES")
        self._absorb(tmp, paint)

    def tube(self, path, r, paint, seg=8, r_end=None, caps=True):
        """Round tube along a list of Godot points (parallel-transport frames)."""
        pts = [g2b(p) for p in path]
        n = len(pts)
        tang = []
        for i in range(n):
            a = pts[max(0, i - 1)]
            b = pts[min(n - 1, i + 1)]
            tang.append((b - a).normalized())
        up = Vector((0, 0, 1)) if abs(tang[0].z) < 0.9 else Vector((1, 0, 0))
        nrm = tang[0].cross(up).normalized()
        rows = []
        for i in range(n):
            if i > 0:
                ax = tang[i - 1].cross(tang[i])
                if ax.length > 1e-6:
                    ang = tang[i - 1].angle(tang[i])
                    nrm = Matrix.Rotation(ang, 3, ax.normalized()) @ nrm
            bi = tang[i].cross(nrm).normalized()
            rr = r if r_end is None else r + (r_end - r) * i / max(1, n - 1)
            rows.append([self.bm.verts.new(pts[i] + (nrm * math.cos(a) + bi * math.sin(a)) * rr)
                         for a in [2 * math.pi * k / seg for k in range(seg)]])
        pid = self._pid(paint)
        for k in range(n - 1):
            for i in range(seg):
                j = (i + 1) % seg
                f = self.bm.faces.new([rows[k][i], rows[k][j], rows[k + 1][j], rows[k + 1][i]])
                f[self.paint] = pid
                f.smooth = True
        if caps:
            for row in (list(reversed(rows[0])), rows[-1]):
                f = self.bm.faces.new(row)
                f[self.paint] = pid
                f.smooth = True

    # ------------------------------------------------------------- finish
    def finish(self, palette, ao=True, ao_distance=1.2, densify=0.0, sharp_deg=42.0,
               ao_strength=1.0, ground=True, weld=True, shade=None, samples=32, mask=None):
        """Returns a Blender object with AO x paint in vertex colours."""
        bm = self.bm
        bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
        if weld:
            bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=0.0004)
        bmesh.ops.triangulate(bm, faces=[f for f in bm.faces if len(f.verts) > 4])
        if densify > 0:
            for _ in range(3):
                long_edges = [e for e in bm.edges if e.calc_length() > densify]
                if not long_edges:
                    break
                bmesh.ops.subdivide_edges(bm, edges=long_edges, cuts=1, use_grid_fill=True)
            bmesh.ops.triangulate(bm, faces=[f for f in bm.faces if len(f.verts) > 4])
        for e in bm.edges:
            if len(e.link_faces) == 2:
                a = e.link_faces[0].normal.angle(e.link_faces[1].normal, 0.0)
                e.smooth = a < math.radians(sharp_deg)
                # different paints never blend across an edge
                if e.link_faces[0][self.paint] != e.link_faces[1][self.paint] and a > math.radians(12):
                    e.smooth = False
        me = bpy.data.meshes.new(self.name)

        def resolve(pname):
            v = palette.get(pname, "#ff00ff")
            if isinstance(v, tuple):
                return v[0], (v[1], v[1], v[1])       # tinted slot, brightness
            return "Fixed", hex_rgb(v)

        names = list(self.paints)
        slot_names = []
        for n in names:
            sn = resolve(n)[0]
            if sn not in slot_names:
                slot_names.append(sn)
        slot_names.sort(key=lambda n: n == "Fixed")
        for n in slot_names:
            m = bpy.data.materials.get(n) or bpy.data.materials.new(n)
            me.materials.append(m)
        face_paint = []
        for f in bm.faces:
            n = names[f[self.paint]]
            face_paint.append(n)
            f.material_index = slot_names.index(resolve(n)[0])
        bm.to_mesh(me)
        bm.free()
        ob = bpy.data.objects.new(self.name, me)
        bpy.context.scene.collection.objects.link(ob)
        # weighted normals keep big flat faces flat next to rounded bevels
        bpy.context.view_layer.objects.active = ob
        ob.select_set(True)
        mod = ob.modifiers.new("wn", "WEIGHTED_NORMAL")
        mod.keep_sharp = True
        mod.weight = 60
        bpy.ops.object.modifier_apply(modifier="wn")
        attr = me.color_attributes.new("AO", "FLOAT_COLOR", "CORNER")
        me.color_attributes.active_color = attr
        if ao:
            _bake_ao(ob, ao_distance, ground, samples)
        else:
            for d in attr.data:
                d.color = (1, 1, 1, 1)
        # fold paint into vertex colour
        for poly, pname in zip(me.polygons, face_paint):
            rgb = resolve(pname)[1]
            c = poly.center
            cg = (c.x, c.z, -c.y)
            k = shade(cg, pname) if shade else 1.0
            for li in poly.loop_indices:
                col = attr.data[li].color
                a = (1.0 - (1.0 - max(0.0, col[0]) ** 0.6) * ao_strength) * k
                if mask:
                    mk = mask(pname)
                    attr.data[li].color = (a * rgb[0], mk[0], mk[1], 1.0)
                else:
                    attr.data[li].color = (a * rgb[0], a * rgb[1], a * rgb[2], 1.0)
        return ob


def _bake_ao(ob, distance, ground, samples):
    """Ambient occlusion per face corner, ray-cast against the model itself.
    Sample points sit a little inside each face, so corners buried in a
    neighbouring part do not turn the whole face black."""
    import random
    from mathutils.bvhtree import BVHTree
    me = ob.data
    verts = [v.co.copy() for v in me.vertices]
    polys = [list(p.vertices) for p in me.polygons]
    if ground:
        k = len(verts)
        verts += [Vector((-60, -60, -0.002)), Vector((60, -60, -0.002)), Vector((60, 60, -0.002)), Vector((-60, 60, -0.002))]
        polys.append([k, k + 1, k + 2, k + 3])
    tree = BVHTree.FromPolygons(verts, polys)
    rng = random.Random(7)
    dirs = []
    for i in range(samples):
        # cosine-weighted hemisphere, stratified
        u = (i + rng.random()) / samples
        v = rng.random()
        r = math.sqrt(u)
        th = 2 * math.pi * v
        dirs.append((r * math.cos(th), r * math.sin(th), math.sqrt(max(0.0, 1 - u))))
    attr = me.color_attributes["AO"]
    for poly in me.polygons:
        n = poly.normal
        t = n.cross(Vector((0, 0, 1)) if abs(n.z) < 0.9 else Vector((1, 0, 0))).normalized()
        b = n.cross(t)
        c = poly.center
        for li in poly.loop_indices:
            p = me.vertices[me.loops[li].vertex_index].co
            o = c.lerp(p, 0.82) + n * 0.004
            hit = 0.0
            for d in dirs:
                w = t * d[0] + b * d[1] + n * d[2]
                h = tree.ray_cast(o, w, distance)
                if h[0] is not None:
                    hit += 1.0 - (h[3] / distance) ** 2 * 0.6
            a = 1.0 - hit / samples
            attr.data[li].color = (a, a, a, 1.0)


def export(ob, path):
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    common = dict(filepath=path, export_format="GLB", use_selection=True, export_apply=True,
                  export_normals=True, export_texcoords=False, export_materials="EXPORT", export_yup=True)
    try:
        bpy.ops.export_scene.gltf(export_vertex_color="ACTIVE", export_all_vertex_colors=False, **common)
    except TypeError:
        bpy.ops.export_scene.gltf(export_colors=True, **common)
    tris = sum(len(p.vertices) - 2 for p in ob.data.polygons)
    print(f"EXPORTED {path.split('/')[-1]} tris={tris} materials={[m.name for m in ob.data.materials]}")
    bpy.data.objects.remove(ob, do_unlink=True)


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
