extends Node
## Inspect the built geometry, rather than trusting the authored height constants.

func _ready() -> void:
	call_deferred("_verify")

func _verify() -> void:
	var port := World.new()
	port._build_port()
	var ground_y := 1000.0
	var large_faces: Array[float] = []
	for child in port.get_children():
		if not child is MeshInstance3D:
			continue
		var mi: MeshInstance3D = child
		if mi.mesh is PlaneMesh and is_equal_approx((mi.mesh as PlaneMesh).size.x, 80.0):
			ground_y = mi.position.y
		if not mi.mesh is ArrayMesh:
			continue
		for si in mi.mesh.get_surface_count():
			var arrays := mi.mesh.surface_get_arrays(si)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var count := indices.size() if not indices.is_empty() else verts.size()
			for ti in range(0, count, 3):
				var a := verts[indices[ti] if not indices.is_empty() else ti] + mi.position
				var b := verts[indices[ti + 1] if not indices.is_empty() else ti + 1] + mi.position
				var c := verts[indices[ti + 2] if not indices.is_empty() else ti + 2] + mi.position
				if absf(a.y - b.y) < 0.0001 and absf(a.y - c.y) < 0.0001 and (b - a).cross(c - a).length() > 100.0:
					large_faces.append(a.y)
	var overlaps := 0
	for height in large_faces:
		if absf(height - ground_y) < 0.02:
			overlaps += 1
	print("GROUND_VERIFY ground_y=%.3f wide_structure_faces=%s overlapping_faces=%d" % [ground_y, large_faces, overlaps])
	port.free()
	get_tree().quit(0 if ground_y < 999.0 and overlaps == 0 else 1)
