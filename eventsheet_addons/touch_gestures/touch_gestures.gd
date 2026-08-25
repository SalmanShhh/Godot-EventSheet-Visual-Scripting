## @ace_tags(input, touch, gestures)
## @ace_category("Touch Gestures")
## @ace_version(1.0.0)
@icon("res://eventsheet_addons/touch_gestures/icon.svg")
class_name TouchGesturesBehavior
extends Node
## Swipes and drawn shapes as triggers. Watches the touch events itself and fires On Swipe (left / right / up / down, or eight ways with the diagonals on) and On Shape Drawn with the name of the closest taught shape. Teach a shape by drawing it once.

## The node this behavior acts on (its parent). Required host: Node.
var host: Node = null

func _enter_tree() -> void:
	host = get_parent() as Node
	if host == null:
		push_warning("TouchGesturesBehavior behavior requires a Node parent.")

## @ace_trigger
## @ace_name("On Swipe")
## @ace_category("Touch Gestures")
signal on_swipe
## @ace_trigger
## @ace_name("On Shape Drawn")
## @ace_category("Touch Gestures")
signal on_shape_drawn
## @ace_trigger
## @ace_name("On Stroke Started")
## @ace_category("Touch Gestures")
signal on_stroke_started

## Print every swipe and every match to the Output panel while tuning the thresholds.
@export var debug_logging: bool = false
## Off: four directions (left, right, up, down). On: the four diagonals as well (up left, up right, down left, down right).
@export var eight_way: bool = false
## How many gathered points a stroke needs before it is worth matching. A tap gathers one or two.
@export_range(4, 64, 1) var minimum_stroke_points: int = 8
## A Touch Shape Library data asset holding the taught shapes. Leave it empty to teach shapes that only live for this run.
@export var shape_library: Resource = null
## How far a stroke may sit from a taught shape and still count, 0 to 1. Higher is more forgiving and more likely to confuse two similar shapes.
@export_range(0.02, 0.8, 0.01) var shape_tolerance: float = 0.22
## How long the finger may take. A slow drag over the same distance is a drag, not a swipe.
@export_range(0.05, 3.0, 0.05) var swipe_max_seconds: float = 0.4
## How far the finger must travel, in pixels, before the drag counts as a swipe.
@export_range(10.0, 600.0, 5.0) var swipe_min_distance: float = 100.0

# How many points every stroke is smoothed to before it is compared. Fixed, because two
# strokes can only be compared point for point when they have the same number of points.
const SAMPLE_COUNT: int = 24

# The eight directions by name, in the order their angle bands run from -180 to 180 degrees.
# Screen coordinates count Y downwards, so "up" is the negative half.
const EIGHT_WAY_NAMES: PackedStringArray = ["left", "up left", "up", "up right", "right", "down right", "down", "down left"]

# Where the finger went down, and when. The whole swipe test is the difference between this
# and where it came up.
var _touch_start: Vector2 = Vector2.ZERO
var _touch_started_at: float = 0.0
# Every point the drag gathered, oldest first. Cleared on each new touch.
var _stroke: PackedVector2Array = PackedVector2Array()
# name -> the smoothed, centred, unit-scaled outline taught for it.
var _shapes: Dictionary = {}
# Last-gesture context, read by the expressions inside the triggers.
var _swipe_direction: String = ""
var _swipe_angle: float = 0.0
var _swipe_distance: float = 0.0
var _swipe_seconds: float = 0.0
var _shape_name: String = ""
var _shape_closeness: float = 0.0
# A stroke reduced to something comparable: SAMPLE_COUNT points spaced evenly along its
# length, moved so their middle sits at the origin, and scaled so the longest side of their
# box is 1. After this a big circle and a small one are the same numbers, which is the whole
# reason a drawn gesture can be recognised at all.
## @ace_hidden
func _normalise(points: PackedVector2Array) -> PackedVector2Array:
	var resampled: PackedVector2Array = _resample(points)
	if resampled.is_empty():
		return resampled
	var centre: Vector2 = Vector2.ZERO
	for point: Vector2 in resampled:
		centre += point
	centre /= float(resampled.size())
	var low: Vector2 = resampled[0]
	var high: Vector2 = resampled[0]
	for point: Vector2 in resampled:
		low = low.min(point)
		high = high.max(point)
	var span: float = maxf(maxf(high.x - low.x, high.y - low.y), 0.001)
	var out: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in resampled:
		out.append((point - centre) / span)
	return out
# SAMPLE_COUNT points spaced evenly along the stroke's length. Walking the length rather than
# taking every Nth point is what makes a slow corner and a fast straight weigh the same.
## @ace_hidden
func _resample(points: PackedVector2Array) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	var total: float = _stroke_length(points)
	if points.size() < 2 or total <= 0.0:
		return out
	var step: float = total / float(SAMPLE_COUNT - 1)
	var walked: float = 0.0
	var index: int = 1
	var cursor: Vector2 = points[0]
	out.append(cursor)
	while out.size() < SAMPLE_COUNT and index < points.size():
		var leg: float = cursor.distance_to(points[index])
		if walked + leg >= step and leg > 0.0:
			cursor = cursor.lerp(points[index], (step - walked) / leg)
			out.append(cursor)
			walked = 0.0
		else:
			walked += leg
			cursor = points[index]
			index += 1
	while out.size() < SAMPLE_COUNT:
		out.append(points[points.size() - 1])
	return out

## @ace_action
## @ace_featured
## @ace_name("Set Swipe Thresholds")
## @ace_category("Touch Gestures")
## @ace_description("Sets how far (pixels) and how fast (seconds) a drag has to be before it counts as a swipe. The defaults suit a phone held in one hand.")
## @ace_display_template("Set swipe thresholds: [b]{minimum_distance}[/b] px in [b]{maximum_seconds}[/b] s")
## @ace_icon("res://eventsheet_addons/touch_gestures/icon.svg")
## @ace_codegen_template("$TouchGesturesBehavior.set_swipe_thresholds({minimum_distance}, {maximum_seconds})")
func set_swipe_thresholds(minimum_distance: float, maximum_seconds: float) -> void:
	swipe_min_distance = maxf(minimum_distance, 1.0)
	swipe_max_seconds = maxf(maximum_seconds, 0.01)

## @ace_action
## @ace_name("Set Eight Way")
## @ace_category("Touch Gestures")
## @ace_description("Turns the four diagonals on or off. Off, a diagonal swipe reports as whichever of left / right / up / down it leaned towards.")
## @ace_icon("res://eventsheet_addons/touch_gestures/icon.svg")
## @ace_codegen_template("$TouchGesturesBehavior.set_eight_way({on})")
func set_eight_way(on: bool) -> void:
	eight_way = on

## @ace_action
## @ace_featured
## @ace_name("Teach Shape From Stroke")
## @ace_category("Touch Gestures")
## @ace_description("Records the stroke that was just drawn as a template under a name. Draw the shape in the running game, then call this - there is no coordinate list to type. The attached shape library is updated straight away and marked changed, so the editor's own Save writes it out; Save Shapes To Library is the explicit write for a running game.")
## @ace_display_template("Teach shape from stroke as [b]{shape_name}[/b]")
## @ace_icon("res://eventsheet_addons/touch_gestures/icon.svg")
## @ace_codegen_template("$TouchGesturesBehavior.teach_shape_from_stroke({shape_name})")
func teach_shape_from_stroke(shape_name: String) -> void:
	if _stroke.size() < minimum_stroke_points:
		return
	_shapes[shape_name] = _normalise(_stroke)
	_write_through_to_library()
	if debug_logging:
		print("[Touch Gestures] taught ", shape_name, " from ", _stroke.size(), " points")

## @ace_action
## @ace_name("Forget Shape")
## @ace_category("Touch Gestures")
## @ace_description("Removes a taught shape, so it stops being matched. The attached library is updated and marked changed the same way teaching updates it.")
## @ace_icon("res://eventsheet_addons/touch_gestures/icon.svg")
## @ace_codegen_template("$TouchGesturesBehavior.forget_shape({shape_name})")
func forget_shape(shape_name: String) -> void:
	_shapes.erase(shape_name)
	_write_through_to_library()

## @ace_action
## @ace_name("Load Shapes From Library")
## @ace_category("Touch Gestures")
## @ace_description("Reads every taught shape out of the attached shape library, replacing what is loaded. Called for you when the behaviour starts.")
## @ace_icon("res://eventsheet_addons/touch_gestures/icon.svg")
## @ace_codegen_template("$TouchGesturesBehavior.load_shapes_from_library()")
func load_shapes_from_library() -> void:
	_shapes.clear()
	if shape_library != null and "shapes" in shape_library:
		for key: Variant in shape_library.shapes:
			_shapes[str(key)] = shape_library.shapes[key]

## @ace_action
## @ace_name("Save Shapes To Library")
## @ace_category("Touch Gestures")
## @ace_description("Writes the attached shape library out to its own file, so the shapes taught this run survive it. Teaching already put them in the library - this is the step that puts the library on disk. Says so when no library is attached, or when the one attached has never been saved as a file and so has nowhere to write.")
## @ace_icon("res://eventsheet_addons/touch_gestures/icon.svg")
## @ace_codegen_template("$TouchGesturesBehavior.save_shapes_to_library()")
func save_shapes_to_library() -> void:
	if shape_library == null or not "shapes" in shape_library:
		push_warning("[Touch Gestures] No shape library is attached, so the shapes taught this run cannot be saved. Attach a Touch Shape Library data asset to keep them.")
		return
	_write_through_to_library()
	if shape_library.resource_path.is_empty():
		push_warning("[Touch Gestures] The attached shape library has never been saved as a file, so there is nowhere to write it. Save it as a .tres first.")
		return
	ResourceSaver.save(shape_library, shape_library.resource_path)

## @ace_action
## @ace_name("Clear Stroke")
## @ace_category("Touch Gestures")
## @ace_description("Throws away the stroke gathered so far, so a gesture interrupted by a menu cannot finish afterwards.")
## @ace_icon("res://eventsheet_addons/touch_gestures/icon.svg")
## @ace_codegen_template("$TouchGesturesBehavior.clear_stroke()")
func clear_stroke() -> void:
	_stroke.clear()

## @ace_condition
## @ace_name("Swipe Was")
## @ace_category("Touch Gestures")
## @ace_description("Whether the swipe that just fired went this way ("left", "right", "up", "down", and with eight-way on "up left", "up right", "down left", "down right").")
## @ace_icon("res://eventsheet_addons/touch_gestures/icon.svg")
## @ace_codegen_template("$TouchGesturesBehavior.swipe_was({direction})")
func swipe_was(direction: String) -> bool:
	return _swipe_direction == direction

## @ace_condition
## @ace_name("Shape Was")
## @ace_category("Touch Gestures")
## @ace_description("Whether the shape that was just drawn is this one.")
## @ace_icon("res://eventsheet_addons/touch_gestures/icon.svg")
## @ace_codegen_template("$TouchGesturesBehavior.shape_was({shape_name})")
func shape_was(shape_name: String) -> bool:
	return _shape_name == shape_name

## @ace_condition
## @ace_name("Knows Shape")
## @ace_category("Touch Gestures")
## @ace_description("Whether a shape has been taught under this name.")
## @ace_icon("res://eventsheet_addons/touch_gestures/icon.svg")
## @ace_codegen_template("$TouchGesturesBehavior.knows_shape({shape_name})")
func knows_shape(shape_name: String) -> bool:
	return _shapes.has(shape_name)

## @ace_expression
## @ace_name("Swipe Direction")
## @ace_category("Touch Gestures")
## @ace_description("Which way the swipe went, as a word (inside On Swipe).")
## @ace_icon("res://eventsheet_addons/touch_gestures/icon.svg")
## @ace_codegen_template("$TouchGesturesBehavior.swipe_direction()")
func swipe_direction() -> String:
	return _swipe_direction

## @ace_expression
## @ace_name("Swipe Angle")
## @ace_category("Touch Gestures")
## @ace_description("The swipe's angle in degrees, 0 pointing right and counting clockwise the way screen coordinates do (inside On Swipe).")
## @ace_icon("res://eventsheet_addons/touch_gestures/icon.svg")
## @ace_codegen_template("$TouchGesturesBehavior.swipe_angle()")
func swipe_angle() -> float:
	return _swipe_angle

## @ace_expression
## @ace_name("Swipe Distance")
## @ace_category("Touch Gestures")
## @ace_description("How far the finger travelled, in pixels (inside On Swipe).")
## @ace_icon("res://eventsheet_addons/touch_gestures/icon.svg")
## @ace_codegen_template("$TouchGesturesBehavior.swipe_distance()")
func swipe_distance() -> float:
	return _swipe_distance

## @ace_expression
## @ace_name("Swipe Seconds")
## @ace_category("Touch Gestures")
## @ace_description("How long the swipe took, in seconds (inside On Swipe).")
## @ace_icon("res://eventsheet_addons/touch_gestures/icon.svg")
## @ace_codegen_template("$TouchGesturesBehavior.swipe_seconds()")
func swipe_seconds() -> float:
	return _swipe_seconds

## @ace_expression
## @ace_name("Swipe Speed")
## @ace_category("Touch Gestures")
## @ace_description("How fast the swipe was, in pixels per second - the number a flick's momentum should scale with (inside On Swipe).")
## @ace_icon("res://eventsheet_addons/touch_gestures/icon.svg")
## @ace_codegen_template("$TouchGesturesBehavior.swipe_speed()")
func swipe_speed() -> float:
	return _swipe_distance / maxf(_swipe_seconds, 0.001)

## @ace_expression
## @ace_name("Shape Name")
## @ace_category("Touch Gestures")
## @ace_description("The name of the shape that was just drawn (inside On Shape Drawn).")
## @ace_icon("res://eventsheet_addons/touch_gestures/icon.svg")
## @ace_codegen_template("$TouchGesturesBehavior.shape_name()")
func shape_name() -> String:
	return _shape_name

## @ace_expression
## @ace_name("Shape Closeness")
## @ace_category("Touch Gestures")
## @ace_description("How close the stroke was to the taught shape, 0 to 1, where 1 is an exact match (inside On Shape Drawn).")
## @ace_icon("res://eventsheet_addons/touch_gestures/icon.svg")
## @ace_codegen_template("$TouchGesturesBehavior.shape_closeness()")
func shape_closeness() -> float:
	return _shape_closeness

## @ace_expression
## @ace_name("Stroke Length")
## @ace_category("Touch Gestures")
## @ace_description("How far the finger travelled along the whole stroke, in pixels - the drawn line's length, not the distance between its ends.")
## @ace_icon("res://eventsheet_addons/touch_gestures/icon.svg")
## @ace_codegen_template("$TouchGesturesBehavior.stroke_length()")
func stroke_length() -> float:
	return _stroke_length(_stroke)

## @ace_expression
## @ace_name("Stroke Points")
## @ace_category("Touch Gestures")
## @ace_description("How many points the stroke gathered so far.")
## @ace_icon("res://eventsheet_addons/touch_gestures/icon.svg")
## @ace_codegen_template("$TouchGesturesBehavior.stroke_points()")
func stroke_points() -> int:
	return _stroke.size()

func _ready() -> void:
	load_shapes_from_library()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_start = event.position
			_touch_started_at = Time.get_ticks_msec() / 1000.0
			_stroke = PackedVector2Array([event.position])
			on_stroke_started.emit()
		else:
			_finish_stroke(event.position)
	elif event is InputEventScreenDrag:
		_stroke.append(event.position)

## @ace_hidden
func _finish_stroke(ended_at: Vector2) -> void:
	# The finger came up: a fast enough journey in one direction is a swipe, and anything else
	# that gathered enough points is a shape worth matching. One gesture per stroke, never both.
	var travelled: Vector2 = ended_at - _touch_start
	var held: float = Time.get_ticks_msec() / 1000.0 - _touch_started_at
	if travelled.length() >= swipe_min_distance and held <= swipe_max_seconds:
		_swipe_direction = _direction_of(travelled)
		_swipe_angle = rad_to_deg(travelled.angle())
		_swipe_distance = travelled.length()
		_swipe_seconds = held
		if debug_logging:
			print("[Touch Gestures] swipe ", _swipe_direction, " ", _swipe_distance, "px in ", _swipe_seconds, "s")
		on_swipe.emit()
		return
	if _stroke.size() < minimum_stroke_points or _shapes.is_empty():
		return
	var matched: Dictionary = _closest_shape(_stroke)
	if matched.is_empty():
		return
	_shape_name = str(matched.name)
	_shape_closeness = float(matched.closeness)
	if debug_logging:
		print("[Touch Gestures] shape ", _shape_name, " closeness ", _shape_closeness)
	on_shape_drawn.emit()

## @ace_hidden
func _direction_of(travelled: Vector2) -> String:
	# Which named direction a travel vector points in. Four bands by default; with eight-way on,
	# the eight bands the diagonals cut the same circle into.
	if not eight_way:
		if absf(travelled.x) > absf(travelled.y):
			return "right" if travelled.x > 0.0 else "left"
		return "down" if travelled.y > 0.0 else "up"
	var degrees: float = rad_to_deg(travelled.angle())
	var band: int = int(round((degrees + 180.0) / 45.0)) % 8
	return EIGHT_WAY_NAMES[band]

## @ace_hidden
func _write_through_to_library() -> void:
	# The one place the attached library is written. Teaching and forgetting both go through it,
	# so the library an author can see in the Inspector is never a step behind what the behaviour
	# knows - and emit_changed() marks the resource dirty, which is what makes the editor's own
	# Save write it out. Saving to DISK from a running game is still Save Shapes To Library: a
	# game cannot rely on an editor being open.
	if shape_library == null or not "shapes" in shape_library:
		return
	shape_library.shapes = _shapes.duplicate(true)
	shape_library.emit_changed()

## @ace_hidden
func _stroke_length(points: PackedVector2Array) -> float:
	# How far the finger travelled ALONG the stroke, which is what tells a long scribble from a
	# short one even when both start and end in the same place.
	var total: float = 0.0
	for index: int in range(1, points.size()):
		total += points[index].distance_to(points[index - 1])
	return total

## @ace_hidden
func _closest_shape(points: PackedVector2Array) -> Dictionary:
	# The taught shape a stroke is closest to, as {name, closeness}, or {} when nothing is close
	# enough. Each template is tried both ways round, so a circle drawn the other way still counts.
	var drawn: PackedVector2Array = _normalise(points)
	if drawn.is_empty():
		return {}
	var reversed_drawn: PackedVector2Array = drawn.duplicate()
	reversed_drawn.reverse()
	var best_name: String = ""
	var best_distance: float = 1e20
	for key: Variant in _shapes:
		var template: PackedVector2Array = _shapes[key]
		var distance: float = minf(_average_distance(drawn, template), _average_distance(reversed_drawn, template))
		if distance < best_distance:
			best_distance = distance
			best_name = str(key)
	if best_name.is_empty() or best_distance > shape_tolerance:
		return {}
	return {"name": best_name, "closeness": clampf(1.0 - best_distance / maxf(shape_tolerance, 0.001), 0.0, 1.0)}

## @ace_hidden
func _average_distance(a: PackedVector2Array, b: PackedVector2Array) -> float:
	# How far apart two normalised strokes are on average, point for point. Templates of a
	# different length are refused rather than stretched: a mismatched library is a bug to see.
	if a.size() != b.size() or a.is_empty():
		return 1e20
	var total: float = 0.0
	for index: int in a.size():
		total += a[index].distance_to(b[index])
	return total / float(a.size())

# Touch Gestures: attach under any node. It reads the touch events itself and fires On Swipe (direction, distance, seconds) and On Shape Drawn (name). Teach a shape by drawing it and calling Teach Shape From Stroke - the attached library is updated there and then. Save Shapes To Library is what writes that library to its file from a running game. On desktop, turn on Project Settings > Input Devices > Pointing > Emulate Touch From Mouse to try it with the mouse.
