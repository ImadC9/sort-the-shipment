class_name Cargo
extends Node3D
## One shipping container: visuals plus a crane-style flight to a moving target.

signal landed(cargo)

## containers are moved under this node while in the air
static var fly_root: Node3D

var id := 0
var color := 0
var hidden := false
var lock_left := 0

var body: MeshInstance3D
var _lock: Node3D
var _lock_label: Label3D

var gold := false
var _gold_nodes: Array[Node3D] = []
var flying := false
var _from := Vector3.ZERO
var _from_basis := Basis()
var _from_scale := 1.0
var _target: Node3D
var _t := 0.0
var _dur := 0.5
var _arc := 2.5
var _waiting_ship: Ship
var _hold_t := 0.0
var _shake := 0.0
var _hl := false

func setup(p_id: int, p_color: int, p_hidden: bool, p_lock: int) -> void:
	id = p_id
	color = p_color
	hidden = p_hidden
	lock_left = p_lock
	body = MeshInstance3D.new()
	body.mesh = Meshes.container_lod_mesh()
	add_child(body)
	_refresh_look()
	if lock_left > 0:
		_add_lock()

var _full := false

func _refresh_look() -> void:
	if hidden:
		body.mesh = Meshes.tarp_mesh()
		body.material_override = Meshes.tarp_material()
	else:
		body.mesh = Meshes.container_mesh() if _full else Meshes.container_lod_mesh()
		body.material_override = Meshes.cargo_material(color, _hl)

## Gold bonus cargo: a star sticker and sparkles; pays out only if loaded straight onto a ship.
func set_gold(on: bool, fade: bool) -> void:
	if on == gold:
		return
	gold = on
	if on:
		# the frame turns to polished gold (see cargo.gdshader) and a coin sits on the door
		body.set_instance_shader_parameter("gold", 1.0)
		for pos_rot in [[Vector3(0.0, Meshes.CH + 0.05, 0.62), Vector3(-PI / 2, PI, 0), 0.0030], [Vector3(0.3, Meshes.CH * 0.74, -Meshes.CL * 0.5 - 0.03), Vector3(0, PI, 0), 0.0026]]:
			var st := Sprite3D.new()
			st.texture = load("res://assets/ui/coin.png")
			st.pixel_size = pos_rot[2]
			st.position = pos_rot[0]
			st.rotation = pos_rot[1]
			st.shaded = false
			st.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			add_child(st)
			_gold_nodes.append(st)
		var sp := CPUParticles3D.new()
		sp.amount = 6
		sp.lifetime = 1.0
		var q := BoxMesh.new()
		q.size = Vector3(0.06, 0.06, 0.06)
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color("#fff3a0")
		q.material = m
		sp.mesh = q
		sp.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		sp.emission_box_extents = Vector3(0.5, 0.05, 0.9)
		sp.direction = Vector3.UP
		sp.spread = 20
		sp.gravity = Vector3.ZERO
		sp.initial_velocity_min = 0.3
		sp.initial_velocity_max = 0.7
		sp.angular_velocity_min = -200
		sp.angular_velocity_max = 200
		var curve := Curve.new()
		curve.add_point(Vector2(0, 0))
		curve.add_point(Vector2(0.3, 1))
		curve.add_point(Vector2(1, 0))
		sp.scale_amount_curve = curve
		sp.position = Vector3(0, Meshes.CH + 0.05, 0)
		add_child(sp)
		_gold_nodes.append(sp)
		set_highlight(true)
	else:
		set_highlight(false)
		body.set_instance_shader_parameter("gold", 0.0)
		for n in _gold_nodes:
			if not is_instance_valid(n):
				continue
			if fade and n is Sprite3D:
				var l: Sprite3D = n
				var tw := l.create_tween().set_parallel(true)
				tw.tween_property(l, "modulate", Color(0.6, 0.62, 0.66, 0.0), 0.5)
				tw.tween_property(l, "position:y", l.position.y + 0.5, 0.5)
				tw.chain().tween_callback(l.queue_free)
			else:
				n.queue_free()
		_gold_nodes.clear()

func set_highlight(on: bool) -> void:
	_hl = on or gold
	if not hidden:
		body.material_override = Meshes.cargo_material(color, on)

func _add_lock() -> void:
	_lock = Node3D.new()
	_lock.position = Vector3(0, Meshes.CH * 0.47, -Meshes.CL * 0.5 - 0.04)
	_lock.rotation.y = PI
	# a steel band across the doors with the padlock in the middle
	var chain := MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = Vector3(Meshes.CW * 0.98, 0.075, 0.03)
	chain.mesh = cm
	chain.material_override = Meshes.flat(Color("#2c4763"), 0.5, 0.0)
	chain.position = Vector3(0, 0, -0.02)
	_lock.add_child(chain)
	var pm := MeshInstance3D.new()
	pm.mesh = Meshes.padlock_mesh()
	pm.material_override = ModelMats.material("Fixed")
	pm.scale = Vector3.ONE * 1.5
	pm.position = Vector3(0, -0.03, 0.04)
	_lock.add_child(pm)
	_lock_label = Label3D.new()
	_lock_label.font = Pal.font_display()
	_lock_label.font_size = 56
	_lock_label.outline_size = 0
	_lock_label.pixel_size = 0.0058
	_lock_label.modulate = Pal.INK
	_lock_label.position = Vector3(0, -0.035, 0.14)
	_lock_label.shaded = false
	_lock.add_child(_lock_label)
	add_child(_lock)
	update_lock(0)
	set_sym_dim(true)

func set_sym_dim(on: bool) -> void:
	if hidden:
		return
	var a := 0.4 if on else 1.0
	body.set_instance_shader_parameter("end_symbol_alpha", a)

func update_lock(sailed: int) -> void:
	if _lock_label:
		_lock_label.text = str(max(1, lock_left - sailed))

func unlock() -> void:
	if _lock == null:
		return
	var l := _lock
	_lock = null
	_lock_label = null
	lock_left = 0
	set_sym_dim(false)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(l, "position", l.position + Vector3(0, 0.9, -0.6), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "rotation", Vector3(0.4, 1.2, 2.0), 0.45)
	tw.tween_property(l, "scale", Vector3.ONE * 0.01, 0.45).set_delay(0.1)
	tw.chain().tween_callback(l.queue_free)

func reveal() -> void:
	if not hidden:
		return
	var tw := create_tween()
	tw.tween_property(body, "scale", Vector3(1.15, 0.05, 1.05), 0.12).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(func():
		hidden = false
		_refresh_look())
	tw.tween_property(body, "scale", Vector3.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func is_locked() -> bool:
	return _lock != null

## Flies to a target node, following it if it moves (e.g. a ship still arriving).
## Full detail when the box is on top of a stack, in the air or on a ship;
## buried boxes use the light model (their detail is hidden anyway).
func set_detail(full: bool) -> void:
	_full = full
	var want := Meshes.tarp_mesh() if hidden else (Meshes.container_mesh() if full else Meshes.container_lod_mesh())
	if body.mesh != want:
		body.mesh = want
	# the door-end symbol only matters on exposed boxes; buried ones keep just the roof mark
	# only exposed boxes need to cast their own shadow
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if full else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func fly_to(target: Node3D, duration: float, arc: float, vessel: Ship = null) -> void:
	set_detail(true)
	_from = global_position
	_from_basis = global_transform.basis.orthonormalized()
	_from_scale = global_transform.basis.get_scale().x
	_target = target
	_t = 0.0
	_dur = minf(duration, 0.30) if Save.reduce_motion else duration
	_arc = minf(arc, 0.65) if Save.reduce_motion else arc
	_waiting_ship = vessel if is_instance_valid(vessel) and vessel.arriving else null
	_hold_t = 0.0
	flying = true
	var root: Node3D = fly_root
	if root and get_parent() != root:
		var gt := global_transform
		get_parent().remove_child(self)
		root.add_child(self)
		global_transform = gt
	_attach_rig()

## Spreader and hoist cables, so each lift reads as a crane move.
var _rig: Node3D

func _attach_rig() -> void:
	if _rig and is_instance_valid(_rig):
		return
	_rig = Node3D.new()
	var sp := MeshInstance3D.new()
	sp.mesh = Meshes.spreader_mesh()
	sp.material_override = ModelMats.material("Fixed")
	sp.position = Vector3(0, Meshes.CH + 0.01, 0)
	_rig.add_child(sp)
	# short hoist cables that fade out above, so several lifts don't criss-cross the screen
	var low := BoxMesh.new()
	low.size = Vector3(0.026, 2.2, 0.026)
	var high := BoxMesh.new()
	high.size = Vector3(0.02, 2.4, 0.02)
	var fade := StandardMaterial3D.new()
	fade.albedo_color = Color(0.17, 0.28, 0.39, 0.3)
	fade.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fade.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for sz in [-0.55, 0.55]:
		var c := MeshInstance3D.new()
		c.mesh = low
		c.material_override = Meshes.flat(Color("#2c4763"), 0.6, 0.0)
		c.position = Vector3(0, Meshes.CH + 1.15, sz)
		c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_rig.add_child(c)
		var c2 := MeshInstance3D.new()
		c2.mesh = high
		c2.material_override = fade
		c2.position = Vector3(0, Meshes.CH + 3.45, sz)
		c2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_rig.add_child(c2)
	_rig.position = Vector3(0, 6.0, 0)
	add_child(_rig)
	var tw := _rig.create_tween()
	tw.tween_property(_rig, "position", Vector3.ZERO, min(0.12, _dur * 0.25)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _release_rig() -> void:
	if _rig == null or not is_instance_valid(_rig):
		return
	var r := _rig
	_rig = null
	var gt := r.global_transform
	remove_child(r)
	if fly_root:
		fly_root.add_child(r)
	else:
		get_parent().add_child(r)
	r.global_transform = gt
	r.rotation = Vector3.ZERO
	var tw := r.create_tween()
	tw.tween_interval(0.06)
	tw.tween_property(r, "position", r.position + Vector3(0, 2.2, 0), 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(r, "scale", Vector3(0.6, 0.6, 0.6), 0.3)
	tw.tween_callback(r.queue_free)

func shake() -> void:
	_shake = 0.35

func pop() -> void:
	var tw := create_tween()
	body.scale = Vector3.ONE if Save.reduce_motion else Vector3(1.045, 0.94, 1.045)
	tw.tween_property(body, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _process(delta: float) -> void:
	if _shake > 0.0:
		_shake = max(0.0, _shake - delta)
		body.position.x = sin(_shake * 70.0) * 0.08 * (_shake / 0.35)
	elif body and body.position.x != 0.0:
		body.position.x = 0.0
	if not flying:
		return
	if not is_instance_valid(_target):
		flying = false
		return
	# Pick up immediately, but hold locally while the berth is being cleared.
	# Following an off-screen queued ship made boxes fly away from the yard.
	if is_instance_valid(_waiting_ship):
		if _waiting_ship.arriving and _waiting_ship.arrive_left > 0.40:
			_hold_t = minf(1.0, _hold_t + delta / 0.18)
			global_position = _from + Vector3(0, (0.12 if Save.reduce_motion else 0.42) * _ease(_hold_t), 0)
			return
		_waiting_ship = null
		_from = global_position
		_from_basis = global_transform.basis.orthonormalized()
	_t = min(1.0, _t + delta / _dur)
	var k := _ease(_t)
	var to := _target.global_position
	var p := _from.lerp(to, k)
	# crane-like path: lift first, travel, then lower
	var height: float = max(_from.y, to.y) + _arc
	var up := sin(PI * k)
	p.y = lerp(_from.y, to.y, k) + (height - lerp(_from.y, to.y, k)) * pow(up, 0.6)
	global_position = p
	var tgb := _target.global_transform.basis
	var tb := tgb.orthonormalized()
	var sc: float = lerp(_from_scale, tgb.get_scale().x, k)
	global_transform.basis = Basis(_from_basis.get_rotation_quaternion().slerp(tb.get_rotation_quaternion(), k)).scaled(Vector3.ONE * sc)
	# a little swing while travelling
	body.rotation.z = 0.0 if Save.reduce_motion else sin(_t * PI * 2.0) * 0.035 * (1.0 - _t)
	if _t >= 1.0:
		flying = false
		body.rotation.z = 0.0
		var gt := _target.global_transform
		get_parent().remove_child(self)
		_target.add_child(self)
		global_transform = gt
		transform = Transform3D.IDENTITY
		_release_rig()
		pop()
		landed.emit(self)

func _ease(x: float) -> float:
	return x * x * (3.0 - 2.0 * x)
