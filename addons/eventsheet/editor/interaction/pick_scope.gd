# Godot EventSheets - what is picked where.
#
# A pick lasts for its event and every sub-event under it, and nowhere else. An event that picks the
# Units in `selected` (For each, Pop back into, a typed local) has "the picked Unit" in its own rows and
# in every sub-event's; a sibling event starts with nothing picked. This file answers that question from
# the sheet's own rows - the PickFilter an event carries, the pop rows, the locals it declares - and
# builds nothing of its own: the pick is the loop or the local that already writes the code.
#
# Pure and static: the reading, the amber row and the tests all ask the same function.
@tool
class_name EventSheetPickScope
extends RefCounted

const POP_ACE_IDS: PackedStringArray = ["ArrayPopBackInto", "ArrayPopFrontInto"]
const FINDING_KIND := "no-pick-here"
const FIX_PICK_FROM_GROUP := "pick_from_a_group"
const FIX_PICK_FROM_LIST := "pick_from_a_list"


## The element type of one of the SHEET's own typed lists ("Node2D" for `Array[Node2D]`), or "". Read here
## rather than through the array-type helper so a first open of a sheet never loads the scene readers.
static func own_list_element(sheet: EventSheetResource, list_name: String) -> String:
	var declared: String = ""
	if sheet.variables.has(list_name):
		declared = str((sheet.variables[list_name] as Dictionary).get("type", "")).strip_edges()
	else:
		for entry: Variant in sheet.events:
			if entry is LocalVariable and (entry as LocalVariable).name == list_name:
				declared = str((entry as LocalVariable).type_name).strip_edges()
	if declared.begins_with("Array[") and declared.ends_with("]"):
		return declared.substr(6, declared.length() - 7).strip_edges()
	return ""


## The picks one event makes by itself: [{"name", "type"}]. A For each names its item and takes the
## element type of the list it walks; a pop row names the item it took; a typed local names itself.
static func own_picks(sheet: EventSheetResource, event_row: EventRow) -> Array[Dictionary]:
	var picks: Array[Dictionary] = []
	if event_row == null:
		return picks
	for entry: Variant in event_row.pick_filters:
		var pick: PickFilter = entry as PickFilter
		if pick == null or not pick.enabled:
			continue
		var item: String = pick.iterator_name.strip_edges()
		if item.is_empty() or item.begins_with("__") or not item.is_valid_identifier():
			continue
		var type_name: String = pick.iterator_type.strip_edges()
		if type_name.is_empty() and pick.collection_kind in [PickFilter.CollectionKind.ARRAY, PickFilter.CollectionKind.EXPRESSION]:
			type_name = own_list_element(sheet, pick.collection_value.strip_edges())
		picks.append({"name": item, "type": type_name})
	for entry: Variant in event_row.actions:
		var action: ACEAction = entry as ACEAction
		if action != null and POP_ACE_IDS.has(action.ace_id):
			var taken: String = str(action.params.get("name", "")).strip_edges()
			if taken.is_valid_identifier():
				picks.append({"name": taken, "type": own_list_element(sheet, str(action.params.get("var_name", "")))})
	for entry: Variant in event_row.local_variables:
		var local: LocalVariable = entry as LocalVariable
		if local != null and not local.name.strip_edges().is_empty() and local.type_name != "Variant":
			picks.append({"name": local.name.strip_edges(), "type": local.type_name})
	return picks


## What is picked at an event: its own picks and those of every event above it, outermost first.
## `chain` is the event's ancestry from the top of its list down to the event itself.
static func in_scope(sheet: EventSheetResource, chain: Array) -> Array[Dictionary]:
	var picked: Array[Dictionary] = []
	for event_row: Variant in chain:
		picked.append_array(own_picks(sheet, event_row as EventRow))
	return picked


## The word the object column shows for each picked name: its TYPE when exactly one pick of that type is
## in scope (Unit), the name as written when two picks share a type (attacker, target) or the type is
## not known. {name: word}.
static func object_words(sheet: EventSheetResource, chain: Array) -> Dictionary:
	var picked: Array[Dictionary] = in_scope(sheet, chain)
	var count: Dictionary = {}
	for entry: Dictionary in picked:
		var type_name: String = str(entry["type"])
		count[type_name] = int(count.get(type_name, 0)) + 1
	var words: Dictionary = {}
	for entry: Dictionary in picked:
		var type_name: String = str(entry["type"])
		words[str(entry["name"])] = type_name if not type_name.is_empty() and int(count[type_name]) == 1 else str(entry["name"])
	return words


## Every pick the sheet makes anywhere, with the event that makes it: {name: [{"type", "event"}]}.
static func all_picks(sheet: EventSheetResource) -> Dictionary:
	var found: Dictionary = {}
	_collect(sheet, sheet.events, found)
	for entry: Variant in sheet.functions:
		if entry is EventFunction:
			_collect(sheet, (entry as EventFunction).events, found)
	return found


static func _collect(sheet: EventSheetResource, items: Array, found: Dictionary) -> void:
	for item: Variant in items:
		if item is EventGroup:
			_collect(sheet, EventSheetGroupFacts.children(item as EventGroup), found)
		elif item is EventRow:
			for entry: Dictionary in own_picks(sheet, item as EventRow):
				if not found.has(entry["name"]):
					found[entry["name"]] = []
				(found[entry["name"]] as Array).append({"type": entry["type"], "event": item})
			_collect(sheet, (item as EventRow).sub_events, found)


## The rows that act on a picked name where nothing by that name is picked: a node-scoped row whose
## target is the name of a pick some OTHER event makes. `rows` are the mistake walk's rows, and `chains`
## answers the ancestry of an event. [{"event", "lane", "index", "name", "type"}]
static func unpicked_requests(sheet: EventSheetResource, rows: Array[Dictionary]) -> Array[Dictionary]:
	var requests: Array[Dictionary] = []
	var everywhere: Dictionary = all_picks(sheet)
	if everywhere.is_empty():
		return requests
	var declared: Dictionary = EventSheetLocalScope.declared_locals(sheet)
	for context: Dictionary in rows:
		if str(context.get("lane", "")) not in ["action", "condition"]:
			continue
		var target: String = str((context.get("params", {}) as Dictionary).get("target", "")).strip_edges()
		if target.is_empty() or not everywhere.has(target):
			continue
		var event_row: EventRow = context.get("event") as EventRow
		if event_row == null or sheet.variables.has(target):
			continue
		# In scope when this event, or one above it, is where the name is picked.
		var here: bool = false
		for made: Dictionary in everywhere[target]:
			if made["event"] == event_row or _is_below(made["event"] as EventRow, event_row):
				here = true
		if not here:
			requests.append({"event": event_row, "lane": context["lane"], "index": context["index"], "name": target,
				"type": str((everywhere[target] as Array)[0]["type"])})
	return requests


## True when `inner` sits anywhere under `outer` (its sub-events, however deep).
static func _is_below(outer: EventRow, inner: EventRow) -> bool:
	for child: Variant in outer.sub_events:
		if child == inner:
			return true
		if child is EventRow and _is_below(child as EventRow, inner):
			return true
		if child is EventGroup:
			for grand: Variant in EventSheetGroupFacts.children(child as EventGroup):
				if grand == inner or (grand is EventRow and _is_below(grand as EventRow, inner)):
					return true
	return false


## The sentence the strip and the Doctor say for one such row.
static func sentence(type_name: String, name: String) -> String:
	var what: String = type_name if not type_name.is_empty() else name
	return EventSheetL10n.translate("No %s is picked here. A pick lasts for its own event and the sub-events under it, so this row has nothing to act on.") % what
