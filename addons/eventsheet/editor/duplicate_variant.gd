@tool
class_name EventSheetDuplicateVariant
extends RefCounted
# Godot EventSheets - "Duplicate as Variant…": the copy and the remap in ONE gesture.
#
# Building the second of anything is a two-dialog chore today: Duplicate, then hunt down
# Replace Object References… (or Paste Special) and remap. Both halves ship and both are good.
# Nothing fuses them, so player 2, the second weapon and the third upgrade tier each cost two
# gestures and two undo entries.
#
# This adds no new machinery at all. The rows travel through the shipped portable form
# (EventSheetSnippet.serialize_rows - the same text Copy puts on the clipboard), the remap is
# EventSheetPasteSpecial.remap (token-safe object references, whole-word variable renames, every
# mapping applied simultaneously so a swap is a swap), and the insertion is the one shipped paste
# path, which assigns fresh event uids and creates missing variables without overwriting any. All
# this file adds is the fusion plus the preview the dialog shows before you commit.


## The retarget table for a selection: {"objects": [...], "variables": [...]} - every object
## reference the rows point at and every sheet variable they need, sorted. The dialog builds one
## "find X, replace with Y" field per entry.
static func targets(sheet: EventSheetResource, rows: Array) -> Dictionary:
	return EventSheetPasteSpecial.targets(snapshot(sheet, rows))


## The rows as a portable, self-contained snippet (rows + the sheet variables they reference).
## Going through the text form is what makes the copy a true DEEP copy with no shared resources.
static func snapshot(sheet: EventSheetResource, rows: Array) -> Dictionary:
	if rows.is_empty():
		return {}
	return EventSheetSnippet.deserialize(EventSheetSnippet.serialize_rows(rows, sheet))


## The variant itself: the same shape EventSheetSnippet.deserialize returns, ready for the dock's
## paste path. `mapping` is {"objects": {from: to}, "variables": {from: to}} - a blank, unchanged
## or invalid target is skipped rather than applied, so a half-filled dialog can never corrupt it.
static func variant(sheet: EventSheetResource, rows: Array, mapping: Dictionary) -> Dictionary:
	var source: Dictionary = snapshot(sheet, rows)
	if source.is_empty():
		return {}
	return EventSheetPasteSpecial.remap(source, mapping)


## The preview pane's lines: what the variant's rows will SAY, read off the rebuilt resources
## rather than predicted - conditions with a "?" lead, actions plain, sub-events indented. The
## text is each row's baked template with its parameter values filled in, which is both the
## sheet's sentence and the GDScript it compiles to, so the preview cannot drift from the result.
static func preview_lines(remapped: Dictionary) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	_describe_rows(remapped.get("rows", []) if remapped.get("rows") is Array else [], 0, lines)
	return lines


## "Duplicate as Variant: 4 row(s), 3 reference(s) and 1 name retargeted." - the status line, in
## the same words Paste Special reports, because it is the same remap.
static func summary(row_count: int, remapped: Dictionary) -> String:
	var counts: Dictionary = remapped.get("remapped", {}) if remapped.get("remapped") is Dictionary else {}
	return "Duplicate as Variant: %d row(s), %d reference(s) and %d name(s) retargeted." % [
		row_count, int(counts.get("objects", 0)), int(counts.get("variables", 0))
	]


static func _describe_rows(rows: Array, depth: int, lines: PackedStringArray) -> void:
	var indent: String = "    ".repeat(depth)
	for row: Variant in rows:
		if row is EventGroup:
			var group: EventGroup = row as EventGroup
			lines.append("%s▸ %s" % [indent, group.group_name])
			_describe_rows(group.events if not group.events.is_empty() else group.rows, depth + 1, lines)
			continue
		if row is CommentRow:
			lines.append("%s# %s" % [indent, (row as CommentRow).text])
			continue
		if row is RawCodeRow:
			for code_line: String in (row as RawCodeRow).code.split("\n"):
				lines.append("%s%s" % [indent, code_line])
			continue
		if not (row is EventRow):
			continue
		var event: EventRow = row as EventRow
		if event.trigger != null:
			lines.append("%s? %s" % [indent, _describe_ace(event.trigger)])
		for condition: Variant in event.conditions:
			lines.append("%s? %s" % [indent, _describe_ace(condition)])
		for action: Variant in event.actions:
			if action is RawCodeRow:
				lines.append("%s%s" % [indent, (action as RawCodeRow).code.split("\n")[0]])
			else:
				lines.append("%s%s" % [indent, _describe_ace(action)])
		_describe_rows(event.sub_events, depth + 1, lines)


## One row's sentence: its baked codegen template with each {param} filled in. An ACE with no
## baked template (an older row, or one whose provider is missing) falls back to its id, so the
## preview always says something rather than showing a blank line.
static func _describe_ace(ace: Variant) -> String:
	if not (ace is Resource):
		return ""
	var template: String = str(ace.get("codegen_template"))
	var params: Dictionary = ace.get("params") if ace.get("params") is Dictionary and not (ace.get("params") as Dictionary).is_empty() else ace.get("parameters")
	if template.strip_edges().is_empty():
		return str(ace.get("ace_id"))
	if params is Dictionary:
		for key: Variant in (params as Dictionary).keys():
			template = template.replace("{%s}" % str(key), str((params as Dictionary)[key]))
	return template.replace("\n", " ").strip_edges()
