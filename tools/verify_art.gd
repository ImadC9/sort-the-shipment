extends SceneTree
## Checks the renderer-specific colour conversion, masks, mesh and LOD retention.

func _initialize() -> void:
	call_deferred("_verify")

func _verify() -> void:
	var failures := 0
	var count := 0
	var total_lods := 0
	var source_path := "res://assets/models/"
	for file in DirAccess.get_files_at(source_path):
		if not file.ends_with(".glb"):
			continue
		var scene: PackedScene = load(source_path + file)
		var model := scene.instantiate()
		for child in model.find_children("*", "MeshInstance3D", true, false):
			var original: Mesh = child.mesh
			var prepared := ModelMats._prepare_mesh(original)
			if prepared.get_surface_count() != original.get_surface_count():
				failures += 1
			if ModelMats._prepare_mesh(prepared) != prepared:
				failures += 1
			for si in original.get_surface_count():
				var before := original.surface_get_arrays(si)
				var after := prepared.surface_get_arrays(si)
				var positions: PackedVector3Array = before[Mesh.ARRAY_VERTEX]
				var new_positions: PackedVector3Array = after[Mesh.ARRAY_VERTEX]
				if positions.size() != new_positions.size():
					failures += 1
				var colours: PackedColorArray = before[Mesh.ARRAY_COLOR]
				var result: PackedColorArray = after[Mesh.ARRAY_COLOR]
				for vi in colours.size():
					var want := colours[vi].linear_to_srgb()
					if absf(result[vi].r - want.r) > 0.006 or absf(result[vi].g - want.g) > 0.006 or absf(result[vi].b - want.b) > 0.006 or absf(result[vi].a - colours[vi].a) > 0.006:
						failures += 1
						break
				var old_lods: Array = RenderingServer.mesh_get_surface(original.get_rid(), si).get("lods", [])
				var new_lods: Array = RenderingServer.mesh_get_surface(prepared.get_rid(), si).get("lods", [])
				total_lods += old_lods.size()
				if old_lods.size() != new_lods.size():
					failures += 1
		count += 1
		model.free()
	print("ART_VERIFY models=%d preserved_LODs=%d failures=%d" % [count, total_lods, failures])
	quit(0 if failures == 0 and count == 23 else 1)
