# Pack source - vector_shapes, the shared base every shape node extends. The behaviour code this
# pack ships, as real GDScript: highlighted, checked and breakpointable here, and assembled into the
# pack by Lib.pack_from_source. Every #region, and the body of every top-level func, is one piece of
# the sheet; everything else is scaffolding the pack declares for itself at build time.
#
# The base holds the MACHINERY and the VERBS; the seven shape scripts hold the FIELDS. That split is
# not tidiness: the Inspector's decor comments (the link button, the handles, the preview card) are
# read from the script a node actually wears, so a field whose decor must fire has to be declared in
# that script rather than inherited from here. Declaring the verbs once, here, is what keeps one
# "Set Thickness" row in the picker instead of seven identical ones.
extends Node2D

#region base_runtime
## Where the pack's own shaders live once it is installed. One shader file per blend mode, all
## including one body: a blend is a `render_mode`, decided when a shader compiles, so it cannot be a
## uniform and "the same drawing, blended differently" is one file each.
const SHADER_DIRECTORY: String = "res://eventsheet_addons/vector_shapes/"

## The blend words a row and the Inspector offer, and the file each one is. These are the five
## blends a canvas shader can express by itself. The ones that read the screen back belong to the
## Blend Modes pack, which replaces an item's material - and a shape owns its material, so the guide
## says to put such a shape under a blended parent instead of fighting over the slot.
const BLEND_SHADERS: Dictionary = {
	"normal": "vector_shape_mix.gdshader",
	"add": "vector_shape_add.gdshader",
	"subtract": "vector_shape_sub.gdshader",
	"multiply": "vector_shape_mul.gdshader",
	"premultiplied": "vector_shape_premul.gdshader"
}

## The dash styles, in the order the shader numbers them - the position in this list IS the number
## written into the shader, so nothing keeps a second table in step with it.
const DASH_STYLES: PackedStringArray = ["plain", "angled", "rounded"]

## How a dash pattern meets the ends of the line it runs along, in the shader's own order.
const DASH_SNAPS: PackedStringArray = ["off", "tiling", "end to end"]

## How a dash length is measured, in the shader's own order: pixels, multiples of the thickness, or
## a fixed number of dashes however long the line is.
const DASH_SPACES: PackedStringArray = ["world", "relative", "count"]

## The end of a stroke, in the shader's own order.
const CAP_STYLES: PackedStringArray = ["none", "square", "round"]

## The colour modes, in the shader's own order.
const COLOUR_MODES: PackedStringArray = ["single", "two", "radial", "angular", "gradient", "per corner"]

## The most points the shader's uniform array holds. A longer outline is Godot's own Polygon2D's
## job, and the guide says so rather than letting the extra points vanish silently.
const MAX_POINTS: int = 32

## The unit words a thickness may be typed in. Pixels and world units are one to one in Godot's 2D;
## a screen unit is a whole viewport width.
const THICKNESS_UNITS: PackedStringArray = ["px", "world", "screen"]

# One Shader resource per blend word, shared by every shape in the project - the material is per
# node (its uniforms are that shape's own numbers), the compiled shader is not.
static var _shaders: Dictionary = {}

# The three dash-style buttons draw their own pictures, and each is made once per session.
static var _dash_icons: Dictionary = {}

# Whether the editor has been handed the dash-style icon renderer yet, this session.
static var _icons_offered: bool = false

# How fast the dashes are scrolling, in patterns per second. Zero parks the tick entirely.
var _dash_scroll_speed: float = 0.0

# The material this shape wears, rebuilt when the blend word changes and never per frame.
var _material: ShaderMaterial = null

# The blend word the current material was built for.
var _material_blend: String = ""

# The strip a gradient fill is sampled from, baked when the gradient changes rather than per draw.
var _gradient_strip: GradientTexture1D = null

func _enter_tree() -> void:
	_offer_dash_icons()
	set_process(false)

func _draw() -> void:
	var shape_material: ShaderMaterial = _shape_material()
	if shape_material == null:
		return
	var pad: float = maxf(_pixel_thickness(), _number("border_thickness", 0.0)) * 0.5 + maxf(_number("antialias_width", 1.0), 0.0) + 2.0
	var quad: Rect2 = shape_bounds().grow(pad)
	_push_uniforms(shape_material, quad)
	draw_rect(quad, Color.WHITE)

func _process(delta: float) -> void:
	if is_zero_approx(_dash_scroll_speed):
		set_process(false)
		return
	# Whole numbers tile, so a pattern that has scrolled for an hour is exactly where it started.
	set("dash_offset", fposmod(_number("dash_offset", 0.0) + _dash_scroll_speed * delta, 1024.0))
	queue_redraw()

## The shape's own kind number, as the shader numbers them. Every shape script answers with its own.
## @ace_hidden
func shape_kind_id() -> int:
	return 0

## The outline this shape is made of, in its own coordinates - the points the segment shapes walk,
## and the outline the length, area and pick tests measure. The analytic shapes answer with the
## outline they would have, so those three rows work on them too.
## @ace_hidden
func shape_points() -> PackedVector2Array:
	return PackedVector2Array()

## Whether that outline comes back to its start.
## @ace_hidden
func shape_is_closed() -> bool:
	return false

## The rectangle the shape needs before its stroke is padded onto it, in its own coordinates.
## @ace_hidden
func shape_bounds() -> Rect2:
	return Rect2(Vector2(-32.0, -32.0), Vector2(64.0, 64.0))

## Redraws after a field a shape script wrote - the one line every setter in the seven scripts
## calls, so a change made in the Inspector and a change made by a row look the same.
## @ace_hidden
func shape_changed() -> void:
	_gradient_strip = null
	queue_redraw()

## The shape's thickness in pixels, after the scale rule: a stroke set to keep its weight on screen
## divides by the node's own scale, so zooming a camera in does not fatten a HUD line.
## @ace_hidden
func _pixel_thickness() -> float:
	var value: float = _number("thickness", 2.0)
	if _word("thickness_scale", "with the node") == "fixed on screen":
		return value / maxf(absf(global_scale.x), 0.0001)
	return value

## One exported number of whichever shape script this is, or the fallback when that shape has no
## such field. The base declares no fields of its own on purpose (a subclass cannot re-export an
## inherited one), so it reads them by name.
## @ace_hidden
func _number(key: String, fallback: float) -> float:
	var value: Variant = _read(key)
	if value is float or value is int:
		return float(value)
	return fallback

## One exported word, or the fallback.
## @ace_hidden
func _word(key: String, fallback: String) -> String:
	var value: Variant = _read(key)
	if value is String or value is StringName:
		return str(value)
	return fallback

## One exported tick box, or false.
## @ace_hidden
func _flag(key: String) -> bool:
	var value: Variant = _read(key)
	return value is bool and value

## One exported colour, or white.
## @ace_hidden
func _colour(key: String) -> Color:
	var value: Variant = _read(key)
	if value is Color:
		return value
	return Color.WHITE

## What the shape draws one field with: the style's value when a style is in the slot and speaks
## for that field, and the shape's own otherwise.
##
## THE SHAPE'S OWN FIELD IS ASKED FIRST, and a field this shape has not got ends the question there.
## That is what lets one style carry a dash pattern and a Triangle wear it: the Triangle declares no
## `dashed`, so nothing reads it, and the style's dashes stay for the shapes that have them.
## @ace_hidden
func _read(key: String) -> Variant:
	var own: Variant = get(key)
	if own == null:
		return null
	var chosen: Variant = get("style")
	if chosen is ShapeStyle:
		var styled: Variant = (chosen as ShapeStyle).value_for(key)
		if styled != null:
			return styled
	return own

## Whether a style is speaking for one of this shape's fields right now - what the Inspector greys
## on, and what a reader of the shape asks before believing a number in the file.
## @ace_hidden
func style_speaks_for(property_name: String) -> bool:
	return get("style") is ShapeStyle and ShapeStyle.styled_keys().has(property_name)

## The one line a style file's own `changed` signal runs: the shape it is dropped into redraws, and
## its Inspector re-reads which fields are the style's.
## @ace_hidden
func style_changed_externally() -> void:
	notify_property_list_changed()
	shape_changed()

## This shape's current look as a style resource - every field a style speaks for, copied out. The
## shape is left exactly as it is; what is done with the answer is the caller's business.
## @ace_hidden
func style_from_fields() -> ShapeStyle:
	var made: ShapeStyle = ShapeStyle.new()
	for key: String in ShapeStyle.styled_keys():
		var value: Variant = get(key)
		if value != null:
			made.set(key, value)
	return made

## Writes this shape's look out as a new style file beside the scene it sits in, and wears it. The
## button in the Inspector header; nothing about the shape changes on screen, because the file holds
## exactly what the shape was already drawing with. Answers the path it wrote, or "" when it could
## not write one.
## @ace_hidden
func save_as_style() -> String:
	var made: ShapeStyle = style_from_fields()
	var folder: String = "res://"
	if not scene_file_path.is_empty():
		folder = scene_file_path.get_base_dir()
	elif owner != null and not owner.scene_file_path.is_empty():
		folder = owner.scene_file_path.get_base_dir()
	var stem: String = String(name).to_snake_case()
	var path: String = "%s/%s_style.tres" % [folder, stem]
	var attempt: int = 2
	while ResourceLoader.exists(path):
		path = "%s/%s_style_%d.tres" % [folder, stem, attempt]
		attempt += 1
	if ResourceSaver.save(made, path) != OK:
		push_warning("Save As Style could not write %s" % path)
		return ""
	made.take_over_path(path)
	set("style", made)
	return path

## The material this shape draws with, built once per blend word. The Shader itself is shared by
## every shape in the project; only the uniforms are this node's.
## @ace_hidden
func _shape_material() -> ShaderMaterial:
	var blend: String = _word("blend", "normal")
	if not BLEND_SHADERS.has(blend):
		blend = "normal"
	if _material != null and _material_blend == blend:
		return _material
	var shader: Shader = shader_for_blend(blend)
	if shader == null:
		return null
	_material = ShaderMaterial.new()
	_material.shader = shader
	_material_blend = blend
	material = _material
	return _material

## The shared Shader for one blend word, loaded once per session. Null when the pack's shader files
## are not installed beside the script, which is a broken install rather than a state to draw in.
## @ace_hidden
static func shader_for_blend(blend: String) -> Shader:
	if _shaders.has(blend):
		return _shaders[blend]
	var file_name: String = str(BLEND_SHADERS.get(blend, BLEND_SHADERS["normal"]))
	var path: String = SHADER_DIRECTORY + file_name
	if not ResourceLoader.exists(path):
		return null
	var shader: Shader = load(path) as Shader
	_shaders[blend] = shader
	return shader

## Hands every field the shader needs over in one pass, at redraw time - never per frame, because a
## shape nothing writes to never redraws.
## @ace_hidden
func _push_uniforms(target_material: ShaderMaterial, quad: Rect2) -> void:
	var thickness: float = _pixel_thickness()
	var space: String = _word("dash_space", "count")
	target_material.set_shader_parameter("shape_kind", shape_kind_id())
	target_material.set_shader_parameter("quad_origin", quad.position)
	target_material.set_shader_parameter("quad_size", quad.size)
	target_material.set_shader_parameter("thickness_px", thickness)
	target_material.set_shader_parameter("aa_width", maxf(_number("antialias_width", 1.0), 0.0001))
	target_material.set_shader_parameter("filled", _flag("fill"))
	target_material.set_shader_parameter("caps", maxi(CAP_STYLES.find(_word("caps", "round")), 0))
	target_material.set_shader_parameter("colour_a", _colour("colour"))
	target_material.set_shader_parameter("colour_b", _colour("colour_b"))
	target_material.set_shader_parameter("colour_c", _colour("colour_c"))
	target_material.set_shader_parameter("colour_d", _colour("colour_d"))
	target_material.set_shader_parameter("colour_mode", maxi(COLOUR_MODES.find(_word("colour_mode", "single")), 0))
	target_material.set_shader_parameter("gradient_texture", _gradient_texture())
	target_material.set_shader_parameter("border_on", _flag("border"))
	target_material.set_shader_parameter("border_colour", _colour("border_colour"))
	target_material.set_shader_parameter("border_px", _number("border_thickness", 2.0))
	target_material.set_shader_parameter("dashed", _flag("dashed"))
	target_material.set_shader_parameter("dash_snap", maxi(DASH_SNAPS.find(_word("dash_snap", "tiling")), 0))
	target_material.set_shader_parameter("dash_style", maxi(DASH_STYLES.find(_word("dash_style", "plain")), 0))
	target_material.set_shader_parameter("dash_offset", _number("dash_offset", 0.0))
	target_material.set_shader_parameter("dash_count", int(_number("dash_count", 16.0)) if space == "count" else 0)
	target_material.set_shader_parameter("dash_gap_share", clampf(_number("dash_spacing", 0.5), 0.0, 0.95))
	target_material.set_shader_parameter("dash_length_px", dash_length_in_pixels(_number("dash_size", 12.0), space, thickness))
	target_material.set_shader_parameter("dash_gap_px", dash_length_in_pixels(_number("dash_spacing", 6.0), space, thickness))
	var end_point: Variant = get("end_point")
	target_material.set_shader_parameter("point_a", Vector2.ZERO)
	target_material.set_shader_parameter("point_b", end_point if end_point is Vector2 else Vector2(64.0, 0.0))
	target_material.set_shader_parameter("radius", _number("radius", 32.0))
	target_material.set_shader_parameter("inner_radius", _number("inner_radius", 0.0))
	target_material.set_shader_parameter("angle_from", deg_to_rad(_number("start_angle", 0.0)))
	target_material.set_shader_parameter("angle_to", deg_to_rad(maxf(_number("end_angle", 360.0), _number("start_angle", 0.0))))
	var size: Variant = get("size")
	target_material.set_shader_parameter("box_half", (size if size is Vector2 else Vector2(64.0, 64.0)) * 0.5)
	var corners: Variant = get("corner_radius")
	target_material.set_shader_parameter("corner_radius", corners if corners is Vector4 else Vector4.ZERO)
	target_material.set_shader_parameter("path_closed", shape_is_closed())
	var outline: PackedVector2Array = shape_points()
	if outline.size() > MAX_POINTS:
		outline = outline.slice(0, MAX_POINTS)
	var padded: PackedVector2Array = outline.duplicate()
	while padded.size() < MAX_POINTS:
		padded.append(Vector2.ZERO)
	target_material.set_shader_parameter("points", padded)
	target_material.set_shader_parameter("point_count", outline.size())

## The gradient a gradient fill samples, baked into a strip when the gradient changes and kept until
## it does - one texture per shape, never one per draw.
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

## Turns a dash length a designer typed into the pixels the shader wants. A world length is pixels;
## a relative length is that many times the stroke's own thickness; in count mode the length is not
## read at all, because the count decides the period.
## @ace_hidden
static func dash_length_in_pixels(value: float, space: String, thickness: float) -> float:
	if space == "relative":
		return maxf(value, 0.0) * maxf(thickness, 0.01)
	return maxf(value, 0.0)

## Turns a thickness a designer typed in one of the three units into the pixels the field stores.
## Pixels and world units are one to one in Godot's 2D; a screen unit is the viewport's own width,
## so a line set in screen units keeps its weight on every phone. The field itself always stores
## pixels, which is why nothing in an emitted sheet moves when the Inspector's unit dropdown is
## flipped - that dropdown is a view of one stored number.
## @ace_hidden
static func thickness_in_pixels(value: float, unit: String, viewport_width: float) -> float:
	if unit == "screen":
		return value * maxf(viewport_width, 1.0)
	return value

## How many whole dashes a span holds, at a dash length and a gap - the same arithmetic the shader
## does, so a row can answer without reading a pixel back.
## @ace_hidden
static func dash_count_for(span: float, dash_length: float, gap: float) -> int:
	var period: float = maxf(dash_length, 0.01) + maxf(gap, 0.0)
	if span <= 0.0:
		return 0
	return int(floor(span / period + 0.0001))

## Whether a point (in the shape's own coordinates) is inside a closed outline - the ray-crossing
## test, which is what the shader's fill does per pixel.
## @ace_hidden
static func point_in_polygon(point: Vector2, outline: PackedVector2Array) -> bool:
	if outline.size() < 3:
		return false
	var inside: bool = false
	var previous: int = outline.size() - 1
	for index: int in outline.size():
		var a: Vector2 = outline[previous]
		var b: Vector2 = outline[index]
		if (b.y > point.y) != (a.y > point.y):
			var x_at: float = b.x + (point.y - b.y) / (a.y - b.y) * (a.x - b.x)
			if point.x < x_at:
				inside = not inside
		previous = index
	return inside

## The three dash-style buttons, drawn by the pack rather than shipped as pictures: the icon IS the
## dash it stands for, with the same duty and the same ends the shader gives it. It is drawn into an
## image rather than through the shader itself because the Inspector asks for the picture and uses
## it in the same breath, and a shader can only answer after a frame has been drawn.
## @ace_hidden
static func dash_style_icon(option: String, size: int) -> Texture2D:
	var key: String = "%s:%d" % [option, size]
	if _dash_icons.has(key):
		return _dash_icons[key]
	var side: int = maxi(size, 8)
	var image: Image = Image.create(side, side, false, Image.FORMAT_RGBA8)
	image.fill(Color(1.0, 1.0, 1.0, 0.0))
	var middle: float = float(side) * 0.5
	var half: float = maxf(float(side) * 0.16, 1.0)
	var period: float = maxf(float(side) * 0.42, 2.0)
	var half_dash: float = period * 0.31
	var flat: float = maxf(half_dash - half, 0.0)
	for x: int in side:
		for y: int in side:
			var across: float = absf(float(y) - middle)
			var lean: float = 0.0
			if option == "angled":
				lean = (float(y) - middle) * 0.5
			var phase: float = fposmod(float(x) + lean, period)
			var along: float = absf(phase - half_dash)
			var covered: bool = along <= half_dash and across <= half
			if option == "rounded":
				covered = Vector2(maxf(along - flat, 0.0), across).length() <= half
			if covered:
				image.set_pixel(x, y, Color(1.0, 1.0, 1.0, 1.0))
	var texture: ImageTexture = ImageTexture.create_from_image(image)
	_dash_icons[key] = texture
	return texture

## Hands the editor the dash-style pictures, once per session and only while the editor is running.
## The plugin is reached by PATH rather than by class name, so a project without it still loads this
## pack, and a shipped game never runs this at all.
## @ace_hidden
func _offer_dash_icons() -> void:
	if _icons_offered or not Engine.is_editor_hint():
		return
	_icons_offered = true
	var api_path: String = "res://addons/eventsheet/api/eventsheets.gd"
	if not ResourceLoader.exists(api_path):
		return
	var api: GDScript = load(api_path) as GDScript
	if api == null:
		return
	for method: Dictionary in api.get_script_method_list():
		if str(method.get("name", "")) == "register_toggle_icon_provider":
			api.call("register_toggle_icon_provider", "vector_shapes_dash", dash_style_icon)
			return
#endregion


## Sets the stroke's width. The unit is the one you typed the number in: pixels and world units are
## the same in 2D, and a screen unit is a whole viewport width, so a line set in screen units keeps
## its weight whatever phone it lands on. The field itself always stores pixels.
func set_thickness(value: float = 2.0, unit: String = "px") -> void:
	var width: float = 1152.0
	var viewport: Viewport = get_viewport()
	if viewport != null:
		width = viewport.get_visible_rect().size.x
	set("thickness", thickness_in_pixels(value, unit, width))
	shape_changed()

## Sets the shape's main colour - the one a single-colour shape is, and the first of the two a
## two-colour, radial or angular one blends between.
func set_shape_colour(colour: Color = Color.WHITE) -> void:
	set("colour", colour)
	shape_changed()

## Sets both ends of a two-colour shape at once and switches a single-colour one to that mode: a
## line that goes red to transparent, an arc that goes danger to healthy along its sweep.
func set_colours(from_colour: Color = Color.WHITE, to_colour: Color = Color.TRANSPARENT) -> void:
	set("colour", from_colour)
	set("colour_b", to_colour)
	if _word("colour_mode", "single") == "single":
		set("colour_mode", "two")
	shape_changed()

## Hands the shape a Gradient resource and switches it to the gradient mode - the whole ramp, shaped
## in Godot's own gradient editor.
func set_gradient(gradient_resource: Gradient) -> void:
	set("gradient", gradient_resource)
	set("colour_mode", "gradient")
	shape_changed()

## Fills the shape or leaves it as an outline. A filled shape draws its border rather than its
## stroke, so the two can never sit a pixel apart.
func set_fill(filled: bool = true) -> void:
	set("fill", filled)
	shape_changed()

## Sets the dash pattern in one row: how many dashes fit the shape, how much of each period is gap,
## and which of the three ends they wear.
func set_dashes(count: int = 12, spacing: float = 0.5, style: String = "plain") -> void:
	set("dashed", true)
	set("dash_space", "count")
	set("dash_count", maxi(count, 1))
	set("dash_spacing", clampf(spacing, 0.0, 0.95))
	if DASH_STYLES.has(style):
		set("dash_style", style)
	shape_changed()

## Moves the dash pattern along the shape without changing it - whole numbers land where they
## started, so an offset that has been scrolling for an hour is still in step.
func set_dash_offset(offset: float = 0.0) -> void:
	set("dash_offset", offset)
	shape_changed()

## Marches the dashes at so many patterns per second - the ants around a selection, the footprint
## that says "placing". A speed of 0 stops them and parks the tick with them, so a stopped shape
## costs nothing per frame.
func scroll_dashes(patterns_per_second: float = 1.0) -> void:
	_dash_scroll_speed = patterns_per_second
	set_process(not is_zero_approx(patterns_per_second))

## Fades the shape's colour to an alpha over a number of seconds - the one animation worth a verb,
## since every other field is an ordinary property a Tween row already drives.
func fade_shape_over(to_alpha: float = 0.0, seconds: float = 0.25) -> void:
	var tint: Color = _colour("colour")
	var target: Color = Color(tint.r, tint.g, tint.b, clampf(to_alpha, 0.0, 1.0))
	if seconds <= 0.0:
		set_shape_colour(target)
		return
	var tween: Tween = create_tween()
	tween.tween_method(set_shape_colour, tint, target, seconds)

## True while the shape is drawn at all: visible in the tree, and not fully transparent.
func shape_is_visible() -> bool:
	return is_visible_in_tree() and _colour("colour").a > 0.0

## True when a point (in world coordinates) lands inside the shape - inside the outline for a filled
## one, within half a thickness of the line otherwise. The pick test for a shape you can click,
## with no collision body under it.
func point_is_inside_shape(point: Vector2 = Vector2.ZERO) -> bool:
	var local: Vector2 = to_local(point)
	var outline: PackedVector2Array = shape_points()
	if outline.size() < 2:
		return shape_bounds().grow(maxf(_pixel_thickness(), 1.0) * 0.5).has_point(local)
	if _flag("fill") and shape_is_closed():
		return point_in_polygon(local, outline)
	var reach: float = maxf(_pixel_thickness(), 1.0) * 0.5
	var last: int = outline.size() - (1 if not shape_is_closed() else 0)
	for index: int in last:
		var next_point: Vector2 = outline[(index + 1) % outline.size()]
		if Geometry2D.get_closest_point_to_segment(local, outline[index], next_point).distance_to(local) <= reach:
			return true
	return false

## How long the shape's outline is, in pixels - the length a dash pattern is fitted into, and the
## number a "walk along it" row divides by.
func shape_length() -> float:
	var outline: PackedVector2Array = shape_points()
	if outline.size() < 2:
		return 0.0
	var total: float = 0.0
	for index: int in outline.size() - 1:
		total += outline[index].distance_to(outline[index + 1])
	if shape_is_closed():
		total += outline[outline.size() - 1].distance_to(outline[0])
	return total

## How much area the shape covers, in square pixels - zero for a shape that is only a line.
func shape_area() -> float:
	var outline: PackedVector2Array = shape_points()
	if outline.size() < 3 or not shape_is_closed():
		return 0.0
	var doubled: float = 0.0
	var previous: int = outline.size() - 1
	for index: int in outline.size():
		doubled += outline[previous].x * outline[index].y - outline[index].x * outline[previous].y
		previous = index
	return absf(doubled) * 0.5

## Replaces a Polygon's or a Polyline's points with a list of positions, in the shape's own
## coordinates - a drawn route, a hull worked out at run time, an outline read from data.
func set_shape_points(new_points: Array) -> void:
	var outline: PackedVector2Array = PackedVector2Array()
	for entry: Variant in new_points:
		if entry is Vector2:
			outline.append(entry)
	set("points", outline)
	shape_changed()

## Sets the radius of a Disc or a Regular Polygon - the one number a ring, a pie and a hexagon are
## all sized by.
func set_shape_radius(new_radius: float = 48.0) -> void:
	set("radius", maxf(new_radius, 0.0))
	shape_changed()

## Sets how many sides a Regular Polygon has: three is a triangle, six a hexagon.
func set_shape_sides(count: int = 6) -> void:
	set("sides", clampi(count, 3, MAX_POINTS))
	shape_changed()

## Sets a Disc's sweep, in degrees: 0 to 360 is the whole disc, and anything less is the pie or the
## arc a cooldown, a vision cone or a health ring is drawn as.
func set_arc(from_degrees: float = 0.0, to_degrees: float = 360.0) -> void:
	set("start_angle", from_degrees)
	set("end_angle", to_degrees)
	shape_changed()

## Puts a Shape Style file into this shape's Style slot - the look (thickness, caps, colours,
## dashes, blend) is read from the file from now on, and an empty slot hands the shape its own
## fields back.
func apply_shape_style(style_file: ShapeStyle) -> void:
	set("style", style_file)

## Puts a Shape Style file into every shape in a group at once - the whole HUD re-skinned from one
## file, which is what a style is for.
func apply_shape_style_to_group(group_name: String, style_file: ShapeStyle) -> void:
	if not is_inside_tree() or group_name.strip_edges().is_empty():
		return
	get_tree().call_group(StringName(group_name), "apply_shape_style", style_file)

## True while this shape is wearing that exact style file - the test a row makes before re-skinning,
## and the one an exception is written against.
func shape_style_is(style_file: ShapeStyle) -> bool:
	return get("style") == style_file
