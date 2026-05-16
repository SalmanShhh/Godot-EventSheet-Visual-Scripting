# EventForge — Event row UI
# Renders a single EventRow as a Construct/GDevelop-style document block.
# Each condition and action entry is a clickable summary.
@tool
extends PanelContainer
class_name EventRowUI

## Emitted when a condition summary is clicked.
signal condition_selected(row: EventRowUI, index: int)
## Emitted when an action summary is clicked.
signal action_selected(row: EventRowUI, index: int)
## Emitted when the event header/row itself is clicked for full event inspection.
signal event_selected(row: EventRowUI)
## Emitted when inline Add Action is requested.
signal add_action_requested(row: EventRowUI)

var event_row: EventRow = null

var _vbox: VBoxContainer = null
var _header_label: Label = null
var _runs_label: Label = null
var _conditions_container: VBoxContainer = null
var _actions_container: VBoxContainer = null

func _init() -> void:
	_build_ui()

func _build_ui() -> void:
	# Outer card styling
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.20, 0.25, 1.0)
	style.border_color = Color(0.35, 0.45, 0.65, 1.0)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(8)
	add_theme_stylebox_override("panel", style)

	_vbox = VBoxContainer.new()
	_vbox.add_theme_constant_override("separation", 4)
	add_child(_vbox)

	# Header row
	var header_row: HBoxContainer = HBoxContainer.new()
	_vbox.add_child(header_row)

	var badge: Label = Label.new()
	badge.text = "Event"
	badge.add_theme_color_override("font_color", Color(0.55, 0.78, 1.0))
	badge.add_theme_font_size_override("font_size", 11)
	header_row.add_child(badge)

	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(spacer)

	# Make header clickable
	var header_btn: Button = Button.new()
	header_btn.text = "✎"
	header_btn.flat = true
	header_btn.tooltip_text = "Select event"
	header_btn.connect("pressed", _on_event_header_pressed)
	header_row.add_child(header_btn)

	# Separator
	var sep: HSeparator = HSeparator.new()
	_vbox.add_child(sep)

	# Runs line
	_runs_label = Label.new()
	_runs_label.add_theme_color_override("font_color", Color(0.85, 0.75, 0.45))
	_runs_label.add_theme_font_size_override("font_size", 11)
	_vbox.add_child(_runs_label)

	# Conditions section
	var cond_heading: Label = Label.new()
	cond_heading.text = "Conditions"
	cond_heading.add_theme_color_override("font_color", Color(0.65, 0.85, 0.65))
	cond_heading.add_theme_font_size_override("font_size", 11)
	_vbox.add_child(cond_heading)

	_conditions_container = VBoxContainer.new()
	_conditions_container.add_theme_constant_override("separation", 2)
	_vbox.add_child(_conditions_container)

	# Actions section
	var actions_row: HBoxContainer = HBoxContainer.new()
	_vbox.add_child(actions_row)

	var action_heading: Label = Label.new()
	action_heading.text = "Actions"
	action_heading.add_theme_color_override("font_color", Color(0.65, 0.75, 1.0))
	action_heading.add_theme_font_size_override("font_size", 11)
	actions_row.add_child(action_heading)

	var action_spacer: Control = Control.new()
	action_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions_row.add_child(action_spacer)

	var add_action_btn: Button = Button.new()
	add_action_btn.text = "+ Add Action"
	add_action_btn.flat = true
	add_action_btn.tooltip_text = "Add an action to this event"
	add_action_btn.connect("pressed", func() -> void: add_action_requested.emit(self))
	actions_row.add_child(add_action_btn)

	_actions_container = VBoxContainer.new()
	_actions_container.add_theme_constant_override("separation", 2)
	_vbox.add_child(_actions_container)

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
func _make_entry_button(text: String, index: int, is_condition: bool) -> Button:
	var btn: Button = Button.new()
	btn.text = text
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.flat = true
	btn.add_theme_color_override("font_color", Color(0.88, 0.88, 0.88))
	btn.add_theme_font_size_override("font_size", 11)
	if is_condition:
		btn.connect("pressed", func() -> void: condition_selected.emit(self, index))
	else:
		btn.connect("pressed", func() -> void: action_selected.emit(self, index))
	return btn

func _on_event_header_pressed() -> void:
	event_selected.emit(self)
