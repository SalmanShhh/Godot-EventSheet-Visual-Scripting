# Godot EventSheets - editing a reopened row of a verb that keeps state keeps THAT state.
#
# Every verb that owns a member (a clock, a seen flag, a deadline) writes it once, under the uid its
# row carries. Opened from a file, the row carries that uid and no member of its own, because the file
# already holds the member and its helper. Editing the row used to build a brand-new one from the
# picker: a second uid, a second member and helper beside the first, and the call now pointing at the
# new, empty state. The edit now keeps the uid the row was read with, so the file still has one of each.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := "stateful_edit_keeps_state_test"


class NoopUndoManager:
	extends RefCounted
	func create_action(_a = null) -> void: pass
	func add_do_method(_a = null, _b = null, _c = null, _d = null, _e = null) -> void: pass
	func add_undo_method(_a = null, _b = null, _c = null, _d = null, _e = null) -> void: pass
	func commit_action() -> void: pass
	func has_undo() -> bool: return false
	func has_redo() -> bool: return false
	func undo() -> void: pass
	func redo() -> void: pass
	func clear_history() -> void: pass


static func run() -> bool:
	var ok: bool = true
	var probe: EventSheetEditor = EventSheetEditor.new()
	probe.setup(EventSheetResource.new())
	var ids: Array = []
	for definition: ACEDefinition in probe._ace_registry.get_all_definitions():
		if definition.ace_type == ACEDefinition.ACEType.CONDITION and not str(definition.metadata.get("member_template", "")).is_empty():
			ids.append([definition.provider_id, definition.id])
	probe.free()
	ok = SUPPORT.check(P, "the vocabulary has verbs that keep state", ids.size() > 10, true) and ok
	for pair: Array in ids:
		ok = _edit_keeps_state(str(pair[0]), str(pair[1]), {}) and ok
	# A changed value rides the edit: the call line carries the new numbers and still one set of members.
	ok = _edit_keeps_state("Core", "EveryRandomSeconds", {"min_seconds": "1.5", "max_seconds": "2.5"}) and ok
	return ok


static func _edit_keeps_state(provider: String, ace_id: String, params: Dictionary) -> bool:
	var ok: bool = true
	var path: String = SUPPORT.own_path("stateful_edit_%s.gd" % ace_id)
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.external_source_path = path
	var editor: EventSheetEditor = EventSheetEditor.new()
	editor.setup(sheet)
	editor.set_undo_redo_manager(NoopUndoManager.new())
	editor._ace_apply._apply_ace_definition(editor._find_definition(provider, ace_id), {}, {})
	var written: String = SUPPORT.compile_output(sheet, path)
	editor.free()
	# The file as a user has it: opened from its own text, the row carries its uid and no member.
	var reopened: EventSheetResource = SUPPORT.reopen(written, true, path)
	var event_row: EventRow = null
	var index: int = -1
	for entry: Variant in reopened.events:
		if entry is EventRow:
			for i: int in (entry as EventRow).conditions.size():
				if (entry as EventRow).conditions[i].ace_id == ace_id and index < 0:
					event_row = entry
					index = i
	if index < 0:
		# Opened as a plain expression row: there is no row of its own to edit, so nothing to duplicate.
		return true
	reopened.external_source_path = path
	var again: EventSheetEditor = EventSheetEditor.new()
	again.setup(reopened)
	again.set_undo_redo_manager(NoopUndoManager.new())
	var context: Dictionary = {"mode": "replace_condition", "selected_resource": event_row, "ace_index": index}
	again._ace_apply._apply_ace_definition(again._find_definition(provider, ace_id), params, context)
	var edited: String = SUPPORT.compile_output(reopened, path)
	again.free()
	var label: String = "%s %s" % [ace_id, "with new values" if not params.is_empty() else "edited"]
	ok = SUPPORT.check(P, "%s: still one member declaration per member" % label, edited.count("\nvar __"), written.count("\nvar __")) and ok
	ok = SUPPORT.check(P, "%s: still one helper function per helper" % label, edited.count("\nfunc __"), written.count("\nfunc __")) and ok
	ok = SUPPORT.check(P, "%s: still one accumulating line" % label, edited.count("get_process_delta_time"), written.count("get_process_delta_time")) and ok
	for key: Variant in params.keys():
		ok = SUPPORT.check(P, "%s: the new %s is written" % [label, str(key)], edited.contains(str(params[key])), true) and ok
	return ok
