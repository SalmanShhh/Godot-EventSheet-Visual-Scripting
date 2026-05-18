# EventSheet — ACE Parameters dialog component
# Builds a dynamic form from ACEDefinition.parameters metadata and emits
# params_confirmed when the user confirms.
#
# Expression parameters (descriptor has "expression": true or type TYPE_EXPRESSION)
# open the ExpressionEditorDialog instead of a plain text field.
@tool
class_name ACEParamsDialog
extends RefCounted

## Emitted when the user confirms the parameter form.
## values is a Dictionary of { param_id -> typed_value }.
## context is the same dictionary passed to open().
signal params_confirmed(definition: ACEDefinition, values: Dictionary, context: Dictionary)

## Sentinel used to identify expression-type parameters that need the expression editor.
const TYPE_EXPRESSION := 9900

var _dialog: ConfirmationDialog = null
var _form: VBoxContainer = null
var _hint: Label = null
var _fields: Dictionary = {}
var _definition: ACEDefinition = null
var _context: Dictionary = {}
## ExpressionEditorDialog instance; shared and re-used across params in the same form.
var _expression_editor: ExpressionEditorDialog = null
## Tracks which parameter keys are expression-type for special extraction handling.
var _expression_param_keys: Dictionary = {}
## Available variable names passed in from the sheet context for the expression editor.
var _available_variable_names: Array = []

## Initialise and attach the dialog to parent_node.
## Must be called before open().
## expression_editor is optional; if provided, expression-type params use it instead of LineEdit.
func init_dialog(parent_node: Node, expression_editor: ExpressionEditorDialog = null) -> void:
	_expression_editor = expression_editor
	if _expression_editor != null and not _expression_editor.expression_confirmed.is_connected(_on_expression_editor_confirmed):
		_expression_editor.expression_confirmed.connect(_on_expression_editor_confirmed)
	_init_dialog_internal(parent_node)

func _init_dialog_internal(parent_node: Node) -> void:
	if _dialog != null:
		return
	_dialog = ConfirmationDialog.new()
	_dialog.title = "ACE Parameters"
	_dialog.visible = false
	_dialog.confirmed.connect(_on_confirmed)
	_dialog.close_requested.connect(_close)
	_dialog.canceled.connect(_close)
	parent_node.add_child(_dialog)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.custom_minimum_size = Vector2(520.0, 260.0)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_dialog.add_child(scroll)

	_form = VBoxContainer.new()
	_form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_form.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_hint = Label.new()
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.modulate = Color(0.80, 0.85, 0.95, 0.95)
	_form.add_child(_hint)
	scroll.add_child(_form)

## Open the parameter form for the given ACEDefinition.
## context is an opaque dictionary forwarded in the params_confirmed signal.
## variable_names provides available sheet variables for expression editor panels.
func open(definition: ACEDefinition, context: Dictionary, variable_names: Array = []) -> void:
	open_with_values(definition, context, {}, variable_names)

func open_with_values(definition: ACEDefinition, context: Dictionary, initial_values: Dictionary, variable_names: Array = []) -> void:
	if _dialog == null:
		push_error("ACEParamsDialog.open() called before init_dialog().")
		return
	_definition = definition
	_context = context.duplicate(true)
	_available_variable_names = variable_names.duplicate()
	_expression_param_keys.clear()
	_fields.clear()
	for child in _form.get_children():
		_form.remove_child(child)
		child.queue_free()
	_hint = Label.new()
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.modulate = Color(0.80, 0.85, 0.95, 0.95)
	_form.add_child(_hint)
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
		# Expression-type params get a special "Edit Expression" button that opens
		# the ExpressionEditorDialog, with the current value displayed as read-only.
		if _is_expression_param(param_dict):
			_expression_param_keys[key] = true
			var expr_row: HBoxContainer = row
			var initial_expr: String = str(initial_values.get(key, param_dict.get("default_value", "")))
			var expr_preview: LineEdit = LineEdit.new()
			expr_preview.text = initial_expr
			expr_preview.placeholder_text = "expression…"
			expr_preview.editable = true
			expr_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var edit_btn: Button = Button.new()
			edit_btn.text = "…"
			edit_btn.tooltip_text = "Open expression editor"
			edit_btn.pressed.connect(func() -> void:
				_open_expression_editor_for(key, expr_preview.text, str(label.text))
			)
			expr_row.add_child(expr_preview)
			expr_row.add_child(edit_btn)
			_form.add_child(expr_row)
			_fields[key] = expr_preview
		else:
			var field: Control = _create_field(param_dict, initial_values)
			field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(field)
			_form.add_child(row)
			_fields[key] = field
	_dialog.title = "%s Parameters%s" % [
		definition.display_name,
		" (Edit)" if _is_reedit_flow() else ""
	]
	_hint.text = _build_hint_text()
	_dialog.popup_centered(Vector2i(560, 360))
	call_deferred("_focus_first_field")

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
	_context.clear()

func _is_reedit_flow() -> bool:
	var mode: String = str(_context.get("mode", ""))
	return mode.begins_with("replace")

func _build_hint_text() -> String:
	var mode: String = str(_context.get("mode", ""))
	var base: String = "Fill in parameters, then press OK to apply."
	match mode:
		"append_condition":
			base = "Adding a condition to the selected event."
		"append_action":
			base = "Adding an action to the selected event."
		"new_sub_condition_event":
			base = "Creating a nested sub-condition event."
		"replace_condition", "replace_trigger", "replace_action":
			base = "Re-editing an existing ACE entry."
		"new_event", "new_condition_event":
			base = "Creating a new event from this ACE."
	return "%s %s" % [
		base,
		"Existing values were loaded for quick re-editing." if _is_reedit_flow() else ""
	]

func _focus_first_field() -> void:
	for key in _fields.keys():
		var field: Control = _fields[key] as Control
		if field != null and field.visible:
			field.grab_focus()
			return

## Returns true when a parameter descriptor marks this as an expression type.
## Checks for "expression": true or a TYPE_EXPRESSION sentinel type.
static func _is_expression_param(param_dict: Dictionary) -> bool:
	if bool(param_dict.get("expression", false)):
		return true
	return int(param_dict.get("type", TYPE_NIL)) == TYPE_EXPRESSION

## Opens the ExpressionEditorDialog for a specific expression-type parameter.
func _open_expression_editor_for(param_key: String, current_value: String, display_name: String) -> void:
	if _expression_editor == null:
		# Fallback: just allow editing in the LineEdit directly.
		return
	_expression_editor.open(
		param_key,
		current_value,
		display_name,
		_available_variable_names,
		_context.duplicate(true)
	)

## Callback when the ExpressionEditorDialog confirms a value.
## Updates the preview LineEdit in the params form with the confirmed expression.
func _on_expression_editor_confirmed(param_key: String, value: String, _expr_context: Dictionary) -> void:
	if _fields.has(param_key) and _fields[param_key] is LineEdit:
		(_fields[param_key] as LineEdit).text = value

static func _parse_bool(value: Variant) -> bool:
	return str(value).to_lower() in ["true", "1", "yes"]
