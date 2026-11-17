# Godot EventSheets - one row sets a shape's colour from a role of a colour palette.
#
# "Set Shape Colour From Palette" takes a palette resource, the name of a colour set and a role ("Danger"),
# and sets the shape's main colour to what that set holds for that role. It reads the palette by the names
# its fields carry, so the shapes pack compiles and runs without the palette pack beside it; a palette, set
# or role that is not there leaves the colour as it was and warns once. It is on both the 2D and the 3D shape
# bases. A test run has no tree, so the shapes are built outside one and asked directly, and the annotations
# the picker reads are pinned as text in the shipped files.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const TEST_NAME := "shape_colour_from_palette_test"
const PALETTE := "res://eventsheet_addons/color_palette_resource/color_palette_resource.gd"
const DISC_2D := "res://eventsheet_addons/vector_shapes/shape_disc_2d.gd"
const DISC_3D := "res://eventsheet_addons/vector_shapes/shape_disc_3d.gd"
const BASE_2D := "res://eventsheet_addons/vector_shapes/vector_shape_2d.gd"
const BASE_3D := "res://eventsheet_addons/vector_shapes/vector_shape_3d.gd"
const RED := Color(0.9, 0.2, 0.2)
const GREEN := Color(0.2, 0.8, 0.3)
const GREY := Color(0.5, 0.5, 0.5)
const ORANGE := Color(0.95, 0.55, 0.1)
const BLUE := Color(0.2, 0.4, 0.95)
const SAND := Color(0.8, 0.7, 0.5)
const START := Color(0.1, 0.1, 0.1)


static func run() -> bool:
	var ok: bool = true
	ok = _reading(DISC_2D) and ok
	ok = _reading(DISC_3D) and ok
	ok = _the_palette_is_asked_by_name() and ok
	ok = _annotations() and ok
	return ok


## Two colour sets of three roles each, the way the palette pack's resource holds them.
static func _palette() -> Resource:
	var palette: Resource = (load(PALETTE) as GDScript).new()
	palette.set("role_names", PackedStringArray(["Danger", "Safe", "Neutral"]))
	palette.set("set_names", PackedStringArray(["Default", "Deuteranopia"]))
	var sets: Array[PackedColorArray] = [PackedColorArray([RED, GREEN, GREY]), PackedColorArray([ORANGE, BLUE, SAND])]
	palette.set("set_colors", sets)
	return palette


static func _reading(shape_path: String) -> bool:
	var which: String = shape_path.get_file()
	var shape: Node = (load(shape_path) as GDScript).new() as Node
	var palette: Resource = _palette()
	var rows: Array = []
	shape.set("colour", START)
	shape.call("set_shape_colour_from_palette", palette, "Deuteranopia", "Safe")
	rows.append(["%s: the second set, the Safe role" % which, shape.get("colour"), BLUE])
	shape.call("set_shape_colour_from_palette", palette, "", "Danger")
	rows.append(["%s: an empty set name is the first set" % which, shape.get("colour"), RED])
	shape.call("set_shape_colour_from_palette", palette, "deuteranopia", "neutral")
	rows.append(["%s: names match without regard to capitals" % which, shape.get("colour"), SAND])
	shape.set("colour", START)
	shape.call("set_shape_colour_from_palette", palette, "Default", "NoSuchRole")
	rows.append(["%s: a role the palette has not got leaves the colour" % which, shape.get("colour"), START])
	rows.append(["%s: and says so once" % which, shape.get("_palette_warned"), true])
	shape.call("set_shape_colour_from_palette", palette, "NoSuchSet", "Danger")
	rows.append(["%s: a set the palette has not got leaves the colour" % which, shape.get("colour"), START])
	shape.call("set_shape_colour_from_palette", null, "", "Danger")
	rows.append(["%s: no palette leaves the colour" % which, shape.get("colour"), START])
	shape.call("set_shape_colour_from_palette", Resource.new(), "", "Danger")
	rows.append(["%s: a resource that is not a palette leaves the colour" % which, shape.get("colour"), START])
	shape.call("set_shape_colour_from_palette", palette, "Default", "Safe")
	rows.append(["%s: a good call after a bad one works" % which, shape.get("colour"), GREEN])
	rows.append(["%s: and lets the next failure speak again" % which, shape.get("_palette_warned"), false])
	shape.free()
	return SUPPORT.pins(TEST_NAME, rows)


## What the row says when it cannot do its work is a plain sentence, and a colour set shorter than its roles is
## one of the cases.
static func _the_palette_is_asked_by_name() -> bool:
	var base: GDScript = load(BASE_2D) as GDScript
	var palette: Resource = _palette()
	var short: Resource = _palette()
	var short_sets: Array[PackedColorArray] = [PackedColorArray([RED])]
	short.set("set_colors", short_sets)
	short.set("set_names", PackedStringArray(["Default"]))
	var three_d: String = FileAccess.get_file_as_string(BASE_3D)
	var two_d: String = FileAccess.get_file_as_string(BASE_2D)
	return SUPPORT.pins(TEST_NAME, [
		["a colour comes back as a colour", base.call("palette_colour", palette, "Default", "Safe"), GREEN],
		["no palette is said in words", base.call("palette_colour", null, "", "Safe"), "no palette was given"],
		["a missing role is said in words", base.call("palette_colour", palette, "", "Calm"), "the palette has no role named \"Calm\""],
		["a missing set is said in words", base.call("palette_colour", palette, "Tritanopia", "Safe"), "the palette has no colour set named \"Tritanopia\""],
		["a set shorter than the roles is said in words", base.call("palette_colour", short, "", "Safe"), "that colour set has no colour for \"Safe\""],
		["the shapes pack does not name the palette pack's class (2D)", two_d.contains("ColorPaletteResource"), false],
		["nor does the 3D base", three_d.contains("ColorPaletteResource"), false],
		["the 3D base asks the same function the 2D base answers with", three_d.contains("SHAPE_WORDS.palette_colour(palette, colour_set, role)"), true],
	])


static func _annotations() -> bool:
	var rows: Array = []
	for pair: Array in [[BASE_2D, "VectorShape2D"], [BASE_3D, "VectorShape3D"]]:
		var source: String = FileAccess.get_file_as_string(pair[0])
		var which: String = str(pair[0]).get_file()
		var block: int = source.find("func set_shape_colour_from_palette(")
		var head: String = source.substr(maxi(block - 1500, 0), mini(1500, block)) if block >= 0 else ""
		rows.append(["%s has the row" % which, block >= 0, true])
		rows.append(["%s: it is an action named for what it does" % which, head.contains("## @ace_action\n## @ace_name(\"Set Shape Colour From Palette\")"), true])
		rows.append(["%s: it sits in the Vector Shapes section" % which, head.contains("## @ace_category(\"Vector Shapes\")"), true])
		rows.append(["%s: its sentence names the role, the palette and the set" % which, head.contains("## @ace_display_template(\"Set shape colour to [b]{role}[/b] from [b]{palette}[/b] ([b]{colour_set}[/b])\")"), true])
		rows.append(["%s: its call goes to the node picked" % which, head.contains("## @ace_codegen_template(\"$%s.set_shape_colour_from_palette({palette}, {colour_set}, {role})\")" % pair[1]), true])
		rows.append(["%s: its three parameters" % which, source.contains("func set_shape_colour_from_palette(palette: Resource, colour_set: String, role: String) -> void:"), true])
		rows.append(["%s: the helper that works the colour out is hidden from the picker" % which, which != "vector_shape_2d.gd" or source.contains("## @ace_hidden\nstatic func palette_colour("), true])
	return SUPPORT.pins(TEST_NAME, rows)
