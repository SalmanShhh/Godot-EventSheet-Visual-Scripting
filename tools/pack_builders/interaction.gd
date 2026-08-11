# Pack builder - interaction (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## Interaction: the "press E to open the chest" behavior. It goes on the PLAYER (not on the thing),
## keeps ONE focused interactable at a time, and tells you the moment that focus changes so a
## prompt can appear and a highlight can start. The thing itself stays plain: give it a function
## named interact() and Interact With Focus calls it.
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "Node2D"
	sheet.custom_class_name = "InteractionBehavior"
	sheet.class_description = "The \"press E to open it\" behavior, worn by the PLAYER. Focus Nearest Interactable keeps one candidate in focus while it is in range, On Focus Changed fires the instant that candidate changes (or goes away) so a prompt label and a highlight can follow it, and Interact With Focus calls the focused thing's own interact() function."
	sheet.addon_category = "Interaction"
	sheet.addon_tags = PackedStringArray(["interaction", "focus", "prompt"])
	sheet.ace_expose_all_mode = "node"

	var about: CommentRow = CommentRow.new()
	about.text = "Interaction behavior: attach to the PLAYER. Run Focus Nearest Interactable under a per-frame trigger (On Every Tick) with your interactables' group name and a reach in pixels; it keeps the nearest one in focus and fires On Focus Changed whenever that changes - including with null when you walk out of range. Highlight the focused node with the Juice pack's Start Blinking and show the prompt with a HUD Kit label. Interact With Focus calls interact() on the focused node if it has one, and always fires On Interacted."
	sheet.events.append(about)

	var focus_changed: SignalRow = SignalRow.new()
	focus_changed.signal_name = "on_focus_changed"
	focus_changed.params = PackedStringArray(["node: Node"])
	focus_changed.trigger = true
	focus_changed.ace_name = "On Focus Changed"
	focus_changed.ace_category = "Interaction"
	sheet.events.append(focus_changed)

	var interacted: SignalRow = SignalRow.new()
	interacted.signal_name = "on_interacted"
	interacted.params = PackedStringArray(["node: Node"])
	interacted.trigger = true
	interacted.ace_name = "On Interacted"
	interacted.ace_category = "Interaction"
	sheet.events.append(interacted)

	# Class-level state plus the one internal that owns every focus change. Routing every write
	# through _set_focus is what makes On Focus Changed an EDGE (once per real change) rather than
	# a per-frame firehose - Focus Nearest Interactable runs every tick and mostly re-picks the
	# same node.
	var state: RawCodeRow = RawCodeRow.new()
	state.code = "\n".join(PackedStringArray([
		"# The interactable currently in focus, or null when nothing is in reach. Read it with the",
		"# Focused Node expression; every change goes through _set_focus so the trigger stays an edge.",
		"var _focus: Node = null",
		"",
		"## @ace_hidden",
		"func _set_focus(new_focus: Node) -> void:",
		"\tif new_focus == _focus:",
		"\t\treturn",
		"\t_focus = new_focus",
		"\ton_focus_changed.emit(_focus)"
	]))
	sheet.events.append(state)

	Lib.append_function(sheet, "focus_nearest", "Focus Nearest Interactable", "Interaction",
		"Focuses the nearest node in the given group that is within reach (in pixels), or nothing at all when none are. Run this under a per-frame trigger (On Every Tick) - it re-picks every tick, but On Focus Changed only fires when the focused node actually changes, including when it becomes nothing.",
		[["group_name", "String"], ["within", "float"]],
		"\n".join(PackedStringArray([
			"if host == null or not is_inside_tree():",
			"\treturn",
			"var best: Node2D = null",
			"var best_distance: float = within",
			"for member: Node in get_tree().get_nodes_in_group(group_name):",
			"\tvar candidate: Node2D = member as Node2D",
			"\tif candidate == null or candidate == host:",
			"\t\tcontinue",
			"\tvar distance: float = host.global_position.distance_to(candidate.global_position)",
			"\tif distance <= best_distance:",
			"\t\tbest_distance = distance",
			"\t\tbest = candidate",
			"_set_focus(best)"
		])),
		"Focus nearest [b]{group_name}[/b] within [b]{within}[/b] px")

	Lib.append_function(sheet, "interact_with_focus", "Interact With Focus", "Interaction",
		"Interacts with the focused node: if it has a function named interact(), that function is called. On Interacted fires either way, so a thing with no interact() of its own can still be handled entirely from a sheet.",
		[],
		"\n".join(PackedStringArray([
			"if _focus == null or not is_instance_valid(_focus):",
			"\treturn",
			"if _focus.has_method(\"interact\"):",
			"\t_focus.call(\"interact\")",
			"on_interacted.emit(_focus)"
		])))

	Lib.append_function(sheet, "clear_focus", "Clear Focus", "Interaction",
		"Drops the current focus (firing On Focus Changed with nothing) - for cutscenes, menus, and death, where the prompt should disappear even though the player has not moved.",
		[],
		"_set_focus(null)")

	Lib.condition(sheet, "has_focus", "Has Focus", "Interaction",
		"True while something interactable is in focus - the condition that shows and hides your \"Press E\" prompt.",
		[],
		"return _focus != null and is_instance_valid(_focus)")

	var focused_node: EventFunction = Lib.exposed_function("focused_node", "Focused Node", "Interaction",
		"The node currently in focus, or nothing when none is. Feed it to the Juice pack's Start Blinking to highlight it, or read a name off it for the prompt text.",
		[],
		"return _focus if _focus != null and is_instance_valid(_focus) else null")
	focused_node.return_type = TYPE_OBJECT
	focused_node.return_type_name = "Node"
	sheet.functions.append(focused_node)

	Lib.feature_verbs(sheet, ["focus_nearest", "interact_with_focus"])
	return Lib.save_pack(sheet, "res://eventsheet_addons/interaction/interaction_behavior")
