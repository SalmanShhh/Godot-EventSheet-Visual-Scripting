## @ace_category("Flash")
## @ace_expose_all(node)
## @ace_version(1.0.0)
@icon("res://eventsheet_addons/flash/icon.svg")
class_name FlashBehavior
extends Node
## Blinks the host node's visibility on and off for a duration, then snaps it back to fully visible and fires On Flash Finished. The classic damage-flicker and invincibility-frames effect, with a single interval knob you can change live.

## The node this behavior acts on (its parent). Required host: CanvasItem.
var host: CanvasItem = null

func _enter_tree() -> void:
	host = get_parent() as CanvasItem
	if host == null:
		push_warning("FlashBehavior behavior requires a CanvasItem parent.")

## @ace_trigger
## @ace_name("On Flash Finished")
## @ace_category("Flash")
signal flash_finished

## Seconds between visibility toggles - smaller values blink faster.
@export var interval: float = 0.1
var remaining: float = 0.0
var accumulator: float = 0.0
var flashing: bool = false
var blink_pattern: Resource = null
var blink_index: int = 0
var blink_left: int = 0
var blink_shown: bool = true
var blink_timer: float = 0.0
var blink_limit: float = 0.0
var blinking: bool = false

# --- Blink patterns: a rhythm the game owns, played on the host ---

## The project-wide answer to "this player has asked for no flashing", the same plain Engine
## meta every other flashing thing here reads, so one row sets it for the whole game.
const BLINK_NO_FLASHING_META: StringName = &"no_flashing"

## No part of a blink may be shorter than this once no flashing has been asked for: the pattern
## still plays, at a rate nobody can be hurt by. A strobe is a medical problem rather than a
## taste, which is why the ceiling is held here instead of trusted to each pattern file.
const BLINK_FLOOR_SECONDS: float = 0.4

func _ready() -> void:
	set_process(false)

func _process(delta: float) -> void:
	if flashing and is_instance_valid(host):
		remaining += -delta
		accumulator += delta
		if accumulator >= interval:
			accumulator = 0.0
			if bool(Engine.get_meta("no_flashing", false)):
				host.visible = true
				host.modulate.a = 1.0 if host.modulate.a < 0.7 else 0.35
			else:
				host.visible = not host.visible
		if remaining <= 0.0:
			flashing = false
			host.visible = true
			host.modulate.a = 1.0
			set_process(false)
			flash_finished.emit()
	if blinking:
		_blink_step(delta)

## @ace_action
## @ace_name("Flash")
## @ace_category("Flash")
## @ace_description("Blinks the host for the given number of seconds.")
## @ace_icon("res://eventsheet_addons/flash/icon.svg")
## @ace_codegen_template("$FlashBehavior.flash({seconds})")
func flash(seconds: float) -> void:
	remaining = seconds
	accumulator = 0.0
	flashing = true
	set_process(true)

## @ace_action
## @ace_name("Stop Flash")
## @ace_category("Flash")
## @ace_description("Stops flashing and restores visibility.")
## @ace_icon("res://eventsheet_addons/flash/icon.svg")
## @ace_codegen_template("$FlashBehavior.stop_flash()")
func stop_flash() -> void:
	flashing = false
	set_process(false)
	if is_instance_valid(host):
		host.visible = true

## @ace_action
## @ace_name("Blink")
## @ace_category("Flash")
## @ace_description("Plays a blink pattern on the host: a BlinkPatternResource file of phases, each one "on for this long, off for that long, this many times". A player who has asked for no flashing gets the same pattern held to a floor and faded instead of hidden, so a pattern can never strobe.")
## @ace_display_template("Blink [b]{pattern}[/b] for [b]{seconds}[/b] s")
## @ace_param(pattern, desc: "The BlinkPatternResource file to play. It is your file: draw the rhythm once in the Inspector and share it between everything that blinks that way.")
## @ace_param(seconds, desc: "Stop after this long, whatever the pattern is doing. 0 plays the pattern out to its last phase.")
## @ace_icon("res://eventsheet_addons/flash/icon.svg")
## @ace_codegen_template("$FlashBehavior.blink({pattern}, {seconds})")
func blink(pattern: Resource, seconds: float) -> void:
	if pattern == null:
		return
	blink_pattern = pattern
	blink_index = 0
	blink_left = _blink_repeats()
	blink_shown = true
	blink_timer = _blink_hold(_blink_phase_number("on", 0.08))
	blink_limit = maxf(seconds, 0.0)
	blinking = not _blink_phases().is_empty()
	_blink_apply()
	if blinking:
		# A blinking host needs the frame it blinks in; the pattern's own end turns it back off.
		set_process(true)

## @ace_action
## @ace_name("Stop Blink")
## @ace_category("Flash")
## @ace_description("Ends the blink now and hands the host back fully visible, wherever in the pattern it had got to.")
## @ace_icon("res://eventsheet_addons/flash/icon.svg")
## @ace_codegen_template("$FlashBehavior.stop_blink()")
func stop_blink() -> void:
	_blink_end()

## @ace_condition
## @ace_name("Is Blinking")
## @ace_category("Flash")
## @ace_description("Whether a blink pattern is playing on this host right now.")
## @ace_icon("res://eventsheet_addons/flash/icon.svg")
## @ace_codegen_template("$FlashBehavior.is_blinking()")
func is_blinking() -> bool:
	return blinking

## @ace_expression
## @ace_name("Blink Phase")
## @ace_category("Flash")
## @ace_description("Which phase of the pattern is playing, counting from 1. 0 when nothing is blinking - so a row can tell the fast winks from the slow ones that follow them.")
## @ace_icon("res://eventsheet_addons/flash/icon.svg")
## @ace_codegen_template("$FlashBehavior.blink_phase()")
func blink_phase() -> int:
	if not blinking:
		return 0
	return blink_index + 1

## Whether the player has asked for no flashing at all.
func _blink_reduced() -> bool:
	return bool(Engine.get_meta(BLINK_NO_FLASHING_META, false))

## How long one part of a phase really lasts: what the file says, floored so a pattern advances
## even when its numbers are shorter than a frame, and floored much harder for a player who has
## asked for no flashing.
func _blink_hold(seconds: float) -> float:
	if _blink_reduced():
		return maxf(seconds, BLINK_FLOOR_SECONDS)
	return maxf(seconds, 0.01)

## The phases of the pattern in flight, or nothing at all when the file is missing or empty.
func _blink_phases() -> Array:
	if blink_pattern == null:
		return []
	var listed: Variant = blink_pattern.get("phases")
	if listed is Array:
		return listed
	return []

## One number out of the phase now playing, with the fallback a file that left it out gets.
func _blink_phase_number(key: String, fallback: float) -> float:
	var phases: Array = _blink_phases()
	if blink_index < 0 or blink_index >= phases.size():
		return fallback
	var phase: Dictionary = phases[blink_index]
	return float(phase.get(key, fallback))

## How many times the phase now playing repeats. Always at least once: a phase nobody plays is
## a phase nobody can see, and a file that says 0 meant one.
func _blink_repeats() -> int:
	return maxi(int(_blink_phase_number("count", 1.0)), 1)

## The host, as the blink wants it this instant.
func _blink_apply() -> void:
	if host == null:
		return
	if _blink_reduced():
		# The same answer the flash above gives: the host stays where the eye can find it and
		# steps between full and faint instead of disappearing.
		host.visible = true
		host.modulate.a = 1.0 if blink_shown else 0.35
	else:
		host.visible = blink_shown

## The end of a blink, however it came: the host is handed back whole.
func _blink_end() -> void:
	blinking = false
	blink_index = 0
	blink_left = 0
	blink_shown = true
	if host != null:
		host.visible = true
		host.modulate.a = 1.0
	# A blink that is over costs nothing per frame - and a flash that is still running keeps its
	# own tick, which is why this asks rather than simply switching processing off.
	set_process(flashing)

## One frame of a blink. The timer runs down, and every time it runs out the host flips: an on
## part becomes an off part, an off part spends one of the phase's repeats, and a phase with no
## repeats left hands over to the next one. A while rather than an if, so a pattern whose parts
## are shorter than a frame still advances instead of drifting behind.
func _blink_step(delta: float) -> void:
	if not blinking:
		return
	if blink_limit > 0.0:
		blink_limit -= delta
		if blink_limit <= 0.0:
			_blink_end()
			return
	blink_timer -= delta
	while blinking and blink_timer <= 0.0:
		if blink_shown:
			blink_shown = false
			blink_timer += _blink_hold(_blink_phase_number("off", 0.08))
		else:
			blink_left -= 1
			if blink_left <= 0:
				blink_index += 1
				if blink_index >= _blink_phases().size():
					_blink_end()
					return
				blink_left = _blink_repeats()
			blink_shown = true
			blink_timer += _blink_hold(_blink_phase_number("on", 0.08))
		_blink_apply()
	# A blink owns this frame even when a flash that ended in the same one has just given it up.
	set_process(true)

# Flash behavior (event-sheet-style): blinks the host's visibility for a duration, then restores it and fires On Flash Finished.
