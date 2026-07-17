@tool
class_name EventSheetExportPack
extends RefCounted
# Export as Addon Pack (coverage Phase C).
#
# Exports the current behavior sheet as a reusable addon pack: writes the pack directory
# (the .tres + its compiled .gd) into eventsheet_addons/<class_snake>/ - the same layout the
# bundled packs use, where the zero-config scanner publishes its ACEs project-wide - plus a
# generated README, and bundles any included sheets when the project policy says so.
#
# Extracted from event_sheet_dock.gd to keep that file maintainable.
#
# WHAT STAYS ON THE DOCK (reached here through `_dock`):
#   • the active-tab state (`_current_sheet`),
#   • the status funnel (`_set_status`),
#   • `_generate_pack_readme` - a thin dock delegate to EventSheetAuthorLoop.generate_pack_readme
#     that a test (singleton_sheets_test) also calls by name, so it stays on the dock,
#   • `is_inside_tree()` - the dock's own tree membership (this helper is a detached RefCounted).
# Globals (EventSheetIdentifierRules, DirAccess, EventSheetResource, ResourceSaver, SheetCompiler,
# FileAccess, ResourceLoader, Engine, EditorInterface) are unchanged.
#
# The dock keeps a thin one-line delegate for `_export_addon_pack` (original name + signature) -
# the menu_bar Sheet menu (id 6), the command palette, and the phase-c / addon-composition tests
# reach it by that name, so they resolve unchanged.

var _dock: Control = null


func init(dock: Control) -> void:
	_dock = dock


## One-click addon publishing: writes the current behavior sheet (+ compiled script) into
## eventsheet_addons/<class_snake>/ where the zero-config scanner publishes its ACEs
## project-wide - the same layout the bundled packs use. base_dir_override is for tests.
func _export_addon_pack(base_dir_override: String = "") -> void:
	if _dock._current_sheet == null:
		return
	if not _dock._current_sheet.behavior_mode or _dock._current_sheet.custom_class_name.strip_edges().is_empty():
		_dock._set_status("Addon packs are behavior sheets - enable behavior mode and set a class name first (Sheet Type).", true)
		return
	var class_name_text: String = _dock._current_sheet.custom_class_name.strip_edges()
	if not EventSheetIdentifierRules.is_valid(class_name_text):
		_dock._set_status("\"%s\" can't be a class name (letters/digits/underscores, not a keyword)." % class_name_text, true)
		return
	var folder_name: String = class_name_text.to_snake_case()
	var base_dir: String = base_dir_override if not base_dir_override.is_empty() else "res://eventsheet_addons/%s" % folder_name
	var base_path: String = "%s/%s" % [base_dir, folder_name]
	DirAccess.make_dir_recursive_absolute(base_dir)
	var pack_sheet: EventSheetResource = _dock._current_sheet.duplicate(true)
	# The SAME pipeline the bundled packs are built with (EventSheets.publish_pack): pack-local
	# icon auto-detect, the four byte-gated de-coding lifts (raw code becomes rows wherever it
	# round-trips), deterministic row uids, and a banner-less .gd that IS the pack - a user's
	# exported addon reads exactly like a shipped one when reopened as a sheet.
	var compile_result: Dictionary = EventSheets.publish_pack(pack_sheet, base_path)
	if not bool(compile_result.get("success", false)):
		_dock._set_status("Export failed: the sheet doesn't compile (%s)." % str(compile_result.get("errors")), true)
		return
	# The .tres companion saves the PUBLISHED sheet (post-pipeline), so recompiling it
	# reproduces the exported .gd byte-for-byte - the same no-drift rule the bundled packs obey.
	var save_error: Error = ResourceSaver.save(pack_sheet, base_path + ".tres")
	if save_error != OK:
		_dock._set_status("Export failed: couldn't save %s.tres (error %d)." % [base_path, save_error], true)
		return
	pack_sheet.take_over_path(base_path + ".tres")
	# Auto-docs: shared packs are documented by default.
	var readme_file: FileAccess = FileAccess.open("%s/README.md" % base_dir, FileAccess.WRITE)
	if readme_file != null:
		readme_file.store_string(_dock._generate_pack_readme(pack_sheet))
		readme_file.close()
	# Lane A composition: packs travel complete - bundle included sheets unless the
	# project policy says reference-only.
	var bundled_count: int = 0
	if str(SheetCompiler._addon_policy("export_bundling", "bundle")) == "bundle":
		for include_path: String in pack_sheet.includes:
			if ResourceLoader.exists(include_path):
				var bundle_target: String = "%s/%s" % [base_dir, include_path.get_file()]
				if bundle_target != include_path and DirAccess.copy_absolute(include_path, bundle_target) == OK:
					bundled_count += 1
	if Engine.is_editor_hint() and _dock.is_inside_tree():
		EditorInterface.get_resource_filesystem().scan()
	var bundle_note: String = " (+%d bundled include(s))" % bundled_count if bundled_count > 0 else ""
	_dock._set_status("Exported addon pack to %s (.tres + .gd)%s - its ACEs are now published project-wide." % [base_dir, bundle_note])
