# Godot EventSheets — sheet-function dialog with an expanding parameter list
#
# The first UI for authoring EventFunctions (model + compiler + CallFunction existed;
# authoring was builder-only). Built for the first-time developer (user call):
# parameters grow row by row via "+ Add parameter" with auto-unique suggested names,
# names auto-snake_case on confirm, duplicates are refused with the reason named,
# and the expose-as-ACE fields stay behind their checkbox until wanted.
@tool
extends RefCounted
class_name EventSheetFunctionDialog

signal function_confirmed(data: Dictionary)

const RETURN_TYPES: Array[Dictionary] = [
	{"label": "void (action)", "type": TYPE_NIL},
	{"label": "bool (condition)", "type": TYPE_BOOL},
	{"label": "int", "type": TYPE_INT},
	{"label": "float", "type": TYPE_FLOAT},
	{"label": "String", "type": TYPE_STRING},
	{"label": "Vector2", "type": TYPE_VECTOR2},
	{"label": "Vector3", "type": TYPE_VECTOR3},
	{"label": "Variant", "type": TYPE_MAX},
]
const PARAM_TYPES: PackedStringArray = ["float", "int", "bool", "String", "Vector2", "Vector3", "Variant"]

var _dialog: ConfirmationDialog = null
var _name_edit: LineEdit = null
var _return_option: OptionButton = null
var _params_box: VBoxContainer = null
var _expose_check: CheckBox = null
var _expose_section: VBoxContainer = null
var _expose_name_edit: LineEdit = null
var _expose_category_edit: LineEdit = null
var _problem_label: Label = null
var _taken_names_provider: Callable = Callable()

func init_dialog(parent_node: Node) -> void:
	if _dialog != null:
		return
	_dialog = ConfirmationDialog.new()
	_dialog.title = "New Sheet Function"
	_dialog.ok_button_text = "Create Function"
	_dialog.confirmed.connect(_on_confirmed)
	parent_node.add_child(_dialog)
	var form: VBoxContainer = EventSheetPopupUI.form_box()
	form.custom_minimum_size = Vector2(440.0, 0.0)
	_dialog.add_child(EventSheetPopupUI.margined(form))
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "deal_damage"
	_dialog.register_text_enter(_name_edit)
	form.add_child(EventSheetPopupUI.form_row("Name", _name_edit))
	_return_option = OptionButton.new()
	for entry: Dictionary in RETURN_TYPES:
		_return_option.add_item(str(entry.get("label")))
	_return_option.tooltip_text = "void functions become actions; bool functions become conditions when exposed."
	form.add_child(EventSheetPopupUI.form_row("Returns", _return_option))
	# Parameters: the label sits in the 130px column and the param rows + the Add button fill
	# the field column, so each param's name field lines up with Name/Returns above it.
	var params_row: HBoxContainer = HBoxContainer.new()
	var params_label: Label = Label.new()
	params_label.text = "Parameters"
	params_label.custom_minimum_size = Vector2(EventSheetPopupUI.LABEL_MIN_WIDTH, 0.0)
	params_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	params_row.add_child(params_label)
	var params_col: VBoxContainer = VBoxContainer.new()
	params_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_params_box = VBoxContainer.new()
	params_col.add_child(_params_box)
	var add_param_button: Button = Button.new()
	add_param_button.text = "+ Add parameter"
	add_param_button.tooltip_text = "Each parameter gets a name and a type; names auto-suggest and stay unique."
	add_param_button.pressed.connect(func() -> void: add_param_row())
	params_col.add_child(add_param_button)
	params_row.add_child(params_col)
	form.add_child(params_row)
	_expose_check = CheckBox.new()
	_expose_check.text = "Expose as a reusable action (other sheets can pick it)"
	_expose_check.tooltip_text = "Publishes the function into pickers — as an action (void) or expression (typed return)."
	_expose_check.toggled.connect(func(on: bool) -> void: _expose_section.visible = on)
	form.add_child(_expose_check)
	_expose_section = EventSheetPopupUI.form_box()
	_expose_section.visible = false
	_expose_name_edit = LineEdit.new()
	_expose_name_edit.placeholder_text = "defaults from the function name"
	_expose_section.add_child(EventSheetPopupUI.form_row("Display name", _expose_name_edit))
	_expose_category_edit = LineEdit.new()
	_expose_category_edit.placeholder_text = "e.g. Combat"
	_expose_section.add_child(EventSheetPopupUI.form_row("Picker category", _expose_category_edit))
	form.add_child(_expose_section)
	_problem_label = Label.new()
	_problem_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_problem_label.visible = false
	_problem_label.add_theme_color_override("font_color", Color(0.95, 0.5, 0.5))
	form.add_child(_problem_label)

## Names already taken on the sheet (functions + variables) — duplicates are refused.
func set_taken_names_provider(provider: Callable) -> void:
	_taken_names_provider = provider

func open() -> void:
	for child: Node in _params_box.get_children():
		child.queue_free()
	_name_edit.text = ""
	_expose_check.button_pressed = false
	_expose_section.visible = false
	_expose_name_edit.text = ""
	_expose_category_edit.text = ""
	_problem_label.visible = false
	_return_option.select(0)
	if _dialog.is_inside_tree():
		_dialog.popup_centered()
	_name_edit.grab_focus()

## One expanding row per parameter: auto-unique suggested name + type + remove.
func add_param_row(suggested_name: String = "") -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var param_name: LineEdit = LineEdit.new()
	param_name.text = suggested_name if not suggested_name.is_empty() else _next_param_name()
	param_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(param_name)
	var param_type: OptionButton = OptionButton.new()
	for type_name: String in PARAM_TYPES:
		param_type.add_item(type_name)
	row.add_child(param_type)
	var remove_button: Button = Button.new()
	remove_button.text = "✕"
	remove_button.tooltip_text = "Remove this parameter."
	remove_button.pressed.connect(func() -> void:
		_params_box.remove_child(row)
		row.queue_free())
	row.add_child(remove_button)
	_params_box.add_child(row)

func _next_param_name() -> String:
	var taken: Dictionary = {}
	for entry: Dictionary in collect_params():
		taken[str(entry.get("id"))] = true
	var index: int = 1
	while taken.has("param_%d" % index):
		index += 1
	return "param_%d" % index

## The current param rows as [{id, type_name}] (names snake_cased + de-duplicated).
func collect_params() -> Array[Dictionary]:
	var params: Array[Dictionary] = []
	var seen: Dictionary = {}
	for row: Node in _params_box.get_children():
		if row.get_child_count() < 2 or not (row.get_child(0) is LineEdit):
			continue
		var raw_name: String = (row.get_child(0) as LineEdit).text.strip_edges().to_snake_case()
		if raw_name.is_empty() or not raw_name.is_valid_identifier() or seen.has(raw_name):
			continue
		seen[raw_name] = true
		params.append({"id": raw_name, "type_name": (row.get_child(1) as OptionButton).get_item_text((row.get_child(1) as OptionButton).selected)})
	return params

func _on_confirmed() -> void:
	var data: Dictionary = build_function_data()
	if not str(data.get("problem", "")).is_empty():
		_problem_label.text = "✗ %s" % str(data.get("problem"))
		_problem_label.visible = true
		if _dialog.is_inside_tree():
			_dialog.call_deferred("popup_centered")
		return
	function_confirmed.emit(data)

## Validated dialog state → {name, return_type, params, expose, ace_display_name,
## ace_category} or {problem}. Auto-corrections: names snake_case, display name
## defaults from the function name.
func build_function_data() -> Dictionary:
	var function_name: String = _name_edit.text.strip_edges().to_snake_case()
	if function_name.is_empty() or not function_name.is_valid_identifier():
		return {"problem": "Function names must be valid identifiers (e.g. deal_damage)."}
	if _taken_names_provider.is_valid() and (_taken_names_provider.call() as PackedStringArray).has(function_name):
		return {"problem": "\"%s\" already exists on this sheet (function or variable)." % function_name}
	var selected_return: Dictionary = RETURN_TYPES[maxi(_return_option.selected, 0)]
	return {
		"problem": "",
		"name": function_name,
		"return_type": int(selected_return.get("type")),
		"params": collect_params(),
		"expose": _expose_check.button_pressed,
		"ace_display_name": _expose_name_edit.text.strip_edges() if not _expose_name_edit.text.strip_edges().is_empty() else function_name.capitalize(),
		"ace_category": _expose_category_edit.text.strip_edges(),
	}
