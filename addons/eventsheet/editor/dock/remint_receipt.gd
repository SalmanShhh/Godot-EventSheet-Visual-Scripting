# Godot EventSheets - RE-MINT, with the eight digits shown before any of them move.
#
# A merge can bring in two rows that each declare the same baked local, and Godot refuses to parse
# the file that results. The repair is small - one of the two rows gets a name of its own, drawn
# against the project so the fix cannot introduce the next collision - but it is still an EDIT, and
# every edit in this pass shows what it would do before it does it. The Doctor's chip used to make
# this one on the click and report it afterwards, which is a report rather than a receipt.
#
# WHAT IS SHOWN IS EXACTLY WHAT LANDS, down to the digits. The new name is minted ONCE, while the
# receipt is being drawn, and the button replays those same tokens rather than drawing fresh ones -
# a receipt promising `__peer_9c41f0a2` and a button writing `__peer_51ba77d3` would be a receipt
# about a different edit.
#
# NOTHING ELSE MOVES. Both rows go on saying exactly what they said and compiling to the same work;
# the only thing that changes is eight hex digits in a name no reader ever types. It is an ordinary
# undoable sheet edit - one step through the funnel, one line in the History panel, Ctrl+Z puts it
# back - and it only ever reaches the sheet in front of the reader.
@tool
class_name EventSheetRemintReceipt
extends RefCounted

var _dock: Node = null
var _dialog: AcceptDialog = null
var _summary_label: Label = null
var _rows_list: ItemList = null
var _token: String = ""
## The names this receipt drew, in the order the edit will use them. Held so the button writes the
## digits the reader read rather than a second draw of its own.
var _minted: PackedStringArray = PackedStringArray()
var _drawn: Array[Dictionary] = []


func init(dock: Node) -> void:
	_dock = dock


## Opens the receipt for one doubled token in the sheet in front of the reader. Returns false when
## this sheet does not declare that token twice, so the caller can say where the gesture lives
## instead of showing an empty window. Nothing is changed until the button.
func open(token: String) -> bool:
	if _dock == null or _dock._current_sheet == null or token.strip_edges().is_empty():
		return false
	_token = token.strip_edges()
	_minted = PackedStringArray()
	_drawn = plan(_dock._current_sheet, _token, _minter())
	if _drawn.is_empty():
		return false
	_build_dialog()
	_fill()
	if _dock.is_inside_tree():
		_dialog.popup_centered(Vector2i(560, 320))
	return true


## What the re-mint would do, worked out ON A COPY so asking never touches the sheet the reader is
## looking at. Each entry is `EventSheetLocalTokens.remint`'s own receipt - {before, after, fields} -
## which is what makes this the same answer the edit produces rather than a second implementation of
## it. Static and pure over its arguments, so the suite reads the words without a window.
static func plan(sheet: EventSheetResource, token: String, minter: Callable) -> Array[Dictionary]:
	var copy: EventSheetResource = sheet.duplicate(true) if sheet != null else null
	if copy == null:
		return []
	return EventSheetLocalTokens.remint(copy, token, minter)


## The receipt's lines, one per row that gets a name of its own: the name it declares now beside the
## name it would declare, and how many of its baked fields carry it.
static func receipt_lines(drawn: Array[Dictionary]) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	for entry: Dictionary in drawn:
		lines.append(EventSheetL10n.translate("%s → %s (%d field(s) in this row)") % [
			str(entry.get("before", "")), str(entry.get("after", "")),
			int(entry.get("fields", 0))])
	return lines


## The sentence above the list: what is being repaired, and what is deliberately not.
static func summary_text(token: String, drawn: Array[Dictionary]) -> String:
	return EventSheetL10n.translate("Two rows in this sheet declare __%s, which is a file Godot will not parse. The %d row(s) below get a name of their own. Both rows go on saying exactly what they say, and one Ctrl+Z puts the name back.") % [
		token, drawn.size()]


## THE EDIT. One undo step through the funnel every other mutation takes, writing the very names the
## receipt above showed - the minter replays what it drew rather than drawing again.
func confirm() -> void:
	if _dock == null or _dock._current_sheet == null or _drawn.is_empty():
		return
	var receipts: Array = []
	var minter: Callable = _minter()
	if not bool(_dock.call("_perform_undoable_sheet_edit",
			EventSheetL10n.translate("Re-mint duplicated local"),
			func() -> bool:
				receipts.assign(EventSheetLocalTokens.remint(_dock._current_sheet, _token, minter))
				return not receipts.is_empty())) or receipts.is_empty():
		_dock._set_status(EventSheetL10n.translate("Nothing in the open sheet declares __%s twice any more - the other copy may already have been re-minted.") % _token, true)
		return
	var first: Dictionary = receipts[0]
	_dock._set_status(EventSheetL10n.translate("%s is now %s in this sheet - both rows read exactly as they did, and Ctrl+Z puts the name back.") % [
		str(first.get("before", "")), str(first.get("after", ""))])


## The one mint this gesture uses: it draws a fresh token the first time each name is needed and
## HANDS BACK THE SAME ONE afterwards. Drawing is what makes the repair safe (the new name is drawn
## against the whole project, so it cannot be the next collision); replaying is what makes the
## receipt true.
func _minter() -> Callable:
	var next: Array[int] = [0]
	return func() -> String:
		if next[0] < _minted.size():
			var held: String = _minted[next[0]]
			next[0] += 1
			return held
		var fresh: String = str(EventSheetDock._fresh_uid_token())
		_minted.append(fresh)
		next[0] += 1
		return fresh


func _build_dialog() -> void:
	if _dialog != null:
		return
	_dialog = AcceptDialog.new()
	_dialog.title = EventSheetL10n.translate("Re-mint duplicated local")
	_dialog.ok_button_text = EventSheetL10n.translate("Re-mint It")
	_dialog.add_cancel_button(EventSheetL10n.translate("Cancel"))
	_dialog.confirmed.connect(confirm)
	var content: VBoxContainer = EventSheetPopupUI.form_box()
	_summary_label = EventSheetPopupUI.hint_label("")
	content.add_child(_summary_label)
	_rows_list = ItemList.new()
	_rows_list.custom_minimum_size = Vector2(0.0, EventSheetPalette.scaled_f(110.0))
	_rows_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(EventSheetPopupUI.titled_card(
		EventSheetL10n.translate("What will be renamed"), _rows_list))
	_dialog.add_child(EventSheetPopupUI.margined(content))
	EventSheetL10n.apply_to(_dialog)
	_dock.add_child(_dialog)


func _fill() -> void:
	_dialog.title = EventSheetL10n.translate("Re-mint duplicated local")
	_summary_label.text = summary_text(_token, _drawn)
	_rows_list.clear()
	for line: String in receipt_lines(_drawn):
		_rows_list.add_item(line)
		_rows_list.set_item_tooltip(_rows_list.item_count - 1, line)
