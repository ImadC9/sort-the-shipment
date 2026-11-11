class_name LevelGen
extends RefCounted
## Builds random yard layouts from a difficulty spec. Every level that ships
## in the game is checked by the solver at build time (tools/build_levels.gd).

static func generate(spec: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var colors: int = spec["colors"]
	var per_color: int = spec["ships_per_color"]
	var cap: int = spec.get("cap", 3)
	var n_stacks: int = spec["stacks"]
	var max_h: int = spec["max_h"]
	var hidden_p: float = spec.get("hidden", 0.0)
	var locks: int = spec.get("locks", 0)

	var pool := []
	for c in colors:
		for i in per_color * cap:
			pool.append(c)
	_shuffle(pool, rng)

	# deal containers into stacks, keeping heights fairly even but not identical
	var stacks := []
	for i in n_stacks:
		stacks.append([])
	for code in pool:
		var choices := []
		var min_h := 999
		for s in n_stacks:
			min_h = min(min_h, stacks[s].size())
		for s in n_stacks:
			if stacks[s].size() < max_h and stacks[s].size() <= min_h + 1:
				choices.append(s)
		if choices.is_empty():
			for s in n_stacks:
				if stacks[s].size() < max_h:
					choices.append(s)
		var s: int = choices[rng.randi_range(0, choices.size() - 1)]
		stacks[s].append(code)

	# hidden containers (never the top one)
	if hidden_p > 0.0:
		for s in n_stacks:
			for i in stacks[s].size() - 1:
				if rng.randf() < hidden_p:
					stacks[s][i] = stacks[s][i] | 16

	# ship queue
	var ships := []
	for c in colors:
		for i in per_color:
			ships.append(c)
	_shuffle(ships, rng)
	if ships.size() > 1 and ships[0] == ships[1]:
		for i in range(2, ships.size()):
			if ships[i] != ships[0]:
				var t = ships[1]
				ships[1] = ships[i]
				ships[i] = t
				break

	# locked containers: buried mid-stack, open after a few ships sail
	var total_ships := ships.size()
	var placed := 0
	var guard := 0
	while placed < locks and guard < 200:
		guard += 1
		var s := rng.randi_range(0, n_stacks - 1)
		if stacks[s].size() < 2:
			continue
		var i := rng.randi_range(0, stacks[s].size() - 1)
		if (stacks[s][i] >> 8) > 0:
			continue
		var need := rng.randi_range(1, clampi(total_ships / 3, 1, 4))
		stacks[s][i] = stacks[s][i] | (need << 8)
		placed += 1

	return {
		"stacks": stacks, "ships": ships, "cap": cap,
		"berths": spec.get("berths", 2), "buffer": spec["buffer"],
		"colors": colors,
	}

static func _shuffle(a: Array, rng: RandomNumberGenerator) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t

## Converts a stored level to the solver's state format.
static func solver_state(level: Dictionary) -> Dictionary:
	var m := GameModel.new()
	m.setup(level)
	return m.to_solver_state()
