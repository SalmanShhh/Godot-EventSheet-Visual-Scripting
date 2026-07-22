# EventForge - the focused "Edit Parameter" dialog.
#
# Clicking a parameter cell on a published verb used to open the WHOLE verb dialog (name, doc comment,
# Inspector button, verb kind cards, publish section, live picker preview) with the cursor parked in
# one field. That is the right dialog for "redesign this verb" and the wrong one for "this input should
# be called speed, not s" - a reader who clicked one cell should not have to find their way back out of
# a form that can restructure the whole verb.
#
# So this dialog holds exactly what a parameter IS: its name, its type, an optional default, and the
# line describing it. Same four fields the verb dialog's parameter row carries, and it writes through
# the same undo funnel, so the two stay interchangeable. "Edit the whole verb…" is one button away for
# anyone who actually wanted the big one.
@tool
class_name EventSheetParamDialog
extends RefCounted

## Emitted on OK with {function: String, index: int, id, type_name, default, description, removed: bool}.
## index < 0 means "append a new parameter".
signal param_confirmed(data: Dictionary)
## Emitted when the user asks for the full verb dialog instead, carrying the verb's name.
signal full_editor_requested(function_name: String)

var _dialog: ConfirmationDialog = null
var _name_edit: LineEdit = null
var _type_option: OptionButton = null
var _default_edit: LineEdit = null
var _description_edit: LineEdit = null
var _remove_check: CheckBox = null
var _title_label: Label = null
## The verb being edited and which of its parameters (-1 while adding a fresh one).
var _function_name: String = ""
var _param_index: int = -1


func init_dialog(parent_node: Node) -> void:
	_dialog = ConfirmationDialog.new()
	_dialog.title = "Edit Parameter"
	_dialog.ok_button_text = "Apply"
	_dialog.confirmed.connect(_on_confirmed)
	parent_node.add_child(_dialog)
	var form: VBoxContainer = EventSheetPopupUI.form_box()
	form.custom_minimum_size = Vector2(420.0, 0.0)
	_dialog.add_child(EventSheetPopupUI.margined(form))

	_title_label = EventSheetPopupUI.hint_label("", 400.0)
	form.add_child(_title_label)

	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "e.g. amount"
	_dialog.register_text_enter(_name_edit)
	form.add_child(EventSheetPopupUI.form_row("Name", _name_edit, EventSheetPopupUI.LABEL_MIN_WIDTH,
		"What this input is called. It becomes the parameter's name in the generated GDScript, and the label on the verb's row, so plain words beat abbreviations."))

	_type_option = OptionButton.new()
	for type_name: String in EventSheetFunctionDialog.PARAM_TYPES:
		_type_option.add_item(type_name)
	form.add_child(EventSheetPopupUI.form_row("Type", _type_option, EventSheetPopupUI.LABEL_MIN_WIDTH,
		"What kind of value this input accepts - a number (int / float), text (String), a true/false (bool), a position (Vector2 / Vector3), or Variant for anything at all."))

	_default_edit = LineEdit.new()
	_default_edit.placeholder_text = "leave empty to make it required"
	form.add_child(EventSheetPopupUI.form_row("Default", _default_edit, EventSheetPopupUI.LABEL_MIN_WIDTH,
		"An optional starting value, so whoever uses the verb can skip this input. Written as GDScript (10, 1.5, \"idle\", true). GDScript requires inputs WITH a default to come last, so filling this in may move the parameter down."))

	_description_edit = LineEdit.new()
	_description_edit.placeholder_text = "what this input is for"
	form.add_child(EventSheetPopupUI.form_row("Description", _description_edit, EventSheetPopupUI.LABEL_MIN_WIDTH,
		"One line explaining this input. It shows in the picker beside the field, which is where somebody decides what to type into it."))

	_remove_check = CheckBox.new()
	_remove_check.text = "Delete this parameter"
	_remove_check.tooltip_text = "Removes the input from the verb entirely. Anything already calling the verb loses the value it was passing here."
	form.add_child(_remove_check)

	# The way back to the full verb dialog, for the person who clicked a parameter but meant to change
	# the verb itself. Without it, narrowing this dialog would have REMOVED a route rather than focused one.
	var full_editor_button: Button = Button.new()
	full_editor_button.text = "Edit the whole verb…"
	full_editor_button.flat = true
	full_editor_button.pressed.connect(func() -> void:
		_dialog.hide()
		full_editor_requested.emit(_function_name))
	form.add_child(full_editor_button)


## Opens on one existing parameter of `event_function` (index into its params).
func open_for_param(event_function: EventFunction, param_index: int) -> void:
	if event_function == null or param_index < 0 or param_index >= event_function.params.size():
		return
	var param: ACEParam = event_function.params[param_index]
	_function_name = event_function.function_name
	_param_index = param_index
	_dialog.title = "Edit Parameter"
	_title_label.text = "An input of %s." % _verb_label(event_function)
	_name_edit.text = param.id
	var type_index: int = Array(EventSheetFunctionDialog.PARAM_TYPES).find(param.type_name)
	_type_option.select(maxi(type_index, 0))
	_default_edit.text = param.gdscript_default
	_description_edit.text = param.description
	_remove_check.button_pressed = false
	_remove_check.visible = true
	_popup()


## Opens blank, to append a fresh parameter to `event_function`.
func open_for_new_param(event_function: EventFunction) -> void:
	if event_function == null:
		return
	_function_name = event_function.function_name
	_param_index = -1
	_dialog.title = "Add Parameter"
	_title_label.text = "A new input for %s." % _verb_label(event_function)
	_name_edit.text = ""
	# Variant is the honest default for a parameter nobody has typed yet - it accepts anything, so the
	# verb compiles and runs while the author is still deciding.
	_type_option.select(maxi(Array(EventSheetFunctionDialog.PARAM_TYPES).find("Variant"), 0))
	_default_edit.text = ""
	_description_edit.text = ""
	_remove_check.button_pressed = false
	# Nothing to delete yet - the checkbox would be a trap that discards what was just typed.
	_remove_check.visible = false
	_popup()


func _popup() -> void:
	_dialog.popup_centered(Vector2i(460, 0))
	_name_edit.call_deferred("grab_focus")
	_name_edit.call_deferred("select_all")


## The verb's friendly name where it has one, so the dialog names what the reader clicked on rather
## than the underlying function identifier.
func _verb_label(event_function: EventFunction) -> String:
	var display_name: String = event_function.ace_display_name.strip_edges()
	return display_name if not display_name.is_empty() else event_function.function_name


func _on_confirmed() -> void:
	param_confirmed.emit({
		"function": _function_name,
		"index": _param_index,
		"id": _name_edit.text.strip_edges(),
		"type_name": EventSheetFunctionDialog.PARAM_TYPES[maxi(_type_option.selected, 0)],
		"default": _default_edit.text.strip_edges(),
		"description": _description_edit.text.strip_edges(),
		"removed": _remove_check.visible and _remove_check.button_pressed,
	})
