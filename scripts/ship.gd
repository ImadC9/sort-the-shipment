class_name Ship
extends Node3D
signal departure_started(ship)
signal berth_released(ship)
## A feeder ship waiting at a berth for containers of one colour.

const MODELS := ["res://assets/models/ship_feeder.glb", "res://assets/models/ship_tanker.glb", "res://assets/models/ship_coaster.glb"]
const FUNNEL_TOPS := [Vector3(-2.27, 3.66, 0.0), Vector3(-2.25, 3.22, 0.5), Vector3(-2.21, 2.9, 0.68)]
const HATCH := 0.05

var uid := 0
var color := 0
var cap := 3
var berth_pos := Vector3.ZERO
var markers: Array[Node3D] = []
var ghosts: Array[MeshInstance3D] = []
var pending := 0
var loaded := 0
var arriving := false
var arrive_left := 0.0
var departing := false
var berth_clear := false
var dispatch_rank := 1
var _entry_blocker: Ship
var _entry_delay := 0.0
var _entry_started := false
var _entry_duration := 0.70
var _departure_active := false
var _departure_lane := -6.1
var _seal_left := 0.18
var _last_landing_at := 0.0
var _seal_played := false

var _hull_root: Node3D
var _bob_t := 0.0
var _dip := 0.0
var _smoke: CPUParticles3D
var _wake: CPUParticles3D
var _sign: Sprite3D

func setup(p_uid: int, p_color: int, p_cap: int) -> void:
	uid = p_uid
	color = p_color
	cap = p_cap
	_bob_t = randf() * 10.0
	_hull_root = Node3D.new()
	add_child(_hull_root)
	var col := Pal.cargo(color)

	# Blender-made hull; the ship type follows the colour so each colour has its own silhouette
	var kind: int = color % MODELS.size()
	var model := ModelMats.instance(MODELS[kind], col)
	_hull_root.add_child(model)
	var funnel_top: Vector3 = FUNNEL_TOPS[kind]
	if Save.has_project("liveries"):
		_add_livery(model, funnel_top)

	# floating badge with the colour symbol, readable from the camera
	_sign = Sprite3D.new()
	_sign.texture = Pal.badge_tex(color)
	_sign.pixel_size = 0.0058
	_sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sign.shaded = false
	_sign.no_depth_test = true
	_sign.render_priority = 2
	_sign.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	# above the bridge, which sits near the middle of the screen
	_sign.position = Vector3(-2.05, Meshes.SHIP_DECK + 3.25, 0.0)
	_hull_root.add_child(_sign)

	# deck slots: a painted symbol on each hatch, a pulsing ghost box and a landing marker
	var xs: Array = Meshes.SLOT_X
	for i in cap:
		var x: float = xs[i % xs.size()]
		var mark := MeshInstance3D.new()
		mark.mesh = _mark_mesh()
		mark.material_override = _mark_material(color)
		mark.position = Vector3(x, Meshes.SHIP_DECK + HATCH + 0.006, 0)
		mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_hull_root.add_child(mark)
		var g := MeshInstance3D.new()
		var gm := BoxMesh.new()
		gm.size = Vector3(Meshes.CW * 0.94, Meshes.CH * 0.94, Meshes.CL * 0.94)
		g.mesh = gm
		g.material_override = Meshes.ghost_material(color)
		g.position = Vector3(x, Meshes.SHIP_DECK + HATCH + Meshes.CH * 0.48, 0)
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_hull_root.add_child(g)
		ghosts.append(g)
		var m := Node3D.new()
		m.position = Vector3(x, Meshes.SHIP_DECK + HATCH + 0.002, 0)
		_hull_root.add_child(m)
		markers.append(m)

	_smoke = CPUParticles3D.new()
	_smoke.amount = 10
	_smoke.lifetime = 2.2
	_smoke.mesh = _puff_mesh()
	_smoke.direction = Vector3(-0.3, 1, 0)
	_smoke.spread = 12
	_smoke.initial_velocity_min = 0.5
	_smoke.initial_velocity_max = 0.8
	_smoke.gravity = Vector3(-0.15, 0.1, 0)
	_smoke.scale_amount_min = 0.5
	_smoke.scale_amount_max = 0.9
	_smoke.scale_amount_curve = _grow_curve()
	_smoke.color = Color(1, 1, 1, 0.75)
	_smoke.position = funnel_top + Vector3(0, 0.05, 0)
	_hull_root.add_child(_smoke)

	_wake = CPUParticles3D.new()
	_wake.amount = 26
	_wake.lifetime = 1.1
	_wake.mesh = _puff_mesh()
	_wake.emitting = false
	_wake.direction = Vector3(-1, 0.4, 0)
	_wake.spread = 35
	_wake.initial_velocity_min = 0.6
	_wake.initial_velocity_max = 1.4
	_wake.gravity = Vector3(0, -1.5, 0)
	_wake.scale_amount_min = 0.5
	_wake.scale_amount_max = 1.0
	_wake.scale_amount_curve = _grow_curve()
	_wake.color = Color(1, 1, 1, 0.9)
	_wake.position = Vector3(-2.7, 0.15, 0)
	_hull_root.add_child(_wake)

static var _mark: Mesh
static var _mark_mats := {}

static func _mark_mesh() -> Mesh:
	if _mark == null:
		var pm := PlaneMesh.new()
		pm.size = Vector2(0.72, 0.72)
		_mark = pm
	return _mark

## The colour's symbol painted on a hatch, in a deeper tone of the ship's colour.
static func _mark_material(c: int) -> StandardMaterial3D:
	if not _mark_mats.has(c):
		var m := StandardMaterial3D.new()
		m.albedo_texture = Pal.symbol_tex(c % Pal.SYMBOL.size())
		m.albedo_color = Pal.cargo(c).lerp(Color("#fffaf0"), 0.15)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.roughness = 0.8
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		_mark_mats[c] = m
	return _mark_mats[c]

static func _puff_mesh() -> Mesh:
	var s := SphereMesh.new()
	s.radius = 0.18
	s.height = 0.36
	s.radial_segments = 8
	s.rings = 4
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	s.material = m
	return s

static func _grow_curve() -> Curve:
	var c := Curve.new()
	c.add_point(Vector2(0, 0.4))
	c.add_point(Vector2(0.3, 1.0))
	c.add_point(Vector2(1, 0.0))
	return c

func _process(delta: float) -> void:
	_bob_t += delta
	_dip = lerp(_dip, 0.0, delta * 5.0)
	var motion := 0.25 if Save.reduce_motion else 1.0
	_hull_root.position.y = sin(_bob_t * 1.4) * 0.04 * motion - _dip
	_hull_root.rotation.x = sin(_bob_t * 1.1) * 0.018 * motion
	_hull_root.rotation.z = sin(_bob_t * 0.8 + 1.0) * 0.009 * motion
	var pulse := 0.12 + 0.08 * (0.5 + 0.5 * sin(_bob_t * 4.0))
	for g in ghosts:
		if g.visible:
			g.scale = Vector3.ONE if Save.reduce_motion else Vector3.ONE * (0.99 + 0.01 * sin(_bob_t * 4.0))
	var gm: StandardMaterial3D = Meshes.ghost_material(color)
	gm.albedo_color.a = pulse
	if arriving:
		if not _entry_started:
			if is_instance_valid(_entry_blocker) and not _entry_blocker.lets_successor_in():
				arrive_left = maxf(0.0, _entry_blocker.entry_eta() - Time.get_ticks_msec() / 1000.0) + _entry_delay + _entry_duration
			else:
				_entry_delay = maxf(0.0, _entry_delay - delta)
				arrive_left = _entry_delay + _entry_duration
				if _entry_delay <= 0.0:
					_start_arrival()
		else:
			arrive_left = maxf(0.0, arrive_left - delta)
	if departing and not _departure_active and not arriving and pending == 0:
		_seal_left = maxf(0.0, _seal_left - delta)
		if _seal_left <= 0.0:
			_start_departure()

## Called when a container is assigned to this ship (before it lands).
func reserve(landing_after := 0.0) -> void:
	pending += 1
	_last_landing_at = maxf(_last_landing_at, Time.get_ticks_msec() / 1000.0 + landing_after)

func on_landed(slot: int) -> void:
	pending = max(0, pending - 1)
	loaded += 1
	if slot < ghosts.size():
		ghosts[slot].visible = false
	_dip = 0.045 if Save.reduce_motion else 0.085
	if loaded >= cap and not _seal_played:
		_seal_played = true
		if not Save.reduce_motion:
			_sign.scale = Vector3.ONE * 1.25
			var settle := create_tween()
			settle.tween_property(_sign, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func place_instant(at: Vector3) -> void:
	berth_pos = at
	position = at

## side: -1 = enters from the left (bow pointing right), +1 = from the right.
var side := -1

## Ships berth stern-to-stern so both bridges sit near the middle of the screen.
## side -1 (left berth): bow points left (-x); side +1: bow points right.
func face(p_side: int) -> void:
	side = p_side
	rotation.y = PI if side < 0 else 0.0

func arrive(at: Vector3, delay: float, p_side: int, predecessor: Ship = null) -> void:
	face(p_side)
	berth_pos = at
	arriving = true
	_entry_blocker = predecessor
	_entry_delay = delay
	_entry_duration = 0.32 if Save.reduce_motion else (0.58 if color % 3 == 1 else 0.54)
	_entry_started = false
	var wait := maxf(0.0, predecessor.entry_eta() - Time.get_ticks_msec() / 1000.0) if is_instance_valid(predecessor) and not predecessor.lets_successor_in() else 0.0
	arrive_left = wait + delay + _entry_duration
	# sails in along the outer channel bow-first, swinging round to berth stern-in
	position = Vector3(at.x + side * 14.0, at.y, at.z - 2.4)
	rotation.y = (0.0 if side < 0 else PI) + 0.0

func _start_arrival() -> void:
	_entry_started = true
	_wake.emitting = true
	var tw := create_tween()
	tw.tween_property(self, "position", berth_pos, _entry_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(self, "rotation:y", PI if side < 0 else 0.0, _entry_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func():
		arriving = false
		arrive_left = 0.0
		_wake.emitting = false
		_dip = 0.04 if Save.reduce_motion else 0.08)

func clear_eta() -> float:
	var now := Time.get_ticks_msec() / 1000.0
	if berth_clear:
		return now
	if _departure_active:
		return maxf(now, _clear_at)
	return maxf(now + arrive_left, _last_landing_at) + _seal_left + (0.32 if Save.reduce_motion else 0.55)

var _clear_at := 0.0
var _depart_t := 0.0

## The next ship may start its approach once this one has begun pulling away:
## it leaves on the outer lane while the newcomer comes in on the inner one.
const SUCCESSOR_GATE := 0.12

func lets_successor_in() -> bool:
	return berth_clear or (_departure_active and Time.get_ticks_msec() / 1000.0 - _depart_t >= SUCCESSOR_GATE)

func entry_eta() -> float:
	var now := Time.get_ticks_msec() / 1000.0
	if lets_successor_in():
		return now
	if _departure_active:
		return _depart_t + SUCCESSOR_GATE
	return maxf(now + arrive_left, _last_landing_at) + _seal_left + SUCCESSOR_GATE

func moving() -> bool:
	return (arriving and _entry_started) or _departure_active

## Sails toward the camera, then across the harbour mouth and away.
func depart(lane_z: float) -> void:
	departing = true
	_departure_lane = lane_z
	_seal_left = 0.06 if Save.reduce_motion else 0.12

func _start_departure() -> void:
	_departure_active = true
	_depart_t = Time.get_ticks_msec() / 1000.0
	var push_time := 0.32 if Save.reduce_motion else 0.55
	_clear_at = Time.get_ticks_msec() / 1000.0 + push_time
	departure_started.emit(self)
	_wake.emitting = true
	_smoke.amount = 18
	# pull off the quay while swinging round, then steam out past the edge of the screen
	var out_dir := float(side)
	var yaw0 := rotation.y
	var tw := create_tween()
	# ease off the quay with a slight bow-out angle, then accelerate away
	tw.tween_property(self, "position", Vector3(position.x + out_dir * 1.0, position.y, _departure_lane), push_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(self, "rotation:y", yaw0 - (0.06 if Save.reduce_motion else 0.16) * out_dir, push_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func():
		berth_clear = true
		berth_released.emit(self))
	tw.tween_property(self, "position", Vector3(position.x + out_dir * 15.0, position.y, _departure_lane - 0.4), 1.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(self, "rotation:y", yaw0, 0.65)
	tw.tween_callback(queue_free)

## Ship Liveries project: a gold band along both sides and a pennant on the funnel.
func _add_livery(model: Node3D, funnel_top: Vector3) -> void:
	var box := AABB()
	var first := true
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var b: AABB = (mi as MeshInstance3D).get_aabb()
		b = (mi as MeshInstance3D).transform * b
		box = b if first else box.merge(b)
		first = false
	if first:
		return
	var gold := Meshes.flat(Color("#ffcc3d"), 0.35, 0.2)
	for sz in [-1.0, 1.0]:
		var band := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(box.size.x * 0.86, 0.1, 0.02)
		band.mesh = bm
		band.material_override = gold
		band.position = Vector3(box.get_center().x, Meshes.SHIP_DECK - 0.22, box.get_center().z + sz * (box.size.z * 0.5 + 0.012))
		_hull_root.add_child(band)
	var pole := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.015
	cm.bottom_radius = 0.02
	cm.height = 0.7
	cm.radial_segments = 6
	pole.mesh = cm
	pole.material_override = Meshes.flat(Color("#f4f4f0"), 0.5)
	pole.position = funnel_top + Vector3(0, 0.35, 0)
	_hull_root.add_child(pole)
	var flag := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(0.3, 0.45, 0.02)
	flag.mesh = pm
	flag.material_override = gold
	flag.rotation.z = -PI / 2
	flag.position = funnel_top + Vector3(0.22, 0.58, 0)
	_hull_root.add_child(flag)
