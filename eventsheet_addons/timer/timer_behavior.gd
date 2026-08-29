## @ace_category("Timer")
## @ace_expose_all(node)
## @ace_version(1.0.0)
@icon("res://eventsheet_addons/timer/icon.svg")
class_name TimerBehavior
extends Node
## A private countdown clock on any node: set the seconds, start it, and On Timer fires when it reaches zero. Turn on repeating for a fixed metronome beat, or leave it off to fire once and stop.

## The node this behavior acts on (its parent). Required host: Node.
var host: Node = null

func _enter_tree() -> void:
	host = get_parent() as Node
	if host == null:
		push_warning("TimerBehavior behavior requires a Node parent.")

## @ace_trigger
## @ace_name("On Timer")
## @ace_category("Timer")
signal timer_finished

## Length of the countdown in seconds; the timer resets to this each time it repeats.
@export var duration: float = 1.0
## When on, the timer restarts after firing On Timer instead of stopping.
@export var repeating: bool = false
var remaining: float = 0.0
var running: bool = false

func _ready() -> void:
	set_process(running)

func _process(delta: float) -> void:
	if running:
		remaining += -delta
		if remaining <= 0.0:
			timer_finished.emit()
			if repeating:
				remaining = duration
			else:
				running = false
				set_process(false)

## @ace_action
## @ace_name("Start Timer")
## @ace_category("Timer")
## @ace_description("Starts (or restarts) the countdown with the given duration.")
## @ace_icon("res://eventsheet_addons/timer/icon.svg")
## @ace_codegen_template("$TimerBehavior.start_timer({seconds})")
func start_timer(seconds: float) -> void:
	duration = seconds
	remaining = seconds
	running = true
	set_process(true)

## @ace_action
## @ace_name("Stop Timer")
## @ace_category("Timer")
## @ace_description("Stops the countdown without firing On Timer.")
## @ace_icon("res://eventsheet_addons/timer/icon.svg")
## @ace_codegen_template("$TimerBehavior.stop_timer()")
func stop_timer() -> void:
	running = false
	set_process(false)

## @ace_hidden
func save_state() -> Dictionary:
	# Save-state seam: the Save System walks any node in its persist group (or targeted
	# by Save/Load Node State) and duck-types these two methods. Plain data only.
	return {
		"remaining": remaining,
		"running": running,
		"duration": duration,
		"repeating": repeating
	}

## @ace_hidden
func load_state(state: Dictionary) -> void:
	if state.is_empty():
		return
	remaining = float(state.get("remaining", 0.0))
	running = bool(state.get("running", false))
	duration = float(state.get("duration", 1.0))
	repeating = bool(state.get("repeating", false))
	# A loaded save can restore a timer that was mid-countdown, so processing follows the
	# state that came back rather than the state the scene was authored with.
	set_process(running)

# Timer behavior (event-sheet-style): Start Timer / Stop Timer from any sheet; the On Timer trigger fires when it elapses (repeats when 'repeating').
