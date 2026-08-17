## @ace_tags(movement, path, curve)
## @ace_category("Path")
## @ace_version(1.0.0)
@icon("res://eventsheet_addons/follow_path/icon.svg")
class_name PathFollowBehavior
extends Node
## Walks the host Node2D along a drawn Path2D at a real speed - patrol routes, conveyors, camera dollies and tower-defence lanes. Once, Loop or Ping-pong, with optional rotate-to-face, and On Path Finished when a one-shot run reaches the end.

## The node this behavior acts on (its parent). Required host: Node2D.
var host: Node2D = null

func _enter_tree() -> void:
	host = get_parent() as Node2D
	if host == null:
		push_warning("PathFollowBehavior behavior requires a Node2D parent.")

## @ace_trigger
## @ace_name("On Path Finished")
signal path_finished

# --- Designer knobs (tune in the Inspector) ---
## The drawn route. Follow Path can hand over a different one at runtime; this is the
## starting route, and the one the editor gizmo draws.
@export var route: Path2D = null
## Pixels per second along the curve. Arc-length paced, so corners do not speed it up.
@export var travel_speed: float = 120.0
## What happens at the end: stop (and fire On Path Finished), start over, or walk back.
@export_enum("once", "loop", "pingpong") var loop_mode: String = "once"
## When on, the host turns to face the direction it is travelling along the curve.
@export var rotate_to_face: bool = false
## Start walking the route as soon as the scene runs, with no Follow Path row needed.
@export var auto_start: bool = false

# --- Internal state ---
# How far along the curve the host is, in PIXELS of arc length (not a 0..1 fraction):
# pacing by baked length is what keeps a tight corner from being crossed faster than a
# straight. _travel_direction is +1 walking forward, -1 on the way back in ping-pong.
var _distance: float = 0.0
var _travel_direction: int = 1
var _following: bool = false

func _process(delta: float) -> void:
	if not _following or host == null or route == null or route.curve == null:
		return
	var length: float = route.curve.get_baked_length()
	if length <= 0.0:
		return
	_distance += travel_speed * delta * float(_travel_direction)
	if _distance >= length:
		if loop_mode == "loop":
			_distance = fmod(_distance, length)
		elif loop_mode == "pingpong":
			# Reflect the overshoot rather than clamping it, so a fast mover keeps its pace
			# through the turn instead of pausing for a frame at the end.
			_distance = maxf(length - (_distance - length), 0.0)
			_travel_direction = -1
		else:
			_distance = length
			_following = false
			_apply_path_position()
			path_finished.emit()
			return
	elif _distance <= 0.0 and _travel_direction < 0:
		_distance = minf(-_distance, length)
		_travel_direction = 1
	_apply_path_position()

func _ready() -> void:
	if auto_start and route != null:
		follow_path(route, travel_speed, loop_mode)

## @ace_hidden
func _apply_path_position() -> void:
	if host == null or route == null or route.curve == null:
		return
	var sample: Transform2D = route.curve.sample_baked_with_rotation(clampf(_distance, 0.0, route.curve.get_baked_length()))
	host.global_position = route.to_global(sample.origin)
	if rotate_to_face:
		var facing: Vector2 = sample.x if _travel_direction >= 0 else -sample.x
		host.global_rotation = route.global_rotation + facing.angle()

## @ace_action
## @ace_name("Follow Path")
## @ace_description("Sends the host travelling along a drawn Path2D at a real speed - patrol routes, conveyor lanes, camera dollies, tower-defence lanes. Ping-pong walks it back and forth forever; Once fires On Path Finished at the end.")
## @ace_param_hint(path node)
## @ace_param_options(mode once=Once, loop=Loop, pingpong=Ping-pong)
## @ace_icon("res://eventsheet_addons/follow_path/icon.svg")
## @ace_codegen_template("$PathFollowBehavior.follow_path({path}, {speed}, {mode})")
func follow_path(path: Path2D, speed: float = 120.0, mode: String = "once") -> void:
	if path == null or path.curve == null or path.curve.get_baked_length() <= 0.0:
		return
	route = path
	travel_speed = speed
	loop_mode = mode
	_distance = 0.0
	_travel_direction = 1
	_following = true
	_apply_path_position()

## @ace_action
## @ace_name("Stop Following Path")
## @ace_description("Halts the run where it stands, WITHOUT firing On Path Finished - a stunned patroller, a conveyor switched off, a dolly interrupted by the player. Follow Path starts it again from the top.")
## @ace_icon("res://eventsheet_addons/follow_path/icon.svg")
## @ace_codegen_template("$PathFollowBehavior.stop_following_path()")
func stop_following_path() -> void:
	_following = false

## @ace_condition
## @ace_name("Is Following Path")
## @ace_description("True while the host is actually travelling - the gate for a walk animation, a conveyor's hum, or a Stop row that should only fire once.")
## @ace_icon("res://eventsheet_addons/follow_path/icon.svg")
## @ace_codegen_template("$PathFollowBehavior.is_following_path()")
func is_following_path() -> bool:
	return _following

## @ace_condition
## @ace_name("Is At Path End")
## @ace_description("True while the host is parked at the far end of its route right now. This is the STATE question, asked whenever a row is reached; for the moment of arrival use the On Path Finished trigger instead - it fires once, for free, with no per-frame checking.")
## @ace_icon("res://eventsheet_addons/follow_path/icon.svg")
## @ace_codegen_template("$PathFollowBehavior.is_at_path_end()")
func is_at_path_end() -> bool:
	if route == null or route.curve == null:
		return false
	return _distance >= route.curve.get_baked_length() - 0.5

## @ace_expression
## @ace_name("Progress Along Path")
## @ace_description("How far along its route the host has come, from 0 at the start to 1 at the end - a racer's lap bar, a delivery tracker, a boss phase keyed to how far the sweep has gone.")
## @ace_icon("res://eventsheet_addons/follow_path/icon.svg")
## @ace_codegen_template("$PathFollowBehavior.progress_along_path()")
func progress_along_path() -> float:
	if route == null or route.curve == null or route.curve.get_baked_length() <= 0.0:
		return 0.0
	return clampf(_distance / route.curve.get_baked_length(), 0.0, 1.0)

## @ace_expression
## @ace_name("Point On Path At")
## @ace_description("The world point a fraction of the way along a path (0 is the start, 1 is the end) - drive a camera dolly, a progress marker, or a preview ghost without moving anything.")
## @ace_param_hint(path node)
## @ace_icon("res://eventsheet_addons/follow_path/icon.svg")
## @ace_codegen_template("$PathFollowBehavior.point_on_path_at({path}, {progress})")
func point_on_path_at(path: Path2D, progress: float = 0.5) -> Vector2:
	if path == null or path.curve == null:
		return Vector2.ZERO
	return path.to_global(path.curve.sample_baked(clampf(progress, 0.0, 1.0) * path.curve.get_baked_length()))

## @ace_expression
## @ace_name("Direction Along Path At")
## @ace_description("Which way the path is heading a fraction of the way along it, as a direction one unit long - point a camera down the track, aim a spawned thing along the lane, or rotate a marker to match the curve.")
## @ace_param_hint(path node)
## @ace_icon("res://eventsheet_addons/follow_path/icon.svg")
## @ace_codegen_template("$PathFollowBehavior.direction_along_path_at({path}, {progress})")
func direction_along_path_at(path: Path2D, progress: float = 0.5) -> Vector2:
	if path == null or path.curve == null:
		return Vector2.RIGHT
	var sample: Transform2D = path.curve.sample_baked_with_rotation(clampf(progress, 0.0, 1.0) * path.curve.get_baked_length())
	return (Vector2.RIGHT.rotated(path.global_rotation + sample.x.angle())).normalized()

## @ace_expression
## @ace_name("Path Length")
## @ace_description("How long a route is in pixels, measured along the curve rather than corner to corner - divide by a speed to know how many seconds the trip takes, or space things evenly along it.")
## @ace_param_hint(path node)
## @ace_icon("res://eventsheet_addons/follow_path/icon.svg")
## @ace_codegen_template("$PathFollowBehavior.path_length({path})")
func path_length(path: Path2D) -> float:
	if path == null or path.curve == null:
		return 0.0
	return path.curve.get_baked_length()

## @ace_expression
## @ace_name("Nearest Point On Path")
## @ace_description("The point on a route closest to a world position - snap a dragged tower onto the lane, work out where a stray unit rejoins its patrol, or find the spot on the track a racer left.")
## @ace_param_hint(path node)
## @ace_icon("res://eventsheet_addons/follow_path/icon.svg")
## @ace_codegen_template("$PathFollowBehavior.nearest_point_on_path({path}, {point})")
func nearest_point_on_path(path: Path2D, point: Vector2) -> Vector2:
	if path == null or path.curve == null:
		return point
	return path.to_global(path.curve.get_closest_point(path.to_local(point)))

static func editor_gizmo_draw(params: Dictionary, host: Node2D, canvas: CanvasItem) -> void:
	# Editor-gizmo contract (select the host or this behavior in the editor): draws the route
	# in the 2D viewport, with a green dot at the start and an orange one at the end, so a
	# patrol reads at a glance and a route drawn backwards is obvious before you press play.
	var drawn_route: Path2D = params.get("route", null) as Path2D
	if drawn_route == null or drawn_route.curve == null or drawn_route.curve.get_point_count() < 2:
		return
	var baked: PackedVector2Array = drawn_route.curve.get_baked_points()
	if baked.size() < 2:
		return
	var points: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in baked:
		points.append(drawn_route.to_global(point))
	# The points are world-space; the canvas rides the host, so draw through the inverse.
	canvas.draw_set_transform_matrix(host.get_global_transform().affine_inverse())
	canvas.draw_polyline(points, Color(0.36, 0.78, 1.0, 0.9), 2.0)
	canvas.draw_circle(points[0], 4.0, Color(0.45, 1.0, 0.6, 0.9))
	canvas.draw_circle(points[points.size() - 1], 4.0, Color(1.0, 0.55, 0.35, 0.9))

# Follow Path behavior: walks the host along a drawn Path2D at a real speed (arc-length paced, so a tight corner does not speed it up). Follow Path starts a run, On Path Finished fires when a Once run reaches the end, and Is At Path End answers the other question - is it parked there right now. This pack is an event sheet - extend it by editing it.
