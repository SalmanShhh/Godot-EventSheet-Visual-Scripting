# Godot EventSheets - the notes a list of nodes earns: a group is Godot's tool for an unordered set.
@tool
class_name NodeListFindingsTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const NAME := "node_list_findings"

const UNORDERED := "extends Node\n\nvar selected: Array[Node2D] = []\n\n\nfunc _on_clicked(unit: Node2D) -> void:\n\tselected.append(unit)\n\n\nfunc _process(_delta: float) -> void:\n\tfor unit: Node2D in selected:\n\t\tunit.hide()\n"
const ORDERED := "extends Node\n\nvar turns: Array[Node2D] = []\n\n\nfunc _process(_delta: float) -> void:\n\tvar next = turns.front()\n\tfor unit: Node2D in turns:\n\t\tunit.hide()\n"
const CLEANED := "extends Node\n\nvar turns: Array[Node2D] = []\n\n\nfunc _process(_delta: float) -> void:\n\tvar next = turns.front()\n\tfor unit: Node2D in turns:\n\t\tunit.hide()\n\tturns.erase(next)\n"
const PLAIN_NUMBERS := "extends Node\n\nvar scores: Array[int] = []\n\n\nfunc _process(_delta: float) -> void:\n\tscores.append(1)\n"


static func _kinds(source: String) -> PackedStringArray:
	var sheet: EventSheetResource = SUPPORT.reopen(source, true, "")
	sheet.external_source_path = "user://node_list_findings_probe.gd"
	var kinds: PackedStringArray = PackedStringArray()
	for finding: Dictionary in EventSheetMistakeFindings.findings(sheet, "user://node_list_findings_probe.gd"):
		var kind: String = str(finding.get("kind", ""))
		if kind.begins_with("node-list") or kind.begins_with("reaches-into"):
			kinds.append(kind)
	return kinds


static func run() -> bool:
	var ok: bool = true
	ok = SUPPORT.check(NAME, "a list of nodes never read by order is an amber row", _kinds(UNORDERED), PackedStringArray(["node-list-never-read-by-order"])) and ok
	ok = SUPPORT.check(NAME, "an ordered list that is looped and never cleaned is the other note", _kinds(ORDERED), PackedStringArray(["node-list-never-cleaned"])) and ok
	ok = SUPPORT.check(NAME, "...and says nothing once an entry is taken out of it", _kinds(CLEANED), PackedStringArray()) and ok
	ok = SUPPORT.check(NAME, "a list of numbers is never judged", _kinds(PLAIN_NUMBERS), PackedStringArray()) and ok
	# The door: the rows become group rows, in the sheet itself.
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	sheet.variables = {"selected": {"type": "Array[Node2D]", "default": [], "exported": false}}
	var add_event: EventRow = EventRow.new()
	add_event.trigger_provider_id = "Core"
	add_event.trigger_id = "OnReady"
	var push: ACEAction = ACEAction.new()
	push.provider_id = "Core"
	push.ace_id = "ArrayAppend"
	push.codegen_template = "{var_name}.append({value})"
	push.params = {"var_name": "selected", "value": "self"}
	add_event.actions.append(push)
	sheet.events.append(add_event)
	var loop: EventRow = EventRow.new()
	loop.trigger_provider_id = "Core"
	loop.trigger_id = "OnProcess"
	var pick: PickFilter = PickFilter.new()
	pick.iterator_name = "unit"
	pick.collection_kind = PickFilter.CollectionKind.ARRAY
	pick.collection_value = "selected"
	loop.pick_filters.append(pick)
	var hide: RawCodeRow = RawCodeRow.new()
	hide.code = "unit.hide()"
	loop.actions.append(hide)
	sheet.events.append(loop)
	var before: Array = EventSheetListFindings.findings(sheet, EventSheetMistakeFindings._read(sheet)["rows"])
	ok = SUPPORT.check(NAME, "the door is offered when every use can be said with a group",
		[before.size(), str((before[0] as Dictionary).get("fix", "")) if not before.is_empty() else ""], [1, EventSheetListFindings.FIX_USE_GROUP]) and ok
	var changed: int = EventSheetListFindings.use_a_group(sheet, "selected")
	var text: String = SUPPORT.compile_output(sheet, "user://node_list_findings_out.gd")
	ok = SUPPORT.check(NAME, "the rewrite changed the push and the loop", changed, 2) and ok
	ok = SUPPORT.check(NAME, "the code now uses the group", [text.contains("self.add_to_group(\"selected\")"), text.contains("get_nodes_in_group(\"selected\")"), text.contains("selected.append")],
		[true, true, false]) and ok
	ok = SUPPORT.check(NAME, "the list's declaration is gone", sheet.variables.has("selected"), false) and ok
	# A list of a parent is another object's list, noted; a child's list is the ordinary way down.
	var up: ACEAction = ACEAction.new()
	up.provider_id = "Core"
	up.ace_id = "ArrayClear"
	up.params = {"var_name": "$../Table.cards"}
	var down: ACEAction = ACEAction.new()
	down.provider_id = "Core"
	down.ace_id = "ArrayClear"
	down.params = {"var_name": "$Enemy.cards"}
	ok = SUPPORT.check(NAME, "a parent's list is noted, a child's is not",
		[EventSheetListFindings.reaches_into_other_list({"row": up, "params": up.params}),
		EventSheetListFindings.reaches_into_other_list({"row": down, "params": down.params})], ["$../Table.cards", ""]) and ok
	# Drop freed first: an event above the loop's, with the loop's trigger.
	var ordered: EventSheetResource = SUPPORT.reopen(ORDERED, true, "")
	var loop_event: EventRow = null
	for entry: Variant in ordered.events:
		if entry is EventRow and not (entry as EventRow).pick_filters.is_empty():
			loop_event = entry as EventRow
	if loop_event != null:
		ok = SUPPORT.check(NAME, "the clean-up event goes above the loop", EventSheetListFindings.drop_freed_before(ordered.events, loop_event, "turns"), true) and ok
		ok = SUPPORT.check(NAME, "...and holds Drop freed instances", ((ordered.events[ordered.events.find(loop_event) - 1] as EventRow).actions[0] as ACEAction).ace_id, "ArrayDropFreed") and ok
	return ok
