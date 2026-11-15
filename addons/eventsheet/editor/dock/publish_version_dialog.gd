@tool
extends RefCounted
# Sheet > Publish New Version...: the pack versioning window and its reading check, moved out of
# the provider registry glue so the first open of a sheet does not compile it. The glue holds one
# instance of this file, loaded by path the first time the window is asked for; the body is the
# old code verbatim.

const EVENTSHEETS_API_PATH := "res://addons/eventsheet/api/eventsheets.gd"
const ANNOTATION_WRITER_PATH := "res://addons/eventsheet/ace/annotation_writer.gd"
const READING_CHECK_PATH := "res://addons/eventsheet/ace/pack_reading_check.gd"

var _dock: Control = null
var _version_dialog: ConfirmationDialog = null
var _version_bump: OptionButton = null
var _version_note: LineEdit = null
var _version_preview: Label = null
var _reading_summary: Label = null
var _reading_failures: ItemList = null


## Sheet > Publish New Version...: the pack versioning ritual - pick patch/minor/major, write a
## one-line change note, and the file's `@ace_version` bumps with the note recorded under it as a
## doc comment (backup first, same write path as Curate Script). Only offered for a sheet that IS
## a pack (it lives under eventsheet_addons/ or already declares a version).
func open_publish_version_dialog(dock: Control) -> void:
	_dock = dock
	var sheet: EventSheetResource = _dock._current_sheet
	var sheet_path: String = str(_dock._current_sheet_path)
	var is_pack: bool = sheet_path.begins_with("res://eventsheet_addons/") or (sheet != null and not sheet.addon_version.strip_edges().is_empty())
	if not is_pack:
		_dock._set_status("Publish New Version is for addon packs - this sheet declares no @ace_version and lives outside eventsheet_addons/.", true)
		return
	if _version_dialog == null:
		var parts: Dictionary = EventSheetPopupUI.panel_window("Publish New Version", Vector2i.ZERO, _dock, "Publish",
			_apply_version_bump, true)
		_version_dialog = parts["window"]
		var form: VBoxContainer = parts["box"]
		_version_bump = OptionButton.new()
		_version_bump.add_item("Patch - fixes, no new actions", 0)
		_version_bump.add_item("Minor - new actions, nothing breaks", 1)
		_version_bump.add_item("Major - breaking changes", 2)
		_version_bump.item_selected.connect(func(_index: int) -> void: _refresh_version_preview())
		form.add_child(EventSheetPopupUI.form_row("Bump", _version_bump, EventSheetPopupUI.LABEL_MIN_WIDTH,
			"Semantic versioning: patch for fixes, minor for additions, major when sheets using the old actions must change."))
		_version_note = LineEdit.new()
		_version_note.placeholder_text = "One line: what changed (recorded in the class docs)"
		form.add_child(EventSheetPopupUI.form_row("Change note", _version_note, EventSheetPopupUI.LABEL_MIN_WIDTH,
			"Stored as a doc comment under @ace_version, so the pack's history reads in its own file."))
		_version_preview = Label.new()
		form.add_child(_version_preview)
		# The reading check. Publishing is never blocked by it - a check that stopped work would
		# just be routed around - but the pack carries its score in the Project Doctor until it
		# passes, and every failure is listed here with the fix rather than as a verdict.
		_reading_summary = Label.new()
		_reading_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_reading_summary.custom_minimum_size = Vector2(430.0, 0.0)
		_reading_failures = ItemList.new()
		_reading_failures.custom_minimum_size = Vector2(430.0, 110.0)
		_reading_failures.auto_height = false
		var reading_box: VBoxContainer = EventSheetPopupUI.form_box()
		reading_box.add_child(_reading_summary)
		reading_box.add_child(_reading_failures)
		form.add_child(EventSheetPopupUI.titled_card("Reading check", reading_box))
	_version_note.text = ""
	_refresh_version_preview()
	_refresh_reading_check(sheet_path)
	EventSheetWindowPlacement.popup_centered(_version_dialog, Vector2i(520, 470))
	_version_note.grab_focus()


func _refresh_version_preview() -> void:
	if _version_preview == null:
		return
	var source: String = FileAccess.get_file_as_string(str(_dock._current_sheet_path))
	var bump: String = ["patch", "minor", "major"][_version_bump.selected if _version_bump.selected >= 0 else 0]
	var preview: Dictionary = load(ANNOTATION_WRITER_PATH).bump_version(source, bump, "preview")
	_version_preview.text = "%s  ->  %s" % [str(preview.get("old_version")), str(preview.get("new_version"))]


## Runs the reading check on what this pack publishes plus the sheet in front of us as its demo,
## and lists every failure with its fix. The score is stored on the sheet's own metadata so the
## score is at hand without re-reflecting every pack.
func _refresh_reading_check(sheet_path: String) -> void:
	if _reading_summary == null or _reading_failures == null:
		return
	var check: Script = load(READING_CHECK_PATH)
	var definitions: Dictionary = check.check_definitions(check.definitions_for_script(sheet_path))
	var demo: Dictionary = check.check_demo_sheet(_dock._current_sheet, sheet_path)
	var result: Dictionary = check.combine(definitions, demo)
	_reading_summary.text = check.summary_text(result)
	_reading_failures.clear()
	for failure: Dictionary in result.get("failures", []):
		_reading_failures.add_item(check.failure_line(failure))
	_reading_failures.visible = not _reading_failures.item_count == 0


func _apply_version_bump() -> void:
	var path: String = str(_dock._current_sheet_path)
	var bump: String = ["patch", "minor", "major"][_version_bump.selected if _version_bump.selected >= 0 else 0]
	var result: Dictionary = load(EVENTSHEETS_API_PATH).publish_pack_version(path, bump, _version_note.text)
	if not bool(result.get("ok", false)):
		_dock._set_status(str(result.get("reason", "Could not publish the new version.")), true)
		return
	_dock._set_status("Published %s v%s (was v%s) - the note is in the class docs, the file was backed up first." % [
		path.get_file(), str(result.get("new_version")), str(result.get("old_version"))])
	# Republish: refresh the vocabulary and reopen the sheet so the banner chip reads the new version.
	_dock._refresh_ace_registry()
	load(EVENTSHEETS_API_PATH).open_sheet(path)
