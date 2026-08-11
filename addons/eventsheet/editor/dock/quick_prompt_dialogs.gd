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
		hint.text = "These actions become one reusable verb: call it anywhere, and it appears in the picker. Type a meaningful name (e.g. \"Apply Physics\")."
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
var _group_desc_edit: TextEdit = null
var _group_edit_target: EventGroup = null


## Group editor popup: edit a group's name and (optional) description together. Replaces the old
## inline title edit - the description renders only as a muted second header line once it is
## non-empty, so an inline-only flow could never ADD one. Reached by double-click / slow-click /
## Enter on a group header, and right after Add Group.
func on_group_edit_requested(group: EventGroup) -> void:
	if group == null:
		return
	if _group_edit_dialog == null:
		_group_edit_dialog = ConfirmationDialog.new()
		_group_edit_dialog.title = "Edit Group"
		_group_edit_dialog.ok_button_text = "Apply"
		_group_edit_dialog.min_size = Vector2i(420, 0)
		var box: VBoxContainer = EventSheetPopupUI.form_box()
		_group_name_edit = LineEdit.new()
		_group_name_edit.placeholder_text = "Group name"
		# Enter in the name field applies + closes (the LineEdit consumes Enter, so the dialog's
		# own OK does not also fire); _apply_group_edit is one-shot-guarded regardless.
		_group_name_edit.text_submitted.connect(func(_submitted: String) -> void:
			_apply_group_edit()
			_group_edit_dialog.hide()
		)
		box.add_child(EventSheetPopupUI.form_row("Name", _group_name_edit))
		_group_desc_edit = TextEdit.new()
		_group_desc_edit.custom_minimum_size = Vector2(0.0, 90.0)
		_group_desc_edit.placeholder_text = "Shown as a muted second line on the group header."
		box.add_child(EventSheetPopupUI.form_row("Description", _group_desc_edit))
		_group_edit_dialog.add_child(EventSheetPopupUI.margined(box))
		_group_edit_dialog.confirmed.connect(_apply_group_edit)
		_dock.add_child(_group_edit_dialog)
	_group_edit_target = group
	_group_name_edit.text = group.group_name if not group.group_name.strip_edges().is_empty() else group.name
	_group_desc_edit.text = group.description
	_group_edit_dialog.popup_centered()
	_group_name_edit.grab_focus()
	_group_name_edit.select_all()


## One-shot apply: nulls the target first so a text-submit + dialog-OK pair can never double-apply.
func _apply_group_edit() -> void:
	if _group_edit_target == null:
		return
	var target: EventGroup = _group_edit_target
	_group_edit_target = null
	apply_group_edit(target, _group_name_edit.text, _group_desc_edit.text)


## Applies a group's name + description undoably. Wraps the pure static mutation so the popup's
## Apply and tests share one code path.
func apply_group_edit(group: EventGroup, new_name: String, new_desc: String) -> bool:
	if group == null:
		return false
	var changed: bool = _dock._perform_undoable_sheet_edit("Edit Group", func() -> bool:
		set_group_fields(group, new_name, new_desc)
		return true
	)
	if changed:
		_dock._mark_dirty("Updated group: %s" % group.group_name)
	return changed


## Pure mutation: trims + applies a group's name (mirrored to .name + .group_name) and its
## description; a blank name falls back to "Group". Static so it is unit-testable without the
## dialog or a display server. Returns the resolved name.
static func set_group_fields(group: EventGroup, new_name: String, new_desc: String) -> String:
	var resolved_name: String = new_name.strip_edges()
	if resolved_name.is_empty():
		resolved_name = "Group"
	group.name = resolved_name
	group.group_name = resolved_name
	group.description = new_desc.strip_edges()
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
