@tool
class_name EventSheetPickingOffer
extends RefCounted

# Picking, offered in Godot's shape.
#
# In another event-sheet editor a condition on an object type PICKS the instances that pass it, and
# the actions under it apply to those. A Godot script belongs to one node, so the same words typed on
# the Player's sheet - "Enemy health <= 0" - have nothing to pick from. When the object named is a
# FAMILY (a script marked `## @ace_family(Enemy)`, whose instances join the `family_enemy` group),
# the Ghost Row offers the picking form instead: one event with a For each over that family and the
# test as the loop's filter. It compiles to the loop a person would write by hand -
#
#     for enemy in get_tree().get_nodes_in_group("family_enemy"):
#         if not (enemy.health <= 0):
#             continue
#
# - so the pick is a visible row the reader can read, not hidden machinery, and the file stays
# plain GDScript. Nothing here adds a compiler path: the event carries an ordinary PickFilter.
#
# Static and pure apart from families(), which reads the project's class list, so tests pin the
# offer and the event it builds without an editor.

## The comparison words a reader types, in the one spelling GDScript uses.
const OPERATORS: Dictionary = {
	"<=": "<=", ">=": ">=", "!=": "!=", "==": "==", "<": "<", ">": ">", "=": "==",
	"≤": "<=", "≥": ">=", "≠": "!=",
}

## families(), and the class-list size it was read at.
static var _families: Dictionary = {}
static var _families_seen_at: int = -1


## {family class: its group} for every family the project declares, read from the project's class
## list and each script's own `## @ace_family(...)` marker. Plugin files are skipped - a family is a
## thing a game declares. Read once per class-list size, so a family added mid-session is found the
## next time the list grows.
static func families() -> Dictionary:
	var classes: Array[Dictionary] = ProjectSettings.get_global_class_list()
	if classes.size() == _families_seen_at and _families_seen_at >= 0:
		return _families
	_families = {}
	_families_seen_at = classes.size()
	for entry: Dictionary in classes:
		var path: String = str(entry.get("path", ""))
		if path.begins_with("res://addons/") or not FileAccess.file_exists(path):
			continue
		var source: String = FileAccess.get_file_as_string(path)
		if not source.contains("## @ace_family("):
			continue
		var family_class: String = str(entry.get("class", ""))
		_families[family_class] = "family_%s" % family_class.to_snake_case()
	return _families


## What a typed sentence offers, or {}. "Enemy health <= 0" -> {family: "Enemy", group:
## "family_enemy", iterator: "enemy", field: "health", op: "<=", value: "0", test:
## "enemy.health <= 0"}; "Enemy" alone offers the loop with no test. Only a family the project
## declares, and never the sheet's own class - a sheet already IS each of its own instances.
static func offer_for(text: String, known: Dictionary, own_class: String) -> Dictionary:
	var words: PackedStringArray = text.strip_edges().split(" ", false)
	if words.is_empty():
		return {}
	var named: String = ""
	for family_class: String in known:
		if family_class.to_lower() == words[0].to_lower():
			named = family_class
	if named.is_empty() or named == own_class:
		return {}
	var iterator: String = named.to_snake_case()
	var offer: Dictionary = {"family": named, "group": str(known[named]), "iterator": iterator,
		"field": "", "op": "", "value": "", "test": ""}
	if words.size() == 1:
		return offer
	if words.size() < 4 or not OPERATORS.has(words[2]):
		return {}
	var field: String = words[1]
	for part: String in field.split("."):
		if not part.is_valid_identifier():
			return {}
	offer["field"] = field
	offer["op"] = str(OPERATORS[words[2]])
	offer["value"] = " ".join(words.slice(3))
	offer["test"] = "%s.%s %s %s" % [iterator, field, offer["op"], offer["value"]]
	return offer


## The line the Ghost Row shows for an offer - the picking form in the sheet's words.
static func label_for(offer: Dictionary) -> String:
	if offer.is_empty():
		return ""
	var line: String = "⟳  %s %s" % [EventSheetL10n.translate("For each"), str(offer["family"])]
	if not str(offer["test"]).is_empty():
		line += " %s %s %s %s" % [EventSheetL10n.translate("where"), str(offer["field"]),
			EventSheetSentence.comparison_symbols(str(offer["op"])), str(offer["value"])]
	return line


## The loop an offer is: a For each over the family's group, iterating under the family's own
## lower-case name, with the test as its filter. One PickFilter; nothing new to compile.
static func pick_filter_for(offer: Dictionary) -> PickFilter:
	var pick: PickFilter = PickFilter.new()
	pick.collection_kind = PickFilter.CollectionKind.GROUP
	pick.collection_value = str(offer["group"])
	pick.iterator_name = str(offer["iterator"])
	pick.predicate_expression = str(offer["test"])
	return pick


## A new event carrying the loop. No trigger of its own, so it runs every tick - the way a blank
## event always has - and the reader adds the actions for the picked ones under it. `event_uid` comes
## from the dock's own id maker, so two offers never share one.
static func event_for(offer: Dictionary, event_uid: String) -> EventRow:
	var event_row: EventRow = EventRow.new()
	event_row.event_uid = event_uid
	event_row.pick_filters.append(pick_filter_for(offer))
	return event_row
