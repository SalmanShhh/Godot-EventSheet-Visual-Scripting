# Pack source - camera_rail. The behaviour code this pack ships, as real GDScript: highlighted,
# checked and breakpointable here, and assembled into the pack by Lib.pack_from_source.
# Every #region, and the body of every top-level func, is one piece of the sheet; everything
# else is scaffolding the pack declares for itself at build time and never reads from here.
extends Camera2D

var host: Camera2D = null

#region block_1
# --- Designer knobs (tune in the Inspector) ---
## The route Fly Along walks when a row hands it no path of its own - the rail's own track.
@export var route: Path2D = null
## How long a shot lasts when a row asks for 0 seconds or less: the rail's default pace.
@export var shot_seconds: float = 3.0
## The curve a shot follows when a row names no ease of its own.
@export_enum("linear", "ease_in", "ease_out", "ease_in_out") var shot_ease: String = "ease_in_out"
## Make the rail's own camera the current one the moment the scene runs.
@export var current_on_ready: bool = true

# --- Internal state ---
# Which shot is running: "" for none, or "fly", "hold", "blend". ONE at a time on purpose - a
# rail is a shot list, and two shots driving one camera at once have no meaning.
var _mode: String = ""
# Seconds into the current shot, and how long it lasts. _progress is the fraction of the two,
# kept rather than recomputed so it survives the shot ending.
var _elapsed: float = 0.0
var _duration: float = 0.0
var _progress: float = 0.0
# The ease the current shot runs on - the row's word, or the Inspector's when the row named none.
var _ease: String = "linear"
# The Fly Along run: the route being walked and its baked length in pixels. Length is read once
# per run because baking a curve is not free and the curve does not change mid-shot.
var _flight_path: Path2D = null
var _flight_length: float = 0.0
# The Blend To run: where the rail's camera stood when the blend started, and the camera it is
# travelling onto. The start pose is captured once - reading it back each frame would blend the
# camera toward a target it is already moving toward, and it would never arrive.
var _blend_target: Camera2D = null
var _blend_from_transform: Transform2D = Transform2D.IDENTITY
var _blend_from_zoom: Vector2 = Vector2.ONE
# The camera this rail last handed the view to: Cut To writes it, and so does the end of a blend.
# It is written whether or not the node is in a tree, because make_current only means anything
# inside one - so this is the honest record of who the rail thinks is holding the view.
var _handed_to: Camera2D = null

## @ace_trigger
## @ace_name("On Shot Finished")
## @ace_description("Fires when a Fly Along run or a Hold reaches its end - the row that starts the next shot. Stop deliberately does not fire it, and a blend fires On Blend Finished instead.")
signal shot_finished

## @ace_trigger
## @ace_name("On Blend Finished")
## @ace_description("Fires the moment a Blend To lands on the other camera and hands the view over. The shot after this one belongs to that camera, not to the rail.")
signal blend_finished

## The eased position of a shot: the straight 0..1 fraction bent by the named curve. Anything
## this does not know is linear, so a misspelled word plays the shot rather than freezing it.
## @ace_hidden
func _eased(fraction: float, curve: String) -> float:
	var straight: float = clampf(fraction, 0.0, 1.0)
	match curve:
		"ease_in":
			return straight * straight
		"ease_out":
			return 1.0 - (1.0 - straight) * (1.0 - straight)
		"ease_in_out":
			return straight * straight * (3.0 - 2.0 * straight)
		_:
			return straight

## Puts the rail's camera at an eased fraction along the flight path. Points come out of the
## curve in the PATH node's own space, so they are converted through it rather than used raw.
## @ace_hidden
func _apply_flight(eased_fraction: float) -> void:
	if host == null or _flight_path == null or _flight_path.curve == null:
		return
	var point: Vector2 = _flight_path.curve.sample_baked(clampf(eased_fraction, 0.0, 1.0) * _flight_length)
	host.global_position = _flight_path.to_global(point)

## Puts the rail's camera an eased fraction of the way onto the blend target: the whole transform
## through interpolate_with (which turns the short way round rather than unwinding), and the zoom
## beside it, because a Camera2D's zoom is not part of its transform.
## @ace_hidden
func _apply_blend(eased_fraction: float) -> void:
	if host == null or _blend_target == null:
		return
	host.global_transform = _blend_from_transform.interpolate_with(_blend_target.global_transform, eased_fraction)
	host.zoom = _blend_from_zoom.lerp(_blend_target.zoom, eased_fraction)

## Ends whatever shot is running, silently. No trigger fires here - the callers that SHOULD
## announce an ending fire their own, which is what keeps Stop quiet and Hold loud.
## @ace_hidden
func _park() -> void:
	_mode = ""
	# A rail with no shot running has nothing to work out each frame, so an idle rail costs
	# nothing until the next Fly Along, Hold or Blend To starts one.
	set_process(false)

## The handover at the end of a blend: the rail's camera lands EXACTLY on the target rather than
## a float's width away from it, then the target takes the view and On Blend Finished fires.
## @ace_hidden
func _finish_blend() -> void:
	var handover: Camera2D = _blend_target
	if host != null and handover != null:
		host.global_transform = handover.global_transform
		host.zoom = handover.zoom
	_blend_target = null
	_park()
	if handover != null:
		_handed_to = handover
		if handover.is_inside_tree():
			handover.make_current()
	blend_finished.emit()
#endregion

func _ready() -> void:
	if current_on_ready and host != null:
		_handed_to = host
		host.make_current()
	# Nothing is running yet, so nothing is worth a frame yet.
	set_process(false)

func _process(delta: float) -> void:
	if _mode.is_empty():
		return
	_elapsed = minf(_elapsed + delta, _duration)
	# A shot of no length is already over: it reads as finished on its first frame rather than
	# dividing by zero, which is what makes "0 seconds" an honest way to spell "cut".
	var fraction: float = 1.0 if _duration <= 0.0 else _elapsed / _duration
	_progress = clampf(fraction, 0.0, 1.0)
	if _mode == "fly":
		_apply_flight(_eased(_progress, _ease))
	elif _mode == "blend":
		_apply_blend(_eased(_progress, _ease))
	if _progress < 1.0:
		return
	if _mode == "blend":
		_finish_blend()
		return
	_park()
	shot_finished.emit()

func fly_along(path: Path2D, seconds: float, ease: String) -> void:
	var walked: Path2D = path if path != null else route
	if walked == null or walked.curve == null or walked.curve.get_baked_length() <= 0.0:
		return
	route = walked
	_flight_path = walked
	_flight_length = walked.curve.get_baked_length()
	_blend_target = null
	_ease = shot_ease if ease.is_empty() else ease
	_duration = shot_seconds if seconds <= 0.0 else seconds
	_elapsed = 0.0
	_progress = 0.0
	_mode = "fly"
	set_process(true)
	# The first frame of the shot is the START of the route, not wherever the camera was parked.
	_apply_flight(0.0)

func cut_to(camera: Camera2D) -> void:
	if camera == null:
		return
	# A cut ends the shot it interrupts without announcing it - the announcement belongs to
	# whatever row asked for the cut.
	_blend_target = null
	_park()
	_handed_to = camera
	if camera.is_inside_tree():
		camera.make_current()

func blend_to(camera: Camera2D, seconds: float, ease: String) -> void:
	if camera == null or host == null:
		return
	_blend_target = camera
	_blend_from_transform = host.global_transform
	_blend_from_zoom = host.zoom
	_ease = shot_ease if ease.is_empty() else ease
	_duration = shot_seconds if seconds <= 0.0 else seconds
	_elapsed = 0.0
	_progress = 0.0
	_mode = "blend"
	set_process(true)

func hold(seconds: float) -> void:
	_blend_target = null
	_duration = shot_seconds if seconds <= 0.0 else seconds
	_elapsed = 0.0
	_progress = 0.0
	_mode = "hold"
	set_process(true)

func stop_rail() -> void:
	_blend_target = null
	_park()

func is_flying() -> bool:
	return _mode == "fly"

func rail_progress() -> float:
	return _progress
