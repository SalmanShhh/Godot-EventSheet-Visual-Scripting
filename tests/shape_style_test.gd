# Godot EventSheets - the Shape Style: a look shared by many shapes, as a file.
#
# Everything here is pinned BY VALUE on real nodes built and freed in this file - a line and a
# triangle reading their fields through a style, the property list the Inspector would draw, and a
# style written to disk and read back. Nothing needs a scene tree or a physics space, which the
# suite has neither of: the group verb is therefore pinned as the two things a test can see - the
# call it makes on each shape, and its refusal to touch anything when there is no tree.
#
# THE SLOT IS AN OVERRIDE, NOT A WRITE. A shape wearing a style keeps its own fields exactly as the
# file stored them; only what it DRAWS with changes, and clearing the slot hands them straight back.
# So every pin below reads both: what the shape stores, and what it draws with.
@tool
class_name ShapeStyleTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const PREFIX := "shape_style_test"

## Where a style written by the test goes - never res://, which is the repository.
const WRITE_DIR := "user://shape_style_test"

## Where the pack ships.
const PACK_DIR := "res://eventsheet_addons/vector_shapes/"


static func run() -> bool:
	var all_passed: bool = true
	all_passed = _pin_the_keys() and all_passed
	all_passed = _pin_the_picker_surface() and all_passed
	all_passed = _pin_the_override() and all_passed
	all_passed = _pin_the_greying() and all_passed
	all_passed = _pin_the_group_verb() and all_passed
	all_passed = _pin_save_as_style() and all_passed
	return all_passed


## The fields a style speaks for, as a list rather than a count: the list is a promise to every
## .tres somebody saves, and a key added or dropped has to be read here first.
static func _pin_the_keys() -> bool:
	var keys: PackedStringArray = ShapeStyle.styled_keys()
	var sorted: PackedStringArray = keys.duplicate()
	sorted.sort()
	var style: ShapeStyle = ShapeStyle.new()
	return SUPPORT.pins(PREFIX, [
		["the keys a style speaks for", ",".join(sorted),
			"blend,caps,colour,colour_b,colour_mode,dash_count,dash_size,dash_snap,dash_space,dash_spacing,dash_style,dashed,gradient,thickness,thickness_scale"],
		["a geometry field is never one of them", str(keys.has("radius") or keys.has("end_point") or keys.has("points")), "false"],
		["a key it does not hold answers nothing", str(style.value_for("end_point")), "<null>"],
		["a key it holds answers its value", float(style.value_for("thickness")), 2.0],
	])


## WHAT THE PICKER OFFERS ON A STYLE: NOTHING, AND THAT IS THE DESIGN. A style is edited in the
## Inspector and put in force by the SHAPE's own Apply Shape Style. A reflected row per field would
## write a style the compiler makes on the spot and no shape wears - it would compile, it would run,
## and no pixel would move - while duplicating by name the rows the shape base already publishes. So
## every field on the file is marked hidden, and the three verbs that ARE about a style live on the
## shape where they can reach one.
##
## The pin is the LIST both ways rather than a count: a dropped hidden marker names the field it put
## back in the picker, and a verb renamed off the base names itself.
static func _pin_the_picker_surface() -> bool:
	var style_ids: PackedStringArray = _published_ids(PACK_DIR + "shape_style.gd")
	var base_ids: PackedStringArray = _published_ids(PACK_DIR + "vector_shape_2d.gd")
	var style_verbs: PackedStringArray = PackedStringArray()
	for ace_id: String in base_ids:
		if ace_id.to_lower().contains("style"):
			style_verbs.append(ace_id)
	return SUPPORT.pins(PREFIX, [
		["the style file publishes no row of its own", ",".join(style_ids), ""],
		["the style verbs live on the shape, where they can reach one", ",".join(style_verbs),
			"method:apply_shape_style,method:apply_shape_style_to_group,method:shape_style_is"],
	])


## Every ace_id one shipped script publishes to the picker, sorted - asked of the registry rather
## than of the file's text, so an analyzer that stopped reading the hidden marker fails here too.
static func _published_ids(script_path: String) -> PackedStringArray:
	var ids: PackedStringArray = PackedStringArray()
	for definition: ACEDefinition in EventSheetPackReadingCheck.definitions_for_script(script_path):
		ids.append(definition.id)
	ids.sort()
	return ids


## A style in the slot is what the shape draws with; the shape's own fields are untouched. And a
## shape that has not got the field a style carries is not given one.
static func _pin_the_override() -> bool:
	var line: ShapeLine2D = ShapeLine2D.new()
	var triangle: ShapeTriangle2D = ShapeTriangle2D.new()
	var style: ShapeStyle = ShapeStyle.new()
	style.thickness = 6.0
	style.caps = "square"
	style.colour = Color("#112233")
	style.dashed = true
	style.dash_count = 20
	var before_thickness: float = line._number("thickness", 0.0)
	line.apply_shape_style(style)
	triangle.apply_shape_style(style)
	var rows: Array = [
		["the line draws 2 px before a style", before_thickness, 2.0],
		["the line draws the style's thickness", line._number("thickness", 0.0), 6.0],
		["the line's own field is untouched", line.thickness, 2.0],
		["the line draws the style's caps", line._word("caps", ""), "square"],
		["the line draws the style's colour", line._colour("colour").to_html(false), "112233"],
		["the line draws the style's dashes", str(line._flag("dashed")), "true"],
		["the line draws the style's dash count", line._number("dash_count", 0.0), 20.0],
		["a triangle has no dashes to give it", str(triangle._flag("dashed")), "false"],
		["the shape says which style it wears", str(line.shape_style_is(style)), "true"],
		["and which it does not", str(line.shape_style_is(null)), "false"],
	]
	line.apply_shape_style(null)
	rows.append(["an empty slot hands the fields back", line._number("thickness", 0.0), 2.0])
	rows.append(["the geometry is never the style's", line.end_point, Vector2(96.0, 0.0)])
	line.free()
	triangle.free()
	return SUPPORT.pins(PREFIX, rows)


## What the Inspector draws: a field a style speaks for is READ-ONLY while the style is in the slot -
## greyed, still there, still storing what the file stored. A field the style says nothing about is
## an ordinary field, and one the shape hides for a reason of its own stays hidden.
static func _pin_the_greying() -> bool:
	var line: ShapeLine2D = ShapeLine2D.new()
	var rows: Array = [
		["thickness is editable with no style", _readonly(line, "thickness"), false],
		["the end point is editable with no style", _readonly(line, "end_point"), false],
	]
	var style: ShapeStyle = ShapeStyle.new()
	line.apply_shape_style(style)
	rows.append(["thickness greys under a style", _readonly(line, "thickness"), true])
	rows.append(["caps greys under a style", _readonly(line, "caps"), true])
	rows.append(["the end point never greys", _readonly(line, "end_point"), false])
	rows.append(["the style slot itself never greys", _readonly(line, "style"), false])
	rows.append(["the shape agrees who speaks for thickness", line.style_speaks_for("thickness"), true])
	rows.append(["and who does not speak for the end point", line.style_speaks_for("end_point"), false])
	line.free()
	return SUPPORT.pins(PREFIX, rows)


## Whether the Inspector would draw one property greyed, asked the way the Inspector asks: the
## shape's own `_validate_property` over a property dictionary it may edit.
static func _readonly(shape: Node2D, property_name: String) -> bool:
	var property: Dictionary = {"name": property_name, "usage": PROPERTY_USAGE_DEFAULT}
	shape._validate_property(property)
	return bool(int(property["usage"]) & PROPERTY_USAGE_READ_ONLY)


## The group verb: what it CALLS on each shape is the same one-shape verb pinned above (so a group
## re-skin cannot drift from a single one), and with no tree to call through it does nothing at all
## rather than failing - which is the state a headless run, and an unparented node, are both in.
static func _pin_the_group_verb() -> bool:
	var first: ShapeLine2D = ShapeLine2D.new()
	var second: ShapeLine2D = ShapeLine2D.new()
	var style: ShapeStyle = ShapeStyle.new()
	style.thickness = 9.0
	first.apply_shape_style_to_group("hud_lines", style)
	var rows: Array = [
		["no tree, no re-skin, no error", str(first.style), "<null>"],
		["the verb names the group call", FileAccess.get_file_as_string(
			"res://eventsheet_addons/vector_shapes/vector_shape_2d.gd").contains(
			"get_tree().call_group(StringName(group_name), \"apply_shape_style\", style_file)"), true],
	]
	# What the group call arrives as, on each shape it reaches.
	for shape: ShapeLine2D in [first, second]:
		shape.apply_shape_style(style)
	rows.append(["the first shape wears it", first._number("thickness", 0.0), 9.0])
	rows.append(["the second shape wears it", second._number("thickness", 0.0), 9.0])
	first.free()
	second.free()
	return SUPPORT.pins(PREFIX, rows)


## Save As Style writes the fields it read, and the shape wears the file it wrote - so the picture
## on screen does not move when the button is pressed.
static func _pin_save_as_style() -> bool:
	DirAccess.make_dir_recursive_absolute(WRITE_DIR)
	var line: ShapeLine2D = ShapeLine2D.new()
	line.name = "AimLine"
	line.scene_file_path = WRITE_DIR + "/aim.tscn"
	line.thickness = 4.5
	line.caps = "none"
	line.colour = Color("#ff8800")
	line.dashed = true
	line.dash_count = 7
	var written: String = line.save_as_style()
	var reopened: ShapeStyle = ResourceLoader.load(written, "", ResourceLoader.CACHE_MODE_IGNORE) as ShapeStyle
	var rows: Array = [
		["it writes beside the scene, named for the node", written, WRITE_DIR + "/aim_line_style.tres"],
		["the file is a style", reopened != null, true],
		["it holds the thickness it read", reopened.thickness if reopened != null else -1.0, 4.5],
		["it holds the caps it read", reopened.caps if reopened != null else "", "none"],
		["it holds the colour it read", reopened.colour.to_html(false) if reopened != null else "", "ff8800"],
		["it holds the dash count it read", reopened.dash_count if reopened != null else -1, 7],
		["the shape now wears a style", line.style != null, true],
		["and draws exactly what it drew before", line._number("thickness", 0.0), 4.5],
		["a geometry field was never written", reopened != null and not ("end_point" in reopened), true],
	]
	line.free()
	DirAccess.remove_absolute(written)
	DirAccess.remove_absolute(WRITE_DIR)
	return SUPPORT.pins(PREFIX, rows)
