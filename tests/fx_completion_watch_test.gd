# Godot EventSheets - ƒx expression autocomplete + external-sheet file watcher
# ƒx fields are single-line CodeEdits with completion fed by the same candidates as the
# GDScript-block editor; external (GDScript-backed) sheets detect disk changes by mtime
# and reload on demand (the prompt itself is editor chrome over these primitives).
@tool
class_name FxCompletionWatchTest
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")


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
	all_passed = _check("freshly opened file is not 'changed'", editor._external_watcher.sheet_changed_on_disk(), false) and all_passed
	# Simulate an outside edit: rewrite the file and force a different stored mtime
	# (filesystem mtime granularity can be 1s - too slow to wait for in tests).
	var rewrite: FileAccess = FileAccess.open(sample_path, FileAccess.WRITE)
	rewrite.store_string("extends Node\n\nvar hp: int = 2\n")
	rewrite.close()
	editor._external_mtime = 1
	all_passed = _check("outside edits are detected", editor._external_watcher.sheet_changed_on_disk(), true) and all_passed
	editor._external_watcher.reload_external_sheet()
	all_passed = _check("reload re-imports the new content",
		str(SheetCompiler.compile(editor._current_sheet, "user://eventsheets_watch_rt.gd").get("output", "")).contains("var hp: int = 2"), true) and all_passed
	all_passed = _check("reload resets the change flag", editor._external_watcher.sheet_changed_on_disk(), false) and all_passed

	# The reload question only offers to drop edits when there ARE edits to drop: on a clean tab
	# Reload is the safe blue answer; with unsaved edits, keeping them is, and the disk is the red one.
	editor._current_sheet.read_only = false
	editor._dirty = false
	editor._external_mtime = 1
	editor._external_watcher.prompt_external_reload_if_changed()
	var clean: ConfirmationDialog = editor._external_watcher._external_reload_dialog
	var clean_read: Array = [clean.title, clean.ok_button_text, clean.get_cancel_button().visible,
		clean.find_child("Danger", true, false) == null]
	editor._dirty = true
	editor._external_watcher.prompt_external_reload_if_changed()
	var dirty: ConfirmationDialog = editor._external_watcher._external_reload_dialog
	var danger: Button = dirty.find_child("Danger", true, false) as Button
	all_passed = _check("a clean tab is offered Reload, a dirty one keeps its edits by default",
		[clean_read, [dirty.ok_button_text, dirty.get_cancel_button().visible, danger.text]],
		[["eventsheets_watch_sample.gd changed outside the editor", "Reload", true, true],
		["Keep mine", false, "Use the file on disk"]]) and all_passed
	# Before choosing, the question says whether this tab has edits to lose and when the file changed,
	# and offers What Changed… beside the blue answer.
	var before: TreeItem = (dirty.find_child("Places", true, false) as Tree).get_root()
	var clean_before: TreeItem = (clean.find_child("Places", true, false) as Tree).get_root()
	var look: Array = dirty.find_children("*", "Button", true, false).filter(
		func(button: Button) -> bool: return button.text == "What Changed…")
	all_passed = _check("the question lists this tab and the disk, and offers What Changed…",
		[before.get_child(0).get_text(0), before.get_child(0).get_text(1), clean_before.get_child(0).get_text(0),
			before.get_child(1).get_text(1), before.get_child(1).get_text(0).begins_with("On disk - changed at "),
			look.size(), [danger.get_index() < (look[0] as Button).get_index(),
				(look[0] as Button).get_index() < dirty.get_ok_button().get_index()] if not look.is_empty() else []],
		["This tab - unsaved edits", "yours", "This tab - nothing unsaved", "the file", true, 1, [true, true]]) and all_passed
	# Esc keeps the edits and remembers the change, so the question is not asked again.
	dirty.canceled.emit()
	all_passed = _check("Esc keeps the edits and stops asking", [editor._dirty, editor._external_watcher.sheet_changed_on_disk()], [true, false]) and all_passed
	# Taking the file on disk first keeps the version in the editor as a backup, and says so.
	for old_backup: String in EventSheetBackups.list_backups(sample_path):
		DirAccess.remove_absolute(old_backup)
	var third: FileAccess = FileAccess.open(sample_path, FileAccess.WRITE)
	third.store_string("extends Node\n\nvar hp: int = 3\n")
	third.close()
	editor._external_mtime = 1
	editor._external_watcher.prompt_external_reload_if_changed()
	var taking: ConfirmationDialog = editor._external_watcher._external_reload_dialog
	var note: String = (taking.find_child("Note", true, false) as Label).text
	taking.custom_action.emit(load(editor.SMALL_PROMPT_PATH).DANGER_ACTION)
	var kept: PackedStringArray = EventSheetBackups.list_backups(sample_path)
	all_passed = _check("the unsaved version is kept in Sheet Backups before the disk one loads", [note,
		FileAccess.get_file_as_string(kept[0]).contains("var hp: int = 2") if not kept.is_empty() else "no backup",
		FileAccess.file_exists(EventSheetExternalWatcher.UNSAVED_COPY),
		str(SheetCompiler.compile(editor._current_sheet, "user://eventsheets_watch_rt.gd").get("output", "")).contains("var hp: int = 3")],
		["Using the file on disk keeps your unsaved edits as a backup in Sheet Backups first; Ctrl+Z cannot bring them back.",
		true, false, true]) and all_passed
	for made: String in EventSheetBackups.list_backups(sample_path):
		DirAccess.remove_absolute(made)
	editor.free()

	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("fx_completion_watch_test", label, actual, expected)
