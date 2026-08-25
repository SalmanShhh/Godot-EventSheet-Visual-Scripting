# Godot EventSheets - the Edit modes dialog: the game's modes, declared once.
#
# What it writes is the whole point of it: FOUR ORDINARY DECLARATIONS the author could have typed,
# and which a hand-written project usually has typed already -
#
#     enum Mode { PLAYING, PAUSED, CUTSCENE, MENU }
#     var mode: Mode = Mode.MENU
#     var mode_stack: Array[int] = []
#     signal mode_changed(from_mode: int, to_mode: int)
#
# plus, for each mode whose policy is not the default, one ordinary "On entering" event carrying the
# rows that apply it. Nothing is stored anywhere else, nothing is hidden, and everything it writes is
# a row a reader can see, edit and delete. That is what makes the feature survive uninstalling the
# plugin, and what makes a project that wrote all four by hand already have it.
#
# THE POLICY, and why there are two dials rather than the three you might expect: what a mode does to
# the game on entering is, in Godot's own documented pause pattern, exactly two questions - does the
# tree keep processing (`get_tree().paused`), and is the mouse shown (`Input.mouse_mode`). "Does
# gameplay input reach the game" is the FIRST of those: pausing the tree is what stops gameplay
# nodes hearing input, and a node that must keep hearing it says so with its own process_mode. A
# third dropdown would be a second spelling of the first, so the strip says that instead.
@tool
class_name EventSheetModesDialog
extends RefCounted

## The rows the policy is written as, by ace id - shipped vocabulary, so the events this dialog
## writes are events the author could have picked themselves.
const PAUSE_ACE: String = "SetPaused"
const MOUSE_SHOWN_ACE: String = "MouseCursorVisible"
const MOUSE_HIDDEN_ACE: String = "MouseRequestPointerLock"

var _dock: Control = null
var _dialog: ConfirmationDialog = null
var _modes_edit: LineEdit = null
var _starts_option: OptionButton = null
var _policy_mode_option: OptionButton = null
var _physics_option: OptionButton = null
var _mouse_option: OptionButton = null
## The ONE help strip at the foot: what the focused field is for, then what the sheet will read as
## and the lines it will compile to.
var _help_strip: EventSheetPopupUI.HelpStrip = null
## mode word -> {"physics": bool, "mouse": bool}, edited here and written on OK. Read from the rows
## the last OK wrote, so re-opening the dialog shows what the sheet actually says.
var _policy: Dictionary = {}


func init(dock: Control) -> void:
	_dock = dock


## Opens the dialog on this sheet's declarations, or on a sensible first set for a sheet that has
## none - the four modes almost every game grows, which the author is free to rewrite before OK.
func open() -> void:
	var sheet: EventSheetResource = _dock._current_sheet
	if sheet == null:
		return
	_build()
	var declared: PackedStringArray = EventSheetModeFacts.names(sheet)
	if declared.is_empty():
		declared = PackedStringArray(["Playing", "Paused", "Menu"])
	_modes_edit.text = " · ".join(declared)
	_policy = read_policy(sheet)
	_refill(declared, EventSheetModeFacts.starts_in(sheet))
	_dialog.popup_centered(Vector2i(560, 460))


func _build() -> void:
	if _dialog != null:
		return
	_dialog = ConfirmationDialog.new()
	_dialog.title = "Modes"
	_dialog.ok_button_text = "OK"
	_dialog.visible = false
	_dialog.confirmed.connect(_on_confirmed)
	_dock.add_child(_dialog)
	var form: VBoxContainer = EventSheetPopupUI.form_box()
	_dialog.add_child(EventSheetPopupUI.margined(form))

	_modes_edit = LineEdit.new()
	_modes_edit.placeholder_text = "Playing · Paused · Cutscene · Menu"
	_modes_edit.text_changed.connect(func(_text: String) -> void: _refill(words_of(_modes_edit.text), _starts_in()))
	form.add_child(EventSheetPopupUI.form_row("Modes", _modes_edit))

	_starts_option = OptionButton.new()
	form.add_child(EventSheetPopupUI.form_row("Starts in", _starts_option))

	# The policy is asked ONE MODE AT A TIME, because it is a fact about that mode. The dropdown
	# beside it picks which mode is being answered for.
	_policy_mode_option = OptionButton.new()
	_policy_mode_option.item_selected.connect(func(_index: int) -> void: _show_policy())
	form.add_child(EventSheetPopupUI.form_row("Policy for", _policy_mode_option))
	_physics_option = _policy_dropdown(["Runs", "Stopped"])
	_physics_option.item_selected.connect(func(_index: int) -> void: _remember_policy())
	form.add_child(EventSheetPopupUI.form_row("Physics", _physics_option))
	_mouse_option = _policy_dropdown(["Hidden", "Shown"])
	_mouse_option.item_selected.connect(func(_index: int) -> void: _remember_policy())
	form.add_child(EventSheetPopupUI.form_row("Mouse", _mouse_option))

	_help_strip = EventSheetPopupUI.help_strip()
	form.add_child(_help_strip)
	_help_strip.follow(_modes_edit, "Modes",
		"The states the whole game can be in, separated by anything you like. They become an enum, and every row and group that names a mode picks from this list.")
	_help_strip.follow(_starts_option, "Starts in",
		"The mode the game opens in - the value the mode variable is declared with.")
	_help_strip.follow(_policy_mode_option, "Policy for",
		"Which mode the two answers below are about. Each mode declares its own policy once, and entering it applies them.")
	_help_strip.follow(_physics_option, "Physics",
		"Whether the scene tree keeps processing while the game is in this mode. This is also the answer to \"does gameplay input reach the game\": pausing the tree is what stops gameplay nodes hearing it, and a node that must keep hearing it says so with its own process mode.")
	_help_strip.follow(_mouse_option, "Mouse",
		"Whether the mouse cursor is shown while the game is in this mode. A menu shows it; a first-person view captures it.")


static func _policy_dropdown(labels: Array) -> OptionButton:
	var dropdown: OptionButton = OptionButton.new()
	for label: String in labels:
		dropdown.add_item(EventSheetL10n.translate(label))
	return dropdown


## Refills the two mode lists from whatever the Modes field says right now, keeping the answers that
## are still answerable - editing the list must not silently forget the policy of a mode that stayed.
func _refill(declared: PackedStringArray, keep_starting: String) -> void:
	for dropdown: OptionButton in [_starts_option, _policy_mode_option]:
		dropdown.clear()
		for word: String in declared:
			dropdown.add_item(word)
	_select(_starts_option, keep_starting)
	if _policy_mode_option.item_count > 0:
		_policy_mode_option.select(0)
	_show_policy()
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


func _policy_mode() -> String:
	return _policy_mode_option.get_item_text(_policy_mode_option.selected) \
		if _policy_mode_option.selected >= 0 else ""


func _show_policy() -> void:
	var answers: Dictionary = _policy.get(_policy_mode(), default_policy())
	_physics_option.select(0 if bool(answers.get("physics", true)) else 1)
	_mouse_option.select(1 if bool(answers.get("mouse", true)) else 0)


func _remember_policy() -> void:
	var mode: String = _policy_mode()
	if not mode.is_empty():
		_policy[mode] = {"physics": _physics_option.selected == 0, "mouse": _mouse_option.selected == 1}


func _on_confirmed() -> void:
	var declared: PackedStringArray = words_of(_modes_edit.text)
	if declared.is_empty():
		_dock._set_status(EventSheetL10n.translate("Name at least one mode."), true)
		return
	_remember_policy()
	var opening: String = _starts_in()
	var policy: Dictionary = _policy.duplicate(true)
	if not _dock._perform_undoable_sheet_edit(EventSheetL10n.translate("Edit modes"), func() -> bool:
			return write(_dock._current_sheet, declared, opening, policy)):
		return
	_dock._refresh_after_edit()
	_dock._set_status(EventSheetL10n.translate("%d mode(s) declared - groups can now say which one they run in.")
		% declared.size())


# ── What it writes, and what it reads back (static and pure, so the suite drives all of it) ──
## The four declarations plus the policy events, written onto a sheet. Returns whether anything
## changed. Every one of them is an ordinary row: an enum row, two variable rows, a signal row, and
## one On entering event per mode whose policy is not the default.
static func write(sheet: EventSheetResource, declared: PackedStringArray, starts_in: String,
		policy: Dictionary) -> bool:
	if sheet == null or declared.is_empty():
		return false
	var members: PackedStringArray = PackedStringArray()
	for word: String in declared:
		members.append(EventSheetModeFacts.member_for(word))
	var enum_row: EnumRow = EventSheetModeFacts.enum_row(sheet)
	if enum_row == null:
		enum_row = EnumRow.new()
		enum_row.enum_name = EventSheetModeFacts.ENUM_NAME
		sheet.events.insert(0, enum_row)
	enum_row.members = members
	# The mode variable ANNOUNCES ITSELF: its setter is where "and tell everybody" belongs in Godot,
	# so every row and every hand-written line that assigns it says so without having to remember to.
	var mode_var: LocalVariable = _ensure_variable(sheet, EventSheetModeFacts.MODE_VARIABLE,
		EventSheetModeFacts.ENUM_NAME, "%s.%s" % [EventSheetModeFacts.ENUM_NAME,
			EventSheetModeFacts.member_for(starts_in if not starts_in.is_empty() else declared[0])])
	mode_var.setter_param = "value"
	mode_var.setter_body = EventSheetModeFacts.SETTER_BODY
	_ensure_variable(sheet, EventSheetModeFacts.STACK_VARIABLE, "Array[int]", "[]")
	_ensure_signal(sheet)
	# The two functions the stack rows call. Ordinary sheet functions, so they are visible, editable
	# and deletable like everything else this dialog writes.
	_ensure_function(sheet, EventSheetModeFacts.PUSH_FUNCTION, EventSheetModeFacts.PUSH_BODY,
		"next", EventSheetModeFacts.ENUM_NAME,
		"Goes to a mode remembering the one underneath, so Go back can return to it.")
	_ensure_function(sheet, EventSheetModeFacts.BACK_FUNCTION, EventSheetModeFacts.BACK_BODY,
		"", "", "Returns to the mode under this one, and does nothing when there is none.")
	# ALL or NOTHING, and the reason is that a policy has to be total to be true: if one mode pauses
	# the game, every other mode has to say that it does not, or entering one of them from the paused
	# one leaves the game paused. So a set of modes that all want the plain answers writes no rows at
	# all, and the moment one of them wants something else they all say what they want.
	var any_differs: bool = false
	for word: String in declared:
		if policy.get(word, default_policy()) != default_policy():
			any_differs = true
	for word: String in declared:
		_write_policy_event(sheet, word, policy.get(word, default_policy()), any_differs)
	return true


## What a mode does to the game unless it says otherwise: the game runs and the mouse is shown. The
## answers a menu-first project wants everywhere, so a mode that says nothing writes no rows at all.
static func default_policy() -> Dictionary:
	return {"physics": true, "mouse": true}


## The policy each mode carries, read back out of the On entering rows this dialog wrote. A mode
## with no such rows carries the default, which is why a first open shows the plain answers.
static func read_policy(sheet: EventSheetResource) -> Dictionary:
	var found: Dictionary = {}
	if sheet == null:
		return found
	for word: String in EventSheetModeFacts.names(sheet):
		var event_row: EventRow = _policy_event(sheet, word)
		if event_row == null:
			continue
		var answers: Dictionary = default_policy()
		for action: Variant in event_row.actions:
			if not (action is Resource):
				continue
			var params: Variant = (action as Resource).get("params")
			var paused: String = str((params as Dictionary).get("paused", "")) if params is Dictionary else ""
			match str((action as Resource).get("ace_id")):
				PAUSE_ACE:
					answers["physics"] = not paused.contains("true")
				MOUSE_HIDDEN_ACE:
					answers["mouse"] = false
				MOUSE_SHOWN_ACE:
					answers["mouse"] = true
		found[word] = answers
	return found


## The words a modes field says, in order, however they were separated. A reader typing commas,
## middots or plain spaces means the same thing, and the field should not be a syntax to learn.
static func words_of(text: String) -> PackedStringArray:
	var said: PackedStringArray = PackedStringArray()
	for part: String in text.replace("·", ",").replace(";", ",").replace("|", ",").split(","):
		var word: String = part.strip_edges()
		if not word.is_empty() and not said.has(word):
			said.append(word)
	return said


## The reading line: what this sheet will say once OK is pressed.
static func reads_as(declared: PackedStringArray, starts_in: String) -> String:
	if declared.is_empty():
		return ""
	var listed: String = " · ".join(declared)
	return listed if starts_in.is_empty() else "%s - starts in %s" % [listed, starts_in]


## And the code line: the enum, plus what entering a mode does about the two policies.
static func in_code(declared: PackedStringArray, starts_in: String) -> String:
	if declared.is_empty():
		return ""
	var members: PackedStringArray = PackedStringArray()
	for word: String in declared:
		members.append(EventSheetModeFacts.member_for(word))
	return "enum %s { %s } · var %s: %s = %s.%s" % [
		EventSheetModeFacts.ENUM_NAME, ", ".join(members), EventSheetModeFacts.MODE_VARIABLE,
		EventSheetModeFacts.ENUM_NAME, EventSheetModeFacts.ENUM_NAME,
		EventSheetModeFacts.member_for(starts_in if not starts_in.is_empty() else declared[0])]


static func _ensure_variable(sheet: EventSheetResource, name: String, type_name: String,
		initial: String) -> LocalVariable:
	var declared: LocalVariable = EventSheetModeFacts.variable_row(sheet, name)
	if declared == null:
		declared = LocalVariable.new()
		declared.name = name
		sheet.events.insert(1, declared)
	declared.type_name = type_name
	declared.default_value = initial
	declared.expression_default = true
	return declared


## One of the two stack functions, written if it is not there. Its BODY is left alone when it is:
## somebody who rewrote it meant to, and this dialog is not the owner of what a function does.
static func _ensure_function(sheet: EventSheetResource, name: String, body: String,
		param_name: String, param_type: String, description: String) -> void:
	for entry: Variant in sheet.functions:
		var existing: EventFunction = entry as EventFunction
		if existing != null and existing.function_name == name:
			return
	var declared: EventFunction = EventFunction.new()
	declared.function_name = name
	declared.description = description
	if not param_name.is_empty():
		var argument: ACEParam = ACEParam.new()
		argument.id = param_name
		argument.type_name = param_type
		declared.params.append(argument)
	var lines: RawCodeRow = RawCodeRow.new()
	lines.code = body
	declared.events.append(lines)
	sheet.functions.append(declared)


static func _ensure_signal(sheet: EventSheetResource) -> void:
	for entry: Variant in sheet.events:
		var existing: SignalRow = entry as SignalRow
		if existing != null and existing.signal_name == EventSheetModeFacts.CHANGED_SIGNAL:
			return
	var declared: SignalRow = SignalRow.new()
	declared.signal_name = EventSheetModeFacts.CHANGED_SIGNAL
	declared.params = EventSheetModeFacts.CHANGED_SIGNAL_PARAMS
	declared.description = "Says the game's mode changed, and what it changed from."
	sheet.events.insert(mini(2, sheet.events.size()), declared)


## The On entering event that carries one mode's policy, or null. Found by its trigger and its mode,
## because that is what it IS - there is no hidden mark on it, and deleting it is allowed.
static func _policy_event(sheet: EventSheetResource, word: String) -> EventRow:
	var member: String = EventSheetModeFacts.member_for(word)
	for entry: Variant in sheet.events:
		var event_row: EventRow = entry as EventRow
		if event_row == null or event_row.trigger_id != EventSheetModeFacts.ENTERING_TRIGGER_ID:
			continue
		if str(event_row.trigger_params.get(EventSheetModeFacts.MODE_PARAM, "")) == member:
			return event_row
	return null


## One mode's policy, written as the two rows that apply it. With `write_it` false the mode's event
## is removed instead: no mode in this sheet wants anything but the plain answers, and a sheet should
## not carry two rows per mode saying the game runs normally.
static func _write_policy_event(sheet: EventSheetResource, word: String, answers: Dictionary,
		write_it: bool) -> void:
	var event_row: EventRow = _policy_event(sheet, word)
	if not write_it:
		# Only an event this dialog would have written is removed. One the author has since put their
		# own rows into is theirs, and stays exactly as it is.
		if event_row != null and _is_only_policy(event_row):
			sheet.events.erase(event_row)
		return
	if event_row == null:
		event_row = EventRow.new()
		event_row.trigger_provider_id = "Core"
		event_row.trigger_id = EventSheetModeFacts.ENTERING_TRIGGER_ID
		event_row.trigger_params = {EventSheetModeFacts.MODE_PARAM: EventSheetModeFacts.member_for(word)}
		sheet.events.append(event_row)
	var kept: Array[Resource] = []
	for action: Variant in event_row.actions:
		if action is Resource and not _is_policy_action(action as Resource):
			kept.append(action as Resource)
	event_row.actions.clear()
	event_row.actions.append(_policy_action(PAUSE_ACE,
		{"paused": "false" if bool(answers.get("physics", true)) else "true"}))
	event_row.actions.append(_policy_action(
		MOUSE_SHOWN_ACE if bool(answers.get("mouse", true)) else MOUSE_HIDDEN_ACE, {}))
	for action: Resource in kept:
		event_row.actions.append(action)


## True when an event holds nothing but the rows this dialog writes - the test that keeps it from
## deleting work somebody added to a mode's entering event.
static func _is_only_policy(event_row: EventRow) -> bool:
	for action: Variant in event_row.actions:
		if action is Resource and not _is_policy_action(action as Resource):
			return false
	return event_row.conditions.is_empty() and event_row.sub_events.is_empty()


static func _is_policy_action(action: Resource) -> bool:
	return [PAUSE_ACE, MOUSE_SHOWN_ACE, MOUSE_HIDDEN_ACE].has(str(action.get("ace_id")))


static func _policy_action(ace_id: String, params: Dictionary) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = ace_id
	action.params = params
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor("Core", ace_id)
	if descriptor != null:
		action.codegen_template = descriptor.codegen_template
	return action
