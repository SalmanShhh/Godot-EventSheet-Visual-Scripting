@tool
class_name SizePairTest
extends RefCounted

## A width and a height on one row: the texture size line round-trips byte for byte (and a line it
## cannot read stays as written), the decor map reads it, a side by side pair keeps its
## @export_range limits, and the sizes and the cost under the row say what they should.

const SUPPORT := preload("res://tests/support.gd")
const NOTES_PATH: String = "res://addons/eventsheet/editor/inspector/size_notes.gd"
const PAIR: String = "extends Node\n\n# @inspector_texture_size 256 512 1024 2048\n# @inspector_link canvas_width canvas_height\n# @inspector_side_by_side\n## Canvas texture width in pixels.\n@export var canvas_width: int = 512\n## Canvas texture height in pixels.\n@export var canvas_height: int = 512\n"
const TABBED: String = "extends Node\n\n# @inspector_texture_size 64 128\n# @inspector_tabs\n@export var canvas_width: int = 512\n"
const NOT_SIZES: String = "extends Node\n\n# @inspector_texture_size big small\n@export var canvas_width: int = 512\n"
const NO_SIZES: String = "extends Node\n\n# @inspector_texture_size\n@export var canvas_width: int = 512\n"


static func run() -> bool:
	var ok: bool = true
	ok = _round_trip() and ok
	ok = _decor() and ok
	ok = _range() and ok
	ok = _notes() and ok
	return ok


static func _round_trip() -> bool:
	var rows: Array = []
	for named: Array in [["a pair with sizes, link and side by side", PAIR], ["sizes above tabs", TABBED], ["a line with no sizes", NO_SIZES], ["a line it cannot read", NOT_SIZES]]:
		rows.append(["%s re-saves byte for byte" % named[0], SUPPORT.reemit(str(named[1]), "user://size_pair_probe.gd"), named[1]])
	var variable: LocalVariable = null
	for entry: Variant in SUPPORT.reopen(PAIR).events:
		if entry is LocalVariable and (entry as LocalVariable).name == "canvas_width":
			variable = entry as LocalVariable
	rows.append(["the first variable is read", variable != null, true])
	if variable != null:
		rows.append(["the sizes are read into the attribute", variable.attributes.get("texture_size", ""), "256 512 1024 2048"])
		rows.append(["the link and the side by side are read with it", [variable.attributes.get("link_with", ""), variable.attributes.get("side_by_side", false)], ["canvas_height", true]])
	var emitted: LocalVariable = LocalVariable.new()
	emitted.name = "canvas_width"
	emitted.type_name = "int"
	emitted.default_value = 512
	emitted.exported = true
	emitted.attributes = {"texture_size": "256 512"}
	rows.append(["the line is written first in the decor block", EventSheetCompiler._emit_tree_variable_line(emitted), "# @inspector_texture_size 256 512\n@export var canvas_width: int = 512"])
	return SUPPORT.pins("size_pair_test", rows)


static func _decor() -> bool:
	var map: Dictionary = EventSheetAttributeDrawers.build_decor_map(PAIR)
	var entries: Array = map.get("canvas_width", [])
	var kinds: PackedStringArray = PackedStringArray()
	var sizes: PackedInt32Array = PackedInt32Array()
	for entry: Variant in entries:
		kinds.append(str((entry as Dictionary).get("kind", "")))
		if str((entry as Dictionary).get("kind", "")) == "texture_size":
			sizes = (entry as Dictionary).get("sizes", PackedInt32Array())
	return SUPPORT.pins("size_pair_test", [
		["the first variable carries the sizes, the link and the side by side", kinds, PackedStringArray(["texture_size", "link", "side_by_side"])],
		["the sizes are the four numbers", sizes, PackedInt32Array([256, 512, 1024, 2048])],
	])


static func _range() -> bool:
	var widgets: GDScript = EventSheetAttributeDrawers.widgets()
	var spec: Dictionary = widgets.SideBySideProperty.range_spec("1,2048,1")
	var open_spec: Dictionary = widgets.SideBySideProperty.range_spec("0,100,0.5,or_greater,or_less")
	var spin: SpinBox = SpinBox.new()
	widgets.SideBySideProperty.apply_range(spin, spec, true)
	var limits: Array = [spin.min_value, spin.max_value, spin.step, spin.allow_greater, spin.allow_lesser]
	var untouched: SpinBox = SpinBox.new()
	untouched.max_value = 77.0
	widgets.SideBySideProperty.apply_range(untouched, {}, true)
	var result: bool = SUPPORT.pins("size_pair_test", [
		["a range hint is read into its limits", [spec["min"], spec["max"], spec["step"], spec["or_greater"], spec["or_less"]], [1.0, 2048.0, 1.0, false, false]],
		["the or greater and or less flags are read", [open_spec["or_greater"], open_spec["or_less"]], [true, true]],
		["a field takes the limits of its property", limits, [1.0, 2048.0, 1.0, false, false]],
		["a property with no range leaves the field as it was", untouched.max_value, 77.0],
		["a pair with no object has no range", widgets.SideBySideProperty.range_of(null, "x"), {}],
	])
	spin.free()
	untouched.free()
	return result


static func _notes() -> bool:
	var notes: Control = load(NOTES_PATH).new(PackedInt32Array([256, 512, 1024]))
	notes.call("show_pair", 512, 512)
	var first: String = str(notes.call("cost_line"))
	var picks: Array = []
	notes.connect("size_picked", func(size: int) -> void: picks.append(size))
	notes.call("show_pair", 512, 256)
	var result: bool = SUPPORT.pins("size_pair_test", [
		["the strip offers each size", notes.call("size_count"), 3],
		["the cost is worked out at four bytes a pixel in Godot's own size words", first, "512 x 512 px, about %s of video memory." % String.humanize_size(512 * 512 * 4)],
		["a square on a listed size fills it", load(NOTES_PATH).pressed_size(512, 512, PackedInt32Array([256, 512])), 512],
		["a pair that is not square fills nothing", load(NOTES_PATH).pressed_size(512, 256, PackedInt32Array([256, 512])), 0],
		["a square on an unlisted size fills nothing", load(NOTES_PATH).pressed_size(300, 300, PackedInt32Array([256, 512])), 0],
	])
	notes.free()
	return result
