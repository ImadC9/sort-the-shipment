extends Node3D
## Renders the app icon art (stacked containers and a ship) on a transparent
## background. Composited into store and launcher icons by tools/make_icons.py.
## godot --path . res://tools/icon.tscn -- --shot=out.png

func _ready() -> void:
	var out := "icon_art.png"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			out = a.trim_prefix("--shot=")
	get_viewport().transparent_bg = true
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#dfe9f7")
	env.ambient_light_energy = 0.3
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.1
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-44, 160, 0)
	sun.light_energy = 0.42
	sun.light_color = Color("#fff4e2")
	sun.shadow_enabled = true
	sun.shadow_opacity = 0.5
	add_child(sun)
	# three toy containers, door ends and symbols towards the camera
	var boxes := [[0, Vector3(-0.56, 0, 0)], [1, Vector3(0.56, 0, 0)], [2, Vector3(0.0, Meshes.CH, 0)]]
	for b in boxes:
		var m := MeshInstance3D.new()
		m.mesh = Meshes.container_mesh()
		m.material_override = Meshes.cargo_material(b[0])
		m.position = b[1]
		add_child(m)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 3.3
	cam.position = Vector3(-3.4, 4.6, -5.6)
	add_child(cam)
	cam.look_at(Vector3(0, 0.74, 0), Vector3.UP)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out)
	get_tree().quit()
