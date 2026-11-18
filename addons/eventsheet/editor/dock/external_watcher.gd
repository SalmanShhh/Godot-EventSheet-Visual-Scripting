@tool
class_name EventSheetExternalWatcher
extends RefCounted

# Watches the active sheet's file on disk (a script sheet's .gd, or a .tres) and offers to reload when
# it diverges from what the editor last opened or saved. The reload dialog lives here; the mtime
# baseline (_external_mtime) stays on the dock, written from its load and save sites.

const SHEET_COMPILER_PATH := "res://addons/eventforge/compiler/sheet_compiler.gd"
const RELOAD_FROM_DISK_PATH := "res://addons/eventsheet/editor/dock/reload_from_disk.gd"
## The file the unsaved version is compiled into before it joins the backup ring; removed straight after.
const UNSAVED_COPY := "user://eventsheet_unsaved_before_reload.gd"
## The custom action of the question's What Changed… button.
const WHAT_CHANGED_ACTION: StringName = &"what_changed"

var _dock: Control = null
var _external_reload_dialog: ConfirmationDialog = null


func init(dock: Control) -> void:
	_dock = dock


## The file the open tab stands on: a script sheet's .gd, or the .tres a resource sheet was opened from
## or saved to. "" for a sheet with no file yet.
func watched_path() -> String:
	var sheet: EventSheetResource = _dock._current_sheet
	if sheet == null:
		return ""
	if not sheet.external_source_path.is_empty():
		return sheet.external_source_path
	var path: String = _dock._current_sheet_path if not _dock._current_sheet_path.is_empty() else sheet.resource_path
	return path if path.get_extension() == "tres" else ""


## True when the active sheet's file changed on disk since open/save.
func sheet_changed_on_disk() -> bool:
	if watched_path().is_empty():
		return false
	var disk_mtime: int = FileAccess.get_modified_time(watched_path())
	return disk_mtime != 0 and _dock._external_mtime != 0 and disk_mtime != _dock._external_mtime


## Re-reads the active sheet from disk (a script: fresh lossless import + ACE lift; a .tres: a fresh load).
func reload_external_sheet() -> void:
	if watched_path().is_empty():
		return
	if _dock._current_sheet.external_source_path.is_empty():
		load(RELOAD_FROM_DISK_PATH).reload(_dock, watched_path())
	else:
		_dock._load_sheet_from_path(_dock._current_sheet.external_source_path)
	_dock._set_status("Reloaded from disk: %s" % watched_path().get_file())


func prompt_external_reload_if_changed() -> void:
	if not sheet_changed_on_disk():
		return
	# A read-only PREVIEW has no editor changes to lose, so it re-renders LIVE: silently re-import the
	# file the moment it changes on disk (edit the .gd in the script editor, refocus the Event Sheets
	# tab, and the rows track it). The confirm dialog is only for an unlocked, editable sheet.
	if _dock._current_sheet != null and _dock._current_sheet.read_only:
		reload_external_sheet()
		return
	# Focus comes back to the editor while the question is still open; asking twice helps nobody.
	if is_instance_valid(_external_reload_dialog) and _external_reload_dialog.visible:
		return
	var dirty: bool = bool(_dock._dirty)
	var ask: Dictionary = load(RELOAD_FROM_DISK_PATH).reload_prompt(watched_path().get_file(), dirty, FileAccess.get_modified_time(watched_path()))
	# Keeping the editor version remembers the new mtime, so the question is asked once per change.
	var keep: Callable = func() -> void:
		if _dock._current_sheet != null:
			_dock._external_mtime = FileAccess.get_modified_time(watched_path())
	ask["on_cancel"] = keep
	ask["on_main"] = keep if dirty else reload_external_sheet
	ask["on_danger"] = use_file_on_disk
	_external_reload_dialog = load(_dock.SMALL_PROMPT_PATH).open(_dock, ask)
	if _dock._current_sheet.external_source_path.is_empty():
		return  # What Changed reads a script sheet's file; a .tres has no such diff
	# What Changed… opens the row-language diff OVER the question, so it is read before choosing; it
	# sits beside the blue answer and never closes the question by itself.
	var dialog: ConfirmationDialog = _external_reload_dialog
	var look: Button = dialog.add_button(EventSheetL10n.translate("What Changed…"), true, WHAT_CHANGED_ACTION)
	look.get_parent().move_child(look, dialog.get_ok_button().get_index())
	dialog.custom_action.connect(func(action: StringName) -> void:
		if action == WHAT_CHANGED_ACTION:
			_dock._sheet_diff.open(dialog))


## "Use the file on disk": the version in the editor goes into the backup ring first, as the question
## promised. When it cannot be kept (the sheet does not compile, or the backup cannot be written),
## nothing is reloaded - the edits stay on screen and the status says why. Returns whether it reloaded.
func use_file_on_disk() -> bool:
	if keep_unsaved_in_backups().is_empty() and EventSheetBackups.backup_count() > 0:
		_dock._set_status(EventSheetL10n.translate("Your unsaved edits could not be kept as a backup, so the file on disk was not loaded. Save this version, or fix what stops it compiling, and choose again."), true)
		return false
	reload_external_sheet()
	return true


## Puts the version in the editor - unsaved edits and all - into the file's backup ring, so taking
## the file on disk loses nothing for good. Returns the backup's path, "" when it could not be kept.
func keep_unsaved_in_backups() -> String:
	return keep_sheet_in_backups(_dock._current_sheet, watched_path())


## The same for any open sheet, under the file name its ring is kept by: the unsaved version of `sheet`
## goes into `ring_path`'s backup ring. "" when it could not be kept.
func keep_sheet_in_backups(sheet: EventSheetResource, ring_path: String) -> String:
	if sheet == null or ring_path.is_empty():
		return ""
	if sheet.external_source_path.is_empty():
		return load(RELOAD_FROM_DISK_PATH).keep_unsaved(sheet, ring_path)
	var compiled: Dictionary = load(SHEET_COMPILER_PATH).compile(sheet, UNSAVED_COPY)
	var kept: String = ""
	if bool(compiled.get("success", false)):
		kept = EventSheetBackups.backup_bytes(ring_path, FileAccess.get_file_as_bytes(UNSAVED_COPY))
	DirAccess.remove_absolute(UNSAVED_COPY)
	return kept
