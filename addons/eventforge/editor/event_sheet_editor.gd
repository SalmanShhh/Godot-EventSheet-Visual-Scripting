# EventForge — Event sheet editor
# Renders the event sheet as a Construct/GDevelop-style vertical document.
# The canvas shows: document header → global variable rows → event/group blocks.
# The inspector panel on the right shows context-sensitive editing UI.
@tool
extends Control
class_name EventSheetEditor

# ── State ────────────────────────────────────────────────────────────────────

var current_sheet: EventSheetResource = null

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

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	_build_layout()

## Called by the plugin to load a sheet into the editor.
func setup(sheet: EventSheetResource = null) -> void:
	current_sheet = sheet
	if is_inside_tree():
		refresh_canvas()
		_show_empty_inspector()

# ── Layout construction ───────────────────────────────────────────────────────

func _build_layout() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 0)
	add_child(hbox)

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

# ── Canvas rendering ──────────────────────────────────────────────────────────

## Rebuilds the full canvas document from current_sheet.
func refresh_canvas() -> void:
	for child in _canvas_vbox.get_children():
		child.queue_free()

	_add_document_header()

	if current_sheet == null:
		var no_sheet: Label = Label.new()
		no_sheet.text = "No sheet loaded. Open or create an EventSheetResource."
		no_sheet.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
		_canvas_vbox.add_child(no_sheet)
		return

	_add_variables_section()
	_add_events_section()

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
		hint.text = "No global variables yet. Use + Add Var to create one."
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
		hint.text = "No events yet. Use + Add Event to create one."
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

func _show_empty_inspector() -> void:
	_clear_inspector()
	_selected_entry_kind = "none"
	var hint: Label = Label.new()
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

	for i: int in range(event_row.conditions.size()):
		var condition: ACECondition = event_row.conditions[i]
		var btn: Button = Button.new()
		btn.text = "  " + EventRowUI.format_condition_summary(condition)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.flat = true
		btn.connect("pressed", func() -> void: _on_condition_selected(row, i))
		_inspector_vbox.add_child(btn)

	var sep2: HSeparator = HSeparator.new()
	_inspector_vbox.add_child(sep2)

	# Actions list
	var act_lbl: Label = Label.new()
	act_lbl.text = "Actions:"
	act_lbl.add_theme_color_override("font_color", Color(0.65, 0.75, 1.0))
	_inspector_vbox.add_child(act_lbl)

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
