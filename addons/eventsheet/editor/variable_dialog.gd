# EventSheet — Variable creation dialog component
# Provides a reusable form for creating global or local variables.
# Connect to variable_confirmed to receive the result.
@tool
class_name VariableDialog
extends RefCounted

## Emitted when the user confirms variable creation or editing.
## scope is "global" or "local". exported = accessible outside the generated script
## (@export var) vs. private (var).
signal variable_confirmed(name: String, type_name: String, default_value: Variant, scope: String, context: Dictionary, is_constant: bool, exported: bool)

var _dialog: ConfirmationDialog = null
var _scope_label: Label = null
var _name_edit: LineEdit = null
var _type_option: OptionButton = null
var _default_edit: LineEdit = null
var _const_check: CheckBox = null
var _exported_check: CheckBox = null
var _const_help: Label = null
var _type_help: Label = null
var _scope: String = "global"
var _context: Dictionary = {}

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
	_type_option.item_selected.connect(func(_index: int) -> void:
		_refresh_const_ui()
	)
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

	var const_row: HBoxContainer = HBoxContainer.new()
	var const_label: Label = Label.new()
	const_label.text = "Flags"
	const_label.custom_minimum_size = Vector2(120.0, 0.0)
	const_row.add_child(const_label)
	_const_check = CheckBox.new()
	_const_check.text = "Constant (const)"
	const_row.add_child(_const_check)
	form.add_child(const_row)

	var access_row: HBoxContainer = HBoxContainer.new()
	var access_label: Label = Label.new()
	access_label.text = "Access"
	access_label.custom_minimum_size = Vector2(120.0, 0.0)
	access_row.add_child(access_label)
	_exported_check = CheckBox.new()
	_exported_check.text = "Global (@export — usable outside the script)"
	_exported_check.tooltip_text = "On: emitted as @export var (other scripts / the inspector can read it).\nOff: emitted as a plain var, private to this event sheet's script."
	access_row.add_child(_exported_check)
	form.add_child(access_row)

	_const_help = Label.new()
	_const_help.visible = false
	_const_help.modulate = Color(0.82, 0.82, 0.82, 0.82)
	form.add_child(_const_help)

	_type_help = Label.new()
	_type_help.visible = false
	_type_help.modulate = Color(0.82, 0.82, 0.82, 0.82)
	form.add_child(_type_help)

## Open the dialog for the given scope ("global" or "local").
func open(scope: String) -> void:
	open_for_edit(scope, {}, "", "int", "", false, "Create Variable", false, scope == "global")

func open_for_edit(
	scope: String,
	context: Dictionary = {},
	name: String = "",
	type_name: String = "int",
	default_value: Variant = "",
	lock_type: bool = false,
	title: String = "Edit Variable",
	is_constant: bool = false,
	exported: bool = true
) -> void:
	if _dialog == null:
		push_error("VariableDialog.open() called before init_dialog().")
		return
	_scope = scope
	_context = context.duplicate(true)
	_scope_label.text = "Scope: %s" % scope.capitalize()
	_dialog.title = title
	_name_edit.text = name
	_default_edit.text = str(default_value)
	var selected_index: int = 0
	for index: int in range(_type_option.item_count):
		if _type_option.get_item_text(index) == type_name:
			selected_index = index
			break
	_type_option.select(selected_index)
	_const_check.button_pressed = is_constant
	# Local variables are inherently private to the script body, so the export toggle only
	# applies to global (sheet-level) variables.
	var is_local: bool = scope == "local"
	_exported_check.button_pressed = exported and not is_local
	_exported_check.disabled = is_local
	_exported_check.tooltip_text = (
		"Local variables are always private to the script."
		if is_local
		else "On: emitted as @export var (readable outside the script).\nOff: a plain private var."
	)
	_refresh_const_ui()
	_type_option.disabled = lock_type
	_type_help.visible = lock_type
	_type_help.text = "Type is locked because this variable is already in use."
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
	# Keep this defensive check in case stale UI state emits a checked const flag
	# for a type that does not support const.
	var is_constant: bool = _const_check.button_pressed and _supports_constant(type_name)
	var exported: bool = _exported_check.button_pressed and _scope == "global"
	variable_confirmed.emit(var_name, type_name, default_value, _scope, _context.duplicate(true), is_constant, exported)

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

func _refresh_const_ui() -> void:
	if _const_check == null or _const_help == null or _type_option == null:
		return
	var type_name: String = _type_option.get_item_text(_type_option.selected)
	var supports_const: bool = _supports_constant(type_name)
	_const_check.disabled = not supports_const
	if not supports_const:
		_const_check.button_pressed = false
	_const_help.visible = not supports_const
	_const_help.text = "Const is unavailable for Variant variables."

func _supports_constant(type_name: String) -> bool:
	return type_name != "Variant"
