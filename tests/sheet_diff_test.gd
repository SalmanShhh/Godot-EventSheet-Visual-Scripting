# EventForge — "What changed since save", in event language. Pins the prefix/suffix changed-region
# core (identical, retune, pure insertion), and the summarize path over a REAL pack: opening
# health.gd untouched diffs as identical; retuning one param names exactly the touched event (with a
# live resource to jump to); saved_path_for resolves external sheets to their own .gd and unsaved
# sheets to "". A save must never happen as a side effect — the diff compiles to a scratch path only.
@tool
extends RefCounted
class_name SheetDiffTest

static func run() -> bool:
	var ok: bool = true

	# ── The changed-region core ──
	var same: PackedStringArray = PackedStringArray(["a", "b", "c"])
	ok = _check("identical → empty region", EventSheetSheetDiff.changed_region(same, same).is_empty(), true) and ok
	var retuned: Dictionary = EventSheetSheetDiff.changed_region(
		PackedStringArray(["a", "b", "c", "d"]), PackedStringArray(["a", "B!", "c", "d"]))
	ok = _check("a one-line retune isolates that line",
		Vector2i(int(retuned.get("new_start")), int(retuned.get("new_end"))), Vector2i(2, 2)) and ok
	var inserted: Dictionary = EventSheetSheetDiff.changed_region(
		PackedStringArray(["a", "b"]), PackedStringArray(["a", "x", "b"]))
	ok = _check("a pure insertion has an empty old side",
		int(inserted.get("old_end")) < int(inserted.get("old_start")), true) and ok
	ok = _check("…and the inserted line on the new side",
		Vector2i(int(inserted.get("new_start")), int(inserted.get("new_end"))), Vector2i(2, 2)) and ok

	# ── saved_path_for ──
	ok = _check("an unsaved sheet has no saved file", EventSheetSheetDiff.saved_path_for(EventSheetResource.new()), "") and ok

	# ── The full summary over a real opened pack ──
	var pack_path: String = "res://eventsheet_addons/health/health_behavior.gd"
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	dock.setup(EventSheetResource.new())
	dock._load_sheet_from_path(pack_path)
	var sheet: EventSheetResource = dock.get_current_sheet()
	ok = _check("an external sheet's saved file is its own .gd", EventSheetSheetDiff.saved_path_for(sheet), pack_path) and ok

	var disk_before: String = FileAccess.get_file_as_string(pack_path)
	var untouched: Dictionary = SheetCompiler.compile(sheet, "user://eventforge_diff_test.gd")
	var clean_summary: Dictionary = EventSheetSheetDiff.summarize(
		str(untouched.get("output", "")), untouched.get("source_map", []), disk_before)
	ok = _check("an untouched open diffs as identical (drift=0 in diff form)", bool(clean_summary.get("identical")), true) and ok

	# Retune one line in a block that STAYS raw (heal lifts into a real EventFunction now, so the
	# probe edits _get_pool — kept raw by its custom `-> HealthPool` return type) and diff again,
	# WITHOUT saving. The opened-pack diff attributes the change to EXACTLY the edited row.
	var edited: RawCodeRow = null
	for row: Variant in sheet.events:
		if row is RawCodeRow and (row as RawCodeRow).code.contains("func _get_pool(type: String)"):
			edited = row as RawCodeRow
	ok = _check("a raw block remains to edit (custom return type keeps _get_pool raw)", edited != null, true) and ok
	if edited == null:
		dock.free()
		return ok
	edited.code = edited.code.replace("health_pools[type] = HealthPool.new()", "health_pools[type] = _make_pool()")
	var after: Dictionary = SheetCompiler.compile(sheet, "user://eventforge_diff_test.gd")
	var summary: Dictionary = EventSheetSheetDiff.summarize(
		str(after.get("output", "")), after.get("source_map", []), disk_before)
	ok = _check("the edit is seen", bool(summary.get("identical")), false) and ok
	var rows: Array = summary.get("rows", [])
	ok = _check("exactly one row changes on save", rows.size(), 1) and ok
	ok = _check("it is EXACTLY the edited heal block (offset fix)", (rows[0] as Dictionary).get("resource") == edited, true) and ok
	ok = _check("the changed row is labelled from its emitted code",
		str((rows[0] as Dictionary).get("label", "")).length() > 0, true) and ok
	ok = _check("the replaced disk line is listed as removed",
		Array(summary.get("removed_lines", PackedStringArray())).any(
			func(line: Variant) -> bool: return str(line) == "health_pools[type] = HealthPool.new()"), true) and ok
	ok = _check("the diff NEVER wrote the real file", FileAccess.get_file_as_string(pack_path), disk_before) and ok
	dock.free()

	# ── Exact row attribution on the EDITOR-AUTHORED (main) compile path, where the source map is
	# sound. Build a sheet, retune one action's param, and the diff names exactly that action's row. ──
	var authored: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	authored.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	var authored_sheet: EventSheetResource = EventSheetResource.new()
	authored_sheet.host_class = "Node2D"
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnProcess"
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "print"
	action.params = {"text": "\"before\""}
	action.codegen_template = "print({text})"
	event.actions.append(action)
	authored_sheet.events.append(event)
	authored.setup(authored_sheet)
	var baseline: String = str(SheetCompiler.compile(authored_sheet, "user://eventforge_diff_authored.gd").get("output", ""))
	action.params = {"text": "\"after\""}
	var changed: Dictionary = SheetCompiler.compile(authored_sheet, "user://eventforge_diff_authored.gd")
	var authored_summary: Dictionary = EventSheetSheetDiff.summarize(
		str(changed.get("output", "")), changed.get("source_map", []), baseline)
	var authored_rows: Array = authored_summary.get("rows", [])
	ok = _check("editor-authored: exactly one row changes", authored_rows.size(), 1) and ok
	ok = _check("editor-authored: it is EXACTLY the retuned event's row",
		(authored_rows[0] as Dictionary).get("resource") == event, true) and ok
	authored.free()

	return ok

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] sheet_diff_test: %s" % label)
		return true
	print("[FAIL] sheet_diff_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
