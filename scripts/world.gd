class_name World
extends Node3D
## The 3D port: scenery, layout, tap input and playback of model events.

signal stack_tapped(stack: int)
signal popup(text: String, screen_pos: Vector2, color: Color, big: bool)
signal ship_loaded(screen_pos: Vector2, color: int)
signal landed_direct(combo: int, screen_pos: Vector2)
signal dispatch_chain_started(ships: int, from_buffer: int)
signal gold_bonus(screen_pos: Vector2, id: int)

const YARD_Z := 1.75
const PAD_Z := -1.35
const BERTH_Z := -4.3
const DEPART_LANE_Z := -8.2   # outer lane: departing ships pass outside incoming ones
const SHIP_SCALE := 0.8
const WATER_Y := -0.55
const QUAY_EDGE := -3.2
const STACK_DX := 1.24
const PAD_DX := 1.22
const BERTH_X := [-2.38, 2.38, 0.0]

var model: GameModel
var camera: Camera3D
var sun: DirectionalLight3D

var cargos := {}            # id -> Cargo
var ships := {}             # uid -> Ship (docked or arriving)
var pad_markers: Array[Node3D] = []
var _pads: Array[MeshInstance3D] = []
var _dynamic: Node3D
var _ships_root: Node3D
var _yard_marks: Node3D
var _hint_arrow: Node3D
var _hint_stack := -1
var _shake := 0.0
var _cam_base := Vector3.ZERO
var _cam_target := Vector3.ZERO
var _gulls: Array[Node3D] = []
var _clouds: Array[Node3D] = []
var _buoys: Array[Node3D] = []
var _t := 0.0
var input_enabled := true
var _pad_glows: Array[MeshInstance3D] = []
var _danger := 0          # 0 calm, 1 one slot left, 2 full
var _cam_offset := Vector3.ZERO
var _foam_mat: ShaderMaterial
var _cranes: Node3D
var harbour: Harbour
var _fov_kick := 0.0
var _visual_epoch := 0
var _berth_departures := {}
var _env: Environment
var _sky_mat: ProceduralSkyMaterial
var _backdrop_mat: ShaderMaterial
var _ground_mat: ShaderMaterial
var _cloud_mat: StandardMaterial3D
var _fill: DirectionalLight3D
var _night_lights: Array[OmniLight3D] = []
var atmosphere := ""
var _look_off := Vector3.ZERO     # camera glide towards a harbour project
var _menu := 0.0                  # 0 = play camera, 1 = home-screen hero view
var _menu_tween: Tween
var _menu_was := false
const MENU_CAM := Vector3(8.4, 12.6, -17.2)
const MENU_TARGET := Vector3(0.2, 0.1, -3.0)

func _ready() -> void:
	_build_environment()
	_build_port()
	_build_decor()
	# yard light masts and a parked terminal tractor
	for p in [Vector3(-7.6, 0, 3.4), Vector3(7.6, 0, 3.4)]:
		var lm := ModelMats.instance("res://assets/models/light_mast.glb")
		lm.position = p
		add_child(lm)
	var tr := ModelMats.instance("res://assets/models/tractor.glb")
	tr.position = Vector3(-6.5, 0, 1.2)
	tr.rotation.y = 0.12
	add_child(tr)
	_bake_static()
	_make_night_lights()
	# ship-to-shore cranes at either end of the quay (repaintable by a harbour project)
	_cranes = Node3D.new()
	add_child(_cranes)
	set_cranes(Save.has_project("cranes"))
	harbour = Harbour.new()
	add_child(harbour)
	harbour.refresh()
	_dynamic = Node3D.new()
	_dynamic.name = "Dynamic"
	add_child(_dynamic)
	Cargo.fly_root = _dynamic
	_ships_root = Node3D.new()
	_ships_root.name = "Ships"
	add_child(_ships_root)
	_hint_arrow = _make_hint_arrow()
	_hint_arrow.visible = false
	add_child(_hint_arrow)

## A chunky bouncing arrow over the suggested stack.
func _make_hint_arrow() -> Node3D:
	var root := Node3D.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color("#ffc533")
	mat.no_depth_test = true
	mat.render_priority = 3
	var rim := StandardMaterial3D.new()
	rim.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rim.albedo_color = Color.WHITE
	rim.no_depth_test = true
	rim.render_priority = 2
	for pass_i in 2:
		var grow := 0.07 if pass_i == 0 else 0.0
		var m: StandardMaterial3D = rim if pass_i == 0 else mat
		var head := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.34 + grow
		cone.bottom_radius = 0.0
		cone.height = 0.5 + grow * 2.0
		cone.radial_segments = 20
		head.mesh = cone
		head.material_override = m
		head.position.y = 0.25
		head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(head)
		var shaft := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.15 + grow
		cyl.bottom_radius = 0.15 + grow
		cyl.height = 0.42 + grow
		cyl.radial_segments = 16
		shaft.mesh = cyl
		shaft.material_override = m
		shaft.position.y = 0.66
		shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(shaft)
	return root

# ================================================================= scenery

func _build_environment() -> void:
	var env := Environment.new()
	_env = env
	var sky := Sky.new()
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	var sm := ProceduralSkyMaterial.new()
	_sky_mat = sm
	sm.sky_top_color = Color("#5ab6f5")
	sm.sky_horizon_color = Color("#def3fc")
	sm.sky_curve = 0.1
	sm.ground_horizon_color = Color("#def3fc")
	sm.ground_bottom_color = Color("#8fd0ee")
	sm.sun_angle_max = 0.0
	sm.sun_curve = 0.01
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#dcebf7")
	env.ambient_light_sky_contribution = 0.0
	env.ambient_light_energy = 0.55
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.tonemap_exposure = 1.0
	env.fog_enabled = false
	env.fog_light_color = Color("#def3fc")
	env.fog_density = 0.004
	env.fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.06
	env.adjustment_contrast = 1.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-47, 156, 0)
	sun.light_color = Color("#fff4e2")
	sun.light_energy = 0.31
	sun.shadow_enabled = true
	sun.shadow_bias = 0.03
	sun.shadow_normal_bias = 0.7
	sun.directional_shadow_max_distance = 26.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.shadow_blur = 2.4
	sun.shadow_opacity = 0.42
	add_child(sun)
	var fill := DirectionalLight3D.new()
	_fill = fill
	fill.rotation_degrees = Vector3(-35, -30, 0)
	fill.light_color = Color("#d6e8ff")
	fill.light_energy = 0.08
	add_child(fill)

	camera = Camera3D.new()
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.fov = 50.0
	camera.near = 0.5
	camera.far = 260.0
	add_child(camera)
	set_camera_for(5)

## The camera hovers over the harbour looking in toward the yard. Placement was
## solved numerically so both berths fit and the yard is as large as possible
## between the HUD and the action buttons on 16:9 to 19.5:9 screens.
func set_camera_for(_n_stacks: int) -> void:
	_cam_base = Vector3(0, 9.8, -9.5)
	_cam_target = Vector3(0, 0.4, 0.9)
	camera.position = _cam_base
	camera.look_at(_cam_target, Vector3.UP)

func _build_port() -> void:
	# water
	var water := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(200, 130)
	pm.subdivide_width = 40
	pm.subdivide_depth = 26
	water.mesh = pm
	var wm := ShaderMaterial.new()
	wm.shader = load("res://shaders/water.gdshader")
	wm.set_shader_parameter("quay_z", QUAY_EDGE - 0.1)
	water.material_override = wm
	_foam_mat = wm
	water.position = Vector3(0, WATER_Y, -62 + QUAY_EDGE)
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)

	# quay top: one shader paints the slabs, the yard, the apron and the lines
	var ground := MeshInstance3D.new()
	var gp := PlaneMesh.new()
	gp.size = Vector2(90, 30.0 - QUAY_EDGE)
	ground.mesh = gp
	var gm := ShaderMaterial.new()
	gm.shader = load("res://shaders/ground.gdshader")
	gm.set_shader_parameter("yard_rect", Vector4(0.0, YARD_Z + 0.02, 4.45, 1.62))
	gm.set_shader_parameter("apron_rect", Vector4(0.0, PAD_Z, 4.0, 1.32))
	gm.set_shader_parameter("quay_z", QUAY_EDGE)
	ground.material_override = gm
	_ground_mat = gm
	ground.position = Vector3(0, 0.0, (QUAY_EDGE + 30.0) * 0.5)
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ground)

	# quay wall: modelled segments with a white kerb and round fenders
	var x := -33.8
	while x <= 33.8:
		var seg := ModelMats.instance("res://assets/models/quay_segment.glb")
		seg.position = Vector3(x, 0.0, QUAY_EDGE)
		add_child(seg)
		x += 2.6
	# bollards
	x = -14.3
	while x <= 14.3:
		var b := ModelMats.instance("res://assets/models/mooring_bollard.glb")
		b.position = Vector3(x, 0.13, QUAY_EDGE + 0.2)
		add_child(b)
		x += 2.6

	_yard_marks = Node3D.new()
	add_child(_yard_marks)

func _build_decor() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	# Three soft ridges recede into haze behind the sheds, so the puzzle stays
	# the brightest, most saturated thing on screen.
	_backdrop_mat = ShaderMaterial.new()
	_backdrop_mat.shader = load("res://shaders/backdrop.gdshader")
	_backdrop_mat.set_shader_parameter("haze_col", ATMOS.get(atmosphere, ATMOS["day"])["hor"])
	var ridges := [
		# z, height, depth, base colour, crest colour, haze, seed
		[27.5, 2.8, 12.0, Color("#93cf86"), Color("#b9e39a"), 0.12, 3],
		[52.0, 7.0, 18.0, Color("#84c6a4"), Color("#aadcb8"), 0.45, 7],
		[88.0, 14.0, 26.0, Color("#9ac4de"), Color("#c3def0"), 0.74, 11],
	]
	for r in ridges:
		var mi := MeshInstance3D.new()
		mi.mesh = Meshes.ridge_mesh(r[6], 150.0, r[1], r[2], r[3], r[4], r[5])
		mi.material_override = _backdrop_mat
		mi.add_to_group("dynamic")   # keep out of the static merge (own shader)
		mi.position = Vector3(0, -0.4, r[0])
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)

	# quayside sheds with roof terraces (the harbour projects build on them)
	var xs := [-12.0, -4.0, 4.5, 12.5]
	for i in xs.size():
		var w := ModelMats.instance("res://assets/models/warehouse_%s.glb" % ("a" if i % 2 == 0 else "b"))
		w.position = Vector3(xs[i], 0, 12.5)
		add_child(w)
	# a row of trees on the grass behind the sheds
	var tx := -20.0
	while tx <= 20.0:
		var t := ModelMats.instance("res://assets/models/%s.glb" % ("tree_round" if rng.randf() < 0.7 else "cypress"))
		t.position = Vector3(tx + rng.randf_range(-0.5, 0.5), 0, rng.randf_range(16.6, 18.4))
		t.scale = Vector3.ONE * rng.randf_range(1.5, 2.1)
		t.rotation.y = rng.randf() * TAU
		_no_shadow(t)
		add_child(t)
		tx += rng.randf_range(1.8, 2.8)
	# palms frame the yard at the sides, clear of the stacks
	for p in [Vector3(-7.7, 0, 5.4), Vector3(7.8, 0, 5.2), Vector3(-9.2, 0, 8.0), Vector3(9.3, 0, 8.1)]:
		var palm := ModelMats.instance("res://assets/models/palm.glb")
		palm.position = p
		palm.rotation.y = rng.randf() * TAU
		palm.scale = Vector3.ONE * rng.randf_range(1.15, 1.35)
		add_child(palm)
	# side stacks of spare containers in washed-out paint
	for side in [-1, 1]:
		for i in 2:
			for row in 2:
				for h in rng.randi_range(1, 3):
					var m := MeshInstance3D.new()
					m.mesh = Meshes.container_lod_mesh()
					m.material_override = Meshes.plain_cargo_material(rng.randi_range(0, 7))
					m.position = Vector3(side * (9.3 + i * 1.12), h * Meshes.CH - Meshes.CH, 1.2 + row * 2.1)
					m.add_to_group("dynamic")
					add_child(m)
	# harbour light on a short breakwater
	var bw := MeshInstance3D.new()
	var bwm := CylinderMesh.new()
	bwm.top_radius = 1.5
	bwm.bottom_radius = 1.9
	bwm.height = 1.2
	bwm.radial_segments = 20
	bw.mesh = bwm
	bw.material_override = Meshes.flat(Color("#e3d6bb"), 0.95)
	bw.position = Vector3(-10.5, WATER_Y, -9.5)
	add_child(bw)
	var lh := ModelMats.instance("res://assets/models/lighthouse.glb")
	lh.position = Vector3(-10.5, WATER_Y + 0.6, -9.5)
	lh.scale = Vector3.ONE * 0.85
	add_child(lh)
	# buoys
	for p in [Vector3(-6.0, WATER_Y, -9.0), Vector3(6.4, WATER_Y, -8.5), Vector3(-3.2, WATER_Y, -14.0), Vector3(4.0, WATER_Y, -15.0)]:
		var buoy := Node3D.new()
		var bmesh := ModelMats.instance("res://assets/models/navigation_buoy.glb", Pal.cargo(0) if p.x < 0 else Pal.cargo(3))
		buoy.add_child(bmesh)
		buoy.position = p
		add_child(buoy)
		_buoys.append(buoy)
	# soft flat-bottomed clouds over the hills
	var cloud_mesh := Meshes._model_mesh("cloud")
	_cloud_mat = StandardMaterial3D.new()
	_cloud_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_cloud_mat.albedo_color = Color(1, 1, 1)
	for i in 9:
		var cl := MeshInstance3D.new()
		cl.mesh = cloud_mesh
		cl.material_override = _cloud_mat
		cl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cl.add_to_group("dynamic")
		cl.scale = Vector3.ONE * rng.randf_range(1.5, 2.6)
		cl.position = Vector3(rng.randf_range(-55, 55), rng.randf_range(19, 29), rng.randf_range(55, 85))
		add_child(cl)
		_clouds.append(cl)
	# seagulls circling over the berths
	for i in 4:
		var g := Node3D.new()
		var gm := MeshInstance3D.new()
		gm.mesh = Meshes.gull_mesh()
		gm.material_override = Meshes.vcol_material(0.7)
		gm.scale = Vector3.ONE * 1.2
		g.add_child(gm)
		g.set_meta("phase", rng.randf() * TAU)
		g.set_meta("r", rng.randf_range(3.5, 7.0))
		g.set_meta("c", Vector3(rng.randf_range(-6, 6), rng.randf_range(5.5, 7.5), rng.randf_range(8, 14)))
		g.set_meta("spd", rng.randf_range(0.25, 0.45) * (1 if i % 2 == 0 else -1))
		add_child(g)
		_gulls.append(g)

func _no_shadow(n: Node) -> void:
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _process(delta: float) -> void:
	_t += delta
	for g in _gulls:
		var ph: float = g.get_meta("phase") + _t * g.get_meta("spd")
		var c: Vector3 = g.get_meta("c")
		var r: float = g.get_meta("r")
		var p := c + Vector3(cos(ph) * r, sin(_t * 0.7 + ph) * 0.4, sin(ph) * r * 0.5)
		var ahead := c + Vector3(cos(ph + 0.05 * sign(g.get_meta("spd"))) * r, 0, sin(ph + 0.05 * sign(g.get_meta("spd"))) * r * 0.5)
		g.position = p
		if p.distance_to(ahead) > 0.001:
			g.look_at(Vector3(ahead.x, p.y, ahead.z), Vector3.UP)
		var wing := sin(_t * 9.0 + ph) * 0.35
		g.get_child(0).rotation.z = wing * 0.3
	for cl in _clouds:
		cl.position.x += delta * 0.6
		if cl.position.x > 60:
			cl.position.x = -60
	for b in _buoys:
		b.position.y = WATER_Y + sin(_t * 1.6 + b.position.x) * 0.08
		b.rotation.z = sin(_t * 1.3 + b.position.z) * 0.12
	if _hint_arrow.visible and _hint_stack >= 0 and model:
		var h: int = model.stacks[_hint_stack].size()
		_hint_arrow.position = Vector3(stack_x(_hint_stack), h * Meshes.CH + 0.35 + abs(sin(_t * 5.0)) * 0.4, YARD_Z - 0.2)
		_hint_arrow.rotation.y = _t * 2.0
	var jitter := Vector3.ZERO
	if _shake > 0.0:
		_shake = max(0.0, _shake - delta)
		var a := _shake * 0.35
		jitter = Vector3(randf_range(-a, a), randf_range(-a, a) * 0.5, 0)
	var mk := smoothstep(0.0, 1.0, _menu)
	# the home view drifts a little, like a hand-held shot of a model harbour
	var drift := Vector3(sin(_t * 0.22) * 0.7, sin(_t * 0.17) * 0.25, 0.0) * (0.0 if Save.reduce_motion else mk)
	camera.position = _cam_base.lerp(MENU_CAM + drift, mk) + _cam_offset + jitter
	if _fov_kick > 0.0:
		_fov_kick = max(0.0, _fov_kick - delta * 2.2)
		camera.fov = 50.0 - 3.5 * sin(_fov_kick * PI)
	elif camera.fov != 50.0:
		camera.fov = 50.0
	if mk > 0.0 or _cam_offset.length_squared() > 0.0001 or _look_off.length_squared() > 0.0001:
		camera.look_at(_cam_target.lerp(MENU_TARGET, mk) + _look_off, Vector3.UP)
	elif _menu_was:
		camera.look_at(_cam_target, Vector3.UP)
	_menu_was = mk > 0.0
	if has_meta("free_cam"):
		var fc: Array = get_meta("free_cam")
		camera.position = fc[0]
		camera.look_at(fc[1], Vector3.UP)
	# buffer danger glow
	var pulse := 0.5 + 0.5 * sin(_t * (9.0 if _danger == 2 else 6.0))
	for g in _pad_glows:
		var m: StandardMaterial3D = g.material_override
		var target_a := 0.0
		if _danger == 1:
			m.albedo_color = Color(1.0, 0.55, 0.1, m.albedo_color.a)
			target_a = 0.18 + 0.22 * pulse
		elif _danger == 2:
			m.albedo_color = Color(0.95, 0.2, 0.25, m.albedo_color.a)
			target_a = 0.28 + 0.25 * pulse
		m.albedo_color.a = lerp(m.albedo_color.a, target_a, min(1.0, delta * 10.0))
	# foam around ships in the water shader
	if _foam_mat:
		var pts := PackedVector4Array()
		for sh in _ships_root.get_children():
			if pts.size() >= 4 or not (sh is Ship):
				continue
			var spd := 1.0 if sh.moving() else 0.10
			pts.append(Vector4(sh.global_position.x, sh.global_position.z, SHIP_SCALE, spd))
		while pts.size() < 4:
			pts.append(Vector4(0, 0, 0, 0))
		_foam_mat.set_shader_parameter("ships", pts)

func set_cranes(gold: bool) -> void:
	for c in _cranes.get_children():
		c.queue_free()
	for xx in [-7.6, 7.6]:
		var c := ModelMats.instance("res://assets/models/crane_gold.glb" if gold else "res://assets/models/crane.glb")
		c.position = Vector3(xx, 0, 0)
		_no_shadow(c)      # its lattice would stripe the whole quay
		_cranes.add_child(c)

## Dispatch chain: horns in a rising sequence, a camera kick and bursts over each ship.
func celebrate_chain(ships_sent: int) -> void:
	if not Save.reduce_motion:
		_fov_kick = minf(0.35, 0.12 * ships_sent)
		shake(0.06)

## Level start: the camera glides down into place.
## Glides the camera towards a point (a newly built project), holds, and returns.
func focus_on(p: Vector3, hold := 1.6) -> void:
	var dir := p - _cam_target
	var look := dir * 0.85
	var move := Vector3(dir.x * 0.45, -2.5, dir.z * 0.35 + 1.0)
	if Save.reduce_motion:
		look *= 0.5
		move *= 0.3
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "_look_off", look, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(self, "_cam_offset", move, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.chain().tween_interval(hold)
	tw.chain().set_parallel(true)
	tw.tween_property(self, "_look_off", Vector3.ZERO, 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(self, "_cam_offset", Vector3.ZERO, 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

## Per-chapter light. Cargo colours must stay readable in every preset, so
## night keeps a strong cool ambient and the yard lamps switch on.
const ATMOS := {
	"day": {"sun": Color("#fff4e2"), "sun_e": 0.42, "sun_rot": Vector3(-47, 156, 0), "amb": Color("#dfe9f7"), "amb_e": 0.26,
		"fill_e": 0.05, "top": Color("#5ab6f5"), "hor": Color("#def3fc"), "shallow": Color("#43c9d8"),
		"deep": Color("#2187dc"), "tint": Color("#e6f8ff"), "fog": 0.0, "fog_col": Color("#def3fc"), "lamps": false, "sat": 1.06,
		"shadow": 0.68, "cloud": Color("#ffffff"), "ground": Color("#ecdcbc"), "grass": Color("#a9dc98")},
	"storm": {"sun": Color("#e6ecf2"), "sun_e": 0.36, "sun_rot": Vector3(-56, 156, 0), "amb": Color("#cfdbe8"), "amb_e": 0.25,
		"fill_e": 0.05, "top": Color("#7e95ab"), "hor": Color("#cdd8e0"), "shallow": Color("#57b3ba"),
		"deep": Color("#2f6f96"), "tint": Color("#d6e2ea"), "fog": 0.006, "fog_col": Color("#cdd8e0"), "lamps": false, "sat": 0.98,
		"shadow": 0.56, "cloud": Color("#b9c6d1"), "ground": Color("#d9ccb6"), "grass": Color("#9bcb92")},
	"gold": {"sun": Color("#ffdca8"), "sun_e": 0.44, "sun_rot": Vector3(-38, 158, 0), "amb": Color("#f3e3cc"), "amb_e": 0.23,
		"fill_e": 0.04, "top": Color("#69b4ee"), "hor": Color("#ffe6bf"), "shallow": Color("#58d0c8"),
		"deep": Color("#2b8fd2"), "tint": Color("#fff0d6"), "fog": 0.0, "fog_col": Color("#ffe6bf"), "lamps": false, "sat": 1.08,
		"shadow": 0.68, "cloud": Color("#fff3df"), "ground": Color("#f4e2c2"), "grass": Color("#b7d98c")},
	"fog": {"sun": Color("#f1f4f6"), "sun_e": 0.36, "sun_rot": Vector3(-52, 156, 0), "amb": Color("#d9e3ec"), "amb_e": 0.26,
		"fill_e": 0.05, "top": Color("#b2cbdc"), "hor": Color("#e8eff3"), "shallow": Color("#74c6c8"),
		"deep": Color("#4a93b8"), "tint": Color("#e9f1f5"), "fog": 0.009, "fog_col": Color("#e4ecf0"), "lamps": false, "sat": 0.96,
		"shadow": 0.52, "cloud": Color("#eef3f6"), "ground": Color("#e0d6c2"), "grass": Color("#a8d2a0")},
	"night": {"sun": Color("#b4c4ff"), "sun_e": 0.21, "sun_rot": Vector3(-58, 140, 0), "amb": Color("#8496c8"), "amb_e": 0.35,
		"fill_e": 0.04, "top": Color("#14244d"), "hor": Color("#3c5590"), "shallow": Color("#2c6f9a"),
		"deep": Color("#15306a"), "tint": Color("#8fb0e6"), "fog": 0.0, "fog_col": Color("#3c5590"), "lamps": true, "sat": 1.1,
		"shadow": 0.6, "cloud": Color("#4a639c"), "ground": Color("#c9c6cf"), "grass": Color("#6f9fa0")},
	"sunset": {"sun": Color("#ffc99a"), "sun_e": 0.4, "sun_rot": Vector3(-32, 166, 0), "amb": Color("#ecd0c8"), "amb_e": 0.23,
		"fill_e": 0.05, "top": Color("#5b7fc4"), "hor": Color("#ffc59a"), "shallow": Color("#5cb8c4"),
		"deep": Color("#3a6fc0"), "tint": Color("#ffe0c8"), "fog": 0.0, "fog_col": Color("#ffc59a"), "lamps": true, "sat": 1.08,
		"shadow": 0.66, "cloud": Color("#ffd9c2"), "ground": Color("#f2dcc4"), "grass": Color("#b0cf8c")},
	"dusk": {"sun": Color("#ffd0b2"), "sun_e": 0.34, "sun_rot": Vector3(-36, 163, 0), "amb": Color("#c9bfe2"), "amb_e": 0.27,
		"fill_e": 0.05, "top": Color("#5a58a8"), "hor": Color("#ffc9a0"), "shallow": Color("#57a6c4"),
		"deep": Color("#3760b4"), "tint": Color("#f0d6e0"), "fog": 0.0, "fog_col": Color("#ffc9a0"), "lamps": true, "sat": 1.08,
		"shadow": 0.64, "cloud": Color("#e8c6d8"), "ground": Color("#e6d6cc"), "grass": Color("#9fc596")},
}
const CHAPTER_ATMOS := ["day", "day", "storm", "gold", "fog", "day", "day", "night", "sunset", "dusk"]

func set_atmosphere_for_level(level_index: int) -> void:
	set_atmosphere(CHAPTER_ATMOS[clampi(level_index / 10, 0, CHAPTER_ATMOS.size() - 1)])

func set_atmosphere(name: String) -> void:
	if name == atmosphere or not ATMOS.has(name):
		return
	atmosphere = name
	var a: Dictionary = ATMOS[name]
	sun.light_color = a["sun"]
	sun.light_energy = a["sun_e"]
	sun.rotation_degrees = a["sun_rot"]
	sun.shadow_opacity = a["shadow"]
	_fill.light_energy = a["fill_e"]
	_env.ambient_light_color = a["amb"]
	_env.ambient_light_energy = a["amb_e"]
	_env.adjustment_enabled = true
	_env.adjustment_saturation = a["sat"]
	_env.tonemap_exposure = 1.0
	_sky_mat.sky_top_color = a["top"]
	_sky_mat.sky_horizon_color = a["hor"]
	_sky_mat.ground_horizon_color = a["hor"]
	_sky_mat.ground_bottom_color = (a["shallow"] as Color).lerp(a["hor"], 0.4)
	if _backdrop_mat:
		_backdrop_mat.set_shader_parameter("haze_col", a["hor"])
	if _cloud_mat:
		_cloud_mat.albedo_color = a["cloud"]
	if _ground_mat:
		_ground_mat.set_shader_parameter("concrete", a["ground"])
		_ground_mat.set_shader_parameter("grass", a["grass"])
	_env.fog_enabled = a["fog"] > 0.0
	_env.fog_density = a["fog"]
	_env.fog_light_color = a["fog_col"]
	if _foam_mat:
		_foam_mat.set_shader_parameter("shallow", a["shallow"])
		_foam_mat.set_shader_parameter("deep", a["deep"])
		_foam_mat.set_shader_parameter("sky_tint", a["tint"])
	for l in _night_lights:
		l.visible = a["lamps"]
	apply_light_override()

## Dev: lighting experiments from the harness (--light=...).
func apply_light_override() -> void:
	if not has_meta("light_override"):
		return
	var v: Array = get_meta("light_override")
	sun.light_energy = v[0]
	_env.ambient_light_energy = v[1]
	sun.shadow_opacity = v[2]
	_env.tonemap_mode = int(v[3])
	_env.tonemap_exposure = v[4]
	_env.adjustment_enabled = true
	_env.adjustment_saturation = v[5]

func _make_night_lights() -> void:
	# warm pools of light from the yard masts and the quay, used after dark
	for p in [Vector3(-6.2, 6.5, 3.2), Vector3(6.2, 6.5, 3.2), Vector3(0, 4.5, -1.0)]:
		var l := OmniLight3D.new()
		l.light_color = Color("#ffd9a0")
		l.light_energy = 1.4
		l.omni_range = 11.0
		l.omni_attenuation = 1.2
		l.shadow_enabled = false
		l.position = p
		l.visible = false
		add_child(l)
		_night_lights.append(l)

## Home screen: a three-quarter hero view of the port. Levels use the play camera.
func set_menu_view(on: bool, instant := false) -> void:
	if _menu_tween:
		_menu_tween.kill()
	var to := 1.0 if on else 0.0
	if instant or Save.reduce_motion:
		_menu = to
		return
	_menu_tween = create_tween()
	_menu_tween.tween_property(self, "_menu", to, 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

func intro_sweep() -> void:
	if Save.reduce_motion:
		return
	if _menu > 0.5:
		return   # the glide in from the home view is the intro
	_cam_offset = Vector3(0, 5.5, -4.0)
	var tw := create_tween()
	tw.tween_property(self, "_cam_offset", Vector3.ZERO, 1.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

## 0 = calm, 1 = one slot left, 2 = full
func set_danger(level: int) -> void:
	_danger = level

func shake(amount: float = 0.3) -> void:
	if Save.reduce_motion:
		return
	_shake = max(_shake, amount)

# ================================================================= layout

func stack_x(s: int) -> float:
	var n := model.stacks.size()
	return (s - (n - 1) * 0.5) * STACK_DX

func pad_x(i: int) -> float:
	var n := model.buffer.size()
	return (i - (n - 1) * 0.5) * PAD_DX

func berth_pos(b: int) -> Vector3:
	var n := model.berth_ship.size()
	var x: float = BERTH_X[b] if n > 1 else 0.0
	return Vector3(x, WATER_Y, BERTH_Z)

func berth_side(b: int) -> int:
	return -1 if berth_pos(b).x <= 0.0 else 1

func cargo_stack_pos(s: int, i: int) -> Vector3:
	return Vector3(stack_x(s), i * Meshes.CH, YARD_Z)

# ================================================================= level build

func load_model(m: GameModel, animate_in := true) -> void:
	_visual_epoch += 1
	_berth_departures.clear()
	model = m
	hide_hint()
	for c in _dynamic.get_children():
		c.queue_free()
	for c in _ships_root.get_children():
		c.queue_free()
	for c in _yard_marks.get_children():
		c.queue_free()
	for id in cargos:
		if is_instance_valid(cargos[id]):
			cargos[id].queue_free()
	cargos.clear()
	ships.clear()
	pad_markers.clear()
	_pads.clear()
	_pad_glows.clear()
	_danger = 0
	set_camera_for(model.stacks.size())

	# yard bays: corner brackets and a painted bay number
	for s in model.stacks.size():
		var mark := MeshInstance3D.new()
		mark.mesh = Meshes.bay_mark_mesh()
		mark.material_override = Meshes.flat(Color(1, 1, 1, 1), 1.0)
		mark.position = Vector3(stack_x(s), 0.0, YARD_Z)
		mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_yard_marks.add_child(mark)
		var bay := Label3D.new()
		bay.font = Pal.font_display()
		bay.text = "%d" % (model.stacks.size() - s)
		bay.font_size = 64
		bay.pixel_size = 0.0058
		bay.modulate = Color(1.0, 1.0, 1.0, 0.95)
		bay.outline_size = 0
		bay.shaded = false
		bay.rotation = Vector3(-PI / 2, PI, 0)
		bay.position = Vector3(stack_x(s), 0.012, YARD_Z - Meshes.CL * 0.5 - 0.3)
		_yard_marks.add_child(bay)

	# buffer pads
	for i in model.buffer.size():
		_add_pad(i, false)

	# containers in the yard
	var delay := 0.0
	for s in model.stacks.size():
		for i in model.stacks[s].size():
			var id: int = model.stacks[s][i]
			var c := _make_cargo(id)
			_dynamic.add_child(c)
			c.position = cargo_stack_pos(s, i)
			if animate_in:
				_drop_in(c, delay + i * 0.05)
		delay += 0.06
	# containers already in the buffer (after undo)
	for i in model.buffer.size():
		var id: int = model.buffer[i]
		if id != -1:
			var c := _make_cargo(id)
			pad_markers[i].add_child(c)

	# ships at berth
	for b in model.berth_ship.size():
		var uid: int = model.berth_ship[b]
		if uid == -1:
			continue
		var ship := _make_ship(uid)
		if animate_in:
			ship.arrive(berth_pos(b), 0.2 + b * 0.25, berth_side(b))
		else:
			ship.face(berth_side(b))
			ship.place_instant(berth_pos(b))
		for k in model.ship_slots[uid].size():
			var id: int = model.ship_slots[uid][k]
			var c := _make_cargo(id)
			ship.markers[k].add_child(c)
			ship.on_landed(k)
	_refresh_locks()
	refresh_detail()

func _drop_in(c: Cargo, delay: float) -> void:
	var target := c.position
	c.position = target + Vector3(0, 7.0, 0)
	c.visible = false
	var tw := c.create_tween()
	tw.tween_interval(delay)
	tw.tween_callback(func(): c.visible = true)
	tw.tween_property(c, "position", target, 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		c.pop()
		Sfx.play("land_buffer", randf_range(1.1, 1.3), -12.0))

func _make_cargo(id: int) -> Cargo:
	var info: Dictionary = model.containers[id]
	var c := Cargo.new()
	c.setup(id, info["c"], info["h"], info["l"])
	cargos[id] = c
	return c

func _make_ship(uid: int) -> Ship:
	var ship := Ship.new()
	ship.setup(uid, model.ship_color[uid], model.cap)
	ship.scale = Vector3.ONE * SHIP_SCALE
	_ships_root.add_child(ship)
	ships[uid] = ship
	return ship

func _add_pad(i: int, animate: bool) -> void:
	var pad := MeshInstance3D.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w := Meshes.CW + 0.16
	var l := Meshes.CL + 0.16
	Meshes.add_rounded_plate(st, w, l, 0.16, 0.010, Color("#4a6482"))
	Meshes.add_rounded_ring(st, w, l, 0.16, 0.06, 0.016, Color("#ffffff"))
	# a soft "P" style hatch: three pale chevrons pointing at the ships
	for k in 3:
		var z := -0.42 + k * 0.42
		for sx in [-1.0, 1.0]:
			var xf := Transform3D(Basis(Vector3.UP, sx * 0.5), Vector3(sx * 0.17, 0.016, z))
			Meshes.add_box_t(st, xf, Vector3(0.42, 0.006, 0.075), Color("#6f8aa8"))
	pad.mesh = st.commit()
	pad.material_override = Meshes.vcol_material(1.0)
	pad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pad.position = Vector3(pad_x(i), 0.0, PAD_Z)
	_yard_marks.add_child(pad)
	_pads.append(pad)
	var marker := Node3D.new()
	marker.position = Vector3(pad_x(i), 0.02, PAD_Z)
	_dynamic.add_child(marker)
	pad_markers.append(marker)
	var glow := MeshInstance3D.new()
	var gst := SurfaceTool.new()
	gst.begin(Mesh.PRIMITIVE_TRIANGLES)
	Meshes.add_rounded_plate(gst, w + 0.14, l + 0.14, 0.22, 0.0, Color.WHITE)
	glow.mesh = gst.commit()
	var gm := StandardMaterial3D.new()
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.albedo_color = Color(1, 0.5, 0.1, 0.0)
	glow.material_override = gm
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	glow.position = Vector3(0, 0.018, 0)
	pad.add_child(glow)
	_pad_glows.append(glow)
	if animate:
		pad.scale = Vector3(0.01, 1, 0.01)
		var tw := pad.create_tween()
		tw.tween_property(pad, "scale", Vector3.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## Extra buffer slot booster: re-centre pads and add one.
func add_pad_animated() -> void:
	var i := model.buffer.size() - 1
	_add_pad(i, true)
	for k in _pads.size():
		var target := Vector3(pad_x(k), 0.0, PAD_Z)
		var tw := _pads[k].create_tween()
		tw.tween_property(_pads[k], "position", target, 0.35).set_trans(Tween.TRANS_QUAD)
		var tw2 := pad_markers[k].create_tween()
		tw2.tween_property(pad_markers[k], "position", Vector3(target.x, 0.02, PAD_Z), 0.35).set_trans(Tween.TRANS_QUAD)
	burst(Vector3(pad_x(i), 0.4, PAD_Z), Color("#ffc53d"), 24)

## Merges every static mesh in the scenery into one mesh per material, so the
## background costs a handful of draw calls instead of hundreds.
func _bake_static() -> void:
	var groups := {}   # material -> [SurfaceTool, shadow?]
	var to_free := []
	for n in find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n
		if mi.get_parent() == null or mi.mesh == null:
			continue
		if mi.is_in_group("dynamic") or mi.mesh is PlaneMesh:
			continue
		# leave anything animated alone (buoys bob, gulls fly, clouds drift)
		var p := mi.get_parent()
		var animated := false
		while p and p != self:
			if p in _buoys or p in _gulls or p in _clouds:
				animated = true
				break
			p = p.get_parent()
		if animated:
			continue
		var xf := global_transform.affine_inverse() * mi.global_transform
		for si in mi.mesh.get_surface_count():
			var mat: Material = mi.get_surface_override_material(si)
			if mat == null:
				mat = mi.material_override
			if mat == null:
				mat = mi.mesh.surface_get_material(si)
			if mat is ShaderMaterial:
				continue
			var casts := mi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var key := "%d_%s" % [mat.get_instance_id() if mat else 0, casts]
			if not groups.has(key):
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				groups[key] = [st, mat, casts]
			var arrays := mi.mesh.surface_get_arrays(si)
			if (arrays[Mesh.ARRAY_INDEX] == null or arrays[Mesh.ARRAY_INDEX].is_empty()) and arrays[Mesh.ARRAY_VERTEX].size() % 3 != 0:
				continue
			# The far town is tiny on screen: merge it from the importer's simplified
			# LOD (about a third of the triangles) instead of the full model.
			if mi.global_position.z > FAR_TOWN_Z:
				var lod := _lod_indices(mi.mesh, si, 0.38)
				if not lod.is_empty():
					arrays[Mesh.ARRAY_INDEX] = lod
			var tmp := ArrayMesh.new()
			tmp.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			groups[key][0].append_from(tmp, 0, xf)
		if not to_free.has(mi):
			to_free.append(mi)
	for mi in to_free:
		mi.get_parent().remove_child(mi)
		mi.queue_free()
	for casts in [true, false]:
		var merged := ArrayMesh.new()
		for key in groups:
			var g: Array = groups[key]
			if g[2] != casts:
				continue
			var arr: Array = (g[0] as SurfaceTool).commit_to_arrays()
			merged.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
			merged.surface_set_material(merged.get_surface_count() - 1, g[1])
		if merged.get_surface_count() == 0:
			continue
		var out := MeshInstance3D.new()
		out.name = "StaticScenery" if casts else "StaticSceneryNoShadow"
		out.mesh = merged
		out.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if casts else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(out)

const FAR_TOWN_Z := 20.0

## The importer's LOD index buffer closest to `ratio` of the full triangle count.
func _lod_indices(mesh: Mesh, si: int, ratio: float) -> PackedInt32Array:
	var surface := RenderingServer.mesh_get_surface(mesh.get_rid(), si)
	var full: int = surface.get("index_count", 0)
	var best := PackedInt32Array()
	var best_err := 1e9
	var stride := RenderingServer.mesh_surface_get_format_index_stride(surface["format"], surface["vertex_count"])
	for lod in surface.get("lods", []):
		var data: PackedByteArray = lod["index_data"]
		var count := int(data.size() / stride)
		var err := absf(float(count) / maxf(1.0, full) - ratio)
		if err < best_err:
			best_err = err
			best = PackedInt32Array()
			best.resize(count)
			for i in count:
				best[i] = data.decode_u16(i * stride) if stride == 2 else data.decode_u32(i * stride)
	return best

## Top-of-stack, buffered and shipped boxes get the detailed model.
func refresh_detail() -> void:
	if model == null:
		return
	var top := {}
	for col in model.stacks:
		for i in col.size():
			top[col[i]] = i == col.size() - 1
	for id in cargos:
		var c = cargos[id]
		if not is_instance_valid(c):
			continue
		c.set_detail(top.get(id, true))

func _refresh_locks() -> void:
	var gone := []
	for id in cargos:
		var c = cargos[id]
		if not is_instance_valid(c):
			gone.append(id)
		elif c.is_locked():
			c.update_lock(model.sailed)
	for id in gone:
		cargos.erase(id)

# ================================================================= input

func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled or model == null:
		return
	var pos := Vector2.ZERO
	var pressed := false
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pos = event.position
		pressed = true
	if not pressed:
		return
	var s := pick_stack(pos)
	if s != -1:
		get_viewport().set_input_as_handled()
		stack_tapped.emit(s)

## Screen-space picking: nearest stack column to the touch point.
func pick_stack(pos: Vector2) -> int:
	var best := -1
	var best_d := INF
	var vp := get_viewport().get_visible_rect().size
	var tol := vp.x * 0.085
	for s in model.stacks.size():
		var h: int = max(1, model.stacks[s].size())
		var a := camera.unproject_position(Vector3(stack_x(s), 0.0, YARD_Z - Meshes.CL * 0.5))
		var b := camera.unproject_position(Vector3(stack_x(s), h * Meshes.CH, YARD_Z + Meshes.CL * 0.3))
		var d := _seg_dist(pos, a, b)
		if d < best_d:
			best_d = d
			best = s
	if best_d <= tol:
		return best
	return -1

func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / max(ab.length_squared(), 0.0001), 0.0, 1.0)
	return p.distance_to(a + ab * t)

func to_screen(p: Vector3) -> Vector2:
	return camera.unproject_position(p)

# ================================================================= events

func play(events: Array) -> void:
	refresh_detail()
	var stagger := 0.0
	var epoch := _visual_epoch
	var chain := {}
	for event in events:
		if event["t"] == "chain":
			chain = event
	var chain_fired := [false]
	var dispatch_rank := 0
	for e in events:
		match e["t"]:
			"move":
				_play_move(e, stagger)
				if e.has("from_buffer"):
					stagger += 0.09
			"reveal":
				var c: Cargo = cargos.get(e["id"])
				if c:
					var cargo_ref: WeakRef = weakref(c)
					get_tree().create_timer(0.12).timeout.connect(func():
						var cargo: Cargo = cargo_ref.get_ref()
						if epoch != _visual_epoch or cargo == null:
							return
						cargo.reveal()
						Sfx.play("reveal")
						burst(cargo.global_position + Vector3(0, Meshes.CH, 0), Color("#fff3b0"), 14))
			"depart":
				var ship: Ship = ships.get(e["ship"])
				if ship:
					dispatch_rank += 1
					ship.dispatch_rank = dispatch_rank
					_berth_departures[e["berth"]] = ship
					ship.departure_started.connect(func(vessel: Ship):
						if epoch != _visual_epoch:
							return
						Sfx.dispatch_horn(vessel.color, vessel.dispatch_rank)
						ring(Vector3(vessel.global_position.x, WATER_Y + 0.08, vessel.global_position.z), 2.8)
						if not chain.is_empty() and not chain_fired[0]:
							chain_fired[0] = true
							dispatch_chain_started.emit(chain["ships"], chain["from_buffer"])
							celebrate_chain(chain["ships"]), CONNECT_ONE_SHOT)
					ships.erase(e["ship"])
					ship.depart(DEPART_LANE_Z)
					_refresh_locks()
			"arrive":
				var ship := _make_ship(e["ship"])
				var previous: Ship = _berth_departures.get(e["berth"])
				if not is_instance_valid(previous):
					previous = null
				ship.arrive(berth_pos(e["berth"]), 0.08, berth_side(e["berth"]), previous)
				stagger = 0.0
			"unlock":
				var c: Cargo = cargos.get(e["id"])
				if c:
					var cargo_ref: WeakRef = weakref(c)
					get_tree().create_timer(0.35).timeout.connect(func():
						var cargo: Cargo = cargo_ref.get_ref()
						if epoch != _visual_epoch or cargo == null:
							return
						cargo.unlock()
						Sfx.play("unlock")
						burst(cargo.global_position + Vector3(0, 0.4, 1.0), Color("#ffcf4a"), 18)
						popup.emit("Unlocked!", to_screen(cargo.global_position + Vector3(0, 1.2, 0)), Color("#ffb020"), false))
			"refuse":
				_play_refuse(e)

func _play_move(e: Dictionary, delay: float) -> void:
	var c: Cargo = cargos.get(e["id"])
	if c == null:
		return
	var target: Node3D
	var dur := 0.44
	var arc := 2.2
	var ship: Ship = null
	if e["to"] == "ship":
		ship = ships.get(e["ship"])
		if ship == null:
			return
		target = ship.markers[e["slot"]]
		dur = 0.48
		arc = 2.6
		ship.reserve(delay + dur + maxf(0.0, ship.arrive_left - 0.40))
	else:
		target = pad_markers[e["slot"]]
		dur = 0.4
		arc = 1.6
	if e.has("from_stack"):
		_bounce_stack(e["from_stack"])
	var epoch := _visual_epoch
	var cargo_ref: WeakRef = weakref(c)
	var target_ref: WeakRef = weakref(target)
	var ship_ref: WeakRef = weakref(ship) if ship != null else null
	var start := func():
		var cargo: Cargo = cargo_ref.get_ref()
		var destination: Node3D = target_ref.get_ref()
		var vessel: Ship = ship_ref.get_ref() if ship_ref != null else null
		if epoch != _visual_epoch or cargo == null or destination == null:
			return
		cargo.fly_to(destination, dur, arc, vessel)
		Sfx.play("pick", randf_range(0.95, 1.1), -4.0)
	if delay > 0.0:
		get_tree().create_timer(delay).timeout.connect(start)
	else:
		start.call()
	c.landed.connect(func(cargo: Cargo):
		var vessel: Ship = ship_ref.get_ref() if ship_ref != null else null
		if epoch == _visual_epoch:
			_on_landed(cargo, e, vessel), CONNECT_ONE_SHOT)

func _bounce_stack(s: int) -> void:
	if Save.reduce_motion:
		return
	var col: Array = model.stacks[s]
	for i in col.size():
		var cg = cargos.get(col[i])
		if cg == null or not is_instance_valid(cg):
			continue
		var tw: Tween = cg.create_tween()
		tw.tween_interval(0.03 * (col.size() - i))
		tw.tween_property(cg.body, "scale", Vector3(1.015, 0.98, 1.015), 0.10)
		tw.tween_property(cg.body, "scale", Vector3.ONE, 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func set_gold(ids: Array) -> void:
	for id in ids:
		var c = cargos.get(id)
		if c and is_instance_valid(c):
			c.set_gold(true, false)

## Expanding foam ring on the water.
func ring(at: Vector3, size: float) -> void:
	var r := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.82
	tm.outer_radius = 1.0
	tm.rings = 24
	tm.ring_segments = 6
	r.mesh = tm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(1, 1, 1, 0.85)
	r.material_override = m
	r.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	r.position = at
	r.scale = Vector3(size * 0.4, 0.05, size * 0.25)
	add_child(r)
	var tw := r.create_tween().set_parallel(true)
	tw.tween_property(r, "scale", Vector3(size * 1.3, 0.05, size * 0.85), 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.9)
	tw.chain().tween_callback(r.queue_free)

func _on_landed(c: Cargo, e: Dictionary, ship: Ship) -> void:
	Save.buzz(14)
	if e["to"] == "ship":
		if not is_instance_valid(ship):
			return
		ship.on_landed(e["slot"])
		var combo: int = e.get("combo", 0)
		Sfx.play("land_ship", 1.0 + 0.07 * min(combo, 9))
		burst(c.global_position + Vector3(0, Meshes.CH, 0), Pal.cargo(c.color).lightened(0.35), 8)
		if e.has("from_stack"):
			landed_direct.emit(combo, to_screen(c.global_position + Vector3(0, 1.0, 0)))
		if c.gold:
			c.set_gold(false, false)
			Sfx.play("gold")
			burst(c.global_position + Vector3(0, Meshes.CH, 0), Color("#ffd23f"), 34)
			burst(c.global_position + Vector3(0, Meshes.CH + 0.4, 0), Color("#fff6c2"), 20)
			gold_bonus.emit(to_screen(c.global_position + Vector3(0, 1.4, 0)), c.id)
		if ship.loaded >= ship.cap:
			Sfx.play("dispatch_seal", 1.0, -4.0)
			Save.buzz(24)
			if not Save.reduce_motion:
				burst(ship.global_position + Vector3(0, 1.4, 0), Pal.cargo(ship.color).lightened(0.3), 6)
			ship_loaded.emit(to_screen(ship.global_position + Vector3(0, 2.0, 0)), ship.color)
	else:
		Sfx.play("land_buffer", randf_range(0.95, 1.05), -2.0)
		burst(c.global_position + Vector3(0, 0.05, 0), Color("#e8e1d3"), 10, true)

func _play_refuse(e: Dictionary) -> void:
	var s: int = e["stack"]
	Sfx.play("error")
	Save.buzz(60)
	if s >= 0 and s < model.stacks.size() and not model.stacks[s].is_empty():
		var c: Cargo = cargos.get(model.stacks[s].back())
		if c:
			c.shake()
	if e["why"] == "full":
		for p in _pads:
			var tw := p.create_tween()
			tw.tween_property(p, "scale", Vector3(1.08, 1, 1.08), 0.08)
			tw.tween_property(p, "scale", Vector3.ONE, 0.2)
		shake(0.12)

# ================================================================= hint

func show_hint(s: int) -> void:
	hide_hint()
	_hint_stack = s
	_hint_arrow.visible = true
	if not model.stacks[s].is_empty():
		var c: Cargo = cargos.get(model.stacks[s].back())
		if c:
			c.set_highlight(true)

func hide_hint() -> void:
	if _hint_stack >= 0 and model and _hint_stack < model.stacks.size() and not model.stacks[_hint_stack].is_empty():
		var c: Cargo = cargos.get(model.stacks[_hint_stack].back())
		if c:
			c.set_highlight(false)
	_hint_stack = -1
	if _hint_arrow:
		_hint_arrow.visible = false

func is_busy() -> bool:
	for id in cargos:
		var c = cargos[id]
		if is_instance_valid(c) and c.flying:
			return true
	for s in _ships_root.get_children():
		if s is Ship and is_instance_valid(s) and (s.arriving or (s.departing and not s.berth_clear)):
			return true
	return false

# ================================================================= particles

static var _spark_mesh: Mesh

func _spark() -> Mesh:
	if _spark_mesh == null:
		var q := BoxMesh.new()
		q.size = Vector3(0.12, 0.12, 0.12)
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.vertex_color_use_as_albedo = true
		m.vertex_color_is_srgb = true
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		q.material = m
		_spark_mesh = q
	return _spark_mesh

func burst(at: Vector3, col: Color, amount: int, dust := false) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = amount
	p.lifetime = 0.7 if not dust else 0.5
	p.explosiveness = 0.95
	p.mesh = _spark()
	p.direction = Vector3.UP
	p.spread = 70 if not dust else 85
	p.initial_velocity_min = 2.0 if not dust else 0.8
	p.initial_velocity_max = 4.0 if not dust else 1.6
	p.gravity = Vector3(0, -7.0, 0)
	p.angular_velocity_min = -360
	p.angular_velocity_max = 360
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.2
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	p.scale_amount_curve = curve
	p.color = col
	p.position = at
	add_child(p)
	p.emitting = true
	get_tree().create_timer(1.5).timeout.connect(p.queue_free)

func big_burst(at: Vector3, col: Color) -> void:
	burst(at, col, 40)
	burst(at + Vector3(0, 0.5, 0), Color("#fff3b0"), 26)
	burst(at, Color(1, 1, 1), 18)

func confetti() -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = 60 if Save.reduce_motion else 140
	p.lifetime = 3.2
	p.explosiveness = 0.85
	var q := BoxMesh.new()
	q.size = Vector3(0.22, 0.02, 0.12)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	q.material = m
	p.mesh = q
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(6, 0.5, 3)
	p.direction = Vector3(0, 1, 0)
	p.spread = 45
	p.initial_velocity_min = 3
	p.initial_velocity_max = 7
	p.gravity = Vector3(0, -4.0, 0)
	p.angular_velocity_min = -500
	p.angular_velocity_max = 500
	p.damping_min = 1.0
	p.damping_max = 2.0
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.2, 0.4, 0.6, 0.8, 1.0])
	g.colors = PackedColorArray([Pal.cargo(0), Pal.cargo(1), Pal.cargo(2), Pal.cargo(3), Pal.cargo(4), Pal.cargo(6)])
	p.color_initial_ramp = g
	p.position = Vector3(0, 3, 0.5)
	add_child(p)
	p.emitting = true
	get_tree().create_timer(4.0).timeout.connect(p.queue_free)
