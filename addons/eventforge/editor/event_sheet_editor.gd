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
## One of: "new_event", "append_condition", "append_action"
var _ace_picker_mode: String = ""
var _ace_picker_target_row: EventRowUI = null

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
	_canvas_vbox.add_theme_constant_override("separation", 8)
	_canvas_vbox.set("custom_minimum_size", Vector2(0, 0))
	_scroll.add_child(_canvas_vbox)

	# ── Vertical separator ────────────────────────────────────────────────────
	var vsep: VSeparator = VSeparator.new()
	hbox.add_child(vsep)

	# ── Right: inspector panel ────────────────────────────────────────────────
	_inspector_panel = PanelContainer.new()
	_inspector_panel.custom_minimum_size = Vector2(260, 0)
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

	var var_name: String = _generate_unique_variable_name()
	current_sheet.variables[var_name] = _make_default_variable_descriptor()
	refresh_canvas()
	_focus_variable_by_name(var_name)
	if _sheet_toolbar != null:
		_sheet_toolbar.set_status("Added variable: %s" % var_name)

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
	_show_ace_picker("Add Event", true, true, false)

func _open_add_condition_picker(row: EventRowUI) -> void:
	_ace_picker_mode = "append_condition"
	_ace_picker_target_row = row
	_show_ace_picker("Add Condition", false, true, false)

func _open_add_action_picker(row: EventRowUI) -> void:
	_ace_picker_mode = "append_action"
	_ace_picker_target_row = row
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
	if category == "Signals / Scene":
		return "Signals / Scene / Input"
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
	match _ace_picker_mode:
		"new_event":
			_create_event_from_descriptor(descriptor)
		"append_condition":
			_append_condition_from_descriptor(descriptor)
		"append_action":
			_append_action_from_descriptor(descriptor)
	if _ace_picker_popup != null:
		_ace_picker_popup.hide()

func _create_event_from_descriptor(descriptor: ACEDescriptor) -> void:
	_ensure_sheet()
	if current_sheet == null or descriptor == null:
		return
	var new_event: EventRow = EventRow.new()
	if descriptor.ace_type == ACEDescriptor.ACEType.TRIGGER:
		new_event.trigger_provider_id = descriptor.provider_id
		new_event.trigger_id = descriptor.ace_id
		new_event.trigger_params = descriptor.build_default_params()
	elif descriptor.ace_type == ACEDescriptor.ACEType.CONDITION:
		new_event.trigger_provider_id = "Core"
		new_event.trigger_id = DEFAULT_RUN_CONTEXT_ACE_ID
		var condition: ACECondition = ACECondition.new()
		condition.provider_id = descriptor.provider_id
		condition.ace_id = descriptor.ace_id
		condition.params = descriptor.build_default_params()
		new_event.conditions.append(condition)
	else:
		new_event.trigger_provider_id = "Core"
		new_event.trigger_id = DEFAULT_RUN_CONTEXT_ACE_ID
	current_sheet.events.append(new_event)
	refresh_canvas()
	_focus_event_by_uid(new_event.event_uid)
	if _sheet_toolbar != null:
		_sheet_toolbar.set_status("Added event: %s" % descriptor.get_list_name())

func _append_condition_from_descriptor(descriptor: ACEDescriptor) -> void:
	var row: EventRowUI = _ace_picker_target_row
	if row == null or row.event_row == null or descriptor == null:
		return
	var condition: ACECondition = ACECondition.new()
	condition.provider_id = descriptor.provider_id
	condition.ace_id = descriptor.ace_id
	condition.params = descriptor.build_default_params()
	row.event_row.conditions.append(condition)
	row.refresh()
	_rebuild_inspector_event(row)

func _append_action_from_descriptor(descriptor: ACEDescriptor) -> void:
	var row: EventRowUI = _ace_picker_target_row
	if row == null or row.event_row == null or descriptor == null:
		return
	var action: ACEAction = ACEAction.new()
	action.provider_id = descriptor.provider_id
	action.ace_id = descriptor.ace_id
	action.params = descriptor.build_default_params()
	row.event_row.actions.append(action)
	row.refresh()
	_rebuild_inspector_event(row)

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

func _focus_event_by_uid(event_uid: String) -> void:
	for child: Node in _canvas_vbox.get_children():
		if child is EventRowUI:
			var row_ui: EventRowUI = child
			if row_ui.event_row != null and row_ui.event_row.event_uid == event_uid:
				_on_event_selected(row_ui)
				return

func _focus_variable_by_name(var_name: String) -> void:
	for child: Node in _canvas_vbox.get_children():
		if child is VariableRowUI:
			var row_ui: VariableRowUI = child
			if row_ui.var_name == var_name:
				_on_variable_selected(row_ui)
				return

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

	var add_event_btn: Button = Button.new()
	add_event_btn.text = "+ Add Event"
	add_event_btn.custom_minimum_size = Vector2(120, 0)
	add_event_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	add_event_btn.connect("pressed", _on_add_event_requested)
	_canvas_vbox.add_child(add_event_btn)

	if current_sheet.events.is_empty():
		var hint: Label = Label.new()
		hint.text = "No events yet. Click + Add Event to pick a run context or condition."
		hint.add_theme_color_override("font_color", Color(0.50, 0.50, 0.60))
		hint.add_theme_font_size_override("font_size", 11)
		_canvas_vbox.add_child(hint)
		return

	for resource: Variant in current_sheet.events:
		if resource is EventRow:
			_add_event_row(resource as EventRow)
		elif resource is EventGroup:
			_add_group_row(resource as EventGroup)

func _add_event_row(event_row: EventRow) -> void:
	var row_ui: EventRowUI = EventRowUI.new()
	row_ui.event_row = event_row
	row_ui.refresh()
	row_ui.event_selected.connect(_on_event_selected)
	row_ui.condition_selected.connect(_on_condition_selected)
	row_ui.action_selected.connect(_on_action_selected)
	row_ui.add_action_requested.connect(_on_row_add_action_requested)
	_canvas_vbox.add_child(row_ui)

func _add_group_row(event_group: EventGroup) -> void:
	var row_ui: GroupRowUI = GroupRowUI.new()
	row_ui.event_group = event_group
	row_ui.refresh()
	row_ui.group_selected.connect(_on_group_selected)
	_canvas_vbox.add_child(row_ui)

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
	_rebuild_inspector_condition(row, index)

func _on_action_selected(row: EventRowUI, index: int) -> void:
	_selected_entry_kind = "action"
	_selected_row = row
	_selected_index = index
	_rebuild_inspector_action(row, index)

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

func _on_group_selected(row: GroupRowUI) -> void:
	_selected_entry_kind = "group"
	_selected_row = row
	_selected_group = row
	_rebuild_inspector_group(row)

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

func _add_back_button(label: String = "← Back to Event") -> void:
	var btn: Button = Button.new()
	btn.text = label
	btn.connect("pressed", _on_back_pressed)
	_inspector_vbox.add_child(btn)
	var sep: HSeparator = HSeparator.new()
	_inspector_vbox.add_child(sep)

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

	# Run context
	var run_context_heading: Label = Label.new()
	run_context_heading.text = "Run Context:"
	run_context_heading.add_theme_color_override("font_color", Color(0.70, 0.70, 0.70))
	run_context_heading.add_theme_font_size_override("font_size", 10)
	_inspector_vbox.add_child(run_context_heading)

	var runs_lbl: Label = Label.new()
	runs_lbl.text = EventRowUI.format_run_context(event_row)
	runs_lbl.add_theme_color_override("font_color", Color(0.85, 0.75, 0.45))
	_inspector_vbox.add_child(runs_lbl)

	var sep1: HSeparator = HSeparator.new()
	_inspector_vbox.add_child(sep1)

	# Conditions list
	var cond_lbl: Label = Label.new()
	cond_lbl.text = "Conditions:"
	cond_lbl.add_theme_color_override("font_color", Color(0.65, 0.85, 0.65))
	_inspector_vbox.add_child(cond_lbl)

	if event_row.conditions.is_empty():
		var empty_conditions: Label = Label.new()
		empty_conditions.text = "Always (default when no conditions are added)."
		empty_conditions.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
		_inspector_vbox.add_child(empty_conditions)

	for i: int in range(event_row.conditions.size()):
		var condition: ACECondition = event_row.conditions[i]
		var btn: Button = Button.new()
		btn.text = "  " + EventRowUI.format_condition_summary(condition)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.flat = true
		btn.connect("pressed", func() -> void: _on_condition_selected(row, i))
		_inspector_vbox.add_child(btn)

	var add_condition_btn: Button = Button.new()
	add_condition_btn.text = "Add Condition"
	add_condition_btn.connect("pressed", _add_condition_to_selected_event)
	_inspector_vbox.add_child(add_condition_btn)

	var sep2: HSeparator = HSeparator.new()
	_inspector_vbox.add_child(sep2)

	# Actions list
	var act_lbl: Label = Label.new()
	act_lbl.text = "Actions:"
	act_lbl.add_theme_color_override("font_color", Color(0.65, 0.75, 1.0))
	_inspector_vbox.add_child(act_lbl)

	if event_row.actions.is_empty():
		var empty_actions: Label = Label.new()
		empty_actions.text = "No actions yet."
		empty_actions.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
		_inspector_vbox.add_child(empty_actions)

	for i: int in range(event_row.actions.size()):
		var action: ACEAction = event_row.actions[i] as ACEAction
		if action == null:
			continue
		var btn: Button = Button.new()
		btn.text = "  " + EventRowUI.format_action_summary(action)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.flat = true
		btn.connect("pressed", func() -> void: _on_action_selected(row, i))
		_inspector_vbox.add_child(btn)

	var add_action_btn: Button = Button.new()
	add_action_btn.text = "Add Action"
	add_action_btn.connect("pressed", _add_action_to_selected_event)
	_inspector_vbox.add_child(add_action_btn)

func _add_condition_to_selected_event() -> void:
	if not (_selected_row is EventRowUI):
		return
	var row: EventRowUI = _selected_row as EventRowUI
	if row == null or row.event_row == null:
		return
	_open_add_condition_picker(row)

func _add_action_to_selected_event() -> void:
	if not (_selected_row is EventRowUI):
		return
	var row: EventRowUI = _selected_row as EventRowUI
	if row == null or row.event_row == null:
		return
	_open_add_action_picker(row)

func _rebuild_inspector_condition(row: EventRowUI, index: int) -> void:
	_clear_inspector()
	if row == null or row.event_row == null:
		_show_empty_inspector()
		return

	_add_back_button()

	var event_row: EventRow = row.event_row
	if index < 0 or index >= event_row.conditions.size():
		_show_empty_inspector()
		return

	var condition: ACECondition = event_row.conditions[index]

	var heading: Label = Label.new()
	heading.text = "Condition: " + EventRowUI.format_condition_summary(condition)
	heading.add_theme_color_override("font_color", Color(0.65, 0.85, 0.65))
	heading.add_theme_font_size_override("font_size", 12)
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_inspector_vbox.add_child(heading)

	# Remove button
	var remove_btn: Button = Button.new()
	remove_btn.text = "Remove Condition"
	remove_btn.connect("pressed", func() -> void: _remove_focused_condition(index))
	_inspector_vbox.add_child(remove_btn)

func _rebuild_inspector_action(row: EventRowUI, index: int) -> void:
	_clear_inspector()
	if row == null or row.event_row == null:
		_show_empty_inspector()
		return

	_add_back_button()

	var event_row: EventRow = row.event_row
	if index < 0 or index >= event_row.actions.size():
		_show_empty_inspector()
		return

	var item: Variant = event_row.actions[index]
	if not (item is ACEAction):
		_show_empty_inspector()
		return

	var action: ACEAction = item as ACEAction

	var heading: Label = Label.new()
	heading.text = "Action: " + EventRowUI.format_action_summary(action)
	heading.add_theme_color_override("font_color", Color(0.65, 0.75, 1.0))
	heading.add_theme_font_size_override("font_size", 12)
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_inspector_vbox.add_child(heading)

	# Remove button
	var remove_btn: Button = Button.new()
	remove_btn.text = "Remove Action"
	remove_btn.connect("pressed", func() -> void: _remove_focused_action(index))
	_inspector_vbox.add_child(remove_btn)

func _rebuild_inspector_variable(row: VariableRowUI) -> void:
	_clear_inspector()
	if row == null:
		_show_empty_inspector()
		return

	var heading: Label = Label.new()
	heading.text = "Variable: " + row.var_name
	heading.add_theme_color_override("font_color", Color(0.35, 0.95, 0.55))
	heading.add_theme_font_size_override("font_size", 12)
	_inspector_vbox.add_child(heading)

	var summary: Label = Label.new()
	summary.text = VariableRowUI.format_summary(row.var_name, row.var_info)
	summary.add_theme_color_override("font_color", Color(0.80, 0.90, 0.80))
	_inspector_vbox.add_child(summary)

	var note: Label = Label.new()
	note.text = "Edit variable name, type, and default value in the Sheet Variables panel."
	note.add_theme_color_override("font_color", Color(0.50, 0.55, 0.50))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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

	var sep: HSeparator = HSeparator.new()
	_inspector_vbox.add_child(sep)

	var planned_note: Label = Label.new()
	planned_note.text = "Nested local variables and group event bodies are planned."
	planned_note.add_theme_color_override("font_color", Color(0.50, 0.45, 0.60))
	planned_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_inspector_vbox.add_child(planned_note)

# ── Focused entry removal ─────────────────────────────────────────────────────

## Removes the focused condition at [index] and returns to full event inspector.
func _remove_focused_condition(index: int) -> void:
	if _selected_row == null or not (_selected_row is EventRowUI):
		return
	var row: EventRowUI = _selected_row as EventRowUI
	if row.event_row == null:
		return
	if index >= 0 and index < row.event_row.conditions.size():
		row.event_row.conditions.remove_at(index)
		row.refresh()
	_clear_focused_entry_state()
	_rebuild_inspector_event(row)

## Removes the focused action at [index] and returns to full event inspector.
func _remove_focused_action(index: int) -> void:
	if _selected_row == null or not (_selected_row is EventRowUI):
		return
	var row: EventRowUI = _selected_row as EventRowUI
	if row.event_row == null:
		return
	if index >= 0 and index < row.event_row.actions.size():
		row.event_row.actions.remove_at(index)
		row.refresh()
	_clear_focused_entry_state()
	_rebuild_inspector_event(row)

## Resets focused condition/action state while keeping the selected row.
func _clear_focused_entry_state() -> void:
	_selected_entry_kind = "event"
	_selected_index = -1

# ── Back button ───────────────────────────────────────────────────────────────

func _on_back_pressed() -> void:
	if _selected_row is EventRowUI:
		_selected_entry_kind = "event"
		_selected_index = -1
		_rebuild_inspector_event(_selected_row as EventRowUI)
	else:
		_show_empty_inspector()
