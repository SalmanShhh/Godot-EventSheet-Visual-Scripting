# Godot EventSheets - RENAME, with everything it touches listed before it touches any of it.
#
# A function's own head row offers Rename, and the first thing the reader sees is not a text field
# with an OK button: it is the list. Every row of this sheet that calls the name, as the words it
# says now beside the words it would say. Every other file in the project that calls it by that name,
# named, counted, and marked as one this will not touch. Only then the button.
#
# NEVER ON OPEN, NEVER ON SAVE. Nothing here happens by itself. A rename is one edit a person
# approved after reading what it would do, applied through the sheet's own undo funnel, so one
# Ctrl+Z puts the whole of it back.
#
# WHAT IT WILL NOT TOUCH, AND WHY IT SAYS SO. The callers index answers BY NAME: a file listed here
# may be calling a different function that happens to share the spelling, and the index cannot tell.
# Being plainly approximate about who calls something costs a reader one glance; being quietly wrong
# about it costs them a broken game. So other files are listed with their counts and left exactly as
# they are, and the receipt says which ones under their own heading rather than in a note afterwards.
# A rename that claimed "6 rows in 3 sheets" and touched four would be worse than saying nothing.
#
# AND WHAT IT WILL WRITE OUTSIDE THIS SHEET, under its own heading too. A sheet that INCLUDES this
# one is rewritten and SAVED by the shipped includers pass - a closed file, written to disk, outside
# the one Ctrl+Z the status line promises. Those files used to be reported only afterwards, which is
# the same defect as the counts above with the sign reversed: the receipt listed less than the button
# touched. They are named before the button exists, and the sentence says they are saved rather than
# undone.
#
# THE SECOND GESTURE IT DRAWS is the door under an outside rename: a row whose name was renamed out
# from under it, and the file's own last save proving what the name became. Same receipt, same
# funnel, same rule that what is shown is what lands - which is why it is this file and not a second
# one that draws it.
#
# The receipt builders are STATIC AND PURE, so the words a reader is shown are pinned by the suite
# rather than assumed.
@tool
class_name EventSheetRenameReceipt
extends RefCounted

var _dock: Node = null
var _dialog: AcceptDialog = null
var _name_edit: LineEdit = null
var _summary_label: Label = null
var _rows_list: ItemList = null
var _elsewhere_card: Control = null
var _elsewhere_list: ItemList = null
var _old_name: String = ""
## The other files that call this name, read ONCE when the dialog opens rather than per keystroke -
## the walk imports every project script that mentions the word, which is not a thing to do while
## somebody is typing.
var _elsewhere: Array[Dictionary] = []
## The outside-rename door's finding, held only while its own confirm is open.
var _finding: Dictionary = {}
## The sheets that INCLUDE this one and say the name - the files the button will rewrite and save.
## Re-read whenever the typed name changes, because a name nothing over there says is a file this
## will not write.
var _includers: PackedStringArray = PackedStringArray()
var _includers_card: Control = null
var _includers_list: ItemList = null


func init(dock: Node) -> void:
	_dock = dock


## Opens Rename over one of this sheet's functions. Nothing is changed until the button.
func open(function_name: String) -> void:
	if _dock == null or _dock._current_sheet == null:
		return
	_old_name = function_name.strip_edges()
	if _old_name.is_empty():
		return
	_finding = {}
	_elsewhere = elsewhere_for(_old_name, str(_dock._current_sheet_path))
	_build_dialog()
	_name_edit.editable = true
	_name_edit.text = _old_name
	_fill()
	if _dock.is_inside_tree():
		_dialog.popup_centered(Vector2i(720, 480))
		_name_edit.grab_focus()
		_name_edit.select_all()


## Opens the same receipt for an outside rename the file itself proved - the door under a row whose
## name went away while somebody was renaming it somewhere else. The new name is not typed here: it
## is what the save said, and a field the reader could edit would turn evidence back into a guess.
func open_for_finding(finding: Dictionary) -> void:
	if _dock == null or _dock._current_sheet == null:
		return
	_finding = finding
	_old_name = str(finding.get("subject", ""))
	_elsewhere = []
	_build_dialog()
	_name_edit.text = str(finding.get("to", ""))
	_name_edit.editable = false
	_fill()
	if _dock.is_inside_tree():
		_dialog.popup_centered(Vector2i(720, 420))


## Every row of one sheet that says `old_name`, as the words it says now beside the words it would
## say. Two lines never merge into one: a receipt whose rows are counted but not shown is a count.
static func row_lines(sheet: EventSheetResource, old_name: String,
		new_name: String) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	if sheet == null or old_name.strip_edges().is_empty():
		return lines
	for reference: Dictionary in EventSheetFindReferences.find_in_sheet(sheet, old_name):
		var before: String = str(reference.get("preview", "")).strip_edges()
		if before.is_empty():
			continue
		lines.append("%s → %s" % [before,
			EventSheetRefactor.rename_in_code(before, old_name, new_name)])
	return lines


## The node half of the same receipt: the reference as the rows write it, the reference they would
## write, and how many of them there are.
##
## Counted BY DOING IT, on a throwaway copy of the sheet, through the very function the button runs.
## A count worked out any other way is a second implementation of the rewrite, and a receipt that
## promised four rows while the button moved five would be the version of this feature nobody trusts.
static func node_lines(sheet: EventSheetResource, from_reference: String,
		to_reference: String) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	if sheet == null or from_reference.is_empty() or to_reference.is_empty():
		return lines
	var copy: EventSheetResource = sheet.duplicate(true)
	if copy == null:
		return lines
	var moved: int = EventSheetRefactor.replace_node_reference(copy.events, from_reference,
		to_reference)
	for entry: Variant in copy.functions:
		var event_function: EventFunction = entry as EventFunction
		if event_function != null:
			moved += EventSheetRefactor.replace_node_reference(
				event_function.events if not event_function.events.is_empty()
					else event_function.rows, from_reference, to_reference)
	for _hit: int in moved:
		lines.append("%s → %s" % [from_reference, to_reference])
	return lines


## The other files that call this name, each with how many of their rows do - listed and left. Sorted
## by path, so two machines draw the same receipt. The sheet being renamed is left out of its own
## list: "this file uses it" is not news to the person renaming it.
static func elsewhere_for(old_name: String, own_path: String) -> Array[Dictionary]:
	var others: Array[Dictionary] = []
	for entry: Dictionary in EventSheetFindReferences.find_in_project_rows(old_name):
		var path: String = str(entry.get("sheet", ""))
		if path.is_empty() or path == own_path:
			continue
		others.append({"path": path, "count": int(entry.get("count", 0))})
	others.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return str(left["path"]) < str(right["path"]))
	return others


## The list under "Named and left exactly as they are" - one line per other file, with the reason it
## is not being rewritten said once at the top of the card rather than repeated on every line.
static func elsewhere_lines(others: Array[Dictionary]) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	for entry: Dictionary in others:
		lines.append(EventSheetL10n.translate("%s - %d row(s)") % [
			str(entry["path"]).get_file(), int(entry["count"])])
	return lines


## The list under "Also written, and saved" - one line per sheet that includes this one and says the
## name. These are the files the button writes OUTSIDE this sheet's undo step, so they are named
## rather than counted.
static func includer_lines(includers: PackedStringArray) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	for path: String in includers:
		lines.append(path.get_file())
	return lines


## The one sentence above the lists: who calls this name, how much of it moves, and what is written
## outside this sheet. It leads with the files because that is the fact a reader is deciding on -
## "am I about to break enemy.gd" - and it ends with the part that is not about undo, because a
## closed sheet this rewrites is saved to disk and Ctrl+Z here does not reach it.
static func summary_text(here: int, others: Array[Dictionary],
		includers: PackedStringArray = PackedStringArray()) -> String:
	var written: String = "" if includers.is_empty() \
		else EventSheetL10n.translate(" %d sheet(s) that include this one are rewritten and SAVED, which one Ctrl+Z here does not undo.") % includers.size()
	if others.is_empty():
		return EventSheetL10n.translate("%d row(s) in this sheet, and nothing else in the project calls it by that name.") % here + written
	var names: PackedStringArray = PackedStringArray()
	var rows: int = 0
	for entry: Dictionary in others:
		names.append(str(entry["path"]).get_file())
		rows += int(entry["count"])
	return EventSheetL10n.translate("Called by %s - %d row(s) in %d other file(s). This rewrites the %d row(s) in this sheet and leaves those exactly as they are.") % [
		" · ".join(names), rows, others.size(), here] + written


## THE EDIT. One undoable step over this sheet - the declaration and every row that says the name -
## and then the shipped includers pass, which rewrites and saves the closed sheets that include this
## one. Nothing outside those is touched, which is what the receipt said before the button existed.
func confirm() -> void:
	if _dock == null or _dock._current_sheet == null:
		return
	var new_name: String = _name_edit.text.strip_edges()
	if _is_node_gesture():
		_point_the_nodes(new_name)
		return
	var problem: String = EventSheetRefactor.validate_new_name(_dock._current_sheet, _old_name,
		new_name)
	if not problem.is_empty():
		_dock._set_status(problem, true)
		return
	var moved: Array[int] = [0]
	if not _dock._perform_undoable_sheet_edit(
			EventSheetL10n.translate("Rename %s") % _old_name, func() -> bool:
				moved[0] = EventSheetRefactor.rename_symbol(_dock._current_sheet, _old_name,
					new_name)
				return moved[0] > 0):
		_dock._set_status(EventSheetL10n.translate("\"%s\" appears nowhere in this sheet.")
			% _old_name, true)
		return
	var touched: PackedStringArray = PackedStringArray()
	if not str(_dock._current_sheet_path).is_empty():
		touched = _dock._rename.rename_in_includers(_old_name, new_name,
			EventSheetProjectFind.list_project_sheets())
	_dock._refresh_title_strip()
	_dock._set_status(EventSheetL10n.translate("%d row(s) renamed - one Ctrl+Z takes all of it back.%s") % [
		moved[0], EventSheetL10n.translate(" Also written: %s.") % ", ".join(touched) \
			if not touched.is_empty() else ""])


## The node half of the same button: every row of this sheet that reaches the old node, pointed at
## the new one in one undoable step. It goes through the refactor core's token-safe replace, so
## `$Torch` never touches `$TorchHolder`.
func _point_the_nodes(new_reference: String) -> void:
	var moved: Array[int] = [0]
	if not _dock._perform_undoable_sheet_edit(
			EventSheetL10n.translate("Point rows at %s") % new_reference, func() -> bool:
				moved[0] = EventSheetRefactor.replace_node_reference(
					_dock._current_sheet.events, _old_name, new_reference)
				for entry: Variant in _dock._current_sheet.functions:
					var event_function: EventFunction = entry as EventFunction
					if event_function != null:
						moved[0] += EventSheetRefactor.replace_node_reference(
							event_function.events if not event_function.events.is_empty()
								else event_function.rows, _old_name, new_reference)
				return moved[0] > 0):
		_dock._set_status(EventSheetL10n.translate("\"%s\" appears nowhere in this sheet.")
			% _old_name, true)
		return
	_dock._set_status(EventSheetL10n.translate("%d row(s) renamed - one Ctrl+Z takes all of it back.")
		% moved[0])


## One list, sized so several rows read at once without the dialog growing past a screen. The second
## list is the shorter one on purpose: it is what is NOT moving, and giving it the same height as the
## first would draw a rename's exceptions as big as its work.
func _list(rows_high: float) -> ItemList:
	var list: ItemList = ItemList.new()
	list.custom_minimum_size = Vector2(0.0, EventSheetPalette.scaled_f(rows_high))
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return list


func _build_dialog() -> void:
	if _dialog != null:
		return
	_dialog = AcceptDialog.new()
	_dialog.ok_button_text = EventSheetL10n.translate("Rename")
	_dialog.add_cancel_button(EventSheetL10n.translate("Cancel"))
	_dialog.confirmed.connect(confirm)
	var content: VBoxContainer = EventSheetPopupUI.form_box()
	_name_edit = LineEdit.new()
	_name_edit.text_changed.connect(func(_text: String) -> void: _fill())
	content.add_child(EventSheetPopupUI.form_row(EventSheetL10n.translate("New name"), _name_edit))
	_summary_label = EventSheetPopupUI.hint_label("")
	content.add_child(_summary_label)
	_rows_list = _list(170.0)
	content.add_child(EventSheetPopupUI.titled_card(EventSheetL10n.translate("What will be rewritten"), _rows_list))
	_elsewhere_list = _list(90.0)
	_elsewhere_card = EventSheetPopupUI.titled_card(
		EventSheetL10n.translate("Named and left exactly as they are - the index answers by name, so a file here may be calling something else"),
		_elsewhere_list)
	content.add_child(_elsewhere_card)
	_includers_list = _list(60.0)
	_includers_card = EventSheetPopupUI.titled_card(
		EventSheetL10n.translate("Also written, and saved - these sheets include this one, so Ctrl+Z here does not undo them"),
		_includers_list)
	content.add_child(_includers_card)
	_dialog.add_child(EventSheetPopupUI.margined(content))
	EventSheetL10n.apply_to(_dialog)
	_dock.add_child(_dialog)


## Draws the receipt for the name currently typed. What is shown is what would land: the list and the
## button read the same sheet and the same two names.
func _fill() -> void:
	_dialog.title = EventSheetL10n.translate("Rename %s") % _old_name
	var new_name: String = _name_edit.text.strip_edges()
	var lines: PackedStringArray = node_lines(_dock._current_sheet, _old_name, new_name) \
		if _is_node_gesture() else row_lines(_dock._current_sheet, _old_name, new_name)
	_rows_list.clear()
	for line: String in lines:
		_rows_list.add_item(line)
		# A long sentence is wider than the list; the tooltip carries the whole of it so nothing the
		# receipt promises to say is only half-said.
		_rows_list.set_item_tooltip(_rows_list.item_count - 1, line)
	_elsewhere_list.clear()
	for line: String in elsewhere_lines(_elsewhere):
		_elsewhere_list.add_item(line)
		_elsewhere_list.set_item_tooltip(_elsewhere_list.item_count - 1, line)
	# A card with nothing under it is a heading saying a project has callers it does not have.
	_elsewhere_card.visible = _elsewhere_list.item_count > 0
	# Worked out per NAME rather than once: a name nothing over there says is a file this will not
	# write, and a card listing it anyway would be a receipt for an edit that does not happen.
	_includers = PackedStringArray() if _is_node_gesture() or new_name.is_empty() \
			or str(_dock._current_sheet_path).is_empty() \
		else _dock._rename.includers_of(_old_name, new_name,
			EventSheetProjectFind.list_project_sheets())
	draw_includers(_includers)
	_summary_label.text = summary_text(lines.size(), _elsewhere, _includers)
	# A node reference is not an identifier, so the identifier rules are not the ones that decide it:
	# what makes that gesture legal is the evidence behind it, which was decided before the door
	# appeared. Only a typed rename is held to the sheet's own naming rules.
	if _is_node_gesture():
		_dialog.get_ok_button().disabled = new_name.is_empty()
		return
	var problem: String = EventSheetRefactor.validate_new_name(_dock._current_sheet, _old_name,
		new_name)
	_dialog.get_ok_button().disabled = not problem.is_empty()


## Draws the third card from a list of paths. Separate from the walk that finds them so the suite and
## the preview can put a known list in front of the reader without a project behind it.
func draw_includers(paths: PackedStringArray) -> void:
	_includers = paths
	_includers_list.clear()
	for line: String in includer_lines(_includers):
		_includers_list.add_item(line)
		_includers_list.set_item_tooltip(_includers_list.item_count - 1, line)
	_includers_card.visible = _includers_list.item_count > 0


## True while this dialog is drawing the node half of the outside-rename door - the one gesture whose
## "name" is a `$Path` or a `%Name` rather than an identifier.
func _is_node_gesture() -> bool:
	return str(_finding.get("kind", "")) == EventSheetRenameFindings.KIND_NODE_GONE
