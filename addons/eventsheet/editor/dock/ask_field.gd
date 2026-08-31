@tool
class_name EventSheetAskField
extends RefCounted

# THE QUICK ADD FIELD, TAUGHT TO ANSWER - the dock half of the ask.
#
# EventSheetAskAnswers decides WHAT the answers are, purely and headlessly. This decides what
# happens when one is chosen, which is the half that needs the dock: a state opens the head band's
# own declaration, a row opens the event, a finding opens the sheet the Doctor named. It also builds
# the shelf the answers are joined from - the sheets the reader has open and the findings of the last
# audit - and it does that from what the dock already holds rather than by going and looking.
#
# THE ADD IS STILL THE ADD, and it is still first. The top line of the list is the sentence as typed,
# and choosing it calls the very same `_quick_add` the field's Enter has always called. So a reader
# who types a row and presses Enter gets the row, exactly as before; a reader who arrows down into
# the answers and presses Enter goes somewhere. One field, one Enter, no mode to be in.
#
# THE DOOR FALLS DOWN A STATED LADDER, because an answer a reader cannot follow is half an answer:
# the exact row when the sheet is open and holds it, else the sheet it lives in, else the status line
# saying plainly what could not be reached. Nothing here silently does nothing.
#
# NOTHING IS HELD ACROSS AN EDIT. An answer carries a uid or a name, never a row object: the undo
# funnel replaces every resource in the sheet on every edit, and a list holding the old ones would
# take a reader to a row that no longer exists. The door re-finds what it names in the LIVE sheet at
# the moment it is opened.

## What the add line's own answer is called in the list, so a test can tell it from an answer and
## the door can tell them apart without reading the label.
const KIND_ADD: String = "add"

## And the door out of the Rows group: the Find window, which reaches the sheets this list does not.
const KIND_FIND: String = "find"

var _dock: Control = null


func init(dock: Control) -> void:
	_dock = dock


## Rides the quick-add field with the shipped completion popup - the same list, the same highlight,
## the same Tab/Enter/Escape. The field's own `text_submitted` still runs when nothing in the popup
## is chosen, which is what keeps a typed-and-Entered sentence adding a row.
func attach(field: LineEdit) -> void:
	if field == null:
		return
	EventSheetCompletionPopup.attach_entries(field,
		func(typed: String) -> Array[Dictionary]: return entries(typed))


## The whole list one query draws: the add line, then the answers with their doors attached. Empty
## for an empty field, so a field nobody has typed in shows nothing at all.
func entries(query: String) -> Array[Dictionary]:
	var typed: String = query.strip_edges()
	if typed.is_empty():
		return []
	var list: Array[Dictionary] = [_add_entry(typed)]
	var offered: Array[Dictionary] = EventSheetAskAnswers.answers(typed, shelf())
	var last_row: int = last_of_kind(offered, EventSheetCompletions.KIND_ROW)
	for at: int in range(offered.size()):
		var answer: Dictionary = offered[at]
		if bool(answer.get("heading", false)):
			list.append(answer)
			continue
		var opened: Dictionary = answer.duplicate()
		opened["open"] = func() -> void: open_answer(answer)
		list.append(opened)
		# The Rows group says how far it looked by ENDING in the door to the window that looks
		# further. A boundary stated at the bottom of the group it applies to is a boundary a reader
		# meets at the moment it starts to matter.
		if at == last_row:
			list.append(_find_entry(typed))
	return list


## Where the last answer of one kind sits in the page, or -1 when the page holds none - which is
## where a group's own closing line goes. Headings are not answers and never count as the last one.
static func last_of_kind(page: Array[Dictionary], kind: String) -> int:
	var found: int = -1
	for at: int in range(page.size()):
		if str(page[at].get("kind", "")) == kind and not bool(page[at].get("heading", false)):
			found = at
	return found


## The add line: the sentence as typed, and the door that adds it. Deliberately the FIRST thing in
## the list and deliberately the same call the field's Enter already made - answering is something
## the field does as well, never instead.
func _add_entry(typed: String) -> Dictionary:
	return {
		"text": typed,
		"detail": "%s %s %s" % [EventSheetL10n.translate("Add row"),
			EventSheetCompletions.SEPARATOR,
			EventSheetAskAnswers.home_of(_dock._current_sheet_path, _dock._current_sheet)],
		"kind": KIND_ADD,
		"open": func() -> void: _run_add(typed),
	}


## The Find window, as the last line of the Rows group: the same query, across every sheet in the
## project rather than the ones that happen to be open.
func _find_entry(typed: String) -> Dictionary:
	return {
		"text": EventSheetL10n.translate("Find \"%s\" in every sheet…") % typed,
		"detail": "",
		"kind": KIND_FIND,
		"open": func() -> void:
			_clear_field()
			_dock._open_project_find(typed),
	}


## The add, run exactly as the field's own Enter runs it: the sentence goes in, and the field empties
## only when a row landed.
func _run_add(typed: String) -> void:
	if _dock._quick_add(typed):
		_clear_field()


## What the reader has open, and what the last audit said - the two things the answers are joined
## from. The ACTIVE sheet is first and is read off the dock rather than out of the tab list, because
## the tab entry is only re-stamped when the tab changes and the live sheet is the one being edited.
func shelf() -> Dictionary:
	var sheets: Array = []
	if _dock._current_sheet != null:
		sheets.append({"path": _dock._current_sheet_path, "sheet": _dock._current_sheet})
	for tab: Dictionary in _dock._open_tabs:
		var sheet: EventSheetResource = tab.get("sheet") as EventSheetResource
		if sheet != null and sheet != _dock._current_sheet:
			sheets.append({"path": str(tab.get("path", "")), "sheet": sheet})
	return {"sheets": sheets, "findings": EventSheetProjectOutline.doctor_findings()}


## Goes where an answer points. Every branch either arrives somewhere or says on the status line what
## it could not reach.
func open_answer(answer: Dictionary) -> void:
	_clear_field()
	match str(answer.get("kind", "")):
		EventSheetCompletions.KIND_ROW:
			_open_row(answer)
		EventSheetCompletions.KIND_FINDING:
			_open_finding(answer)
		EventSheetCompletions.KIND_MODE:
			_open_mode(answer)
		_:
			_open_declaration(answer)


## A row: the event itself when a tab holds it, else the sheet it lives in with the Find bar carrying
## the query, which is where a reader would have gone next anyway.
func _open_row(answer: Dictionary) -> void:
	if _dock.reveal_event_row(str(answer.get("uid", ""))):
		return
	if _open_home(answer):
		return
	_dock._set_status(EventSheetL10n.translate("That row is in %s, which is not open.")
		% str(answer.get("home", "")), true)


## A state, a variable, a function or a signal: its own declaration row, in the sheet that declares
## it. Re-found in the LIVE sheet by name, never held.
func _open_declaration(answer: Dictionary) -> void:
	if not _open_home(answer):
		return
	var sheet: EventSheetResource = _dock._current_sheet
	var wanted: Resource = null
	if str(answer.get("kind", "")) == EventSheetCompletions.KIND_STATE:
		wanted = EventSheetStateFacts.enum_row(sheet)
	else:
		var name: String = str(answer.get("symbol", ""))
		for entry: Variant in EventSheetCommandPalette.collect_symbols(sheet):
			if str((entry as Dictionary).get("name", "")) == name:
				wanted = (entry as Dictionary).get("resource") as Resource
				break
	var view: EventSheetViewport = _dock._active_view()
	if wanted != null and view != null and view.reveal_resource(wanted):
		return
	_dock._set_status(EventSheetL10n.translate("%s is declared in %s - opened it, but the row it is on has moved.")
		% [str(answer.get("text", "")), str(answer.get("home", ""))], true)


## A mode: the file that declares the game's Mode enum. The autoloads are read HERE rather than while
## the reader types, because reading them is file access and typing must not be.
func _open_mode(answer: Dictionary) -> void:
	for path: String in EventSheetModeFacts.autoload_scripts():
		if EventSheetModeFacts.members_in_source(FileAccess.get_file_as_string(path)).is_empty():
			continue
		_dock._navigate.record_current()
		_dock._navigate.open_or_focus(path)
		return
	_dock._set_status(EventSheetL10n.translate("%s is a mode of this sheet's own declaration.")
		% str(answer.get("text", "")))


## A finding: the sheet the Doctor named, and the row inside it when the finding named one. The same
## ladder the Doctor's own page walks, so a finding opened from here and one opened from there arrive
## in the same place.
func _open_finding(answer: Dictionary) -> void:
	var path: String = str(answer.get("path", ""))
	if path.is_empty() or not ResourceLoader.exists(path) \
			or (path.get_extension() != "gd" and path.get_extension() != "tres"):
		_dock._set_status(EventSheetL10n.translate("That finding is about %s, which is not a sheet - open it from the FileSystem dock.")
			% (path.get_file() if not path.is_empty() else str(answer.get("home", ""))))
		return
	_dock._navigate.record_current()
	_dock._navigate.open_or_focus(path)
	var uid: String = str((answer.get("finding", {}) as Dictionary).get("uid", ""))
	if not uid.is_empty():
		_dock.reveal_event_row(uid)


## Opens (or focuses) the sheet an answer lives in, and says whether the dock is now showing it. An
## answer about the sheet already open needs no navigation at all.
func _open_home(answer: Dictionary) -> bool:
	var path: String = str(answer.get("path", ""))
	if path.is_empty() or path == _dock._current_sheet_path:
		return true
	_dock._navigate.record_current()
	_dock._navigate.open_or_focus(path)
	return _dock._current_sheet_path == path


## Empties the field, which is what every successful gesture in it does - the add has always cleared
## on success, and arriving somewhere is no less finished than adding a row.
func _clear_field() -> void:
	if _dock._quick_add_edit != null:
		_dock._quick_add_edit.clear()
