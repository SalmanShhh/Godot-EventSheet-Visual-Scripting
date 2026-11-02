# Godot EventSheets - what the compiler said about a sheet when it was last written, kept where the
# editor can show it.
#
# The compiler has always returned a list of warnings beside its output ("Condition X is off and keeps
# state of its own", "Include not found", ...). Nothing in the editor read it: only the MCP server did,
# so a sheet could compile with a dozen warnings and a reader would never be told. This is the join
# that tells them, under the quiet-sheet law: a warning that belongs to one event sets the amber state
# on that event's row (the row's help strip says the words once it is selected), every warning is
# counted on the status line after a save, and the Doctor's inbox lists them.
#
# WHAT IS KEPT. For each sheet file, the warnings of its LAST write - not re-derived on every ask,
# because a compile is exactly what a canvas must not pay for per frame. A save replaces the entry, so
# a warning that was fixed stops being reported with nothing to clean up. The event a warning belongs
# to is held by instance id and looked up when asked: an edit replaces the resources a sheet holds, so
# after one the amber state goes quiet until the next save writes the sheet again - a stale mark on a
# row that has since changed would be worse than none.
#
# PURE + STATIC: no viewport, no dialog, no display server, so every word is pinned headless.
@tool
class_name EventSheetCompileFindings
extends RefCounted

## The one finding kind, by id. Frozen: the amber state, the strip and the Doctor's line address it.
const KIND_COMPILER_WARNING := "compiler-warning"

## Where a finding hangs. Always under the event the compiler was writing when it warned.
const ANCHOR_EVENT := "event"

## path -> {"warnings": Array[String], "rows": Array[{uid, message}]}.
static var _recorded: Dictionary = {}


## The file a sheet is written to, which is what its warnings are filed under. "" for a sheet with no
## file yet: nothing was written, so there is nothing to have warned about.
static func key_of(sheet: EventSheetResource) -> String:
	if sheet == null:
		return ""
	if not sheet.external_source_path.is_empty():
		return sheet.external_source_path
	return sheet.resource_path


## Remembers what one compile said, replacing what the last one did. Returns true when the SET of
## warnings changed, which is the caller's cue to repaint the amber state: the usual save of a sheet
## that had none and has none must not rebuild a single row.
static func record(sheet: EventSheetResource, compile_result: Dictionary) -> bool:
	var key: String = key_of(sheet)
	if key.is_empty():
		return false
	var warnings: Array = (compile_result.get("warnings", []) as Array).duplicate()
	var rows: Array = (compile_result.get("warning_rows", []) as Array).duplicate(true)
	var before: Dictionary = _recorded.get(key, {})
	var changed: bool = before.get("warnings", []) != warnings or before.get("rows", []) != rows
	if warnings.is_empty():
		_recorded.erase(key)
	else:
		_recorded[key] = {"warnings": warnings, "rows": rows}
	return changed


## Every warning the last write of this sheet's file produced, in the compiler's order.
static func warnings_for(sheet: EventSheetResource) -> Array:
	return (_recorded.get(key_of(sheet), {}).get("warnings", []) as Array).duplicate()


## The sheet files with warnings on record, in path order - the Doctor's corpus.
static func recorded_paths() -> PackedStringArray:
	var paths: PackedStringArray = PackedStringArray(_recorded.keys())
	paths.sort()
	return paths


## Every warning on record for one file path.
static func warnings_at(path: String) -> Array:
	return (_recorded.get(path, {}).get("warnings", []) as Array).duplicate()


## Forgets everything on record. A test's way back to a clean slate.
static func clear() -> void:
	_recorded.clear()


## The findings the canvas puts into the amber state: one per warning the compiler attributed to an
## event that is still in the sheet. The shape every family speaks (kind, severity, anchor, event,
## subject, message, fix, fix_label), and no door: a warning's cure is a different row or a different
## setting, neither of which is a one-property write a strip button can make for somebody.
static func findings(sheet: EventSheetResource) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for entry: Variant in (_recorded.get(key_of(sheet), {}).get("rows", []) as Array):
		var event_row: EventRow = instance_from_id(int(str((entry as Dictionary).get("uid", "0")))) as EventRow
		if event_row == null:
			continue
		found.append({
			"kind": KIND_COMPILER_WARNING, "severity": "warning", "anchor": ANCHOR_EVENT,
			"event": event_row, "subject": "", "message": str((entry as Dictionary).get("message", "")),
			"fix": "", "fix_label": "",
		})
	return found


## " - N compiler warning(s)" for the sentence another message ends with, or "" when the file has none
## on record - so a second finding about the same save never hides the first.
static func tail_for(path: String) -> String:
	var count: int = warnings_at(path).size()
	return "" if count == 0 else " - " + EventSheetL10n.translate("%d compiler warning(s) - the first: %s") % [count, str(warnings_at(path)[0])]


## The words after a save: how many warnings, and the first. "" when there were none.
static func summary(warnings: Array) -> String:
	if warnings.is_empty():
		return ""
	return EventSheetL10n.translate("%d compiler warning(s) - the first: %s") % [warnings.size(), str(warnings[0])]
