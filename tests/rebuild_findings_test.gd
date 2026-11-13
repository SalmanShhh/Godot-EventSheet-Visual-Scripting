# Godot EventSheets - a tool that builds without clearing what it built last time.
#
# A tool sheet that adds nodes to the open scene when a button is pressed adds another copy every press
# unless something removes the last one first. These pins say when the sheet says so (a tool sheet, an
# event with a Building row that marks what it builds, nothing clearing before it), that every quieter
# case stays quiet, that the door writes the clearing row at the top under the node the event builds
# under, and that the pair compiles to the loop a Godot user would have written.
@tool
class_name RebuildFindingsTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const NAME: String = "rebuild_findings_test"
const BUILDING := preload("res://addons/eventforge/registration/modules/building_aces.gd")


## A Building row as a tool sheet holds it: baked, with the owner and mark lines part of the row.
static func _building_row(ace_id: String, params: Dictionary) -> ACEAction:
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor("Core", ace_id)
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = ace_id
	action.params = params
	action.codegen_template = BUILDING.tool_form(descriptor.codegen_template).replace("{uid}", "t1")
	return action


static func _clearing_row() -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "RemoveBuiltNodes"
	action.params = {"parent": "get_tree().edited_scene_root"}
	action.codegen_template = ACERegistry.find_descriptor("Core", "RemoveBuiltNodes").codegen_template.replace("{uid}", "t2")
	return action


static func _event(trigger: String, rows: Array) -> EventRow:
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = trigger
	for row: Variant in rows:
		event.actions.append(row)
	return event


static func _fence() -> ACEAction:
	return _building_row("AddNewNodeInto", {"type": "Node2D", "label": "\"Fence\"",
		"parent": "get_tree().edited_scene_root", "name": "fence"})


static func _sheet(tool_mode: bool, events: Array) -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.tool_mode = tool_mode
	for event: Variant in events:
		sheet.events.append(event)
	return sheet


static func run() -> bool:
	var passed: bool = true
	passed = _when_it_speaks() and passed
	passed = _when_it_stays_quiet() and passed
	passed = _the_door() and passed
	passed = _the_pair_compiles() and passed
	return passed


static func _when_it_speaks() -> bool:
	var sheet: EventSheetResource = _sheet(true, [_event("OnReady", [_fence()])])
	var found: Array[Dictionary] = EventSheetRebuildFindings.findings(sheet, "res://fence_tool.gd")
	return SUPPORT.pins(NAME, [
		["a tool sheet that builds and clears nothing earns one note", found.size(), 1],
		["it is the rebuild kind", str(found[0].get("kind", "")), "tool-builds-without-clearing"],
		["it is anchored at the event", str(found[0].get("anchor", "")), "event"],
		["it names the file", str(found[0].get("message", "")).begins_with("fence_tool.gd builds nodes"), true],
		["it offers the door", str(found[0].get("fix", "")), "clear_what_it_built_first"],
		["the door builds under what the row builds under", str(found[0].get("to", "")), "get_tree().edited_scene_root"],
	])


static func _when_it_stays_quiet() -> bool:
	var game: EventSheetResource = _sheet(false, [_event("OnReady", [_fence()])])
	var clears_first: EventSheetResource = _sheet(true, [_event("OnReady", [_clearing_row(), _fence()])])
	var earlier: EventSheetResource = _sheet(true, [_event("OnReady", [_clearing_row()]), _event("OnReady", [_fence()])])
	var other_trigger: EventSheetResource = _sheet(true, [_event("OnReady", [_clearing_row()]), _event("OnProcess", [_fence()])])
	var plain_row: ACEAction = ACEAction.new()
	plain_row.provider_id = "Core"
	plain_row.ace_id = "AddNewNodeInto"
	plain_row.params = {"type": "Node2D", "name": "fence", "parent": "self"}
	plain_row.codegen_template = ACERegistry.find_descriptor("Core", "AddNewNodeInto").codegen_template
	var unmarked: EventSheetResource = _sheet(true, [_event("OnReady", [plain_row])])
	return SUPPORT.pins(NAME, [
		["a game sheet says nothing", EventSheetRebuildFindings.findings(game).size(), 0],
		["an event that clears first says nothing", EventSheetRebuildFindings.findings(clears_first).size(), 0],
		["an earlier event for the same trigger clears for the later one", EventSheetRebuildFindings.findings(earlier).size(), 0],
		["a clear under another trigger does not cover this one", EventSheetRebuildFindings.findings(other_trigger).size(), 1],
		["a row that was not dropped in as a tool row is not asked", EventSheetRebuildFindings.findings(unmarked).size(), 0],
	])


static func _the_door() -> bool:
	var event: EventRow = _event("OnReady", [_fence()])
	var sheet: EventSheetResource = _sheet(true, [event])
	var found: Array[Dictionary] = EventSheetRebuildFindings.findings(sheet)
	var first: bool = EventSheetRebuildFindings.clear_first(found[0], "t9")
	var again: bool = EventSheetRebuildFindings.clear_first(found[0], "t9")
	return SUPPORT.pins(NAME, [
		["the door writes the row", first, true],
		["and only once", again, false],
		["it goes at the top of the event", (event.actions[0] as ACEAction).ace_id, "RemoveBuiltNodes"],
		["the building row is still there after it", (event.actions[1] as ACEAction).ace_id, "AddNewNodeInto"],
		["it clears under the node the event builds under", str((event.actions[0] as ACEAction).params.get("parent", "")), "get_tree().edited_scene_root"],
		["its local carries the id it was given", (event.actions[0] as ACEAction).codegen_template.contains("__built_t9"), true],
		["the event no longer earns the note", EventSheetRebuildFindings.findings(sheet).size(), 0],
	])


static func _the_pair_compiles() -> bool:
	var sheet: EventSheetResource = _sheet(true, [_event("OnReady", [_clearing_row(), _fence()])])
	var output: String = SUPPORT.compile_output(sheet)
	var cleared_at: int = output.find("\tfor __built_t2: Node in get_tree().edited_scene_root.get_children():\n\t\tif __built_t2.has_meta(&\"built_by_sheet\") and __built_t2.get_meta(&\"built_by_sheet\") == get_script().resource_path:\n\t\t\tget_tree().edited_scene_root.remove_child(__built_t2)\n\t\t\t__built_t2.queue_free()\n")
	var built_at: int = output.find("\tvar fence := Node2D.new()\n\tfence.name = \"Fence\"\n\tget_tree().edited_scene_root.add_child(fence, true)\n\tif Engine.is_editor_hint():\n\t\tfence.owner = get_tree().edited_scene_root\n\t\tfence.set_meta(&\"built_by_sheet\", get_script().resource_path)\n")
	return SUPPORT.pins(NAME, [
		["the clearing loop is written", cleared_at >= 0, true],
		["the node is built, owned and marked", built_at >= 0, true],
		["the clearing comes before the building", cleared_at < built_at, true],
		["the file is a tool script", output.contains("@tool"), true],
	])
