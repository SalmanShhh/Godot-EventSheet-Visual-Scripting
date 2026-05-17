# EventSheet — Variable creation dialog component
# Provides a reusable form for creating global or local variables.
# Connect to variable_confirmed to receive the result.
@tool
class_name VariableDialog
extends RefCounted

## Emitted when the user confirms variable creation.
## scope is "global" or "local".
signal variable_confirmed(name: String, type_name: String, default_value: Variant, scope: String)

var _dialog: ConfirmationDialog = null
var _scope_label: Label = null
var _name_edit: LineEdit = null
var _type_option: OptionButton = null
var _default_edit: LineEdit = null
var _scope: String = "global"

## Initialise and attach the dialog to parent_node.
## Must be called before open().
func init_dialog(parent_node: Node) -> void:
	if _dialog != null:
		return
	_dialog = ConfirmationDialog.new()
	_dialog.title = "Create Variable"
	_dialog.visible = false
	_dialog.confirmed.connect(_on_confirmed)
	_dialog.close_requested.connect(_close)
	_dialog.canceled.connect(_close)
	parent_node.add_child(_dialog)

	var form: VBoxContainer = VBoxContainer.new()
	form.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	form.custom_minimum_size = Vector2(420.0, 180.0)
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_dialog.add_child(form)

	_scope_label = Label.new()
	form.add_child(_scope_label)

	var name_row: HBoxContainer = HBoxContainer.new()
	var name_label: Label = Label.new()
	name_label.text = "Name"
	name_label.custom_minimum_size = Vector2(120.0, 0.0)
	name_row.add_child(name_label)
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "health"
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(_name_edit)
	form.add_child(name_row)

	var type_row: HBoxContainer = HBoxContainer.new()
	var type_label: Label = Label.new()
	type_label.text = "Type"
	type_label.custom_minimum_size = Vector2(120.0, 0.0)
	type_row.add_child(type_label)
	_type_option = OptionButton.new()
	for option: String in ["int", "float", "bool", "String", "Variant"]:
		_type_option.add_item(option)
	_type_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	type_row.add_child(_type_option)
	form.add_child(type_row)

	var default_row: HBoxContainer = HBoxContainer.new()
	var default_label: Label = Label.new()
	default_label.text = "Default"
	default_label.custom_minimum_size = Vector2(120.0, 0.0)
	default_row.add_child(default_label)
	_default_edit = LineEdit.new()
	_default_edit.placeholder_text = "0"
	_default_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	default_row.add_child(_default_edit)
	form.add_child(default_row)

## Open the dialog for the given scope ("global" or "local").
func open(scope: String) -> void:
	if _dialog == null:
		push_error("VariableDialog.open() called before init_dialog().")
		return
	_scope = scope
	_scope_label.text = "Scope: %s" % scope.capitalize()
	_name_edit.text = ""
	_default_edit.text = ""
	_type_option.selected = 0
	_dialog.popup_centered(Vector2i(440, 220))

func _close() -> void:
	if _dialog != null:
		_dialog.hide()

func _on_confirmed() -> void:
	var var_name: String = _name_edit.text.strip_edges()
	if var_name.is_empty():
		return
	var type_name: String = _type_option.get_item_text(_type_option.selected)
	var default_value: Variant = _parse_default(type_name, _default_edit.text)
	variable_confirmed.emit(var_name, type_name, default_value, _scope)

## Returns the trimmed text from the name field.
func get_last_name_text() -> String:
	if _name_edit == null:
		return ""
	return _name_edit.text.strip_edges()

static func _parse_default(type_name: String, raw: String) -> Variant:
	var value: String = raw.strip_edges()
	match type_name:
		"int":
			return int(value) if not value.is_empty() else 0
		"float":
			return float(value) if not value.is_empty() else 0.0
		"bool":
			return value.to_lower() in ["true", "1", "yes"]
		"String":
			return value
		_:
			return value
