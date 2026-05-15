# EventForge — Event row UI
@tool
extends PanelContainer
class_name EventRowUI

signal selected(row: EventRow)
signal delete_requested(row: EventRow)
signal add_condition_requested(row: EventRow)
signal add_action_requested(row: EventRow)

var row: EventRow = null

var _enabled_checkbox: CheckBox
var _trigger_label: Label
var _counts_label: Label
var _add_condition_button: Button
var _add_action_button: Button
var _delete_button: Button

## Initializes the row card UI.
func setup() -> void:
    if _enabled_checkbox != null:
        return

    var content: HBoxContainer = HBoxContainer.new()
    add_child(content)

    _enabled_checkbox = CheckBox.new()
    _enabled_checkbox.toggled.connect(_on_enabled_toggled)
    content.add_child(_enabled_checkbox)

    _trigger_label = Label.new()
    _trigger_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    content.add_child(_trigger_label)

    _counts_label = Label.new()
    content.add_child(_counts_label)

    _add_condition_button = Button.new()
    _add_condition_button.text = "+Condition"
    _add_condition_button.pressed.connect(_on_add_condition_pressed)
    content.add_child(_add_condition_button)

    _add_action_button = Button.new()
    _add_action_button.text = "+Action"
    _add_action_button.pressed.connect(_on_add_action_pressed)
    content.add_child(_add_action_button)

    _delete_button = Button.new()
    _delete_button.text = "Delete"
    _delete_button.pressed.connect(_on_delete_pressed)
    content.add_child(_delete_button)

    set_selected(false)

## Binds a row resource and refreshes visible fields.
func set_row(value: EventRow) -> void:
    setup()
    row = value
    if row == null:
        _enabled_checkbox.button_pressed = false
        _trigger_label.text = "<no row>"
        _counts_label.text = ""
        return

    _enabled_checkbox.button_pressed = row.enabled
    var trigger_id: String = row.trigger_id
    if trigger_id.is_empty() and row.trigger != null:
        trigger_id = row.trigger.ace_id
    if trigger_id.is_empty():
        _trigger_label.text = "<no trigger>"
        _trigger_label.add_theme_color_override("font_color", Color(0.95, 0.55, 0.55))
    else:
        _trigger_label.text = _descriptor_summary(row.trigger_provider_id, trigger_id)
        _trigger_label.remove_theme_color_override("font_color")

    var condition_summary: String = _condition_summary()
    var action_summary: String = _action_summary()
    _counts_label.text = "C:%d %s | A:%d %s" % [row.conditions.size(), condition_summary, row.actions.size(), action_summary]

## Updates selected highlight.
func set_selected(is_selected: bool) -> void:
    var background: Color = Color(0.20, 0.32, 0.55, 0.35) if is_selected else Color(0.12, 0.12, 0.12, 0.08)
    add_theme_stylebox_override("panel", _make_stylebox(background))

func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and row != null:
        emit_signal("selected", row)

func _make_stylebox(color: Color) -> StyleBoxFlat:
    var box: StyleBoxFlat = StyleBoxFlat.new()
    box.bg_color = color
    box.corner_radius_top_left = 4
    box.corner_radius_top_right = 4
    box.corner_radius_bottom_left = 4
    box.corner_radius_bottom_right = 4
    return box

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

func _descriptor_summary(provider_id: String, ace_id: String) -> String:
    if ace_id.is_empty():
        return "-"
    var descriptor: ACEDescriptor = ACERegistry.find_descriptor(provider_id, ace_id)
    if descriptor == null:
        return ace_id
    if descriptor.display_name.is_empty():
        return descriptor.ace_id
    return "%s (%s)" % [descriptor.display_name, descriptor.ace_id]

func _condition_summary() -> String:
    if row == null or row.conditions.is_empty():
        return "-"
    var items: Array[String] = []
    var count: int = min(row.conditions.size(), 2)
    for index: int in range(count):
        var condition: ACECondition = row.conditions[index]
        items.append(_descriptor_summary(condition.provider_id, condition.ace_id))
    return "[%s]" % ", ".join(items)

func _action_summary() -> String:
    if row == null or row.actions.is_empty():
        return "-"
    var items: Array[String] = []
    var added: int = 0
    for action_item: Variant in row.actions:
        if not (action_item is ACEAction):
            continue
        var action: ACEAction = action_item
        items.append(_descriptor_summary(action.provider_id, action.ace_id))
        added += 1
        if added >= 2:
            break
    if items.is_empty():
        return "-"
    return "[%s]" % ", ".join(items)
