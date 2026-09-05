# Godot EventSheets - the Vector Shapes pack's 3D half: the spatial shaders compile, the two halves
# read ONE drawing, a screen-unit stroke measures what it should, and the eleven shipped scripts
# round-trip.
#
# THE SHADER PIN IS A COMPILE PROOF. A shader that fails to compile reports NO uniforms at all, so a
# test that asked "does it have a `ribbon`?" would pass on a broken shader by asking the wrong
# thing. The pin here is the WHOLE sorted uniform list of each of the ten spatial variants: it can
# only be that list if both includes parsed, the uniforms declared and the vertex and fragment
# stages compiled, and it says which uniform moved when somebody renames one.
#
# THE NEVER-DRIFT PIN IS DERIVED, not written twice. The 3D list with its five spatial-only uniforms
# taken out has to BE the canvas list, and both shader families have to name the one include file -
# which is what says the dashes, the caps and the colour modes still have a single copy.
#
# Nothing here needs a scene tree or a physics space, which the suite has neither of: the shapes are
# built, asked and freed, and the shader work is resource-level.
@tool
class_name VectorShapes3dTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const PREFIX := "vector_shapes_3d_test"

## Where the pack ships. One folder: the canvas half and the spatial half are one pack.
const PACK_DIR := "res://eventsheet_addons/vector_shapes/"

## The one file both halves read the drawing from.
const SHARED_INCLUDE := "vector_shapes.gdshaderinc"

## The spatial half's own include, which names the file above.
const SPATIAL_INCLUDE := "vector_shapes_3d.gdshaderinc"

## The ten spatial variants: five blends, each with and without the depth test. A blend and a depth
## test are both `render_mode`, decided when a shader compiles, so neither can be a uniform.
const SHADER_FILES_3D: PackedStringArray = [
	"vector_shape_3d_add.gdshader",
	"vector_shape_3d_add_through.gdshader",
	"vector_shape_3d_mix.gdshader",
	"vector_shape_3d_mix_through.gdshader",
	"vector_shape_3d_mul.gdshader",
	"vector_shape_3d_mul_through.gdshader",
	"vector_shape_3d_premul.gdshader",
	"vector_shape_3d_premul_through.gdshader",
	"vector_shape_3d_sub.gdshader",
	"vector_shape_3d_sub_through.gdshader"
]

## One of the canvas variants, read beside a spatial one so the shared surface can be compared.
const SHADER_FILE_2D := "vector_shape_mix.gdshader"

## Every uniform a spatial shape needs, sorted - the shared drawing's surface plus the five a shape
## only needs once it is in a world with a camera in it.
const SHADER_UNIFORMS_3D := "aa_width,angle_from,angle_to,billboard,border_colour,border_on,border_px,box_half,caps,colour_a,colour_b,colour_c,colour_d,colour_mode,corner_radius,dash_count,dash_gap_px,dash_gap_share,dash_length_px,dash_offset,dash_snap,dash_style,dashed,filled,gradient_texture,inner_radius,path_closed,point_a,point_b,point_count,points,quad_origin,quad_size,radius,ribbon,ribbon_a,ribbon_b,screen_thickness,shape_kind,thickness_px"

## The five the spatial half adds, sorted: whether the shape turns to face the camera, whether it is
## a strip between two points and where those two points are, and whether its stroke is pixels.
const SPATIAL_ONLY_UNIFORMS: PackedStringArray = [
	"billboard", "ribbon", "ribbon_a", "ribbon_b", "screen_thickness"
]

## The eleven scripts the 3D half ships: the base, the six twins and the four solid wrappers.
const PACK_SCRIPTS_3D: PackedStringArray = [
	"vector_shape_3d.gd",
	"shape_cone_3d.gd",
	"shape_cuboid_3d.gd",
	"shape_disc_3d.gd",
	"shape_line_3d.gd",
	"shape_polygon_3d.gd",
	"shape_polyline_3d.gd",
	"shape_rect_3d.gd",
	"shape_regular_polygon_3d.gd",
	"shape_sphere_3d.gd",
	"shape_torus_3d.gd"
]

## Which exported field of each 3D shape earns a ROW, sorted. The pin is the LIST rather than a
## count, because the failure it exists to catch is a dropped `@ace_hidden` marker: one deleted line
## puts a designed-in-the-Inspector field back in the picker, and this names which script it was.
const PUBLISHED_FIELDS_3D := {
	"shape_cone_3d.gd": "capped,height",
	"shape_cuboid_3d.gd": "size",
	"shape_disc_3d.gd": "colour_mode,inner_radius",
	"shape_line_3d.gd": "colour_mode,end_point,start_point",
	"shape_polygon_3d.gd": "colour_mode",
	"shape_polyline_3d.gd": "closed,colour_mode",
	"shape_rect_3d.gd": "colour_mode,size",
	"shape_regular_polygon_3d.gd": "angle,colour_mode",
	"shape_sphere_3d.gd": "",
	"shape_torus_3d.gd": "inner_radius"
}


static func run() -> bool:
	var all_passed: bool = true
	all_passed = _pin_the_spatial_shaders() and all_passed
	all_passed = _pin_the_one_drawing() and all_passed
	all_passed = _pin_the_screen_unit() and all_passed
	all_passed = _pin_the_shapes() and all_passed
	all_passed = _pin_the_scroll_tick_3d() and all_passed
	all_passed = _pin_the_rows() and all_passed
	all_passed = _pin_the_shipped_scripts() and all_passed
	all_passed = _pin_the_published_fields() and all_passed
	_cleanup()
	return all_passed


## The scripts the round trip above wrote. A compile writes to where it is told to compile, so each
## re-emission leaves a copy of a shape in the user folder - and on CI the whole suite runs serially
## in one process, so what one test leaves behind is state the next one sees.
static func _cleanup() -> void:
	for file_name: String in PACK_SCRIPTS_3D:
		var written: String = "user://vector_shapes_3d_%s" % file_name
		if FileAccess.file_exists(written):
			DirAccess.remove_absolute(written)


## Every spatial variant compiles, and they all offer the same uniforms - which is the point of an
## included body: ten render modes, one drawing.
static func _pin_the_spatial_shaders() -> bool:
	var rows: Array = []
	for file_name: String in SHADER_FILES_3D:
		var shader: Shader = load(PACK_DIR + file_name) as Shader
		rows.append(["%s loads" % file_name, shader != null, true])
		if shader == null:
			continue
		rows.append(["%s uniforms" % file_name, _uniforms_of(shader), SHADER_UNIFORMS_3D])
	return SUPPORT.pins(PREFIX, rows)


## The two halves read ONE file. Both shader families name the shared include, that include keeps
## the drawing in a function the spatial half can call, and the spatial uniform list with its own
## five taken out is exactly the canvas one - so a dash tuned in 2D and the same dash in 3D cannot
## be different arithmetic.
static func _pin_the_one_drawing() -> bool:
	var shared: String = FileAccess.get_file_as_string(PACK_DIR + SHARED_INCLUDE)
	var spatial: String = FileAccess.get_file_as_string(PACK_DIR + SPATIAL_INCLUDE)
	var canvas_shader: String = FileAccess.get_file_as_string(PACK_DIR + SHADER_FILE_2D)
	var flat: Shader = load(PACK_DIR + SHADER_FILE_2D) as Shader
	var spatial_shader: Shader = load(PACK_DIR + "vector_shape_3d_mix.gdshader") as Shader
	var shared_in_3d: PackedStringArray = PackedStringArray()
	if spatial_shader != null:
		for name: String in _uniforms_of(spatial_shader).split(","):
			if not SPATIAL_ONLY_UNIFORMS.has(name):
				shared_in_3d.append(name)
	return SUPPORT.pins(PREFIX, [
		["the canvas shader reads the shared include", canvas_shader.contains('#include "%s"' % SHARED_INCLUDE), true],
		["the spatial include reads the same file", spatial.contains(SHARED_INCLUDE), true],
		["the spatial include is what the spatial shaders read",
			FileAccess.get_file_as_string(PACK_DIR + "vector_shape_3d_mix.gdshader").contains(SPATIAL_INCLUDE), true],
		["the shared include holds the drawing as a function", shared.contains("vec4 vector_shape_at("), true],
		["the canvas fragment stands aside for a spatial one", shared.contains("#ifndef VECTOR_SHAPES_SPATIAL"), true],
		["the spatial half declares itself before including", spatial.contains("#define VECTOR_SHAPES_SPATIAL"), true],
		["the drawing's uniforms are the same in both halves", ",".join(shared_in_3d),
			_uniforms_of(flat) if flat != null else "the canvas shader did not compile"]
	])


## A screen-unit stroke by VALUE, at two distances. A pixel is not a length in a 3D world until a
## camera says how far away the shape is: twice as far is twice as wide in the world, which is
## exactly what keeps it the same width on the screen.
static func _pin_the_screen_unit() -> bool:
	var base: GDScript = load(PACK_DIR + "vector_shape_3d.gd") as GDScript
	return SUPPORT.pins(PREFIX, [
		["two pixels five metres away, 90 degrees over 1000 rows",
			"%.5f" % base.call("screen_thickness_in_units", 2.0, 5.0, 1000.0, 90.0), "0.02000"],
		["the same two pixels ten metres away",
			"%.5f" % base.call("screen_thickness_in_units", 2.0, 10.0, 1000.0, 90.0), "0.04000"],
		["twice the rows is half the world width",
			"%.5f" % base.call("screen_thickness_in_units", 2.0, 5.0, 2000.0, 90.0), "0.01000"],
		["nothing wide is nothing wide however far away",
			"%.5f" % base.call("screen_thickness_in_units", 0.0, 9.0, 1000.0, 90.0), "0.00000"],
		["the five blend words map onto the engine's own surface blends",
			"%d,%d,%d,%d,%d" % [base.call("solid_blend_mode", "normal"), base.call("solid_blend_mode", "add"),
				base.call("solid_blend_mode", "subtract"), base.call("solid_blend_mode", "multiply"),
				base.call("solid_blend_mode", "premultiplied")],
			"%d,%d,%d,%d,%d" % [BaseMaterial3D.BLEND_MODE_MIX, BaseMaterial3D.BLEND_MODE_ADD,
				BaseMaterial3D.BLEND_MODE_SUB, BaseMaterial3D.BLEND_MODE_MUL, BaseMaterial3D.BLEND_MODE_MUL]]
	])


## Real 3D shapes answering the rows that measure them, and wearing the material their own geometry
## mode asks for. The tube a volumetric path is made of is pinned by its vertex count, because a
## tube that quietly built nothing would otherwise look exactly like one that built well.
static func _pin_the_shapes() -> bool:
	var line: Object = (load(PACK_DIR + "shape_line_3d.gd") as GDScript).new()
	line.set("start_point", Vector3.ZERO)
	line.set("end_point", Vector3(3.0, 4.0, 0.0))
	var rect: Object = (load(PACK_DIR + "shape_rect_3d.gd") as GDScript).new()
	rect.set("size", Vector2(2.0, 1.0))
	rect.set("fill", true)
	var hexagon: Object = (load(PACK_DIR + "shape_regular_polygon_3d.gd") as GDScript).new()
	hexagon.set("sides", 6)
	hexagon.set("radius", 1.0)
	var sphere: Object = (load(PACK_DIR + "shape_sphere_3d.gd") as GDScript).new()
	var base: GDScript = load(PACK_DIR + "vector_shape_3d.gd") as GDScript
	var tube: Mesh = base.call("tube_mesh",
		PackedVector3Array([Vector3.ZERO, Vector3(1.0, 0.0, 0.0)]), false, 0.1, 8)
	line.call("_refresh_shape")
	sphere.call("_refresh_shape")
	var passed: bool = SUPPORT.pins(PREFIX, [
		["the line's length", line.call("shape_length"), 5.0],
		["a line covers no area", line.call("shape_area"), 0.0],
		["the line is a ribbon", line.call("shape_is_ribbon"), true],
		["the rect's outline length", rect.call("shape_length"), 6.0],
		["the rect's area", rect.call("shape_area"), 2.0],
		["the rect holds a point inside it", rect.call("point_is_inside_shape", Vector3(0.5, 0.2, 0.0)), true],
		["the rect lets a point past its corner go", rect.call("point_is_inside_shape", Vector3(1.4, 0.9, 0.0)), false],
		["a hexagon has six corners", hexagon.call("shape_points_3d").size(), 6],
		["a hexagon is closed", hexagon.call("shape_is_closed"), true],
		["a sphere is solid whatever its geometry field says", sphere.call("shape_geometry"), "volumetric"],
		["the shader arms the 3D twins take", "%d,%d,%d" % [line.call("shape_kind_id"),
			rect.call("shape_kind_id"), hexagon.call("shape_kind_id")], "0,2,6"],
		["a two-point tube at eight sides is sixteen triangles of wall and two fans of eight",
			tube.get_faces().size(), (16 + 16) * 3],
		["a flat shape wears the distance-field shader", line.get("material_override") is ShaderMaterial, true],
		["a solid wrapper wears a surface instead", sphere.get("material_override") is StandardMaterial3D, true],
		["the shape hands its own kind to the shader",
			(line.get("material_override") as ShaderMaterial).get_shader_parameter("ribbon"), true]
	])
	line.free()
	rect.free()
	hexagon.free()
	sphere.free()
	return passed


## Every row the 3D half ships is written against the 3D class, so the picker can turn that leading
## `$VectorShape3D.` into the node you actually picked. A pack whose script IS the node emits a bare
## member call by default, and a bare call has no node in it to retarget - the row would then write
## a call to the sheet's own script. The check reads the SHIPPED annotations rather than a re-opened
## sheet, because the annotation is what a project installing this pack actually gets.
static func _pin_the_rows() -> bool:
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(PACK_DIR + "vector_shape_3d.gd")
	var names: PackedStringArray = PackedStringArray()
	for entry: Resource in sheet.functions:
		if entry is EventFunction and (entry as EventFunction).expose_as_ace:
			names.append((entry as EventFunction).function_name)
	names.sort()
	var templates: int = 0
	var untargeted: PackedStringArray = PackedStringArray()
	for raw_line: String in FileAccess.get_file_as_string(PACK_DIR + "vector_shape_3d.gd").split("
"):
		var line: String = raw_line.strip_edges()
		if not line.begins_with("## @ace_codegen_template("):
			continue
		templates += 1
		if not line.begins_with('## @ace_codegen_template("$VectorShape3D.'):
			untargeted.append(line)
	return SUPPORT.pins(PREFIX, [
		["the rows the 3D half ships", ",".join(names),
			"fade_shape_over,point_is_inside_shape,scroll_dashes,set_arc,set_colours,set_dash_offset,set_dashes,set_fill,set_geometry,set_gradient,set_shape_colour,set_shape_points,set_shape_radius,set_shape_sides,set_thickness,shape_area,shape_is_visible,shape_length"],
		["every row carries an emitted call of its own", templates, names.size()],
		["every row targets the node you picked", ",".join(untargeted), ""],
		["the shape is the host every 3D row is written for", sheet.host_class, "MeshInstance3D"]
	])


## Every shipped script parses, opens as a sheet and re-emits itself byte for byte - the lossless
## covenant, held for all eleven rather than for the one file the folder walk happens to reach first.
## Each shape also still asks for the preview card, which is what puts a picture of it at the top of
## its own Inspector.
## A DASH SCROLL IS ONE NUMBER MOVING here too. The 3D setter queues the whole deferred refresh - a
## recomputed AABB, a rebuilt outline array, forty uniforms and a fresh gradient strip - so the scroll
## tick marks its write and hands the shader the one uniform instead. Pinned by the two things that
## are visible without a world: no refresh is queued, and the baked gradient survives.
static func _pin_the_scroll_tick_3d() -> bool:
	var shape: Object = (load(PACK_DIR + "shape_line_3d.gd") as GDScript).new()
	var strip: GradientTexture1D = GradientTexture1D.new()
	shape.set("_gradient_strip", strip)
	shape.set("_refresh_queued", false)
	shape.set("_scrolling_3d", true)
	shape.call("shape_changed")
	var passed: bool = SUPPORT.pins(PREFIX, [
		["a scroll tick queues no refresh", shape.get("_refresh_queued"), false],
		["and leaves the baked gradient where it is", shape.get("_gradient_strip") == strip, true],
	])
	shape.set("_scrolling_3d", false)
	shape.free()
	return passed


static func _pin_the_shipped_scripts() -> bool:
	var rows: Array = []
	for file_name: String in PACK_SCRIPTS_3D:
		var path: String = PACK_DIR + file_name
		var shipped: String = FileAccess.get_file_as_string(path)
		rows.append(["%s parses" % file_name, load(path) != null, true])
		var sheet: EventSheetResource = GDScriptImporter.new().import_external(path)
		var reemitted: String = SUPPORT.compile_output(sheet, "user://vector_shapes_3d_%s" % file_name)
		rows.append(["%s re-emits itself" % file_name, reemitted == shipped, true])
		if file_name != "vector_shape_3d.gd":
			rows.append(["%s asks for the preview card" % file_name, shipped.contains("# @inspector_preview"), true])
	return SUPPORT.pins(PREFIX, rows)


## The fields each 3D shape publishes as a row, read back out of the shipped source the same way the
## vocabulary reads it: an `@export` whose doc block ends in `@ace_hidden` is an Inspector field and
## nothing else; every other `@export` is a row.
static func _pin_the_published_fields() -> bool:
	var rows: Array = []
	var file_names: Array = PUBLISHED_FIELDS_3D.keys()
	file_names.sort()
	for file_name: String in file_names:
		rows.append(["%s publishes" % file_name, _published_fields_of(PACK_DIR + file_name),
			str(PUBLISHED_FIELDS_3D[file_name])])
	return SUPPORT.pins(PREFIX, rows)


## One shader's uniform names, sorted and comma-joined. Empty when the shader did not compile, which
## is exactly why the pin is the whole list rather than one name.
static func _uniforms_of(shader: Shader) -> String:
	var names: PackedStringArray = PackedStringArray()
	for uniform: Dictionary in shader.get_shader_uniform_list():
		names.append(str(uniform.get("name", "")))
	names.sort()
	return ",".join(names)


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
