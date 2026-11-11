extends SceneTree

func _initialize() -> void:
	var levels: Array = JSON.parse_string(FileAccess.get_file_as_string("res://levels/levels.json"))
	var updated := OpeningLevels.apply_to(levels)
	if updated.size() != 100:
		push_error("Opening validation failed; original level file retained")
		quit(1)
		return
	var file := FileAccess.open("res://levels/levels.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(updated, "  "))
	file.close()
	print("OPENING_BUILT 20 authored levels; levels 21-100 retained")
	quit()
