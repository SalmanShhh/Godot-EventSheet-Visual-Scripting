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
	var passed: bool = _the_rows_that_make_a_node_name_it()
	return _the_picked_rows() and passed


## A row that makes a node leaves a name behind, and the name is an object for the rows after it: a node made
## from a type is that type, a behaviour is its class, and a copy of a scene file is the class of the scene's
## root. A scene held in a constant is a name with no class, still offered.
static func _the_rows_that_make_a_node_name_it() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnReady"
	event.actions.append(_made("AddNewNodeInto", {"type": "Marker2D", "name": "marker", "parent": "self", "label": ""}))
	event.actions.append(_made("AddBehaviourInto", {"behaviour": "Timer", "name": "clock", "target": "self", "once": "yes"}))
	event.actions.append(_made("SpawnNewCopy", {"scene": "load(\"res://tests/fixtures/collision_scene_enemy.tscn\")",
		"name": "foe", "at": "global_position", "parent": "self"}))
	event.actions.append(_made("SpawnNewCopy3D", {"scene": "Enemy3D", "name": "boss", "at": "global_position", "parent": "self"}))
	event.actions.append(_made("AddNewNodeInto", {"type": "Marker2D", "name": "not a name", "parent": "self", "label": ""}))
	sheet.events.append(event)
	var picks: Array[Dictionary] = EventSheetPickScope.own_picks(sheet, event)
	return SUPPORT.pins(NAME, [
		["Add New Node leaves its name, typed as the type it made", picks[0], {"name": "marker", "type": "Marker2D"}],
		["Add Behaviour leaves its name, typed as the behaviour", picks[1], {"name": "clock", "type": "Timer"}],
		["a copy of a scene file is typed as the root of that scene", picks[2], {"name": "foe", "type": "CharacterBody2D"}],
		["a copy of a scene held in a constant is a name with no type", picks[3], {"name": "boss", "type": ""}],
		["a name that is not an identifier is not offered", picks.size(), 4],
		["the type a row is given is read from its type field", EventSheetPickScope.type_made_by("AddNewNodeInto", {"type": "Timer"}), "Timer"],
		["a type that is not a name is no type", EventSheetPickScope.type_made_by("AddNewNodeInto", {"type": "get_class()"}), ""],
	])


static func _made(ace_id: String, params: Dictionary) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = ace_id
	action.params = params
	return action


static func _the_picked_rows() -> bool:
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
		["the object column shows the picked type under the pick and the name outside it",
			ArrayObjectColumnTest._objects_of(sheet).filter(func(entry: Array) -> bool: return entry[0] == "action").map(func(entry: Array) -> String: return entry[1]),
			["Node2D", "Node2D", "unit"]],
		["a row under the pick is not flagged", requests.any(func(entry: Dictionary) -> bool: return entry["event"] == picker or entry["event"] == inner), false],
	])
