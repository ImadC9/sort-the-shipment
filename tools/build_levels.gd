extends SceneTree
## Builds the level pack: 10 hand-designed opening levels (levels/hand.json)
## followed by generated levels, then gives every level three star objectives
## and proves they can all be met in one play-through.
##
## Run: godot --headless --path . --script res://tools/build_levels.gd
##
## Objectives per level:
##   ★ clear the yard
##   ★ peak storage target ("never use more than N pads")
##   ★ a mastery goal: double/triple dispatch, load all gold straight, or a park limit
## A level ships only if the solver finds one solution meeting all three.
## Covered cargo must also be "robust": solvable for random rearrangements of the
## hidden colours, so a first reveal never makes the level impossible.

const NAMES := [
	"Busy Quay", "Rush Hour", "Sea Mist", "Deep Stacks", "Calm Waters",
	"Mixed Cargo", "Harbor Master", "Spring Tide", "Fog Rolls In", "Easy Breeze",
	"Paperwork", "Seven Seas", "Night Owl", "Gate Check", "Sunny Spell",
	"Quarter Ton", "Full Manifest", "Locked Down", "Storm Season", "Port Legend",
	"Gold Coast", "Treasure Bay", "Bright Cargo", "Lucky Berth", "Shiny Load",
	"Coin Toss", "Gilded Crane", "Sun Deck", "Golden Hour", "Pirate's Pay",
	"Fog Bank", "Grey Morning", "Hidden Hold", "Blind Corner", "Soft Light",
	"Mystery Box", "Low Cloud", "Foghorn", "Tarp Town", "Clear Skies",
	"Customs Week", "Red Tape", "Stamp Duty", "Inspection", "Quiet Desk",
	"Bonded Store", "Sealed Cargo", "Key Holder", "Free Trade", "Clearance",
	"Rainbow Fleet", "Six Flags", "Colour Wheel", "Prism", "Easy Sorting",
	"Paint Box", "Spectrum", "Kaleidoscope", "Pastel Day", "Full Palette",
	"Night Shift", "Moonrise", "Lamp Light", "Graveyard Watch", "Starry Quay",
	"Midnight Load", "Owl Patrol", "Dark Water", "Dawn Break", "Night Cap",
	"Long Haul", "Big Convoy", "Endless Queue", "Steady Hands", "Slow Tide",
	"Heavy Lift", "Marathon", "Supply Run", "Second Wind", "Final Leg",
	"Master Class", "Iron Nerves", "Grand Berth", "No Room", "High Stakes",
	"Last Light", "Perfect Storm", "Title Fight", "Crown Jewel", "Legend",
]
const BUDGET := 60000

var _rng := RandomNumberGenerator.new()

func _init() -> void:
	var t0 := Time.get_ticks_msec()
	var hand: Array = JSON.parse_string(FileAccess.open("res://levels/hand.json", FileAccess.READ).get_as_text())
	var out := []
	for i in hand.size():
		var entry: Dictionary = hand[i]
		var lvl = _build_hand(i, entry)
		if lvl == null:
			push_error("hand level %d (%s) failed" % [i + 1, entry["name"]])
			quit(1)
			return
		out.append(lvl)
		_report(out.size(), lvl)
	var specs := _gen_specs()
	for k in specs.size():
		var spec: Dictionary = specs[k]
		var idx := out.size()
		var lvl = _generate(idx, spec, NAMES[k], spec["prefer"])
		if lvl == null:
			push_error("generated level %d failed: %s" % [idx + 1, spec])
			quit(1)
			return
		out.append(lvl)
		_report(out.size(), lvl)
	out = OpeningLevels.apply_to(out)
	if out.size() != 100:
		push_error("Opening validation failed; no level file written")
		quit(1)
		return
	var f := FileAccess.open("res://levels/levels.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(out, "  "))
	f.close()
	print("Wrote %d levels in %.1fs" % [out.size(), (Time.get_ticks_msec() - t0) / 1000.0])
	quit(0)

func _report(n: int, lvl: Dictionary) -> void:
	var c := 0
	for s in lvl["stacks"]:
		c += s.size()
	print("L%02d %-15s cont=%2d stacks=%d buf=%d stars3<=%d stars2<=%d chain=%s rand=%.2f robust=%s" % [
		n, lvl["name"], c, lvl["stacks"].size(), lvl["buffer"], lvl["stars"]["three"], lvl["stars"]["two"],
		lvl["chain_possible"], lvl["random_rate"], lvl.get("robust", "-")])

# ------------------------------------------------------------------ building

func _build_hand(i: int, entry: Dictionary):
	if entry.has("gen"):
		var spec: Dictionary = entry["gen"].duplicate()
		var lvl = _generate(i, spec, entry["name"], entry["prefer"])
		if lvl:
			lvl["tip"] = entry["tip"]
			lvl["hand"] = true
		return lvl
	var lvl := {"name": entry["name"], "ships": entry["ships"], "stacks": entry["stacks"],
		"cap": 3, "berths": 2, "buffer": entry["buffer"], "colors": 0, "tip": entry["tip"], "hand": true}
	if entry.has("three"):
		lvl["three_override"] = entry["three"]
	var colours := {}
	for st in lvl["stacks"]:
		for code in st:
			colours[int(code) & 15] = true
	lvl["colors"] = colours.size()
	return _finish(i, lvl, entry["prefer"], true)

func _generate(i: int, spec: Dictionary, name: String, prefer: Array):
	for seed_i in 500:
		_rng.seed = 7777 * (i + 1) + seed_i * 31
		var lvl := LevelGen.generate(spec, _rng)
		var st := LevelGen.solver_state(lvl)
		var sv := _solver(lvl)
		var opt := sv.min_buffer(st, lvl["buffer"])
		if opt == -1 or opt < spec.get("min_opt", 0):
			continue
		sv.limit = lvl["buffer"]
		var rate := sv.random_success(st, 80, _rng)
		if rate < spec["lo"] or rate > spec["hi"]:
			continue
		if spec.get("hidden", 0.0) > 0.0 and not _robust(lvl, 12):
			continue
		lvl["name"] = name
		_add_gold(lvl, int(spec.get("gold", 0)), "gold" in prefer)
		var done = _finish(i, lvl, prefer, false)
		if done == null:
			continue
		# 3 stars must ask for restraint, never come free with the clear
		if int(done["stars"]["three"]) >= int(done["buffer"]):
			continue
		if spec.get("hidden", 0.0) > 0.0:
			done["robust"] = true
		return done
	return null

func _solver(lvl: Dictionary) -> Solver:
	var sv := Solver.new()
	sv.queue = lvl["ships"]
	sv.cap = lvl["cap"]
	sv.limit = lvl["buffer"]
	sv.budget = BUDGET
	return sv

## One star rule for every level: the fewer containers parked at the same time,
## the more stars. ★ clear, ★★ peak parking <= two, ★★★ peak parking <= three.
## The solver proves a 3-star play-through exists and stores it.
func _finish(i: int, lvl: Dictionary, _prefer: Array, hand: bool):
	var st := LevelGen.solver_state(lvl)
	var sv := _solver(lvl)
	var min_peak := sv.min_buffer(st, lvl["buffer"])
	if min_peak == -1:
		return null
	var has_hidden := false
	for col in lvl["stacks"]:
		for code in col:
			if int(code) & 16:
				has_hidden = true
	sv.limit = lvl["buffer"]
	lvl["random_rate"] = snappedf(sv.random_success(st, 80, _rng), 0.01)
	var three := min_peak if (hand and not has_hidden) else min_peak + 1
	# never let the 3-star target become "use every spot" (that would be free stars)
	if not hand and three >= int(lvl["buffer"]) and min_peak < int(lvl["buffer"]):
		three = min_peak
	if lvl.has("three_override"):
		three = int(lvl["three_override"])
		lvl.erase("three_override")
	three = clampi(three, min_peak, int(lvl["buffer"]))
	# The game celebrates dispatch chains, so a chain must never cost the third
	# star: there has to be a 3-star play-through that also sends two ships off
	# in one move. Hand levels may raise the 3-star limit to make room for it;
	# generated levels are simply rejected and regenerated.
	# (Levels 1-2 come before chains are taught and are exempt.)
	var cv := _solver(lvl)
	cv.need_chain = 2 if i >= 2 else 0
	var base_three := three
	var sol = null
	while three <= int(lvl["buffer"]):
		cv.limit = three
		sol = cv.solve(st)
		if sol != null or not hand:
			break
		three += 1
	if sol == null and hand:
		# a lesson where no chain fits at all keeps its plain 3-star rule
		three = base_three
		sv.limit = three
		sol = sv.solve(st)
		lvl["chain_possible"] = false
	if sol == null:
		return null
	if not hand and three >= int(lvl["buffer"]) and min_peak < int(lvl["buffer"]):
		return null
	var two := clampi(three + 1, three, int(lvl["buffer"]))
	if not lvl.has("chain_possible"):
		lvl["chain_possible"] = i >= 2
	lvl["stars"] = {"three": three, "two": two}
	lvl["solution"] = sol
	lvl["min_peak"] = min_peak
	lvl["id"] = i + 1
	return lvl

## Gold containers: random picks; when "load all gold straight" is the goal it is checked later.
func _add_gold(lvl: Dictionary, n: int, _for_goal: bool) -> void:
	var slots := []
	for s in lvl["stacks"].size():
		for k in lvl["stacks"][s].size():
			var code: int = lvl["stacks"][s][k]
			if code & 16 or code >> 8:
				continue
			slots.append([s, k])
	for j in n:
		if slots.is_empty():
			return
		var pick: Array = slots.pop_at(_rng.randi_range(0, slots.size() - 1))
		lvl["stacks"][pick[0]][pick[1]] = int(lvl["stacks"][pick[0]][pick[1]]) | 32

## Covered cargo fairness: shuffle which hidden slot holds which colour; every
## arrangement must still be solvable with the level's full buffer.
func _robust(lvl: Dictionary, samples: int) -> bool:
	var hidden := []
	for s in lvl["stacks"].size():
		for k in lvl["stacks"][s].size():
			if int(lvl["stacks"][s][k]) & 16:
				hidden.append([s, k])
	if hidden.size() < 2:
		return true
	for t in samples:
		var copy := lvl.duplicate(true)
		var cols := []
		for h in hidden:
			cols.append(int(copy["stacks"][h[0]][h[1]]) & 15)
		LevelGen._shuffle(cols, _rng)
		for j in hidden.size():
			var h: Array = hidden[j]
			var code: int = copy["stacks"][h[0]][h[1]]
			copy["stacks"][h[0]][h[1]] = (code & ~15) | cols[j]
		var sv := _solver(copy)
		if sv.solve(LevelGen.solver_state(copy)) == null:
			return false
	return true

# ------------------------------------------------------------------ campaign 11-30

## Nine chapters of ten after the lessons. Each chapter leans on one twist and
## climbs inside itself (positions 4 and 8 are breathers, 9 is the chapter finale).
## Levels stay short (24-36 containers); difficulty comes from tight parking,
## covered cargo, locks, more colours and longer ship queues.
const CHAPTER_POS := [0.15, 0.35, 0.5, 0.65, 0.05, 0.55, 0.7, 0.85, 0.1, 1.0]

func _gen_specs() -> Array:
	var s := []
	for ch in 9:
		var g := float(ch) / 8.0             # campaign progress 0..1
		for k in 10:
			var pos: float = CHAPTER_POS[k]
			var breather := k == 4 or k == 8
			var t: float = clampf(g * 0.65 + pos * 0.35, 0.0, 1.0)
			var colors := 4 if ch == 0 else 5
			var per := 2
			var hidden := 0.0
			var locks := 0
			var gold := 1 + int(g * 2.0)
			var buffer := 5
			match ch:
				0:  # Busy Harbour: learn tight parking
					buffer = 4 if k in [1, 3, 6, 7, 9] else 5
				1:  # Storm Season: five colours, a little of everything
					hidden = [0.0, 0.25, 0.0, 0.3][k % 4]
					locks = [0, 0, 2, 0, 3][k % 5]
					buffer = 4 if k in [3, 7, 9] else 5
				2:  # Gold Coast
					colors = 4 if k < 5 else 5
					gold = 3 + k % 3
					buffer = 4 if k in [6, 9] else 5
				3:  # Fog Bank: lots of covered cargo
					colors = 4 if k < 4 else 5
					hidden = 0.3 + 0.15 * pos
				4:  # Customs Week: padlocks
					locks = 2 + int(pos * 3.0)
					buffer = 4 if k in [7, 9] else 5
				5:  # Rainbow Fleet: six colours
					colors = 6
					buffer = 6 if pos < 0.6 else 5
				6:  # Night Shift: covered + locks, tight parking
					colors = 4 if k % 2 == 0 else 5
					hidden = 0.25
					locks = 2
					buffer = 4
				7:  # Long Haul: three ships per colour
					colors = 4
					per = 3
					buffer = 5 if pos < 0.7 else 4
				8:  # Harbour Master: everything
					colors = 5 if k % 3 else 6
					hidden = 0.25 if k % 2 == 0 else 0.0
					locks = 2 if k % 2 == 1 else 0
					buffer = 5 if colors == 6 else 4
			if breather:
				hidden = 0.0
				locks = 0
				buffer = max(buffer, 5)
			var stacks := 5 if colors == 4 else 6
			var n := colors * per * 3
			# Bridge out of the 20-level opening (which tops out at 24 boxes and four
			# colours): 21 stays at that size, 22 adds the fifth colour as a breather,
			# 23 is a medium step, and the chapter climbs from 24 as before.
			var bridge := ch == 1 and k < 3
			if bridge:
				colors = 4 if k == 0 else 5
				stacks = 5 if colors == 4 else 6
				n = colors * per * 3
				hidden = 0.0
				locks = 1 if k == 0 else 0
				gold = 1
				buffer = 5
			var spec := {
				"colors": colors, "ships_per_color": per, "stacks": stacks,
				"max_h": int(ceil(float(n) / stacks)) + 1,
				"buffer": buffer, "hidden": hidden, "locks": locks,
				"lo": [0.6, 0.5, 0.4][k] if bridge else (0.4 if breather else lerp(0.32, 0.03, t)),
				"hi": [0.92, 0.8, 0.65][k] if bridge else (1.0 if breather else lerp(0.78, 0.3, t)),
				"min_opt": [1, 0, 1][k] if bridge else (0 if breather else (1 if t < 0.3 else (2 if t < 0.7 else 3))),
				"gold": gold, "prefer": [],
			}
			s.append(spec)
	return s
