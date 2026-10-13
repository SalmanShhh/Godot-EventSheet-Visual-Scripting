@tool
class_name EventSheetStructRowDialogs
extends RefCounted

# Three small windows that write one structural row each: Enum (a name and its values), Signal (a
# name and its parameters) and Match (a value and the branches it picks between).
#
# All three are built on the window kit the same way: a band at the top showing the row as the sheet
# will, a card per thing being written, a state note that says what is wrong with WHICH field while
# OK waits for the fix, and the help strip at the foot describing the focused field and the code it
# writes. Built lazily on first use; the dock keeps thin _open_enum_dialog / _open_signal_dialog /
# _open_match_dialog delegates so the viewport's edit signals keep calling the dock unchanged. This
# class reaches back through the dock for the active sheet, the undoable-edit funnel and the refresh
# / dirty / status feedback.

var _dock: Control = null


func init(dock: Control) -> void:
	_dock = dock


## The shared start of all three windows: a ConfirmationDialog whose OK never closes it by itself
## (a refused value keeps everything typed), holding a band, the caller's cards, a state note and the
## help strip. Returns {dialog, band, form, note, strip}.
func _window(title: String, ok_text: String) -> Dictionary:
	var dialog: ConfirmationDialog = ConfirmationDialog.new()
	dialog.title = title
	dialog.ok_button_text = ok_text
	dialog.dialog_hide_on_ok = false
	var form: VBoxContainer = EventSheetPopupUI.form_box()
	form.custom_minimum_size = Vector2(EventSheetPalette.scaled_f(440.0), 0.0)
	var band: EventSheetPopupUI.RowBand = EventSheetPopupUI.RowBand.new()
	form.add_child(band)
	dialog.add_child(EventSheetPopupUI.margined(form))
	var note: EventSheetPopupUI.StateNote = EventSheetPopupUI.StateNote.new(EventSheetPalette.scaled_f(400.0))
	var strip: EventSheetPopupUI.HelpStrip = EventSheetPopupUI.help_strip("", "", "", "", EventSheetPalette.scaled_f(400.0))
	return {"dialog": dialog, "band": band, "form": form, "note": note, "strip": strip}


## Shows a window centred at `width` (before display scaling), sized to its content - once the dock is
## on screen; a dock that is not (the suite drives these headless) just keeps the window filled.
func _popup(dialog: ConfirmationDialog, width: float) -> void:
	if _dock.is_inside_tree():
		dialog.popup_centered(Vector2i(int(EventSheetPalette.scaled_f(width)), 0))


## Puts the note and the strip under the cards, and the window under the dock.
func _finish_window(parts: Dictionary) -> void:
	var form: VBoxContainer = parts["form"]
	form.add_child(parts["note"])
	form.add_child(parts["strip"])
	_dock.add_child(parts["dialog"])


## Reads a name field and its entries, each [text, field]: a value or parameter name with an optional
## `separator` part ("IDLE = 4", "damage: int"). {name, entries, problem, field} - `field` is the
## control the problem is about, so it can wear the red edge. A blank entry is an unfilled slot.
static func _read_named(name_edit: LineEdit, name_problem: String, entries: Array, separator: String,
		entry_problem: String) -> Dictionary:
	var new_name: String = EventSheetIdentifierRules.sanitize(name_edit.text)
	if not EventSheetIdentifierRules.is_valid(new_name):
		return {"problem": name_problem.replace("{name}", name_edit.text), "field": name_edit}
	var parts: PackedStringArray = PackedStringArray()
	for entry: Array in entries:
		var text: String = entry[0]
		if text.strip_edges().is_empty():
			continue
		var part: String = EventSheetIdentifierRules.sanitize(text.get_slice(separator, 0))
		if not EventSheetIdentifierRules.is_valid(part):
			return {"problem": entry_problem.replace("{name}", text.strip_edges()), "field": entry[1]}
		if text.contains(separator):
			part += (" = " if separator == "=" else ": ") + text.get_slice(separator, 1).strip_edges()
		parts.append(part)
	return {"name": new_name, "entries": parts, "problem": "", "field": null}


## Shows what a read says: the red edge on the field it blames, the note, OK held while it is wrong,
## and the line it writes in the band and the strip.
static func _show_read(read: Dictionary, fields: Array, parts: Array, line: String) -> void:
	var problem: String = str(read.get("problem", ""))
	for field: Control in fields:
		EventSheetPopupUI.mark_field(field, field == read.get("field"))
	(parts[1] as EventSheetPopupUI.StateNote).say(problem)
	(parts[0] as ConfirmationDialog).get_ok_button().disabled = not problem.is_empty()
	(parts[2] as EventSheetPopupUI.RowBand).show_row("", line if problem.is_empty() else "")
	(parts[3] as EventSheetPopupUI.HelpStrip).set_reading("", line if problem.is_empty() else "")


## Runs one window's write through the undo funnel and says what it did.
func _commit(undo_note: String, done: String, operation: Callable) -> void:
	if _dock._perform_undoable_sheet_edit(undo_note, operation):
		_dock._refresh_after_edit()
		_dock._mark_dirty(done)


# ── Enum ──────────────────────────────────────────────────────────────────────────────────────
# One field per value (with its remove button) rather than lines in one text box, so every value is
# plainly a separate entry. The model is unchanged - members stays a PackedStringArray - so the
# compile and the byte-gated lift are untouched.
var _enum_dialog: ConfirmationDialog = null
var _enum_band: EventSheetPopupUI.RowBand = null
var _enum_name_edit: LineEdit = null
var _enum_members_box: VBoxContainer = null
var _enum_member_edits: Array[LineEdit] = []
var _enum_multiline_check: CheckBox = null
var _enum_target: EnumRow = null
var _enum_problem_label: EventSheetPopupUI.StateNote = null
var _enum_strip: EventSheetPopupUI.HelpStrip = null


## Opens the enum editor for an EnumRow (double-click or "Add Enum Below").
func open_enum_dialog(enum_resource: Resource) -> void:
	var enum_row: EnumRow = enum_resource as EnumRow
	if enum_row == null:
		return
	_ensure_enum_dialog()
	_populate_enum_dialog(enum_row)
	_enum_dialog.title = EventSheetL10n.translate("Edit enum {name}").replace("{name}", enum_row.enum_name)
	_popup(_enum_dialog, 480.0)


## Fills the (already-built) dialog with the enum's name and one value field per member - the non-popup
## half of open_enum_dialog, so it is drivable without a window.
func _populate_enum_dialog(enum_row: EnumRow) -> void:
	_enum_target = enum_row
	_enum_name_edit.text = enum_row.enum_name
	_enum_multiline_check.button_pressed = enum_row.multiline
	_clear_enum_member_rows()
	if enum_row.members.is_empty():
		_add_enum_member_row("")
	else:
		for member: String in enum_row.members:
			_add_enum_member_row(member)
	_refresh_enum()


func _ensure_enum_dialog() -> void:
	if _enum_dialog != null:
		return
	var parts: Dictionary = _window(EventSheetL10n.translate("Edit Enum"), EventSheetL10n.translate("OK"))
	_enum_dialog = parts["dialog"]
	_enum_band = parts["band"]
	_enum_problem_label = parts["note"]
	_enum_strip = parts["strip"]
	var form: VBoxContainer = parts["form"]
	_enum_name_edit = LineEdit.new()
	_enum_name_edit.placeholder_text = "State"
	_enum_name_edit.text_changed.connect(func(_text: String) -> void: _refresh_enum())
	var name_box: VBoxContainer = EventSheetPopupUI.form_box()
	name_box.add_child(EventSheetPopupUI.form_row(EventSheetL10n.translate("Enum name"), _enum_name_edit))
	form.add_child(EventSheetPopupUI.titled_card(EventSheetL10n.translate("Enum"), name_box))
	var values_box: VBoxContainer = EventSheetPopupUI.form_box()
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(EventSheetPalette.scaled_f(400.0), EventSheetPalette.scaled_f(130.0))
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_enum_members_box = VBoxContainer.new()
	_enum_members_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_enum_members_box)
	values_box.add_child(scroll)
	var add_button: Button = Button.new()
	add_button.text = EventSheetL10n.translate("+ Add value")
	add_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	add_button.pressed.connect(func() -> void:
		var edit: LineEdit = _add_enum_member_row("")
		edit.grab_focus())
	values_box.add_child(add_button)
	# Long enums with explicit values usually write one member per line - the toggle keeps the
	# generated GDScript in that shape (and a lifted multi-line enum arrives with it already on).
	_enum_multiline_check = CheckBox.new()
	_enum_multiline_check.text = EventSheetL10n.translate("Write one value per line (multi-line enum)")
	_enum_multiline_check.toggled.connect(func(_on: bool) -> void: _refresh_enum())
	values_box.add_child(_enum_multiline_check)
	form.add_child(EventSheetPopupUI.titled_card(EventSheetL10n.translate("Values"), values_box))
	_finish_window(parts)
	_enum_strip.follow(_enum_name_edit, EventSheetL10n.translate("Enum name"),
		EventSheetL10n.translate("The enum's name. It becomes a type: a variable can hold one of its values, and a match can pick between them."))
	_enum_strip.follow(add_button, EventSheetL10n.translate("Values"),
		EventSheetL10n.translate("One value per field; an optional \"= 4\" sets an explicit number."))
	_enum_strip.follow(_enum_multiline_check, EventSheetL10n.translate("Multi-line enum"),
		EventSheetL10n.translate("Off: enum State { IDLE, RUN }. On: each value on its own tab-indented line - the usual shape for long enums with explicit numbers."))
	_enum_strip.describe(EventSheetL10n.translate("Values"),
		EventSheetL10n.translate("One value per field; an optional \"= 4\" sets an explicit number."))
	_enum_dialog.confirmed.connect(_on_enum_dialog_confirmed)


## Adds one "value field + remove button" row and returns its LineEdit (so callers can focus it).
func _add_enum_member_row(text: String) -> LineEdit:
	var row: HBoxContainer = HBoxContainer.new()
	var edit: LineEdit = LineEdit.new()
	edit.text = text
	edit.placeholder_text = "IDLE"
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.text_changed.connect(func(_t: String) -> void: _refresh_enum())
	edit.text_submitted.connect(func(_t: String) -> void: _enum_dialog.get_ok_button().grab_focus())
	row.add_child(edit)
	var remove_button: Button = Button.new()
	remove_button.text = "✕"
	remove_button.tooltip_text = EventSheetL10n.translate("Remove this value")
	remove_button.pressed.connect(_remove_enum_member_row.bind(row, edit))
	row.add_child(remove_button)
	_enum_members_box.add_child(row)
	_enum_member_edits.append(edit)
	if _enum_strip != null:
		_enum_strip.follow(edit, EventSheetL10n.translate("Values"),
			EventSheetL10n.translate("One value per field; an optional \"= 4\" sets an explicit number."))
	_refresh_enum()
	return edit


func _remove_enum_member_row(row: HBoxContainer, edit: LineEdit) -> void:
	_enum_member_edits.erase(edit)
	_drop_row(_enum_strip, edit, row, false)
	# Keep at least one field so the list is never empty and there is always somewhere to type.
	if _enum_member_edits.is_empty():
		_add_enum_member_row("")
	_refresh_enum()


func _clear_enum_member_rows() -> void:
	for index: int in range(_enum_members_box.get_child_count() - 1, -1, -1):
		_drop_row(_enum_strip, _enum_member_edits[index], _enum_members_box.get_child(index), true)
	_enum_member_edits.clear()


## Takes one field's row out of its window: the strip stops following the field and the row goes.
static func _drop_row(strip: EventSheetPopupUI.HelpStrip, field: Control, row: Node, now: bool) -> void:
	strip.followed.erase(field)
	row.get_parent().remove_child(row)
	if now:
		row.free()
	else:
		row.queue_free()


## What the fields currently describe: {name, entries (the values), problem, field}.
func _read_enum() -> Dictionary:
	var read: Dictionary = _read_named(_enum_name_edit,
		EventSheetL10n.translate("\"{name}\" can't be an enum name (letters/digits/underscores, not a GDScript keyword)."),
		_enum_member_edits.map(func(edit: LineEdit) -> Array: return [edit.text, edit]), "=",
		EventSheetL10n.translate("\"{name}\" can't be an enum value name."))
	if str(read["problem"]).is_empty() and (read["entries"] as PackedStringArray).is_empty():
		return {"problem": EventSheetL10n.translate("Enums need a name and at least one value."),
			"field": _enum_member_edits[0] if not _enum_member_edits.is_empty() else null}
	return read


## The line the enum compiles to, on one line - what the band and the strip show.
static func enum_line(enum_name: String, members: PackedStringArray) -> String:
	return "enum %s { %s }" % [enum_name, ", ".join(members)]


## Redraws the band, the strip's code line, the red edge and the note, and holds OK while a field is
## wrong - so the reason is on screen before OK is pressed, not after.
func _refresh_enum() -> void:
	if _enum_band == null or _enum_name_edit == null:
		return
	var read: Dictionary = _read_enum()
	_show_read(read, [_enum_name_edit] + _enum_member_edits, [_enum_dialog, _enum_problem_label, _enum_band, _enum_strip],
		enum_line(str(read.get("name", "")), read.get("entries", PackedStringArray()) as PackedStringArray))


func _on_enum_dialog_confirmed() -> void:
	if _enum_target == null:
		return
	var target: EnumRow = _enum_target
	var read: Dictionary = _read_enum()
	if not str(read.get("problem", "")).is_empty():
		_refresh_enum()
		return
	_enum_dialog.hide()
	var new_name: String = str(read["name"])
	var new_members: PackedStringArray = read["entries"]
	var multiline_choice: bool = _enum_multiline_check.button_pressed
	_commit("Edit Enum", "Enum updated (compiles before variables; use it as a variable type).", func() -> bool:
		if target.enum_name == new_name and target.members == new_members and target.multiline == multiline_choice:
			return false
		target.enum_name = new_name
		target.members = new_members
		target.multiline = multiline_choice
		return true)


# ── Signal ────────────────────────────────────────────────────────────────────────────────────
var _signal_dialog: ConfirmationDialog = null
var _signal_band: EventSheetPopupUI.RowBand = null
var _signal_name_edit: LineEdit = null
var _signal_params_edit: TextEdit = null
var _signal_target: SignalRow = null
var _signal_problem_label: EventSheetPopupUI.StateNote = null
var _signal_strip: EventSheetPopupUI.HelpStrip = null


## Opens the signal editor (double-click or "Add Signal Below").
func open_signal_dialog(signal_resource: Resource) -> void:
	var signal_row: SignalRow = signal_resource as SignalRow
	if signal_row == null:
		return
	_ensure_signal_dialog()
	_signal_target = signal_row
	_signal_name_edit.text = signal_row.signal_name
	_signal_params_edit.text = "\n".join(signal_row.params)
	_refresh_signal()
	_signal_dialog.title = EventSheetL10n.translate("Edit signal {name}").replace("{name}", signal_row.signal_name)
	_popup(_signal_dialog, 480.0)


func _ensure_signal_dialog() -> void:
	if _signal_dialog != null:
		return
	var parts: Dictionary = _window(EventSheetL10n.translate("Edit Signal"), EventSheetL10n.translate("OK"))
	_signal_dialog = parts["dialog"]
	_signal_band = parts["band"]
	_signal_problem_label = parts["note"]
	_signal_strip = parts["strip"]
	var box: VBoxContainer = EventSheetPopupUI.form_box()
	_signal_name_edit = LineEdit.new()
	_signal_name_edit.placeholder_text = "hit"
	_signal_name_edit.text_changed.connect(func(_text: String) -> void: _refresh_signal())
	box.add_child(EventSheetPopupUI.form_row(EventSheetL10n.translate("Signal name"), _signal_name_edit))
	_signal_params_edit = TextEdit.new()
	_signal_params_edit.custom_minimum_size = Vector2(EventSheetPalette.scaled_f(260.0), EventSheetPalette.scaled_f(90.0))
	_signal_params_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_signal_params_edit.text_changed.connect(_refresh_signal)
	box.add_child(EventSheetPopupUI.form_row(EventSheetL10n.translate("Parameters"), _signal_params_edit))
	(parts["form"] as VBoxContainer).add_child(EventSheetPopupUI.titled_card(EventSheetL10n.translate("Signal"), box))
	_finish_window(parts)
	_signal_strip.follow(_signal_name_edit, EventSheetL10n.translate("Signal name"),
		EventSheetL10n.translate("What the signal is called. It appears in the On signal and Emit signal pickers under this name."))
	_signal_strip.follow(_signal_params_edit, EventSheetL10n.translate("Parameters"),
		EventSheetL10n.translate("One parameter per line; an optional \"damage: int\" gives it a type."))
	_signal_strip.describe(EventSheetL10n.translate("Parameters"),
		EventSheetL10n.translate("One parameter per line; an optional \"damage: int\" gives it a type."))
	_signal_dialog.confirmed.connect(_on_signal_dialog_confirmed)


## What the fields currently describe: {name, entries (the parameters), problem, field}.
func _read_signal() -> Dictionary:
	return _read_named(_signal_name_edit,
		EventSheetL10n.translate("\"{name}\" can't be a signal name (letters/digits/underscores, not a GDScript keyword)."),
		Array(_signal_params_edit.text.split("\n")).map(func(line: String) -> Array: return [line, _signal_params_edit]),
		":", EventSheetL10n.translate("\"{name}\" can't be a signal parameter name."))


func _refresh_signal() -> void:
	if _signal_band == null or _signal_name_edit == null:
		return
	var read: Dictionary = _read_signal()
	_show_read(read, [_signal_name_edit, _signal_params_edit], [_signal_dialog, _signal_problem_label, _signal_band,
		_signal_strip], "signal %s(%s)" % [str(read.get("name", "")), ", ".join(read.get("entries", PackedStringArray()) as PackedStringArray)])


func _on_signal_dialog_confirmed() -> void:
	if _signal_target == null:
		return
	var target: SignalRow = _signal_target
	var read: Dictionary = _read_signal()
	if not str(read.get("problem", "")).is_empty():
		_refresh_signal()
		return
	_signal_dialog.hide()
	var new_name: String = str(read["name"])
	var new_params: PackedStringArray = read["entries"]
	_commit("Edit Signal", "Signal updated (it now appears in the On/Emit Signal pickers).", func() -> bool:
		if target.signal_name == new_name and target.params == new_params:
			return false
		target.signal_name = new_name
		target.params = new_params
		return true)


# ── Match ─────────────────────────────────────────────────────────────────────────────────────
# Laid out like the parameters window: the Value the match decides by (with the sheet's variables
# offered as you type), then one row per branch - "Match 1  IDLE" - and Otherwise for the rest. The
# window writes the BRANCHES only; each one lands on the sheet as a sub-event whose actions are added
# there from the picker, like any event. Re-editing keeps every branch's actions: a row remembers the
# MatchCase it came from, so only its value changes.
var _match_dialog: ConfirmationDialog = null
var _match_band: EventSheetPopupUI.RowBand = null
var _match_expression_edit: LineEdit = null
var _match_value_info: Label = null
var _match_cases_box: VBoxContainer = null
var _match_case_rows: Array = []  # each: {"pattern": LineEdit, "row": Control, "case": MatchCase or null}
var _match_otherwise: OptionButton = null
var _match_fill_button: Button = null
var _match_note: EventSheetPopupUI.StateNote = null
var _match_strip: EventSheetPopupUI.HelpStrip = null
var _match_target: MatchRow = null
## The event a NEW match is added to on Done (null when an existing match is being edited).
var _match_host: EventRow = null
## The `_` branch the match already had, so Otherwise keeps its actions across an edit.
var _match_otherwise_case: MatchCase = null
## How many actions the rows removed in this sitting held - said out loud before Done drops them.
var _match_dropped_actions: int = 0
var _match_variables: Array[Dictionary] = []


## Opens the Match window on an existing match (double-click its head or a branch), or - with `host` -
## on a new one that Done adds to that event's actions in one undo step.
func open_match_dialog(match_resource: Resource, host: EventRow = null) -> void:
	var match_row: MatchRow = match_resource as MatchRow
	if match_row == null:
		return
	_ensure_match_dialog()
	_match_host = host
	_populate_match_dialog(match_row)
	_popup(_match_dialog, 520.0)


## Fills the (already-built) window from the match - the non-popup half of open_match_dialog, so it is
## drivable without a window. Branches come from the structured `cases`, or from branches_text split the
## way the importer splits it; the last `_` becomes Otherwise.
func _populate_match_dialog(match_row: MatchRow) -> void:
	_match_target = match_row
	_match_variables.clear()
	if _dock._current_sheet != null:
		_match_variables = EventSheetVariableOwners.own_entries(_dock._current_sheet)
		_match_variables.append_array(EventSheetVariableOwners.local_entries(_dock._current_sheet))
	_match_expression_edit.text = match_row.match_expression
	_clear_match_case_rows()
	_match_dropped_actions = 0
	_match_otherwise_case = null
	var cases: Array[MatchCase] = match_row.cases
	if cases.is_empty() and not match_row.branches_text.strip_edges().is_empty():
		cases = EventSheetACELifter._structure_match_cases(match_row.branches_text.split("\n"))
	var otherwise: bool = cases.is_empty()
	for case_index: int in range(cases.size()):
		var match_case: MatchCase = cases[case_index]
		if match_case.pattern.strip_edges() == "_" and case_index == cases.size() - 1:
			_match_otherwise_case = match_case
			otherwise = true
			continue
		_add_match_case_row(_pattern_shown(match_case.pattern), match_case)
	if _match_case_rows.is_empty():
		_add_match_case_row("")
	_match_otherwise.select(0 if otherwise else 1)
	_refresh_match()


func _ensure_match_dialog() -> void:
	if _match_dialog != null:
		return
	var parts: Dictionary = _window(EventSheetL10n.translate("Parameters for System: Match"), EventSheetL10n.translate("Done"))
	_match_dialog = parts["dialog"]
	_match_band = parts["band"]
	_match_note = parts["note"]
	_match_strip = parts["strip"]
	var box: VBoxContainer = EventSheetPopupUI.form_box()
	_match_expression_edit = LineEdit.new()
	_match_expression_edit.placeholder_text = "state"
	_match_expression_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_match_expression_edit.text_changed.connect(func(_text: String) -> void: _refresh_match())
	var value_row: HBoxContainer = HBoxContainer.new()
	value_row.add_child(_match_expression_edit)
	var value_pick: MenuButton = EventSheetPopupUI.autocomplete_combo(_match_expression_edit,
		func() -> PackedStringArray: return _value_choices(), _value_note)
	value_pick.tooltip_text = EventSheetL10n.translate("This sheet's variables (any expression still works)")
	value_row.add_child(value_pick)
	box.add_child(EventSheetPopupUI.form_row(EventSheetL10n.translate("Value"), value_row))
	_match_value_info = EventSheetPopupUI.hint_label("", EventSheetPalette.scaled_f(300.0))
	_match_value_info.add_theme_color_override("font_color", EventSheetPopupUI.muted_text_color())
	box.add_child(_match_value_info)
	_match_cases_box = VBoxContainer.new()
	_match_cases_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(_match_cases_box)
	_match_otherwise = EventSheetPopupUI.described_option()
	EventSheetPopupUI.add_described_item(_match_otherwise, EventSheetL10n.translate("Else (anything else)"),
		EventSheetL10n.translate("A last branch for every value the matches above do not name."))
	EventSheetPopupUI.add_described_item(_match_otherwise, EventSheetL10n.translate("Nothing"),
		EventSheetL10n.translate("No last branch: a value no match names does nothing."))
	_match_otherwise.item_selected.connect(func(_index: int) -> void: _refresh_match())
	box.add_child(EventSheetPopupUI.form_row(EventSheetL10n.translate("Otherwise"), _match_otherwise))
	var buttons: HBoxContainer = HBoxContainer.new()
	var add_button: Button = Button.new()
	add_button.text = EventSheetL10n.translate("+ Add match")
	add_button.pressed.connect(func() -> void:
		var entry: Dictionary = _add_match_case_row("")
		(entry["pattern"] as LineEdit).grab_focus()
		_refresh_match())
	buttons.add_child(add_button)
	# One click adds a branch for every value of the enum the Value holds, so a match on a state
	# starts exhaustive and correctly named. Non-destructive: values already there are skipped.
	_match_fill_button = Button.new()
	_match_fill_button.text = EventSheetL10n.translate("One match per state")
	_match_fill_button.pressed.connect(func() -> void:
		_fill_cases_from_subject()
		_refresh_match())
	buttons.add_child(_match_fill_button)
	box.add_child(buttons)
	box.add_child(EventSheetPopupUI.hint_label(
		EventSheetL10n.translate("Each match becomes a sub-event on the sheet; its actions are added there, like any event."),
		EventSheetPalette.scaled_f(400.0)))
	(parts["form"] as VBoxContainer).add_child(EventSheetPopupUI.titled_card(EventSheetL10n.translate("Match"), box))
	_finish_window(parts)
	_match_strip.describe(EventSheetL10n.translate("Match"),
		EventSheetL10n.translate("Run one branch, picked by comparing a value: like a chain of Compare events ending in Else."))
	_match_strip.follow(_match_expression_edit, EventSheetL10n.translate("Value"),
		EventSheetL10n.translate("What the match compares. Pick one of this sheet's variables from the list, or type any expression."))
	_match_strip.follow_option(_match_otherwise, func(_index: int) -> Dictionary:
		return {"heading": EventSheetL10n.translate("Otherwise"),
			"body": EventSheetL10n.translate("Else catches every value the matches above do not name; it stays empty (does nothing) until you add actions to it.")})
	_match_strip.follow(add_button, EventSheetL10n.translate("+ Add match"),
		EventSheetL10n.translate("Adds one more value to pick between."))
	_match_strip.follow(_match_fill_button, EventSheetL10n.translate("One match per state"),
		EventSheetL10n.translate("Adds a match for every value of the enum the Value holds, skipping the ones already here."),
		_fill_button_help)
	_match_dialog.confirmed.connect(_on_match_dialog_confirmed)


## Adds one branch row (its value field, the suggestions, a remove button) and returns its parts.
## `source_case` is the MatchCase the row edits, so its actions survive a change of value.
func _add_match_case_row(shown_pattern: String, source_case: MatchCase = null) -> Dictionary:
	var head: HBoxContainer = HBoxContainer.new()
	var pattern_edit: LineEdit = LineEdit.new()
	pattern_edit.text = shown_pattern
	pattern_edit.placeholder_text = "IDLE"
	pattern_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pattern_edit.text_changed.connect(func(_text: String) -> void: _refresh_match())
	head.add_child(pattern_edit)
	var pick: MenuButton = EventSheetPopupUI.autocomplete_combo(pattern_edit,
		func() -> PackedStringArray: return PackedStringArray(_match_pattern_choices()))
	pick.tooltip_text = EventSheetL10n.translate("Pick a value for this branch (you can still type any)")
	head.add_child(pick)
	var remove_button: Button = Button.new()
	remove_button.text = "✕"
	remove_button.tooltip_text = EventSheetL10n.translate("Remove this match")
	head.add_child(remove_button)
	var row: Control = EventSheetPopupUI.form_row("", head)
	_match_cases_box.add_child(row)
	var entry: Dictionary = {"pattern": pattern_edit, "row": row, "case": source_case}
	remove_button.pressed.connect(func() -> void:
		_remove_match_case_row(entry)
		_refresh_match())
	_match_case_rows.append(entry)
	if _match_strip != null:
		_match_strip.follow(pattern_edit, EventSheetL10n.translate("Match"),
			EventSheetL10n.translate("The value this branch runs for: pick from the list or type any value. Otherwise catches everything else."))
	_relabel_match_rows()
	return entry


func _remove_match_case_row(entry: Dictionary) -> void:
	var source_case: MatchCase = entry.get("case") as MatchCase
	if source_case != null:
		_match_dropped_actions += source_case.events.size()
	_match_case_rows.erase(entry)
	_drop_row(_match_strip, entry["pattern"], entry["row"], false)
	if _match_case_rows.is_empty():
		_add_match_case_row("")
	_relabel_match_rows()


func _clear_match_case_rows() -> void:
	for entry: Dictionary in _match_case_rows:
		_drop_row(_match_strip, entry["pattern"], entry["row"], true)
	_match_case_rows.clear()


## "Match 1", "Match 2", … down the rows, renumbered after a removal.
func _relabel_match_rows() -> void:
	for index: int in range(_match_case_rows.size()):
		var row: Control = _match_case_rows[index]["row"]
		var caption: Label = row.get_child(0) as Label
		if caption != null:
			caption.text = EventSheetL10n.translate("Match {n}").replace("{n}", str(index + 1))


## The variable names the Value field offers: this sheet's own and its locals.
func _value_choices() -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	for entry: Dictionary in _match_variables:
		names.append(str(entry.get("insert_text", entry.get("name", ""))))
	return names


## The type a Value suggestion shows beside its name.
func _value_note(suggestion: String) -> String:
	return str(_variable_entry(suggestion).get("type_name", ""))


func _variable_entry(var_name: String) -> Dictionary:
	for entry: Dictionary in _match_variables:
		if str(entry.get("insert_text", entry.get("name", ""))) == var_name:
			return entry
	return {}


## The sheet's enums as [{name, members}], read straight off the live sheet, groups included.
func _sheet_enums() -> Array:
	var out: Array = []
	var sheet: EventSheetResource = _dock._current_sheet
	if sheet == null:
		return out
	var rows: Array = []
	SheetCompiler._collect_enum_rows(sheet.events, rows)
	for row: Variant in rows:
		if row is EnumRow and (row as EnumRow).enabled:
			out.append({"name": (row as EnumRow).enum_name, "members": (row as EnumRow).members})
	return out


## The sheet enum the Value holds (its variable's type is that enum), or "".
func _subject_enum_name() -> String:
	var type_name: String = str(_variable_entry(_match_expression_edit.text.strip_edges()).get("type_name", ""))
	for enum_entry: Dictionary in _sheet_enums():
		if str(enum_entry.get("name")) == type_name:
			return type_name
	return ""


## The member names of one sheet enum, any "= 4" dropped.
func _enum_members(enum_name: String) -> PackedStringArray:
	var members: PackedStringArray = PackedStringArray()
	for enum_entry: Dictionary in _sheet_enums():
		if str(enum_entry.get("name")) == enum_name:
			for member: Variant in enum_entry.get("members", []):
				members.append(str(member).get_slice("=", 0).strip_edges())
	return members


## The values a branch offers. When the Value holds a sheet enum, that enum's members by their own
## names (IDLE, RUN); true / false for a bool; otherwise every sheet enum's members as Enum.MEMBER.
func _match_pattern_choices() -> Array:
	var subject_enum: String = _subject_enum_name()
	if not subject_enum.is_empty():
		return Array(_enum_members(subject_enum))
	var choices: Array = []
	if str(_variable_entry(_match_expression_edit.text.strip_edges()).get("type_name", "")) == "bool":
		return ["true", "false"]
	for enum_entry: Dictionary in _sheet_enums():
		for member: String in _enum_members(str(enum_entry.get("name"))):
			choices.append("%s.%s" % [str(enum_entry.get("name")), member])
	return choices


## A branch's value as written into the code: a bare member of the Value's enum gains its enum's
## name (IDLE -> State.IDLE); anything else is written exactly as typed.
func _pattern_written(shown: String) -> String:
	var text: String = shown.strip_edges()
	var subject_enum: String = _subject_enum_name()
	if not subject_enum.is_empty() and _enum_members(subject_enum).has(text):
		return "%s.%s" % [subject_enum, text]
	return text


## The inverse, for a branch read back into the window: State.IDLE shows as IDLE when the Value holds
## State. Display only.
func _pattern_shown(pattern: String) -> String:
	var subject_enum: String = _subject_enum_name()
	if not subject_enum.is_empty() and pattern.strip_edges().begins_with(subject_enum + "."):
		var member: String = pattern.strip_edges().substr(subject_enum.length() + 1)
		if _enum_members(subject_enum).has(member):
			return member
	return pattern.strip_edges()


## Adds a branch for every member of the Value's enum not already there, filling an empty first row
## rather than leaving it blank above them.
func _fill_cases_from_subject() -> void:
	var subject_enum: String = _subject_enum_name()
	if subject_enum.is_empty():
		return
	var existing: Array = []
	for entry: Dictionary in _match_case_rows.duplicate():
		var shown: String = (entry["pattern"] as LineEdit).text.strip_edges()
		if shown.is_empty() and entry.get("case") == null:
			_match_case_rows.erase(entry)
			_drop_row(_match_strip, entry["pattern"], entry["row"], true)
			continue
		existing.append(_pattern_written(shown))
	for member: String in _enum_members(subject_enum):
		if not existing.has("%s.%s" % [subject_enum, member]):
			_add_match_case_row(member)
	_relabel_match_rows()


func _fill_button_help() -> String:
	if _subject_enum_name().is_empty():
		return EventSheetL10n.translate("Pick a Value whose type is one of this sheet's enums, and this adds a match for each of its values.")
	return EventSheetL10n.translate("Adds a match for every value of the enum the Value holds, skipping the ones already here.")


## The branches the window describes right now, as patterns in order (Otherwise's `_` last).
func _match_patterns() -> PackedStringArray:
	var patterns: PackedStringArray = PackedStringArray()
	for entry: Dictionary in _match_case_rows:
		var written: String = _pattern_written((entry["pattern"] as LineEdit).text)
		if not written.is_empty():
			patterns.append(written)
	if _match_otherwise.selected == 0:
		patterns.append("_")
	return patterns


## Why Done cannot write the match yet, or "": a Value, at least one branch, no value twice.
func match_problem() -> String:
	if _match_expression_edit.text.strip_edges().is_empty():
		return EventSheetL10n.translate("Give the match a Value to compare.")
	var patterns: PackedStringArray = _match_patterns()
	if patterns.is_empty():
		return EventSheetL10n.translate("Add at least one match, or choose Else for Otherwise.")
	var seen: Dictionary = {}
	for pattern: String in patterns:
		if seen.has(pattern):
			return EventSheetL10n.translate("{value} is matched twice - the second one could never run.").replace("{value}", _pattern_shown(pattern))
		seen[pattern] = true
	return ""


## Redraws the band, the code line, the state note and the Value's info line, and holds Done while
## the window cannot write a match.
func _refresh_match() -> void:
	if _match_band == null or _match_expression_edit == null or _match_otherwise == null:
		return
	var subject: String = _match_expression_edit.text.strip_edges()
	var entry: Dictionary = _variable_entry(subject)
	var info: String = ""
	if not entry.is_empty():
		info = "%s (%s)" % [subject, str(entry.get("type_name", ""))]
		if not str(entry.get("description", "")).is_empty():
			info += " - " + str(entry.get("description", ""))
	_match_value_info.text = info
	_match_value_info.visible = not info.is_empty()
	_match_fill_button.disabled = _subject_enum_name().is_empty()
	_match_band.show_row(EventSheetL10n.translate("System"), "%s %s" % [EventSheetL10n.translate("match"), subject])
	var patterns: PackedStringArray = _match_patterns()
	_match_strip.set_reading("", match_code_line(subject, patterns))
	var problem: String = match_problem()
	_match_dialog.get_ok_button().disabled = not problem.is_empty()
	if not problem.is_empty():
		_match_note.say(problem)
	elif _match_dropped_actions > 0:
		_match_note.say(EventSheetL10n.translate("Done drops the {n} action(s) the removed matches held.").replace("{n}", str(_match_dropped_actions)), EventSheetPopupUI.TONE_WARNING)
	elif _match_host != null:
		_match_note.say(EventSheetL10n.translate("Done sets up {n} events on the sheet, ready for your actions.").replace("{n}", str(patterns.size())), EventSheetPopupUI.TONE_OK)
	else:
		_match_note.say(EventSheetL10n.translate("Done updates the match: {n} branches, each keeping its actions.").replace("{n}", str(patterns.size())), EventSheetPopupUI.TONE_OK)


## The code a match writes, folded onto one line for the strip: `match state: State.IDLE: … _: pass`.
static func match_code_line(subject: String, patterns: PackedStringArray) -> String:
	if subject.is_empty():
		return ""
	var arms: PackedStringArray = PackedStringArray()
	for pattern: String in patterns:
		arms.append("%s: %s" % [pattern, "pass" if pattern == "_" else "…"])
	return "match %s: %s" % [subject, "  ".join(arms)]


## Builds the branches from the rows: a row that came from a case keeps that case (and its actions)
## with its new value; a new row is a new, empty branch; Otherwise keeps the old `_` branch.
func _built_cases() -> Array[MatchCase]:
	var cases: Array[MatchCase] = []
	for entry: Dictionary in _match_case_rows:
		var written: String = _pattern_written((entry["pattern"] as LineEdit).text)
		if written.is_empty():
			continue
		cases.append(_branch(written, entry.get("case") as MatchCase))
	if _match_otherwise.selected == 0:
		cases.append(_branch("_", _match_otherwise_case))
	return cases


## A branch with `pattern`, carrying the actions (and the on/off) of `source` when there is one. A new
## MatchCase rather than the source itself: the live sheet only changes inside the undo funnel.
static func _branch(pattern: String, source: MatchCase) -> MatchCase:
	var match_case: MatchCase = MatchCase.new()
	match_case.pattern = pattern
	if source != null:
		match_case.enabled = source.enabled
		match_case.events = source.events.duplicate()
	return match_case


func _on_match_dialog_confirmed() -> void:
	if _match_target == null:
		return
	var problem: String = match_problem()
	var expression: String = _match_expression_edit.text.strip_edges()
	var new_cases: Array[MatchCase] = _built_cases()
	# The whole construct must compile before it commits: a value that is not valid code says so here.
	if problem.is_empty():
		var verdict: Dictionary = EventSheetGDScriptLint.lint(_match_construct_preview(expression, new_cases), true, _dock._current_sheet)
		if not bool(verdict.get("ok", true)):
			problem = EventSheetL10n.translate("The match doesn't compile - check the Value and each match's value.")
	if not problem.is_empty():
		_refresh_match()
		_match_note.say(problem)
		return
	_match_dialog.hide()
	var target: MatchRow = _match_target
	var host: EventRow = _match_host
	_match_host = null
	_commit("Add Match" if host != null else "Edit Match",
		"Match updated." if host == null else "Match added - add each branch's actions on the sheet.", func() -> bool:
			if host == null and target.match_expression == expression and _same_cases(target.cases, new_cases):
				return false
			target.match_expression = expression
			target.cases = new_cases
			# The raw form is only read while `cases` is empty; written from the cases it stays a true copy.
			target.branches_text = _match_branches_from_cases(new_cases)
			if host != null and not host.actions.has(target):
				host.actions.append(target)
			return true)


## True when two branch lists hold the same patterns and the same actions - an untouched Done.
static func _same_cases(old_cases: Array[MatchCase], new_cases: Array[MatchCase]) -> bool:
	if old_cases.size() != new_cases.size():
		return false
	for index: int in range(old_cases.size()):
		if old_cases[index].pattern != new_cases[index].pattern or old_cases[index].events.size() != new_cases[index].events.size():
			return false
	return true


## Lands an action in one branch - the Add action door under a branch row. A branch whose whole body is
## the `pass` a file needed for an empty arm gives that line up: it was only ever holding the place.
static func append_case_action(match_case: MatchCase, action: Resource) -> void:
	if match_case.events.size() == 1 and match_case.events[0] is RawCodeRow \
			and (match_case.events[0] as RawCodeRow).code.strip_edges() == "pass":
		match_case.events = []
	match_case.events.append(action)


## The body text a branch holds as code (its RawCodeRows joined), for the lint gate and the raw copy.
static func _case_body_text(match_case: MatchCase) -> String:
	var lines: PackedStringArray = PackedStringArray()
	for item: Variant in match_case.events:
		if item is RawCodeRow:
			lines.append((item as RawCodeRow).code)
	return "\n".join(lines)


## The whole construct for the lint gate: `match expr:` + each branch's pattern and a `pass` body. The
## bodies are the sheet's own rows and compile with it; the window only answers for the patterns.
static func _match_construct_preview(expression: String, cases: Array[MatchCase]) -> String:
	var lines: PackedStringArray = PackedStringArray(["match %s:" % expression])
	for match_case: MatchCase in cases:
		lines.append("\t%s:" % match_case.pattern)
		lines.append("\t\tpass")
	return "\n".join(lines)


## The verbatim branches_text kept in step with the cases (the raw fallback): each pattern, then its
## code body or `pass`.
static func _match_branches_from_cases(cases: Array[MatchCase]) -> String:
	var lines: PackedStringArray = PackedStringArray()
	for match_case: MatchCase in cases:
		lines.append(match_case.pattern + ":")
		var body_text: String = _case_body_text(match_case)
		if body_text.strip_edges().is_empty():
			lines.append("\tpass")
		else:
			for body_line: String in body_text.split("\n"):
				lines.append("\t" + body_line)
	return "\n".join(lines)
