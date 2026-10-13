# EventForge - the unsaved-close guard. Closing a tab with unsaved edits must not silently drop
# work: a dirty tab arms a 3-way Save / Discard / Cancel dialog, a clean tab closes immediately.
# Save is the OK button so Enter keeps the work; Discard is its own button that must be clicked.
@tool
class_name UnsavedCloseTest
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")


static func run() -> bool:
	var ok: bool = true
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock

	var first: EventSheetResource = EventSheetResource.new()
	first.host_class = "Node2D"
	var second: EventSheetResource = EventSheetResource.new()
	second.host_class = "Node2D"
	dock._open_tabs.clear()
	dock._open_tabs.append({"sheet": first, "path": "", "dirty": true})
	dock._open_tabs.append({"sheet": second, "path": "", "dirty": false})
	dock._active_tab_index = 0

	ok = _check("dirty tab is detected", dock.is_tab_dirty(0), true) and ok
	ok = _check("clean tab is not dirty", dock.is_tab_dirty(1), false) and ok
	ok = _check("has_unsaved_tabs sees the dirty tab", dock.has_unsaved_tabs(), true) and ok

	# The guard dialog is a 3-way Save / Discard / Cancel.
	dock._ensure_unsaved_close_dialog()
	ok = _check("guard dialog created", dock._unsaved_close_dialog != null, true) and ok
	ok = _check("OK button saves, so Enter keeps the work", dock._unsaved_close_dialog.ok_button_text, "Save") and ok
	ok = _check("Cancel button aborts", dock._unsaved_close_dialog.cancel_button_text, "Cancel") and ok
	ok = _check("Discard is its own button", _button_texts(dock._unsaved_close_dialog).has("Discard"), true) and ok
	ok = _check("OK does not discard", dock._unsaved_close_dialog.confirmed.is_connected(dock._on_unsaved_close_save), true) and ok

	# A custom action that is not Discard closes nothing.
	dock._pending_close_index = 0
	dock._on_unsaved_close_action(&"something_else")
	ok = _check("another action leaves the tab open", dock.get_open_tab_count(), 2) and ok
	# Discard closes the armed tab and clears the pending index.
	dock._on_unsaved_close_action(dock.UNSAVED_DISCARD_ACTION)
	ok = _check("discard closes the tab", dock.get_open_tab_count(), 1) and ok
	ok = _check("pending index cleared", dock._pending_close_index, -1) and ok
	ok = _check("remaining tab is clean", dock.has_unsaved_tabs(), false) and ok

	# A clean tab closes immediately, with no guard. Two clean tabs so one remains afterwards -
	# closing the LAST tab re-opens the welcome sheet (correct), which would mask this check.
	var clean_a: EventSheetResource = EventSheetResource.new()
	clean_a.host_class = "Node2D"
	var clean_b: EventSheetResource = EventSheetResource.new()
	clean_b.host_class = "Node2D"
	dock._open_tabs.clear()
	dock._open_tabs.append({"sheet": clean_a, "path": "", "dirty": false})
	dock._open_tabs.append({"sheet": clean_b, "path": "", "dirty": false})
	dock._active_tab_index = 0
	dock._suppress_tab_signal = false
	dock._on_tab_close_pressed(0)
	ok = _check("clean tab closes without a prompt", dock.get_open_tab_count(), 1) and ok

	dock.free()
	return ok


## The text of every button the dialog shows, wherever Godot placed it.
static func _button_texts(dialog: AcceptDialog) -> PackedStringArray:
	var texts: PackedStringArray = PackedStringArray()
	for button: Node in dialog.find_children("*", "Button", true, false):
		texts.append((button as Button).text)
	return texts


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("unsaved_close_test", label, actual, expected)
