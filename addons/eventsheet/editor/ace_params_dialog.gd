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
const ADD_ANOTHER_ACTION := "add_another"

## Session memory of the last-applied values per ace id, so re-adding the same ACE
## prefills what you used last time instead of the bare descriptor default (Tier-1
## tedium cut: the values you type repeatedly stop being re-typed). Static = shared
## across dialog instances; cleared only on editor restart.
static var _remembered_values: Dictionary = {}

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
var _add_another_button: Button = null

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
	_dialog.title = "Parameters"
	_dialog.visible = false
	_dialog.confirmed.connect(_on_confirmed)
	_dialog.close_requested.connect(_close)
	_dialog.visibility_changed.connect(func() -> void:
		if not _dialog.visible:
			_stop_audio_preview()
	)
	_dialog.canceled.connect(_close)
	_back_button = _dialog.add_button("◀ Back", true, BACK_ACTION)
	# "Apply & Add Another" keeps the picker loop going for repeated authoring
	# (add three conditions without re-opening the picker each time). Only shown in
	# append modes, where the target event is stable.
	_add_another_button = _dialog.add_button("✚ Apply & Add Another", false, ADD_ANOTHER_ACTION)
	_dialog.custom_action.connect(_on_custom_action)
	parent_node.add_child(_dialog)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.custom_minimum_size = Vector2(520.0, 260.0)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Fields fit the dialog width instead of growing a horizontal scrollbar (long
	# enum defaults like DisplayServer.WINDOW_MODE_FULLSCREEN used to overflow).
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
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
	# Fresh add (no existing params, not a re-edit) prefills from session memory of
	# the last values used for this ACE.
	var form_values: Dictionary = initial_values
	if initial_values.is_empty() and not _is_reedit_flow() and _remembered_values.has(definition.id):
		form_values = (_remembered_values[definition.id] as Dictionary).duplicate(true)
	_build_form(definition, form_values)
	_dialog.title = "%s Parameters%s" % [
		definition.display_name,
		" (Edit)" if _is_reedit_flow() else ""
	]
	_dialog.get_ok_button().disabled = _apply_blocked
	# Back returns to the picker — from the add flow OR a row edit (which opens in a replace_* mode),
	# so editing any ACE (action/expression too, not just conditions) can go back and swap.
	_set_back_visible(_can_return_to_picker())
	if _add_another_button != null:
		_add_another_button.visible = str(_context.get("mode", "")) in ["append_condition", "append_action"]
	_dialog.popup_centered(Vector2i(560, 380))
	_dialog.call_deferred("grab_focus")
	call_deferred("_focus_first_field")

## Rebuilds the parameter rows. Separated from open() so it can be exercised without
## popping the window (which requires a display server).
var _single_param_form: bool = false

func _build_form(definition: ACEDefinition, initial_values: Dictionary) -> void:
	_fields.clear()
	_field_hints.clear()
	_apply_blocked = false
	_single_param_form = definition.parameters.size() == 1
	for child in _form.get_children():
		_form.remove_child(child)
		child.queue_free()
	_hint = Label.new()
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.add_theme_color_override("font_color", Color(0.80, 0.85, 0.95, 0.95))
	_form.add_child(_hint)
	# Native-node ACEs link to the engine's own class reference — the vocabulary IS
	# Godot, and the built-in docs are one click away.
	var docs_class: String = str(definition.metadata.get("node_type", "")).strip_edges()
	if not docs_class.is_empty() and ClassDB.class_exists(docs_class):
		var docs_button: Button = Button.new()
		docs_button.text = "View %s in Godot Docs" % docs_class
		docs_button.flat = true
		docs_button.tooltip_text = "Open the built-in class reference for %s." % docs_class
		docs_button.pressed.connect(func() -> void: open_class_docs(docs_class))
		_form.add_child(docs_button)

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
	# Hover the label OR the field for the parameter's purpose (descriptions also
	# render below, but tooltips answer "what is this?" without scanning down).
	var hover_text: String = str(param_dict.get("description", ""))
	if not hover_text.is_empty():
		label.tooltip_text = hover_text
		field.tooltip_text = hover_text
	# Dropdowns clip long entries instead of forcing the dialog wider.
	if field is OptionButton:
		(field as OptionButton).clip_text = true
		(field as OptionButton).custom_minimum_size = Vector2(220.0, 0.0)

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
var _hint_factories: Dictionary = {}

func _ensure_hint_factories() -> void:
	if _hint_factories.is_empty():
		_hint_factories = {
			"key_capture": _create_key_capture_field,
			"audio_path": _create_audio_path_field,
			"scene_path": _create_scene_path_field,
			"animation_reference": _create_animation_field,
			"method_reference": _create_method_reference_field,
			"property_reference": _create_property_reference_field,
		}

func _create_field(param_dict: Dictionary, initial_values: Dictionary, key: String, hint: String) -> Control:
	var field_type: int = int(param_dict.get("type", TYPE_NIL))
	var default_value: Variant = initial_values.get(key, param_dict.get("default_value", ""))
	var options: Array = param_dict.get("options", [])
	var autocomplete: Array = param_dict.get("autocomplete", [])

	# A lone Vector2/Vector3 param (positions, sizes…) splits into per-axis fields —
	# each axis is still a full GDScript expression (user call: "when setting
	# positions, split it into 2-3 params").
	if _single_param_form and hint in ["", EXPRESSION_HINT]:
		var vector_parts: PackedStringArray = vector_literal_parts(str(default_value))
		if not vector_parts.is_empty():
			return _create_vector_field(key, vector_parts)
	if hint == VARIABLE_REFERENCE_HINT or hint.begins_with(VARIABLE_REFERENCE_HINT + ":"):
		return _create_variable_reference_field(key, default_value, hint)
	if hint == "signal_reference" or hint.begins_with("signal_reference:"):
		return _create_signal_reference_field(key, default_value, hint.ends_with(":quoted"))
	if hint.begins_with("enum:"):
		return _create_enum_reference_field(key, default_value, hint.get_slice(":", 1))
	# Exact-match field hints dispatch through the registry — adding the next hint is
	# one registration line, not another branch (prefix hints stay above: they carry
	# arguments after ':').
	_ensure_hint_factories()
	if _hint_factories.has(hint):
		return (_hint_factories[hint] as Callable).call(key, default_value)
	if hint == "color" or field_type == TYPE_COLOR:
		return _create_color_field(key, default_value)
	if hint == EXPRESSION_HINT:
		return _create_expression_field(key, default_value)
	# Editable autocomplete combo (Construct-style): type any value, or filter/pick from
	# the behavior-declared suggestions. Takes priority over a fixed dropdown.
	if autocomplete is Array and not autocomplete.is_empty():
		return _create_autocomplete_field(key, autocomplete, default_value)
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
	# Keyboard flow: Enter in any plain field presses OK (type, Enter, done).
	if _dialog is AcceptDialog:
		(_dialog as AcceptDialog).register_text_enter(edit)
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

## Editable autocomplete combo (Construct-style "Combo" with free text): a LineEdit the
## user types into, plus a ▾ button whose popup lists the behavior-declared suggestions
## filtered by what's already typed. Picking inserts a suggestion verbatim; typing any
## other value is still allowed. The LineEdit IS the value-bearing field (read like text).
func _create_autocomplete_field(key: String, suggestions: Array, default_value: Variant) -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var edit: LineEdit = LineEdit.new()
	edit.text = str(default_value)
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.placeholder_text = "type or pick…"
	# Enter still presses OK (keyboard flow stays identical to a plain field).
	if _dialog is AcceptDialog:
		(_dialog as AcceptDialog).register_text_enter(edit)
	row.add_child(edit)

	var suggestion_texts: PackedStringArray = PackedStringArray()
	for suggestion: Variant in suggestions:
		var suggestion_text: String = str(suggestion).strip_edges()
		if not suggestion_text.is_empty() and not suggestion_texts.has(suggestion_text):
			suggestion_texts.append(suggestion_text)

	var picker: MenuButton = MenuButton.new()
	picker.text = "▾"
	picker.tooltip_text = "Suggestions (you can still type any value)"
	var popup: PopupMenu = picker.get_popup()
	# Rebuild the (filtered) list each time it opens so what's typed narrows the choices.
	popup.about_to_popup.connect(func() -> void:
		_rebuild_autocomplete_popup(popup, suggestion_texts, edit.text))
	# Whenever the suggestion popup closes (pick, Escape, click-away), return the caret to
	# the field so Enter still confirms the dialog and typing continues seamlessly.
	popup.popup_hide.connect(func() -> void: edit.grab_focus())
	popup.id_pressed.connect(func(picked_id: int) -> void:
		if picked_id >= 0 and picked_id < suggestion_texts.size():
			edit.text = suggestion_texts[picked_id]
			edit.caret_column = edit.text.length()
			edit.grab_focus())
	# Down-arrow from the field opens the suggestions (keyboard-first authoring).
	# accept_event() (a Control method) stops the key here — this dialog is a RefCounted
	# wrapper, so there is no get_viewport()/set_input_as_handled() to reach for.
	edit.gui_input.connect(func(event: InputEvent) -> void:
		var key_event: InputEventKey = event as InputEventKey
		if key_event != null and key_event.pressed and key_event.keycode == KEY_DOWN:
			_rebuild_autocomplete_popup(popup, suggestion_texts, edit.text)
			# Don't pop a dead, disabled-only "(no match)" menu — keep the caret in the field.
			if popup.item_count == 1 and popup.is_item_disabled(0):
				edit.accept_event()
				return
			popup.position = Vector2i(edit.get_screen_position() + Vector2(0.0, edit.size.y))
			popup.reset_size()
			popup.popup()
			edit.accept_event())
	row.add_child(picker)
	_fields[key] = edit
	return row

## Fills `popup` with the suggestions whose text contains `filter_text` (case-insensitive;
## empty filter shows all). Each item's id is its index into the FULL list, so a pick maps
## back correctly even when filtered. Pure enough to unit-test directly.
func _rebuild_autocomplete_popup(popup: PopupMenu, suggestions: PackedStringArray, filter_text: String) -> void:
	popup.clear()
	var needle: String = filter_text.strip_edges().to_lower()
	var any_added: bool = false
	for index: int in range(suggestions.size()):
		var suggestion: String = suggestions[index]
		if needle.is_empty() or suggestion.to_lower().contains(needle):
			popup.add_item(suggestion, index)
			any_added = true
	if not any_added:
		popup.add_item("(no match — keep typing)", -1)
		popup.set_item_disabled(popup.item_count - 1, true)

## hint may carry a required base type ("variable_reference:Array") — the dropdown then
## offers only variables of that container type (Variant/untyped always qualify).
## Reflection pickers for the Helper ACEs' method/property params: an editable suggest-combo
## of the sheet host class's members (reflected from ClassDB), so Call Method / Set Property
## become pick-don't-type. Editable, so an expert can still type a member reflection misses.
func _create_method_reference_field(key: String, default_value: Variant) -> Control:
	return _create_autocomplete_field(key, reflected_members(_host_class_for_context(), "method"), default_value)

func _create_property_reference_field(key: String, default_value: Variant) -> Control:
	return _create_autocomplete_field(key, reflected_members(_host_class_for_context(), "property"), default_value)

## The sheet's host class (or Node) — the default Call Method / Set Property target (`self`).
func _host_class_for_context() -> String:
	var sheet: EventSheetResource = (_lint_context_provider.call() as EventSheetResource) if _lint_context_provider.is_valid() else null
	return sheet.host_class if sheet != null and not sheet.host_class.strip_edges().is_empty() else "Node"

## Public method / property names declared on a class (reflected from ClassDB, sorted, no
## private `_`-prefixed members). Static + pure, so it is unit-testable without a dialog.
static func reflected_members(host_class: String, kind: String) -> Array:
	var names: Array = []
	if host_class.is_empty() or not ClassDB.class_exists(host_class):
		return names
	if kind == "property":
		for info: Dictionary in ClassDB.class_get_property_list(host_class):
			var member: String = str(info.get("name", ""))
			if not member.is_empty() and not member.begins_with("_") and not member.contains("/") and not names.has(member):
				names.append(member)
	else:
		for info: Dictionary in ClassDB.class_get_method_list(host_class):
			var member: String = str(info.get("name", ""))
			if not member.is_empty() and not member.begins_with("_") and not names.has(member):
				names.append(member)
	names.sort()
	return names

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
		dropdown.set_item_metadata(index, format_quoted_literal(signal_name) if quoted else signal_name)
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
		if entry is SignalRow and (entry as SignalRow).enabled:
			var row_signal: String = (entry as SignalRow).signal_name
			if not row_signal.is_empty() and not names.has(row_signal):
				names.append(row_signal)
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

## Sheet-enum-driven dropdown (hint "enum:State"): options are the enum's members as
## State.MEMBER values — the C3 Combo backed by a real enum.
func _create_enum_reference_field(key: String, default_value: Variant, enum_name: String) -> Control:
	var sheet: EventSheetResource = (_lint_context_provider.call() as EventSheetResource) if _lint_context_provider.is_valid() else null
	var member_options: Array = []
	if sheet != null:
		for entry in sheet.events:
			if entry is EnumRow and (entry as EnumRow).enum_name == enum_name and (entry as EnumRow).enabled:
				for member: String in (entry as EnumRow).members:
					var member_name: String = member.get_slice("=", 0).strip_edges()
					member_options.append({"key": "%s.%s" % [enum_name, member_name], "label": member_name})
	if member_options.is_empty():
		var fallback: LineEdit = LineEdit.new()
		fallback.text = str(default_value)
		fallback.placeholder_text = "%s.MEMBER (enum not found in this sheet)" % enum_name
		_fields[key] = fallback
		return fallback
	return _create_options_field(key, member_options, default_value)

## Color picker param (hint "color" or a Color-typed param). The value round-trips as a
## canonical Color(r, g, b, a) literal so the sheet can show a swatch next to the text.
func _create_color_field(key: String, default_value: Variant) -> Control:
	var picker: ColorPickerButton = ColorPickerButton.new()
	picker.custom_minimum_size = Vector2(72.0, 0.0)
	var parsed: Variant = str_to_var(str(default_value))
	picker.color = parsed if parsed is Color else Color.WHITE
	_fields[key] = picker
	return picker

func _can_drop_on_expression(_position: Vector2, data: Variant) -> bool:
	if not (data is Dictionary):
		return false
	var kind: String = str((data as Dictionary).get("type", ""))
	return kind == "files" or kind == "nodes"

func _drop_on_expression(_position: Vector2, data: Variant, edit: CodeEdit) -> void:
	var snippet: String = drop_data_to_expression(data)
	if not snippet.is_empty():
		edit.insert_text_at_caret(snippet)

## Converts an editor drag payload to GDScript: FileSystem files become quoted res://
## paths; Scene-dock nodes become $Path references (relative to the edited scene root).
static func drop_data_to_expression(data: Variant) -> String:
	if not (data is Dictionary):
		return ""
	var payload: Dictionary = data as Dictionary
	match str(payload.get("type", "")):
		"files":
			var files: Array = payload.get("files", [])
			return format_quoted_literal(str(files[0])) if not files.is_empty() else ""
		"nodes":
			var nodes: Array = payload.get("nodes", [])
			if nodes.is_empty():
				return ""
			var node_path: String = str(nodes[0])
			var relative: String = node_path.get_file()
			if Engine.is_editor_hint():
				var scene_root: Node = EditorInterface.get_edited_scene_root()
				if scene_root != null:
					var root_prefix: String = str(scene_root.get_path())
					if node_path.begins_with(root_prefix + "/"):
						relative = node_path.trim_prefix(root_prefix + "/")
			return _node_reference(relative)
	return ""

## $Name for identifier-safe paths, $"Path/To Node" otherwise.
static func _node_reference(relative_path: String) -> String:
	var identifier_regex: RegEx = RegEx.new()
	if identifier_regex.compile("^[A-Za-z_][A-Za-z0-9_]*$") == OK and identifier_regex.search(relative_path) != null:
		return "$%s" % relative_path
	return "$\"%s\"" % relative_path

## Audio params: a path field plus a ▶ button that previews the sound in the editor
## (loads the stream into a throwaway player under the dialog; ■ stops it).
## Shared scaffold for path-style fields (audio/scene/…): container + expanding
## LineEdit with FileSystem drag-drop, Enter-applies, and _fields registration.
## Returns {"container": HBoxContainer, "edit": LineEdit}; callers add their button.
func _build_path_field_base(key: String, default_value: Variant) -> Dictionary:
	var container: HBoxContainer = HBoxContainer.new()
	var path_edit: LineEdit = LineEdit.new()
	path_edit.text = str(default_value)
	path_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(path_edit)
	path_edit.set_drag_forwarding(Callable(), _can_drop_on_expression, _drop_on_line_edit.bind(path_edit))
	if _dialog is AcceptDialog:
		(_dialog as AcceptDialog).register_text_enter(path_edit)
	_fields[key] = path_edit
	return {"container": container, "edit": path_edit}

func _create_audio_path_field(key: String, default_value: Variant) -> Control:
	var base: Dictionary = _build_path_field_base(key, default_value)
	var container: HBoxContainer = base["container"]
	var path_edit: LineEdit = base["edit"]
	var preview: Button = Button.new()
	preview.text = "▶"
	preview.tooltip_text = "Preview this sound"
	preview.pressed.connect(func() -> void:
		if _preview_player != null and is_instance_valid(_preview_player):
			_preview_player.queue_free()
			_preview_player = null
			preview.text = "▶"
			return
		var resource_path: String = path_edit.text.strip_edges().trim_prefix("\"").trim_suffix("\"")
		var stream: Resource = load(resource_path) if ResourceLoader.exists(resource_path) else null
		if not (stream is AudioStream):
			preview.tooltip_text = "Not an audio file: %s" % resource_path
			return
		_preview_player = AudioStreamPlayer.new()
		_preview_player.stream = stream
		container.add_child(_preview_player)
		_preview_player.finished.connect(func() -> void:
			if _preview_player != null and is_instance_valid(_preview_player):
				_preview_player.queue_free()
				_preview_player = null
			preview.text = "▶"
		)
		_preview_player.play()
		preview.text = "■"
	)
	container.add_child(preview)
	return container

var _preview_player: AudioStreamPlayer = null

## Scene params: a path field plus a Browse… button (editor file dialog filtered to
## scenes); the chosen path inserts quoted, ready for load()/Spawn Scene At.
func _create_scene_path_field(key: String, default_value: Variant) -> Control:
	var base: Dictionary = _build_path_field_base(key, default_value)
	var container: HBoxContainer = base["container"]
	var path_edit: LineEdit = base["edit"]
	var browse: Button = Button.new()
	browse.text = "Browse…"
	browse.pressed.connect(func() -> void: _browse_for_scene(path_edit))
	container.add_child(browse)
	return container

# One cached scene browser, parented to the PERSISTENT params dialog: no per-press
# accumulation, and a form rebuild can't kill it mid-interaction. The target retargets
# per open via a single stored reference (old lambda connections would pile up).
var _scene_file_dialog: EditorFileDialog = null
var _scene_browse_target: LineEdit = null

func _browse_for_scene(path_edit: LineEdit) -> void:
	if not Engine.is_editor_hint():
		return
	if _scene_file_dialog == null:
		_scene_file_dialog = EditorFileDialog.new()
		_scene_file_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
		_scene_file_dialog.add_filter("*.tscn", "Scenes")
		_scene_file_dialog.add_filter("*.scn", "Scenes (binary)")
		_scene_file_dialog.file_selected.connect(func(selected_path: String) -> void:
			if _scene_browse_target != null and is_instance_valid(_scene_browse_target):
				_scene_browse_target.text = format_quoted_literal(selected_path)
		)
		_dialog.add_child(_scene_file_dialog)
	_scene_browse_target = path_edit
	_scene_file_dialog.popup_file_dialog()

## Drops onto plain LineEdit fields: files become quoted paths, nodes $Refs (reuses
## the expression-field converter so the two can never disagree).
func _drop_on_line_edit(_position: Vector2, data: Variant, edit: LineEdit) -> void:
	var snippet: String = drop_data_to_expression(data)
	if not snippet.is_empty() and is_instance_valid(edit):
		edit.text = snippet

## The single source of truth for "value as a GDScript string literal".
static func format_quoted_literal(value: String) -> String:
	return "\"%s\"" % value

## Animation params (C3's animation picker): a dropdown of every animation on every
## AnimationPlayer in the edited scene, plus a free-text fallback for names that only
## exist at runtime. Selections insert quoted.
var animation_scene_root_override: Node = null  # tests inject a tree here

func _create_animation_field(key: String, default_value: Variant) -> Control:
	var container: HBoxContainer = HBoxContainer.new()
	var name_edit: LineEdit = LineEdit.new()
	name_edit.text = str(default_value)
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(name_edit)
	var scene_root: Node = animation_scene_root_override
	if scene_root == null and Engine.is_editor_hint():
		scene_root = EditorInterface.get_edited_scene_root()
	var known: PackedStringArray = animation_options_from(scene_root)
	if not known.is_empty():
		var picker: OptionButton = OptionButton.new()
		picker.add_item("(animations)")
		for animation_name: String in known:
			picker.add_item(animation_name)
			# Real entries are tagged — position-proof against future separators.
			picker.set_item_metadata(picker.item_count - 1, animation_name)
		picker.item_selected.connect(func(index: int) -> void:
			var tagged: Variant = picker.get_item_metadata(index)
			if tagged is String:
				name_edit.text = format_quoted_literal(tagged)
		)
		container.add_child(picker)
	if _dialog is AcceptDialog:
		(_dialog as AcceptDialog).register_text_enter(name_edit)
	_fields[key] = name_edit
	return container

## Every animation name on every AnimationPlayer under root (sorted, deduped) —
## static + UI-free so the headless suite can pin it.
static func animation_options_from(root: Node) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	if root == null:
		return names
	var seen: Dictionary = {}
	var pending: Array = [root]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		if node is AnimationPlayer:
			for animation_name: StringName in (node as AnimationPlayer).get_animation_list():
				seen[str(animation_name)] = true
		for child: Node in node.get_children():
			pending.append(child)
	for unique_name: Variant in seen.keys():
		names.append(str(unique_name))
	names.sort()
	return names

## C3's press-a-key workflow: a button that captures the next key press (storing the
## KEY_* constant), plus a fallback dropdown for keys that can't be detected.
func _create_key_capture_field(key: String, default_value: Variant) -> Control:
	var container: HBoxContainer = HBoxContainer.new()
	var capture: Button = Button.new()
	capture.text = str(default_value) if not str(default_value).is_empty() else "<click, then press a key>"
	capture.set_meta("key_constant", str(default_value))
	capture.toggle_mode = true
	capture.tooltip_text = "Click, then press the key you want."
	capture.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	capture.gui_input.connect(func(input_event: InputEvent) -> void:
		if capture.button_pressed and input_event is InputEventKey and (input_event as InputEventKey).pressed:
			var constant: String = key_constant_for((input_event as InputEventKey).physical_keycode)
			capture.set_meta("key_constant", constant)
			capture.text = constant
			capture.button_pressed = false
			capture.accept_event()
	)
	container.add_child(capture)
	var fallback: OptionButton = OptionButton.new()
	fallback.add_item("(or choose)")
	for key_name in ["KEY_SPACE", "KEY_ENTER", "KEY_ESCAPE", "KEY_SHIFT", "KEY_CTRL", "KEY_ALT", "KEY_TAB", "KEY_UP", "KEY_DOWN", "KEY_LEFT", "KEY_RIGHT"]:
		fallback.add_item(key_name)
	fallback.item_selected.connect(func(index: int) -> void:
		if index > 0:
			capture.set_meta("key_constant", fallback.get_item_text(index))
			capture.text = fallback.get_item_text(index)
	)
	container.add_child(fallback)
	_fields[key] = capture
	return container

## Physical keycode -> KEY_* constant name (KEY_F8, KEY_PAGEUP, KEY_SPACE…).
static func key_constant_for(keycode: int) -> String:
	var key_name: String = OS.get_keycode_string(keycode)
	# Keypad constants keep their underscore (KEY_KP_ADD); everything else drops spaces
	# (KEY_PAGEUP, KEY_BRACKETLEFT…).
	if key_name.begins_with("Kp "):
		return "KEY_KP_%s" % key_name.substr(3).to_upper().replace(" ", "")
	return "KEY_%s" % key_name.to_upper().replace(" ", "")

static func color_to_literal(value: Color) -> String:
	return "Color(%s, %s, %s, %s)" % [String.num(value.r, 3), String.num(value.g, 3), String.num(value.b, 3), String.num(value.a, 3)]

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
	# Godot-native drag & drop: dropping a FileSystem file inserts its quoted res:// path,
	# dropping a Scene-dock node inserts a $Path reference.
	edit.set_drag_forwarding(Callable(), _can_drop_on_expression, _drop_on_expression.bind(edit))
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
	var node_button: Button = Button.new()
	node_button.text = "🔍"
	node_button.tooltip_text = "Pick a scene node (search by name, class or path)"
	node_button.pressed.connect(_open_node_picker.bind(key))
	container.add_child(node_button)
	_fields[key] = edit
	return container

# ── Scene node picker (large-project search) ──────────────────────────────────────────
# Search modes (all case-insensitive):
#   plain text        -> matches node NAME, CLASS or PATH ("Area2D" finds every area)
#   group:enemies     -> nodes in that Godot group
#   script:Enemy      -> nodes whose attached script matches (global class or filename)
#   scene:query       -> CROSS-SCENE: scans res:// .tscn files for matching node headers
# Filter chips (2D/3D/UI/Audio/Physics) pre-filter by base class. Recently picked nodes
# surface first; "Used in sheet" lists every $Ref this sheet already makes, tinted red
# when the node no longer exists in the edited scene (broken-reference audit).
var _node_picker_window: Window = null
var _node_picker_tree: Tree = null
var _node_picker_search: LineEdit = null
var _node_picker_target_key: String = ""
var _node_picker_chips: Dictionary = {}  # chip label -> Button (toggle)
var _node_picker_used_toggle: Button = null
var _node_picker_recents: PackedStringArray = PackedStringArray()

const NODE_PICKER_CHIP_CLASSES: Dictionary = {
	"2D": ["Node2D"], "3D": ["Node3D"], "UI": ["Control"],
	"Audio": ["AudioStreamPlayer", "AudioStreamPlayer2D", "AudioStreamPlayer3D"],
	"Physics": ["CollisionObject2D", "CollisionObject3D", "Joint2D", "Joint3D"]
}
const NODE_PICKER_RECENTS_CAP := 8
const NODE_PICKER_SCENE_SCAN_CAP := 200

## Stops any in-flight audio preview (called when the dialog hides — a preview must
## never outlive the dialog that started it).
func _stop_audio_preview() -> void:
	if _preview_player != null and is_instance_valid(_preview_player):
		_preview_player.queue_free()
	_preview_player = null

func _open_node_picker(key: String) -> void:
	_node_picker_target_key = key
	_ensure_node_picker_ui()
	_populate_node_picker()
	_node_picker_window.popup_centered()
	_node_picker_search.grab_focus()

## Builds the picker UI lazily (separate from _open so headless tests can drive it).
func _ensure_node_picker_ui() -> void:
	if _node_picker_window == null:
		_node_picker_window = Window.new()
		_node_picker_window.title = "Pick Node"
		_node_picker_window.size = Vector2i(480, 460)
		_node_picker_window.close_requested.connect(func() -> void: _node_picker_window.hide())
		var box: VBoxContainer = VBoxContainer.new()
		box.set_anchors_preset(Control.PRESET_FULL_RECT)
		_node_picker_search = LineEdit.new()
		_node_picker_search.placeholder_text = "Search…  (also group:enemies, script:Enemy, scene:Coin)"
		_node_picker_search.text_changed.connect(func(_t: String) -> void: _populate_node_picker())
		# Enter commits the first result (parity with the main ACE picker's type-and-Enter).
		_node_picker_search.text_submitted.connect(func(_t: String) -> void: _activate_first_node_picker_match())
		box.add_child(_node_picker_search)
		var chip_row: HBoxContainer = HBoxContainer.new()
		for chip_label: String in NODE_PICKER_CHIP_CLASSES.keys():
			var chip: Button = Button.new()
			chip.text = chip_label
			chip.toggle_mode = true
			chip.toggled.connect(func(_on: bool) -> void: _populate_node_picker())
			chip_row.add_child(chip)
			_node_picker_chips[chip_label] = chip
		_node_picker_used_toggle = Button.new()
		_node_picker_used_toggle.text = "Used in sheet"
		_node_picker_used_toggle.toggle_mode = true
		_node_picker_used_toggle.tooltip_text = "List every node reference this sheet makes (red = missing from the scene)."
		_node_picker_used_toggle.toggled.connect(func(_on: bool) -> void: _populate_node_picker())
		chip_row.add_child(_node_picker_used_toggle)
		box.add_child(chip_row)
		_node_picker_tree = Tree.new()
		_node_picker_tree.columns = 2
		_node_picker_tree.set_column_title(0, "Node")
		_node_picker_tree.set_column_title(1, "Class")
		_node_picker_tree.column_titles_visible = true
		_node_picker_tree.hide_root = true
		_node_picker_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_node_picker_tree.item_activated.connect(_on_node_picker_activated)
		box.add_child(_node_picker_tree)
		_node_picker_window.add_child(box)
		_dialog.add_child(_node_picker_window)

func _populate_node_picker() -> void:
	var scene_root: Node = EditorInterface.get_edited_scene_root() if Engine.is_editor_hint() else null
	_populate_node_picker_from_root(scene_root)

## Population factored from the editor entry point so tests can drive an explicit tree.
func _populate_node_picker_from_root(scene_root: Node) -> void:
	_node_picker_tree.clear()
	var root_item: TreeItem = _node_picker_tree.create_item()
	var query: String = _node_picker_search.text.strip_edges()
	# Used-in-sheet audit view.
	if _node_picker_used_toggle != null and _node_picker_used_toggle.button_pressed:
		var sheet: EventSheetResource = null
		if _lint_context_provider.is_valid():
			sheet = _lint_context_provider.call() as EventSheetResource
		for reference: String in extract_sheet_node_references(sheet):
			var item: TreeItem = _node_picker_tree.create_item(root_item)
			var exists: bool = scene_root != null and scene_root.has_node(NodePath(reference))
			item.set_text(0, reference)
			item.set_text(1, "" if exists else "MISSING")
			item.set_metadata(0, reference)
			if not exists:
				item.set_custom_color(0, Color(0.9, 0.35, 0.35))
				item.set_custom_color(1, Color(0.9, 0.35, 0.35))
		return
	# Cross-scene search: scan .tscn node headers.
	if query.to_lower().begins_with("scene:"):
		for hit: Dictionary in scan_scene_files(query.substr(6).strip_edges()):
			var scene_item: TreeItem = _node_picker_tree.create_item(root_item)
			scene_item.set_text(0, "%s  —  %s" % [str(hit.get("node", "")), str(hit.get("file", ""))])
			scene_item.set_text(1, str(hit.get("class", "")))
			scene_item.set_metadata(0, "scene::" + str(hit.get("file", "")))
		return
	if scene_root == null:
		var empty: TreeItem = _node_picker_tree.create_item(root_item)
		empty.set_text(0, "(no scene open)")
		return
	# Recents first (when not searching).
	if query.is_empty():
		for recent: String in _node_picker_recents:
			if scene_root.has_node(NodePath(recent)):
				var recent_item: TreeItem = _node_picker_tree.create_item(root_item)
				recent_item.set_text(0, "★ " + recent)
				recent_item.set_text(1, scene_root.get_node(NodePath(recent)).get_class())
				recent_item.set_metadata(0, recent)
	_append_node_picker_rows(scene_root, scene_root, root_item, query)

func _append_node_picker_rows(node: Node, scene_root: Node, parent_item: TreeItem, query: String) -> void:
	var relative: String = str(scene_root.get_path_to(node))
	if _chip_filter_allows(node) and node_matches_query(node, relative, query):
		var item: TreeItem = _node_picker_tree.create_item(parent_item)
		item.set_text(0, relative if node != scene_root else node.name)
		item.set_text(1, node.get_class())
		item.set_metadata(0, relative if node != scene_root else ".")
	for child: Node in node.get_children():
		_append_node_picker_rows(child, scene_root, parent_item, query)

## True when no chip is active, or the node inherits any active chip's base classes.
func _chip_filter_allows(node: Node) -> bool:
	var any_active: bool = false
	for chip_label: String in _node_picker_chips.keys():
		var chip: Button = _node_picker_chips[chip_label]
		if not chip.button_pressed:
			continue
		any_active = true
		for base_class: String in NODE_PICKER_CHIP_CLASSES[chip_label]:
			if node.is_class(base_class):
				return true
	return not any_active

## Query matching with the group:/script: prefixes (plain = name/class/path).
static func node_matches_query(node: Node, relative_path: String, query: String) -> bool:
	if query.is_empty():
		return true
	var lowered: String = query.to_lower()
	if lowered.begins_with("group:"):
		return node.is_in_group(StringName(query.substr(6).strip_edges()))
	if lowered.begins_with("script:"):
		var wanted: String = lowered.substr(7).strip_edges()
		var script: Script = node.get_script() as Script
		if script == null:
			return false
		return str(script.get_global_name()).to_lower().contains(wanted) \
			or script.resource_path.get_file().to_lower().contains(wanted)
	return node.name.to_lower().contains(lowered) \
		or node.get_class().to_lower().contains(lowered) \
		or relative_path.to_lower().contains(lowered)

## Every $Name / $"Path" reference the sheet makes (params, blocks, pick filters).
static func extract_sheet_node_references(sheet: EventSheetResource) -> PackedStringArray:
	var references: PackedStringArray = PackedStringArray()
	if sheet == null:
		return references
	var reference_regex: RegEx = RegEx.new()
	reference_regex.compile("\\$(?:\"([^\"]+)\"|([A-Za-z_][A-Za-z0-9_/]*))")
	var haystacks: PackedStringArray = PackedStringArray()
	_collect_reference_haystacks(sheet.events, haystacks)
	for function_entry: Variant in sheet.functions:
		if function_entry is EventFunction:
			_collect_reference_haystacks((function_entry as EventFunction).events if not (function_entry as EventFunction).events.is_empty() else (function_entry as EventFunction).rows, haystacks)
	for haystack: String in haystacks:
		for regex_match: RegExMatch in reference_regex.search_all(haystack):
			var reference: String = regex_match.get_string(1) if not regex_match.get_string(1).is_empty() else regex_match.get_string(2)
			if not references.has(reference):
				references.append(reference)
	return references

static func _collect_reference_haystacks(rows: Array, into: PackedStringArray) -> void:
	for row: Variant in rows:
		if row is RawCodeRow:
			into.append((row as RawCodeRow).code)
		elif row is EventGroup:
			var group: EventGroup = row as EventGroup
			_collect_reference_haystacks(group.events if not group.events.is_empty() else group.rows, into)
		elif row is EventRow:
			var event_row: EventRow = row as EventRow
			for ace: Variant in event_row.conditions + event_row.actions:
				if ace is RawCodeRow:
					into.append((ace as RawCodeRow).code)
				elif ace is MatchRow:
					into.append((ace as MatchRow).branches_text)
				elif ace is Resource and ace.get("params") is Dictionary:
					for value: Variant in (ace.get("params") as Dictionary).values():
						if value is String:
							into.append(value)
			for pick: Variant in event_row.pick_filters:
				if pick is PickFilter:
					into.append((pick as PickFilter).collection_value)
					into.append((pick as PickFilter).predicate_expression)
			_collect_reference_haystacks(event_row.sub_events, into)

## Cross-scene search: regex-scans .tscn node headers (text format) under res://.
## Returns [{file, node, class}] capped at NODE_PICKER_SCENE_SCAN_CAP.
static func scan_scene_files(query: String, base_dir: String = "res://") -> Array:
	var hits: Array = []
	if query.is_empty():
		return hits
	var header_regex: RegEx = RegEx.new()
	header_regex.compile("\\[node name=\"([^\"]+)\"(?: type=\"([^\"]+)\")?")
	var pending: PackedStringArray = PackedStringArray([base_dir])
	var lowered: String = query.to_lower()
	while not pending.is_empty() and hits.size() < NODE_PICKER_SCENE_SCAN_CAP:
		var directory_path: String = pending[pending.size() - 1]
		pending.remove_at(pending.size() - 1)
		var directory: DirAccess = DirAccess.open(directory_path)
		if directory == null:
			continue
		directory.list_dir_begin()
		var entry: String = directory.get_next()
		while not entry.is_empty():
			var full_path: String = directory_path.path_join(entry)
			if directory.current_is_dir():
				if not entry.begins_with("."):
					pending.append(full_path)
			elif entry.get_extension() == "tscn":
				var content: String = FileAccess.get_file_as_string(full_path)
				for regex_match: RegExMatch in header_regex.search_all(content):
					var node_name: String = regex_match.get_string(1)
					var node_class: String = regex_match.get_string(2)
					if node_name.to_lower().contains(lowered) or node_class.to_lower().contains(lowered):
						hits.append({"file": full_path, "node": node_name, "class": node_class})
						if hits.size() >= NODE_PICKER_SCENE_SCAN_CAP:
							break
			entry = directory.get_next()
	return hits

## Depth-first: the first tree item carrying metadata — a real result row, skipping non-selectable
## group folders and empty-state placeholders. Lets Enter in the sub-picker search boxes commit the
## top match the way the main ACE picker's type-and-Enter does.
func _first_metadata_row(item: TreeItem) -> TreeItem:
	if item == null:
		return null
	var child: TreeItem = item.get_first_child()
	while child != null:
		if child.get_metadata(0) != null:
			return child
		var nested: TreeItem = _first_metadata_row(child)
		if nested != null:
			return nested
		child = child.get_next()
	return null

## Enter in the node-picker search box commits the first matching node.
func _activate_first_node_picker_match() -> void:
	var first: TreeItem = _first_metadata_row(_node_picker_tree.get_root()) if _node_picker_tree != null else null
	if first != null:
		first.select(0)
		_on_node_picker_activated()

## Enter in the expression-picker search box commits the first matching expression.
func _activate_first_expression_match() -> void:
	var first: TreeItem = _first_metadata_row(_expression_tree.get_root()) if _expression_tree != null else null
	if first != null:
		first.select(0)
		_on_expression_activated()

func _on_node_picker_activated() -> void:
	var selected: TreeItem = _node_picker_tree.get_selected()
	if selected == null:
		return
	var relative: String = str(selected.get_metadata(0))
	var reference: String
	if relative.begins_with("scene::"):
		reference = format_quoted_literal(relative.trim_prefix("scene::"))
	else:
		reference = "self" if relative == "." else _node_reference(relative)
		var existing_index: int = _node_picker_recents.find(relative)
		if existing_index >= 0:
			_node_picker_recents.remove_at(existing_index)
		_node_picker_recents.insert(0, relative)
		if _node_picker_recents.size() > NODE_PICKER_RECENTS_CAP:
			_node_picker_recents.resize(NODE_PICKER_RECENTS_CAP)
	var field: Variant = _fields.get(_node_picker_target_key)
	if field is TextEdit:
		(field as TextEdit).insert_text_at_caret(reference)
		_validate_expression_field(field)
	elif field is LineEdit:
		(field as LineEdit).insert_text_at_caret(reference)
	_node_picker_window.hide()

## Literal node-path references in an expression that can be checked against a scene: bare `$Name`,
## `$"Quoted/Path"`, and `get_node("Path")`. Unique-name (`%Name`) refs are handled separately by
## unique_names_in_expression(); dynamic get_node(expr) is not statically resolvable and is skipped.
static func node_references_in_expression(expression: String) -> PackedStringArray:
	var references: PackedStringArray = PackedStringArray()
	var dollar_re: RegEx = RegEx.new()
	dollar_re.compile("\\$(?:\"([^\"]+)\"|([A-Za-z_][A-Za-z0-9_/]*))")
	for hit: RegExMatch in dollar_re.search_all(expression):
		var quoted: String = hit.get_string(1)
		references.append(quoted if not quoted.is_empty() else hit.get_string(2))
	var get_node_re: RegEx = RegEx.new()
	get_node_re.compile("get_node\\(\"([^\"]+)\"\\)")
	for hit: RegExMatch in get_node_re.search_all(expression):
		references.append(hit.get_string(1))
	return references

## Unique-name references (Godot 4's `%Name` — the stable, refactor-proof way to reach a node, like a
## Construct object name): bare `%Name` and `%"Quoted Name"`. A `%` that sits INSIDE a string literal is
## a printf-style format specifier (`"%d"`, `"%.2f"`) and is NOT a node reference, so it is skipped.
static func unique_names_in_expression(expression: String) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	var quoted_re: RegEx = RegEx.new()
	quoted_re.compile("%\"([^\"]+)\"")
	for hit: RegExMatch in quoted_re.search_all(expression):
		names.append(hit.get_string(1))
	var bare_re: RegEx = RegEx.new()
	bare_re.compile("%([A-Za-z_][A-Za-z0-9_]*)")
	for hit: RegExMatch in bare_re.search_all(expression):
		if _is_inside_string_literal(expression, hit.get_start()):
			continue  # "%d" / "%s" format specifier, not a node ref
		names.append(hit.get_string(1))
	return names

## Whether `index` falls inside a "…" string literal (odd number of double-quotes before it). Cheap
## heuristic — enough to tell a `%d` format specifier from a real `%Name` node reference.
static func _is_inside_string_literal(text: String, index: int) -> bool:
	var quotes: int = 0
	for i: int in range(mini(index, text.length())):
		if text[i] == "\"":
			quotes += 1
	return quotes % 2 == 1

## True when a trailing `%` is the modulo / string-format operator (preceded by a value: an
## identifier, number, `)`, `]`, or a closing quote) rather than the start of a `%Name` reference.
static func _looks_like_modulo(before_caret: String) -> bool:
	var stem: String = before_caret.substr(0, before_caret.length() - 1).rstrip(" 	")
	if stem.is_empty():
		return false
	var last: String = stem.substr(stem.length() - 1)
	return "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_)]\"'".contains(last)

## The first node reference in `expression` that does NOT resolve in `scene_root`, or "" when every
## reference resolves (or there are none / no scene to check). Checks both `$path`/get_node refs (via
## has_node) and `%Name` unique refs (via the scene's unique-name set); a `%`-ref is returned with its
## `%` so the warning reads back as `%Foo`. Absolute paths are skipped — they address the running tree,
## not the edited scene. Used to surface a typo'd reference as an author-time warning.
static func unresolved_node_reference(expression: String, scene_root: Node) -> String:
	if scene_root == null:
		return ""
	for reference: String in node_references_in_expression(expression):
		if reference.is_empty() or reference.begins_with("/"):
			continue
		if not scene_root.has_node(NodePath(reference)):
			return reference
	var unique_refs: PackedStringArray = unique_names_in_expression(expression)
	if not unique_refs.is_empty():
		var known: PackedStringArray = scene_unique_names(scene_root)
		for name: String in unique_refs:
			if not name.is_empty() and not known.has(name):
				return "%" + name
	return ""

## Every node under `scene_root` as a relative path (Player, UI, UI/Score, …), capped, for `$` node
## autocomplete. Depth-first so siblings stay grouped under their parent.
static func scene_node_paths(scene_root: Node, limit: int = 200) -> PackedStringArray:
	var paths: PackedStringArray = PackedStringArray()
	if scene_root != null:
		_collect_node_paths(scene_root, scene_root, paths, limit)
	return paths

static func _collect_node_paths(node: Node, scene_root: Node, paths: PackedStringArray, limit: int) -> void:
	for child: Node in node.get_children():
		if paths.size() >= limit:
			return
		paths.append(str(scene_root.get_path_to(child)))
		_collect_node_paths(child, scene_root, paths, limit)

## The unique names (`%Name`) reachable from anywhere in `scene_root`: nodes flagged
## unique_name_in_owner whose owner is the scene root (owner-scoped — an instanced sub-scene's own
## uniques are encapsulated and not reachable via `%` here). Drives `%` validation + autocomplete.
static func scene_unique_names(scene_root: Node, limit: int = 200) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	if scene_root != null:
		_collect_unique_names(scene_root, scene_root, names, limit)
	return names

static func _collect_unique_names(node: Node, scene_root: Node, names: PackedStringArray, limit: int) -> void:
	for child: Node in node.get_children():
		if names.size() >= limit:
			return
		if child.unique_name_in_owner and child.owner == scene_root:
			names.append(child.name)
		_collect_unique_names(child, scene_root, names, limit)

## The scene to validate node paths against: a test-injected tree, else the edited scene (editor only).
var node_validation_scene_override: Node = null  # tests inject a tree here

func _validation_scene_root() -> Node:
	if node_validation_scene_override != null:
		return node_validation_scene_override
	return EditorInterface.get_edited_scene_root() if Engine.is_editor_hint() else null

## Live expression validation: compile-checks the field against the sheet context
## (variables, host members) and tints the text red when it would not compile. The lint
## context provider is optional — without it the field stays unvalidated.
func _validate_expression_field(edit: Control) -> void:
	if not _lint_context_provider.is_valid():
		return
	var sheet: EventSheetResource = _lint_context_provider.call() as EventSheetResource
	var lint_result: Dictionary = EventSheetGDScriptLint.lint_expression(str(edit.get("text")), sheet)
	if bool(lint_result.get("ok", true)):
		# Valid GDScript — but a literal $node / get_node("…") path that does NOT exist in the edited
		# scene is almost always a typo. Flag it amber (a warning, not a red error: the node may be
		# spawned at runtime) so "$Enmy" is caught at author time instead of failing silently in game.
		var unresolved: String = unresolved_node_reference(str(edit.get("text")), _validation_scene_root())
		if unresolved.is_empty():
			edit.remove_theme_color_override("font_color")
			edit.tooltip_text = "Plain GDScript — anything valid in an expression works here."
		else:
			edit.add_theme_color_override("font_color", Color(0.92, 0.72, 0.35))
			if unresolved.begins_with("%"):
				# Teach the unique-name idiom: % resolves only once a node is marked unique in the scene.
				edit.tooltip_text = "⚠ No node named \"%s\" in this scene — right-click the node in the scene tree ▸ Access as Unique Name (or it may be spawned at runtime)." % unresolved
			else:
				edit.tooltip_text = "⚠ No node \"%s\" in this scene yet — fine if it is spawned at runtime, otherwise check the path." % unresolved
		_update_quickfix_button(edit, "")
		_update_didyoumean_button(edit, "", "")
	else:
		edit.add_theme_color_override("font_color", Color(0.96, 0.45, 0.45))
		var undeclared: String = undeclared_identifier_in_expression(str(edit.get("text")), sheet)
		# Typo path first: if the unknown identifier is one edit away from something the sheet
		# DOES know, offer a one-click "Use it" before the create-new-variable fallback — far
		# friendlier than a red squiggle for a non-coder who fat-fingered a name.
		var suggestion: String = closest_known_identifier(undeclared, sheet)
		if suggestion.is_empty():
			edit.tooltip_text = "✗ Not a valid GDScript expression for this sheet."
		else:
			edit.tooltip_text = "✗ Unknown \"%s\". Did you mean \"%s\"?" % [undeclared, suggestion]
		_update_quickfix_button(edit, undeclared)
		_update_didyoumean_button(edit, undeclared, suggestion)

## Wires the sheet-context source for expression validation (returns EventSheetResource).
func set_lint_context_provider(provider: Callable) -> void:
	_lint_context_provider = provider

## Opens the editor's built-in class reference for a native class. Returns the help
## topic (testable headless, where there's no editor to open it in).
static func open_class_docs(docs_class: String) -> String:
	var topic: String = "class_name:%s" % docs_class
	if Engine.is_editor_hint() and Engine.has_singleton("EditorInterface"):
		var script_editor: Variant = (Engine.get_singleton("EditorInterface") as Object).call("get_script_editor")
		if script_editor is Object:
			(script_editor as Object).call("goto_help", topic)
	return topic

# ── Create-variable quick-fix: an undeclared identifier in an expression field grows
# a one-click "+ var" button (cancel → Add Variable → retype, collapsed to one click).
# The dialog stays dock-agnostic: the dock injects a creator Callable(name) -> bool.
var _variable_creator: Callable = Callable()
var _quickfix_buttons: Dictionary = {}
var _didyoumean_buttons: Dictionary = {}

## The closest name the sheet already knows (variable / tree var / sheet function / host
## member) to an unknown identifier, within a small edit distance — powers the "Did you
## mean …?" typo quick-fix. "" when nothing is close enough (avoid nonsense suggestions).
static func closest_known_identifier(identifier: String, sheet: EventSheetResource) -> String:
	if identifier.length() < 2:
		return ""
	var candidates: Array[String] = []
	if sheet != null:
		for var_name: Variant in sheet.variables.keys():
			candidates.append(str(var_name))
		for row: Variant in sheet.events:
			if row is LocalVariable:
				candidates.append((row as LocalVariable).name)
		for function_entry: Variant in sheet.functions:
			if function_entry is EventFunction:
				candidates.append((function_entry as EventFunction).function_name)
	var host_class: String = sheet.host_class if sheet != null and ClassDB.class_exists(sheet.host_class) else "Node"
	for property: Dictionary in ClassDB.class_get_property_list(host_class):
		candidates.append(str(property.get("name")))
	var best: String = ""
	var best_distance: int = 3  # only suggest within 2 edits (strictly < 3)
	for candidate: String in candidates:
		if candidate.is_empty() or candidate == identifier:
			continue
		var distance: int = _edit_distance(identifier.to_lower(), candidate.to_lower())
		if distance < best_distance:
			best_distance = distance
			best = candidate
	return best

## Levenshtein distance (small strings — identifiers), used only by closest_known_identifier.
static func _edit_distance(a: String, b: String) -> int:
	var n: int = a.length()
	var m: int = b.length()
	if n == 0:
		return m
	if m == 0:
		return n
	var previous: Array[int] = []
	for j: int in range(m + 1):
		previous.append(j)
	for i: int in range(1, n + 1):
		var current: Array[int] = [i]
		current.resize(m + 1)
		for j: int in range(1, m + 1):
			var cost: int = 0 if a[i - 1] == b[j - 1] else 1
			current[j] = min(min(previous[j] + 1, current[j - 1] + 1), previous[j - 1] + cost)
		previous = current
	return previous[m]

func set_variable_creator(creator: Callable) -> void:
	_variable_creator = creator

## The probable culprit when an expression fails lint: the first plain identifier the
## sheet context can't account for. The engine never exposes its parse-error text to
## scripts (the lint result is generic), so this derives the answer from the
## expression itself — skipping string literals, member accesses (`x.y`), node refs
## (`$`/`%`/`&`), calls, keywords, sheet variables/functions/tree vars, host members,
## global classes and singletons. "" when the failure isn't identifier-shaped.
static func undeclared_identifier_in_expression(expression: String, sheet: EventSheetResource) -> String:
	var stripped: String = RegEx.create_from_string("\"[^\"]*\"|'[^']*'").sub(expression, " ", true)
	var skip_words: PackedStringArray = PackedStringArray([
		"true", "false", "null", "and", "or", "not", "in", "is", "as", "if", "else",
		"self", "host", "delta", "PI", "TAU", "INF", "NAN",
	])
	var host_class: String = sheet.host_class if sheet != null and ClassDB.class_exists(sheet.host_class) else "Node"
	var host_members: Dictionary = {}
	for property: Dictionary in ClassDB.class_get_property_list(host_class):
		host_members[str(property.get("name"))] = true
	var tree_variables: Dictionary = {}
	if sheet != null:
		for row: Variant in sheet.events:
			if row is LocalVariable:
				tree_variables[(row as LocalVariable).name] = true
	for ident_match: RegExMatch in RegEx.create_from_string("[A-Za-z_][A-Za-z0-9_]*").search_all(stripped):
		var ident: String = ident_match.get_string()
		var before: String = stripped.substr(0, ident_match.get_start()).strip_edges(false, true)
		if before.ends_with(".") or before.ends_with("$") or before.ends_with("&") or before.ends_with("%"):
			continue
		if stripped.substr(ident_match.get_end()).strip_edges(true, false).begins_with("("):
			continue
		if skip_words.has(ident) or ClassDB.class_exists(ident) or Engine.has_singleton(ident):
			continue
		if sheet != null and (sheet.variables.has(ident) or tree_variables.has(ident)):
			continue
		var is_sheet_function: bool = false
		if sheet != null:
			for function_entry: Variant in sheet.functions:
				if function_entry is EventFunction and (function_entry as EventFunction).function_name == ident:
					is_sheet_function = true
					break
		if is_sheet_function or ClassDB.class_has_method(host_class, ident) or host_members.has(ident):
			continue
		return ident
	return ""

func _update_quickfix_button(edit: Control, identifier: String) -> void:
	var button: Button = _quickfix_buttons.get(edit) as Button
	if identifier.is_empty() or not _variable_creator.is_valid():
		if button != null:
			button.visible = false
		return
	if button == null or not is_instance_valid(button):
		button = Button.new()
		button.pressed.connect(_on_quickfix_pressed.bind(edit))
		var parent: Node = edit.get_parent()
		if parent == null:
			return
		parent.add_child(button)
		_quickfix_buttons[edit] = button
	button.text = "+ var %s" % identifier
	button.tooltip_text = "Create the sheet variable \"%s\" and re-check this expression." % identifier
	button.set_meta("identifier", identifier)
	button.visible = true

func _on_quickfix_pressed(edit: Control) -> void:
	var button: Button = _quickfix_buttons.get(edit) as Button
	if button == null or not _variable_creator.is_valid():
		return
	if bool(_variable_creator.call(str(button.get_meta("identifier", "")))):
		_validate_expression_field(edit)

## "Did you mean …?" typo quick-fix: a one-click button that swaps the unknown identifier
## for the closest name the sheet knows, then re-validates. Distinct from the create-var
## button, which the user wants when the name is genuinely new.
func _update_didyoumean_button(edit: Control, identifier: String, suggestion: String) -> void:
	var button: Button = _didyoumean_buttons.get(edit) as Button
	if identifier.is_empty() or suggestion.is_empty():
		if button != null:
			button.visible = false
		return
	if button == null or not is_instance_valid(button):
		button = Button.new()
		button.pressed.connect(_on_didyoumean_pressed.bind(edit))
		var parent: Node = edit.get_parent()
		if parent == null:
			return
		parent.add_child(button)
		_didyoumean_buttons[edit] = button
	button.text = "Use \"%s\"" % suggestion
	button.tooltip_text = "Replace \"%s\" with \"%s\" in this expression." % [identifier, suggestion]
	button.set_meta("identifier", identifier)
	button.set_meta("suggestion", suggestion)
	button.visible = true

func _on_didyoumean_pressed(edit: Control) -> void:
	var button: Button = _didyoumean_buttons.get(edit) as Button
	if button == null:
		return
	var identifier: String = str(button.get_meta("identifier", ""))
	var suggestion: String = str(button.get_meta("suggestion", ""))
	if identifier.is_empty() or suggestion.is_empty():
		return
	# Whole-word replace so "hp" inside "shparrow" is never touched.
	var replaced: String = RegEx.create_from_string("\\b%s\\b" % RegEx.create_from_string("[^A-Za-z0-9_]").sub(identifier, "", true)).sub(str(edit.get("text")), suggestion, true)
	edit.set("text", replaced)
	_validate_expression_field(edit)

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
	# Right after a `$`, offer the edited scene's node paths so a path can be typed-and-picked, not only
	# selected through the 🔍 picker. The `$` is already typed, so the inserted text is the bare path.
	if before_caret.ends_with("$") and Engine.is_editor_hint():
		for node_path: String in scene_node_paths(EditorInterface.get_edited_scene_root()):
			edit.add_code_completion_option(CodeEdit.KIND_NODE_PATH, "$" + node_path, node_path)
	# Right after a `%`, offer the scene's unique names (the stable, refactor-proof references) — unless
	# the `%` is the modulo / string-format operator (a % b, "%d" % x).
	if before_caret.ends_with("%") and Engine.is_editor_hint() and not _looks_like_modulo(before_caret):
		for unique_name: String in scene_unique_names(EditorInterface.get_edited_scene_root()):
			edit.add_code_completion_option(CodeEdit.KIND_NODE_PATH, "%" + unique_name, unique_name)
	edit.update_code_completion_options(true)
	edit.set_code_hint(EventSheetGDScriptLint.signature_hint(before_caret, sheet))

## Extract the typed value from a registered field node.
## "Vector2(0, 0)" → ["0", "0"]; "Vector3(1, 2, 3)" → ["1", "2", "3"]; [] otherwise.
## Splits on TOP-LEVEL commas only, so nested calls inside an axis survive.
static func vector_literal_parts(value: String) -> PackedStringArray:
	var trimmed: String = value.strip_edges()
	var dims: int = 0
	if trimmed.begins_with("Vector2(") and trimmed.ends_with(")"):
		dims = 2
	elif trimmed.begins_with("Vector3(") and trimmed.ends_with(")"):
		dims = 3
	if dims == 0:
		return PackedStringArray()
	var inner: String = trimmed.substr(8, trimmed.length() - 9)
	var parts: PackedStringArray = PackedStringArray()
	var depth: int = 0
	var current: String = ""
	for character in inner:
		if character == "(":
			depth += 1
		elif character == ")":
			depth -= 1
		if character == "," and depth == 0:
			parts.append(current.strip_edges())
			current = ""
		else:
			current += character
	parts.append(current.strip_edges())
	return parts if parts.size() == dims else PackedStringArray()

## Per-axis fields composing back to "VectorN(x, y[, z])" on extract.
func _create_vector_field(key: String, parts: PackedStringArray) -> Control:
	var container: HBoxContainer = HBoxContainer.new()
	container.add_theme_constant_override("separation", 6)
	var axis_edits: Array = []
	var axis_names: PackedStringArray = PackedStringArray(["x", "y", "z"])
	for axis in parts.size():
		var axis_label: Label = Label.new()
		axis_label.text = axis_names[axis]
		container.add_child(axis_label)
		var axis_edit: LineEdit = LineEdit.new()
		axis_edit.text = parts[axis]
		axis_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		axis_edit.tooltip_text = "Any GDScript expression works per axis."
		_dialog.register_text_enter(axis_edit)
		container.add_child(axis_edit)
		axis_edits.append(axis_edit)
	container.set_meta("vector_axis_edits", axis_edits)
	_fields[key] = container
	return container

func _extract_value(field: Control) -> Variant:
	if field is CheckBox:
		return (field as CheckBox).button_pressed
	if field.has_meta("vector_axis_edits"):
		var axis_values: PackedStringArray = PackedStringArray()
		for axis_edit: Variant in (field.get_meta("vector_axis_edits") as Array):
			axis_values.append((axis_edit as LineEdit).text.strip_edges())
		return "Vector%d(%s)" % [axis_values.size(), ", ".join(axis_values)]
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
	if field is ColorPickerButton:
		return color_to_literal((field as ColorPickerButton).color)
	if field is Button and field.has_meta("key_constant"):
		return str(field.get_meta("key_constant"))
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

## True unless the lint scratch ITSELF is broken (a sheet variable shadowing a host
## member makes the scratch unparseable, so every expression "fails" and the OK
## guardrail would lock the user out — verified by linting a bare literal).
func _lint_context_healthy() -> bool:
	if not _lint_context_provider.is_valid():
		return true
	var baseline_sheet: EventSheetResource = _lint_context_provider.call() as EventSheetResource
	return bool(EventSheetGDScriptLint.lint_expression("0", baseline_sheet).get("ok", true))

func _on_confirmed() -> void:
	if _definition == null or _apply_blocked:
		return
	# Guardrail (C3-style): block the commit while any expression doesn't compile.
	var invalid_field: Control = _first_invalid_expression() if _lint_context_healthy() else null
	if invalid_field != null:
		if _hint != null:
			_hint.text = "✗ An expression doesn't compile — fix it before applying."
		invalid_field.grab_focus()
		if _dialog != null and is_instance_valid(_dialog) and _dialog.is_inside_tree():
			_dialog.call_deferred("popup_centered", Vector2i(520, 380))
		return
	_commit(false)

## Shared apply path for OK and "Apply & Add Another". When chaining, the context
## carries chain_add so the dock reopens the picker in the same append mode; the
## values are remembered either way.
func _commit(chain: bool) -> void:
	var values: Dictionary = {}
	for key: Variant in _fields.keys():
		values[str(key)] = _extract_value(_fields[key])
	_remembered_values[_definition.id] = values.duplicate(true)
	var context: Dictionary = _context.duplicate(true)
	if chain:
		context["chain_add"] = true
	params_confirmed.emit(_definition, values, context)
	_definition = null
	_context.clear()

func _on_custom_action(action: StringName) -> void:
	if str(action) == BACK_ACTION:
		var definition: ACEDefinition = _definition
		var context: Dictionary = _context.duplicate(true)
		_close()
		back_requested.emit(definition, context)
		return
	if str(action) == ADD_ANOTHER_ACTION:
		# Same validation gate as OK; only chain when it passed (definition cleared).
		if _definition == null or _apply_blocked:
			return
		var invalid_field: Control = _first_invalid_expression() if _lint_context_healthy() else null
		if invalid_field != null:
			if _hint != null:
				_hint.text = "✗ An expression doesn't compile — fix it before applying."
			invalid_field.grab_focus()
			return
		_commit(true)
		_close()

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
	# Enter commits the first result (parity with the main ACE picker's type-and-Enter).
	_expression_search.text_submitted.connect(func(_text: String) -> void: _activate_first_expression_match())
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
	# Visual expression builder: also list the host object's OWN members (reflected),
	# so any property/method is pickable without typing — not just registered ACEs.
	var host_class: String = _host_class_for_context()
	_add_member_expression_group(root, "This Object — Properties", reflected_members(host_class, "property"), false, query)
	_add_member_expression_group(root, "This Object — Methods", reflected_members(host_class, "method"), true, query)

## Adds a reflected-members group to the expression picker; methods insert as `name()`,
## properties as `name`. Honors the search query (case-insensitive substring filter).
func _add_member_expression_group(root: TreeItem, label: String, members: Array, is_method: bool, query: String) -> void:
	var lowered: String = query.to_lower()
	var group_item: TreeItem = null
	for member: Variant in members:
		var member_name: String = str(member)
		if not lowered.is_empty() and not member_name.to_lower().contains(lowered):
			continue
		if group_item == null:
			group_item = _expression_tree.create_item(root)
			group_item.set_text(0, label)
			group_item.set_custom_color(0, ACEPickerDialog.GROUP_COLOR_NODE_TYPE)
			group_item.set_selectable(0, false)
		var fragment: String = member_expression_fragment(member_name, is_method)
		var item: TreeItem = _expression_tree.create_item(group_item)
		item.set_text(0, fragment)
		item.set_custom_color(0, ACEPickerDialog.ITEM_COLOR_EXPRESSION)
		item.set_metadata(0, fragment)

## The insert fragment for a reflected member: `name()` for a method, `name` for a
## property. Static + pure, so it is unit-testable without a dialog.
static func member_expression_fragment(member: String, is_method: bool) -> String:
	return (member + "()") if is_method else member

func _on_expression_activated() -> void:
	var item: TreeItem = _expression_tree.get_selected()
	if item == null:
		return
	var metadata: Variant = item.get_metadata(0)
	var insert_text: String = ""
	if metadata is ACEDefinition:
		insert_text = _expression_template(metadata as ACEDefinition)
	elif metadata is String:
		insert_text = str(metadata)
	if insert_text.is_empty():
		return
	var target: Control = _fields.get(_expression_target_key, null)
	if target is LineEdit:
		var line_edit: LineEdit = target as LineEdit
		line_edit.text = insert_text
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
	# The dock sets from_picker when this dialog is opened from a picker selection.
	return bool(_context.get("from_picker", false))

## Whether Back can return to a picker: the add flow (from_picker) OR a row edit, which opens in a
## replace_* mode the picker understands — so editing an action/expression can also go back to swap
## the ACE, exactly like editing a condition already does (it routes through the replace-picker).
func _can_return_to_picker() -> bool:
	if _came_from_picker():
		return true
	return str(_context.get("mode", "")) in ["replace_condition", "replace_action", "replace_trigger"]

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
