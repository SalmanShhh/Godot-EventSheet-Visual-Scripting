# Godot EventSheets - the tree announcing a node joining or leaving a group.
#
# What this gate holds, in the order the mistakes actually happen:
#   1. THE CONNECTION. Each trigger is one of the scene tree's OWN signals, wired once in `_ready`
#      like every other lifted trigger, and the two do not share a handler - `node_added` and
#      `node_removed` are different signals, and the crowd trigger already owns `_on_node_removed`.
#   2. THE FILTER IS A ROW. Picking the trigger puts the SHIPPED Is In Group condition in the sheet
#      with the trigger's own group in it - one condition, not a hidden wrapper and not a new row
#      re-saying a question the vocabulary already had. It compiles to a plain `if`.
#   3. THE FIREHOSE HAS NO GATE. The stated Any group choice means every node entering or leaving the
#      world, so nothing is added under it and the event says exactly what it does.
#   4. THE LIFT. The connect-plus-is_in_group-guard shape somebody wrote by hand opens as the
#      trigger, filter and all, and the file re-emits byte for byte.
#   5. THE HONEST FACTS. The cost (the guard runs for every node, with the figure MEASURED rather
#      than asserted), the timing (a group joined in _ready is joined too late, and that node is
#      never matched at all) and teardown (every member leaves when a branch is freed or the game
#      quits) are all stated on the rows, not hidden.
#
# Values are pinned, never counts.
@tool
class_name GroupArrivalTest
extends RefCounted

const MODULE_PATH: String = "res://addons/eventforge/registration/modules/group_arrival_aces.gd"


static func run() -> bool:
	var passed: bool = true
	passed = _test_each_trigger_is_its_own_tree_signal() and passed
	passed = _test_the_filter_is_the_shipped_condition() and passed
	passed = _test_any_group_gets_no_gate() and passed
	passed = _test_hand_written_code_opens_as_the_trigger() and passed
	passed = _test_the_cost_and_the_timing_are_stated() and passed
	return passed


# ── 1. The connection ──


static func _test_each_trigger_is_its_own_tree_signal() -> bool:
	var passed: bool = true
	var output: String = _compiled("OnNodeJoinsGroup", "\"minimap\"", "user://eventforge_group_join.gd")
	passed = _check("a join is the tree's own node-added signal",
		output.contains("\tget_tree().node_added.connect(_on_node_joined_group)"), true) and passed
	passed = _check("and the handler is handed the node that arrived",
		output.contains("func _on_node_joined_group(node: Node) -> void:"), true) and passed
	var leaving: String = _compiled("OnNodeLeavesGroup", "\"minimap\"", "user://eventforge_group_leave.gd")
	passed = _check("a departure is the tree's own node-removed signal",
		leaving.contains("\tget_tree().node_removed.connect(_on_node_left_group)"), true) and passed
	# NOT the crowd trigger's handler. Two events answering different questions off one signal must
	# not share a function, or one event's body ends up under the other's gate.
	passed = _check("and it does not take over the crowd trigger's handler name",
		leaving.contains("_on_node_removed"), false) and passed
	return passed


# ── 2 and 3. The filter, and the firehose ──


static func _test_the_filter_is_the_shipped_condition() -> bool:
	var module: GDScript = load(MODULE_PATH)
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	dock.setup(EventSheetResource.new())
	var definition: ACEDefinition = dock._ace_registry.find_definition("Core", str(module.get("JOINS_TRIGGER_ID")))
	var passed: bool = _check("the trigger is registered", definition != null, true)
	if definition == null:
		dock.free()
		return false
	var event: EventRow = _applied(dock, definition, "\"bats\"")
	passed = _check("applying the trigger adds one condition row, not a hidden wrapper",
		event.conditions.size(), 1) and passed
	if event.conditions.size() == 1:
		var gate: ACECondition = event.conditions[0] as ACECondition
		passed = _check("and it is the SHIPPED Is In Group row rather than a new one",
			gate.ace_id, "IsInGroup") and passed
		passed = _check("asked of the node the trigger handed over",
			str(gate.params.get("target", "")), "node") and passed
		passed = _check("about the group the trigger already named",
			str(gate.params.get("group", "")), "\"bats\"") and passed
	dock.free()

	# And what that condition writes: an ordinary `if` inside the handler.
	var output: String = _compiled("OnNodeJoinsGroup", "\"minimap\"", "user://eventforge_group_gate.gd")
	passed = _check("the gate is an ordinary if in the emitted handler",
		output.contains("\tif node.is_in_group(\"minimap\"):"), true) and passed
	passed = _check("and the body runs under it",
		output.contains("\t\tprint(\"arrived\")"), true) and passed
	return passed


static func _test_any_group_gets_no_gate() -> bool:
	var module: GDScript = load(MODULE_PATH)
	var passed: bool = _check("the Any group choice is the empty name, which is visibly not a group",
		str(module.get("ANY_GROUP")), "\"\"")
	passed = _check("and a blank field means the same thing",
		module.call("is_any_group", ""), true) and passed
	passed = _check("while a real group name does not",
		module.call("is_any_group", "\"enemies\""), false) and passed
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	dock.setup(EventSheetResource.new())
	var definition: ACEDefinition = dock._ace_registry.find_definition("Core", str(module.get("LEAVES_TRIGGER_ID")))
	if definition == null:
		dock.free()
		return _check("the departure trigger is registered", false, true) and passed
	var event: EventRow = _applied(dock, definition, str(module.get("ANY_GROUP")))
	passed = _check("the firehose gets no gate under it", event.conditions.size(), 0) and passed
	dock.free()
	return passed


# ── 4. The lift ──


static func _test_hand_written_code_opens_as_the_trigger() -> bool:
	var source: String = _compiled("OnNodeJoinsGroup", "\"minimap\"", "user://eventforge_group_lift.gd")
	var imported: EventSheetResource = GDScriptImporter.new().import_external_source(source)
	var lifted: EventRow = null
	for row: Variant in imported.events:
		if row is EventRow and (row as EventRow).trigger_id == "OnNodeJoinsGroup":
			lifted = row
	var passed: bool = _check("the connect and its guarded handler open as the trigger", lifted != null, true)
	if lifted != null:
		passed = _check("with the filter read back as a condition row rather than lost",
			lifted.conditions.size(), 1) and passed
		if lifted.conditions.size() == 1:
			var gate: ACECondition = lifted.conditions[0] as ACECondition
			passed = _check("and the group it filters on survives the open",
				str(gate.params.get("group", "")), "\"minimap\"") and passed
	imported.external_source_path = "user://eventforge_group_lift_back.gd"
	passed = _check("and the opened file re-emits byte for byte",
		_compile(imported, "user://eventforge_group_lift_back.gd") == source, true) and passed
	return passed


# ── 5. The two honest facts ──


static func _test_the_cost_and_the_timing_are_stated() -> bool:
	var by_id: Dictionary = {}
	for descriptor: Variant in load(MODULE_PATH).call("get_descriptors"):
		if descriptor is ACEDescriptor:
			by_id[str((descriptor as ACEDescriptor).ace_id)] = descriptor
	var joins: String = str(by_id.get("OnNodeJoinsGroup", ACEDescriptor.new()).description)
	var passed: bool = _check("the cost is stated on the row",
		joins.contains("every node entering the world"), true)
	# MEASURED, not asserted. The repo standard is that a figure is taken off a machine rather than
	# guessed, and "nothing worth measuring" is the sentence a reader quotes back after their spawn
	# path gets slower - so the row carries the number instead.
	passed = _check("and the cost carries its measured figure",
		joins.contains("0.34 microseconds per node"), true) and passed
	# THE TIMING, said where it actually bites. `node_added` is emitted BEFORE `_ready` runs, so a
	# group joined there - the commonest place a project joins one - is never matched by this trigger
	# at all. The old wording said "after add_child", which no reader maps onto _ready, and it also
	# promised the next join would announce it, which is not true of that node.
	passed = _check("and so is the timing, named at the place it bites",
		joins.contains("_ready is joined too late"), true) and passed
	# The departure row states the one thing that separates it from the crowd trigger: it fires for a
	# move as well as a destroy, and does not pretend otherwise - and that teardown is a departure,
	# which is what makes the body run once per member against a tree being taken apart.
	var leaves: String = str(by_id.get("OnNodeLeavesGroup", ACEDescriptor.new()).description)
	passed = _check("the departure row admits it fires on a reparent too",
		leaves.contains("a move to another parent included"), true) and passed
	passed = _check("and that every member leaves when the game is taken apart",
		leaves.contains("TEARDOWN IS A DEPARTURE TOO"), true) and passed
	return passed


# ── Harness ──


## One trigger applied through the dock's own bake step, with the group the author typed on it.
static func _applied(dock: EventSheetDock, definition: ACEDefinition, group_value: String) -> EventRow:
	var event: EventRow = EventRow.new()
	var trigger: ACECondition = ACECondition.new()
	trigger.provider_id = "Core"
	trigger.ace_id = definition.id
	trigger.params = {"group": group_value}
	event.trigger = trigger
	dock._ace_apply._bake_trigger_signature(event, definition)
	return event


## One arrival event, gate and all, compiled on a Node2D host - the smallest sheet that holds one.
static func _compiled(trigger_id: String, group_value: String, path: String) -> String:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = trigger_id
	event.trigger_params = {"group": group_value}
	var gate: ACECondition = ACECondition.new()
	gate.provider_id = "Core"
	gate.ace_id = "IsInGroup"
	gate.codegen_template = "{target}.is_in_group({group})"
	gate.params = {"target": "node", "group": group_value}
	event.conditions.append(gate)
	var printed: ACEAction = ACEAction.new()
	printed.provider_id = "Core"
	printed.ace_id = "Print"
	printed.params = {"value": "\"arrived\""}
	event.actions.append(printed)
	sheet.events.append(event)
	return _compile(sheet, path)


static func _compile(sheet: EventSheetResource, path: String) -> String:
	return str(SheetCompiler.compile(sheet, path).get("output", ""))


static func _check(label: String, got: Variant, expected: Variant) -> bool:
	if got == expected:
		return true
	print("[FAIL] group_arrival_test: %s -> expected %s, got %s" % [label, expected, got])
	return false
