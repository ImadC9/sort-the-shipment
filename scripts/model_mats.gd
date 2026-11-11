class_name ModelMats
extends RefCounted
## Loads Blender-made GLB models and swaps their named materials for game
## materials. Baked ambient occlusion lives in the vertex colours and is
## multiplied into every surface.

const BASE := {
	"HullWhite": [Color("#f6f6f2"), 0.55, 0.0],
	"BootTop": [Color("#ffffff"), 0.5, 0.0],
	"Bottom": [Color("#c4473f"), 0.7, 0.0],
	"Hatch": [Color("#a7b7c2"), 0.6, 0.2],
	"House": [Color("#fbfbf7"), 0.5, 0.0],
	"Glass": [Color("#356b79"), 0.27, 0.05],
	"Roof": [Color("#c9d1d8"), 0.6, 0.0],
	"FunnelTop": [Color("#2b2f36"), 0.6, 0.0],
	"Metal": [Color("#c3ccd4"), 0.4, 0.4],
	"Orange": [Color("#ff7a1a"), 0.5, 0.0],
	"Dark": [Color("#3a3f47"), 0.6, 0.3],
	"Yellow": [Color("#ffc53d"), 0.5, 0.1],
	"Blue": [Color("#5aa9e6"), 0.5, 0.2],
	"Light": [Color("#eef3f7"), 0.5, 0.1],
	"Black": [Color("#2a2d33"), 0.6, 0.1],
	"Rubber": [Color("#2f3238"), 0.9, 0.0],
	"Concrete": [Color("#d9d2c4"), 0.95, 0.0],
	"Lamp": [Color("#fff3c4"), 0.3, 0.0],
	"Red": [Color("#ef4b5c"), 0.5, 0.0],
	"White": [Color("#ffffff"), 0.5, 0.0],
	# all untinted parts after Blender folded their colours into the vertex colours
	"Fixed": [Color("#ffffff"), 0.5, 0.0],
}

static var _cache := {}
static var _scenes := {}
static var _prepared_meshes := {}

static func _prepare_mesh(src: Mesh) -> Mesh:
	# 2.0: the Blender kit already stores vertex colours in the renderer's
	# colour space, so meshes are used exactly as imported.
	return src

static func material(name: String, tint: Color = Color.WHITE) -> StandardMaterial3D:
	var col: Color
	var rough := 0.6
	var metal := 0.0
	match name:
		"Hull":
			col = tint
			rough = 0.42
		"Funnel":
			col = tint.lerp(Color.WHITE, 0.06)
			rough = 0.45
		"Deck":
			# the open deck carries the ship's colour, a tone deeper than the cargo
			col = tint.darkened(0.14).lerp(Color("#2c4763"), 0.12)
			rough = 0.8
		"Hatch":
			# landing pads for the boxes: a pale wash of the ship's colour
			col = tint.lerp(Color("#fffaf0"), 0.62)
			rough = 0.75
		_:
			var b: Array = BASE.get(name, [Color(1, 1, 1), 0.6, 0.0])
			col = b[0]
			rough = b[1]
			metal = b[2]
	var key := "%s_%s" % [name, col.to_html()]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	m.metallic = metal
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	# soft toy shading: light wraps round the form, with a faint rim
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
	m.metallic_specular = 0.35
	m.rim_enabled = true
	m.rim = 0.16
	m.rim_tint = 0.5
	_cache[key] = m
	return m

## A painted, colour-blind-friendly mark. Loaded cargo naturally covers it.
static func add_deck_symbol(parent: Node3D, colour: int, pos: Vector3) -> void:
	var symbol := Label3D.new()
	symbol.font = Pal.font_sym()
	symbol.font_size = 64
	symbol.text = Pal.symbol(colour)
	symbol.pixel_size = 0.009
	symbol.outline_size = 10
	symbol.modulate = Color("#fff6df")
	symbol.outline_modulate = Color("#28495b")
	symbol.position = pos
	symbol.rotation = Vector3(-PI / 2, PI, 0)
	symbol.shaded = false
	symbol.double_sided = false
	symbol.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(symbol)

## Instances a GLB model and applies game materials (Hull/Funnel/Deck tinted).
static func instance(path: String, tint: Color = Color.WHITE) -> Node3D:
	if not _scenes.has(path):
		_scenes[path] = load(path)
	var root: Node3D = (_scenes[path] as PackedScene).instantiate()
	_apply(root, tint)
	return root

static func _apply(n: Node, tint: Color) -> void:
	if n is MeshInstance3D:
		var mi: MeshInstance3D = n
		mi.mesh = _prepare_mesh(mi.mesh)
		for i in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(i)
			var nm := src.resource_name if src else ""
			mi.set_surface_override_material(i, material(nm, tint))
	for c in n.get_children():
		_apply(c, tint)

## Fetches the first mesh of a model, for cases where a raw Mesh is needed.
static func mesh_of(path: String) -> Mesh:
	var root := instance(path)
	var found: Mesh = null
	for c in root.find_children("*", "MeshInstance3D", true, false):
		found = (c as MeshInstance3D).mesh
		break
	root.free()
	return found
