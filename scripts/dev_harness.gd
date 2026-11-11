class_name DevHarness
extends Node
## Command-line test harness and screenshot tool. Only created when the game is
## started with user arguments (godot --path . -- --verify, --bugtest, ...), so
## it never runs in a normal play session. `g` is the game controller.

var g: Node
var _args := {}

func run(game: Node, args: Dictionary) -> void:
	g = game
	_args = args
	await _run_harness()

func _snap(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)

## --level=N --screen=title|levels|play|card|win|lose|harbour|campaign --autoplay --shot=...
func _run_harness() -> void:
	var lv := int(_args.get("level", "1")) - 1
	var screen: String = _args.get("screen", "play")
	var out: String = _args.get("shot", "")
	if _args.has("fresh"):
		Save.resume = {}
	if _args.has("simads"):
		Ads.simulate = true
	if _args.has("noui"):
		g.hud.visible = false
		g.hud.root.visible = false
	if _args.has("cam"):
		# --cam=x,y,z,tx,ty,tz  free camera for scenery checks
		var c := Array(str(_args["cam"]).split(",")).map(func(v): return float(v))
		g.world.set_meta("free_cam", [Vector3(c[0], c[1], c[2]), Vector3(c[3], c[4], c[5])])
	if _args.has("light"):
		# --light=sun_energy,ambient_energy,shadow_opacity,tonemap(0 lin,2 filmic,3 aces,4 agx),exposure,saturation
		var v := Array(str(_args["light"]).split(",")).map(func(x): return float(x))
		g.world.set_meta("light_override", v)
		g.world.apply_light_override()
	if _args.has("coins"):
		Save.coins = int(_args["coins"])
	if _args.has("projects"):
		Save.projects = Array(str(_args["projects"]).split(",", false))
		g.world.harbour.refresh()
		g.world.set_cranes(Save.has_project("cranes"))
	if _args.has("verify"):
		await _verify_all()
		return
	if _args.has("perf"):
		g.start_level(lv)
		await get_tree().create_timer(2.5).timeout
		var f0 := Engine.get_frames_drawn()
		var t0 := Time.get_ticks_msec()
		await get_tree().create_timer(2.0).timeout
		print("PERF fps=%.1f draw_calls=%d primitives=%d" % [(Engine.get_frames_drawn() - f0) * 1000.0 / (Time.get_ticks_msec() - t0),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)])
		if _args.has("breakdown"):
			_tri_breakdown()
		get_tree().quit()
		return
	if _args.has("pickcheck"):
		await _pick_check()
		return
	if _args.has("buildtest"):
		g._go_title()
		g.hud.clear_overlay()
		await get_tree().create_timer(0.6).timeout
		var id: String = _args["buildtest"]
		print("BUILD ok=", Save.build_project(id), " coins=", Save.coins, " projects=", Save.projects)
		g._on_project_built(id)
		await get_tree().create_timer(1.4).timeout
		await _snap(_args.get("shot", "/tmp/b.png"))
		get_tree().quit()
		return
	if _args.has("trust"):
		await _trust_test()
		return
	if _args.has("chaintest"):
		await _chain_test()
		return
	if _args.has("adtest"):
		await _ad_test()
		return
	if _args.has("bugtest"):
		await _bug_test()
		return
	if _args.has("uitest"):
		await _ui_test()
		return
	match screen:
		"title":
			Save.unlocked = max(Save.unlocked, lv + 1)
			g._go_title()
		"levels":
			Save.unlocked = max(Save.unlocked, lv + 1)
			g._go_title()
			g.hud.show_levels(lv + 1, g.levels.size())
		"harbour":
			g._go_title()
			g.hud.show_harbour(Save.unlocked, g.levels.size())
		"campaign":
			g._go_title()
			g.hud.show_campaign_complete(72, 90, 41)
		"settings":
			g._go_title()
			g.hud.show_settings()
		"rank":
			g._go_title()
			g.hud.show_rank()
		"levelinfo":
			Save.unlocked = max(Save.unlocked, lv + 1)
			g._go_title()
			g.hud.show_level_info(lv - 2)
		"pause":
			g.start_level(lv)
			await get_tree().create_timer(1.6).timeout
			g.hud.show_pause()
		"lose":
			g.start_level(lv)
			await get_tree().create_timer(1.6).timeout
			g.state = "lost"
			g.hud.show_lose(true, 2, "", Ads.rewarded_ready("rescue"))
		"card":
			g.start_level(lv)
		_:
			g.start_level(lv)
	if _args.has("autoplay"):
		await _autoplay(out)
		return
	if _args.has("boosters"):
		await _booster_test(out)
		return
	await get_tree().create_timer(float(_args.get("wait", "1.5"))).timeout
	if out != "":
		await _snap(out)
	get_tree().quit()

## Plays the stored 3-star solution, snapping screenshots at the requested move numbers.
func _autoplay(prefix: String) -> void:
	await get_tree().create_timer(1.4).timeout
	g.hud.clear_overlay()
	var sol: Array = g.levels[g.current]["solution"]
	var at := []
	for t in str(_args.get("at", "")).split(",", false):
		at.append(int(t))
	var gap := float(_args.get("gap", "0.35"))
	for i in sol.size():
		g._on_tap(int(sol[i]))
		if i + 1 in at and prefix != "" and _args.has("burst"):
			var t0 := 0.0
			for bt in str(_args["burst"]).split(",", false):
				await get_tree().create_timer(float(bt) - t0).timeout
				t0 = float(bt)
				await _snap("%s_%02d_%s.png" % [prefix, i + 1, bt])
		elif i + 1 in at and prefix != "":
			await get_tree().create_timer(float(_args.get("snapdelay", "0.25"))).timeout
			await _snap("%s_%02d.png" % [prefix, i + 1])
		await get_tree().create_timer(gap).timeout
	await get_tree().create_timer(float(_args.get("endwait", "3.2"))).timeout
	if prefix != "":
		await _snap("%s_end.png" % prefix)
	print("AUTOPLAY level=%d state=%s peak=%d stars=%d chain=%d" % [g.current + 1, g.state, g.model.peak, g._stars_now(), g.model.best_chain])
	get_tree().quit()

## Hint, extra slot, random play until stuck, lose screen, undo.
func _booster_test(prefix: String) -> void:
	Save.coins = 500
	await get_tree().create_timer(1.6).timeout
	g.hud.clear_overlay()
	g._hint()
	await get_tree().create_timer(0.5).timeout
	await _snap(prefix + "_hint.png")
	g._extra_slot(false)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var n := 0
	while g.state == "playing" and n < 80:
		var legal := []
		for s in g.model.stacks.size():
			if g.model.check_tap(s) == "":
				legal.append(s)
		if legal.is_empty():
			break
		g._on_tap(legal[rng.randi_range(0, legal.size() - 1)])
		n += 1
		await get_tree().create_timer(0.12).timeout
	await get_tree().create_timer(3.0).timeout
	print("BOOSTER state=%s moves=%d peak=%d buffer=%d" % [g.state, g.model.moves, g.model.peak, g.model.buffer.size()])
	await _snap(prefix + "_end.png")
	if g.state == "lost":
		g._undo()
		await get_tree().create_timer(0.8).timeout
		print("after undo state=%s remaining=%d" % [g.state, g.model.remaining_containers()])
	get_tree().quit()

## Trust checks: undo refunds earned coins; resume restores a level in progress.
func _trust_test() -> void:
	Save.coins = 100
	g.start_level(2)
	await get_tree().create_timer(1.2).timeout
	var sol: Array = g.levels[2]["solution"]
	var before := Save.coins
	for s in sol:
		g._on_tap(int(s))
		await get_tree().create_timer(0.9).timeout
		if g.model.sailed >= 2 or g.model.finished:
			break
	await get_tree().create_timer(2.5).timeout
	var after_chain := Save.coins
	var moves = g.model.moves
	# undo every move made: the balance must return to where it started
	while not g.history.is_empty():
		g.undos = 9
		g._undo()
	print("TRUST undo-coins start=%d peak=%d after_undo=%d (%s)" % [before, after_chain, Save.coins, "OK" if Save.coins == before else "LEAK"])
	var coins_ok := Save.coins == before
	# resume: play a few moves, go home, come back
	g.start_level(6)
	await get_tree().create_timer(1.2).timeout
	for k in 4:
		g._on_tap(int(g.levels[6]["solution"][k]))
		await get_tree().create_timer(0.6).timeout
	var want = g.model.remaining_containers()
	g._go_title()
	Save.load_data()
	g._on_play()
	await get_tree().create_timer(0.8).timeout
	var resume_ok: bool = g.current == 6 and g.model.remaining_containers() == want
	print("TRUST resume level=%d remaining=%d expected=%d moves=%d (%s)" % [g.current + 1, g.model.remaining_containers(), want, moves, "OK" if resume_ok else "BROKEN"])
	get_tree().quit(0 if coins_ok and resume_ok else 1)

## Simulated touches on every stack of several levels must hit that stack.
func _pick_check() -> void:
	var bad := 0
	var total := 0
	for lv in [0, 4, 11, 29, 60, 80, 99]:
		g.start_level(lv)
		await get_tree().create_timer(1.5).timeout
		for s in g.model.stacks.size():
			var h: int = g.model.stacks[s].size()
			for frac in [0.1, 0.5, 0.95]:
				var p = g.world.camera.unproject_position(Vector3(g.world.stack_x(s), h * Meshes.CH * frac, World.YARD_Z - Meshes.CL * 0.5))
				var got = g.world.pick_stack(p)
				total += 1
				if got != s:
					bad += 1
	print("PICKCHECK %d/%d correct" % [total - bad, total])
	get_tree().quit(0 if bad == 0 else 1)

## Headless check: every level's stored solution clears the yard with 3 stars.
func _verify_all() -> void:
	var ok := 0
	for i in g.levels.size():
		g.current = i
		g.model = GameModel.new()
		g.model.setup(g.levels[i])
		var won := false
		for s in g.levels[i]["solution"]:
			var ev = g.model.tap(int(s))
			for e in ev:
				if e["t"] == "refuse":
					print("L%d refused at stack %d (%s)" % [i + 1, s, e["why"]])
				if e["t"] == "win":
					won = true
		var c := 0
		for st in g.levels[i]["stacks"]:
			c += st.size()
		var t = g._thresholds()
		print("L%02d %s stars=%d containers=%d peak=%d (3*<=%d 2*<=%d) chain=%d %s" % [i + 1, "WIN " if won else "FAIL", g._stars_now(), c, g.model.peak, t[0], t[1], g.model.best_chain, g.levels[i]["name"]])
		if won and g._stars_now() == 3:
			ok += 1
	print("VERIFY %d/%d levels: 3-star solution confirmed" % [ok, g.levels.size()])
	get_tree().quit(0 if ok == g.levels.size() else 1)

## Menu flow: tabs, level popup, starting a level, Android back, pause, home.
func _ui_test() -> void:
	var fails := [0]
	var check := func(name: String, cond: bool):
		print("UITEST %-34s %s" % [name, "OK" if cond else "FAIL"])
		if not cond:
			fails[0] += 1
	Save.unlocked = max(Save.unlocked, 5)
	Save.resume = {}
	g._go_title()
	await get_tree().create_timer(0.5).timeout
	check.call("home tab open", g.hud._menu != null and g.hud._menu.tab == "home")
	g.hud._menu.switch_tab("map")
	await get_tree().create_timer(0.5).timeout
	check.call("map tab", g.hud._menu.tab == "map")
	var ms: ScrollContainer = g.hud._menu._map_scroll
	var np: Vector2 = g.hud._menu._node_pos(Save.unlocked - 1, (ms.get_child(0) as Control).custom_minimum_size.y)
	check.call("map shows the current level", np.y >= ms.scroll_vertical and np.y <= ms.scroll_vertical + ms.size.y)
	g._notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	check.call("back from map goes home", g.state == "title" and g.hud._menu.tab == "home")
	g.hud.show_settings()
	# a phone tap arrives as a touch AND an emulated click: the switch must flip once
	var sws = g.hud._pop.find_children("*", "Control", true, false).filter(func(n): return n is Icons.Switch)
	var music_before: bool = Save.music
	if not sws.is_empty():
		var sw: Control = sws[0]
		var touch := InputEventScreenTouch.new()
		touch.pressed = true
		var click := InputEventMouseButton.new()
		click.pressed = true
		click.button_index = MOUSE_BUTTON_LEFT
		sw._gui_input(touch)
		sw._gui_input(click)
		await get_tree().process_frame
	check.call("phone tap flips a switch once", not sws.is_empty() and Save.music != music_before)
	await get_tree().create_timer(0.35).timeout
	if not sws.is_empty():
		var row: Control = (sws[0] as Control).get_parent()
		var click2 := InputEventMouseButton.new()
		click2.pressed = true
		click2.button_index = MOUSE_BUTTON_LEFT
		row.gui_input.emit(click2)
	check.call("tapping the row label flips it back", not sws.is_empty() and Save.music == music_before)
	g._notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	await get_tree().process_frame
	check.call("back closes settings", not g.hud.is_modal_open() and g.state == "title")
	g.hud._menu.switch_tab("map")
	g.hud.show_level_info(2)
	check.call("level popup open", g.hud.is_modal_open())
	g.hud.level_chosen.emit(2)
	g.hud.clear_overlay()
	await get_tree().create_timer(0.3).timeout
	check.call("level 3 started", g.state == "playing" and g.current == 2)
	check.call("menu gone while playing", not g.hud.is_overlay_open())
	g._notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	await get_tree().process_frame
	check.call("back pauses", g.hud.is_modal_open() and g.state == "playing")
	var moves = g.model.moves
	g._on_tap(int(g.levels[2]["solution"][0]))
	check.call("taps blocked while paused", g.model.moves == moves)
	g._notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	await get_tree().process_frame
	check.call("back resumes", not g.hud.is_modal_open())
	g._on_tap(int(g.levels[2]["solution"][0]))
	check.call("taps work after resume", g.model.moves == moves + 1)
	g.hud.show_pause()
	g.hud.home_pressed.emit()
	await get_tree().create_timer(0.3).timeout
	check.call("home from pause", g.state == "title" and g.hud._menu != null)
	check.call("resume saved", not Save.resume.is_empty())
	g._notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	print("UITEST %s" % ("ALL OK" if fails[0] == 0 else "FAILURES: %d" % fails[0]))
	get_tree().quit(0 if fails[0] == 0 else 1)

## Plays levels back to back through the real win -> CONTINUE path, logging
## memory and object counts after each one (catches leaks and transition bugs).
func _chain_test() -> void:
	var first := int(_args.get("level", "1")) - 1
	var count := int(_args.get("count", "8"))
	Save.unlocked = max(Save.unlocked, first + count + 1)
	g.start_level(first)
	for n in count:
		await get_tree().create_timer(1.3).timeout
		for s in g.levels[g.current]["solution"]:
			g._on_tap(int(s))
			await get_tree().create_timer(float(_args.get("tapgap", "0.12"))).timeout
		var t_last := Time.get_ticks_msec()
		var guard := 0
		while g.state != "won" and guard < 400:
			await get_tree().create_timer(0.05).timeout
			guard += 1
		print("CHAINTIME level=%d taps=%d settle_after_last_tap=%.2fs" % [g.current + 1, g.levels[g.current]["solution"].size(), (Time.get_ticks_msec() - t_last) / 1000.0])
		guard = 0
		while not g.hud.is_modal_open() and guard < 100:
			await get_tree().create_timer(0.05).timeout
			guard += 1
		await get_tree().create_timer(float(_args.get("after", "1.2"))).timeout
		print("CHAIN level=%d state=%s mem=%.1fMB objects=%d nodes=%d orphans=%d vram=%.1fMB" % [g.current + 1, g.state,
			Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
			Performance.get_monitor(Performance.OBJECT_COUNT), Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
			Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
			Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0])
		if _args.has("dump"):
			var by := {}
			for nd in get_tree().root.find_children("*", "", true, false):
				by[nd.get_class()] = by.get(nd.get_class(), 0) + 1
			var st := {}
			for tw in get_tree().get_processed_tweens():
				var k := "run=%s valid=%s loops=%d el=%d" % [tw.is_running(), tw.is_valid(), tw.get_loops_left(), int(tw.get_total_elapsed_time() / 5.0) * 5]
				st[k] = st.get(k, 0) + 1
			print("DUMP tweens=%d %s" % [get_tree().get_processed_tweens().size(), st])
		if g.state != "won":
			print("CHAIN stuck in state ", g.state)
			get_tree().quit(1)
			return
		g.hud.clear_overlay()
		g.hud.next_pressed.emit()
	print("CHAIN done")
	get_tree().quit()

## Reproductions of the review's defects; each line must print OK.
func _bug_test() -> void:
	var fails := [0]
	var check := func(name: String, cond: bool, info: String = ""):
		print("BUGTEST %-44s %s %s" % [name, "OK" if cond else "FAIL", info])
		if not cond:
			fails[0] += 1
	Save.unlocked = 100
	Save.coins = 1000
	Save.resume = {}
	# 1. winning move, then an instant restart: the old attempt must not finish the new one
	g.start_level(0)
	await get_tree().create_timer(1.2).timeout
	var sol: Array = g.levels[0]["solution"]
	for s in sol:
		g._on_tap(int(s))
	g.start_level(0)
	await get_tree().create_timer(3.0).timeout
	check.call("restart after winning move stays a new attempt", g.state == "playing" and g.model.moves == 0 and not g.hud.is_modal_open(), "state=%s moves=%d" % [g.state, g.model.moves])
	# 1b. a losing move then an instant undo: no lose screen afterwards
	var lost := false
	var rng := RandomNumberGenerator.new()
	for seed_i in 12:
		if lost:
			break
		g.start_level(97)
		await get_tree().create_timer(1.0).timeout
		rng.seed = 3 + seed_i
		lost = await _lose_then_undo(rng)
	await get_tree().create_timer(3.0).timeout
	check.call("undo during the lose pause cancels the loss", lost and g.state == "playing" and not g.hud.is_modal_open(), "lost=%s state=%s" % [lost, g.state])
	# 2. undo refunds exactly what the move earned, fast or slow
	var results := []
	for speed in [0.0, 0.9]:
		g.start_level(5)
		await get_tree().create_timer(1.2).timeout
		var s6: Array = g.levels[5]["solution"]
		for k in s6.size():
			g._on_tap(int(s6[k]))
			if speed > 0.0:
				await get_tree().create_timer(speed).timeout
			if k >= 3 and int(g.history.back()["earned"]) > 0 and not g.model.finished:
				break
		var coins_before_last: int = Save.coins - int(g.history.back()["earned"])
		await get_tree().create_timer(3.0).timeout
		var before_undo := Save.coins
		g.undos = 3
		g._undo()
		results.append([before_undo, Save.coins, coins_before_last, before_undo - Save.coins])
	check.call("undo refund independent of tap speed", results[0][3] > 0 and results[0][3] == results[1][3] and results[0][1] == results[0][2] and results[1][1] == results[1][2], str(results))
	# 3. a bought spot survives undo and is not charged twice
	g.start_level(6)
	await get_tree().create_timer(1.2).timeout
	var base = g.model.buffer.size()
	g._on_tap(int(g.levels[6]["solution"][0]))
	await get_tree().create_timer(1.0).timeout
	var c0 := Save.coins
	g._extra_slot(false)
	var c1 := Save.coins
	g.undos = 3
	g._undo()
	await get_tree().create_timer(0.5).timeout
	check.call("bought spot survives undo", g.model.buffer.size() == base + 1 and c0 - c1 == Hud.COST_SLOT and Save.coins == c1 - 0 or (g.model.buffer.size() == base + 1 and c0 - Save.coins == Hud.COST_SLOT + int(0)), "buffer=%d base=%d paid=%d" % [g.model.buffer.size(), base, c0 - c1])
	# 4. resume keeps undo history
	g.start_level(6)
	await get_tree().create_timer(1.2).timeout
	g._on_tap(int(g.levels[6]["solution"][0]))
	g._on_tap(int(g.levels[6]["solution"][1]))
	await get_tree().create_timer(1.5).timeout
	g._go_title()
	Save.load_data()
	g._on_play()
	await get_tree().create_timer(1.0).timeout
	var h = g.history.size()
	g.undos = 3
	g._undo()
	check.call("resume keeps undo history", h == 2 and g.model.moves == 1, "history=%d moves=%d" % [h, g.model.moves])
	# a resume saved for a different layout of the level (app update) is dropped
	g.start_level(6)
	await get_tree().create_timer(1.0).timeout
	g._on_tap(int(g.levels[6]["solution"][0]))
	await get_tree().create_timer(0.8).timeout
	g._go_title()
	Save.resume["sig"] = "old-layout"   # as if an update changed this level since
	g._on_play()
	await get_tree().create_timer(0.8).timeout
	check.call("stale resume is dropped, not restored", g.model.moves == 0 and Save.resume.is_empty(), "moves=%d" % g.model.moves)
	# P2: +1 spot is never offered when it cannot work
	g.start_level(6)
	await get_tree().create_timer(1.0).timeout
	while g.model.buffer.size() < g.MAX_SPOTS:
		g.model.add_buffer_slot()
	check.call("+1 spot refused at the spot limit", g._slot_blocker() != "", g._slot_blocker())
	# P2: hints keep the best reachable star tier on fresh boards
	var keep := 0
	for lv in [10, 30, 50, 70, 90]:
		g.start_level(lv)
		await get_tree().create_timer(0.4).timeout
		g._free_hint = true
		g._hint()
		var t = g._thresholds()
		var sv = g._solver_here()
		sv.limit = t[0]
		var st = g.model.to_solver_state()
		if g.world._hint_stack >= 0:
			var m2 := GameModel.new()
			m2.setup(g.levels[lv])
			m2.tap(g.world._hint_stack)
			sv.budget = 60000
			if sv.solve(m2.to_solver_state()) != null:
				keep += 1
	check.call("first hint keeps 3 stars reachable", keep == 5, "%d/5" % keep)
	# BUILD works straight from the win screen, and the card comes back after
	Save.projects = []
	Save.coins = 5000
	g.start_level(2)
	await get_tree().create_timer(1.2).timeout
	for s3 in g.levels[2]["solution"]:
		g._on_tap(int(s3))
		await get_tree().create_timer(0.15).timeout
	var waited := 0
	while not g.hud.is_modal_open() and waited < 120:
		await get_tree().create_timer(0.05).timeout
		waited += 1
	var first_id: String = Save.next_project()[0]
	var bb = _find_button(g.hud._pop, "BUILD")
	var found_win := bb != null
	if found_win:
		bb.pressed.emit()
	await get_tree().create_timer(0.5).timeout
	var hidden_during = not g.hud._pop.visible
	await get_tree().create_timer(3.5).timeout
	check.call("BUILD on the win screen builds", found_win and Save.has_project(first_id), "button=%s built=%s" % [found_win, Save.has_project(first_id)])
	check.call("win card returns with the next project", hidden_during and g.hud._pop.visible and g.hud.is_modal_open() and g.state == "won" and _find_button(g.hud._pop, "CONTINUE") != null)
	# and from the home screen strip
	g._go_title()
	await get_tree().create_timer(0.6).timeout
	var second_id: String = Save.next_project()[0]
	var hb = _find_button(g.hud._overlay, "BUILD")
	var found_home := hb != null
	if found_home:
		hb.pressed.emit()
	await get_tree().create_timer(3.2).timeout
	check.call("BUILD on the home screen builds", found_home and Save.has_project(second_id) and g.state == "title" and g.hud._menu != null, "button=%s built=%s" % [found_home, Save.has_project(second_id)])
	print("BUGTEST %s" % ("ALL OK" if fails[0] == 0 else "FAILURES: %d" % fails[0]))
	get_tree().quit(0 if fails[0] == 0 else 1)

## Random play until a move loses, then an instant undo. True if a loss happened.
func _lose_then_undo(rng: RandomNumberGenerator) -> bool:
	for k in 80:
		var legal := []
		for st in g.model.stacks.size():
			if g.model.check_tap(st) == "":
				legal.append(st)
		if legal.is_empty():
			return false
		g._on_tap(legal[rng.randi_range(0, legal.size() - 1)])
		if g.model.finished:
			return false
		if g._ending:
			g.undos = 3
			g._undo()
			return true
		await get_tree().process_frame
	return false

func _find_button(root_node: Node, text: String) -> Button:
	for b in root_node.find_children("*", "Button", true, false):
		if (b as Button).text == text and (b as Button).is_visible_in_tree() and not (b as Button).disabled:
			return b
	return null

## Ad placements with the simulated ad service, plus the "no ad available" paths.
func _ad_test() -> void:
	var fails := [0]
	var check := func(name: String, cond: bool, info: String = ""):
		print("ADTEST %-46s %s %s" % [name, "OK" if cond else "FAIL", info])
		if not cond:
			fails[0] += 1
	Save.unlocked = 100
	Save.resume = {}
	# --- no ad SDK on desktop: nothing offered, nothing breaks
	Ads.simulate = false
	Save.coins = 0
	g.start_level(97)   # one of the tightest levels: random play loses quickly
	await get_tree().create_timer(1.0).timeout
	var lost: bool = await _play_until_lost(7)
	check.call("a loss was reached for the test", lost)
	check.call("no ad button without an ad", lost and _find_button(g.hud._pop, "      FREE SPOT") == null)
	# --- with ads: free spot on the lose screen, once per attempt
	Ads.simulate = true
	g._show_lose()
	await get_tree().process_frame
	var adb := _find_button(g.hud._pop, "      FREE SPOT")
	check.call("lose screen offers a free spot for an ad", adb != null)
	var spots_before: int = g.model.buffer.size()
	var coins_before := Save.coins
	if adb:
		adb.pressed.emit()
	await get_tree().create_timer(0.5).timeout
	check.call("watching the ad adds a spot for free", g.state == "playing" and g.model.buffer.size() == spots_before + 1 and Save.coins == coins_before, "state=%s spots=%d->%d" % [g.state, spots_before, g.model.buffer.size()])
	g.state = "lost"
	g._show_lose()
	await get_tree().process_frame
	check.call("only one ad rescue per attempt", _find_button(g.hud._pop, "      FREE SPOT") == null)
	g.hud.clear_overlay()
	# --- hint paid by an ad when coins run out
	g.start_level(30)
	await get_tree().create_timer(0.8).timeout
	g._free_hint = false
	Save.coins = 0
	g._refresh_hint_badge()
	check.call("hint badge switches to the ad", g.hud._hint_badge.text == "AD", g.hud._hint_badge.text)
	g.world.hide_hint()
	g._hint()
	await get_tree().create_timer(0.3).timeout
	check.call("ad pays for the hint", g.world._hint_stack >= 0 and Save.coins == 0)
	Ads.simulate = false
	g.world.hide_hint()
	g._refresh_hint_badge()
	g._hint()
	check.call("no ad, no coins: no hint and no charge", g.world._hint_stack < 0 and Save.coins == 0)
	Ads.simulate = true
	# --- bonus coins on the win screen
	Save.coins = 500
	g.start_level(2)
	await get_tree().create_timer(1.0).timeout
	for s3 in g.levels[2]["solution"]:
		g._on_tap(int(s3))
		await get_tree().create_timer(0.12).timeout
	var waited := 0
	while not g.hud.is_modal_open() and waited < 120:
		await get_tree().create_timer(0.05).timeout
		waited += 1
	await get_tree().create_timer(2.5).timeout
	var bonus: Button = null
	for b in g.hud._pop.find_children("*", "Button", true, false):
		if (b as Button).text.ends_with("COINS"):
			bonus = b
	var c0 := Save.coins
	var found_bonus := bonus != null
	if found_bonus:
		bonus.pressed.emit()
	await get_tree().create_timer(0.3).timeout
	check.call("win screen bonus pays the clear reward again", found_bonus and Save.coins > c0, "%d -> %d" % [c0, Save.coins])
	# --- interstitial pacing
	Ads._last_fullscreen = -1000.0
	Ads._wins_since_interstitial = 0
	Ads.interstitials_shown = 0
	var ran := [0]
	for k in 2:
		Ads.level_break(3, func(): ran[0] += 1)
	check.call("no interstitials while learning (first levels)", Ads.interstitials_shown == 0 and ran[0] == 2)
	Ads._wins_since_interstitial = 0
	for k in 3:
		Ads.level_break(20, func(): ran[0] += 1)
	check.call("one interstitial every 3 levels", Ads.interstitials_shown == 1)
	for k in 3:
		Ads.level_break(20, func(): ran[0] += 1)
	check.call("spaced at least 2 minutes apart", Ads.interstitials_shown == 1)
	check.call("the game always continues after a break", ran[0] == 8)
	print("ADTEST %s" % ("ALL OK" if fails[0] == 0 else "FAILURES: %d" % fails[0]))
	get_tree().quit(0 if fails[0] == 0 else 1)

## Random legal moves (seeded) until the level is lost. True if it was.
func _play_until_lost(seed_v: int) -> bool:
	var rng := RandomNumberGenerator.new()
	for attempt in 10:
		rng.seed = seed_v + attempt
		for k in 80:
			var legal := []
			for st in g.model.stacks.size():
				if g.model.check_tap(st) == "":
					legal.append(st)
			if legal.is_empty():
				break
			g._on_tap(legal[rng.randi_range(0, legal.size() - 1)])
			await get_tree().create_timer(0.05).timeout
			if g.model.finished:
				break
		var w := 0
		while g._ending and g.state == "playing" and w < 80:
			await get_tree().create_timer(0.05).timeout
			w += 1
		if g.state == "lost":
			return true
		g.start_level(g.current)
		await get_tree().create_timer(0.8).timeout
	return false

## --perf --breakdown: triangles and mesh instances per model, visible scene only.
func _tri_breakdown() -> void:
	var groups := {}
	var shadow_tris := 0
	for n in g.world.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if not mi.is_visible_in_tree() or mi.mesh == null:
			continue
		var tris := 0
		for si in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(si)
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			tris += idx.size() / 3 if idx.size() > 0 else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
		var key := mi.mesh.resource_name if mi.mesh.resource_name != "" else str(mi.get_parent().name).left(18) + "/" + str(mi.name).left(14)
		var e: Array = groups.get(key, [0, 0, 0])
		e[0] += 1
		e[1] += tris
		e[2] += mi.mesh.get_surface_count()
		groups[key] = e
		if mi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			shadow_tris += tris
	var keys := groups.keys()
	keys.sort_custom(func(a, b): return groups[a][1] > groups[b][1])
	var total := 0
	for k in keys:
		total += groups[k][1]
	print("BREAKDOWN total_tris=%d shadow_casting_tris=%d" % [total, shadow_tris])
	for k in keys.slice(0, 28):
		print("  %-36s inst=%3d tris=%7d surfaces=%d" % [k, groups[k][0], groups[k][1], groups[k][2]])
