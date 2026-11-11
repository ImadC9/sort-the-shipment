class_name OpeningLevels
extends RefCounted
## Twenty explicit authored layouts; no regeneration of the later campaign.

static func apply_to(existing: Array) -> Array:
	var definitions: Array = JSON.parse_string(FileAccess.get_file_as_string("res://levels/opening_design.json"))
	assert(definitions.size() == 20 and existing.size() == 100)
	var result := existing.duplicate(true)
	for i in definitions.size():
		var d: Dictionary = definitions[i]
		var level := {"id": i + 1, "name": d["name"], "ships": d["ships"], "stacks": d["stacks"], "buffer": d["buffer"],
			"berths": 2, "cap": 3, "hand": true, "lesson": d["lesson"], "opening_revision": 3}
		if d.has("tip"):
			level["tip"] = d["tip"]
		var counts := {}
		for stack in level["stacks"]:
			assert(stack.size() <= 6)
			for code in stack:
				var colour := int(code) & 15
				counts[colour] = counts.get(colour, 0) + 1
		for colour in counts:
			var boats := 0
			for ship_colour in level["ships"]:
				if int(ship_colour) == colour:
					boats += 1
			assert(counts[colour] == boats * 3)
		level["colors"] = counts.size()
		var solver := Solver.new()
		solver.queue = level["ships"]
		solver.cap = 3
		solver.budget = 500000
		var start := LevelGen.solver_state(level)
		var minimum := solver.min_buffer(start, level["buffer"])
		var three := int(d["three"])
		assert(minimum >= 0 and three >= minimum and three <= int(level["buffer"]))
		solver.limit = three
		solver.need_chain = 2 if i >= 2 else 0
		var solution = solver.solve(start)
		level["chain_possible"] = solution != null and i >= 2
		if solution == null:
			solver.need_chain = 0
			solution = solver.solve(start)
		assert(solution != null)
		level["solution"] = solution
		level["min_peak"] = minimum
		level["stars"] = {"three": three, "two": mini(three + 1, int(level["buffer"]))}
		var rng := RandomNumberGenerator.new()
		rng.seed = 32100 + i
		solver.limit = level["buffer"]
		level["random_rate"] = snappedf(solver.random_success(start, 400, rng), 0.001)
		result[i] = level
		print("OPENING L%02d %-20s moves=%d min=%d three=%d chain=%s random_clear=%.3f" % [i + 1, level["name"], solution.size(), minimum, three, level["chain_possible"], level["random_rate"]])
	return result
