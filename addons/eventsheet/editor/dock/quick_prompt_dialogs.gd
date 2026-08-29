@tool
class_name EventSheetQuickPromptDialogs
extends RefCounted

# The dock's three one-field prompt popups: Extract-to-Function name, Conditional Breakpoint
# expression, and the Group editor (name + description).
#
# Each is a small lazily-built ConfirmationDialog/AcceptDialog whose whole job is "type one thing,
# apply undoably". Extracted from event_sheet_dock.gd so the dock stays focused; the dock keeps
# thin delegates (_prompt_extract_function_name / _set_breakpoint_condition_requested /
# _on_group_edit_requested / apply_group_edit / set_group_fields) so viewport signal connections,
# context menus, and tests keep calling the dock unchanged. This class reaches back through the
# dock reference for the active sheet, the undoable-edit wrapper, and dirty/status feedback.

var _dock: Control = null


func init(dock: Control) -> void:
	_dock = dock

# ── Extract-to-Function name prompt (one field: name the new concept) ──
var _extract_function_name_dialog: ConfirmationDialog = null
var _extract_function_name_edit: LineEdit = null
var _extract_function_callback: Callable = Callable()


## Prompts for the function name, then invokes callback(name). Pre-filled with a unique default (so Enter
## just works) but selected - the user is nudged to type a real, meaningful name, because naming the
## concept ("Apply Physics") is the whole point of extracting.
var _timeline_step_dialog: ConfirmationDialog = null
var _timeline_step_at_edit: LineEdit = null
var _timeline_step_code_edit: LineEdit = null
var _timeline_step_target: TimelineRow = null


func prompt_extract_function_name(callback: Callable) -> void:
	if _extract_function_name_dialog == null:
		_extract_function_name_dialog = ConfirmationDialog.new()
		_extract_function_name_dialog.title = "Extract to Function"
		_extract_function_name_dialog.ok_button_text = "Extract"
		_extract_function_name_dialog.min_size = Vector2i(380, 0)
		var box: VBoxContainer = EventSheetPopupUI.form_box()
		_extract_function_name_edit = LineEdit.new()
		_extract_function_name_edit.placeholder_text = "apply_physics"
		_extract_function_name_edit.text_submitted.connect(func(_t: String) -> void:
			_apply_extract_function()
			_extract_function_name_dialog.hide()
		)
		box.add_child(EventSheetPopupUI.form_row("Name this action", _extract_function_name_edit))
		var hint: Label = Label.new()
		hint.text = "These actions become one reusable function: call it anywhere, and it appears in the picker. Type a meaningful name (e.g. \"Apply Physics\")."
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.custom_minimum_size = Vector2(340.0, 0.0)
		hint.add_theme_color_override("font_color", EventSheetPalette.TEXT_MUTED)
		box.add_child(hint)
		_extract_function_name_dialog.add_child(EventSheetPopupUI.margined(box))
		_extract_function_name_dialog.confirmed.connect(_apply_extract_function)
		_dock.add_child(_extract_function_name_dialog)
	_extract_function_callback = callback
	_extract_function_name_edit.text = _dock._unique_extracted_function_name(_dock._current_sheet, "do_something") if _dock._current_sheet != null else "do_something"
	_extract_function_name_dialog.popup_centered()
	_extract_function_name_edit.grab_focus()
	_extract_function_name_edit.select_all()


## One-shot apply: nulls the callback first so the confirmed + text_submitted signals can't double-fire.
func _apply_extract_function() -> void:
	if not _extract_function_callback.is_valid():
		return
	var entered: String = _extract_function_name_edit.text.strip_edges()
	var callback: Callable = _extract_function_callback
	_extract_function_callback = Callable()
	if entered.is_empty():
		return
	callback.call(entered)

# ── Add Inspector button prompt (one field: what the button says) ──
var _inspector_button_dialog: ConfirmationDialog = null
var _inspector_button_edit: LineEdit = null


## The smallest editor tool there is: a button in the Inspector that runs one function. Prompts
## for what the button should SAY, then hands the label to the caller, which writes the
## `@export_tool_button` line and the empty function it calls in one undo step.
func prompt_inspector_button(callback: Callable) -> void:
	if _inspector_button_dialog == null:
		_inspector_button_dialog = ConfirmationDialog.new()
		_inspector_button_dialog.title = "Add Inspector Button"
		_inspector_button_dialog.ok_button_text = "Add"
		_inspector_button_dialog.min_size = Vector2i(400, 0)
		var box: VBoxContainer = EventSheetPopupUI.form_box()
		box.add_child(EventSheetPopupUI.hint_label("A button in the Inspector that runs one function while you are editing the scene. You get the button and an empty function to fill in; the sheet has to be a Tool sheet for it to run."))
		_inspector_button_edit = LineEdit.new()
		_inspector_button_edit.placeholder_text = "Bake"
		_inspector_button_edit.text_submitted.connect(func(_text: String) -> void:
			_apply_inspector_button()
			_inspector_button_dialog.hide()
		)
		box.add_child(EventSheetPopupUI.form_row("Button says", _inspector_button_edit))
		_inspector_button_dialog.add_child(EventSheetPopupUI.margined(box))
		_inspector_button_dialog.confirmed.connect(_apply_inspector_button)
		_dock.add_child(_inspector_button_dialog)
	_inspector_button_callback = callback
	_inspector_button_edit.text = "Bake"
	_inspector_button_dialog.popup_centered()
	_inspector_button_edit.grab_focus()
	_inspector_button_edit.select_all()


var _inspector_button_callback: Callable = Callable()


## One-shot apply, for the same reason the extract prompt is one-shot: `confirmed` and
## `text_submitted` both fire when the user presses Enter.
func _apply_inspector_button() -> void:
	if not _inspector_button_callback.is_valid():
		return
	var entered: String = _inspector_button_edit.text.strip_edges()
	var callback: Callable = _inspector_button_callback
	_inspector_button_callback = Callable()
	if entered.is_empty():
		return
	callback.call(entered)

# ── Conditional Breakpoint prompt (one field: a boolean guard expression) ──
var _breakpoint_condition_dialog: AcceptDialog = null
var _breakpoint_condition_edit: LineEdit = null
var _breakpoint_condition_target: EventRow = null


## Visual debugging: a conditional breakpoint. Prompts for a GDScript boolean expression; the
## breakpoint then fires only when it is true (compiled as `if <cond>: breakpoint`). Sets and
## enables the row breakpoint; a blank expression clears the guard (break every pass).
func set_breakpoint_condition_requested() -> void:
	if _dock._context_row == null or not (_dock._context_row.source_resource is EventRow):
		_dock._set_status("Right-click an event to set a breakpoint condition.", true)
		return
	var event: EventRow = _dock._context_row.source_resource as EventRow
	if _breakpoint_condition_dialog == null:
		_breakpoint_condition_dialog = AcceptDialog.new()
		_breakpoint_condition_dialog.title = "Conditional Breakpoint"
		_breakpoint_condition_dialog.ok_button_text = "Set"
		_breakpoint_condition_dialog.min_size = Vector2i(440, 0)
		var box: VBoxContainer = EventSheetPopupUI.form_box()
		box.add_child(EventSheetPopupUI.hint_label("Break only when this GDScript expression is true. Leave blank to break every pass - either way, this enables the event's breakpoint."))
		_breakpoint_condition_edit = LineEdit.new()
		_breakpoint_condition_edit.placeholder_text = "e.g. health <= 0"
		box.add_child(EventSheetPopupUI.form_row("Condition", _breakpoint_condition_edit))
		_breakpoint_condition_dialog.add_child(EventSheetPopupUI.margined(box))
		_breakpoint_condition_dialog.confirmed.connect(_apply_breakpoint_condition)
		_dock.add_child(_breakpoint_condition_dialog)
	_breakpoint_condition_target = event
	_breakpoint_condition_edit.text = event.debug_break_condition
	_breakpoint_condition_dialog.popup_centered()
	_breakpoint_condition_edit.grab_focus()


func _apply_breakpoint_condition() -> void:
	if _breakpoint_condition_target == null:
		return
	var event: EventRow = _breakpoint_condition_target
	var condition: String = _breakpoint_condition_edit.text.strip_edges()
	var changed: bool = _dock._perform_undoable_sheet_edit("Set Breakpoint Condition", func() -> bool:
		event.debug_break = true
		event.debug_break_condition = condition
		return true
	)
	if changed:
		var note: String = ("Breakpoint will pause when: %s" % condition) if not condition.is_empty() else "Breakpoint will pause every pass."
		if _dock._current_sheet != null and not _dock._current_sheet.emit_breakpoints:
			note += "  (enable Tools ▸ Debug Breakpoints to emit.)"
		_dock._mark_dirty(note)

# ── Group editor popup (name + optional description) ──
var _group_edit_dialog: ConfirmationDialog = null
var _group_name_edit: LineEdit = null
var _group_desc_edit: LineEdit = null
var _group_enabled_check: CheckBox = null
var _group_runtime_check: CheckBox = null
var _group_runs_on: OptionButton = null
var _group_runs_in: OptionButton = null
## The modes this project declares, read ONCE when the dialog opens rather than on every keystroke:
## the list comes from the autoload scripts, and a keystroke may not go to disk.
var _group_runs_in_choices: Array[Dictionary] = []
var _group_color_button: ColorPickerButton = null
var _group_help_strip: EventSheetPopupUI.HelpStrip = null
var _group_edit_target: EventGroup = null
## The colour the swatch opened on. Apply writes a colour only when the swatch moved off it, so a
## group that deliberately carries none does not come back tinted just for having been edited.
var _group_color_seed: Color = Color(0, 0, 0, 0)

## The facts a group HAS, in the order the dialog asks for them. One table, so the dialog, its help
## strip and the tests all read the same list.
const GROUP_FIELD_ORDER: PackedStringArray = ["Name", "Description", "Runs on", "Active on start", "Can be switched at runtime", "Colour", "Runs in"]

## What the description field shows when nothing is offered in its place - an example, not a default.
const GROUP_DESCRIPTION_PLACEHOLDER := "Damage, hits and death."


## The ONE group dialog: name, description, active on start, switchable at runtime, colour.
## Everything a group IS, in one place, instead of a name field plus three separate menu items.
## Reached by double-click / slow-click / Enter on a group head, from Edit group..., and right
## after Add Group.
func on_group_edit_requested(group: EventGroup) -> void:
	if group == null:
		return
	if _group_edit_dialog == null:
		_build_group_edit_dialog()
	_group_edit_target = group
	_group_name_edit.text = group.group_name if not group.group_name.strip_edges().is_empty() else group.name
	_group_desc_edit.text = group.description
	_offer_group_draft(group)
	_group_enabled_check.button_pressed = group.enabled
	_group_runtime_check.button_pressed = group.runtime_toggleable
	_group_runs_on.select(EventSheetGroupFacts.runs_on_index(group.runs_on))
	# The mode list is rebuilt on every open: a mode declared a minute ago has to be pickable now.
	_group_runs_in_choices = EventSheetGroupFacts.runs_in_choices(_dock._current_sheet)
	_group_runs_in.clear()
	for choice: Dictionary in _group_runs_in_choices:
		_group_runs_in.add_item(str(choice.get("label", "")))
	_group_runs_in.select(EventSheetGroupFacts.runs_in_index(_dock._current_sheet, group.runs_in))
	_group_color_seed = group.custom_color if group.custom_color.a > 0.0 else _dock.DEFAULT_STRUCTURE_COLOR
	_group_color_button.color = _group_color_seed
	_refresh_group_reading()
	_group_edit_dialog.popup_centered()
	_group_name_edit.grab_focus()
	_group_name_edit.select_all()


## Shows what this group's rows would say about it, as the description field's own placeholder - an
## offer that cannot overwrite anything, because a placeholder is not text. Only for a group with no
## description, only when its rows compose something, and only once per group per session: the shared
## offer budget decides, so a person who ignored the suggestion is not shown it again on every open.
func _offer_group_draft(group: EventGroup) -> void:
	_group_desc_edit.placeholder_text = GROUP_DESCRIPTION_PLACEHOLDER
	var draft: String = EventSheetDescriptionDrafts.for_group(group)
	var described: bool = not EventSheetDescriptions.for_group(group).is_empty()
	if EventSheetDescriptionDrafts.may_offer("group", EventSheetDescriptions.group_name_of(group), described, draft):
		_group_desc_edit.placeholder_text = draft


func _build_group_edit_dialog() -> void:
	_group_edit_dialog = ConfirmationDialog.new()
	_group_edit_dialog.title = "Edit group"
	_group_edit_dialog.ok_button_text = "Apply"
	_group_edit_dialog.min_size = Vector2i(460, 0)
	var box: VBoxContainer = EventSheetPopupUI.form_box()
	_group_help_strip = EventSheetPopupUI.help_strip(
		GROUP_FIELD_ORDER[0], _group_field_help(GROUP_FIELD_ORDER[0]))
	_group_name_edit = LineEdit.new()
	_group_name_edit.placeholder_text = "Combat"
	# Enter in the name field applies + closes (the LineEdit consumes Enter, so the dialog's
	# own OK does not also fire); _apply_group_edit is one-shot-guarded regardless.
	_group_name_edit.text_submitted.connect(func(_submitted: String) -> void:
		_apply_group_edit()
		_group_edit_dialog.hide()
	)
	_group_name_edit.text_changed.connect(func(_text: String) -> void: _refresh_group_reading())
	box.add_child(EventSheetPopupUI.form_row("Name", _group_name_edit))
	_group_desc_edit = LineEdit.new()
	_group_desc_edit.placeholder_text = GROUP_DESCRIPTION_PLACEHOLDER
	_group_desc_edit.text_changed.connect(func(_text: String) -> void: _refresh_group_reading())
	box.add_child(EventSheetPopupUI.form_row("Description", _group_desc_edit))
	# Who runs this group's events over a network. A dropdown, described choice by choice, and
	# the answer is stored on the group rather than repeated as a condition on every event inside it.
	_group_runs_on = OptionButton.new()
	for choice: Dictionary in EventSheetGroupFacts.runs_on_choices():
		_group_runs_on.add_item(str(choice.get("label", "")))
	_group_runs_on.item_selected.connect(func(_index: int) -> void: _refresh_group_reading())
	box.add_child(EventSheetPopupUI.form_row(GROUP_FIELD_ORDER[2], _group_runs_on))
	# And which MODE of the game these events run in - the same shape, and the same reason: asked
	# once of the group rather than repeated as an In mode condition on every event inside it. The
	# list is empty for a project that declares no modes, so it reads as one choice: every mode.
	_group_runs_in = OptionButton.new()
	_group_runs_in.item_selected.connect(func(_index: int) -> void: _refresh_group_reading())
	box.add_child(EventSheetPopupUI.form_row(GROUP_FIELD_ORDER[6], _group_runs_in))
	_group_enabled_check = CheckBox.new()
	_group_enabled_check.text = GROUP_FIELD_ORDER[3]
	_group_enabled_check.toggled.connect(func(_on: bool) -> void: _refresh_group_reading())
	box.add_child(EventSheetPopupUI.form_row("", _group_enabled_check))
	_group_runtime_check = CheckBox.new()
	_group_runtime_check.text = GROUP_FIELD_ORDER[4]
	_group_runtime_check.toggled.connect(func(_on: bool) -> void: _refresh_group_reading())
	box.add_child(EventSheetPopupUI.form_row("", _group_runtime_check))
	_group_color_button = ColorPickerButton.new()
	_group_color_button.custom_minimum_size = Vector2(120.0, 0.0)
	box.add_child(EventSheetPopupUI.form_row(GROUP_FIELD_ORDER[5], _group_color_button))
	for followed: Array in [
		[_group_name_edit, GROUP_FIELD_ORDER[0]],
		[_group_desc_edit, GROUP_FIELD_ORDER[1]],
		[_group_enabled_check, GROUP_FIELD_ORDER[3]],
		[_group_runtime_check, GROUP_FIELD_ORDER[4]],
		[_group_color_button, GROUP_FIELD_ORDER[5]],
		[_group_runs_in, GROUP_FIELD_ORDER[6]],
	]:
		_group_help_strip.follow(followed[0] as Control, str(followed[1]), _group_field_help(str(followed[1])))
	# The one dropdown here describes its CHOICE, not the field: what "the host" costs a client is a
	# different paragraph from what "everyone" costs the host, and the strip follows whichever is
	# highlighted - the same way the Add variable dialog's Scope list reads.
	_group_help_strip.follow_option(_group_runs_on, func(index: int) -> Dictionary:
		var choices: Array[Dictionary] = EventSheetGroupFacts.runs_on_choices()
		if index < 0 or index >= choices.size():
			return {}
		var choice: Dictionary = choices[index]
		return {
			"heading": "%s - %s" % [GROUP_FIELD_ORDER[2], str(choice.get("label", ""))],
			"body": str(choice.get("description", ""))
		}
	)
	box.add_child(_group_help_strip)
	_group_edit_dialog.add_child(EventSheetPopupUI.margined(box))
	_group_edit_dialog.confirmed.connect(_apply_group_edit)
	_dock.add_child(_group_edit_dialog)


## What each field of the group dialog is, in one line. A table rather than five literals at the
## call site, so the strip and any future caller say the same thing.
static func _group_field_help(field: String) -> String:
	match field:
		"Name":
			return "What the group head reads. It is also the name a Set group active row writes."
		"Description":
			return "One line beside the name, on the head itself - and still there when the group is folded."
		"Active on start":
			return "Off compiles the whole group out: nothing inside it runs, and nothing inside it is emitted."
		"Can be switched at runtime":
			return "Adds the flag Set group active flips, so this group can be turned on and off while the game runs."
		"Colour":
			return "Paints the bracket down the group's body, so a big sheet reads by colour."
		"Runs in":
			return "Which mode of the game these events run in. Said once here instead of as an In mode condition on every event inside, which is how one of them gets forgotten."
	return ""


## Writes the answer a reader picked from the head's Runs on submenu. One undo step, through the
## same path the dialog's Apply takes, so the two gestures can never write the fact two ways.
func on_group_runs_on_chosen(menu_id: int) -> void:
	var group: EventGroup = _dock._context_group()
	if group == null or not _dock.GROUP_RUNS_ON_VALUES.has(menu_id):
		_dock._set_status("Right-click a group head to say who runs it.", true)
		return
	apply_group_edit(group, group.display_name(), group.description,
		{"runs_on": str(_dock.GROUP_RUNS_ON_VALUES[menu_id])})


## Once a group says who runs it, the same test written on one of its own events is the group's
## word said twice - and it would compile twice, `multiplayer.is_server() and multiplayer.is_server()`.
## This takes it off every row the group now guards; a nested group that answers for itself keeps its
## own rows. That is what makes "Runs on: the host" the way to fold up a project that repeated an
## Is host condition on every event. Static + pure, so the fold is testable without the dialog.
##
## An OR row is left exactly as it is. Only an AND row says the guard twice: dropping one term of
## `is host or is on floor` leaves `is on floor`, which the group then wraps in the host guard - the
## opposite gate, written in one undo step by a dropdown that never mentioned the row.
static func fold_runs_on_conditions(group: EventGroup, guard: String) -> void:
	if group == null or guard.is_empty():
		return
	for row: Variant in group.child_rows():
		if row is EventGroup:
			if (row as EventGroup).runs_on.strip_edges().is_empty():
				fold_runs_on_conditions(row as EventGroup, guard)
			continue
		if not (row is EventRow) or (row as EventRow).condition_mode != EventRow.ConditionMode.AND:
			continue
		var kept: Array[ACECondition] = []
		for condition: ACECondition in (row as EventRow).conditions:
			if condition == null or ConditionCodegen.generate_condition(condition) != guard:
				kept.append(condition)
		(row as EventRow).conditions = kept


## The line a runs_on answer writes around the group's events, or "" for everyone - which writes
## nothing at all, and is why a single-player sheet compiles to exactly what it always did.
static func _runs_on_code_line(value: String) -> String:
	var guard: String = EventGroup.runs_on_guard(value)
	return "" if guard.is_empty() else "if %s:" % guard


## The strip's READS AS line: the head this dialog is about to write, and - for a switchable group -
## the row that can now reach it.
func _refresh_group_reading() -> void:
	if _group_help_strip == null:
		return
	var name_text: String = _group_name_edit.text.strip_edges()
	if name_text.is_empty():
		name_text = "Group"
	var reads: String = name_text
	var description: String = _group_desc_edit.text.strip_edges()
	if not description.is_empty():
		reads += "  %s" % description
	if not _group_enabled_check.button_pressed:
		reads += "  (off)"
	var runs_on: String = str((EventSheetGroupFacts.runs_on_choices()[_group_runs_on.selected] as Dictionary).get("value", ""))
	if not runs_on.is_empty():
		reads += "  %s" % runs_on
	var runs_in: String = _chosen_mode()
	if not runs_in.is_empty():
		reads += "  %s" % runs_in
	# The IN CODE line says every line this dialog is about to write: the flag a switchable group
	# declares, and the guard a runs_on group wraps its events in. Either alone is the whole answer.
	var code_lines: PackedStringArray = PackedStringArray()
	if _group_runtime_check.button_pressed:
		code_lines.append("var __group_%s_active: bool = %s" % [
			SheetCompiler.guard_token(name_text),
			"true" if _group_enabled_check.button_pressed else "false"
		])
	var guard_line: String = _runs_on_code_line(runs_on)
	if not guard_line.is_empty():
		code_lines.append(guard_line)
	var mode_guard: String = EventGroup.runs_in_guard(runs_in)
	if not mode_guard.is_empty():
		code_lines.append("if %s: …" % mode_guard)
	_group_help_strip.set_reading(reads, "  ".join(code_lines))


## One-shot apply: nulls the target first so a text-submit + dialog-OK pair can never double-apply.
func _apply_group_edit() -> void:
	if _group_edit_target == null:
		return
	var target: EventGroup = _group_edit_target
	_group_edit_target = null
	var extras: Dictionary = group_edit_extras(
		_group_enabled_check.button_pressed, _group_runtime_check.button_pressed,
		_group_color_button.color, _group_color_seed)
	extras["runs_on"] = str((EventSheetGroupFacts.runs_on_choices()[_group_runs_on.selected] as Dictionary).get("value", ""))
	extras["runs_in"] = _chosen_mode()
	apply_group_edit(target, _group_name_edit.text, _group_desc_edit.text, extras)


## The mode the dropdown is on, out of the list read when the dialog opened. "" for every mode,
## which is both the first entry and the answer a project with no modes can only give.
func _chosen_mode() -> String:
	if _group_runs_in == null or _group_runs_in.selected < 0 \
			or _group_runs_in.selected >= _group_runs_in_choices.size():
		return ""
	return str(_group_runs_in_choices[_group_runs_in.selected].get("value", ""))


## What Apply asks `set_group_fields` to change beyond the name and the description. The colour
## rides along only when the swatch moved off the colour it opened on: the picker has to open on
## SOME colour, and a group that deliberately carries none must not come back tinted just because its
## description was edited. "Group Colour…" on the row menu is still how a group is given one.
## Static so the rule is testable without a display server.
static func group_edit_extras(enabled: bool, runtime_toggleable: bool, chosen: Color, seeded: Color) -> Dictionary:
	var extras: Dictionary = {"enabled": enabled, "runtime_toggleable": runtime_toggleable}
	if chosen != seeded:
		extras["custom_color"] = chosen
	return extras


## Applies a group's fields undoably. Wraps the pure static mutation so the popup's Apply and tests
## share one code path. `extras` carries whatever the caller wants changed beyond name/description;
## anything it leaves out stays exactly as the group has it.
func apply_group_edit(group: EventGroup, new_name: String, new_desc: String, extras: Dictionary = {}) -> bool:
	if group == null:
		return false
	var changed: bool = _dock._perform_undoable_sheet_edit("Edit Group", func() -> bool:
		set_group_fields(group, new_name, new_desc, extras)
		return true
	)
	if changed:
		_dock._mark_dirty("Updated group: %s" % group.group_name)
	return changed


## Pure mutation: trims + applies a group's name (mirrored to .name + .group_name) and its
## description; a blank name falls back to "Group". `extras` may carry "enabled",
## "runtime_toggleable" and "custom_color"; a key it omits leaves that fact alone. Static so it is
## unit-testable without the dialog or a display server. Returns the resolved name.
static func set_group_fields(group: EventGroup, new_name: String, new_desc: String, extras: Dictionary = {}) -> String:
	var resolved_name: String = new_name.strip_edges()
	if resolved_name.is_empty():
		resolved_name = "Group"
	group.name = resolved_name
	group.group_name = resolved_name
	group.description = new_desc.strip_edges()
	if extras.has("enabled"):
		group.enabled = bool(extras["enabled"])
	if extras.has("runtime_toggleable"):
		group.runtime_toggleable = bool(extras["runtime_toggleable"])
	if extras.has("runs_on"):
		group.runs_on = str(extras["runs_on"]).strip_edges()
		fold_runs_on_conditions(group, EventGroup.runs_on_guard(group.runs_on))
	if extras.has("runs_in"):
		group.runs_in = str(extras["runs_in"]).strip_edges()
		# And the same tidying the answer above does: an In mode condition on every event inside a
		# group that now says the same thing is the repetition the group was asked to end.
		fold_runs_on_conditions(group, EventGroup.runs_in_guard(group.runs_in))
	if extras.has("custom_color"):
		group.custom_color = extras["custom_color"]
	return resolved_name


# ── Collection-declaration entry prompt (Add Entry… / Edit Entry… on a Declare row) ──
var _entry_dialog: ConfirmationDialog = null
var _entry_key_edit: LineEdit = null
var _entry_key_row: Control = null
var _entry_value_edit: LineEdit = null
var _entry_target: CollectionDeclRow = null
var _entry_index: int = -1


## Add (entry_index -1) or edit one entry of a Declare row. The key field shows only for a
## dictionary, and string keys must include their own quotes - the field holds the SOURCE text
## of the key, so `"calm"` and a bare enum constant are both legal and neither is guessed at.
## "Add Step..." on a Timeline: WHEN (seconds) and WHAT (one GDScript line - a call or a Set,
## which the beat row then reads back in plain words). Same card grammar as the entry dialog.
func prompt_timeline_step(timeline: TimelineRow) -> void:
	if timeline == null:
		return
	if _timeline_step_dialog == null:
		_timeline_step_dialog = ConfirmationDialog.new()
		_timeline_step_dialog.title = "Add Timeline Step"
		_timeline_step_dialog.ok_button_text = "Add"
		_timeline_step_dialog.min_size = Vector2i(380, 0)
		var box: VBoxContainer = EventSheetPopupUI.form_box()
		_timeline_step_at_edit = LineEdit.new()
		_timeline_step_at_edit.placeholder_text = "0.5"
		box.add_child(EventSheetPopupUI.form_row("At (seconds)", _timeline_step_at_edit))
		_timeline_step_code_edit = LineEdit.new()
		_timeline_step_code_edit.placeholder_text = "show_message(\"GO!\")"
		box.add_child(EventSheetPopupUI.form_row("Do", _timeline_step_code_edit))
		_timeline_step_dialog.add_child(EventSheetPopupUI.margined(box))
		_timeline_step_dialog.confirmed.connect(func() -> void:
			_dock._apply_timeline_step(_timeline_step_target, float(_timeline_step_at_edit.text) if _timeline_step_at_edit.text.strip_edges().is_valid_float() else 0.0, _timeline_step_code_edit.text)
		)
		_dock.add_child(_timeline_step_dialog)
	_timeline_step_target = timeline
	_timeline_step_at_edit.text = ""
	_timeline_step_code_edit.text = ""
	_timeline_step_dialog.popup_centered()
	_timeline_step_at_edit.grab_focus()


func prompt_collection_entry(decl: CollectionDeclRow, entry_index: int) -> void:
	if decl == null:
		return
	if _entry_dialog == null:
		_entry_dialog = ConfirmationDialog.new()
		_entry_dialog.ok_button_text = "Apply"
		_entry_dialog.min_size = Vector2i(420, 0)
		var box: VBoxContainer = EventSheetPopupUI.form_box()
		_entry_key_edit = LineEdit.new()
		_entry_key_edit.placeholder_text = "\"key\" (quotes included) or a constant"
		_entry_key_row = EventSheetPopupUI.form_row("Key", _entry_key_edit)
		box.add_child(_entry_key_row)
		_entry_value_edit = LineEdit.new()
		_entry_value_edit.placeholder_text = "Value expression, e.g. 3 or Vector2(1, 2)"
		_entry_value_edit.text_submitted.connect(func(_submitted: String) -> void:
			_apply_collection_entry()
			_entry_dialog.hide()
		)
		box.add_child(EventSheetPopupUI.form_row("Value", _entry_value_edit))
		_entry_dialog.add_child(EventSheetPopupUI.margined(box))
		_entry_dialog.confirmed.connect(_apply_collection_entry)
		_dock.add_child(_entry_dialog)
	_entry_target = decl
	_entry_index = entry_index
	_entry_dialog.title = "Edit Entry" if entry_index >= 0 else "Add Entry"
	_entry_key_row.visible = decl.is_dictionary()
	_entry_key_edit.text = decl.entry_keys[entry_index] if entry_index >= 0 and entry_index < decl.entry_keys.size() else ""
	_entry_value_edit.text = decl.entry_values[entry_index] if entry_index >= 0 and entry_index < decl.entry_values.size() else ""
	_entry_dialog.popup_centered()
	if decl.is_dictionary() and entry_index < 0:
		_entry_key_edit.grab_focus()
	else:
		_entry_value_edit.grab_focus()
		_entry_value_edit.select_all()


## One-shot apply: nulls the target first so a text-submit + dialog-OK pair can never double-apply.
func _apply_collection_entry() -> void:
	if _entry_target == null:
		return
	var target: CollectionDeclRow = _entry_target
	_entry_target = null
	var target_index: int = _entry_index
	_entry_index = -1
	var applied: bool = _dock._perform_undoable_sheet_edit("Edit Entry", func() -> bool:
		return set_collection_entry(target, target_index, _entry_key_edit.text, _entry_value_edit.text)
	)
	if applied:
		_dock._mark_dirty("Updated entry." if target_index >= 0 else "Added entry.")


## Thin delegate: the mutation itself lives on CollectionDeclRow.set_entry, the single path the
## entry dialog, the inline value edit, and the public API all share.
static func set_collection_entry(decl: CollectionDeclRow, entry_index: int, key_text: String, value_text: String) -> bool:
	if decl == null:
		return false
	return decl.set_entry(entry_index, key_text, value_text)
