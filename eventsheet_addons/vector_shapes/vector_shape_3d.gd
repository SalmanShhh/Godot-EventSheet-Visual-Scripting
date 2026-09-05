@tool
## @ace_tags(visual, shapes, drawing, shader, 3d)
## @ace_category("Vector Shapes")
## @ace_version(1.0.0)
@icon("res://eventsheet_addons/vector_shapes/icon.svg")
class_name VectorShape3D
extends MeshInstance3D
## The base every 3D Vector Shape node extends: one quad wearing the spatial half of the pack's distance-field shader when the shape is flat or a billboard, a real mesh when it is volumetric, and the rows that drive both. Add a Line 3D, Disc 3D, Rect 3D, Polygon 3D, Polyline 3D, Regular Polygon 3D, Sphere, Cuboid, Cone or Torus from the Create Node dialog rather than this.

## The 2D half of the pack, for the word lists both halves number the shader's arms with and for the
## dash-style pictures. Read by path rather than by class name so a project loads this script even
## while the editor's class cache is being rebuilt, and so there is exactly one copy of each list.
const SHAPE_WORDS := preload("res://eventsheet_addons/vector_shapes/vector_shape_2d.gd")

## Where the pack's own shaders live once it is installed.
const SHADER_DIRECTORY: String = "res://eventsheet_addons/vector_shapes/"

## The blend words a 3D shape offers, and the file each one is when the shape is sorted against the
## world the ordinary way. A blend is a `render_mode`, decided when a shader compiles and impossible
## to make a uniform, which is why "the same drawing, blended differently" is one file each.
const BLEND_SHADERS_3D: Dictionary = {
	"normal": "vector_shape_3d_mix.gdshader",
	"add": "vector_shape_3d_add.gdshader",
	"subtract": "vector_shape_3d_sub.gdshader",
	"multiply": "vector_shape_3d_mul.gdshader",
	"premultiplied": "vector_shape_3d_premul.gdshader"
}

## The same five, drawn over everything in front of them - the gizmo line that reads through a wall.
## A depth test is a `render_mode` too, so it doubles the files for the same reason the blends do.
const BLEND_SHADERS_3D_THROUGH: Dictionary = {
	"normal": "vector_shape_3d_mix_through.gdshader",
	"add": "vector_shape_3d_add_through.gdshader",
	"subtract": "vector_shape_3d_sub_through.gdshader",
	"multiply": "vector_shape_3d_mul_through.gdshader",
	"premultiplied": "vector_shape_3d_premul_through.gdshader"
}

## The three ways a 2D shape lives in 3D: on its own plane, always facing the camera, or as real
## geometry. The first two are the same quad and the same shader; the third is a mesh.
const GEOMETRIES: PackedStringArray = ["flat", "billboard", "volumetric"]

## The two ways a stroke's width is read: in the node's own units, or in pixels on the screen.
const THICKNESS_UNITS_3D: PackedStringArray = ["world", "screen"]

## The two depth readings, in the order the shader files are named for.
const DEPTH_MODES: PackedStringArray = ["test", "through walls"]

## How far a shape with a screen-unit stroke may reach past its own box before the engine may cull
## it. A screen-unit stroke is as wide as the camera says it is, so its box cannot be worked out on
## the CPU; this is the margin the engine's own cull-margin field exists for.
const SCREEN_CULL_MARGIN: float = 1.0

# One Shader resource per blend word and depth reading, shared by every 3D shape in the project.
# The material is per node (its uniforms are that shape's own numbers); the compiled shader is not.
static var _shaders_3d: Dictionary = {}

# The one quad every flat and billboard shape wears. Its own vertices are never used - the vertex
# stage places them from the shape's box - so one mesh serves the whole project.
static var _quad: QuadMesh = null

# How fast the dashes are scrolling, in patterns per second. Zero parks the tick entirely.
var _dash_scroll_speed: float = 0.0

# The material this shape wears, rebuilt when the blend or the depth word changes, never per frame.
var _material_3d: ShaderMaterial = null

# The blend and depth words the current shader material was built for.
var _material_key: String = ""

# The material a volumetric shape wears - real geometry, so a real surface rather than a distance
# field. Rebuilt when the blend word changes, never per frame.
var _solid_material: StandardMaterial3D = null

# The strip a gradient fill is sampled from, baked when the gradient changes rather than per frame.
var _gradient_strip: GradientTexture1D = null

# Whether a refresh is already waiting. A shape has thirty-odd fields and a scene load writes most
# of them in a burst; coalescing them means one mesh build and one uniform pass, not thirty.
var _refresh_queued: bool = false

# The mesh a volumetric shape last built, and the reading it was built for, so a field that does not
# change the geometry (a colour, a dash offset) never rebuilds it.
var _volume_key: String = ""

# True only while the scroll tick is writing dash_offset. It is what tells shape_changed that this
# write is one number moving rather than a shape that has changed, so a scrolling pattern costs one
# uniform a frame instead of an AABB, an outline array and forty uniforms.
var _scrolling_3d: bool = false

# The fade a Fade Shape Over row started, kept so a second one takes the colour over instead of
# fighting the first for it.
var _fade_3d: Tween = null

# Whether the editor has been handed the dash-style icon renderer yet, this session. The 2D twin
# carries the same flag: without it every shape entering the tree reloads the API script and walks
# its whole method list to register the provider that is already registered.
static var _icons_offered_3d: bool = false
## The rectangle the shape needs on its own plane, before its stroke is padded onto it.
## @ace_hidden
func shape_plane_bounds() -> Rect2:
	return Rect2(Vector2(-0.5, -0.5), Vector2(1.0, 1.0))
## The mesh a volumetric shape is, at a detail level. The default is a tube along the shape's own
## outline, which is what a line, a polyline, a polygon and a regular polygon all want; the shapes
## with an engine primitive of their own (a disc, a rect, the four wrappers) answer with that.
## @ace_hidden
func shape_volume_mesh(detail: int) -> Mesh:
	return tube_mesh(shape_points_3d(), shape_is_closed(), maxf(_number("thickness", 0.05) * 0.5, 0.001), detail)
## The surface a volumetric shape wears: its own colour, unshaded so the colour a designer picked is
## the colour on screen, and the blend word as the material's own blend mode. A shape made of real
## geometry has no outline to run a dash along, which is what the flat and billboard forms are for.
## @ace_hidden
func _volume_material() -> StandardMaterial3D:
	if _solid_material == null:
		_solid_material = StandardMaterial3D.new()
		_solid_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_solid_material.cull_mode = BaseMaterial3D.CULL_BACK
	var tint: Color = _colour("colour")
	_solid_material.albedo_color = tint
	_solid_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if tint.a < 1.0 else BaseMaterial3D.TRANSPARENCY_DISABLED
	_solid_material.blend_mode = solid_blend_mode(_word("blend", "normal"))
	_solid_material.no_depth_test = _word("depth", "test") != "test"
	return _solid_material
## The engine's own blend number for one of the pack's five blend words. Subtract has no spatial
## blend of its own, so it reads as the multiply that is nearest to it rather than silently as the
## ordinary one.
## @ace_hidden
static func solid_blend_mode(blend: String) -> BaseMaterial3D.BlendMode:
	match blend:
		"add":
			return BaseMaterial3D.BLEND_MODE_ADD
		"subtract":
			return BaseMaterial3D.BLEND_MODE_SUB
		"multiply", "premultiplied":
			return BaseMaterial3D.BLEND_MODE_MUL
	return BaseMaterial3D.BLEND_MODE_MIX
## The one quad every flat and billboard shape wears, made once per session.
## @ace_hidden
static func _shared_quad() -> QuadMesh:
	if _quad == null:
		_quad = QuadMesh.new()
		_quad.size = Vector2.ONE
	return _quad
## A tube along a path, at a radius, with so many sides - what a volumetric line, polyline, polygon
## or regular polygon is. Built once when the path changes; the rings are carried along the path with
## a fixed reference direction, which is exact for the planar outlines every shape here has.
## @ace_hidden
static func tube_mesh(path: PackedVector3Array, closed: bool, radius: float, sides: int) -> Mesh:
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count: int = path.size()
	if count < 2:
		return ArrayMesh.new()
	var ring_count: int = maxi(sides, 3)
	var rings: Array = []
	for index: int in count:
		var previous: Vector3 = path[(index - 1 + count) % count] if closed or index > 0 else path[index]
		var next: Vector3 = path[(index + 1) % count] if closed or index < count - 1 else path[index]
		var direction: Vector3 = (next - previous)
		if direction.length() < 0.00001:
			direction = Vector3.RIGHT
		direction = direction.normalized()
		var reference: Vector3 = Vector3.BACK if absf(direction.dot(Vector3.BACK)) < 0.9 else Vector3.UP
		var across: Vector3 = reference.cross(direction).normalized()
		var up: Vector3 = direction.cross(across).normalized()
		var ring: PackedVector3Array = PackedVector3Array()
		for step: int in ring_count:
			var angle: float = TAU * float(step) / float(ring_count)
			ring.append(path[index] + (across * cos(angle) + up * sin(angle)) * radius)
		rings.append(ring)
	var segments: int = count if closed else count - 1
	for index: int in segments:
		var here: PackedVector3Array = rings[index]
		var there: PackedVector3Array = rings[(index + 1) % count]
		for step: int in ring_count:
			var next_step: int = (step + 1) % ring_count
			surface.add_vertex(here[step])
			surface.add_vertex(there[step])
			surface.add_vertex(there[next_step])
			surface.add_vertex(here[step])
			surface.add_vertex(there[next_step])
			surface.add_vertex(here[next_step])
	if not closed:
		# The two flat ends, so an open tube is not a pipe you can see down.
		for pair: Array in [[rings[0], path[0], true], [rings[count - 1], path[count - 1], false]]:
			var ring: PackedVector3Array = pair[0]
			var middle: Vector3 = pair[1]
			for step: int in ring_count:
				var next_step: int = (step + 1) % ring_count
				surface.add_vertex(middle)
				surface.add_vertex(ring[next_step] if bool(pair[2]) else ring[step])
				surface.add_vertex(ring[step] if bool(pair[2]) else ring[next_step])
	surface.generate_normals()
	return surface.commit()
## The material a flat or billboard shape draws with, built once per blend-and-depth pairing. The
## Shader itself is shared by every 3D shape in the project; only the uniforms are this node's.
## @ace_hidden
func _shape_material_3d() -> ShaderMaterial:
	var blend: String = _word("blend", "normal")
	if not BLEND_SHADERS_3D.has(blend):
		blend = "normal"
	var through: bool = _word("depth", "test") != "test"
	var key: String = "%s|%s" % [blend, str(through)]
	if _material_3d != null and _material_key == key:
		return _material_3d
	var shader: Shader = shader_for_blend_3d(blend, through)
	if shader == null:
		return null
	_material_3d = ShaderMaterial.new()
	_material_3d.shader = shader
	_material_key = key
	material_override = _material_3d
	return _material_3d
## The shared Shader for one blend word and depth reading, loaded once per session. Null when the
## pack's shader files are not installed beside the script, which is a broken install rather than a
## state to draw in.
## @ace_hidden
static func shader_for_blend_3d(blend: String, through_walls: bool) -> Shader:
	var table: Dictionary = BLEND_SHADERS_3D_THROUGH if through_walls else BLEND_SHADERS_3D
	var file_name: String = str(table.get(blend, table["normal"]))
	if _shaders_3d.has(file_name):
		return _shaders_3d[file_name]
	var path: String = SHADER_DIRECTORY + file_name
	if not ResourceLoader.exists(path):
		return null
	var shader: Shader = load(path) as Shader
	_shaders_3d[file_name] = shader
	return shader
## The gradient a gradient fill samples, baked into a strip when the gradient changes and kept until
## it does - one texture per shape, never one per frame.
## @ace_hidden
func _gradient_texture() -> Texture2D:
	var value: Variant = get("gradient")
	if not (value is Gradient):
		return null
	if _gradient_strip != null and _gradient_strip.gradient == value:
		return _gradient_strip
	_gradient_strip = GradientTexture1D.new()
	_gradient_strip.gradient = value
	_gradient_strip.width = 256
	return _gradient_strip

## @ace_action
## @ace_featured
## @ace_name("Set Thickness")
## @ace_category("Vector Shapes")
## @ace_description("Sets how wide the shape's stroke is, and what the number means. In world units it is the node's own units, so a rope five centimetres thick is 0.05; in screen units it is pixels, and the shape keeps that weight however far away the camera gets - which is what a range ring or a gizmo line wants.")
## @ace_display_template("Set thickness to [b]{value}[/b] [b]{unit}[/b]")
## @ace_param_options(unit world, screen)
## @ace_icon("res://eventsheet_addons/vector_shapes/icon.svg")
## @ace_codegen_template("$VectorShape3D.set_thickness({value}, "{unit}")")
func set_thickness(value: float, unit: String) -> void:
	set("thickness", maxf(value, 0.0))
	if THICKNESS_UNITS_3D.has(unit):
		set("thickness_unit", unit)
	shape_changed()

## @ace_action
## @ace_featured
## @ace_name("Set Geometry")
## @ace_category("Vector Shapes")
## @ace_description("Sets which of the three forms the shape takes: flat on its own plane, always turned to face the camera, or real geometry a light and a depth buffer treat like anything else in the scene.")
## @ace_display_template("Set geometry to [b]{mode}[/b]")
## @ace_param_options(mode flat, billboard, volumetric)
## @ace_icon("res://eventsheet_addons/vector_shapes/icon.svg")
## @ace_codegen_template("$VectorShape3D.set_geometry("{mode}")")
func set_geometry(mode: String) -> void:
	if GEOMETRIES.has(mode):
		set("geometry", mode)
	shape_changed()

## @ace_action
## @ace_name("Set Shape Colour")
## @ace_category("Vector Shapes")
## @ace_description("Sets the shape's main colour - the whole of it in single mode, and the first end of the blend in every other mode.")
## @ace_display_template("Set shape colour to [b]{colour}[/b]")
## @ace_icon("res://eventsheet_addons/vector_shapes/icon.svg")
## @ace_codegen_template("$VectorShape3D.set_shape_colour({colour})")
func set_shape_colour(colour: Color) -> void:
	set("colour", colour)
	shape_changed()

## @ace_action
## @ace_name("Set Colours")
## @ace_category("Vector Shapes")
## @ace_description("Sets both ends of a two-colour shape at once, and switches a single-colour one to that mode: a rope that goes bright at the hand and dark at the anchor, an arc that goes danger to healthy along its sweep.")
## @ace_display_template("Set colours [b]{from_colour}[/b] to [b]{to_colour}[/b]")
## @ace_icon("res://eventsheet_addons/vector_shapes/icon.svg")
## @ace_codegen_template("$VectorShape3D.set_colours({from_colour}, {to_colour})")
func set_colours(from_colour: Color, to_colour: Color) -> void:
	set("colour", from_colour)
	set("colour_b", to_colour)
	if _word("colour_mode", "single") == "single":
		set("colour_mode", "two")
	shape_changed()

## @ace_action
## @ace_name("Set Gradient")
## @ace_category("Vector Shapes")
## @ace_description("Hands the shape a Gradient resource and switches it to the gradient mode - the whole ramp, shaped in Godot's own gradient editor and re-used by every shape that points at it.")
## @ace_icon("res://eventsheet_addons/vector_shapes/icon.svg")
## @ace_codegen_template("$VectorShape3D.set_gradient({gradient_resource})")
func set_gradient(gradient_resource: Gradient) -> void:
	set("gradient", gradient_resource)
	set("colour_mode", "gradient")
	shape_changed()

## @ace_action
## @ace_name("Set Fill")
## @ace_category("Vector Shapes")
## @ace_description("Fills the shape, or leaves it as an outline. A filled shape draws its border rather than its stroke, so the two can never sit a unit apart.")
## @ace_display_template("Set fill to [b]{filled}[/b]")
## @ace_icon("res://eventsheet_addons/vector_shapes/icon.svg")
## @ace_codegen_template("$VectorShape3D.set_fill({filled})")
func set_fill(filled: bool) -> void:
	set("fill", filled)
	shape_changed()

## @ace_action
## @ace_featured
## @ace_name("Set Dashes")
## @ace_category("Vector Shapes")
## @ace_description("Sets the dash pattern in one row: how many dashes fit the shape however long it is, how much of each period is gap, and which of the three ends the dashes wear.")
## @ace_display_template("Set dashes [b]{count}[/b], spacing [b]{spacing}[/b], [b]{style}[/b]")
## @ace_param_options(style plain, angled, rounded)
## @ace_icon("res://eventsheet_addons/vector_shapes/icon.svg")
## @ace_codegen_template("$VectorShape3D.set_dashes({count}, {spacing}, "{style}")")
func set_dashes(count: int, spacing: float, style: String) -> void:
	set("dashed", true)
	set("dash_space", "count")
	set("dash_count", maxi(count, 1))
	set("dash_spacing", clampf(spacing, 0.0, 0.95))
	if SHAPE_WORDS.DASH_STYLES.has(style):
		set("dash_style", style)
	shape_changed()

## @ace_action
## @ace_name("Set Dash Offset")
## @ace_category("Vector Shapes")
## @ace_description("Moves the dash pattern along the shape without changing it. Whole numbers land where they started, so an offset that has been scrolling for an hour is still in step.")
## @ace_icon("res://eventsheet_addons/vector_shapes/icon.svg")
## @ace_codegen_template("$VectorShape3D.set_dash_offset({offset})")
func set_dash_offset(offset: float) -> void:
	set("dash_offset", offset)
	shape_changed()

## @ace_action
## @ace_name("Scroll Dashes")
## @ace_category("Vector Shapes")
## @ace_description("Marches the dashes at so many patterns per second - the ants around a placement ring, the rope that says "pulling". A speed of 0 stops them and parks the tick with them, so a stopped shape costs nothing per frame.")
## @ace_display_template("Scroll dashes at [b]{patterns_per_second}[/b] per second")
## @ace_icon("res://eventsheet_addons/vector_shapes/icon.svg")
## @ace_codegen_template("$VectorShape3D.scroll_dashes({patterns_per_second})")
func scroll_dashes(patterns_per_second: float) -> void:
	_dash_scroll_speed = patterns_per_second
	set_process(not is_zero_approx(patterns_per_second))

## @ace_action
## @ace_name("Fade Shape Over")
## @ace_category("Vector Shapes")
## @ace_description("Fades the shape's colour to an alpha over a number of seconds - the one animation worth a verb, since every other field is an ordinary property a Tween Property row already drives.")
## @ace_icon("res://eventsheet_addons/vector_shapes/icon.svg")
## @ace_codegen_template("$VectorShape3D.fade_shape_over({to_alpha}, {seconds})")
func fade_shape_over(to_alpha: float, seconds: float) -> void:
	if _fade_3d != null and _fade_3d.is_valid():
		_fade_3d.kill()
	_fade_3d = null
	var tint: Color = _colour("colour")
	var target: Color = Color(tint.r, tint.g, tint.b, clampf(to_alpha, 0.0, 1.0))
	if seconds <= 0.0:
		set_shape_colour(target)
		return
	_fade_3d = create_tween()
	_fade_3d.tween_method(set_shape_colour, tint, target, seconds)

## @ace_action
## @ace_name("Set Shape Points")
## @ace_category("Vector Shapes")
## @ace_description("Replaces a Polygon 3D's or a Polyline 3D's points with a list of positions in the shape's own coordinates - a route worked out at run time, a hull, an outline read from data.")
## @ace_icon("res://eventsheet_addons/vector_shapes/icon.svg")
## @ace_codegen_template("$VectorShape3D.set_shape_points({new_points})")
func set_shape_points(new_points: Array) -> void:
	var outline: PackedVector3Array = PackedVector3Array()
	for entry: Variant in new_points:
		if entry is Vector3:
			outline.append(entry)
		elif entry is Vector2:
			outline.append(Vector3((entry as Vector2).x, (entry as Vector2).y, 0.0))
	set("points", outline)
	shape_changed()

## @ace_action
## @ace_name("Set Shape Radius")
## @ace_category("Vector Shapes")
## @ace_description("Sets the radius of a Disc 3D, a Regular Polygon 3D, a Sphere, a Cone or a Torus - the one number a ring, a hexagon and a ball are all sized by.")
## @ace_icon("res://eventsheet_addons/vector_shapes/icon.svg")
## @ace_codegen_template("$VectorShape3D.set_shape_radius({new_radius})")
func set_shape_radius(new_radius: float) -> void:
	set("radius", maxf(new_radius, 0.0))
	shape_changed()

## @ace_action
## @ace_name("Set Shape Sides")
## @ace_category("Vector Shapes")
## @ace_description("Sets how many sides a Regular Polygon 3D has: three is a triangle, six a hexagon, and a high number is a circle drawn the expensive way (a Disc 3D is the cheap one).")
## @ace_icon("res://eventsheet_addons/vector_shapes/icon.svg")
## @ace_codegen_template("$VectorShape3D.set_shape_sides({count})")
func set_shape_sides(count: int) -> void:
	set("sides", clampi(count, 3, SHAPE_WORDS.MAX_POINTS))
	shape_changed()

## @ace_action
## @ace_name("Set Arc")
## @ace_category("Vector Shapes")
## @ace_description("Sets a Disc 3D's sweep, in degrees: 0 to 360 is the whole disc, and anything less is the pie or the arc a cooldown, a scanning cone or a range wedge is drawn as.")
## @ace_display_template("Set arc from [b]{from_degrees}[/b] to [b]{to_degrees}[/b] degrees")
## @ace_icon("res://eventsheet_addons/vector_shapes/icon.svg")
## @ace_codegen_template("$VectorShape3D.set_arc({from_degrees}, {to_degrees})")
func set_arc(from_degrees: float, to_degrees: float) -> void:
	set("start_angle", from_degrees)
	set("end_angle", to_degrees)
	shape_changed()

## @ace_condition
## @ace_name("Shape Is Visible")
## @ace_category("Vector Shapes")
## @ace_description("True while the shape is drawn at all: visible in the tree, and not fully transparent.")
## @ace_display_template("the shape is visible")
## @ace_icon("res://eventsheet_addons/vector_shapes/icon.svg")
## @ace_codegen_template("$VectorShape3D.shape_is_visible()")
func shape_is_visible() -> bool:
	return is_visible_in_tree() and _colour("colour").a > 0.0

## @ace_condition
## @ace_name("Point Is Inside Shape")
## @ace_category("Vector Shapes")
## @ace_description("True when a point (in world coordinates) lands inside the shape, read on the shape's own plane - inside the outline for a filled one, within half a thickness of the line otherwise. The pick test for a shape you can click, with no collision body under it.")
## @ace_display_template("[b]{point}[/b] is inside the shape")
## @ace_icon("res://eventsheet_addons/vector_shapes/icon.svg")
## @ace_codegen_template("$VectorShape3D.point_is_inside_shape({point})")
func point_is_inside_shape(point: Vector3) -> bool:
	var local: Vector3 = to_local(point)
	var outline: PackedVector3Array = shape_points_3d()
	var reach: float = pick_reach()
	if outline.size() < 2:
		return shape_plane_bounds().grow(reach).has_point(Vector2(local.x, local.y))
	if shape_is_ribbon():
		return Geometry3D.get_closest_point_to_segment(local, outline[0], outline[outline.size() - 1]).distance_to(local) <= reach
	var flat: PackedVector2Array = PackedVector2Array()
	for entry: Vector3 in outline:
		flat.append(Vector2(entry.x, entry.y))
	var here: Vector2 = Vector2(local.x, local.y)
	if _flag("fill") and shape_is_closed():
		return SHAPE_WORDS.point_in_polygon(here, flat)
	var last: int = flat.size() - (1 if not shape_is_closed() else 0)
	for index: int in last:
		var next_point: Vector2 = flat[(index + 1) % flat.size()]
		if Geometry2D.get_closest_point_to_segment(here, flat[index], next_point).distance_to(here) <= reach:
			return true
	return false

## @ace_expression
## @ace_name("Shape Length")
## @ace_category("Vector Shapes")
## @ace_description("How long the shape's outline is, in the node's own units - the length a dash pattern is fitted into, and the number a "walk along it" row divides by.")
## @ace_icon("res://eventsheet_addons/vector_shapes/icon.svg")
## @ace_codegen_template("$VectorShape3D.shape_length()")
func shape_length() -> float:
	var outline: PackedVector3Array = shape_points_3d()
	if outline.size() < 2:
		return 0.0
	var total: float = 0.0
	for index: int in outline.size() - 1:
		total += outline[index].distance_to(outline[index + 1])
	if shape_is_closed():
		total += outline[outline.size() - 1].distance_to(outline[0])
	return total

## @ace_expression
## @ace_name("Shape Area")
## @ace_category("Vector Shapes")
## @ace_description("How much area the shape covers on its own plane, in square units. A shape that is only a line covers none.")
## @ace_icon("res://eventsheet_addons/vector_shapes/icon.svg")
## @ace_codegen_template("$VectorShape3D.shape_area()")
func shape_area() -> float:
	var outline: PackedVector3Array = shape_points_3d()
	if outline.size() < 3 or not shape_is_closed():
		return 0.0
	var doubled: float = 0.0
	var previous: int = outline.size() - 1
	for index: int in outline.size():
		doubled += outline[previous].x * outline[index].y - outline[index].x * outline[previous].y
		previous = index
	return absf(doubled) * 0.5

func _enter_tree() -> void:
	_offer_dash_icons_3d()
	set_process(false)
	shape_changed()

func _process(delta: float) -> void:
	if is_zero_approx(_dash_scroll_speed):
		set_process(false)
		return
	# Whole numbers tile, so a pattern that has scrolled for an hour is exactly where it started.
	#
	# A SCROLL MOVES ONE NUMBER. Writing the field the ordinary way calls the shape's own setter,
	# which queues the whole deferred refresh: the custom AABB recomputed, the outline padded into a
	# fresh array, forty uniforms pushed again and the gradient strip re-baked into a new texture -
	# every frame for as long as the dashes run. So the write is marked as a scroll, the setter's
	# refresh is skipped, and the one uniform that actually moved is handed over here. A material
	# that does not exist yet has never drawn, so that case takes the ordinary path and builds one.
	var moved: float = fposmod(_number("dash_offset", 0.0) + _dash_scroll_speed * delta, 1024.0)
	_scrolling_3d = _material_3d != null
	set("dash_offset", moved)
	if _scrolling_3d:
		_material_3d.set_shader_parameter("dash_offset", moved)
		_scrolling_3d = false

## The shape's own kind number, as the shader numbers them - the same numbers the 2D twins use,
## because it is the same drawing. Every shape script answers with its own.
## @ace_hidden
func shape_kind_id() -> int:
	return 0

## The outline this shape is made of, in its own coordinates. Points are Vector3 rather than Vector2
## so the viewport's own handles can drag them; every shape but the Line reads their X and Y and
## leaves the Z to say which plane it was dragged on.
## @ace_hidden
func shape_points_3d() -> PackedVector3Array:
	return PackedVector3Array()

## Whether that outline comes back to its start.
## @ace_hidden
func shape_is_closed() -> bool:
	return false

## Whether this shape is a strip between two points in space rather than a drawing on a plane. Only
## the Line is: a rope between a hand and a grapple point has no plane of its own.
## @ace_hidden
func shape_is_ribbon() -> bool:
	return false

## Whether this node is one of the solid wrappers - a sphere, a cuboid, a cone or a torus. They are
## geometry and nothing else, so they never reach the distance-field shader at all.
## @ace_hidden
func shape_is_solid() -> bool:
	return false

## Which of the three geometry modes this node is in. A solid wrapper has no such field and is always
## the third; every other shape reads its own.
## @ace_hidden
func shape_geometry() -> String:
	if shape_is_solid():
		return "volumetric"
	var mode: String = _word("geometry", "flat")
	return mode if GEOMETRIES.has(mode) else "flat"

## Redraws after a field a shape script wrote - the one line every setter in the shape scripts calls,
## so a change made in the Inspector and a change made by a row look the same. The work itself is
## deferred, which is what turns a scene load's burst of writes into one rebuild. The one write it
## does NOT refresh for is a dash scroll, which moves a single uniform and hands the shader that
## uniform itself rather than paying for the whole shape once a frame.
## @ace_hidden
func shape_changed() -> void:
	if _scrolling_3d:
		return
	_gradient_strip = null
	if _refresh_queued:
		return
	_refresh_queued = true
	_refresh_shape.call_deferred()

## Rebuilds whatever actually changed: the mesh when the geometry did, the material when the blend
## or the depth word did, and the uniforms always. Never called per frame.
## @ace_hidden
func _refresh_shape() -> void:
	_refresh_queued = false
	if shape_geometry() == "volumetric":
		_build_volume()
		return
	_volume_key = ""
	if mesh != _shared_quad():
		mesh = _shared_quad()
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# A screen-unit stroke is only as wide as the camera says it is, so the box this shape claims
	# cannot be worked out here. The engine's own cull margin is what covers the difference.
	extra_cull_margin = SCREEN_CULL_MARGIN if _word("thickness_unit", "world") == "screen" else 0.0
	var box: Rect2 = shape_plane_bounds()
	var pad: float = maxf(_number("thickness", 0.05), _number("border_thickness", 0.0)) + 0.02
	var outline: PackedVector3Array = shape_points_3d()
	if shape_is_ribbon() and outline.size() > 1:
		custom_aabb = AABB(outline[0], Vector3.ZERO).expand(outline[outline.size() - 1]).grow(pad)
	else:
		var grown: Rect2 = box.grow(pad)
		# A billboard turns about its own centre, so the box it claims has to hold it turned.
		var depth: float = maxf(grown.size.x, grown.size.y) if shape_geometry() == "billboard" else pad
		custom_aabb = AABB(Vector3(grown.position.x, grown.position.y, -depth * 0.5),
			Vector3(grown.size.x, grown.size.y, depth))
	_push_uniforms_3d()

## The mesh a volumetric shape wears, built when the geometry it is made of changes and kept until
## it does. A colour, a dash offset or a blend word never reaches this.
## @ace_hidden
func _build_volume() -> void:
	extra_cull_margin = 0.0
	custom_aabb = AABB()
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var detail: int = clampi(int(_number("detail", 16.0)), 3, 64)
	var key: String = "%s|%d|%.4f|%s" % [str(shape_points_3d()), detail, _number("thickness", 0.05), _volume_reading()]
	if key != _volume_key or mesh == null:
		_volume_key = key
		mesh = shape_volume_mesh(detail)
	material_override = _volume_material()

## Everything about a volumetric shape's own numbers that changes the MESH, as one string - the
## shapes with an engine primitive answer with their radius and size, and the tube shapes have said
## all of it already through their outline.
## @ace_hidden
func _volume_reading() -> String:
	return "%.4f|%.4f|%.4f|%s" % [_number("radius", 0.0), _number("inner_radius", 0.0),
		_number("height", 0.0), str(get("size"))]

## One exported number of whichever shape script this is, or the fallback when that shape has no
## such field. The base declares no fields of its own on purpose (a subclass cannot re-export an
## inherited one), so it reads them by name.
## @ace_hidden
func _number(key: String, fallback: float) -> float:
	var value: Variant = get(key)
	if value is float or value is int:
		return float(value)
	return fallback

## One exported word, or the fallback.
## @ace_hidden
func _word(key: String, fallback: String) -> String:
	var value: Variant = get(key)
	if value is String or value is StringName:
		return str(value)
	return fallback

## One exported tick box, or false.
## @ace_hidden
func _flag(key: String) -> bool:
	var value: Variant = get(key)
	return value is bool and value

## One exported colour, or white.
## @ace_hidden
func _colour(key: String) -> Color:
	var value: Variant = get(key)
	if value is Color:
		return value
	return Color.WHITE

## Hands every field the shader needs over in one pass, when something changed - never per frame,
## because a shape nothing writes to is never refreshed.
## @ace_hidden
func _push_uniforms_3d() -> void:
	var shape_material: ShaderMaterial = _shape_material_3d()
	if shape_material == null:
		return
	# A shape that has just come back from volumetric is still wearing the solid surface.
	if material_override != shape_material:
		material_override = shape_material
	var screen_units: bool = _word("thickness_unit", "world") == "screen"
	var quad: Rect2 = shape_plane_bounds()
	var outline: PackedVector3Array = shape_points_3d()
	shape_material.set_shader_parameter("shape_kind", shape_kind_id())
	shape_material.set_shader_parameter("quad_origin", quad.position)
	shape_material.set_shader_parameter("quad_size", quad.size)
	shape_material.set_shader_parameter("thickness_px", maxf(_number("thickness", 0.05), 0.0))
	shape_material.set_shader_parameter("screen_thickness", screen_units)
	shape_material.set_shader_parameter("billboard", shape_geometry() == "billboard")
	shape_material.set_shader_parameter("ribbon", shape_is_ribbon())
	shape_material.set_shader_parameter("ribbon_a", outline[0] if outline.size() > 0 else Vector3.ZERO)
	shape_material.set_shader_parameter("ribbon_b", outline[outline.size() - 1] if outline.size() > 1 else Vector3.RIGHT)
	shape_material.set_shader_parameter("aa_width", maxf(_number("antialias_width", 1.0), 0.0001))
	shape_material.set_shader_parameter("filled", _flag("fill"))
	shape_material.set_shader_parameter("caps", maxi(SHAPE_WORDS.CAP_STYLES.find(_word("caps", "round")), 0))
	shape_material.set_shader_parameter("colour_a", _colour("colour"))
	shape_material.set_shader_parameter("colour_b", _colour("colour_b"))
	shape_material.set_shader_parameter("colour_c", _colour("colour_c"))
	shape_material.set_shader_parameter("colour_d", _colour("colour_d"))
	shape_material.set_shader_parameter("colour_mode", maxi(SHAPE_WORDS.COLOUR_MODES.find(_word("colour_mode", "single")), 0))
	shape_material.set_shader_parameter("gradient_texture", _gradient_texture())
	shape_material.set_shader_parameter("border_on", _flag("border"))
	shape_material.set_shader_parameter("border_colour", _colour("border_colour"))
	shape_material.set_shader_parameter("border_px", _number("border_thickness", 0.02))
	shape_material.set_shader_parameter("dashed", _flag("dashed"))
	shape_material.set_shader_parameter("dash_snap", maxi(SHAPE_WORDS.DASH_SNAPS.find(_word("dash_snap", "tiling")), 0))
	shape_material.set_shader_parameter("dash_style", maxi(SHAPE_WORDS.DASH_STYLES.find(_word("dash_style", "plain")), 0))
	shape_material.set_shader_parameter("dash_offset", _number("dash_offset", 0.0))
	var space: String = _word("dash_space", "count")
	var thickness: float = maxf(_number("thickness", 0.05), 0.0)
	shape_material.set_shader_parameter("dash_count", int(_number("dash_count", 12.0)) if space == "count" else 0)
	shape_material.set_shader_parameter("dash_gap_share", clampf(_number("dash_spacing", 0.5), 0.0, 0.95))
	shape_material.set_shader_parameter("dash_length_px",
		SHAPE_WORDS.dash_length_in_pixels(_number("dash_size", 0.2), space, thickness))
	shape_material.set_shader_parameter("dash_gap_px",
		SHAPE_WORDS.dash_length_in_pixels(_number("dash_spacing", 0.1), space, thickness))
	var span: float = 1.0
	if shape_is_ribbon() and outline.size() > 1:
		span = maxf(outline[0].distance_to(outline[outline.size() - 1]), 0.0001)
	shape_material.set_shader_parameter("point_a", Vector2.ZERO)
	shape_material.set_shader_parameter("point_b", Vector2(span, 0.0))
	shape_material.set_shader_parameter("radius", _number("radius", 0.5))
	shape_material.set_shader_parameter("inner_radius", _number("inner_radius", 0.0))
	shape_material.set_shader_parameter("angle_from", deg_to_rad(_number("start_angle", 0.0)))
	shape_material.set_shader_parameter("angle_to", deg_to_rad(maxf(_number("end_angle", 360.0), _number("start_angle", 0.0))))
	var size: Variant = get("size")
	shape_material.set_shader_parameter("box_half", (size if size is Vector2 else Vector2.ONE) * 0.5)
	var corners: Variant = get("corner_radius")
	shape_material.set_shader_parameter("corner_radius", corners if corners is Vector4 else Vector4.ZERO)
	shape_material.set_shader_parameter("path_closed", shape_is_closed())
	var flat: PackedVector2Array = PackedVector2Array()
	for index: int in mini(outline.size(), SHAPE_WORDS.MAX_POINTS):
		flat.append(Vector2(outline[index].x, outline[index].y))
	var written: int = flat.size()
	while flat.size() < SHAPE_WORDS.MAX_POINTS:
		flat.append(Vector2.ZERO)
	shape_material.set_shader_parameter("points", flat)
	shape_material.set_shader_parameter("point_count", 0 if shape_is_ribbon() else written)

## Half the width the stroke has where it is drawn, which is how close a click has to land. In the
## node's own units that is half the thickness; in screen units the stroke is pixels, so the reading
## takes the live camera's distance - a hairline that looks four pixels wide is four pixels wide to
## click, however far away it is.
## @ace_hidden
func pick_reach() -> float:
	var width: float = maxf(_number("thickness", 0.05), 0.001)
	if _word("thickness_unit", "world") != "screen" or not is_inside_tree():
		return width * 0.5
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return width * 0.5
	var rows: float = get_viewport().get_visible_rect().size.y
	var away: float = camera.global_position.distance_to(global_position)
	return screen_thickness_in_units(width, away, rows, camera.fov) * 0.5

## What a stroke typed in PIXELS measures in the world, at a distance from a camera. A pixel is not
## a length in 3D until something says how far away the shape is: at twice the distance the same
## stroke covers twice as much world, which is exactly what keeps it the same width on the screen.
## The shader reads that from how much of the shape one pixel covers where it lands; this is the same
## reading for the CPU, which is what the pick test below has to use so that clicking a screen-unit
## line is as forgiving as the line looks.
## @ace_hidden
static func screen_thickness_in_units(pixels: float, distance: float, viewport_height: float, fov_degrees: float) -> float:
	var rows: float = maxf(viewport_height, 1.0)
	var half_fov: float = deg_to_rad(clampf(fov_degrees, 0.1, 179.0) * 0.5)
	return maxf(pixels, 0.0) * 2.0 * maxf(distance, 0.0) * tan(half_fov) / rows

## Hands the editor the dash-style pictures the 2D half draws, once per session and only while the
## editor is running - so a project holding only 3D shapes still gets the three dash buttons. The
## plugin is reached by PATH rather than by class name, so a project without it still loads this
## pack, and a shipped game never runs this at all.
## @ace_hidden
func _offer_dash_icons_3d() -> void:
	if _icons_offered_3d or not Engine.is_editor_hint():
		return
	_icons_offered_3d = true
	var api_path: String = "res://addons/eventsheet/api/eventsheets.gd"
	if not ResourceLoader.exists(api_path):
		return
	var api: GDScript = load(api_path) as GDScript
	if api == null:
		return
	for method: Dictionary in api.get_script_method_list():
		if str(method.get("name", "")) == "register_toggle_icon_provider":
			api.call("register_toggle_icon_provider", "vector_shapes_dash", SHAPE_WORDS.dash_style_icon)
			return

# Vector Shapes in 3D: ten nodes that draw the same shapes their 2D twins do, on a spatial shader that reads the same drawing. Each one is flat on its own plane, turned to face the camera, or real geometry - the Geometry buttons at the top of the Inspector. A thickness is in the node's own units or in screen pixels; the dashes, the caps and the colour modes are the ones the 2D half has, because they are the same file. The rows below work on whichever 3D shape you pick. This pack is an event sheet - extend it by editing it.
