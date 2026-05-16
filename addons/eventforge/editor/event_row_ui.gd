# EventForge — Event row UI
# Renders a single EventRow as an event-sheet entry line with inline clauses.
@tool
extends PanelContainer
class_name EventRowUI

## Emitted when a condition summary is clicked.
signal condition_selected(row: EventRowUI, index: int)
## Emitted when a condition right-click menu requests edit.
signal condition_edit_requested(row: EventRowUI, index: int)
## Emitted when a condition right-click menu requests adding another condition.
signal condition_add_another_requested(row: EventRowUI, index: int)
## Emitted when a condition right-click menu requests replacement.
signal condition_replace_requested(row: EventRowUI, index: int)
## Emitted when a condition right-click menu requests inversion toggle.
signal condition_invert_requested(row: EventRowUI, index: int)
## Emitted when an action summary is clicked.
signal action_selected(row: EventRowUI, index: int)
## Emitted when the event row itself is clicked for full event inspection.
signal event_selected(row: EventRowUI)
## Emitted when inline Add Action is requested.
signal add_action_requested(row: EventRowUI)
## Emitted when inline Add Condition is requested.
signal add_condition_requested(row: EventRowUI)
## Emitted when delete is requested for this event row.
signal event_delete_requested(row: EventRowUI)
## Emitted when delete is requested for a condition.
signal condition_delete_requested(row: EventRowUI, index: int)
## Emitted when delete is requested for an action.
signal action_delete_requested(row: EventRowUI, index: int)

var event_row: EventRow = null

var _runs_button: Button = null
var _conditions_container: HFlowContainer = null
var _actions_container: HFlowContainer = null
var _condition_context_menu: PopupMenu = null
var _context_condition_index: int = -1
var _action_context_menu: PopupMenu = null
var _context_action_index: int = -1
var _depth: int = 0
var _selected: bool = false
var _hovered: bool = false

const CONDITION_MENU_EDIT: int = 1
const CONDITION_MENU_ADD_ANOTHER: int = 2
const CONDITION_MENU_REPLACE: int = 3
const CONDITION_MENU_INVERT: int = 4
const CONDITION_MENU_DELETE: int = 5
const ACTION_MENU_EDIT: int = 1
const ACTION_MENU_DELETE: int = 2

const ROW_BG: Color = Color(0.074, 0.085, 0.114, 1.0)
const ROW_BG_HOVER: Color = Color(0.091, 0.105, 0.139, 1.0)
const ROW_BG_SELECTED: Color = Color(0.108, 0.136, 0.186, 1.0)
const ROW_BORDER: Color = Color(0.142, 0.168, 0.224, 1.0)
const ROW_BORDER_HOVER: Color = Color(0.243, 0.312, 0.438, 1.0)
const ROW_BORDER_SELECTED: Color = Color(0.356, 0.522, 0.812, 1.0)
const CONDITION_TOKEN_BG: Color = Color(0.155, 0.206, 0.310, 1.0)
const CONDITION_TOKEN_BG_HOVER: Color = Color(0.205, 0.260, 0.385, 1.0)
const ACTION_TOKEN_BG: Color = Color(0.110, 0.170, 0.155, 1.0)
const ACTION_TOKEN_BG_HOVER: Color = Color(0.148, 0.218, 0.198, 1.0)
const CONDITION_TOKEN_BORDER: Color = Color(0.225, 0.315, 0.462, 1.0)
const ACTION_TOKEN_BORDER: Color = Color(0.178, 0.268, 0.248, 1.0)
const RUN_CONTEXT_SYMBOL: String = "◆"
const CLAUSE_CONDITION_PREFIX: String = "when"
const CLAUSE_ACTION_PREFIX: String = "do"
const LANE_DIVIDER_COLOR: Color = Color(0.22, 0.28, 0.42, 0.92)
const COND_LANE_BG: Color = Color(0.082, 0.098, 0.135, 1.0)
const ACTION_LANE_BG: Color = Color(0.074, 0.087, 0.118, 1.0)
const CONDITION_PLACEHOLDER_BG: Color = Color(0.104, 0.137, 0.205, 1.0)
const CONDITION_PLACEHOLDER_BORDER: Color = Color(0.190, 0.262, 0.385, 1.0)
const ACTION_PLACEHOLDER_BG: Color = Color(0.088, 0.142, 0.132, 1.0)
const ACTION_PLACEHOLDER_BORDER: Color = Color(0.155, 0.236, 0.218, 1.0)
const TOKEN_LEFT_BORDER_WIDTH: int = 2
const COND_LANE_RATIO: float = 1.0
const ACTION_LANE_RATIO: float = 1.85
const ENTRY_TOOLTIP_TEXT: String = "Left-click to edit · Right-click for options"

func _init() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_build_ui()

func _ensure_ui_built() -> void:
	if _runs_button != null and _conditions_container != null and _actions_container != null:
		return
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	_condition_context_menu = null
	_action_context_menu = null
	_build_ui()

func _build_ui() -> void:
	_apply_row_style()

	_condition_context_menu = PopupMenu.new()
	_condition_context_menu.add_item("Edit", CONDITION_MENU_EDIT)
	_condition_context_menu.add_item("Add Another Condition", CONDITION_MENU_ADD_ANOTHER)
	_condition_context_menu.add_item("Replace Condition", CONDITION_MENU_REPLACE)
	_condition_context_menu.add_separator()
	_condition_context_menu.add_item("Invert Condition", CONDITION_MENU_INVERT)
	_condition_context_menu.add_separator()
	_condition_context_menu.add_item("Delete Condition", CONDITION_MENU_DELETE)
	_condition_context_menu.connect("id_pressed", _on_condition_context_menu_id_pressed)
	add_child(_condition_context_menu)

	_action_context_menu = PopupMenu.new()
	_action_context_menu.add_item("Edit", ACTION_MENU_EDIT)
	_action_context_menu.add_separator()
	_action_context_menu.add_item("Delete Action", ACTION_MENU_DELETE)
	_action_context_menu.connect("id_pressed", _on_action_context_menu_id_pressed)
	add_child(_action_context_menu)

	# Root row: flush 0-separation so lanes sit edge-to-edge inside the border.
	var line: HBoxContainer = HBoxContainer.new()
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_theme_constant_override("separation", 0)
	add_child(line)

	# ── Condition lane (left) ──────────────────────────────────────────────────
	var cond_panel: PanelContainer = PanelContainer.new()
	cond_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cond_panel.size_flags_stretch_ratio = COND_LANE_RATIO
	var cond_style: StyleBoxFlat = StyleBoxFlat.new()
	cond_style.bg_color = COND_LANE_BG
	cond_style.set_border_width_all(0)
	cond_style.set_corner_radius_all(0)
	cond_style.set_content_margin(SIDE_LEFT, 5)
	cond_style.set_content_margin(SIDE_RIGHT, 4)
	cond_style.set_content_margin(SIDE_TOP, 2)
	cond_style.set_content_margin(SIDE_BOTTOM, 2)
	cond_panel.add_theme_stylebox_override("panel", cond_style)
	line.add_child(cond_panel)

	var cond_vbox: VBoxContainer = VBoxContainer.new()
	cond_vbox.add_theme_constant_override("separation", 1)
	cond_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cond_panel.add_child(cond_vbox)

	# Event header row: select handle + run-context trigger + "when" clause + add
	var cond_header: HBoxContainer = HBoxContainer.new()
	cond_header.add_theme_constant_override("separation", 3)
	cond_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cond_vbox.add_child(cond_header)

	var select_btn: Button = Button.new()
	select_btn.text = "⋮"
	select_btn.flat = true
	select_btn.tooltip_text = "Select event line"
	select_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	select_btn.add_theme_color_override("font_color", Color(0.72, 0.78, 0.92))
	select_btn.add_theme_color_override("font_hover_color", Color(0.90, 0.94, 1.0))
	select_btn.connect("pressed", _on_event_header_pressed)
	cond_header.add_child(select_btn)

	_runs_button = Button.new()
	_runs_button.flat = true
	_runs_button.tooltip_text = "Select event run context"
	_runs_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_runs_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_runs_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_runs_button.add_theme_color_override("font_color", Color(0.68, 0.77, 0.94))
	_runs_button.add_theme_color_override("font_hover_color", Color(0.84, 0.90, 1.0))
	_runs_button.add_theme_font_size_override("font_size", 10)
	var run_style: StyleBoxFlat = StyleBoxFlat.new()
	run_style.bg_color = Color(0.143, 0.176, 0.250, 1.0)
	run_style.border_color = Color(0.269, 0.357, 0.525, 1.0)
	run_style.set_border_width_all(1)
	run_style.set_corner_radius_all(0)
	run_style.set_content_margin(SIDE_LEFT, 5)
	run_style.set_content_margin(SIDE_RIGHT, 5)
	run_style.set_content_margin(SIDE_TOP, 0)
	run_style.set_content_margin(SIDE_BOTTOM, 0)
	_runs_button.add_theme_stylebox_override("normal", run_style)
	var run_hover: StyleBoxFlat = run_style.duplicate()
	run_hover.bg_color = Color(0.181, 0.218, 0.308, 1.0)
	_runs_button.add_theme_stylebox_override("hover", run_hover)
	_runs_button.add_theme_stylebox_override("pressed", run_hover)
	_runs_button.add_theme_stylebox_override("focus", run_hover)
	_runs_button.connect("pressed", _on_event_header_pressed)
	cond_header.add_child(_runs_button)

	cond_header.add_child(_make_clause_prefix(CLAUSE_CONDITION_PREFIX, Color(0.52, 0.68, 0.94)))

	var add_condition_btn: Button = Button.new()
	add_condition_btn.text = "+"
	add_condition_btn.flat = true
	add_condition_btn.tooltip_text = "Add condition to this event"
	add_condition_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_condition_btn.add_theme_color_override("font_color", Color(0.62, 0.76, 0.98))
	add_condition_btn.add_theme_color_override("font_hover_color", Color(0.84, 0.92, 1.0))
	add_condition_btn.add_theme_font_size_override("font_size", 10)
	add_condition_btn.connect("pressed", _on_add_condition_pressed)
	cond_header.add_child(add_condition_btn)

	# Conditions token flow (wraps within the lane)
	_conditions_container = HFlowContainer.new()
	_conditions_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_conditions_container.add_theme_constant_override("h_separation", 3)
	_conditions_container.add_theme_constant_override("v_separation", 1)
	cond_vbox.add_child(_conditions_container)

	# ── Lane divider ───────────────────────────────────────────────────────────
	var lane_div: ColorRect = ColorRect.new()
	lane_div.custom_minimum_size = Vector2(2, 0)
	lane_div.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lane_div.color = LANE_DIVIDER_COLOR
	lane_div.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(lane_div)

	# ── Action lane (right) ────────────────────────────────────────────────────
	var action_panel: PanelContainer = PanelContainer.new()
	action_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_panel.size_flags_stretch_ratio = ACTION_LANE_RATIO
	var action_style: StyleBoxFlat = StyleBoxFlat.new()
	action_style.bg_color = ACTION_LANE_BG
	action_style.set_border_width_all(0)
	action_style.set_corner_radius_all(0)
	action_style.set_content_margin(SIDE_LEFT, 5)
	action_style.set_content_margin(SIDE_RIGHT, 4)
	action_style.set_content_margin(SIDE_TOP, 2)
	action_style.set_content_margin(SIDE_BOTTOM, 2)
	action_panel.add_theme_stylebox_override("panel", action_style)
	line.add_child(action_panel)

	var action_hbox: HBoxContainer = HBoxContainer.new()
	action_hbox.add_theme_constant_override("separation", 3)
	action_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_panel.add_child(action_hbox)

	action_hbox.add_child(_make_clause_prefix(CLAUSE_ACTION_PREFIX, Color(0.52, 0.83, 0.65)))

	_actions_container = HFlowContainer.new()
	_actions_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_actions_container.add_theme_constant_override("h_separation", 3)
	_actions_container.add_theme_constant_override("v_separation", 1)
	action_hbox.add_child(_actions_container)

	var add_action_btn: Button = Button.new()
	add_action_btn.text = "+ action"
	add_action_btn.flat = true
	add_action_btn.tooltip_text = "Add action"
	add_action_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_action_btn.add_theme_color_override("font_color", Color(0.48, 0.76, 0.60))
	add_action_btn.add_theme_color_override("font_hover_color", Color(0.65, 0.92, 0.74))
	add_action_btn.add_theme_font_size_override("font_size", 10)
	add_action_btn.connect("pressed", _on_add_action_pressed)
	action_hbox.add_child(add_action_btn)

	# ── Delete event (far right, outside lanes) ────────────────────────────────
	var delete_event_btn: Button = Button.new()
	delete_event_btn.text = "✕"
	delete_event_btn.flat = true
	delete_event_btn.tooltip_text = "Delete this event"
	delete_event_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	delete_event_btn.add_theme_color_override("font_color", Color(0.86, 0.46, 0.51))
	delete_event_btn.add_theme_color_override("font_hover_color", Color(0.98, 0.62, 0.67))
	delete_event_btn.connect("pressed", _on_delete_event_pressed)
	line.add_child(delete_event_btn)

	mouse_filter = Control.MOUSE_FILTER_STOP
	connect("mouse_entered", _on_mouse_entered)
	connect("mouse_exited", _on_mouse_exited)
	connect("gui_input", _on_row_gui_input)

func set_depth(depth: int) -> void:
	_depth = max(0, depth)
	_apply_row_style()

func set_selected(selected: bool) -> void:
	_selected = selected
	_apply_row_style()

func _apply_row_style() -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	if _selected:
		style.bg_color = ROW_BG_SELECTED
		style.border_color = ROW_BORDER_SELECTED
	elif _hovered:
		style.bg_color = _apply_depth_tint(ROW_BG_HOVER)
		style.border_color = ROW_BORDER_HOVER
	else:
		style.bg_color = _apply_depth_tint(ROW_BG)
		style.border_color = ROW_BORDER
	style.set_border_width_all(1)
	style.border_width_left = 4 + min(_depth, 4)
	style.set_corner_radius_all(0)
	# Zero content margins — inner lane panels carry their own padding so
	# the lanes extend flush from the left depth-accent border to the right edge.
	style.set_content_margin(SIDE_LEFT, 0)
	style.set_content_margin(SIDE_RIGHT, 0)
	style.set_content_margin(SIDE_TOP, 0)
	style.set_content_margin(SIDE_BOTTOM, 0)
	add_theme_stylebox_override("panel", style)

func _apply_depth_tint(base: Color) -> Color:
	var depth_factor: float = float(min(_depth, 4))
	if depth_factor <= 0.0:
		return base
	var lifted: float = depth_factor * 0.012
	return Color(
		min(base.r + lifted, 1.0),
		min(base.g + lifted, 1.0),
		min(base.b + lifted, 1.0),
		base.a
	)

## Refreshes the display from the assigned event_row resource.
func refresh() -> void:
	if event_row == null:
		return
	_ensure_ui_built()
	_refresh_runs()
	_refresh_conditions()
	_refresh_actions()

## Returns a human-readable run-context label for the event row's trigger_id.
## Defaults to "Every Frame" when row/trigger_id are empty.
static func format_run_context(row: EventRow) -> String:
	if row == null or row.trigger_id.is_empty():
		return "Every Frame"
	match row.trigger_id:
		"OnReady":
			return "On Ready"
		"OnPhysicsProcess":
			return "On Physics"
		"OnBodyEntered":
			return "On Body Entered"
		"OnAreaEntered":
			return "On Area Entered"
		"OnTimeout":
			return "On Timeout"
		"OnAnimationFinished":
			var anim: String = str(row.trigger_params.get("anim_name", ""))
			if anim.is_empty():
				return "On Animation Finished"
			return 'On Animation "%s" Finished' % anim
		"OnSignal":
			var sig: String = str(row.trigger_params.get("signal_name", "signal"))
			var src: String = str(row.trigger_params.get("source", ""))
			if src.is_empty():
				return 'On "%s"' % sig
			return 'On "%s" from %s' % [sig, src]
		_:
			return row.trigger_id

## Returns a readable summary of an ACECondition.
static func format_condition_summary(condition: ACECondition) -> String:
	if condition == null:
		return "(condition)"
	if condition.ace_id.is_empty():
		return "(condition)"
	var prefix: String = "NOT " if condition.negated else ""
	var from_descriptor: String = _format_condition_from_descriptor(condition)
	if not from_descriptor.is_empty():
		return prefix + from_descriptor
	match condition.ace_id:
		"IsOnFloor":
			return prefix + "Is On Floor"
		"HasGroupMember":
			var group: String = str(_ace_param(condition.params, condition.parameters, "group", ""))
			return prefix + ('In group "%s"' % group)
		"CompareVar":
			var vname: String = str(_ace_param(condition.params, condition.parameters, "var_name", "var"))
			var op: String = str(_ace_param(condition.params, condition.parameters, "op", "=="))
			var val: String = str(_ace_param(condition.params, condition.parameters, "value", ""))
			return prefix + ("%s %s %s" % [vname, op, val])
		"Always":
			return prefix + "Always"
		_:
			return prefix + condition.ace_id

## Returns a readable summary of an ACEAction.
static func format_action_summary(action: ACEAction) -> String:
	if action == null:
		return "(action)"
	if action.ace_id.is_empty():
		return "(action)"
	var from_descriptor: String = _format_action_from_descriptor(action)
	if not from_descriptor.is_empty():
		return from_descriptor
	match action.ace_id:
		"SetVar":
			var vname: String = str(_ace_param(action.params, action.parameters, "var_name", "var"))
			var val: String = str(_ace_param(action.params, action.parameters, "value", ""))
			return "%s = %s" % [vname, val]
		"AddVar":
			var vname: String = str(_ace_param(action.params, action.parameters, "var_name", "var"))
			var amt: String = str(_ace_param(action.params, action.parameters, "amount", "0"))
			return "%s += %s" % [vname, amt]
		"PrintLog":
			var msg: String = str(_ace_param(action.params, action.parameters, "message", ""))
			return 'Print %s' % msg
		"QueueFree":
			return "Queue Free"
		"EmitSignal":
			var sig: String = str(_ace_param(action.params, action.parameters, "signal_name", "signal"))
			return 'Emit "%s"' % sig
		_:
			return action.ace_id

## Returns a param value from primary dict, falling back to legacy alias dict.
static func _ace_param(primary: Dictionary, fallback: Dictionary, key: String, default: Variant) -> Variant:
	if primary.has(key):
		return primary[key]
	if fallback.has(key):
		return fallback[key]
	return default

static func _format_condition_from_descriptor(condition: ACECondition) -> String:
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor(condition.provider_id, condition.ace_id)
	if descriptor == null:
		return ""
	var params_dict: Dictionary = condition.params if not condition.params.is_empty() else condition.parameters
	return descriptor.format_display(params_dict)

static func _format_action_from_descriptor(action: ACEAction) -> String:
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor(action.provider_id, action.ace_id)
	if descriptor == null:
		return ""
	var params_dict: Dictionary = action.params if not action.params.is_empty() else action.parameters
	return descriptor.format_display(params_dict)

func _refresh_runs() -> void:
	if _runs_button == null:
		return
	_runs_button.text = "%s %s" % [RUN_CONTEXT_SYMBOL, format_run_context(event_row)]

func _refresh_conditions() -> void:
	if _conditions_container == null:
		return
	for child in _conditions_container.get_children():
		child.queue_free()

	if event_row.conditions.is_empty():
		_conditions_container.add_child(_make_placeholder_token("Always", true))
		return

	for i: int in range(event_row.conditions.size()):
		var condition: ACECondition = event_row.conditions[i]
		_conditions_container.add_child(_make_entry_button(format_condition_summary(condition), i, true))

func _refresh_actions() -> void:
	if _actions_container == null:
		return
	for child in _actions_container.get_children():
		child.queue_free()

	if event_row.actions.is_empty():
		_actions_container.add_child(_make_placeholder_token("(no actions)", false))
		return

	for i: int in range(event_row.actions.size()):
		var action: ACEAction = event_row.actions[i] as ACEAction
		if action == null:
			continue
		_actions_container.add_child(_make_entry_button(format_action_summary(action), i, false))

func _make_placeholder_token(text: String, is_condition: bool) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = CONDITION_PLACEHOLDER_BG if is_condition else ACTION_PLACEHOLDER_BG
	style.border_color = CONDITION_PLACEHOLDER_BORDER if is_condition else ACTION_PLACEHOLDER_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(0)
	style.border_width_left = TOKEN_LEFT_BORDER_WIDTH
	style.set_content_margin(SIDE_LEFT, 5)
	style.set_content_margin(SIDE_RIGHT, 5)
	style.set_content_margin(SIDE_TOP, 2)
	style.set_content_margin(SIDE_BOTTOM, 2)
	panel.add_theme_stylebox_override("panel", style)
	var label: Label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color(0.67, 0.74, 0.85))
	label.add_theme_font_size_override("font_size", 10)
	panel.add_child(label)
	return panel

func _make_clause_prefix(text: String, color: Color) -> Label:
	var prefix: Label = Label.new()
	prefix.text = text
	prefix.add_theme_color_override("font_color", color)
	prefix.add_theme_font_size_override("font_size", 10)
	return prefix

## Creates a clickable entry button for a condition (is_condition=true) or action.
func _make_entry_button(text: String, index: int, is_condition: bool) -> Button:
	var btn: Button = Button.new()
	btn.text = text
	btn.flat = true
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.add_theme_color_override("font_color", Color(0.88, 0.92, 0.99))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	btn.add_theme_font_size_override("font_size", 11)

	var normal_style: StyleBoxFlat = StyleBoxFlat.new()
	normal_style.bg_color = CONDITION_TOKEN_BG if is_condition else ACTION_TOKEN_BG
	normal_style.border_color = CONDITION_TOKEN_BORDER if is_condition else ACTION_TOKEN_BORDER
	normal_style.set_border_width_all(1)
	normal_style.border_width_left = TOKEN_LEFT_BORDER_WIDTH
	normal_style.set_corner_radius_all(0)
	normal_style.set_content_margin(SIDE_LEFT, 6)
	normal_style.set_content_margin(SIDE_RIGHT, 6)
	normal_style.set_content_margin(SIDE_TOP, 2)
	normal_style.set_content_margin(SIDE_BOTTOM, 2)
	btn.add_theme_stylebox_override("normal", normal_style)

	var hover_style: StyleBoxFlat = normal_style.duplicate()
	hover_style.bg_color = CONDITION_TOKEN_BG_HOVER if is_condition else ACTION_TOKEN_BG_HOVER
	btn.add_theme_stylebox_override("hover", hover_style)
	btn.add_theme_stylebox_override("pressed", hover_style)
	btn.add_theme_stylebox_override("focus", hover_style)

	if is_condition:
		btn.tooltip_text = ENTRY_TOOLTIP_TEXT
		btn.connect("pressed", func() -> void: condition_selected.emit(self, index))
		btn.connect("gui_input", func(event: InputEvent) -> void: _on_condition_entry_gui_input(event, index))
	else:
		btn.tooltip_text = ENTRY_TOOLTIP_TEXT
		btn.connect("pressed", func() -> void: action_selected.emit(self, index))
		btn.connect("gui_input", func(event: InputEvent) -> void: _on_action_entry_gui_input(event, index))
	return btn

func _on_mouse_entered() -> void:
	_hovered = true
	_apply_row_style()

func _on_mouse_exited() -> void:
	_hovered = false
	_apply_row_style()

func _on_row_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return
	event_selected.emit(self)

func _on_event_header_pressed() -> void:
	event_selected.emit(self)

func _on_add_condition_pressed() -> void:
	add_condition_requested.emit(self)

func _on_add_action_pressed() -> void:
	add_action_requested.emit(self)

func _on_delete_event_pressed() -> void:
	event_delete_requested.emit(self)

func _on_condition_entry_gui_input(event: InputEvent, index: int) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_RIGHT or not mb.pressed:
		return
	_context_condition_index = index
	if _condition_context_menu == null:
		return
	get_viewport().set_input_as_handled()
	_condition_context_menu.position = DisplayServer.mouse_get_position()
	_condition_context_menu.reset_size()
	_condition_context_menu.popup()

func _on_action_entry_gui_input(event: InputEvent, index: int) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_RIGHT or not mb.pressed:
		return
	_context_action_index = index
	if _action_context_menu == null:
		return
	get_viewport().set_input_as_handled()
	_action_context_menu.position = DisplayServer.mouse_get_position()
	_action_context_menu.reset_size()
	_action_context_menu.popup()

func _on_condition_context_menu_id_pressed(id: int) -> void:
	if _context_condition_index < 0:
		return
	match id:
		CONDITION_MENU_EDIT:
			condition_edit_requested.emit(self, _context_condition_index)
		CONDITION_MENU_ADD_ANOTHER:
			condition_add_another_requested.emit(self, _context_condition_index)
		CONDITION_MENU_REPLACE:
			condition_replace_requested.emit(self, _context_condition_index)
		CONDITION_MENU_INVERT:
			condition_invert_requested.emit(self, _context_condition_index)
		CONDITION_MENU_DELETE:
			condition_delete_requested.emit(self, _context_condition_index)

func _on_action_context_menu_id_pressed(id: int) -> void:
	if _context_action_index < 0:
		return
	match id:
		ACTION_MENU_EDIT:
			action_selected.emit(self, _context_action_index)
		ACTION_MENU_DELETE:
			action_delete_requested.emit(self, _context_action_index)
