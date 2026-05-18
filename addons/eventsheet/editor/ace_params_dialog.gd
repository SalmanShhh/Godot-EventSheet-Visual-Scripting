# EventSheet — ACE Parameters dialog component
# Builds a dynamic form from ACEDefinition.parameters metadata and emits
# params_confirmed when the user confirms.
@tool
class_name ACEParamsDialog
extends RefCounted

## Emitted when the user confirms the parameter form.
## values is a Dictionary of { param_id -> typed_value }.
## context is the same dictionary passed to open().
signal params_confirmed(definition: ACEDefinition, values: Dictionary, context: Dictionary)

const REEDIT_HINT_TEXT := " Existing values were loaded so designers can re-edit without re-entering parameters."

var _dialog: ConfirmationDialog = null
var _form: VBoxContainer = null
var _fields: Dictionary = {}
var _field_specs: Dictionary = {}
var _definition: ACEDefinition = null
var _context: Dictionary = {}
var _hint_label: Label = null

## Initialise and attach the dialog to parent_node.
## Must be called before open().
func init_dialog(parent_node: Node) -> void:
	if _dialog != null:
		return
	_dialog = ConfirmationDialog.new()
	_dialog.title = "ACE Parameters"
	_dialog.visible = false
	_dialog.confirmed.connect(_on_confirmed)
	_dialog.close_requested.connect(_close)
	_dialog.canceled.connect(_close)
	parent_node.add_child(_dialog)

	var content: VBoxContainer = VBoxContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_dialog.add_child(content)

	_hint_label = Label.new()
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_hint_label)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.custom_minimum_size = Vector2(520.0, 260.0)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(scroll)

	_form = VBoxContainer.new()
	_form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_form.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(_form)

## Open the parameter form for the given ACEDefinition.
## context is an opaque dictionary forwarded in the params_confirmed signal.
func open(definition: ACEDefinition, context: Dictionary) -> void:
	open_with_values(definition, context, {})

func open_with_values(definition: ACEDefinition, context: Dictionary, initial_values: Dictionary) -> void:
	if _dialog == null:
		push_error("ACEParamsDialog.open() called before init_dialog().")
		return
	_definition = definition
	_context = context.duplicate(true)
	_fields.clear()
	_field_specs.clear()
	for child in _form.get_children():
		_form.remove_child(child)
		child.queue_free()
	var first_field: Control = null
	for parameter: Variant in definition.parameters:
		if not (parameter is Dictionary):
			continue
		var param_dict: Dictionary = parameter as Dictionary
		var row: HBoxContainer = HBoxContainer.new()
		var label: Label = Label.new()
		var key: String = str(param_dict.get("id", ""))
		label.text = str(param_dict.get("display_name", key))
		var description: String = str(param_dict.get("description", ""))
		if not description.is_empty():
			label.tooltip_text = description
		label.custom_minimum_size = Vector2(160.0, 0.0)
		row.add_child(label)
		var field: Control = _create_field(param_dict, initial_values)
		field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(field)
		_form.add_child(row)
		_fields[key] = field
		_field_specs[key] = param_dict.duplicate(true)
		if first_field == null:
			first_field = field
	_dialog.title = "%s Parameters" % definition.display_name
	if _hint_label != null:
		_hint_label.text = _build_context_hint(definition, context, initial_values)
	_dialog.popup_centered(Vector2i(560, 360))
	if first_field != null:
		first_field.grab_focus()

func _close() -> void:
	if _dialog != null:
		_dialog.hide()

## Build a typed input widget for one parameter entry.
func _create_field(param_dict: Dictionary, initial_values: Dictionary) -> Control:
	var field_type: int = int(param_dict.get("type", TYPE_NIL))
	var key: String = str(param_dict.get("id", ""))
	var default_value: Variant = initial_values.get(key, param_dict.get("default_value", ""))
	var options: Array = param_dict.get("options", [])
	if options is Array and not options.is_empty():
		var dropdown: OptionButton = OptionButton.new()
		for option_entry in options:
			var option_key: String = ""
			var option_label: String = ""
			if option_entry is Dictionary:
				option_key = str((option_entry as Dictionary).get("key", ""))
				option_label = str((option_entry as Dictionary).get("label", option_key))
			else:
				option_key = str(option_entry)
				option_label = option_key
			if option_key.is_empty():
				continue
			dropdown.add_item(option_label)
			var index: int = dropdown.item_count - 1
			dropdown.set_item_metadata(index, option_key)
			if option_key == str(default_value):
				dropdown.select(index)
		return dropdown
	if field_type == TYPE_BOOL:
		var check: CheckBox = CheckBox.new()
		check.button_pressed = _parse_bool(default_value)
		return check
	if field_type in [TYPE_INT, TYPE_FLOAT]:
		var spin: SpinBox = SpinBox.new()
		spin.step = 1.0 if field_type == TYPE_INT else 0.1
		spin.allow_greater = true
		spin.allow_lesser = true
		spin.value = float(default_value)
		return spin
	var edit: LineEdit = LineEdit.new()
	edit.text = str(default_value)
	return edit

## Extract the typed value from a field widget.
func _extract_value(field: Control) -> Variant:
	if field is CheckBox:
		return (field as CheckBox).button_pressed
	if field is OptionButton:
		var option_button: OptionButton = field as OptionButton
		var selected_index: int = option_button.selected
		if selected_index < 0:
			return ""
		var metadata: Variant = option_button.get_item_metadata(selected_index)
		if metadata != null:
			return metadata
		return option_button.get_item_text(selected_index)
	if field is SpinBox:
		var spin: SpinBox = field as SpinBox
		if is_equal_approx(spin.step, 1.0):
			return int(spin.value)
		return spin.value
	if field is LineEdit:
		return (field as LineEdit).text
	return ""

func _on_confirmed() -> void:
	if _definition == null:
		return
	var values: Dictionary = {}
	for key: Variant in _fields.keys():
		values[str(key)] = _extract_value(_fields[key])
	params_confirmed.emit(_definition, values, _context.duplicate(true))
	_definition = null
	_field_specs.clear()
	_context.clear()

static func _parse_bool(value: Variant) -> bool:
	return str(value).to_lower() in ["true", "1", "yes"]

func _build_context_hint(definition: ACEDefinition, context: Dictionary, initial_values: Dictionary) -> String:
	var mode: String = str(context.get("mode", "new_event"))
	var is_reedit: bool = not initial_values.is_empty()
	var mode_label: String = "Add"
	match mode:
		"replace_condition", "replace_trigger", "replace_action":
			mode_label = "Update"
		"new_sub_condition_event":
			mode_label = "Add nested event"
		_:
			mode_label = "Add"
	var reedit_hint: String = REEDIT_HINT_TEXT if is_reedit else ""
	return "%s %s parameters.%s" % [mode_label, definition.display_name, reedit_hint]
