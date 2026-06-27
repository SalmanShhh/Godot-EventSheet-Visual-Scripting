# Godot EventSheets — sheet-function dialog (Construct-3 style)
#
# Authors an EventFunction from a popup, the way Construct's "Add function" dialog does:
#  • "Usable as" picks Action / Condition / Expression in one control (an Expression is a getter
#    that returns a typed value; a Condition is a bool test; an Action is a void doer / setter) and
#    sets the return type for you — the easy get/set toggle.
#  • Parameters are full C3 rows: name · type · default value · description.
#  • "Run only when" adds guard conditions (GDScript boolean expressions) that wrap the function
#    body in an `if`, so the body only runs when they hold (e.g. a node setting is enabled).
#  • Expose-as-ACE publishes it into other sheets' pickers.
@tool
extends RefCounted
class_name EventSheetFunctionDialog

signal function_confirmed(data: Dictionary)

# "Usable as" → the EventFunction return type the three-way expose derives its directive from
# (void = action, bool = condition, any other value = expression).
const USABLE_AS: Array[Dictionary] = [
	{"label": "Action (does something — a setter)", "kind": "action"},
	{"label": "Condition (a yes/no test)", "kind": "condition"},
	{"label": "Expression (returns a value — a getter)", "kind": "expression"},
]
# Value types offered when "Usable as" is Expression.
const VALUE_TYPES: Array[Dictionary] = [
	{"label": "float", "type": TYPE_FLOAT},
	{"label": "int", "type": TYPE_INT},
	{"label": "String", "type": TYPE_STRING},
	{"label": "bool", "type": TYPE_BOOL},
	{"label": "Vector2", "type": TYPE_VECTOR2},
	{"label": "Vector3", "type": TYPE_VECTOR3},
	{"label": "Variant", "type": TYPE_MAX},
]
const PARAM_TYPES: PackedStringArray = ["float", "int", "bool", "String", "Vector2", "Vector3", "Variant"]

var _dialog: ConfirmationDialog = null
var _name_edit: LineEdit = null
var _description_edit: LineEdit = null
var _usable_option: OptionButton = null
var _value_type_row: Control = null
var _value_type_option: OptionButton = null
var _params_box: VBoxContainer = null
var _guards_box: VBoxContainer = null
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
	form.custom_minimum_size = Vector2(520.0, 0.0)
	_dialog.add_child(EventSheetPopupUI.margined(form))

	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "deal_damage"
	_dialog.register_text_enter(_name_edit)
	form.add_child(EventSheetPopupUI.form_row("Name", _name_edit))

	_description_edit = LineEdit.new()
	_description_edit.placeholder_text = "What this function does (shown in the picker)."
	form.add_child(EventSheetPopupUI.form_row("Description", _description_edit))

	# Usable as: the get/set + condition toggle. Expression reveals a value-type sub-row.
	_usable_option = OptionButton.new()
	for entry: Dictionary in USABLE_AS:
		_usable_option.add_item(str(entry.get("label")))
	_usable_option.item_selected.connect(func(_index: int) -> void: _sync_value_type_visibility())
	form.add_child(EventSheetPopupUI.form_row("Usable as", _usable_option))
	_value_type_option = OptionButton.new()
	for entry: Dictionary in VALUE_TYPES:
		_value_type_option.add_item(str(entry.get("label")))
	_value_type_row = EventSheetPopupUI.form_row("Value type", _value_type_option)
	form.add_child(_value_type_row)

	# Parameters — C3-style rows: name · type · default · description.
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
	add_param_button.tooltip_text = "Each parameter has a name, type, optional default value, and description."
	add_param_button.pressed.connect(func() -> void: add_param_row())
	params_col.add_child(add_param_button)
	params_row.add_child(params_col)
	form.add_child(params_row)

	# Run only when — guard conditions that wrap the function body in an `if`.
	var guards_row: HBoxContainer = HBoxContainer.new()
	var guards_label: Label = Label.new()
	guards_label.text = "Run only when"
	guards_label.custom_minimum_size = Vector2(EventSheetPopupUI.LABEL_MIN_WIDTH, 0.0)
	guards_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	guards_row.add_child(guards_label)
	var guards_col: VBoxContainer = VBoxContainer.new()
	guards_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_guards_box = VBoxContainer.new()
	guards_col.add_child(_guards_box)
	var add_guard_button: Button = Button.new()
	add_guard_button.text = "+ Add condition"
	add_guard_button.tooltip_text = "A GDScript boolean expression — the body runs only when all hold (e.g. host.enabled)."
	add_guard_button.pressed.connect(func() -> void: add_guard_row())
	guards_col.add_child(add_guard_button)
	guards_row.add_child(guards_col)
	form.add_child(guards_row)

	# Expose as an ACE other sheets can pick.
	_expose_check = CheckBox.new()
	_expose_check.text = "Expose as a reusable ACE (other sheets can pick it)"
	_expose_check.tooltip_text = "Publishes the function into pickers as the chosen Usable-as kind."
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
	_sync_value_type_visibility()

## Names already taken on the sheet (functions + variables) — duplicates are refused.
func set_taken_names_provider(provider: Callable) -> void:
	_taken_names_provider = provider

func open() -> void:
	for child: Node in _params_box.get_children():
		child.queue_free()
	for child: Node in _guards_box.get_children():
		child.queue_free()
	_name_edit.text = ""
	_description_edit.text = ""
	_expose_check.button_pressed = false
	_expose_section.visible = false
	_expose_name_edit.text = ""
	_expose_category_edit.text = ""
	_problem_label.visible = false
	_usable_option.select(0)
	_value_type_option.select(0)
	_sync_value_type_visibility()
	if _dialog.is_inside_tree():
		_dialog.popup_centered()
	_name_edit.grab_focus()

## The value-type sub-row only matters for an Expression (Action = void, Condition = bool).
func _sync_value_type_visibility() -> void:
	if _value_type_row != null:
		_value_type_row.visible = _usable_kind() == "expression"

func _usable_kind() -> String:
	return str(USABLE_AS[maxi(_usable_option.selected, 0)].get("kind"))

## One expanding row per parameter: name · type · default · description · remove.
func add_param_row(suggested_name: String = "") -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var param_name: LineEdit = LineEdit.new()
	param_name.text = suggested_name if not suggested_name.is_empty() else _next_param_name()
	param_name.custom_minimum_size = Vector2(110.0, 0.0)
	param_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(param_name)
	var param_type: OptionButton = OptionButton.new()
	for type_name: String in PARAM_TYPES:
		param_type.add_item(type_name)
	row.add_child(param_type)
	var param_default: LineEdit = LineEdit.new()
	param_default.placeholder_text = "default"
	param_default.tooltip_text = "Optional default value (a GDScript expression). Defaulted params must come last."
	param_default.custom_minimum_size = Vector2(80.0, 0.0)
	row.add_child(param_default)
	var param_desc: LineEdit = LineEdit.new()
	param_desc.placeholder_text = "description"
	param_desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(param_desc)
	var remove_button: Button = Button.new()
	remove_button.text = "✕"
	remove_button.tooltip_text = "Remove this parameter."
	remove_button.pressed.connect(func() -> void:
		_params_box.remove_child(row)
		row.queue_free())
	row.add_child(remove_button)
	_params_box.add_child(row)

## One row per guard condition: a boolean expression + remove.
func add_guard_row(expression: String = "") -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var guard_edit: LineEdit = LineEdit.new()
	guard_edit.text = expression
	guard_edit.placeholder_text = "e.g. host.enabled  or  is_active"
	guard_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(guard_edit)
	var remove_button: Button = Button.new()
	remove_button.text = "✕"
	remove_button.tooltip_text = "Remove this condition."
	remove_button.pressed.connect(func() -> void:
		_guards_box.remove_child(row)
		row.queue_free())
	row.add_child(remove_button)
	_guards_box.add_child(row)

func _next_param_name() -> String:
	var taken: Dictionary = {}
	for entry: Dictionary in collect_params():
		taken[str(entry.get("id"))] = true
	var index: int = 1
	while taken.has("param_%d" % index):
		index += 1
	return "param_%d" % index

## The current param rows as [{id, type_name, default, description}] (names snake_cased + de-duplicated).
func collect_params() -> Array[Dictionary]:
	var params: Array[Dictionary] = []
	var seen: Dictionary = {}
	for row: Node in _params_box.get_children():
		if row.get_child_count() < 4 or not (row.get_child(0) is LineEdit):
			continue
		var raw_name: String = (row.get_child(0) as LineEdit).text.strip_edges().to_snake_case()
		if raw_name.is_empty() or not raw_name.is_valid_identifier() or seen.has(raw_name):
			continue
		seen[raw_name] = true
		var type_option: OptionButton = row.get_child(1) as OptionButton
		params.append({
			"id": raw_name,
			"type_name": type_option.get_item_text(type_option.selected),
			"default": (row.get_child(2) as LineEdit).text.strip_edges(),
			"description": (row.get_child(3) as LineEdit).text.strip_edges(),
		})
	return params

## The current guard expressions (non-empty, in order).
func collect_guards() -> PackedStringArray:
	var guards: PackedStringArray = PackedStringArray()
	for row: Node in _guards_box.get_children():
		if row.get_child_count() < 1 or not (row.get_child(0) is LineEdit):
			continue
		var expression: String = (row.get_child(0) as LineEdit).text.strip_edges()
		if not expression.is_empty():
			guards.append(expression)
	return guards

func _on_confirmed() -> void:
	var data: Dictionary = build_function_data()
	if not str(data.get("problem", "")).is_empty():
		_problem_label.text = "✗ %s" % str(data.get("problem"))
		_problem_label.visible = true
		if _dialog.is_inside_tree():
			_dialog.call_deferred("popup_centered")
		return
	function_confirmed.emit(data)

## Validated dialog state → {name, return_type, params, guards, description, expose,
## ace_display_name, ace_category} or {problem}. Auto-corrections: names snake_case, display
## name defaults from the function name, return type derived from "Usable as".
func build_function_data() -> Dictionary:
	var function_name: String = _name_edit.text.strip_edges().to_snake_case()
	if function_name.is_empty() or not function_name.is_valid_identifier():
		return {"problem": "Function names must be valid identifiers (e.g. deal_damage)."}
	if _taken_names_provider.is_valid() and (_taken_names_provider.call() as PackedStringArray).has(function_name):
		return {"problem": "\"%s\" already exists on this sheet (function or variable)." % function_name}
	var params: Array[Dictionary] = collect_params()
	# GDScript requires defaulted parameters to be trailing — refuse a gap so the generated
	# function never fails to parse.
	var seen_default: bool = false
	for param: Dictionary in params:
		if not str(param.get("default", "")).is_empty():
			seen_default = true
		elif seen_default:
			return {"problem": "Parameters with a default value must come after those without (\"%s\" has no default)." % str(param.get("id"))}
	var return_type: int = TYPE_NIL
	match _usable_kind():
		"condition":
			return_type = TYPE_BOOL
		"expression":
			return_type = int(VALUE_TYPES[maxi(_value_type_option.selected, 0)].get("type"))
		_:
			return_type = TYPE_NIL
	return {
		"problem": "",
		"name": function_name,
		"return_type": return_type,
		"params": params,
		"guards": collect_guards(),
		"description": _description_edit.text.strip_edges(),
		"expose": _expose_check.button_pressed,
		"ace_display_name": _expose_name_edit.text.strip_edges() if not _expose_name_edit.text.strip_edges().is_empty() else function_name.capitalize(),
		"ace_category": _expose_category_edit.text.strip_edges(),
	}
