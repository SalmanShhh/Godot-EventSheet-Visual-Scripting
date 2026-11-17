# Godot EventSheets - Sheet > Tidy This Script: the window that shows every line before any is written.
#
# A script keeps the spelling it was written in, and an untouched open and save never changes a byte. This is
# the one door that does, and it only opens because the reader chose it. The change is planned on a copy of
# the sheet (tidy_script.gd), every line that would be written differently is listed here as `before => after`,
# and nothing happens until Apply.
#
# APPLY IS ONE UNDO STEP, THEN THE ORDINARY SAVE. The change lands through the funnel every other edit takes,
# and the sheet is saved the way Save saves it, which takes the usual backup of the file first. The plan is
# made AGAIN inside the edit and compared with the one that was shown: when the sheet moved while the window
# was open, nothing is written and the window draws what the sheet says now.
@tool
extends RefCounted

const TIDY := preload("res://addons/eventsheet/editor/dock/tidy_script.gd")

var _dock: Node = null
var _dialog: AcceptDialog = null
var _summary_label: Label = null
var _list: Tree = null
var _plan: Dictionary = {}


func init(dock: Node) -> void:
	_dock = dock


## Opens the window over the sheet in front of the reader. A sheet with nothing to tidy says so on the status
## line and opens no window. Nothing is changed until Apply.
func open() -> void:
	if _dock == null or _dock._current_sheet == null:
		return
	_plan = TIDY.plan(_dock._current_sheet)
	if bool(_plan.get("unsure", false)):
		_dock._set_status(EventSheetL10n.translate("This script cannot be tidied: it does not write back the same text from a copy, so nothing was planned."), true)
		return
	if (_plan["changes"] as Array).is_empty():
		_dock._set_status(EventSheetL10n.translate("Nothing to tidy."))
		return
	_build_dialog()
	_fill()
	if _dock.is_inside_tree():
		EventSheetWindowPlacement.popup_centered(_dialog, Vector2i(820, 520))


## The words above the list: how many lines would change, and how many are left as they are.
static func summary_text(made: Dictionary) -> String:
	var moving: int = (made.get("changes", []) as Array).size()
	var staying: int = int(made.get("left", 0))
	var would: String = EventSheetL10n.counted("1 line would be rewritten in one step you can undo.",
		"%d lines would be rewritten in one step you can undo.", moving)
	if staying == 0:
		return would
	return would + " " + EventSheetL10n.counted("1 line is left as it is.", "%d lines are left as they are.", staying)


## THE EDIT. One undo step through the funnel, then the ordinary save.
func confirm() -> void:
	if _dock == null or _dock._current_sheet == null:
		return
	var shown: String = str(_plan.get("after", ""))
	var count: Array[int] = [0]
	var moved_on: Array[bool] = [false]
	var landed: bool = _dock._perform_undoable_sheet_edit(EventSheetL10n.translate("Tidy this script"), func() -> bool:
		var now: Dictionary = TIDY.plan(_dock._current_sheet)
		if str(now.get("after", "")) != shown:
			moved_on[0] = true
			return false
		count[0] = (now["changes"] as Array).size()
		return TIDY.apply(_dock._current_sheet, now) > 0)
	if not landed:
		if moved_on[0]:
			_plan = TIDY.plan(_dock._current_sheet)
			if (_plan["changes"] as Array).is_empty():
				_dock._set_status(EventSheetL10n.translate("This sheet changed while the window was open, so nothing was written. Nothing to tidy."), true)
				return
			_fill()
			if _dock.is_inside_tree():
				EventSheetWindowPlacement.popup_centered(_dialog, Vector2i(820, 520))
			_dock._set_status(EventSheetL10n.translate("This sheet changed while the window was open, so nothing was written - here is what it says now."), true)
			return
		_dock._set_status(EventSheetL10n.translate("Nothing was tidied."), true)
		return
	_dock._sheet_io._on_save_requested()
	_dock._set_status(EventSheetL10n.counted("1 line tidied and saved. Undo puts the sheet back; the old file is in the sheet backups.",
		"%d lines tidied and saved. Undo puts the sheet back; the old file is in the sheet backups.", count[0]))


func _build_dialog() -> void:
	if _dialog != null:
		return
	var parts: Dictionary = EventSheetPopupUI.panel_window("", Vector2i.ZERO, _dock,
		EventSheetL10n.translate("Apply"), confirm, true)
	_dialog = parts["window"]
	_dialog.cancel_button_text = EventSheetL10n.translate("Cancel")
	var content: VBoxContainer = parts["box"]
	_summary_label = EventSheetPopupUI.hint_label("")
	content.add_child(_summary_label)
	_list = Tree.new()
	_list.hide_root = true
	_list.columns = 1
	_list.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_list.focus_mode = Control.FOCUS_NONE
	_list.custom_minimum_size = Vector2(0.0, EventSheetPalette.scaled_f(300.0))
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(EventSheetPopupUI.titled_card(EventSheetL10n.translate("What will be rewritten"), _list))
	EventSheetL10n.apply_to(_dialog)


func _fill() -> void:
	_dialog.title = EventSheetL10n.translate("Tidy this script")
	_summary_label.text = summary_text(_plan)
	_list.clear()
	var root: TreeItem = _list.create_item()
	for line: String in TIDY.preview_lines(_plan):
		var item: TreeItem = _list.create_item(root)
		item.set_text(0, line)
		item.set_autowrap_mode(0, TextServer.AUTOWRAP_WORD_SMART)
		item.set_tooltip_text(0, line)
	_dialog.get_ok_button().disabled = (_plan["changes"] as Array).is_empty()
