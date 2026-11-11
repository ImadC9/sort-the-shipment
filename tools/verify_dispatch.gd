extends Node
## Behaviour-level animation regression: real inputs, landings and berth handovers.
var game: Node
var failures := 0
var launches := []
var case_id := 0
var sampled_invalid := {}

func _ready() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	add_child(game)
	# the game builds the harbour a few frames in (under the loading cover)
	while game.world == null or game.state != "title":
		await get_tree().process_frame
	await get_tree().create_timer(1.2).timeout
	game.world._ships_root.child_entered_tree.connect(_watch)
	await _play_case(2, false)
	await _play_case(9, false)
	await _play_case(19, false)
	await _play_case(99, false)
	await _undo_case()
	await _restart_case()
	await _play_case(2, true)
	print("DISPATCH_VERIFY failures=%d launch_events=%d" % [failures, launches.size()])
	get_tree().quit(0 if failures == 0 else 1)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("DISPATCH_CHECK " + message)

func _watch(node: Node) -> void:
	if not node is Ship:
		return
	var ship: Ship = node
	var token := case_id
	ship.departure_started.connect(func(vessel: Ship):
		_check(vessel.pending == 0 and vessel.loaded == vessel.cap, "launch before final cargo landed")
		_check(not vessel.arriving, "launch before docking completed")
		launches.append({"case": token, "uid": vessel.uid, "time": Time.get_ticks_msec()}))

func _process(_delta: float) -> void:
	if not game or not game.world:
		return
	for node in game.world._ships_root.get_children():
		if node is Ship and node.arriving and node._entry_started:
			var prior = node._entry_blocker
			# 1.11: the newcomer may start its approach once the previous ship has
			# begun pulling away (it leaves on the outer lane), never earlier.
			if is_instance_valid(prior) and not prior.lets_successor_in() and not sampled_invalid.has(node.get_instance_id()):
				sampled_invalid[node.get_instance_id()] = true
				_check(false, "incoming ship entered before predecessor started leaving")

func _settle() -> void:
	var end := Time.get_ticks_msec() + 16000
	while (game.world.is_busy() or (game._ending and game.state == "playing")) and Time.get_ticks_msec() < end:
		await get_tree().process_frame
	_check(Time.get_ticks_msec() < end, "visual pipeline did not settle")
	await get_tree().create_timer(0.75).timeout

func _play_case(index: int, reduced: bool) -> void:
	case_id += 1
	Save.reduce_motion = reduced
	game.start_level(index)
	await get_tree().create_timer(1.35).timeout
	var before := launches.size()
	var solution: Array = game.levels[index]["solution"]
	for tap in solution:
		var moves: int = game.model.moves
		game._on_tap(int(tap))
		_check(game.model.moves == moves + 1, "a legal rapid tap was blocked")
		await get_tree().create_timer(0.025).timeout
	await _settle()
	_check(game.state == "won" and game.model.finished, "rapid solution failed to finish")
	_check(launches.size() - before == game.model.sailed, "missing or duplicate physical departure")
	_check(game._stars_now() == 3, "stored solution lost stars")
	print("DISPATCH_CASE level=%d reduced=%s moves=%d launched=%d OK" % [index + 1, reduced, solution.size(), launches.size() - before])

func _undo_case() -> void:
	case_id += 1
	Save.reduce_motion = false
	game.start_level(2)
	await get_tree().create_timer(1.35).timeout
	var solution: Array = game.levels[2]["solution"]
	for i in 8:
		game._on_tap(int(solution[i]))
		await get_tree().create_timer(0.02).timeout
	game._undo()
	var logical_moves: int = game.model.moves
	var old_epoch: int = game.world._visual_epoch
	await get_tree().create_timer(2.0).timeout
	_check(game.model.moves == logical_moves and game.state == "playing", "stale win after undo")
	_check(not game.world.is_busy(), "undo left a queued visual job alive")
	_check(game.world._visual_epoch == old_epoch, "unexpected visual rebuild after undo")
	print("DISPATCH_UNDO during queued chain OK")

func _restart_case() -> void:
	case_id += 1
	game.start_level(2)
	await get_tree().create_timer(1.35).timeout
	for tap in game.levels[2]["solution"]:
		game._on_tap(int(tap))
		await get_tree().create_timer(0.015).timeout
	game.start_level(0)
	await get_tree().create_timer(3.0).timeout
	_check(game.current == 0 and game.model.moves == 0 and game.state == "playing", "stale chain/result changed restarted level")
	_check(not game.hud.is_modal_open(), "stale win modal after restart")
	print("DISPATCH_RESTART during winning chain OK")
