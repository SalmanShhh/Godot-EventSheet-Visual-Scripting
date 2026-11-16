# Godot EventSheets - a row placed or edited in the dock writes a plain number where its template only
# guards the value, and a row nobody touched keeps the line it had.
#
# `maxf({seconds}, 0.001)` around `2.0` is `2.0`. Every route that builds a row from the vocabulary
# (the picker, an edit, a batch edit, the preview in the parameters window, the Ask rows) turns the
# row's `folds_literals` on; the compiler then decides from the value in the slot. A row read from a
# file is not rebuilt, so it, and every sibling beside an edited row, writes the guard as before. A
# sheet saved as a resource stores the field only when it is on, so a `.tres` nobody touched saves
# back the same text it had.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := "placed_rows_fold_test"
const OLD_TWO := "extends Node\n\nvar __every_a: float = 0.0\nvar __every_b: float = 0.0\n\nfunc _process(delta: float) -> void:\n\t__every_a += delta\n\tif __every_a >= maxf(2.0, 0.001):\n\t\t__every_a = fmod(__every_a, maxf(2.0, 0.001))\n\t\tprint(\"a\")\n\t__every_b += delta\n\tif __every_b >= maxf(3.0, 0.001):\n\t\t__every_b = fmod(__every_b, maxf(3.0, 0.001))\n\t\tprint(\"b\")\n"


class NoopUndoManager:
	extends RefCounted
	func create_action(_a = null) -> void: pass
	func add_do_method(_a = null, _b = null, _c = null, _d = null, _e = null) -> void: pass
	func add_undo_method(_a = null, _b = null, _c = null, _d = null, _e = null) -> void: pass
	func commit_action() -> void: pass
	func has_undo() -> bool: return false
	func has_redo() -> bool: return false


static func run() -> bool:
	var ok: bool = true
	var editor: EventSheetEditor = EventSheetEditor.new()
	var sheet: EventSheetResource = SUPPORT.reopen(OLD_TWO)
	sheet.external_source_path = SUPPORT.own_path("placed_rows_fold.gd")
	editor.setup(sheet)
	editor.set_undo_redo_manager(NoopUndoManager.new())
	var every: ACEDefinition = editor._find_definition("Core", "EveryXSeconds")
	var bob: ACEDefinition = editor._find_definition("Core", "BobUpAndDown")
	ok = SUPPORT.check(P, "the verbs resolve", every != null and bob != null, true) and ok
	if every == null or bob == null:
		editor.free()
		return false
	# Every door of the dock that builds a row from a definition turns the flag on.
	var placed: ACECondition = editor._ace_apply._create_condition_from_definition(every, {"seconds": "2.0"})
	var placed_action: ACEAction = editor._ace_apply._create_action_from_definition(bob, {"height": "6.0", "period": "2.0"})
	ok = SUPPORT.pins(P, [
		["a placed condition asks for the short line", placed.folds_literals, true],
		["a placed action asks for the short line", placed_action.folds_literals, true],
		["a duplicate keeps the flag", placed.duplicate(true).folds_literals, true],
		["the Every row writes the number", EventSheetConditionCodegen.generate_condition(placed).replace(placed.params.get("uid", "?"), "X").contains(">= 2.0"), true],
		["the action writes the number", EventSheetActionCodegen.generate_action(placed_action).contains("TAU / 2.0"), true],
		["the guard is back when the value is a name", EventSheetActionCodegen.generate_action(_with(placed_action, "period", "wave")).contains("TAU / maxf(wave, 0.01)"), true],
		["the preview in the parameters window shows the same line", ACEParamsDialog.row_code_line(bob, {"height": "6.0", "period": "2.0"}).contains("TAU / 2.0"), true],
	]) and ok
	# The unedited sheet writes its file back unchanged.
	ok = SUPPORT.check(P, "the old sheet saves back byte for byte", SUPPORT.compile_output(sheet, sheet.external_source_path), OLD_TWO) and ok
	# Editing the first row's seconds through the dock rebuilds that row only.
	var first_event: EventRow = _event_with_every(sheet, 0)
	var second_event: EventRow = _event_with_every(sheet, 1)
	var second_flag_before: bool = _every(second_event).folds_literals
	editor._ace_apply._apply_ace_definition(every, {"seconds": "5.0"}, {
		"mode": "replace_condition", "selected_resource": first_event, "ace_index": _every_index(first_event)})
	var out: String = SUPPORT.compile_output(sheet, sheet.external_source_path)
	ok = SUPPORT.check(P, "the edited row writes the short line", out.contains(">= 5.0:"), true) and ok
	ok = SUPPORT.check(P, "the row beside it keeps the guard", out.contains("if __every_b >= maxf(3.0, 0.001):"), true) and ok
	ok = SUPPORT.check(P, "the row beside it still has the flag off", second_flag_before, false) and ok
	ok = SUPPORT.check(P, "the row beside it keeps its rebase line", out.contains("__every_b = fmod(__every_b, maxf(3.0, 0.001))"), true) and ok
	editor.free()
	# A sheet saved as a resource stores the field only when it is on.
	var untouched: EventSheetResource = SUPPORT.reopen(OLD_TWO)
	var untouched_path: String = SUPPORT.own_path("placed_rows_untouched.tres")
	ResourceSaver.save(untouched, untouched_path)
	ok = SUPPORT.check(P, "a resource sheet nobody touched stores no new field", FileAccess.get_file_as_string(untouched_path).contains("folds_literals"), false) and ok
	var flagged: EventSheetResource = SUPPORT.reopen(OLD_TWO)
	_every(_event_with_every(flagged, 0)).folds_literals = true
	var flagged_path: String = SUPPORT.own_path("placed_rows_flagged.tres")
	ResourceSaver.save(flagged, flagged_path)
	var reloaded: EventSheetResource = ResourceLoader.load(flagged_path, "", ResourceLoader.CACHE_MODE_IGNORE) as EventSheetResource
	ok = SUPPORT.check(P, "a placed row's flag survives a save as a resource", _every(_event_with_every(reloaded, 0)).folds_literals, true) and ok
	return ok


static func _with(action: ACEAction, key: String, value: String) -> ACEAction:
	var copy: ACEAction = action.duplicate(true)
	copy.params[key] = value
	return copy


static func _every_index(event_row: EventRow) -> int:
	for i: int in event_row.conditions.size():
		if event_row.conditions[i].ace_id == "EveryXSeconds":
			return i
	return -1


static func _every(event_row: EventRow) -> ACECondition:
	return event_row.conditions[_every_index(event_row)]


static func _event_with_every(sheet: EventSheetResource, nth: int) -> EventRow:
	var seen: int = 0
	for entry: Variant in sheet.events:
		if entry is EventRow and _every_index(entry as EventRow) >= 0:
			if seen == nth:
				return entry as EventRow
			seen += 1
	return null
