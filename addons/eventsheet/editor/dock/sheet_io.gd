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
# The in-flight asynchronous .gd open (see _begin_async_gd_open). Null when nothing is opening.
var _open_job: EventSheetOpenJob = null
var _open_job_path: String = ""
## The raw sheet the open painted first - the identity that finds the right tab when the lift lands
## (the same file can legitimately be open in two tabs, so the path alone is not an identity).
var _open_job_raw: EventSheetResource = null
var _open_polling: bool = false
## P4 - the scene being read one script per frame, and whether that read is still running.
var _scene_sheet: EventSheetResource = null
var _scene_polling: bool = false


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
		_begin_async_gd_open(resolved_path)
		return
	# P4 - a .tscn opens as the reading of the WHOLE layout: every script the scene uses, each under
	# its own object bar. Read only for good, and the scene file is never written to.
	if resolved_path.get_extension() == "tscn":
		_open_scene_as_sheet(resolved_path)
		return
	var loaded: Resource = ResourceLoader.load(resolved_path)
	if loaded is EventSheetResource:
		_dock.setup(loaded as EventSheetResource)
		_dock._current_sheet_path = resolved_path
		_dock._dirty = false
		_dock._refresh_title_strip()
		_dock._clear_undo_history()
		EventSheets._notify_lifecycle("opened", {"sheet": loaded, "path": resolved_path})
		return
	_dock._set_status("Open failed: %s is not an EventSheetResource." % resolved_path.get_file(), true)


## Opens a .gd as a sheet WITHOUT freezing the editor.
##
## Opening a .gd is two passes: a fast raw one (rows + verbatim code blocks) and the ACE lift, which
## reverse-matches every function against the vocabulary and then recompiles the whole sheet to
## byte-verify it. The lift is the slow half - measured at 3.9 s for the FPS controller pack and
## 21 s for a 4,600-line dock helper - and running it inline blocked the editor with no repaint at
## all, so a big file looked like a crash.
##
## PAINT FIRST: the raw pass (12-40 ms on those same files) runs here on the main thread and is set
## up immediately, so the file is on screen as rows and code blocks right away. The lift then runs on
## a worker thread behind the "Opening…" strip, and its result replaces the sheet in the SAME tab
## when it lands. "Show as code instead" cancels the lift and keeps exactly what is already showing.
func _begin_async_gd_open(resolved_path: String) -> void:
	# One open at a time: an in-flight lift is abandoned (its result is discarded) so the newer
	# request wins. Cancel makes the worker bail at its next function, so the join is short.
	_abandon_open_job()
	var raw: EventSheetResource = GDScriptImporter.new().import_external(resolved_path, false)
	if raw == null:
		_dock._set_status("Open failed: could not read %s." % resolved_path.get_file(), true)
		return
	# Open a .gd as a SAFE read-only PREVIEW by default - a casual look can never
	# overwrite the hand-written script. "Edit Events" in the banner unlocks editing.
	raw.read_only = true
	_dock.setup(raw)
	_dock._current_sheet_path = resolved_path
	_dock._dirty = false
	_dock._refresh_title_strip()
	_dock._clear_undo_history()
	_dock._external_mtime = FileAccess.get_modified_time(resolved_path)
	_dock._refresh_preview_banner()
	_dock._set_status("Opening %s - showing the code now, working out the events…" % resolved_path.get_file())
	_open_job = EventSheetOpenJob.new()
	_open_job_path = resolved_path
	_open_job_raw = raw
	if not _open_job.start(resolved_path):
		_open_job = null
		_open_job_raw = null
		return
	if _dock._open_progress != null:
		_dock._open_progress.cancel_requested_callback = _cancel_open_job
		_dock._open_progress.show_for(resolved_path)
	# No tree (a headless test driving the dock directly): there are no frames to poll on, so join
	# right here - same result, just synchronous.
	if not _dock.is_inside_tree():
		_collect_open_job()
		return
	_dock.get_tree().process_frame.connect(_poll_open_job)
	_open_polling = true


## P4. Opens a .tscn as the reading of the whole layout, WITHOUT freezing the editor: the scene's bar
## and one object bar per script paint at once, then one script is read per frame behind the progress
## strip. A scene with twenty scripts is twenty short reads rather than one long stall.
##
## The composite is read only for good: it has no single file to compile back to, so Save refuses it
## and the preview banner offers no unlock. Editing happens per script, by opening that file.
func _open_scene_as_sheet(resolved_path: String) -> void:
	_abandon_open_job()
	_stop_scene_polling()
	var sheet: EventSheetResource = EventSheetSceneSheet.build_shell(resolved_path)
	if sheet == null:
		_dock._set_status("Open failed: could not read %s." % resolved_path.get_file(), true)
		return
	_scene_sheet = sheet
	_dock.setup(sheet)
	_dock._current_sheet_path = resolved_path
	_dock._dirty = false
	_dock._refresh_title_strip()
	_dock._clear_undo_history()
	_dock._refresh_preview_banner()
	_dock._set_status("Opening %s - reading every script the scene uses…" % resolved_path.get_file())
	if not _dock.is_inside_tree():
		# No tree (a headless test driving the dock directly): there are no frames to spread over.
		while EventSheetSceneSheet.load_next_member(sheet):
			pass
		_dock._viewport.set_sheet(sheet)
		return
	if _dock._open_progress != null:
		_dock._open_progress.cancel_requested_callback = _stop_scene_polling
		_dock._open_progress.show_for(resolved_path)
	_dock.get_tree().process_frame.connect(_poll_scene_open)
	_scene_polling = true


## One script per frame, with the strip counting them down.
func _poll_scene_open() -> void:
	if _scene_sheet == null:
		_stop_scene_polling()
		return
	var more: bool = EventSheetSceneSheet.load_next_member(_scene_sheet)
	# The rows are rebuilt as each script lands, so the sheet fills in front of the reader.
	if _dock._current_sheet == _scene_sheet:
		_dock._viewport.set_sheet(_scene_sheet)
	var pending: int = EventSheetSceneSheet.pending_members(_scene_sheet)
	if _dock._open_progress != null:
		var total: int = EventSheetSceneSheet.members_of(_scene_sheet).size()
		_dock._open_progress.update("Reading %s - script %d of %d" % [
			EventSheetSceneSheet.scene_path_of(_scene_sheet).get_file(), total - pending, total],
			float(total - pending) / float(maxi(total, 1)))
	if more or pending > 0:
		return
	_stop_scene_polling()
	_dock._set_status("Opened %s - reading only. Double-click an object bar to edit that script." %
		EventSheetSceneSheet.scene_path_of(_scene_sheet).get_file())


func _stop_scene_polling() -> void:
	if not _scene_polling:
		return
	_scene_polling = false
	if _dock.is_inside_tree() and _dock.get_tree().process_frame.is_connected(_poll_scene_open):
		_dock.get_tree().process_frame.disconnect(_poll_scene_open)
	if _dock._open_progress != null:
		_dock._open_progress.hide_strip()


## Per-frame poll: republish the worker's counters, and collect the sheet once it lands.
func _poll_open_job() -> void:
	if _open_job == null:
		_stop_open_polling()
		return
	if _dock._open_progress != null:
		_dock._open_progress.update(_open_job.status_text(), _open_job.progress_ratio())
	if _open_job.is_done():
		_collect_open_job()


func _cancel_open_job() -> void:
	if _open_job != null:
		_open_job.cancel()


## Drops an in-flight open without showing its result (a newer open superseded it).
func _abandon_open_job() -> void:
	if _open_job == null:
		return
	_open_job.cancel()
	_open_job.finish()
	_open_job = null
	_open_job_path = ""
	_open_job_raw = null
	_stop_open_polling()
	if _dock._open_progress != null:
		_dock._open_progress.hide_strip()


func _stop_open_polling() -> void:
	if not _open_polling:
		return
	_open_polling = false
	if _dock.is_inside_tree() and _dock.get_tree().process_frame.is_connected(_poll_open_job):
		_dock.get_tree().process_frame.disconnect(_poll_open_job)


## Joins the worker and shows what it produced.
func _collect_open_job() -> void:
	var job: EventSheetOpenJob = _open_job
	var job_path: String = _open_job_path
	var job_raw: EventSheetResource = _open_job_raw
	_open_job = null
	_open_job_path = ""
	_open_job_raw = null
	_stop_open_polling()
	if _dock._open_progress != null:
		_dock._open_progress.hide_strip()
	if job == null:
		return
	var lifted: EventSheetResource = job.finish()
	if lifted == null:
		# The strip is already down - never leave it up on failure.
		_dock._set_status("Open failed: could not read %s." % job_path.get_file(), true)
		return
	_finish_gd_open(lifted, job_raw, job_path, job.was_canceled())


## Swaps the finished sheet into the tab the raw pass opened and reports what happened. The tab is
## found by the RAW SHEET's identity: the user is free to switch (or close) tabs while a lift runs,
## and the same file can legitimately be open twice, so the result has to land in the exact tab it
## came from rather than in whichever one happens to be active.
func _finish_gd_open(sheet: EventSheetResource, raw_sheet: EventSheetResource, resolved_path: String, was_canceled: bool) -> void:
	var tab_index: int = -1
	for index: int in range(_dock._open_tabs.size()):
		if _dock._open_tabs[index].get("sheet") == raw_sheet:
			tab_index = index
			break
	if tab_index < 0:
		# The tab was closed while the lift ran - nothing to update, and nothing to say.
		return
	# Edited while the lift ran (the user unlocked it with "Edit Events" and changed something):
	# their rows win. Swapping in the lifted sheet would silently throw the edit away.
	var is_active: bool = tab_index == _dock._active_tab_index
	if bool(_dock._open_tabs[tab_index].get("dirty", false)) or (is_active and _dock._dirty):
		_dock._set_status("Opened %s - you started editing while it loaded, so it stays as you left it (reopen the file to read it as events)." % resolved_path.get_file())
		return
	# "Edit Events" during the open is a real answer to "is this a preview?" - carry it across
	# rather than snapping the sheet back to read-only under the user.
	sheet.read_only = raw_sheet.read_only if raw_sheet != null else true
	sheet.external_source_path = resolved_path
	_dock._open_tabs[tab_index] = {"sheet": sheet, "path": resolved_path, "dirty": false}
	if is_active:
		# Re-activating the tab reloads the viewport and re-points _current_sheet/_path/_dirty +
		# clears undo. setup() cannot be used: it dedups by object identity, and this is a fresh
		# resource, so it would append a SECOND tab for the same file.
		_dock._activate_tab(tab_index)
		_dock._external_mtime = FileAccess.get_modified_time(resolved_path)
		# The lift report explains the structure/code boundary per block - the teaching
		# surface for what GDScript maps to which events (the banner recomputes its own copy
		# from the active sheet, so tab switches always show the right counts).
		_dock._refresh_preview_banner()
		_flag_parse_error_rows(sheet, resolved_path)
	EventSheets._notify_lifecycle("opened", {"sheet": sheet, "path": resolved_path})
	if was_canceled:
		_dock._set_status("Opened %s as code - stopped working out the events, so every function is shown as a script block. Reopen the file to try again." % resolved_path.get_file())
		return
	_dock._set_status("Opened %s - viewing it as a sheet. Just start editing to change it here, or \"Open in Godot Script Editor\" for the code. (%s)" % [resolved_path.get_file(), EventSheetLiftReport.summary(EventSheetLiftReport.for_sheet(sheet))])


## Marks the rows built from lines the ENGINE could not parse, using the errors the open job already
## collected. The line-to-row join is the source map of a compile of this sheet: an opened file
## re-emits byte-identically, so line N of the output is line N of the file on disk. A file that
## parses clears any marks a previous check left behind.
func _flag_parse_error_rows(sheet: EventSheetResource, resolved_path: String) -> void:
	if sheet == null or _dock._viewport == null:
		return
	var errors: Array = EventSheetParseErrors.errors_for(sheet)
	if errors.is_empty():
		_dock._viewport.clear_row_diagnostics()
		return
	var source_map: Array = SheetCompiler.compile(sheet, resolved_path).get("source_map", [])
	_dock._viewport.set_row_diagnostics(EventSheetParseErrors.row_diagnostics(errors, source_map))


## Opens a freshly-created .gd as an EDITABLE sheet tab, NOT the read-only preview a casual Open
## gives. The user just authored it via FileSystem "Create New > Event Sheet", so they should be
## able to add events immediately. Mirrors _save_sheet_as_gdscript's editable-reopen recipe.
func _open_new_sheet(path: String) -> void:
	var resolved_path: String = path.strip_edges()
	if resolved_path.is_empty():
		return
	var imported: EventSheetResource = GDScriptImporter.new().import_external(resolved_path)
	if imported == null:
		_dock._set_status("Created %s, but couldn't open it as a sheet." % resolved_path.get_file(), true)
		return
	imported.read_only = false  # just authored - open it editable, not as a preview
	_dock.setup(imported)
	_dock._current_sheet_path = resolved_path
	_dock._dirty = false
	_dock._refresh_title_strip()
	_dock._clear_undo_history()
	_dock._external_mtime = FileAccess.get_modified_time(resolved_path)
	_dock._refresh_preview_banner()
	_dock._set_status("Created %s - start adding events, then Save." % resolved_path.get_file())


## Compiles a GDScript-backed sheet to its .gd source. Returns whether the compile succeeded (and
## sets a failure status when it does not). Shared by Save and "Open in Godot" so the latter can
## refuse to open a stale source when the sheet doesn't currently compile.
func _save_backed_sheet() -> bool:
	# The .gd IS the sheet on this path - it deserves the same backup ring a .tres save
	# gets (pre-save bytes first; the ring dedups no-op saves so it doesn't churn).
	EventSheetBackups.backup_sheet(_dock._current_sheet.external_source_path)
	var compile_result: Dictionary = SheetCompiler.compile(_dock._current_sheet, _dock._current_sheet.external_source_path)
	EventSheets._notify_lifecycle("compiled", {"sheet": _dock._current_sheet, "path": _dock._current_sheet.external_source_path, "success": bool(compile_result.get("success", false))})
	if not bool(compile_result.get("success", false)):
		_dock._set_status("This sheet doesn't compile yet - fix the error, then save again. (%s)" % ", ".join(PackedStringArray(compile_result.get("errors", []))), true)
		return false
	_dock._dirty = false
	_dock._external_mtime = FileAccess.get_modified_time(_dock._current_sheet.external_source_path)
	_dock._refresh_title_strip()
	EventSheets._notify_lifecycle("saved", {"sheet": _dock._current_sheet, "path": _dock._current_sheet.external_source_path})
	return true


func _on_save_requested() -> void:
	if _dock._current_sheet == null:
		_dock._set_status("Nothing to save.", true)
		return
	# Read-only preview never writes back over the source file. The user opts in with
	# "Edit Events" (then this becomes a normal GDScript-backed save), or forks via Save As.
	# P4 - a scene read as one sheet is many files at once, and the .tscn is not one of them: there is
	# nothing here to save, so say where the editing happens instead.
	if EventSheetSceneSheet.is_scene_sheet(_dock._current_sheet):
		_dock._set_status("%s is a reading of the whole scene - double-click an object bar to open that script and save there." %
			EventSheetSceneSheet.scene_path_of(_dock._current_sheet).get_file(), true)
		return
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
		# A scratch sheet that gets a path stops being one: it is a file of the user's project now,
		# and it must close with the same "you have unsaved changes" guard as any other tab.
		EventSheetDocScratch.claim_saved(_dock._current_sheet)
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


## Sheet ▸ Save as text…: the whole sheet as the plain listing every event-sheet community pastes
## into a forum post or an issue - "+ " for a condition, "-> " for an action, indented by
## sub-event, event numbers on - written as Markdown. Read-only output in the sheet's own words:
## the round trip lives in the .gd, so nothing reads back in from here.
func _save_sheet_as_text_requested() -> void:
	if _dock._current_sheet == null:
		_dock._set_status("Open or create a sheet first.", true)
		return
	var dialog: FileDialog = FileDialog.new()
	dialog.title = "Save Sheet as Text"
	dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.filters = PackedStringArray(["*.md ; Markdown"])
	dialog.current_path = "%s.md" % _exported_script_basename()
	dialog.file_selected.connect(func(path: String) -> void:
		_write_sheet_text(path)
		dialog.call_deferred("queue_free")
	)
	dialog.canceled.connect(func() -> void: dialog.queue_free())
	_dock.add_child(dialog)
	dialog.popup_centered(Vector2i(860, 580))


func _write_sheet_text(path: String) -> void:
	var target: String = path if path.get_extension() == "md" else path + ".md"
	var file: FileAccess = FileAccess.open(target, FileAccess.WRITE)
	if file == null:
		_dock._set_status("Could not write %s." % target.get_file(), true)
		return
	file.store_string(sheet_text_markdown())
	file.close()
	_dock._set_status("Saved the sheet as text to %s." % target.get_file())


## The whole sheet's listing as Markdown - separated from the file dialog so it is testable.
func sheet_text_markdown() -> String:
	var view: EventSheetViewport = _dock._active_view()
	if view == null:
		return ""
	return EventSheetTextListing.markdown_for_rows(view.get_row_tree(), _exported_script_basename())


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
	# Save As over an EXISTING file is still an overwrite - ring its pre-save bytes too.
	EventSheetBackups.backup_sheet(resolved_path)
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
	# Save As over an existing .gd overwrites it - ring its pre-save bytes first.
	EventSheetBackups.backup_sheet(path)
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
