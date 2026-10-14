@tool
class_name EventSheetExternalWatcher
extends RefCounted

# Watches the active GDScript-backed sheet's file on disk and offers to reload when it diverges
# from what the editor last opened/saved. Extracted from event_sheet_dock.gd so the dock stays
# focused.
#
# The reload dialog is owned state and lives here. The mtime baseline (_external_mtime) stays on
# the DOCK because it is written from several load/save sites that remain on the dock; this class
# reads and writes it through the dock reference. The dock keeps thin delegates
# (_prompt_external_reload_if_changed / _external_sheet_changed_on_disk / _reload_external_sheet)
# so the focus-in notification and the watch test keep calling the dock unchanged.

const SHEET_COMPILER_PATH := "res://addons/eventforge/compiler/sheet_compiler.gd"
## The file the unsaved version is compiled into before it joins the backup ring; removed straight after.
const UNSAVED_COPY := "user://eventsheet_unsaved_before_reload.gd"
## The custom action of the question's What Changed… button.
const WHAT_CHANGED_ACTION: StringName = &"what_changed"

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
	# Focus comes back to the editor while the question is still open; asking twice helps nobody.
	if is_instance_valid(_external_reload_dialog) and _external_reload_dialog.visible:
		return
	var dirty: bool = bool(_dock._dirty)
	var ask: Dictionary = reload_prompt(_dock._current_sheet.external_source_path.get_file(), dirty,
		FileAccess.get_modified_time(_dock._current_sheet.external_source_path))
	# Keeping the editor version remembers the new mtime, so the question is asked once per change.
	var keep: Callable = func() -> void:
		if _dock._current_sheet != null:
			_dock._external_mtime = FileAccess.get_modified_time(_dock._current_sheet.external_source_path)
	ask["on_cancel"] = keep
	ask["on_main"] = keep if dirty else reload_external_sheet
	ask["on_danger"] = func() -> void:
		keep_unsaved_in_backups()
		reload_external_sheet()
	_external_reload_dialog = load(_dock.SMALL_PROMPT_PATH).open(_dock, ask)
	# What Changed… opens the row-language diff OVER the question, so it is read before choosing; it
	# sits beside the blue answer and never closes the question by itself.
	var dialog: ConfirmationDialog = _external_reload_dialog
	var look: Button = dialog.add_button(EventSheetL10n.translate("What Changed…"), true, WHAT_CHANGED_ACTION)
	look.get_parent().move_child(look, dialog.get_ok_button().get_index())
	dialog.custom_action.connect(func(action: StringName) -> void:
		if action == WHAT_CHANGED_ACTION:
			_dock._sheet_diff.open(dialog))


## Puts the version in the editor - unsaved edits and all - into the file's backup ring, so taking
## the file on disk loses nothing for good. Returns the backup's path, "" when it could not be kept.
func keep_unsaved_in_backups() -> String:
	var sheet: EventSheetResource = _dock._current_sheet
	if sheet == null or sheet.external_source_path.is_empty():
		return ""
	var compiled: Dictionary = load(SHEET_COMPILER_PATH).compile(sheet, UNSAVED_COPY)
	var kept: String = ""
	if bool(compiled.get("success", false)):
		kept = EventSheetBackups.backup_bytes(sheet.external_source_path, FileAccess.get_file_as_bytes(UNSAVED_COPY))
	DirAccess.remove_absolute(UNSAVED_COPY)
	return kept


## What the reload question says, and which answer is the safe one. With unsaved edits here, keeping
## them is the blue answer and the file on disk is the red one; on a clean tab a reload loses
## nothing, so Reload is the blue answer and nothing is painted as dangerous. The list above the
## answers says, before anyone chooses, whether this tab has edits to lose and when the file changed
## (`changed_at` is its modification time, 0 when unknown).
static func reload_prompt(file_name: String, dirty: bool, changed_at: int = 0) -> Dictionary:
	var at: String = "" if changed_at <= 0 else Time.get_time_string_from_unix_time(
		changed_at + int(Time.get_time_zone_from_system().get("bias", 0)) * 60).left(5)
	var ask: Dictionary = {
		"list": [[EventSheetL10n.translate("This tab - unsaved edits") if dirty
				else EventSheetL10n.translate("This tab - nothing unsaved"), EventSheetL10n.translate("yours")],
			[EventSheetL10n.translate("On disk - changed at %s") % at if not at.is_empty()
				else EventSheetL10n.translate("On disk - changed"), EventSheetL10n.translate("the file")]],
		"title": EventSheetL10n.translate("%s changed outside the editor") % file_name,
		"say": EventSheetL10n.translate("The file on disk changed, and nothing here is unsaved. Show the new version?"),
		"note": EventSheetL10n.translate("Reloading reads its events again; there is nothing for Ctrl+Z to take back."),
		"glyph": "!",
		"main": EventSheetL10n.translate("Reload"),
		"cancel": EventSheetL10n.translate("Keep this version"),
	}
	if dirty:
		ask.merge({
			"say": EventSheetL10n.translate("The file on disk changed while you were editing it here. Which version do you want?"),
			"note": EventSheetL10n.translate("Using the file on disk keeps your unsaved edits as a backup in Sheet Backups first; Ctrl+Z cannot bring them back."),
			"main": EventSheetL10n.translate("Keep mine"),
			"cancel": "",
			"danger": EventSheetL10n.translate("Use the file on disk"),
		}, true)
	return ask
