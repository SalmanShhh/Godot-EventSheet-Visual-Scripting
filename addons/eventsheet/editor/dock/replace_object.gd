@tool
class_name EventSheetReplaceObject
extends RefCounted
# REPLACE OBJECT, scoped to the selection: every reference to object A in the selected events
# becomes B. The rewrite itself is the rename refactor with a scope (EventSheetRefactor
# .replace_node_reference, token-safe, one undo step, byte-exact for every line it does not
# touch); this file is the two things that make it a good OFFER:
#
#   • the objects that have the SAME conditions and actions are listed first, because those are
#     the swaps that will still read the same afterwards,
#   • parameters that name an instance variable of A that B does not have are collected, so the
#     Doctor can say so instead of the sheet quietly compiling to a missing member.
#
# Pure functions over a scene root and the selected rows, so both halves are testable.

## Findings from the LAST replace, for the Doctor check the dock registers. Session state, never
## written to disk: {"from", "to", "members": PackedStringArray, "path"}.
static var last_missing: Dictionary = {}


## `suggestions` reordered so the closest objects come first: the same script as `from_reference`
## (identical conditions and actions), then the same class, then everything else. Stable inside
## each band, so an unresolvable scene leaves the order exactly as it arrived.
static func rank_suggestions(suggestions: PackedStringArray, from_reference: String, scene_root: Node) -> PackedStringArray:
	var source: Node = resolve_reference(from_reference, scene_root)
	if source == null:
		return suggestions
	var same_script: PackedStringArray = PackedStringArray()
	var same_class: PackedStringArray = PackedStringArray()
	var rest: PackedStringArray = PackedStringArray()
	for suggestion: String in suggestions:
		var candidate: Node = resolve_reference(suggestion, scene_root)
		if candidate == null or candidate == source:
			rest.append(suggestion)
		elif candidate.get_script() != null and candidate.get_script() == source.get_script():
			same_script.append(suggestion)
		elif candidate.get_class() == source.get_class():
			same_class.append(suggestion)
		else:
			rest.append(suggestion)
	var ranked: PackedStringArray = PackedStringArray()
	ranked.append_array(same_script)
	ranked.append_array(same_class)
	ranked.append_array(rest)
	return ranked


## The node a sheet reference points at: "$Path", "%Unique", "self", or a bare node name.
static func resolve_reference(reference: String, scene_root: Node) -> Node:
	if scene_root == null:
		return null
	var clean: String = reference.strip_edges()
	if clean.is_empty():
		return null
	if clean == "self":
		return scene_root
	if clean.begins_with("$"):
		clean = clean.substr(1)
	if clean.begins_with("%"):
		return scene_root.get_node_or_null(NodePath(clean))
	return scene_root.get_node_or_null(NodePath(clean))


## Members of A that the selected rows read through it (`$Enemy.hp` → "hp") and that B does not
## have - the parameters that would compile to a missing member after the swap.
static func missing_members(rows: Array, from_reference: String, to_reference: String, scene_root: Node) -> PackedStringArray:
	var replacement: Node = resolve_reference(to_reference, scene_root)
	var missing: PackedStringArray = PackedStringArray()
	if replacement == null:
		return missing
	for member: String in members_used(rows, from_reference):
		if not has_member(replacement, member) and not missing.has(member):
			missing.append(member)
	return missing


## Every `<reference>.<member>` the rows name, in first-seen order.
static func members_used(rows: Array, from_reference: String) -> PackedStringArray:
	var pattern: RegEx = RegEx.create_from_string("%s\\.([A-Za-z_][A-Za-z0-9_]*)" % _escaped(from_reference))
	var used: PackedStringArray = PackedStringArray()
	if pattern == null:
		return used
	var texts: PackedStringArray = PackedStringArray()
	_collect_texts(rows, texts)
	for text: String in texts:
		for hit: RegExMatch in pattern.search_all(text):
			var member: String = hit.get_string(1)
			if not used.has(member):
				used.append(member)
	return used


## True when `node` carries `member` as a property or a method - the two ways a row can name it.
static func has_member(node: Node, member: String) -> bool:
	for property: Dictionary in node.get_property_list():
		if str(property.get("name", "")) == member:
			return true
	return node.has_method(member)


static func _collect_texts(rows: Array, into: PackedStringArray) -> void:
	for row: Variant in rows:
		if row is RawCodeRow:
			into.append((row as RawCodeRow).code)
		elif row is EventGroup:
			var group: EventGroup = row as EventGroup
			_collect_texts(group.events if not group.events.is_empty() else group.rows, into)
		elif row is EventRow:
			var event_row: EventRow = row as EventRow
			var aces: Array = event_row.conditions + event_row.actions
			if event_row.trigger != null:
				aces.append(event_row.trigger)
			for ace: Variant in aces:
				if ace is RawCodeRow:
					into.append((ace as RawCodeRow).code)
				elif ace is Resource and ace.get("params") is Dictionary:
					for value: Variant in (ace.get("params") as Dictionary).values():
						if value is String:
							into.append(value)
			for pick: Variant in event_row.pick_filters:
				if pick is PickFilter:
					into.append((pick as PickFilter).collection_value)
					into.append((pick as PickFilter).predicate_expression)
			_collect_texts(event_row.sub_events, into)


## The Doctor check the dock registers: says what the last Replace object left naming a member the
## new object does not have. Nothing recorded, nothing reported.
static func doctor_check(_sheet_paths: PackedStringArray, findings: Array[Dictionary]) -> void:
	var members: PackedStringArray = last_missing.get("members", PackedStringArray())
	if members.is_empty():
		return
	findings.append({
		"severity": "warning",
		"check": "replace-object-members",
		"path": str(last_missing.get("path", "")),
		"message": "Replacing %s with %s left rows naming %s - %s does not have %s." % [
			str(last_missing.get("from", "")), str(last_missing.get("to", "")), ", ".join(members),
			str(last_missing.get("to", "")), "it" if members.size() == 1 else "them"]
	})


static func _escaped(reference: String) -> String:
	var escaped: String = ""
	for character: String in reference:
		if character.is_valid_identifier() or character == "_":
			escaped += character
		else:
			escaped += "\\" + character
	return escaped
