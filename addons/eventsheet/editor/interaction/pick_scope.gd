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

## The rows that take one instance out of (or off) a list and name it: {ace_id: [param naming it, param naming the list]}.
## Pops name the list as a variable; the pick rows name it as an expression.
const PICK_ACES: Dictionary = {
	"ArrayPopBackInto": ["name", "var_name"],
	"ArrayPopFrontInto": ["name", "var_name"],
	"PickNearest": ["name", "list"],
	"PickFarthest": ["name", "list"],
	"PickRandomInstance": ["name", "list"],
	"PickWhere": ["name", "list"],
	"PickFirstWhere": ["name", "list"],
	"PickLastWhere": ["name", "list"],
	"PickTop": ["name", "list"],
	"PickBottom": ["name", "list"],
}
## The local rows that declare a typed name: {ace_id: [param naming it, param giving its type]}.
const TYPED_LOCAL_ACES: Dictionary = {"SetLocalVarTyped": ["name", "var_type"]}
## Types that are values, never instances: a typed local of one of these is not a pick.
const VALUE_TYPES: PackedStringArray = ["", "Variant", "int", "float", "bool", "String", "StringName", "NodePath", "Vector2", "Vector2i",
	"Vector3", "Vector3i", "Vector4", "Vector4i", "Color", "Rect2", "Rect2i", "Transform2D", "Transform3D", "Basis", "Quaternion",
	"Plane", "AABB", "Projection", "RID", "Callable", "Signal", "Array", "Dictionary", "Object", "void"]
## The rows that make a node and name it, and where their type comes from (see made_names.gd).
const MADE_NAMES := preload("res://addons/eventsheet/editor/interaction/made_names.gd")
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


## True when `type_name` names something with instances in a scene (a node, or a class of the project) rather than a value or a helper object.
static func is_instance_type(type_name: String) -> bool:
	var plain: String = type_name.strip_edges()
	if VALUE_TYPES.has(plain) or plain.begins_with("Array[") or not plain.is_valid_identifier():
		return false
	# An engine class has instances in a scene only when it is a node (a Tween or a FileAccess is a helper a
	# line holds, not something the next rows are about); a class of the project may be anything.
	return not ClassDB.class_exists(plain) or ClassDB.is_parent_class(plain, "Node")


## A loop's item as written - "unit" or "unit: Unit" - as [name, type].
static func split_item(written: String) -> PackedStringArray:
	var at: int = written.find(":")
	if at < 0:
		return PackedStringArray([written.strip_edges(), ""])
	return PackedStringArray([written.substr(0, at).strip_edges(), written.substr(at + 1).strip_edges()])


## The element type of a list written as an expression: a bare name of one of the sheet's own lists.
static func list_expression_element(sheet: EventSheetResource, expression: String) -> String:
	var plain: String = expression.strip_edges()
	return own_list_element(sheet, plain) if plain.is_valid_identifier() else ""


## The instances an event's trigger hands it: the typed arguments of the signal that starts it
## ("unit: Unit" in `_on_unit_clicked(unit: Unit)`), as [{"name", "type"}]. Arguments of a value type are not instances.
static func carried_instances(event_row: EventRow) -> Array[Dictionary]:
	var carried: Array[Dictionary] = []
	if event_row == null:
		return carried
	var signature: String = event_row.trigger_args.strip_edges()
	if signature.is_empty():
		signature = str(event_row.trigger_params.get("args", "")).strip_edges()
	for argument: String in signature.split(","):
		var written: PackedStringArray = split_item(argument.split("=")[0])
		if written[0].is_valid_identifier() and is_instance_type(written[1]):
			carried.append({"name": written[0], "type": written[1]})
	return carried


## The node an event's trigger is aimed at, when it is not the sheet's own: a trigger on a child node
## ("Enemy | On died") is about that node, so that node is an instance the rows under it can be given as a value.
## [{"name": the reference as written ($Enemy), "type": ""}].
static func trigger_sources(event_row: EventRow) -> Array[Dictionary]:
	var sources: Array[Dictionary] = []
	if event_row == null:
		return sources
	var path: String = event_row.trigger_source_path.strip_edges()
	if path.is_empty():
		return sources
	sources.append({"name": path if path.begins_with("$") or path.begins_with("%") else "$" + path, "type": ""})
	return sources


## Every instance a row at `target` can be given as a value: what the events above it picked, what their triggers
## carry and what their triggers are aimed at. [{"name", "type"}], nearest-first order is not promised.
static func values_offered(sheet: EventSheetResource, target: Resource) -> Array[Dictionary]:
	var offered: Array[Dictionary] = []
	var seen: Dictionary = {}
	var chain: Array = chain_for(sheet, target)
	for entry: Dictionary in in_scope(sheet, chain):
		if not seen.has(entry["name"]):
			seen[entry["name"]] = true
			offered.append({"name": str(entry["name"]), "type": str(entry["type"])})
	for event_row: Variant in chain:
		for entry: Dictionary in carried_instances(event_row as EventRow) + trigger_sources(event_row as EventRow):
			if not seen.has(entry["name"]):
				seen[entry["name"]] = true
				offered.append(entry)
	return offered


## The type of the node a row that makes one leaves behind, "" when it cannot be told. A row that is given a
## type says it (Add New Node, Add Behaviour); a copy of a scene is the class of the scene's root, read off the
## file when the Scene field names one. A scene held in a constant or built at run time stays untyped, which
## still offers the name and says nothing about its class. Loaded by path so a first open of a sheet never
## loads the scene readers for a sheet that spawns nothing.
static func type_made_by(ace_id: String, params: Dictionary) -> String:
	if MADE_NAMES.TYPE_PARAMS.has(ace_id):
		var given: String = str(params.get(MADE_NAMES.TYPE_PARAMS[ace_id], "")).strip_edges()
		return given if given.is_valid_identifier() else ""
	var scene: String = str(params.get(MADE_NAMES.SCENE_PARAM, "")).strip_edges()
	if scene.is_empty():
		return ""
	var path: String = str(load("res://addons/eventsheet/editor/interaction/object_facts.gd").call("scene_path_in", scene))
	if path.is_empty():
		return ""
	var nodes: Array = load("res://addons/eventforge/importer/scene_connections.gd").call("nodes_of_scene", path)
	return str((nodes[0] as Dictionary).get("type", "")) if not nodes.is_empty() else ""


## The picks one event makes by itself: [{"name", "type"}]. A For each names its item and takes the
## element type of the list it walks; a pop or pick row names the item it took; a typed local names itself. The
## amber "nothing is picked here" check leaves the locals a line declares out (`with_declared_locals`): a name a function
## also has as a parameter or a member is not a request for a pick.
static func own_picks(sheet: EventSheetResource, event_row: EventRow, with_declared_locals: bool = true) -> Array[Dictionary]:
	var picks: Array[Dictionary] = []
	if event_row == null:
		return picks
	for entry: Variant in event_row.pick_filters:
		var pick: PickFilter = entry as PickFilter
		if pick == null or not pick.enabled:
			continue
		var written: PackedStringArray = split_item(pick.iterator_name)
		var item: String = written[0]
		if item.is_empty() or item.begins_with("__") or not item.is_valid_identifier():
			continue
		var type_name: String = pick.iterator_type.strip_edges()
		if type_name.is_empty():
			type_name = written[1]
		if type_name.is_empty() and pick.collection_kind in [PickFilter.CollectionKind.ARRAY, PickFilter.CollectionKind.EXPRESSION]:
			type_name = own_list_element(sheet, pick.collection_value.strip_edges())
		# A loop over a list of values (Array[String]) holds no instances, so it picks nothing the object column names.
		if not type_name.is_empty() and not is_instance_type(type_name):
			continue
		picks.append({"name": item, "type": type_name})
	for entry: Variant in event_row.actions:
		var action: ACEAction = entry as ACEAction
		if action == null:
			continue
		var params: Dictionary = action.params if not action.params.is_empty() else action.parameters
		if PICK_ACES.has(action.ace_id):
			var names: Array = PICK_ACES[action.ace_id]
			var taken: String = str(params.get(names[0], "")).strip_edges()
			var taken_type: String = list_expression_element(sheet, str(params.get(names[1], "")))
			if taken.is_valid_identifier() and (taken_type.is_empty() or is_instance_type(taken_type)):
				picks.append({"name": taken, "type": taken_type})
		elif MADE_NAMES.NAME_PARAMS.has(action.ace_id):
			var made: String = str(params.get(MADE_NAMES.NAME_PARAMS[action.ace_id], "")).strip_edges()
			var made_type: String = type_made_by(action.ace_id, params)
			if made.is_valid_identifier() and (made_type.is_empty() or is_instance_type(made_type)):
				picks.append({"name": made, "type": made_type})
		elif with_declared_locals and TYPED_LOCAL_ACES.has(action.ace_id):
			var declared: Array = TYPED_LOCAL_ACES[action.ace_id]
			var local_name: String = str(params.get(declared[0], "")).strip_edges()
			var local_type: String = str(params.get(declared[1], "")).strip_edges()
			if local_name.is_valid_identifier() and is_instance_type(local_type):
				picks.append({"name": local_name, "type": local_type})
	for entry: Variant in event_row.local_variables:
		var local: LocalVariable = entry as LocalVariable
		if local != null and not local.name.strip_edges().is_empty() and is_instance_type(local.type_name):
			picks.append({"name": local.name.strip_edges(), "type": local.type_name.strip_edges()})
	return picks


## What is picked at an event: its own picks and those of every event above it, outermost first.
## `chain` is the event's ancestry from the top of its list down to the event itself.
static func in_scope(sheet: EventSheetResource, chain: Array) -> Array[Dictionary]:
	var picked: Array[Dictionary] = []
	for event_row: Variant in chain:
		picked.append_array(own_picks(sheet, event_row as EventRow))
	return picked


## The event `target` is, or holds (a condition or an action of), and every event above it, outermost first.
## [] when the sheet has no such event.
static func chain_for(sheet: EventSheetResource, target: Resource) -> Array:
	if sheet == null or target == null:
		return []
	var tops: Array = [sheet.events]
	for entry: Variant in sheet.functions:
		if entry is EventFunction:
			tops.append((entry as EventFunction).events)
	for top: Variant in tops:
		var found: Array = _chain_in(top as Array, target, [])
		if not found.is_empty():
			return found
	return []


static func _holds(event_row: EventRow, target: Resource) -> bool:
	if target is ACECondition:
		return event_row.conditions.has(target as ACECondition)
	if target is ACEAction:
		return event_row.actions.has(target as ACEAction)
	return false


static func _chain_in(items: Array, target: Resource, above: Array) -> Array:
	for item: Variant in items:
		if item is EventGroup:
			var inside: Array = _chain_in(EventSheetGroupFacts.children(item as EventGroup), target, above)
			if not inside.is_empty():
				return inside
		elif item is EventRow:
			var event_row: EventRow = item as EventRow
			var chain: Array = above + [event_row]
			if event_row == target or _holds(event_row, target):
				return chain
			var deeper: Array = _chain_in(event_row.sub_events, target, chain)
			if not deeper.is_empty():
				return deeper
	return []


## The picked instances an Add action / Add condition offers as objects at `target`: [{"name", "type", "word"}], one
## per pick of a type with instances, by the word the object column reads it with (its type, or its name as written
## when two picks share a type). [] outside every pick.
static func offered_objects(sheet: EventSheetResource, target: Resource) -> Array[Dictionary]:
	var chain: Array = chain_for(sheet, target)
	var offered: Array[Dictionary] = []
	if chain.is_empty():
		return offered
	var words: Dictionary = object_words(sheet, chain)
	var seen: Dictionary = {}
	for entry: Dictionary in in_scope(sheet, chain):
		var name: String = str(entry["name"])
		if seen.has(name) or not is_instance_type(str(entry["type"])):
			continue
		seen[name] = true
		offered.append({"name": name, "type": str(entry["type"]), "word": str(words.get(name, name))})
	return offered


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


## A row whose values reach THROUGH a picked name to one of its members ("unit.health < 20"), re-read as a row
## about that object: {"object": the word the object column shows, "params": a COPY of the values with the
## "unit." taken off}. {} when the row names a target of its own, reaches through no pick, or reaches through
## two. Nothing here changes the row; the caller reads the copy and throws it away.
static func read_through(params: Dictionary, words: Dictionary) -> Dictionary:
	if words.is_empty() or not str(params.get("target", "")).strip_edges().is_empty():
		return {}
	var owner: String = ""
	var rewritten: Dictionary = {}
	for key: Variant in params.keys():
		var value: String = str(params[key]).strip_edges()
		var dot_at: int = value.find(".")
		var head: String = value.substr(0, dot_at).strip_edges() if dot_at > 0 else ""
		if head.is_empty() or not words.has(head) or not _opens_with_identifier(value.substr(dot_at + 1)):
			rewritten[key] = params[key]
			continue
		if not owner.is_empty() and owner != head:
			return {}
		owner = head
		rewritten[key] = value.substr(dot_at + 1)
	if owner.is_empty():
		return {}
	return {"object": str(words[owner]), "params": rewritten}


static func _opens_with_identifier(text: String) -> bool:
	var first: String = text.strip_edges().left(1)
	return first == "_" or (first.to_lower() != first.to_upper())


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
			for entry: Dictionary in own_picks(sheet, item as EventRow, false):
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
