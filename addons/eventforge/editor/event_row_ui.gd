# EventForge — Event row UI
# Renders a single EventRow as a Construct/GDevelop-style document block.
# Each condition and action entry is a clickable summary.
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
## Emitted when the event header/row itself is clicked for full event inspection.
signal event_selected(row: EventRowUI)
## Emitted when inline Add Action is requested.
signal add_action_requested(row: EventRowUI)
## Emitted when inline Add Condition is requested.
signal add_condition_requested(row: EventRowUI)

var event_row: EventRow = null

var _runs_label: Label = null
var _conditions_container: VBoxContainer = null
var _actions_container: VBoxContainer = null
var _condition_context_menu: PopupMenu = null
var _context_condition_index: int = -1

const CONDITION_MENU_EDIT: int = 1
const CONDITION_MENU_ADD_ANOTHER: int = 2
const CONDITION_MENU_REPLACE: int = 3
const CONDITION_MENU_INVERT: int = 4

func _init() -> void:
	_build_ui()

func _build_ui() -> void:
	# Outer card: left accent border, tight margins.
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.13, 0.15, 0.20, 1.0)
	style.border_color = Color(0.35, 0.45, 0.65, 1.0)
	style.set_border_width_all(0)
	style.border_width_left = 3
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.set_corner_radius_all(4)
	style.set_content_margin_all(0)
	add_theme_stylebox_override("panel", style)

	_condition_context_menu = PopupMenu.new()
	_condition_context_menu.add_item("Edit", CONDITION_MENU_EDIT)
	_condition_context_menu.add_item("Add Another Condition", CONDITION_MENU_ADD_ANOTHER)
	_condition_context_menu.add_item("Replace Condition", CONDITION_MENU_REPLACE)
	_condition_context_menu.add_separator()
	_condition_context_menu.add_item("Invert Condition", CONDITION_MENU_INVERT)
	_condition_context_menu.connect("id_pressed", _on_condition_context_menu_id_pressed)
	add_child(_condition_context_menu)

	# Side-by-side lanes directly inside the card (GDevelop / Construct style).
	var lanes_hbox: HBoxContainer = HBoxContainer.new()
	lanes_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lanes_hbox.add_theme_constant_override("separation", 0)
	add_child(lanes_hbox)

	# ── Conditions lane (left, ~40%) ─────────────────────────────────────────
	var conditions_lane: PanelContainer = PanelContainer.new()
	conditions_lane.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var conditions_lane_style: StyleBoxFlat = StyleBoxFlat.new()
	conditions_lane_style.bg_color = Color(0.09, 0.15, 0.11, 0.95)
	conditions_lane_style.border_color = Color(0.30, 0.62, 0.42, 0.6)
	conditions_lane_style.set_border_width_all(0)
	conditions_lane_style.border_width_right = 1
	conditions_lane_style.set_corner_radius_all(0)
	conditions_lane_style.set_content_margin(SIDE_LEFT, 6)
	conditions_lane_style.set_content_margin(SIDE_RIGHT, 5)
	conditions_lane_style.set_content_margin(SIDE_TOP, 4)
	conditions_lane_style.set_content_margin(SIDE_BOTTOM, 5)
	conditions_lane.add_theme_stylebox_override("panel", conditions_lane_style)
	lanes_hbox.add_child(conditions_lane)

	var conditions_lane_vbox: VBoxContainer = VBoxContainer.new()
	conditions_lane_vbox.add_theme_constant_override("separation", 2)
	conditions_lane.add_child(conditions_lane_vbox)

	# Header row: runs label (expandable) + ✎ edit btn + + Add Condition btn.
	var cond_header: HBoxContainer = HBoxContainer.new()
	cond_header.add_theme_constant_override("separation", 2)
	conditions_lane_vbox.add_child(cond_header)

	_runs_label = Label.new()
	_runs_label.add_theme_color_override("font_color", Color(0.55, 0.78, 0.55))
	_runs_label.add_theme_font_size_override("font_size", 10)
	_runs_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_runs_label.clip_text = true
	cond_header.add_child(_runs_label)

	var header_btn: Button = Button.new()
	header_btn.text = "✎"
	header_btn.flat = true
	header_btn.tooltip_text = "Select event"
	header_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	header_btn.add_theme_font_size_override("font_size", 10)
	header_btn.connect("pressed", _on_event_header_pressed)
	cond_header.add_child(header_btn)

	var add_condition_btn: Button = Button.new()
	add_condition_btn.text = "+ Condition"
	add_condition_btn.flat = true
	add_condition_btn.tooltip_text = "Add a condition to this event"
	add_condition_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_condition_btn.add_theme_color_override("font_color", Color(0.55, 0.90, 0.65))
	add_condition_btn.add_theme_font_size_override("font_size", 10)
	add_condition_btn.connect("pressed", _on_add_condition_pressed)
	cond_header.add_child(add_condition_btn)

	_conditions_container = VBoxContainer.new()
	_conditions_container.add_theme_constant_override("separation", 1)
	conditions_lane_vbox.add_child(_conditions_container)

	# ── Actions lane (right, ~60%) ───────────────────────────────────────────
	var actions_lane: PanelContainer = PanelContainer.new()
	actions_lane.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions_lane.size_flags_stretch_ratio = 1.5
	var actions_lane_style: StyleBoxFlat = StyleBoxFlat.new()
	actions_lane_style.bg_color = Color(0.10, 0.12, 0.18, 0.95)
	actions_lane_style.set_border_width_all(0)
	actions_lane_style.set_corner_radius_all(0)
	actions_lane_style.set_content_margin(SIDE_LEFT, 6)
	actions_lane_style.set_content_margin(SIDE_RIGHT, 5)
	actions_lane_style.set_content_margin(SIDE_TOP, 4)
	actions_lane_style.set_content_margin(SIDE_BOTTOM, 5)
	actions_lane.add_theme_stylebox_override("panel", actions_lane_style)
	lanes_hbox.add_child(actions_lane)

	var actions_lane_vbox: VBoxContainer = VBoxContainer.new()
	actions_lane_vbox.add_theme_constant_override("separation", 2)
	actions_lane.add_child(actions_lane_vbox)

	var actions_header: HBoxContainer = HBoxContainer.new()
	actions_header.add_theme_constant_override("separation", 2)
	actions_lane_vbox.add_child(actions_header)

	var action_heading: Label = Label.new()
	action_heading.text = "Actions"
	action_heading.add_theme_color_override("font_color", Color(0.50, 0.65, 0.95))
	action_heading.add_theme_font_size_override("font_size", 10)
	action_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions_header.add_child(action_heading)

	var add_action_btn: Button = Button.new()
	add_action_btn.text = "+ Action"
	add_action_btn.flat = true
	add_action_btn.tooltip_text = "Add an action to this event"
	add_action_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_action_btn.add_theme_color_override("font_color", Color(0.55, 0.75, 1.0))
	add_action_btn.add_theme_font_size_override("font_size", 10)
	add_action_btn.connect("pressed", _on_add_action_pressed)
	actions_header.add_child(add_action_btn)

	_actions_container = VBoxContainer.new()
	_actions_container.add_theme_constant_override("separation", 1)
	actions_lane_vbox.add_child(_actions_container)

## Refreshes the display from the assigned event_row resource.
func refresh() -> void:
	if event_row == null:
		return
	_refresh_runs()
	_refresh_conditions()
	_refresh_actions()

## Returns a human-readable run-context label for the event row's trigger_id.
static func format_run_context(row: EventRow) -> String:
	if row == null or row.trigger_id.is_empty():
		return "Runs: Every Tick (default)"
	match row.trigger_id:
		"OnProcess":
			return "Runs: Every Frame"
		"OnReady":
			return "Runs: On Ready"
		"OnPhysicsProcess":
			return "Runs: On Physics Process"
		"OnBodyEntered":
			return "Runs: On Body Entered"
		"OnSignal":
			var sig: String = str(row.trigger_params.get("signal_name", "signal"))
			var src: String = str(row.trigger_params.get("source", ""))
			if src.is_empty():
				return 'Runs: On Signal "%s"' % sig
			return 'Runs: On Signal "%s" from %s' % [sig, src]
		_:
			return "Runs: %s" % row.trigger_id

## Returns a readable summary of an ACECondition.
static func format_condition_summary(condition: ACECondition) -> String:
	if condition == null:
		return "(empty condition)"
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
		return "(empty action)"
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

# ── Private helpers ──────────────────────────────────────────────────────────

func _refresh_runs() -> void:
	_runs_label.text = format_run_context(event_row)

func _refresh_conditions() -> void:
	for child in _conditions_container.get_children():
		child.queue_free()

	if event_row.conditions.is_empty():
		var hint: Label = Label.new()
		hint.text = "  Always"
		hint.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
		hint.add_theme_font_size_override("font_size", 11)
		_conditions_container.add_child(hint)
		return

	for i: int in range(event_row.conditions.size()):
		var condition: ACECondition = event_row.conditions[i]
		var btn: Button = _make_entry_button(
			"  " + format_condition_summary(condition),
			i,
			true
		)
		_conditions_container.add_child(btn)

func _refresh_actions() -> void:
	for child in _actions_container.get_children():
		child.queue_free()

	if event_row.actions.is_empty():
		var hint: Label = Label.new()
		hint.text = "  (no actions)"
		hint.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
		hint.add_theme_font_size_override("font_size", 11)
		_actions_container.add_child(hint)
		return

	for i: int in range(event_row.actions.size()):
		var action: ACEAction = event_row.actions[i] as ACEAction
		if action == null:
			continue
		var btn: Button = _make_entry_button(
			"  " + format_action_summary(action),
			i,
			false
		)
		_actions_container.add_child(btn)

## Creates a clickable entry button for a condition (is_condition=true) or action.
## Condition buttons support right-click context menus; the cursor and hover
## styling signal interactivity clearly to the user.
func _make_entry_button(text: String, index: int, is_condition: bool) -> Button:
	var btn: Button = Button.new()
	btn.text = text
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.flat = true
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.add_theme_color_override("font_color", Color(0.88, 0.88, 0.88))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	btn.add_theme_font_size_override("font_size", 11)

	# Subtle hover highlight so users can see the entry is interactive.
	var hover_style: StyleBoxFlat = StyleBoxFlat.new()
	hover_style.bg_color = Color(1.0, 1.0, 1.0, 0.07)
	hover_style.set_corner_radius_all(3)
	btn.add_theme_stylebox_override("hover", hover_style)

	if is_condition:
		btn.tooltip_text = "Left-click to edit - Right-click for options"
		btn.connect("pressed", func() -> void: condition_selected.emit(self, index))
		btn.connect("gui_input", func(event: InputEvent) -> void: _on_condition_entry_gui_input(event, index))
	else:
		btn.tooltip_text = "Left-click to edit action parameters"
		btn.connect("pressed", func() -> void: action_selected.emit(self, index))
	return btn

func _on_event_header_pressed() -> void:
	event_selected.emit(self)

func _on_add_condition_pressed() -> void:
	add_condition_requested.emit(self)

func _on_add_action_pressed() -> void:
	add_action_requested.emit(self)

func _on_condition_entry_gui_input(event: InputEvent, index: int) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_RIGHT or not mb.pressed:
		return
	_context_condition_index = index
	if _condition_context_menu == null:
		return
	_condition_context_menu.position = DisplayServer.mouse_get_position()
	_condition_context_menu.reset_size()
	_condition_context_menu.popup()
	get_viewport().set_input_as_handled()

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
