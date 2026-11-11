extends Node
## Game controller: menus, level flow, star goals, dispatch chains, boosters,
## rewards, harbour projects and resume-in-progress.

const UNDOS_PER_LEVEL := 3
const MAX_SPOTS := 8
const CHAIN_BONUS_PER_SHIP := 15

var world: World
var hud: Hud
var model: GameModel
var levels: Array = []
var current := 0
var _first_title := true
var history: Array = []          # [{model, earned}] one per move, for undo
var undos := UNDOS_PER_LEVEL
var state := "title"             # title | intro | playing | won | lost
var _ending := false
var _tutorial_steps := 0
var _free_hint := true
var _assisted := false           # used undo / hint / extra slot this attempt
var _last_free := 99
var _stamps_quiet_until := 0
var _chains_this_level := 0
var _attempt := 0                # bumped for every new attempt; stale callbacks check it
var _extra_slots := 0            # parking spots bought this attempt (survive undo)
var _ad_rescue_used := false     # one ad rescue per attempt
const RESUME_HISTORY := 3        # undo steps kept across app restarts


func _ready() -> void:
	var args := _parse_args()
	# Normal start: show the loading cover first (it continues the boot splash),
	# then build the harbour a step at a time so the bar can move.
	var cover: LoadingCover = null
	if args.is_empty():
		cover = LoadingCover.new()
		add_child(cover)
		cover.set_progress(0.12)
		await get_tree().process_frame
		await get_tree().process_frame
	var f := FileAccess.open("res://levels/levels.json", FileAccess.READ)
	levels = JSON.parse_string(f.get_as_text())
	world = World.new()
	add_child(world)
	if cover:
		cover.set_progress(0.5)
		await get_tree().process_frame
	hud = Hud.new()
	add_child(hud)
	for l in levels:
		hud.level_names.append(l["name"])
	model = GameModel.new()
	world.stack_tapped.connect(_on_tap)
	world.popup.connect(func(t, p, c, big): hud.popup(t, p, c, big))
	world.ship_loaded.connect(_on_ship_loaded)
	world.landed_direct.connect(_on_landed_direct)
	world.dispatch_chain_started.connect(_on_chain_launched)
	world.gold_bonus.connect(_on_gold_bonus)
	hud.play_pressed.connect(_on_play)
	hud.level_chosen.connect(start_level)
	hud.next_pressed.connect(_on_next)
	hud.retry_pressed.connect(func(): start_level(current))
	hud.undo_pressed.connect(_undo)
	hud.hint_pressed.connect(_hint)
	hud.continue_pressed.connect(func(): _extra_slot(true))
	hud.home_pressed.connect(_go_title)
	hud.project_built.connect(_on_project_built)
	hud.ad_rescue_pressed.connect(_ad_rescue)
	Ads.availability_changed.connect(_refresh_hint_badge)
	if args.is_empty():
		cover.set_progress(0.65)
		_go_title()
		# Let the first frames of the harbour render under the cover: on phones
		# this is where shaders compile, which used to be the blank pause.
		for i in 6:
			cover.set_progress(0.7 + 0.05 * i)
			await get_tree().process_frame
		await cover.finish()
		Sfx.music_on()
	else:
		Sfx.music_on()
		var harness := DevHarness.new()
		add_child(harness)
		harness.run(self, args)

## Android back button: leave a level for the title, or quit from the title.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		# back closes a popup or steps a menu tab home; in a level it pauses
		if hud and hud.handle_back():
			return
		if state == "playing" and not hud.is_modal_open():
			hud.show_pause()
		elif state in ["playing", "won", "lost", "intro"]:
			_go_title()
		else:
			get_tree().quit()
	elif what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_resume()
		Save.save_data()

# ================================================================= flow

func _go_title() -> void:
	if state == "playing":
		_save_resume()
	_attempt += 1   # anything still pending for the level just left is void
	hud.flash_transition()
	state = "title"
	world.input_enabled = false
	world.hide_hint()
	current = clampi(Save.unlocked - 1, 0, levels.size() - 1)
	world.set_atmosphere_for_level(current)
	model.setup(levels[current])
	world.load_model(model, false)
	world.set_gold(model.gold_ids())
	world.set_menu_view(true, _first_title)
	_first_title = false
	hud.show_title(Save.unlocked, levels.size())

func _on_play() -> void:
	if not Save.resume.is_empty() and _resume():
		return
	start_level(Save.unlocked - 1)

func _on_next() -> void:
	if current == levels.size() - 1:
		Save.campaign_done = true
		Save.save_data()
		state = "title"
		hud.show_campaign_complete(Save.total_stars(), levels.size() * 3, Save.chains)
		return
	var nxt := current + 1
	Ads.level_break(Save.stars.size(), func(): start_level(nxt))

## Sets the level up and starts straight away; lesson levels show a coach tip.
func start_level(i: int) -> void:
	current = clampi(i, 0, levels.size() - 1)
	Save.resume = {}
	_setup_attempt()
	model.setup(levels[current])
	world.set_atmosphere_for_level(current)
	world.load_model(model, true)
	world.set_gold(model.gold_ids())
	_after_load()
	hud.flash_transition()
	world.intro_sweep()
	world.set_menu_view(false)
	Sfx.play("whoosh")
	state = "intro"
	_begin()

func _setup_attempt() -> void:
	_attempt += 1
	_ending = false
	_extra_slots = 0
	_ad_rescue_used = false
	history.clear()
	undos = UNDOS_PER_LEVEL
	_free_hint = true
	hud.set_hint_free(true)
	_assisted = false
	_chains_this_level = 0
	hud.clear_overlay()
	hud.set_game_visible(true)
	hud.set_level(current, levels[current])
	hud.refresh_coins(false)

func _after_load() -> void:
	_last_free = model.buffer.size()
	world.set_danger(0)
	_refresh_hud()

func _begin() -> void:
	state = "playing"
	world.input_enabled = true
	hud.banner("LEVEL %d" % (current + 1), levels[current]["name"])
	var lvl: Dictionary = levels[current]
	if lvl.get("hand", false) and lvl.has("tip"):
		var tip: String = lvl["tip"]
		var att := _attempt
		get_tree().create_timer(1.6).timeout.connect(func():
			if att == _attempt and state == "playing" and model.moves == 0:
				hud.coach(tip))
	_tutorial()

## Resume a level the player left mid-way (app closed or went home).
func _resume() -> bool:
	var r: Dictionary = Save.resume
	var lv := int(r.get("level", -1))
	# an app update may have changed the level: never restore a board into a different layout
	if lv < 0 or lv >= levels.size() or str(r.get("sig", "")) != _level_sig(lv):
		Save.resume = {}
		Save.save_data()
		return false
	current = lv
	_setup_attempt()
	model.setup(levels[current])
	world.set_atmosphere_for_level(current)
	model.restore(r["model"])
	undos = int(r.get("undos", UNDOS_PER_LEVEL))
	_assisted = r.get("assisted", false)
	_free_hint = r.get("free_hint", true)
	hud.set_hint_free(_free_hint)
	_extra_slots = int(r.get("extra_slots", 0))
	for h in r.get("history", []):
		history.append({"model": h["model"], "earned": int(h.get("earned", 0)), "chains": int(h.get("chains", 0))})
	world.load_model(model, false)
	world.set_menu_view(false)
	world.set_gold(_live_gold())
	_after_load()
	hud.flash_transition()
	hud.toast("Welcome back! Picking up where you left off")
	_begin()
	return true

func _save_resume() -> void:
	if state != "playing" or model.moves == 0 or model.finished:
		return
	var keep := []
	for h in history.slice(max(0, history.size() - RESUME_HISTORY)):
		keep.append({"model": h["model"], "earned": h["earned"], "chains": h.get("chains", 0)})
	Save.resume = {"level": current, "sig": _level_sig(current), "model": model.snapshot(), "undos": undos,
		"assisted": _assisted, "free_hint": _free_hint, "extra_slots": _extra_slots, "history": keep}
	Save.save_data()

## Fingerprint of a level's layout, so a resume never lands on a changed level.
func _level_sig(i: int) -> String:
	var l: Dictionary = levels[i]
	return str([l["stacks"], l["ships"], l["buffer"]]).md5_text().substr(0, 12)

func _live_gold() -> Array:
	# gold already loaded onto a ship has paid out; only the rest still sparkle
	var out := []
	for id in model.gold_ids():
		var on_ship := false
		for uid in model.ship_slots:
			if id in model.ship_slots[uid]:
				on_ship = true
		if not on_ship:
			out.append(id)
	return out

# ================================================================= stars

## One rule everywhere: the fewer containers parked at the same time, the more stars.
func _thresholds() -> Array:
	var st: Dictionary = levels[current].get("stars", {"three": 0, "two": 1})
	return [int(st["three"]), int(st["two"])]

func _stars_now() -> int:
	var t := _thresholds()
	if model.peak <= t[0]:
		return 3
	if model.peak <= t[1]:
		return 2
	return 1

# ================================================================= hud

func _refresh_hud() -> void:
	hud.set_queue(model.queue.slice(model.next_q))
	var used := model.buffer_used()
	var free := model.buffer.size() - used
	var t := _thresholds()
	hud.set_buffer(used, model.buffer.size(), t[0], t[1])
	hud.set_stars(_stars_now())
	world.set_danger(0 if free > 1 else (1 if free == 1 else 2))
	if free == 1 and _last_free > 1 and state == "playing":
		Sfx.play("warn")
		Save.buzz(30)
	_last_free = free
	hud.set_undos(undos)
	hud.set_manifest(model.hidden_manifest())
	_refresh_hint_badge()

func _tutorial() -> void:
	# the first lessons point at a good first move
	_tutorial_steps = 3 if current == 0 else (1 if current < 3 else 0)
	if _tutorial_steps > 0:
		var att := _attempt
		get_tree().create_timer(0.9).timeout.connect(func():
			if att == _attempt:
				_tutorial_hint())

func _tutorial_hint() -> void:
	if _tutorial_steps <= 0 or state != "playing":
		world.hide_hint()
		return
	var sv := _solver_here()
	var path = sv.solve(model.to_solver_state())
	if path and not path.is_empty():
		world.show_hint(path[0])

func _solver_here() -> Solver:
	var sv := Solver.new()
	sv.queue = model.queue
	sv.cap = model.cap
	sv.limit = model.buffer.size()
	return sv

# ================================================================= moves

## Coins are committed the moment a move is made, from the rules' own events,
## and recorded on that move so undo refunds exactly what it earned. The
## animations that follow only display them.
const PAY_SHIP := 5
const PAY_GOLD := 10
const PAY_COMBO := 1

func _move_reward(events: Array) -> int:
	var n := 0
	for e in events:
		match e["t"]:
			"depart":
				n += PAY_SHIP
			"move":
				if e["to"] == "ship":
					if model.is_gold(int(e["id"])):
						n += PAY_GOLD
					if e.has("from_stack") and int(e.get("combo", 0)) >= 3:
						n += PAY_COMBO
			"chain":
				n += _chain_bonus(e)
	return n

func _chain_bonus(e: Dictionary) -> int:
	var ships: int = e["ships"]
	var fb: int = e["from_buffer"]
	return CHAIN_BONUS_PER_SHIP * max(0, ships - 1) + (2 * fb if ships >= 2 else 8)

func _on_tap(s: int) -> void:
	if state != "playing" or hud.is_overlay_open() or _ending:
		return
	var snap := model.snapshot()
	var events := model.tap(s)
	if events.size() == 1 and events[0]["t"] == "refuse":
		world.play(events)
		var why: String = events[0]["why"]
		if why == "full":
			hud.toast("All parking spots are full! Try another stack")
		elif why == "locked":
			hud.toast("Locked by customs")
		return
	var earned := _move_reward(events)
	var chains := 0
	for e in events:
		if e["t"] == "chain":
			chains += 1
	history.append({"model": snap, "earned": earned, "chains": chains})
	# coins and the resume point go to disk in one write
	Save.coins += earned
	Save.chains += chains
	world.hide_hint()
	if model.moves >= 2:
		hud.hide_coach()
	world.play(events)
	for e in events:
		if e["t"] == "chain":
			_on_chain(e)
	_refresh_hud()
	if model.finished:
		Save.resume = {}   # the clear is paid; never replay the final move from a resume
	else:
		_save_resume()
	if Save.resume.is_empty():
		Save.save_data()
	if _tutorial_steps > 0:
		_tutorial_steps -= 1
		var att := _attempt
		get_tree().create_timer(0.55).timeout.connect(func():
			if att == _attempt:
				_tutorial_hint())
	for e in events:
		if e["t"] == "win":
			_finish(true)
		elif e["t"] == "lose":
			_finish(false)

## The signature moment: one tap sent several ships off, or emptied the pads.
func _on_chain(e: Dictionary) -> void:
	_chains_this_level += 1
	_stamps_quiet_until = Time.get_ticks_msec() + 3000

## Feedback begins at the first physical launch, not a timer after the tap.
func _on_chain_launched(ships: int, from_buffer: int) -> void:
	if state not in ["playing", "won"]:
		return
	_stamps_quiet_until = Time.get_ticks_msec() + 3500
	var bonus := _chain_bonus({"ships": ships, "from_buffer": from_buffer})
	hud.chain_callout(ships, from_buffer, bonus)
	hud.refresh_coins()
	Sfx.play("dispatch_chime", 1.0, -6.0)
	Save.buzz(35)

func _on_ship_loaded(screen_pos: Vector2, color: int) -> void:
	# no stamp during a chain (the chain callout speaks for it) or on the winning ship
	if Time.get_ticks_msec() > _stamps_quiet_until and not model.finished and state == "playing":
		hud.stamp("SHIPPED!", screen_pos + Vector2(0, -60), Pal.cargo(color).darkened(0.15))
	hud.fly_coins(screen_pos, PAY_SHIP, 4)

func _on_landed_direct(combo: int, screen_pos: Vector2) -> void:
	if state != "playing" or _ending:
		return
	if combo >= 3:
		hud.fly_coins(screen_pos, PAY_COMBO, 1)

func _on_gold_bonus(screen_pos: Vector2, _id: int) -> void:
	hud.popup("+10 GOLD", screen_pos + Vector2(0, -40), Color("#e0a800"), false)
	hud.fly_coins(screen_pos, PAY_GOLD, 6)

func _finish(won: bool) -> void:
	_ending = true
	world.hide_hint()
	var att := _attempt
	var at_move := model.moves
	await get_tree().create_timer(0.3).timeout
	var deadline := Time.get_ticks_msec() + 9000
	while world.is_busy() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		if att != _attempt:
			return
	# a restart, undo, level change or trip home since this move voids the result
	if att != _attempt or model.moves != at_move or state != "playing":
		return
	if won and not model.finished:
		return
	if won:
		state = "won"
		var stars := _stars_now()
		var prev_best := Save.get_stars(current + 1)
		# a level's full reward is paid once per new star; replays of a level
		# already at that rating pay a small, clearly shown amount
		var reward := 20 + 10 * stars if stars > prev_best else 10
		var result := {"stars": stars, "three": _thresholds()[0], "reward": reward, "replay": stars <= prev_best,
			"last_level": current == levels.size() - 1, "fireworks": Save.has_project("fireworks")}
		var first_clear := Save.get_stars(current + 1) == 0
		var rank_before: int = Save.rank_info()[3]
		Save.add_coins(reward)
		Save.record_win(current + 1, stars, levels.size())
		if first_clear and (current + 1) % 5 == 0:
			result["crate"] = 100 + 20 * ((current + 1) / 5)
			Save.add_coins(result["crate"])
		var ri := Save.rank_info()
		if ri[3] > rank_before:
			result["rank_up"] = ri[0]
		world.confetti()
		Sfx.play("win")
		Save.buzz(60)
		await get_tree().create_timer(0.6).timeout
		# the player may have left (pause > home) during the short celebration
		if state != "won" or att != _attempt:
			return
		hud.show_win(result)
		hud.refresh_coins()
	else:
		state = "lost"
		Save.resume = {}
		Save.save_data()
		Sfx.play("lose")
		await get_tree().create_timer(0.4).timeout
		if state != "lost" or att != _attempt:
			return
		_show_lose()

# ================================================================= boosters

func _undo() -> void:
	if undos <= 0 or history.is_empty():
		hud.toast("Nothing to undo" if history.is_empty() else "No undos left")
		return
	if state == "lost":
		state = "playing"
	if state != "playing":
		return
	_ending = false
	undos -= 1
	_assisted = true
	var h: Dictionary = history.pop_back()
	# coins earned by the undone move go back, so undo can't be used to farm rewards
	if int(h["earned"]) > 0:
		Save.coins = max(0, Save.coins - int(h["earned"]))
		hud.refresh_coins()
	Save.chains = max(0, Save.chains - int(h.get("chains", 0)))
	model.restore(h["model"])
	# spots bought this attempt are kept: undo takes back moves, not purchases
	while model.buffer.size() < int(levels[current]["buffer"]) + _extra_slots:
		model.add_buffer_slot()
	world.load_model(model, false)
	world.set_gold(_live_gold())
	_last_free = 99
	_refresh_hud()
	_save_resume()
	if Save.resume.is_empty():
		Save.save_data()
	Sfx.play("whoosh", 1.2)
	hud.bump("undo")

## Hint booster: the first one each level is free, then it costs coins; with too
## few coins a rewarded ad can pay for it instead.
func _hint() -> void:
	if state != "playing":
		return
	if _free_hint:
		_run_hint("free")
	elif Save.coins >= Hud.COST_HINT:
		_run_hint("coins")
	elif Ads.rewarded_ready("hint"):
		var att := _attempt
		Ads.show_rewarded("hint", func():
			if att == _attempt and state == "playing":
				_run_hint("ad"))
	else:
		hud.toast("Not enough coins")

func _refresh_hint_badge() -> void:
	if _free_hint:
		hud.set_hint_mode("free")
	elif Save.coins < Hud.COST_HINT and Ads.rewarded_ready("hint"):
		hud.set_hint_mode("ad")
	else:
		hud.set_hint_mode("coins")

func _run_hint(pay: String) -> void:
	if pay == "coins" and not Save.spend(Hud.COST_HINT):
		return
	# aim for the best star tier still reachable, then fall back to a safe clear
	var t := _thresholds()
	var tiers := []
	if model.peak <= t[0]:
		tiers.append([t[0], 3])
	if model.peak <= t[1]:
		tiers.append([t[1], 2])
	tiers.append([model.buffer.size(), 1])
	var path = null
	var tier := 1
	var sv: Solver
	for tr in tiers:
		sv = _solver_here()
		sv.limit = max(int(tr[0]), model.buffer_used())
		sv.budget = 30000 if tr[1] > 1 else 60000
		path = sv.solve(model.to_solver_state())
		if path != null and not path.is_empty():
			tier = tr[1]
			break
	var best_possible: int = tiers[0][1]
	if path == null or path.is_empty():
		if pay == "coins":
			Save.add_coins(Hud.COST_HINT)
		# only claim a dead end when the search actually proved it
		if sv.exhausted():
			hud.toast("Couldn't find a hint from here. Try thinking one ship ahead!")
		else:
			hud.toast("No way out from here. Try Undo!")
			hud.bump("undo")
		hud.refresh_coins()
		return
	_assisted = true
	var msg := ""
	if tier < best_possible:
		msg = "Safe move: this clears the level but keeps %d star%s" % [tier, "" if tier == 1 else "s"]
	if pay == "free":
		_free_hint = false
		if msg == "":
			msg = "First hint is free!"
	if msg != "":
		hud.toast(msg)
	hud.refresh_coins()
	_refresh_hint_badge()
	world.show_hint(path[0])
	hud.bump("hint")
	_save_resume()

## Why an extra spot can't be offered right now ("" = it can). With
## `ignore_coins` it only asks whether a spot would help (for the ad rescue).
func _slot_blocker(ignore_coins := false) -> String:
	if model.buffer.size() >= MAX_SPOTS:
		return "The quay has no room for another spot"
	# a spot only helps if some stack could then be moved
	var tm := GameModel.new()
	tm.setup(levels[current])
	tm.restore(model.snapshot())
	tm.add_buffer_slot()
	var helps := false
	for st in tm.stacks.size():
		if tm.check_tap(st) == "":
			helps = true
			break
	if not helps:
		return "An extra spot can't help here. Try Undo"
	if not ignore_coins and Save.coins < Hud.COST_SLOT:
		return "Not enough coins for an extra spot"
	return ""

func _show_lose() -> void:
	var why := _slot_blocker()
	var ad_ok := not _ad_rescue_used and _slot_blocker(true) == "" and Ads.rewarded_ready("rescue")
	hud.show_lose(why == "", undos if history.size() > 0 else 0, why, ad_ok)

## Lose screen: watch an ad for a free extra spot (once per attempt).
func _ad_rescue() -> void:
	if state != "lost" or _ad_rescue_used:
		return
	var att := _attempt
	var shown := Ads.show_rewarded("rescue", func():
		if att == _attempt and state == "lost":
			_ad_rescue_used = true
			_grant_spot(true),
		func(earned: bool):
			if not earned and att == _attempt and state == "lost":
				_show_lose())
	if not shown:
		hud.toast("No ad available right now")
		_show_lose()

func _extra_slot(from_lose: bool) -> void:
	if state not in ["playing", "lost"]:
		return
	var why := _slot_blocker()
	if why != "" or not Save.spend(Hud.COST_SLOT):
		hud.toast(why if why != "" else "Not enough coins")
		if from_lose and state == "lost":
			_show_lose()
		return
	_grant_spot(from_lose)

func _grant_spot(from_lose: bool) -> void:
	state = "playing"
	_ending = false
	_assisted = true
	_extra_slots += 1
	model.add_buffer_slot()
	world.add_pad_animated()
	hud.refresh_coins()
	_refresh_hud()
	Sfx.play("unlock", 1.2)
	_save_resume()
	if from_lose:
		hud.toast("Extra spot added. Keep going!")

# ================================================================= harbour

func _on_project_built(id: String) -> void:
	if id == "cranes":
		world.set_cranes(true)
	world.harbour.refresh(id)
	if id == "liveries":
		world.load_model(model, false)   # rebuild the docked ships with their new paint
	var spot: Vector3 = Harbour.FOCUS.get(id, Harbour.SPOTS.get(id, Vector3(0, 0, 6)))
	if id == "planters":
		spot = Vector3(5.15, 0, 2.5)
	world.big_burst(spot + Vector3(0, 1.5, 0), Color("#ffd23f"))
	world.focus_on(spot)
	if id == "fireworks":
		hud.fireworks(3.0)
	var pname := ""
	for p in Save.PROJECTS:
		if p[0] == id:
			pname = p[1]
	hud.toast("%s complete!" % pname)
	await get_tree().create_timer(2.4).timeout
	if state == "title":
		hud.show_title(Save.unlocked, levels.size())

## Command-line user arguments (--key=value), used only by the test harness.
func _parse_args() -> Dictionary:
	var d := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=")
		d[kv[0]] = kv[1] if kv.size() > 1 else ""
	return d
