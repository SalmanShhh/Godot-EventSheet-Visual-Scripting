# Godot EventSheets - editing an Every X Seconds row read from a file keeps ONE clock.
#
# A file that already has a timer opens as three rows: the `+= delta` line, the Every row (its clock
# is the `uid` it was read with) and the `fmod` rebase line. Editing the Every row used to build a
# brand-new condition from the picker's definition: a second clock (`__every_<fresh>`, its own member,
# its own `+= get_process_delta_time()` and its own rebase) while the old clock's two rows stayed,
# updating a timer nothing read, and the rebase still said the old seconds. The edit now keeps the
# clock it was read with and the rebase follows the new seconds. The template is untouched.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := "every_seconds_edit_test"
const APPLY_PATH := "res://addons/eventsheet/editor/dock/ace_apply.gd"
const SOURCE := "extends Node\n\nvar fired: int = 0\nvar __every_tick: float = 0.0\n\nfunc _process(delta: float) -> void:\n\t__every_tick += delta\n\tif __every_tick >= maxf(0.5, 0.001):\n\t\t__every_tick = fmod(__every_tick, maxf(0.5, 0.001))\n\t\tfired += 1\n"
const EDITED_BY_DOCK := "extends Node

var fired: int = 0
var __every_tick: float = 0.0

func _process(delta: float) -> void:
	__every_tick += delta
	if __every_tick >= 1.0:
		__every_tick = fmod(__every_tick, 1.0)
		fired += 1
"
const FOLDED_SOURCE := "extends Node

var fired: int = 0
var __every_tick: float = 0.0

func _process(delta: float) -> void:
	__every_tick += delta
	if __every_tick >= 0.5:
		__every_tick = fmod(__every_tick, 0.5)
		fired += 1
"
const EDITED := "extends Node\n\nvar fired: int = 0\nvar __every_tick: float = 0.0\n\nfunc _process(delta: float) -> void:\n\t__every_tick += delta\n\tif __every_tick >= maxf(1.0, 0.001):\n\t\t__every_tick = fmod(__every_tick, maxf(1.0, 0.001))\n\t\tfired += 1\n"


static func run() -> bool:
	var ok: bool = true
	var apply: Script = load(APPLY_PATH)
	ok = _through_the_dock(SOURCE, "an old file", EDITED_BY_DOCK, "replace_condition") and ok
	ok = _through_the_dock(SOURCE, "an old file, edited with every matching row", EDITED_BY_DOCK, "batch_edit_params") and ok
	ok = _through_the_dock(FOLDED_SOURCE, "a file that wrote the short line", EDITED_BY_DOCK, "replace_condition") and ok
	ok = SUPPORT.check(P, "the dock has the keep-the-clock step", apply.has_method("keep_lifted_clock"), true) and ok
	if not apply.has_method("keep_lifted_clock"):
		return false
	var sheet: EventSheetResource = SUPPORT.reopen(SOURCE)
	var event_row: EventRow = null
	var index: int = -1
	for entry: Variant in sheet.events:
		if entry is EventRow:
			for i: int in (entry as EventRow).conditions.size():
				if (entry as EventRow).conditions[i].ace_id == "EveryXSeconds":
					event_row = entry
					index = i
	ok = SUPPORT.check(P, "the file opens with an Every row", index >= 0, true) and ok
	# What the picker builds for "1.0 seconds", fresh clock baked, exactly as ace_apply does it.
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor("Core", "EveryXSeconds")
	var edited: ACECondition = ACECondition.new()
	edited.provider_id = "Core"
	edited.ace_id = "EveryXSeconds"
	edited.params = {"seconds": "1.0"}
	edited.codegen_template = descriptor.codegen_template.replace("{uid}", "1a2b3c4d")
	edited.member_declaration = descriptor.member_template.replace("{uid}", "1a2b3c4d")
	edited.codegen_prelude = descriptor.codegen_prelude.replace("{uid}", "1a2b3c4d")
	edited.codegen_on_true = descriptor.codegen_on_true.replace("{uid}", "1a2b3c4d")
	apply.call("keep_lifted_clock", event_row.conditions[index], edited, event_row)
	event_row.conditions[index] = edited
	sheet.external_source_path = SUPPORT.own_path("every_seconds_edit.gd")
	var out: String = SUPPORT.compile_output(sheet, SUPPORT.own_path("every_seconds_edit.gd"))
	ok = SUPPORT.check(P, "the edit writes one clock with the new seconds, rebase included", out, EDITED) and ok
	ok = SUPPORT.check(P, "no second clock", out.contains("__every_1a2b3c4d"), false) and ok
	ok = SUPPORT.check(P, "the edited file opens and saves back byte for byte", EventSheets.round_trips(out), true) and ok
	# A row placed fresh from the picker (no clock read from a file) still gets its own clock.
	var fresh_event: EventRow = EventRow.new()
	var fresh: ACECondition = ACECondition.new()
	fresh.ace_id = "EveryXSeconds"
	fresh.params = {"seconds": "1.0"}
	fresh.member_declaration = descriptor.member_template.replace("{uid}", "1a2b3c4d")
	apply.call("keep_lifted_clock", null, fresh, fresh_event)
	ok = SUPPORT.check(P, "a fresh row keeps its own member", fresh.member_declaration, "var __every_1a2b3c4d: float = 0.0") and ok
	return ok


class NoopUndoManager:
	extends RefCounted
	func create_action(_a = null) -> void: pass
	func add_do_method(_a = null, _b = null, _c = null, _d = null, _e = null) -> void: pass
	func add_undo_method(_a = null, _b = null, _c = null, _d = null, _e = null) -> void: pass
	func commit_action() -> void: pass
	func has_undo() -> bool: return false
	func has_redo() -> bool: return false


## The edit the way the dock makes it: the Every row's seconds changed to 1.0 through the apply funnel.
static func _through_the_dock(source: String, what: String, expected: String, mode: String) -> bool:
	var ok: bool = true
	var sheet: EventSheetResource = SUPPORT.reopen(source)
	sheet.external_source_path = SUPPORT.own_path("every_seconds_edit_dock.gd")
	var editor: EventSheetEditor = EventSheetEditor.new()
	editor.setup(sheet)
	editor.set_undo_redo_manager(NoopUndoManager.new())
	var definition: ACEDefinition = editor._find_definition("Core", "EveryXSeconds")
	var event_row: EventRow = null
	var index: int = -1
	for entry: Variant in sheet.events:
		if entry is EventRow:
			for i: int in (entry as EventRow).conditions.size():
				if (entry as EventRow).conditions[i].ace_id == "EveryXSeconds":
					event_row = entry
					index = i
	var context: Dictionary = {"mode": mode, "selected_resource": event_row, "ace_index": index}
	if mode == "batch_edit_params":
		context = {"mode": mode, "batch_kind": "condition", "batch_targets": [{"event": event_row, "index": index}], "batch_count": 1}
	editor._ace_apply._apply_ace_definition(definition, {"seconds": "1.0"}, context)
	var out: String = SUPPORT.compile_output(sheet, sheet.external_source_path)
	ok = SUPPORT.check(P, "%s: the edit through the dock writes one clock with the new seconds" % what, out, expected) and ok
	ok = SUPPORT.check(P, "%s: the edited file opens and saves back byte for byte" % what, EventSheets.round_trips(out), true) and ok
	var parsed: GDScript = GDScript.new()
	parsed.source_code = out
	ok = SUPPORT.check(P, "%s: the edited file parses" % what, parsed.reload(true), OK) and ok
	editor.free()
	return ok
