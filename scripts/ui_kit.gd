class_name UiKit
extends RefCounted
## The UI design system (2.0 "Toy Harbour"): warm paper surfaces with a soft
## lip and shadow, chunky tinted buttons that squish when pressed, one rounded
## typeface (Fredoka), navy ink. Surfaces are nine-patch textures made by
## tools/make_ui.py; small flat bits still use StyleBoxFlat.

const R_CARD := 44
const R_BTN := 30
const SHADOW := Color(0.07, 0.15, 0.26, 0.2)

static var _tex := {}

static func tex(name: String) -> Texture2D:
	if not _tex.has(name):
		_tex[name] = load("res://assets/ui/%s.png" % name)
	return _tex[name]

## Nine-patch style from a surface texture. m = [left, top, right, bottom]
## texture margins, e = expand margins (the shadow drawn outside the rect).
static func tex_style(name: String, m: Array, e: Array, tint := Color.WHITE) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = tex(name)
	sb.texture_margin_left = m[0]
	sb.texture_margin_top = m[1]
	sb.texture_margin_right = m[2]
	sb.texture_margin_bottom = m[3]
	sb.expand_margin_left = e[0]
	sb.expand_margin_top = e[1]
	sb.expand_margin_right = e[2]
	sb.expand_margin_bottom = e[3]
	sb.modulate_color = tint
	return sb

static func _btn_style(tint: Color, down: bool, small := false) -> StyleBoxTexture:
	if small:
		return tex_style("btn_s_down" if down else "btn_s", [30, 30, 30, 37], [10, 10, 10, 10], tint)
	return tex_style("btn_down" if down else "btn", [42, 42, 42, 52], [12, 12, 12, 12], tint)

static func _paper_style(down: bool) -> StyleBoxTexture:
	return tex_style("paper_btn_down" if down else "paper_btn", [40, 40, 40, 49], [12, 12, 12, 12])

static func margins(sb: StyleBox, l: float, t: float, r: float, b: float) -> StyleBox:
	sb.content_margin_left = l
	sb.content_margin_top = t
	sb.content_margin_right = r
	sb.content_margin_bottom = b
	return sb

## Flat rounded box for small pieces (pips, tags, wells).
static func style(bg: Color, radius := 28, border_bottom := 0, border_col := Color(0, 0, 0, 0), shadow := 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.border_width_bottom = border_bottom
	sb.border_color = border_col
	sb.anti_aliasing = true
	sb.corner_detail = 10
	if shadow > 0:
		sb.shadow_color = SHADOW
		sb.shadow_size = shadow
		sb.shadow_offset = Vector2(0, shadow * 0.5)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	return sb

## A sunken well inside a card (reward counters, project strips).
static func well_style(tint := Color.WHITE) -> StyleBoxTexture:
	var sb := tex_style("well", [22, 22, 22, 22], [0, 0, 0, 0], tint)
	margins(sb, 18, 12, 18, 12)
	return sb

## Body text.
static func label(text: String, size: int, col: Color = Pal.INK, align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", Pal.font_ui())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

## Display text: headings, numbers, callouts. Over the 3D scene pass an
## outline colour and width; on paper leave it plain.
static func title(text: String, size: int, col: Color = Color.WHITE, outline: Color = Pal.INK, outline_px := 0, align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := label(text, size, col, align)
	l.add_theme_font_override("font", Pal.font_display())
	if outline_px > 0:
		l.add_theme_color_override("font_outline_color", outline)
		l.add_theme_constant_override("outline_size", outline_px)
	return l

static func sym_label(text: String, size: int, col: Color) -> Label:
	var l := label(text, size, col)
	l.add_theme_font_override("font", Pal.font_sym())
	return l

## A cargo symbol as a small tinted sprite.
static func symbol(c: int, d: float, col: Color) -> TextureRect:
	var t := TextureRect.new()
	t.texture = Pal.symbol_tex(c)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(d, d)
	t.modulate = col
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t

## Press feel shared by every button: squish down, spring back.
static func add_squish(b: Control) -> void:
	b.resized.connect(func(): b.pivot_offset = b.size * 0.5)
	if b is BaseButton:
		var bb := b as BaseButton
		bb.button_down.connect(func():
			Sfx.play("click")
			var tw := b.create_tween()
			tw.tween_property(b, "scale", Vector2(0.94, 0.94), 0.06))
		bb.button_up.connect(func():
			var tw := b.create_tween()
			tw.tween_property(b, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT))

## A soft sheen across the top of a coloured button.
static func _gloss(b: Control, radius: int, inset := 8.0) -> void:
	var g := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.16)
	sb.set_corner_radius_all(max(4, radius - 8))
	sb.corner_radius_bottom_left = max(4, radius - 16)
	sb.corner_radius_bottom_right = max(4, radius - 16)
	sb.anti_aliasing = true
	g.add_theme_stylebox_override("panel", sb)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g.anchor_right = 1.0
	g.anchor_bottom = 0.4
	g.offset_left = inset
	g.offset_right = -inset
	g.offset_top = inset * 0.75
	g.offset_bottom = 0
	b.add_child(g)

## Big tinted button with a darker lip so it looks pressable.
static func button(text: String, bg: Color, size := 40, min_w := 300, min_h := 104, text_col := Color.WHITE) -> Button:
	var b := Button.new()
	b.text = text
	var small := min_h < 88
	b.custom_minimum_size = Vector2(min_w, min_h)
	b.add_theme_font_override("font", Pal.font_display())
	b.add_theme_font_size_override("font_size", size)
	for st in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(st, text_col)
	b.add_theme_color_override("font_disabled_color", Color("#f4f6f8"))
	# a soft drop shadow in a deeper tone of the button instead of a hard outline
	b.add_theme_color_override("font_shadow_color", Color(bg.darkened(0.38), 0.75))
	b.add_theme_constant_override("shadow_offset_x", 0)
	b.add_theme_constant_override("shadow_offset_y", max(2, int(size * 0.07)))
	b.add_theme_constant_override("shadow_outline_size", 0)
	var lip := 7.0 if small else 10.0
	var n := margins(_btn_style(bg, false, small), 22, 6, 22, 6 + lip)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", n)
	var pressed := margins(_btn_style(bg, true, small), 22, 6 + lip * 0.6, 22, 6 + lip * 0.4)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("hover_pressed", pressed)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var dis := margins(_btn_style(Color("#b9c4cf"), false, small), 22, 6, 22, 6 + lip)
	b.add_theme_stylebox_override("disabled", dis)
	b.focus_mode = Control.FOCUS_NONE
	_gloss(b, 20 if small else R_BTN, 7.0 if small else 9.0)
	add_squish(b)
	return b

## Small square button with a drawn icon (close, etc.).
static func round_button(icon: String, bg: Color, icon_col: Color, d := 100) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(d, d)
	var n := margins(_btn_style(bg, false, true), 0, 0, 0, 7)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", n)
	var p := margins(_btn_style(bg, true, true), 0, 4, 0, 3)
	b.add_theme_stylebox_override("pressed", p)
	b.add_theme_stylebox_override("hover_pressed", p)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("disabled", margins(_btn_style(Color("#b9c4cf"), false, true), 0, 0, 0, 7))
	b.focus_mode = Control.FOCUS_NONE
	var ic := Icons.Glyph.new(icon, icon_col)
	ic.set_anchors_preset(Control.PRESET_FULL_RECT)
	ic.offset_left = d * 0.26
	ic.offset_right = -d * 0.26
	ic.offset_top = d * 0.22
	ic.offset_bottom = -d * 0.3
	b.add_child(ic)
	add_squish(b)
	return b

## Rounded square button that holds a drawn icon control. White = paper.
static func icon_button(icon: Control, bg: Color = Color.WHITE, d := 88, _radius := 26) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(d, d)
	b.focus_mode = Control.FOCUS_NONE
	var paper := bg == Color.WHITE
	var n: StyleBox = margins(_paper_style(false) if paper else _btn_style(bg, false), 0, 0, 0, 0)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", n)
	var p: StyleBox = margins(_paper_style(true) if paper else _btn_style(bg, true), 0, 0, 0, 0)
	b.add_theme_stylebox_override("pressed", p)
	b.add_theme_stylebox_override("hover_pressed", p)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var dis: StyleBox = margins(_paper_style(false), 0, 0, 0, 0)
	if paper:
		(dis as StyleBoxTexture).modulate_color = Color(0.93, 0.94, 0.95, 0.9)
	b.add_theme_stylebox_override("disabled", dis)
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = d * 0.24
	icon.offset_right = -d * 0.24
	icon.offset_top = d * 0.2
	icon.offset_bottom = -d * 0.28
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(icon)
	if not paper:
		_gloss(b, R_BTN, 9.0)
		b.move_child(icon, -1)
	add_squish(b)
	return b

## Coral "X" that sits on a card's top-right corner.
static func close_button() -> Button:
	return round_button("close", Pal.BAD, Color.WHITE, 72)

## The standard paper card.
static func card_style() -> StyleBoxTexture:
	var sb := tex_style("card", [72, 72, 72, 84], [28, 28, 28, 28])
	margins(sb, 36, 36, 36, 50)
	return sb

## Paper panel for in-level chrome (level title, next ships, gauges).
static func pill_style(l := 16.0, t := 6.0, r := 16.0, b := 12.0) -> StyleBoxTexture:
	var sb := tex_style("pill", [40, 40, 40, 46], [10, 10, 10, 10])
	margins(sb, l, t, r, b)
	return sb

static func chip_style(l := 10.0, t := 4.0, r := 10.0, b := 8.0) -> StyleBoxTexture:
	var sb := tex_style("chip", [26, 26, 26, 30], [8, 8, 8, 8])
	margins(sb, l, t, r, b)
	return sb

## Rounded pill used for counters (coins, stars) in top bars.
static func pill(_radius := 34) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", pill_style(10, 6, 22, 12))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p

static func hbox(sep := 10, align := BoxContainer.ALIGNMENT_BEGIN) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	h.alignment = align
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return h

static func vbox(sep := 10, align := BoxContainer.ALIGNMENT_BEGIN) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	v.alignment = align
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return v

static func spacer(h := 0.0, expand := false) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if expand:
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c

static func centered(c: Control) -> CenterContainer:
	var cc := CenterContainer.new()
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cc.add_child(c)
	return cc

## Height of the status bar / notch in viewport pixels (0 on desktop).
static func safe_top(vp: Vector2) -> float:
	var screen := DisplayServer.screen_get_size()
	var safe := DisplayServer.get_display_safe_area()
	if screen.y <= 0 or safe.size.y <= 0:
		return 0.0
	return clampf(float(safe.position.y) / float(screen.y) * vp.y, 0.0, 120.0)

static func pop_in(c: Control, delay := 0.0) -> void:
	c.pivot_offset = c.size * 0.5
	c.scale = Vector2(0.8, 0.8)
	c.modulate.a = 0.0
	var tw := c.create_tween().set_parallel(true)
	tw.tween_property(c, "scale", Vector2.ONE, 0.38).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "modulate:a", 1.0, 0.16).set_delay(delay)

static func pulse(c: Control) -> Tween:
	c.pivot_offset = c.size * 0.5
	var tw := c.create_tween().set_loops()
	tw.tween_property(c, "scale", Vector2(1.04, 1.04), 0.7).set_trans(Tween.TRANS_SINE)
	tw.tween_property(c, "scale", Vector2.ONE, 0.7).set_trans(Tween.TRANS_SINE)
	return tw
