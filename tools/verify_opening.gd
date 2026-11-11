extends SceneTree

func _initialize() -> void:
	var levels: Array = JSON.parse_string(FileAccess.get_file_as_string("res://levels/levels.json"))
	var fairness: Array = JSON.parse_string(FileAccess.get_file_as_string("res://levels/opening_fairness.json"))
	var failures := 0
	var checked := 0
	for proof in fairness:
		for variant in proof["cases"]:
			var level: Dictionary = levels[int(proof["level"]) - 1].duplicate(true)
			level["stacks"] = variant["stacks"]
			var game := GameModel.new()
			game.setup(level)
			for tap in variant["solution"]:
				var events := game.tap(int(tap))
				if events.size() == 1 and events[0]["t"] == "refuse":
					failures += 1
			if not game.finished or game.peak > int(variant["three"]):
				failures += 1
			checked += 1
	print("OPENING_FAIRNESS variants=%d failures=%d" % [checked, failures])
	quit(0 if failures == 0 else 1)
