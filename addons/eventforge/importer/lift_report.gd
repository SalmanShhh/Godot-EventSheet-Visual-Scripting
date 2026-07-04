# Godot EventSheets - the lift report ("why is this still GDScript?")
#
# After a .gd opens as a sheet, this explains the boundary between structure and
# code: which functions lifted into events, and why each remaining block stayed
# verbatim - with the closest ACE named, so the boundary teaches instead of
# confusing. Computed post-hoc from the imported sheet (the lifter needs no
# changes to be explainable). For event-sheet users learning Godot, every unlifted block
# is a lesson; for Godot devs it's trust through transparency.
@tool
class_name EventSheetLiftReport
extends RefCounted


## One entry per top-level row/function: {kind: "event"|"function"|"code"|"comment",
## label, reason} - reason is "" for lifted structure.
static func for_sheet(sheet: EventSheetResource) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if sheet == null:
		return entries
	for row: Variant in sheet.events:
		if row is EventRow:
			var event: EventRow = row
			var raw_inside: int = 0
			for ace: Variant in event.actions:
				if ace is RawCodeRow:
					raw_inside += 1
			entries.append({"kind": "event", "label": "EVENT %s/%s" % [event.trigger_provider_id, event.trigger_id],
				"reason": "" if raw_inside == 0 else "%d line group(s) inside stayed in-flow GDScript (no matching ACE template)." % raw_inside})
		elif row is CommentRow:
			entries.append({"kind": "comment", "label": (row as CommentRow).text.get_slice("\n", 0), "reason": ""})
		elif row is RawCodeRow:
			var code: String = (row as RawCodeRow).code
			entries.append({"kind": "code", "label": _label_for(code), "reason": reason_for(code)})
	for function_entry: Variant in sheet.functions:
		if function_entry is EventFunction:
			entries.append({"kind": "function", "label": "FUNCTION %s" % (function_entry as EventFunction).function_name, "reason": ""})
	return entries


## The closest-ACE explanation for a block that stayed code. The boundary is the
## curriculum: each reason names the structured way to say the same thing.
static func reason_for(code: String) -> String:
	var stripped: String = code.strip_edges()
	if stripped.begins_with("extends ") or stripped.begins_with("@icon") or stripped.begins_with("class_name ") \
			or RegEx.create_from_string("(?m)^(@export|var |const |signal |enum )").search(stripped) != null \
			and not stripped.begins_with("func "):
		return "Class prelude (extends / variables / signals) - declarations lift only when byte-exact."
	if stripped.contains("await "):
		return "Uses await - the Wait action is the structured equivalent."
	if RegEx.create_from_string("(?m)^\\s*while ").search(stripped) != null:
		return "Uses a while loop - the System Repeat/While ACEs are the structured equivalent."
	if RegEx.create_from_string("(?m)^\\s*for ").search(stripped) != null:
		return "Uses a for loop - the System loop ACEs (or a For Each pick filter) cover this."
	if RegEx.create_from_string("(?m)^\\s*match ").search(stripped) != null:
		return "Uses match - Add Match To Actions… is the structured equivalent."
	if stripped.contains("func("):
		return "Holds a lambda - Callables-as-data stay honest GDScript by design."
	if stripped.begins_with("func "):
		return "Custom function with no lift shape - sheet functions (exposed as ACEs) cover this."
	return "No matching ACE template - stays honest GDScript (lossless either way)."


static func _label_for(code: String) -> String:
	for line: String in code.split("\n"):
		if not line.strip_edges().is_empty():
			return line.strip_edges().left(60)
	return "(blank block)"


## "4 events, 1 function, 2 code blocks" - the status-line form.
static func summary(entries: Array[Dictionary]) -> String:
	var counts: Dictionary = {"event": 0, "function": 0, "code": 0, "comment": 0}
	for entry: Dictionary in entries:
		var kind: String = str(entry.get("kind"))
		counts[kind] = int(counts.get(kind, 0)) + 1
	return "%d event(s), %d function(s), %d code section(s)" % [int(counts["event"]), int(counts["function"]), int(counts["code"])]
