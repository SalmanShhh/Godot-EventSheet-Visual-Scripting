# EventSheet — Expression Editor Dialog
# Provides a dedicated editing surface for ACE parameters that hold GDScript expressions.
# Opened automatically by ACEParamsDialog when a parameter descriptor has
# "expression": true or type TYPE_EXPRESSION (custom sentinel).
#
# Features:
#   - Single-line expression input with syntax-hint label
#   - Available sheet variables list (global + local from context)
#   - Clear/reset button
#   - OK/Cancel flow
#
# Deferred:
#   - Autocomplete dropdown
#   - Function browser panel
#   - Live expression validation / syntax error indicators
#   - Expression history per param key
@tool
class_name ExpressionEditorDialog
extends RefCounted

## Emitted when the user confirms the expression.
## param_key is the parameter id this dialog was opened for.
## value is the confirmed expression string.
## context is forwarded from the open() call.
signal expression_confirmed(param_key: String, value: String, context: Dictionary)

const HINT_TEXT := "Enter a GDScript expression. Sheet variables and node properties are in scope.\nExamples:  health * 2 + 10    speed > 5.0    \"hello \" + player_name"
const VAR_PANEL_HINT := "Double-click a variable to insert it at the cursor."

var _dialog: ConfirmationDialog = null
var _expression_input: LineEdit = null
var _hint_label: Label = null
var _var_list: ItemList = null
var _param_key: String = ""
var _context: Dictionary = {}

## Initialise and attach the dialog to parent_node.
## Must be called before open().
func init_dialog(parent_node: Node) -> void:
	if _dialog != null:
		return
	_dialog = ConfirmationDialog.new()
	_dialog.title = "Edit Expression"
	_dialog.visible = false
	_dialog.min_size = Vector2i(600, 380)
	_dialog.confirmed.connect(_on_confirmed)
	_dialog.close_requested.connect(_close)
	_dialog.canceled.connect(_close)
	parent_node.add_child(_dialog)

	var root: VBoxContainer = VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 6)
	_dialog.add_child(root)

	# Hint text
	_hint_label = Label.new()
	_hint_label.text = HINT_TEXT
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.modulate = Color(0.80, 0.85, 0.95, 0.90)
	root.add_child(_hint_label)

	# Expression input
	_expression_input = LineEdit.new()
	_expression_input.placeholder_text = "e.g. health * 2 + bonus"
	_expression_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_expression_input.clear_button_enabled = true
	root.add_child(_expression_input)

	# Variable browser
	var var_section_label: Label = Label.new()
	var_section_label.text = "Available sheet variables:"
	var_section_label.modulate = Color(0.72, 0.76, 0.88, 0.85)
	root.add_child(var_section_label)

	_var_list = ItemList.new()
	_var_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_var_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_var_list.custom_minimum_size = Vector2(0.0, 120.0)
	_var_list.item_activated.connect(_on_var_list_activated)
	_var_list.tooltip_text = VAR_PANEL_HINT
	root.add_child(_var_list)

## Open the expression editor for a specific parameter.
## param_key:      the ACE parameter id this expression belongs to
## initial_value:  current expression string (empty string for new params)
## display_name:   human-readable label shown in the dialog title
## variable_names: available variable names from the active sheet
## context:        opaque dictionary forwarded in expression_confirmed
func open(
	param_key: String,
	initial_value: String,
	display_name: String,
	variable_names: Array,
	context: Dictionary
) -> void:
	if _dialog == null:
		push_error("ExpressionEditorDialog.open() called before init_dialog().")
		return
	_param_key = param_key
	_context = context.duplicate(true)
	_dialog.title = "Edit Expression — %s" % display_name

	_expression_input.text = initial_value

	# Populate variable list
	_var_list.clear()
	for var_name in variable_names:
		_var_list.add_item(str(var_name))

	_dialog.popup_centered(Vector2i(640, 420))
	_expression_input.grab_focus()
	# Place caret at end of pre-filled text
	_expression_input.caret_column = _expression_input.text.length()

func _close() -> void:
	if _dialog != null:
		_dialog.hide()

func _on_confirmed() -> void:
	var value: String = _expression_input.text if _expression_input != null else ""
	expression_confirmed.emit(_param_key, value, _context.duplicate(true))
	_close()

## When the user double-clicks a variable name, insert it at the cursor position.
func _on_var_list_activated(index: int) -> void:
	if _var_list == null or _expression_input == null:
		return
	var var_name: String = _var_list.get_item_text(index)
	if var_name.is_empty():
		return
	var caret: int = _expression_input.caret_column
	var current: String = _expression_input.text
	_expression_input.text = current.substr(0, caret) + var_name + current.substr(caret)
	_expression_input.caret_column = caret + var_name.length()
	_expression_input.grab_focus()

func is_open() -> bool:
	return _dialog != null and _dialog.visible
