# Godot EventSheets - THE BACKUP RING, WITH A DOOR ON IT.
#
# Every pack update copies the files it is about to overwrite or remove into the same per-file ring a
# sheet save uses, before the first new byte lands. Until now that was a folder and a sentence: the
# editor's own Restore menu restores the SHEET IN FRONT OF YOU, which a pack's guide, icon or
# translation table never is, so recovering one meant copying a file out of `user://` by hand.
#
# This is that door. One list, newest first per file, and one button.
#
#   WHAT IS LISTED   every previous version of every file this pack has or ever had, with when it
#                    went into the ring and how big it is. A file an update REMOVED is listed too,
#                    and says so - that is the case somebody comes here for.
#   WHAT THE BUTTON  writes one entry's bytes back over the file they came from, as ONE undoable
#   DOES            edit. Ctrl+Z writes back the bytes that were there, or removes the file again
#                    when there was none, so a restore is as reversible as any other edit.
#   WHAT IT NEVER    touch the ring. It is read, listed and copied out of; only a save or an update
#   DOES             ever adds to it, and only the ring's own pruning ever takes anything out. A
#                    door that consumed the thing it is for would only have to be wrong once.
#
# ALL THE THINKING IS ELSEWHERE, as it is for the update window beside this one: the listing, the
# line each row reads, the edit and the receipt are static and pure in `EventSheetPackUpdate`, so the
# suite pins what a reader is shown and what a press does without opening a window. This file is the
# shell.
@tool
class_name EventSheetPackRestoreDialog
extends AcceptDialog

## The pack being restored into, and the entries currently on the page.
var _pack_folder: String = ""
var _entries: Array[Dictionary] = []

var _summary: Label = null
var _list: ItemList = null
var _restore_button: Button = null
var _status: Label = null

## Called with the sentence a restore left behind, so the manager can say it on its own status line
## and rebuild its table.
var _on_restored: Callable = Callable()


func _init() -> void:
	title = EventSheetL10n.translate("Restore a file from the backup ring")
	ok_button_text = EventSheetL10n.translate("Close")
	add_child(EventSheetPopupUI.margined(_build_body()))


func configure(on_restored: Callable) -> void:
	_on_restored = on_restored
	# THE WAY BACK GOES THE SAME WAY. A restore's Ctrl+Z is not a smaller event than the restore: the
	# file it writes can be the pack's own `.gd`, whose annotations are the vocabulary. So the undo
	# announces itself through the very handler the press does, and the status line, the redrawn list
	# and the registry all hear about both directions from one place.
	EventSheetPackUpdate.announce_restore_undone_to(func(said: String) -> void:
		_status.text = said
		_entries = EventSheetPackUpdate.restorable(_pack_folder)
		_fill()
		_status.text = said
		if _on_restored.is_valid():
			_on_restored.call(said))


## Points the window at one pack. Returns false when the ring holds nothing for it, so the caller
## says so on its own status line rather than opening an empty page.
func open_restore(pack_folder: String) -> bool:
	_pack_folder = pack_folder
	_entries = EventSheetPackUpdate.restorable(_pack_folder)
	if _entries.is_empty():
		return false
	_fill()
	return true


func _build_body() -> Control:
	var page: VBoxContainer = EventSheetPopupUI.form_box()
	page.custom_minimum_size = Vector2(680.0, 420.0)
	_summary = EventSheetPopupUI.hint_label("", 640.0)
	page.add_child(_summary)
	var box: VBoxContainer = EventSheetPopupUI.form_box()
	_list = EventSheetPopupUI.sized_list(220.0)
	_list.item_selected.connect(func(_index: int) -> void: _restore_button.disabled = false)
	box.add_child(_list)
	_restore_button = Button.new()
	_restore_button.text = EventSheetL10n.translate("Put this one back")
	_restore_button.tooltip_text = EventSheetL10n.translate("Writes the chosen backup's bytes over the file in the pack, as one edit you can undo. The backup ring itself is not touched.")
	_restore_button.disabled = true
	_restore_button.pressed.connect(_on_restore_pressed)
	box.add_child(_restore_button)
	page.add_child(EventSheetPopupUI.titled_card(
		EventSheetL10n.translate("What the ring is holding, newest first"), box))
	_status = EventSheetPopupUI.hint_label("", 640.0)
	page.add_child(_status)
	return page


func _fill() -> void:
	_summary.text = summary_text(_pack_folder, _entries)
	_list.clear()
	for entry: Dictionary in _entries:
		var line: String = EventSheetPackUpdate.restore_line(entry)
		_list.add_item(line)
		_list.set_item_tooltip(_list.item_count - 1, str(entry.get("backup", "")))
	_restore_button.disabled = true
	_status.text = ""


## The line above the list: which pack, how many files it is about, and how many versions of them.
## Pure, so the suite pins the sentence rather than a window's label.
static func summary_text(pack_folder: String, entries: Array[Dictionary]) -> String:
	var files: PackedStringArray = PackedStringArray()
	for entry: Dictionary in entries:
		var path: String = str(entry.get("path", ""))
		if not files.has(path):
			files.append(path)
	return EventSheetL10n.translate("%s - the backup ring is holding %d earlier version(s) of %d file(s). Choose one and it is written back over the file in the pack, as one edit you can undo.") % [
		pack_folder.get_file(), entries.size(), files.size()]


func _on_restore_pressed() -> void:
	var chosen: PackedInt32Array = _list.get_selected_items()
	if chosen.is_empty() or chosen[0] >= _entries.size():
		return
	var said: String = EventSheetPackUpdate.restore_text(
		EventSheetPackUpdate.restore(_entries[chosen[0]]))
	_status.text = said
	# The list is drawn again because a restore changes what the rows say about themselves: the file
	# that was gone is in the folder now, and its row must stop claiming otherwise.
	_entries = EventSheetPackUpdate.restorable(_pack_folder)
	_fill()
	_status.text = said
	if _on_restored.is_valid():
		_on_restored.call(said)
