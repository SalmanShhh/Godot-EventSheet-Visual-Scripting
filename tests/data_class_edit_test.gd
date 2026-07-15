# EventForge - a "Data class" block's fields are editable in place. Double-clicking a field's name, type or
# default opens a one-field inline editor; committing re-emits the class from its structured model into the
# RawCodeRow's code through the undo funnel. This pins the covenant of the EDIT path (Phase 1b), where the
# byte round-trip no longer applies (an edit is a deliberate change) but a SHARPER guarantee does: an edit
# changes ONLY the touched field's line - every other field, the header and the doc prefix stay byte
# identical (it follows from the lift byte-gate: the model reproduced the source exactly, so re-emitting
# after one field changes touches one line). Also pinned: a no-op / invalid edit changes nothing, the edited
# state round-trips, and the field rows stay inert (source null) so select / drag / delete never reach them.
@tool
class_name DataClassEditTest
extends RefCounted

const PACK := "res://eventsheet_addons/abilities/abilities_behavior.gd"


static func run() -> bool:
	var ok: bool = true
	var source: String = (FileAccess.open(PACK, FileAccess.READ)).get_as_text()

	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	dock.setup(EventSheetResource.new())
	dock._load_sheet_from_path(PACK)
	var view: EventSheetViewport = dock._active_view()
	var class_row: EventRowData = _find_data_class_row(view)
	ok = _check("found the AbilityData block with its 10 field rows", class_row != null and class_row.children.size() == 10, true) and ok
	if class_row == null:
		dock.free()
		return false

	# ── ONLY the default is editable; name and type are read-only (a rename/type change would break use
	# sites elsewhere in the .gd). The row stays inert (null source) for select / drag / delete. ──
	var cooldown_row: EventRowData = class_row.children[0]
	var default_span: SemanticSpan = _span_with_part(cooldown_row, "default")
	ok = _check("the default value is an editable span", default_span != null, true) and ok
	ok = _check("the name / type parts are NOT editable (no rename/type-change footgun)",
		_span_with_part(cooldown_row, "name") == null and _span_with_part(cooldown_row, "type") == null, true) and ok
	ok = _check("the default span is not caret-editable (the generic inline editor skips it)",
		default_span != null and not bool((default_span.metadata as Dictionary).get("editable", true)), true) and ok
	ok = _check("the field row is inert (source null - select / drag / delete skip it)", cooldown_row.source_resource == null, true) and ok
	# The field maps onto the sheet's condition/action model: name : type in the CONDITION cell, default in
	# the ACTION cell (so it reads as an event, not a plain declaration line).
	ok = _check("the field is an EVENT row (gets the condition | action lanes)",
		cooldown_row.row_type == EventRowData.RowType.EVENT, true) and ok
	ok = _check("the field name is in the CONDITION cell",
		str((cooldown_row.spans[0].metadata as Dictionary).get("lane")), "condition") and ok
	var default_lane: String = str((default_span.metadata as Dictionary).get("lane")) if default_span != null else "<null>"
	ok = _check("the editable default is in the ACTION cell", default_lane, "action") and ok
	ok = _check("each field row has a unique row_uid (selecting one never highlights the rest)",
		str(cooldown_row.row_uid) != "" and str(cooldown_row.row_uid) != str((class_row.children[1] as EventRowData).row_uid), true) and ok
	var raw_row: Resource = (default_span.metadata as Dictionary).get("raw_row") if default_span != null else null
	var field_index: int = int((default_span.metadata as Dictionary).get("field_index", -1)) if default_span != null else -1
	ok = _check("edit metadata references the class RawCodeRow", raw_row is RawCodeRow, true) and ok

	# Baseline: compiling the untouched sheet reproduces the file (drift=0), so the diffs below isolate the edit.
	ok = _check("the untouched pack compiles byte-identically (drift=0)", _compile(dock) == source, true) and ok

	# ── A pack opens as a read-only preview; a NO-OP field-edit Enter must not unlock it (the unlock fires
	# inside the undo funnel, so a no-op must never reach the funnel). ──
	ok = _check("the opened pack starts as a read-only preview", dock.get_current_sheet().read_only, true) and ok
	_drive_field_edit(dock, raw_row, field_index, "default", "0.0")  # re-enter the existing value
	ok = _check("a no-op field edit does NOT unlock the read-only preview", dock.get_current_sheet().read_only, true) and ok
	ok = _check("a no-op field edit leaves the file byte-identical", _compile(dock) == source, true) and ok

	# ── A drag of an inert field row is refused (it can never alias into sheet.events) ──
	var drag_target: EventRowData = EventRowData.new()
	drag_target.source_resource = dock.get_current_sheet().events[0]
	dock._move_rows([cooldown_row], drag_target, "after", false)
	ok = _check("dragging a field row is a no-op (null source, nothing aliased)",
		not dock.get_current_sheet().events.has(null), true) and ok

	# ── A REAL edit (cooldown default 0.0 -> 5.0) changes ONLY that line, and unlocks the preview ──
	var live_raw: Resource = _find_ability_data_raw(dock.get_current_sheet())
	_drive_field_edit(dock, live_raw, field_index, "default", "5.0")
	var after_default: String = _compile(dock)
	ok = _check("editing the default changed the file", after_default != source, true) and ok
	ok = _check("ONLY the cooldown default line changed (the sibling guarantee)",
		_diff_is(source, after_default, "\tvar cooldown: float = 0.0", "\tvar cooldown: float = 5.0"), true) and ok
	ok = _check("a real edit unlocks the preview (deliberate edit intent)", dock.get_current_sheet().read_only, false) and ok

	# ── The edited state round-trips: re-import the emitted file, the field shows 5.0 ──
	var reimported: EventSheetResource = GDScriptImporter.new().import_external_source(after_default)
	ok = _check("the edited default round-trips (re-import shows 5.0)",
		_reimport_field_default(reimported, "cooldown"), "5.0") and ok

	# ── A default carrying whitespace is preserved verbatim (no strip_edges rewriting bytes) ──
	live_raw = _find_ability_data_raw(dock.get_current_sheet())
	_drive_field_edit(dock, live_raw, field_index, "default", "7.5 ")  # trailing space is the user's bytes
	ok = _check("the default is written verbatim (trailing space kept, not stripped)",
		_compile(dock).contains("\tvar cooldown: float = 7.5 \n"), true) and ok

	# ── @export / const members render as read-only rows, so no declaration is ever hidden ──
	var syn_sheet: EventSheetResource = EventSheetResource.new()
	syn_sheet.host_class = "Node"
	var syn_raw: RawCodeRow = RawCodeRow.new()
	syn_raw.code = "class Config:\n\t@export var volume: float = 1.0\n\t@export var muted: bool = false"
	syn_sheet.events.append(syn_raw)
	var dock2: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock2.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	dock2.setup(syn_sheet)
	var syn_row: EventRowData = _find_data_class_row(dock2._active_view())
	ok = _check("an @export-only data class shows its members as rows (never '0 fields' with them hidden)",
		syn_row != null and syn_row.children.size() == 2, true) and ok
	dock2.free()

	dock.free()
	return ok


static func _drive_field_edit(dock: EventSheetDock, raw_row: Resource, field_index: int, part: String, new_value: String) -> void:
	dock._on_data_class_field_edit_requested(raw_row, field_index, part, "")
	dock._inline_params._field_edit_field.text = new_value
	dock._inline_params._commit_data_class_field_edit()


# Compile to a THROWAWAY user:// path, never the real pack: SheetCompiler.compile writes its output to the
# path argument (falling back to sheet.external_source_path when empty), so compiling an EDITED sheet to the
# pack would overwrite the committed .gd on disk. The returned "output" text is what we assert on.
static func _compile(dock: EventSheetDock) -> String:
	return str(SheetCompiler.compile(dock.get_current_sheet(), "user://dc_edit_test_out.gd").get("output", ""))


## True when `after` differs from `before` in EXACTLY one line, and that line went from old_line to new_line.
static func _diff_is(before: String, after: String, old_line: String, new_line: String) -> bool:
	var b: PackedStringArray = before.split("\n")
	var a: PackedStringArray = after.split("\n")
	if b.size() != a.size():
		return false
	var diffs: int = 0
	var matched: bool = false
	for i: int in range(b.size()):
		if b[i] != a[i]:
			diffs += 1
			if b[i] == old_line and a[i] == new_line:
				matched = true
	return diffs == 1 and matched


static func _find_data_class_row(view: EventSheetViewport) -> EventRowData:
	# The data-class header row keeps its RawCodeRow as source and a class-name-keyed row_uid; its field
	# children are inert (null source). This finds the header without depending on its span text.
	for entry: Dictionary in view.get_flat_rows():
		var row_data: EventRowData = entry.get("row")
		if row_data != null and row_data.source_resource is RawCodeRow and str(row_data.row_uid).begins_with("data_class_"):
			return row_data
	return null


static func _span_with_part(row_data: EventRowData, part: String) -> SemanticSpan:
	for span: SemanticSpan in row_data.spans:
		if span != null and span.metadata is Dictionary and str((span.metadata as Dictionary).get("part", "")) == part:
			return span
	return null


static func _find_ability_data_raw(sheet: EventSheetResource) -> Resource:
	for ev: Variant in sheet.events:
		if ev is RawCodeRow and (ev as RawCodeRow).code.contains("class AbilityData"):
			return ev as Resource
	return null


static func _reimport_field_default(sheet: EventSheetResource, field_name: String) -> String:
	var raw: Resource = _find_ability_data_raw(sheet)
	if raw == null:
		return "<no class>"
	var model: Dictionary = ViewportRowBuilder.parse_data_class((raw as RawCodeRow).code)
	for entry: Dictionary in model.get("body", []):
		if str(entry.get("kind")) == "field" and str(entry.get("name")) == field_name:
			return str(entry.get("default"))
	return "<no field>"


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] data_class_edit_test: %s" % label)
		return true
	print("[FAIL] data_class_edit_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
