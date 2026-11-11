class_name Hud
extends CanvasLayer
## All 2D UI. Layers, back to front:
##   game_ui  - in-level chrome (top bar, next ships, parking gauge, boosters)
##   _overlay - the menu shell (home / level map / harbour, see menu.gd)
##   _pop     - modal popups: pause, settings, level info, win, lose
##   effects  - popups, stamps, coins, toasts, fades

signal play_pressed
signal level_chosen(index: int)
signal next_pressed
signal retry_pressed
signal undo_pressed
signal hint_pressed
signal continue_pressed
signal home_pressed
signal project_built(id: String)
signal ad_rescue_pressed

const COST_HINT := 25
const COST_SLOT := 60
const BLUE := Color("#3d8ef5")
const GREEN := Color("#2fc272")
const PURPLE := Color("#9364f0")
const AMBER := Color("#ffab1f")
const DIM := Color(0.07, 0.16, 0.28)

var root: Control
var game_ui: Control
var level_names: Array = []
var _level_cap: Label
var _level_name: Label
var _coin_label: Label
var _coin_icon: Control
var _coin_pill: PanelContainer
var _queue_box: HBoxContainer
var _undo_btn: Button
var _undo_badge: Label
var _hint_btn: Button
var _hint_badge: Label
var _overlay: Control
var _pop: Control
var _fx: Control
var _toast: Label
var _shown_coins := 0
var _fade: ColorRect
var _live_stars: Array = []
var _chain_notice: Control
var _coach: PanelContainer
var _manifest: HBoxContainer
var _buf_pill: PanelContainer
var _buf_pips: HBoxContainer
var _buf_label: Label
var _coin_tween: Tween
var _menu: Menu
var _modal_back: Callable      # what Android back does while a modal is open
var _hint_free := true

func _ready() -> void:
	layer = 5
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	# soft vignette pulls the eye to the middle of the yard
	var vig := TextureRect.new()
	var vt := GradientTexture2D.new()
	var vg := Gradient.new()
	vg.offsets = PackedFloat32Array([0.0, 0.62, 1.0])
	vg.colors = PackedColorArray([Color(0.08, 0.2, 0.35, 0.0), Color(0.08, 0.2, 0.35, 0.0), Color(0.08, 0.2, 0.35, 0.13)])
	vt.gradient = vg
	vt.fill = GradientTexture2D.FILL_RADIAL
	vt.fill_from = Vector2(0.5, 0.5)
	vt.fill_to = Vector2(1.08, 1.0)
	vt.width = 256
	vt.height = 256
	vig.texture = vt
	vig.set_anchors_preset(Control.PRESET_FULL_RECT)
	vig.stretch_mode = TextureRect.STRETCH_SCALE
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(vig)
	_build_game_ui()
	for n in ["_overlay", "_pop", "_fx"]:
		var c := Control.new()
		c.set_anchors_preset(Control.PRESET_FULL_RECT)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(c)
		set(n, c)
	_toast = UiKit.label("", 28, Color.WHITE)
	_toast.add_theme_stylebox_override("normal", UiKit.margins(UiKit.style(Color(Pal.INK, 0.94), 30, 0, Color.BLACK, 8), 30, 14, 30, 14))
	_toast.modulate.a = 0.0
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast.custom_minimum_size = Vector2(0, 0)
	_fx.add_child(_toast)
	_shown_coins = Save.coins
	_coin_label.text = str(_shown_coins)
	_fade = ColorRect.new()
	_fade.color = Color(1, 1, 1, 0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_fade)

func _vp() -> Vector2:
	return root.get_viewport_rect().size

# ================================================================ in-game HUD

func _build_game_ui() -> void:
	game_ui = Control.new()
	game_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	game_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(game_ui)
	var safe := UiKit.safe_top(_vp())

	# top bar: pause | level | coins
	var top := MarginContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.add_theme_constant_override("margin_left", 20)
	top.add_theme_constant_override("margin_right", 20)
	top.add_theme_constant_override("margin_top", int(22 + safe))
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game_ui.add_child(top)
	var col := UiKit.vbox(12)
	top.add_child(col)
	var bar := UiKit.hbox(14)
	col.add_child(bar)
	var pause := UiKit.icon_button(Icons.Pause.new(Pal.INK), Color.WHITE, 84, 26)
	pause.pressed.connect(show_pause)
	bar.add_child(pause)
	var lp := PanelContainer.new()
	lp.add_theme_stylebox_override("panel", UiKit.pill_style(16, 4, 16, 10))
	lp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(lp)
	var lv := UiKit.vbox(-8, BoxContainer.ALIGNMENT_CENTER)
	lp.add_child(lv)
	_level_cap = UiKit.title("LEVEL 1", 36, Pal.INK)
	_level_name = UiKit.label("First Shift", 20, Pal.INK_SOFT)
	lv.add_child(_level_cap)
	lv.add_child(_level_name)
	var cv := coin_pill()
	_coin_pill = cv[0]
	_coin_icon = cv[1]
	_coin_label = cv[2]
	_coin_pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(_coin_pill)

	# next ships (+ the covered-cargo manifest on covered levels)
	var info := PanelContainer.new()
	info.add_theme_stylebox_override("panel", UiKit.pill_style(20, 8, 18, 14))
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(info)
	var iv := UiKit.vbox(6)
	info.add_child(iv)
	var qrow := UiKit.hbox(10)
	iv.add_child(qrow)
	qrow.add_child(UiKit.title("NEXT", 24, Pal.INK_SOFT))
	_queue_box = UiKit.hbox(6)
	_queue_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	qrow.add_child(_queue_box)
	_manifest = UiKit.hbox(8)
	_manifest.visible = false
	iv.add_child(_manifest)

	# parking gauge with the live stars
	var mid := UiKit.hbox(10, BoxContainer.ALIGNMENT_CENTER)
	mid.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	mid.offset_top = -272
	mid.offset_bottom = -206
	game_ui.add_child(mid)
	_buf_pill = PanelContainer.new()
	_buf_pill.add_theme_stylebox_override("panel", UiKit.pill_style(20, 6, 14, 12))
	_buf_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mid.add_child(_buf_pill)
	var bh := UiKit.hbox(10)
	_buf_pill.add_child(bh)
	_buf_label = UiKit.title("PARKING", 22, Pal.INK_SOFT)
	bh.add_child(_buf_label)
	_buf_pips = UiKit.hbox(6)
	bh.add_child(_buf_pips)
	var sp := UiKit.hbox(-6)
	bh.add_child(sp)
	for k in 3:
		var st := Icons.Star.new(36, true)
		sp.add_child(st)
		_live_stars.append(st)

	# boosters
	var bottom := UiKit.hbox(30, BoxContainer.ALIGNMENT_CENTER)
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -184
	bottom.offset_bottom = -38
	game_ui.add_child(bottom)
	var u := _booster("undo", BLUE, "UNDO")
	_undo_btn = u[0]
	_undo_badge = u[1]
	_undo_btn.pressed.connect(func(): undo_pressed.emit())
	bottom.add_child(u[2])
	var h := _booster("hint", AMBER, "HINT")
	_hint_btn = h[0]
	_hint_badge = h[1]
	_hint_btn.pressed.connect(func(): hint_pressed.emit())
	bottom.add_child(h[2])
	var r := _booster("retry", GREEN, "RETRY")
	r[0].pressed.connect(func(): retry_pressed.emit())
	r[1].visible = false
	bottom.add_child(r[2])
	set_hint_free(true)

## [pill, coin icon, label]
func coin_pill() -> Array:
	var p := UiKit.pill()
	var h := UiKit.hbox(8)
	p.add_child(h)
	var ci := Icons.Coin.new(48)
	h.add_child(ci)
	var l := UiKit.title(str(Save.coins), 34, Pal.INK)
	l.custom_minimum_size = Vector2(70, 0)
	h.add_child(l)
	return [p, ci, l]

## [button, badge, column]. A paper key with its icon and caption inside.
func _booster(icon: String, col: Color, caption: String) -> Array:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(176, 132)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var glyph := Icons.Glyph.new(icon, col)
	var b := UiKit.icon_button(glyph, Color.WHITE, 132, 34)
	b.custom_minimum_size = Vector2(176, 132)
	b.size = Vector2(176, 132)
	glyph.offset_left = 54
	glyph.offset_right = -54
	glyph.offset_top = 16
	glyph.offset_bottom = -54
	var cap := UiKit.title(caption, 24, Pal.INK_SOFT)
	cap.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	cap.offset_top = -52
	cap.offset_bottom = -18
	b.add_child(cap)
	holder.add_child(b)
	var badge := UiKit.title("", 24, Color.WHITE)
	badge.add_theme_stylebox_override("normal", UiKit.margins(UiKit.style(GREEN, 20, 4, GREEN.darkened(0.25), 0), 12, 0, 12, 2))
	badge.position = Vector2(124, -14)
	badge.custom_minimum_size = Vector2(46, 44)
	holder.add_child(badge)
	return [b, badge, holder]

func _set_badge(badge: Label, text: String, col: Color) -> void:
	badge.text = text
	badge.add_theme_stylebox_override("normal", UiKit.margins(UiKit.style(col, 20, 4, col.darkened(0.22), 3), 12, 0, 12, 2))

func set_level(index: int, data: Dictionary) -> void:
	_level_cap.text = "LEVEL %d" % (index + 1)
	_level_name.text = data.get("name", "")

func set_undos(n: int) -> void:
	_undo_badge.visible = true
	_set_badge(_undo_badge, str(n), BLUE if n > 0 else Pal.INK_FAINT)
	_undo_btn.disabled = n <= 0

## The first hint each level is free; after that it costs coins.
func set_hint_free(free: bool) -> void:
	set_hint_mode("free" if free else "coins")

## How the next hint is paid for: free | coins | ad (watch an ad instead of coins).
func set_hint_mode(mode: String) -> void:
	_hint_free = mode == "free"
	match mode:
		"free":
			_set_badge(_hint_badge, "FREE", GREEN)
		"ad":
			_set_badge(_hint_badge, "AD", PURPLE)
		_:
			_set_badge(_hint_badge, str(COST_HINT), AMBER)

func set_queue(colors: Array) -> void:
	for c in _queue_box.get_children():
		c.queue_free()
	if colors.is_empty():
		_queue_box.add_child(UiKit.label("last ships at the quay!", 22, Pal.INK_SOFT, HORIZONTAL_ALIGNMENT_LEFT))
		return
	# the very next arrival gets a bigger, outlined chip
	var first := PanelContainer.new()
	var fsb := UiKit.style(Color("#fff1c9"), 16, 0, Color("#ffc533"), 0)
	fsb.set_border_width_all(3)
	first.add_theme_stylebox_override("panel", UiKit.margins(fsb, 8, 5, 8, 5))
	first.mouse_filter = Control.MOUSE_FILTER_IGNORE
	first.add_child(Icons.ShipChip.new(colors[0], 48))
	_queue_box.add_child(first)
	var shown: int = min(colors.size(), 6)
	for i in range(1, shown):
		var chip := Icons.ShipChip.new(colors[i], 38)
		chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_queue_box.add_child(chip)
	if colors.size() > shown:
		_queue_box.add_child(UiKit.title("+%d" % (colors.size() - shown), 24, Pal.INK_SOFT))

## Under-tarp manifest: colour counts still hidden, so covered cargo is planned, not guessed.
func set_manifest(counts: Dictionary) -> void:
	for c in _manifest.get_children():
		c.free()
	var total := 0
	for k in counts:
		total += counts[k]
	_manifest.visible = total > 0
	if total == 0:
		return
	_manifest.add_child(UiKit.title("COVERED", 20, Color("#a08c68")))
	var keys := counts.keys()
	keys.sort()
	for c in keys:
		var ms := UiKit.symbol(c, 24, Pal.cargo(c))
		ms.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_manifest.add_child(ms)
		_manifest.add_child(UiKit.title("%d " % counts[c], 22, Pal.INK))

## Parking gauge. Spots up to `three` keep all 3 stars (green zone), up to `two`
## keep 2 (orange zone), beyond that only 1 (red zone). Empty spots show their zone.
func set_buffer(used: int, size: int, three: int = 99, two: int = 99) -> void:
	var free := size - used
	if _buf_pips.get_child_count() != size:
		for c in _buf_pips.get_children():
			c.free()
		for i in size:
			var pip := Panel.new()
			pip.custom_minimum_size = Vector2(30, 28)
			pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_buf_pips.add_child(pip)
	for i in size:
		var pip: Panel = _buf_pips.get_child(i)
		var zone := Pal.GOOD if i < three else (AMBER if i < two else Pal.BAD)
		var sb: StyleBoxFlat
		if i < used:
			sb = UiKit.style(zone, 10, 4, zone.darkened(0.22), 0)
		else:
			sb = UiKit.style(zone.lerp(Pal.PAPER, 0.8), 10, 0, zone, 0)
			sb.set_border_width_all(3)
			sb.border_color = zone.lerp(Pal.PAPER, 0.35)
		pip.add_theme_stylebox_override("panel", UiKit.margins(sb, 0, 0, 0, 0))
	_buf_label.text = "PARKING" if free > 1 else ("LAST SPOT!" if free == 1 else "FULL!")
	_buf_label.add_theme_color_override("font_color", Pal.INK_SOFT if free > 1 else (Color("#e88a00") if free == 1 else Pal.BAD))
	if free <= 1 and used > 0:
		_buf_pill.pivot_offset = _buf_pill.size * 0.5
		var tw := _buf_pill.create_tween()
		tw.tween_property(_buf_pill, "scale", Vector2(1.1, 1.1), 0.08)
		tw.tween_property(_buf_pill, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_ELASTIC)

## Live stars beside the parking gauge. Losing one is quiet: just a grey star.
func set_stars(n: int) -> void:
	for k in 3:
		var st: Icons.Star = _live_stars[k]
		var want := k < n
		if st.filled != want:
			st.set_filled(want)
			if not want:
				st.pivot_offset = st.size * 0.5
				var tw := st.create_tween()
				tw.tween_property(st, "scale", Vector2(1.3, 1.3), 0.08)
				tw.tween_property(st, "scale", Vector2.ONE, 0.25)

## A short tip bubble just under the top bar (covers only the town).
func coach(text: String, seconds: float = 7.0) -> void:
	hide_coach()
	_coach = PanelContainer.new()
	_coach.add_theme_stylebox_override("panel", UiKit.pill_style(20, 14, 26, 20))
	_coach.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := UiKit.hbox(14)
	_coach.add_child(h)
	var bulb := Icons.Tile.new("hint", AMBER, 58)
	bulb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(bulb)
	var l := UiKit.label(text, 25, Pal.INK, HORIZONTAL_ALIGNMENT_LEFT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(500, 0)
	h.add_child(l)
	_fx.add_child(_coach)
	_coach.reset_size()
	var vp := _vp()
	_coach.position = Vector2((vp.x - _coach.size.x) * 0.5, 236 + UiKit.safe_top(vp))
	_coach.modulate.a = 0.0
	_coach.pivot_offset = _coach.size * 0.5
	_coach.scale = Vector2(0.85, 0.85)
	var c := _coach
	var tw := c.create_tween()
	tw.tween_property(c, "modulate:a", 1.0, 0.2)
	tw.parallel().tween_property(c, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(seconds)
	tw.tween_property(c, "modulate:a", 0.0, 0.4)
	tw.tween_callback(c.queue_free)

func hide_coach() -> void:
	if _coach and is_instance_valid(_coach):
		var c := _coach
		var tw := c.create_tween()
		tw.tween_property(c, "modulate:a", 0.0, 0.2)
		tw.tween_callback(c.queue_free)
	_coach = null

func set_game_visible(v: bool) -> void:
	game_ui.visible = v

func refresh_coins(animated := true) -> void:
	var target := Save.coins
	if _menu and is_instance_valid(_menu):
		_menu.refresh_coins()
	if _coin_tween:
		_coin_tween.kill()
	if not animated:
		_shown_coins = target
		_coin_label.text = str(target)
		return
	_coin_tween = create_tween()
	_coin_tween.tween_method(func(v: float):
		_shown_coins = int(v)
		_coin_label.text = str(_shown_coins), float(_shown_coins), float(target), 0.5)
	_coin_pill.pivot_offset = _coin_pill.size * 0.5
	var tw := _coin_pill.create_tween()
	tw.tween_property(_coin_pill, "scale", Vector2(1.12, 1.12), 0.08)
	tw.tween_property(_coin_pill, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)

# ================================================================ effects

## Big rubber-stamp text that slams onto the screen.
func stamp(text: String, at: Vector2, col: Color) -> void:
	var l := UiKit.title(text, 40, col)
	var sb := UiKit.margins(UiKit.style(Color(Pal.PAPER, 0.96), 18, 0, col, 6), 18, 2, 18, 4)
	sb.set_border_width_all(5)
	sb.border_color = col
	l.add_theme_stylebox_override("normal", sb)
	_fx.add_child(l)
	l.reset_size()
	var vp := _vp()
	var pos := at - l.size * 0.5
	pos.x = clampf(pos.x, 16.0, vp.x - l.size.x - 16.0)
	pos.y = clampf(pos.y, 300.0, vp.y - 400.0)
	l.position = pos
	l.pivot_offset = l.size * 0.5
	l.rotation = deg_to_rad(randf_range(-9, -4))
	l.scale = Vector2(2.4, 2.4)
	l.modulate.a = 0.0
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(l, "modulate:a", 1.0, 0.1)
	tw.chain().tween_callback(func(): Sfx.play("stamp", randf_range(0.95, 1.05), -3.0))
	tw.chain().tween_interval(0.75)
	tw.chain().tween_property(l, "modulate:a", 0.0, 0.3)
	tw.chain().tween_callback(l.queue_free)

## Ribbon label: [holder control]. Width adapts to the text.
func ribbon(text: String, col: Color, size := 46, min_w := 460) -> Control:
	var l := UiKit.title(text, size, Color.WHITE)
	l.add_theme_color_override("font_shadow_color", Color(col.darkened(0.4), 0.8))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", max(2, int(size * 0.08)))
	var w: float = max(min_w, Pal.font_display().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + size * 3.2)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(w, size * 2.0)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rb := Icons.Ribbon.new(col)
	rb.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.add_child(rb)
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.offset_bottom = -size * 0.2
	holder.add_child(l)
	return holder

## Level intro banner.
func banner(title_text: String, subtitle: String) -> void:
	var box := UiKit.vbox(4)
	box.add_child(ribbon(title_text, Pal.ACCENT, 54, 420))
	box.add_child(UiKit.title(subtitle, 34, Color.WHITE, Pal.INK, 10))
	_fx.add_child(box)
	box.reset_size()
	var vp := _vp()
	box.position = Vector2(vp.x + 40, vp.y * 0.36)
	var tw := box.create_tween()
	tw.tween_property(box, "position:x", (vp.x - box.size.x) * 0.5, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.0)
	tw.tween_property(box, "position:x", -box.size.x - 40, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(box.queue_free)

## Quick white flash used between screens.
func flash_transition() -> void:
	_fade.color.a = 0.85
	var tw := _fade.create_tween()
	tw.tween_property(_fade, "color:a", 0.0, 0.45).set_trans(Tween.TRANS_QUAD)

func popup(text: String, at: Vector2, col: Color, big := false) -> void:
	var l := UiKit.title(text, 68 if big else 50, col, Pal.PAPER, 14)
	l.add_theme_color_override("font_shadow_color", Color(0.11, 0.21, 0.34, 0.3))
	l.add_theme_constant_override("shadow_offset_y", 5)
	_fx.add_child(l)
	l.reset_size()
	var vp := _vp()
	var pos := at - l.size * 0.5
	pos.x = clampf(pos.x, 16.0, vp.x - l.size.x - 16.0)
	pos.y = clampf(pos.y, 260.0, vp.y - 360.0)
	l.position = pos
	l.pivot_offset = l.size * 0.5
	l.scale = Vector2(0.3, 0.3)
	l.rotation = randf_range(-0.12, 0.12)
	var tw := l.create_tween()
	tw.tween_property(l, "scale", Vector2.ONE * (1.15 if big else 1.0), 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "position:y", l.position.y - 90, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.3)
	tw.tween_callback(l.queue_free)

## Coins burst out of a point and fly into whichever coin counter is on screen.
func fly_coins(from: Vector2, amount: int, n := 6) -> void:
	var icon: Control = _coin_icon
	if _menu and is_instance_valid(_menu) and _menu.visible:
		icon = _menu.coin_icon
	var target := icon.get_global_rect().get_center()
	for i in n:
		var c := Icons.Coin.new(38)
		_fx.add_child(c)
		c.position = from - Vector2(19, 19)
		var spread := Vector2(randf_range(-90, 90), randf_range(-110, -30))
		var tw := c.create_tween()
		tw.tween_property(c, "position", c.position + spread, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).set_delay(i * 0.03)
		tw.tween_property(c, "position", target - Vector2(19, 19), 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(c, "scale", Vector2(0.7, 0.7), 0.5)
		tw.tween_callback(func():
			c.queue_free()
			if i == 0:
				Sfx.play("coin", randf_range(1.0, 1.15), -4.0)
			if i == n - 1:
				refresh_coins())
	if amount >= 20:
		popup("+%d" % amount, from + Vector2(0, -40), Color("#ffb020"), false)

func toast(text: String) -> void:
	_toast.text = text
	var vp := _vp()
	var w := Pal.font_ui().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x + 64
	_toast.autowrap_mode = TextServer.AUTOWRAP_OFF if w <= vp.x - 60 else TextServer.AUTOWRAP_WORD_SMART
	_toast.custom_minimum_size = Vector2(min(w, vp.x - 60), 0)
	_toast.size = Vector2.ZERO
	_toast.reset_size()
	_toast.position = Vector2((vp.x - _toast.size.x) * 0.5, 236 + UiKit.safe_top(vp))
	var tw := _toast.create_tween()
	_toast.modulate.a = 0.0
	tw.tween_property(_toast, "modulate:a", 1.0, 0.15)
	tw.tween_interval(1.6)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.3)

func bump(btn_name: String) -> void:
	var b: Button = {"hint": _hint_btn, "undo": _undo_btn}.get(btn_name)
	if b and b.is_inside_tree():
		b.pivot_offset = b.size * 0.5
		var tw := b.create_tween()
		tw.tween_property(b, "scale", Vector2(1.15, 1.15), 0.08)
		tw.tween_property(b, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_ELASTIC)

## The signature moment: several ships sent off by one tap.
func chain_callout(ships: int, from_buffer: int, bonus: int) -> void:
	if is_instance_valid(_chain_notice):
		_chain_notice.queue_free()
	var t_text := "QUAY CLEARED!"
	var col := Pal.SEA
	if ships >= 3:
		t_text = "TRIPLE DISPATCH!" if ships == 3 else "MEGA DISPATCH x%d!" % ships
		col = Pal.BAD
	elif ships == 2:
		t_text = "DOUBLE DISPATCH!"
		col = Pal.ACCENT
	var box := PanelContainer.new()
	_chain_notice = box
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var csb := UiKit.style(col, 26, 6, col.darkened(0.22), 8)
	box.add_theme_stylebox_override("panel", UiKit.margins(csb, 26, 8, 26, 14))
	box.add_child(UiKit.title(t_text + ("  +%d" % bonus if bonus > 0 else ""), 34, Color.WHITE))
	_fx.add_child(box)
	box.reset_size()
	var vp := _vp()
	box.position = Vector2((vp.x - box.size.x) * 0.5, vp.y * 0.56)
	box.pivot_offset = box.size * 0.5
	box.modulate.a = 0.0
	var tw := box.create_tween()
	tw.tween_property(box, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.95)
	tw.tween_property(box, "modulate:a", 0.0, 0.18)
	tw.tween_callback(box.queue_free)

func _flash_edges(col: Color) -> void:
	var vig := TextureRect.new()
	var vt := GradientTexture2D.new()
	var vg := Gradient.new()
	vg.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	var c0 := col
	c0.a = 0.0
	var c1 := col
	c1.a = 0.55
	vg.colors = PackedColorArray([c0, c0, c1])
	vt.gradient = vg
	vt.fill = GradientTexture2D.FILL_RADIAL
	vt.fill_from = Vector2(0.5, 0.5)
	vt.fill_to = Vector2(1.1, 1.0)
	vt.width = 128
	vt.height = 128
	vig.texture = vt
	vig.set_anchors_preset(Control.PRESET_FULL_RECT)
	vig.stretch_mode = TextureRect.STRETCH_SCALE
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx.add_child(vig)
	var tw := vig.create_tween()
	tw.tween_property(vig, "modulate:a", 0.0, 0.8)
	tw.tween_callback(vig.queue_free)

## 2D fireworks over the top of the screen (Victory Fireworks project).
func fireworks(duration: float) -> void:
	var vp := _vp()
	var n := int(duration * 2.2)
	for i in n:
		get_tree().create_timer(i * duration / n).timeout.connect(func():
			var p := CPUParticles2D.new()
			p.one_shot = true
			p.amount = 46
			p.lifetime = 1.1
			p.explosiveness = 1.0
			p.spread = 180
			p.initial_velocity_min = 180
			p.initial_velocity_max = 320
			p.gravity = Vector2(0, 260)
			p.damping_min = 60
			p.damping_max = 90
			p.scale_amount_min = 9
			p.scale_amount_max = 15
			p.color = Pal.cargo(randi() % 7).lightened(0.2)
			var ramp := Gradient.new()
			ramp.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
			p.color_ramp = ramp
			p.position = Vector2(randf_range(80, vp.x - 80), randf_range(vp.y * 0.08, vp.y * 0.3))
			_fx.add_child(p)
			p.emitting = true
			Sfx.play("pick", randf_range(1.6, 2.0), -10.0)
			get_tree().create_timer(1.6).timeout.connect(p.queue_free))

# ================================================================ modals

func clear_overlay() -> void:
	if is_instance_valid(_chain_notice):
		_chain_notice.queue_free()
	close_modal()
	for c in _overlay.get_children():
		c.queue_free()
	_menu = null
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

func close_modal() -> void:
	_pop.visible = true
	for c in _pop.get_children():
		c.queue_free()
	_pop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_modal_back = Callable()

func is_overlay_open() -> bool:
	return _pop.get_child_count() > 0 or _overlay.get_child_count() > 0

func is_modal_open() -> bool:
	return _pop.get_child_count() > 0

## Android back: closes a dismissable popup, or steps a menu tab back home.
## Returns false when there was nothing to step back from.
func handle_back() -> bool:
	if is_modal_open():
		if _modal_back.is_valid():
			_modal_back.call()
			return true
		return false
	if _menu and is_instance_valid(_menu):
		return _menu.handle_back()
	return false

func _dim(alpha := 0.55) -> ColorRect:
	close_modal()
	hide_coach()
	_pop.mouse_filter = Control.MOUSE_FILTER_STOP
	var d := ColorRect.new()
	d.color = Color(DIM.r, DIM.g, DIM.b, 0.0)
	d.set_anchors_preset(Control.PRESET_FULL_RECT)
	d.mouse_filter = Control.MOUSE_FILTER_STOP
	_pop.add_child(d)
	d.create_tween().tween_property(d, "color:a", alpha * 0.82, 0.22)
	return d

## A modal: ribbon on top of a white card, optional close X. Returns the card's
## content column. `on_close` (if valid) is wired to the X and to Android back.
func modal(title_text: String, col: Color, width := 600, on_close: Callable = Callable(), alpha := 0.55) -> VBoxContainer:
	_dim(alpha)
	_modal_back = on_close
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pop.add_child(center)
	var wrap := UiKit.vbox(-34)
	center.add_child(wrap)
	var rb := ribbon(title_text, col, 44, width - 80)
	rb.z_index = 2
	rb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	wrap.add_child(rb)
	var panel := PanelContainer.new()
	var sb := UiKit.card_style()
	sb.content_margin_top = 64
	panel.add_theme_stylebox_override("panel", sb)
	panel.custom_minimum_size = Vector2(width, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	wrap.add_child(panel)
	var v := UiKit.vbox(20, BoxContainer.ALIGNMENT_CENTER)
	panel.add_child(v)
	wrap.ready.connect(func(): UiKit.pop_in(wrap), CONNECT_ONE_SHOT)
	if on_close.is_valid():
		var x := UiKit.close_button()
		x.pressed.connect(on_close)
		x.z_index = 3
		_pop.add_child(x)
		x.modulate.a = 0.0
		panel.resized.connect(func():
			var r := panel.get_global_rect()
			x.position = Vector2(r.end.x - 56, r.position.y - 18))
		var tw := x.create_tween()
		tw.tween_interval(0.25)
		tw.tween_property(x, "modulate:a", 1.0, 0.15)
	return v

## A button marked with a play badge: tapping it plays a rewarded ad.
func _ad_button(text: String, col: Color, size: int, w: int, h: int) -> Button:
	var b := UiKit.button("      " + text, col, size, w, h)
	var badge := PanelContainer.new()
	badge.add_theme_stylebox_override("panel", UiKit.margins(UiKit.style(Color(Pal.PAPER, 0.97), 18), 10, 2, 12, 4))
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bh := UiKit.hbox(4)
	badge.add_child(bh)
	var tri := Icons.Glyph.new("play", col)
	tri.custom_minimum_size = Vector2(24, 24)
	bh.add_child(tri)
	bh.add_child(UiKit.title("AD", 24, col))
	badge.anchor_top = 0.5
	badge.anchor_bottom = 0.5
	badge.offset_left = 22
	badge.offset_top = -28
	badge.offset_bottom = 16
	b.add_child(badge)
	return b

## A row "icon  Label ........ [switch]" bound to a Save setting.
func _setting_row(glyph: String, text: String, key: String) -> Control:
	var row := UiKit.hbox(16)
	row.custom_minimum_size = Vector2(0, 74)
	row.mouse_filter = Control.MOUSE_FILTER_STOP   # the whole row is the tap target
	var t := Icons.Tile.new(glyph, {"music": PURPLE, "sound": BLUE, "vibrate": AMBER, "reduce_motion": GREEN}.get(key, BLUE), 62)
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(t)
	var l := UiKit.title(text, 30, Pal.INK, Pal.INK, 0, HORIZONTAL_ALIGNMENT_LEFT)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	var sw := Icons.Switch.new(bool(Save.get(key)))
	sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sw.toggled.connect(func(on: bool):
		Save.set(key, on)
		Save.save_data()
		if key == "music":
			Sfx.refresh_music())
	row.add_child(sw)
	row.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			sw.toggle()
			row.accept_event())
	return row

func _settings_rows(v: VBoxContainer, all := true) -> void:
	v.add_child(_setting_row("music", "Music", "music"))
	v.add_child(_setting_row("sound", "Sound", "sound"))
	v.add_child(_setting_row("vibrate", "Vibration", "vibrate"))
	if all:
		v.add_child(_setting_row("motion", "Reduce motion", "reduce_motion"))

func show_settings() -> void:
	var v := modal("SETTINGS", BLUE, 600, close_modal)
	_settings_rows(v)
	if Ads.privacy_options_required():
		var priv := UiKit.button("PRIVACY OPTIONS", BLUE, 26, 360, 76)
		priv.pressed.connect(Ads.show_privacy_options)
		v.add_child(UiKit.centered(priv))
	var report := UiKit.button("COPY ERROR LOG", Color("#93a4b5"), 26, 360, 76)
	report.pressed.connect(func():
		var n := copy_error_log()
		toast("Log copied (%d lines). Paste it to the developer." % n if n > 0 else "No log found yet"))
	v.add_child(UiKit.centered(report))
	var credits := UiKit.label("Sort the Shipment  •  v%s\nFont: Fredoka (SIL Open Font Licence)" % ProjectSettings.get_setting("application/config/version", "2.0"), 18, Pal.INK_SOFT)
	v.add_child(credits)

func show_pause() -> void:
	if is_modal_open():
		return
	Sfx.play("click")
	var v := modal("PAUSED", BLUE, 600, close_modal)
	_settings_rows(v, false)
	v.add_child(UiKit.spacer(4))
	var resume := UiKit.button("RESUME", GREEN, 44, 460, 112)
	resume.pressed.connect(close_modal)
	v.add_child(UiKit.centered(resume))
	var row := UiKit.hbox(20, BoxContainer.ALIGNMENT_CENTER)
	var restart := UiKit.button("RESTART", BLUE, 32, 220, 92)
	restart.pressed.connect(func():
		clear_overlay()
		retry_pressed.emit())
	row.add_child(restart)
	var home := UiKit.button("HOME", Pal.ACCENT, 32, 220, 92)
	home.pressed.connect(func():
		clear_overlay()
		home_pressed.emit())
	row.add_child(home)
	v.add_child(row)

func show_level_info(i: int) -> void:
	var lname: String = level_names[i] if i < level_names.size() else ""
	var v := modal("LEVEL %d" % (i + 1), Pal.ACCENT, 580, close_modal)
	v.add_child(UiKit.title(lname, 46, Pal.INK))
	var best := Save.get_stars(i + 1)
	var srow := UiKit.hbox(4, BoxContainer.ALIGNMENT_CENTER)
	for k in 3:
		var st := Icons.Star.new(96 if k == 1 else 80, k < best)
		st.size_flags_vertical = Control.SIZE_SHRINK_END if k == 1 else Control.SIZE_SHRINK_CENTER
		srow.add_child(st)
	v.add_child(srow)
	var note := "Your best: %d of 3 stars" % best if best > 0 else "Park fewer containers at once for more stars"
	if best == 3:
		note = "Perfect! All 3 stars earned"
	v.add_child(UiKit.label(note, 24, Pal.INK_SOFT))
	var play := UiKit.button("PLAY", GREEN, 50, 400, 116)
	play.pressed.connect(func():
		clear_overlay()
		level_chosen.emit(i))
	v.add_child(UiKit.centered(play))
	play.ready.connect(func(): UiKit.pulse(play), CONNECT_ONE_SHOT)

func show_rank() -> void:
	var ri := Save.rank_info()
	var v := modal("PORT RANK", PURPLE, 600, close_modal)
	v.add_child(UiKit.title(ri[0], 50, PURPLE))
	var srow := UiKit.hbox(8, BoxContainer.ALIGNMENT_CENTER)
	srow.add_child(Icons.Star.new(44))
	srow.add_child(UiKit.title("%d stars" % Save.total_stars(), 36, Pal.INK))
	v.add_child(srow)
	if ri[2] > 0:
		var pb := Icons.Progress.new()
		pb.custom_minimum_size = Vector2(440, 22)
		pb.value = float(Save.total_stars() - ri[1]) / float(ri[2] - ri[1])
		v.add_child(UiKit.centered(pb))
		v.add_child(UiKit.label("%d more stars to the next rank" % (ri[2] - Save.total_stars()), 22, Pal.INK_SOFT))
	var list := UiKit.vbox(6)
	for r in Save.RANKS:
		var row := UiKit.hbox(12)
		var got: bool = Save.total_stars() >= int(r[0])
		var l := UiKit.title(r[1], 27, Pal.INK if got else Pal.INK_FAINT, Pal.INK, 0, HORIZONTAL_ALIGNMENT_LEFT)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		row.add_child(UiKit.title(str(r[0]), 26, Pal.INK_SOFT if got else Pal.INK_FAINT))
		row.add_child(Icons.Star.new(30, got))
		list.add_child(row)
	v.add_child(list)

# ---------------------------------------------------------------- menu shell

func show_title(unlocked: int, total: int) -> void:
	_open_menu("home", unlocked, total)

func show_levels(unlocked: int, total: int) -> void:
	_open_menu("map", unlocked, total)

func show_harbour(unlocked: int, total: int) -> void:
	_open_menu("harbour", unlocked, total)

func _open_menu(tab: String, unlocked: int, total: int) -> void:
	set_game_visible(false)
	close_modal()
	for c in _overlay.get_children():
		c.queue_free()
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_menu = Menu.new(self, unlocked, total)
	_overlay.add_child(_menu)
	_menu.switch_tab(tab, false)

# ---------------------------------------------------------------- results

## Rewards screen. result: stars, three, reward, crate, rank_up, last_level, fireworks
func show_win(result: Dictionary) -> void:
	var stars: int = result["stars"]
	_dim(0.6)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pop.add_child(center)
	var wrap := UiKit.vbox(-30)
	center.add_child(wrap)
	# stars over turning light rays
	var top := Control.new()
	top.custom_minimum_size = Vector2(640, 200)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(top)
	var burst := Icons.Sunburst.new(Color(1, 0.92, 0.55, 0.28 if stars == 3 else 0.16))
	burst.size = Vector2(820, 820)
	burst.position = Vector2(320 - 410, 120 - 410)
	top.add_child(burst)
	var srow := UiKit.hbox(0, BoxContainer.ALIGNMENT_CENTER)
	srow.set_anchors_preset(Control.PRESET_FULL_RECT)
	top.add_child(srow)
	var star_nodes := []
	for k in 3:
		var holder := CenterContainer.new()
		holder.custom_minimum_size = Vector2(170, 200)
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var st := Icons.Star.new(170 if k == 1 else 130, false)
		st.rotation = [-0.2, 0.0, 0.2][k]
		holder.add_child(st)
		if k != 1:
			holder.size_flags_vertical = Control.SIZE_SHRINK_END
			holder.custom_minimum_size = Vector2(150, 160)
		srow.add_child(holder)
		star_nodes.append(st)
	var rb := ribbon("LEVEL COMPLETE!", GREEN, 50, 560)
	rb.z_index = 2
	rb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	wrap.add_child(UiKit.spacer(36))
	wrap.add_child(rb)
	var panel := PanelContainer.new()
	var sb := UiKit.card_style()
	sb.content_margin_top = 62
	panel.add_theme_stylebox_override("panel", sb)
	panel.custom_minimum_size = Vector2(600, 0)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	wrap.add_child(panel)
	var v := UiKit.vbox(18, BoxContainer.ALIGNMENT_CENTER)
	panel.add_child(v)
	var three: int = result.get("three", 0)
	var msg := "Perfect parking!" if stars == 3 else ("Park nothing for 3 stars" if three == 0 else "Park %d or fewer at once for 3 stars" % three)
	v.add_child(UiKit.title(msg, 34 if stars == 3 else 28, Pal.INK if stars == 3 else Pal.INK_SOFT))
	if result.get("replay", false):
		v.add_child(UiKit.label("Replay reward. Beat your best for the full prize!" if stars < 3 else "Replay reward. You already have all 3 stars here", 20, Pal.INK_SOFT))
	# reward pill
	var rp := PanelContainer.new()
	rp.add_theme_stylebox_override("panel", UiKit.margins(UiKit.style(Color("#fff0c4"), 40, 0, Color("#f6d27a"), 0), 22, 8, 32, 8))
	rp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rrow := UiKit.hbox(10, BoxContainer.ALIGNMENT_CENTER)
	rp.add_child(rrow)
	rrow.add_child(Icons.Coin.new(58))
	var rl := UiKit.title("+0", 52, Color("#e88a00"), Color.WHITE, 0)
	rrow.add_child(rl)
	v.add_child(UiKit.centered(rp))
	var base_reward: int = result["reward"]
	if Ads.rewarded_ready("bonus") and base_reward > 0:
		var bonus := _ad_button("+%d COINS" % base_reward, PURPLE, 30, 360, 84)
		bonus.pressed.connect(func():
			bonus.disabled = true
			if not Ads.show_rewarded("bonus", func():
				Save.add_coins(base_reward)
				rl.text = "+%d" % (base_reward * 2)
				fly_coins(rp.get_global_rect().get_center(), base_reward, 8)
				bonus.queue_free()):
				bonus.disabled = false
				toast("No ad available right now"))
		v.add_child(UiKit.centered(bonus))
	# milestone crate / rank up slot in here
	var extras := UiKit.vbox(10)
	v.add_child(extras)
	# next harbour project: what the coins are for
	var proj := Save.next_project()
	if not proj.is_empty():
		_win_strip_slot = UiKit.vbox(0)
		v.add_child(_win_strip_slot)
		_fill_win_strip()
	var buttons := UiKit.hbox(18, BoxContainer.ALIGNMENT_CENTER)
	var replay := UiKit.icon_button(Icons.Glyph.new("retry", Color.WHITE), BLUE, 112, 30)
	replay.pressed.connect(func():
		clear_overlay()
		retry_pressed.emit())
	buttons.add_child(replay)
	var next := UiKit.button("CONTINUE" if not result.get("last_level", false) else "FINISH", GREEN, 48, 360, 112)
	next.pressed.connect(func():
		clear_overlay()
		next_pressed.emit())
	buttons.add_child(next)
	v.add_child(buttons)
	wrap.ready.connect(func(): UiKit.pop_in(wrap), CONNECT_ONE_SHOT)
	if result.get("fireworks", false):
		fireworks(3.5)
	# stars land one by one, then the coins count up. The tween belongs to the
	# card, so tapping CONTINUE early stops it with the card (no stray callbacks).
	var tw := wrap.create_tween()
	tw.tween_interval(0.45)
	for k in 3:
		var st: Icons.Star = star_nodes[k]
		var got := k < stars
		tw.tween_callback(func():
			if got:
				st.set_filled(true)
				Sfx.play("star%d" % (k + 1))
				Save.buzz(25)
				st.pivot_offset = st.size * 0.5
				st.scale = Vector2(1.8, 1.8)
				var t2 := st.create_tween()
				t2.tween_property(st, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))
		tw.tween_interval(0.34 if got else 0.1)
	tw.tween_method(func(x: float): rl.text = "+%d" % int(x), 0.0, float(result["reward"]), 0.6)
	tw.tween_callback(func(): Sfx.play("coin"))
	var crate_amt: int = result.get("crate", 0)
	if crate_amt > 0:
		var crow := UiKit.hbox(12, BoxContainer.ALIGNMENT_CENTER)
		var crate := Icons.Crate.new(96)
		crow.add_child(crate)
		var cl := UiKit.title("Milestone crate!", 32, Color("#a86c35"))
		crow.add_child(cl)
		extras.add_child(crow)
		tw.tween_interval(0.2)
		for k in 3:
			tw.tween_callback(func():
				Sfx.play("crate", 0.9 + k * 0.08, -4.0)
				crate.pivot_offset = crate.size * 0.5
				var t2 := crate.create_tween()
				t2.tween_property(crate, "rotation", 0.18 * (1 if k % 2 == 0 else -1), 0.06)
				t2.tween_property(crate, "rotation", 0.0, 0.1))
			tw.tween_interval(0.26)
		tw.tween_callback(func():
			crate.set_open(true)
			crate.scale = Vector2(1.3, 1.3)
			crate.create_tween().tween_property(crate, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK)
			cl.text = "+%d coins!" % crate_amt
			cl.add_theme_color_override("font_color", Color("#e88a00"))
			Sfx.play("gold")
			Save.buzz(50)
			fly_coins(crate.get_global_rect().get_center(), crate_amt, 10))
		tw.tween_interval(0.4)
	var new_rank: String = result.get("rank_up", "")
	if new_rank != "":
		var rk := UiKit.title("RANK UP!  %s" % new_rank, 30, Color.WHITE)
		rk.add_theme_stylebox_override("normal", UiKit.margins(UiKit.style(PURPLE, 24, 6, PURPLE.darkened(0.22), 0), 24, 6, 24, 12))
		rk.modulate.a = 0.0
		extras.add_child(UiKit.centered(rk))
		tw.tween_callback(func():
			Sfx.play("rankup")
			rk.pivot_offset = rk.size * 0.5
			rk.scale = Vector2(1.6, 1.6)
			var t3 := rk.create_tween().set_parallel(true)
			t3.tween_property(rk, "modulate:a", 1.0, 0.2)
			t3.tween_property(rk, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK))
	tw.tween_callback(func(): UiKit.pulse(next))

## "Next project" strip: icon tile, name, progress bar with coin count.
## Builds a project from anywhere in the UI. Returns true when it was built.
func build_project_now(id: String) -> bool:
	if not Save.build_project(id):
		toast("Not enough coins yet")
		return false
	Sfx.play("rankup")
	Save.buzz(50)
	project_built.emit(id)
	return true

## "Next project" strip: icon tile, name, progress bar with coin count, and a
## working BUILD button when it's affordable and `on_build` is given.
func _project_strip(proj: Array, on_build: Callable = Callable()) -> Control:
	var p := PanelContainer.new()
	var can_build := Save.coins >= int(proj[2])
	p.add_theme_stylebox_override("panel", UiKit.margins(UiKit.well_style(Color("#e9f8e6") if can_build else Color.WHITE), 14, 12, 18, 14))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := UiKit.hbox(14)
	p.add_child(h)
	h.add_child(Icons.Tile.new(Menu.project_glyph(proj[0]), Menu.project_color(proj[0]), 72))
	var tv := UiKit.vbox(4)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(tv)
	tv.add_child(UiKit.title(proj[1], 26, Pal.INK, Pal.INK, 0, HORIZONTAL_ALIGNMENT_LEFT))
	var pb := Icons.Progress.new()
	pb.custom_minimum_size = Vector2(300, 16)
	pb.value = clampf(float(Save.coins) / float(proj[2]), 0.0, 1.0)
	tv.add_child(pb)
	var cnt := UiKit.label("%d / %d" % [min(Save.coins, int(proj[2])), proj[2]], 21, Pal.INK_SOFT, HORIZONTAL_ALIGNMENT_LEFT)
	tv.add_child(cnt)
	if can_build and on_build.is_valid():
		var b := UiKit.button("BUILD", GREEN, 30, 140, 76)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.pressed.connect(on_build)
		h.add_child(b)
		b.ready.connect(func(): UiKit.pulse(b), CONNECT_ONE_SHOT)
	elif can_build:
		var chip := UiKit.title("BUILD!", 26, Color.WHITE)
		chip.add_theme_stylebox_override("normal", UiKit.margins(UiKit.style(GREEN, 20, 5, GREEN.darkened(0.22), 0), 16, 4, 16, 9))
		chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(chip)
	return p

var _win_strip_slot: VBoxContainer

## (Re)fills the win card's project strip; its BUILD button builds right here.
func _fill_win_strip() -> void:
	if _win_strip_slot == null or not is_instance_valid(_win_strip_slot):
		return
	for c in _win_strip_slot.get_children():
		c.queue_free()
	var proj := Save.next_project()
	if proj.is_empty():
		_win_strip_slot.add_child(UiKit.title("Harbour complete!", 28, GREEN.darkened(0.15)))
		return
	var id: String = proj[0]
	_win_strip_slot.add_child(_project_strip(proj, func():
		if not build_project_now(id):
			return
		# step aside while the camera shows the new build, then come back
		_pop.visible = false
		var slot := _win_strip_slot
		get_tree().create_timer(3.3).timeout.connect(func():
			if is_instance_valid(slot) and slot.is_inside_tree():
				_pop.visible = true
				_fill_win_strip())))

func show_campaign_complete(total_stars: int, max_stars: int, chains: int) -> void:
	var v := modal("PORT LEGEND!", PURPLE, 600, Callable(), 0.6)
	var burst := Icons.Sunburst.new(Color(1, 0.92, 0.55, 0.22))
	burst.size = Vector2(900, 900)
	burst.position = (_vp() - burst.size) * 0.5
	burst.z_index = -1
	_pop.add_child(burst)
	_pop.move_child(burst, 1)
	v.add_child(UiKit.label("You cleared every shipment in the campaign.", 28, Pal.INK))
	var srow := UiKit.hbox(10, BoxContainer.ALIGNMENT_CENTER)
	srow.add_child(Icons.Star.new(64))
	srow.add_child(UiKit.title("%d / %d" % [total_stars, max_stars], 52, Pal.INK))
	v.add_child(srow)
	v.add_child(UiKit.label("%d dispatch chains triggered" % chains, 24, Pal.INK_SOFT))
	var hint := UiKit.label("Go back for any missing stars, and finish your harbour!", 22, Pal.INK_SOFT)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(hint)
	var ok := UiKit.button("TO THE HARBOUR", GREEN, 40, 440, 112)
	ok.pressed.connect(func():
		clear_overlay()
		home_pressed.emit())
	v.add_child(UiKit.centered(ok))
	fireworks(4.0)

func show_lose(can_slot: bool, undos_left: int, blocker: String = "", ad_rescue := false) -> void:
	var v := modal("OUT OF PARKING", Pal.BAD, 600)
	# a full gauge says it at a glance
	var pips := UiKit.hbox(8, BoxContainer.ALIGNMENT_CENTER)
	for i in 5:
		var pip := Panel.new()
		pip.custom_minimum_size = Vector2(56, 58)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pip.add_theme_stylebox_override("panel", UiKit.style(Pal.BAD, 14, 6, Pal.BAD.darkened(0.22), 0))
		pips.add_child(pip)
	var plus := Panel.new()
	plus.custom_minimum_size = Vector2(56, 58)
	plus.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var psb := UiKit.style(Color("#e9f8e6"), 14, 0, GREEN, 0)
	psb.set_border_width_all(4)
	psb.border_color = GREEN
	plus.add_theme_stylebox_override("panel", psb)
	var pl := UiKit.title("+1", 28, GREEN)
	pl.set_anchors_preset(Control.PRESET_FULL_RECT)
	plus.add_child(pl)
	pips.add_child(plus)
	v.add_child(pips)
	var sub := UiKit.label("Every spot is full and no ship wants the top boxes.", 26, Pal.INK_SOFT)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.custom_minimum_size = Vector2(500, 0)
	v.add_child(sub)
	if ad_rescue:
		var adb := _ad_button("FREE SPOT", PURPLE, 44, 460, 116)
		adb.pressed.connect(func():
			clear_overlay()
			ad_rescue_pressed.emit())
		v.add_child(UiKit.centered(adb))
		adb.ready.connect(func(): UiKit.pulse(adb), CONNECT_ONE_SHOT)
	var cont := UiKit.button("+1 SPOT", GREEN, 44, 460, 116)
	cont.disabled = not can_slot
	cont.pressed.connect(func():
		clear_overlay()
		continue_pressed.emit())
	var price := PanelContainer.new()
	price.add_theme_stylebox_override("panel", UiKit.margins(UiKit.style(Color(0, 0.2, 0.1, 0.18), 22), 8, 2, 14, 2))
	price.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ph := UiKit.hbox(4)
	price.add_child(ph)
	ph.add_child(Icons.Coin.new(38))
	ph.add_child(UiKit.title(str(COST_SLOT), 30, Color.WHITE))
	price.anchor_left = 1.0
	price.anchor_right = 1.0
	price.anchor_top = 0.5
	price.anchor_bottom = 0.5
	price.offset_left = -150
	price.offset_right = -24
	price.offset_top = -32
	price.offset_bottom = 18
	cont.add_child(price)
	cont.alignment = HORIZONTAL_ALIGNMENT_LEFT
	cont.add_theme_constant_override("h_separation", 0)
	cont.text = "    +1 SPOT"
	v.add_child(UiKit.centered(cont))
	if not can_slot and not ad_rescue:
		var bl := UiKit.label(blocker if blocker != "" else "Not enough coins for an extra spot", 20, Pal.INK_SOFT)
		bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		bl.custom_minimum_size = Vector2(480, 0)
		v.add_child(bl)
	var row := UiKit.hbox(18, BoxContainer.ALIGNMENT_CENTER)
	if undos_left > 0:
		var ub := UiKit.button("UNDO", BLUE, 34, 220, 96)
		ub.pressed.connect(func():
			clear_overlay()
			undo_pressed.emit())
		row.add_child(ub)
	var retry := UiKit.button("TRY AGAIN", Pal.ACCENT, 34, 220 if undos_left > 0 else 460, 96)
	retry.pressed.connect(func():
		clear_overlay()
		retry_pressed.emit())
	row.add_child(retry)
	v.add_child(row)
	if can_slot and not ad_rescue:
		cont.ready.connect(func(): UiKit.pulse(cont), CONNECT_ONE_SHOT)

## Copies the end of the last two session logs (the crashed session and this
## one) to the clipboard so a player can paste them into a bug report.
func copy_error_log() -> int:
	var dir := DirAccess.open("user://logs")
	if dir == null:
		return 0
	var files := []
	for f in dir.get_files():
		if f.ends_with(".log"):
			files.append(["user://logs/" + f, FileAccess.get_modified_time("user://logs/" + f)])
	files.sort_custom(func(a, b): return a[1] > b[1])
	var out := PackedStringArray(["Sort the Shipment %s  |  %s  |  %s" % [ProjectSettings.get_setting("application/config/version", "?"), OS.get_model_name(), OS.get_version()]])
	var lines := 0
	for k in range(min(2, files.size()) - 1, -1, -1):
		var txt := FileAccess.get_file_as_string(files[k][0])
		var arr := txt.split("\n")
		out.append("---- %s ----" % files[k][0].get_file())
		var start: int = max(0, arr.size() - 120)
		for i in range(start, arr.size()):
			out.append(arr[i])
			lines += 1
	DisplayServer.clipboard_set("\n".join(out))
	return lines
