# Pack builder - vector_shapes (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")

## The class every shape extends, and the name a row's emitted call is written against before the
## picker turns it into the node you picked.
const PACK_CLASS := "VectorShape2D"

## Where the pack lands.
const PACK_DIR := "res://eventsheet_addons/vector_shapes"

## The thickness units a Set Thickness row offers - the same three the Inspector's unit dropdown
## reads, so a number typed in a row and a number typed in the Inspector mean the same thing.
const UNITS := ["px", "world", "screen"]

## The three dash ends, in the order the shader numbers them.
const DASH_STYLES := ["plain", "angled", "rounded"]

## The class every 3D shape extends. The 3D half is authored in a source folder of its own and lands
## in the SAME pack folder: one pack, two families, one shader body read by both.
const PACK_CLASS_3D := "VectorShape3D"

## The two units a 3D Set Thickness row offers. There is no pixel unit here: a pixel is not a length
## in a 3D world until a camera says how far away the shape is, which is what "screen" means.
const UNITS_3D := ["world", "screen"]

## The three ways a 2D shape lives in 3D, in the order the base numbers them.
const GEOMETRIES := ["flat", "billboard", "volumetric"]


## Vector Shapes: seven 2D nodes that draw themselves with one quad and one distance-field canvas
## shader - a line, a disc (which is also a ring, a pie and an arc), a rect with rounded corners, a
## polygon, a polyline, a triangle and a regular polygon. A distance field is what makes them worth
## having: the outline is solved per pixel, so a ring is round at 4x zoom and a hairline is one crisp
## pixel, with no texture to author and nothing tessellated on the CPU.
##
## ONE SHADER, NOT SEVEN. The shape is a uniform the fragment branches on, rather than a shader per
## kind. The branch is uniform across a draw (every pixel of one quad takes the same arm), and the
## thing a phone or a browser actually pays for is shader COMPILES and pipeline switches - seven
## variants would be seven of each. The only reason there is more than one file at all is the blend
## mode: a blend is a `render_mode`, fixed when the shader compiles and impossible to make a uniform,
## so the five blends are five four-line files that include one body.
##
## WHY THE FIELDS ARE IN THE SEVEN SCRIPTS AND THE VERBS ARE IN THE BASE. The Inspector's decor
## comments - the equals button linking a dash count to its spacing, the viewport handles, the
## preview card - are read from the source of the script a node actually wears, so a field whose
## decor must fire has to be declared in that script rather than inherited. The verbs have no such
## rule, so they are declared once on the base: one "Set Thickness" row in the picker that works on
## any shape, instead of seven identical ones.
static func build() -> bool:
	if not _build_base():
		return false
	if not _build_style():
		return false
	for shape: Array in _shapes():
		if not _build_shape(shape):
			return false
	if not _build_base_3d():
		return false
	for shape: Array in _shapes_3d():
		if not _build_shape_3d(shape):
			return false
	for solid: Array in _solids_3d():
		if not _build_solid_3d(solid):
			return false
	# The shaders ARE the pack: without them a shape draws nothing at all. They ship in the same
	# build, from the same source folders, byte-stable like everything else here - the canvas half
	# and the spatial half into one folder, because they are one pack.
	# Both bases are spelled out rather than built from PACK_DIR: the shipment gate reads these calls
	# out of this file as text, so a path assembled at run time is a path no gate can follow.
	if not Lib.ship_files("vector_shapes", "res://eventsheet_addons/vector_shapes/vector_shapes",
			PackedStringArray(["gdshader", "gdshaderinc"])):
		return false
	return Lib.ship_files("vector_shapes_3d", "res://eventsheet_addons/vector_shapes/vector_shapes_3d",
		PackedStringArray(["gdshader", "gdshaderinc"]))


## The base class: the drawing machinery, the shared statics, and every row the pack ships.
static func _build_base() -> bool:
	var src: Lib.PackSource = Lib.pack_from_source("vector_shapes", "Node2D", PACK_CLASS,
		"The base every Vector Shape node extends: one quad, one distance-field canvas shader, and the rows that drive them - thickness with its unit, colours, fills, dashes and the pick tests. Add a Line, Disc, Rect, Polygon, Polyline, Triangle or Regular Polygon from the Create Node dialog rather than this.",
		Lib.manifest().category("Vector Shapes").tags(["visual", "shapes", "drawing", "shader", "2d"]))
	src.sheet.tool_mode = true  # so a shape draws itself in the editor viewport, not only in game
	src.note("Vector Shapes: seven 2D nodes drawn by one distance-field shader - crisp at any zoom, one draw each, no texture. Add one from the Create Node dialog (Line, Disc, Rect, Polygon, Polyline, Triangle, Regular Polygon), then tune it in the Inspector: a thickness with its unit, a colour mode, a border, and a Dashed section with the three dash ends. The rows below work on whichever shape you pick. This pack is an event sheet - extend it by editing it.")
	src.block("base_runtime")
	src.verb("set_thickness", "Set Thickness",
		"Sets how wide the shape's stroke is. The unit is the one you typed the number in: pixels and world units are the same in Godot's 2D, and a screen unit is a whole viewport width, so a line set in screen units keeps its weight on every phone. The field itself always stores pixels.",
		[["value", "float"], ["unit", "String"]])
	_options(src.sheet, "unit", UNITS)
	_quoted_argument(src.sheet, "set_thickness({value}, \"{unit}\")")
	src.verb("set_shape_colour", "Set Shape Colour",
		"Sets the shape's main colour - the whole of it in single mode, and the first end of the blend in every other mode.",
		[["colour", "Color"]])
	src.verb("set_colours", "Set Colours",
		"Sets both ends of a two-colour shape at once, and switches a single-colour one to that mode: a line that goes red to transparent, an arc that goes danger to healthy along its sweep.",
		[["from_colour", "Color"], ["to_colour", "Color"]])
	src.verb("set_gradient", "Set Gradient",
		"Hands the shape a Gradient resource and switches it to the gradient mode - the whole ramp, shaped in Godot's own gradient editor and re-used by every shape that points at it.",
		[["gradient_resource", "Gradient"]])
	src.verb("set_fill", "Set Fill",
		"Fills the shape, or leaves it as an outline. A filled shape draws its border rather than its stroke, so the two can never sit a pixel apart.",
		[["filled", "bool"]])
	src.verb("set_dashes", "Set Dashes",
		"Sets the dash pattern in one row: how many dashes fit the shape however long it is, how much of each period is gap, and which of the three ends the dashes wear.",
		[["count", "int"], ["spacing", "float"], ["style", "String"]])
	_options(src.sheet, "style", DASH_STYLES)
	_quoted_argument(src.sheet, "set_dashes({count}, {spacing}, \"{style}\")")
	src.verb("set_dash_offset", "Set Dash Offset",
		"Moves the dash pattern along the shape without changing it. Whole numbers land where they started, so an offset that has been scrolling for an hour is still in step.",
		[["offset", "float"]])
	src.verb("scroll_dashes", "Scroll Dashes",
		"Marches the dashes at so many patterns per second - the ants around a selection, the footprint that says \"placing\". A speed of 0 stops them and parks the tick with them, so a stopped shape costs nothing per frame.",
		[["patterns_per_second", "float"]])
	src.verb("fade_shape_over", "Fade Shape Over",
		"Fades the shape's colour to an alpha over a number of seconds - the one animation worth a verb, since every other field is an ordinary property a Tween Property row already drives.",
		[["to_alpha", "float"], ["seconds", "float"]])
	src.verb("set_shape_points", "Set Shape Points",
		"Replaces a Polygon's or a Polyline's points with a list of positions in the shape's own coordinates - a drawn route, a hull worked out at run time, an outline read from data.",
		[["new_points", "Array"]])
	src.verb("set_shape_radius", "Set Shape Radius",
		"Sets the radius of a Disc or a Regular Polygon - the one number a ring, a pie and a hexagon are all sized by.",
		[["new_radius", "float"]])
	src.verb("set_shape_sides", "Set Shape Sides",
		"Sets how many sides a Regular Polygon has: three is a triangle, six a hexagon, and a high number is a circle drawn the expensive way (a Disc is the cheap one).",
		[["count", "int"]])
	src.verb("set_arc", "Set Arc",
		"Sets a Disc's sweep, in degrees: 0 to 360 is the whole disc, and anything less is the pie or the arc a cooldown, a vision cone or a health ring is drawn as.",
		[["from_degrees", "float"], ["to_degrees", "float"]])
	src.verb("apply_shape_style", "Apply Shape Style",
		"Puts a Shape Style file into the shape's Style slot: its thickness, caps, colours, dashes and blend are read from that file from now on. An empty slot hands the shape its own fields back.",
		[["style_file", "ShapeStyle"]])
	src.verb("apply_shape_style_to_group", "Apply Shape Style To Group",
		"Puts one Shape Style file into every shape in a group at once - the whole HUD re-skinned from one file, which is what a style is for.",
		[["group_name", "String"], ["style_file", "ShapeStyle"]])
	src.verb("tether_between", "Tether Between",
		"Runs the shape between two nodes and keeps it there: its start follows the first, its end follows the second, and it redraws only on the frames one of them actually moved. The leash, the grapple rope, the wire between a machine and its switch.",
		[["first", "Node2D"], ["second", "Node2D"]])
	src.verb("untether", "Untether",
		"Lets go of both nodes. The shape stays exactly where the last frame left it, and its tick parks.",
		[])
	src.verb("fill_ring_to", "Fill Ring To",
		"Sweeps a Disc's arc to a fraction of the way round - 0 is empty, 1 is the whole ring. The cooldown, the stamina wheel, the loading circle, in one row per frame.",
		[["fraction", "float"]])
	src.verb("follow_cursor", "Follow Cursor",
		"Puts the shape under the pointer every frame, snapped to a grid of that many pixels (0 for no snap) - the placement footprint, the brush outline, the target marker. Stop Following ends it and parks the tick.",
		[["snap_to", "float"]])
	src.verb("stop_following", "Stop Following",
		"Stops the shape following the pointer. It stays where it was left.",
		[])
	src.verb("fit_around", "Fit Around",
		"Sizes the shape to what a node covers, plus a margin, and centres it on it - the selection box round a picked unit, the highlight round a card, the ring round a building.",
		[["node", "Node2D"], ["margin", "float"]])
	src.verb("show_shape_for", "Show For",
		"Shows the shape and hides it again after so many seconds - the hit marker, the ping, the flash of a footprint that says \"placed\".",
		[["seconds", "float"]])
	src.condition("shape_is_tethered", "Shape Is Tethered",
		"True while the shape is running between two nodes that both still exist.",
		[])
	src.condition("ring_is_full", "Ring Is Full",
		"True while a Disc's arc goes the whole way round - the cooldown that has finished, the wheel that is charged.",
		[])
	src.expression("point_along_shape_at", "Point Along Shape At",
		"The point a fraction of the way along the shape's outline, in the shape's own coordinates - 0 is the start, 0.5 the middle, 1 the end. Where to put a marker on a route, a spark on a wire, a label on a border.",
		[["fraction", "float"]], TYPE_VECTOR2)
	src.condition("shape_is_visible", "Shape Is Visible",
		"True while the shape is drawn at all: visible in the tree, and not fully transparent.",
		[])
	src.condition("shape_style_is", "Shape Style Is",
		"True while the shape is wearing that exact Shape Style file - the test a row makes before re-skinning, and the one an exception is written against.",
		[["style_file", "ShapeStyle"]])
	src.condition("point_is_inside_shape", "Point Is Inside Shape",
		"True when a point (in world coordinates) lands inside the shape - inside the outline for a filled one, within half a thickness of the line otherwise. The pick test for a shape you can click, with no collision body under it.",
		[["point", "Vector2"]])
	src.expression("shape_length", "Shape Length",
		"How long the shape's outline is, in pixels - the length a dash pattern is fitted into, and the number a \"walk along it\" row divides by.",
		[], TYPE_FLOAT)
	src.expression("shape_area", "Shape Area",
		"How much area the shape covers, in square pixels. A shape that is only a line covers none.",
		[], TYPE_FLOAT)
	Lib.verb_sentences(src.sheet, {
		"set_thickness": "Set thickness to [b]{value}[/b] [b]{unit}[/b]",
		"set_shape_colour": "Set shape colour to [b]{colour}[/b]",
		"set_colours": "Set colours [b]{from_colour}[/b] to [b]{to_colour}[/b]",
		"set_fill": "Set fill to [b]{filled}[/b]",
		"set_dashes": "Set dashes [b]{count}[/b], spacing [b]{spacing}[/b], [b]{style}[/b]",
		"scroll_dashes": "Scroll dashes at [b]{patterns_per_second}[/b] per second",
		"set_arc": "Set arc from [b]{from_degrees}[/b] to [b]{to_degrees}[/b] degrees",
		"apply_shape_style": "Apply shape style [b]{style_file}[/b]",
		"apply_shape_style_to_group": "Apply shape style [b]{style_file}[/b] to group [b]{group_name}[/b]",
		"tether_between": "Tether between [b]{first}[/b] and [b]{second}[/b]",
		"fill_ring_to": "Fill ring to [b]{fraction}[/b]",
		"follow_cursor": "Follow the cursor, snapped to [b]{snap_to}[/b]",
		"fit_around": "Fit around [b]{node}[/b] with a margin of [b]{margin}[/b]",
		"show_shape_for": "Show for [b]{seconds}[/b] seconds",
		"shape_is_tethered": "the shape is tethered",
		"ring_is_full": "the ring is full",
		"point_along_shape_at": "the point [b]{fraction}[/b] along the shape",
		"shape_is_visible": "the shape is visible",
		"shape_style_is": "the shape style is [b]{style_file}[/b]",
		"point_is_inside_shape": "[b]{point}[/b] is inside the shape",
	})
	Lib.feature_verbs(src.sheet, ["set_thickness", "set_dashes", "scroll_dashes", "tether_between", "fill_ring_to"])
	_target_every_verb(src.sheet, PACK_CLASS)
	return Lib.publish(src, "%s/vector_shape_2d" % PACK_DIR)


## The style file: the look half of a shape's fields, as a resource the project owns. The pack ships
## NO styles - a style is saved out of a shape somebody tuned (the Save As Style button on any 2D
## shape), because a house style shipped in the pack would be a look nobody asked for.
static func _build_style() -> bool:
	var src: Lib.PackSource = Lib.pack_from_source("vector_shapes", "Resource", "ShapeStyle",
		"A stroke style twenty shapes can share: thickness, caps, colour mode and colours, dashes and blend, as a file. Drop one into a 2D shape's Style slot and those fields are read from the file; save one out of a shape you have tuned with Save As Style.",
		Lib.manifest().category("Vector Shapes").tags(["visual", "shapes", "drawing", "style", "2d"]))
	src.sheet.tool_mode = true  # so a style edited in the Inspector repaints the shapes wearing it
	src.note("A Shape Style is a look, not a shape: the fields it speaks for are the ones a designer re-uses (thickness and its scale rule, caps, the colour mode and its colours, the dash pattern, the blend), and never a radius, an end point or a list of points. A shape that has not got a field the style carries is untouched by it. This pack is an event sheet - extend it by editing it.")
	src.block("style_fields")
	src.block("style_runtime")
	return Lib.publish(src, "%s/shape_style" % PACK_DIR)


## The seven shapes, each as [file name, class name, what it is, which shared field pieces it has].
## The pieces a shape does NOT name are the fields it genuinely has not got: a Line ships no corner
## radius and a Triangle no dash section, rather than shipping them greyed out.
static func _shapes() -> Array:
	return [
		["shape_line_2d", "ShapeLine2D", "line",
			"A straight line from the node's origin to a point you drag, drawn by distance so it is one crisp pixel wide at any zoom. Caps, a colour at each end, and dashes that scroll.",
			["caps", "dashes"]],
		["shape_disc_2d", "ShapeDisc2D", "disc",
			"A disc, and by two angles and an inner radius also a ring, a pie and an arc - the cooldown ring, the vision cone and the health arc are all this one node.",
			["fill", "dashes"]],
		["shape_rect_2d", "ShapeRect2D", "rect",
			"A rectangle with rounded corners (one number, or four), a fill, a border, and dashes on that border - the selection box, the panel, the placement footprint.",
			["fill", "border", "dashes"]],
		["shape_polygon_2d", "ShapePolygon2D", "polygon",
			"A closed outline through points you drag in the viewport, filled or hollow, with a border of its own.",
			["fill", "border"]],
		["shape_polyline_2d", "ShapePolyline2D", "polyline",
			"A path through points you drag in the viewport, open or closed, with caps and dashes - the route preview, the tether, the drawn trail.",
			["caps", "dashes"]],
		["shape_triangle_2d", "ShapeTriangle2D", "triangle",
			"Three corners, the first of them the node's own origin, with a colour per corner if you want one - the arrow head, the wedge, the pointer.",
			["fill", "border"]],
		["shape_regular_polygon_2d", "ShapeRegularPolygon2D", "regular_polygon",
			"A shape of N equal sides at a radius: a triangle, a hexagon, a near-circle - filled, bordered and dashable, from two numbers.",
			["fill", "border", "dashes"]]
	]


## One shape node: its own geometry and outline, plus the shared field pieces it has.
static func _build_shape(shape: Array) -> bool:
	var file_name: String = str(shape[0])
	var pack_class: String = str(shape[1])
	var piece_prefix: String = str(shape[2])
	var description: String = str(shape[3])
	var parts: Array = shape[4]
	var src: Lib.PackSource = Lib.pack_from_source("vector_shapes", PACK_CLASS, pack_class, description,
		Lib.manifest().category("Vector Shapes").tags(["visual", "shapes", "drawing", "2d"]))
	src.sheet.tool_mode = true
	src.block("fields_style")
	src.block("%s_geometry" % piece_prefix)
	src.block("fields_stroke")
	if parts.has("caps"):
		src.block("fields_caps")
	if parts.has("dashes"):
		src.block("fields_dash_toggle")
	src.block("%s_colour_mode" % piece_prefix)
	src.block("fields_colour")
	if parts.has("fill"):
		src.block("fields_fill")
	if parts.has("border"):
		src.block("fields_border")
	if parts.has("dashes"):
		src.block("fields_dashed")
	src.block("fields_drawing")
	src.block("fields_validate")
	src.block("%s_runtime" % piece_prefix)
	return Lib.publish(src, "%s/%s" % [PACK_DIR, file_name])


## Writes every verb's emitted call against the shape class, so the picker can turn that leading
## `$VectorShape2D.` into the node you actually picked - which is the whole point of a row that
## works on any of the seven shapes. A pack whose script IS the node (rather than a behaviour that
## attaches to one) emits a bare member call by default, and a bare call has no node in it to
## retarget: the row would then write a call to the SHEET's own script. The two verbs with a
## dropdown already carry their own call, quotes and all, and keep it.
static func _target_every_verb(sheet: EventSheetResource, pack_class: String) -> void:
	for function_resource: Resource in sheet.functions:
		if not (function_resource is EventFunction):
			continue
		var fn: EventFunction = function_resource as EventFunction
		if not fn.codegen_template_override.is_empty():
			continue
		var slots: PackedStringArray = PackedStringArray()
		for parameter: ACEParam in fn.params:
			slots.append("{%s}" % parameter.id)
		fn.codegen_template_override = "$%s.%s(%s)" % [pack_class, fn.function_name, ", ".join(slots)]


## Sets the dropdown options on the last-declared verb's parameter, so the row offers the words it
## actually accepts instead of a free-text field somebody has to spell right.
static func _options(sheet: EventSheetResource, param_id: String, choices: Array) -> void:
	var typed: Array[String] = []
	for choice: Variant in choices:
		typed.append(str(choice))
	var fn: EventFunction = sheet.functions[sheet.functions.size() - 1]
	for parameter: ACEParam in fn.params:
		if parameter.id == param_id:
			parameter.options = typed


## Rewrites the last-declared verb's emitted call so a dropdown word lands inside GDScript QUOTES. A
## picked key is inserted verbatim, so a String argument chosen from a list would otherwise emit
## `set_thickness(4, px)` - an identifier nothing declares. The annotation vocabulary carries no
## quoted key (the scanner reads the quotes off again), so the template holds them. The picker turns
## the leading `$VectorShape2D.` into the node you picked, exactly as it does for the automatic form.
static func _quoted_argument(sheet: EventSheetResource, call: String, pack_class: String = PACK_CLASS) -> void:
	var fn: EventFunction = sheet.functions[sheet.functions.size() - 1]
	fn.codegen_template_override = "$%s.%s" % [pack_class, call]


## The 3D base: the drawing machinery for a spatial shape, and every row the 3D half ships.
##
## WHY THE 3D HALF IS A SECOND BASE AND NOT A MODE ON THE FIRST. A Node2D and a MeshInstance3D have
## no common ancestor that can draw, so a shape that lives in 3D is a different node with the same
## vocabulary - which is exactly what the engine's own Bullet and Camera Rail packs do. What the two
## halves DO share is the drawing itself: one `.gdshaderinc` holds the distance fields, the dashes,
## the caps and the colour modes, and both shader families include that one file.
static func _build_base_3d() -> bool:
	var src: Lib.PackSource = Lib.pack_from_source("vector_shapes_3d", "MeshInstance3D", PACK_CLASS_3D,
		"The base every 3D Vector Shape node extends: one quad wearing the spatial half of the pack's distance-field shader when the shape is flat or a billboard, a real mesh when it is volumetric, and the rows that drive both. Add a Line 3D, Disc 3D, Rect 3D, Polygon 3D, Polyline 3D, Regular Polygon 3D, Sphere, Cuboid, Cone or Torus from the Create Node dialog rather than this.",
		Lib.manifest().category("Vector Shapes").tags(["visual", "shapes", "drawing", "shader", "3d"]))
	src.sheet.tool_mode = true  # so a shape draws itself in the editor viewport, not only in game
	src.note("Vector Shapes in 3D: ten nodes that draw the same shapes their 2D twins do, on a spatial shader that reads the same drawing. Each one is flat on its own plane, turned to face the camera, or real geometry - the Geometry buttons at the top of the Inspector. A thickness is in the node's own units or in screen pixels; the dashes, the caps and the colour modes are the ones the 2D half has, because they are the same file. The rows below work on whichever 3D shape you pick. This pack is an event sheet - extend it by editing it.")
	src.block("base_runtime_3d")
	src.verb("set_thickness", "Set Thickness",
		"Sets how wide the shape's stroke is, and what the number means. In world units it is the node's own units, so a rope five centimetres thick is 0.05; in screen units it is pixels, and the shape keeps that weight however far away the camera gets - which is what a range ring or a gizmo line wants.",
		[["value", "float"], ["unit", "String"]])
	_options(src.sheet, "unit", UNITS_3D)
	_quoted_argument(src.sheet, "set_thickness({value}, \"{unit}\")", PACK_CLASS_3D)
	src.verb("set_geometry", "Set Geometry",
		"Sets which of the three forms the shape takes: flat on its own plane, always turned to face the camera, or real geometry a light and a depth buffer treat like anything else in the scene.",
		[["mode", "String"]])
	_options(src.sheet, "mode", GEOMETRIES)
	_quoted_argument(src.sheet, "set_geometry(\"{mode}\")", PACK_CLASS_3D)
	src.verb("set_shape_colour", "Set Shape Colour",
		"Sets the shape's main colour - the whole of it in single mode, and the first end of the blend in every other mode.",
		[["colour", "Color"]])
	src.verb("set_colours", "Set Colours",
		"Sets both ends of a two-colour shape at once, and switches a single-colour one to that mode: a rope that goes bright at the hand and dark at the anchor, an arc that goes danger to healthy along its sweep.",
		[["from_colour", "Color"], ["to_colour", "Color"]])
	src.verb("set_gradient", "Set Gradient",
		"Hands the shape a Gradient resource and switches it to the gradient mode - the whole ramp, shaped in Godot's own gradient editor and re-used by every shape that points at it.",
		[["gradient_resource", "Gradient"]])
	src.verb("set_fill", "Set Fill",
		"Fills the shape, or leaves it as an outline. A filled shape draws its border rather than its stroke, so the two can never sit a unit apart.",
		[["filled", "bool"]])
	src.verb("set_dashes", "Set Dashes",
		"Sets the dash pattern in one row: how many dashes fit the shape however long it is, how much of each period is gap, and which of the three ends the dashes wear.",
		[["count", "int"], ["spacing", "float"], ["style", "String"]])
	_options(src.sheet, "style", DASH_STYLES)
	_quoted_argument(src.sheet, "set_dashes({count}, {spacing}, \"{style}\")", PACK_CLASS_3D)
	src.verb("set_dash_offset", "Set Dash Offset",
		"Moves the dash pattern along the shape without changing it. Whole numbers land where they started, so an offset that has been scrolling for an hour is still in step.",
		[["offset", "float"]])
	src.verb("scroll_dashes", "Scroll Dashes",
		"Marches the dashes at so many patterns per second - the ants around a placement ring, the rope that says \"pulling\". A speed of 0 stops them and parks the tick with them, so a stopped shape costs nothing per frame.",
		[["patterns_per_second", "float"]])
	src.verb("fade_shape_over", "Fade Shape Over",
		"Fades the shape's colour to an alpha over a number of seconds - the one animation worth a verb, since every other field is an ordinary property a Tween Property row already drives.",
		[["to_alpha", "float"], ["seconds", "float"]])
	src.verb("set_shape_points", "Set Shape Points",
		"Replaces a Polygon 3D's or a Polyline 3D's points with a list of positions in the shape's own coordinates - a route worked out at run time, a hull, an outline read from data.",
		[["new_points", "Array"]])
	src.verb("set_shape_radius", "Set Shape Radius",
		"Sets the radius of a Disc 3D, a Regular Polygon 3D, a Sphere, a Cone or a Torus - the one number a ring, a hexagon and a ball are all sized by.",
		[["new_radius", "float"]])
	src.verb("set_shape_sides", "Set Shape Sides",
		"Sets how many sides a Regular Polygon 3D has: three is a triangle, six a hexagon, and a high number is a circle drawn the expensive way (a Disc 3D is the cheap one).",
		[["count", "int"]])
	src.verb("set_arc", "Set Arc",
		"Sets a Disc 3D's sweep, in degrees: 0 to 360 is the whole disc, and anything less is the pie or the arc a cooldown, a scanning cone or a range wedge is drawn as.",
		[["from_degrees", "float"], ["to_degrees", "float"]])
	src.condition("shape_is_visible", "Shape Is Visible",
		"True while the shape is drawn at all: visible in the tree, and not fully transparent.",
		[])
	src.condition("point_is_inside_shape", "Point Is Inside Shape",
		"True when a point (in world coordinates) lands inside the shape, read on the shape's own plane - inside the outline for a filled one, within half a thickness of the line otherwise. The pick test for a shape you can click, with no collision body under it.",
		[["point", "Vector3"]])
	src.expression("shape_length", "Shape Length",
		"How long the shape's outline is, in the node's own units - the length a dash pattern is fitted into, and the number a \"walk along it\" row divides by.",
		[], TYPE_FLOAT)
	src.expression("shape_area", "Shape Area",
		"How much area the shape covers on its own plane, in square units. A shape that is only a line covers none.",
		[], TYPE_FLOAT)
	Lib.verb_sentences(src.sheet, {
		"set_thickness": "Set thickness to [b]{value}[/b] [b]{unit}[/b]",
		"set_geometry": "Set geometry to [b]{mode}[/b]",
		"set_shape_colour": "Set shape colour to [b]{colour}[/b]",
		"set_colours": "Set colours [b]{from_colour}[/b] to [b]{to_colour}[/b]",
		"set_fill": "Set fill to [b]{filled}[/b]",
		"set_dashes": "Set dashes [b]{count}[/b], spacing [b]{spacing}[/b], [b]{style}[/b]",
		"scroll_dashes": "Scroll dashes at [b]{patterns_per_second}[/b] per second",
		"set_arc": "Set arc from [b]{from_degrees}[/b] to [b]{to_degrees}[/b] degrees",
		"shape_is_visible": "the shape is visible",
		"point_is_inside_shape": "[b]{point}[/b] is inside the shape",
	})
	Lib.feature_verbs(src.sheet, ["set_geometry", "set_thickness", "set_dashes"])
	_target_every_verb(src.sheet, PACK_CLASS_3D)
	return Lib.publish(src, "%s/vector_shape_3d" % PACK_DIR)


## The six 3D twins, each as [file name, class name, which shared field pieces it has, what it is].
## The pieces a shape does NOT name are the fields it genuinely has not got, exactly as in 2D.
static func _shapes_3d() -> Array:
	return [
		["shape_line_3d", "ShapeLine3D", "line_3d",
			"A line between two points in space, drawn as a strip that faces the camera or the node's own plane - the grapple rope, the laser sight, the tether. Caps, a colour at each end, and dashes that scroll.",
			["caps", "dashes"]],
		["shape_disc_3d", "ShapeDisc3D", "disc_3d",
			"A disc, and by two angles and an inner radius also a ring, a pie and an arc - the range ring on the ground, the scanning cone, the cooldown wheel over a unit's head.",
			["fill", "dashes"]],
		["shape_rect_3d", "ShapeRect3D", "rect_3d",
			"A rectangle with rounded corners (one number, or four), a fill, a border, and dashes on that border - the panel over a machine, the selection box on the floor, the plate behind a health bar.",
			["fill", "border", "dashes"]],
		["shape_polygon_3d", "ShapePolygon3D", "polygon_3d",
			"A closed outline through points you drag in the 3D viewport, filled or hollow, with a border of its own - the claimed territory, the zone marker, the stylised leaf.",
			["fill", "border"]],
		["shape_polyline_3d", "ShapePolyline3D", "polyline_3d",
			"A path through points you drag in the 3D viewport, open or closed, with caps and dashes - the patrol route, the pipe run, the cable.",
			["caps", "dashes"]],
		["shape_regular_polygon_3d", "ShapeRegularPolygon3D", "regular_polygon_3d",
			"A shape of N equal sides at a radius: a triangle, a hexagon, a near-circle - filled, bordered and dashable, from two numbers. The hex tile marker, the summoning ring, the landing pad.",
			["fill", "border", "dashes"]]
	]


## The four solid wrappers, each as [file name, class name, piece prefix, what it is]. They are the
## engine's own primitive meshes wearing the family's colour, blend and depth fields, so a debug
## volume or a stylised prop is one node with the same Inspector as the shapes beside it.
static func _solids_3d() -> Array:
	return [
		["shape_sphere_3d", "ShapeSphere3D", "sphere_3d",
			"The engine's own sphere with the family's colour, blend and depth fields on it - the debug volume, the stylised planet, the ball at the end of a pointer."],
		["shape_cuboid_3d", "ShapeCuboid3D", "cuboid_3d",
			"The engine's own box with the family's colour, blend and depth fields on it - the block-out volume, the crate, the trigger you want to see."],
		["shape_cone_3d", "ShapeCone3D", "cone_3d",
			"A cone with an optional cap, wearing the family's colour, blend and depth fields - the spotlight volume, the arrow head, the vision cone you can walk around."],
		["shape_torus_3d", "ShapeTorus3D", "torus_3d",
			"The engine's own torus with the family's colour, blend and depth fields on it - the portal ring, the halo, the hoop a racer flies through."]
	]


## One 3D twin: the geometry mode first (it is the choice the rest of the Inspector hangs off), then
## its own geometry, then the shared field pieces that shape actually has.
static func _build_shape_3d(shape: Array) -> bool:
	var file_name: String = str(shape[0])
	var pack_class: String = str(shape[1])
	var piece_prefix: String = str(shape[2])
	var description: String = str(shape[3])
	var parts: Array = shape[4]
	var src: Lib.PackSource = Lib.pack_from_source("vector_shapes_3d", PACK_CLASS_3D, pack_class, description,
		Lib.manifest().category("Vector Shapes").tags(["visual", "shapes", "drawing", "3d"]))
	src.sheet.tool_mode = true
	src.block("fields_geometry_3d")
	src.block("%s_geometry" % piece_prefix)
	src.block("fields_stroke_3d")
	if parts.has("caps"):
		src.block("fields_caps_3d")
	if parts.has("dashes"):
		src.block("fields_dash_toggle_3d")
	src.block("%s_colour_mode" % piece_prefix)
	src.block("fields_colour_3d")
	if parts.has("fill"):
		src.block("fields_fill_3d")
	if parts.has("border"):
		src.block("fields_border_3d")
	if parts.has("dashes"):
		src.block("fields_dashed_3d")
	src.block("fields_drawing_3d")
	src.block("fields_validate_3d")
	src.block("%s_runtime" % piece_prefix)
	return Lib.publish(src, "%s/%s" % [PACK_DIR, file_name])


## One solid wrapper: its own geometry, and the four fields a surface has. No stroke, no dashes and
## no distance field - a shape made of real geometry has no outline to run a pattern along, and the
## flat and billboard forms of the six twins are what that is for.
static func _build_solid_3d(solid: Array) -> bool:
	var file_name: String = str(solid[0])
	var pack_class: String = str(solid[1])
	var piece_prefix: String = str(solid[2])
	var description: String = str(solid[3])
	var src: Lib.PackSource = Lib.pack_from_source("vector_shapes_3d", PACK_CLASS_3D, pack_class, description,
		Lib.manifest().category("Vector Shapes").tags(["visual", "shapes", "drawing", "3d"]))
	src.sheet.tool_mode = true
	src.block("%s_geometry" % piece_prefix)
	src.block("fields_solid_3d")
	src.block("%s_runtime" % piece_prefix)
	return Lib.publish(src, "%s/%s" % [PACK_DIR, file_name])
