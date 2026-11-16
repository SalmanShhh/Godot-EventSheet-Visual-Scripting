# EventForge - what the compiler does with a Custom Block row it cannot write.
#
# Loaded by path, only when it is needed. A block whose kind is not registered (its pack was removed)
# or whose emit() produced nothing for a row that holds fields (emit() hit a script error) is never
# dropped silently: the result gets a warning and an error naming the kind and what the row holds,
# `success` turns false, and the compiler does not write the file, so a saved script never quietly
# lacks a line the sheet still holds. A `.tres` sheet stores only the kind id and the fields, never
# the emitted line, so there is nothing to keep verbatim.
@tool
extends RefCounted


## Returns `lines` untouched, after recording a gap in `result` when `lines` should not be empty.
static func checked(block: CustomBlockRow, kind: EventSheetBlockKind, lines: PackedStringArray, result: Dictionary) -> PackedStringArray:
	var said: String = ""
	if kind == null:
		said = "This sheet has %s, but no behaviour pack provides that kind, so its line cannot be written. Put the pack back, or delete the row." % label(block)
	elif lines.is_empty() and not block.fields.is_empty() and not kind.writes_nothing(block):
		said = "The %s wrote nothing, so its line is missing from the script. Its pack's emit code may have an error - check the Output panel." % label(block).trim_prefix("the ")
	if not said.is_empty():
		(result["warnings"] as Array).append(said)
		(result["errors"] as Array).append(said)
		result["success"] = false
	return lines


## "the 'my_pack.todo' block (text: fix this)" - the kind and what the row holds, so a person can find it.
static func label(block: CustomBlockRow) -> String:
	var shown: PackedStringArray = PackedStringArray()
	for field_id: Variant in block.fields:
		var text: String = str(block.fields[field_id]).replace("\n", " ")
		shown.append("%s: %s" % [field_id, text.left(30) + ("..." if text.length() > 30 else "")])
		if shown.size() == 3:
			break
	return "the '%s' block%s" % [block.kind_id, "" if shown.is_empty() else " (%s)" % ", ".join(shown)]
