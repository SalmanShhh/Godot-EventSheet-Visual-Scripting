# Pack builder - touch_gestures (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## Touch Gestures: swipes and drawn shapes as triggers. Attach it under any node and it watches the
## touch events itself - a finger down, the drag between, the finger up - and fires On Swipe with a
## direction or On Shape Drawn with a name.
##
## The two halves are deliberately separate. A SWIPE is a distance covered quickly enough in one
## dominant direction: four ways by default, eight when the diagonals are turned on. A SHAPE is the
## whole stroke the drag gathered, smoothed to a fixed number of points, moved to the origin, scaled
## to a unit box and compared against every taught template both ways round - so a circle drawn
## clockwise and one drawn anticlockwise are the same circle, and a big one and a small one are too.
##
## Templates are TAUGHT rather than typed: draw the shape in the running game, call Teach Shape From
## Stroke with a name, and save the library to a .tres. That is why there is no coordinate list
## anywhere in this pack.
##
## Pinches and pans are already sentences the sheet owns (Touch > On Pinch / On Pan), so nothing here
## re-speaks them, and a SEQUENCE of gestures is the Combo Box behaviour's job - feed it the swipe
## direction as a token.
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "Node"
	sheet.custom_class_name = "TouchGesturesBehavior"
	sheet.class_description = "Swipes and drawn shapes as triggers. Watches the touch events itself and fires On Swipe (left / right / up / down, or eight ways with the diagonals on) and On Shape Drawn with the name of the closest taught shape. Teach a shape by drawing it once."
	sheet.addon_category = "Touch Gestures"
	sheet.addon_tags = PackedStringArray(["input", "touch", "gestures"])
	sheet.variables = {
		"debug_logging": {"type": "bool", "default": false, "exported": true,
			"attributes": {"tooltip": "Print every swipe and every match to the Output panel while tuning the thresholds."}},
		"eight_way": {"type": "bool", "default": false, "exported": true,
			"attributes": {"tooltip": "Off: four directions (left, right, up, down). On: the four diagonals as well (up left, up right, down left, down right)."}},
		"minimum_stroke_points": {"type": "int", "default": 8, "exported": true,
			"attributes": {"tooltip": "How many gathered points a stroke needs before it is worth matching. A tap gathers one or two.", "range": {"min": "4", "max": "64", "step": "1"}}},
		"shape_library": {"type": "Resource", "default": null, "exported": true,
			"attributes": {"tooltip": "A Touch Shape Library data asset holding the taught shapes. Leave it empty to teach shapes that only live for this run."}},
		"shape_tolerance": {"type": "float", "default": 0.22, "exported": true,
			"attributes": {"tooltip": "How far a stroke may sit from a taught shape and still count, 0 to 1. Higher is more forgiving and more likely to confuse two similar shapes.", "range": {"min": "0.02", "max": "0.8", "step": "0.01"}}},
		"swipe_max_seconds": {"type": "float", "default": 0.4, "exported": true,
			"attributes": {"tooltip": "How long the finger may take. A slow drag over the same distance is a drag, not a swipe.", "range": {"min": "0.05", "max": "3.0", "step": "0.05"}}},
		"swipe_min_distance": {"type": "float", "default": 100.0, "exported": true,
			"attributes": {"tooltip": "How far the finger must travel, in pixels, before the drag counts as a swipe.", "range": {"min": "10.0", "max": "600.0", "step": "5.0"}}}
	}
	var about: CommentRow = CommentRow.new()
	about.text = "Touch Gestures: attach under any node. It reads the touch events itself and fires On Swipe (direction, distance, seconds) and On Shape Drawn (name). Teach a shape by drawing it and calling Teach Shape From Stroke - the attached library is updated there and then. Save Shapes To Library is what writes that library to its file from a running game. On desktop, turn on Project Settings > Input Devices > Pointing > Emulate Touch From Mouse to try it with the mouse."
	sheet.events.append(about)
	var block: RawCodeRow = RawCodeRow.new()
	block.code = "\n".join(_runtime_lines())
	sheet.events.append(block)

	# --- Tuning ---
	Lib.append_function(sheet, "set_swipe_thresholds", "Set Swipe Thresholds", "Touch Gestures", "Sets how far (pixels) and how fast (seconds) a drag has to be before it counts as a swipe. The defaults suit a phone held in one hand.",
		[["minimum_distance", "float"], ["maximum_seconds", "float"]],
		"swipe_min_distance = maxf(minimum_distance, 1.0)\nswipe_max_seconds = maxf(maximum_seconds, 0.01)")
	Lib.append_function(sheet, "set_eight_way", "Set Eight Way", "Touch Gestures", "Turns the four diagonals on or off. Off, a diagonal swipe reports as whichever of left / right / up / down it leaned towards.",
		[["on", "bool"]],
		"eight_way = on")

	# --- Shapes ---
	Lib.append_function(sheet, "teach_shape_from_stroke", "Teach Shape From Stroke", "Touch Gestures", "Records the stroke that was just drawn as a template under a name. Draw the shape in the running game, then call this - there is no coordinate list to type. The attached shape library is updated straight away and marked changed, so the editor's own Save writes it out; Save Shapes To Library is the explicit write for a running game.",
		[["shape_name", "String"]],
		"if _stroke.size() < minimum_stroke_points:\n\treturn\n_shapes[shape_name] = _normalise(_stroke)\n_write_through_to_library()\nif debug_logging:\n\tprint(\"[Touch Gestures] taught \", shape_name, \" from \", _stroke.size(), \" points\")")
	Lib.append_function(sheet, "forget_shape", "Forget Shape", "Touch Gestures", "Removes a taught shape, so it stops being matched. The attached library is updated and marked changed the same way teaching updates it.",
		[["shape_name", "String"]],
		"_shapes.erase(shape_name)\n_write_through_to_library()")
	Lib.append_function(sheet, "load_shapes_from_library", "Load Shapes From Library", "Touch Gestures", "Reads every taught shape out of the attached shape library, replacing what is loaded. Called for you when the behaviour starts.",
		[],
		"_shapes.clear()\nif shape_library != null and \"shapes\" in shape_library:\n\tfor key: Variant in shape_library.shapes:\n\t\t_shapes[str(key)] = shape_library.shapes[key]")
	Lib.append_function(sheet, "save_shapes_to_library", "Save Shapes To Library", "Touch Gestures", "Writes the attached shape library out to its own file, so the shapes taught this run survive it. Teaching already put them in the library - this is the step that puts the library on disk. Says so when no library is attached, or when the one attached has never been saved as a file and so has nowhere to write.",
		[],
		"if shape_library == null or not \"shapes\" in shape_library:\n\tpush_warning(\"[Touch Gestures] No shape library is attached, so the shapes taught this run cannot be saved. Attach a Touch Shape Library data asset to keep them.\")\n\treturn\n_write_through_to_library()\nif shape_library.resource_path.is_empty():\n\tpush_warning(\"[Touch Gestures] The attached shape library has never been saved as a file, so there is nowhere to write it. Save it as a .tres first.\")\n\treturn\nResourceSaver.save(shape_library, shape_library.resource_path)")
	Lib.append_function(sheet, "clear_stroke", "Clear Stroke", "Touch Gestures", "Throws away the stroke gathered so far, so a gesture interrupted by a menu cannot finish afterwards.",
		[],
		"_stroke.clear()")

	# --- Conditions ---
	Lib.condition(sheet, "swipe_was", "Swipe Was", "Touch Gestures", "Whether the swipe that just fired went this way (\"left\", \"right\", \"up\", \"down\", and with eight-way on \"up left\", \"up right\", \"down left\", \"down right\").",
		[["direction", "String"]],
		"return _swipe_direction == direction")
	Lib.condition(sheet, "shape_was", "Shape Was", "Touch Gestures", "Whether the shape that was just drawn is this one.",
		[["shape_name", "String"]],
		"return _shape_name == shape_name")
	Lib.condition(sheet, "knows_shape", "Knows Shape", "Touch Gestures", "Whether a shape has been taught under this name.",
		[["shape_name", "String"]],
		"return _shapes.has(shape_name)")

	# --- Expressions ---
	Lib.number(sheet, "swipe_direction", "Swipe Direction", "Touch Gestures", "Which way the swipe went, as a word (inside On Swipe).", [],
		"return _swipe_direction", TYPE_STRING)
	Lib.number(sheet, "swipe_angle", "Swipe Angle", "Touch Gestures", "The swipe's angle in degrees, 0 pointing right and counting clockwise the way screen coordinates do (inside On Swipe).", [],
		"return _swipe_angle", TYPE_FLOAT)
	Lib.number(sheet, "swipe_distance", "Swipe Distance", "Touch Gestures", "How far the finger travelled, in pixels (inside On Swipe).", [],
		"return _swipe_distance", TYPE_FLOAT)
	Lib.number(sheet, "swipe_seconds", "Swipe Seconds", "Touch Gestures", "How long the swipe took, in seconds (inside On Swipe).", [],
		"return _swipe_seconds", TYPE_FLOAT)
	Lib.number(sheet, "swipe_speed", "Swipe Speed", "Touch Gestures", "How fast the swipe was, in pixels per second - the number a flick's momentum should scale with (inside On Swipe).", [],
		"return _swipe_distance / maxf(_swipe_seconds, 0.001)", TYPE_FLOAT)
	Lib.number(sheet, "shape_name", "Shape Name", "Touch Gestures", "The name of the shape that was just drawn (inside On Shape Drawn).", [],
		"return _shape_name", TYPE_STRING)
	Lib.number(sheet, "shape_closeness", "Shape Closeness", "Touch Gestures", "How close the stroke was to the taught shape, 0 to 1, where 1 is an exact match (inside On Shape Drawn).", [],
		"return _shape_closeness", TYPE_FLOAT)
	Lib.number(sheet, "stroke_length", "Stroke Length", "Touch Gestures", "How far the finger travelled along the whole stroke, in pixels - the drawn line's length, not the distance between its ends.", [],
		"return _stroke_length(_stroke)", TYPE_FLOAT)
	Lib.number(sheet, "stroke_points", "Stroke Points", "Touch Gestures", "How many points the stroke gathered so far.", [],
		"return _stroke.size()", TYPE_INT)

	# The pack's hero verbs: starred + bold at the top of their picker section.
	Lib.verb_sentences(sheet, {
		"teach_shape_from_stroke": "Teach shape from stroke as [b]{shape_name}[/b]",
		"set_swipe_thresholds": "Set swipe thresholds: [b]{minimum_distance}[/b] px in [b]{maximum_seconds}[/b] s",
	})
	Lib.feature_verbs(sheet, ["teach_shape_from_stroke", "set_swipe_thresholds"])
	return Lib.save_pack(sheet, "res://eventsheet_addons/touch_gestures/touch_gestures")


## The runtime block: the touch bookkeeping, the swipe test and the shape matcher. Kept in one place
## so the whole recogniser reads top to bottom the way it runs.
static func _runtime_lines() -> PackedStringArray:
	return PackedStringArray([
		"## @ace_trigger",
		"## @ace_name(\"On Swipe\")",
		"## @ace_category(\"Touch Gestures\")",
		"signal on_swipe()",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Shape Drawn\")",
		"## @ace_category(\"Touch Gestures\")",
		"signal on_shape_drawn()",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Stroke Started\")",
		"## @ace_category(\"Touch Gestures\")",
		"signal on_stroke_started()",
		"",
		"# How many points every stroke is smoothed to before it is compared. Fixed, because two",
		"# strokes can only be compared point for point when they have the same number of points.",
		"const SAMPLE_COUNT: int = 24",
		"",
		"# The eight directions by name, in the order their angle bands run from -180 to 180 degrees.",
		"# Screen coordinates count Y downwards, so \"up\" is the negative half.",
		"const EIGHT_WAY_NAMES: PackedStringArray = [\"left\", \"up left\", \"up\", \"up right\", \"right\", \"down right\", \"down\", \"down left\"]",
		"",
		"# Where the finger went down, and when. The whole swipe test is the difference between this",
		"# and where it came up.",
		"var _touch_start: Vector2 = Vector2.ZERO",
		"var _touch_started_at: float = 0.0",
		"# Every point the drag gathered, oldest first. Cleared on each new touch.",
		"var _stroke: PackedVector2Array = PackedVector2Array()",
		"# name -> the smoothed, centred, unit-scaled outline taught for it.",
		"var _shapes: Dictionary = {}",
		"# Last-gesture context, read by the expressions inside the triggers.",
		"var _swipe_direction: String = \"\"",
		"var _swipe_angle: float = 0.0",
		"var _swipe_distance: float = 0.0",
		"var _swipe_seconds: float = 0.0",
		"var _shape_name: String = \"\"",
		"var _shape_closeness: float = 0.0",
		"",
		"func _ready() -> void:",
		"\tload_shapes_from_library()",
		"",
		"func _input(event: InputEvent) -> void:",
		"\tif event is InputEventScreenTouch:",
		"\t\tif event.pressed:",
		"\t\t\t_touch_start = event.position",
		"\t\t\t_touch_started_at = Time.get_ticks_msec() / 1000.0",
		"\t\t\t_stroke = PackedVector2Array([event.position])",
		"\t\t\ton_stroke_started.emit()",
		"\t\telse:",
		"\t\t\t_finish_stroke(event.position)",
		"\telif event is InputEventScreenDrag:",
		"\t\t_stroke.append(event.position)",
		"",
		"# The finger came up: a fast enough journey in one direction is a swipe, and anything else",
		"# that gathered enough points is a shape worth matching. One gesture per stroke, never both.",
		"## @ace_hidden",
		"func _finish_stroke(ended_at: Vector2) -> void:",
		"\tvar travelled: Vector2 = ended_at - _touch_start",
		"\tvar held: float = Time.get_ticks_msec() / 1000.0 - _touch_started_at",
		"\tif travelled.length() >= swipe_min_distance and held <= swipe_max_seconds:",
		"\t\t_swipe_direction = _direction_of(travelled)",
		"\t\t_swipe_angle = rad_to_deg(travelled.angle())",
		"\t\t_swipe_distance = travelled.length()",
		"\t\t_swipe_seconds = held",
		"\t\tif debug_logging:",
		"\t\t\tprint(\"[Touch Gestures] swipe \", _swipe_direction, \" \", _swipe_distance, \"px in \", _swipe_seconds, \"s\")",
		"\t\ton_swipe.emit()",
		"\t\treturn",
		"\tif _stroke.size() < minimum_stroke_points or _shapes.is_empty():",
		"\t\treturn",
		"\tvar matched: Dictionary = _closest_shape(_stroke)",
		"\tif matched.is_empty():",
		"\t\treturn",
		"\t_shape_name = str(matched.name)",
		"\t_shape_closeness = float(matched.closeness)",
		"\tif debug_logging:",
		"\t\tprint(\"[Touch Gestures] shape \", _shape_name, \" closeness \", _shape_closeness)",
		"\ton_shape_drawn.emit()",
		"",
		"# Which named direction a travel vector points in. Four bands by default; with eight-way on,",
		"# the eight bands the diagonals cut the same circle into.",
		"## @ace_hidden",
		"func _direction_of(travelled: Vector2) -> String:",
		"\tif not eight_way:",
		"\t\tif absf(travelled.x) > absf(travelled.y):",
		"\t\t\treturn \"right\" if travelled.x > 0.0 else \"left\"",
		"\t\treturn \"down\" if travelled.y > 0.0 else \"up\"",
		"\tvar degrees: float = rad_to_deg(travelled.angle())",
		"\tvar band: int = int(round((degrees + 180.0) / 45.0)) % 8",
		"\treturn EIGHT_WAY_NAMES[band]",
		"",
		"# The one place the attached library is written. Teaching and forgetting both go through it,",
		"# so the library an author can see in the Inspector is never a step behind what the behaviour",
		"# knows - and emit_changed() marks the resource dirty, which is what makes the editor's own",
		"# Save write it out. Saving to DISK from a running game is still Save Shapes To Library: a",
		"# game cannot rely on an editor being open.",
		"## @ace_hidden",
		"func _write_through_to_library() -> void:",
		"\tif shape_library == null or not \"shapes\" in shape_library:",
		"\t\treturn",
		"\tshape_library.shapes = _shapes.duplicate(true)",
		"\tshape_library.emit_changed()",
		"",
		"# How far the finger travelled ALONG the stroke, which is what tells a long scribble from a",
		"# short one even when both start and end in the same place.",
		"## @ace_hidden",
		"func _stroke_length(points: PackedVector2Array) -> float:",
		"\tvar total: float = 0.0",
		"\tfor index: int in range(1, points.size()):",
		"\t\ttotal += points[index].distance_to(points[index - 1])",
		"\treturn total",
		"",
		"# A stroke reduced to something comparable: SAMPLE_COUNT points spaced evenly along its",
		"# length, moved so their middle sits at the origin, and scaled so the longest side of their",
		"# box is 1. After this a big circle and a small one are the same numbers, which is the whole",
		"# reason a drawn gesture can be recognised at all.",
		"## @ace_hidden",
		"func _normalise(points: PackedVector2Array) -> PackedVector2Array:",
		"\tvar resampled: PackedVector2Array = _resample(points)",
		"\tif resampled.is_empty():",
		"\t\treturn resampled",
		"\tvar centre: Vector2 = Vector2.ZERO",
		"\tfor point: Vector2 in resampled:",
		"\t\tcentre += point",
		"\tcentre /= float(resampled.size())",
		"\tvar low: Vector2 = resampled[0]",
		"\tvar high: Vector2 = resampled[0]",
		"\tfor point: Vector2 in resampled:",
		"\t\tlow = low.min(point)",
		"\t\thigh = high.max(point)",
		"\tvar span: float = maxf(maxf(high.x - low.x, high.y - low.y), 0.001)",
		"\tvar out: PackedVector2Array = PackedVector2Array()",
		"\tfor point: Vector2 in resampled:",
		"\t\tout.append((point - centre) / span)",
		"\treturn out",
		"",
		"# SAMPLE_COUNT points spaced evenly along the stroke's length. Walking the length rather than",
		"# taking every Nth point is what makes a slow corner and a fast straight weigh the same.",
		"## @ace_hidden",
		"func _resample(points: PackedVector2Array) -> PackedVector2Array:",
		"\tvar out: PackedVector2Array = PackedVector2Array()",
		"\tvar total: float = _stroke_length(points)",
		"\tif points.size() < 2 or total <= 0.0:",
		"\t\treturn out",
		"\tvar step: float = total / float(SAMPLE_COUNT - 1)",
		"\tvar walked: float = 0.0",
		"\tvar index: int = 1",
		"\tvar cursor: Vector2 = points[0]",
		"\tout.append(cursor)",
		"\twhile out.size() < SAMPLE_COUNT and index < points.size():",
		"\t\tvar leg: float = cursor.distance_to(points[index])",
		"\t\tif walked + leg >= step and leg > 0.0:",
		"\t\t\tcursor = cursor.lerp(points[index], (step - walked) / leg)",
		"\t\t\tout.append(cursor)",
		"\t\t\twalked = 0.0",
		"\t\telse:",
		"\t\t\twalked += leg",
		"\t\t\tcursor = points[index]",
		"\t\t\tindex += 1",
		"\twhile out.size() < SAMPLE_COUNT:",
		"\t\tout.append(points[points.size() - 1])",
		"\treturn out",
		"",
		"# The taught shape a stroke is closest to, as {name, closeness}, or {} when nothing is close",
		"# enough. Each template is tried both ways round, so a circle drawn the other way still counts.",
		"## @ace_hidden",
		"func _closest_shape(points: PackedVector2Array) -> Dictionary:",
		"\tvar drawn: PackedVector2Array = _normalise(points)",
		"\tif drawn.is_empty():",
		"\t\treturn {}",
		"\tvar reversed_drawn: PackedVector2Array = drawn.duplicate()",
		"\treversed_drawn.reverse()",
		"\tvar best_name: String = \"\"",
		"\tvar best_distance: float = 1e20",
		"\tfor key: Variant in _shapes:",
		"\t\tvar template: PackedVector2Array = _shapes[key]",
		"\t\tvar distance: float = minf(_average_distance(drawn, template), _average_distance(reversed_drawn, template))",
		"\t\tif distance < best_distance:",
		"\t\t\tbest_distance = distance",
		"\t\t\tbest_name = str(key)",
		"\tif best_name.is_empty() or best_distance > shape_tolerance:",
		"\t\treturn {}",
		"\treturn {\"name\": best_name, \"closeness\": clampf(1.0 - best_distance / maxf(shape_tolerance, 0.001), 0.0, 1.0)}",
		"",
		"# How far apart two normalised strokes are on average, point for point. Templates of a",
		"# different length are refused rather than stretched: a mismatched library is a bug to see.",
		"## @ace_hidden",
		"func _average_distance(a: PackedVector2Array, b: PackedVector2Array) -> float:",
		"\tif a.size() != b.size() or a.is_empty():",
		"\t\treturn 1e20",
		"\tvar total: float = 0.0",
		"\tfor index: int in a.size():",
		"\t\ttotal += a[index].distance_to(b[index])",
		"\treturn total / float(a.size())"
	])
