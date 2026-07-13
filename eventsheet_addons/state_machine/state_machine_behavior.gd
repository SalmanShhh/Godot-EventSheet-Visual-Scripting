## @ace_category("State Machine")
## @ace_expose_all(node)
@icon("res://eventsheet_addons/behavior.svg")
class_name StateMachineBehavior
extends Node

## The node this behavior acts on (its parent). Required host: Node.
var host: Node = null

func _enter_tree() -> void:
	host = get_parent() as Node
	if host == null:
		push_warning("StateMachineBehavior behavior requires a Node parent.")

## @ace_trigger
## @ace_name("On State Changed")
## @ace_category("State Machine")
signal state_changed(previous: String, next: String)

@export var state: String = "idle"

## @ace_condition
## @ace_name("Is In State")
## @ace_category("State Machine")
## @ace_description("True while the machine is in the given state.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$StateMachineBehavior.is_in_state({state_name})")
func is_in_state(state_name: String) -> bool:
	return state == state_name

## @ace_action
## @ace_name("Set State")
## @ace_category("State Machine")
## @ace_description("Switches to the given state and fires On State Changed.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$StateMachineBehavior.set_state({next})")
func set_state(next: String) -> void:
	if state != next:
		var previous: String = state
		state = next
		state_changed.emit(previous, next)

## @ace_hidden
func save_state() -> Dictionary:
	# Save-state seam: the Save System walks any node in its persist group (or targeted
	# by Save/Load Node State) and duck-types these two methods. Plain data only.
	# The parameter is named data (not state) so it never shadows the state member.
	# Loading assigns state directly - a restore must not fire On State Changed.
	return {
		"state": state
	}

## @ace_hidden
func load_state(data: Dictionary) -> void:
	if data.is_empty():
		return
	state = str(data.get("state", "idle"))

# State machine behavior: Set State / Is In State from any sheet; On State Changed fires with (previous, next).
