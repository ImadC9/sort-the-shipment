class_name Menu
extends Control
## The menu shell: a shared top bar (rank, coins, settings) and a bottom tab bar
## switching between three pages: the level MAP, HOME (big play button over the
## live port) and the HARBOUR (cosmetic projects).

const TABS := ["map", "home", "harbour"]
const NAV_H := 150.0
const CHAPTERS := ["Training Docks", "Busy Harbour", "Storm Season", "Gold Coast", "Fog Bank",
	"Customs Week", "Rainbow Fleet", "Night Shift", "Long Haul", "Harbour Master"]

var hud: Hud
var unlocked := 1
var total := 30
var tab := ""
var coin_icon: Control
var _coin_label: Label
var _pages := {}
var _bgs := {}
var _nav := {}
var _harbour_badge: Control
var _top_h := 130.0
var _safe := 0.0
var _map_scroll: ScrollContainer
var _press_scroll := 0
var _top_fade: TextureRect

func _init(p_hud: Hud, p_unlocked: int, p_total: int) -> void:
	hud = p_hud
	unlocked = p_unlocked
	total = p_total
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _ready() -> void:
	_safe = UiKit.safe_top(get_viewport_rect().size)
	_top_h = 128.0 + _safe
	_build()

## Icon name (assets/ui/icons) for a harbour project.
static func project_glyph(id: String) -> String:
	return "p_" + id

static func project_color(id: String) -> Color:
	return {"lighthouse": Pal.BAD, "bunting": Pal.ACCENT, "cafe": Color("#b9825a"),
		"planters": Color("#ff72b6"), "fireworks": Pal.VIOLET, "fountain": Color("#1fc4c8"),
		"clocktower": Pal.SEA, "cranes": Color("#ffab1f"), "solar": Color("#ffab1f"),
		"lamps": Color("#f5a11a"), "flags": Pal.BAD, "pool": Color("#1fc4c8"), "gardens": Pal.GOOD,
		"icecream": Color("#ff72b6"), "fairylights": Pal.VIOLET, "monument": Color("#b9825a"),
		"liveries": Pal.SEA}.get(id, Pal.GOOD)

func refresh(p_unlocked: int, p_total: int) -> void:
	if p_unlocked == unlocked and p_total == total:
		refresh_coins()
		return
	unlocked = p_unlocked
	total = p_total
	for c in get_children():
		c.free()
	_pages.clear()
	_bgs.clear()
	_nav.clear()
	tab = ""
	_build()

func refresh_coins() -> void:
	if _coin_label:
		_coin_label.text = str(Save.coins)

func _build() -> void:
	# opaque backgrounds for the map and harbour pages (home shows the live port)
	_bgs["map"] = _gradient_bg(Color("#c6eefa"), Color("#4fb9ee"))
	_bgs["harbour"] = _gradient_bg(Color("#fff6e0"), Color("#ffe0b0"))
	var home_bg := _gradient_bg(Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.0))
	_bgs["home"] = home_bg
	_pages["home"] = _build_home()
	_pages["map"] = _build_map()
	_pages["harbour"] = _build_harbour()
	for k in TABS:
		_bgs[k].visible = false
		_pages[k].visible = false
	_top_fade = TextureRect.new()
	var gt := GradientTexture2D.new()
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.72, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	gt.gradient = g
	gt.fill_from = Vector2(0.5, 0)
	gt.fill_to = Vector2(0.5, 1)
	gt.width = 8
	gt.height = 64
	_top_fade.texture = gt
	_top_fade.stretch_mode = TextureRect.STRETCH_SCALE
	_top_fade.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_top_fade.offset_bottom = _top_h + 20
	_top_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_top_fade)
	_build_top_bar()
	_build_nav()

func _gradient_bg(a: Color, b: Color) -> TextureRect:
	var t := TextureRect.new()
	var gt := GradientTexture2D.new()
	var g := Gradient.new()
	g.colors = PackedColorArray([a, b])
	gt.gradient = g
	gt.fill_from = Vector2(0.5, 0)
	gt.fill_to = Vector2(0.5, 1)
	gt.width = 8
	gt.height = 256
	t.texture = gt
	t.set_anchors_preset(Control.PRESET_FULL_RECT)
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(t)
	return t

# ---------------------------------------------------------------- chrome

func _build_top_bar() -> void:
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_TOP_WIDE)
	m.add_theme_constant_override("margin_left", 20)
	m.add_theme_constant_override("margin_right", 20)
	m.add_theme_constant_override("margin_top", int(22 + _safe))
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(m)
	var bar := UiKit.hbox(14)
	m.add_child(bar)
	# rank pill (tap for the rank ladder)
	var rank := Button.new()
	rank.focus_mode = Control.FOCUS_NONE
	var psb := UiKit.pill_style(10, 6, 22, 12)
	for st in ["normal", "hover", "pressed", "hover_pressed"]:
		rank.add_theme_stylebox_override(st, psb)
	rank.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var rh := UiKit.hbox(8)
	rh.set_anchors_preset(Control.PRESET_FULL_RECT)
	rh.offset_left = 10
	rank.add_child(rh)
	var star := Icons.Star.new(52)
	star.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rh.add_child(star)
	var rv := UiKit.vbox(-8, BoxContainer.ALIGNMENT_CENTER)
	rh.add_child(rv)
	rv.add_child(UiKit.title(str(Save.total_stars()), 32, Pal.INK, Pal.INK, 0, HORIZONTAL_ALIGNMENT_LEFT))
	rv.add_child(UiKit.label(Save.rank_info()[0], 18, Pal.VIOLET, HORIZONTAL_ALIGNMENT_LEFT))
	rank.custom_minimum_size = Vector2(224, 84)
	rank.pressed.connect(hud.show_rank)
	UiKit.add_squish(rank)
	bar.add_child(rank)
	bar.add_child(UiKit.spacer(0, true))
	var cp := hud.coin_pill()
	coin_icon = cp[1]
	_coin_label = cp[2]
	cp[0].size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(cp[0])
	var gear := UiKit.icon_button(Icons.Glyph.new("settings", Pal.INK_SOFT), Color.WHITE, 84, 24)
	gear.pressed.connect(hud.show_settings)
	bar.add_child(gear)

func _build_nav() -> void:
	var nav := PanelContainer.new()
	nav.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	nav.offset_top = -NAV_H
	var sb := UiKit.style(Pal.PAPER, 0, 0, Pal.PAPER, 18)
	sb.shadow_offset = Vector2(0, -4)
	sb.corner_radius_top_left = 44
	sb.corner_radius_top_right = 44
	nav.add_theme_stylebox_override("panel", UiKit.margins(sb, 20, 10, 20, 14))
	nav.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(nav)
	var row := UiKit.hbox(0)
	nav.add_child(row)
	var defs := {"map": ["LEVELS", Icons.MapIcon.new()], "home": ["HOME", Icons.House.new()],
		"harbour": ["HARBOUR", Icons.Glyph.new("anchor")]}
	for k in TABS:
		var b := Button.new()
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for st in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
			b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
		row.add_child(b)
		var bubble := Panel.new()
		bubble.add_theme_stylebox_override("panel", UiKit._btn_style(Pal.SEA, false))
		bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(bubble)
		var icon: Control = defs[k][1]
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(icon)
		var cap := UiKit.title(defs[k][0], 22, Pal.INK)
		b.add_child(cap)
		var key: String = k
		b.pressed.connect(func():
			Sfx.play("click")
			switch_tab(key))
		b.resized.connect(func(): _layout_tab(key))
		_nav[k] = {"button": b, "bubble": bubble, "icon": icon, "cap": cap}
		if k == "harbour":
			_harbour_badge = UiKit.title("!", 26, Color.WHITE)
			_harbour_badge.add_theme_stylebox_override("normal", UiKit.margins(UiKit.style(Pal.BAD, 20, 3, Pal.BAD.darkened(0.2), 0), 15, 0, 15, 3))
			b.add_child(_harbour_badge)
			var nxt := Save.next_project()
			_harbour_badge.visible = not nxt.is_empty() and Save.coins >= int(nxt[2])

func _layout_tab(k: String) -> void:
	var t: Dictionary = _nav[k]
	var b: Button = t["button"]
	var active := k == tab
	var w := b.size.x
	var bubble: Panel = t["bubble"]
	bubble.visible = active
	bubble.size = Vector2(124, 96)
	bubble.position = Vector2((w - 124) * 0.5, -34)
	var icon: Control = t["icon"]
	var isz := 56.0 if active else 50.0
	icon.size = Vector2(isz, isz)
	icon.position = Vector2((w - isz) * 0.5, -18 if active else 14)
	var col := Color.WHITE if active else Pal.INK_FAINT
	if icon.has_method("set_color"):
		icon.call("set_color", col)
	var cap: Label = t["cap"]
	cap.size = Vector2(w, 34)
	cap.position = Vector2(0, 82)
	cap.add_theme_color_override("font_color", Pal.INK if active else Pal.INK_FAINT)
	if _harbour_badge and k == "harbour":
		_harbour_badge.position = Vector2(w * 0.5 + 18, -6)

## Show a page. Pages slide in from the side they sit on in the tab bar.
func switch_tab(k: String, animate := true) -> void:
	if k == tab:
		return
	var old := tab
	tab = k
	for n in TABS:
		_bgs[n].visible = n == k
	if _top_fade:
		_top_fade.visible = k != "home"
		_top_fade.modulate = Color("#c6eefa") if k == "map" else Color("#fff6e0")
	for n in _nav:
		_layout_tab(n)
	var page: Control = _pages[k]
	page.visible = true
	if old != "" and animate and not Save.reduce_motion:
		var dir := 1.0 if TABS.find(k) > TABS.find(old) else -1.0
		var w := get_viewport_rect().size.x
		var old_page: Control = _pages[old]
		page.position.x = w * dir * 0.35
		page.modulate.a = 0.0
		var tw := page.create_tween().set_parallel(true)
		tw.tween_property(page, "position:x", 0.0, 0.28).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		tw.tween_property(page, "modulate:a", 1.0, 0.18)
		old_page.visible = false
	else:
		page.position.x = 0
		page.modulate.a = 1.0
		for n in TABS:
			if n != k:
				_pages[n].visible = false
	if old != "" and old != k:
		_pages[old].visible = false
	if k == "map":
		_scroll_to_current()

func handle_back() -> bool:
	if tab != "home":
		switch_tab("home")
		return true
	return false

# ---------------------------------------------------------------- home

func _build_home() -> Control:
	var page := Control.new()
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(page)
	var v := UiKit.vbox(16)
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	page.add_child(v)
	v.add_child(UiKit.spacer(_top_h + 10))
	v.add_child(_logo())
	v.add_child(UiKit.spacer(0, true))
	# what the coins are for: builds right away when affordable, else opens the harbour
	var proj := Save.next_project()
	if not proj.is_empty():
		var pid: String = proj[0]
		var affordable := Save.coins >= int(proj[2])
		var strip := hud._project_strip(proj, func():
			hud.clear_overlay()
			hud.build_project_now(pid)) if affordable else hud._project_strip(proj)
		strip.custom_minimum_size = Vector2(560, 0)
		var sbtn := Button.new()
		sbtn.flat = true
		sbtn.focus_mode = Control.FOCUS_NONE
		for st in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
			sbtn.add_theme_stylebox_override(st, StyleBoxEmpty.new())
		sbtn.custom_minimum_size = Vector2(560, 112)
		strip.set_anchors_preset(Control.PRESET_FULL_RECT)
		strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sbtn.add_child(strip)
		sbtn.pressed.connect(func():
			if Save.coins >= int(proj[2]):
				hud.clear_overlay()
				hud.build_project_now(pid)
			else:
				switch_tab("harbour"))
		UiKit.add_squish(sbtn)
		v.add_child(UiKit.centered(sbtn))
	var resuming: bool = not Save.resume.is_empty()
	var play_lv: int = int(Save.resume.get("level", unlocked - 1)) + 1 if resuming else unlocked
	var play := UiKit.button("CONTINUE" if resuming else "PLAY  LEVEL %d" % play_lv, Hud.GREEN, 56, 520, 144)
	play.pressed.connect(func(): hud.play_pressed.emit())
	v.add_child(UiKit.centered(play))
	play.ready.connect(func(): UiKit.pulse(play), CONNECT_ONE_SHOT)
	if resuming:
		v.add_child(UiKit.title("Level %d in progress" % play_lv, 26, Color.WHITE, Pal.INK, 8))
	v.add_child(UiKit.spacer(NAV_H + 28))
	return page

## The wordmark: SORT stencilled on four little containers, over SHIPMENT.
func _logo() -> Control:
	var box := UiKit.vbox(0, BoxContainer.ALIGNMENT_CENTER)
	var row1 := UiKit.hbox(10, BoxContainer.ALIGNMENT_CENTER)
	var word := "SORT"
	for i in word.length():
		var c := Pal.cargo([0, 1, 2, 3][i])
		var tile := PanelContainer.new()
		tile.add_theme_stylebox_override("panel", UiKit.margins(UiKit._btn_style(c, false), 0, 0, 0, 12))
		tile.custom_minimum_size = Vector2(116, 128)
		tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# frame posts, like the containers in the yard
		for px in [0.0, 1.0]:
			var post := ColorRect.new()
			post.color = Color(0, 0, 0, 0.1)
			post.mouse_filter = Control.MOUSE_FILTER_IGNORE
			post.custom_minimum_size = Vector2(12, 0)
			post.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN if px == 0.0 else Control.SIZE_SHRINK_END
			tile.add_child(post)
		var l := UiKit.title(word[i], 92, Color.WHITE)
		l.add_theme_color_override("font_shadow_color", Color(c.darkened(0.4), 0.8))
		l.add_theme_constant_override("shadow_offset_x", 0)
		l.add_theme_constant_override("shadow_offset_y", 6)
		tile.add_child(l)
		tile.rotation = [-0.05, 0.03, -0.03, 0.05][i]
		row1.add_child(tile)
	box.add_child(row1)
	box.add_child(UiKit.spacer(18))
	var the := UiKit.title("THE", 34, Pal.ACCENT_2, Pal.INK, 10)
	box.add_child(the)
	var ship := UiKit.title("SHIPMENT", 108, Color.WHITE, Pal.INK, 22)
	ship.add_theme_color_override("font_shadow_color", Color(0.07, 0.15, 0.26, 0.35))
	ship.add_theme_constant_override("shadow_offset_y", 9)
	ship.add_theme_constant_override("shadow_outline_size", 22)
	box.add_child(ship)
	box.add_theme_constant_override("separation", -14)
	# tiles bounce in a gentle wave (scale only, so the layout stays put)
	for i in row1.get_child_count():
		var l: Control = row1.get_child(i)
		l.ready.connect(func():
			l.pivot_offset = l.size * 0.5
			if Save.reduce_motion:
				return
			var tw := l.create_tween().set_loops()
			tw.tween_interval(i * 0.18)
			tw.tween_property(l, "scale", Vector2(1.07, 1.07), 0.35).set_trans(Tween.TRANS_SINE)
			tw.tween_property(l, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK)
			tw.tween_interval(1.6 - i * 0.18), CONNECT_ONE_SHOT)
	return box

# ---------------------------------------------------------------- level map

func _node_pos(i: int, h: float) -> Vector2:
	var chapter := i / 10
	var y := h - 230.0 - i * 172.0 - chapter * 150.0
	return Vector2(360.0 + 165.0 * sin(i * 0.82), y)

func _build_map() -> Control:
	var page := Control.new()
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(page)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_bottom = -NAV_H + 40
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	page.add_child(scroll)
	_map_scroll = scroll
	var chapters := int(ceil(total / 10.0))
	var h := 230.0 + total * 172.0 + chapters * 150.0 + _top_h + 60.0
	var content := Control.new()
	content.custom_minimum_size = Vector2(720, h)
	content.mouse_filter = Control.MOUSE_FILTER_PASS
	scroll.add_child(content)
	# drifting wave marks for texture
	var waves := _Waves.new(h)
	waves.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.add_child(waves)
	var route := Icons.Route.new()
	route.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.add_child(route)
	var pts := []
	for i in total:
		pts.append(_node_pos(i, h))
	route.pts = pts
	route.reached = unlocked - 1
	# chapter signs
	for c in chapters:
		var first := c * 10
		var p := _node_pos(first, h)
		var rb := hud.ribbon("%s" % CHAPTERS[c % CHAPTERS.size()], [Pal.SEA_DEEP, Pal.ACCENT, Pal.VIOLET, Pal.GOOD, Color("#ffab1f"), Color("#1fb0b8"), Pal.BAD][c % 7], 30, 360)
		content.add_child(rb)
		rb.reset_size()
		rb.position = Vector2(360 - rb.custom_minimum_size.x * 0.5, p.y + 108)
		var sub := UiKit.title("Levels %d-%d" % [first + 1, min(first + 10, total)], 22, Color.WHITE, Color("#2a7fc0"), 6)
		sub.size = Vector2(720, 30)
		sub.position = Vector2(0, p.y + 108 + 66)
		content.add_child(sub)
	# level bubbles
	for i in total:
		var p: Vector2 = pts[i]
		var state := "done" if i + 1 < unlocked else ("current" if i + 1 == unlocked else "locked")
		if i + 1 <= unlocked and Save.get_stars(i + 1) > 0 and i + 1 == unlocked:
			state = "current"
		var stars := Save.get_stars(i + 1)
		var milestone := (i + 1) % 5 == 0
		var node := Icons.LevelNode.new(i + 1, state, stars, milestone)
		var btn := Button.new()
		btn.flat = true
		btn.focus_mode = Control.FOCUS_NONE
		for st in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
			btn.add_theme_stylebox_override(st, StyleBoxEmpty.new())
		btn.mouse_filter = Control.MOUSE_FILTER_PASS
		btn.size = node.size
		btn.position = p - node.size * 0.5
		btn.add_child(node)
		content.add_child(btn)
		UiKit.add_squish(btn)
		var idx := i
		btn.button_down.connect(func(): _press_scroll = scroll.scroll_vertical)
		btn.pressed.connect(func(): _on_node(idx, state))
		if state != "locked" and stars > 0:
			for k in 3:
				var s := Icons.Star.new(42 if k == 1 else 36, k < stars)
				s.position = p + Vector2((k - 1) * 40 - s.custom_minimum_size.x * 0.5, -node.size.y * 0.5 - 34 + (0 if k == 1 else 10) - s.custom_minimum_size.y * 0.5 + 18)
				s.size = s.custom_minimum_size
				s.rotation = (k - 1) * 0.25
				content.add_child(s)
		if milestone and Save.get_stars(i + 1) == 0:
			var crate := Icons.Crate.new(70)
			crate.size = crate.custom_minimum_size
			var side := 1.0 if p.x < 360 else -1.0
			crate.position = p + Vector2(side * 96 - 35, -40)
			content.add_child(crate)
		if state == "current":
			var pin := _Pin.new()
			pin.size = Vector2(100, 100)
			pin.z_index = 2
			pin.position = p + Vector2(-50, -node.size.y * 0.5 - 118)
			content.add_child(pin)
	return page

func _on_node(i: int, state: String) -> void:
	if abs(_map_scroll.scroll_vertical - _press_scroll) > 12:
		return   # that was a drag, not a tap
	if state == "locked":
		hud.toast("Finish level %d to unlock this one" % unlocked)
		return
	hud.show_level_info(i)

func _scroll_to_current() -> void:
	if _map_scroll == null:
		return
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_valid(_map_scroll):
		return
	var content: Control = _map_scroll.get_child(0)
	var p := _node_pos(clampi(unlocked - 1, 0, total - 1), content.custom_minimum_size.y)
	_map_scroll.scroll_vertical = int(p.y - _map_scroll.size.y * 0.55)

## A white map pin with the ship that's waiting at the current level.
class _Pin extends Control:
	var t := 0.0
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _process(d: float) -> void:
		t += d
		queue_redraw()
	func _draw() -> void:
		var bob := 0.0 if Save.reduce_motion else sin(t * 3.0) * 6.0
		var c := Vector2(size.x * 0.5, size.y * 0.42 + bob)
		var r := size.x * 0.4
		draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.55, r * 0.6), c + Vector2(r * 0.55, r * 0.6), c + Vector2(0, r * 1.45)]), Color("#fffdf7"))
		draw_circle(c + Vector2(0, 5), r, Color(0.07, 0.2, 0.4, 0.18), true, -1.0, true)
		draw_circle(c, r, Color("#fffdf7"), true, -1.0, true)
		draw_circle(c, r * 0.8, Pal.ACCENT, true, -1.0, true)
		var d := r * 1.05
		Icons.draw_fit(self, Icons.icon_tex("ship"), Rect2(c - Vector2(d, d) * 0.5, Vector2(d, d)), Color.WHITE)

## The chart behind the level route: the sea changes colour chapter by chapter
## (matching each chapter's weather), with islands, sailing boats, rocks and
## buoys on whichever side the route leaves free.
class _Waves extends Control:
	const SEA := [Color("#56c6ee"), Color("#3fb2ea"), Color("#6c9fbd"), Color("#4fc7bd"), Color("#9cc6d4"),
		Color("#4cbcec"), Color("#39a6e4"), Color("#2c4f96"), Color("#8a7fd0"), Color("#5a5cae")]
	var marks := []
	var decor := []      # [kind, x, y, scale, colour index]
	var h_total := 0.0
	func _init(h: float) -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		h_total = h
		var rng := RandomNumberGenerator.new()
		rng.seed = 11
		for i in int(h / 60.0):
			marks.append(Vector3(rng.randf_range(20, 700), rng.randf_range(0, h), rng.randf_range(14, 26)))
		# one decoration every ~260 px, on the side away from the route
		var y := h - 420.0
		var k := 0
		while y > 160.0:
			var i := _level_at(y)
			var rx := 360.0 + 165.0 * sin(i * 0.82)
			var x := rng.randf_range(560, 640) if rx < 360.0 else rng.randf_range(80, 160)
			var kind: String = ["island", "boat", "rocks", "boat", "island", "buoy"][k % 6]
			decor.append([kind, x, y + rng.randf_range(-30, 30), rng.randf_range(0.85, 1.15), rng.randi_range(0, 7)])
			y -= rng.randf_range(230, 300)
			k += 1
	func _level_at(y: float) -> float:
		# inverse of Menu._node_pos, ignoring the small chapter gaps
		return clampf((h_total - 230.0 - y) / 187.0, 0.0, 999.0)
	func _chapter_y(c: int) -> float:
		# y of the first level of chapter c
		return h_total - 230.0 - c * 10 * 172.0 - c * 150.0
	func _draw() -> void:
		# sea bands, blended across each chapter boundary
		var n := SEA.size()
		var stops := [[h_total + 400.0, SEA[0]]]
		for c in range(1, n):
			var by := _chapter_y(c) + 200.0
			stops.append([by, SEA[c - 1]])
			stops.append([by - 240.0, SEA[c]])
		stops.append([-400.0, SEA[n - 1]])
		for k in stops.size() - 1:
			var y0: float = stops[k][0]
			var y1: float = stops[k + 1][0]
			var c0: Color = stops[k][1]
			var c1: Color = stops[k + 1][1]
			draw_polygon(PackedVector2Array([Vector2(0, y1), Vector2(720, y1), Vector2(720, y0), Vector2(0, y0)]),
				PackedColorArray([c1, c1, c0, c0]))
		# long soft swells
		var y := 80.0
		var j := 0
		while y < h_total:
			var pts := PackedVector2Array()
			for x in range(-20, 760, 40):
				pts.append(Vector2(x, y + sin(x * 0.012 + j * 1.7) * 14.0))
			draw_polyline(pts, Color(1, 1, 1, 0.07), 26.0, true)
			y += 210.0
			j += 1
		for m in marks:
			var c := Vector2(m.x, m.y)
			draw_arc(c, m.z, PI * 1.18, PI * 1.82, 10, Color(1, 1, 1, 0.26), 4.0, true)
			draw_arc(c + Vector2(m.z * 1.2, 0), m.z, PI * 1.18, PI * 1.82, 10, Color(1, 1, 1, 0.26), 4.0, true)
		for d in decor:
			var at := Vector2(d[1], d[2])
			match d[0]:
				"island": _island(at, d[3])
				"boat": _boat(at, d[3], Pal.cargo(d[4]))
				"rocks": _rocks(at, d[3])
				"buoy": _buoy(at, d[3], Pal.cargo(d[4]))
	func _ellipse(c: Vector2, r: Vector2, col: Color) -> void:
		var pts := PackedVector2Array()
		for i in 32:
			var a := i * TAU / 32
			pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
		draw_colored_polygon(pts, col)
	func _island(c: Vector2, s: float) -> void:
		_ellipse(c + Vector2(0, 8 * s), Vector2(128, 58) * s, Color(1, 1, 1, 0.16))     # shallows
		_ellipse(c + Vector2(0, 8 * s), Vector2(108, 46) * s, Color(0.75, 0.98, 0.95, 0.5))
		_ellipse(c + Vector2(0, 7 * s), Vector2(88, 36) * s, Color("#e2c98f"))
		_ellipse(c, Vector2(84, 33) * s, Color("#f8e6b4"))
		_ellipse(c + Vector2(-10, -7) * s, Vector2(56, 21) * s, Color("#58c47c"))
		_ellipse(c + Vector2(-14, -11) * s, Vector2(44, 15) * s, Color("#7bd98d"))
		_palm(c + Vector2(18, -8) * s, s, 1.0)
		_palm(c + Vector2(-30, -12) * s, s * 0.72, -1.0)
	func _palm(base: Vector2, s: float, lean: float) -> void:
		var top := base + Vector2(12 * lean, -70) * s
		var mid := base + Vector2(2 * lean, -36) * s
		draw_polyline(PackedVector2Array([base, mid, top]), Color("#b98050"), 8.0 * s, true)
		for a in [-2.75, -2.1, -1.57, -1.0, -0.4]:
			var tip := top + Vector2(cos(a), sin(a) * 0.55 + 0.38) * 44.0 * s
			draw_line(top, tip, Color("#3fae6c"), 11.0 * s, true)
			draw_circle(tip, 5.5 * s, Color("#3fae6c"), true, -1.0, true)
		for a in [-2.4, -1.57, -0.75]:
			var tip2 := top + Vector2(cos(a), sin(a) * 0.5 + 0.2) * 30.0 * s
			draw_line(top, tip2, Color("#63cf86"), 7.0 * s, true)
		draw_circle(top, 7 * s, Color("#2f9a5c"), true, -1.0, true)
	func _boat(c: Vector2, s: float, col: Color) -> void:
		_ellipse(c + Vector2(0, 16 * s), Vector2(62, 13) * s, Color(1, 1, 1, 0.35))      # wake
		var hull := PackedVector2Array([c + Vector2(-44, -4) * s, c + Vector2(48, -4) * s, c + Vector2(34, 16) * s, c + Vector2(-32, 16) * s])
		draw_colored_polygon(hull, col.darkened(0.12))
		draw_colored_polygon(PackedVector2Array([c + Vector2(-44, -4) * s, c + Vector2(48, -4) * s, c + Vector2(44, 3) * s, c + Vector2(-41, 3) * s]), Color("#fffaf0"))
		draw_line(c + Vector2(0, -4) * s, c + Vector2(0, -82) * s, Color("#8d6a48"), 4.0 * s, true)
		draw_colored_polygon(PackedVector2Array([c + Vector2(5, -78) * s, c + Vector2(40, -14) * s, c + Vector2(5, -14) * s]), Color("#fffaf0"))
		draw_colored_polygon(PackedVector2Array([c + Vector2(-5, -66) * s, c + Vector2(-5, -14) * s, c + Vector2(-32, -14) * s]), col.lightened(0.15))
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -84) * s, c + Vector2(16, -78) * s, c + Vector2(0, -72) * s]), col)
	func _rocks(c: Vector2, s: float) -> void:
		_ellipse(c + Vector2(0, 14 * s), Vector2(70, 22) * s, Color(1, 1, 1, 0.3))
		for r in [[-22, 0, 30, 26], [16, -6, 36, 34], [44, 6, 18, 16]]:
			var q: Vector2 = c + Vector2(r[0], r[1]) * s
			_ellipse(q + Vector2(0, 4 * s), Vector2(r[2], r[3] * 0.8) * s, Color("#7f8ea3"))
			_ellipse(q + Vector2(-3, -4) * s, Vector2(r[2] * 0.8, r[3] * 0.55) * s, Color("#aab7c6"))
	func _buoy(c: Vector2, s: float, col: Color) -> void:
		_ellipse(c + Vector2(0, 16 * s), Vector2(34, 10) * s, Color(1, 1, 1, 0.4))
		draw_colored_polygon(PackedVector2Array([c + Vector2(-20, 14) * s, c + Vector2(20, 14) * s, c + Vector2(9, -26) * s, c + Vector2(-9, -26) * s]), col)
		draw_colored_polygon(PackedVector2Array([c + Vector2(-15.5, -4) * s, c + Vector2(15.5, -4) * s, c + Vector2(12.5, -15) * s, c + Vector2(-12.5, -15) * s]), Color("#fffaf0"))
		draw_circle(c + Vector2(0, -34) * s, 8 * s, Color("#ffe07a"), true, -1.0, true)

# ---------------------------------------------------------------- harbour

func _build_harbour() -> Control:
	var page := Control.new()
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(page)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_bottom = -NAV_H + 30
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	page.add_child(scroll)
	var m := MarginContainer.new()
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m.add_theme_constant_override("margin_left", 28)
	m.add_theme_constant_override("margin_right", 28)
	m.add_theme_constant_override("margin_top", int(_top_h + 6))
	m.add_theme_constant_override("margin_bottom", 70)
	m.mouse_filter = Control.MOUSE_FILTER_PASS
	scroll.add_child(m)
	var list := UiKit.vbox(16)
	list.mouse_filter = Control.MOUSE_FILTER_PASS
	m.add_child(list)
	# header
	var built := 0
	for p in Save.PROJECTS:
		if Save.has_project(p[0]):
			built += 1
	list.add_child(UiKit.title("YOUR HARBOUR", 54, Pal.INK))
	list.add_child(UiKit.label("Spend coins to build up the port", 25, Pal.INK_SOFT))
	var prog := UiKit.hbox(14, BoxContainer.ALIGNMENT_CENTER)
	var pb := Icons.Progress.new()
	pb.custom_minimum_size = Vector2(400, 26)
	pb.value = float(built) / Save.PROJECTS.size()
	prog.add_child(pb)
	prog.add_child(UiKit.title("%d/%d" % [built, Save.PROJECTS.size()], 30, Pal.INK))
	list.add_child(prog)
	list.add_child(UiKit.spacer(6))
	var nxt := Save.next_project()
	for p in Save.PROJECTS:
		list.add_child(_project_card(p, not nxt.is_empty() and nxt[0] == p[0]))
	return page

func _project_card(p: Array, is_next: bool) -> Control:
	var id: String = p[0]
	var done := Save.has_project(id)
	var cost := int(p[2])
	var can := Save.coins >= cost
	var card := PanelContainer.new()
	var bg := Color("#fffdf7") if (done or is_next) else Color(1, 0.99, 0.96, 0.6)
	var sb := UiKit.margins(UiKit.style(bg, 30, 7, Color("#ecd9b4") if not is_next else Color("#ffc533"), 8 if is_next else 0), 18, 16, 18, 20)
	if is_next:
		sb.set_border_width_all(4)
		sb.border_width_bottom = 9
	card.add_theme_stylebox_override("panel", sb)
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	var h := UiKit.hbox(16)
	card.add_child(h)
	var locked := not done and not is_next
	var tile := Icons.Tile.new(project_glyph(id), project_color(id) if not locked else Color("#c9d2da"), 92)
	tile.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(tile)
	var tv := UiKit.vbox(2)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(tv)
	tv.add_child(UiKit.title(p[1], 29, Pal.INK if not locked else Pal.INK_SOFT, Pal.INK, 0, HORIZONTAL_ALIGNMENT_LEFT))
	var dl := UiKit.label(p[3], 20, Pal.INK_SOFT, HORIZONTAL_ALIGNMENT_LEFT)
	dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dl.custom_minimum_size = Vector2(280, 0)
	tv.add_child(dl)
	if is_next and not can:
		var pbar := Icons.Progress.new()
		pbar.custom_minimum_size = Vector2(260, 16)
		pbar.value = float(Save.coins) / cost
		tv.add_child(UiKit.spacer(4))
		tv.add_child(pbar)
	var right := UiKit.vbox(4, BoxContainer.ALIGNMENT_CENTER)
	right.custom_minimum_size = Vector2(150, 0)
	h.add_child(right)
	if done:
		right.add_child(UiKit.centered(Icons.Tile.new("check", Pal.GOOD, 64)))
		right.add_child(UiKit.title("BUILT", 22, Pal.GOOD.darkened(0.1)))
	elif is_next:
		var b := UiKit.button("BUILD", Hud.GREEN, 32, 150, 80)
		b.disabled = not can
		b.mouse_filter = Control.MOUSE_FILTER_PASS
		b.pressed.connect(func():
			if Save.coins >= cost:
				hud.clear_overlay()
				hud.build_project_now(id))
		right.add_child(b)
		var price := UiKit.hbox(6, BoxContainer.ALIGNMENT_CENTER)
		price.add_child(Icons.Coin.new(32))
		price.add_child(UiKit.title(str(cost), 28, Pal.INK if can else Pal.INK_SOFT))
		right.add_child(price)
		if can:
			b.ready.connect(func(): UiKit.pulse(b), CONNECT_ONE_SHOT)
	else:
		right.add_child(UiKit.centered(Icons.Lock.new(48)))
		var price := UiKit.hbox(6, BoxContainer.ALIGNMENT_CENTER)
		price.add_child(Icons.Coin.new(28))
		price.add_child(UiKit.title(str(cost), 26, Pal.INK_FAINT))
		right.add_child(price)
	return card
