# Godot EventSheets - a pick lasts for its event and the sub-events under it, and nowhere else.
@tool
class_name PickScopeTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const NAME := "pick_scope"


static func _hide(target: String) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "HideNode"
	action.codegen_template = "{target.}hide()"
	action.params = {"target": target}
	return action


static func _sheet() -> Array:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	sheet.variables = {"selected": {"type": "Array[Node2D]", "default": [], "exported": false}}
	var picker: EventRow = EventRow.new()
	picker.trigger_provider_id = "Core"
	picker.trigger_id = "OnProcess"
	var pick: PickFilter = PickFilter.new()
	pick.iterator_name = "unit"
	pick.collection_kind = PickFilter.CollectionKind.ARRAY
	pick.collection_value = "selected"
	picker.pick_filters.append(pick)
	picker.actions.append(_hide("unit"))
	var inner: EventRow = EventRow.new()
	inner.actions.append(_hide("unit"))
	picker.sub_events.append(inner)
	var sibling: EventRow = EventRow.new()
	sibling.trigger_provider_id = "Core"
	sibling.trigger_id = "OnReady"
	sibling.actions.append(_hide("unit"))
	sheet.events.append(picker)
	sheet.events.append(sibling)
	return [sheet, picker, inner, sibling]


static func run() -> bool:
	var built: Array = _sheet()
	var sheet: EventSheetResource = built[0]
	var picker: EventRow = built[1]
	var inner: EventRow = built[2]
	var sibling: EventRow = built[3]
	var rows: Array[Dictionary] = EventSheetMistakeFindings._read(sheet)["rows"]
	var requests: Array[Dictionary] = EventSheetPickScope.unpicked_requests(sheet, rows)
	var found: Array[Dictionary] = EventSheetListFindings.findings(sheet, rows)
	var no_pick: Array = found.filter(func(entry: Dictionary) -> bool: return str(entry.get("kind", "")) == EventSheetPickScope.FINDING_KIND)
	# Two picks of one type read as their names.
	var twice: EventRow = EventRow.new()
	var second: PickFilter = PickFilter.new()
	second.iterator_name = "target"
	second.collection_kind = PickFilter.CollectionKind.ARRAY
	second.collection_value = "selected"
	twice.pick_filters.append((picker.pick_filters[0] as PickFilter).duplicate())
	twice.pick_filters.append(second)
	return SUPPORT.pins(NAME, [
		["the event that picks has the picked Unit-type object", EventSheetPickScope.object_words(sheet, [picker]), {"unit": "Node2D"}],
		["a sub-event under it has it too", EventSheetPickScope.object_words(sheet, [picker, inner]), {"unit": "Node2D"}],
		["a sibling event has nothing picked", EventSheetPickScope.object_words(sheet, [sibling]), {}],
		["two picks of one type show each name as written", EventSheetPickScope.object_words(sheet, [twice]), {"unit": "unit", "target": "target"}],
		["only the sibling's row asks for a pick that is not there", requests.map(func(entry: Dictionary) -> bool: return entry["event"] == sibling), [true]],
		["the amber row says so in words", no_pick.map(func(entry: Dictionary) -> String: return str(entry["message"]).left(25)), ["No Node2D is picked here."]],
		["a row under the pick is not flagged", requests.any(func(entry: Dictionary) -> bool: return entry["event"] == picker or entry["event"] == inner), false],
	])
