# EventForge - the enum editor gives each value its OWN field (with a "+ Add value" button and a per-row
# remove), instead of one shared text box where it is unclear whether a value was added. Pins: one field per
# member on open, "+ Add value" grows the list, a per-row remove shrinks it (never below one), a blank field
# is ignored, and confirming rebuilds EnumRow.members (including explicit "= N" values) so the enum still
# compiles to its canonical single-line form - the model is unchanged, so the byte-gated round-trip holds.
@tool
class_name EnumFieldEditorTest
extends RefCounted


static func run() -> bool:
	var ok: bool = true

	var enum_row: EnumRow = EnumRow.new()
	enum_row.enum_name = "State"
	enum_row.members = PackedStringArray(["IDLE", "RUN"])
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	sheet.events.append(enum_row)

	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	dock.setup(sheet)
	var dialogs: EventSheetStructRowDialogs = dock._struct_rows
	dialogs._ensure_enum_dialog()

	# ── One value field per member on open ──
	dialogs._populate_enum_dialog(enum_row)
	ok = _check("one value field per member", dialogs._enum_member_edits.size(), 2) and ok
	ok = _check("the first field holds the first value", dialogs._enum_member_edits[0].text, "IDLE") and ok
	ok = _check("the second field holds the second value", dialogs._enum_member_edits[1].text, "RUN") and ok

	# ── "+ Add value" grows the list; the new value carries an explicit number ──
	var added: LineEdit = dialogs._add_enum_member_row("")
	added.text = "HURT = 4"
	ok = _check("adding a value grows the list to 3 fields", dialogs._enum_member_edits.size(), 3) and ok

	# ── Confirming rebuilds members (explicit value kept) and the enum compiles canonically ──
	dialogs._on_enum_dialog_confirmed()
	var live_enum: EnumRow = _find_enum(dock.get_current_sheet())
	ok = _check("members rebuilt from the fields, in order, with the explicit value",
		live_enum != null and live_enum.members == PackedStringArray(["IDLE", "RUN", "HURT = 4"]), true) and ok
	var compiled: String = str(SheetCompiler.compile(dock.get_current_sheet(), "user://enum_field_test_out.gd").get("output", ""))
	ok = _check("the enum compiles to its canonical single-line form",
		compiled.contains("enum State { IDLE, RUN, HURT = 4 }"), true) and ok

	# ── A per-row remove shrinks the list ──
	dialogs._populate_enum_dialog(live_enum)  # reopen with the 3 values
	var first_row: HBoxContainer = dialogs._enum_members_box.get_child(0) as HBoxContainer
	var first_edit: LineEdit = dialogs._enum_member_edits[0]
	dialogs._remove_enum_member_row(first_row, first_edit)
	ok = _check("removing a value shrinks the list to 2 fields", dialogs._enum_member_edits.size(), 2) and ok
	ok = _check("the removed value is gone (RUN is now first)", dialogs._enum_member_edits[0].text, "RUN") and ok

	# ── Removing down to the last value keeps one empty field (never a blank list) ──
	dialogs._clear_enum_member_rows()
	var only: LineEdit = dialogs._add_enum_member_row("ONLY")
	dialogs._remove_enum_member_row(dialogs._enum_members_box.get_child(0) as HBoxContainer, only)
	ok = _check("removing the last value leaves one empty field", dialogs._enum_member_edits.size(), 1) and ok
	ok = _check("that field is empty", dialogs._enum_member_edits[0].text, "") and ok

	# ── A blank field is ignored on confirm (not an error). The removes above were dialog-only (never
	# confirmed), so the live enum still holds all three values; re-populating shows them all. ──
	dialogs._populate_enum_dialog(live_enum)
	dialogs._add_enum_member_row("")  # a trailing empty slot
	dialogs._on_enum_dialog_confirmed()
	var after_blank: EnumRow = _find_enum(dock.get_current_sheet())
	ok = _check("a blank trailing field is ignored (the three real values remain)",
		after_blank != null and after_blank.members == PackedStringArray(["IDLE", "RUN", "HURT = 4"]), true) and ok

	dock.free()
	return ok


static func _find_enum(sheet: EventSheetResource) -> EnumRow:
	for ev: Variant in sheet.events:
		if ev is EnumRow:
			return ev as EnumRow
	return null


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] enum_field_editor_test: %s" % label)
		return true
	print("[FAIL] enum_field_editor_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
