# Godot EventSheets - the States window: one object's states, declared once.
#
# Double-click the state row (or choose Declare states) and this opens as "States of <variable>": what the
# machine is for, then its states in order - each with a name, a sentence and a radio that says which one
# the object starts in - and the doors to add, remove, reorder and rename them. A rename is a rename
# EVERYWHERE: every row, trigger and hand-written line of the sheet that said the old name says the new
# one in the same edit.
#
# What it writes is the whole point of it: ORDINARY DECLARATIONS the author could have typed, and which a
# hand-written object usually has typed already -
#
#     ## What the player is doing: standing, running or in the air.
#     enum State {
#         ## Standing still on the floor.
#         IDLE,
#         RUN,
#     }
#     var state: State = State.IDLE      (with the setter that announces the change)
#     signal state_changed(from_state: int, to_state: int)
#     var previous_state: State = State.IDLE
#     var state_entered_msec: int = Time.get_ticks_msec()
#
# Nothing is stored anywhere else, nothing is hidden from the code, and everything it writes is a line a
# reader can see, edit and delete - which is what makes the feature survive uninstalling the plugin, and
# what makes an object that wrote them by hand already have it. The sentences are `##` lines, so Godot's
# own help shows them too.
#
# ONE DECLARATION IS ONE MACHINE. A second machine on the same object is a second declared state
# variable, written by hand the same way this writes the first - there is no "add machine" concept to
# learn, because a machine was never a thing here; it is an enum and a variable.
#
# THE SAME DIALOG FAMILY AS THE GAME'S MODES: Edit modes (`modes_dialog.gd`) asks the identical two
# questions - the names, and the one it starts in - for the game's own machine. This asks them for an
# object's. It asks no third question: what a state DOES is the rows the author puts under On entering.
@tool
class_name EventSheetStatesDialog
extends RefCounted

## The machine's own rows of this window, kept apart from the sheet until Apply: {"orig", "name", "note"}
## per state. `orig` is the member the state is on the sheet now ("" for one added in this window), which
## is how a rename is told from a removal plus an addition.
var _entries: Array = []
var _description: String = ""
var _default_index: int = 0

var _dock: Control = null
var _dialog: ConfirmationDialog = null
var _description_edit: LineEdit = null
var _list: VBoxContainer = null
var _code: Label = null
var _problem_label: EventSheetPopupUI.StateNote = null
var _radio_group: ButtonGroup = null


func init(dock: Control) -> void:
	_dock = dock


## Opens the window on this sheet's machine, or on a first set for a sheet that has none - three states
## an object usually grows, which the author is free to rewrite before Apply.
func open() -> void:
	var sheet: EventSheetResource = _dock._current_sheet
	if sheet == null:
		return
	_build()
	var model: Dictionary = model_of(sheet)
	_entries = model["states"]
	_description = str(model["description"])
	_default_index = int(model["default"])
	_dialog.title = EventSheetL10n.translate("States of %s") % EventSheetStateFacts.STATE_VARIABLE
	_description_edit.text = _description
	_problem_label.say("")
	_rebuild_list()
	EventSheetPopupUI.popup_fitted(_dialog, Vector2i(620, 480))


func _build() -> void:
	if _dialog != null:
		return
	# EVERY WORD IN HERE IS KEYED, chrome included. A refusal keeps the window open on what was typed, so
	# the fix is one edit rather than a re-entry.
	var parts: Dictionary = EventSheetPopupUI.panel_window(EventSheetL10n.translate("States"),
		Vector2i(620, 420), _dock, EventSheetL10n.translate("Apply"), _on_confirmed)
	_dialog = parts["window"]
	var form: VBoxContainer = parts["box"]

	_description_edit = LineEdit.new()
	_description_edit.name = "StatesDescription"
	_description_edit.placeholder_text = EventSheetL10n.translate("What the player is doing: standing, running or in the air.")
	_description_edit.text_changed.connect(func(text: String) -> void:
		_description = text
		_show_code())
	form.add_child(EventSheetPopupUI.form_row(EventSheetL10n.translate("What it is for"), _description_edit))
	EventSheets.attach_completions(_description_edit, EventSheetCompletions.FIELD_STATE_NOTE)

	form.add_child(EventSheetPopupUI.section_header(EventSheetL10n.translate("States")))
	_list = VBoxContainer.new()
	_list.name = "StatesList"
	_list.add_theme_constant_override("separation", 4)
	form.add_child(_list)

	var add: Button = Button.new()
	add.name = "AddState"
	add.flat = true
	add.alignment = HORIZONTAL_ALIGNMENT_LEFT
	add.text = EventSheetL10n.translate("+ Add a state")
	add.pressed.connect(_on_add_pressed)
	form.add_child(add)

	_problem_label = EventSheetPopupUI.StateNote.new(520.0)
	form.add_child(_problem_label)

	form.add_child(EventSheetPopupUI.hint_label(EventSheetL10n.translate("There is always exactly one default: a new machine takes its first state, and removing the default moves it to the next. Each description is written as a ## line above the state in the enum, so Godot's own help shows it too. Renaming a state renames it in every row of the sheet; a state that rows still use cannot be removed until they stop.")))

	_code = Label.new()
	_code.name = "StatesCode"
	_code.add_theme_font_override("font", EventSheetPopupUI.editor_font("source"))
	_code.add_theme_color_override("font_color", EventSheetPopupUI.secondary_text_color())
	form.add_child(EventSheetPopupUI.panel_section(_code))


## The list of state rows, rebuilt from the working copy. One row per state: the reorder doors, the name,
## the sentence, the default radio, how many rows use it, and the door to remove it.
func _rebuild_list() -> void:
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	_radio_group = ButtonGroup.new()
	var counts: Dictionary = EventSheetStateFacts.naming_counts(_dock._current_sheet)
	for index: int in _entries.size():
		_list.add_child(_state_row(index, counts))
	_show_code()


func _state_row(index: int, counts: Dictionary) -> Control:
	var entry: Dictionary = _entries[index]
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "State%d" % index
	row.add_theme_constant_override("separation", 6)

	var up: Button = Button.new()
	up.name = "Up"
	up.flat = true
	up.text = "▲"
	up.tooltip_text = EventSheetL10n.translate("Move up")
	up.disabled = index == 0
	up.pressed.connect(_move.bind(index, -1))
	row.add_child(up)
	var down: Button = Button.new()
	down.name = "Down"
	down.flat = true
	down.text = "▼"
	down.tooltip_text = EventSheetL10n.translate("Move down")
	down.disabled = index == _entries.size() - 1
	down.pressed.connect(_move.bind(index, 1))
	row.add_child(down)

	var name_edit: LineEdit = LineEdit.new()
	name_edit.name = "Name"
	name_edit.custom_minimum_size.x = 130.0
	name_edit.text = str(entry["name"])
	name_edit.add_theme_font_override("font", EventSheetPopupUI.editor_font("source"))
	name_edit.text_changed.connect(func(text: String) -> void:
		(_entries[index] as Dictionary)["name"] = text.strip_edges()
		_show_code())
	row.add_child(name_edit)
	EventSheets.attach_completions(name_edit, EventSheetCompletions.FIELD_STATE_NAME)

	var note_edit: LineEdit = LineEdit.new()
	note_edit.name = "Note"
	note_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	note_edit.placeholder_text = EventSheetL10n.translate("What this state is")
	note_edit.text = str(entry["note"])
	note_edit.text_changed.connect(func(text: String) -> void:
		(_entries[index] as Dictionary)["note"] = text.strip_edges()
		_show_code())
	row.add_child(note_edit)
	EventSheets.attach_completions(note_edit, EventSheetCompletions.FIELD_STATE_NOTE)

	var radio: CheckBox = CheckBox.new()
	radio.name = "Default"
	radio.button_group = _radio_group
	radio.text = EventSheetL10n.translate("default")
	radio.button_pressed = index == _default_index
	radio.toggled.connect(func(on: bool) -> void:
		if on:
			_default_index = index
			_show_code())
	row.add_child(radio)

	var used: int = int(counts.get(str(entry["orig"]), 0)) if not str(entry["orig"]).is_empty() else 0
	var uses: Label = Label.new()
	uses.name = "Uses"
	# The quieter text of the editor theme, so the count reads secondary in dark and light alike.
	uses.add_theme_color_override("font_color", EventSheetPopupUI.muted_text_color())
	uses.text = "" if used == 0 else (EventSheetL10n.translate("1 row") if used == 1 else EventSheetL10n.translate("%d rows") % used)
	uses.custom_minimum_size.x = 50.0
	row.add_child(uses)

	var remove: Button = Button.new()
	remove.name = "Remove"
	remove.flat = true
	remove.text = "✕"
	remove.tooltip_text = EventSheetL10n.translate("Remove this state")
	remove.disabled = _entries.size() <= 1
	remove.pressed.connect(_remove.bind(index))
	row.add_child(remove)
	return row


func _move(index: int, by: int) -> void:
	var target: int = index + by
	if target < 0 or target >= _entries.size():
		return
	var moved: Variant = _entries[index]
	_entries.remove_at(index)
	_entries.insert(target, moved)
	if _default_index == index:
		_default_index = target
	elif _default_index == target:
		_default_index = index
	_rebuild_list()


func _remove(index: int) -> void:
	if _entries.size() <= 1:
		return
	var gone: Dictionary = _entries[index]
	var uses: int = int(EventSheetStateFacts.naming_counts(_dock._current_sheet).get(str(gone["orig"]), 0))
	if uses > 0:
		# The rows that still use it come FIRST: nothing is removed until they are pointed somewhere else.
		_problem_label.say(left_list_note_for(_dock._current_sheet, str(gone["orig"])), EventSheetPopupUI.TONE_WARNING)
		return
	_entries.remove_at(index)
	# Removing the default moves it to the next state, or to the one before when it was the last.
	if _default_index == index:
		_default_index = mini(index, _entries.size() - 1)
	elif _default_index > index:
		_default_index -= 1
	_problem_label.say("")
	_rebuild_list()


func _on_add_pressed() -> void:
	_entries.append({"orig": "", "name": _fresh_name(), "note": ""})
	_rebuild_list()


## A name for a state added in this window: NEW_STATE, then NEW_STATE_2, and so on.
func _fresh_name() -> String:
	var taken: PackedStringArray = PackedStringArray()
	for entry: Dictionary in _entries:
		taken.append(str(entry["name"]))
	var candidate: String = "NEW_STATE"
	var number: int = 2
	while taken.has(candidate):
		candidate = "NEW_STATE_%d" % number
		number += 1
	return candidate


func _show_code() -> void:
	if _code != null:
		_code.text = code_for({"states": _entries, "description": _description, "default": _default_index})


func _on_confirmed() -> void:
	var sheet: EventSheetResource = _dock._current_sheet
	var model: Dictionary = {"states": _entries.duplicate(true), "description": _description, "default": _default_index}
	var problem: String = problem_with(sheet, model)
	if not problem.is_empty():
		# Said where the typing was, and the window stays open on it: the fix is one edit.
		_problem_label.say(problem)
		_dialog.show()
		return
	_problem_label.say("")
	_dialog.hide()
	if not _dock._perform_undoable_sheet_edit(EventSheetL10n.translate("Edit states"), func() -> bool:
			return apply_model(_dock._current_sheet, model)):
		return
	_dock._refresh_after_edit()
	_dock._set_status(EventSheetL10n.translate("%d state(s) declared - rows can now say which one this object is in.")
		% _entries.size())


# ── The working copy, and what it writes (static and pure, so the suite drives all of it) ──────────────
## The window's working copy of the sheet's machine: {"states": [{"orig", "name", "note"}], "description",
## "default"}. A sheet with no machine gets three states an object usually grows, which the author is free
## to rewrite before Apply.
static func model_of(sheet: EventSheetResource) -> Dictionary:
	var states: Array = []
	var declared: EnumRow = EventSheetStateFacts.enum_row(sheet)
	if declared == null or declared.members.is_empty():
		for first: String in ["IDLE", "CHASE", "HURT"]:
			states.append({"orig": "", "name": first, "note": ""})
		return {"states": states, "description": "", "default": 0}
	for member: String in declared.members:
		var bare: String = EnumRow.bare_name(member)
		states.append({"orig": bare, "name": bare, "note": declared.note_for(bare)})
	var default_name: String = EventSheetStateFacts.default_member(sheet)
	var default_at: int = 0
	for index: int in states.size():
		if str((states[index] as Dictionary)["name"]) == default_name:
			default_at = index
	return {"states": states, "description": declared.description, "default": default_at}


## What is wrong with applying this working copy, said as one sentence, or "" when nothing is. A rename is
## never a problem - it is followed everywhere - but a name that cannot be an identifier, two states of one
## name, and a removed state some row still uses are.
static func problem_with(sheet: EventSheetResource, model: Dictionary) -> String:
	var states: Array = model["states"]
	if states.is_empty():
		return EventSheetL10n.translate("Name at least one state.")
	var seen: PackedStringArray = PackedStringArray()
	for entry: Dictionary in states:
		var name: String = str(entry["name"]).strip_edges()
		if name.is_empty() or not name.is_valid_identifier():
			return EventSheetL10n.translate("\"%s\" can't be a state name: use letters, digits and underscores, not starting with a digit.") % name
		if seen.has(name):
			return EventSheetL10n.translate("Two states are named %s. Each state needs a name of its own.") % name
		seen.append(name)
	var kept: PackedStringArray = PackedStringArray()
	for entry: Dictionary in states:
		if not str(entry["orig"]).is_empty():
			kept.append(str(entry["orig"]))
	var counts: Dictionary = EventSheetStateFacts.naming_counts(sheet)
	var blocked: PackedStringArray = PackedStringArray()
	for member: String in EventSheetStateFacts.bare_members(sheet):
		if not kept.has(member) and int(counts.get(member, 0)) > 0:
			blocked.append(left_list_note_for(sheet, member))
	return " ".join(blocked)


## Writes the working copy onto the sheet, every rename followed through every row. Returns whether it did;
## an unwritable copy (see problem_with) changes nothing.
static func apply_model(sheet: EventSheetResource, model: Dictionary) -> bool:
	if sheet == null or not problem_with(sheet, model).is_empty():
		return false
	var states: Array = model["states"]
	var default_at: int = clampi(int(model["default"]), 0, states.size() - 1)
	var names: PackedStringArray = PackedStringArray()
	for entry: Dictionary in states:
		names.append(str(entry["name"]).strip_edges())
	var opening: String = names[default_at]
	# Renames first, through a placeholder so two states that swap names cannot meet halfway.
	var renames: Array = []
	for entry: Dictionary in states:
		var from: String = str(entry["orig"])
		if not from.is_empty() and from != str(entry["name"]).strip_edges():
			renames.append([from, str(entry["name"]).strip_edges()])
	var placeholders: Array = []
	for index: int in renames.size():
		var placeholder: String = "__STATE_RENAME_%d__" % index
		rename_everywhere(sheet, str(renames[index][0]), placeholder)
		placeholders.append([placeholder, str(renames[index][1])])
	for pair: Array in placeholders:
		rename_everywhere(sheet, str(pair[0]), str(pair[1]))
	# What each member says after its name ("HURT = 4") belongs to the member, so it travels with it.
	var written: Dictionary = {}
	var declared: EnumRow = EventSheetStateFacts.enum_row(sheet)
	if declared != null:
		for member: String in declared.members:
			var suffix: String = member.substr(member.find("=")) if member.contains("=") else ""
			written[EnumRow.bare_name(member)] = suffix
	if not write(sheet, names, opening):
		return false
	var enum_row: EnumRow = EventSheetStateFacts.enum_row(sheet)
	var members: PackedStringArray = PackedStringArray()
	var notes: Dictionary = {}
	for index: int in states.size():
		var entry: Dictionary = states[index]
		var current: String = names[index]
		var original: String = str(entry["orig"]) if not str(entry["orig"]).is_empty() else current
		var suffix: String = str(written.get(original, written.get(current, "")))
		members.append(current if suffix.is_empty() else "%s %s" % [current, suffix])
		var note: String = str(entry["note"]).strip_edges()
		if not note.is_empty():
			notes[current] = note
	enum_row.members = members
	enum_row.member_notes = notes
	enum_row.description = str(model["description"]).strip_edges()
	return true


## Every place the sheet says one state, said with another name: the rows' own parameters (Is, Was, Go to,
## the timed question, the two triggers), the lines of a `match` and of any kept code, the way a
## hand-written machine spells it. Returns how many places changed.
static func rename_everywhere(sheet: EventSheetResource, from: String, to: String) -> int:
	if sheet == null or from == to or from.is_empty() or to.is_empty():
		return 0
	var changed: int = 0
	var pattern: RegEx = RegEx.new()
	pattern.compile("\\b%s%s\\b" % [EventSheetStateFacts.MEMBER_PREFIX.replace(".", "\\."), from])
	var replacement: String = EventSheetStateFacts.MEMBER_PREFIX + to
	changed += _rename_in(EventSheetStateFacts.rows_of(sheet), from, to, pattern, replacement)
	# The variable may start in it.
	for variable_name: String in [EventSheetStateFacts.STATE_VARIABLE, EventSheetStateFacts.PREVIOUS_VARIABLE]:
		var declared: LocalVariable = EventSheetStateFacts.variable_row(sheet, variable_name)
		if declared != null and str(declared.default_value).strip_edges() == EventSheetStateFacts.MEMBER_PREFIX + from:
			declared.default_value = replacement
			changed += 1
	return changed


static func _rename_in(items: Array, from: String, to: String, pattern: RegEx, replacement: String) -> int:
	var changed: int = 0
	for item: Variant in items:
		if item is EventGroup:
			changed += _rename_in(EventSheetGroupFacts.children(item as EventGroup), from, to, pattern, replacement)
			continue
		if item is RawCodeRow:
			var code: String = (item as RawCodeRow).code
			var rewritten: String = pattern.sub(code, replacement, true)
			if rewritten != code:
				(item as RawCodeRow).code = rewritten
				changed += 1
			continue
		if item is MatchRow:
			changed += _rename_in_match(item as MatchRow, from, to, pattern, replacement)
			continue
		var event_row: EventRow = item as EventRow
		if event_row == null:
			continue
		if str(event_row.trigger_params.get(EventSheetStateFacts.STATE_PARAM, "")).strip_edges() == from:
			event_row.trigger_params[EventSheetStateFacts.STATE_PARAM] = to
			changed += 1
		if event_row.trigger != null and str(event_row.trigger.params.get(EventSheetStateFacts.STATE_PARAM, "")).strip_edges() == from:
			event_row.trigger.params[EventSheetStateFacts.STATE_PARAM] = to
		for is_action: bool in [false, true]:
			for ace: Variant in (event_row.actions if is_action else event_row.conditions):
				if ace is MatchRow:
					changed += _rename_in_match(ace as MatchRow, from, to, pattern, replacement)
					continue
				if ace is RawCodeRow:
					var raw: String = (ace as RawCodeRow).code
					var raw_rewritten: String = pattern.sub(raw, replacement, true)
					if raw_rewritten != raw:
						(ace as RawCodeRow).code = raw_rewritten
						changed += 1
					continue
				if not (ace is Resource) or not EventSheetStateFacts.STATE_ACE_IDS.has(str((ace as Resource).get("ace_id"))):
					continue
				var params: Variant = (ace as Resource).get("params")
				if params is Dictionary and str((params as Dictionary).get(EventSheetStateFacts.STATE_PARAM, "")).strip_edges() == from:
					(params as Dictionary)[EventSheetStateFacts.STATE_PARAM] = to
					changed += 1
		changed += _rename_in(event_row.sub_events, from, to, pattern, replacement)
	return changed


static func _rename_in_match(row: MatchRow, from: String, to: String, pattern: RegEx, replacement: String) -> int:
	var changed: int = 0
	var text: String = pattern.sub(row.branches_text, replacement, true)
	if text != row.branches_text:
		row.branches_text = text
		changed += 1
	for case_row: MatchCase in row.cases:
		if case_row == null:
			continue
		var rewritten: String = pattern.sub(case_row.pattern, replacement, true)
		if rewritten != case_row.pattern:
			case_row.pattern = rewritten
			changed += 1
		changed += _rename_in(case_row.events, from, to, pattern, replacement)
	return changed


## The sentence a state that rows still use is refused with ("CHASE is still used by 3 rows - ..."), and
## what the window says as a removal is tried.
static func left_list_note_for(sheet: EventSheetResource, member: String) -> String:
	var used: int = int(EventSheetStateFacts.naming_counts(sheet).get(member, 0))
	return EventSheetL10n.translate("%s is still used by %d row(s), so it was not removed. Point those rows at another state first, then remove it.") % [member, used]


## The enum and the variable the working copy will write, as the code a reader would see.
static func code_for(model: Dictionary) -> String:
	var lines: PackedStringArray = PackedStringArray()
	var description: String = str(model.get("description", "")).strip_edges()
	if not description.is_empty():
		lines.append("## %s" % description)
	lines.append("enum %s {" % EventSheetStateFacts.ENUM_NAME)
	var states: Array = model.get("states", [])
	for entry: Dictionary in states:
		var note: String = str(entry.get("note", "")).strip_edges()
		if not note.is_empty():
			lines.append("\t## %s" % note)
		lines.append("\t%s," % str(entry.get("name", "")))
	lines.append("}")
	if not states.is_empty():
		var at: int = clampi(int(model.get("default", 0)), 0, states.size() - 1)
		lines.append("var %s: %s = %s.%s" % [EventSheetStateFacts.STATE_VARIABLE, EventSheetStateFacts.ENUM_NAME,
			EventSheetStateFacts.ENUM_NAME, str((states[at] as Dictionary).get("name", ""))])
	return "\n".join(lines)


## The declarations, written onto a sheet: the enum row, the state variable that starts in `starts_in`, and
## the helpers the vocabulary leans on. Returns whether anything changed. Every one of them is an ordinary
## row. An enum that already carries sentences keeps them: only the members and the default move.
static func write(sheet: EventSheetResource, declared: PackedStringArray, starts_in: String) -> bool:
	if sheet == null or declared.is_empty():
		return false
	if not still_named_states(sheet, declared).is_empty():
		return false
	var members: PackedStringArray = PackedStringArray()
	for word: String in declared:
		members.append(EventSheetStateFacts.member_for(word))
	var enum_row: EnumRow = EventSheetStateFacts.enum_row(sheet)
	if enum_row == null:
		enum_row = EnumRow.new()
		enum_row.enum_name = EventSheetStateFacts.ENUM_NAME
		sheet.events.insert(0, enum_row)
	enum_row.members = members
	_ensure_signal(sheet)
	var opening: String = "%s.%s" % [EventSheetStateFacts.ENUM_NAME,
		EventSheetStateFacts.member_for(starts_in if not starts_in.is_empty() else declared[0])]
	# The state variable ANNOUNCES ITSELF: its setter is where "and tell everybody" belongs in Godot,
	# so every row and every hand-written line that assigns it says so without having to remember to.
	# The same setter is what keeps the other two declarations true.
	var state_var: LocalVariable = _ensure_variable(sheet, EventSheetStateFacts.STATE_VARIABLE,
		EventSheetStateFacts.ENUM_NAME, opening)
	state_var.setter_param = "value"
	state_var.setter_body = EventSheetStateFacts.SETTER_BODY
	# What we came from, and when this state began. Declared rather than derived because both are
	# facts about a moment that has already passed, and nothing else in the file could recover them.
	_ensure_variable(sheet, EventSheetStateFacts.PREVIOUS_VARIABLE,
		EventSheetStateFacts.ENUM_NAME, opening)
	# The clock STARTS AT BIRTH, not at zero: a variable initialiser runs when the object is built, so
	# the state it opens in has been held since then. Written as `0`, the timed question would be
	# comparing against the whole run instead, and an object spawned mid-game would answer "for over
	# 2s" on its first frame.
	_ensure_variable(sheet, EventSheetStateFacts.SINCE_VARIABLE, "int",
		EventSheetStateFacts.SINCE_INITIAL)
	return true


## The declared states (bare members) that `declared` would remove while rows of the sheet still name them
## - Go to, Is, Was, On entering, On leaving. A name that is merely CHANGED is not a removal here: the
## window follows a rename through every row, and the plain list form below has no way to say one, so a
## state missing from it is treated as removed.
static func still_named_states(sheet: EventSheetResource, declared: PackedStringArray) -> PackedStringArray:
	var blocked: PackedStringArray = PackedStringArray()
	if sheet == null:
		return blocked
	var kept: PackedStringArray = PackedStringArray()
	for word: String in declared:
		kept.append(EventSheetStateFacts.member_for(word))
	var named: PackedStringArray = EventSheetStateFacts.named_states(sheet)
	for member: String in EventSheetStateFacts.bare_members(sheet):
		if not kept.has(member) and named.has(member):
			blocked.append(member)
	return blocked


## What the window says as a state leaves the list while rows still say it - one sentence per such
## state ("HURT left the list - 3 row(s) still say State.HURT."), or "" when nothing is left behind.
static func left_list_note(sheet: EventSheetResource, declared: PackedStringArray) -> String:
	var counts: Dictionary = EventSheetStateFacts.naming_counts(sheet)
	var said: PackedStringArray = PackedStringArray()
	for member: String in still_named_states(sheet, declared):
		said.append(EventSheetL10n.translate("%s left the list - %d row(s) still say %s.") % [
			EventSheetStateFacts.word_for(member), int(counts.get(member, 0)),
			EventSheetStateFacts.MEMBER_PREFIX + member])
	return " ".join(said)


## The words a states field says, in order, however they were separated. A reader typing commas,
## middots or plain spaces means the same thing, and the field should not be a syntax to learn. The
## same reading the modes field uses, so the two dialogs cannot disagree about what a list is.
static func words_of(text: String) -> PackedStringArray:
	return EventSheetModesDialog.words_of(text)


## The reading line: what a states list says once written, asked of the same one-line assembly the modes
## use so the two cannot promise different lines.
static func reads_as(declared: PackedStringArray, starts_in: String) -> String:
	return EventSheetModeFacts.band_line(declared, starts_in)


## And the code line: the enum and the variable.
static func in_code(declared: PackedStringArray, starts_in: String) -> String:
	if declared.is_empty():
		return ""
	var members: PackedStringArray = PackedStringArray()
	for word: String in declared:
		members.append(EventSheetStateFacts.member_for(word))
	return "enum %s { %s } · var %s: %s = %s.%s" % [
		EventSheetStateFacts.ENUM_NAME, ", ".join(members), EventSheetStateFacts.STATE_VARIABLE,
		EventSheetStateFacts.ENUM_NAME, EventSheetStateFacts.ENUM_NAME,
		EventSheetStateFacts.member_for(starts_in if not starts_in.is_empty() else declared[0])]


static func _ensure_variable(sheet: EventSheetResource, name: String, type_name: String,
		initial: String) -> LocalVariable:
	var declared: LocalVariable = EventSheetStateFacts.variable_row(sheet, name)
	if declared == null:
		declared = LocalVariable.new()
		declared.name = name
		sheet.events.insert(mini(1, sheet.events.size()), declared)
	declared.type_name = type_name
	declared.default_value = initial
	declared.expression_default = true
	return declared


static func _ensure_signal(sheet: EventSheetResource) -> void:
	for entry: Variant in sheet.events:
		var existing: SignalRow = entry as SignalRow
		if existing != null and existing.signal_name == EventSheetStateFacts.CHANGED_SIGNAL:
			return
	var declared: SignalRow = SignalRow.new()
	declared.signal_name = EventSheetStateFacts.CHANGED_SIGNAL
	declared.params = EventSheetStateFacts.CHANGED_SIGNAL_PARAMS
	declared.description = "Says this object's state changed, and what it changed from."
	sheet.events.insert(mini(1, sheet.events.size()), declared)
