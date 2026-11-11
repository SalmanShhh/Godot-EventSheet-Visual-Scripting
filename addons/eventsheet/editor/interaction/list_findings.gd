# Godot EventSheets - the three notes a list of nodes can earn, and the one rewrite that answers them.
#
# A list of nodes is the right tool when ORDER matters (a turn order, a spawn queue). For an unordered
# set (selected units, targets in range) Godot's own tool is a GROUP, which forgets a destroyed node by
# itself. So, for an Array of nodes the sheet declares:
#
#   never read by order   no pop, no front or back, no index, no sort: only push, erase, has and
#                         for-each. Amber, with the door "Use a group instead", which rewrites the rows
#                         to add_to_group / remove_from_group / is_in_group / For each in group.
#   never cleaned         a list that IS read by order, looped over, and never has a destroyed
#                         instance taken out of it anywhere on the sheet. Amber, with the door
#                         "Drop freed instances first". (A group needs no such clean-up.)
#   another object's list a row that names a list of a parent, a sibling or an Autoload. A note, not an
#                         error: the row keeps working, and the sentence suggests asking that object
#                         through a function or a signal instead.
#
# Pure and static, like the mistake checks it joins: every sentence is pinned headless.
@tool
class_name EventSheetListFindings
extends RefCounted

const KIND_UNORDERED_NODE_LIST := "node-list-never-read-by-order"
const KIND_NEVER_CLEANED := "node-list-never-cleaned"
const KIND_OTHER_OBJECTS_LIST := "reaches-into-another-objects-list"

const FIX_USE_GROUP := "use_a_group_instead"
const FIX_DROP_FREED := "drop_freed_instances_first"

## The calls that read a list by position or order.
const ORDER_CALLS: PackedStringArray = [
	"pop_back", "pop_front", "front", "back", "sort", "sort_custom", "reverse", "insert", "remove_at",
	"slice", "find", "rfind", "shuffle", "bsearch", "resize",
]
## The calls that take an entry out of a list (so a destroyed instance can leave it).
const REMOVING_CALLS: PackedStringArray = ["erase", "remove_at", "pop_back", "pop_front", "clear", "assign"]

## The list rows the group rewrite knows how to say, by the ids they are written with.
const GROUP_ADD_IDS: PackedStringArray = ["ArrayAppend", "ArrayAppendOnce"]


## The sheet's arrays of nodes: {name: element type}. Typed `Array[Unit]` where Unit is a node class
## (built in, or one the project declares). An untyped Array says nothing about its items, so it is never judged.
static func node_lists(sheet: EventSheetResource) -> Dictionary:
	var lists: Dictionary = {}
	if sheet == null:
		return lists
	var names: PackedStringArray = PackedStringArray(sheet.variables.keys())
	for entry: Variant in sheet.events:
		if entry is LocalVariable:
			names.append((entry as LocalVariable).name)
	for list_name: String in names:
		var element: String = EventSheetArrayTypes.list_element_type(sheet, list_name)
		if not element.is_empty() and is_node_class(element):
			lists[list_name] = element
	return lists


## Whether a class name is a Node (built in, or a project class whose base chain reaches one).
static func is_node_class(class_name_text: String) -> bool:
	var current: String = class_name_text
	var guard: int = 0
	var project: Dictionary = {}
	for entry: Dictionary in ProjectSettings.get_global_class_list():
		project[str(entry.get("class", ""))] = str(entry.get("base", ""))
	while not current.is_empty() and guard < 16:
		if ClassDB.class_exists(current):
			return current == "Node" or ClassDB.is_parent_class(current, "Node")
		current = str(project.get(current, ""))
		guard += 1
	return false


## What the sheet does with one list, read off the lines every row compiles to.
## {"order": bool, "uses": bool, "loops": bool, "removes": bool, "convertible": bool, "first": context}
static func usage(rows: Array[Dictionary], list_name: String) -> Dictionary:
	var word: String = "\\b%s\\b" % RegEx.create_from_string("[^A-Za-z0-9_]").sub(list_name, "", true)
	var call_regex: RegEx = RegEx.create_from_string(word + "\\.([a-z_]+)\\(")
	var index_regex: RegEx = RegEx.create_from_string(word + "\\[")
	var loop_regex: RegEx = RegEx.create_from_string("\\bin\\s+" + word + "\\s*[:)\\n]|\\bin\\s+" + word + "$")
	var found: Dictionary = {"order": false, "uses": false, "loops": false, "removes": false, "convertible": true, "first": null}
	for context: Dictionary in rows:
		var line: String = EventSheetMistakeFindings.code_only(str(context.get("line", "")))
		if not line.contains(list_name):
			continue
		var mentioned: bool = false
		for hit: RegExMatch in call_regex.search_all(line):
			mentioned = true
			var call: String = hit.get_string(1)
			if ORDER_CALLS.has(call):
				found["order"] = true
			if REMOVING_CALLS.has(call):
				found["removes"] = true
		if index_regex.search(line) != null:
			found["order"] = true
			mentioned = true
		if loop_regex.search(line) != null or (str(context.get("lane", "")) == "pick" and call_regex.search(line) == null and RegEx.create_from_string(word).search(line) != null):
			found["loops"] = true
			mentioned = true
		if not mentioned:
			continue
		found["uses"] = true
		if found["first"] == null:
			found["first"] = context
		if not _can_say_with_a_group(context, list_name):
			found["convertible"] = false
	return found


## Whether one row that mentions the list is one the group rewrite can say.
static func _can_say_with_a_group(context: Dictionary, list_name: String) -> bool:
	var row: Variant = context.get("row")
	if row is PickFilter:
		var pick: PickFilter = row as PickFilter
		return pick.collection_value.strip_edges() == list_name and pick.predicate_expression.strip_edges().is_empty() \
			and pick.order_by_expression.strip_edges().is_empty() and pick.pick_first_n == 0
	var params: Dictionary = context.get("params", {})
	var named: String = str(params.get("var_name", "")).strip_edges()
	if row is ACEAction:
		var id: String = (row as ACEAction).ace_id
		return named == list_name and (GROUP_ADD_IDS.has(id) or id == "ArrayErase")
	if row is ACECondition:
		return named == list_name and (row as ACECondition).ace_id == "ArrayContains"
	return false


## The notes this sheet earns. `rows` are the mistake walk's rows.
static func findings(sheet: EventSheetResource, rows: Array[Dictionary]) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	var lists: Dictionary = node_lists(sheet)
	for list_name: String in lists:
		var seen: Dictionary = usage(rows, list_name)
		if not bool(seen["uses"]):
			continue
		var context: Dictionary = seen["first"]
		var event_row: EventRow = context.get("event") as EventRow
		if event_row == null:
			continue
		if not bool(seen["order"]):
			var doors: Dictionary = {}
			if bool(seen["convertible"]):
				doors = EventSheetMistakeFindings._door_keys([[FIX_USE_GROUP, EventSheetL10n.translate("Use a group instead")]])
			found.append(EventSheetMistakeFindings._finding(KIND_UNORDERED_NODE_LIST, "warning", event_row, list_name,
				EventSheetL10n.translate("%s holds nodes but is never read by position or order. A group is Godot's way to keep an unordered set of nodes, and it drops a destroyed instance by itself.") % list_name,
				"", "", context, doors))
		elif bool(seen["loops"]) and not bool(seen["removes"]):
			var looped: Dictionary = _loop_context(rows, list_name)
			var loop_event: EventRow = (looped.get("event") as EventRow) if not looped.is_empty() else event_row
			found.append(EventSheetMistakeFindings._finding(KIND_NEVER_CLEANED, "warning", loop_event, list_name,
				EventSheetL10n.translate("%s is read in a loop but nothing on this sheet ever takes a destroyed instance out of it, and the next use of a freed one is an error (a group needs no such clean-up).") % list_name,
				"", "", looped if not looped.is_empty() else context,
				EventSheetMistakeFindings._door_keys([[FIX_DROP_FREED, EventSheetL10n.translate("Drop freed instances first")]])))
	for request: Dictionary in EventSheetPickScope.unpicked_requests(sheet, rows):
		var doors: Array = []
		var type_name: String = str(request["type"])
		var family_group: String = str(EventSheetPickingOffer.families().get(type_name, ""))
		if not family_group.is_empty():
			doors.append([EventSheetPickScope.FIX_PICK_FROM_GROUP, EventSheetL10n.translate("Pick the %s from a group") % type_name])
		var list_name: String = _list_of_type(sheet, type_name)
		if not list_name.is_empty():
			doors.append([EventSheetPickScope.FIX_PICK_FROM_LIST, EventSheetL10n.translate("Pick the %s from %s") % [type_name, list_name]])
		var extra: Dictionary = EventSheetMistakeFindings._door_keys(doors)
		extra["pick_name"] = str(request["name"])
		extra["pick_type"] = type_name
		extra["pick_group"] = family_group
		extra["pick_list"] = list_name
		found.append(EventSheetMistakeFindings._finding(EventSheetPickScope.FINDING_KIND, "warning", request["event"] as EventRow,
			str(request["name"]), EventSheetPickScope.sentence(type_name, str(request["name"])), "", "",
			{"lane": request["lane"], "index": request["index"]}, extra))
	for context: Dictionary in rows:
		var reached: String = reaches_into_other_list(context)
		if reached.is_empty():
			continue
		found.append(EventSheetMistakeFindings._finding(KIND_OTHER_OBJECTS_LIST, "warning", context.get("event") as EventRow, reached,
			EventSheetL10n.translate("This row reaches into %s, a list that belongs to another object. It works, but the object that owns a list should be asked for it through a function or a signal instead.") % reached,
			"", "", context, {}))
	return found


## The sheet's own list of `type_name`, or "" when it has none.
static func _list_of_type(sheet: EventSheetResource, type_name: String) -> String:
	if type_name.is_empty():
		return ""
	for list_name: Variant in sheet.variables.keys():
		if EventSheetArrayTypes.list_element_type(sheet, str(list_name)) == type_name:
			return str(list_name)
	return ""


static func _loop_context(rows: Array[Dictionary], list_name: String) -> Dictionary:
	for context: Dictionary in rows:
		if str(context.get("lane", "")) == "pick" and str(context.get("line", "")).contains(list_name):
			return context
	return {}


## The list a row names that belongs to a parent, a sibling or an Autoload ("" for any other row).
## A node below the sheet's own (`$Child.items`) is the ordinary way to call down and is not noted.
static func reaches_into_other_list(context: Dictionary) -> String:
	var row: Variant = context.get("row")
	if not (row is ACEAction or row is ACECondition):
		return ""
	var provider: String = (row as Resource).get("provider_id")
	if not (provider.is_empty() or provider == "Core"):
		return ""
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor("Core", str((row as Resource).get("ace_id")))
	if descriptor == null or not str(descriptor.category).begins_with("Variables: Array"):
		return ""
	var named: String = str((context.get("params", {}) as Dictionary).get("var_name", "")).strip_edges()
	if named.is_empty() or not named.contains("."):
		return ""
	var head: String = named.substr(0, named.rfind("."))
	if head.begins_with("$..") or head.begins_with("get_parent") or head == "owner" or head.begins_with("get_node(\"..") \
			or ProjectSettings.has_setting("autoload/" + head):
		return named
	return ""


## The rewrite behind "Use a group instead", on the live sheet: every row that spells the list becomes the
## group row that says the same thing, and the list's declaration goes. Returns how many rows changed.
static func use_a_group(sheet: EventSheetResource, list_name: String) -> int:
	var group_text: String = "\"%s\"" % list_name
	var changed: int = _rewrite_events(sheet.events, list_name, group_text)
	for entry: Variant in sheet.functions:
		if entry is EventFunction:
			changed += _rewrite_events((entry as EventFunction).events, list_name, group_text)
	if changed > 0:
		sheet.variables.erase(list_name)
		for entry: Variant in sheet.events.duplicate():
			if entry is LocalVariable and (entry as LocalVariable).name == list_name:
				sheet.events.erase(entry)
	return changed


static func _rewrite_events(items: Array, list_name: String, group_text: String) -> int:
	var changed: int = 0
	for item: Variant in items:
		if item is EventGroup:
			changed += _rewrite_events(EventSheetGroupFacts.children(item as EventGroup), list_name, group_text)
			continue
		var event_row: EventRow = item as EventRow
		if event_row == null:
			continue
		for pick: Variant in event_row.pick_filters:
			var filter: PickFilter = pick as PickFilter
			if filter != null and filter.collection_value.strip_edges() == list_name:
				filter.collection_kind = PickFilter.CollectionKind.GROUP
				filter.collection_value = list_name
				changed += 1
		for index: int in event_row.actions.size():
			var action: ACEAction = event_row.actions[index] as ACEAction
			if action == null or str(action.params.get("var_name", "")).strip_edges() != list_name:
				continue
			var swapped: ACEAction = ACEAction.new()
			swapped.provider_id = "Core"
			swapped.params = {"target": str(action.params.get("value", "self")), "group": group_text}
			if GROUP_ADD_IDS.has(action.ace_id):
				swapped.ace_id = "AddToGroup"
				swapped.codegen_template = "{target}.add_to_group({group})"
			elif action.ace_id == "ArrayErase":
				swapped.ace_id = "RemoveFromGroup"
				swapped.codegen_template = "{target}.remove_from_group({group})"
			else:
				continue
			event_row.actions[index] = swapped
			changed += 1
		for index: int in event_row.conditions.size():
			var condition: ACECondition = event_row.conditions[index] as ACECondition
			if condition == null or condition.ace_id != "ArrayContains" \
					or str(condition.params.get("var_name", "")).strip_edges() != list_name:
				continue
			var swapped_test: ACECondition = ACECondition.new()
			swapped_test.provider_id = "Core"
			swapped_test.ace_id = "IsInGroup"
			swapped_test.codegen_template = "{target}.is_in_group({group})"
			swapped_test.negated = condition.negated
			swapped_test.params = {"target": str(condition.params.get("value", "self")), "group": group_text}
			event_row.conditions[index] = swapped_test
			changed += 1
		changed += _rewrite_events(event_row.sub_events, list_name, group_text)
	return changed


## The rewrite behind "Drop freed instances first": a new event just above the one that loops, with the
## trigger the loop's event has, holding the Drop freed instances row. Returns false when the event is not
## in `items` (the caller looks in the sheet's events and every function's).
static func drop_freed_before(items: Array, loop_event: EventRow, list_name: String) -> bool:
	var at: int = items.find(loop_event)
	if at < 0:
		for item: Variant in items:
			if item is EventRow and drop_freed_before((item as EventRow).sub_events, loop_event, list_name):
				return true
			if item is EventGroup and drop_freed_before(EventSheetGroupFacts.children(item as EventGroup), loop_event, list_name):
				return true
		return false
	var before: EventRow = EventRow.new()
	before.trigger_provider_id = loop_event.trigger_provider_id
	before.trigger_id = loop_event.trigger_id
	before.trigger_args = loop_event.trigger_args
	before.trigger_params = loop_event.trigger_params.duplicate()
	var drop: ACEAction = ACEAction.new()
	drop.provider_id = "Core"
	drop.ace_id = "ArrayDropFreed"
	drop.codegen_template = "{var_name}.assign({var_name}.filter(is_instance_valid))"
	drop.params = {"var_name": list_name}
	before.actions.append(drop)
	items.insert(at, before)
	return true
