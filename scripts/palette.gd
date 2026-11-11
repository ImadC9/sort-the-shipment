class_name Pal
extends RefCounted
## Shared colours, symbols and fonts.

const CARGO := [
	Color("#f25565"),  # red
	Color("#3d8ef5"),  # blue
	Color("#ffc533"),  # yellow
	Color("#36c176"),  # green
	Color("#9364f0"),  # purple
	Color("#ff8b3d"),  # orange
	Color("#ff72b6"),  # pink
	Color("#1fc4c8"),  # teal
]
## shape per colour so colour-blind players can still sort
const SYMBOL := ["●", "■", "▲", "★", "◆", "♥", "✚", "⬟"]
const NAMES := ["Red", "Blue", "Yellow", "Green", "Purple", "Orange", "Pink", "Teal"]

# --- 2.0 "Toy Harbour" interface palette: warm paper, deep navy ink, sea accents
const INK := Color("#1f3350")
const INK_SOFT := Color("#62788f")
const INK_FAINT := Color("#a9b8c6")
const PAPER := Color("#fffaf0")        # cards and pills
const PAPER_EDGE := Color("#e6d9c0")   # the lip under a card
const PAPER_DIM := Color("#f4ecdc")    # wells inside a card
const SEA := Color("#2f9fe8")
const SEA_DEEP := Color("#1c7fd0")
const ACCENT := Color("#ff8b3d")
const ACCENT_2 := Color("#ffc533")
const GOOD := Color("#2fc272")
const BAD := Color("#f25565")
const VIOLET := Color("#9364f0")
const TARP := Color("#eadfc8")

static var _font_ui: Font
static var _font_sym: Font
static var _font_display: Font
static var _sym_tex := {}

## Body text.
static func font_ui() -> Font:
	if _font_ui == null:
		_font_ui = load("res://assets/fonts/Fredoka-SemiBold.ttf")
	return _font_ui

## Rounded display face for headings, numbers and buttons.
static func font_display() -> Font:
	if _font_display == null:
		_font_display = load("res://assets/fonts/Fredoka-Bold.ttf")
	return _font_display

## Fallback glyph font (a few arrows and marks).
static func font_sym() -> Font:
	if _font_sym == null:
		_font_sym = load("res://assets/fonts/DejaVuSans-Bold.ttf")
	return _font_sym

## White cargo symbol sprite (0-7 colours, 8 = question mark).
static func symbol_tex(c: int) -> Texture2D:
	var k := 8 if c < 0 or c > 8 else c
	if not _sym_tex.has(k):
		_sym_tex[k] = load("res://assets/ui/sym/sym_%d.png" % k)
	return _sym_tex[k]

## Round ship badge for a colour.
static func badge_tex(c: int) -> Texture2D:
	var k := "b%d" % (c % CARGO.size())
	if not _sym_tex.has(k):
		_sym_tex[k] = load("res://assets/ui/sym/badge_%d.png" % (c % CARGO.size()))
	return _sym_tex[k]

static func cargo(c: int) -> Color:
	return CARGO[c % CARGO.size()]

static func symbol(c: int) -> String:
	return SYMBOL[c % SYMBOL.size()]
