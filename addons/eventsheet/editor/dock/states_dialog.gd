# Godot EventSheets - the States window: one object's states, declared once.
#
# Double-click the state row (or choose Declare states) and this opens as "States of <variable>": what the
# machine is for, then its states in order - each with a name, a sentence and a radio that says which one
# the object starts in - and the doors to add, remove, reorder and rename them. A rename is a rename
# EVERYWHERE, across the whole project: every row, trigger and hand-written line of the sheet, and every
# other script that names the state through the declaring class, says the new name in the same edit, and
# the window lists those files first. Removing a state does the same with the state the rows move to - the
# default - so nothing is ever left pointing at a state that is gone, and one Undo takes all of it back.
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
## The machine this window edits, as EventSheetStateFacts.machine hands it back ({} for a sheet with none
## yet, which is the primary State machine about to be declared).
var _found: Dictionary = {}
## The state the window opened on, picked in the list; -1 when none was asked for.
var _picked: int = -1
## The list of what a rename or removal will change, rebuilt as the working copy changes.
var _effects: VBoxContainer = null
## Every project script as {path: text}, read once when a change first needs it and dropped on close.
var _sources: Dictionary = {}
var _sources_ready: bool = false


func init(dock: Control) -> void:
	_dock = dock


## Opens the window on this sheet's machine, or on a first set for a sheet that has none - three states
## an object usually grows, which the author is free to rewrite before Apply.
##
## `variable_name` says which machine (the primary `state`, or another `<x>_state` variable typed by an
## enum of its own) and `picked` which of its states is picked in the list when it opens.
func open(variable_name: String = EventSheetStateFacts.STATE_VARIABLE, picked: String = "") -> void:
	if _dock._current_sheet == null:
		return
	# A .gd opened as a preview holds only a skeleton of its rows. The window lists everything a rename or
	# a removal reaches, so it works on the whole sheet from the start, the way any edit does.
	_dock._ace_apply._unlock_preview_for_edit()
	var sheet: EventSheetResource = _dock._current_sheet
	_build()
	_found = EventSheetStateFacts.machine(sheet, variable_name)
	var model: Dictionary = model_of(sheet, _found)
	_entries = model["states"]
	_description = str(model["description"])
	_default_index = int(model["default"])
	_picked = -1
	for index: int in _entries.size():
		if str((_entries[index] as Dictionary)["name"]) == picked:
			_picked = index
	_sources.clear()
	_sources_ready = false
	_dialog.title = EventSheetL10n.translate("States of %s") % variable_name
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

	# What a rename or a removal will change, listed before Apply writes any of it.
	_effects = VBoxContainer.new()
	_effects.name = "StatesEffects"
	_effects.add_theme_constant_override("separation", 2)
	form.add_child(_effects)

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
	_refresh_effects()


func _state_row(index: int, counts: Dictionary) -> Control:
	var entry: Dictionary = _entries[index]
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "State%d" % index
	row.add_theme_constant_override("separation", 6)
	if index == _picked:
		# The state a click in the sheet's row asked for wears the editor's accent, so it is the one a
		# reader's eye lands on; the colour comes from the theme, light or dark.
		var plate: PanelContainer = PanelContainer.new()
		plate.name = "State%dPicked" % index
		var fill: StyleBoxFlat = StyleBoxFlat.new()
		fill.bg_color = Color(EventSheetPopupUI.accent_color(), 0.28)
		fill.set_corner_radius_all(4)
		fill.content_margin_left = 4.0
		fill.content_margin_right = 4.0
		fill.content_margin_top = 2.0
		fill.content_margin_bottom = 2.0
		plate.add_theme_stylebox_override("panel", fill)
		plate.add_child(row)
		_fill_state_row(row, index, entry, counts)
		return plate
	_fill_state_row(row, index, entry, counts)
	return row


func _fill_state_row(row: HBoxContainer, index: int, entry: Dictionary, counts: Dictionary) -> void:
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
		_show_code()
		_refresh_effects())
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
			_show_code()
			_refresh_effects())
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
	# A state some row still says is removed all the same: the list below says which rows, and Apply moves
	# them to the default.
	_entries.remove_at(index)
	if _picked == index:
		_picked = -1
	elif _picked > index:
		_picked -= 1
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


## The working copy as the statics take it, with the original states that are gone from the list.
func _working_model() -> Dictionary:
	var model: Dictionary = {"states": _entries.duplicate(true), "description": _description, "default": _default_index}
	model["removed"] = removed_members(_dock._current_sheet, model, _found)
	return model


## Every project script, read the first time a change needs them.
func _project_sources() -> Dictionary:
	if not _sources_ready:
		_sources = EventSheetStateUses.read_project()
		_sources_ready = true
	return _sources


## The list under the form: for each rename and each removal, where it reaches - this sheet's rows and
## every other file - so Apply is never a surprise. Empty while nothing renames or goes.
func _refresh_effects() -> void:
	if _effects == null or _dock == null or _dock._current_sheet == null:
		return
	for child: Node in _effects.get_children():
		_effects.remove_child(child)
		child.queue_free()
	var sheet: EventSheetResource = _dock._current_sheet
	var model: Dictionary = _working_model()
	if renames_of(model).is_empty() and (model["removed"] as PackedStringArray).is_empty():
		return
	var lines: PackedStringArray = effect_lines(sheet, model, _found, _project_sources())
	for line: String in lines:
		var label: Label = Label.new()
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = 520.0
		label.text = line
		label.add_theme_color_override("font_color", EventSheetPopupUI.secondary_text_color())
		_effects.add_child(label)


func _show_code() -> void:
	if _code != null:
		_code.text = code_for({"states": _entries, "description": _description, "default": _default_index})


func _on_confirmed() -> void:
	var sheet: EventSheetResource = _dock._current_sheet
	var model: Dictionary = _working_model()
	var problem: String = problem_with(sheet, model, _found)
	if not problem.is_empty():
		# Said where the typing was, and the window stays open on it: the fix is one edit.
		_problem_label.say(problem)
		_dialog.show()
		return
	_problem_label.say("")
	_dialog.hide()
	# Every other script that names a renamed or removed state is rewritten in the same step, so ONE Undo
	# puts the open sheet and those files back together.
	var file_edits: Dictionary = project_file_edits(sheet, model, _found, _project_sources())
	if not _dock._perform_undoable_sheet_edit(EventSheetL10n.translate("Edit states"), func() -> bool:
			return apply_model(_dock._current_sheet, model, _found), file_edits):
		return
	_dock._refresh_after_edit()
	_dock._set_status(EventSheetL10n.translate("%d state(s) declared - rows can now say which one this object is in.")
		% _entries.size())


# ── The working copy, and what it writes (static and pure, so the suite drives all of it) ──────────────
## The window's working copy of the sheet's machine: {"states": [{"orig", "name", "note"}], "description",
## "default"}. A sheet with no machine gets three states an object usually grows, which the author is free
## to rewrite before Apply.
static func model_of(sheet: EventSheetResource, found: Dictionary = {}) -> Dictionary:
	var states: Array = []
	var declared: EnumRow = EventSheetStateFacts.enum_row(sheet) if found.is_empty() else found["enum"] as EnumRow
	if declared == null or declared.members.is_empty():
		for first: String in ["IDLE", "CHASE", "HURT"]:
			states.append({"orig": "", "name": first, "note": ""})
		return {"states": states, "description": "", "default": 0, "removed": PackedStringArray()}
	for member: String in declared.members:
		var bare: String = EnumRow.bare_name(member)
		states.append({"orig": bare, "name": bare, "note": declared.note_for(bare)})
	var default_name: String = EventSheetStateFacts.default_member(sheet, found)
	var default_at: int = 0
	for index: int in states.size():
		if str((states[index] as Dictionary)["name"]) == default_name:
			default_at = index
	return {"states": states, "description": declared.description, "default": default_at, "removed": PackedStringArray()}


## What is wrong with applying this working copy, said as one sentence, or "" when nothing is. A rename is
## never a problem - it is followed everywhere - but a name that cannot be an identifier, two states of one
## name, and two states of one name. A removal is no problem: the rows that used the state move to the
## default, and the window lists them first.
static func problem_with(sheet: EventSheetResource, model: Dictionary, _found: Dictionary = {}) -> String:
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
	return ""


## The original members the working copy no longer lists - the states removed in the window.
static func removed_members(sheet: EventSheetResource, model: Dictionary, found: Dictionary = {}) -> PackedStringArray:
	var kept: PackedStringArray = PackedStringArray()
	for entry: Dictionary in model["states"]:
		if not str(entry["orig"]).is_empty():
			kept.append(str(entry["orig"]))
	var gone: PackedStringArray = PackedStringArray()
	for member: String in EventSheetStateFacts.bare_members(sheet, found):
		if not kept.has(member):
			gone.append(member)
	return gone


## The renames the working copy makes: [[from, to], ...], in list order.
static func renames_of(model: Dictionary) -> Array:
	var renames: Array = []
	for entry: Dictionary in model["states"]:
		var from: String = str(entry["orig"])
		var to: String = str(entry["name"]).strip_edges()
		if not from.is_empty() and from != to:
			renames.append([from, to])
	return renames


## The state the rows of a removed state move to: the machine's new default, said by its new name.
static func default_name_of(model: Dictionary) -> String:
	var states: Array = model["states"]
	if states.is_empty():
		return ""
	return str((states[clampi(int(model["default"]), 0, states.size() - 1)] as Dictionary)["name"]).strip_edges()


## What Apply will change, one sentence per rename and per removal: this sheet's rows, then each other
## file with its count. `sources` is {path: text} of the project's scripts. Empty when nothing changes.
static func effect_lines(sheet: EventSheetResource, model: Dictionary, found: Dictionary, sources: Dictionary) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	var declaring: String = sheet.custom_class_name.strip_edges()
	var enum_name: String = str(found.get("enum_name", EventSheetStateFacts.ENUM_NAME))
	var skip: Dictionary = {}
	if not sheet.external_source_path.is_empty():
		skip[sheet.external_source_path] = true
	var target: String = default_name_of(model)
	var changes: Array = []
	for pair: Array in renames_of(model):
		changes.append([str(pair[0]), str(pair[1]), false])
	for member: String in removed_members(sheet, model, found):
		changes.append([member, target, true])
	for change: Array in changes:
		var member: String = str(change[0])
		var places: PackedStringArray = PackedStringArray()
		var here: int = rows_using(sheet, member, found)
		if here > 0:
			places.append(EventSheetL10n.translate("this sheet (1 row)") if here == 1 else EventSheetL10n.translate("this sheet (%d rows)") % here)
		var uses: Array[Dictionary] = EventSheetStateUses.scan(sources, declaring, enum_name, PackedStringArray([member]), skip)
		for entry: Dictionary in uses:
			places.append("%s (%s)" % [str(entry["path"]).get_file(),
				EventSheetL10n.translate("1 place") if int(entry["count"]) == 1 else EventSheetL10n.translate("%d places") % int(entry["count"])])
		if bool(change[2]):
			if places.is_empty():
				lines.append(EventSheetL10n.translate("%s is removed. No row uses it.") % member)
			else:
				lines.append(EventSheetL10n.translate("%s is removed. These move to %s, the default: %s.") % [member, str(change[1]), ", ".join(places)])
		else:
			if places.is_empty():
				lines.append(EventSheetL10n.translate("%s becomes %s. No row uses it.") % [member, str(change[1])])
			else:
				lines.append(EventSheetL10n.translate("%s becomes %s in: %s.") % [member, str(change[1]), ", ".join(places)])
	return lines


## How many places of this sheet a rename of `member` would change: asked of a copy by running the very
## rename Apply runs, so the list the window shows and the edit it makes cannot disagree.
static func rows_using(sheet: EventSheetResource, member: String, found: Dictionary = {}) -> int:
	var copy: EventSheetResource = sheet.duplicate(true)
	var machine_here: Dictionary = {}
	if not found.is_empty():
		machine_here = EventSheetStateFacts.machine(copy, str(found.get("variable_name", EventSheetStateFacts.STATE_VARIABLE)))
	return rename_everywhere(copy, member, "__COUNTED__", machine_here)


## The edits to the project's OTHER scripts that Apply makes: {path: {"before", "after"}} for every script
## that names a renamed or removed state through the declaring class. A swap of two names goes through a
## placeholder, like the sheet's own rows do. Empty when no other script is touched.
static func project_file_edits(sheet: EventSheetResource, model: Dictionary, found: Dictionary, sources: Dictionary) -> Dictionary:
	var edits: Dictionary = {}
	var declaring: String = sheet.custom_class_name.strip_edges()
	if declaring.is_empty() or sources.is_empty():
		return edits
	var enum_name: String = str(found.get("enum_name", EventSheetStateFacts.ENUM_NAME))
	var skip: Dictionary = {}
	if not sheet.external_source_path.is_empty():
		skip[sheet.external_source_path] = true
	var renames: Array = renames_of(model)
	var removed: PackedStringArray = removed_members(sheet, model, found)
	var target: String = default_name_of(model)
	var touched: PackedStringArray = PackedStringArray()
	for pair: Array in renames:
		touched.append(str(pair[0]))
	touched.append_array(removed)
	for entry: Dictionary in EventSheetStateUses.scan(sources, declaring, enum_name, touched, skip):
		var path: String = str(entry["path"])
		var before: String = str(sources[path])
		var text: String = before
		var placeholders: Array = []
		for index: int in renames.size():
			var placeholder: String = "__STATE_RENAME_%d__" % index
			text = str(EventSheetStateUses.rewrite(text, declaring, enum_name, str(renames[index][0]), placeholder)["text"])
			placeholders.append([placeholder, str(renames[index][1])])
		for pair: Array in placeholders:
			text = str(EventSheetStateUses.rewrite(text, declaring, enum_name, str(pair[0]), str(pair[1]))["text"])
		for member: String in removed:
			text = str(EventSheetStateUses.rewrite(text, declaring, enum_name, member, target)["text"])
		if text != before:
			edits[path] = {"before": before, "after": text}
	return edits


## Writes the working copy onto the sheet, every rename followed through every row. Returns whether it did;
## an unwritable copy (see problem_with) changes nothing.
static func apply_model(sheet: EventSheetResource, model: Dictionary, found: Dictionary = {}) -> bool:
	if sheet == null or not problem_with(sheet, model, found).is_empty():
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
		rename_everywhere(sheet, str(renames[index][0]), placeholder, found)
		placeholders.append([placeholder, str(renames[index][1])])
	for pair: Array in placeholders:
		rename_everywhere(sheet, str(pair[0]), str(pair[1]), found)
	# A removed state's rows move to the default, so nothing is left pointing at a state that is gone.
	for gone: String in removed_members(sheet, model, found):
		if gone != opening:
			rename_everywhere(sheet, gone, opening, found)
	# What each member says after its name ("HURT = 4") belongs to the member, so it travels with it.
	var written: Dictionary = {}
	var declared: EnumRow = EventSheetStateFacts.enum_row(sheet) if found.is_empty() else found["enum"] as EnumRow
	if declared != null:
		for member: String in declared.members:
			var suffix: String = member.substr(member.find("=")) if member.contains("=") else ""
			written[EnumRow.bare_name(member)] = suffix
	var own_machine: bool = not found.is_empty() and str(found.get("variable_name", "")) != EventSheetStateFacts.STATE_VARIABLE
	if own_machine:
		# A machine of its own has only its enum and its variable: no setter, no helpers to keep true.
		(found["variable"] as LocalVariable).default_value = "%s.%s" % [found["enum_name"], opening]
	elif not write(sheet, names, opening):
		return false
	var enum_row: EnumRow = EventSheetStateFacts.enum_row(sheet) if not own_machine else found["enum"] as EnumRow
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
static func rename_everywhere(sheet: EventSheetResource, from: String, to: String, found: Dictionary = {}) -> int:
	if sheet == null or from == to or from.is_empty() or to.is_empty():
		return 0
	var changed: int = 0
	# A machine of its own is named by its own enum (`WeaponState.DRAWN`); only the primary machine has the
	# vocabulary rows (Is, Was, Go to, the two triggers) whose parameter carries the bare member.
	var own_machine: bool = not found.is_empty() and str(found.get("variable_name", "")) != EventSheetStateFacts.STATE_VARIABLE
	var prefix: String = (str(found["enum_name"]) + ".") if not found.is_empty() else EventSheetStateFacts.MEMBER_PREFIX
	var pattern: RegEx = RegEx.new()
	pattern.compile("\\b%s%s\\b" % [prefix.replace(".", "\\."), from])
	var replacement: String = prefix + to
	changed += _rename_in(EventSheetStateFacts.rows_of(sheet), from, to, pattern, replacement, not own_machine)
	# The variable may start in it.
	var variable_names: Array = [found["variable_name"]] if own_machine else [EventSheetStateFacts.STATE_VARIABLE, EventSheetStateFacts.PREVIOUS_VARIABLE]
	for variable_name: String in variable_names:
		var declared: LocalVariable = EventSheetStateFacts.variable_row(sheet, variable_name)
		if declared != null and str(declared.default_value).strip_edges() == prefix + from:
			declared.default_value = replacement
			changed += 1
	return changed


static func _rename_in(items: Array, from: String, to: String, pattern: RegEx, replacement: String,
		with_params: bool = true) -> int:
	var changed: int = 0
	for item: Variant in items:
		if item is EventGroup:
			changed += _rename_in(EventSheetGroupFacts.children(item as EventGroup), from, to, pattern, replacement, with_params)
			continue
		if item is RawCodeRow:
			var code: String = (item as RawCodeRow).code
			var rewritten: String = pattern.sub(code, replacement, true)
			if rewritten != code:
				(item as RawCodeRow).code = rewritten
				changed += 1
			continue
		if item is MatchRow:
			changed += _rename_in_match(item as MatchRow, from, to, pattern, replacement, with_params)
			continue
		var event_row: EventRow = item as EventRow
		if event_row == null:
			continue
		if with_params and str(event_row.trigger_params.get(EventSheetStateFacts.STATE_PARAM, "")).strip_edges() == from:
			event_row.trigger_params[EventSheetStateFacts.STATE_PARAM] = to
			changed += 1
		if with_params and event_row.trigger != null and str(event_row.trigger.params.get(EventSheetStateFacts.STATE_PARAM, "")).strip_edges() == from:
			event_row.trigger.params[EventSheetStateFacts.STATE_PARAM] = to
		for is_action: bool in [false, true]:
			for ace: Variant in (event_row.actions if is_action else event_row.conditions):
				if ace is MatchRow:
					changed += _rename_in_match(ace as MatchRow, from, to, pattern, replacement, with_params)
					continue
				if ace is RawCodeRow:
					var raw: String = (ace as RawCodeRow).code
					var raw_rewritten: String = pattern.sub(raw, replacement, true)
					if raw_rewritten != raw:
						(ace as RawCodeRow).code = raw_rewritten
						changed += 1
					continue
				if ace is Resource and not EventSheetStateFacts.STATE_ACE_IDS.has(str((ace as Resource).get("ace_id"))):
					# Any other row can name the state in a typed value (`weapon_state = WeaponState.FIRING`
					# in a Set variable action, a Compare condition), so its text params follow too.
					var other: Variant = (ace as Resource).get("params")
					if other is Dictionary:
						for key: Variant in (other as Dictionary).keys():
							if (other as Dictionary)[key] is String:
								var text_value: String = (other as Dictionary)[key]
								var text_rewritten: String = pattern.sub(text_value, replacement, true)
								if text_rewritten != text_value:
									(other as Dictionary)[key] = text_rewritten
									changed += 1
					continue
				if not with_params or not (ace is Resource):
					continue
				var params: Variant = (ace as Resource).get("params")
				if params is Dictionary and str((params as Dictionary).get(EventSheetStateFacts.STATE_PARAM, "")).strip_edges() == from:
					(params as Dictionary)[EventSheetStateFacts.STATE_PARAM] = to
					changed += 1
		changed += _rename_in(event_row.sub_events, from, to, pattern, replacement, with_params)
	return changed


static func _rename_in_match(row: MatchRow, from: String, to: String, pattern: RegEx, replacement: String,
		with_params: bool = true) -> int:
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
		changed += _rename_in(case_row.events, from, to, pattern, replacement, with_params)
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
