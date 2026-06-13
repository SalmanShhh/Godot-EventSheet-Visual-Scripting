# EventSheet — Variable creation dialog component
# Provides a reusable form for creating global or local variables.
# Connect to variable_confirmed to receive the result.
@tool
class_name VariableDialog
extends RefCounted

## Emitted when the user confirms variable creation or editing.
## scope is "global" or "local". exported = accessible outside the generated script
## (@export var) vs. private (var).
signal variable_confirmed(name: String, type_name: String, default_value: Variant, scope: String, context: Dictionary, is_constant: bool, exported: bool, options: PackedStringArray, attributes: Dictionary)

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
var _default_help: Label = null
var _options_edit: LineEdit = null
var _options_row: HBoxContainer = null
var _enum_fill_menu: MenuButton = null
var _enum_provider: Callable = Callable()
var _attr_toggle: Button = null
var _attr_section: VBoxContainer = null
var _attr_tooltip_edit: LineEdit = null
var _attr_group_edit: LineEdit = null
var _attr_range_edit: LineEdit = null
var _attr_multiline_check: CheckBox = null
var _attr_show_if_edit: LineEdit = null
var _attr_lock_unless_edit: LineEdit = null
var _attr_on_changed_edit: LineEdit = null
var _attr_clamp_check: CheckBox = null
var _attr_read_only_check: CheckBox = null
var _attr_drawer_option: OptionButton = null

## Offered types. Collections accept GDScript literal defaults ({"key": 1}, [1, 2]) with
## live validation; typed containers (Godot 4 Array[T] / Dictionary[K, V]) also check
## element types for builtin T.
const TYPE_OPTIONS: PackedStringArray = [
	"int", "float", "bool", "String", "Variant",
	"Array", "Array[int]", "Array[float]", "Array[String]",
	"Dictionary", "Dictionary[String, int]", "Dictionary[String, float]",
	"Dictionary[String, String]", "Dictionary[String, Variant]"
]

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
	for option: String in TYPE_OPTIONS:
		_type_option.add_item(option)
	_type_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_type_option.item_selected.connect(func(_index: int) -> void:
		_refresh_const_ui()
		_refresh_default_hint()
		_refresh_contextual_rows()
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
	_default_edit.text_changed.connect(func(_text: String) -> void:
		_refresh_default_hint()
	)
	default_row.add_child(_default_edit)
	form.add_child(default_row)
	_options_row = HBoxContainer.new()
	var options_label: Label = Label.new()
	options_label.text = "Options (combo)"
	options_label.custom_minimum_size = Vector2(120.0, 0.0)
	_options_row.add_child(options_label)
	_options_edit = LineEdit.new()
	_options_edit.placeholder_text = "comma-separated, e.g. easy, normal, hard (String only)"
	_options_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_options_row.add_child(_options_edit)
	# Sheet enums fill the combo in one click (user call: automate enums into combos).
	_enum_fill_menu = MenuButton.new()
	_enum_fill_menu.text = "From enum"
	_enum_fill_menu.flat = false
	_enum_fill_menu.visible = false
	_enum_fill_menu.about_to_popup.connect(_populate_enum_fill_menu)
	_enum_fill_menu.get_popup().index_pressed.connect(func(index: int) -> void:
		_options_edit.text = str(_enum_fill_menu.get_popup().get_item_metadata(index)))
	_options_row.add_child(_enum_fill_menu)
	form.add_child(_options_row)
	# Inspector attributes (Tiers 1–3) live behind a disclosure (user call: the dialog
	# threw everything at once) — collapsed for new variables, auto-expanded when the
	# variable being edited already uses any of them. Exported globals only.
	_attr_toggle = Button.new()
	_attr_toggle.flat = true
	_attr_toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_attr_toggle.toggle_mode = true
	_attr_toggle.text = "▸  Inspector options (tooltip, range, show-if…)"
	_attr_toggle.tooltip_text = "Optional Inspector polish for exported globals — everything compiles to plain Godot annotations."
	_attr_toggle.toggled.connect(func(expanded: bool) -> void:
		_attr_toggle.text = ("▾" if expanded else "▸") + _attr_toggle.text.substr(1)
		_attr_section.visible = expanded)
	form.add_child(_attr_toggle)
	_attr_section = VBoxContainer.new()
	_attr_section.visible = false
	form.add_child(_attr_section)
	_attr_tooltip_edit = LineEdit.new()
	_attr_tooltip_edit.placeholder_text = "Tooltip — shown when hovering the property"
	_attr_section.add_child(_attr_tooltip_edit)
	_attr_group_edit = LineEdit.new()
	_attr_group_edit.placeholder_text = "Group — Inspector section header (e.g. Combat)"
	_attr_section.add_child(_attr_group_edit)
	_attr_range_edit = LineEdit.new()
	_attr_range_edit.placeholder_text = "Range — min, max, step (numeric types: slider)"
	_attr_section.add_child(_attr_range_edit)
	_attr_multiline_check = CheckBox.new()
	_attr_multiline_check.text = "Multiline (String: big text box)"
	_attr_section.add_child(_attr_multiline_check)
	_attr_show_if_edit = LineEdit.new()
	_attr_show_if_edit.placeholder_text = "Show if — bool variable (hidden when false)"
	_attr_section.add_child(_attr_show_if_edit)
	_attr_lock_unless_edit = LineEdit.new()
	_attr_lock_unless_edit.placeholder_text = "Lock unless — bool variable (read-only when false)"
	_attr_section.add_child(_attr_lock_unless_edit)
	_attr_on_changed_edit = LineEdit.new()
	_attr_on_changed_edit.placeholder_text = "On changed — sheet function called after assignment"
	_attr_section.add_child(_attr_on_changed_edit)
	var attr_checks: HBoxContainer = HBoxContainer.new()
	_attr_clamp_check = CheckBox.new()
	_attr_clamp_check.text = "Clamp to range"
	attr_checks.add_child(_attr_clamp_check)
	_attr_drawer_option = OptionButton.new()
	_attr_drawer_option.add_item("Default field")
	_attr_drawer_option.add_item("Progress bar (numeric)")
	attr_checks.add_child(_attr_drawer_option)
	_attr_read_only_check = CheckBox.new()
	_attr_read_only_check.text = "Read-only"
	attr_checks.add_child(_attr_read_only_check)
	_attr_section.add_child(attr_checks)
	_default_help = Label.new()
	_default_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_default_help.custom_minimum_size = Vector2(380.0, 0.0)
	_default_help.visible = false
	_default_help.modulate = Color(0.82, 0.82, 0.82, 0.82)
	form.add_child(_default_help)

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
	_const_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_const_help.custom_minimum_size = Vector2(380.0, 0.0)
	_const_help.visible = false
	_const_help.modulate = Color(0.82, 0.82, 0.82, 0.82)
	form.add_child(_const_help)

	_type_help = Label.new()
	_type_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_type_help.custom_minimum_size = Vector2(380.0, 0.0)
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
	# Containers display as canonical GDScript literals (str() doesn't escape strings).
	if default_value is Array or default_value is Dictionary:
		_default_edit.text = SheetCompiler._to_code_literal(default_value)
	else:
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
	var existing_attributes: Dictionary = context.get("attributes") if context.get("attributes") is Dictionary else {}
	_attr_tooltip_edit.text = str(existing_attributes.get("tooltip", ""))
	_attr_group_edit.text = str(existing_attributes.get("group", ""))
	var existing_range: Variant = existing_attributes.get("range")
	_attr_range_edit.text = "%s, %s, %s" % [existing_range.get("min"), existing_range.get("max"), existing_range.get("step")] if existing_range is Dictionary else ""
	_attr_multiline_check.button_pressed = bool(existing_attributes.get("multiline", false))
	_attr_show_if_edit.text = str(existing_attributes.get("show_if", ""))
	_attr_lock_unless_edit.text = str(existing_attributes.get("lock_unless", ""))
	_attr_on_changed_edit.text = str(existing_attributes.get("on_changed", ""))
	_attr_clamp_check.button_pressed = bool(existing_attributes.get("clamp", false))
	_attr_read_only_check.button_pressed = bool(existing_attributes.get("read_only", false))
	_attr_drawer_option.select(1 if str(existing_attributes.get("drawer", "")) == "progress_bar" else 0)
	# Progressive disclosure: the Inspector section starts collapsed for new variables
	# and auto-expands when the variable already uses any attribute.
	if _attr_toggle != null:
		_attr_toggle.button_pressed = not existing_attributes.is_empty()
		_attr_section.visible = not existing_attributes.is_empty()
		_attr_toggle.text = ("▾" if _attr_section.visible else "▸") + _attr_toggle.text.substr(1)
	_refresh_const_ui()
	_refresh_default_hint()
	_refresh_contextual_rows()
	_type_option.disabled = lock_type
	_type_help.visible = lock_type
	_type_help.text = "Type is locked because this variable is already in use."
	if _dialog.is_inside_tree():
		_dialog.popup_centered(Vector2i(440, 220))

func _close() -> void:
	if _dialog != null:
		_dialog.hide()

func _on_confirmed() -> void:
	var var_name: String = _name_edit.text.strip_edges()
	if var_name.is_empty():
		return
	var type_name: String = _type_option.get_item_text(_type_option.selected)
	# Guardrail (C3-style): an invalid collection literal never commits — the dialog
	# reopens with the text intact so the user fixes or cancels deliberately.
	var verdict: Dictionary = validate_default(type_name, _default_edit.text)
	if not bool(verdict.get("ok", true)):
		if _default_help != null:
			_default_help.visible = true
			_default_help.text = "✗ %s" % str(verdict.get("error", ""))
		if _dialog.is_inside_tree():
			_dialog.call_deferred("popup_centered", Vector2i(440, 240))
		return
	var default_value: Variant = _parse_default(type_name, _default_edit.text)
	# Combo guardrail (C3): a String with options must default to one of them.
	var combo_options: PackedStringArray = parse_options(_options_edit.text if _options_edit != null else "")
	if type_name == "String" and not combo_options.is_empty():
		if str(default_value).strip_edges().is_empty():
			default_value = combo_options[0]
		elif not combo_options.has(str(default_value)):
			if _default_help != null:
				_default_help.visible = true
				_default_help.text = "✗ Default must be one of the options (%s)." % ", ".join(combo_options)
			if _dialog.is_inside_tree():
				_dialog.call_deferred("popup_centered", Vector2i(440, 260))
			return
	# Keep this defensive check in case stale UI state emits a checked const flag
	# for a type that does not support const.
	var is_constant: bool = _const_check.button_pressed and _supports_constant(type_name)
	var exported: bool = _exported_check.button_pressed and _scope == "global"
	var attributes: Dictionary = {}
	if not _attr_tooltip_edit.text.strip_edges().is_empty():
		attributes["tooltip"] = _attr_tooltip_edit.text.strip_edges()
	if not _attr_group_edit.text.strip_edges().is_empty():
		attributes["group"] = _attr_group_edit.text.strip_edges()
	var range_text: String = _attr_range_edit.text.strip_edges()
	if not range_text.is_empty():
		var range_parts: PackedStringArray = range_text.split(",", false)
		if range_parts.size() != 3 or not (type_name == "int" or type_name == "float"):
			if _default_help != null:
				_default_help.visible = true
				_default_help.text = "✗ Range needs 'min, max, step' on an int/float variable."
			if _dialog.is_inside_tree():
				_dialog.call_deferred("popup_centered", Vector2i(440, 260))
			return
		attributes["range"] = {"min": range_parts[0].strip_edges(), "max": range_parts[1].strip_edges(), "step": range_parts[2].strip_edges()}
	if _attr_multiline_check.button_pressed and type_name == "String":
		attributes["multiline"] = true
	for conditional in [["show_if", _attr_show_if_edit], ["lock_unless", _attr_lock_unless_edit], ["on_changed", _attr_on_changed_edit]]:
		var conditional_value: String = (conditional[1] as LineEdit).text.strip_edges()
		if conditional_value.is_empty():
			continue
		if not EventSheetIdentifierRules.is_valid(conditional_value):
			if _default_help != null:
				_default_help.visible = true
				_default_help.text = "✗ %s must be a single identifier (a variable/function name)." % str(conditional[0]).capitalize()
			if _dialog.is_inside_tree():
				_dialog.call_deferred("popup_centered", Vector2i(440, 260))
			return
		attributes[conditional[0]] = conditional_value
	if _attr_clamp_check.button_pressed:
		if not attributes.has("range"):
			if _default_help != null:
				_default_help.visible = true
				_default_help.text = "✗ Clamp needs a Range (min, max, step) to clamp to."
			if _dialog.is_inside_tree():
				_dialog.call_deferred("popup_centered", Vector2i(440, 260))
			return
		attributes["clamp"] = true
	if _attr_read_only_check.button_pressed:
		attributes["read_only"] = true
	if _attr_drawer_option.selected == 1:
		if not (type_name == "int" or type_name == "float"):
			if _default_help != null:
				_default_help.visible = true
				_default_help.text = "✗ The progress-bar drawer needs an int/float variable."
			if _dialog.is_inside_tree():
				_dialog.call_deferred("popup_centered", Vector2i(440, 260))
			return
		attributes["drawer"] = "progress_bar"
	variable_confirmed.emit(var_name, type_name, default_value, _scope, _context.duplicate(true), is_constant, exported, combo_options, attributes)

## Returns the trimmed text from the name field.
func get_last_name_text() -> String:
	if _name_edit == null:
		return ""
	return _name_edit.text.strip_edges()

## Parses the comma-separated combo options text ("a, b, c").
static func parse_options(raw: String) -> PackedStringArray:
	var options: PackedStringArray = PackedStringArray()
	for entry: String in raw.split(","):
		if not entry.strip_edges().is_empty():
			options.append(entry.strip_edges())
	return options

static func _parse_default(type_name: String, raw: String) -> Variant:
	var value: String = raw.strip_edges()
	if is_collection_type(type_name):
		if value.is_empty():
			return {} if type_name.begins_with("Dictionary") else []
		var parsed: Variant = str_to_var(value)
		if parsed is Array or parsed is Dictionary:
			return parsed
		return {} if type_name.begins_with("Dictionary") else []
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

static func is_collection_type(type_name: String) -> bool:
	return type_name.begins_with("Array") or type_name.begins_with("Dictionary")

## Validates a default-value text against the chosen type ({ok, error}). Collections must
## be GDScript literals of the right container kind; typed containers (Array[T] /
## Dictionary[K, V]) also check element types when T is a builtin scalar.
static func validate_default(type_name: String, raw: String) -> Dictionary:
	var value: String = raw.strip_edges()
	if not is_collection_type(type_name) or value.is_empty():
		return {"ok": true, "error": ""}
	var parsed: Variant = str_to_var(value)
	var wants_dictionary: bool = type_name.begins_with("Dictionary")
	if parsed == null or (wants_dictionary and not (parsed is Dictionary)) or (not wants_dictionary and not (parsed is Array)):
		return {"ok": false, "error": "Not a valid %s literal — e.g. %s" % [
			"Dictionary" if wants_dictionary else "Array",
			"{\"key\": 1}" if wants_dictionary else "[1, 2, 3]"
		]}
	var element_type: String = ""
	if type_name.contains("[") and type_name.ends_with("]"):
		var inner: String = type_name.get_slice("[", 1).trim_suffix("]")
		element_type = inner.get_slice(",", 1).strip_edges() if wants_dictionary else inner.strip_edges()
	var scalar_checks: Dictionary = {"int": TYPE_INT, "float": TYPE_FLOAT, "String": TYPE_STRING, "bool": TYPE_BOOL}
	if scalar_checks.has(element_type):
		var expected_type: int = int(scalar_checks[element_type])
		var values: Array = (parsed as Dictionary).values() if wants_dictionary else (parsed as Array)
		for element: Variant in values:
			# int literals are valid floats in GDScript.
			if typeof(element) == TYPE_INT and expected_type == TYPE_FLOAT:
				continue
			if typeof(element) != expected_type:
				return {"ok": false, "error": "Element %s is not %s (declared %s)." % [str(element), element_type, type_name]}
	return {"ok": true, "error": ""}

## Live ✓/✗ hint under the default field while typing collection literals.
## Show fields only when they can apply (user call: don't throw everything at once):
## combo options are String-only, range/clamp/drawer are numeric, multiline is String.
func _refresh_contextual_rows() -> void:
	if _type_option == null or _options_row == null:
		return
	var type_name: String = _type_option.get_item_text(maxi(_type_option.selected, 0))
	var numeric: bool = type_name in ["int", "float"]
	_options_row.visible = type_name == "String"
	_enum_fill_menu.visible = _options_row.visible and _enum_provider.is_valid() and not (_enum_provider.call() as Array).is_empty()
	if _attr_range_edit != null:
		_attr_range_edit.visible = numeric
		_attr_clamp_check.visible = numeric
		_attr_drawer_option.visible = numeric
		_attr_multiline_check.visible = type_name == "String"

## Wires the sheet-enum source for the one-click combo fill (returns
## Array[Dictionary{name, members}]).
func set_enum_provider(provider: Callable) -> void:
	_enum_provider = provider

func _populate_enum_fill_menu() -> void:
	var popup: PopupMenu = _enum_fill_menu.get_popup()
	popup.clear()
	if not _enum_provider.is_valid():
		return
	for entry: Variant in (_enum_provider.call() as Array):
		if not (entry is Dictionary):
			continue
		var members: PackedStringArray = PackedStringArray()
		for member: Variant in (entry as Dictionary).get("members", []):
			# Members may carry explicit values ("HURT = 4") — the combo wants names.
			members.append(str(member).get_slice("=", 0).strip_edges())
		popup.add_item(str((entry as Dictionary).get("name", "")))
		popup.set_item_metadata(popup.item_count - 1, ", ".join(members))

func _refresh_default_hint() -> void:
	if _default_help == null or _type_option == null or _default_edit == null:
		return
	var type_name: String = _type_option.get_item_text(_type_option.selected)
	if not is_collection_type(type_name):
		_default_help.visible = false
		_default_edit.placeholder_text = "0"
		return
	_default_edit.placeholder_text = "{\"key\": 1}" if type_name.begins_with("Dictionary") else "[1, 2, 3]"
	if _default_edit.text.strip_edges().is_empty():
		_default_help.visible = false
		return
	var verdict: Dictionary = validate_default(type_name, _default_edit.text)
	_default_help.visible = true
	_default_help.text = "✓ literal OK" if bool(verdict.get("ok", false)) else "✗ %s" % str(verdict.get("error", ""))

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
