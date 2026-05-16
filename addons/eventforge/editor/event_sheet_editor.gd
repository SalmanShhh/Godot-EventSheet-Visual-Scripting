# EventForge — Event sheet editor
# Renders the event sheet as a Construct/GDevelop-style vertical document.
# The canvas shows: document header → global variable rows → event/group blocks.
# The inspector panel on the right shows context-sensitive editing UI.
@tool
extends Control
class_name EventSheetEditor

# ── State ────────────────────────────────────────────────────────────────────

var current_sheet: EventSheetResource = null
## True when the loaded sheet has unsaved changes.
var _is_dirty: bool = false
# user:// is the editor's writable data path; keep preview output out of res:// assets.
const PREVIEW_OUTPUT_PATH: String = "user://eventforge_preview_generated.gd"
const DEFAULT_RUN_CONTEXT_ACE_ID: String = "OnProcess"
## Pre-declared sections for the "Add Event" picker (triggers + conditions mode).
## Node-type sections are listed first so they appear even before descriptor scanning
## populates them.  Additional node types registered at runtime are added dynamically
## by _populate_ace_picker as descriptors are scanned.
const EVENT_PICKER_GROUPS: PackedStringArray = [
	"Run Context / Triggers",
	"CharacterBody2D",
	"Area2D",
	"Node2D",
	"RigidBody2D",
	"Timer",
	"AnimationPlayer",
	"General Conditions",
	"Variables",
	"Loops",
	"Signals / Scene / Input",
	"Custom ACEs"
]
## Pre-declared sections for expression insertion picker shown from ACE params.
## Keep node-type sections first to align with #54 grouping and #51 expression UX.
const EXPRESSION_PICKER_GROUPS: PackedStringArray = [
	"CharacterBody2D",
	"Area2D",
	"Node2D",
	"RigidBody2D",
	"Timer",
	"AnimationPlayer",
	"General Expressions",
	"Variables",
	"Custom ACEs"
]
## Category group names that are not node types — used to distinguish node-type
## groups (amber) from logical category groups (muted blue) in the picker.
const CORE_CATEGORY_GROUP_NAMES: PackedStringArray = [
	"Run Context / Triggers",
	"General Conditions",
	"General Actions",
	"General Expressions",
	"Variables",
	"Loops",
	"Signals / Scene / Input",
	"Custom ACEs"
]
const ACE_PARAMS_DIALOG_SIZE: Vector2i = Vector2i(420, 300)
const ACE_PICKER_DIALOG_SIZE: Vector2i = Vector2i(520, 420)
const EXPRESSION_PICKER_DIALOG_SIZE: Vector2i = Vector2i(520, 360)
const NO_VARIABLES_AVAILABLE_TEXT: String = "No variables available"
const NO_VARIABLES_AVAILABLE_HINT_TEXT: String = "No variables are available. Add a variable before applying this ACE."
const NO_EXPRESSIONS_AVAILABLE_TEXT: String = "No expressions available"
const ACE_PARAMS_LABEL_WIDTH: float = 110.0
const ACE_PARAMS_LABEL_MIN_HEIGHT: float = 20.0
const EXPRESSION_PARAM_HINTS: PackedStringArray = ["expression"]
const BRANCH_GUIDE_CHAR: String = "└"
const BRANCH_GUIDE_LABEL: String = "└─"
const CANVAS_BG: Color = Color(0.060, 0.067, 0.088, 1.0)
const CANVAS_BORDER: Color = Color(0.141, 0.164, 0.214, 1.0)
## Amber colour used for node-type / Godot class group headers in the ACE picker.
const ACE_PICKER_NODE_TYPE_GROUP_COLOR: Color = Color(0.92, 0.72, 0.38)
const SHORTCUT_BLOCKING_FOCUS_TYPES: Array[String] = ["LineEdit", "TextEdit", "SpinBox"]

## Currently selected entry kind.
## One of: "none", "event", "condition", "action", "variable", "group", "comment"
var _selected_entry_kind: String = "none"
var _selected_row: Variant = null       # EventRowUI / VariableRowUI / GroupRowUI
var _selected_index: int = -1           # condition or action index within event
var _selected_variable_name: String = ""
var _selected_group: Variant = null     # GroupRowUI

# ── UI references ─────────────────────────────────────────────────────────────

var _scroll: ScrollContainer = null
var _canvas_vbox: VBoxContainer = null
var _sheet_canvas_shell: PanelContainer = null
var _canvas_doc_title_label: Label = null
var _canvas_doc_path_label: Label = null
var _canvas_doc_dirty_label: Label = null
var _inspector_panel: PanelContainer = null
var _inspector_vbox: VBoxContainer = null
var _sheet_toolbar: SheetToolbar = null
## Status bar label at the bottom of the workspace.
var _status_label: Label = null
var _ace_picker_popup: Window = null
var _ace_picker_title: Label = null
var _ace_picker_search: LineEdit = null
var _ace_picker_tree: Tree = null
var _ace_picker_description: Label = null
## One of: "new_event", "append_condition", "replace_condition", "append_action", "replace_action"
var _ace_picker_mode: String = ""
var _ace_picker_target_row: EventRowUI = null
var _ace_picker_target_condition_index: int = -1
## Stored picker type flags so the search handler can re-populate with the same filters.
var _ace_picker_include_triggers: bool = false
var _ace_picker_include_conditions: bool = false
var _ace_picker_include_actions: bool = false
var _ace_params_dialog: ConfirmationDialog = null
var _ace_params_form: VBoxContainer = null
var _ace_params_hint: Label = null
var _ace_params_fields: Dictionary = {}
var _ace_params_mode: String = ""
var _ace_params_descriptor: ACEDescriptor = null
var _ace_params_target_row: EventRowUI = null
var _ace_params_target_index: int = -1
var _ace_params_existing_values: Dictionary = {}
var _ace_params_hint_base_text: String = ""
## True when the param dialog was opened from the ACE picker (enables Back button).
var _ace_params_from_picker: bool = false
var _ace_params_back_button: Button = null
var _expression_picker_popup: Window = null
var _expression_picker_search: LineEdit = null
var _expression_picker_tree: Tree = null
var _expression_picker_description: Label = null
var _expression_picker_target_input: LineEdit = null

var _variable_dialog: ConfirmationDialog = null
var _variable_name_edit: LineEdit = null
var _variable_type_option: OptionButton = null
var _variable_initial_edit: LineEdit = null
var _variable_description_edit: LineEdit = null
var _variable_dialog_mode: String = ""
var _variable_dialog_original_name: String = ""
var _suppress_variable_popup_on_select: bool = false
var _current_rows_host: VBoxContainer = null
var _comment_text_edit: LineEdit = null
var _copied_event_row: EventRow = null

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	_build_layout()

func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if _is_workflow_shortcut_blocked():
		return
	var handled: bool = false
	if key_event.ctrl_pressed and not key_event.alt_pressed and not key_event.meta_pressed:
		if not key_event.shift_pressed and key_event.keycode == KEY_E:
			handled = _handle_workflow_shortcut("add_event")
		elif not key_event.shift_pressed and key_event.keycode == KEY_C:
			handled = _handle_workflow_shortcut("copy_event")
		elif not key_event.shift_pressed and key_event.keycode == KEY_V:
			handled = _handle_workflow_shortcut("paste_event")
		elif not key_event.shift_pressed and key_event.keycode == KEY_S:
			handled = _handle_workflow_shortcut("save")
		elif key_event.shift_pressed and key_event.keycode == KEY_S:
			handled = _handle_workflow_shortcut("save_as")
		elif key_event.shift_pressed and key_event.keycode == KEY_V:
			handled = _handle_workflow_shortcut("add_variable")
		elif key_event.shift_pressed and key_event.keycode == KEY_C:
			handled = _handle_workflow_shortcut("add_condition")
		elif key_event.shift_pressed and key_event.keycode == KEY_A:
			handled = _handle_workflow_shortcut("add_action")
	elif key_event.keycode == KEY_Q and _has_no_modifiers(key_event):
		handled = _handle_workflow_shortcut("add_comment")
	elif key_event.keycode == KEY_DELETE and _has_no_modifiers(key_event):
		handled = _handle_workflow_shortcut("delete_selection")
	if handled:
		get_viewport().set_input_as_handled()

func _has_no_modifiers(key_event: InputEventKey) -> bool:
	return not (key_event.alt_pressed or key_event.ctrl_pressed or key_event.meta_pressed or key_event.shift_pressed)

func _is_workflow_shortcut_blocked() -> bool:
	if _ace_picker_popup != null and _ace_picker_popup.visible:
		return true
	if _ace_params_dialog != null and _ace_params_dialog.visible:
		return true
	if _variable_dialog != null and _variable_dialog.visible:
		return true
	var focus_owner: Control = get_viewport().gui_get_focus_owner()
	if focus_owner == null:
		return false
	for focus_type: String in SHORTCUT_BLOCKING_FOCUS_TYPES:
		if focus_owner.is_class(focus_type):
			return true
	return false

func _handle_workflow_shortcut(action: String) -> bool:
	match action:
		"add_event":
			_on_add_event_requested()
			return true
		"save":
			_on_save_sheet()
			return true
		"save_as":
			_on_save_as_sheet()
			return true
		"add_variable":
			_on_add_variable_requested()
			return true
		"add_condition":
			var condition_row: EventRowUI = _get_selected_event_row_for_shortcuts()
			if condition_row == null:
				return false
			_on_row_add_condition_requested(condition_row)
			return true
		"add_action":
			var action_row: EventRowUI = _get_selected_event_row_for_shortcuts()
			if action_row == null:
				return false
			_on_row_add_action_requested(action_row)
			return true
		"add_comment":
			_insert_comment_from_selection_context()
			return true
		"copy_event":
			return _copy_selected_event_tree()
		"paste_event":
			return _paste_copied_event_tree()
		"delete_selection":
			return _delete_current_selection()
		_:
			return false

func _get_selected_event_row_for_shortcuts() -> EventRowUI:
	if not (_selected_row is EventRowUI):
		return null
	var row: EventRowUI = _selected_row as EventRowUI
	if row.event_row == null:
		return null
	return row

func _copy_selected_event_tree() -> bool:
	var row: EventRowUI = _get_selected_event_row_for_shortcuts()
	if row == null or row.event_row == null:
		return false
	_copied_event_row = row.event_row.duplicate(true) as EventRow
	if _copied_event_row == null:
		return false
	_regenerate_event_tree_uids(_copied_event_row)
	_set_status("Copied event")
	return true

func _paste_copied_event_tree() -> bool:
	if current_sheet == null or _copied_event_row == null:
		return false
	var pasted_event: EventRow = _copied_event_row.duplicate(true) as EventRow
	if pasted_event == null:
		return false
	_regenerate_event_tree_uids(pasted_event)
	var target_resource: Resource = _get_comment_insertion_target_resource()
	var inserted: bool = false
	if target_resource != null:
		inserted = _insert_resource_relative_in_array(current_sheet.events, target_resource, true, pasted_event)
	if not inserted:
		current_sheet.events.append(pasted_event)
	refresh_canvas()
	_focus_event_by_uid(pasted_event.event_uid)
	_mark_dirty()
	_set_status("Pasted event")
	return true

func _regenerate_event_tree_uids(event_row: EventRow) -> void:
	if event_row == null:
		return
	event_row.event_uid = EventRow._generate_short_uid()
	for sub_resource: Variant in event_row.sub_events:
		if sub_resource is EventRow:
			_regenerate_event_tree_uids(sub_resource as EventRow)
		elif sub_resource is EventGroup:
			_regenerate_group_tree_uids(sub_resource as EventGroup)

func _regenerate_group_tree_uids(event_group: EventGroup) -> void:
	if event_group == null:
		return
	event_group.group_uid = EventGroup._generate_short_uid()
	for child: Variant in event_group.events:
		if child is EventRow:
			_regenerate_event_tree_uids(child as EventRow)
		elif child is EventGroup:
			_regenerate_group_tree_uids(child as EventGroup)
	for legacy_child: Variant in event_group.rows:
		if legacy_child is EventRow:
			_regenerate_event_tree_uids(legacy_child as EventRow)
		elif legacy_child is EventGroup:
			_regenerate_group_tree_uids(legacy_child as EventGroup)

func _delete_current_selection() -> bool:
	match _selected_entry_kind:
		"event":
			var event_row: EventRowUI = _get_selected_event_row_for_shortcuts()
			if event_row == null:
				return false
			_on_event_delete_requested(event_row)
			return true
		"condition":
			var condition_row: EventRowUI = _get_selected_event_row_for_shortcuts()
			if condition_row == null:
				return false
			if _selected_index < 0 or _selected_index >= condition_row.event_row.conditions.size():
				return false
			_on_condition_delete_requested(condition_row, _selected_index)
			return true
		"action":
			var action_row: EventRowUI = _get_selected_event_row_for_shortcuts()
			if action_row == null:
				return false
			if _selected_index < 0 or _selected_index >= action_row.event_row.actions.size():
				return false
			_on_action_delete_requested(action_row, _selected_index)
			return true
		"variable":
			if not (_selected_row is VariableRowUI):
				return false
			var variable_row: VariableRowUI = _selected_row as VariableRowUI
			_on_variable_delete_requested(variable_row)
			return true
		"group":
			if not (_selected_row is GroupRowUI):
				return false
			var group_row: GroupRowUI = _selected_row as GroupRowUI
			_on_group_delete_requested(group_row)
			return true
		"comment":
			if not (_selected_row is CommentRowUI):
				return false
			var comment_row: CommentRowUI = _selected_row as CommentRowUI
			_on_comment_delete_requested(comment_row)
			return true
		_:
			return false

## Called by the plugin to load a sheet into the editor.
func setup(sheet: EventSheetResource = null) -> void:
	_load_sheet(sheet)

# ── Layout construction ───────────────────────────────────────────────────────

func _build_layout() -> void:
	# Size flags ensure proper expansion when the parent is a container
	# (e.g. the editor main screen); PRESET_FULL_RECT covers anchor-based parents.
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Workspace shell: VBoxContainer fills the full main-screen area.
	# Separation is 0 so each zone (toolbar / content / status bar) butts directly
	# against the next without any gap — matching the Script editor composition.
	var workspace_vbox: VBoxContainer = VBoxContainer.new()
	workspace_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	workspace_vbox.add_theme_constant_override("separation", 0)
	add_child(workspace_vbox)

	# ── Toolbar (full-width, flush at top) ────────────────────────────────────
	_sheet_toolbar = SheetToolbar.new()
	_sheet_toolbar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sheet_toolbar.new_sheet_requested.connect(_on_create_new_sheet)
	_sheet_toolbar.open_sheet_requested.connect(_on_open_existing_sheet)
	_sheet_toolbar.save_requested.connect(_on_save_sheet)
	_sheet_toolbar.save_as_requested.connect(_on_save_as_sheet)
	_sheet_toolbar.add_event_requested.connect(_on_add_event_requested)
	_sheet_toolbar.add_var_requested.connect(_on_add_variable_requested)
	_sheet_toolbar.compile_requested.connect(_on_compile_requested)
	workspace_vbox.add_child(_sheet_toolbar)

	# ── Content area (canvas + inspector) with small breathing margins ─────────
	var content_margin: MarginContainer = MarginContainer.new()
	content_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_margin.add_theme_constant_override("margin_left", 6)
	content_margin.add_theme_constant_override("margin_right", 6)
	content_margin.add_theme_constant_override("margin_top", 6)
	content_margin.add_theme_constant_override("margin_bottom", 4)
	workspace_vbox.add_child(content_margin)

	var workspace_split: HSplitContainer = HSplitContainer.new()
	workspace_split.name = "WorkspaceSplit"
	workspace_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	workspace_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_margin.add_child(workspace_split)

	# ── Left: canvas scroll ───────────────────────────────────────────────────
	_sheet_canvas_shell = PanelContainer.new()
	_sheet_canvas_shell.name = "SheetCanvasShell"
	_sheet_canvas_shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sheet_canvas_shell.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var canvas_style: StyleBoxFlat = StyleBoxFlat.new()
	canvas_style.bg_color = CANVAS_BG
	canvas_style.border_color = CANVAS_BORDER
	canvas_style.set_border_width_all(1)
	canvas_style.set_corner_radius_all(0)
	canvas_style.set_content_margin_all(0)
	_sheet_canvas_shell.add_theme_stylebox_override("panel", canvas_style)
	workspace_split.add_child(_sheet_canvas_shell)

	var canvas_shell_vbox: VBoxContainer = VBoxContainer.new()
	canvas_shell_vbox.add_theme_constant_override("separation", 0)
	canvas_shell_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas_shell_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_sheet_canvas_shell.add_child(canvas_shell_vbox)

	var canvas_doc_strip: PanelContainer = PanelContainer.new()
	canvas_doc_strip.name = "SheetCanvasDocumentStrip"
	canvas_doc_strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var strip_style: StyleBoxFlat = StyleBoxFlat.new()
	strip_style.bg_color = Color(0.074, 0.084, 0.111, 1.0)
	strip_style.border_color = Color(0.152, 0.178, 0.230, 1.0)
	strip_style.set_border_width_all(0)
	strip_style.border_width_bottom = 1
	strip_style.set_content_margin(SIDE_LEFT, 10)
	strip_style.set_content_margin(SIDE_RIGHT, 10)
	strip_style.set_content_margin(SIDE_TOP, 4)
	strip_style.set_content_margin(SIDE_BOTTOM, 4)
	canvas_doc_strip.add_theme_stylebox_override("panel", strip_style)
	canvas_shell_vbox.add_child(canvas_doc_strip)

	var strip_row: HBoxContainer = HBoxContainer.new()
	strip_row.add_theme_constant_override("separation", 7)
	strip_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas_doc_strip.add_child(strip_row)

	var strip_kind: Label = Label.new()
	strip_kind.text = "EventSheetResource"
	strip_kind.add_theme_color_override("font_color", Color(0.62, 0.80, 1.0))
	strip_kind.add_theme_font_size_override("font_size", 9)
	strip_row.add_child(strip_kind)

	var strip_sep: VSeparator = VSeparator.new()
	strip_sep.add_theme_color_override("color", Color(0.24, 0.28, 0.36, 0.60))
	strip_row.add_child(strip_sep)

	var resource_tab: PanelContainer = PanelContainer.new()
	resource_tab.name = "SheetCanvasResourceTab"
	var resource_tab_style: StyleBoxFlat = StyleBoxFlat.new()
	resource_tab_style.bg_color = Color(0.102, 0.117, 0.151, 1.0)
	resource_tab_style.border_color = Color(0.222, 0.262, 0.336, 1.0)
	resource_tab_style.set_border_width_all(1)
	resource_tab_style.border_width_bottom = 0
	resource_tab_style.set_corner_radius_all(0)
	resource_tab_style.set_content_margin(SIDE_LEFT, 8)
	resource_tab_style.set_content_margin(SIDE_RIGHT, 8)
	resource_tab_style.set_content_margin(SIDE_TOP, 3)
	resource_tab_style.set_content_margin(SIDE_BOTTOM, 3)
	resource_tab.add_theme_stylebox_override("panel", resource_tab_style)
	strip_row.add_child(resource_tab)

	var resource_tab_row: HBoxContainer = HBoxContainer.new()
	resource_tab_row.add_theme_constant_override("separation", 6)
	resource_tab.add_child(resource_tab_row)

	_canvas_doc_title_label = Label.new()
	_canvas_doc_title_label.text = "No Sheet Loaded"
	_canvas_doc_title_label.add_theme_color_override("font_color", Color(0.86, 0.93, 1.0))
	_canvas_doc_title_label.add_theme_font_size_override("font_size", 11)
	resource_tab_row.add_child(_canvas_doc_title_label)

	_canvas_doc_dirty_label = Label.new()
	_canvas_doc_dirty_label.text = "●"
	_canvas_doc_dirty_label.add_theme_color_override("font_color", Color(0.95, 0.72, 0.30))
	_canvas_doc_dirty_label.add_theme_font_size_override("font_size", 9)
	_canvas_doc_dirty_label.tooltip_text = "Unsaved changes"
	_canvas_doc_dirty_label.visible = false
	resource_tab_row.add_child(_canvas_doc_dirty_label)

	var path_sep: VSeparator = VSeparator.new()
	path_sep.add_theme_color_override("color", Color(0.24, 0.28, 0.36, 0.60))
	strip_row.add_child(path_sep)

	_canvas_doc_path_label = Label.new()
	_canvas_doc_path_label.text = "Open or create a sheet to begin"
	_canvas_doc_path_label.add_theme_color_override("font_color", Color(0.52, 0.62, 0.78))
	_canvas_doc_path_label.add_theme_font_size_override("font_size", 9)
	strip_row.add_child(_canvas_doc_path_label)

	var strip_spacer: Control = Control.new()
	strip_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	strip_row.add_child(strip_spacer)

	var canvas_margin: MarginContainer = MarginContainer.new()
	canvas_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas_margin.add_theme_constant_override("margin_left", 10)
	canvas_margin.add_theme_constant_override("margin_right", 10)
	canvas_margin.add_theme_constant_override("margin_top", 10)
	canvas_margin.add_theme_constant_override("margin_bottom", 10)
	canvas_shell_vbox.add_child(canvas_margin)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	canvas_margin.add_child(_scroll)

	_canvas_vbox = VBoxContainer.new()
	_canvas_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_canvas_vbox.add_theme_constant_override("separation", 6)
	_canvas_vbox.set("custom_minimum_size", Vector2(0, 0))
	_scroll.add_child(_canvas_vbox)

	# ── Right: inspector panel (passive context panel) ────────────────────────
	_inspector_panel = PanelContainer.new()
	_inspector_panel.custom_minimum_size = Vector2(220, 0)
	_inspector_panel.size_flags_horizontal = Control.SIZE_FILL
	_inspector_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var insp_style: StyleBoxFlat = StyleBoxFlat.new()
	insp_style.bg_color = Color(0.079, 0.087, 0.113, 1.0)
	insp_style.border_color = Color(0.157, 0.181, 0.233, 1.0)
	insp_style.set_border_width_all(1)
	insp_style.set_corner_radius_all(0)
	insp_style.set_content_margin_all(10)
	_inspector_panel.add_theme_stylebox_override("panel", insp_style)
	workspace_split.add_child(_inspector_panel)

	_inspector_vbox = VBoxContainer.new()
	_inspector_vbox.add_theme_constant_override("separation", 6)
	_inspector_panel.add_child(_inspector_vbox)

	# ── Status bar (full-width at bottom) ──────────────────────────────────────
	var status_bar: PanelContainer = PanelContainer.new()
	status_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb_style: StyleBoxFlat = StyleBoxFlat.new()
	sb_style.bg_color = Color(0.064, 0.071, 0.092, 1.0)
	sb_style.border_color = Color(0.141, 0.164, 0.214, 1.0)
	sb_style.set_border_width_all(0)
	sb_style.border_width_top = 1
	sb_style.set_content_margin(SIDE_LEFT, 10)
	sb_style.set_content_margin(SIDE_RIGHT, 10)
	sb_style.set_content_margin(SIDE_TOP, 3)
	sb_style.set_content_margin(SIDE_BOTTOM, 3)
	status_bar.add_theme_stylebox_override("panel", sb_style)
	workspace_vbox.add_child(status_bar)

	_status_label = Label.new()
	_status_label.text = ""
	_status_label.add_theme_color_override("font_color", Color(0.70, 0.74, 0.80))
	_status_label.add_theme_font_size_override("font_size", 10)
	status_bar.add_child(_status_label)

	_show_empty_inspector()
	_refresh_toolbar_state()
	_build_ace_picker_popup()
	_build_expression_picker_popup()
	_build_ace_params_dialog_popup()
	_build_variable_dialog_popup()

# ── Canvas rendering ──────────────────────────────────────────────────────────

## Rebuilds the full canvas document from current_sheet.
func refresh_canvas() -> void:
	for child in _canvas_vbox.get_children():
		_canvas_vbox.remove_child(child)
		child.queue_free()

	_add_document_header()

	if current_sheet == null:
		_add_no_sheet_onboarding()
		return

	_add_variables_section()
	_add_events_section()
	_refresh_row_selection_states()
	_refresh_workspace_context()

func _add_no_sheet_onboarding() -> void:
	var margin: MarginContainer = MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_left", 26)
	margin.add_theme_constant_override("margin_right", 26)
	margin.add_theme_constant_override("margin_bottom", 28)

	var card: PanelContainer = PanelContainer.new()
	var card_style: StyleBoxFlat = StyleBoxFlat.new()
	card_style.bg_color = Color(0.095, 0.110, 0.145, 1.0)
	card_style.border_color = Color(0.214, 0.264, 0.347, 1.0)
	card_style.set_border_width_all(1)
	card_style.set_corner_radius_all(8)
	card_style.set_content_margin_all(24)
	card.add_theme_stylebox_override("panel", card_style)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	card.add_child(vbox)

	var title: Label = Label.new()
	title.text = "No Event Sheet Open"
	title.add_theme_color_override("font_color", Color(0.83, 0.92, 1.0))
	title.add_theme_font_size_override("font_size", 17)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var body: Label = Label.new()
	body.text = "Create or open a sheet to start writing inline event clauses."
	body.add_theme_color_override("font_color", Color(0.62, 0.71, 0.83))
	body.add_theme_font_size_override("font_size", 11)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(body)

	var sep: HSeparator = HSeparator.new()
	vbox.add_child(sep)

	var actions: HBoxContainer = HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 10)
	vbox.add_child(actions)

	var create_btn: Button = Button.new()
	create_btn.text = "Create New Event Sheet"
	create_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	create_btn.connect("pressed", _on_create_new_sheet)
	actions.add_child(create_btn)

	var open_btn: Button = Button.new()
	open_btn.text = "Open Existing Event Sheet"
	open_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	open_btn.connect("pressed", _on_open_existing_sheet)
	actions.add_child(open_btn)

	margin.add_child(card)
	_canvas_vbox.add_child(margin)

## Creates a blank in-memory EventSheetResource and loads it into the editor.
func _on_create_new_sheet() -> void:
	_load_sheet(EventSheetResource.new())
	_set_status("Created new Event Sheet")

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
			_set_status("Opened: %s" % path.get_file())
		else:
			push_warning("[EventForge] Selected file is not an EventSheetResource: %s" % path)
			_set_status("Selected file is not an EventSheetResource", true)
		dialog.queue_free()
	)
	dialog.connect("canceled", func() -> void: dialog.queue_free())
	add_child(dialog)
	dialog.popup_centered(Vector2i(700, 500))

## Saves the current sheet to its existing resource path.
## If the sheet has no path yet, delegates to Save As.
func _on_save_sheet() -> void:
	if current_sheet == null:
		_set_status("No sheet to save", true)
		return
	if current_sheet.resource_path.is_empty():
		_on_save_as_sheet()
		return
	var err: Error = ResourceSaver.save(current_sheet, current_sheet.resource_path)
	if err == OK:
		_clear_dirty()
		_set_status("Saved: %s" % current_sheet.resource_path.get_file())
	else:
		_set_status("Save failed (error %d)" % err, true)

## Opens a FileDialog for the user to choose a save path.
func _on_save_as_sheet() -> void:
	if current_sheet == null:
		_set_status("No sheet to save", true)
		return
	var dialog: FileDialog = FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	dialog.access = FileDialog.ACCESS_RESOURCES
	dialog.filters = PackedStringArray(["*.tres ; EventSheetResource"])
	if not current_sheet.resource_path.is_empty():
		dialog.current_path = current_sheet.resource_path
	dialog.connect("file_selected", func(path: String) -> void:
		var err: Error = ResourceSaver.save(current_sheet, path)
		if err == OK:
			current_sheet.take_over_path(path)
			_clear_dirty()
			refresh_canvas()
			_refresh_toolbar_state()
			_set_status("Saved as: %s" % path.get_file())
		else:
			_set_status("Save failed (error %d)" % err, true)
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

func _on_add_comment_requested() -> void:
	_ensure_sheet()
	if current_sheet == null:
		return
	_insert_comment_from_selection_context()

func _insert_comment_from_selection_context() -> void:
	if current_sheet == null:
		return
	var target_resource: Resource = _get_comment_insertion_target_resource()
	if target_resource != null:
		_insert_new_comment_relative(target_resource, true)
		return
	var new_comment: CommentRow = CommentRow.new()
	new_comment.text = "Comment"
	current_sheet.events.append(new_comment)
	refresh_canvas()
	_focus_comment_row(new_comment)
	_mark_dirty()
	_set_status("Added comment row")

func _get_comment_insertion_target_resource() -> Resource:
	match _selected_entry_kind:
		"event", "condition", "action":
			if _selected_row is EventRowUI:
				var event_row_ui: EventRowUI = _selected_row as EventRowUI
				return event_row_ui.event_row
		"group":
			if _selected_row is GroupRowUI:
				var group_row_ui: GroupRowUI = _selected_row as GroupRowUI
				return group_row_ui.event_group
		"comment":
			if _selected_row is CommentRowUI:
				var comment_row_ui: CommentRowUI = _selected_row as CommentRowUI
				return comment_row_ui.comment_row
	return null

func _on_compile_requested() -> void:
	if current_sheet == null:
		_set_status("Create or open a sheet before compiling", true)
		return

	var result: Dictionary = SheetCompiler.compile(current_sheet, PREVIEW_OUTPUT_PATH)
	var ok: bool = bool(result.get("success", false))
	if ok:
		_set_status("Compiled preview to %s" % PREVIEW_OUTPUT_PATH)
	else:
		var errors: Array = result.get("errors", [])
		var first_error_text: String = str(errors[0]) if not errors.is_empty() else "No error details available"
		_set_status("Compile failed: %s" % first_error_text, true)

func _load_sheet(sheet: EventSheetResource) -> void:
	current_sheet = sheet
	# Avoid stale references in inspector selection when switching sheets.
	_reset_selection_state()
	_clear_dirty()
	if is_inside_tree():
		refresh_canvas()
		_show_empty_inspector()
	_refresh_toolbar_state()

func _ensure_sheet() -> void:
	if current_sheet != null:
		return
	_load_sheet(EventSheetResource.new())
	_set_status("Created new Event Sheet")

func _refresh_toolbar_state() -> void:
	if _sheet_toolbar == null:
		return
	_sheet_toolbar.set_sheet_loaded(current_sheet != null)
	_sheet_toolbar.set_dirty(_is_dirty)
	_refresh_canvas_document_strip_context()
	_refresh_workspace_context()

func _refresh_workspace_context() -> void:
	if _sheet_toolbar == null:
		return
	_sheet_toolbar.set_context(current_sheet, _selected_entry_kind)

func _refresh_canvas_document_strip_context() -> void:
	if _canvas_doc_title_label != null:
		_canvas_doc_title_label.text = _format_document_title(current_sheet)
	if _canvas_doc_path_label != null:
		_canvas_doc_path_label.text = _format_document_path_hint(current_sheet)
	if _canvas_doc_dirty_label != null:
		_canvas_doc_dirty_label.visible = _is_dirty and current_sheet != null

static func _format_document_title(sheet: EventSheetResource) -> String:
	if sheet == null:
		return "No Sheet Loaded"
	if sheet.resource_path.is_empty():
		return "Untitled Sheet"
	return sheet.resource_path.get_file().get_basename()

static func _format_document_path_hint(sheet: EventSheetResource) -> String:
	if sheet == null:
		return "Open or create a sheet to begin"
	if sheet.resource_path.is_empty():
		return "Unsaved (in-memory)"
	return sheet.resource_path

## Marks the current sheet as having unsaved changes.
func _mark_dirty() -> void:
	if _is_dirty:
		return
	_is_dirty = true
	if _sheet_toolbar != null:
		_sheet_toolbar.set_dirty(true)
	_refresh_canvas_document_strip_context()

## Clears the unsaved-changes flag and updates the toolbar indicator.
func _clear_dirty() -> void:
	_is_dirty = false
	if _sheet_toolbar != null:
		_sheet_toolbar.set_dirty(false)
	_refresh_canvas_document_strip_context()

## Updates the workspace status bar text.
func _set_status(text: String, is_error: bool = false) -> void:
	if _status_label == null:
		return
	_status_label.text = text
	_status_label.add_theme_color_override(
		"font_color",
		Color(0.90, 0.55, 0.55) if is_error else Color(0.70, 0.74, 0.80)
	)

func _build_ace_picker_popup() -> void:
	_ace_picker_popup = Window.new()
	_ace_picker_popup.name = "ACEPickerPopup"
	_ace_picker_popup.min_size = ACE_PICKER_DIALOG_SIZE
	_ace_picker_popup.connect("close_requested", func(): _ace_picker_popup.hide())
	add_child(_ace_picker_popup)

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 8)
	_ace_picker_popup.add_child(margin)

	var wrapper: VBoxContainer = VBoxContainer.new()
	wrapper.add_theme_constant_override("separation", 6)
	margin.add_child(wrapper)

	_ace_picker_title = Label.new()
	_ace_picker_title.add_theme_color_override("font_color", Color(0.80, 0.90, 1.0))
	_ace_picker_title.add_theme_font_size_override("font_size", 14)
	wrapper.add_child(_ace_picker_title)

	_ace_picker_search = LineEdit.new()
	_ace_picker_search.name = "ACEPickerSearch"
	_ace_picker_search.placeholder_text = "Filter ACEs…"
	_ace_picker_search.connect("text_changed", _on_ace_picker_search_changed)
	wrapper.add_child(_ace_picker_search)

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
	_ace_picker_popup.hide()

func _build_expression_picker_popup() -> void:
	_expression_picker_popup = Window.new()
	_expression_picker_popup.name = "ExpressionPickerPopup"
	_expression_picker_popup.min_size = EXPRESSION_PICKER_DIALOG_SIZE
	_expression_picker_popup.title = "Insert Expression"
	_expression_picker_popup.connect("close_requested", func():
		_expression_picker_popup.hide()
		_expression_picker_target_input = null
	)
	add_child(_expression_picker_popup)

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 8)
	_expression_picker_popup.add_child(margin)

	var wrapper: VBoxContainer = VBoxContainer.new()
	wrapper.add_theme_constant_override("separation", 6)
	margin.add_child(wrapper)

	var title_label: Label = Label.new()
	title_label.text = "Insert Expression"
	title_label.add_theme_color_override("font_color", Color(0.80, 0.90, 1.0))
	title_label.add_theme_font_size_override("font_size", 14)
	wrapper.add_child(title_label)

	_expression_picker_search = LineEdit.new()
	_expression_picker_search.name = "ExpressionPickerSearch"
	_expression_picker_search.placeholder_text = "Filter expressions…"
	_expression_picker_search.connect("text_changed", _on_expression_picker_search_changed)
	wrapper.add_child(_expression_picker_search)

	_expression_picker_tree = Tree.new()
	_expression_picker_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_expression_picker_tree.hide_root = true
	_expression_picker_tree.select_mode = Tree.SELECT_ROW
	_expression_picker_tree.connect("item_activated", _on_expression_picker_item_activated)
	_expression_picker_tree.connect("item_selected", _on_expression_picker_item_selected)
	wrapper.add_child(_expression_picker_tree)

	_expression_picker_description = Label.new()
	_expression_picker_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_expression_picker_description.add_theme_color_override("font_color", Color(0.65, 0.70, 0.78))
	_expression_picker_description.text = "Pick an expression ACE to insert."
	wrapper.add_child(_expression_picker_description)
	_expression_picker_popup.hide()

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

func _open_replace_action_picker(row: EventRowUI, index: int) -> void:
	_ace_picker_mode = "replace_action"
	_ace_picker_target_row = row
	_ace_picker_target_condition_index = index
	_show_ace_picker("Replace Action", false, false, true)

func _show_ace_picker(title: String, include_triggers: bool, include_conditions: bool, include_actions: bool) -> void:
	if _ace_picker_popup == null:
		return
	_ace_picker_include_triggers = include_triggers
	_ace_picker_include_conditions = include_conditions
	_ace_picker_include_actions = include_actions
	_ace_picker_popup.title = title
	_ace_picker_title.text = title
	_ace_picker_description.text = "Pick an ACE to add."
	if _ace_picker_search != null:
		_ace_picker_search.text = ""
	_populate_ace_picker(include_triggers, include_conditions, include_actions)
	_ace_picker_popup.popup_centered(ACE_PICKER_DIALOG_SIZE)

func _open_expression_picker(target_input: LineEdit) -> void:
	if target_input == null or _expression_picker_popup == null:
		return
	_expression_picker_target_input = target_input
	_expression_picker_description.text = "Pick an expression ACE to insert."
	if _expression_picker_search != null:
		_expression_picker_search.text = ""
	_populate_expression_picker()
	_expression_picker_popup.popup_centered(EXPRESSION_PICKER_DIALOG_SIZE)

func _populate_ace_picker(include_triggers: bool, include_conditions: bool, include_actions: bool, filter_text: String = "") -> void:
	if _ace_picker_tree == null:
		return
	_ace_picker_tree.clear()
	var root: TreeItem = _ace_picker_tree.create_item()
	var groups: Dictionary = {}
	var filter_lower: String = filter_text.to_lower().strip_edges()
	if _ace_picker_mode == "new_event" and filter_lower.is_empty():
		# Pre-declare sections — node-type groups first, then logical categories.
		# Omit pre-declared sections when filtering so only groups with matches appear.
		for name: String in EVENT_PICKER_GROUPS:
			var section: TreeItem = _ace_picker_tree.create_item(root)
			section.set_text(0, name)
			section.set_selectable(0, false)
			section.set_custom_color(0, _get_picker_group_color(name))
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
		# Filter: skip items that don't match the search text (case-insensitive).
		if not filter_lower.is_empty():
			var name_match: bool = descriptor.get_list_name().to_lower().contains(filter_lower)
			var desc_match: bool = descriptor.description.to_lower().contains(filter_lower)
			var node_match: bool = descriptor.node_type.to_lower().contains(filter_lower)
			if not name_match and not desc_match and not node_match:
				continue
		var group_name: String = _get_picker_group(descriptor)
		if not groups.has(group_name):
			var group_item: TreeItem = _ace_picker_tree.create_item(root)
			group_item.set_text(0, group_name)
			group_item.set_selectable(0, false)
			group_item.set_custom_color(0, _get_picker_group_color(group_name))
			groups[group_name] = group_item
		var item: TreeItem = _ace_picker_tree.create_item(groups[group_name])
		item.set_text(0, descriptor.get_list_name())
		var ace_type_label: String = _get_ace_type_label(descriptor.ace_type)
		var desc_text: String = descriptor.description if not descriptor.description.is_empty() else descriptor.get_display_text()
		item.set_tooltip_text(0, "[%s]  %s" % [ace_type_label, desc_text])
		item.set_custom_color(0, _get_picker_item_color(descriptor))
		item.set_metadata(0, descriptor)

func _populate_expression_picker(filter_text: String = "") -> void:
	if _expression_picker_tree == null:
		return
	_expression_picker_tree.clear()
	var root: TreeItem = _expression_picker_tree.create_item()
	var groups: Dictionary = {}
	var added_items: int = 0
	var filter_lower: String = filter_text.to_lower().strip_edges()
	if filter_lower.is_empty():
		for name: String in EXPRESSION_PICKER_GROUPS:
			var section: TreeItem = _expression_picker_tree.create_item(root)
			section.set_text(0, name)
			section.set_selectable(0, false)
			section.set_custom_color(0, _get_picker_group_color(name))
			groups[name] = section
	for descriptor: ACEDescriptor in ACERegistry.get_all_descriptors():
		if descriptor == null or descriptor.ace_type != ACEDescriptor.ACEType.EXPRESSION:
			continue
		if not filter_lower.is_empty():
			var name_match: bool = descriptor.get_list_name().to_lower().contains(filter_lower)
			var desc_match: bool = descriptor.description.to_lower().contains(filter_lower)
			var node_match: bool = descriptor.node_type.to_lower().contains(filter_lower)
			if not name_match and not desc_match and not node_match:
				continue
		var group_name: String = _get_picker_group(descriptor)
		if not groups.has(group_name):
			var group_item: TreeItem = _expression_picker_tree.create_item(root)
			group_item.set_text(0, group_name)
			group_item.set_selectable(0, false)
			group_item.set_custom_color(0, _get_picker_group_color(group_name))
			groups[group_name] = group_item
		var item: TreeItem = _expression_picker_tree.create_item(groups[group_name])
		item.set_text(0, descriptor.get_list_name())
		var desc_text: String = descriptor.description if not descriptor.description.is_empty() else descriptor.get_display_text()
		item.set_tooltip_text(0, "[Expression]  %s" % desc_text)
		item.set_custom_color(0, _get_picker_item_color(descriptor))
		item.set_metadata(0, descriptor)
		added_items += 1
	if added_items == 0 and _expression_picker_description != null:
		_expression_picker_description.text = NO_EXPRESSIONS_AVAILABLE_TEXT

## Returns the group name used to organise a descriptor in the ACE picker.
## node_type takes priority; non-Core providers group by provider_id; Core ACEs
## fall back to category.  This supports issue #54 node-type grouping.
func _get_picker_group(descriptor: ACEDescriptor) -> String:
	# Node-type grouping takes priority (issue #54).
	if not descriptor.node_type.is_empty():
		return descriptor.node_type
	# Runtime providers group under their provider ID.
	# An empty provider_id falls back to "Custom ACEs" (treated as a catch-all category,
	# not a node-type group) since a nameless descriptor may indicate a registration issue.
	if descriptor.provider_id != "Core":
		return descriptor.provider_id if not descriptor.provider_id.is_empty() else "Custom ACEs"
	if descriptor.ace_type == ACEDescriptor.ACEType.TRIGGER:
		return "Run Context / Triggers"
	var category: String = descriptor.category
	if category.is_empty():
		if descriptor.ace_type == ACEDescriptor.ACEType.CONDITION:
			return "General Conditions"
		if descriptor.ace_type == ACEDescriptor.ACEType.EXPRESSION:
			return "General Expressions"
		return "General Actions"
	return category

## Returns the header colour for an ACE picker group.
## Groups not in CORE_CATEGORY_GROUP_NAMES are treated as node-type groups (amber).
static func _get_picker_group_color(group_name: String) -> Color:
	match group_name:
		"Run Context / Triggers":
			return Color(0.55, 0.85, 0.70)  # teal-green
		"Variables":
			return Color(0.65, 0.82, 0.98)  # muted blue
		"Custom ACEs":
			return Color(0.80, 0.65, 0.95)  # purple
		_:
			if CORE_CATEGORY_GROUP_NAMES.has(group_name):
				return Color(0.68, 0.74, 0.84)  # default muted
			# Node-type / class groups use amber to signal their Godot class origin.
			return ACE_PICKER_NODE_TYPE_GROUP_COLOR

## Returns the text colour for an individual ACE picker item based on its ACE type.
## Soft-tinted so items are distinguishable within a group without overwhelming the group header.
static func _get_picker_item_color(descriptor: ACEDescriptor) -> Color:
	match descriptor.ace_type:
		ACEDescriptor.ACEType.TRIGGER:
			return Color(0.72, 0.94, 0.76)   # soft green  – triggers
		ACEDescriptor.ACEType.CONDITION:
			return Color(0.72, 0.88, 1.00)   # soft blue   – conditions
		ACEDescriptor.ACEType.ACTION:
			return Color(0.70, 0.95, 0.88)   # soft teal   – actions
		_:
			return Color(0.84, 0.87, 0.92)   # neutral

## Returns a human-readable label for an ACE type used in picker tooltips.
static func _get_ace_type_label(ace_type: ACEDescriptor.ACEType) -> String:
	match ace_type:
		ACEDescriptor.ACEType.TRIGGER:    return "Trigger"
		ACEDescriptor.ACEType.CONDITION:  return "Condition"
		ACEDescriptor.ACEType.ACTION:     return "Action"
		ACEDescriptor.ACEType.EXPRESSION: return "Expression"
		_:                                return "ACE"

## Called when the ACE picker search box text changes.
## Re-populates the tree with only entries matching the current filter.
func _on_ace_picker_search_changed(new_text: String) -> void:
	_populate_ace_picker(_ace_picker_include_triggers, _ace_picker_include_conditions, _ace_picker_include_actions, new_text)

func _on_expression_picker_search_changed(new_text: String) -> void:
	_populate_expression_picker(new_text)

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

func _on_expression_picker_item_selected() -> void:
	if _expression_picker_tree == null:
		return
	var item: TreeItem = _expression_picker_tree.get_selected()
	if item == null:
		return
	var value: Variant = item.get_metadata(0)
	if value is ACEDescriptor:
		var descriptor: ACEDescriptor = value
		_expression_picker_description.text = descriptor.description if not descriptor.description.is_empty() else descriptor.get_display_text()

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

func _on_expression_picker_item_activated() -> void:
	if _expression_picker_tree == null:
		return
	var item: TreeItem = _expression_picker_tree.get_selected()
	if item == null:
		return
	var value: Variant = item.get_metadata(0)
	if not (value is ACEDescriptor):
		return
	var descriptor: ACEDescriptor = value as ACEDescriptor
	var snippet: String = _build_expression_snippet(descriptor, descriptor.build_default_params())
	_insert_expression_snippet(snippet)

func _build_expression_snippet(descriptor: ACEDescriptor, values: Dictionary) -> String:
	if descriptor == null:
		return ""
	var template: String = descriptor.codegen_template if not descriptor.codegen_template.is_empty() else descriptor.get_display_text()
	var keys: Array[String] = []
	for key: Variant in values.keys():
		keys.append(str(key))
	# Replace longer tokens first so names like {amount} are not partially
	# affected by shorter tokens such as {a}.
	keys.sort_custom(func(a: String, b: String) -> bool:
		return a.length() > b.length()
	)
	for key: String in keys:
		var token: String = "{%s}" % key
		# Missing keys intentionally leave unresolved tokens in place so users can
		# keep editing partially-specified expression templates.
		template = template.replace(token, str(values.get(key, token)))
	return template

func _insert_expression_snippet(snippet: String) -> void:
	if _expression_picker_target_input == null:
		return
	var existing_text: String = _expression_picker_target_input.text.strip_edges(false, true)
	var insert_text: String = snippet.strip_edges()
	if insert_text.is_empty():
		return
	if existing_text.strip_edges().is_empty():
		_expression_picker_target_input.text = insert_text
	else:
		var separator: String = " " if _should_insert_expression_separator(existing_text, insert_text) else ""
		_expression_picker_target_input.text = "%s%s%s" % [existing_text, separator, insert_text]
	_expression_picker_target_input.grab_focus()
	if _expression_picker_popup != null:
		_expression_picker_popup.hide()
	_expression_picker_target_input = null

func _should_insert_expression_separator(existing_text: String, insert_text: String) -> bool:
	if existing_text.is_empty() or insert_text.is_empty():
		return false
	var last_char: String = existing_text[-1]
	if last_char in [" ", "\t", "\n", "(", "[", "{", ".", "!", "~"]:
		return false
	var first_char: String = insert_text[0]
	if first_char in [")", "]", "}", ".", ",", ";"]:
		return false
	return true

func _build_ace_params_dialog_popup() -> void:
	_ace_params_dialog = ConfirmationDialog.new()
	_ace_params_dialog.title = "ACE Parameters"
	_ace_params_dialog.min_size = ACE_PARAMS_DIALOG_SIZE
	_ace_params_dialog.get_ok_button().text = "Apply"
	_ace_params_dialog.connect("confirmed", _on_ace_params_dialog_confirmed)
	_ace_params_dialog.connect("custom_action", _on_ace_params_dialog_custom_action)
	_ace_params_back_button = _ace_params_dialog.add_button("◀ Back", true, "back")
	add_child(_ace_params_dialog)

	var body: VBoxContainer = VBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	_ace_params_dialog.add_child(body)

	_ace_params_hint = Label.new()
	_ace_params_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ace_params_hint.add_theme_color_override("font_color", Color(0.65, 0.70, 0.78))
	body.add_child(_ace_params_hint)

	var form_scroll: ScrollContainer = ScrollContainer.new()
	form_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	form_scroll.custom_minimum_size = Vector2(0, 140)
	form_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	form_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	body.add_child(form_scroll)

	_ace_params_form = VBoxContainer.new()
	_ace_params_form.add_theme_constant_override("separation", 4)
	_ace_params_form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form_scroll.add_child(_ace_params_form)

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
		"replace_action":
			params_dialog_mode = "replace_action"
	if params_dialog_mode.is_empty():
		return
	# If there are no editable parameters, apply immediately using a snapshot of
	# picker context and clear stale picker/params state to avoid re-entry.
	if descriptor.params.is_empty():
		var apply_mode: String = params_dialog_mode
		var apply_target_row: EventRowUI = _ace_picker_target_row
		var apply_target_index: int = _ace_picker_target_condition_index
		_ace_picker_mode = ""
		_ace_picker_target_row = null
		_ace_picker_target_condition_index = -1
		if _ace_picker_popup != null:
			_ace_picker_popup.hide()
		_ace_params_mode = apply_mode
		_ace_params_descriptor = descriptor
		_ace_params_target_row = apply_target_row
		_ace_params_target_index = apply_target_index
		_apply_ace_params({})
		_ace_params_descriptor = null
		_ace_params_mode = ""
		_ace_params_target_row = null
		_ace_params_target_index = -1
		return
	_open_ace_params_dialog(descriptor, params_dialog_mode, _ace_picker_target_row, _ace_picker_target_condition_index, descriptor.build_default_params(), true)

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
	_open_ace_params_dialog(descriptor, "edit_condition", row, index, values, false)

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
	_open_ace_params_dialog(descriptor, "edit_action", row, index, values, false)

func _merge_ace_param_values(descriptor: ACEDescriptor, primary: Dictionary, fallback: Dictionary) -> Dictionary:
	var values: Dictionary = descriptor.build_default_params()
	var source: Dictionary = primary if not primary.is_empty() else fallback
	for key: Variant in source.keys():
		values[key] = source[key]
	return values

func _open_ace_params_dialog(descriptor: ACEDescriptor, mode: String, row: EventRowUI, index: int, values: Dictionary, from_picker: bool = false) -> void:
	if _ace_params_dialog == null or _ace_params_form == null or descriptor == null:
		return
	_ace_params_mode = mode
	_ace_params_descriptor = descriptor
	_ace_params_target_row = row
	_ace_params_target_index = index
	_ace_params_existing_values = values.duplicate(true)
	_ace_params_fields.clear()
	_ace_params_from_picker = from_picker
	if _ace_params_back_button != null:
		_ace_params_back_button.visible = from_picker

	for child: Node in _ace_params_form.get_children():
		_ace_params_form.remove_child(child)
		child.queue_free()

	_ace_params_dialog.title = "%s Parameters" % descriptor.get_list_name()
	_ace_params_hint_base_text = descriptor.description if not descriptor.description.is_empty() else descriptor.get_display_text()
	_ace_params_hint.text = _ace_params_hint_base_text

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
			var row_box: VBoxContainer = VBoxContainer.new()
			row_box.add_theme_constant_override("separation", 2)
			row_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL

			var form_row: HBoxContainer = HBoxContainer.new()
			form_row.add_theme_constant_override("separation", 8)
			form_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var label: Label = Label.new()
			label.text = param.get_param_name()
			label.custom_minimum_size = Vector2(ACE_PARAMS_LABEL_WIDTH, ACE_PARAMS_LABEL_MIN_HEIGHT)
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			form_row.add_child(label)

			var input: Control = _create_ace_param_input(param, _ace_params_existing_values.get(key, param.get_initial_value()))
			input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var input_host: Control = input
			if _param_supports_expression_picker(param, input):
				var inline_row: HBoxContainer = HBoxContainer.new()
				inline_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				inline_row.add_theme_constant_override("separation", 6)
				inline_row.add_child(input)
				var expression_btn: Button = Button.new()
				expression_btn.text = "ƒx"
				expression_btn.tooltip_text = "Insert expression…"
				expression_btn.connect("pressed", _on_expression_insert_requested.bind(input))
				inline_row.add_child(expression_btn)
				input_host = inline_row
			form_row.add_child(input_host)
			_ace_params_fields[key] = {
				"param": param,
				"input": input
			}
			row_box.add_child(form_row)

			var desc: String = param.get_param_description()
			if not desc.is_empty():
				var desc_label: Label = Label.new()
				desc_label.text = desc
				desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				desc_label.add_theme_color_override("font_color", Color(0.55, 0.60, 0.65))
				row_box.add_child(desc_label)
			_ace_params_form.add_child(row_box)

	_refresh_ace_params_dialog_confirm_state()
	_ace_params_dialog.reset_size()
	_ace_params_dialog.popup_centered(ACE_PARAMS_DIALOG_SIZE)

func _param_supports_expression_picker(param: ACEParam, input: Control) -> bool:
	if param == null or not (input is LineEdit):
		return false
	return EXPRESSION_PARAM_HINTS.has(param.hint.to_lower())

func _on_expression_insert_requested(target_input: Control) -> void:
	if not (target_input is LineEdit):
		return
	_open_expression_picker(target_input as LineEdit)

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
## Shows an explicit empty-state item when no variables are available.
func _create_variable_dropdown(current_value: String) -> OptionButton:
	var option: OptionButton = OptionButton.new()
	var var_names: Array[String] = _get_available_variable_names()
	if var_names.is_empty():
		option.add_item(NO_VARIABLES_AVAILABLE_TEXT)
		option.set_item_disabled(0, true)
		option.select(0)
		option.disabled = true
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
		var selected_text: String = option.get_item_text(selected)
		if param.hint == "variable_reference" and selected_text == NO_VARIABLES_AVAILABLE_TEXT:
			return ""
		return selected_text
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
	if _has_missing_variable_reference_selection():
		_refresh_ace_params_dialog_confirm_state()
		return
	var values: Dictionary = _collect_ace_param_values()
	_apply_ace_params(values)

func _on_ace_params_dialog_custom_action(action: StringName) -> void:
	if action == "back":
		_go_back_to_picker()

## Closes the param dialog and reopens the ACE picker, preserving the picker context.
func _go_back_to_picker() -> void:
	if _ace_params_dialog != null:
		_ace_params_dialog.hide()
	if not _ace_params_from_picker:
		return
	_reshow_ace_picker_for_current_mode()

## Reopens the ACE picker for the current _ace_picker_mode without requiring a param dialog.
func _reshow_ace_picker_for_current_mode() -> void:
	match _ace_picker_mode:
		"new_event":
			_show_ace_picker("Add Event", true, true, false)
		"append_condition":
			_show_ace_picker("Add Condition", false, true, false)
		"replace_condition":
			_show_ace_picker("Replace Condition", false, true, false)
		"append_action":
			_show_ace_picker("Add Action", false, false, true)
		"replace_action":
			_show_ace_picker("Replace Action", false, false, true)

func _refresh_ace_params_dialog_confirm_state() -> void:
	if _ace_params_dialog == null:
		return
	var has_invalid_variable_selection: bool = _has_missing_variable_reference_selection()
	var ok_button: Button = _ace_params_dialog.get_ok_button()
	if ok_button != null:
		ok_button.disabled = has_invalid_variable_selection
	if has_invalid_variable_selection:
		_ace_params_hint.text = "%s\n%s" % [_ace_params_hint_base_text, NO_VARIABLES_AVAILABLE_HINT_TEXT]
	else:
		_ace_params_hint.text = _ace_params_hint_base_text

func _has_missing_variable_reference_selection() -> bool:
	for key: Variant in _ace_params_fields.keys():
		var entry_dict: Variant = _ace_params_fields[key]
		if not (entry_dict is Dictionary):
			continue
		var entry: Dictionary = entry_dict as Dictionary
		var typed_param: ACEParam = entry.get("param")
		if typed_param == null or typed_param.hint != "variable_reference":
			continue
		var input_control: Variant = entry.get("input")
		if not (input_control is OptionButton):
			return true
		var option: OptionButton = input_control as OptionButton
		if option.item_count <= 0:
			return true
		var selected: int = option.selected
		if selected < 0:
			selected = option.get_selected_id()
		if selected < 0:
			return true
		if option.get_item_text(selected) == NO_VARIABLES_AVAILABLE_TEXT:
			return true
	return false

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
		"replace_action":
			_replace_action_with_params(_ace_params_descriptor, _ace_params_target_index, values)
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
	_mark_dirty()
	_set_status("Added event: %s" % descriptor.get_list_name())

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
	_mark_dirty()
	_set_status("Added event: %s" % descriptor.get_list_name())

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
	_mark_dirty()

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
	_mark_dirty()

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
	_mark_dirty()

func _replace_action_with_params(descriptor: ACEDescriptor, index: int, params: Dictionary) -> void:
	var row: EventRowUI = _ace_params_target_row
	if row == null or row.event_row == null or descriptor == null:
		return
	if index < 0 or index >= row.event_row.actions.size():
		return
	var action: ACEAction = ACEAction.new()
	action.provider_id = descriptor.provider_id
	action.ace_id = descriptor.ace_id
	_set_action_params(action, params)
	row.event_row.actions[index] = action
	row.refresh()
	_rebuild_inspector_event(row)
	_mark_dirty()

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
	_mark_dirty()

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
	_mark_dirty()

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
		_set_status("Variable name cannot be empty", true)
		return
	var is_editing: bool = _variable_dialog_mode == "edit"
	if current_sheet.variables.has(new_name) and (not is_editing or new_name != _variable_dialog_original_name):
		_set_status("Variable name already exists: %s" % new_name, true)
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
	_mark_dirty()
	if is_editing:
		_set_status("Updated variable: %s" % new_name)
	else:
		_set_status("Added variable: %s" % new_name)

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

func _focus_comment_row(comment_row: CommentRow) -> void:
	if comment_row == null:
		return
	var row_ui: CommentRowUI = _find_comment_row_ui_by_resource(_canvas_vbox, comment_row)
	if row_ui != null:
		_on_comment_selected(row_ui)

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

func _find_event_row_resource_by_uid(arr: Array, event_uid: String) -> EventRow:
	for resource: Variant in arr:
		if resource is EventRow:
			var event_row: EventRow = resource as EventRow
			if event_row.event_uid == event_uid:
				return event_row
			var nested: EventRow = _find_event_row_resource_by_uid(event_row.sub_events, event_uid)
			if nested != null:
				return nested
		elif resource is EventGroup:
			var event_group: EventGroup = resource as EventGroup
			var from_events: EventRow = _find_event_row_resource_by_uid(event_group.events, event_uid)
			if from_events != null:
				return from_events
			var from_rows: EventRow = _find_event_row_resource_by_uid(event_group.rows, event_uid)
			if from_rows != null:
				return from_rows
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

func _find_comment_row_ui_by_resource(node: Node, comment_row: CommentRow) -> CommentRowUI:
	if node is CommentRowUI:
		var row_ui: CommentRowUI = node as CommentRowUI
		if row_ui.comment_row == comment_row:
			return row_ui
	for child: Node in node.get_children():
		var nested: CommentRowUI = _find_comment_row_ui_by_resource(child, comment_row)
		if nested != null:
			return nested
	return null

func _add_document_header() -> void:
	var header_panel: PanelContainer = PanelContainer.new()
	header_panel.name = "SheetDocumentHeader"
	var hstyle: StyleBoxFlat = StyleBoxFlat.new()
	hstyle.bg_color = Color(0.089, 0.104, 0.140, 1.0)
	hstyle.border_color = Color(0.205, 0.246, 0.326, 1.0)
	hstyle.set_border_width_all(1)
	hstyle.border_width_left = 3
	hstyle.set_corner_radius_all(6)
	hstyle.set_content_margin(SIDE_LEFT, 12)
	hstyle.set_content_margin(SIDE_RIGHT, 12)
	hstyle.set_content_margin(SIDE_TOP, 7)
	hstyle.set_content_margin(SIDE_BOTTOM, 7)
	header_panel.add_theme_stylebox_override("panel", hstyle)

	var shell: VBoxContainer = VBoxContainer.new()
	shell.add_theme_constant_override("separation", 3)
	header_panel.add_child(shell)

	var line: HBoxContainer = HBoxContainer.new()
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_theme_constant_override("separation", 8)
	shell.add_child(line)

	var title: Label = Label.new()
	title.text = _format_document_title(current_sheet)
	title.add_theme_color_override("font_color", Color(0.88, 0.94, 1.0))
	title.add_theme_font_size_override("font_size", 13)
	line.add_child(title)

	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(spacer)

	var subtitle: Label = Label.new()
	if current_sheet == null:
		subtitle.text = "Ready to author"
	else:
		subtitle.text = "%d globals • %d root entries" % [current_sheet.variables.size(), current_sheet.events.size()]
	subtitle.add_theme_color_override("font_color", Color(0.55, 0.68, 0.88))
	subtitle.add_theme_font_size_override("font_size", 10)
	line.add_child(subtitle)

	var path_hint: Label = Label.new()
	path_hint.text = _format_document_path_hint(current_sheet)
	path_hint.add_theme_color_override("font_color", Color(0.42, 0.52, 0.68))
	path_hint.add_theme_font_size_override("font_size", 9)
	shell.add_child(path_hint)

	_canvas_vbox.add_child(header_panel)

func _add_section_shell(name: String, title: String, subtitle: String, accent: Color, action_text: String = "", action_handler: Callable = Callable(), framed: bool = true) -> VBoxContainer:
	var section_host: Control
	var section_vbox: VBoxContainer = VBoxContainer.new()
	section_vbox.add_theme_constant_override("separation", 4)
	if framed:
		var section_panel: PanelContainer = PanelContainer.new()
		section_panel.name = name
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = Color(0.068, 0.075, 0.100, 1.0)
		style.border_color = Color(0.165, 0.190, 0.244, 1.0)
		style.set_border_width_all(1)
		style.border_width_left = 3
		style.set_corner_radius_all(6)
		style.set_content_margin(SIDE_LEFT, 9)
		style.set_content_margin(SIDE_RIGHT, 9)
		style.set_content_margin(SIDE_TOP, 7)
		style.set_content_margin(SIDE_BOTTOM, 7)
		section_panel.add_theme_stylebox_override("panel", style)
		_canvas_vbox.add_child(section_panel)
		section_panel.add_child(section_vbox)
		section_host = section_panel
	else:
		var section_box: VBoxContainer = VBoxContainer.new()
		section_box.name = name
		section_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		section_box.add_theme_constant_override("separation", 3)
		_canvas_vbox.add_child(section_box)
		section_box.add_child(section_vbox)
		section_host = section_box

	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section_vbox.add_child(header)

	var accent_rail: ColorRect = ColorRect.new()
	accent_rail.custom_minimum_size = Vector2(3, 0)
	accent_rail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	accent_rail.color = accent
	header.add_child(accent_rail)

	var title_label: Label = Label.new()
	title_label.text = title
	title_label.add_theme_color_override("font_color", accent)
	title_label.add_theme_font_size_override("font_size", 11)
	header.add_child(title_label)

	var sub: Label = Label.new()
	sub.text = subtitle
	sub.add_theme_color_override("font_color", Color(0.50, 0.58, 0.74))
	sub.add_theme_font_size_override("font_size", 9)
	header.add_child(sub)

	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	if not action_text.is_empty() and action_handler.is_valid():
		var action_btn: Button = Button.new()
		action_btn.text = action_text
		action_btn.flat = true
		action_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		action_btn.add_theme_color_override("font_color", accent)
		action_btn.add_theme_color_override("font_hover_color", Color(0.88, 0.94, 1.0))
		action_btn.connect("pressed", action_handler)
		header.add_child(action_btn)

	var header_sep: HSeparator = HSeparator.new()
	header_sep.add_theme_color_override("color", Color(accent.r, accent.g, accent.b, 0.30))
	section_vbox.add_child(header_sep)

	var body: VBoxContainer = VBoxContainer.new()
	body.add_theme_constant_override("separation", 2)
	section_vbox.add_child(body)
	if not framed:
		body.add_theme_constant_override("separation", 1)
	section_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return body

func _add_variables_section() -> void:
	var section_body: VBoxContainer = _add_section_shell("SheetSectionGlobals", "Globals", "Project-level data", Color(0.62, 0.80, 1.0), "+ Variable", Callable(self, "_on_add_variable_requested"))

	var variables: Dictionary = current_sheet.variables
	if variables.is_empty():
		section_body.add_child(_make_section_empty_card("No global variables yet — add one to seed authored clauses."))
		return

	var sorted_keys: Array = variables.keys()
	sorted_keys.sort()
	for key: Variant in sorted_keys:
		var row: VariableRowUI = VariableRowUI.new()
		row.var_name = str(key)
		row.var_info = variables[key] if variables[key] is Dictionary else {}
		row.set_depth(0)
		row.refresh()
		row.variable_selected.connect(_on_variable_selected)
		row.variable_delete_requested.connect(_on_variable_delete_requested)
		section_body.add_child(row)

func _add_events_section() -> void:
	var section_body: VBoxContainer = _add_section_shell("SheetSectionEvents", "Events", "Continuous row surface", Color(0.78, 0.87, 1.0), "", Callable(), false)
	_current_rows_host = section_body
	_add_canvas_row(_make_add_event_anchor_row(), 0)

	if current_sheet.events.is_empty():
		section_body.add_child(_make_section_empty_card("No events yet — start by adding an event line."))
	else:
		var render_guard: Dictionary = {}
		for resource: Variant in current_sheet.events:
			_add_event_resource(resource, 0, render_guard)
	_current_rows_host = null

func _make_add_event_anchor_row() -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 4)

	var add_btn: Button = Button.new()
	add_btn.text = "Add Event"
	add_btn.flat = true
	add_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_btn.tooltip_text = "Add event line"
	add_btn.add_theme_color_override("font_color", Color(0.72, 0.84, 1.0))
	add_btn.add_theme_color_override("font_hover_color", Color(0.90, 0.96, 1.0))
	add_btn.add_theme_font_size_override("font_size", 11)
	var btn_style: StyleBoxFlat = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.114, 0.140, 0.196, 1.0)
	btn_style.border_color = Color(0.262, 0.342, 0.498, 1.0)
	btn_style.set_border_width_all(1)
	btn_style.border_width_left = 3
	btn_style.set_corner_radius_all(0)
	btn_style.set_content_margin(SIDE_LEFT, 7)
	btn_style.set_content_margin(SIDE_RIGHT, 7)
	btn_style.set_content_margin(SIDE_TOP, 3)
	btn_style.set_content_margin(SIDE_BOTTOM, 3)
	add_btn.add_theme_stylebox_override("normal", btn_style)
	var btn_hover: StyleBoxFlat = btn_style.duplicate()
	btn_hover.bg_color = Color(0.136, 0.167, 0.232, 1.0)
	add_btn.add_theme_stylebox_override("hover", btn_hover)
	add_btn.add_theme_stylebox_override("pressed", btn_hover)
	add_btn.add_theme_stylebox_override("focus", btn_hover)
	add_btn.connect("pressed", Callable(self, "_on_add_event_requested"))
	row.add_child(add_btn)

	var add_comment_btn: Button = Button.new()
	add_comment_btn.text = "Add Comment"
	add_comment_btn.flat = true
	add_comment_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_comment_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_comment_btn.tooltip_text = "Add inline comment row"
	add_comment_btn.add_theme_color_override("font_color", Color(0.90, 0.82, 0.62))
	add_comment_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.93, 0.76))
	add_comment_btn.add_theme_font_size_override("font_size", 11)
	var comment_btn_style: StyleBoxFlat = btn_style.duplicate()
	comment_btn_style.bg_color = Color(0.174, 0.142, 0.090, 1.0)
	comment_btn_style.border_color = Color(0.426, 0.332, 0.186, 1.0)
	add_comment_btn.add_theme_stylebox_override("normal", comment_btn_style)
	var comment_btn_hover: StyleBoxFlat = comment_btn_style.duplicate()
	comment_btn_hover.bg_color = Color(0.205, 0.168, 0.108, 1.0)
	add_comment_btn.add_theme_stylebox_override("hover", comment_btn_hover)
	add_comment_btn.add_theme_stylebox_override("pressed", comment_btn_hover)
	add_comment_btn.add_theme_stylebox_override("focus", comment_btn_hover)
	add_comment_btn.connect("pressed", Callable(self, "_on_add_comment_requested"))
	row.add_child(add_comment_btn)
	return row

func _add_event_resource(resource: Variant, indent_level: int, render_guard: Dictionary = {}) -> void:
	if resource is EventRow:
		_add_event_row(resource as EventRow, indent_level, render_guard)
	elif resource is EventGroup:
		_add_group_row(resource as EventGroup, indent_level, render_guard)
	elif resource is CommentRow:
		_add_comment_row(resource as CommentRow, indent_level, render_guard)

func _add_event_row(event_row: EventRow, indent_level: int = 0, render_guard: Dictionary = {}) -> void:
	var row_key: String = _make_render_guard_key("event", event_row.event_uid, event_row.get_instance_id())
	if render_guard.has(row_key):
		return
	render_guard[row_key] = true
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
	row_ui.action_replace_requested.connect(_on_action_replace_requested)
	row_ui.add_condition_requested.connect(_on_row_add_condition_requested)
	row_ui.add_action_requested.connect(_on_row_add_action_requested)
	row_ui.insert_event_above_requested.connect(_on_event_insert_above_requested)
	row_ui.insert_event_below_requested.connect(_on_event_insert_below_requested)
	row_ui.event_delete_requested.connect(_on_event_delete_requested)
	row_ui.condition_delete_requested.connect(_on_condition_delete_requested)
	row_ui.action_delete_requested.connect(_on_action_delete_requested)
	row_ui.condition_move_requested.connect(_on_condition_move_requested)
	row_ui.action_move_requested.connect(_on_action_move_requested)
	row_ui.comment_drop_requested.connect(_on_comment_drop_on_event_requested)
	_add_canvas_row(row_ui, indent_level)

	for sub_resource: Variant in event_row.sub_events:
		_add_event_resource(sub_resource, indent_level + 1, render_guard)

func _add_group_row(event_group: EventGroup, indent_level: int = 0, render_guard: Dictionary = {}) -> void:
	var group_key: String = _make_render_guard_key("group", event_group.group_uid, event_group.get_instance_id())
	if render_guard.has(group_key):
		return
	render_guard[group_key] = true
	var row_ui: GroupRowUI = GroupRowUI.new()
	row_ui.event_group = event_group
	row_ui.refresh()
	row_ui.group_selected.connect(_on_group_selected)
	row_ui.group_collapsed_toggled.connect(_on_group_collapsed_toggled)
	row_ui.insert_event_above_requested.connect(_on_group_insert_above_requested)
	row_ui.insert_event_below_requested.connect(_on_group_insert_below_requested)
	row_ui.group_delete_requested.connect(_on_group_delete_requested)
	_add_canvas_row(row_ui, indent_level)

	if _is_group_collapsed(event_group):
		return

	var child_rows: Array = event_group.events if not event_group.events.is_empty() else event_group.rows
	for child: Variant in child_rows:
		_add_event_resource(child, indent_level + 1, render_guard)

func _add_comment_row(comment_row: CommentRow, indent_level: int = 0, render_guard: Dictionary = {}) -> void:
	var comment_key: String = _make_render_guard_key("comment", "", comment_row.get_instance_id())
	if render_guard.has(comment_key):
		return
	render_guard[comment_key] = true
	var row_ui: CommentRowUI = CommentRowUI.new()
	row_ui.comment_row = comment_row
	row_ui.refresh()
	row_ui.comment_selected.connect(_on_comment_selected)
	row_ui.comment_delete_requested.connect(_on_comment_delete_requested)
	row_ui.insert_comment_above_requested.connect(_on_comment_insert_above_requested)
	row_ui.insert_comment_below_requested.connect(_on_comment_insert_below_requested)
	row_ui.comment_text_changed.connect(_on_comment_text_changed)
	row_ui.comment_text_submitted.connect(_on_comment_text_submitted)
	row_ui.comment_drop_requested.connect(_on_comment_drop_on_comment_requested)
	_add_canvas_row(row_ui, indent_level)

func _make_render_guard_key(prefix: String, stable_uid: String, fallback_instance_id: int) -> String:
	if not stable_uid.is_empty():
		return "%s:%s" % [prefix, stable_uid]
	return "%s:%s" % [prefix, str(fallback_instance_id)]

func _add_canvas_row(row: Control, indent_level: int) -> void:
	if row == null:
		return
	if row.has_method("set_depth"):
		row.call("set_depth", indent_level)
	var wrap_margin: MarginContainer = MarginContainer.new()
	wrap_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap_margin.add_theme_constant_override("margin_top", 0)
	wrap_margin.add_theme_constant_override("margin_bottom", 0)
	var line: HBoxContainer = HBoxContainer.new()
	line.name = "SheetLineRow"
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_theme_constant_override("separation", 1)
	wrap_margin.add_child(line)

	var gutter: HBoxContainer = HBoxContainer.new()
	gutter.name = "SheetGutter"
	gutter.add_theme_constant_override("separation", 3)
	gutter.custom_minimum_size = Vector2(14 + (11 * indent_level), 0)
	gutter.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gutter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(gutter)

	var root_pin: Label = Label.new()
	root_pin.text = "│"
	root_pin.add_theme_color_override("font_color", Color(0.48, 0.60, 0.80))
	root_pin.add_theme_font_size_override("font_size", 9)
	gutter.add_child(root_pin)

	for i: int in range(indent_level):
		var guide: ColorRect = ColorRect.new()
		guide.custom_minimum_size = Vector2(1, 0)
		guide.size_flags_vertical = Control.SIZE_EXPAND_FILL
		guide.color = Color(0.33, 0.42, 0.58, 0.92)
		gutter.add_child(guide)

	if indent_level > 0:
		var branch: Label = Label.new()
		branch.text = BRANCH_GUIDE_LABEL
		branch.add_theme_color_override("font_color", Color(0.62, 0.72, 0.92))
		branch.add_theme_font_size_override("font_size", 9)
		gutter.add_child(branch)

	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(row)
	var host: Node = _current_rows_host if _current_rows_host != null else _canvas_vbox
	host.add_child(wrap_margin)

func _refresh_row_selection_states() -> void:
	if _canvas_vbox == null:
		return
	_refresh_row_selection_states_recursive(_canvas_vbox)

func _refresh_row_selection_states_recursive(node: Node) -> void:
	if node == null:
		return
	if node is EventRowUI:
		var event_row_ui: EventRowUI = node as EventRowUI
		event_row_ui.set_selected(_selected_row == event_row_ui)
	elif node is VariableRowUI:
		var variable_row_ui: VariableRowUI = node as VariableRowUI
		variable_row_ui.set_selected(_selected_row == variable_row_ui)
	elif node is GroupRowUI:
		var group_row_ui: GroupRowUI = node as GroupRowUI
		group_row_ui.set_selected(_selected_row == group_row_ui)
	elif node is CommentRowUI:
		var comment_row_ui: CommentRowUI = node as CommentRowUI
		comment_row_ui.set_selected(_selected_row == comment_row_ui)
	for child: Node in node.get_children():
		_refresh_row_selection_states_recursive(child)

# ── Selection handlers ────────────────────────────────────────────────────────

func _on_event_selected(row: EventRowUI) -> void:
	_selected_entry_kind = "event"
	_selected_row = row
	_selected_index = -1
	_refresh_row_selection_states()
	_refresh_workspace_context()
	_rebuild_inspector_event(row)

func _on_condition_selected(row: EventRowUI, index: int) -> void:
	_selected_entry_kind = "condition"
	_selected_row = row
	_selected_index = index
	_refresh_row_selection_states()
	_refresh_workspace_context()
	_open_condition_params_dialog(row, index)

func _on_condition_edit_requested(row: EventRowUI, index: int) -> void:
	_on_condition_selected(row, index)

func _on_condition_add_another_requested(row: EventRowUI, _index: int) -> void:
	if row == null or row.event_row == null:
		return
	_selected_entry_kind = "event"
	_selected_row = row
	_selected_index = -1
	_refresh_row_selection_states()
	_refresh_workspace_context()
	_open_add_condition_picker(row)

func _on_condition_replace_requested(row: EventRowUI, index: int) -> void:
	if row == null or row.event_row == null:
		return
	if index < 0 or index >= row.event_row.conditions.size():
		return
	_selected_entry_kind = "condition"
	_selected_row = row
	_selected_index = index
	_refresh_row_selection_states()
	_refresh_workspace_context()
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
	_refresh_inspector_for_current_selection()
	_mark_dirty()

func _on_action_selected(row: EventRowUI, index: int) -> void:
	_selected_entry_kind = "action"
	_selected_row = row
	_selected_index = index
	_refresh_row_selection_states()
	_refresh_workspace_context()
	_open_action_params_dialog(row, index)

func _on_action_replace_requested(row: EventRowUI, index: int) -> void:
	if row == null or row.event_row == null:
		return
	if index < 0 or index >= row.event_row.actions.size():
		return
	_selected_entry_kind = "action"
	_selected_row = row
	_selected_index = index
	_refresh_row_selection_states()
	_refresh_workspace_context()
	_open_replace_action_picker(row, index)

func _on_row_add_condition_requested(row: EventRowUI) -> void:
	if row == null or row.event_row == null:
		return
	_selected_entry_kind = "event"
	_selected_row = row
	_selected_index = -1
	_refresh_row_selection_states()
	_refresh_workspace_context()
	_open_add_condition_picker(row)

func _on_row_add_action_requested(row: EventRowUI) -> void:
	if row == null or row.event_row == null:
		return
	_selected_entry_kind = "event"
	_selected_row = row
	_selected_index = -1
	_refresh_row_selection_states()
	_refresh_workspace_context()
	_open_add_action_picker(row)

func _on_event_insert_above_requested(row: EventRowUI) -> void:
	if row == null or row.event_row == null:
		return
	_insert_new_event_relative(row.event_row.event_uid, "event", false)

func _on_event_insert_below_requested(row: EventRowUI) -> void:
	if row == null or row.event_row == null:
		return
	_insert_new_event_relative(row.event_row.event_uid, "event", true)

func _on_group_insert_above_requested(row: GroupRowUI) -> void:
	if row == null or row.event_group == null:
		return
	_insert_new_event_relative(row.event_group.group_uid, "group", false)

func _on_group_insert_below_requested(row: GroupRowUI) -> void:
	if row == null or row.event_group == null:
		return
	_insert_new_event_relative(row.event_group.group_uid, "group", true)

func _on_event_delete_requested(row: EventRowUI) -> void:
	if row == null or row.event_row == null:
		return
	var uid: String = row.event_row.event_uid
	_delete_event_by_uid(uid)

func _on_condition_delete_requested(row: EventRowUI, index: int) -> void:
	if row == null or row.event_row == null:
		return
	if index < 0 or index >= row.event_row.conditions.size():
		return
	row.event_row.conditions.remove_at(index)
	row.refresh()
	if _selected_row == row and _selected_entry_kind == "condition":
		if _selected_index == index:
			_selected_entry_kind = "event"
			_selected_index = -1
		elif _selected_index > index:
			_selected_index -= 1
	_refresh_row_selection_states()
	_refresh_workspace_context()
	_refresh_inspector_for_current_selection()
	_mark_dirty()

func _on_action_delete_requested(row: EventRowUI, index: int) -> void:
	if row == null or row.event_row == null:
		return
	if index < 0 or index >= row.event_row.actions.size():
		return
	row.event_row.actions.remove_at(index)
	row.refresh()
	if _selected_row == row and _selected_entry_kind == "action":
		if _selected_index == index:
			_selected_entry_kind = "event"
			_selected_index = -1
		elif _selected_index > index:
			_selected_index -= 1
	_refresh_row_selection_states()
	_refresh_workspace_context()
	_refresh_inspector_for_current_selection()
	_mark_dirty()

func _on_condition_move_requested(source_event_uid: String, source_index: int, target_row: EventRowUI, target_index: int) -> void:
	if current_sheet == null or target_row == null or target_row.event_row == null:
		return
	var source_event: EventRow = _find_event_row_resource_by_uid(current_sheet.events, source_event_uid)
	var target_event: EventRow = target_row.event_row
	if source_event == null:
		return
	if source_index < 0 or source_index >= source_event.conditions.size():
		return
	var moving_condition: ACECondition = source_event.conditions[source_index] as ACECondition
	if moving_condition == null:
		return
	source_event.conditions.remove_at(source_index)
	var insert_index: int = target_index
	if insert_index < 0:
		insert_index = target_event.conditions.size()
	if source_event == target_event and insert_index > source_index:
		insert_index -= 1
	insert_index = clampi(insert_index, 0, target_event.conditions.size())
	target_event.conditions.insert(insert_index, moving_condition)
	refresh_canvas()
	var focus_row: EventRowUI = _find_event_row_ui_by_uid(_canvas_vbox, target_event.event_uid)
	if focus_row != null:
		_selected_entry_kind = "condition"
		_selected_row = focus_row
		_selected_index = insert_index
		_refresh_row_selection_states()
		_refresh_workspace_context()
		_refresh_inspector_for_current_selection()
	_mark_dirty()
	_set_status("Moved condition")

func _on_action_move_requested(source_event_uid: String, source_index: int, target_row: EventRowUI, target_index: int) -> void:
	if current_sheet == null or target_row == null or target_row.event_row == null:
		return
	var source_event: EventRow = _find_event_row_resource_by_uid(current_sheet.events, source_event_uid)
	var target_event: EventRow = target_row.event_row
	if source_event == null:
		return
	if source_index < 0 or source_index >= source_event.actions.size():
		return
	var moving_action: ACEAction = source_event.actions[source_index] as ACEAction
	if moving_action == null:
		return
	source_event.actions.remove_at(source_index)
	var insert_index: int = target_index
	if insert_index < 0:
		insert_index = target_event.actions.size()
	if source_event == target_event and insert_index > source_index:
		insert_index -= 1
	insert_index = clampi(insert_index, 0, target_event.actions.size())
	target_event.actions.insert(insert_index, moving_action)
	refresh_canvas()
	var focus_row: EventRowUI = _find_event_row_ui_by_uid(_canvas_vbox, target_event.event_uid)
	if focus_row != null:
		_selected_entry_kind = "action"
		_selected_row = focus_row
		_selected_index = insert_index
		_refresh_row_selection_states()
		_refresh_workspace_context()
		_refresh_inspector_for_current_selection()
	_mark_dirty()
	_set_status("Moved action")

func _on_comment_drop_on_event_requested(target_row: EventRowUI, source_comment: CommentRow, insert_after: bool) -> void:
	if current_sheet == null or target_row == null or target_row.event_row == null or source_comment == null:
		return
	if not _remove_resource_from_rows(current_sheet.events, source_comment):
		return
	if not _insert_resource_relative_in_array(current_sheet.events, target_row.event_row, insert_after, source_comment):
		return
	refresh_canvas()
	_focus_comment_row(source_comment)
	_mark_dirty()
	_set_status("Moved comment")

func _on_comment_drop_on_comment_requested(target_row: CommentRowUI, source_comment: CommentRow, insert_after: bool) -> void:
	if current_sheet == null or target_row == null or target_row.comment_row == null or source_comment == null:
		return
	if source_comment == target_row.comment_row:
		return
	if not _remove_resource_from_rows(current_sheet.events, source_comment):
		return
	if not _insert_resource_relative_in_array(current_sheet.events, target_row.comment_row, insert_after, source_comment):
		return
	refresh_canvas()
	_focus_comment_row(source_comment)
	_mark_dirty()
	_set_status("Moved comment")

func _delete_event_by_uid(uid: String) -> void:
	if current_sheet == null or uid.is_empty():
		return
	for i: int in range(current_sheet.events.size() - 1, -1, -1):
		var resource: Variant = current_sheet.events[i]
		if resource is EventRow and (resource as EventRow).event_uid == uid:
			current_sheet.events.remove_at(i)
			_reset_selection_state()
			refresh_canvas()
			_show_empty_inspector()
			_refresh_workspace_context()
			_mark_dirty()
			_set_status("Event deleted")
			return
	for event_resource: Variant in current_sheet.events:
		if event_resource is EventRow:
			if _remove_sub_event_by_uid(event_resource as EventRow, uid):
				_reset_selection_state()
				refresh_canvas()
				_show_empty_inspector()
				_refresh_workspace_context()
				_mark_dirty()
				_set_status("Event deleted")
				return

func _insert_new_event_relative(target_uid: String, target_kind: String, insert_after: bool) -> void:
	if current_sheet == null:
		_set_status("No sheet loaded for insertion", true)
		return
	if target_uid.is_empty():
		_set_status("Cannot insert relative to an empty target row id", true)
		return
	var new_event: EventRow = _make_default_insert_event_row()
	if not _insert_event_relative_in_array(current_sheet.events, target_uid, target_kind, insert_after, new_event):
		_set_status("Could not locate target row for insertion", true)
		return
	refresh_canvas()
	_focus_event_by_uid(new_event.event_uid)
	_mark_dirty()
	var direction: String = "below" if insert_after else "above"
	_set_status("Inserted event %s" % direction)

func _make_default_insert_event_row() -> EventRow:
	var new_event: EventRow = EventRow.new()
	new_event.trigger_provider_id = "Core"
	new_event.trigger_id = DEFAULT_RUN_CONTEXT_ACE_ID
	return new_event

func _insert_event_relative_in_array(arr: Array, target_uid: String, target_kind: String, insert_after: bool, new_event: EventRow) -> bool:
	for i: int in range(arr.size()):
		var resource: Variant = arr[i]
		if target_kind == "event" and resource is EventRow:
			var event_row: EventRow = resource as EventRow
			if event_row.event_uid == target_uid:
				var event_insert_index: int = i + (1 if insert_after else 0)
				arr.insert(event_insert_index, new_event)
				return true
		elif target_kind == "group" and resource is EventGroup:
			var event_group: EventGroup = resource as EventGroup
			if event_group.group_uid == target_uid:
				var group_insert_index: int = i + (1 if insert_after else 0)
				arr.insert(group_insert_index, new_event)
				return true

		if resource is EventRow:
			var nested_event: EventRow = resource as EventRow
			if _insert_event_relative_in_array(nested_event.sub_events, target_uid, target_kind, insert_after, new_event):
				return true
		elif resource is EventGroup:
			var nested_group: EventGroup = resource as EventGroup
			if _insert_event_relative_in_array(nested_group.events, target_uid, target_kind, insert_after, new_event):
				return true
			# `rows` is the legacy alias of `events`; older sheets may still carry children there.
			if _insert_event_relative_in_array(nested_group.rows, target_uid, target_kind, insert_after, new_event):
				return true
	return false

func _insert_new_comment_relative(target_resource: Resource, insert_after: bool) -> void:
	if current_sheet == null:
		_set_status("No sheet loaded for insertion", true)
		return
	if target_resource == null:
		_set_status("Cannot insert relative to an empty target row", true)
		return
	var new_comment: CommentRow = CommentRow.new()
	new_comment.text = "Comment"
	if not _insert_resource_relative_in_array(current_sheet.events, target_resource, insert_after, new_comment):
		_set_status("Could not locate target row for insertion", true)
		return
	refresh_canvas()
	_focus_comment_row(new_comment)
	_mark_dirty()
	var direction: String = "below" if insert_after else "above"
	_set_status("Inserted comment %s" % direction)

func _insert_resource_relative_in_array(arr: Array, target_resource: Resource, insert_after: bool, new_resource: Resource) -> bool:
	for i: int in range(arr.size()):
		var resource: Variant = arr[i]
		if resource == target_resource:
			var insert_index: int = i + (1 if insert_after else 0)
			arr.insert(insert_index, new_resource)
			return true
		if resource is EventRow:
			var nested_event: EventRow = resource as EventRow
			if _insert_resource_relative_in_array(nested_event.sub_events, target_resource, insert_after, new_resource):
				return true
		elif resource is EventGroup:
			var nested_group: EventGroup = resource as EventGroup
			if _insert_resource_relative_in_array(nested_group.events, target_resource, insert_after, new_resource):
				return true
			if _insert_resource_relative_in_array(nested_group.rows, target_resource, insert_after, new_resource):
				return true
	return false

func _remove_resource_from_rows(arr: Array, target_resource: Resource) -> bool:
	for i: int in range(arr.size()):
		var resource: Variant = arr[i]
		if resource == target_resource:
			arr.remove_at(i)
			return true
		if resource is EventRow:
			var event_row: EventRow = resource as EventRow
			if _remove_resource_from_rows(event_row.sub_events, target_resource):
				return true
		elif resource is EventGroup:
			var event_group: EventGroup = resource as EventGroup
			if _remove_resource_from_rows(event_group.events, target_resource):
				return true
			if _remove_resource_from_rows(event_group.rows, target_resource):
				return true
	return false

func _remove_sub_event_by_uid(parent: EventRow, uid: String) -> bool:
	for i: int in range(parent.sub_events.size()):
		var resource: Variant = parent.sub_events[i]
		if resource is EventRow and (resource as EventRow).event_uid == uid:
			parent.sub_events.remove_at(i)
			return true
		if resource is EventRow:
			if _remove_sub_event_by_uid(resource as EventRow, uid):
				return true
	return false

func _on_variable_selected(row: VariableRowUI) -> void:
	_selected_entry_kind = "variable"
	_selected_row = row
	_selected_variable_name = row.var_name
	_refresh_row_selection_states()
	_refresh_workspace_context()
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
	_refresh_row_selection_states()
	_refresh_workspace_context()
	_rebuild_inspector_group(row)

func _on_comment_selected(row: CommentRowUI) -> void:
	_selected_entry_kind = "comment"
	_selected_row = row
	_selected_index = -1
	_selected_group = null
	_selected_variable_name = ""
	_refresh_row_selection_states()
	_refresh_workspace_context()
	_rebuild_inspector_comment(row)

func _on_comment_text_changed(row: CommentRowUI, text: String) -> void:
	if row == null or row.comment_row == null:
		return
	if row.comment_row.text == text:
		return
	row.comment_row.text = text
	var is_selected_comment_row: bool = (_selected_entry_kind == "comment" and _selected_row == row)
	var has_sync_target: bool = (_comment_text_edit != null and not _comment_text_edit.has_focus())
	if is_selected_comment_row and has_sync_target and _comment_text_edit.text != text:
		_comment_text_edit.text = text
	_mark_dirty()

func _on_comment_text_submitted(row: CommentRowUI, text: String) -> void:
	_on_comment_text_changed(row, text)
	_set_status("Comment updated")

func _on_group_collapsed_toggled(row: GroupRowUI, _collapsed: bool) -> void:
	if row == null or row.event_group == null:
		return
	var group_uid: String = row.event_group.group_uid
	refresh_canvas()
	_focus_group_by_uid(group_uid)
	_mark_dirty()

func _on_variable_delete_requested(row: VariableRowUI) -> void:
	if row == null or current_sheet == null:
		return
	var var_name: String = row.var_name
	if not current_sheet.variables.has(var_name):
		return
	var was_selected: bool = (_selected_entry_kind == "variable" and _selected_variable_name == var_name)
	# Capture re-focus info before any state changes (canvas refresh invalidates row references).
	var refocus_event_uid: String = ""
	var refocus_var_name: String = ""
	var refocus_group_uid: String = ""
	if not was_selected:
		if _selected_entry_kind in ["event", "condition", "action"] and _selected_row is EventRowUI:
			var sel_event_row: EventRowUI = _selected_row as EventRowUI
			if sel_event_row.event_row != null:
				refocus_event_uid = sel_event_row.event_row.event_uid
		elif _selected_entry_kind == "variable":
			refocus_var_name = _selected_variable_name
		elif _selected_entry_kind == "group" and _selected_group is GroupRowUI:
			var sel_group_row: GroupRowUI = _selected_group as GroupRowUI
			if sel_group_row.event_group != null:
				refocus_group_uid = sel_group_row.event_group.group_uid
	current_sheet.variables.erase(var_name)
	if was_selected:
		_reset_selection_state()
	refresh_canvas()
	if was_selected:
		_show_empty_inspector()
	elif not refocus_event_uid.is_empty():
		_focus_event_by_uid(refocus_event_uid)
	elif not refocus_var_name.is_empty():
		_focus_variable_by_name(refocus_var_name)
	elif not refocus_group_uid.is_empty():
		_focus_group_by_uid(refocus_group_uid)
	_refresh_workspace_context()
	_mark_dirty()
	_set_status("Variable deleted: %s" % var_name)

func _on_group_delete_requested(row: GroupRowUI) -> void:
	if row == null or row.event_group == null or current_sheet == null:
		return
	var uid: String = row.event_group.group_uid
	_delete_group_by_uid(uid)

func _on_comment_delete_requested(row: CommentRowUI) -> void:
	if row == null or row.comment_row == null or current_sheet == null:
		return
	var was_selected: bool = (_selected_entry_kind == "comment" and _selected_row == row)
	if _remove_resource_from_rows(current_sheet.events, row.comment_row):
		if was_selected:
			_reset_selection_state()
		refresh_canvas()
		if was_selected:
			_show_empty_inspector()
		_refresh_workspace_context()
		_mark_dirty()
		_set_status("Comment deleted")

func _on_comment_insert_above_requested(row: CommentRowUI) -> void:
	if row == null or row.comment_row == null:
		return
	_insert_new_comment_relative(row.comment_row, false)

func _on_comment_insert_below_requested(row: CommentRowUI) -> void:
	if row == null or row.comment_row == null:
		return
	_insert_new_comment_relative(row.comment_row, true)

func _delete_group_by_uid(uid: String) -> void:
	if current_sheet == null or uid.is_empty():
		return
	var was_selected: bool = (_selected_entry_kind == "group" and _selected_group is GroupRowUI and (_selected_group as GroupRowUI).event_group != null and (_selected_group as GroupRowUI).event_group.group_uid == uid)
	# Capture re-focus info before any state changes (canvas refresh invalidates row references).
	var refocus_event_uid: String = ""
	var refocus_var_name: String = ""
	if not was_selected:
		if _selected_entry_kind in ["event", "condition", "action"] and _selected_row is EventRowUI:
			var sel_event_row: EventRowUI = _selected_row as EventRowUI
			if sel_event_row.event_row != null:
				refocus_event_uid = sel_event_row.event_row.event_uid
		elif _selected_entry_kind == "variable":
			refocus_var_name = _selected_variable_name
	if _remove_group_by_uid_from_array(current_sheet.events, uid):
		if was_selected:
			_reset_selection_state()
		refresh_canvas()
		if was_selected:
			_show_empty_inspector()
		elif not refocus_event_uid.is_empty():
			_focus_event_by_uid(refocus_event_uid)
		elif not refocus_var_name.is_empty():
			_focus_variable_by_name(refocus_var_name)
		_refresh_workspace_context()
		_mark_dirty()
		_set_status("Group deleted")

## Recursively removes the first EventGroup with the given uid from an array.
## Searches top-level entries and nested EventGroup.events/rows as well as EventRow.sub_events.
## Returns true if a match was found and removed.
func _remove_group_by_uid_from_array(arr: Array, uid: String) -> bool:
	for i: int in range(arr.size()):
		var resource: Variant = arr[i]
		if resource is EventGroup:
			var group: EventGroup = resource as EventGroup
			if group.group_uid == uid:
				arr.remove_at(i)
				return true
			if _remove_group_by_uid_from_array(group.events, uid):
				return true
			if not group.rows.is_empty() and _remove_group_by_uid_from_array(group.rows, uid):
				return true
		elif resource is EventRow:
			var event_row: EventRow = resource as EventRow
			if _remove_group_by_uid_from_array(event_row.sub_events, uid):
				return true
	return false

func _is_group_collapsed(event_group: EventGroup) -> bool:
	if event_group == null:
		return false
	return event_group.is_collapsed()

# ── Inspector builders ────────────────────────────────────────────────────────

func _clear_inspector() -> void:
	_comment_text_edit = null
	for child in _inspector_vbox.get_children():
		child.queue_free()

func _reset_selection_state() -> void:
	_selected_entry_kind = "none"
	_selected_row = null
	_selected_index = -1
	_selected_variable_name = ""
	_selected_group = null

## Creates a styled card container for inspector content.
func _make_inspector_card(border_accent: Color = Color(0.196, 0.223, 0.279, 1.0)) -> PanelContainer:
	var card: PanelContainer = PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.100, 0.112, 0.145, 1.0)
	style.border_color = border_accent
	style.set_border_width_all(1)
	style.border_width_left = 3
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10)
	card.add_theme_stylebox_override("panel", style)
	return card

## Creates a styled empty-state card for use inside section bodies.
func _make_section_empty_card(hint_text: String) -> PanelContainer:
	var card: PanelContainer = PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.070, 0.078, 0.102, 1.0)
	style.border_color = Color(0.150, 0.170, 0.220, 0.70)
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.set_content_margin_all(10)
	card.add_theme_stylebox_override("panel", style)
	var hint: Label = Label.new()
	hint.text = hint_text
	hint.add_theme_color_override("font_color", Color(0.48, 0.56, 0.68))
	hint.add_theme_font_size_override("font_size", 10)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(hint)
	return card

func _show_empty_inspector() -> void:
	_clear_inspector()
	_reset_selection_state()
	_refresh_row_selection_states()
	_refresh_workspace_context()
	var shell: PanelContainer = _make_inspector_card()

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	shell.add_child(vbox)

	var title: Label = Label.new()
	title.text = "Inspector"
	title.add_theme_color_override("font_color", Color(0.73, 0.83, 0.98))
	title.add_theme_font_size_override("font_size", 12)
	vbox.add_child(title)

	var heading_sep: HSeparator = HSeparator.new()
	heading_sep.add_theme_color_override("color", Color(0.196, 0.223, 0.279, 0.80))
	vbox.add_child(heading_sep)

	var hint: Label = Label.new()
	if current_sheet == null:
		hint.text = "Create or open an event sheet to start editing."
	else:
		hint.text = "Select an event, condition, action, variable, group, or comment row to edit it."
	hint.add_theme_color_override("font_color", Color(0.56, 0.63, 0.75))
	hint.add_theme_font_size_override("font_size", 10)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(hint)
	_inspector_vbox.add_child(shell)

func _refresh_inspector_for_current_selection() -> void:
	match _selected_entry_kind:
		"event", "condition", "action":
			if _selected_row is EventRowUI:
				_rebuild_inspector_event(_selected_row as EventRowUI)
				return
		"variable":
			if _selected_row is VariableRowUI:
				_rebuild_inspector_variable(_selected_row as VariableRowUI)
				return
		"group":
			if _selected_row is GroupRowUI:
				_rebuild_inspector_group(_selected_row as GroupRowUI)
				return
		"comment":
			if _selected_row is CommentRowUI:
				_rebuild_inspector_comment(_selected_row as CommentRowUI)
				return
	_show_empty_inspector()

## Rebuilds the inspector to show a compact event summary.
## Primary editing is handled through event block lanes and popups.
func _rebuild_inspector_event(row: EventRowUI) -> void:
	_clear_inspector()
	if row == null or row.event_row == null:
		_show_empty_inspector()
		return

	var event_row: EventRow = row.event_row

	var card: PanelContainer = _make_inspector_card(Color(0.196, 0.235, 0.320, 1.0))
	var card_vbox: VBoxContainer = VBoxContainer.new()
	card_vbox.add_theme_constant_override("separation", 4)
	card.add_child(card_vbox)

	var heading: Label = Label.new()
	heading.text = "Event"
	heading.add_theme_color_override("font_color", Color(0.55, 0.78, 1.0))
	heading.add_theme_font_size_override("font_size", 12)
	card_vbox.add_child(heading)

	var heading_sep: HSeparator = HSeparator.new()
	heading_sep.add_theme_color_override("color", Color(0.196, 0.235, 0.320, 0.80))
	card_vbox.add_child(heading_sep)

	var runs_lbl: Label = Label.new()
	runs_lbl.text = EventRowUI.format_run_context(event_row)
	runs_lbl.add_theme_color_override("font_color", Color(0.85, 0.75, 0.45))
	runs_lbl.add_theme_font_size_override("font_size", 10)
	runs_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_vbox.add_child(runs_lbl)

	var summary: Label = Label.new()
	summary.text = "%d condition(s)  ·  %d action(s)" % [event_row.conditions.size(), event_row.actions.size()]
	summary.add_theme_color_override("font_color", Color(0.65, 0.70, 0.75))
	summary.add_theme_font_size_override("font_size", 10)
	card_vbox.add_child(summary)

	var authoring_note: Label = Label.new()
	authoring_note.text = "Edit via event block."
	authoring_note.add_theme_color_override("font_color", Color(0.40, 0.45, 0.50))
	authoring_note.add_theme_font_size_override("font_size", 10)
	authoring_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_vbox.add_child(authoring_note)

	_inspector_vbox.add_child(card)

## Rebuilds the inspector for a selected variable.
## The popup dialog is the primary editing path (clicking the row opens it).
func _rebuild_inspector_variable(row: VariableRowUI) -> void:
	_clear_inspector()
	if row == null:
		_show_empty_inspector()
		return

	var card: PanelContainer = _make_inspector_card(Color(0.178, 0.240, 0.196, 1.0))
	var card_vbox: VBoxContainer = VBoxContainer.new()
	card_vbox.add_theme_constant_override("separation", 4)
	card.add_child(card_vbox)

	var heading: Label = Label.new()
	heading.text = "Variable"
	heading.add_theme_color_override("font_color", Color(0.35, 0.95, 0.55))
	heading.add_theme_font_size_override("font_size", 12)
	card_vbox.add_child(heading)

	var heading_sep: HSeparator = HSeparator.new()
	heading_sep.add_theme_color_override("color", Color(0.178, 0.240, 0.196, 0.80))
	card_vbox.add_child(heading_sep)

	var summary: Label = Label.new()
	summary.text = VariableRowUI.format_summary(row.var_name, row.var_info)
	summary.add_theme_color_override("font_color", Color(0.80, 0.90, 0.80))
	summary.add_theme_font_size_override("font_size", 10)
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_vbox.add_child(summary)

	var note: Label = Label.new()
	note.text = "Click the row to edit."
	note.add_theme_color_override("font_color", Color(0.40, 0.50, 0.40))
	note.add_theme_font_size_override("font_size", 10)
	card_vbox.add_child(note)

	_inspector_vbox.add_child(card)

func _rebuild_inspector_group(row: GroupRowUI) -> void:
	_clear_inspector()
	if row == null or row.event_group == null:
		_show_empty_inspector()
		return

	var event_group: EventGroup = row.event_group

	var card: PanelContainer = _make_inspector_card(Color(0.220, 0.168, 0.310, 1.0))
	var card_vbox: VBoxContainer = VBoxContainer.new()
	card_vbox.add_theme_constant_override("separation", 4)
	card.add_child(card_vbox)

	var heading: Label = Label.new()
	var display_name: String = event_group.name
	if display_name.is_empty():
		display_name = event_group.group_name
	heading.text = "Group: " + (display_name if not display_name.is_empty() else "(unnamed)")
	heading.add_theme_color_override("font_color", Color(0.80, 0.50, 1.0))
	heading.add_theme_font_size_override("font_size", 12)
	card_vbox.add_child(heading)

	var heading_sep: HSeparator = HSeparator.new()
	heading_sep.add_theme_color_override("color", Color(0.220, 0.168, 0.310, 0.80))
	card_vbox.add_child(heading_sep)

	var desc_lbl: Label = Label.new()
	desc_lbl.text = "Description: " + (event_group.description if not event_group.description.is_empty() else "(none)")
	desc_lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.80))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_vbox.add_child(desc_lbl)

	var enabled_lbl: Label = Label.new()
	enabled_lbl.text = "Enabled: %s" % str(event_group.enabled)
	enabled_lbl.add_theme_color_override("font_color", Color(0.70, 0.92, 0.68) if event_group.enabled else Color(0.84, 0.56, 0.56))
	enabled_lbl.add_theme_font_size_override("font_size", 10)
	card_vbox.add_child(enabled_lbl)

	var collapsed_lbl: Label = Label.new()
	collapsed_lbl.text = "Collapsed: %s" % str(_is_group_collapsed(event_group))
	collapsed_lbl.add_theme_color_override("font_color", Color(0.65, 0.70, 0.80))
	collapsed_lbl.add_theme_font_size_override("font_size", 10)
	card_vbox.add_child(collapsed_lbl)

	var note_sep: HSeparator = HSeparator.new()
	card_vbox.add_child(note_sep)

	var planned_note: Label = Label.new()
	planned_note.text = "Nested local variables and group event bodies are planned."
	planned_note.add_theme_color_override("font_color", Color(0.50, 0.45, 0.60))
	planned_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_vbox.add_child(planned_note)

	_inspector_vbox.add_child(card)

func _rebuild_inspector_comment(row: CommentRowUI) -> void:
	_clear_inspector()
	if row == null or row.comment_row == null:
		_show_empty_inspector()
		return

	var card: PanelContainer = _make_inspector_card(Color(0.412, 0.338, 0.175, 1.0))
	var card_vbox: VBoxContainer = VBoxContainer.new()
	card_vbox.add_theme_constant_override("separation", 4)
	card.add_child(card_vbox)

	var heading: Label = Label.new()
	heading.text = "Comment"
	heading.add_theme_color_override("font_color", Color(1.0, 0.90, 0.60))
	heading.add_theme_font_size_override("font_size", 12)
	card_vbox.add_child(heading)

	var heading_sep: HSeparator = HSeparator.new()
	heading_sep.add_theme_color_override("color", Color(0.412, 0.338, 0.175, 0.80))
	card_vbox.add_child(heading_sep)

	var edit_label: Label = Label.new()
	edit_label.text = "Text"
	edit_label.add_theme_color_override("font_color", Color(0.72, 0.64, 0.50))
	edit_label.add_theme_font_size_override("font_size", 10)
	card_vbox.add_child(edit_label)

	_comment_text_edit = LineEdit.new()
	_comment_text_edit.placeholder_text = "Write comment…"
	_comment_text_edit.text = row.comment_row.text
	_comment_text_edit.tooltip_text = "Comment text (inline row updates live)"
	_comment_text_edit.add_theme_font_size_override("font_size", 10)
	_comment_text_edit.connect("text_changed", func(text: String) -> void: _on_comment_text_changed(row, text))
	_comment_text_edit.connect("text_submitted", func(text: String) -> void: _on_comment_text_submitted(row, text))
	card_vbox.add_child(_comment_text_edit)

	var interaction_hint: Label = Label.new()
	interaction_hint.text = "Tip: Click ✎ on the row or type directly in-row for contextual authoring."
	interaction_hint.add_theme_color_override("font_color", Color(0.62, 0.56, 0.45))
	interaction_hint.add_theme_font_size_override("font_size", 9)
	interaction_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_vbox.add_child(interaction_hint)

	var note: Label = Label.new()
	note.text = "Comment rows annotate authoring flow and are skipped by compilation."
	note.add_theme_color_override("font_color", Color(0.52, 0.47, 0.38))
	note.add_theme_font_size_override("font_size", 10)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_vbox.add_child(note)

	_inspector_vbox.add_child(card)
