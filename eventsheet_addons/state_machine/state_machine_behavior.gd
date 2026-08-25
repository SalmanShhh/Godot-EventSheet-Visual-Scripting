## @ace_category("State Machine")
## @ace_expose_all(node)
## @ace_version(1.0.0)
@icon("res://eventsheet_addons/state_machine/icon.svg")
class_name StateMachineBehavior
extends Node
## Gives a node one named "what am I doing right now" state and a clean way to switch it. Go to state changes it, Current state is branches on it, and On any state change fires on every switch with the state you left and the state you entered.

## The node this behavior acts on (its parent). Required host: Node.
var host: Node = null

func _enter_tree() -> void:
	host = get_parent() as Node
	if host == null:
		push_warning("StateMachineBehavior behavior requires a Node parent.")

## @ace_trigger
## @ace_name("On any state change")
## @ace_category("State Machine")
signal state_changed(previous: String, next: String)

## The machine's current state name; change it with Go to state.
@export var state: String = "idle"
var previous_state: String = ""
var _state_entered_ticks: int = 0

## @ace_condition
## @ace_name("Current state is")
## @ace_category("State Machine")
## @ace_description("True while the machine is in the given state.")
## @ace_icon("res://eventsheet_addons/state_machine/icon.svg")
## @ace_codegen_template("$StateMachineBehavior.is_in_state({state_name})")
func is_in_state(state_name: String) -> bool:
	return state == state_name

## @ace_action
## @ace_name("Go to state")
## @ace_category("State Machine")
## @ace_description("Switches to the given state and fires On any state change.")
## @ace_icon("res://eventsheet_addons/state_machine/icon.svg")
## @ace_codegen_template("$StateMachineBehavior.set_state({next})")
func set_state(next: String) -> void:
	if state != next:
		var previous: String = state
		state = next
		previous_state = previous
		_state_entered_ticks = Time.get_ticks_msec()
		state_changed.emit(previous, next)

## @ace_expression
## @ace_name("Time in state")
## @ace_category("State Machine")
## @ace_description("How many seconds the machine has been in its current state.")
## @ace_icon("res://eventsheet_addons/state_machine/icon.svg")
## @ace_codegen_template("$StateMachineBehavior.time_in_state()")
func time_in_state() -> float:
	return (float(Time.get_ticks_msec() - _state_entered_ticks) / 1000.0)

## @ace_hidden
func save_state() -> Dictionary:
	# Save-state seam: the Save System walks any node in its persist group (or targeted
	# by Save/Load Node State) and duck-types these two methods. Plain data only.
	# The parameter is named data (not state) so it never shadows the state member.
	# Loading assigns state directly - a restore must not fire On any state change.
	return {
		"state": state
	}

## @ace_hidden
func load_state(data: Dictionary) -> void:
	if data.is_empty():
		return
	state = str(data.get("state", "idle"))

# State machine behavior: Go to state / Current state is from any sheet; On any state change fires with (previous, next).
