@tool
class_name EventSheetDuplicateEvents
extends RefCounted
# DUPLICATE EVENTS FOR… (V13) - the events one object has, given to another object.
#
# Replace object, in a batch: every top-level event that names the source object is copied once per
# target, and each copy has the source's reference swapped for the target's - the same rewrite the
# single Replace object gesture does, run over copies instead of over the originals, so the events
# you already had are untouched.
#
# Pure and static over the sheet's resources, so the whole batch is testable without a dock; the
# dock does nothing but run it inside one undo step and append what comes back.


## The reference the sheet actually writes for an object label. `Enemy` is written `$Enemy` in the
## rows, so the swap has to address the reference, not the label - and when the sheet already spells
## it some other way (`%Enemy`, `$Level/Enemy`), that spelling is the one that is answered.
static func reference_for(sheet: EventSheetResource, object_label: String) -> String:
	var wanted: String = object_label.strip_edges()
	if sheet == null or wanted.is_empty():
		return ""
	for reference: String in EventSheetRefactor.collect_node_references(sheet.events):
		if EventSheetArrangement.object_name_of(reference) == wanted:
			return reference
	return "$%s" % wanted


## The reference a target label is written with, in the source's own spelling: a `%Unique` source
## gives a `%Unique` target, a `$Path/To/Thing` source gives a sibling path.
static func target_reference(source_reference: String, target_label: String) -> String:
	var clean: String = target_label.strip_edges()
	if clean.is_empty():
		return ""
	if clean.begins_with("$") or clean.begins_with("%"):
		return clean
	if source_reference.begins_with("%"):
		return "%%%s" % clean
	var body: String = source_reference.strip_edges().trim_prefix("$")
	if body.contains("/"):
		var segments: PackedStringArray = body.split("/")
		segments[segments.size() - 1] = clean
		return "$%s" % "/".join(segments)
	return "$%s" % clean


## Every top-level event that names `source_reference`, copied and re-pointed at `target_label`.
## The originals are never touched: each copy is a deep duplicate, and the swap runs on the copy.
static func copies_for(sheet: EventSheetResource, source_reference: String, target_label: String) -> Array:
	var copies: Array = []
	if sheet == null or source_reference.strip_edges().is_empty():
		return copies
	var target: String = target_reference(source_reference, target_label)
	if target.is_empty() or target == source_reference:
		return copies
	for entry: Variant in sheet.events:
		var row: Resource = entry as Resource
		if row == null or row is SignalRow:
			continue
		if not Array(EventSheetRefactor.collect_node_references([row])).has(source_reference):
			continue
		var copy: Resource = row.duplicate(true)
		if EventSheetRefactor.replace_node_reference([copy], source_reference, target) > 0:
			copies.append(copy)
	return copies
