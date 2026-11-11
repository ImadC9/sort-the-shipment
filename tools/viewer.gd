extends Node3D
## Model turntable for checking Blender models under game-like lighting.
## godot --path . res://tools/viewer.tscn -- --models=a.glb,b.glb --yaw=30 --pitch=-25 --dist=9 --shot=out.png

func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=")
		args[kv[0]] = kv[1] if kv.size() > 1 else ""
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#bfe6f2")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#cfe3f2")
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.tonemap_exposure = 0.92
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.08
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 152, 0)
	sun.light_energy = 0.8
	sun.light_color = Color("#fff1dc")
	sun.shadow_enabled = true
	sun.shadow_opacity = 0.4
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-35, -30, 0)
	fill.light_energy = 0.3
	add_child(fill)
	var floor_m := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60, 60)
	floor_m.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color("#bfe3ee")
	floor_m.material_override = fm
	floor_m.position.y = float(args.get("floor", "-0.02"))
	add_child(floor_m)

	var paths: PackedStringArray = str(args.get("models", "")).split(",", false)
	var spacing := float(args.get("spacing", "6.5"))
	var tints := [Pal.cargo(0), Pal.cargo(1), Pal.cargo(2), Pal.cargo(3)]
	for i in paths.size():
		var m := ModelMats.instance("res://assets/models/" + paths[i], tints[i % tints.size()])
		m.position = Vector3((i - (paths.size() - 1) * 0.5) * spacing, 0, 0)
		add_child(m)
	var cam := Camera3D.new()
	cam.fov = float(args.get("fov", "40"))
	var yaw := deg_to_rad(float(args.get("yaw", "35")))
	var pitch := deg_to_rad(float(args.get("pitch", "-25")))
	var dist := float(args.get("dist", "12"))
	var target := Vector3(0, float(args.get("ty", "1")), 0)
	cam.position = target + Vector3(cos(pitch) * sin(yaw), -sin(pitch), cos(pitch) * cos(yaw)) * dist
	add_child(cam)
	cam.look_at(target, Vector3.UP)
	cam.current = true
	await get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(args.get("shot", "/tmp/view.png"))
	get_tree().quit()
