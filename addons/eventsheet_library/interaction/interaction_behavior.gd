## @ace_tags(interaction, focus, prompt)
## @ace_category("Interaction")
## @ace_expose_all(node)
## @ace_version(1.0.0)
@icon("res://eventsheet_addons/interaction/icon.svg")
class_name InteractionBehavior
extends Node
## The "press E to open it" behavior, worn by the PLAYER. Focus Nearest Interactable keeps one candidate in focus while it is in range, On Focus Changed fires the instant that candidate changes (or goes away) so a prompt label and a highlight can follow it, and Interact With Focus calls the focused thing's own interact() function.

## The node this behavior acts on (its parent). Required host: Node2D.
var host: Node2D = null

func _enter_tree() -> void:
	host = get_parent() as Node2D
	if host == null:
		push_warning("InteractionBehavior behavior requires a Node2D parent.")

## @ace_trigger
## @ace_name("On Focus Changed")
## @ace_category("Interaction")
signal on_focus_changed(node: Node)
## @ace_trigger
## @ace_name("On Interacted")
## @ace_category("Interaction")
signal on_interacted(node: Node)

# The interactable currently in focus, or null when nothing is in reach. Read it with the
# Focused Node expression; every change goes through _set_focus so the trigger stays an edge.
var _focus: Node = null

## @ace_action
## @ace_featured
## @ace_name("Focus Nearest Interactable")
## @ace_category("Interaction")
## @ace_description("Focuses the nearest node in the given group that is within reach (in pixels), or nothing at all when none are. Run this under a per-frame trigger (On Every Tick) - it re-picks every tick, but On Focus Changed only fires when the focused node actually changes, including when it becomes nothing.")
## @ace_display_template("Focus nearest [b]{group_name}[/b] within [b]{within}[/b] px")
## @ace_icon("res://eventsheet_addons/interaction/icon.svg")
## @ace_codegen_template("$InteractionBehavior.focus_nearest({group_name}, {within})")
func focus_nearest(group_name: String, within: float) -> void:
	if host == null or not is_inside_tree():
		return
	var best: Node2D = null
	var best_distance: float = within
	for member: Node in get_tree().get_nodes_in_group(group_name):
		var candidate: Node2D = member as Node2D
		if candidate == null or candidate == host:
			continue
		var distance: float = host.global_position.distance_to(candidate.global_position)
		if distance <= best_distance:
			best_distance = distance
			best = candidate
	_set_focus(best)

## @ace_action
## @ace_featured
## @ace_name("Interact With Focus")
## @ace_category("Interaction")
## @ace_description("Interacts with the focused node: if it has a function named interact(), that function is called. On Interacted fires either way, so a thing with no interact() of its own can still be handled entirely from a sheet.")
## @ace_icon("res://eventsheet_addons/interaction/icon.svg")
## @ace_codegen_template("$InteractionBehavior.interact_with_focus()")
func interact_with_focus() -> void:
	if _focus == null or not is_instance_valid(_focus):
		return
	if _focus.has_method("interact"):
		_focus.call("interact")
	on_interacted.emit(_focus)

## @ace_action
## @ace_name("Clear Focus")
## @ace_category("Interaction")
## @ace_description("Drops the current focus (firing On Focus Changed with nothing) - for cutscenes, menus, and death, where the prompt should disappear even though the player has not moved.")
## @ace_icon("res://eventsheet_addons/interaction/icon.svg")
## @ace_codegen_template("$InteractionBehavior.clear_focus()")
func clear_focus() -> void:
	_set_focus(null)

## @ace_condition
## @ace_name("Has Focus")
## @ace_category("Interaction")
## @ace_description("True while something interactable is in focus - the condition that shows and hides your "Press E" prompt.")
## @ace_icon("res://eventsheet_addons/interaction/icon.svg")
## @ace_codegen_template("$InteractionBehavior.has_focus()")
func has_focus() -> bool:
	return _focus != null and is_instance_valid(_focus)

## @ace_expression
## @ace_name("Focused Node")
## @ace_category("Interaction")
## @ace_description("The node currently in focus, or nothing when none is. Feed it to the Juice pack's Start Blinking to highlight it, or read a name off it for the prompt text.")
## @ace_icon("res://eventsheet_addons/interaction/icon.svg")
## @ace_codegen_template("$InteractionBehavior.focused_node()")
func focused_node() -> Node:
	return _focus if _focus != null and is_instance_valid(_focus) else null

## @ace_hidden
func _set_focus(new_focus: Node) -> void:
	if new_focus == _focus:
		return
	_focus = new_focus
	on_focus_changed.emit(_focus)

# Interaction behavior: attach to the PLAYER. Run Focus Nearest Interactable under a per-frame trigger (On Every Tick) with your interactables' group name and a reach in pixels; it keeps the nearest one in focus and fires On Focus Changed whenever that changes - including with null when you walk out of range. Highlight the focused node with the Juice pack's Start Blinking and show the prompt with a HUD Kit label. Interact With Focus calls interact() on the focused node if it has one, and always fires On Interacted.
