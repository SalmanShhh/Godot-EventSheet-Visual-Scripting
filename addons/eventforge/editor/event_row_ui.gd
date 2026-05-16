# EventForge — Event row UI
@tool
extends PanelContainer
class_name EventRowUI

signal selected(row: EventRow)
signal delete_requested(row: EventRow)
signal add_condition_requested(row: EventRow)
signal add_action_requested(row: EventRow)
signal duplicate_requested(row: EventRow)

var row: EventRow = null

var _enabled_checkbox: CheckBox
var _title_label: Label
var _runs_label: Label
var _prompt_label: Label
var _conditions_list: VBoxContainer
var _actions_list: VBoxContainer
var _add_condition_button: Button
var _add_action_button: Button
var _duplicate_button: Button
var _delete_button: Button

## Initializes the row card UI.
func setup() -> void:
	if _enabled_checkbox != null:
		return

	var wrapper: VBoxContainer = VBoxContainer.new()
	wrapper.add_theme_constant_override("separation", 8)
	add_child(wrapper)

	var header: HBoxContainer = HBoxContainer.new()
	wrapper.add_child(header)

	_enabled_checkbox = CheckBox.new()
	_enabled_checkbox.toggled.connect(_on_enabled_toggled)
	header.add_child(_enabled_checkbox)

	_title_label = Label.new()
	_title_label.text = "Event"
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title_label)

	_runs_label = Label.new()
	_runs_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	wrapper.add_child(_runs_label)

	_prompt_label = Label.new()
	_prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_prompt_label.visible = false
	wrapper.add_child(_prompt_label)

	wrapper.add_child(_section_title("Conditions"))
	_conditions_list = VBoxContainer.new()
	_conditions_list.add_theme_constant_override("separation", 4)
	wrapper.add_child(_conditions_list)

	wrapper.add_child(_section_title("Actions"))
	_actions_list = VBoxContainer.new()
	_actions_list.add_theme_constant_override("separation", 4)
	wrapper.add_child(_actions_list)

	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	wrapper.add_child(buttons)

	_add_condition_button = Button.new()
	_add_condition_button.text = "+ Condition"
	_add_condition_button.pressed.connect(_on_add_condition_pressed)
	buttons.add_child(_add_condition_button)

	_add_action_button = Button.new()
	_add_action_button.text = "+ Action"
	_add_action_button.pressed.connect(_on_add_action_pressed)
	buttons.add_child(_add_action_button)

	_duplicate_button = Button.new()
	_duplicate_button.text = "Duplicate"
	_duplicate_button.pressed.connect(_on_duplicate_pressed)
	buttons.add_child(_duplicate_button)

	_delete_button = Button.new()
	_delete_button.text = "Delete"
	_delete_button.pressed.connect(_on_delete_pressed)
	buttons.add_child(_delete_button)

	set_selected(false)

## Binds a row resource and refreshes visible fields.
func set_row(value: EventRow) -> void:
	setup()
	row = value
	_clear_list(_conditions_list)
	_clear_list(_actions_list)
	if row == null:
		_enabled_checkbox.button_pressed = false
		_title_label.text = "Event"
		_runs_label.text = "Runs: Every Frame"
		_prompt_label.visible = false
		return

	_enabled_checkbox.button_pressed = row.enabled
	_title_label.text = "Event %s" % row.event_uid
	_runs_label.text = "Runs: %s" % _run_summary()

	if row.conditions.is_empty():
		_conditions_list.add_child(_entry_label("Always"))
	else:
		for condition: ACECondition in row.conditions:
			_conditions_list.add_child(_entry_label(_condition_summary(condition)))

	if row.actions.is_empty():
		_actions_list.add_child(_entry_label("No actions yet"))
	else:
		for action_item: Variant in row.actions:
			if action_item is ACEAction:
				_actions_list.add_child(_entry_label(_action_summary(action_item)))

	var has_trigger: bool = TriggerResolver.has_trigger_condition(row)
	var is_new_event: bool = not has_trigger and row.conditions.is_empty() and row.actions.is_empty()
	_prompt_label.visible = is_new_event
	if is_new_event:
		_prompt_label.text = "New Event\nChoose a Trigger, Condition, or Action from the left panel."
	else:
		_prompt_label.text = ""

## Updates selected highlight.
func set_selected(is_selected: bool) -> void:
	var background: Color = Color(0.20, 0.32, 0.55, 0.45) if is_selected else Color(0.12, 0.12, 0.12, 0.08)
	add_theme_stylebox_override("panel", _make_stylebox(background, is_selected))

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and row != null:
		emit_signal("selected", row)

func _make_stylebox(color: Color, is_selected: bool) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = color
	box.border_width_left = 2
	box.border_width_top = 2
	box.border_width_right = 2
	box.border_width_bottom = 2
	box.border_color = Color(0.38, 0.62, 0.96, 0.9) if is_selected else Color(0.30, 0.30, 0.30, 0.35)
	box.corner_radius_top_left = 4
	box.corner_radius_top_right = 4
	box.corner_radius_bottom_left = 4
	box.corner_radius_bottom_right = 4
	box.content_margin_left = 8
	box.content_margin_top = 8
	box.content_margin_right = 8
	box.content_margin_bottom = 8
	return box

func _section_title(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	return label

func _entry_label(text: String) -> Label:
	var label: Label = Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = "  %s" % text
	return label

func _run_summary() -> String:
	if row == null:
		return "Every Frame"
	var trigger_id: String = TriggerResolver.get_trigger_id(row)
	match trigger_id:
		"":
			return "Every Frame"
		"OnReady":
			return "On Ready"
		"OnProcess":
			return "On Process"
		"OnPhysicsProcess":
			return "On Physics Process"
		"OnBodyEntered":
			return "On Body Entered"
		"OnSignal":
			var params: Dictionary = TriggerResolver.get_trigger_params(row)
			var signal_name: String = _clean_param_text(str(params.get("signal_name", "eventforge_signal")))
			var target_node: String = _clean_param_text(str(params.get("target_node", "self")))
			if target_node.is_empty() or target_node == ".":
				target_node = "self"
			return "On Signal \"%s\" from %s" % [signal_name, target_node]
		_:
			return _descriptor_name(TriggerResolver.get_trigger_provider_id(row), trigger_id)

func _condition_summary(condition: ACECondition) -> String:
	var name: String = _descriptor_name(condition.provider_id, condition.ace_id)
	var detail: String = ConditionCodegen.generate_condition(condition)
	if detail.is_empty() or detail == name or _has_no_visible_params(condition.params if not condition.params.is_empty() else condition.parameters):
		return name
	return "%s: %s" % [name, detail]

func _action_summary(action: ACEAction) -> String:
	var name: String = _descriptor_name(action.provider_id, action.ace_id)
	var detail: String = ActionCodegen.generate_action(action)
	if detail.is_empty() or detail == name or _has_no_visible_params(action.params if not action.params.is_empty() else action.parameters):
		return name
	return "%s: %s" % [name, detail]

func _has_no_visible_params(params: Dictionary) -> bool:
	if params.is_empty():
		return true
	for value: Variant in params.values():
		if not str(value).strip_edges().is_empty():
			return false
	return true

func _clean_param_text(text: String) -> String:
	var cleaned: String = text.strip_edges()
	if cleaned.begins_with("\"") and cleaned.ends_with("\"") and cleaned.length() >= 2:
		cleaned = cleaned.substr(1, cleaned.length() - 2)
	return cleaned

func _descriptor_name(provider_id: String, ace_id: String) -> String:
	if ace_id.is_empty():
		return "-"
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor(provider_id, ace_id)
	if descriptor == null:
		return ace_id
	if descriptor.display_name.is_empty():
		return descriptor.ace_id
	return descriptor.display_name

func _clear_list(container: VBoxContainer) -> void:
	if container == null:
		return
	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()

func _on_enabled_toggled(is_enabled: bool) -> void:
	if row != null:
		row.enabled = is_enabled
		emit_signal("selected", row)

func _on_delete_pressed() -> void:
	if row != null:
		emit_signal("delete_requested", row)

func _on_add_condition_pressed() -> void:
	if row != null:
		emit_signal("add_condition_requested", row)

func _on_add_action_pressed() -> void:
	if row != null:
		emit_signal("add_action_requested", row)

func _on_duplicate_pressed() -> void:
	if row != null:
		emit_signal("duplicate_requested", row)
