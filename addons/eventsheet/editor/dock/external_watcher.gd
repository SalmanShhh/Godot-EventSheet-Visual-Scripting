@tool
extends RefCounted
class_name EventSheetExternalWatcher

# Watches the active GDScript-backed sheet's file on disk and offers to reload when it diverges
# from what the editor last opened/saved. Extracted from event_sheet_dock.gd so the dock stays
# focused.
#
# The reload dialog is owned state and lives here. The mtime baseline (_external_mtime) stays on
# the DOCK because it is written from several load/save sites that remain on the dock; this class
# reads and writes it through the dock reference. The dock keeps thin delegates
# (_prompt_external_reload_if_changed / _external_sheet_changed_on_disk / _reload_external_sheet)
# so the focus-in notification and the watch test keep calling the dock unchanged.

var _dock: Control = null
var _external_reload_dialog: ConfirmationDialog = null

func init(dock: Control) -> void:
	_dock = dock

## True when the active GDScript-backed sheet's file changed on disk since open/save.
func sheet_changed_on_disk() -> bool:
	if _dock._current_sheet == null or _dock._current_sheet.external_source_path.is_empty():
		return false
	var disk_mtime: int = FileAccess.get_modified_time(_dock._current_sheet.external_source_path)
	return disk_mtime != 0 and _dock._external_mtime != 0 and disk_mtime != _dock._external_mtime

## Re-imports the active external sheet from disk (fresh lossless import + ACE lift).
func reload_external_sheet() -> void:
	if _dock._current_sheet == null or _dock._current_sheet.external_source_path.is_empty():
		return
	_dock._load_sheet_from_path(_dock._current_sheet.external_source_path)
	_dock._set_status("Reloaded from disk: %s" % _dock._current_sheet_path.get_file())

func prompt_external_reload_if_changed() -> void:
	if not sheet_changed_on_disk():
		return
	# A read-only PREVIEW has no editor changes to lose, so it re-renders LIVE: silently re-import the
	# file the moment it changes on disk (edit the .gd in the script editor, refocus the Event Sheets
	# tab, and the rows track it). The confirm dialog is only for an unlocked, editable sheet.
	if _dock._current_sheet != null and _dock._current_sheet.read_only:
		reload_external_sheet()
		return
	if _external_reload_dialog == null:
		_external_reload_dialog = ConfirmationDialog.new()
		_external_reload_dialog.title = "File Changed On Disk"
		_external_reload_dialog.ok_button_text = "Reload"
		_external_reload_dialog.cancel_button_text = "Keep Editor Version"
		_external_reload_dialog.confirmed.connect(reload_external_sheet)
		# Keeping the editor version: remember the new mtime so we only ask once per change.
		_external_reload_dialog.canceled.connect(func() -> void:
			if _dock._current_sheet != null:
				_dock._external_mtime = FileAccess.get_modified_time(_dock._current_sheet.external_source_path)
		)
		_dock.add_child(_external_reload_dialog)
	_external_reload_dialog.dialog_text = "%s was modified outside the sheet editor.
Reload it (re-import + event lifting)? Unsaved sheet edits will be lost." % _dock._current_sheet.external_source_path.get_file()
	_external_reload_dialog.popup_centered(Vector2i(460, 160))
