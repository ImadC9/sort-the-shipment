class_name Meshes
extends RefCounted
## Shared meshes and materials. Models come from Blender (assets/models); a few
## flat helpers (slot frames, particles) are still built in code.

const CW := 1.0     # container width (x)
const CH := 0.8     # container height (y)
const CL := 1.9     # container length (z)

static var _cache := {}

# ---------------------------------------------------------------- helpers

static func add_box(st: SurfaceTool, center: Vector3, size: Vector3, col: Color) -> void:
	var h := size * 0.5
	var faces := [
		[Vector3(1, 0, 0), [Vector3(h.x, -h.y, h.z), Vector3(h.x, -h.y, -h.z), Vector3(h.x, h.y, -h.z), Vector3(h.x, h.y, h.z)]],
		[Vector3(-1, 0, 0), [Vector3(-h.x, -h.y, -h.z), Vector3(-h.x, -h.y, h.z), Vector3(-h.x, h.y, h.z), Vector3(-h.x, h.y, -h.z)]],
		[Vector3(0, 1, 0), [Vector3(-h.x, h.y, h.z), Vector3(h.x, h.y, h.z), Vector3(h.x, h.y, -h.z), Vector3(-h.x, h.y, -h.z)]],
		[Vector3(0, -1, 0), [Vector3(-h.x, -h.y, -h.z), Vector3(h.x, -h.y, -h.z), Vector3(h.x, -h.y, h.z), Vector3(-h.x, -h.y, h.z)]],
		[Vector3(0, 0, 1), [Vector3(-h.x, -h.y, h.z), Vector3(h.x, -h.y, h.z), Vector3(h.x, h.y, h.z), Vector3(-h.x, h.y, h.z)]],
		[Vector3(0, 0, -1), [Vector3(h.x, -h.y, -h.z), Vector3(-h.x, -h.y, -h.z), Vector3(-h.x, h.y, -h.z), Vector3(h.x, h.y, -h.z)]],
	]
	for f in faces:
		var n: Vector3 = f[0]
		var v: Array = f[1]
		for idx in [0, 2, 1, 0, 3, 2]:
			st.set_normal(n)
			st.set_color(col)
			st.add_vertex(center + v[idx])

static func _begin() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st

# ---------------------------------------------------------------- container

## 2.0: toy containers modelled in Blender (tools/blender/build_all.py): a
## rounded frame around a ribbed body, shading baked into vertex colours.
static func _model_mesh(name: String) -> Mesh:
	if not _cache.has(name):
		var scene: PackedScene = load("res://assets/models/%s.glb" % name)
		var root := scene.instantiate()
		var found: Mesh = null
		for c in root.find_children("*", "MeshInstance3D", true, false):
			found = (c as MeshInstance3D).mesh
			break
		root.free()
		_cache[name] = found
	return _cache[name]

static func container_mesh() -> Mesh:
	return _model_mesh("container")

## Buried boxes: same silhouette, no ribs.
static func container_lod_mesh() -> Mesh:
	return _model_mesh("container_lod")

## Covered cargo: a strapped canvas sheet.
static func tarp_mesh() -> Mesh:
	return _model_mesh("container_tarp")

const CARGO_SHADER := preload("res://shaders/cargo.gdshader")
const CARGO_SYMBOLS := preload("res://assets/textures/cargo_symbols.png")

static func _cargo_base(mat: ShaderMaterial) -> void:
	mat.shader = CARGO_SHADER
	mat.set_shader_parameter("symbol_tex", CARGO_SYMBOLS)

static func cargo_material(c: int, highlighted := false) -> ShaderMaterial:
	var key := "cargo_%d_%s" % [c, highlighted]
	if _cache.has(key):
		return _cache[key]
	var mat := ShaderMaterial.new()
	_cargo_base(mat)
	mat.set_shader_parameter("tint", Pal.cargo(c))
	mat.set_shader_parameter("symbol", c % Pal.SYMBOL.size())
	mat.set_shader_parameter("symbol_col", Color(1, 1, 1))
	mat.set_shader_parameter("highlight", 1.0 if highlighted else 0.0)
	_cache[key] = mat
	return mat

## Scenery containers (spare stacks, decorations): softer paint, no symbol.
static func plain_cargo_material(c: int) -> ShaderMaterial:
	var key := "cargo_plain_%d" % c
	if _cache.has(key):
		return _cache[key]
	var mat := ShaderMaterial.new()
	_cargo_base(mat)
	mat.set_shader_parameter("tint", Pal.cargo(c).lerp(Color("#efe6d6"), 0.42))
	mat.set_shader_parameter("symbol", -1)
	_cache[key] = mat
	return mat

static func tarp_material() -> ShaderMaterial:
	if _cache.has("tarp"):
		return _cache["tarp"]
	var mat := ShaderMaterial.new()
	_cargo_base(mat)
	mat.set_shader_parameter("tint", Pal.TARP)
	mat.set_shader_parameter("symbol", 8)
	mat.set_shader_parameter("symbol_col", Color("#8d7a5c"))
	mat.set_shader_parameter("symbol_shadow", 0.0)
	mat.set_shader_parameter("tarp", 1.0)
	_cache["tarp"] = mat
	return mat

static func ghost_material(c: int) -> StandardMaterial3D:
	var key := "ghost_%d" % c
	if _cache.has(key):
		return _cache[key]
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var col := Pal.cargo(c)
	col.a = 0.16
	mat.albedo_color = col
	mat.no_depth_test = false
	_cache[key] = mat
	return mat

static func flat(col: Color, rough := 0.8, metal := 0.0) -> StandardMaterial3D:
	var key := "flat_%s_%s_%s" % [col.to_html(), rough, metal]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	m.metallic = metal
	_cache[key] = m
	return m

static func vcol_material(rough := 0.75) -> StandardMaterial3D:
	var key := "vcol_%s" % rough
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = rough
	_cache[key] = m
	return m

# ---------------------------------------------------------------- ship

const SHIP_DECK := 0.95   # deck height above the waterline
const SLOT_X := [-1.15, -0.05, 1.05]

static func slot_frame_mesh() -> ArrayMesh:
	if _cache.has("slotframe"):
		return _cache["slotframe"]
	var st := _begin()
	var w := Color(1, 1, 1)
	var t := 0.05
	var hx := CW * 0.5 + 0.03
	var hz := CL * 0.5 + 0.03
	add_box(st, Vector3(0, 0.01, hz), Vector3(hx * 2 + t, 0.02, t), w)
	add_box(st, Vector3(0, 0.01, -hz), Vector3(hx * 2 + t, 0.02, t), w)
	add_box(st, Vector3(hx, 0.01, 0), Vector3(t, 0.02, hz * 2), w)
	add_box(st, Vector3(-hx, 0.01, 0), Vector3(t, 0.02, hz * 2), w)
	var m := st.commit()
	_cache["slotframe"] = m
	return m

# ---------------------------------------------------------------- crane


static func spreader_mesh() -> Mesh:
	return _model_mesh("spreader")

# ---------------------------------------------------------------- decor

## Box with an arbitrary transform (for leaning trunks, drooping fronds, domes...).
static func add_box_t(st: SurfaceTool, xf: Transform3D, size: Vector3, col: Color) -> void:
	var tmp := SurfaceTool.new()
	tmp.begin(Mesh.PRIMITIVE_TRIANGLES)
	add_box(tmp, Vector3.ZERO, size, col)
	var arr := tmp.commit_to_arrays()
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	for i in verts.size():
		st.set_normal((xf.basis * norms[i]).normalized())
		st.set_color(col)
		st.add_vertex(xf * verts[i])

static func gull_mesh() -> ArrayMesh:
	if _cache.has("gull"):
		return _cache["gull"]
	var st := _begin()
	var w := Color(1, 1, 1)
	add_box(st, Vector3(0, 0, 0), Vector3(0.12, 0.1, 0.35), w)
	add_box(st, Vector3(0.25, 0.05, 0), Vector3(0.4, 0.03, 0.14), w)
	add_box(st, Vector3(-0.25, 0.05, 0), Vector3(0.4, 0.03, 0.14), w)
	add_box(st, Vector3(0.47, 0.05, 0), Vector3(0.08, 0.03, 0.1), Color(0.3, 0.3, 0.3))
	add_box(st, Vector3(-0.47, 0.05, 0), Vector3(0.08, 0.03, 0.1), Color(0.3, 0.3, 0.3))
	add_box(st, Vector3(0, 0.0, 0.2), Vector3(0.05, 0.04, 0.08), Color("#ffb347"))
	var m := st.commit()
	_cache["gull"] = m
	return m

static func padlock_mesh() -> Mesh:
	return _model_mesh("padlock")

# ---------------------------------------------------------------- ground paint

## Outline of a rounded rectangle in the xz plane (w along x, l along z).
static func _rr_points(w: float, l: float, r: float, seg := 6) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var hx := w * 0.5 - r
	var hz := l * 0.5 - r
	for c in [[hx, hz, 0.0], [-hx, hz, PI * 0.5], [-hx, -hz, PI], [hx, -hz, PI * 1.5]]:
		for k in seg + 1:
			var a: float = c[2] + PI * 0.5 * k / seg
			pts.append(Vector2(c[0] + cos(a) * r, c[1] + sin(a) * r))
	return pts

## Flat rounded plate lying on the ground (vertex-coloured).
static func add_rounded_plate(st: SurfaceTool, w: float, l: float, r: float, y: float, col: Color) -> void:
	var pts := _rr_points(w, l, r)
	for i in pts.size():
		var a := pts[i]
		var b := pts[(i + 1) % pts.size()]
		for p in [Vector2.ZERO, a, b]:
			st.set_normal(Vector3.UP)
			st.set_color(col)
			st.add_vertex(Vector3(p.x, y, p.y))

## Flat rounded outline of thickness t (drawn inwards from the given size).
## dash > 0 leaves gaps for a dashed line.
static func add_rounded_ring(st: SurfaceTool, w: float, l: float, r: float, t: float, y: float, col: Color) -> void:
	var outer := _rr_points(w, l, r)
	var inner := _rr_points(w - t * 2.0, l - t * 2.0, maxf(0.01, r - t))
	for i in outer.size():
		var j := (i + 1) % outer.size()
		for p in [outer[i], outer[j], inner[j], outer[i], inner[j], inner[i]]:
			st.set_normal(Vector3.UP)
			st.set_color(col)
			st.add_vertex(Vector3(p.x, y, p.y))

## Four painted corner brackets marking a container bay.
static func bay_mark_mesh() -> ArrayMesh:
	if _cache.has("baymark"):
		return _cache["baymark"]
	var st := _begin()
	var w := Color(1, 1, 1)
	var hx := CW * 0.5 + 0.045
	var hz := CL * 0.5 + 0.045
	var t := 0.055
	var arm := 0.3
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			add_box(st, Vector3(sx * (hx - arm * 0.5), 0.006, sz * hz), Vector3(arm, 0.012, t), w)
			add_box(st, Vector3(sx * hx, 0.006, sz * (hz - arm * 0.5)), Vector3(t, 0.012, arm), w)
	var m := st.commit()
	_cache["baymark"] = m
	return m

## Rounded scrubby hill for the backdrop: a smooth dome with olive greens,
## darker scrub patches and pale rock near the base.
## Backdrop ridge height at (x, local z): a smooth, gently rolling crest line.
static func ridge_height(seed_v: int, length: float, height: float, depth: float, x: float, lz: float) -> float:
	var s := float(seed_v)
	var crest := height * (0.62 + 0.22 * sin(x * 0.045 + s) + 0.12 * sin(x * 0.11 + s * 2.3) + 0.05 * sin(x * 0.27 + s * 0.7))
	var u := clampf(lz / depth + 0.5, 0.0, 1.0)          # 0 front foot .. 1 back
	var prof := sin(clampf(u * 1.25, 0.0, 1.0) * PI * 0.5)  # rises quickly, then a broad top
	return crest * prof

## A long ridge for the backdrop: vertex colour from foot to crest, alpha = haze.
static func ridge_mesh(seed_v: int, length: float, height: float, depth: float, base: Color, crest: Color, haze: float) -> ArrayMesh:
	var key := "ridge_%d_%s_%s" % [seed_v, height, depth]
	if _cache.has(key):
		return _cache[key]
	var nx := 96
	var nz := 7
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var grid := []
	for j in nz + 1:
		var lz := (float(j) / nz - 0.5) * depth
		var row := []
		for i in nx + 1:
			var x := (float(i) / nx - 0.5) * length
			var y := ridge_height(seed_v, length, height, depth, x, lz)
			row.append(Vector3(x, y, lz))
		grid.append(row)
	for j in nz:
		for i in nx:
			var a: Vector3 = grid[j][i]
			var b: Vector3 = grid[j][i + 1]
			var c: Vector3 = grid[j + 1][i + 1]
			var d: Vector3 = grid[j + 1][i]
			for v in [a, c, b, a, d, c]:
				var t := clampf(v.y / maxf(0.01, height), 0.0, 1.0)
				var col := base.lerp(crest, t * t)
				# a few darker swathes of scrub so the slopes are not plastic
				col = col.darkened(0.06 * (0.5 + 0.5 * sin(v.x * 0.3 + float(seed_v)) * sin(v.y * 1.7)))
				# soft field strips across the slope, like terraced farmland seen from afar
				col = col.darkened(0.035 * (0.5 + 0.5 * sin(v.y * 3.2 + v.x * 0.05)))
				col.a = haze
				st.set_color(col)
				st.add_vertex(v)
	st.generate_normals()
	var m := st.commit()
	_cache[key] = m
	return m

static func hill_mesh(seed_v: int) -> ArrayMesh:
	var key := "hill_%d" % seed_v
	if _cache.has(key):
		return _cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var seg := 18
	var rings := 6
	var hgt := rng.randf_range(2.6, 4.0)
	var wob := []
	for i in seg:
		wob.append(rng.randf_range(0.82, 1.15))
	var pts := []
	var cols := []
	for r in rings + 1:
		var t := float(r) / rings          # 0 = rim, 1 = summit
		for i in seg:
			var a := TAU * i / seg
			var rad := 7.0 * (1.0 - t) * float(wob[i]) * (1.0 - 0.15 * t)
			var y := hgt * sin(t * PI * 0.5) - 0.3
			pts.append(Vector3(cos(a) * rad, y, sin(a) * rad))
			var base := Color("#9bb866").lerp(Color("#6f9a4f"), t)
			if rng.randf() < 0.3:
				base = base.darkened(0.16)
			if r == 0:
				base = Color("#d9c9a2")
			elif r == 1 and rng.randf() < 0.5:
				base = Color("#c9bf8e")
			cols.append(base)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for r in rings:
		for i in seg:
			var a := r * seg + i
			var b := r * seg + (i + 1) % seg
			var c := (r + 1) * seg + (i + 1) % seg
			var d := (r + 1) * seg + i
			for k in [a, b, c, a, c, d]:
				st.set_color(cols[k])
				st.add_vertex(pts[k])
	st.index()
	st.generate_normals()
	var m := st.commit()
	_cache[key] = m
	return m
