# Godot EventSheets - one search that knows what the sheet knows.
#
# The Quick Add field answers as well as adds, and everything worth pinning about that is a VALUE:
# which answers a word produces, what each one is labelled with, which group it lands in, which group
# leads, and - the promise that mattered most - that the add is still the add.
#
# The join itself is pure (EventSheetAskAnswers takes a shelf and a query and returns a page), so
# almost everything here runs with no dock at all. The two things that need one - the add line and
# the doors - are pinned through EventSheetAskField over a fresh editor, without any toolbar.
#
# THE CACHE IS PART OF THE CONTRACT and is therefore pinned rather than assumed: the two new field
# kinds are built once per sheet and only filtered afterwards, which is the only reason a keystroke
# can join six kinds and still land inside a frame. The budget itself lives in
# huge_project_budget_test.gd, beside the other per-keystroke number.
@tool
class_name AskFieldTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")


static func run() -> bool:
	var ok: bool = _test_the_shelf_is_read_as_kinds()
	ok = _test_names_beat_prose() and ok
	ok = _test_the_leading_group_follows_the_best_answer() and ok
	ok = _test_a_group_says_how_much_it_holds() and ok
	ok = _test_findings_are_searchable() and ok
	ok = _test_the_floor() and ok
	ok = _test_the_add_is_still_first() and ok
	ok = _test_the_row_door_names_its_event() and ok
	ok = _test_the_pools_are_built_once() and ok
	ok = _test_find_and_ask_read_one_collection() and ok
	ok = _test_the_popup_opens_a_door() and ok
	ok = _test_headings_are_not_answers() and ok
	return ok


## A sheet with one of everything the field can answer with: three states, a tree variable, a
## function, a signal, and an event whose action carries a piece of text worth finding.
static func _sheet() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.custom_class_name = "Enemy"
	sheet.host_class = "CharacterBody2D"
	var states: EnumRow = EnumRow.new()
	states.enum_name = EventSheetStateFacts.ENUM_NAME
	states.members = PackedStringArray(["PATROL", "CHASE", "STAGGER"])
	sheet.events.append(states)
	var held: LocalVariable = LocalVariable.new()
	held.name = "chase_speed"
	held.type_name = "float"
	sheet.events.append(held)
	var announced: SignalRow = SignalRow.new()
	announced.signal_name = "gave_up"
	sheet.events.append(announced)
	var event_row: EventRow = EventRow.new()
	event_row.event_uid = "ask-row-1"
	var action: ACEAction = ACEAction.new()
	action.ace_id = "SetProperty"
	action.params = {"value": "chase the player harder"}
	event_row.actions.append(action)
	sheet.events.append(event_row)
	var published: EventFunction = EventFunction.new()
	published.function_name = "begin_chase"
	sheet.functions.append(published)
	return sheet


static func _shelf(sheet: EventSheetResource, findings: Array = []) -> Dictionary:
	EventSheetCompletions.clear_cache()
	return {"sheets": [{"path": "res://enemy.gd", "sheet": sheet}], "findings": findings}


## Every answer of one kind in a page, as its text. Headings are not answers.
static func _texts(page: Array[Dictionary], kind: String) -> PackedStringArray:
	var said: PackedStringArray = PackedStringArray()
	for entry: Dictionary in page:
		if str(entry.get("kind", "")) == kind and not bool(entry.get("heading", false)):
			said.append(str(entry.get("text", "")))
	return said


## The kinds a page holds, in the order their groups appear.
static func _groups(page: Array[Dictionary]) -> PackedStringArray:
	var order: PackedStringArray = PackedStringArray()
	for entry: Dictionary in page:
		if bool(entry.get("heading", false)):
			order.append(str(entry.get("kind", "")))
	return order


## One word, read as every kind the sheet can answer it with - and each answer LABELLED with what it
## is and where it lives, which is the whole difference between a list of hits and an answer.
static func _test_the_shelf_is_read_as_kinds() -> bool:
	var page: Array[Dictionary] = EventSheetAskAnswers.answers("chase", _shelf(_sheet()))
	var ok: bool = SUPPORT.pin_table("ask_field", {
		EventSheetCompletions.KIND_STATE: PackedStringArray(["Chase"]),
		EventSheetCompletions.KIND_VARIABLE: PackedStringArray(["chase_speed"]),
		EventSheetCompletions.KIND_FUNCTION: PackedStringArray(["begin_chase"]),
		EventSheetCompletions.KIND_SIGNAL: PackedStringArray(),
		EventSheetCompletions.KIND_ROW: PackedStringArray(["chase the player harder"]),
	}, func(kind: String) -> Variant: return _texts(page, kind))
	var labels: Dictionary = {}
	for entry: Dictionary in page:
		if not bool(entry.get("heading", false)):
			labels[str(entry.get("text", ""))] = str(entry.get("detail", ""))
	ok = SUPPORT.pin_value("ask_field", "the state says its kind and its home",
		str(labels.get("Chase", "")), "State · Enemy") and ok
	ok = SUPPORT.pin_value("ask_field", "and so does the row",
		str(labels.get("chase the player harder", "")), "Row · Enemy") and ok
	return ok


## The law that decides the whole ranking: a word that IS something's name outranks the same word
## found inside a sentence, whatever else the two score.
static func _test_names_beat_prose() -> bool:
	var page: Array[Dictionary] = EventSheetAskAnswers.answers("chase", _shelf(_sheet()))
	var first_name: int = -1
	var first_prose: int = -1
	for at: int in range(page.size()):
		if bool(page[at].get("heading", false)):
			continue
		var kind: String = str(page[at].get("kind", ""))
		if first_prose < 0 and kind == EventSheetCompletions.KIND_ROW:
			first_prose = at
		if first_name < 0 and EventSheetAskAnswers.NAME_KINDS.has(kind):
			first_name = at
	var ok: bool = SUPPORT.pin_value("ask_field", "the first name answer stands above the first prose one",
		first_name >= 0 and first_prose > first_name, true)
	# And it is the band that puts it there rather than the scores happening to fall that way: the
	# weakest name a ranker can report still has to beat the strongest sentence it can.
	return SUPPORT.pin_value("ask_field", "the band clears the ranker's own ceiling",
		EventSheetAskAnswers.NAME_BAND > 1000, true) and ok


## Which group LEADS is decided by the best answer in it, not by a fixed list of what matters. So the
## state's own name leads when a state is named, and the row leads when the words are a row's.
static func _test_the_leading_group_follows_the_best_answer() -> bool:
	var sheet: EventSheetResource = _sheet()
	return SUPPORT.pin_table("ask_field", {
		"chase": EventSheetCompletions.KIND_STATE,
		"player harder": EventSheetCompletions.KIND_ROW,
		"gave": EventSheetCompletions.KIND_SIGNAL,
	}, func(query: String) -> Variant:
		var order: PackedStringArray = _groups(EventSheetAskAnswers.answers(query, _shelf(sheet)))
		return order[0] if not order.is_empty() else "")


## THE BAND SCALE LAW on a list: a group shows a few and SAYS how many it holds. A group whose whole
## contents are on screen says no number, because "3 of 3" is a number nobody learns anything from.
static func _test_a_group_says_how_much_it_holds() -> bool:
	var sheet: EventSheetResource = _sheet()
	for index: int in range(8):
		var event_row: EventRow = EventRow.new()
		event_row.event_uid = "ask-row-fill-%d" % index
		var action: ACEAction = ACEAction.new()
		action.ace_id = "SetProperty"
		action.params = {"value": "chase step %d" % index}
		event_row.actions.append(action)
		sheet.events.append(event_row)
	var page: Array[Dictionary] = EventSheetAskAnswers.answers("chase", _shelf(sheet))
	var headings: Dictionary = {}
	for entry: Dictionary in page:
		if bool(entry.get("heading", false)):
			headings[str(entry.get("kind", ""))] = str(entry.get("text", ""))
	var ok: bool = SUPPORT.pin_value("ask_field", "the capped group says how much of it is shown",
		str(headings.get(EventSheetCompletions.KIND_ROW, "")),
		"Rows - %d of 9" % EventSheetAskAnswers.GROUP_LIMIT)
	ok = SUPPORT.pin_value("ask_field", "a group that fits says only what it is",
		str(headings.get(EventSheetCompletions.KIND_STATE, "")), "States") and ok
	return SUPPORT.pin_value("ask_field", "and the group really is capped at the stated number",
		_texts(page, EventSheetCompletions.KIND_ROW).size(), EventSheetAskAnswers.GROUP_LIMIT) and ok


## The inbox becomes searchable the moment a name crosses the mind - which is the point of putting
## findings here at all. A finding says its SEVERITY rather than the word "finding", because that is
## what a reader is looking at, and it says it in the Doctor's own words.
static func _test_findings_are_searchable() -> bool:
	var findings: Array = [
		{"check": "state-unreachable", "path": "res://enemy.gd", "subject": "STAGGER",
			"severity": "warning", "message": "Nothing ever goes to Stagger."},
		{"check": "state-unreachable", "path": "res://boss.gd", "subject": "PANIC",
			"severity": "error", "message": "Panic is entered but never left."},
	]
	var page: Array[Dictionary] = EventSheetAskAnswers.answers("panic", _shelf(_sheet(), findings))
	var found: Dictionary = {}
	for entry: Dictionary in page:
		if str(entry.get("kind", "")) == EventSheetCompletions.KIND_FINDING \
				and not bool(entry.get("heading", false)):
			found = entry
	var ok: bool = SUPPORT.pin_value("ask_field", "the finding is answered by its own words",
		str(found.get("text", "")), "Panic is entered but never left.")
	ok = SUPPORT.pin_value("ask_field", "labelled with its severity and the file it is about",
		str(found.get("detail", "")), "Error · boss.gd") and ok
	ok = SUPPORT.pin_value("ask_field", "and it carries the path its door needs",
		str(found.get("path", "")), "res://boss.gd") and ok
	# And nothing runs an audit to answer: with no findings recorded there is simply no group.
	ok = SUPPORT.pin_value("ask_field", "no audit means no Findings group",
		_groups(EventSheetAskAnswers.answers("panic", _shelf(_sheet()))).has(
			EventSheetCompletions.KIND_FINDING), false) and ok
	return ok


## One letter matches most of a project and answers nothing, so the field is the add bar it has
## always been until there are two.
static func _test_the_floor() -> bool:
	var sheet: EventSheetResource = _sheet()
	return SUPPORT.pin_table("ask_field", {
		"c": 0,
		"ch": 1,
	}, func(query: String) -> Variant:
		return mini(EventSheetAskAnswers.answers(query, _shelf(sheet)).size(), 1))


## THE PROMISE: answering is additive. The first line of the list is the sentence as typed, so Enter
## on an untouched list runs the add it always ran.
static func _test_the_add_is_still_first() -> bool:
	var dock: EventSheetEditor = EventSheetEditor.new()
	dock._current_sheet = _sheet()
	dock._current_sheet_path = "res://enemy.gd"
	EventSheetCompletions.clear_cache()
	var list: Array[Dictionary] = dock._ask_field.entries("chase")
	var first: Dictionary = list[0] if not list.is_empty() else {}
	var ok: bool = SUPPORT.pin_value("ask_field", "the add line is first",
		str(first.get("kind", "")), EventSheetAskField.KIND_ADD)
	ok = SUPPORT.pin_value("ask_field", "and it is the sentence as typed",
		str(first.get("text", "")), "chase") and ok
	ok = SUPPORT.pin_value("ask_field", "and it says what it will do and where",
		str(first.get("detail", "")), "Add row · Enemy") and ok
	ok = SUPPORT.pin_value("ask_field", "and it is a door, not text to insert",
		first.get("open") is Callable, true) and ok
	# An empty field offers nothing at all - not even the add line, which would be an add of nothing.
	ok = SUPPORT.pin_value("ask_field", "an empty field answers nothing",
		dock._ask_field.entries("   ").size(), 0) and ok
	# And the Rows group ends in the door to the window that reaches the sheets this list does not.
	var rows_end: int = EventSheetAskField.last_of_kind(list, EventSheetCompletions.KIND_ROW)
	ok = SUPPORT.pin_value("ask_field", "the Rows group ends in the project-wide door",
		str(list[rows_end + 1].get("kind", "")) if rows_end >= 0 and rows_end + 1 < list.size() else "",
		EventSheetAskField.KIND_FIND) and ok
	dock.free()
	return ok


## A row answer carries the EVENT it lives in, which is what makes it a door rather than a report -
## and text that lives outside an event honestly carries nothing.
static func _test_the_row_door_names_its_event() -> bool:
	var sheet: EventSheetResource = _sheet()
	var loose: CommentRow = CommentRow.new()
	loose.text = "chase notes for later"
	sheet.events.append(loose)
	var page: Array[Dictionary] = EventSheetAskAnswers.answers("chase", _shelf(sheet))
	var by_text: Dictionary = {}
	for entry: Dictionary in page:
		by_text[str(entry.get("text", ""))] = str(entry.get("uid", ""))
	var ok: bool = SUPPORT.pin_value("ask_field", "the row inside an event names it",
		str(by_text.get("chase the player harder", "!")), "ask-row-1")
	return SUPPORT.pin_value("ask_field", "the comment outside one names nothing",
		str(by_text.get("chase notes for later", "!")), "") and ok


## The cache contract, which is the only reason a keystroke can join six kinds: each new kind is
## BUILT once per sheet and filtered afterwards, and a sheet the funnel replaced is read again.
static func _test_the_pools_are_built_once() -> bool:
	var sheet: EventSheetResource = _sheet()
	EventSheetCompletions.clear_cache()
	var first: Array[Dictionary] = EventSheetCompletions.candidates(sheet,
		EventSheetCompletions.FIELD_ASK_ROW)
	var again: Array[Dictionary] = EventSheetCompletions.candidates(sheet,
		EventSheetCompletions.FIELD_ASK_ROW)
	# Identity rather than equality: two equal lists would still mean the sheet was walked twice.
	var ok: bool = SUPPORT.pin_value("ask_field", "the second ask is the SAME list, not an equal one",
		is_same(first, again), true)
	ok = SUPPORT.pin_value("ask_field", "a symbol pool carries the states as words, then the names",
		_symbol_texts(sheet), PackedStringArray(["Patrol", "Chase", "Stagger",
			"begin_chase", "chase_speed", "gave_up"])) and ok
	# Every entry carries its own lowered text, which is what keeps a keystroke off the allocator.
	var lowered: bool = true
	for entry: Dictionary in EventSheetCompletions.candidates(sheet,
			EventSheetCompletions.FIELD_ASK_ROW):
		if not entry.has("lower"):
			lowered = false
	ok = SUPPORT.pin_value("ask_field", "and every row candidate is pre-lowered", lowered, true) and ok
	return ok


static func _symbol_texts(sheet: EventSheetResource) -> PackedStringArray:
	var said: PackedStringArray = PackedStringArray()
	for entry: Dictionary in EventSheetCompletions.candidates(sheet,
			EventSheetCompletions.FIELD_ASK_SYMBOL):
		said.append(str(entry.get("text", "")))
	return said


## The field and the Find window look at the sheet through the same eyes. If they did not, the field
## would offer rows the window swears are not there.
static func _test_find_and_ask_read_one_collection() -> bool:
	var sheet: EventSheetResource = _sheet()
	EventSheetCompletions.clear_cache()
	var found: Array = EventSheetProjectFind.find_in_sheet(sheet, "chase")
	var asked: PackedStringArray = _texts(EventSheetAskAnswers.answers("chase", _shelf(sheet)),
		EventSheetCompletions.KIND_ROW)
	var ok: bool = SUPPORT.pin_value("ask_field", "the window finds the row", found.size(), 1)
	ok = SUPPORT.pin_value("ask_field", "the field answers with it", asked.size(), 1) and ok
	return SUPPORT.pin_value("ask_field", "and the window now names the event too",
		str((found[0] as Dictionary).get("uid", "")) if not found.is_empty() else "",
		"ask-row-1") and ok


## The popup's own half: an entry carrying a door RUNS it rather than writing anything into the
## field, so one keyboard model covers completing and answering both.
static func _test_the_popup_opens_a_door() -> bool:
	var field: LineEdit = LineEdit.new()
	var opened: Dictionary = {"count": 0}
	var popup: EventSheetCompletionPopup = EventSheetCompletionPopup.attach_entries(field,
		func(_typed: String) -> Array[Dictionary]: return [
			{"text": "Chase", "detail": "State · Enemy", "kind": "state",
				"open": func() -> void: opened["count"] = int(opened["count"]) + 1}])
	popup.entries = popup._ask("chase")
	popup.index = 0
	field.text = "chase"
	var ok: bool = SUPPORT.pin_value("ask_field", "accepting a door runs it", popup.accept(), true)
	ok = SUPPORT.pin_value("ask_field", "and writes nothing into the field", field.text, "chase") and ok
	ok = SUPPORT.pin_value("ask_field", "and it ran exactly once", int(opened["count"]), 1) and ok
	field.free()
	return ok


## A heading is a place-marker, not an answer: the highlight steps over it and accepting it does
## nothing, so a group's own title can never be a door to nowhere.
static func _test_headings_are_not_answers() -> bool:
	var field: LineEdit = LineEdit.new()
	var popup: EventSheetCompletionPopup = EventSheetCompletionPopup.attach_entries(field,
		func(_typed: String) -> Array[Dictionary]: return [
			{"text": "States", "detail": "", "kind": "state", "heading": true},
			{"text": "Chase", "detail": "", "kind": "state"},
			{"text": "Rows", "detail": "", "kind": "row", "heading": true},
			{"text": "chase harder", "detail": "", "kind": "row"}])
	popup.refresh("chase")
	var landed: int = popup.index
	popup.move(1)
	var stepped: int = popup.index
	popup.move(1)
	var wrapped: int = popup.index
	var ok: bool = SUPPORT.pin_value("ask_field",
		"the highlight lands on the first answer, not the heading", landed, 1)
	ok = SUPPORT.pin_value("ask_field", "and Down steps over the next heading", stepped, 3) and ok
	ok = SUPPORT.pin_value("ask_field", "and wraps back to the first answer", wrapped, 1) and ok
	popup.index = 0
	popup.entries[0] = {"text": "States", "detail": "", "kind": "state", "heading": true}
	ok = SUPPORT.pin_value("ask_field", "accepting a heading does nothing at all",
		popup.accept(), false) and ok
	field.free()
	return ok
