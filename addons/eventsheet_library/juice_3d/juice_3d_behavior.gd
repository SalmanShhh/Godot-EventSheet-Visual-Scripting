# @ace_tags(camera, juice, 3d)
# @ace_category("Juice 3D")
# @ace_expose_all(node)
# @ace_version(1.0.0)
@tool
@icon("res://eventsheet_addons/juice_3d/icon.svg")
class_name Juice3DBehavior
extends Node
## 3D camera game feel on the active Camera3D: trauma-based shake, weapon recoil, directional kicks from a world point, head bob, jitter, a held lean, FOV punch/zoom, host blink and punches, screen FX (vignette, chromatic kick, speed lines), varied one-shot audio, and eased score tickers. Every camera effect is an additive offset that is removed and re-applied around whoever owns the camera, so mouse look and animations keep the real pose and your aim is never touched. A Juice Player beside it plays its shake, zoom (the field of view), punch, flash, hitstop, slowmo and screen cards over a 3D view.
##
## Changes on its parent: modulate.

# @ace_hidden
## The node this behavior acts on. Empty: its parent.
@export var acts_on: Node3D = null

## The node this behavior acts on (Acts on, or else its parent). Required host: Node3D.
var host: Node3D = null

func _enter_tree() -> void:
	host = acts_on if acts_on != null else get_parent() as Node3D
	if host == null:
		push_warning("Juice3D Behavior needs a Node3D: put it under one, or set Acts on. This one is at " + str(get_path()) + ".")

@warning_ignore("unused_private_class_variable")
# @ace_hidden
## Plays in the editor. Your scene is not changed.
@export_tool_button("Preview", "Play") var _preview_start_button: Callable = _preview_start

@warning_ignore("unused_private_class_variable")
# @ace_hidden
## Plays in the editor. Your scene is not changed.
@export_tool_button("Stop preview", "Stop") var _preview_stop_button: Callable = _preview_stop

@warning_ignore("unused_private_class_variable")
# @ace_hidden
## Sets the effect off in the editor. Your scene is not changed.
@export_tool_button("Nudge", "ToolMove") var _preview_nudge_button: Callable = _preview_nudge

## The Engine meta key every previewing behaviour shares for its table of rest values, one entry per host.
const _PREVIEW_TABLE_META: String = "_eventsheets_previews"

## The key of a table entry's remembered rest values.
const _PREVIEW_REST: String = "rest"

## The key of a table entry's count of behaviours previewing on that host.
const _PREVIEW_USERS: String = "users"

## The key of a table entry's host values as the preview last left them, to tell a hand edit from the preview's own writes.
const _PREVIEW_SEEN: String = "seen"

## The Engine meta key that holds the editor's own low-processor setting while any preview plays, so it can be put back.
const _PREVIEW_IDLE_META: String = "_eventsheets_previews_low_processor"

## True while Preview is playing in the editor. Always false in a running game.
var _previewing: bool = false

## Counts the Preview presses, so a repeat loop from an earlier press ends.
var _preview_run: int = 0

## This behaviour's own unsaved values from when Preview started, put back on Stop.
var _preview_own: Dictionary = {}

## True when the host's values were noted since the last check for a hand edit, so the note is fresh enough to trust.
var _preview_noted: bool = false

func _validate_property(property: Dictionary) -> void:
	if property.name == "_preview_start_button" and _previewing:
		property.usage = PROPERTY_USAGE_NONE
	elif property.name == "_preview_stop_button" and not _previewing:
		property.usage = PROPERTY_USAGE_NONE

func _notification(what: int) -> void:
	if not Engine.is_editor_hint() or not _previewing:
		return
	if what == NOTIFICATION_EXIT_TREE:
		_preview_stop()
	elif what == NOTIFICATION_EDITOR_PRE_SAVE:
		_preview_keep_hand_edits()
		_preview_put_back(host, _preview_rest_of(host))
		_preview_note_seen()

static func _preview_values(node: Object, own: bool) -> Dictionary:
	var values: Dictionary = {}
	for info: Dictionary in node.get_property_list():
		var usage: int = info.usage
		var prop_name: String = info.name
		if info.type == TYPE_NIL or info.type == TYPE_CALLABLE or prop_name.contains("/") or prop_name == "script" or prop_name == "owner":
			continue
		if own:
			if not (usage & PROPERTY_USAGE_SCRIPT_VARIABLE) or (usage & PROPERTY_USAGE_STORAGE) or prop_name.begins_with("_preview") or prop_name == "host":
				continue
		elif not (usage & PROPERTY_USAGE_STORAGE):
			continue
		var value: Variant = node.get(prop_name)
		values[prop_name] = value.duplicate() if (value is Array or value is Dictionary) else value
	return values

static func _preview_put_back(node: Object, values: Dictionary) -> void:
	if node == null or not is_instance_valid(node):
		return
	for prop_name: String in values:
		var now: Variant = node.get(prop_name)
		var rest: Variant = values[prop_name]
		if typeof(now) != typeof(rest) or now != rest:
			node.set(prop_name, rest)

static func _preview_table() -> Dictionary:
	if not Engine.has_meta(_PREVIEW_TABLE_META):
		Engine.set_meta(_PREVIEW_TABLE_META, {})
	return Engine.get_meta(_PREVIEW_TABLE_META)

func _preview_rest_of(node: Object) -> Dictionary:
	if node == null:
		return {}
	var entry: Dictionary = _preview_table().get(node.get_instance_id(), {})
	return entry.get(_PREVIEW_REST, {})

func _preview_start() -> void:
	if not Engine.is_editor_hint() or _previewing or host == null or not is_inside_tree():
		return
	var table: Dictionary = _preview_table()
	var key: int = host.get_instance_id()
	if table.has(key):
		_preview_put_back(host, table[key][_PREVIEW_REST])
		table[key][_PREVIEW_USERS] += 1
	else:
		table[key] = {_PREVIEW_REST: _preview_values(host, false), _PREVIEW_USERS: 1}
	_preview_own = _preview_values(self, true)
	_previewing = true
	_preview_run += 1
	notify_property_list_changed()
	_preview_kick()
	_preview_watch_begin()

## Starts watching for a hand edit: notes the host as it stands now, then again just before each drawn frame, and
## checks at the start of each physics and process frame, before anything has written to the host that frame.
func _preview_watch_begin() -> void:
	if not Engine.has_meta(_PREVIEW_IDLE_META):
		Engine.set_meta(_PREVIEW_IDLE_META, OS.low_processor_usage_mode)
		OS.low_processor_usage_mode = false
	_preview_note_seen()
	var tree: SceneTree = get_tree()
	if not RenderingServer.frame_pre_draw.is_connected(_preview_note_seen):
		RenderingServer.frame_pre_draw.connect(_preview_note_seen)
	if tree != null and not tree.physics_frame.is_connected(_preview_watch):
		tree.physics_frame.connect(_preview_watch)
	if tree != null and not tree.process_frame.is_connected(_preview_watch):
		tree.process_frame.connect(_preview_watch)

func _preview_watch_end() -> void:
	_preview_noted = false
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if RenderingServer.frame_pre_draw.is_connected(_preview_note_seen):
		RenderingServer.frame_pre_draw.disconnect(_preview_note_seen)
	if tree != null and tree.physics_frame.is_connected(_preview_watch):
		tree.physics_frame.disconnect(_preview_watch)
	if tree != null and tree.process_frame.is_connected(_preview_watch):
		tree.process_frame.disconnect(_preview_watch)

## Writes the host's values down as the preview leaves them. Taken just before a frame is drawn, it is what the
## next frame's check compares the host with.
func _preview_note_seen() -> void:
	if not is_instance_valid(host):
		return
	var entry: Dictionary = _preview_table().get(host.get_instance_id(), {})
	if entry.is_empty():
		return
	entry[_PREVIEW_SEEN] = _preview_values(host, false)
	_preview_noted = true

## Takes anything on the host that is not what the preview last left there as the host's new resting value, so
## Stop and a save keep it. Returns whether there was any. A note that has not been refreshed since the last check
## is stale and proves nothing, so then there is nothing to keep.
func _preview_keep_hand_edits() -> bool:
	if not _preview_noted or not is_instance_valid(host):
		return false
	var entry: Dictionary = _preview_table().get(host.get_instance_id(), {})
	if not entry.has(_PREVIEW_SEEN):
		return false
	var seen: Dictionary = entry[_PREVIEW_SEEN]
	var rest: Dictionary = entry.get(_PREVIEW_REST, {})
	var kept: bool = false
	for prop_name: String in seen:
		var now: Variant = host.get(prop_name)
		var before: Variant = seen[prop_name]
		if typeof(now) != typeof(before) or now != before:
			rest[prop_name] = now.duplicate() if (now is Array or now is Dictionary) else now
			kept = true
	return kept

## Runs at the start of every physics and process frame, once per drawn frame: a hand edit ends the preview and keeps the edit.
func _preview_watch() -> void:
	if not _previewing or not _preview_noted:
		return
	if _preview_keep_hand_edits():
		_preview_stop()
	_preview_noted = false

func _preview_stop() -> void:
	if not _previewing:
		return
	_preview_keep_hand_edits()
	_preview_watch_end()
	_previewing = false
	_preview_kill_tweens()
	_preview_put_back(self, _preview_own)
	var table: Dictionary = _preview_table()
	var key: int = host.get_instance_id() if host != null else 0
	if table.has(key):
		_preview_put_back(host, table[key][_PREVIEW_REST])
		table[key][_PREVIEW_USERS] -= 1
		if table[key][_PREVIEW_USERS] <= 0:
			table.erase(key)
	if table.is_empty() and Engine.has_meta(_PREVIEW_IDLE_META):
		OS.low_processor_usage_mode = Engine.get_meta(_PREVIEW_IDLE_META)
		Engine.remove_meta(_PREVIEW_IDLE_META)
	notify_property_list_changed()

func _preview_kill_tweens() -> void:
	for info: Dictionary in get_property_list():
		if not (info.usage & PROPERTY_USAGE_SCRIPT_VARIABLE) or info.name == "host":
			continue
		var held: Variant = get(info.name)
		var live_tweens: Array = []
		if held is Tween:
			live_tweens.append(held)
		elif held is Dictionary:
			live_tweens.append_array((held as Dictionary).values())
		elif held is Array:
			live_tweens.append_array(held)
		for candidate: Variant in live_tweens:
			if candidate is Tween and (candidate as Tween).is_valid():
				(candidate as Tween).kill()

func _preview_kick() -> void:
	pass

func _preview_nudge() -> void:
	_preview_start()
	if not _previewing:
		return
	punch_scale(0.4, 0.6)

# @ace_trigger
# @ace_name("On Punch Finished")
signal punch_finished
# @ace_trigger
# @ace_name("On Ticker Finished")
signal ticker_finished(ticker_name: String)
# @ace_trigger
# @ace_name("On Shake Stopped")
signal shake_stopped
# @ace_trigger
# @ace_name("On Lean Finished")
signal lean_finished
# @ace_trigger
# @ace_name("On Zoom Finished")
signal zoom_finished

# --- Choices (the words the choice parameters take; saved scenes keep them) ---
## The word reducing.
const MODE_REDUCING := "reducing"
## The word constant.
const MODE_CONSTANT := "constant"

# --- Designer knobs (tune the FEEL in the Inspector) ---
## Peak shake rotation, in degrees, at full trauma (pitch/yaw; roll uses a third of it).
@export_range(0.0, 30.0, 0.5) var max_shake_degrees: float = 4.0
## Peak positional shake, in metres, at full trauma (0 = rotation-only shake).
@export_range(0.0, 1.0, 0.01) var max_shake_offset: float = 0.05
## Trauma lost per second - higher means shorter, snappier shakes.
@export_range(0.1, 10.0, 0.1) var shake_decay: float = 1.4
## How fast the shake/jitter noise scrolls (the wobble rate).
@export_range(1.0, 60.0, 1.0) var shake_frequency: float = 25.0
## How fast a Recoil kick re-centres, in degrees per second.
@export_range(1.0, 360.0, 1.0) var recoil_recovery: float = 30.0
## How fast an FOV Punch returns to normal, in degrees per second.
@export_range(5.0, 500.0, 5.0) var fov_recovery: float = 60.0
## How fast a positional Kick (Kick Camera Away From Point) re-centres, in metres per second.
@export_range(0.05, 20.0, 0.05) var kick_recovery: float = 0.6

# --- Internal state ---
## Current shake strength from 0 to 1; it decays over time.
var trauma: float = 0.0
## Running time that drives the shake noise.
var shake_time: float = 0.0
## True while a shake is running.
var _shaking: bool = false
## Noise generator behind the shake.
var _noise: FastNoiseLite = null
## Camera the effects are told to use instead of the current one.
var _camera_override: Camera3D = null
# The camera the offsets were last applied to - offsets are pulled off it before anything
# else, so a camera switch mid-effect can never corrupt the new camera's pose.
## The camera the effects last worked on.
var _last_camera: Camera3D = null
# What we added to the camera last frame (subtracted again at the top of every tick).
## Position offset the effects added to the camera this frame.
var _applied_position: Vector3 = Vector3.ZERO
## Rotation offset the effects added to the camera this frame.
var _applied_rotation: Vector3 = Vector3.ZERO
## Field of view change the effects added this frame.
var _applied_fov: float = 0.0
## Upward recoil kick, in radians.
var _recoil_pitch: float = 0.0
## Sideways recoil kick, in radians.
var _recoil_yaw: float = 0.0
## True while the walking bob is running.
var _bob_active: bool = false
## Running time that drives the bob.
var _bob_time: float = 0.0
## How far the bob moves, in metres.
var _bob_amplitude: float = 0.06
## How fast the bob cycles, in cycles per second.
var _bob_frequency: float = 2.2
## True while the jitter is running.
var _jitter_active: bool = false
## Running time that drives the jitter.
var _jitter_time: float = 0.0
## How far the jitter moves, in metres.
var _jitter_offset: float = 0.02
## How far the jitter rolls the camera, in degrees.
var _jitter_roll: float = 0.5
## Current lean angle of the camera, in radians.
var _lean_roll: float = 0.0
## The tween easing the lean.
var _lean_tween: Tween = null
## Field of view kick being applied, in degrees.
var _fov_kick: float = 0.0
# Positional camera kick (Kick Camera Away From Point) - recovers like recoil.
## Current positional kick of the camera.
var _kick_vec: Vector3 = Vector3.ZERO
# Blink state (visibility strobe - the 3D take on invulnerability frames).
## True while the host is blinking.
var _blink_active: bool = false
## Running time that drives the blink.
var _blink_time: float = 0.0
## Blinks per second.
var _blink_rate: float = 8.0
# Punch state (kick out, spring back; rest captured per gesture so repeats never drift).
## The host's scale before any effect changed it.
var _base_scale3: Vector3 = Vector3.ONE
## The tween running the position punch.
var _punch_pos_tween: Tween = null
## Position to settle back to after the punch.
var _punch_pos_rest: Vector3 = Vector3.ZERO
# Eased tickers (Count To): name -> displayed value / target / driving tween.
## Number tickers by name, showing a value that counts toward its target.
var _tickers: Dictionary = {}
## The value each ticker is counting toward.
var _ticker_targets: Dictionary = {}
## The tween driving each ticker.
var _ticker_tweens: Dictionary = {}
## The camera the effects drive: an explicit override (Use Camera), else the active Camera3D.
func _camera() -> Camera3D:
	if _camera_override != null and is_instance_valid(_camera_override):
		return _camera_override
	var vp: Viewport = get_viewport()
	if vp == null:
		return null
	return vp.get_camera_3d()

# --- Channels: a shake said once, and heard by everything listening ---
#
# A CHANNEL IS A GROUP. Nothing is invented here: Shake Channel is one call_group, a listener is
# a node in that group, and the Node dock already shows which groups a node is in. That is why a
# collapse can reach every hanging lamp in a level without a single reference between them.

## Channel target word: shake the camera the player looks through.
const CHANNEL_SHAKE_CAMERA: String = "the camera"
## Shake target word: shake the node itself.
const CHANNEL_SHAKE_NODE: String = "this node"
## Shake target word: shake the whole screen.
const CHANNEL_SHAKE_SCREEN: String = "the screen"

# One answer per node rather than one per
# channel: a lamp that rattles for the quake channel and the truck channel rattles the same way,
# and a node that wants to do two different things is two nodes.
## Which shake target this listener answers with - the camera, this node or the screen - for every channel.
var _channel_shakes: String = CHANNEL_SHAKE_CAMERA

## Strength of the channel shake in progress; the camera reads it as trauma from 0 to 1.
var _channel_amount: float = 0.0
## Total seconds of the channel effect in progress.
var _channel_span: float = 0.0
## Seconds left on the channel effect.
var _channel_left: float = 0.0
## Offset to settle back to when the channel effect ends.
var _channel_rest: Vector3 = Vector3.ZERO
## True while a channel effect is moving the host.
var _channel_driving: bool = false

# --- Position Shake: an object's own position, shaken and put back ---
# A Position Shake moves ONLY the position of a node - never the camera, the rotation or the scale. It is an offset that is
# added to the position when a frame is built and taken off again once that frame has been drawn, so the object is at its own
# place for every script and every physics step, ends exactly where it would have been, and keeps whatever motion it had.
# Two shakes at once add. A Punch Position at the same time still works.

## The position shakes running now: the node each one moves, how hard, how long, the shape, the weights and the jump it is on.
var _position_shakes: Array[Dictionary] = []

## What is added to each node's position right now, by node: the offset and the position it was left at, so it can be taken off again.
var _position_added: Dictionary = {}

## Whether the draw hook that takes the offsets off is connected.
var _position_hooked: bool = false

## How many times a second a position shake jumps to a new place when nothing says otherwise.
const POSITION_SHAKE_JUMPS: float = 30.0
# @ace_hidden
## The same shake on any 3D node, scaled by `at_strength` (how a Juice Player card passes its strength). The
## effect-strength dial scales the amount, and while no flashing is on the amount is held under the ceiling and the time over
## the floor, so a player who asked for calm gets a calmer shake and not a jitter strobe. `weights` is how much of the amount
## goes along x, y and z. Gives back true when it took the shake, false when the node is not one it can shake.
func shake_position_on(node: Node, amount: float, seconds: float, fade_in: bool = false, fade_out: bool = true,
		curve: Curve = null, weights: Vector3 = Vector3.ONE, jumps_per_second: float = POSITION_SHAKE_JUMPS, at_strength: float = 1.0) -> bool:
	if not (node is Node3D) or amount <= 0.0 or at_strength <= 0.0:
		return false
	var size: float = amount * at_strength * maxf(float(Engine.get_meta("effect_strength", 1.0)), 0.0)
	if bool(Engine.get_meta(NO_FLASHING_META, false)):
		size *= STEP_FLASH_CEILING
	_position_shakes.append({"node": node, "amount": size, "seconds": maxf(_step_seconds(seconds), STEP_NATURAL_SECONDS),
		"elapsed": 0.0, "fade_in": fade_in, "fade_out": fade_out, "curve": curve, "x": weights.x, "y": weights.y, "z": weights.z,
		"rate": maxf(jumps_per_second, 0.1), "jump": -1, "way": Vector3.ZERO})
	_position_hook()
	set_process(true)
	return true

# --- Timed shakes: a shake that lasts the Seconds it was given and has a shape ---
# Shake adds trauma, which fades at Shake Decay whatever length a card says; a timed shake lasts exactly its length and has a
# shape (fade in, fade out, both, neither, or a curve). The shape is applied to the amount BEFORE the camera mixer squares
# it, timed shakes add to the trauma and to each other up to the same top of 1, and only the trauma decays.

## The timed shakes running now: the amount, the length, the clock and the shape of each.
var _timed_shakes: Array[Dictionary] = []

## What the camera mixer drew its shake with on the last frame, before squaring: the trauma plus every timed shake, held to 1.
var _shake_level: float = 0.0

# The tint overlay: a top CanvasLayer ColorRect built on first use - the screen
# wash for damage reds, poison greens, night blues. Strength IS the opacity.
## Screen layer that holds the tint.
var _tint_overlay: CanvasLayer = null
## Full-screen rectangle that shows the tint.
var _tint_rect: ColorRect = null

# The screen-FX overlay: one full-screen shader with four dials (vignette, chromatic
# aberration, the chromatic shake's directional split, radial speed lines) built on first use,
# hidden whenever every dial is 0.
## Screen layer that holds the full-screen effects.
var _fx_layer: CanvasLayer = null
## Full-screen rectangle the effect shader draws on.
var _fx_rect: ColorRect = null
## Shader material that draws the vignette and colour fringing.
var _fx_material: ShaderMaterial = null
## The tween easing the vignette.
var _vignette_tween: Tween = null
## The tween easing the colour fringing.
var _chroma_tween: Tween = null
## Shader source for the vignette and colour fringing.
const _FX_SHADER: String = """
shader_type canvas_item;
uniform sampler2D screen_texture: hint_screen_texture, filter_linear_mipmap;
uniform float vignette_strength = 0.0;
uniform vec4 vignette_color: source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float chroma_strength = 0.0;
uniform vec2 chroma_shift = vec2(0.0, 0.0);
uniform float chroma_intensity = 0.0;
uniform float speed_lines = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 centered = uv - vec2(0.5);
	vec2 chroma_offset = centered * chroma_strength * 0.03;
	vec3 col = vec3(
		texture(screen_texture, uv + chroma_offset).r,
		texture(screen_texture, uv).g,
		texture(screen_texture, uv - chroma_offset).b);
	// The SHAKE's split, on top of the kick's: the kick pulls the channels apart outwards from
	// the middle, while this slides the whole screen's channels along one direction that moves.
	// Red leads, green trails the other way, blue overshoots four times as far, and a fourth,
	// nearer tap ghosts behind the three - the smear that reads as impact rather than as a lens.
	// Behind a gate, because those are FOUR more reads of the screen per pixel and the overlay
	// is also on screen for a vignette or for speed lines, with no shake anywhere near it.
	if (chroma_intensity > 0.0) {
		vec3 shaken = vec3(
			texture(screen_texture, uv + chroma_shift).r,
			texture(screen_texture, uv - chroma_shift).g,
			texture(screen_texture, uv + chroma_shift * 4.0).b);
		shaken = mix(shaken, texture(screen_texture, uv + chroma_shift * 1.25).rgb, 0.25);
		col = mix(col, shaken, clamp(chroma_intensity, 0.0, 1.0));
	}
	float vignette = smoothstep(0.35, 1.0, length(centered) * 1.5) * vignette_strength;
	col = mix(col, vignette_color.rgb, clamp(vignette, 0.0, 1.0));
	float angle = atan(centered.y, centered.x);
	float streak = step(0.86, fract(sin(floor(angle * 60.0) + floor(TIME * 24.0) * 7.0) * 43758.545));
	float ring = smoothstep(0.2, 0.65, length(centered));
	col = mix(col, vec3(1.0), streak * ring * clamp(speed_lines, 0.0, 1.0) * 0.65);
	COLOR = vec4(col, 1.0);
}
"""

# --- Chromatic shake: a directional channel split that moves while it lasts ---

# A shake told which way to
# point keeps that direction, so the noise lands on the AMOUNT instead and the split breathes
# along one line rather than swinging around the screen.
## How much of the peak a fixed-angle shake can lose to the wander.
const CHROMA_SHAKE_WANDER: float = 0.35

# The Engine meta the whole project keeps the no-flashing answer in - the one the built-in Set
# No Flashing row writes. A game carrying that row needs nothing else: the split comes out half
# as wide and wanders half as fast, which is the same shake without the strobe. This is the
# pack's ONE name for that meta, read by everything here that has to obey it.
## Engine meta key holding the project's no-flashing choice.
const NO_FLASHING_META: StringName = &"no_flashing"

# The magnitude the screen is showing right now, in pixels - what the expression answers with.
## Current strength of the colour-fringe shake.
var _chroma_shake_magnitude: float = 0.0
# The magnitude the gesture was fired at, before falloff, wander and the no-flashing halving.
## Strength the colour-fringe shake started at.
var _chroma_shake_from: float = 0.0
## Seconds the colour-fringe shake lasts.
var _chroma_shake_duration: float = 0.3
## Seconds the colour-fringe shake has run.
var _chroma_shake_elapsed: float = 0.0
# True for the "constant" mode: hold the amount flat for the duration, then stop dead.
## True while the colour-fringe shake is held at full strength.
var _chroma_shake_hold: bool = false
# The direction in degrees, or below zero for a direction that wanders with the noise.
## Direction of the fringe in degrees; below 0 lets it wander with the noise.
var _chroma_shake_angle: float = -1.0
# The noise clock, advanced by delta so the wander rides the game's own time - and advanced
# ALREADY SCALED BY THE RATE, which is what lets the rate change mid-shake. Keeping a raw clock
# and multiplying the whole of it by the rate at sampling time would move every past frame's
# sample too, so turning no flashing on would teleport the split to an unrelated direction in
# that one frame: a strobe delivered by the setting that exists to prevent strobing.
## Running phase that drives the colour-fringe shake.
var _chroma_shake_phase: float = 0.0
## True while the colour-fringe shake is running.
var _chroma_shake_active: bool = false

# --- Cards played through this node: what a Juice Player calls ---
#
# A Juice Player beside this node plays its shake, zoom, punch, flash, hitstop, slowmo and screen cards through
# moment_step, the call the 2D Juice node answers too. Each word has its meaning over a 3D view: zoom is the
# field of view, punch is the scale of the Node3D, flash tints a 3D sprite or label and otherwise the whole
# screen. A scene that holds BOTH Juice nodes beside a player keeps playing through the 2D one.

## Highest amount a card may reach while no flashing is on, from 0 to 1. The 2D Juice node holds its cards to the same number.
const STEP_FLASH_CEILING: float = 0.3
## Shortest a card may last while no flashing is on, in seconds.
const STEP_FLASH_FLOOR_SECONDS: float = 0.4
## The least an effect lasts when its card asks for nothing, in seconds.
const STEP_NATURAL_SECONDS: float = 0.05
## The step words whose amount is how much of something a player SEES: only these are held to the ceiling.
const STEP_AMPLITUDE_VERBS: PackedStringArray = ["shake", "flash", "punch", "shockwave",
		"chromatic", "pulse", "hold"]

## True while a hit stop is freezing time.
var _hitstop_active: bool = false
## Time scale to put back when the hit stop ends.
var _hitstop_prev_scale: float = 1.0
## The tween that holds a slowmo and eases the time scale back to normal.
var _slowmo_tween: Tween = null
## The tween bringing the field of view to a zoom card's value.
var _zoom_tween: Tween = null
## The tween springing the host's scale back after a punch.
var _punch_scale_tween: Tween = null
## The tween fading a flash away, on the host's tint or on the whole screen.
var _flash_tween: Tween = null
## The tint a flash on the host fades back to.
var _flash_rest: Color = Color.WHITE
## True while a flash is washing the whole screen rather than tinting the host.
var _flash_on_screen: bool = false
## What each Juice Player's play first found, by player: the field of view, the scale, the tint and the time scale.
var _step_rest: Dictionary = {}
## What each Juice Player's play leaves behind when it is stopped: where its cards would have put each value.
var _step_ends: Dictionary = {}

# Asking the tree for a group is a
# dictionary read, so a game that has no post stack at all pays nothing to be told so again.
## Group the screen effects layer joins so moments can find it.
const POST_STACK_GROUP: StringName = &"screen_fx_post_stack"

# The post stack layer is looked up lazily, and only a found layer is remembered:
# a game whose post stack arrives after the first beat has played - a level that adds its own
# effects, a pause screen built on demand - would otherwise be missed for ever, and every later
# moment would quietly fall back to this pack's own overlay.
## The Screen FX layer this game has, once one has been FOUND.
var _moment_screen: CanvasLayer = null

## The methods a moment calls on the Screen FX layer; one that lacks any is reported once, by name.
const SCREEN_FX_METHODS: PackedStringArray = ["shockwave", "chromatic_pulse", "pulse_post_effect", "post_strength", "add_post_effect", "fade_post_strength"]

## True once the Screen FX layer has been checked for the methods a moment calls.
var _moment_screen_checked: bool = false

# The missing-post-stack warning is said once per scene rather than once per step: a moment that plays on
# every hit would otherwise write the same sentence sixty times a second, which is how a warning
# stops being read at all.
## Whether the missing post stack has already been mentioned in the current scene.
var _moment_told_screen: bool = false
## Scene in which the missing post stack was last mentioned, so it is said once per scene.
var _moment_told_scene: Node = null
# @ace_hidden
## The Screen FX layer this game has, or null. THE POINT OF LOOKING is that a moment must not build a
## second full-screen rectangle of its own: a hit that reads the whole screen twice costs twice as
## much and looks wrong wherever the two overlap. A game with no Screen FX layer falls back to this
## pack's own overlay for the two effects it can draw.
##
## ONLY A FOUND LAYER IS KEPT, and a layer that has left the tree is asked for again: a miss costs
## one group lookup, so re-asking on the next beat is cheaper than the mistake of never asking
## again. The layer must be in the group above, which the Screen FX pack's own layer joins as it
## enters the tree - a hand-built post layer joins it in one line to be found the same way.
func _moment_screen_fx() -> CanvasLayer:
	if _moment_screen != null and is_instance_valid(_moment_screen) and _moment_screen.is_inside_tree():
		return _moment_screen
	_moment_screen = null
	if not is_inside_tree():
		return null
	var found: Node = get_tree().get_first_node_in_group(POST_STACK_GROUP)
	if found is CanvasLayer and found.has_method("pulse_post_effect"):
		_moment_screen = found as CanvasLayer
		if not _moment_screen_checked:
			_moment_screen_checked = true
			var missing: PackedStringArray = PackedStringArray()
			for method: String in SCREEN_FX_METHODS:
				if not found.has_method(method):
					missing.append(method)
			if not missing.is_empty():
				push_warning("Moment: the post stack layer %s has no %s - a step that needs one will not work." % [found.name, ", ".join(missing)])
	return _moment_screen

func _ready() -> void:
	tree_exiting.connect(_on_tree_exiting)
	_noise = FastNoiseLite.new()
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 1.0
	_noise.seed = randi()
	if host is Node3D:
		_base_scale3 = (host as Node3D).scale
	# No shake, no kick, no bob on the first frame, and every verb that starts one turns
	# processing back on - so an idle Juice 3D costs nothing per frame.
	set_process(false)

func _on_tree_exiting() -> void:
	# The global time scale is put back ONLY if this node is the one holding it away from 1: an unrelated node
	# leaving the tree must not snap a slowmo or a game-owned pause back to normal.
	var __owned_time := _hitstop_active or (_slowmo_tween != null and is_instance_valid(_slowmo_tween) and _slowmo_tween.is_running())
	_hitstop_active = false
	if _slowmo_tween != null and is_instance_valid(_slowmo_tween):
		_slowmo_tween.kill()
	_slowmo_tween = null
	if __owned_time:
		Engine.time_scale = 1.0
	_unapply()

func _process(delta: float) -> void:
	if Engine.is_editor_hint() and not _previewing:
		return
	_position_shake_step(delta)
	_chroma_shake_step(delta)
	# Effect STATE advances camera-or-not (headless-safe); only the apply needs a camera.
	var timed_level: float = _tick_timed_shakes(delta)
	var shaking_now: bool = trauma > 0.0 or timed_level > 0.0 or not _timed_shakes.is_empty()
	if trauma > 0.0:
		trauma = maxf(trauma - shake_decay * delta, 0.0)
	if shaking_now:
		shake_time += delta
		_shaking = true
	_shake_level = clampf(trauma + timed_level, 0.0, 1.0)
	if _shake_level <= 0.0 and _timed_shakes.is_empty() and _shaking:
		_shaking = false
		shake_stopped.emit()
	_recoil_pitch = move_toward(_recoil_pitch, 0.0, recoil_recovery * delta)
	_recoil_yaw = move_toward(_recoil_yaw, 0.0, recoil_recovery * delta)
	_fov_kick = move_toward(_fov_kick, 0.0, fov_recovery * delta)
	_kick_vec = _kick_vec.move_toward(Vector3.ZERO, kick_recovery * delta)
	if _blink_active and host is Node3D:
		_blink_time += delta * _blink_rate
		(host as Node3D).visible = fmod(_blink_time, 1.0) < 0.5
	if _bob_active:
		_bob_time += delta * _bob_frequency
	if _jitter_active:
		_jitter_time += delta * shake_frequency
	# A channel shake is drawn here, in a tick this behaviour was already paying for rather than
	# in a timer of its own.
	_channel_tick(delta)
	# Additive apply: pull last frame's offsets off first, so the pose the controller wrote
	# this frame is the base - the effects ride on TOP of mouse look, never against it.
	_unapply()
	# Every effect has settled and last frame's offsets are already back off the camera, so the
	# next frame has nothing to do: stop paying for the tick until a verb starts another effect.
	# A held lean is NOT settled - it is re-applied after every unapply, so it keeps the tick
	# alive, as does the tween still writing it.
	var kicks_busy: bool = _recoil_pitch != 0.0 or _recoil_yaw != 0.0 or _fov_kick != 0.0 or _kick_vec != Vector3.ZERO
	var effects_busy: bool = trauma > 0.0 or not _timed_shakes.is_empty() or _bob_active or _jitter_active or _blink_active or absf(_lean_roll) > 0.0001 or _chroma_shake_active
	var lean_running: bool = _lean_tween != null and is_instance_valid(_lean_tween) and _lean_tween.is_running()
	if not (kicks_busy or effects_busy or lean_running or _channel_busy() or _position_busy()):
		set_process(false)
	var cam: Camera3D = _camera()
	if cam == null:
		return
	_last_camera = cam
	var fx_position: Vector3 = _kick_vec
	var fx_rotation: Vector3 = Vector3(deg_to_rad(_recoil_pitch), deg_to_rad(_recoil_yaw), deg_to_rad(_lean_roll))
	if _shake_level > 0.0:
		# Square the trauma so the shake ramps in perceptually (Squirrel Eiserloh's model).
		var amount: float = _shake_level * _shake_level
		var t: float = shake_time * shake_frequency
		fx_rotation += Vector3(deg_to_rad(max_shake_degrees) * amount * _noise.get_noise_2d(t, 0.0), deg_to_rad(max_shake_degrees) * amount * _noise.get_noise_2d(0.0, t), deg_to_rad(max_shake_degrees) * amount * _noise.get_noise_2d(t, t) / 3.0)
		fx_position += Vector3(max_shake_offset * amount * _noise.get_noise_2d(t, 50.0), max_shake_offset * amount * _noise.get_noise_2d(50.0, t), 0.0)
	if _jitter_active:
		fx_position += Vector3(_jitter_offset * _noise.get_noise_2d(_jitter_time, 100.0), _jitter_offset * _noise.get_noise_2d(100.0, _jitter_time), 0.0)
		fx_rotation.z += deg_to_rad(_jitter_roll) * _noise.get_noise_2d(_jitter_time, 200.0)
	if _bob_active:
		# A walking figure-8: side sway at half rate, one vertical dip per step.
		fx_position += Vector3(sin(_bob_time * TAU * 0.5) * _bob_amplitude * 0.5, -absf(sin(_bob_time * TAU * 0.5)) * _bob_amplitude, 0.0)
	# One global dial every camera effect is scaled by, so a player who gets motion sick can
	# turn shake, recoil, bob and lean down (or off) and keep the game. 1 when nobody has set
	# it, so a project that never asks is untouched.
	var effect_strength: float = float(Engine.get_meta("effect_strength", 1.0))
	fx_position *= effect_strength
	fx_rotation *= effect_strength
	cam.position += fx_position
	cam.rotation += fx_rotation
	cam.fov = clampf(cam.fov + _fov_kick, 1.0, 179.0)
	_applied_position = fx_position
	_applied_rotation = fx_rotation
	_applied_fov = _fov_kick

# @ace_action
# @ace_featured
# @ace_name("Shake")
# @ace_description("Adds screenshake to the active 3D camera (0 = none, 1 = max). Stacks and decays automatically - fire it on every hit or explosion.")
# @ace_display_template("Shake at [b]{strength}[/b]")
# @ace_codegen_template("$Juice3DBehavior.shake({strength})")
func shake(strength: float) -> void:
	trauma = clampf(trauma + strength, 0.0, 1.0)
	set_process(true)

# @ace_action
# @ace_name("Stop Shake")
# @ace_description("Cancels any shake immediately (other effects keep running).")
# @ace_codegen_template("$Juice3DBehavior.stop_shake()")
func stop_shake() -> void:
	trauma = 0.0
	_timed_shakes.clear()
	_shake_level = 0.0
	shake_time = 0.0
	_shaking = false

# @ace_action
# @ace_name("Recoil")
# @ace_description("Weapon recoil: kicks the view UP by a pitch (degrees) plus a random side spread, then re-centres at the Recoil Recovery rate. Fire on every shot - kicks stack, so sustained fire climbs. Cosmetic (rides on top of mouse look; aim is untouched).")
# @ace_codegen_template("$Juice3DBehavior.recoil({vertical_kick}, {horizontal_spread})")
func recoil(vertical_kick: float, horizontal_spread: float) -> void:
	_recoil_pitch += vertical_kick
	_recoil_yaw += randf_range(-horizontal_spread, horizontal_spread)
	set_process(true)

# @ace_action
# @ace_name("Start Head Bob")
# @ace_description("Starts a walking head-bob on the camera: a figure-8 (side sway at half rate, one downward dip per step). Amplitude is metres, frequency is steps per second. Call while your character moves; Stop Head Bob when they halt.")
# @ace_codegen_template("$Juice3DBehavior.start_head_bob({amplitude}, {frequency})")
func start_head_bob(amplitude: float, frequency: float) -> void:
	_bob_amplitude = amplitude
	_bob_frequency = maxf(frequency, 0.01)
	_bob_active = true
	set_process(true)

# @ace_action
# @ace_name("Stop Head Bob")
# @ace_description("Stops the head bob.")
# @ace_codegen_template("$Juice3DBehavior.stop_head_bob()")
func stop_head_bob() -> void:
	_bob_active = false

# @ace_action
# @ace_name("Start Jitter")
# @ace_description("Starts a continuous nervous wobble (position in metres + a touch of roll) that runs until Stop Jitter - unlike Shake it never decays. Engines idling, helicopters, low health, fear.")
# @ace_codegen_template("$Juice3DBehavior.start_jitter({position_amount}, {roll_degrees})")
func start_jitter(position_amount: float, roll_degrees: float) -> void:
	_jitter_offset = position_amount
	_jitter_roll = roll_degrees
	_jitter_active = true
	set_process(true)

# @ace_action
# @ace_name("Stop Jitter")
# @ace_description("Stops the jitter wobble.")
# @ace_codegen_template("$Juice3DBehavior.stop_jitter()")
func stop_jitter() -> void:
	_jitter_active = false

# @ace_action
# @ace_name("Lean")
# @ace_description("Eases the camera roll to an angle (degrees) and HOLDS it - lean into a wall ride, peek a corner, bank with a turn. Lean back to 0 to level out. Emits On Lean Finished.")
# @ace_codegen_template("$Juice3DBehavior.lean({degrees}, {duration})")
func lean(degrees: float, duration: float) -> void:
	if _lean_tween != null:
		_lean_tween.kill()
	var tw: Tween = create_tween()
	tw.tween_property(self, "_lean_roll", degrees, maxf(duration, 0.001)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.finished.connect(func() -> void: lean_finished.emit())
	_lean_tween = tw
	set_process(true)

# @ace_action
# @ace_featured
# @ace_name("FOV Punch")
# @ace_description("Kicks the field of view wider (positive, a speed boost / dash) or tighter (negative, an impact) by an amount in degrees, then eases back at the FOV Recovery rate. Fire-and-forget.")
# @ace_display_template("Punch FOV by [b]{amount}[/b]")
# @ace_codegen_template("$Juice3DBehavior.fov_punch({amount})")
func fov_punch(amount: float) -> void:
	_fov_kick += amount
	set_process(true)

# @ace_action
# @ace_name("Zoom FOV To")
# @ace_description("Smoothly changes the camera's base field of view to a value in degrees and keeps it there (an aim-down-sights zoom is FOV 40, back to 75 to unzoom). Emits On Zoom Finished.")
# @ace_codegen_template("$Juice3DBehavior.zoom_fov_to({fov}, {duration})")
func zoom_fov_to(fov: float, duration: float) -> void:
	var cam: Camera3D = _camera()
	if cam == null:
		return
	# Clear any active FOV punch first (unapply this frame's kick, zero it) so the tween drives a CLEAN
	# base to the exact target. Baking the current _applied_fov into the end value overshot permanently:
	# the kick decays to ~0 during the tween, so the camera settled at fov + the initial kick.
	_unapply()
	_fov_kick = 0.0
	if _zoom_tween != null and is_instance_valid(_zoom_tween):
		_zoom_tween.kill()
	var tw: Tween = create_tween()
	tw.tween_property(cam, "fov", clampf(fov, 1.0, 179.0), maxf(duration, 0.001)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.finished.connect(func() -> void: zoom_finished.emit())
	_zoom_tween = tw

# @ace_action
# @ace_name("Use Camera")
# @ace_description("Pin the effects to a specific Camera3D (by path). Leave it unused to auto-target whichever camera is active.")
# @ace_codegen_template("$Juice3DBehavior.use_camera({camera_path})")
func use_camera(camera_path: NodePath) -> void:
	_unapply()
	_camera_override = get_node_or_null(camera_path) as Camera3D

# @ace_action
# @ace_name("Kick Camera Away From Point")
# @ace_description("Shoves the camera AWAY from a world position (an explosion, a hit source) and re-centres at the Kick Recovery rate - Recoil's directional sibling when you know the cause's location. Cosmetic (additive; aim untouched). Composes with Shake.")
# @ace_codegen_template("$Juice3DBehavior.kick_away_from({world_position}, {strength})")
func kick_away_from(world_position: Vector3, strength: float) -> void:
	var cam: Camera3D = _camera()
	if cam == null:
		return
	var away: Vector3 = cam.global_position - world_position
	away = away.normalized() if away.length() > 0.001 else Vector3.UP
	_kick_vec += away * strength
	set_process(true)

# @ace_action
# @ace_name("Start Blinking")
# @ace_description("Strobes the host's visibility - invulnerability frames, respawn grace, a targeted highlight. Runs until Stop Blinking.")
# @ace_codegen_template("$Juice3DBehavior.start_blinking({times_per_second})")
func start_blinking(times_per_second: float) -> void:
	_blink_rate = maxf(times_per_second, 0.1)
	_blink_time = 0.0
	_blink_active = true
	set_process(true)

# @ace_action
# @ace_name("Stop Blinking")
# @ace_description("Stops the blink and makes the host visible again.")
# @ace_codegen_template("$Juice3DBehavior.stop_blinking()")
func stop_blinking() -> void:
	_blink_active = false
	if host is Node3D:
		(host as Node3D).visible = true

# @ace_action
# @ace_name("Punch Scale")
# @ace_description("Kicks the host's scale up (or down, negative) and springs it back elastically - pickups, flinches, beat pulses. Emits On Punch Finished.")
# @ace_codegen_template("$Juice3DBehavior.punch_scale({strength}, {duration})")
func punch_scale(strength: float, duration: float) -> void:
	var scaled: Node3D = host as Node3D
	if scaled == null:
		return
	if _punch_scale_tween != null and is_instance_valid(_punch_scale_tween):
		_punch_scale_tween.kill()
	scaled.scale = _base_scale3 * (1.0 + clampf(strength, -0.9, 5.0))
	var tw: Tween = create_tween()
	tw.tween_property(scaled, "scale", _base_scale3, maxf(duration, 0.001)).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.finished.connect(func() -> void: punch_finished.emit())
	_punch_scale_tween = tw

# @ace_action
# @ace_name("Punch Position")
# @ace_description("Kicks the host's position by an offset (metres) and springs it back elastically - knockback reads, impact shoves away from an attacker. Emits On Punch Finished.")
# @ace_codegen_template("$Juice3DBehavior.punch_position({offset}, {duration})")
func punch_position(offset: Vector3, duration: float) -> void:
	var shoved: Node3D = host as Node3D
	if shoved == null:
		return
	if _punch_pos_tween != null and _punch_pos_tween.is_valid():
		_punch_pos_tween.kill()
	else:
		_punch_pos_rest = shoved.position
	shoved.position = _punch_pos_rest + offset
	var tw: Tween = create_tween()
	tw.tween_property(shoved, "position", _punch_pos_rest, maxf(duration, 0.001)).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.finished.connect(func() -> void: punch_finished.emit())
	_punch_pos_tween = tw

# @ace_action
# @ace_name("Pulse Vignette")
# @ace_description("Darkens the screen edges to a color at a strength (0..1), then fades back out - taking damage, a near miss, holding your breath. Composes with Fade Screen Tint for last-stand moments.")
# @ace_codegen_template("$Juice3DBehavior.pulse_vignette({strength}, {color}, {seconds})")
func pulse_vignette(strength: float, color: Color, seconds: float) -> void:
	_ensure_fx_overlay()
	if _fx_material == null:
		return
	if _vignette_tween != null and _vignette_tween.is_valid():
		_vignette_tween.kill()
	_fx_material.set_shader_parameter("vignette_color", Color(color.r, color.g, color.b, 1.0))
	_fx_material.set_shader_parameter("vignette_strength", clampf(strength, 0.0, 1.0))
	_fx_rect.visible = true
	var tw: Tween = create_tween()
	tw.tween_property(_fx_material, "shader_parameter/vignette_strength", 0.0, maxf(seconds, 0.01)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.finished.connect(_fx_update_visibility)
	_vignette_tween = tw

# @ace_action
# @ace_featured
# @ace_name("Chromatic Kick")
# @ace_description("Splits the screen's color channels for an instant and settles back - the AAA impact frame. Fire with Shake on explosions and heavy hits.")
# @ace_display_template("Chromatic kick at [b]{strength}[/b] for [b]{seconds}[/b] s")
# @ace_codegen_template("$Juice3DBehavior.chromatic_kick({strength}, {seconds})")
func chromatic_kick(strength: float, seconds: float) -> void:
	_ensure_fx_overlay()
	if _fx_material == null:
		return
	if _chroma_tween != null and _chroma_tween.is_valid():
		_chroma_tween.kill()
	_fx_material.set_shader_parameter("chroma_strength", clampf(strength, 0.0, 1.0))
	_fx_rect.visible = true
	var tw: Tween = create_tween()
	tw.tween_property(_fx_material, "shader_parameter/chroma_strength", 0.0, maxf(seconds, 0.01)).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.finished.connect(_fx_update_visibility)
	_chroma_tween = tw

# @ace_action
# @ace_name("Chromatic Shake")
# @ace_description("Shakes the screen's color channels apart along a direction that moves - the Shake you feel, on the screen instead of the camera. Magnitude is how far they split in pixels, and a reducing shake falls to nothing over the duration while a constant one holds and then stops dead. Leave the angle below zero and the split wanders with the same noise the camera shake uses (so the two read as one hit); give it an angle and the split stays on that line and only breathes. Firing again restarts it. It runs on the game's own time, so any change to Engine.time_scale glides it and a freeze holds it. The words for mode are the constants MODE_REDUCING, MODE_CONSTANT.")
# @ace_display_template("Chromatic shake [b]{magnitude}[/b] px for [b]{duration}[/b] s")
# @ace_param_options(mode reducing, constant)
# @ace_codegen_template("$Juice3DBehavior.chromatic_shake({magnitude}, {duration}, "{mode}", {angle_degrees})")
func chromatic_shake(magnitude: float, duration: float, mode: String, angle_degrees: float) -> void:
	_ensure_fx_overlay()
	_chroma_shake_from = maxf(magnitude, 0.0)
	_chroma_shake_duration = maxf(duration, 0.01)
	_chroma_shake_hold = mode == "constant"
	_chroma_shake_angle = angle_degrees
	# Firing again RESTARTS the shake rather than stacking a second one on it: the same split, from
	# the top. The noise clock deliberately keeps running, so a second hit carries the wander on
	# instead of snapping the split back to where the first one started.
	_chroma_shake_elapsed = 0.0
	_chroma_shake_active = true
	if _fx_rect != null:
		_fx_rect.visible = true
	_chroma_shake_write()
	set_process(true)

# @ace_action
# @ace_name("Stop Chromatic Shake")
# @ace_description("Takes the chromatic shake off the screen at once - the way out of a constant one, and the way to end a reducing one early (a hit interrupted by a cutscene). The overlay hides itself unless a vignette, a kick or speed lines are still on it.")
# @ace_codegen_template("$Juice3DBehavior.stop_chromatic_shake()")
func stop_chromatic_shake() -> void:
	_chroma_shake_active = false
	_chroma_shake_elapsed = 0.0
	_chroma_shake_magnitude = 0.0
	if _fx_material == null:
		return
	_fx_material.set_shader_parameter("chroma_shift", Vector2.ZERO)
	_fx_material.set_shader_parameter("chroma_intensity", 0.0)
	# Hands the overlay back: it hides itself unless a vignette, a kick or speed lines are still on it.
	_fx_update_visibility()

# @ace_action
# @ace_name("Set Speed Lines")
# @ace_description("Radial anime-style speed streaks at an intensity (0..1) that HOLD until you set 0 - sprints, dashes, adrenaline modes. Pair with FOV Punch for full sprint feel.")
# @ace_codegen_template("$Juice3DBehavior.set_speed_lines({intensity})")
func set_speed_lines(intensity: float) -> void:
	_ensure_fx_overlay()
	if _fx_material == null:
		return
	_fx_material.set_shader_parameter("speed_lines", clampf(intensity, 0.0, 1.0))
	_fx_update_visibility()

# @ace_action
# @ace_name("Play Sound Varied")
# @ace_description("Plays a sound with a random pitch and volume wobble around the base - the #1 trick against repetitive footsteps, hits, and shots. Fire-and-forget (the player frees itself).")
# @ace_codegen_template("$Juice3DBehavior.play_sound_varied({path}, {pitch_jitter}, {volume_jitter_db})")
func play_sound_varied(path: String, pitch_jitter: float, volume_jitter_db: float) -> void:
	_spawn_one_shot(path, 1.0 + randf_range(-pitch_jitter, pitch_jitter), randf_range(-absf(volume_jitter_db), 0.0))

# @ace_action
# @ace_name("Play Sound With Intensity")
# @ace_description("Plays a sound scaled by an intensity (0..1): quiet + lower-pitched when light, full + brighter when heavy - drive it, Shake, and Punch Scale from ONE hit-power value so light and heavy hits differ by one number.")
# @ace_codegen_template("$Juice3DBehavior.play_sound_intensity({path}, {intensity})")
func play_sound_intensity(path: String, intensity: float) -> void:
	var power: float = clampf(intensity, 0.0, 1.0)
	_spawn_one_shot(path, lerpf(0.85, 1.15, power) * (1.0 + randf_range(-0.03, 0.03)), lerpf(-14.0, 0.0, power))

# @ace_action
# @ace_name("Count To")
# @ace_description("Eases a named display value toward a target over a duration - scores and gold ROLL instead of snapping. Read it with the Ticker Value expression; emits On Ticker Finished (with the name) when it lands.")
# @ace_codegen_template("$Juice3DBehavior.count_to({ticker_name}, {target}, {duration})")
func count_to(ticker_name: String, target: float, duration: float) -> void:
	var from: float = float(_tickers.get(ticker_name, 0.0))
	_ticker_targets[ticker_name] = target
	var old_tween: Tween = _ticker_tweens.get(ticker_name, null)
	if old_tween != null and is_instance_valid(old_tween):
		old_tween.kill()
	var tw: Tween = create_tween()
	tw.tween_method(func(v: float) -> void: _tickers[ticker_name] = v, from, target, maxf(duration, 0.001)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.finished.connect(_finish_ticker.bind(ticker_name))
	_ticker_tweens[ticker_name] = tw

# @ace_action
# @ace_name("Set Ticker")
# @ace_description("Sets a named display value INSTANTLY (cancelling any roll) - initialise a score at 0, or snap on a reset.")
# @ace_codegen_template("$Juice3DBehavior.set_ticker({ticker_name}, {value})")
func set_ticker(ticker_name: String, value: float) -> void:
	var old_tween: Tween = _ticker_tweens.get(ticker_name, null)
	if old_tween != null and is_instance_valid(old_tween):
		old_tween.kill()
	_tickers[ticker_name] = value
	_ticker_targets[ticker_name] = value

# @ace_action
# @ace_name("Shake Channel")
# @ace_description("Says one shake to a whole CHANNEL: everything listening on it shakes, and nothing else in the game hears a thing. A channel is a GROUP - the same groups the Node dock shows - so a distant collapse reaches the hanging lamps, a hit reaches the HUD, and neither side needs a reference to the other. Each listener decides what it shakes: the camera, itself, or the screen. A 2D listener and a 3D one answer the same broadcast, so one row can shake a level and its interface together.")
# @ace_display_template("Shake channel [b]{channel}[/b] with [b]{magnitude}[/b] for [b]{seconds}[/b] s")
# @ace_param(channel, default: props, desc: "Which channel to shake - a group name. Everything listening on it hears this; everything else does not.")
# @ace_param(magnitude, default: 0.5, desc: "How hard: 0 to 1 for a listener shaking the camera, world units for one shaking itself, pixels for one shaking the screen.")
# @ace_param(seconds, default: 0.6, desc: "How long the shake lasts before it has faded to nothing.")
# @ace_codegen_template("$Juice3DBehavior.shake_channel("{channel}", {magnitude}, {seconds})")
func shake_channel(channel: String, magnitude: float, seconds: float) -> void:
	if not is_inside_tree():
		return
	get_tree().call_group(StringName(channel), "shake_from_channel", magnitude, seconds)

# @ace_action
# @ace_name("Listen On Channel")
# @ace_description("Makes this node a LISTENER: whenever that channel is shaken, this node shakes too. The channel is a group, so this row is the group the Node dock shows, joined from the sheet. The second field is what this node shakes, and it is its answer on every channel it listens on - a listener has one way of shaking, and a second row on another channel does not give it a second one.")
# @ace_display_template("Listen on channel [b]{channel}[/b] and shake [b]{shakes}[/b]")
# @ace_param(channel, default: props, desc: "Which channel to listen on - a group name. Say it once, at the start of the scene.")
# @ace_param(shakes, options: the camera|this node|the screen, default: this node, desc: "What this node moves when the channel speaks: the camera the player looks through, this node itself, or the screen's colour channels.")
# @ace_codegen_template("$Juice3DBehavior.listen_on_channel("{channel}", "{shakes}")")
func listen_on_channel(channel: String, shakes: String) -> void:
	add_to_group(StringName(channel), true)
	_channel_shakes = shakes

# @ace_action
# @ace_name("Stop Listening On Channel")
# @ace_description("Takes this node off a channel: it stops hearing that channel's shakes and settles back to the pose it was found in. Every other channel it listens on is left alone.")
# @ace_display_template("Stop listening on channel [b]{channel}[/b]")
# @ace_param(channel, default: props, desc: "Which channel to stop hearing.")
# @ace_codegen_template("$Juice3DBehavior.stop_listening_on_channel("{channel}")")
func stop_listening_on_channel(channel: String) -> void:
	if is_in_group(StringName(channel)):
		remove_from_group(StringName(channel))
	_channel_put_back()

# @ace_expression
# @ace_name("Ticker Value")
# @ace_codegen_template("$Juice3DBehavior.ticker_value({ticker_name})")
## What a ticker currently SHOWS - the eased value Count To is rolling toward its target.
## Print or draw this instead of the real variable and scores roll instead of snapping.
func ticker_value(ticker_name: String) -> float:
	return float(_tickers.get(ticker_name, 0.0))

# @ace_hidden
func _finish_ticker(ticker_name: String) -> void:
	_tickers[ticker_name] = _ticker_targets.get(ticker_name, _tickers.get(ticker_name, 0.0))
	ticker_finished.emit(ticker_name)

# @ace_hidden
## Spawns a throwaway one-shot AudioStreamPlayer (frees itself when done).
func _spawn_one_shot(path: String, pitch: float, volume_db: float) -> void:
	var stream: AudioStream = load(path) as AudioStream
	if stream == null:
		return
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.stream = stream
	player.pitch_scale = maxf(pitch, 0.05)
	player.volume_db = volume_db
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()

## Removes last frame's additive offsets from whichever camera received them, so this frame
## starts from the pose the camera's OWNER (controller/animation) wrote.
func _unapply() -> void:
	if _last_camera == null or not is_instance_valid(_last_camera):
		_applied_position = Vector3.ZERO
		_applied_rotation = Vector3.ZERO
		_applied_fov = 0.0
		return
	_last_camera.position -= _applied_position
	_last_camera.rotation -= _applied_rotation
	_last_camera.fov = clampf(_last_camera.fov - _applied_fov, 1.0, 179.0)
	_applied_position = Vector3.ZERO
	_applied_rotation = Vector3.ZERO
	_applied_fov = 0.0

# @ace_condition
# @ace_name("Is Shaking")
# @ace_codegen_template("$Juice3DBehavior.is_shaking()")
func is_shaking() -> bool:
	return trauma > 0.0 or not _timed_shakes.is_empty()

# @ace_expression
# @ace_name("Trauma")
# @ace_codegen_template("$Juice3DBehavior.current_trauma()")
func current_trauma() -> float:
	return trauma

# @ace_hidden
## What a broadcast arrives as. call_group reaches this by name, so the method's NAME is the
## contract between a Shake Channel row and every listener - spelled the same in both Juice
## packs, so one broadcast reaches a 3D prop and a 2D panel alike.
##
## The accessibility dial is applied HERE for the two shakes this node draws itself, and NOT for
## the camera: the camera mixer applies it once already, and applying it twice would square it.
func shake_from_channel(magnitude: float, seconds: float) -> void:
	if _channel_shakes == CHANNEL_SHAKE_SCREEN:
		chromatic_shake(magnitude * maxf(float(Engine.get_meta("effect_strength", 1.0)), 0.0), seconds, "reducing", -1.0)
		return
	if _channel_shakes == CHANNEL_SHAKE_CAMERA:
		_channel_amount = maxf(magnitude, 0.0)
	else:
		_channel_amount = maxf(magnitude, 0.0) * maxf(float(Engine.get_meta("effect_strength", 1.0)), 0.0)
	_channel_span = maxf(seconds, 0.0001)
	_channel_left = _channel_span
	set_process(true)

# @ace_hidden
## One frame of a channel shake. A camera listener holds the trauma the mixer already reads up
## to what the channel asked for, so the two never draw two shakes over each other; a node
## listener rides the same noise around the pose it was found in. Both fade to nothing over the
## time the broadcast named, and the node is put back the frame it runs out.
func _channel_tick(delta: float) -> void:
	if _channel_left <= 0.0:
		if _channel_driving:
			_channel_put_back()
		return
	_channel_left = maxf(_channel_left - delta, 0.0)
	var fade: float = clampf(_channel_left / maxf(_channel_span, 0.0001), 0.0, 1.0)
	if _channel_shakes == CHANNEL_SHAKE_CAMERA:
		trauma = maxf(trauma, clampf(_channel_amount * fade, 0.0, 1.0))
		return
	if not (host is Node3D):
		_channel_left = 0.0
		return
	if _noise == null:
		_noise = FastNoiseLite.new()
		_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		_noise.frequency = 1.0
		_noise.seed = randi()
	if not _channel_driving:
		_channel_driving = true
		_channel_rest = (host as Node3D).position
	var t: float = (_channel_span - _channel_left) * shake_frequency
	var offset: Vector3 = Vector3(_noise.get_noise_2d(t, 300.0), _noise.get_noise_2d(300.0, t), _noise.get_noise_2d(t, t))
	(host as Node3D).position = _channel_rest + offset * _channel_amount * fade
	if _channel_left <= 0.0:
		_channel_put_back()

# @ace_hidden
## Hands the node back exactly as it was found, and forgets the shake. Called when a shake runs
## out and when a listener leaves the channel, so nothing is ever left displaced.
func _channel_put_back() -> void:
	if _channel_driving and host is Node3D:
		(host as Node3D).position = _channel_rest
	_channel_driving = false
	_channel_amount = 0.0
	_channel_span = 0.0
	_channel_left = 0.0

# @ace_hidden
## Whether a channel shake is still costing anything - what the parking check asks.
func _channel_busy() -> bool:
	return _channel_left > 0.0 or _channel_driving

# @ace_action
# @ace_name("Shake Position")
# @ace_description("Shakes ONLY the position of the 3D object this node is on - not the camera, not its rotation or its size - for exactly this long, then puts it back where it was. Jitter, tremble, rumble or wobble a sprite, a door, a button or a crate. Fade in rises from nothing, Fade out dies away, and a Curve you drew can be the shape. Weights let it shake sideways only (Y weight 0, Z weight 0). The amount is in metres. It adds to a Position Shake already running, and Stop Position Shake ends it.")
# @ace_display_template("Shake position by [b]{amount}[/b] m for [b]{seconds}[/b] s, fade in [b]{fade_in}[/b], fade out [b]{fade_out}[/b]")
# @ace_param(amount, default: 0.1, desc: "How far the object may move from where it is, in metres, at the strongest moment.")
# @ace_param(seconds, default: 0.4, desc: "How long the shake lasts.")
# @ace_param(fade_in, default: false, desc: "On: the shake rises from nothing to the amount.")
# @ace_param(fade_out, default: true, desc: "On: the shake dies away to nothing by the end.")
# @ace_param(curve, default: null, desc: "Optional Curve file that is the shape of the shake instead of the two ticks.")
# @ace_param(x_weight, default: 1.0, desc: "How much of the amount it moves sideways. 0 shakes up and down only.")
# @ace_param(y_weight, default: 1.0, desc: "How much of the amount it moves up and down. 0 shakes sideways only.")
# @ace_param(z_weight, default: 1.0, desc: "How much of the amount it moves towards and away from the camera. 0 keeps it on its own plane.")
# @ace_param(jumps_per_second, default: 30.0, desc: "How many times a second it jumps to a new place. Lower is a slow rumble, higher a buzz.")
# @ace_codegen_template("$Juice3DBehavior.shake_position({amount}, {seconds}, {fade_in}, {fade_out}, {curve}, {x_weight}, {y_weight}, {z_weight}, {jumps_per_second})")
## Shakes the position of the 3D object this node is on, for `seconds`, by up to `amount` metres, then puts it back exactly.
func shake_position(amount: float = 0.1, seconds: float = 0.4, fade_in: bool = false, fade_out: bool = true, curve: Curve = null, x_weight: float = 1.0, y_weight: float = 1.0, z_weight: float = 1.0, jumps_per_second: float = 30.0) -> void:
	shake_position_on(host, amount, seconds, fade_in, fade_out, curve, Vector3(x_weight, y_weight, z_weight), jumps_per_second, 1.0)

# @ace_action
# @ace_name("Stop Position Shake")
# @ace_description("Ends every Position Shake on this node at once and puts the shaken objects back where they were.")
# @ace_codegen_template("$Juice3DBehavior.stop_position_shake()")
## Ends every position shake this node has going and puts each shaken object back where it was.
func stop_position_shake() -> void:
	_position_shakes.clear()
	_position_take_off()
	_position_unhook()

# @ace_hidden
## Whether any position shake is still going, for the tick's parking check.
func _position_busy() -> bool:
	return not _position_shakes.is_empty()

# @ace_hidden
## Connects the draw hook and the exit hook the first time a shake starts.
func _position_hook() -> void:
	if _position_hooked:
		return
	_position_hooked = true
	RenderingServer.frame_post_draw.connect(_position_take_off)
	if not tree_exiting.is_connected(_position_end):
		tree_exiting.connect(_position_end)

# @ace_hidden
## Lets the hooks go once nothing is shaking.
func _position_unhook() -> void:
	if not _position_hooked:
		return
	_position_hooked = false
	if RenderingServer.frame_post_draw.is_connected(_position_take_off):
		RenderingServer.frame_post_draw.disconnect(_position_take_off)

# @ace_hidden
## This node is leaving the scene: nothing it shook may be left displaced.
func _position_end() -> void:
	_position_shakes.clear()
	_position_take_off()
	_position_unhook()

# @ace_hidden
## Takes every offset off its node. If something put the node back on its own place meanwhile (a script that sets the position
## outright), there is nothing left to take off.
func _position_take_off() -> void:
	for node: Variant in _position_added.keys():
		var held: Dictionary = _position_added[node]
		if is_instance_valid(node):
			var now: Vector3 = (node as Node3D).position
			var added: Vector3 = held["added"]
			if now == (held["left"] as Vector3):
				(node as Node3D).position = held["base"]
			elif not now.is_equal_approx((held["left"] as Vector3) - added):
				(node as Node3D).position = now - added
	_position_added.clear()

# @ace_hidden
## One frame of every position shake: the old offsets come off, the clocks move on, and the new offsets go on. Called from
## the tick, so the position is the last thing written to the object before it is drawn.
func _position_shake_step(delta: float) -> void:
	_position_take_off()
	if _position_shakes.is_empty():
		_position_unhook()
		return
	var sums: Dictionary = {}
	for at: int in range(_position_shakes.size() - 1, -1, -1):
		var one: Dictionary = _position_shakes[at]
		var node: Node = one["node"] as Node
		one["elapsed"] = float(one["elapsed"]) + delta
		var span: float = float(one["seconds"])
		if not is_instance_valid(node) or float(one["elapsed"]) >= span:
			_position_shakes.remove_at(at)
			continue
		var jump: int = int(floor(float(one["elapsed"]) * float(one["rate"])))
		if jump != int(one["jump"]):
			one["jump"] = jump
			one["way"] = Vector3(randf_range(-1.0, 1.0) * float(one["x"]), randf_range(-1.0, 1.0) * float(one["y"]), randf_range(-1.0, 1.0) * float(one["z"]))
		var level: float = float(one["amount"]) * _shake_shape(float(one["elapsed"]) / span, bool(one["fade_in"]), bool(one["fade_out"]), one["curve"] as Curve)
		sums[node] = (sums.get(node, Vector3.ZERO) as Vector3) + (one["way"] as Vector3) * level
	for node: Variant in sums.keys():
		var offset: Vector3 = sums[node]
		var now: Vector3 = (node as Node3D).position
		(node as Node3D).position = now + offset
		_position_added[node] = {"added": offset, "left": now + offset, "base": now}
	if _position_shakes.is_empty():
		_position_unhook()

# @ace_hidden
## Starts one timed shake of `amount` that lasts `seconds` (never under a twentieth of a second) with the shape the two ticks
## and the curve ask for. A curve is the shape on its own and the ticks are not read.
func _start_timed_shake(amount: float, seconds: float, fade_in: bool, fade_out: bool, curve: Curve) -> void:
	if amount <= 0.0:
		return
	_timed_shakes.append({"amount": amount, "seconds": maxf(seconds, STEP_NATURAL_SECONDS), "elapsed": 0.0,
		"fade_in": fade_in, "fade_out": fade_out, "curve": curve})
	set_process(true)

# @ace_hidden
## Shakes the camera for `seconds` at `amount` (0 to 1) with the shape the two ticks and the curve ask for. The strength
## scales the amount, and while no flashing is on the amount is held under the ceiling and the time over the floor.
func shake_timed(amount: float, seconds: float, fade_in: bool = false, fade_out: bool = true, curve: Curve = null, at_strength: float = 1.0) -> void:
	_start_timed_shake(_step_allowed(amount, at_strength), _step_seconds(seconds), fade_in, fade_out, curve)

# @ace_hidden
## Plays a Shake card that holds a tick or a curve: reads the card and calls shake_timed. The Juice Player calls this by
## name when it finds it here.
func shake_from_card(card: Dictionary, strength: float) -> void:
	var curve: Curve = null
	var kept: String = str(card.get("curve", "")).strip_edges()
	if not kept.is_empty():
		curve = load(kept) as Curve if ResourceLoader.exists(kept) else null
		if curve == null:
			push_warning("Juice 3D: a Shake card keeps the curve \"%s\", which is no Curve file now, so it shakes with its ticks instead." % kept)
	shake_timed(float(card.get("amount", 1.0)), float(card.get("seconds", 0.0)), bool(card.get("fade_in", false)), bool(card.get("fade_out", false)), curve, strength)

# @ace_hidden
## Moves every timed shake on by one frame and gives back the level they add to the trauma. A shake that has run its whole
## length is let go, and the ones left keep their own clocks.
func _tick_timed_shakes(delta: float) -> float:
	var level: float = 0.0
	for at: int in range(_timed_shakes.size() - 1, -1, -1):
		var one: Dictionary = _timed_shakes[at]
		one["elapsed"] = float(one["elapsed"]) + delta
		var span: float = float(one["seconds"])
		if float(one["elapsed"]) >= span:
			_timed_shakes.remove_at(at)
			continue
		level += float(one["amount"]) * _shake_shape(float(one["elapsed"]) / span, bool(one["fade_in"]), bool(one["fade_out"]), one["curve"] as Curve)
	return level

# @ace_hidden
## The share of its amount a timed shake has `through` its length (0 at the first frame, 1 at the last): the same shape the
## Juice pack draws. Fade out falls from the full amount to nothing, Fade in rises from nothing, both swell and die away, and
## a curve is the shape on its own.
static func _shake_shape(through: float, fade_in: bool, fade_out: bool, curve: Curve = null) -> float:
	var t: float = clampf(through, 0.0, 1.0)
	if curve != null and curve.point_count > 0:
		return maxf(curve.sample(lerpf(curve.min_domain, curve.max_domain, t)), 0.0)
	if fade_in and fade_out:
		return 1.0 - absf(2.0 * t - 1.0)
	if fade_in:
		return t
	if fade_out:
		return 1.0 - t
	return 1.0

# @ace_hidden
## What the camera mixer drew its shake with on the last frame, before squaring.
func shake_level() -> float:
	return _shake_level

# @ace_hidden
func _ensure_tint_overlay() -> void:
	if _tint_overlay != null or not is_inside_tree():
		return
	_tint_overlay = CanvasLayer.new()
	_tint_overlay.layer = 90
	add_child(_tint_overlay)
	_tint_rect = ColorRect.new()
	_tint_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	_tint_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tint_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tint_overlay.add_child(_tint_rect)

# @ace_action
# @ace_name("Set Screen Tint")
# @ace_codegen_template("$Juice3DBehavior.set_screen_tint({color}, {strength})")
## Washes the WHOLE SCREEN with a color at Strength opacity (0..1) over the 3D view -
## damage red, poison green, night blue. Call again to retune; strength 0 clears.
func set_screen_tint(color: Color, strength: float) -> void:
	_ensure_tint_overlay()
	if _tint_rect != null:
		_tint_rect.color = Color(color.r, color.g, color.b, clampf(strength, 0.0, 1.0))
		_tint_rect.visible = _tint_rect.color.a > 0.001

# @ace_action
# @ace_name("Fade Screen Tint")
# @ace_codegen_template("$Juice3DBehavior.fade_screen_tint({seconds})")
## Fades the screen tint's strength to zero over the given seconds - the damage-flash
## pattern: Set Screen Tint red 0.4, then Fade Screen Tint 0.3.
func fade_screen_tint(seconds: float) -> void:
	if _tint_rect == null or not _tint_rect.visible:
		return
	create_tween().tween_property(_tint_rect, "color:a", 0.0, maxf(seconds, 0.01))

# @ace_action
# @ace_name("Clear Screen Tint")
# @ace_codegen_template("$Juice3DBehavior.clear_screen_tint()")
## Removes the screen tint instantly.
func clear_screen_tint() -> void:
	if _tint_rect != null:
		_tint_rect.visible = false

# @ace_hidden
func _ensure_fx_overlay() -> void:
	if _fx_layer != null or not is_inside_tree():
		return
	_fx_layer = CanvasLayer.new()
	_fx_layer.layer = 91
	add_child(_fx_layer)
	_fx_rect = ColorRect.new()
	_fx_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var fx_shader: Shader = Shader.new()
	fx_shader.code = _FX_SHADER
	_fx_material = ShaderMaterial.new()
	_fx_material.shader = fx_shader
	# Seed every uniform so get_shader_parameter never returns null: reading an un-set uniform
	# returns null (NOT the shader default), and _fx_update_visibility's float() would fault on it
	# whenever only one of the effects had been used.
	_fx_material.set_shader_parameter("vignette_strength", 0.0)
	_fx_material.set_shader_parameter("chroma_strength", 0.0)
	_fx_material.set_shader_parameter("chroma_shift", Vector2.ZERO)
	_fx_material.set_shader_parameter("chroma_intensity", 0.0)
	_fx_material.set_shader_parameter("speed_lines", 0.0)
	_fx_rect.material = _fx_material
	_fx_rect.visible = false
	_fx_layer.add_child(_fx_rect)

# @ace_hidden
func _fx_update_visibility() -> void:
	if _fx_rect == null or _fx_material == null:
		return
	_fx_rect.visible = float(_fx_material.get_shader_parameter("vignette_strength")) > 0.001 \
			or float(_fx_material.get_shader_parameter("chroma_strength")) > 0.001 \
			or float(_fx_material.get_shader_parameter("chroma_intensity")) > 0.001 \
			or float(_fx_material.get_shader_parameter("speed_lines")) > 0.001

# @ace_hidden
## Whether this player has asked for no flashing.
func _chroma_shake_quiet() -> bool:
	return bool(Engine.get_meta(NO_FLASHING_META, false))

# @ace_hidden
## How fast the split's direction wanders: the same knob the camera shake scrolls its noise at,
## halved while no flashing is on.
func _chroma_shake_rate() -> float:
	return shake_frequency * (0.5 if _chroma_shake_quiet() else 1.0)

# @ace_hidden
## One sample of the shared noise at the shake's own clock - what makes the split move.
func _chroma_shake_wander() -> float:
	if _noise == null:
		return 0.0
	return _noise.get_noise_2d(_chroma_shake_phase, 0.0)

# @ace_hidden
## How much of the shake is left: all of it while a constant one holds, and a straight line down
## to nothing while a reducing one runs.
func _chroma_shake_fade() -> float:
	if not _chroma_shake_active:
		return 0.0
	if _chroma_shake_hold:
		return 1.0
	return clampf(1.0 - _chroma_shake_elapsed / maxf(_chroma_shake_duration, 0.0001), 0.0, 1.0)

# @ace_hidden
## Which way the split points this frame: the angle it was told, or the shared noise walking it
## around. Without a seeded noise (a shake fired before _ready) it points right rather than
## nowhere, so the effect is still visible.
##
## It is a UNIT direction whichever way it came, because the magnitude beside it is the whole
## promise: 12 pixels asked for is 12 pixels wide on screen, and the expression that answers 12
## is answering about the same split. The noise therefore picks the ANGLE - one full turn per
## unit of noise - rather than the vector. Reading a PAIR of samples as the vector instead would
## hand back a direction shorter than one almost always, and nothing at all in the frames where
## both samples crossed zero together, so the split would quietly be a fraction of what the row
## and the expression both said it was.
func _chroma_shake_direction() -> Vector2:
	if _chroma_shake_angle >= 0.0:
		return Vector2.from_angle(deg_to_rad(_chroma_shake_angle))
	if _noise == null:
		return Vector2.RIGHT
	return Vector2.from_angle(_chroma_shake_wander() * TAU)

# @ace_hidden
## The magnitude the shake itself is at this frame, in pixels: what was asked for, less the
## falloff spent, less the wander a fixed angle leaves on the amount, halved while no flashing
## is on. The player's effect-strength dial is spent on top of this, where the frame is written.
func _chroma_shake_amount() -> float:
	var amount: float = _chroma_shake_from * _chroma_shake_fade()
	if _chroma_shake_angle >= 0.0:
		amount *= 1.0 - CHROMA_SHAKE_WANDER * absf(_chroma_shake_wander())
	if _chroma_shake_quiet():
		amount *= 0.5
	return amount

# @ace_hidden
## Writes this frame of the shake onto the overlay shader. The shift is in pixels here and in
## screen fractions there, so it is divided by the viewport - a 12-pixel split is 12 pixels wide
## on every resolution. The magnitude is kept whether or not there is a shader to write to, so
## the expression answers off-tree (and headless) exactly as it does on screen - and it is
## stored AFTER the effect-strength dial, because the expression's promise is to answer with
## the width the screen is showing, not the width the row asked for before the player's
## setting was spent on it.
func _chroma_shake_write() -> void:
	# The same global dial the camera effects are scaled by, so a player who turned the shake
	# down turned this down with it.
	var effect_strength: float = float(Engine.get_meta("effect_strength", 1.0))
	_chroma_shake_magnitude = _chroma_shake_amount() * effect_strength
	if _fx_material == null:
		return
	var span: Vector2 = Vector2(1.0, 1.0)
	var vp: Viewport = get_viewport()
	if vp != null:
		span = vp.get_visible_rect().size
	span = Vector2(maxf(span.x, 1.0), maxf(span.y, 1.0))
	var shift: Vector2 = _chroma_shake_direction() * _chroma_shake_magnitude
	_fx_material.set_shader_parameter("chroma_shift", shift / span)
	# The falloff is spent ONCE, and it is spent on the shift above. This dial is how far the
	# shaken taps are mixed in at all, so writing the fade here as well would square the curve:
	# a reducing shake would be a quarter of itself half way through while the row, the docs and
	# the expression all promised half. It is a GATE - on while a shake runs, and put back to 0
	# by Stop Chromatic Shake - which is also what the overlay's visibility check reads it as.
	_fx_material.set_shader_parameter("chroma_intensity", 1.0)

# @ace_hidden
## One frame of the shake. The clock is advanced by DELTA, which the engine has already scaled
## by time: slow motion glides the split, a hitstop freezes it mid-frame, and the duration
## stretches with them - the shake belongs to the game's time, not the wall clock. The noise
## clock takes the wander rate on the way in, so a rate that changes mid-shake bends the walk
## from here on rather than moving where the whole walk so far was read from.
func _chroma_shake_step(delta: float) -> void:
	if not _chroma_shake_active:
		return
	_chroma_shake_phase += delta * _chroma_shake_rate()
	_chroma_shake_elapsed += delta
	if _chroma_shake_elapsed >= _chroma_shake_duration:
		# A reducing shake has reached nothing and a constant one has held long enough: both end
		# here, the overlay is put back to clean, and the tick parks itself on the next pass.
		stop_chromatic_shake()
		return
	_chroma_shake_write()

# @ace_condition
# @ace_name("Is Chromatic Shaking")
# @ace_codegen_template("$Juice3DBehavior.is_chromatic_shaking()")
## Whether a chromatic shake is running right now - true from the row that fires it until the
## duration is up or Stop Chromatic Shake takes it off.
func is_chromatic_shaking() -> bool:
	return _chroma_shake_active

# @ace_expression
# @ace_name("Chromatic Shake Magnitude")
# @ace_codegen_template("$Juice3DBehavior.chromatic_shake_magnitude()")
## How wide the split is right now, in pixels: the magnitude after the falloff, the wander, the
## no-flashing halving and the player's effect-strength dial - the width the screen is showing,
## not the width the row asked for. Zero when nothing is shaking. Drive a rumble or a HUD wobble
## from it and the whole hit reads as one thing.
func chromatic_shake_magnitude() -> float:
	return _chroma_shake_magnitude

# @ace_hidden
## Whether this node plays only when no other Juice node sits beside the Juice Player. It does: a scene with a
## Juice node for 2D beside the player plays through that one, as it always did.
func yields_to_other_juice() -> bool:
	return true

# @ace_hidden
## The field of view that shows a view a percent closer (100 is no change, 110 a tenth closer), measured on the
## size of the view the way a lens zooms.
static func fov_for_zoom(fov: float, percent: float) -> float:
	if percent <= 0.0:
		return fov
	return clampf(rad_to_deg(2.0 * atan(tan(deg_to_rad(fov) * 0.5) * (100.0 / percent))), 1.0, 179.0)

# @ace_hidden
## What an amount really becomes: scaled by the strength of the play, then held under the ceiling while no flashing is on.
func _step_allowed(amount: float, strength: float) -> float:
	var wanted: float = amount * maxf(strength, 0.0)
	if bool(Engine.get_meta(NO_FLASHING_META, false)):
		return clampf(wanted, -STEP_FLASH_CEILING, STEP_FLASH_CEILING)
	return wanted

# @ace_hidden
## And what a time really becomes: never quicker than the floor while no flashing is on.
func _step_seconds(seconds: float) -> float:
	if bool(Engine.get_meta(NO_FLASHING_META, false)):
		return maxf(seconds, STEP_FLASH_FLOOR_SECONDS)
	return maxf(seconds, 0.0)

# @ace_hidden
## Plays ONE card: the same call, with the same five arguments, the 2D Juice node answers to.
func moment_step(verb: String, amount: float, effect: String, seconds: float, strength: float) -> void:
	var word: String = verb.strip_edges().to_lower()
	var named: String = effect.strip_edges().to_lower()
	var span: float = maxf(seconds, 0.0)
	if STEP_AMPLITUDE_VERBS.has(word):
		amount = _step_allowed(amount, strength)
		span = _step_seconds(span)
	var screen: CanvasLayer = null
	if word == "shockwave" or word == "chromatic" or word == "pulse" or word == "hold":
		screen = _moment_screen_fx()
	match word:
		"shake":
			shake(amount)
		"hitstop":
			_step_hitstop(span, clampf(amount, 0.0, 1.0))
		"slowmo":
			_step_slowmo(clampf(amount, 0.0, 1.0), span)
		"flash":
			_step_flash(named, amount, maxf(span, STEP_NATURAL_SECONDS))
		"punch":
			punch_scale(amount, maxf(span, STEP_NATURAL_SECONDS))
		"zoom":
			_step_zoom(amount, maxf(span, STEP_NATURAL_SECONDS))
		"shockwave":
			if screen != null:
				screen.call("shockwave", _step_here(), amount)
			else:
				_moment_wants_screen(word)
		"chromatic":
			if screen != null:
				screen.call("chromatic_pulse", amount, maxf(span, STEP_NATURAL_SECONDS))
			else:
				chromatic_kick(amount, maxf(span, STEP_NATURAL_SECONDS))
		"pulse":
			if screen != null:
				screen.call("pulse_post_effect", named, amount, maxf(span, STEP_NATURAL_SECONDS))
			elif named == "vignette":
				pulse_vignette(amount, Color.BLACK, maxf(span, STEP_NATURAL_SECONDS))
			else:
				_moment_wants_screen(word)
		"hold":
			if screen == null:
				_moment_wants_screen(word)
			else:
				if screen.has_method("hold_post_effect"):
					screen.call("hold_post_effect", named, amount, span)
				else:
					if float(screen.call("post_strength", named)) <= 0.0001:
						screen.call("add_post_effect", named, named, 0.0)
					screen.call("fade_post_strength", named, amount, span, 0.0)
		_:
			push_warning("Juice 3D: no card word is called \"%s\" here." % word)

# @ace_hidden
## Where the thing that caused a card is on the screen, in pixels: the host's place seen through the camera, or the middle of the view.
func _step_here() -> Vector2:
	var cam: Camera3D = _camera()
	if cam != null and host != null and not cam.is_position_behind(host.global_position):
		return cam.unproject_position(host.global_position)
	var view: Viewport = get_viewport()
	return view.get_visible_rect().size * 0.5 if view != null else Vector2.ZERO

# @ace_hidden
func _set_time_scale(scale_now: float) -> void:
	Engine.time_scale = scale_now

# @ace_hidden
## A hit pause: time stops (or slows to the scale given) for a few frames, then goes back to what it was. It ignores
## repeat hits already mid-freeze and holds a slowmo still for the duration.
func _step_hitstop(freeze_seconds: float, freeze_scale: float) -> void:
	if _hitstop_active:
		return
	_hitstop_active = true
	_hitstop_prev_scale = Engine.time_scale
	if _slowmo_tween != null and is_instance_valid(_slowmo_tween) and _slowmo_tween.is_running():
		_slowmo_tween.pause()
	Engine.time_scale = maxf(freeze_scale, 0.0)
	await get_tree().create_timer(maxf(freeze_seconds, 0.0), true, false, true).timeout
	if not _hitstop_active:
		return
	_hitstop_active = false
	Engine.time_scale = _hitstop_prev_scale
	if _slowmo_tween != null and is_instance_valid(_slowmo_tween):
		_slowmo_tween.play()

# @ace_hidden
## Slow motion: time eases down to the scale, holds for the seconds given, and eases back. It counts in real time.
func _step_slowmo(target_scale: float, hold_seconds: float) -> void:
	if _slowmo_tween != null and is_instance_valid(_slowmo_tween):
		_slowmo_tween.kill()
	var tw: Tween = create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_method(_set_time_scale, Engine.time_scale, target_scale, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_interval(maxf(hold_seconds, 0.0))
	tw.tween_method(_set_time_scale, target_scale, 1.0, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_slowmo_tween = tw

# @ace_hidden
## A flash: a 3D sprite or label is tinted towards the colour and fades back; any other host flashes the whole screen.
func _step_flash(tint_word: String, amount: float, span: float) -> void:
	var tint: Color = Color.from_string(tint_word, Color.WHITE)
	var share: float = clampf(amount, 0.0, 1.0)
	var fading: bool = _flash_tween != null and is_instance_valid(_flash_tween) and _flash_tween.is_running()
	if fading:
		_flash_tween.kill()
	if host is SpriteBase3D or host is Label3D:
		if not fading or _flash_on_screen:
			_flash_rest = host.modulate
		_flash_on_screen = false
		host.modulate = _flash_rest.lerp(Color(tint.r, tint.g, tint.b, _flash_rest.a), share)
		_flash_tween = create_tween()
		_flash_tween.tween_property(host, "modulate", _flash_rest, span)
	else:
		set_screen_tint(tint, share * 0.5)
		if _tint_rect != null:
			_flash_on_screen = true
			_flash_tween = create_tween()
			_flash_tween.tween_property(_tint_rect, "color:a", 0.0, span)

# @ace_hidden
## A zoom: the field of view narrows to show the view this percent closer, and stays there until the play is put back.
func _step_zoom(percent: float, span: float) -> void:
	var cam: Camera3D = _camera()
	if cam == null or percent <= 0.0:
		return
	_unapply()
	zoom_fov_to(fov_for_zoom(cam.fov, percent), span)

# @ace_hidden
## A Juice Player is opening a play: write down, ONCE for that player, what the cards will touch is worth now
## (the first value is the one a Restore puts back), and what each will be worth when the cards have run.
func juice_player_began(key: String, steps: Array) -> void:
	var kept: Dictionary = _step_rest.get(key, {})
	var ends: Dictionary = {}
	var cam: Camera3D = _camera()
	var tinted: bool = host is SpriteBase3D or host is Label3D
	for step: Variant in steps:
		if not (step is Dictionary):
			continue
		var card: Dictionary = step as Dictionary
		match str(card.get("verb", "")).strip_edges().to_lower():
			"zoom":
				if cam != null:
					if not kept.has("fov"):
						kept["fov"] = cam.fov - _applied_fov
					ends["fov"] = fov_for_zoom(float(ends.get("fov", kept["fov"])), float(card.get("amount", 100.0)))
			"punch":
				if host is Node3D:
					kept["scale"] = _base_scale3
					ends["scale"] = _base_scale3
			"flash":
				if tinted:
					if not kept.has("tint"):
						kept["tint"] = _flash_rest if _flash_tween != null and is_instance_valid(_flash_tween) and _flash_tween.is_running() else host.modulate
					ends["tint"] = kept["tint"]
			"hitstop", "slowmo":
				if not kept.has("time"):
					kept["time"] = Engine.time_scale
				ends["time"] = 1.0
			"chromatic", "pulse":
				kept["screen"] = true
				ends["screen"] = true
	_step_rest[key] = kept
	_step_ends[key] = ends

# @ace_hidden
## A Juice Player stopped (put_back false) or restored (put_back true): every effect its cards set going on this node
## ends now, whether or not the list has finished walking. A value lands where the cards would have left it, or goes
## back to the first value the player saw. The shakes end either way.
func juice_player_ended(key: String, put_back: bool) -> void:
	stop_position_shake()
	if trauma > 0.0 or _shaking:
		stop_shake()
	if _chroma_shake_active:
		stop_chromatic_shake()
	var values: Dictionary = _step_rest.get(key, {}) if put_back else _step_ends.get(key, {})
	if values.has("time"):
		if _slowmo_tween != null and is_instance_valid(_slowmo_tween):
			_slowmo_tween.kill()
		_slowmo_tween = null
		_hitstop_active = false
		Engine.time_scale = float(values["time"])
	if values.has("fov"):
		if _zoom_tween != null and is_instance_valid(_zoom_tween):
			_zoom_tween.kill()
		var cam: Camera3D = _camera()
		if cam != null:
			_unapply()
			cam.fov = clampf(float(values["fov"]), 1.0, 179.0)
	if values.has("scale") and host is Node3D:
		if _punch_scale_tween != null and is_instance_valid(_punch_scale_tween):
			_punch_scale_tween.kill()
		(host as Node3D).scale = values["scale"]
	if values.has("tint") and (host is SpriteBase3D or host is Label3D):
		if _flash_tween != null and is_instance_valid(_flash_tween):
			_flash_tween.kill()
		host.modulate = values["tint"]
	if values.has("screen"):
		_step_clear_screen()
	if _flash_on_screen and _flash_tween != null and is_instance_valid(_flash_tween):
		_flash_tween.kill()
		_flash_on_screen = false
		clear_screen_tint()
	if put_back:
		_step_rest.erase(key)
	_step_ends.erase(key)

# @ace_hidden
## Ends a vignette pulse and a chromatic kick on the spot, so the screen is clear.
func _step_clear_screen() -> void:
	if _fx_material == null:
		return
	if _vignette_tween != null and _vignette_tween.is_valid():
		_vignette_tween.kill()
	if _chroma_tween != null and _chroma_tween.is_valid():
		_chroma_tween.kill()
	_fx_material.set_shader_parameter("vignette_strength", 0.0)
	_fx_material.set_shader_parameter("chroma_strength", 0.0)
	_fx_update_visibility()

# @ace_hidden
## Says, ONCE PER SCENE, that a step asked for the post stack and this game has none. The three
## steps that reach the screen are the only ones that can want it, and without it a shockwave and a
## hold do nothing at all while a pulse draws only its vignette - each of them silently, which is a
## moment that looks broken and says nothing about why. The sentence names the step and the way out.
func _moment_wants_screen(word: String) -> void:
	if not _first_time_without_a_screen():
		return
	push_warning(("Moment: the \"%s\" step needs a post stack and this scene has none - add the "
		+ "Screen FX pack's screen_fx.tscn to the scene, or take the step out of the moment.") % word)

# @ace_hidden
## Whether this is the FIRST time in this scene that a step has gone without the post stack -
## true once, then false until the scene changes. Its own function so the once-ness is a value
## that can be asked for, rather than a line in a log somebody has to notice.
func _first_time_without_a_screen() -> bool:
	var here: Node = null
	if is_inside_tree():
		here = get_tree().current_scene
	if _moment_told_screen and _moment_told_scene == here:
		return false
	_moment_told_screen = true
	_moment_told_scene = here
	return true

# 3D camera game feel: shake, recoil, head bob, jitter, lean, and FOV punch/zoom on the active Camera3D - auto-found, applied as additive offsets so they never fight the controller that owns the camera. Verbs mirror the 2D Juice pack.
