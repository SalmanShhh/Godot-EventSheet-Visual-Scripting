# EventForge - the Every Tick prompt. Taking the last condition off a top-level event asks whether to
# keep it as an every-tick event or delete it. Dismissing the question (Esc, the close box) must keep
# the event: only the Delete The Event button deletes it.
@tool
class_name EveryTickPromptTest
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")


static func run() -> bool:
	var ok: bool = true
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	var event_row: EventRow = EventRow.new()
	event_row.event_uid = "every_tick_probe"
	sheet.events.append(event_row)
	dock._current_sheet = sheet
	var ops: EventSheetRowEditOps = EventSheetRowEditOps.new()
	ops._dock = dock

	ops._prompt_keep_as_every_tick("every_tick_probe")
	var dialog: ConfirmationDialog = ops._every_tick_dialog
	ok = _check("the prompt was built", dialog != null, true) and ok
	ok = _check("OK keeps the event", dialog.ok_button_text, "Keep As Every Tick") and ok
	ok = _check("there is no Cancel button to mistake for delete", dialog.get_cancel_button().visible, false) and ok
	ok = _check("Delete The Event is its own button", _button_texts(dialog).has("Delete The Event"), true) and ok

	# Esc and the close box send `canceled`: the event stays.
	dialog.canceled.emit()
	ok = _check("dismissing keeps the event", sheet.events.size(), 1) and ok
	# Another custom action deletes nothing either.
	dialog.custom_action.emit(&"something_else")
	ok = _check("another action keeps the event", dock._current_sheet.events.size(), 1) and ok
	# Only the Delete The Event button deletes.
	dialog.custom_action.emit(ops.EVERY_TICK_DELETE_ACTION)
	ok = _check("Delete The Event deletes it", dock._current_sheet.events.size(), 0) and ok

	dock.free()
	return ok


## The text of every button the dialog shows, wherever Godot placed it.
static func _button_texts(dialog: AcceptDialog) -> PackedStringArray:
	var texts: PackedStringArray = PackedStringArray()
	for button: Node in dialog.find_children("*", "Button", true, false):
		texts.append((button as Button).text)
	return texts


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("every_tick_prompt_test", label, actual, expected)
