# Godot EventSheets — ƒx expression autocomplete + external-sheet file watcher
# ƒx fields are single-line CodeEdits with completion fed by the same candidates as the
# GDScript-block editor; external (GDScript-backed) sheets detect disk changes by mtime
# and reload on demand (the prompt itself is editor chrome over these primitives).
@tool
extends RefCounted
class_name FxCompletionWatchTest

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
	var all_passed: bool = true

	# ── ƒx fields ────────────────────────────────────────────────────────────
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.variables = {"health": {"type": "int", "default": 100, "exported": false}}
	var dialog: ACEParamsDialog = ACEParamsDialog.new()
	dialog.set_lint_context_provider(func() -> EventSheetResource: return sheet)
	var container: Control = dialog._create_expression_field("amount", "health + 10")
	var code_edit: CodeEdit = null
	for child in container.get_children():
		if child is CodeEdit:
			code_edit = child
	all_passed = _check("expression field is a completion-capable CodeEdit", code_edit != null, true) and all_passed
	if code_edit != null:
		all_passed = _check("completion is enabled", code_edit.code_completion_enabled, true) and all_passed
		all_passed = _check("field value extracts as the expression", str(dialog._extract_value(code_edit)), "health + 10") and all_passed
		code_edit.text = "health +\n10"
		all_passed = _check("newlines never reach the value", str(dialog._extract_value(code_edit)).contains("\n"), false) and all_passed
		var candidates: Array[Dictionary] = EventSheetGDScriptLint.completion_candidates(sheet)
		var has_health: bool = false
		for candidate in candidates:
			if str(candidate.get("label", "")) == "health":
				has_health = true
		all_passed = _check("sheet variables are completion candidates", has_health, true) and all_passed
	container.free()

	# ── External sheet watcher ───────────────────────────────────────────────
	var sample_path: String = "user://eventsheets_watch_sample.gd"
	var file: FileAccess = FileAccess.open(sample_path, FileAccess.WRITE)
	file.store_string("extends Node\n\nvar hp: int = 1\n")
	file.close()
	var editor: EventSheetEditor = EventSheetEditor.new()
	editor.set_undo_redo_manager(NoopUndoManager.new())
	editor._load_sheet_from_path(sample_path)
	all_passed = _check("external sheet opened", editor._current_sheet != null and editor._current_sheet.external_source_path == sample_path, true) and all_passed
	all_passed = _check("freshly opened file is not 'changed'", editor._external_sheet_changed_on_disk(), false) and all_passed
	# Simulate an outside edit: rewrite the file and force a different stored mtime
	# (filesystem mtime granularity can be 1s — too slow to wait for in tests).
	var rewrite: FileAccess = FileAccess.open(sample_path, FileAccess.WRITE)
	rewrite.store_string("extends Node\n\nvar hp: int = 2\n")
	rewrite.close()
	editor._external_mtime = 1
	all_passed = _check("outside edits are detected", editor._external_sheet_changed_on_disk(), true) and all_passed
	editor._reload_external_sheet()
	all_passed = _check("reload re-imports the new content",
		str(SheetCompiler.compile(editor._current_sheet, "user://eventsheets_watch_rt.gd").get("output", "")).contains("var hp: int = 2"), true) and all_passed
	all_passed = _check("reload resets the change flag", editor._external_sheet_changed_on_disk(), false) and all_passed
	editor.free()

	return all_passed

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] fx_completion_watch_test: %s" % label)
		return true
	print("[FAIL] fx_completion_watch_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
