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
	for shape: Array in _shapes():
		if not _build_shape(shape):
			return false
	# The shaders ARE the pack: without them a shape draws nothing at all. They ship in the same
	# build, from the same source folder, byte-stable like everything else here.
	return Lib.ship_files("vector_shapes", "%s/vector_shapes" % PACK_DIR,
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
	src.condition("shape_is_visible", "Shape Is Visible",
		"True while the shape is drawn at all: visible in the tree, and not fully transparent.",
		[])
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
		"shape_is_visible": "the shape is visible",
		"point_is_inside_shape": "[b]{point}[/b] is inside the shape",
	})
	Lib.feature_verbs(src.sheet, ["set_thickness", "set_dashes", "scroll_dashes"])
	_target_every_verb(src.sheet)
	return Lib.publish(src, "%s/vector_shape_2d" % PACK_DIR)


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
static func _target_every_verb(sheet: EventSheetResource) -> void:
	for function_resource: Resource in sheet.functions:
		if not (function_resource is EventFunction):
			continue
		var fn: EventFunction = function_resource as EventFunction
		if not fn.codegen_template_override.is_empty():
			continue
		var slots: PackedStringArray = PackedStringArray()
		for parameter: ACEParam in fn.params:
			slots.append("{%s}" % parameter.id)
		fn.codegen_template_override = "$%s.%s(%s)" % [PACK_CLASS, fn.function_name, ", ".join(slots)]


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
static func _quoted_argument(sheet: EventSheetResource, call: String) -> void:
	var fn: EventFunction = sheet.functions[sheet.functions.size() - 1]
	fn.codegen_template_override = "$%s.%s" % [PACK_CLASS, call]
