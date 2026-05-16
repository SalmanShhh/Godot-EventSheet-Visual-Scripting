# EventForge — Event sheet editor
# Renders the event sheet as a Construct/GDevelop-style vertical document.
# The canvas shows: document header → global variable rows → event/group blocks.
# The inspector panel on the right shows context-sensitive editing UI.
@tool
extends Control
class_name EventSheetEditor

# ── State ────────────────────────────────────────────────────────────────────

var current_sheet: EventSheetResource = null
# user:// is the editor's writable data path; keep preview output out of res:// assets.
const PREVIEW_OUTPUT_PATH: String = "user://eventforge_preview_generated.gd"
const DEFAULT_RUN_CONTEXT_ACE_ID: String = "OnProcess"
const EVENT_PICKER_GROUPS: PackedStringArray = [
	"Run Context / Triggers",
	"General Conditions",
	"Variables",
	"Loops",
	"Signals / Scene / Input",
	"Custom ACEs"
]

## Currently selected entry kind.
## One of: "none", "event", "condition", "action", "variable", "group"
var _selected_entry_kind: String = "none"
var _selected_row: Variant = null       # EventRowUI / VariableRowUI / GroupRowUI
var _selected_index: int = -1           # condition or action index within event
var _selected_variable_name: String = ""
var _selected_group: Variant = null     # GroupRowUI

# ── UI references ─────────────────────────────────────────────────────────────

var _scroll: ScrollContainer = null
var _canvas_vbox: VBoxContainer = null
var _inspector_panel: PanelContainer = null
var _inspector_vbox: VBoxContainer = null
var _sheet_toolbar: SheetToolbar = null
var _ace_picker_popup: PopupPanel = null
var _ace_picker_title: Label = null
var _ace_picker_tree: Tree = null
var _ace_picker_description: Label = null
## One of: "new_event", "append_condition", "replace_condition", "append_action"
var _ace_picker_mode: String = ""
var _ace_picker_target_row: EventRowUI = null
var _ace_picker_target_condition_index: int = -1
var _ace_params_dialog: ConfirmationDialog = null
var _ace_params_form: VBoxContainer = null
var _ace_params_hint: Label = null
var _ace_params_fields: Dictionary = {}
var _ace_params_mode: String = ""
var _ace_params_descriptor: ACEDescriptor = null
var _ace_params_target_row: EventRowUI = null
var _ace_params_target_index: int = -1
var _ace_params_existing_values: Dictionary = {}

var _variable_dialog: ConfirmationDialog = null
var _variable_name_edit: LineEdit = null
var _variable_type_option: OptionButton = null
var _variable_initial_edit: LineEdit = null
var _variable_description_edit: LineEdit = null
var _variable_dialog_mode: String = ""
var _variable_dialog_original_name: String = ""
var _suppress_variable_popup_on_select: bool = false

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	_build_layout()

## Called by the plugin to load a sheet into the editor.
func setup(sheet: EventSheetResource = null) -> void:
	_load_sheet(sheet)

# ── Layout construction ───────────────────────────────────────────────────────

func _build_layout() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	var root: VBoxContainer = VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	_sheet_toolbar = SheetToolbar.new()
	_sheet_toolbar.new_sheet_requested.connect(_on_create_new_sheet)
	_sheet_toolbar.open_sheet_requested.connect(_on_open_existing_sheet)
	_sheet_toolbar.add_event_requested.connect(_on_add_event_requested)
	_sheet_toolbar.add_var_requested.connect(_on_add_variable_requested)
	_sheet_toolbar.compile_requested.connect(_on_compile_requested)
	root.add_child(_sheet_toolbar)

	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_theme_constant_override("separation", 0)
	root.add_child(hbox)

	# ── Left: canvas scroll ───────────────────────────────────────────────────
	_scroll = ScrollContainer.new()
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	hbox.add_child(_scroll)

	_canvas_vbox = VBoxContainer.new()
	_canvas_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_canvas_vbox.add_theme_constant_override("separation", 4)
	_canvas_vbox.set("custom_minimum_size", Vector2(0, 0))
	_scroll.add_child(_canvas_vbox)

	# ── Vertical separator ────────────────────────────────────────────────────
	var vsep: VSeparator = VSeparator.new()
	hbox.add_child(vsep)

	# ── Right: inspector panel (passive context panel) ────────────────────────
	_inspector_panel = PanelContainer.new()
	_inspector_panel.custom_minimum_size = Vector2(200, 0)
	_inspector_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var insp_style: StyleBoxFlat = StyleBoxFlat.new()
	insp_style.bg_color = Color(0.12, 0.13, 0.16, 1.0)
	insp_style.set_content_margin_all(8)
	_inspector_panel.add_theme_stylebox_override("panel", insp_style)
	hbox.add_child(_inspector_panel)

	_inspector_vbox = VBoxContainer.new()
	_inspector_vbox.add_theme_constant_override("separation", 6)
	_inspector_panel.add_child(_inspector_vbox)

	_show_empty_inspector()
	_refresh_toolbar_state()
	_build_ace_picker_popup()
	_build_ace_params_dialog_popup()
	_build_variable_dialog_popup()

# ── Canvas rendering ──────────────────────────────────────────────────────────

## Rebuilds the full canvas document from current_sheet.
func refresh_canvas() -> void:
	for child in _canvas_vbox.get_children():
		child.queue_free()

	_add_document_header()

	if current_sheet == null:
		_add_no_sheet_onboarding()
		return

	_add_variables_section()
	_add_events_section()

func _add_no_sheet_onboarding() -> void:
	var margin: MarginContainer = MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_bottom", 40)

	var card: PanelContainer = PanelContainer.new()
	var card_style: StyleBoxFlat = StyleBoxFlat.new()
	card_style.bg_color = Color(0.14, 0.16, 0.20, 1.0)
	card_style.set_corner_radius_all(6)
	card_style.set_content_margin_all(24)
	card.add_theme_stylebox_override("panel", card_style)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	card.add_child(vbox)

	var title: Label = Label.new()
	title.text = "No Event Sheet Open"
	title.add_theme_color_override("font_color", Color(0.80, 0.90, 1.0))
	title.add_theme_font_size_override("font_size", 16)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var body: Label = Label.new()
	body.text = "Create a new Event Sheet to start building event logic."
	body.add_theme_color_override("font_color", Color(0.60, 0.65, 0.70))
	body.add_theme_font_size_override("font_size", 11)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(body)

	var sep: HSeparator = HSeparator.new()
	vbox.add_child(sep)

	var create_btn: Button = Button.new()
	create_btn.text = "Create New Event Sheet"
	create_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	create_btn.connect("pressed", _on_create_new_sheet)
	vbox.add_child(create_btn)

	var open_btn: Button = Button.new()
	open_btn.text = "Open Existing Event Sheet"
	open_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	open_btn.connect("pressed", _on_open_existing_sheet)
	vbox.add_child(open_btn)

	margin.add_child(card)
	_canvas_vbox.add_child(margin)

## Creates a blank in-memory EventSheetResource and loads it into the editor.
func _on_create_new_sheet() -> void:
	_load_sheet(EventSheetResource.new())
	if _sheet_toolbar != null:
		_sheet_toolbar.set_status("Created new Event Sheet")

## Opens a FileDialog so the user can pick an existing EventSheetResource.
func _on_open_existing_sheet() -> void:
	var dialog: FileDialog = FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.access = FileDialog.ACCESS_RESOURCES
	dialog.filters = PackedStringArray(["*.tres ; EventSheetResource", "*.res ; EventSheetResource"])
	dialog.connect("file_selected", func(path: String) -> void:
		var sheet: Variant = load(path)
		if sheet is EventSheetResource:
			_load_sheet(sheet as EventSheetResource)
			if _sheet_toolbar != null:
				_sheet_toolbar.set_status("Opened: %s" % path.get_file())
		else:
			push_warning("[EventForge] Selected file is not an EventSheetResource: %s" % path)
			if _sheet_toolbar != null:
				_sheet_toolbar.set_status("Selected file is not an EventSheetResource", true)
		dialog.queue_free()
	)
	dialog.connect("canceled", func() -> void: dialog.queue_free())
	add_child(dialog)
	dialog.popup_centered(Vector2i(700, 500))

func _on_add_variable_requested() -> void:
	_ensure_sheet()
	if current_sheet == null:
		return
	_open_variable_dialog_for_create()

func _on_add_event_requested() -> void:
	_ensure_sheet()
	if current_sheet == null:
		return
	_open_add_event_picker()

func _on_compile_requested() -> void:
	if current_sheet == null:
		if _sheet_toolbar != null:
			_sheet_toolbar.set_status("Create or open a sheet before compiling", true)
		return

	var result: Dictionary = SheetCompiler.compile(current_sheet, PREVIEW_OUTPUT_PATH)
	var ok: bool = bool(result.get("success", false))
	if _sheet_toolbar != null:
		if ok:
			_sheet_toolbar.set_status("Compiled preview to %s" % PREVIEW_OUTPUT_PATH)
		else:
			var errors: Array = result.get("errors", [])
			var first_error_text: String = str(errors[0]) if not errors.is_empty() else "No error details available"
			_sheet_toolbar.set_status("Compile failed: %s" % first_error_text, true)

func _load_sheet(sheet: EventSheetResource) -> void:
	current_sheet = sheet
	# Avoid stale references in inspector selection when switching sheets.
	_reset_selection_state()
	if is_inside_tree():
		refresh_canvas()
		_show_empty_inspector()
	_refresh_toolbar_state()

func _ensure_sheet() -> void:
	if current_sheet != null:
		return
	_load_sheet(EventSheetResource.new())
	if _sheet_toolbar != null:
		_sheet_toolbar.set_status("Created new Event Sheet")

func _refresh_toolbar_state() -> void:
	if _sheet_toolbar == null:
		return
	_sheet_toolbar.set_sheet_loaded(current_sheet != null)

func _build_ace_picker_popup() -> void:
	_ace_picker_popup = PopupPanel.new()
	_ace_picker_popup.name = "ACEPickerPopup"
	_ace_picker_popup.size = Vector2(520, 420)
	add_child(_ace_picker_popup)

	var wrapper: VBoxContainer = VBoxContainer.new()
	wrapper.custom_minimum_size = Vector2(500, 380)
	wrapper.add_theme_constant_override("separation", 6)
	_ace_picker_popup.add_child(wrapper)

	_ace_picker_title = Label.new()
	_ace_picker_title.add_theme_color_override("font_color", Color(0.80, 0.90, 1.0))
	_ace_picker_title.add_theme_font_size_override("font_size", 14)
	wrapper.add_child(_ace_picker_title)

	_ace_picker_tree = Tree.new()
	_ace_picker_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_ace_picker_tree.hide_root = true
	_ace_picker_tree.select_mode = Tree.SELECT_ROW
	_ace_picker_tree.connect("item_activated", _on_ace_picker_item_activated)
	_ace_picker_tree.connect("item_selected", _on_ace_picker_item_selected)
	wrapper.add_child(_ace_picker_tree)

	_ace_picker_description = Label.new()
	_ace_picker_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ace_picker_description.add_theme_color_override("font_color", Color(0.65, 0.70, 0.78))
	_ace_picker_description.text = "Pick an ACE to add."
	wrapper.add_child(_ace_picker_description)

func _open_add_event_picker() -> void:
	_ace_picker_mode = "new_event"
	_ace_picker_target_row = null
	_ace_picker_target_condition_index = -1
	_show_ace_picker("Add Event", true, true, false)

func _open_add_condition_picker(row: EventRowUI) -> void:
	_ace_picker_mode = "append_condition"
	_ace_picker_target_row = row
	_ace_picker_target_condition_index = -1
	_show_ace_picker("Add Condition", false, true, false)

func _open_replace_condition_picker(row: EventRowUI, index: int) -> void:
	_ace_picker_mode = "replace_condition"
	_ace_picker_target_row = row
	_ace_picker_target_condition_index = index
	_show_ace_picker("Replace Condition", false, true, false)

func _open_add_action_picker(row: EventRowUI) -> void:
	_ace_picker_mode = "append_action"
	_ace_picker_target_row = row
	_ace_picker_target_condition_index = -1
	_show_ace_picker("Add Action", false, false, true)

func _show_ace_picker(title: String, include_triggers: bool, include_conditions: bool, include_actions: bool) -> void:
	if _ace_picker_popup == null:
		return
	_ace_picker_title.text = title
	_ace_picker_description.text = "Pick an ACE to add."
	_populate_ace_picker(include_triggers, include_conditions, include_actions)
	_ace_picker_popup.popup_centered_ratio(0.55)

func _populate_ace_picker(include_triggers: bool, include_conditions: bool, include_actions: bool) -> void:
	if _ace_picker_tree == null:
		return
	_ace_picker_tree.clear()
	var root: TreeItem = _ace_picker_tree.create_item()
	var groups: Dictionary = {}
	if _ace_picker_mode == "new_event":
		# Keep Construct-style sections visible even before all ACE categories are populated.
		for name: String in EVENT_PICKER_GROUPS:
			var section: TreeItem = _ace_picker_tree.create_item(root)
			section.set_text(0, name)
			section.set_selectable(0, false)
			groups[name] = section
	for descriptor: ACEDescriptor in ACERegistry.get_all_descriptors():
		if descriptor == null:
			continue
		if descriptor.ace_type == ACEDescriptor.ACEType.TRIGGER and not include_triggers:
			continue
		if descriptor.ace_type == ACEDescriptor.ACEType.CONDITION and not include_conditions:
			continue
		if descriptor.ace_type == ACEDescriptor.ACEType.ACTION and not include_actions:
			continue
		if descriptor.ace_type == ACEDescriptor.ACEType.EXPRESSION:
			continue
		var group_name: String = _get_picker_group(descriptor)
		if not groups.has(group_name):
			var group_item: TreeItem = _ace_picker_tree.create_item(root)
			group_item.set_text(0, group_name)
			group_item.set_selectable(0, false)
			groups[group_name] = group_item
		var item: TreeItem = _ace_picker_tree.create_item(groups[group_name])
		item.set_text(0, descriptor.get_list_name())
		item.set_tooltip_text(0, descriptor.description if not descriptor.description.is_empty() else descriptor.get_display_text())
		item.set_metadata(0, descriptor)

func _get_picker_group(descriptor: ACEDescriptor) -> String:
	if descriptor.provider_id != "Core":
		return "Custom ACEs"
	if descriptor.ace_type == ACEDescriptor.ACEType.TRIGGER:
		return "Run Context / Triggers"
	var category: String = descriptor.category
	if category.is_empty():
		return "General Conditions" if descriptor.ace_type == ACEDescriptor.ACEType.CONDITION else "General Actions"
	return category

func _on_ace_picker_item_selected() -> void:
	if _ace_picker_tree == null:
		return
	var item: TreeItem = _ace_picker_tree.get_selected()
	if item == null:
		return
	var value: Variant = item.get_metadata(0)
	if value is ACEDescriptor:
		var descriptor: ACEDescriptor = value
		_ace_picker_description.text = descriptor.description if not descriptor.description.is_empty() else descriptor.get_display_text()

func _on_ace_picker_item_activated() -> void:
	if _ace_picker_tree == null:
		return
	var item: TreeItem = _ace_picker_tree.get_selected()
	if item == null:
		return
	var value: Variant = item.get_metadata(0)
	if not (value is ACEDescriptor):
		return
	var descriptor: ACEDescriptor = value
	if _ace_picker_popup != null:
		_ace_picker_popup.hide()
	_open_ace_params_dialog_for_picker_selection(descriptor)

func _build_ace_params_dialog_popup() -> void:
	_ace_params_dialog = ConfirmationDialog.new()
	_ace_params_dialog.title = "ACE Parameters"
	_ace_params_dialog.min_size = Vector2i(320, 0)
	_ace_params_dialog.get_ok_button().text = "Apply"
	_ace_params_dialog.connect("confirmed", _on_ace_params_dialog_confirmed)
	add_child(_ace_params_dialog)

	var body: VBoxContainer = VBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	_ace_params_dialog.add_child(body)

	_ace_params_hint = Label.new()
	_ace_params_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ace_params_hint.add_theme_color_override("font_color", Color(0.65, 0.70, 0.78))
	_ace_params_hint.add_theme_font_size_override("font_size", 11)
	body.add_child(_ace_params_hint)

	_ace_params_form = VBoxContainer.new()
	_ace_params_form.add_theme_constant_override("separation", 6)
	body.add_child(_ace_params_form)

## Called after an ACE is picked. Skips the parameter dialog when the descriptor
## has no params and applies the selection immediately instead.
func _open_ace_params_dialog_for_picker_selection(descriptor: ACEDescriptor) -> void:
	if descriptor == null:
		return
	var params_dialog_mode: String = ""
	match _ace_picker_mode:
		"new_event":
			if descriptor.ace_type == ACEDescriptor.ACEType.TRIGGER:
				params_dialog_mode = "new_event_trigger"
			elif descriptor.ace_type == ACEDescriptor.ACEType.CONDITION:
				params_dialog_mode = "new_event_condition"
		"append_condition":
			params_dialog_mode = "append_condition"
		"replace_condition":
			params_dialog_mode = "replace_condition"
		"append_action":
			params_dialog_mode = "append_action"
	if params_dialog_mode.is_empty():
		return
	# If there are no editable parameters, apply immediately without a dialog.
	if descriptor.params.is_empty():
		_ace_params_mode = params_dialog_mode
		_ace_params_descriptor = descriptor
		_ace_params_target_row = _ace_picker_target_row
		_ace_params_target_index = _ace_picker_target_condition_index
		_apply_ace_params({})
		return
	_open_ace_params_dialog(descriptor, params_dialog_mode, _ace_picker_target_row, _ace_picker_target_condition_index, descriptor.build_default_params())

func _open_condition_params_dialog(row: EventRowUI, index: int) -> void:
	if row == null or row.event_row == null:
		return
	if index < 0 or index >= row.event_row.conditions.size():
		return
	var condition: ACECondition = row.event_row.conditions[index]
	if condition == null:
		return
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor(condition.provider_id, condition.ace_id)
	if descriptor == null:
		return
	var values: Dictionary = _merge_ace_param_values(descriptor, condition.params, condition.parameters)
	_open_ace_params_dialog(descriptor, "edit_condition", row, index, values)

func _open_action_params_dialog(row: EventRowUI, index: int) -> void:
	if row == null or row.event_row == null:
		return
	if index < 0 or index >= row.event_row.actions.size():
		return
	var action_value: Variant = row.event_row.actions[index]
	if not (action_value is ACEAction):
		return
	var action: ACEAction = action_value as ACEAction
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor(action.provider_id, action.ace_id)
	if descriptor == null:
		return
	var values: Dictionary = _merge_ace_param_values(descriptor, action.params, action.parameters)
	_open_ace_params_dialog(descriptor, "edit_action", row, index, values)

func _merge_ace_param_values(descriptor: ACEDescriptor, primary: Dictionary, fallback: Dictionary) -> Dictionary:
	var values: Dictionary = descriptor.build_default_params()
	var source: Dictionary = primary if not primary.is_empty() else fallback
	for key: Variant in source.keys():
		values[key] = source[key]
	return values

func _open_ace_params_dialog(descriptor: ACEDescriptor, mode: String, row: EventRowUI, index: int, values: Dictionary) -> void:
	if _ace_params_dialog == null or _ace_params_form == null or descriptor == null:
		return
	_ace_params_mode = mode
	_ace_params_descriptor = descriptor
	_ace_params_target_row = row
	_ace_params_target_index = index
	_ace_params_existing_values = values.duplicate(true)
	_ace_params_fields.clear()

	# Remove children immediately so reset_size works correctly.
	for child: Node in _ace_params_form.get_children():
		_ace_params_form.remove_child(child)
		child.queue_free()

	_ace_params_dialog.title = "%s Parameters" % descriptor.get_list_name()
	_ace_params_hint.text = descriptor.description if not descriptor.description.is_empty() else descriptor.get_display_text()

	if descriptor.params.is_empty():
		var no_params: Label = Label.new()
		no_params.text = "No parameters for this ACE. Confirm to apply."
		no_params.add_theme_color_override("font_color", Color(0.55, 0.55, 0.60))
		_ace_params_form.add_child(no_params)
	else:
		for param: ACEParam in descriptor.params:
			if param == null:
				continue
			var key: String = param.id if not param.id.is_empty() else param.name
			if key.is_empty():
				continue
			# Form row: label on the left, input filling the right.
			var row_box: HBoxContainer = HBoxContainer.new()
			row_box.add_theme_constant_override("separation", 8)

			var label: Label = Label.new()
			label.text = param.get_param_name() + ":"
			label.custom_minimum_size = Vector2(86, 0)
			label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			label.add_theme_font_size_override("font_size", 12)
			row_box.add_child(label)

			var input: Control = _create_ace_param_input(param, _ace_params_existing_values.get(key, param.get_initial_value()))
			input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row_box.add_child(input)
			_ace_params_fields[key] = {
				"param": param,
				"input": input
			}

			_ace_params_form.add_child(row_box)

	# Disable OK if any variable_reference field has no available variables.
	var needs_vars: bool = false
	for key: Variant in _ace_params_fields.keys():
		var entry: Variant = _ace_params_fields[key]
		if not (entry is Dictionary):
			continue
		var param: ACEParam = (entry as Dictionary).get("param")
		if param != null and param.hint == "variable_reference" and _get_available_variable_names().is_empty():
			needs_vars = true
			break
	if needs_vars:
		var warn: Label = Label.new()
		warn.text = "⚠ No variables available. Add a variable first."
		warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		warn.add_theme_color_override("font_color", Color(1.0, 0.75, 0.35))
		warn.add_theme_font_size_override("font_size", 11)
		_ace_params_form.add_child(warn)
	_ace_params_dialog.get_ok_button().disabled = needs_vars

	_ace_params_dialog.reset_size()
	_ace_params_dialog.popup_centered()

## Creates an appropriate UI control for the given ACE parameter.
## Control type is chosen based on type_name, hint, and options metadata:
##   hint == "variable_reference"      → variable dropdown
##   type_name bool/boolean             → bool OptionButton
##   type_name int/integer              → integer SpinBox
##   type_name float/double             → float SpinBox
##   options[] non-empty               → enum OptionButton
##   (fallback)                         → LineEdit
func _create_ace_param_input(param: ACEParam, value: Variant) -> Control:
	# Variable reference — show a dropdown of sheet variables.
	if param.hint == "variable_reference":
		return _create_variable_dropdown(str(value))
	var type_name: String = param.type_name.to_lower()
	if type_name in ["bool", "boolean"] or param.type == TYPE_BOOL:
		var bool_input: OptionButton = OptionButton.new()
		bool_input.add_item("False")
		bool_input.add_item("True")
		bool_input.select(1 if bool(value) else 0)
		return bool_input
	if type_name in ["int", "integer"] or param.type == TYPE_INT:
		var spin: SpinBox = SpinBox.new()
		spin.step = 1.0
		spin.allow_lesser = true
		spin.allow_greater = true
		var v: float = float(str(value)) if str(value).is_valid_float() else 0.0
		spin.value = v
		return spin
	if type_name in ["float", "double"] or param.type == TYPE_FLOAT:
		var spin: SpinBox = SpinBox.new()
		spin.step = 0.01
		spin.allow_lesser = true
		spin.allow_greater = true
		var v: float = float(str(value)) if str(value).is_valid_float() else 0.0
		spin.value = v
		return spin
	if not param.options.is_empty():
		var option_input: OptionButton = OptionButton.new()
		for item: String in param.options:
			option_input.add_item(item)
		var wanted: String = str(value)
		for i: int in range(option_input.item_count):
			if option_input.get_item_text(i) == wanted:
				option_input.select(i)
				break
		return option_input
	var line_input: LineEdit = LineEdit.new()
	line_input.text = str(value)
	return line_input

## Creates a variable-name dropdown pre-populated with sheet variables.
## Shows a disabled placeholder when no variables exist, so the user knows
## they need to create a variable before using this ACE.
func _create_variable_dropdown(current_value: String) -> OptionButton:
	var option: OptionButton = OptionButton.new()
	var var_names: Array[String] = _get_available_variable_names()
	if var_names.is_empty():
		option.add_item("(no variables)")
		option.set_item_disabled(0, true)
		option.select(0)
		return option
	var selected_idx: int = 0
	for i: int in range(var_names.size()):
		option.add_item(var_names[i])
		if var_names[i] == current_value:
			selected_idx = i
	option.select(selected_idx)
	return option

## Returns a sorted list of variable names available in the current sheet.
func _get_available_variable_names() -> Array[String]:
	var names: Array[String] = []
	if current_sheet == null:
		return names
	for key: Variant in current_sheet.variables.keys():
		names.append(str(key))
	names.sort()
	return names

func _collect_ace_param_values() -> Dictionary:
	var output: Dictionary = {}
	for key: Variant in _ace_params_fields.keys():
		var entry_dict: Variant = _ace_params_fields[key]
		if not (entry_dict is Dictionary):
			continue
		var entry: Dictionary = entry_dict as Dictionary
		var typed_param: ACEParam = entry.get("param")
		if typed_param == null:
			continue
		var input_control: Variant = entry.get("input")
		var input: Control = input_control as Control
		output[str(key)] = _extract_ace_param_input_value(typed_param, input)
	return output

func _extract_ace_param_input_value(param: ACEParam, input: Control) -> Variant:
	if input == null:
		return param.get_initial_value()
	if input is SpinBox:
		var spin: SpinBox = input as SpinBox
		var type_name: String = param.type_name.to_lower()
		if type_name in ["int", "integer"] or param.type == TYPE_INT:
			return int(spin.value)
		return spin.value
	if input is OptionButton:
		var option: OptionButton = input as OptionButton
		if _is_bool_param(param):
			return option.selected == 1
		var selected: int = option.selected
		if selected < 0:
			selected = option.get_selected_id()
		if selected < 0:
			return ""
		return option.get_item_text(selected)
	if input is LineEdit:
		var text: String = (input as LineEdit).text.strip_edges()
		var type_name: String = param.type_name.to_lower()
		if type_name in ["int", "integer"] or param.type == TYPE_INT:
			return int(text) if text.is_valid_int() else 0
		if type_name in ["float", "double"] or param.type == TYPE_FLOAT:
			return float(text) if text.is_valid_float() else 0.0
		if _is_bool_param(param):
			var lower: String = text.to_lower()
			return lower in ["1", "true", "yes", "on"]
		return text
	return param.get_initial_value()

func _is_bool_param(param: ACEParam) -> bool:
	return param.type == TYPE_BOOL or param.type_name.to_lower() in ["bool", "boolean"]

func _on_ace_params_dialog_confirmed() -> void:
	if _ace_params_descriptor == null:
		return
	var values: Dictionary = _collect_ace_param_values()
	_apply_ace_params(values)

func _apply_ace_params(values: Dictionary) -> void:
	if _ace_params_descriptor == null:
		return
	match _ace_params_mode:
		"new_event_trigger":
			_create_event_with_trigger(_ace_params_descriptor, values)
		"new_event_condition":
			_create_event_with_condition(_ace_params_descriptor, values)
		"append_condition":
			_append_condition_with_params(_ace_params_descriptor, values)
		"replace_condition":
			_replace_condition_with_params(_ace_params_descriptor, _ace_params_target_index, values)
		"append_action":
			_append_action_with_params(_ace_params_descriptor, values)
		"edit_condition":
			_edit_condition_params(_ace_params_target_index, values)
		"edit_action":
			_edit_action_params(_ace_params_target_index, values)

func _create_event_with_trigger(descriptor: ACEDescriptor, params: Dictionary) -> void:
	_ensure_sheet()
	if current_sheet == null or descriptor == null:
		return
	var new_event: EventRow = EventRow.new()
	new_event.trigger_provider_id = descriptor.provider_id
	new_event.trigger_id = descriptor.ace_id
	new_event.trigger_params = params.duplicate(true)
	current_sheet.events.append(new_event)
	refresh_canvas()
	_focus_event_by_uid(new_event.event_uid)
	if _sheet_toolbar != null:
		_sheet_toolbar.set_status("Added event: %s" % descriptor.get_list_name())

func _create_event_with_condition(descriptor: ACEDescriptor, params: Dictionary) -> void:
	_ensure_sheet()
	if current_sheet == null or descriptor == null:
		return
	var new_event: EventRow = EventRow.new()
	new_event.trigger_provider_id = "Core"
	new_event.trigger_id = DEFAULT_RUN_CONTEXT_ACE_ID
	var condition: ACECondition = ACECondition.new()
	condition.provider_id = descriptor.provider_id
	condition.ace_id = descriptor.ace_id
	_set_condition_params(condition, params)
	new_event.conditions.append(condition)
	current_sheet.events.append(new_event)
	refresh_canvas()
	_focus_event_by_uid(new_event.event_uid)
	if _sheet_toolbar != null:
		_sheet_toolbar.set_status("Added event: %s" % descriptor.get_list_name())

func _append_condition_with_params(descriptor: ACEDescriptor, params: Dictionary) -> void:
	var row: EventRowUI = _ace_params_target_row
	if row == null or row.event_row == null or descriptor == null:
		return
	var condition: ACECondition = ACECondition.new()
	condition.provider_id = descriptor.provider_id
	condition.ace_id = descriptor.ace_id
	_set_condition_params(condition, params)
	row.event_row.conditions.append(condition)
	row.refresh()
	_rebuild_inspector_event(row)

func _replace_condition_with_params(descriptor: ACEDescriptor, index: int, params: Dictionary) -> void:
	var row: EventRowUI = _ace_params_target_row
	if row == null or row.event_row == null or descriptor == null:
		return
	if index < 0 or index >= row.event_row.conditions.size():
		return
	var condition: ACECondition = ACECondition.new()
	condition.provider_id = descriptor.provider_id
	condition.ace_id = descriptor.ace_id
	_set_condition_params(condition, params)
	row.event_row.conditions[index] = condition
	row.refresh()
	_rebuild_inspector_event(row)

func _append_action_with_params(descriptor: ACEDescriptor, params: Dictionary) -> void:
	var row: EventRowUI = _ace_params_target_row
	if row == null or row.event_row == null or descriptor == null:
		return
	var action: ACEAction = ACEAction.new()
	action.provider_id = descriptor.provider_id
	action.ace_id = descriptor.ace_id
	_set_action_params(action, params)
	row.event_row.actions.append(action)
	row.refresh()
	_rebuild_inspector_event(row)

func _edit_condition_params(index: int, params: Dictionary) -> void:
	var row: EventRowUI = _ace_params_target_row
	if row == null or row.event_row == null:
		return
	if index < 0 or index >= row.event_row.conditions.size():
		return
	var condition: ACECondition = row.event_row.conditions[index]
	if condition == null:
		return
	_set_condition_params(condition, params)
	row.refresh()
	_rebuild_inspector_event(row)

func _edit_action_params(index: int, params: Dictionary) -> void:
	var row: EventRowUI = _ace_params_target_row
	if row == null or row.event_row == null:
		return
	if index < 0 or index >= row.event_row.actions.size():
		return
	var item: Variant = row.event_row.actions[index]
	if not (item is ACEAction):
		return
	var action: ACEAction = item as ACEAction
	_set_action_params(action, params)
	row.refresh()
	_rebuild_inspector_event(row)

func _set_condition_params(condition: ACECondition, params: Dictionary) -> void:
	if condition == null:
		return
	condition.params = params.duplicate(true)
	condition.parameters = condition.params.duplicate(true)

func _set_action_params(action: ACEAction, params: Dictionary) -> void:
	if action == null:
		return
	action.params = params.duplicate(true)
	action.parameters = action.params.duplicate(true)

func _generate_unique_variable_name() -> String:
	var base: String = "var_"
	var index: int = 1
	while current_sheet.variables.has("%s%d" % [base, index]):
		index += 1
	return "%s%d" % [base, index]

func _make_default_variable_descriptor() -> Dictionary:
	return {
		"type": "int",
		"default": 0,
		"exported": true
	}

func _build_variable_dialog_popup() -> void:
	_variable_dialog = ConfirmationDialog.new()
	_variable_dialog.title = "Variable"
	_variable_dialog.min_size = Vector2i(360, 0)
	_variable_dialog.get_ok_button().text = "Save"
	_variable_dialog.connect("confirmed", _on_variable_dialog_confirmed)
	add_child(_variable_dialog)

	var body: VBoxContainer = VBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	_variable_dialog.add_child(body)

	var name_row: HBoxContainer = HBoxContainer.new()
	var name_label: Label = Label.new()
	name_label.text = "Name"
	name_label.custom_minimum_size = Vector2(90, 0)
	name_row.add_child(name_label)
	_variable_name_edit = LineEdit.new()
	_variable_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(_variable_name_edit)
	body.add_child(name_row)

	var type_row: HBoxContainer = HBoxContainer.new()
	var type_label: Label = Label.new()
	type_label.text = "Type"
	type_label.custom_minimum_size = Vector2(90, 0)
	type_row.add_child(type_label)
	_variable_type_option = OptionButton.new()
	_variable_type_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for type_name: String in ["int", "float", "bool", "String", "Variant"]:
		_variable_type_option.add_item(type_name)
	type_row.add_child(_variable_type_option)
	body.add_child(type_row)

	var initial_row: HBoxContainer = HBoxContainer.new()
	var initial_label: Label = Label.new()
	initial_label.text = "Initial value"
	initial_label.custom_minimum_size = Vector2(90, 0)
	initial_row.add_child(initial_label)
	_variable_initial_edit = LineEdit.new()
	_variable_initial_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	initial_row.add_child(_variable_initial_edit)
	body.add_child(initial_row)

	var description_row: HBoxContainer = HBoxContainer.new()
	var description_label: Label = Label.new()
	description_label.text = "Description"
	description_label.custom_minimum_size = Vector2(90, 0)
	description_row.add_child(description_label)
	_variable_description_edit = LineEdit.new()
	_variable_description_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	description_row.add_child(_variable_description_edit)
	body.add_child(description_row)

func _open_variable_dialog_for_create() -> void:
	if _variable_dialog == null:
		return
	_variable_dialog_mode = "create"
	_variable_dialog_original_name = ""
	_variable_dialog.title = "Create Variable"
	_variable_name_edit.text = _generate_unique_variable_name()
	_select_variable_type("int")
	_variable_initial_edit.text = "0"
	_variable_description_edit.text = ""
	_variable_dialog.popup_centered()
	_variable_name_edit.grab_focus()
	_variable_name_edit.select_all()

func _open_variable_dialog_for_edit(var_name: String, var_info: Dictionary) -> void:
	if _variable_dialog == null:
		return
	_variable_dialog_mode = "edit"
	_variable_dialog_original_name = var_name
	_variable_dialog.title = "Edit Variable"
	_variable_name_edit.text = var_name
	_select_variable_type(str(var_info.get("type", "Variant")))
	_variable_initial_edit.text = str(var_info.get("default", var_info.get("value", "")))
	_variable_description_edit.text = str(var_info.get("description", ""))
	_variable_dialog.popup_centered()
	_variable_name_edit.grab_focus()
	_variable_name_edit.select_all()

func _select_variable_type(type_name: String) -> void:
	if _variable_type_option == null:
		return
	for i: int in range(_variable_type_option.item_count):
		if _variable_type_option.get_item_text(i) == type_name:
			_variable_type_option.select(i)
			return
	_variable_type_option.add_item(type_name)
	_variable_type_option.select(_variable_type_option.item_count - 1)

func _get_selected_variable_type() -> String:
	if _variable_type_option == null or _variable_type_option.item_count == 0:
		return "Variant"
	var selected: int = _variable_type_option.get_selected_id()
	if selected < 0:
		selected = _variable_type_option.selected
	if selected < 0:
		return "Variant"
	return _variable_type_option.get_item_text(selected)

func _on_variable_dialog_confirmed() -> void:
	if current_sheet == null:
		return
	var new_name: String = _variable_name_edit.text.strip_edges()
	if new_name.is_empty():
		if _sheet_toolbar != null:
			_sheet_toolbar.set_status("Variable name cannot be empty", true)
		return
	var is_editing: bool = _variable_dialog_mode == "edit"
	if current_sheet.variables.has(new_name) and (not is_editing or new_name != _variable_dialog_original_name):
		if _sheet_toolbar != null:
			_sheet_toolbar.set_status("Variable name already exists: %s" % new_name, true)
		return

	var target_descriptor: Dictionary = {}
	if is_editing and current_sheet.variables.has(_variable_dialog_original_name):
		var existing: Variant = current_sheet.variables[_variable_dialog_original_name]
		if existing is Dictionary:
			target_descriptor = (existing as Dictionary).duplicate(true)
	if target_descriptor.is_empty():
		target_descriptor = _make_default_variable_descriptor().duplicate(true)

	var selected_type: String = _get_selected_variable_type()
	target_descriptor["type"] = selected_type
	target_descriptor["default"] = _parse_variable_initial_value(_variable_initial_edit.text, selected_type)
	target_descriptor["description"] = _variable_description_edit.text.strip_edges()
	if not target_descriptor.has("exported"):
		target_descriptor["exported"] = true

	if is_editing and current_sheet.variables.has(_variable_dialog_original_name) and _variable_dialog_original_name != new_name:
		current_sheet.variables.erase(_variable_dialog_original_name)
	current_sheet.variables[new_name] = target_descriptor

	refresh_canvas()
	_focus_variable_by_name(new_name)
	if _sheet_toolbar != null:
		if is_editing:
			_sheet_toolbar.set_status("Updated variable: %s" % new_name)
		else:
			_sheet_toolbar.set_status("Added variable: %s" % new_name)

func _parse_variable_initial_value(raw_text: String, type_name: String) -> Variant:
	var text: String = raw_text.strip_edges()
	match type_name:
		"int":
			if text.is_empty():
				return 0
			return int(text)
		"float":
			if text.is_empty():
				return 0.0
			return float(text)
		"bool":
			if text.is_empty():
				return false
			var lower: String = text.to_lower()
			return lower in ["1", "true", "yes", "on"]
		"String", "StringName":
			return text
		_:
			if text.is_empty():
				return null
			return text

func _focus_event_by_uid(event_uid: String) -> void:
	var row_ui: EventRowUI = _find_event_row_ui_by_uid(_canvas_vbox, event_uid)
	if row_ui != null:
		_on_event_selected(row_ui)

func _focus_variable_by_name(var_name: String) -> void:
	var row_ui: VariableRowUI = _find_variable_row_ui_by_name(_canvas_vbox, var_name)
	if row_ui != null:
		_suppress_variable_popup_on_select = true
		_on_variable_selected(row_ui)
		_suppress_variable_popup_on_select = false

func _focus_group_by_uid(group_uid: String) -> void:
	if group_uid.is_empty():
		return
	var row_ui: GroupRowUI = _find_group_row_ui_by_uid(_canvas_vbox, group_uid)
	if row_ui != null:
		_on_group_selected(row_ui)

func _find_event_row_ui_by_uid(node: Node, event_uid: String) -> EventRowUI:
	if node is EventRowUI:
		var row_ui: EventRowUI = node as EventRowUI
		if row_ui.event_row != null and row_ui.event_row.event_uid == event_uid:
			return row_ui
	for child: Node in node.get_children():
		var nested: EventRowUI = _find_event_row_ui_by_uid(child, event_uid)
		if nested != null:
			return nested
	return null

func _find_variable_row_ui_by_name(node: Node, var_name: String) -> VariableRowUI:
	if node is VariableRowUI:
		var row_ui: VariableRowUI = node as VariableRowUI
		if row_ui.var_name == var_name:
			return row_ui
	for child: Node in node.get_children():
		var nested: VariableRowUI = _find_variable_row_ui_by_name(child, var_name)
		if nested != null:
			return nested
	return null

func _find_group_row_ui_by_uid(node: Node, group_uid: String) -> GroupRowUI:
	if node is GroupRowUI:
		var row_ui: GroupRowUI = node as GroupRowUI
		if row_ui.event_group != null and row_ui.event_group.group_uid == group_uid:
			return row_ui
	for child: Node in node.get_children():
		var nested: GroupRowUI = _find_group_row_ui_by_uid(child, group_uid)
		if nested != null:
			return nested
	return null

func _add_document_header() -> void:
	var header_panel: PanelContainer = PanelContainer.new()
	var hstyle: StyleBoxFlat = StyleBoxFlat.new()
	hstyle.bg_color = Color(0.15, 0.17, 0.22, 1.0)
	hstyle.border_color = Color(0.35, 0.50, 0.80, 1.0)
	hstyle.set_border_width_all(0)
	hstyle.border_width_bottom = 2
	hstyle.set_content_margin_all(10)
	header_panel.add_theme_stylebox_override("panel", hstyle)

	var title: Label = Label.new()
	title.text = "Event Sheet Document"
	title.add_theme_color_override("font_color", Color(0.70, 0.85, 1.0))
	title.add_theme_font_size_override("font_size", 14)
	header_panel.add_child(title)
	_canvas_vbox.add_child(header_panel)

func _add_section_heading(text: String) -> void:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color(0.65, 0.65, 0.70))
	label.add_theme_font_size_override("font_size", 11)
	_canvas_vbox.add_child(label)

	var sep: HSeparator = HSeparator.new()
	_canvas_vbox.add_child(sep)

func _add_variables_section() -> void:
	_add_section_heading("Global Variables")

	var variables: Dictionary = current_sheet.variables
	if variables.is_empty():
		var hint: Label = Label.new()
		hint.text = "No global variables yet. Use 'Add Variable' in the toolbar to create one."
		hint.add_theme_color_override("font_color", Color(0.50, 0.60, 0.50))
		hint.add_theme_font_size_override("font_size", 11)
		_canvas_vbox.add_child(hint)
		return

	var sorted_keys: Array = variables.keys()
	sorted_keys.sort()
	for key: Variant in sorted_keys:
		var row: VariableRowUI = VariableRowUI.new()
		row.var_name = str(key)
		row.var_info = variables[key] if variables[key] is Dictionary else {}
		row.refresh()
		row.variable_selected.connect(_on_variable_selected)
		_canvas_vbox.add_child(row)

func _add_events_section() -> void:
	_add_section_heading("Events")

	if current_sheet.events.is_empty():
		var hint: Label = Label.new()
		hint.text = "No events yet. Click + Add Event to pick a run context or condition."
		hint.add_theme_color_override("font_color", Color(0.50, 0.50, 0.60))
		hint.add_theme_font_size_override("font_size", 11)
		_canvas_vbox.add_child(hint)
	else:
		for resource: Variant in current_sheet.events:
			_add_event_resource(resource, 0)

	# Inline "Add Event" at the bottom of the events area — mirrors the
	# per-row "Add Action" / "Add Condition" affordance pattern.
	var add_event_btn: Button = Button.new()
	add_event_btn.text = "+ Add Event"
	add_event_btn.flat = true
	add_event_btn.tooltip_text = "Add a new event block to the sheet"
	add_event_btn.custom_minimum_size = Vector2(120, 0)
	add_event_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	add_event_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_event_btn.add_theme_color_override("font_color", Color(0.65, 0.78, 1.0))
	add_event_btn.connect("pressed", _on_add_event_requested)
	_canvas_vbox.add_child(add_event_btn)

func _add_event_resource(resource: Variant, indent_level: int) -> void:
	if resource is EventRow:
		_add_event_row(resource as EventRow, indent_level)
	elif resource is EventGroup:
		_add_group_row(resource as EventGroup, indent_level)

func _add_event_row(event_row: EventRow, indent_level: int = 0) -> void:
	var row_ui: EventRowUI = EventRowUI.new()
	row_ui.event_row = event_row
	row_ui.refresh()
	row_ui.event_selected.connect(_on_event_selected)
	row_ui.condition_selected.connect(_on_condition_selected)
	row_ui.condition_edit_requested.connect(_on_condition_edit_requested)
	row_ui.condition_add_another_requested.connect(_on_condition_add_another_requested)
	row_ui.condition_replace_requested.connect(_on_condition_replace_requested)
	row_ui.condition_invert_requested.connect(_on_condition_invert_requested)
	row_ui.action_selected.connect(_on_action_selected)
	row_ui.add_condition_requested.connect(_on_row_add_condition_requested)
	row_ui.add_action_requested.connect(_on_row_add_action_requested)
	_add_canvas_row(row_ui, indent_level)

	# Render existing sub-events indented below this row, preparing the layout
	# for future sub-event authoring without implementing drag/drop or nesting UI.
	for sub_resource: Variant in event_row.sub_events:
		_add_event_resource(sub_resource, indent_level + 1)

func _add_group_row(event_group: EventGroup, indent_level: int = 0) -> void:
	var row_ui: GroupRowUI = GroupRowUI.new()
	row_ui.event_group = event_group
	row_ui.refresh()
	row_ui.group_selected.connect(_on_group_selected)
	row_ui.group_collapsed_toggled.connect(_on_group_collapsed_toggled)
	_add_canvas_row(row_ui, indent_level)

	if _is_group_collapsed(event_group):
		return

	var child_rows: Array = event_group.events if not event_group.events.is_empty() else event_group.rows
	for child: Variant in child_rows:
		_add_event_resource(child, indent_level + 1)

func _add_canvas_row(row: Control, indent_level: int) -> void:
	if row == null:
		return
	if indent_level <= 0:
		_canvas_vbox.add_child(row)
		return
	var margin: MarginContainer = MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 20 * indent_level)
	margin.add_child(row)
	_canvas_vbox.add_child(margin)

# ── Selection handlers ────────────────────────────────────────────────────────

func _on_event_selected(row: EventRowUI) -> void:
	_selected_entry_kind = "event"
	_selected_row = row
	_selected_index = -1
	_rebuild_inspector_event(row)

func _on_condition_selected(row: EventRowUI, index: int) -> void:
	_selected_entry_kind = "condition"
	_selected_row = row
	_selected_index = index
	_open_condition_params_dialog(row, index)

func _on_condition_edit_requested(row: EventRowUI, index: int) -> void:
	_on_condition_selected(row, index)

func _on_condition_add_another_requested(row: EventRowUI, _index: int) -> void:
	if row == null or row.event_row == null:
		return
	_selected_entry_kind = "event"
	_selected_row = row
	_selected_index = -1
	_open_add_condition_picker(row)

func _on_condition_replace_requested(row: EventRowUI, index: int) -> void:
	if row == null or row.event_row == null:
		return
	if index < 0 or index >= row.event_row.conditions.size():
		return
	_selected_entry_kind = "condition"
	_selected_row = row
	_selected_index = index
	_open_replace_condition_picker(row, index)

## Toggles the negated flag on the condition at the given index.
func _on_condition_invert_requested(row: EventRowUI, index: int) -> void:
	if row == null or row.event_row == null:
		return
	if index < 0 or index >= row.event_row.conditions.size():
		return
	var condition: ACECondition = row.event_row.conditions[index]
	if condition == null:
		return
	condition.negated = not condition.negated
	row.refresh()
	_rebuild_inspector_event(row)

func _on_action_selected(row: EventRowUI, index: int) -> void:
	_selected_entry_kind = "action"
	_selected_row = row
	_selected_index = index
	_open_action_params_dialog(row, index)

func _on_row_add_condition_requested(row: EventRowUI) -> void:
	if row == null or row.event_row == null:
		return
	_selected_entry_kind = "event"
	_selected_row = row
	_selected_index = -1
	_open_add_condition_picker(row)

func _on_row_add_action_requested(row: EventRowUI) -> void:
	if row == null or row.event_row == null:
		return
	_selected_entry_kind = "event"
	_selected_row = row
	_selected_index = -1
	_open_add_action_picker(row)

func _on_variable_selected(row: VariableRowUI) -> void:
	_selected_entry_kind = "variable"
	_selected_row = row
	_selected_variable_name = row.var_name
	_rebuild_inspector_variable(row)
	if _suppress_variable_popup_on_select:
		return
	if _variable_dialog != null and _variable_dialog.visible:
		return
	_open_variable_dialog_for_edit(row.var_name, row.var_info)

func _on_group_selected(row: GroupRowUI) -> void:
	_selected_entry_kind = "group"
	_selected_row = row
	_selected_group = row
	_rebuild_inspector_group(row)

func _on_group_collapsed_toggled(row: GroupRowUI, _collapsed: bool) -> void:
	if row == null or row.event_group == null:
		return
	var group_uid: String = row.event_group.group_uid
	refresh_canvas()
	_focus_group_by_uid(group_uid)

func _is_group_collapsed(event_group: EventGroup) -> bool:
	if event_group == null:
		return false
	return event_group.is_collapsed()

# ── Inspector builders ────────────────────────────────────────────────────────

func _clear_inspector() -> void:
	for child in _inspector_vbox.get_children():
		child.queue_free()

func _reset_selection_state() -> void:
	_selected_entry_kind = "none"
	_selected_row = null
	_selected_index = -1
	_selected_variable_name = ""
	_selected_group = null

func _show_empty_inspector() -> void:
	_clear_inspector()
	_reset_selection_state()
	var hint: Label = Label.new()
	if current_sheet == null:
		hint.text = "Create or open an event sheet to start editing."
	else:
		hint.text = "Select an event, condition, action, variable, or group to edit it."
	hint.add_theme_color_override("font_color", Color(0.45, 0.45, 0.45))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_inspector_vbox.add_child(hint)

## Rebuilds the inspector to show a compact event summary.
## Primary editing is handled through event block lanes and popups.
func _rebuild_inspector_event(row: EventRowUI) -> void:
	_clear_inspector()
	if row == null or row.event_row == null:
		_show_empty_inspector()
		return

	var event_row: EventRow = row.event_row

	var heading: Label = Label.new()
	heading.text = "Event"
	heading.add_theme_color_override("font_color", Color(0.55, 0.78, 1.0))
	heading.add_theme_font_size_override("font_size", 12)
	_inspector_vbox.add_child(heading)

	var runs_lbl: Label = Label.new()
	runs_lbl.text = EventRowUI.format_run_context(event_row)
	runs_lbl.add_theme_color_override("font_color", Color(0.85, 0.75, 0.45))
	runs_lbl.add_theme_font_size_override("font_size", 10)
	runs_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_inspector_vbox.add_child(runs_lbl)

	_inspector_vbox.add_child(HSeparator.new())

	var summary: Label = Label.new()
	summary.text = "%d condition(s)  ·  %d action(s)" % [event_row.conditions.size(), event_row.actions.size()]
	summary.add_theme_color_override("font_color", Color(0.65, 0.70, 0.75))
	summary.add_theme_font_size_override("font_size", 10)
	_inspector_vbox.add_child(summary)

	var authoring_note: Label = Label.new()
	authoring_note.text = "Edit via event block."
	authoring_note.add_theme_color_override("font_color", Color(0.40, 0.45, 0.50))
	authoring_note.add_theme_font_size_override("font_size", 10)
	authoring_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_inspector_vbox.add_child(authoring_note)

## Rebuilds the inspector for a selected variable.
## The popup dialog is the primary editing path (clicking the row opens it).
func _rebuild_inspector_variable(row: VariableRowUI) -> void:
	_clear_inspector()
	if row == null:
		_show_empty_inspector()
		return

	var heading: Label = Label.new()
	heading.text = "Variable"
	heading.add_theme_color_override("font_color", Color(0.35, 0.95, 0.55))
	heading.add_theme_font_size_override("font_size", 12)
	_inspector_vbox.add_child(heading)

	var summary: Label = Label.new()
	summary.text = VariableRowUI.format_summary(row.var_name, row.var_info)
	summary.add_theme_color_override("font_color", Color(0.80, 0.90, 0.80))
	summary.add_theme_font_size_override("font_size", 10)
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_inspector_vbox.add_child(summary)

	var note: Label = Label.new()
	note.text = "Click the row to edit."
	note.add_theme_color_override("font_color", Color(0.40, 0.50, 0.40))
	note.add_theme_font_size_override("font_size", 10)
	_inspector_vbox.add_child(note)

func _rebuild_inspector_group(row: GroupRowUI) -> void:
	_clear_inspector()
	if row == null or row.event_group == null:
		_show_empty_inspector()
		return

	var event_group: EventGroup = row.event_group

	var heading: Label = Label.new()
	var display_name: String = event_group.name
	if display_name.is_empty():
		display_name = event_group.group_name
	heading.text = "Group: " + (display_name if not display_name.is_empty() else "(unnamed)")
	heading.add_theme_color_override("font_color", Color(0.80, 0.50, 1.0))
	heading.add_theme_font_size_override("font_size", 12)
	_inspector_vbox.add_child(heading)

	var desc_lbl: Label = Label.new()
	desc_lbl.text = "Description: " + (event_group.description if not event_group.description.is_empty() else "(none)")
	desc_lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.80))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_inspector_vbox.add_child(desc_lbl)

	var enabled_lbl: Label = Label.new()
	enabled_lbl.text = "Enabled: %s" % str(event_group.enabled)
	_inspector_vbox.add_child(enabled_lbl)

	var collapsed_lbl: Label = Label.new()
	collapsed_lbl.text = "Collapsed: %s" % str(_is_group_collapsed(event_group))
	_inspector_vbox.add_child(collapsed_lbl)

	var sep: HSeparator = HSeparator.new()
	_inspector_vbox.add_child(sep)

	var planned_note: Label = Label.new()
	planned_note.text = "Nested local variables and group event bodies are planned."
	planned_note.add_theme_color_override("font_color", Color(0.50, 0.45, 0.60))
	planned_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_inspector_vbox.add_child(planned_note)
