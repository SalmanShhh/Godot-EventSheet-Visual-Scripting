@tool
class_name EventSheetSheetIO
extends RefCounted
# The sheet FILE-IO subsystem: opening a sheet from disk and every write-back path (Save,
# Save As, Export Generated GDScript, Save-as-.gd). Extracted from event_sheet_dock.gd to keep
# that file maintainable. The tab cluster, mutation funnel, and UI refreshers STAY on the dock -
# this helper reaches them (and add_child, EVENT_SHEET_FILTERS) through the `_dock` back-reference,
# the same pattern as the other dock/ helpers. The dock keeps thin one-line delegates with the
# original names + signatures so external callers (plugin.gd, the other dock/ helpers, menu_bar,
# command_palette) and the tests don't change. Globals (SheetCompiler, EventSheetBackups,
# ResourceSaver/Loader, FileAccess, GDScriptImporter, EventSheetLiftReport) are untouched.
#
# ORDER NOTE: _on_save_requested's compile-on-save sequence is load-bearing - save →
# (compile-on-save fail → _run_diagnostics → status → _refresh_title_strip → return) else
# _run_diagnostics → _refresh_title_strip → status. Preserved verbatim from the dock.

var _dock: Control = null


func init(dock: Control) -> void:
	_dock = dock


func _load_sheet_from_path(path: String) -> void:
	var resolved_path: String = path.strip_edges()
	if resolved_path.is_empty():
		_dock._set_status("Open failed: no file selected.", true)
		return
	# GDScript-backed sheets: any .gd opens losslessly (lifted rows + verbatim blocks); the
	# file stays the single source of truth and Save compiles back to it.
	if resolved_path.get_extension() == "gd":
		var imported: EventSheetResource = GDScriptImporter.new().import_external(resolved_path)
		if imported == null:
			_dock._set_status("Open failed: could not read %s." % resolved_path.get_file(), true)
			return
		# Open a .gd as a SAFE read-only PREVIEW by default - a casual look can never
		# overwrite the hand-written script. "Edit Events" in the banner unlocks editing.
		imported.read_only = true
		_dock.setup(imported)
		_dock._current_sheet_path = resolved_path
		_dock._dirty = false
		_dock._refresh_title_strip()
		_dock._clear_undo_history()
		_dock._external_mtime = FileAccess.get_modified_time(resolved_path)
		# The lift report explains the structure/code boundary per block - the teaching
		# surface for what GDScript maps to which events (the banner recomputes its own copy
		# from the active sheet, so tab switches always show the right counts).
		_dock._refresh_preview_banner()
		_dock._set_status("Opened %s - viewing it as a sheet. Just start editing to change it here, or \"Open in Godot Script Editor\" for the code. (%s)" % [resolved_path.get_file(), EventSheetLiftReport.summary(EventSheetLiftReport.for_sheet(imported))])
		return
	var loaded: Resource = ResourceLoader.load(resolved_path)
	if loaded is EventSheetResource:
		_dock.setup(loaded as EventSheetResource)
		_dock._current_sheet_path = resolved_path
		_dock._dirty = false
		_dock._refresh_title_strip()
		_dock._clear_undo_history()
		return
	_dock._set_status("Open failed: %s is not an EventSheetResource." % resolved_path.get_file(), true)


## Compiles a GDScript-backed sheet to its .gd source. Returns whether the compile succeeded (and
## sets a failure status when it does not). Shared by Save and "Open in Godot" so the latter can
## refuse to open a stale source when the sheet doesn't currently compile.
func _save_backed_sheet() -> bool:
	var compile_result: Dictionary = SheetCompiler.compile(_dock._current_sheet, _dock._current_sheet.external_source_path)
	if not bool(compile_result.get("success", false)):
		_dock._set_status("This sheet doesn't compile yet - fix the error, then save again. (%s)" % ", ".join(PackedStringArray(compile_result.get("errors", []))), true)
		return false
	_dock._dirty = false
	_dock._external_mtime = FileAccess.get_modified_time(_dock._current_sheet.external_source_path)
	_dock._refresh_title_strip()
	return true


func _on_save_requested() -> void:
	if _dock._current_sheet == null:
		_dock._set_status("Nothing to save.", true)
		return
	# Read-only preview never writes back over the source file. The user opts in with
	# "Edit Events" (then this becomes a normal GDScript-backed save), or forks via Save As.
	if _dock._current_sheet.read_only:
		var source_name: String = _dock._current_sheet.external_source_path.get_file()
		_dock._set_status("You're viewing %s - click \"Edit Events\" in the banner to edit and save it, or use Save As… to keep a separate copy." % source_name, true)
		return
	# GDScript-backed sheets save by compiling back to their .gd source (order-preserving;
	# an untouched sheet reproduces the file byte-identically).
	if not _dock._current_sheet.external_source_path.is_empty():
		if _save_backed_sheet():
			_dock._set_status("Saved GDScript: %s" % _dock._current_sheet.external_source_path.get_file())
		return
	if _dock._current_sheet_path.is_empty() and _dock._current_sheet.resource_path.is_empty():
		_on_save_as_requested()
		return
	var save_path: String = _dock._current_sheet_path if not _dock._current_sheet_path.is_empty() else _dock._current_sheet.resource_path
	# Backup ring: the file's pre-save bytes go to user://eventsheet_backups first
	# (eventsheets/editor/backup_count, 0 disables) - a bad save costs one save, not
	# the sheet. Restore lives in Tools → Sheet Backups….
	EventSheetBackups.backup_sheet(save_path)
	var err: Error = ResourceSaver.save(_dock._current_sheet, save_path)
	if err == OK:
		_dock._current_sheet.take_over_path(save_path)
		_dock._current_sheet_path = save_path
		_dock._dirty = false
		# Save As can change the path - keep the saved session pointing at it
		# (sweep catch: sessions otherwise lag until the next tab switch).
		_dock._persist_session()
		# Compile-on-save (default ON; eventsheets/editor/compile_on_save to disable):
		# play-testing can never hit a stale generated script. Export integrity still
		# covers exports; this covers F5.
		var compile_on_save: bool = bool(ProjectSettings.get_setting("eventsheets/editor/compile_on_save", true))
		if compile_on_save:
			var auto_result: Dictionary = SheetCompiler.compile(_dock._current_sheet, "")
			if not bool(auto_result.get("success", false)):
				_dock._run_diagnostics()
				# Friendly + actionable first (diagnostics just flagged + jumped to the bad row), with
				# the raw compiler detail kept in parentheses for anyone who wants it.
				_dock._set_status("Saved, but it won't run yet - a row has an error. Jumped to the first; hover the red row for the fix. (%s)" % ", ".join(PackedStringArray(auto_result.get("errors", []))), true)
				_dock._refresh_title_strip()
				return
		# Row-level lint: flag any bad ƒx expression / GDScript block ON its row + jump to the
		# first, even when the structural compile passed (the common code-free error case).
		var issue_count: int = _dock._run_diagnostics()
		_dock._refresh_title_strip()
		if issue_count > 0:
			_dock._set_status("Saved: %s - %d row(s) need attention (jumped to the first)." % [save_path.get_file(), issue_count], true)
		else:
			_dock._set_status("Saved: %s" % save_path.get_file())
	else:
		_dock._set_status("Save failed (error %d)." % err, true)


func _on_save_as_requested() -> void:
	if _dock._current_sheet == null:
		_dock._set_status("Nothing to save.", true)
		return
	var dialog: FileDialog = FileDialog.new()
	dialog.title = "Save EventSheet As"
	dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	dialog.access = FileDialog.ACCESS_RESOURCES
	dialog.filters = PackedStringArray(_dock.EVENT_SHEET_FILTERS)
	dialog.current_path = _build_initial_save_path()
	dialog.file_selected.connect(func(path: String) -> void:
		_save_sheet_to_path(path)
		dialog.call_deferred("queue_free")
	)
	dialog.canceled.connect(func() -> void: dialog.queue_free())
	_dock.add_child(dialog)
	dialog.popup_centered(Vector2i(860, 580))


func _export_gdscript_requested() -> void:
	if _dock._current_sheet == null:
		_dock._set_status("Open or create a sheet first.", true)
		return
	var dialog: FileDialog = FileDialog.new()
	dialog.title = "Export Generated GDScript"
	dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	dialog.access = FileDialog.ACCESS_RESOURCES
	dialog.filters = PackedStringArray(["*.gd ; GDScript"])
	dialog.current_path = "res://%s.gd" % _exported_script_basename()
	dialog.file_selected.connect(func(path: String) -> void:
		_write_exported_gdscript(path)
		dialog.call_deferred("queue_free")
	)
	dialog.canceled.connect(func() -> void: dialog.queue_free())
	_dock.add_child(dialog)
	dialog.popup_centered(Vector2i(860, 580))


func _exported_script_basename() -> String:
	if _dock._current_sheet != null and not _dock._current_sheet.custom_class_name.strip_edges().is_empty():
		return _dock._current_sheet.custom_class_name.to_snake_case()
	if not _dock._current_sheet_path.is_empty():
		return _dock._current_sheet_path.get_file().get_basename()
	return "event_sheet"


func _write_exported_gdscript(path: String) -> void:
	var target: String = path if path.get_extension() == "gd" else path + ".gd"
	var result: Dictionary = SheetCompiler.compile(_dock._current_sheet, target)
	var errors: Array = result.get("errors", [])
	if not errors.is_empty():
		_dock._set_status("Export failed: %s" % str(errors[0]), true)
		return
	_dock._set_status("Exported standalone GDScript to %s - no plugin dependency." % target.get_file())


func _save_sheet_to_path(path: String) -> void:
	if _dock._current_sheet == null:
		_dock._set_status("Nothing to save.", true)
		return
	var resolved_path: String = _normalize_sheet_save_path(path)
	# Saving as .gd makes the sheet a plain GDScript file (no .tres) - the default format.
	if resolved_path.get_extension().to_lower() == "gd":
		_save_sheet_as_gdscript(resolved_path)
		return
	# Save As .tres converts a GDScript-backed sheet into a normal sheet: the .gd stops
	# being the source of truth (it is left untouched on disk).
	var was_backed: bool = not _dock._current_sheet.external_source_path.is_empty()
	if was_backed:
		_dock._current_sheet.external_source_path = ""
	var err: Error = ResourceSaver.save(_dock._current_sheet, resolved_path)
	if err == OK:
		_dock._current_sheet.take_over_path(resolved_path)
		_dock._current_sheet_path = resolved_path
		_dock._dirty = false
		_dock._refresh_title_strip()
		if was_backed:
			# Don't silently change the format under an expert: name the consequence.
			_dock._set_status("Saved as %s - now a .tres sheet; the .gd is no longer the source (left untouched on disk)." % resolved_path.get_file())
		else:
			_dock._set_status("Saved as: %s" % resolved_path.get_file())
	else:
		_dock._set_status("Save failed (error %d)." % err, true)


## Saves the sheet as a plain .gd (no .tres): compiles it to that path, then re-opens the .gd as the
## GDScript-backed source of truth, so the file IS the sheet and future edits round-trip through it.
## SheetCompiler.compile already picks the right path - full header for a structured sheet, order-
## preserving for an already-backed one. The reopened sheet is editable (not the read-only preview a
## casual Open gives), since the user just authored it. Returns whether it saved.
func _save_sheet_as_gdscript(path: String) -> bool:
	# omit_generated_banner: this .gd is the user's hand-editable source of truth, NOT a regenerated
	# companion - it must not carry the "DO NOT EDIT / regenerated on every compile" banner.
	var compile_result: Dictionary = SheetCompiler.compile(_dock._current_sheet, path, true)
	if not bool(compile_result.get("success", false)):
		_dock._set_status("Couldn't save as GDScript: %s" % ", ".join(PackedStringArray(compile_result.get("errors", []))), true)
		return false
	var backed: EventSheetResource = GDScriptImporter.new().import_external(path)
	if backed == null:
		_dock._set_status("Saved %s, but couldn't reopen it as a sheet." % path.get_file(), true)
		return false
	backed.read_only = false  # the user just authored it - open it editable, not as a preview
	# Replace the ACTIVE tab's sheet in place. Calling setup() would append a SECOND tab (its dedup
	# matches by object identity, and `backed` is a freshly-imported resource), duplicating the sheet.
	if _dock._active_tab_index >= 0 and _dock._active_tab_index < _dock._open_tabs.size():
		_dock._open_tabs[_dock._active_tab_index] = {"sheet": backed, "path": path, "dirty": false}
		_dock._activate_tab(_dock._active_tab_index)  # reloads the viewport + sets _current_sheet/_path/_dirty + clears undo
	else:
		_dock.setup(backed)
		_dock._current_sheet_path = path
		_dock._dirty = false
	_dock._external_mtime = FileAccess.get_modified_time(path)
	_dock._refresh_preview_banner()
	_dock._set_status("Saved as GDScript: %s - the .gd is now the source of truth." % path.get_file())
	return true


func _suggest_sheet_filename() -> String:
	var candidate_path: String = _dock._current_sheet_path
	if candidate_path.is_empty() and _dock._current_sheet != null:
		candidate_path = _dock._current_sheet.resource_path
	var file_name: String = candidate_path.get_file()
	if file_name.is_empty():
		file_name = "event_sheet.gd"  # .gd is the default sheet format (no .tres needed)
	elif file_name.get_extension().is_empty():
		file_name += ".gd"
	return file_name


## Returns the preferred directory for open/save dialogs, defaulting to res://.
func _suggest_sheet_directory() -> String:
	var candidate_path: String = _dock._current_sheet_path
	if candidate_path.is_empty() and _dock._current_sheet != null:
		candidate_path = _dock._current_sheet.resource_path
	var directory: String = candidate_path.get_base_dir()
	if directory.is_empty():
		return "res://"
	return directory


## Builds the initial save path shown in the Save As dialog.
func _build_initial_save_path() -> String:
	var candidate_path: String = _dock._current_sheet_path
	if candidate_path.is_empty() and _dock._current_sheet != null:
		candidate_path = _dock._current_sheet.resource_path
	if candidate_path.is_empty():
		return "res://%s" % _suggest_sheet_filename()
	return _normalize_sheet_save_path(candidate_path)


## Ensures save paths always include a valid filename and EventSheet resource extension.
func _normalize_sheet_save_path(path: String) -> String:
	var resolved_path: String = path.strip_edges()
	if resolved_path.is_empty():
		resolved_path = "res://%s" % _suggest_sheet_filename()
	var file_name: String = resolved_path.get_file()
	if file_name.is_empty():
		resolved_path = resolved_path.path_join(_suggest_sheet_filename())
		file_name = resolved_path.get_file()
	var extension: String = file_name.get_extension().to_lower()
	if extension.is_empty():
		resolved_path += ".gd"  # default sheet format
	elif extension not in ["tres", "res", "gd"]:
		resolved_path = "%s.gd" % resolved_path.get_basename()
	return resolved_path
