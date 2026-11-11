class_name Icons
extends RefCounted
## Icons and small drawn widgets. Line icons are white SVGs (assets/ui/icons,
## written by tools/make_ui.py) tinted at draw time; coins, stars and crates
## are painted sprites.

static var _cache := {}

## Old glyph characters still used by callers -> icon names.
const GLYPH_ICON := {
	"⚙": "settings", "↶": "undo", "?": "hint", "↻": "retry", "⚓": "anchor", "▶": "play", "✕": "close",
	"✔": "check", "♫": "music", "◉": "sound", "≋": "vibrate", "◐": "motion", "✦": "hint", "★": "star", "+": "plus",
}

static func icon_tex(name: String) -> Texture2D:
	var key: String = GLYPH_ICON.get(name, name)
	if not _cache.has(key):
		var path := "res://assets/ui/icons/%s.svg" % key
		_cache[key] = load(path) if ResourceLoader.exists(path) else null
	return _cache[key]

static func sprite(name: String) -> Texture2D:
	if not _cache.has("s_" + name):
		_cache["s_" + name] = load("res://assets/ui/%s.png" % name)
	return _cache["s_" + name]

## Draws a texture centred in a rect, keeping its aspect.
static func draw_fit(c: CanvasItem, t: Texture2D, rect: Rect2, col := Color.WHITE) -> void:
	if t == null:
		return
	var ts := t.get_size()
	var s: float = min(rect.size.x / ts.x, rect.size.y / ts.y)
	var sz := ts * s
	c.draw_texture_rect(t, Rect2(rect.position + (rect.size - sz) * 0.5, sz), false, col)

class Coin extends Control:
	var d := 44.0
	func _init(p_d := 44.0) -> void:
		d = p_d
		custom_minimum_size = Vector2(d, d)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	func _draw() -> void:
		Icons.draw_fit(self, Icons.sprite("coin"), Rect2(Vector2.ZERO, size))

class Star extends Control:
	var filled := true
	var d := 120.0
	func _init(p_d := 120.0, p_filled := true) -> void:
		d = p_d
		filled = p_filled
		custom_minimum_size = Vector2(d, d)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	func set_filled(f: bool) -> void:
		filled = f
		queue_redraw()
	func _draw() -> void:
		Icons.draw_fit(self, Icons.sprite("star" if filled else "star_empty"), Rect2(Vector2.ZERO, size))

## A little ship in the colour it will collect, with its symbol.
class ShipChip extends Control:
	var color := 0
	var d := 54.0
	func _init(p_color: int, p_d := 54.0) -> void:
		color = p_color
		d = p_d
		custom_minimum_size = Vector2(d * 1.34, d)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	func _draw() -> void:
		var w := size.x
		var h := size.y
		var col := Pal.cargo(color)
		var hull := StyleBoxFlat.new()
		hull.bg_color = col
		hull.corner_radius_bottom_left = int(h * 0.3)
		hull.corner_radius_bottom_right = int(h * 0.42)
		hull.corner_radius_top_left = int(h * 0.08)
		hull.corner_radius_top_right = int(h * 0.08)
		hull.border_width_bottom = max(2, int(h * 0.07))
		hull.border_color = col.darkened(0.25)
		hull.anti_aliasing = true
		hull.corner_detail = 8
		# bridge and funnel behind the hull
		var house := StyleBoxFlat.new()
		house.bg_color = Color("#fffaf0")
		house.set_corner_radius_all(int(h * 0.07))
		house.anti_aliasing = true
		draw_style_box(house, Rect2(w * 0.06, h * 0.12, w * 0.24, h * 0.4))
		draw_rect(Rect2(w * 0.1, h * 0.2, w * 0.16, h * 0.1), Color("#3f7896"))
		draw_style_box(hull, Rect2(0, h * 0.42, w, h * 0.54))
		draw_rect(Rect2(w * 0.0, h * 0.42, w, h * 0.07), Color(1, 1, 1, 0.9))
		var sym_d := h * 0.34
		Icons.draw_fit(self, Pal.symbol_tex(color % Pal.SYMBOL.size()), Rect2(w * 0.6 - sym_d * 0.5, h * 0.53, sym_d, sym_d), Color.WHITE)

class Progress extends Control:
	var value := 0.0
	var fill := Pal.GOOD
	func _init() -> void:
		custom_minimum_size = Vector2(300, 18)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func set_value(v: float) -> void:
		# a bar that isn't on screen just takes the value: a tween bound to a node
		# outside the tree never runs and would never be freed
		if not is_inside_tree():
			value = v
			return
		var tw := create_tween()
		tw.tween_property(self, "value", v, 0.35).set_trans(Tween.TRANS_QUAD)
	func _process(_d: float) -> void:
		queue_redraw()
	func _draw() -> void:
		var r := size.y * 0.5
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("#e9dfcb")
		sb.set_corner_radius_all(int(r))
		sb.anti_aliasing = true
		draw_style_box(sb, Rect2(Vector2.ZERO, size))
		if value > 0.001:
			var fb := StyleBoxFlat.new()
			fb.bg_color = fill
			fb.set_corner_radius_all(int(r))
			fb.anti_aliasing = true
			draw_style_box(fb, Rect2(Vector2.ZERO, Vector2(max(size.y, size.x * value), size.y)))
			var gl := StyleBoxFlat.new()
			gl.bg_color = Color(1, 1, 1, 0.3)
			gl.set_corner_radius_all(int(r))
			draw_style_box(gl, Rect2(Vector2(r * 0.6, size.y * 0.2), Vector2(max(2.0, size.x * value - r * 1.2), size.y * 0.24)))

class Crate extends Control:
	var d := 120.0
	var open := false
	func _init(p_d := 120.0) -> void:
		d = p_d
		custom_minimum_size = Vector2(d, d)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	func set_open(o: bool) -> void:
		open = o
		queue_redraw()
	func _draw() -> void:
		Icons.draw_fit(self, Icons.sprite("crate_open" if open else "crate"), Rect2(Vector2.ZERO, size))

## An icon (by name or by an old glyph character) drawn centred and scaled to
## fit its rect. Unknown names fall back to the display font.
class Glyph extends Control:
	var glyph := "?"
	var color := Pal.INK
	var display := false
	func _init(p_glyph: String, p_color: Color = Pal.INK, p_display := false) -> void:
		glyph = p_glyph
		color = p_color
		display = p_display
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	func set_color(c: Color) -> void:
		color = c
		queue_redraw()
	func _draw() -> void:
		var t := Icons.icon_tex(glyph)
		if t != null:
			Icons.draw_fit(self, t, Rect2(Vector2.ZERO, size), color)
			return
		var f: Font = Pal.font_display()
		var fs := int(min(size.x, size.y) * 0.92)
		var ts := f.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var asc := f.get_ascent(fs)
		var desc := f.get_descent(fs)
		draw_string(f, Vector2((size.x - ts.x) * 0.5, (size.y + asc - desc) * 0.5), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)

class Lock extends Glyph:
	func _init(d := 44.0, p_color: Color = Pal.INK_FAINT) -> void:
		super("lock", p_color)
		custom_minimum_size = Vector2(d, d)

class Pause extends Glyph:
	func _init(p_color: Color = Pal.INK) -> void:
		super("pause", p_color)

## Folded map: the Levels tab.
class MapIcon extends Glyph:
	func _init(p_color: Color = Pal.INK) -> void:
		super("map", p_color)

class House extends Glyph:
	func _init(p_color: Color = Pal.INK) -> void:
		super("home", p_color)

## Slowly turning light rays behind a reward.
class Sunburst extends Control:
	var color := Color(1, 0.93, 0.6, 0.55)
	var rays := 12
	var spin := 0.0
	func _init(p_color: Color = Color(1, 0.93, 0.6, 0.55)) -> void:
		color = p_color
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _process(delta: float) -> void:
		if not Save.reduce_motion:
			spin += delta * 0.2
			queue_redraw()
	func _draw() -> void:
		var c := size * 0.5
		var r: float = max(size.x, size.y) * 0.5
		var clear := Color(color, 0.0)
		for i in rays:
			var a0 := spin + i * TAU / rays
			var a1 := a0 + TAU / rays * 0.46
			# rays fade out towards their tips
			draw_polygon(PackedVector2Array([c, c + Vector2(cos(a0), sin(a0)) * r, c + Vector2(cos(a1), sin(a1)) * r]),
				PackedColorArray([color, clear, clear]))
		for k in 5:
			draw_circle(c, r * (0.36 - k * 0.06), Color(1, 1, 0.9, 0.07))

## A ribbon banner with folded tails; put a label on top of it.
class Ribbon extends Control:
	var color := Pal.GOOD
	func _init(p_color: Color) -> void:
		color = p_color
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var w := size.x
		var h := size.y
		var tail := h * 0.5
		var drop := h * 0.2
		var dark := color.darkened(0.22)
		var darker := color.darkened(0.42)
		for s in [-1, 1]:
			var x0 := 0.0 if s == -1 else w
			var x1 := tail * 1.5 if s == -1 else w - tail * 1.5
			var notch := x0 + (tail * 0.42 if s == -1 else -tail * 0.42)
			draw_colored_polygon(PackedVector2Array([
				Vector2(x0, drop), Vector2(x1, drop), Vector2(x1, h + drop), Vector2(x0, h + drop),
				Vector2(notch, h * 0.5 + drop)]), dark)
			var xf := tail if s == -1 else w - tail
			draw_colored_polygon(PackedVector2Array([Vector2(xf, h - 2), Vector2(x1, h - 2), Vector2(x1, h + drop)]), darker)
		var sb := StyleBoxFlat.new()
		sb.bg_color = color
		sb.set_corner_radius_all(int(h * 0.22))
		sb.border_width_bottom = int(h * 0.09)
		sb.border_color = color.darkened(0.16)
		sb.anti_aliasing = true
		sb.shadow_color = Color(0.07, 0.15, 0.26, 0.18)
		sb.shadow_size = 6
		sb.shadow_offset = Vector2(0, 4)
		draw_style_box(sb, Rect2(tail, 0, w - tail * 2.0, h))
		var sh := StyleBoxFlat.new()
		sh.bg_color = Color(1, 1, 1, 0.14)
		sh.set_corner_radius_all(int(h * 0.16))
		draw_style_box(sh, Rect2(tail + 8, 5, w - tail * 2.0 - 16, h * 0.34))

## On/off switch.
class Switch extends Control:
	signal toggled(on: bool)
	var on := true
	var t := 1.0
	func _init(p_on: bool) -> void:
		on = p_on
		t = 1.0 if on else 0.0
		custom_minimum_size = Vector2(104, 58)
		mouse_filter = Control.MOUSE_FILTER_STOP
	var _last_toggle := -1000
	## On phones one tap arrives twice (the touch and the mouse click Android
	## emulates from it), so only the click is used, and a second toggle within
	## a moment is ignored.
	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			toggle()
			accept_event()
		elif e is InputEventScreenTouch:
			accept_event()
	func toggle() -> void:
		var now := Time.get_ticks_msec()
		if now - _last_toggle < 250:
			return
		_last_toggle = now
		on = not on
		Sfx.play("click")
		Save.buzz(12)
		var tw := create_tween()
		tw.tween_property(self, "t", 1.0 if on else 0.0, 0.18).set_trans(Tween.TRANS_QUAD)
		toggled.emit(on)
	func _process(_d: float) -> void:
		queue_redraw()
	func _draw() -> void:
		var w := size.x
		var h := size.y
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("#d9cfbb").lerp(Pal.GOOD, t)
		sb.set_corner_radius_all(int(h * 0.5))
		sb.anti_aliasing = true
		sb.border_width_top = 3
		sb.border_color = sb.bg_color.darkened(0.12)
		draw_style_box(sb, Rect2(Vector2.ZERO, size))
		var r := h * 0.5 - 6
		var x := lerpf(h * 0.5, w - h * 0.5, t)
		draw_circle(Vector2(x, h * 0.5 + 3), r, Color(0.07, 0.15, 0.26, 0.18), true, -1.0, true)
		draw_circle(Vector2(x, h * 0.5), r, Color("#fffdf7"), true, -1.0, true)

## A level buoy on the map.
class LevelNode extends Control:
	var number := 1
	var state := "locked"  # done | current | locked
	var stars := 0
	var milestone := false
	func _init(p_number: int, p_state: String, p_stars: int, p_milestone: bool) -> void:
		number = p_number
		state = p_state
		stars = p_stars
		milestone = p_milestone
		var d := 150.0 if state == "current" else 120.0
		custom_minimum_size = Vector2(d, d)
		size = custom_minimum_size
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	func _draw() -> void:
		var d := size.x
		var c := Vector2(d * 0.5, d * 0.47)
		var r := d * 0.4
		var col := Color("#d5dde4")
		if state == "done":
			col = Pal.VIOLET if milestone else Pal.SEA
		elif state == "current":
			col = Pal.ACCENT
		# soft shadow on the water, white collar, coloured face with a lip
		draw_circle(c + Vector2(0, d * 0.11), r * 1.04, Color(0.05, 0.2, 0.4, 0.16), true, -1.0, true)
		draw_circle(c + Vector2(0, d * 0.065), r * 1.1, Color("#e3d5ba") if state != "locked" else Color("#c3cdd6"), true, -1.0, true)
		draw_circle(c, r * 1.1, Color("#fffdf7") if state != "locked" else Color("#eef2f5"), true, -1.0, true)
		draw_circle(c + Vector2(0, d * 0.03), r * 0.9, col.darkened(0.22), true, -1.0, true)
		draw_circle(c, r * 0.9, col, true, -1.0, true)
		draw_arc(c, r * 0.7, PI * 1.12, PI * 1.6, 14, Color(1, 1, 1, 0.35), d * 0.045, true)
		if state != "locked":
			var f := Pal.font_display()
			var fs := int(d * (0.36 if number < 10 else (0.32 if number < 100 else 0.26)))
			var txt := str(number)
			var ts := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
			var pos := Vector2(c.x - ts.x * 0.5, c.y + f.get_ascent(fs) * 0.34)
			draw_string(f, pos + Vector2(0, d * 0.022), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col.darkened(0.35))
			draw_string(f, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
		else:
			var lw := d * 0.34
			Icons.draw_fit(self, Icons.icon_tex("lock"), Rect2(c - Vector2(lw, lw) * 0.5, Vector2(lw, lw)), Color("#9eabb8"))

## Dotted route between level buoys.
class Route extends Control:
	var pts: Array = []       # Vector2 centres in this control's space
	var reached := 0          # segments before this index are drawn solid
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		for i in range(pts.size() - 1):
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			var mid := (a + b) * 0.5 + Vector2((b.y - a.y) * 0.18, 0)
			var length := a.distance_to(b)
			var n := int(length / 26.0)
			for k in range(1, n):
				var t := float(k) / n
				var p := a.lerp(mid, t).lerp(mid.lerp(b, t), t)
				var done := i < reached
				draw_circle(p, 6.5 if done else 5.0, Color(1, 1, 1, 0.95) if done else Color(1, 1, 1, 0.4), true, -1.0, true)

## Small rounded tile with an icon: harbour project icons, setting rows.
class Tile extends Control:
	var glyph := "?"
	var color := Pal.GOOD
	func _init(p_glyph: String, p_color: Color, d := 96.0) -> void:
		glyph = p_glyph
		color = p_color
		custom_minimum_size = Vector2(d, d)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	func _draw() -> void:
		var d := size.x
		var sb := StyleBoxFlat.new()
		sb.bg_color = color
		sb.set_corner_radius_all(int(d * 0.28))
		sb.border_width_bottom = int(d * 0.07)
		sb.border_color = color.darkened(0.2)
		sb.anti_aliasing = true
		sb.corner_detail = 10
		draw_style_box(sb, Rect2(Vector2.ZERO, size))
		var sh := StyleBoxFlat.new()
		sh.bg_color = Color(1, 1, 1, 0.16)
		sh.set_corner_radius_all(int(d * 0.2))
		draw_style_box(sh, Rect2(d * 0.1, d * 0.07, d * 0.8, d * 0.32))
		var t := Icons.icon_tex(glyph)
		if t != null:
			Icons.draw_fit(self, t, Rect2(d * 0.22, d * 0.18, d * 0.56, d * 0.56), Color.WHITE)
		else:
			var f := Pal.font_display()
			var fs := int(d * 0.5)
			var ts := f.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
			draw_string(f, Vector2((d - ts.x) * 0.5, d * 0.5 + f.get_ascent(fs) * 0.3), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
