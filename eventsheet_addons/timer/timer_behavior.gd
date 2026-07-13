## @ace_category("Timer")
## @ace_expose_all(node)
@icon("res://eventsheet_addons/behavior.svg")
class_name TimerBehavior
extends Node

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
var remaining: float = 0.0
## When on, the timer restarts after firing On Timer instead of stopping.
@export var repeating: bool = false
var running: bool = false

func _process(delta: float) -> void:
	if running:
		remaining += -delta
		if remaining <= 0.0:
			timer_finished.emit()
			if repeating:
				remaining = duration
			else:
				running = false

## @ace_action
## @ace_name("Start Timer")
## @ace_category("Timer")
## @ace_description("Starts (or restarts) the countdown with the given duration.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$TimerBehavior.start_timer({seconds})")
func start_timer(seconds: float) -> void:
	duration = seconds
	remaining = seconds
	running = true

## @ace_action
## @ace_name("Stop Timer")
## @ace_category("Timer")
## @ace_description("Stops the countdown without firing On Timer.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$TimerBehavior.stop_timer()")
func stop_timer() -> void:
	running = false

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

# Timer behavior (event-sheet-style): Start Timer / Stop Timer from any sheet; the On Timer trigger fires when it elapses (repeats when 'repeating').
