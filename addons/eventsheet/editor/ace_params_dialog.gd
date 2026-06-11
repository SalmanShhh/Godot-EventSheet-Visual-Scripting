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
	_dialog.visibility_changed.connect(func() -> void:
		if not _dialog.visible:
			_stop_audio_preview()
	)
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
var _hint_factories: Dictionary = {}

func _ensure_hint_factories() -> void:
	if _hint_factories.is_empty():
		_hint_factories = {
			"key_capture": _create_key_capture_field,
			"audio_path": _create_audio_path_field,
			"scene_path": _create_scene_path_field,
			"animation_reference": _create_animation_field,
		}

func _create_field(param_dict: Dictionary, initial_values: Dictionary, key: String, hint: String) -> Control:
	var field_type: int = int(param_dict.get("type", TYPE_NIL))
	var default_value: Variant = initial_values.get(key, param_dict.get("default_value", ""))
	var options: Array = param_dict.get("options", [])

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
			return "\"%s\"" % str(files[0]) if not files.is_empty() else ""
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

func _on_node_picker_activated() -> void:
	var selected: TreeItem = _node_picker_tree.get_selected()
	if selected == null:
		return
	var relative: String = str(selected.get_metadata(0))
	var reference: String
	if relative.begins_with("scene::"):
		reference = "\"%s\"" % relative.trim_prefix("scene::")
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
