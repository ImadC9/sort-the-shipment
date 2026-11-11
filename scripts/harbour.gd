class_name Harbour
extends Node3D
## Harbour Projects: cosmetic upgrades that visibly change the port.
## They sit in the strip behind the yard, which is always on screen.
## The next unbuilt project shows a small construction site so players can see
## where their coins are going.

var _built := {}          # id -> Node3D
var _site: Node3D
var _beam: Node3D
var _jets: Array = []
var _flags: Array = []
var _t := 0.0

const SPOTS := {
	"lighthouse": Vector3(4.9, 0, 9.0),
	"bunting": Vector3(0, 0, 9.75),
	# roof terraces on the warehouses stay visible above even the tallest stacks
	"cafe": Vector3(3.6, 3.43, 12.2),
	"planters": Vector3(0, 0, 0),
	"fountain": Vector3(-3.8, 3.43, 12.2),
	"clocktower": Vector3(-4.9, 0, 9.2),
	"cranes": Vector3(7.3, 0, 0),
	"solar": Vector3(0, 3.43, 13.6),
	"lamps": Vector3(0, 0, 8.6),
	"flags": Vector3(0, 3.43, 10.7),
	"pool": Vector3(-1.7, 3.43, 11.2),
	"gardens": Vector3(0, 3.43, 11.4),
	"icecream": Vector3(-6.5, 0, 7.0),
	"fairylights": Vector3(0, 3.48, 9.88),
	"monument": Vector3(3.2, 0, 7.0),
	"liveries": Vector3(0, 0, -4.3),
}

## Where the camera glides to show a finished project (and the construction
## sign stands for the next one).
const FOCUS := {
	"solar": Vector3(0, 3.4, 13.0), "lamps": Vector3(0, 1.0, 8.6), "flags": Vector3(0.3, 5.0, 10.7),
	"pool": Vector3(-1.7, 3.6, 11.2), "gardens": Vector3(-6.4, 3.4, 11.4), "icecream": Vector3(-6.5, 0.8, 7.0),
	"fairylights": Vector3(0, 3.4, 10.0), "monument": Vector3(3.2, 1.0, 7.0), "liveries": Vector3(0, 0.5, -4.3),
}

func refresh(animate_id: String = "") -> void:
	for id in _built:
		if is_instance_valid(_built[id]):
			_built[id].queue_free()
	_built.clear()
	if _site and is_instance_valid(_site):
		_site.queue_free()
	_site = null
	_beam = null
	_jets.clear()
	_flags.clear()
	for p in Save.PROJECTS:
		var id: String = p[0]
		if id == "fireworks":
			continue
		if Save.has_project(id):
			var n := _make(id)
			if n:
				add_child(n)
				_built[id] = n
				if id == animate_id:
					_pop_in(n)
		elif id == "lighthouse":
			# the old lighthouse stands there, weathered, until it is restored
			var ruin := _lighthouse(false)
			ruin.position = SPOTS["lighthouse"]
			add_child(ruin)
			_built["lighthouse_ruin"] = ruin
	var nxt := Save.next_project()
	if not nxt.is_empty() and SPOTS.has(nxt[0]) and not nxt[0] in ["lighthouse", "cranes", "liveries", "solar", "gardens", "fairylights", "lamps", "flags"]:
		_site = _construction_site()
		var at: Vector3 = SPOTS[nxt[0]]
		if nxt[0] == "bunting":
			at += Vector3(0, 0, -0.6)
		elif nxt[0] == "planters":
			at = Vector3(5.15, 0, 2.0)
		_site.position = at
		add_child(_site)

func _pop_in(n: Node3D) -> void:
	var s := n.scale
	n.scale = s * 0.05
	var tw := n.create_tween()
	tw.tween_property(n, "scale", s, 0.7).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func _process(delta: float) -> void:
	_t += delta
	if _beam and is_instance_valid(_beam):
		_beam.rotation.y = _t * 1.2
	for f in _flags:
		if is_instance_valid(f):
			f.rotation.x = sin(_t * 3.0 + f.position.x * 1.7) * 0.25

# ---------------------------------------------------------------- builders

func _make(id: String) -> Node3D:
	var n: Node3D
	match id:
		"lighthouse":
			n = _lighthouse(true)
		"bunting":
			n = _bunting()
		"cafe":
			n = _cafe()
		"planters":
			n = _planters()
		"fountain":
			n = _fountain()
		"clocktower":
			n = _clocktower()
		"cranes", "liveries":
			return null   # handled by World / Ship
		"solar":
			n = _solar()
		"lamps":
			n = _lamps()
		"flags":
			n = _flag_masts()
		"pool":
			n = _pool()
		"gardens":
			n = _gardens()
		"icecream":
			n = _icecream()
		"fairylights":
			n = _fairy_lights()
		"monument":
			n = _monument()
		_:
			return null
	n.position = SPOTS[id]
	return n

func _mesh(st: SurfaceTool) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = Meshes.vcol_material(0.7)
	return mi

func _st() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st

func _cyl(st: SurfaceTool, center: Vector3, r_bot: float, r_top: float, h: float, col: Color, segs := 12) -> void:
	for i in segs:
		var a0 := TAU * i / segs
		var a1 := TAU * (i + 1) / segs
		var b0 := center + Vector3(cos(a0) * r_bot, -h * 0.5, sin(a0) * r_bot)
		var b1 := center + Vector3(cos(a1) * r_bot, -h * 0.5, sin(a1) * r_bot)
		var t0 := center + Vector3(cos(a0) * r_top, h * 0.5, sin(a0) * r_top)
		var t1 := center + Vector3(cos(a1) * r_top, h * 0.5, sin(a1) * r_top)
		var n := Vector3(cos((a0 + a1) * 0.5), 0.15, sin((a0 + a1) * 0.5)).normalized()
		for p in [b0, t0, t1, b0, t1, b1]:
			st.set_normal(n)
			st.set_color(col)
			st.add_vertex(p)
		for p in [center + Vector3(0, h * 0.5, 0), t1, t0]:
			st.set_normal(Vector3.UP)
			st.set_color(col)
			st.add_vertex(p)

func _lighthouse(restored: bool) -> Node3D:
	var root := Node3D.new()
	var model := ModelMats.instance("res://assets/models/lighthouse.glb" if restored else "res://assets/models/lighthouse_ruin.glb")
	model.scale = Vector3.ONE * 0.92
	root.add_child(model)
	if restored:
		var top := 4.3 * 0.92
		var glow := OmniLight3D.new()
		glow.light_color = Color("#fff1b8")
		glow.light_energy = 0.5
		glow.omni_range = 3.0
		glow.position = Vector3(0, top + 0.4, 0)
		root.add_child(glow)
		# rotating beam
		_beam = Node3D.new()
		_beam.position = Vector3(0, top + 0.37, 0)
		var beam := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.05
		cm.bottom_radius = 0.6
		cm.height = 5.0
		cm.radial_segments = 10
		beam.mesh = cm
		var bm := StandardMaterial3D.new()
		bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		bm.albedo_color = Color(1.0, 0.95, 0.7, 0.16)
		bm.cull_mode = BaseMaterial3D.CULL_DISABLED
		beam.material_override = bm
		beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		beam.rotation.z = -PI / 2
		beam.position = Vector3(2.5, 0, 0)
		_beam.add_child(beam)
		root.add_child(_beam)
	return root

func _bunting() -> Node3D:
	var root := Node3D.new()
	var st := _st()
	var xs := [-6.0, -2.0, 2.0, 6.0]
	for x in xs:
		Meshes.add_box(st, Vector3(x, 1.6, 0), Vector3(0.08, 3.2, 0.08), Color("#ffffff"))
	root.add_child(_mesh(st))
	# flags hang from a sagging line between poles
	for i in xs.size() - 1:
		var a: float = xs[i]
		var b: float = xs[i + 1]
		var n := 9
		for k in n:
			var t := (k + 0.5) / n
			var x: float = lerp(a, b, t)
			var y := 3.1 - sin(t * PI) * 0.45
			var flag := MeshInstance3D.new()
			var pm := PrismMesh.new()
			pm.size = Vector3(0.28, 0.34, 0.02)
			flag.mesh = pm
			flag.material_override = Meshes.flat(Pal.cargo((k + i * 3) % 6), 0.6)
			flag.rotation.z = PI
			flag.position = Vector3(x, y - 0.17, 0)
			flag.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(flag)
			_flags.append(flag)
	return root

func _cafe() -> Node3D:
	var root := Node3D.new()
	var st := _st()
	var cols := [Color("#ef4b5c"), Color("#3d8fe8"), Color("#ffc53d")]
	for i in 3:
		var x := -1.6 + i * 1.6
		var c: Color = cols[i]
		Meshes.add_box(st, Vector3(x, 0.32, 0), Vector3(0.5, 0.05, 0.5), Color("#ffffff"))
		Meshes.add_box(st, Vector3(x, 0.16, 0), Vector3(0.06, 0.32, 0.06), Color("#8d8a86"))
		Meshes.add_box(st, Vector3(x, 0.8, 0), Vector3(0.04, 1.4, 0.04), Color("#ffffff"))
		_cyl(st, Vector3(x, 1.45, 0), 0.75, 0.05, 0.3, c, 10)
		for dz in [-0.45, 0.45]:
			Meshes.add_box(st, Vector3(x, 0.2, dz), Vector3(0.24, 0.04, 0.24), Color("#d98e3c"))
			Meshes.add_box(st, Vector3(x, 0.36, dz + signf(dz) * 0.1), Vector3(0.24, 0.3, 0.03), Color("#d98e3c"))
	# kiosk
	Meshes.add_box(st, Vector3(2.5, 0.55, 0.2), Vector3(1.2, 1.1, 0.8), Color("#fff3d6"))
	Meshes.add_box(st, Vector3(2.5, 1.15, 0.0), Vector3(1.4, 0.1, 1.1), Color("#ef4b5c"))
	Meshes.add_box(st, Vector3(2.5, 0.7, -0.21), Vector3(0.9, 0.35, 0.02), Color("#2f6f99"))
	root.add_child(_mesh(st))
	return root

func _planters() -> Node3D:
	var root := Node3D.new()
	var st := _st()
	var flowers := [Color("#ff6fb7"), Color("#ffc53d"), Color("#ef4b5c"), Color("#9a63e6")]
	var k := 0
	for side in [1.0, -1.0]:
		var x: float = 5.15 * side
		var z: float = -0.2 if side > 0 else 3.0
		var z_end := 6.2
		while z <= z_end:
			if k % 3 == 2:
				Meshes.add_box(st, Vector3(x, 0.22, z), Vector3(0.3, 0.06, 0.9), Color("#c98a4b"))
				Meshes.add_box(st, Vector3(x + 0.13 * side, 0.4, z), Vector3(0.05, 0.28, 0.9), Color("#c98a4b"))
				for dz in [-0.38, 0.38]:
					Meshes.add_box(st, Vector3(x, 0.1, z + dz), Vector3(0.28, 0.2, 0.05), Color("#3a3f47"))
			else:
				Meshes.add_box(st, Vector3(x, 0.2, z), Vector3(0.46, 0.4, 0.84), Color("#e9dcc0"))
				Meshes.add_box(st, Vector3(x, 0.44, z), Vector3(0.38, 0.12, 0.76), Color("#4cbb6c"))
				for f in 3:
					Meshes.add_box(st, Vector3(x, 0.56, z - 0.24 + f * 0.24), Vector3(0.14, 0.12, 0.14), flowers[(k + f) % flowers.size()])
			z += 1.2
			k += 1
	root.add_child(_mesh(st))
	return root

func _fountain() -> Node3D:
	var root := Node3D.new()
	var st := _st()
	_cyl(st, Vector3(0, 0.15, 0), 0.9, 0.9, 0.3, Color("#e9dcc0"), 16)
	_cyl(st, Vector3(0, 0.31, 0), 0.78, 0.78, 0.02, Color("#5cc7e0"), 16)
	_cyl(st, Vector3(0, 0.6, 0), 0.12, 0.1, 0.7, Color("#e9dcc0"), 10)
	_cyl(st, Vector3(0, 0.95, 0), 0.35, 0.35, 0.08, Color("#e9dcc0"), 12)
	root.add_child(_mesh(st))
	var jet := CPUParticles3D.new()
	jet.amount = 40
	jet.lifetime = 0.9
	var drop := SphereMesh.new()
	drop.radius = 0.04
	drop.height = 0.08
	drop.radial_segments = 6
	drop.rings = 3
	var dm := StandardMaterial3D.new()
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.albedo_color = Color("#bfefff")
	drop.material = dm
	jet.mesh = drop
	jet.direction = Vector3.UP
	jet.spread = 18
	jet.initial_velocity_min = 2.0
	jet.initial_velocity_max = 2.6
	jet.gravity = Vector3(0, -6, 0)
	jet.position = Vector3(0, 1.0, 0)
	root.add_child(jet)
	_jets.append(jet)
	return root

func _clocktower() -> Node3D:
	var root := Node3D.new()
	var st := _st()
	Meshes.add_box(st, Vector3(0, 0.25, 0), Vector3(1.6, 0.5, 1.6), Color("#e9dcc0"))
	Meshes.add_box(st, Vector3(0, 2.2, 0), Vector3(1.1, 3.6, 1.1), Color("#fbf3e3"))
	Meshes.add_box(st, Vector3(0, 4.25, 0), Vector3(1.3, 0.5, 1.3), Color("#fbf3e3"))
	for d in [Vector3(0, 0, -0.66), Vector3(0.66, 0, 0), Vector3(-0.66, 0, 0)]:
		var face: Vector3 = Vector3(0, 4.25, 0) + d
		var size: Vector3 = Vector3(0.7, 0.7, 0.03) if d.z != 0 else Vector3(0.03, 0.7, 0.7)
		Meshes.add_box(st, face, size, Color("#ffffff"))
		Meshes.add_box(st, face + d.normalized() * 0.02 + Vector3(0, 0.1, 0), size * Vector3(0.12, 0.35, 1) if d.z != 0 else size * Vector3(1, 0.35, 0.12), Color("#2b2f36"))
	Meshes.add_box(st, Vector3(0, 4.6, 0), Vector3(1.45, 0.12, 1.45), Color("#2e9a5a"))
	_cyl(st, Vector3(0, 5.15, 0), 0.75, 0.05, 1.0, Color("#2e9a5a"), 4)
	Meshes.add_box(st, Vector3(0, 5.85, 0), Vector3(0.06, 0.5, 0.06), Color("#ffc53d"))
	for y in [1.3, 2.4]:
		Meshes.add_box(st, Vector3(0, y, -0.56), Vector3(0.3, 0.55, 0.02), Color("#2f6f99"))
	root.add_child(_mesh(st))
	return root

func _construction_site() -> Node3D:
	var root := Node3D.new()
	var st := _st()
	for i in 4:
		var a := TAU * i / 4.0 + 0.4
		var p := Vector3(cos(a) * 0.7, 0.2, sin(a) * 0.45)
		_cyl(st, p, 0.12, 0.02, 0.4, Color("#ff7a1a"), 8)
		_cyl(st, p + Vector3(0, 0.02, 0), 0.085, 0.07, 0.07, Color("#ffffff"), 8)
	Meshes.add_box(st, Vector3(0, 0.05, 0), Vector3(1.6, 0.04, 1.1), Color("#e8d7b0"))
	root.add_child(_mesh(st))
	return root

# ---------------------------------------------------------------- phase 2

const ROOF_XS := [-4.0, 4.5]          # the two warehouses in view

func _glow_mat(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	return m

func _solar() -> Node3D:
	var root := Node3D.new()
	var st := _st()
	for wx in ROOF_XS:
		for row in 2:
			for k in 5:
				var x: float = wx - 2.6 + k * 1.3
				var z := -0.5 + row * 0.9
				# skylights sit at z ~ -1.1 (local 1.5 on the roof): rows go behind them
				Meshes.add_box(st, Vector3(x, 0.12, z + 0.35), Vector3(1.15, 0.06, 0.06), Color("#9aa5b1"))
				var xf := Transform3D(Basis(Vector3.RIGHT, -0.35), Vector3(x, 0.22, z + 0.35))
				Meshes.add_box_t(st, xf, Vector3(1.12, 0.04, 0.72), Color("#1f4f86"))
				Meshes.add_box_t(st, xf.translated_local(Vector3(0, 0.025, 0)), Vector3(0.02, 0.01, 0.7), Color("#c9d6e3"))
	root.add_child(_mesh(st))
	return root

func _lamps() -> Node3D:
	var root := Node3D.new()
	var st := _st()
	var gm := _glow_mat(Color("#fff1b8"))
	for x in [-6.6, -3.0, 3.8, 6.7]:
		Meshes.add_box(st, Vector3(x, 0.08, 0), Vector3(0.3, 0.16, 0.3), Color("#2f3238"))
		_cyl(st, Vector3(x, 0.95, 0), 0.05, 0.04, 1.7, Color("#2f3238"), 8)
		Meshes.add_box(st, Vector3(x, 1.82, 0), Vector3(0.3, 0.05, 0.3), Color("#2f3238"))
		var bulb := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.16
		sm.height = 0.32
		sm.radial_segments = 10
		sm.rings = 5
		bulb.mesh = sm
		bulb.material_override = gm
		bulb.position = Vector3(x, 1.98, 0)
		bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(bulb)
	root.add_child(_mesh(st))
	return root

func _flag_masts() -> Node3D:
	var root := Node3D.new()
	var st := _st()
	var cols := [Color("#ef4b5c"), Color("#3d8fe8"), Color("#38c172")]
	var xs := [-0.9, 1.4, 1.95]
	for i in xs.size():
		var x: float = xs[i]
		var h := 4.2 - i * 0.4
		_cyl(st, Vector3(x, h * 0.5, 0), 0.06, 0.04, h, Color("#f4f4f0"), 8)
		_cyl(st, Vector3(x, h + 0.05, 0), 0.09, 0.09, 0.1, Color("#ffc53d"), 8)
		var flag := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.9, 0.55, 0.02)
		flag.mesh = bm
		flag.material_override = Meshes.flat(cols[i], 0.6)
		flag.position = Vector3(x + 0.47, h - 0.35, 0)
		flag.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(flag)
		_flags.append(flag)
	root.add_child(_mesh(st))
	return root

func _gardens() -> Node3D:
	var root := Node3D.new()
	var st := _st()
	for wx in [-6.4, 7.0]:
		for k in 3:
			var x: float = wx - 0.9 + k * 0.9
			Meshes.add_box(st, Vector3(x, 0.18, 0), Vector3(0.7, 0.36, 0.7), Color("#c98a4b"))
			Meshes.add_box(st, Vector3(x, 0.38, 0), Vector3(0.6, 0.06, 0.6), Color("#5a3e2b"))
		root.add_child(_mesh(st))
		for k in 3:
			var t := ModelMats.instance("res://assets/models/%s.glb" % ("cypress" if k == 1 else "tree_round"))
			t.position = Vector3(wx - 0.9 + k * 0.9, 0.4, 0)
			t.scale = Vector3.ONE * (0.55 if k == 1 else 0.6)
			root.add_child(t)
	return root

func _icecream() -> Node3D:
	var root := Node3D.new()
	var st := _st()
	Meshes.add_box(st, Vector3(0, 0.5, 0), Vector3(1.4, 1.0, 0.8), Color("#ffffff"))
	Meshes.add_box(st, Vector3(0, 0.5, -0.41), Vector3(1.2, 0.5, 0.02), Color("#ff6fb7"))
	for k in 7:
		Meshes.add_box(st, Vector3(-0.6 + k * 0.2, 1.75, 0), Vector3(0.2, 0.06, 1.1), Color("#ff6fb7") if k % 2 == 0 else Color("#ffffff"))
	for x in [-0.6, 0.6]:
		Meshes.add_box(st, Vector3(x, 1.35, -0.5), Vector3(0.05, 0.8, 0.05), Color("#d9d2c4"))
	# a giant cone on the roof
	_cyl(st, Vector3(0, 2.15, 0), 0.04, 0.22, 0.5, Color("#e0a35a"), 10)
	_cyl(st, Vector3(0, 2.5, 0), 0.24, 0.12, 0.26, Color("#ffd6e8"), 10)
	root.add_child(_mesh(st))
	return root

func _fairy_lights() -> Node3D:
	var root := Node3D.new()
	var cols := [Color("#fff1b8"), Color("#ffd27a"), Color("#ffb3c7"), Color("#b8e4ff")]
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var sm := SphereMesh.new()
	sm.radius = 0.07
	sm.height = 0.14
	sm.radial_segments = 6
	sm.rings = 3
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	sm.material = m
	mm.mesh = sm
	var pts := []
	for wx in ROOF_XS:
		for k in 24:
			var x: float = wx - 3.5 + k * 0.3
			pts.append(Vector3(x, -0.12 - absf(sin(k * 0.52)) * 0.18, 0))
	mm.instance_count = pts.size()
	for i in pts.size():
		mm.set_instance_transform(i, Transform3D(Basis(), pts[i]))
		mm.set_instance_color(i, cols[i % cols.size()])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	return root

func _monument() -> Node3D:
	var root := Node3D.new()
	root.scale = Vector3.ONE * 1.35
	var st := _st()
	Meshes.add_box(st, Vector3(0, 0.25, 0), Vector3(1.1, 0.5, 1.1), Color("#e9dcc0"))
	Meshes.add_box(st, Vector3(0, 0.55, 0), Vector3(0.8, 0.1, 0.8), Color("#d6c6a4"))
	var bronze := Color("#b07a3a")
	_cyl(st, Vector3(0, 1.45, 0), 0.09, 0.09, 1.6, bronze, 8)
	Meshes.add_box(st, Vector3(0, 2.05, 0), Vector3(0.7, 0.1, 0.12), bronze)
	_cyl(st, Vector3(0, 2.35, 0), 0.14, 0.14, 0.08, bronze, 10)
	for sx in [-1.0, 1.0]:
		var xf := Transform3D(Basis(Vector3.BACK, 0.7 * sx), Vector3(0.32 * sx, 0.85, 0))
		Meshes.add_box_t(st, xf, Vector3(0.12, 0.6, 0.12), bronze)
		Meshes.add_box_t(st, Transform3D(Basis(), Vector3(0.5 * sx, 1.08, 0)), Vector3(0.14, 0.14, 0.14), bronze)
	root.add_child(_mesh(st))
	return root

func _pool() -> Node3D:
	var root := Node3D.new()
	var st := _st()
	Meshes.add_box(st, Vector3(0, 0.08, 0), Vector3(1.9, 0.16, 1.3), Color("#f4f4f0"))
	Meshes.add_box(st, Vector3(0, 0.165, 0), Vector3(1.6, 0.02, 1.0), Color("#3fc4e0"))
	for k in 3:
		Meshes.add_box(st, Vector3(-0.55 + k * 0.55, 0.12, -0.95), Vector3(0.36, 0.06, 0.6), Color("#ffffff"))
		Meshes.add_box(st, Vector3(-0.55 + k * 0.55, 0.2, -0.75), Vector3(0.34, 0.12, 0.04), Color("#ffffff"))
	Meshes.add_box(st, Vector3(1.15, 0.7, -0.95), Vector3(0.04, 1.2, 0.04), Color("#d9d2c4"))
	_cyl(st, Vector3(1.15, 1.3, -0.95), 0.6, 0.05, 0.25, Color("#ff8a3d"), 10)
	root.add_child(_mesh(st))
	return root
