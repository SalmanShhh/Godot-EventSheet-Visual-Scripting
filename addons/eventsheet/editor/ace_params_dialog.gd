# EventSheet — ACE Parameters dialog component
# Builds a dynamic form from ACEDefinition.parameters metadata and emits params_confirmed
# when the user confirms. Supports:
#  - left-label / right-control rows with the parameter description rendered below,
#  - variable-reference params (hint == "variable_reference"): a dropdown of the sheet's
#    variables; when none exist the dialog blocks apply and tells the user to add one,
#  - expression params (hint == "expression"): an inline "fx" button opening an Insert
#    Expression picker (EXPRESSION ACE definitions) whose code template is inserted,
#  - a "Back" button (when opened from the picker) that returns to the picker.
@tool
class_name ACEParamsDialog
extends RefCounted

## Emitted when the user confirms the parameter form.
## values is a Dictionary of { param_id -> typed_value }.
signal params_confirmed(definition: ACEDefinition, values: Dictionary, context: Dictionary)
## Emitted when the user presses Back to return to the picker.
signal back_requested(definition: ACEDefinition, context: Dictionary)

const VARIABLE_REFERENCE_HINT := "variable_reference"
const EXPRESSION_HINT := "expression"
const NO_VARIABLES_PLACEHOLDER := "No variables available"
const BACK_ACTION := "back"

var _dialog: ConfirmationDialog = null
var _form: VBoxContainer = null
var _hint: Label = null
var _fields: Dictionary = {}
var _field_hints: Dictionary = {}
var _definition: ACEDefinition = null
var _context: Dictionary = {}
var _registry: EventSheetACERegistry = null
var _variable_names_provider: Callable = Callable()
var _variable_names: PackedStringArray = PackedStringArray()
var _apply_blocked: bool = false
var _back_button: Button = null

# Sheet-context source for live ƒx validation (set by the dock; returns the active sheet).
var _lint_context_provider: Callable = Callable()

# Insert Expression picker (lazy).
var _expression_window: Window = null
var _expression_tree: Tree = null
var _expression_search: LineEdit = null
var _expression_target_key: String = ""

## Initialise and attach the dialog to parent_node. Must be called before open().
## registry powers the Insert Expression picker; variable_names_provider returns the
## current sheet variable names (Callable -> PackedStringArray/Array).
func init_dialog(parent_node: Node, registry: EventSheetACERegistry = null, variable_names_provider: Callable = Callable()) -> void:
	_registry = registry
	_variable_names_provider = variable_names_provider
	if _dialog != null:
		return
	_dialog = ConfirmationDialog.new()
	_dialog.title = "ACE Parameters"
	_dialog.visible = false
	_dialog.confirmed.connect(_on_confirmed)
	_dialog.close_requested.connect(_close)
	_dialog.canceled.connect(_close)
	_back_button = _dialog.add_button("◀ Back", true, BACK_ACTION)
	_dialog.custom_action.connect(_on_custom_action)
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
	_form.add_theme_constant_override("separation", 4)
	scroll.add_child(_form)

func set_registry(registry: EventSheetACERegistry) -> void:
	_registry = registry

## Open the parameter form for the given ACEDefinition.
func open(definition: ACEDefinition, context: Dictionary) -> void:
	open_with_values(definition, context, {})

func open_with_values(definition: ACEDefinition, context: Dictionary, initial_values: Dictionary) -> void:
	if _dialog == null:
		push_error("ACEParamsDialog.open() called before init_dialog().")
		return
	_definition = definition
	_context = context.duplicate(true)
	_variable_names = _resolve_variable_names()
	_build_form(definition, initial_values)
	_dialog.title = "%s Parameters%s" % [
		definition.display_name,
		" (Edit)" if _is_reedit_flow() else ""
	]
	_dialog.get_ok_button().disabled = _apply_blocked
	# Back only makes sense when this dialog was opened from the picker flow.
	_set_back_visible(_came_from_picker())
	_dialog.popup_centered(Vector2i(560, 380))
	_dialog.call_deferred("grab_focus")
	call_deferred("_focus_first_field")

## Rebuilds the parameter rows. Separated from open() so it can be exercised without
## popping the window (which requires a display server).
func _build_form(definition: ACEDefinition, initial_values: Dictionary) -> void:
	_fields.clear()
	_field_hints.clear()
	_apply_blocked = false
	for child in _form.get_children():
		_form.remove_child(child)
		child.queue_free()
	_hint = Label.new()
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.add_theme_color_override("font_color", Color(0.80, 0.85, 0.95, 0.95))
	_form.add_child(_hint)

	for parameter: Variant in definition.parameters:
		if not (parameter is Dictionary):
			continue
		_add_param_row(parameter as Dictionary, initial_values)

	_hint.text = _build_hint_text()

func _add_param_row(param_dict: Dictionary, initial_values: Dictionary) -> void:
	var key: String = str(param_dict.get("id", ""))
	var hint: String = str(param_dict.get("hint", ""))
	_field_hints[key] = hint

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var label: Label = Label.new()
	label.text = str(param_dict.get("display_name", key))
	label.custom_minimum_size = Vector2(160.0, 0.0)
	row.add_child(label)
	var field: Control = _create_field(param_dict, initial_values, key, hint)
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(field)
	_form.add_child(row)

	# Parameter description rendered below its control.
	var description: String = str(param_dict.get("description", ""))
	if not description.is_empty():
		var description_label: Label = Label.new()
		description_label.text = description
		description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description_label.add_theme_font_size_override("font_size", 11)
		description_label.add_theme_color_override("font_color", Color(0.66, 0.70, 0.78, 0.9))
		_form.add_child(description_label)

## Build a typed input widget for one parameter entry. The value-extraction node is
## registered in _fields[key]; the returned Control is what gets added to the row.
func _create_field(param_dict: Dictionary, initial_values: Dictionary, key: String, hint: String) -> Control:
	var field_type: int = int(param_dict.get("type", TYPE_NIL))
	var default_value: Variant = initial_values.get(key, param_dict.get("default_value", ""))
	var options: Array = param_dict.get("options", [])

	if hint == VARIABLE_REFERENCE_HINT or hint.begins_with(VARIABLE_REFERENCE_HINT + ":"):
		return _create_variable_reference_field(key, default_value, hint)
	if hint == "signal_reference" or hint.begins_with("signal_reference:"):
		return _create_signal_reference_field(key, default_value, hint.ends_with(":quoted"))
	if hint == EXPRESSION_HINT:
		return _create_expression_field(key, default_value)
	if options is Array and not options.is_empty():
		return _create_options_field(key, options, default_value)
	if field_type == TYPE_BOOL:
		var check: CheckBox = CheckBox.new()
		check.button_pressed = _parse_bool(default_value)
		_fields[key] = check
		return check
	if field_type in [TYPE_INT, TYPE_FLOAT]:
		var spin: SpinBox = SpinBox.new()
		spin.step = 1.0 if field_type == TYPE_INT else 0.1
		spin.allow_greater = true
		spin.allow_lesser = true
		spin.value = float(default_value)
		_fields[key] = spin
		return spin
	var edit: LineEdit = LineEdit.new()
	edit.text = str(default_value)
	_fields[key] = edit
	return edit

func _create_options_field(key: String, options: Array, default_value: Variant) -> OptionButton:
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
	_fields[key] = dropdown
	return dropdown

## hint may carry a required base type ("variable_reference:Array") — the dropdown then
## offers only variables of that container type (Variant/untyped always qualify).
func _create_variable_reference_field(key: String, default_value: Variant, hint: String = VARIABLE_REFERENCE_HINT) -> Control:
	var required_type: String = hint.get_slice(":", 1) if hint.contains(":") else ""
	var offered_names: Array = []
	for candidate_name in _variable_names:
		if required_type.is_empty() or _variable_matches_type(str(candidate_name), required_type):
			offered_names.append(candidate_name)
	if offered_names.is_empty():
		# No (matching) variables exist: surface a disabled placeholder and block apply.
		_apply_blocked = true
		var placeholder: LineEdit = LineEdit.new()
		placeholder.text = NO_VARIABLES_PLACEHOLDER if required_type.is_empty() else "No %s variables — add one first" % required_type
		placeholder.editable = false
		_fields[key] = placeholder
		return placeholder
	var dropdown: OptionButton = OptionButton.new()
	for variable_name in offered_names:
		dropdown.add_item(variable_name)
		var index: int = dropdown.item_count - 1
		dropdown.set_item_metadata(index, variable_name)
		if variable_name == str(default_value):
			dropdown.select(index)
	if dropdown.selected < 0 and dropdown.item_count > 0:
		dropdown.select(0)
	_fields[key] = dropdown
	return dropdown

## True when the sheet variable's declared type starts with `required` (so "Array" also
## matches "Array[int]"); untyped/Variant variables always qualify.
func _variable_matches_type(variable_name: String, required: String) -> bool:
	var sheet: EventSheetResource = (_lint_context_provider.call() as EventSheetResource) if _lint_context_provider.is_valid() else null
	if sheet == null:
		return true
	var type_name: String = ""
	if sheet.variables.has(variable_name):
		type_name = str((sheet.variables[variable_name] as Dictionary).get("type", ""))
	for entry in sheet.events:
		if entry is LocalVariable and (entry as LocalVariable).name == variable_name:
			type_name = (entry as LocalVariable).type_name
	if type_name.is_empty() or type_name == "Variant":
		return true
	return type_name.begins_with(required)

## C3-style object-signal picker: a dropdown of the host class's signals plus signals
## declared in the sheet's GDScript blocks (raw names — OnSignal connects them directly).
## The current value is always offered (custom names persist).
## quoted=true stores values as "name" string literals (Emit Signal's template wraps
## them in &{...}); false stores raw names (On Signal connects them directly).
func _create_signal_reference_field(key: String, default_value: Variant, quoted: bool = false) -> Control:
	var options: Array[String] = _signal_options()
	var current: String = str(default_value).strip_edges()
	if quoted:
		current = current.trim_prefix("\"").trim_suffix("\"")
	if not current.is_empty() and not options.has(current):
		options.insert(0, current)
	if options.is_empty():
		var fallback: LineEdit = LineEdit.new()
		fallback.text = current
		fallback.placeholder_text = "signal name"
		_fields[key] = fallback
		return fallback
	var dropdown: OptionButton = OptionButton.new()
	for signal_name in options:
		dropdown.add_item(signal_name)
		var index: int = dropdown.item_count - 1
		dropdown.set_item_metadata(index, "\"%s\"" % signal_name if quoted else signal_name)
		if signal_name == current:
			dropdown.select(index)
	if dropdown.selected < 0 and dropdown.item_count > 0:
		dropdown.select(0)
	_fields[key] = dropdown
	return dropdown

## Host-class signals (ClassDB) + `signal x` declarations in the sheet's class-level
## GDScript blocks, sorted and deduplicated.
func _signal_options() -> Array[String]:
	var names: Array[String] = []
	var sheet: EventSheetResource = (_lint_context_provider.call() as EventSheetResource) if _lint_context_provider.is_valid() else null
	if sheet == null:
		return names
	for entry in sheet.events:
		if entry is RawCodeRow:
			for line in (entry as RawCodeRow).code.split("\n"):
				if line.begins_with("signal "):
					var declared: String = line.trim_prefix("signal ").strip_edges()
					declared = declared.get_slice("(", 0).strip_edges()
					if not declared.is_empty() and not names.has(declared):
						names.append(declared)
	if ClassDB.class_exists(sheet.host_class):
		for signal_info in ClassDB.class_get_signal_list(sheet.host_class):
			var signal_name: String = str(signal_info.get("name", ""))
			if not signal_name.is_empty() and not names.has(signal_name):
				names.append(signal_name)
	names.sort()
	return names

func _create_expression_field(key: String, default_value: Variant) -> Control:
	var container: HBoxContainer = HBoxContainer.new()
	container.add_theme_constant_override("separation", 4)
	# A single-line CodeEdit instead of a LineEdit: same look, but with completion popups
	# for sheet variables/functions and host members (Ctrl+Space or just typing).
	var edit: CodeEdit = CodeEdit.new()
	edit.text = str(default_value)
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.custom_minimum_size = Vector2(0.0, 31.0)
	edit.scroll_fit_content_height = true
	edit.gutters_draw_line_numbers = false
	edit.code_completion_enabled = true
	# Expressions are plain GDScript — say so explicitly so C3 users learn there is no
	# separate expression language to memorize.
	edit.placeholder_text = "GDScript expression (e.g. health + 10)"
	edit.tooltip_text = "Plain GDScript — anything valid in an expression works here. Ctrl+Space completes sheet variables/functions and host members."
	edit.text_changed.connect(func() -> void:
		# Keep it single-line (Enter confirms the dialog instead of inserting a newline).
		if edit.text.contains("
"):
			var caret: int = edit.get_caret_column()
			edit.text = edit.text.replace("
", " ")
			edit.set_caret_column(mini(caret, edit.text.length()))
		_validate_expression_field(edit)
		edit.request_code_completion()
	)
	edit.code_completion_requested.connect(func() -> void: _populate_expression_completion(edit))
	_validate_expression_field(edit)
	container.add_child(edit)
	var fx_button: Button = Button.new()
	fx_button.text = "ƒx"
	fx_button.tooltip_text = "Insert a GDScript expression"
	fx_button.pressed.connect(_open_expression_picker.bind(key))
	container.add_child(fx_button)
	_fields[key] = edit
	return container

## Live expression validation: compile-checks the field against the sheet context
## (variables, host members) and tints the text red when it would not compile. The lint
## context provider is optional — without it the field stays unvalidated.
func _validate_expression_field(edit: Control) -> void:
	if not _lint_context_provider.is_valid():
		return
	var sheet: EventSheetResource = _lint_context_provider.call() as EventSheetResource
	var lint_result: Dictionary = EventSheetGDScriptLint.lint_expression(str(edit.get("text")), sheet)
	if bool(lint_result.get("ok", true)):
		edit.remove_theme_color_override("font_color")
		edit.tooltip_text = "Plain GDScript — anything valid in an expression works here."
	else:
		edit.add_theme_color_override("font_color", Color(0.96, 0.45, 0.45))
		edit.tooltip_text = "✗ Not a valid GDScript expression for this sheet."

## Wires the sheet-context source for expression validation (returns EventSheetResource).
func set_lint_context_provider(provider: Callable) -> void:
	_lint_context_provider = provider

## Fills the completion popup with sheet variables/functions + host members (same source
## as the GDScript-block editor, so the vocabulary matches everywhere).
func _populate_expression_completion(edit: CodeEdit) -> void:
	if not _lint_context_provider.is_valid():
		return
	var sheet: EventSheetResource = _lint_context_provider.call() as EventSheetResource
	var before_caret: String = edit.get_line(edit.get_caret_line()).substr(0, edit.get_caret_column())
	# Context-aware: `host.` / typed-variable. / $Behavior. offer that type's members.
	for candidate: Dictionary in EventSheetGDScriptLint.completion_for_context(before_caret, sheet):
		edit.add_code_completion_option(
			int(candidate.get("kind", CodeEdit.KIND_PLAIN_TEXT)),
			str(candidate.get("label", "")),
			str(candidate.get("label", ""))
		)
	edit.update_code_completion_options(true)
	edit.set_code_hint(EventSheetGDScriptLint.signature_hint(before_caret, sheet))

## Extract the typed value from a registered field node.
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
	if field is CodeEdit:
		# Expression fields are single-line CodeEdits (for completion); strip any newline
		# completion may sneak in.
		return (field as CodeEdit).text.replace("
", " ").strip_edges()
	return ""

## First expression field whose text fails the compile-check (null = all valid). The
## commit guardrail: invalid GDScript never reaches the sheet.
func _first_invalid_expression() -> Control:
	if not _lint_context_provider.is_valid():
		return null
	var sheet: EventSheetResource = _lint_context_provider.call() as EventSheetResource
	for key: Variant in _fields.keys():
		var field: Control = _fields[key]
		if field is CodeEdit and not bool(EventSheetGDScriptLint.lint_expression(str(field.get("text")), sheet).get("ok", true)):
			return field
	return null

func _on_confirmed() -> void:
	if _definition == null or _apply_blocked:
		return
	# Guardrail (C3-style): block the commit while any expression doesn't compile.
	var invalid_field: Control = _first_invalid_expression()
	if invalid_field != null:
		if _hint != null:
			_hint.text = "✗ An expression doesn't compile — fix it before applying."
		invalid_field.grab_focus()
		if _dialog != null and is_instance_valid(_dialog) and _dialog.is_inside_tree():
			_dialog.call_deferred("popup_centered", Vector2i(520, 380))
		return
	var values: Dictionary = {}
	for key: Variant in _fields.keys():
		values[str(key)] = _extract_value(_fields[key])
	params_confirmed.emit(_definition, values, _context.duplicate(true))
	_definition = null
	_context.clear()

func _on_custom_action(action: StringName) -> void:
	if str(action) != BACK_ACTION:
		return
	var definition: ACEDefinition = _definition
	var context: Dictionary = _context.duplicate(true)
	_close()
	back_requested.emit(definition, context)

func _set_back_visible(visible: bool) -> void:
	if _back_button != null:
		_back_button.visible = visible

# ── Insert Expression picker ────────────────────────────────────────────────

func _open_expression_picker(target_key: String) -> void:
	_expression_target_key = target_key
	_ensure_expression_window()
	_refresh_expression_tree()
	_expression_window.popup_centered(Vector2i(560, 460))
	_expression_search.grab_focus()

func _ensure_expression_window() -> void:
	if _expression_window != null:
		return
	_expression_window = Window.new()
	_expression_window.title = "Insert Expression"
	_expression_window.visible = false
	_expression_window.min_size = Vector2i(480, 360)
	_expression_window.close_requested.connect(func() -> void: _expression_window.hide())
	_dialog.add_child(_expression_window)

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	_expression_window.add_child(margin)

	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	margin.add_child(content)

	_expression_search = LineEdit.new()
	_expression_search.placeholder_text = "Search expressions..."
	_expression_search.clear_button_enabled = true
	_expression_search.text_changed.connect(func(_text: String) -> void: _refresh_expression_tree())
	content.add_child(_expression_search)

	_expression_tree = Tree.new()
	_expression_tree.hide_root = true
	_expression_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_expression_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_expression_tree.item_activated.connect(_on_expression_activated)
	content.add_child(_expression_tree)

func _refresh_expression_tree() -> void:
	if _expression_tree == null or _registry == null:
		return
	_expression_tree.clear()
	var root: TreeItem = _expression_tree.create_item()
	var query: String = _expression_search.text.strip_edges()
	var group_nodes: Dictionary = {}
	for definition: ACEDefinition in _registry.search(query):
		if definition.ace_type != ACEDefinition.ACEType.EXPRESSION:
			continue
		var node_type: String = str(definition.metadata.get("node_type", "")).strip_edges()
		var group_key: String = node_type if not node_type.is_empty() else (definition.category if not definition.category.is_empty() else "General")
		if not group_nodes.has(group_key):
			var group_item: TreeItem = _expression_tree.create_item(root)
			group_item.set_text(0, group_key)
			group_item.set_custom_color(0, ACEPickerDialog.GROUP_COLOR_NODE_TYPE if not node_type.is_empty() else ACEPickerDialog.GROUP_COLOR_NEUTRAL)
			group_item.set_selectable(0, false)
			group_nodes[group_key] = group_item
		var item: TreeItem = _expression_tree.create_item(group_nodes[group_key])
		item.set_text(0, definition.display_name)
		item.set_custom_color(0, ACEPickerDialog.ITEM_COLOR_EXPRESSION)
		if not definition.description.is_empty():
			item.set_tooltip_text(0, definition.description)
		item.set_metadata(0, definition)

func _on_expression_activated() -> void:
	var item: TreeItem = _expression_tree.get_selected()
	if item == null:
		return
	var definition: ACEDefinition = item.get_metadata(0)
	if definition == null:
		return
	var target: Control = _fields.get(_expression_target_key, null)
	if target is LineEdit:
		var line_edit: LineEdit = target as LineEdit
		line_edit.text = _expression_template(definition)
		line_edit.grab_focus()
		line_edit.caret_column = line_edit.text.length()
	_expression_window.hide()

## Returns the code template inserted for an expression definition (with default params).
func _expression_template(definition: ACEDefinition) -> String:
	var template: String = str(definition.metadata.get("codegen_template", ""))
	if template.is_empty():
		var display: String = definition.format_display({})
		return display if not display.is_empty() else definition.display_name
	# Substitute default parameter values into the codegen template placeholders.
	for index in range(definition.parameters.size()):
		var parameter: Variant = definition.parameters[index]
		if not (parameter is Dictionary):
			continue
		var param_dict: Dictionary = parameter as Dictionary
		var param_key: String = str(param_dict.get("id", ""))
		if param_key.is_empty():
			continue
		var param_value: String = str(param_dict.get("default_value", param_dict.get("default", "")))
		template = template.replace("{%d}" % index, param_value)
		template = template.replace("{%s}" % param_key, param_value)
	return template

# ── Helpers ─────────────────────────────────────────────────────────────────

func _resolve_variable_names() -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	if not _variable_names_provider.is_valid():
		return names
	var result: Variant = _variable_names_provider.call()
	if result is PackedStringArray:
		return result
	if result is Array:
		for entry in result:
			names.append(str(entry))
	return names

func _came_from_picker() -> bool:
	# The dock sets from_picker when this dialog is opened from a picker selection;
	# direct row edits (double-click an ACE) open it without a picker to return to.
	return bool(_context.get("from_picker", false))

func _close() -> void:
	if _dialog != null:
		_dialog.hide()

func _is_reedit_flow() -> bool:
	var mode: String = str(_context.get("mode", ""))
	return mode.begins_with("replace")

func _build_hint_text() -> String:
	if _apply_blocked:
		return "This ACE references a sheet variable, but none exist yet. Add a variable to the sheet first, then add this ACE."
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
		if field != null and field.visible and not (field is LineEdit and not (field as LineEdit).editable):
			field.grab_focus()
			return

static func _parse_bool(value: Variant) -> bool:
	return str(value).to_lower() in ["true", "1", "yes"]
