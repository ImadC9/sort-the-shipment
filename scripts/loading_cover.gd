class_name LoadingCover
extends CanvasLayer
## Start-up cover. It shows the same picture as Godot's boot splash
## (assets/ui/splash.png, made by tools/make_splash.py), placed the same way,
## so the hand-over from the engine is invisible. It adds a progress bar while
## the harbour is built and while the first frames compile their shaders
## underneath it, then fades away. Blocks taps until it is gone.

const IMG := Vector2(1080, 1920)
const BG := Color(0.86, 0.94, 0.98)       # = application/boot_splash/bg_color
const BAR_Y := 1478.0                      # in splash-image pixels
const BAR_W := 520.0
const BAR_H := 30.0
const MIN_SECONDS := 0.7                   # never just flash past

var _root: Control
var _tex: Texture2D
var _target := 0.0
var _shown := 0.0
var _born := 0.0
var _done := false

func _init() -> void:
	layer = 128

func _ready() -> void:
	_born = Time.get_ticks_msec() / 1000.0
	_tex = load("res://assets/ui/splash.png")
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.draw.connect(_draw_cover)
	add_child(_root)

## 0..1; the bar glides towards it.
func set_progress(p: float) -> void:
	_target = maxf(_target, clampf(p, 0.0, 1.0))

func _process(delta: float) -> void:
	_shown = move_toward(_shown, _target, delta * 1.8)
	_root.queue_redraw()

## Fills the bar, waits for it, then fades the cover out and frees it.
func finish() -> void:
	if _done:
		return
	_done = true
	set_progress(1.0)
	while _shown < 0.999 or Time.get_ticks_msec() / 1000.0 - _born < MIN_SECONDS:
		await get_tree().process_frame
	var tw := _root.create_tween()
	tw.tween_property(_root, "modulate:a", 0.0, 0.35).set_trans(Tween.TRANS_SINE)
	await tw.finished
	queue_free()

func _draw_cover() -> void:
	var vs := _root.size
	_root.draw_rect(Rect2(Vector2.ZERO, vs), BG)
	var s := minf(vs.x / IMG.x, vs.y / IMG.y)
	var off := (vs - IMG * s) * 0.5
	_root.draw_texture_rect(_tex, Rect2(off, IMG * s), false)
	# progress bar
	var w := BAR_W * s
	var h := BAR_H * s
	var pos := off + Vector2((IMG.x - BAR_W) * 0.5, BAR_Y) * s
	var track := StyleBoxFlat.new()
	track.bg_color = Color(1, 1, 1, 0.9)
	track.set_corner_radius_all(int(h * 0.5))
	track.border_color = Color(Pal.INK, 0.12)
	track.set_border_width_all(maxi(1, int(2 * s)))
	_root.draw_style_box(track, Rect2(pos, Vector2(w, h)))
	var inset := 5.0 * s
	var fw := maxf(h - inset * 2, (w - inset * 2) * _shown)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Pal.ACCENT
	fill.set_corner_radius_all(int((h - inset * 2) * 0.5))
	_root.draw_style_box(fill, Rect2(pos + Vector2(inset, inset), Vector2(fw, h - inset * 2)))
	# a soft highlight along the top of the fill
	_root.draw_rect(Rect2(pos + Vector2(inset + h * 0.3, inset + 2 * s), Vector2(maxf(0, fw - h * 0.6), maxf(1, 3 * s))), Color(1, 1, 1, 0.35))
	# caption
	var font := Pal.font_display()
	var fs := int(38 * s)
	var text := "Loading the harbour..."
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	_root.draw_string(font, Vector2(off.x + IMG.x * s * 0.5 - tw * 0.5, pos.y + h + 62 * s), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(Pal.INK_SOFT, 0.9))
