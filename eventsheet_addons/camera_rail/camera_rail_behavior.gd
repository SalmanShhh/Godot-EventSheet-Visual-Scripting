## @ace_tags(camera, cinematic, path)
## @ace_category("Camera Rail")
## @ace_version(1.0.0)
@icon("res://eventsheet_addons/camera_rail/icon.svg")
class_name CameraRailBehavior
extends Node
## A shot list for a Camera2D: fly the camera along a drawn Path2D over a number of seconds, hold on a beat, blend onto another camera and hand the view over, or cut to one outright. On Shot Finished and On Blend Finished end every shot, so a cutscene is a chain of rows.

## The node this behavior acts on (its parent). Required host: Camera2D.
var host: Camera2D = null

func _enter_tree() -> void:
	host = get_parent() as Camera2D
	if host == null:
		push_warning("CameraRailBehavior behavior requires a Camera2D parent.")

## @ace_trigger
## @ace_name("On Shot Finished")
signal shot_finished
## @ace_trigger
## @ace_name("On Blend Finished")
signal blend_finished

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

## @ace_action
## @ace_featured
## @ace_name("Fly Along")
## @ace_category("Camera Rail")
## @ace_description("Flies the rail's camera along a drawn Path2D, start to end, over a number of seconds - the dolly shot. Leave the path empty to walk the route set in the Inspector, and 0 seconds to use the rail's default pace. On Shot Finished fires at the end of the run.")
## @ace_display_template("fly along [i]{path}[/i] over [b]{seconds}[/b]s, [b]{ease}[/b]")
## @ace_param_options(ease linear=Linear, ease_in=Ease in, ease_out=Ease out, ease_in_out=Ease in and out)
## @ace_icon("res://eventsheet_addons/camera_rail/icon.svg")
## @ace_codegen_template("$CameraRailBehavior.fly_along({path}, {seconds}, {ease})")
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

## @ace_action
## @ace_featured
## @ace_name("Cut To")
## @ace_category("Camera Rail")
## @ace_description("Hands the view to another camera immediately - the hard cut. Whatever shot the rail was running stops where it stands, without firing On Shot Finished, because the cut is the ending.")
## @ace_display_template("cut to [i]{camera}[/i]")
## @ace_icon("res://eventsheet_addons/camera_rail/icon.svg")
## @ace_codegen_template("$CameraRailBehavior.cut_to({camera})")
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

## @ace_action
## @ace_featured
## @ace_name("Blend To")
## @ace_category("Camera Rail")
## @ace_description("Travels the rail's camera onto another camera - position, rotation and zoom together - over a number of seconds, then hands the view to it. The soft cut between two framed shots. On Blend Finished fires at the handover.")
## @ace_display_template("blend onto [i]{camera}[/i] over [b]{seconds}[/b]s, [b]{ease}[/b]")
## @ace_param_options(ease linear=Linear, ease_in=Ease in, ease_out=Ease out, ease_in_out=Ease in and out)
## @ace_icon("res://eventsheet_addons/camera_rail/icon.svg")
## @ace_codegen_template("$CameraRailBehavior.blend_to({camera}, {seconds}, {ease})")
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

## @ace_action
## @ace_name("Hold")
## @ace_category("Camera Rail")
## @ace_description("Parks the rail for a number of seconds and then fires On Shot Finished - the beat between two moves. 0 seconds falls back to the rail's default pace.")
## @ace_display_template("hold this shot for [b]{seconds}[/b]s")
## @ace_icon("res://eventsheet_addons/camera_rail/icon.svg")
## @ace_codegen_template("$CameraRailBehavior.hold({seconds})")
func hold(seconds: float) -> void:
	_blend_target = null
	_duration = shot_seconds if seconds <= 0.0 else seconds
	_elapsed = 0.0
	_progress = 0.0
	_mode = "hold"
	set_process(true)

## @ace_action
## @ace_name("Stop Rail")
## @ace_category("Camera Rail")
## @ace_description("Halts the shot where it stands, WITHOUT firing On Shot Finished - a cutscene the player skipped, a chase that ended early. The next Fly Along, Hold or Blend To starts a fresh shot.")
## @ace_display_template("stop the rail")
## @ace_icon("res://eventsheet_addons/camera_rail/icon.svg")
## @ace_codegen_template("$CameraRailBehavior.stop_rail()")
func stop_rail() -> void:
	_blend_target = null
	_park()

## @ace_condition
## @ace_name("Is Flying")
## @ace_category("Camera Rail")
## @ace_description("True while a Fly Along run is actually travelling. A Hold and a blend are not flights, so this stays false through both - the gate for a skip prompt or a letterbox that only belongs on a dolly.")
## @ace_display_template("the rail is flying")
## @ace_icon("res://eventsheet_addons/camera_rail/icon.svg")
## @ace_codegen_template("$CameraRailBehavior.is_flying()")
func is_flying() -> bool:
	return _mode == "fly"

## @ace_expression
## @ace_name("Rail Progress")
## @ace_category("Camera Rail")
## @ace_description("How far through the current shot the rail has come, from 0 at its start to 1 when it finished - the progress bar of a cutscene, or the driver for a fade that tracks the move. It is the time through the shot, before the ease bends it, and it keeps its last value once the shot ends.")
## @ace_icon("res://eventsheet_addons/camera_rail/icon.svg")
## @ace_codegen_template("$CameraRailBehavior.rail_progress()")
func rail_progress() -> float:
	return _progress

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

## @ace_hidden
func _apply_flight(eased_fraction: float) -> void:
	if host == null or _flight_path == null or _flight_path.curve == null:
		return
	var point: Vector2 = _flight_path.curve.sample_baked(clampf(eased_fraction, 0.0, 1.0) * _flight_length)
	host.global_position = _flight_path.to_global(point)

## @ace_hidden
func _apply_blend(eased_fraction: float) -> void:
	if host == null or _blend_target == null:
		return
	host.global_transform = _blend_from_transform.interpolate_with(_blend_target.global_transform, eased_fraction)
	host.zoom = _blend_from_zoom.lerp(_blend_target.zoom, eased_fraction)

## @ace_hidden
func _park() -> void:
	_mode = ""
	# A rail with no shot running has nothing to work out each frame, so an idle rail costs
	# nothing until the next Fly Along, Hold or Blend To starts one.
	set_process(false)

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

# Camera Rail behavior: attach it under the Camera2D you want to direct. Fly Along walks that camera down a drawn Path2D over seconds, Hold parks it on a beat, Blend To travels onto another camera and hands the view over, and Cut To switches outright. On Shot Finished chains the next shot. Shake and zoom from the Juice pack ride on whichever camera is current, this one included. This pack is an event sheet - extend it by editing it.
