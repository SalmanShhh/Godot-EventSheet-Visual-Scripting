# Godot EventSheets - Tier-3 usability: the save-time backup ring (user:// ring,
# restore-into-editor as an unsaved change) and project-local templates (drop a .tres
# in the templates dir → New… menu; blueprints skipped by doctor + vocabulary doc).
@tool
class_name SheetBackupsTemplatesTest
extends RefCounted


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
	# Unchanged bytes don't churn the ring: re-backing-up an identical file returns the
	# newest backup instead of writing a duplicate (GDScript-backed sheets back up on
	# EVERY save now, most of which are byte-identical no-ops).
	all_passed = _check("an identical re-backup dedups to the newest entry",
		EventSheetBackups.backup_sheet(sheet_path), first_backup) and all_passed
	all_passed = _check("the dedup did not grow the ring",
		EventSheetBackups.list_backups(sheet_path).size(), 1) and all_passed
	sheet.variables = {"hp": {"type": "int", "default": 2, "exported": true}}
	ResourceSaver.save(sheet, sheet_path)
	EventSheetBackups.backup_sheet(sheet_path)
	var backups: PackedStringArray = EventSheetBackups.list_backups(sheet_path)
	all_passed = _check("backups list newest first",
		backups.size() == 2 and backups[0].get_file().begins_with("0002."), true) and all_passed
	ProjectSettings.set_setting("eventsheets/editor/backup_count", 2)
	sheet.variables = {"hp": {"type": "int", "default": 3, "exported": true}}
	ResourceSaver.save(sheet, sheet_path)
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

	# ── .gd sheets ride the same ring (review fix) ────────────────────────────────
	# GDScript-backed saves used to skip the backup ring entirely (and list_backups
	# filtered to .tres, so even a hand-made .gd backup was invisible to Restore).
	var gd_path: String = "user://backup_ring_source.gd"
	for stale_gd: String in EventSheetBackups.list_backups(gd_path):
		DirAccess.remove_absolute(stale_gd)
	var gd_v1: String = "extends Node\n"
	var gd_file: FileAccess = FileAccess.open(gd_path, FileAccess.WRITE)
	gd_file.store_string(gd_v1)
	gd_file.close()
	var gd_backup: String = EventSheetBackups.backup_sheet(gd_path)
	all_passed = _check("a .gd backup lands in the ring and is LISTED",
		EventSheetBackups.list_backups(gd_path).size(), 1) and all_passed
	all_passed = _check("the .gd backup holds the pre-save source",
		FileAccess.get_file_as_string(gd_backup), gd_v1) and all_passed
	# Restore a .gd backup INTO a backed editor: re-imports the source, keeps the open
	# sheet's source path + read-only state, and stays an unsaved change.
	var gd_v2_file: FileAccess = FileAccess.open(gd_path, FileAccess.WRITE)
	gd_v2_file.store_string("extends Node2D\n")
	gd_v2_file.close()
	var gd_editor: EventSheetEditor = EventSheetEditor.new()
	var backed: EventSheetResource = GDScriptImporter.new().import_external(gd_path)
	backed.read_only = false
	gd_editor.setup(backed)
	gd_editor.set_undo_redo_manager(NoopUndoManager.new())
	gd_editor._current_sheet_path = gd_path
	gd_editor._restore_backup_path(gd_backup)
	all_passed = _check("restoring a .gd backup brings the OLD source's model back",
		gd_editor._current_sheet.host_class, "Node") and all_passed
	all_passed = _check("the restored sheet keeps its source path",
		gd_editor._current_sheet.external_source_path, gd_path) and all_passed
	all_passed = _check("a .gd restore is an unsaved change", gd_editor._dirty, true) and all_passed
	gd_editor.free()

	# ── Atomic compile writes ─────────────────────────────────────────────────────
	# _write_output_if_changed goes through a temp file + rename now: overwriting an
	# EXISTING .gd must land the new content whole and leave no temp file behind.
	var atomic_path: String = "user://atomic_write_probe.gd"
	var atomic_sheet: EventSheetResource = EventSheetResource.new()
	atomic_sheet.host_class = "Node"
	SheetCompiler.compile(atomic_sheet, atomic_path)
	atomic_sheet.host_class = "Node2D"
	SheetCompiler.compile(atomic_sheet, atomic_path)
	all_passed = _check("an atomic overwrite lands the NEW content",
		FileAccess.get_file_as_string(atomic_path).contains("extends Node2D"), true) and all_passed
	all_passed = _check("no temp file is left behind",
		FileAccess.file_exists(atomic_path + ".efwrite.tmp"), false) and all_passed

	# ── Project templates ─────────────────────────────────────────────────────────
	ProjectSettings.set_setting("eventsheets/project/templates_dir", "user://tpl_dir")
	DirAccess.make_dir_recursive_absolute("user://tpl_dir")
	# The dir has to START empty. This test SAVES templates into it, and Save as Template suffixes
	# rather than overwrites, so a run that ends between the saves and the cleanup leaves a
	# boss_fight-N.tres behind for every later run to find - and the scan below then reports this
	# machine's history instead of what the test wrote.
	_sweep_template_dir()
	var template: EventSheetResource = EventSheetResource.new()
	template.host_class = "CharacterBody2D"
	template.custom_class_name = "BossFight"
	template.variables = {"phase": {"type": "int", "default": 1, "exported": true}}
	ResourceSaver.save(template, "user://tpl_dir/boss_fight.tres")
	all_passed = _check("templates dir is scanned",
		EventSheetTemplates.list_templates(), PackedStringArray(["user://tpl_dir/boss_fight.tres"])) and all_passed
	all_passed = _check("template paths are recognized",
		EventSheetTemplates.is_template_path("user://tpl_dir/boss_fight.tres")
		and not EventSheetTemplates.is_template_path("res://tests/fixtures/compiler_golden_sheet.tres"), true) and all_passed
	all_passed = _check("doctor/vocab filter drops only templates",
		EventSheetTemplates.non_template_sheets(PackedStringArray(["user://tpl_dir/boss_fight.tres", "res://tests/fixtures/compiler_golden_sheet.tres"])),
		PackedStringArray(["res://tests/fixtures/compiler_golden_sheet.tres"])) and all_passed
	var copy: EventSheetResource = EventSheetTemplates.load_copy("user://tpl_dir/boss_fight.tres")
	all_passed = _check("template copies are deep and path-less",
		copy.resource_path.is_empty() and copy.custom_class_name == "BossFight"
		and int((copy.variables.get("phase", {}) as Dictionary).get("default", -1)) == 1, true) and all_passed

	# New… menu, recomputed at the batch-13 merge as base + every parcel's delta. Base 23;
	# Folded four flat Editor-Tools items into one submenu (-4 +1); kits 1 added four
	# game-shape starters + their section separator (+5); kits 2 added Boomer Arsenal and
	# Game Options (+2); the Level Stats Screen starter joined them (+1); the
	# Keycard Door starter followed (+1), and the Skill Tree Screen starter beside it (+1).
	# 23 - 4 + 1 + 5 + 2 + 1 + 1 + 1 = 30.
	editor._starter._build_template_menu_items()
	all_passed = _check("template menu lists built-ins and the project template",
		editor._starter._template_menu.item_count == 23 - 4 + 1 + 5 + 2 + 1 + 1 + 1
		and editor._starter._project_template_paths == PackedStringArray(["user://tpl_dir/boss_fight.tres"]), true) and all_passed
	# The tool starters are VALUES rather than a count, so a renamed entry names itself. They now live
	# in the submenu, which is where the "New Sheet ▸ Editor tool" list lives.
	var tool_entries: PackedStringArray = PackedStringArray()
	var shapes_menu: PopupMenu = editor._starter._build_editor_tool_menu()
	for menu_index: int in range(shapes_menu.item_count):
		if shapes_menu.get_item_id(menu_index) in [10, 12, 13, 14]:
			tool_entries.append(shapes_menu.get_item_text(menu_index))
	all_passed = _check("the Editor Tool submenu still leads with the four shipped shapes",
		"|".join(tool_entries),
		"One-click chore - run it yourself, from the sheet's bar|Editor plugin - the editor switches it on and off|Importer add-on - runs when files are imported|Export hook - runs when the project is exported") and all_passed
	all_passed = _check("and offers all fifteen", shapes_menu.item_count, 15) and all_passed
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
			"user://backup_ring_source.gd", "user://atomic_write_probe.gd"]:
		if FileAccess.file_exists(cleanup_path):
			DirAccess.remove_absolute(cleanup_path)
	_sweep_template_dir()
	return all_passed


## Every file in the temporary templates dir, gone. Run before the templates are written and again
## after, so neither this run nor the next one scans a leftover - naming the files to delete could
## only ever list the ones a finished run made, and the stragglers come from the runs that did not
## finish.
static func _sweep_template_dir() -> void:
	for file_name: String in DirAccess.get_files_at("user://tpl_dir"):
		DirAccess.remove_absolute("user://tpl_dir/%s" % file_name)


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] sheet_backups_templates_test: %s" % label)
		return true
	print("[FAIL] sheet_backups_templates_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
