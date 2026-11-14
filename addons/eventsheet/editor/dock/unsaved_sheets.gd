@tool
extends RefCounted

# The two answers the plugin gives Godot about sheets that have edits not saved yet. Godot asks them
# when the editor quits, when the project is reloaded, and on Save All and save-before-run:
#
#   - status_text(dock): the sentence Godot's own "save changes?" dialog prints, naming each sheet.
#   - save_dirty_tabs(dock): writes every unsaved sheet the way the Save button does (backup, atomic
#     write, the same checks), and returns one plain line per sheet it could not write.
#
# A sheet that cannot be written - it was never saved so it has no file, its file holds unresolved
# merge markers, or it does not compile yet - is never skipped in silence: it is named with its reason,
# and it never holds the editor open, because Godot's dialog always offers Don't Save and Cancel.
#
# Loaded by path by the plugin, only when Godot asks, so the editor start does not compile it.


## The sentence for Godot's dialog: one line per unsaved sheet, "" when every sheet is saved.
static func status_text(dock: Control) -> String:
	var lines: PackedStringArray = PackedStringArray()
	for index: int in unsaved_indexes(dock):
		var tab: Dictionary = dock._open_tabs[index]
		var reason: String = refusal_reason(tab.get("sheet"), str(tab.get("path", "")))
		if reason.is_empty():
			lines.append("- %s" % file_name(tab))
		else:
			lines.append("- %s (%s)" % [file_name(tab), reason])
	if lines.is_empty():
		return ""
	return "%s\n%s" % [EventSheetL10n.translate("Event sheets with changes that are not saved yet:"), "\n".join(lines)]


## Saves every unsaved sheet through the dock's own Save, one tab at a time, and puts the reader back
## on the tab they were looking at. Returns a line per sheet that could not be written.
static func save_dirty_tabs(dock: Control) -> PackedStringArray:
	var failed: PackedStringArray = PackedStringArray()
	var indexes: Array[int] = unsaved_indexes(dock)
	if indexes.is_empty():
		return failed
	var started_on: Variant = dock._current_sheet
	for index: int in indexes:
		if index >= dock._open_tabs.size():
			continue
		var tab: Dictionary = dock._open_tabs[index]
		var reason: String = refusal_reason(tab.get("sheet"), str(tab.get("path", "")))
		if not reason.is_empty():
			failed.append("%s: %s" % [file_name(tab), reason])
			continue
		if index != dock._active_tab_index:
			dock._activate_tab(index)
		dock._sheet_io._on_save_requested()
		if dock._dirty:
			var said: String = str(dock._status_label.tooltip_text) if dock._status_label != null else ""
			if said.is_empty():
				said = EventSheetL10n.translate("it was not saved - open it in the EventSheet screen and press Save")
			failed.append("%s: %s" % [file_name(tab), said])
	for index: int in range(dock._open_tabs.size()):
		if dock._open_tabs[index].get("sheet") == started_on and index != dock._active_tab_index:
			dock._activate_tab(index)
			break
	if not failed.is_empty():
		var report: String = EventSheetL10n.translate("These event sheets were not saved: %s") % " | ".join(failed)
		push_warning(report)
		dock._set_status(report, true)
	return failed


## The indexes of the tabs with edits not saved yet. The tab in front keeps its flag on the dock rather
## than in its entry, so the entry is brought up to date first.
static func unsaved_indexes(dock: Control) -> Array[int]:
	var found: Array[int] = []
	if dock == null:
		return found
	dock._sync_active_tab_state()
	for index: int in range(dock._open_tabs.size()):
		if bool(dock._open_tabs[index].get("dirty", false)):
			found.append(index)
	return found


## Why a save would be refused before it is tried, in the reader's words; "" when it can be tried.
static func refusal_reason(sheet: Variant, tab_path: String) -> String:
	if sheet == null:
		return ""
	var resource: EventSheetResource = sheet as EventSheetResource
	if resource == null:
		return ""
	var path: String = resource.external_source_path if not resource.external_source_path.is_empty() else tab_path
	if path.is_empty():
		path = resource.resource_path
	if path.is_empty():
		return EventSheetL10n.translate("it has never been saved, so it has no file yet - use Save As in the EventSheet screen to give it one")
	if resource.blocked_by_conflict() or (not resource.external_source_path.is_empty() \
			and EventSheetConflictGuard.blocks_file(resource.external_source_path)):
		return EventSheetL10n.translate("its file still holds unresolved merge markers - finish the merge first")
	if resource.read_only:
		return EventSheetL10n.translate("it is open read-only - press Edit Events, or use Save As to keep a copy")
	return ""


## The name a tab goes by in these lines: its file, or "Untitled" when it has none.
static func file_name(tab: Dictionary) -> String:
	var resource: EventSheetResource = tab.get("sheet") as EventSheetResource
	var path: String = str(tab.get("path", ""))
	if resource != null and not resource.external_source_path.is_empty():
		path = resource.external_source_path
	if path.is_empty() and resource != null:
		path = resource.resource_path
	return path.get_file() if not path.is_empty() else EventSheetL10n.translate("Untitled EventSheet")
