# Godot EventSheets - the Declare states dialog: one object's states, declared once.
#
# What it writes is the whole point of it: FIVE ORDINARY DECLARATIONS the author could have typed,
# and which a hand-written object usually has typed already -
#
#     enum State { PATROL, CHASE, STAGGER }
#     signal state_changed(from_state: int, to_state: int)
#     var state: State = State.PATROL      (with the setter that announces the change)
#     var previous_state: State = State.PATROL
#     var state_entered_msec: int = Time.get_ticks_msec()
#
# Nothing is stored anywhere else, nothing is hidden, and everything it writes is a row a reader can
# see, edit and delete. That is what makes the feature survive uninstalling the plugin, and what
# makes an object that wrote them by hand already have it.
#
# ONE DECLARATION IS ONE MACHINE. A second machine on the same object is simply a second declared
# state variable, written by hand the same way this writes the first - there is no "add machine"
# concept to learn, because a machine was never a thing here; it is an enum and a variable.
#
# THE SAME DIALOG FAMILY AS THE GAME'S MODES: Edit modes (`modes_dialog.gd`) asks the identical two
# questions - the names, and the one it starts in - for the game's own machine. This asks them for an
# object's. It asks no third question: the modes dialog's policy dials are about what a MODE does to
# the whole game (pausing the tree, showing the mouse), and an object's state does not have an
# opinion about the scene tree. What a state does is the rows the author puts under On entering.
@tool
class_name EventSheetStatesDialog
extends RefCounted

var _dock: Control = null
var _dialog: ConfirmationDialog = null
var _states_edit: LineEdit = null
var _starts_option: OptionButton = null
## The ONE help strip at the foot: what the focused field is for, then what the sheet will read as
## and the lines it will compile to.
var _help_strip: EventSheetPopupUI.HelpStrip = null


func init(dock: Control) -> void:
	_dock = dock


## Opens the dialog on this sheet's declarations, or on a first set for a sheet that has none - three
## states an object usually grows, which the author is free to rewrite before OK.
func open() -> void:
	var sheet: EventSheetResource = _dock._current_sheet
	if sheet == null:
		return
	_build()
	var declared: PackedStringArray = EventSheetStateFacts.names(sheet)
	if declared.is_empty():
		declared = PackedStringArray(["Idle", "Chase", "Hurt"])
	_states_edit.text = " · ".join(declared)
	_refill(declared, EventSheetStateFacts.starts_in(sheet))
	_dialog.popup_centered(Vector2i(560, 320))


func _build() -> void:
	if _dialog != null:
		return
	_dialog = ConfirmationDialog.new()
	_dialog.title = "States"
	_dialog.ok_button_text = "OK"
	_dialog.visible = false
	_dialog.confirmed.connect(_on_confirmed)
	_dock.add_child(_dialog)
	var form: VBoxContainer = EventSheetPopupUI.form_box()
	_dialog.add_child(EventSheetPopupUI.margined(form))

	_states_edit = LineEdit.new()
	_states_edit.placeholder_text = "Patrol · Chase · Stagger"
	_states_edit.text_changed.connect(func(_text: String) -> void: _refill(words_of(_states_edit.text), _starts_in()))
	form.add_child(EventSheetPopupUI.form_row("States", _states_edit))

	_starts_option = OptionButton.new()
	_starts_option.item_selected.connect(func(_index: int) -> void: _show_reading())
	form.add_child(EventSheetPopupUI.form_row("Starts in", _starts_option))

	_help_strip = EventSheetPopupUI.help_strip()
	form.add_child(_help_strip)
	_help_strip.follow(_states_edit, "States",
		"The states this one object can be in, separated by anything you like. They become an enum, and every row that names a state picks from this list - which is why a typo cannot reach the game.")
	_help_strip.follow(_starts_option, "Starts in",
		"The state the object opens in - the value the state variable is declared with. It is also the one state that needs no row going to it.")


## Refills the starts-in list from whatever the States field says right now, keeping the answer if it
## is still answerable - editing the list must not silently move where the object starts.
func _refill(declared: PackedStringArray, keep_starting: String) -> void:
	_starts_option.clear()
	for word: String in declared:
		_starts_option.add_item(word)
	_select(_starts_option, keep_starting)
	_show_reading()


func _show_reading() -> void:
	var declared: PackedStringArray = words_of(_states_edit.text)
	_help_strip.set_reading(reads_as(declared, _starts_in()), in_code(declared, _starts_in()))


static func _select(dropdown: OptionButton, wanted: String) -> void:
	for index: int in range(dropdown.item_count):
		if dropdown.get_item_text(index) == wanted:
			dropdown.select(index)
			return
	if dropdown.item_count > 0:
		dropdown.select(0)


func _starts_in() -> String:
	return _starts_option.get_item_text(_starts_option.selected) if _starts_option.selected >= 0 else ""


func _on_confirmed() -> void:
	var declared: PackedStringArray = words_of(_states_edit.text)
	if declared.is_empty():
		_dock._set_status(EventSheetL10n.translate("Name at least one state."), true)
		return
	var opening: String = _starts_in()
	if not _dock._perform_undoable_sheet_edit(EventSheetL10n.translate("Declare states"), func() -> bool:
			return write(_dock._current_sheet, declared, opening)):
		return
	_dock._refresh_after_edit()
	_dock._set_status(EventSheetL10n.translate("%d state(s) declared - rows can now say which one this object is in.")
		% declared.size())


# ── What it writes, and what it reads back (static and pure, so the suite drives all of it) ──
## The five declarations, written onto a sheet. Returns whether anything changed. Every one of them
## is an ordinary row: an enum row, a signal row, and three variable rows.
static func write(sheet: EventSheetResource, declared: PackedStringArray, starts_in: String) -> bool:
	if sheet == null or declared.is_empty():
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


## The words a states field says, in order, however they were separated. A reader typing commas,
## middots or plain spaces means the same thing, and the field should not be a syntax to learn. The
## same reading the modes field uses, so the two dialogs cannot disagree about what a list is.
static func words_of(text: String) -> PackedStringArray:
	return EventSheetModesDialog.words_of(text)


## The reading line: what this sheet's head will say once OK is pressed.
static func reads_as(declared: PackedStringArray, starts_in: String) -> String:
	if declared.is_empty():
		return ""
	var listed: String = " · ".join(declared)
	return listed if starts_in.is_empty() else "%s, starts in %s" % [listed, starts_in]


## And the code line: the enum and the variable, which is what the band echoes.
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
