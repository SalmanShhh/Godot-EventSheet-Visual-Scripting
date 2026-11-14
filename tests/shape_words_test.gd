@tool
class_name ShapeWordsTest
extends RefCounted

## The vector shapes name their choice words once, in the 2D base, and the 3D shapes and the Canvas
## Surface read the same words. The exported lines in the shape scripts keep the words as text (the
## editor builds the drop-down from that line and a saved scene stores the word), so this pins the two
## together: every word a shape offers has a constant, no constant is a word nothing offers, and the
## Canvas Surface, which is a separate pack and so keeps its own copy, speaks the same words.

const SUPPORT := preload("res://tests/support.gd")
const NAME: String = "shape_words_test"
const PACK_DIR: String = "res://eventsheet_addons/vector_shapes/"
const BASE_2D: String = "res://eventsheet_addons/vector_shapes/vector_shape_2d.gd"
const BASE_3D: String = "res://eventsheet_addons/vector_shapes/vector_shape_3d.gd"
const CANVAS: String = "res://eventsheet_addons/canvas_surface/canvas_surface.gd"
const STYLE: String = "res://eventsheet_addons/vector_shapes/shape_style.gd"

## [exported variable, constant prefix, which scripts offer it: 2 = 2D shapes and the style file, 3 = 3D shapes]
const CHOICES: Array = [
	["thickness_scale", "THICKNESS_SCALE_", 2],
	["colour_mode", "COLOUR_MODE_", 2],
	["dash_space", "DASH_SPACE_", 2],
	["dash_snap", "DASH_SNAP_", 2],
	["dash_style", "DASH_STYLE_", 2],
	["blend", "BLEND_", 2],
	["caps", "CAPS_", 2],
	["colour_mode", "COLOUR_MODE_", 3],
	["dash_space", "DASH_SPACE_", 3],
	["dash_snap", "DASH_SNAP_", 3],
	["dash_style", "DASH_STYLE_", 3],
	["blend", "BLEND_", 3],
	["caps", "CAPS_", 3],
]


static func run() -> bool:
	var rows: Array = []
	var base: GDScript = load(BASE_2D) as GDScript
	var base_3d: GDScript = load(BASE_3D) as GDScript
	for choice: Array in CHOICES:
		var offered: PackedStringArray = _offered(str(choice[0]), int(choice[2]))
		var named: PackedStringArray = _named(base, str(choice[1]))
		offered.sort()
		named.sort()
		rows.append(["%dD shapes: every %s word has a constant and no constant is extra" % [int(choice[2]), choice[0]], named, offered])
	# The 3D-only words, and the units, which a row may also type in pixels.
	rows.append(["3D shapes: every geometry word has a constant", _sorted(_named(base_3d, "GEOMETRY_")), _sorted(_offered("geometry", 3))])
	rows.append(["3D shapes: every depth word has a constant", _sorted(_named(base_3d, "DEPTH_")), _sorted(_offered("depth", 3))])
	var units: PackedStringArray = _named(base, "THICKNESS_UNIT_")
	for word: String in _offered("thickness_unit", 3):
		rows.append(["the unit word %s has a constant" % word, units.has(word), true])
	# The Canvas Surface is its own pack, so it keeps a copy of the words - the same words.
	var canvas: GDScript = load(CANVAS) as GDScript
	var canvas_words: Dictionary = canvas.get_script_constant_map()
	var shared: Dictionary = base.get_script_constant_map()
	rows.append(["the canvas speaks the same cap words", canvas_words.get("CAP_WORDS"), shared.get("CAP_STYLES")])
	rows.append(["the canvas speaks the same colour modes", canvas_words.get("COLOUR_MODE_WORDS"), shared.get("COLOUR_MODES")])
	rows.append(["the canvas speaks the same dash snaps", canvas_words.get("DASH_SNAP_WORDS"), shared.get("DASH_SNAPS")])
	rows.append(["the canvas speaks the same dash styles", canvas_words.get("DASH_STYLE_WORDS"), shared.get("DASH_STYLES")])
	var defaults: Dictionary = canvas_words.get("STYLE_DEFAULTS", {})
	rows.append(["the canvas's default words are words the shapes offer", [
		defaults.get("caps") in shared.get("CAP_STYLES"), defaults.get("colour_mode") in shared.get("COLOUR_MODES"),
		defaults.get("dash_space") in shared.get("DASH_SPACES"), defaults.get("dash_snap") in shared.get("DASH_SNAPS"),
		defaults.get("dash_style") in shared.get("DASH_STYLES")], [true, true, true, true, true]])
	return SUPPORT.pins(NAME, rows)


static func _sorted(words: PackedStringArray) -> PackedStringArray:
	var copy: PackedStringArray = words.duplicate()
	copy.sort()
	return copy


## Every constant of one choice, by its prefix, as the word it holds.
static func _named(script: GDScript, prefix: String) -> PackedStringArray:
	var named: PackedStringArray = PackedStringArray()
	var constants: Dictionary = script.get_script_constant_map()
	for constant_name: Variant in constants:
		if str(constant_name).begins_with(prefix) and constants[constant_name] is String:
			named.append(str(constants[constant_name]))
	return named


## Every word any shape script of one dimension offers for one exported choice.
static func _offered(variable: String, dimension: int) -> PackedStringArray:
	var offered: PackedStringArray = PackedStringArray()
	var suffix: String = "_%dd.gd" % dimension
	for file: String in DirAccess.get_files_at(PACK_DIR):
		if not (file.begins_with("shape_") and file.ends_with(suffix)):
			continue
		var script: GDScript = load(PACK_DIR + file) as GDScript
		for property: Dictionary in script.get_script_property_list():
			if str(property.name) == variable:
				for word: String in str(property.hint_string).split(",", false):
					if not offered.has(word):
						offered.append(word)
	if dimension == 2:
		var style: GDScript = load(STYLE) as GDScript
		for property: Dictionary in style.get_script_property_list():
			if str(property.name) == variable:
				for word: String in str(property.hint_string).split(",", false):
					if not offered.has(word):
						offered.append(word)
	return offered
