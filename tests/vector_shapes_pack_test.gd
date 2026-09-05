# Godot EventSheets - the Vector Shapes pack: the shader compiles, the arithmetic is right, and the
# eight shipped scripts round-trip.
#
# THE SHADER PIN IS A COMPILE PROOF. A shader that fails to compile reports NO uniforms at all, so a
# test that asked "does it have a `radius`?" would pass on a broken shader by asking the wrong thing.
# The pin here is the WHOLE sorted uniform list of each of the five blend variants: it can only be
# that list if the include parsed, the uniforms declared and the fragment compiled, and it says which
# uniform moved when somebody renames one.
#
# THE PICK AND SIZE PINS ARE VALUES on real nodes, built and freed here - a disc, a rect and a
# triangle answering whether a point is inside them, how long their outline is and how much area they
# cover. Nothing in this file needs a scene tree or a physics space, which the suite has neither of.
@tool
class_name VectorShapesPackTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const PREFIX := "vector_shapes_pack_test"

## Where the pack ships.
const PACK_DIR := "res://eventsheet_addons/vector_shapes/"

## The five blend variants, each four lines around one included body.
const SHADER_FILES: PackedStringArray = [
	"vector_shape_add.gdshader",
	"vector_shape_mix.gdshader",
	"vector_shape_mul.gdshader",
	"vector_shape_premul.gdshader",
	"vector_shape_sub.gdshader"
]

## Every uniform the drawing needs, sorted - the whole surface the eight scripts write to.
const SHADER_UNIFORMS := "aa_width,angle_from,angle_to,border_colour,border_on,border_px,box_half,caps,colour_a,colour_b,colour_c,colour_d,colour_mode,corner_radius,dash_count,dash_gap_px,dash_gap_share,dash_length_px,dash_offset,dash_snap,dash_style,dashed,filled,gradient_texture,inner_radius,path_closed,point_a,point_b,point_count,points,quad_origin,quad_size,radius,shape_kind,thickness_px"

## The eight scripts the pack ships: the base, and the seven shapes.
const PACK_SCRIPTS: PackedStringArray = [
	"vector_shape_2d.gd",
	"shape_disc_2d.gd",
	"shape_line_2d.gd",
	"shape_polygon_2d.gd",
	"shape_polyline_2d.gd",
	"shape_rect_2d.gd",
	"shape_regular_polygon_2d.gd",
	"shape_triangle_2d.gd"
]

## The marker that says a thickness is STORED in pixels however the Inspector's dropdown reads it.
## Every shape carries it, which is what keeps an emitted number still when the view is switched.
const UNIT_MARKER := "eventsheet:unit:kinds=px|world|screen,store=px"

## Which exported field of each shape earns a ROW, sorted.
##
## A shape is designed in the Inspector, so it carries thirty-odd exported fields; a picker that
## offered a row per field would answer "how do I dash this" with sixty entries nobody reads. So
## every field a VERB already says is marked `@ace_hidden` and reaches the sheet through Set
## Property and Tween Property like any other property, and what is left here is the short list of
## fields that are a sentence and that no verb says.
##
## The pin is the LIST rather than a count, because the failure it exists to catch is a dropped
## marker: one deleted `@ace_hidden` line puts a field back in the picker, and this names which.
const PUBLISHED_FIELDS := {
	"shape_disc_2d.gd": "colour_mode,inner_radius",
	"shape_line_2d.gd": "colour_mode,end_point",
	"shape_polygon_2d.gd": "colour_mode",
	"shape_polyline_2d.gd": "closed,colour_mode",
	"shape_rect_2d.gd": "colour_mode,size",
	"shape_regular_polygon_2d.gd": "angle,colour_mode",
	"shape_triangle_2d.gd": "colour_mode,corner_b,corner_c"
}


static func run() -> bool:
	var all_passed: bool = true
	all_passed = _pin_the_shaders() and all_passed
	all_passed = _pin_the_arithmetic() and all_passed
	all_passed = _pin_the_shapes() and all_passed
	all_passed = _pin_the_shipped_scripts() and all_passed
	all_passed = _pin_the_published_fields() and all_passed
	_cleanup()
	return all_passed


## The scripts the round trip above wrote. A compile writes to where it is told to compile, so each
## re-emission leaves a copy of a shape in the user folder - and on CI the whole suite runs serially
## in one process, so what one test leaves behind is state the next one sees.
static func _cleanup() -> void:
	for file_name: String in PACK_SCRIPTS:
		var written: String = "user://vector_shapes_%s" % file_name
		if FileAccess.file_exists(written):
			DirAccess.remove_absolute(written)


## The fields each shape publishes as a row, read back out of the shipped source the same way the
## vocabulary reads it: an `@export` whose doc block ends in `@ace_hidden` is an Inspector field
## and nothing else; every other `@export` is a row.
static func _pin_the_published_fields() -> bool:
	var rows: Array = []
	var file_names: Array = PUBLISHED_FIELDS.keys()
	file_names.sort()
	for file_name: String in file_names:
		rows.append(["%s publishes" % file_name, _published_fields_of(PACK_DIR + file_name),
			str(PUBLISHED_FIELDS[file_name])])
	return SUPPORT.pins(PREFIX, rows)


## The exported field names of one script that are NOT marked hidden, sorted and comma-joined.
static func _published_fields_of(path: String) -> String:
	var names: PackedStringArray = PackedStringArray()
	var hidden: bool = false
	for raw_line: String in FileAccess.get_file_as_string(path).split("\n"):
		var line: String = raw_line.strip_edges()
		if line == "## @ace_hidden":
			hidden = true
			continue
		if line.begins_with("@export_group(") or line.begins_with("@export_category("):
			hidden = false
			continue
		if line.begins_with("@export"):
			if not hidden:
				var declared: String = line.substr(line.find(" var ") + 5)
				var stop: int = declared.length()
				for terminator: String in [":", " ", "("]:
					var at: int = declared.find(terminator)
					if at >= 0 and at < stop:
						stop = at
				names.append(declared.substr(0, stop))
			hidden = false
			continue
		hidden = false
	names.sort()
	return ",".join(names)


## Every blend variant compiles, and they all offer the same uniforms - which is the point of an
## included body: five render modes, one drawing.
static func _pin_the_shaders() -> bool:
	var rows: Array = []
	for file_name: String in SHADER_FILES:
		var path: String = PACK_DIR + file_name
		var shader: Shader = load(path) as Shader
		rows.append(["%s loads" % file_name, shader != null, true])
		if shader == null:
			continue
		var names: PackedStringArray = PackedStringArray()
		for uniform: Dictionary in shader.get_shader_uniform_list():
			names.append(str(uniform.get("name", "")))
		names.sort()
		rows.append(["%s uniforms" % file_name, ",".join(names), SHADER_UNIFORMS])
	return SUPPORT.pins(PREFIX, rows)


## The three conversions a row and the Inspector share, by value. A screen unit is a whole viewport
## width, which is why the same number is a different stroke on two screens - and why the field
## stores pixels rather than the typed number.
static func _pin_the_arithmetic() -> bool:
	var base: GDScript = load(PACK_DIR + "vector_shape_2d.gd") as GDScript
	return SUPPORT.pins(PREFIX, [
		["pixels stay pixels", base.call("thickness_in_pixels", 2.0, "px", 640.0), 2.0],
		["world units are pixels", base.call("thickness_in_pixels", 2.0, "world", 640.0), 2.0],
		["half a screen unit on a 640 wide screen", base.call("thickness_in_pixels", 0.5, "screen", 640.0), 320.0],
		["half a screen unit on a 1280 wide screen", base.call("thickness_in_pixels", 0.5, "screen", 1280.0), 640.0],
		["a world dash length is pixels", base.call("dash_length_in_pixels", 8.0, "world", 4.0), 8.0],
		["a relative dash length is thicknesses", base.call("dash_length_in_pixels", 3.0, "relative", 4.0), 12.0],
		["a counted dash length is left alone", base.call("dash_length_in_pixels", 8.0, "count", 4.0), 8.0],
		["dashes in a hundred pixels at 8 and 2", base.call("dash_count_for", 100.0, 8.0, 2.0), 10],
		["dashes in a hundred pixels at 12 and 0", base.call("dash_count_for", 100.0, 12.0, 0.0), 8],
		["no dashes in no length", base.call("dash_count_for", 0.0, 8.0, 2.0), 0]
	])


## A disc, a rect and a triangle answering the three rows that measure them.
static func _pin_the_shapes() -> bool:
	var disc: Object = (load(PACK_DIR + "shape_disc_2d.gd") as GDScript).new()
	disc.set("radius", 50.0)
	disc.set("fill", true)
	var rect: Object = (load(PACK_DIR + "shape_rect_2d.gd") as GDScript).new()
	rect.set("size", Vector2(120.0, 80.0))
	rect.set("fill", true)
	var triangle: Object = (load(PACK_DIR + "shape_triangle_2d.gd") as GDScript).new()
	triangle.set("corner_b", Vector2(90.0, 0.0))
	triangle.set("corner_c", Vector2(0.0, 60.0))
	triangle.set("fill", true)
	var line: Object = (load(PACK_DIR + "shape_line_2d.gd") as GDScript).new()
	line.set("end_point", Vector2(60.0, 80.0))
	var passed: bool = SUPPORT.pins(PREFIX, [
		["the disc holds its middle", disc.call("point_is_inside_shape", Vector2(0.0, 0.0)), true],
		["the disc holds a point inside its radius", disc.call("point_is_inside_shape", Vector2(30.0, 20.0)), true],
		["the disc lets a point outside it go", disc.call("point_is_inside_shape", Vector2(60.0, 0.0)), false],
		["the rect holds a point inside it", rect.call("point_is_inside_shape", Vector2(50.0, 30.0)), true],
		["the rect lets a point past its corner go", rect.call("point_is_inside_shape", Vector2(61.0, 41.0)), false],
		["the triangle holds a point inside it", triangle.call("point_is_inside_shape", Vector2(20.0, 10.0)), true],
		["the triangle lets the far corner go", triangle.call("point_is_inside_shape", Vector2(80.0, 50.0)), false],
		["the rect's area", rect.call("shape_area"), 9600.0],
		["the triangle's area", triangle.call("shape_area"), 2700.0],
		["a line covers no area", line.call("shape_area"), 0.0],
		["the line's length", line.call("shape_length"), 100.0],
		["the rect's outline length", rect.call("shape_length"), 400.0],
		["a line is not closed", line.call("shape_is_closed"), false],
		["a rect is closed", rect.call("shape_is_closed"), true],
		["the shader arms the shapes take", "%d,%d,%d,%d" % [line.call("shape_kind_id"),
			disc.call("shape_kind_id"), rect.call("shape_kind_id"), triangle.call("shape_kind_id")], "0,1,2,5"]
	])
	disc.free()
	rect.free()
	triangle.free()
	line.free()
	return passed


## Every shipped script parses, opens as a sheet and re-emits itself byte for byte - the lossless
## covenant, held for all eight rather than for the one file the folder walk happens to reach first.
## Each shape also still says its thickness is stored in pixels.
static func _pin_the_shipped_scripts() -> bool:
	var rows: Array = []
	for file_name: String in PACK_SCRIPTS:
		var path: String = PACK_DIR + file_name
		var shipped: String = FileAccess.get_file_as_string(path)
		rows.append(["%s parses" % file_name, load(path) != null, true])
		var sheet: EventSheetResource = GDScriptImporter.new().import_external(path)
		var verify_path: String = "user://vector_shapes_%s" % file_name
		var reemitted: String = SUPPORT.compile_output(sheet, verify_path)
		rows.append(["%s re-emits itself" % file_name, reemitted == shipped, true])
		if file_name != "vector_shape_2d.gd":
			rows.append(["%s stores its thickness in pixels" % file_name, shipped.contains(UNIT_MARKER), true])
			rows.append(["%s asks for the preview card" % file_name, shipped.contains("# @inspector_preview"), true])
	return SUPPORT.pins(PREFIX, rows)
