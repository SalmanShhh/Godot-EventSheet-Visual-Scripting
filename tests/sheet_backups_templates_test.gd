# Godot EventSheets — Tier-3 usability: the save-time backup ring (user:// ring,
# restore-into-editor as an unsaved change) and project-local templates (drop a .tres
# in the templates dir → New… menu; blueprints skipped by doctor + vocabulary doc).
@tool
extends RefCounted
class_name SheetBackupsTemplatesTest

class NoopUndoManager:
	extends RefCounted
	func create_action(_a = null) -> void: pass
	func add_do_method(_a = null, _b = null, _c = null, _d = null, _e = null) -> void: pass
	func add_undo_method(_a = null, _b = null, _c = null, _d = null, _e = null) -> void: pass
	func commit_action() -> void: pass
	func has_undo() -> bool: return false
	func has_redo() -> bool: return false

static func run() -> bool:
	var all_passed: bool = true

	# ── Backup ring core ──────────────────────────────────────────────────────────
	all_passed = _check("missing files have nothing to back up",
		EventSheetBackups.backup_sheet("user://backup_nothing_here.tres"), "") and all_passed
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	sheet.variables = {"hp": {"type": "int", "default": 1, "exported": true}}
	var sheet_path: String = "user://backup_fixture.tres"
	for stale: String in EventSheetBackups.list_backups(sheet_path):
		DirAccess.remove_absolute(stale)
	ResourceSaver.save(sheet, sheet_path)
	var original_bytes: PackedByteArray = FileAccess.get_file_as_bytes(sheet_path)
	var first_backup: String = EventSheetBackups.backup_sheet(sheet_path)
	all_passed = _check("backup preserves the file's exact bytes",
		FileAccess.get_file_as_bytes(first_backup) == original_bytes, true) and all_passed
	EventSheetBackups.backup_sheet(sheet_path)
	var backups: PackedStringArray = EventSheetBackups.list_backups(sheet_path)
	all_passed = _check("backups list newest first",
		backups.size() == 2 and backups[0].get_file().begins_with("0002."), true) and all_passed
	ProjectSettings.set_setting("eventsheets/editor/backup_count", 2)
	EventSheetBackups.backup_sheet(sheet_path)
	backups = EventSheetBackups.list_backups(sheet_path)
	all_passed = _check("the ring prunes the oldest past backup_count",
		backups.size() == 2 and backups[1].get_file().begins_with("0002."), true) and all_passed
	ProjectSettings.set_setting("eventsheets/editor/backup_count", 0)
	all_passed = _check("backup_count 0 disables the ring",
		EventSheetBackups.backup_sheet(sheet_path), "") and all_passed
	ProjectSettings.set_setting("eventsheets/editor/backup_count", null)

	# ── Save hook + restore-into-editor ───────────────────────────────────────────
	ProjectSettings.set_setting("eventsheets/editor/compile_on_save", false)
	var editor: EventSheetEditor = EventSheetEditor.new()
	var hook_sheet: EventSheetResource = EventSheetResource.new()
	hook_sheet.host_class = "Node"
	hook_sheet.variables = {"hp": {"type": "int", "default": 1, "exported": true}}
	editor.setup(hook_sheet)
	editor.set_undo_redo_manager(NoopUndoManager.new())
	editor._current_sheet_path = "user://backup_hook.tres"
	if FileAccess.file_exists("user://backup_hook.tres"):
		DirAccess.remove_absolute("user://backup_hook.tres")
	for stale: String in EventSheetBackups.list_backups("user://backup_hook.tres"):
		DirAccess.remove_absolute(stale)
	editor._on_save_requested()
	all_passed = _check("the first save has no pre-save bytes to ring",
		EventSheetBackups.list_backups("user://backup_hook.tres").is_empty(), true) and all_passed
	hook_sheet.variables = {"hp": {"type": "int", "default": 2, "exported": true}}
	editor._on_save_requested()
	all_passed = _check("the second save backs up the previous state",
		EventSheetBackups.list_backups("user://backup_hook.tres").size(), 1) and all_passed
	hook_sheet.variables = {"hp": {"type": "int", "default": 3, "exported": true}}
	editor._restore_backup_path(EventSheetBackups.list_backups("user://backup_hook.tres")[0])
	all_passed = _check("restore brings the backed-up model into the editor",
		int((editor._current_sheet.variables.get("hp", {}) as Dictionary).get("default", -1)), 1) and all_passed
	all_passed = _check("a restore is an unsaved change", editor._dirty, true) and all_passed
	ProjectSettings.set_setting("eventsheets/editor/compile_on_save", null)

	# ── Project templates ─────────────────────────────────────────────────────────
	ProjectSettings.set_setting("eventsheets/project/templates_dir", "user://tpl_dir")
	DirAccess.make_dir_recursive_absolute("user://tpl_dir")
	var template: EventSheetResource = EventSheetResource.new()
	template.host_class = "CharacterBody2D"
	template.custom_class_name = "BossFight"
	template.variables = {"phase": {"type": "int", "default": 1, "exported": true}}
	ResourceSaver.save(template, "user://tpl_dir/boss_fight.tres")
	all_passed = _check("templates dir is scanned",
		EventSheetTemplates.list_templates(), PackedStringArray(["user://tpl_dir/boss_fight.tres"])) and all_passed
	all_passed = _check("template paths are recognized",
		EventSheetTemplates.is_template_path("user://tpl_dir/boss_fight.tres")
		and not EventSheetTemplates.is_template_path("res://demo/sheets/player.tres"), true) and all_passed
	all_passed = _check("doctor/vocab filter drops only templates",
		EventSheetTemplates.non_template_sheets(PackedStringArray(["user://tpl_dir/boss_fight.tres", "res://demo/sheets/player.tres"])),
		PackedStringArray(["res://demo/sheets/player.tres"])) and all_passed
	var copy: EventSheetResource = EventSheetTemplates.load_copy("user://tpl_dir/boss_fight.tres")
	all_passed = _check("template copies are deep and path-less",
		copy.resource_path.is_empty() and copy.custom_class_name == "BossFight"
		and int((copy.variables.get("phase", {}) as Dictionary).get("default", -1)) == 1, true) and all_passed

	# New… menu: 11 built-in starters + 5 intent section separators (the creation-time
	# "what are you making?" ask) + the project-templates separator + 1 project template
	# = 18 entries; adopting id 100 swaps
	# the template copy in as an unsaved sheet.
	editor._starter._build_template_menu_items()
	all_passed = _check("template menu lists built-ins and the project template",
		editor._starter._template_menu.item_count == 18
		and editor._starter._project_template_paths == PackedStringArray(["user://tpl_dir/boss_fight.tres"]), true) and all_passed
	editor._starter._new_sheet_from_template(100)
	all_passed = _check("adopting a project template starts an unsaved copy",
		editor._current_sheet.custom_class_name == "BossFight"
		and editor._current_sheet_path.is_empty() and editor._dirty, true) and all_passed
	all_passed = _check("the adopted copy never aliases the template",
		editor._current_sheet != template
		and editor._current_sheet.variables is Dictionary, true) and all_passed

	# Save as Template: writes into the dir, never overwrites (suffix instead).
	editor._save_as_project_template()
	editor._save_as_project_template()
	all_passed = _check("save-as-template suffixes instead of overwriting",
		FileAccess.file_exists("user://tpl_dir/boss_fight-2.tres")
		and FileAccess.file_exists("user://tpl_dir/boss_fight-3.tres"), true) and all_passed

	ProjectSettings.set_setting("eventsheets/project/templates_dir", null)
	editor.free()
	for cleanup_path: String in ["user://backup_fixture.tres", "user://backup_hook.tres",
			"user://tpl_dir/boss_fight.tres", "user://tpl_dir/boss_fight-2.tres", "user://tpl_dir/boss_fight-3.tres"]:
		if FileAccess.file_exists(cleanup_path):
			DirAccess.remove_absolute(cleanup_path)
	return all_passed

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] sheet_backups_templates_test: %s" % label)
		return true
	print("[FAIL] sheet_backups_templates_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
