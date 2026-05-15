# EventForge — Dual view switcher
@tool
extends HBoxContainer
class_name DualViewSwitcher

signal view_mode_changed(mode: int)

const MODE_EVENT_SHEET: int = 0
const MODE_GDSCRIPT: int = 1
const MODE_SPLIT: int = 2

var _button_group: ButtonGroup = ButtonGroup.new()
var _sheet_button: Button
var _split_button: Button
var _code_button: Button

## Builds mode toggle controls.
func setup() -> void:
    if _sheet_button != null:
        return

    _sheet_button = _make_button("Sheet", MODE_EVENT_SHEET)
    _split_button = _make_button("Split", MODE_SPLIT)
    _code_button = _make_button("Code", MODE_GDSCRIPT)

    add_child(_sheet_button)
    add_child(_split_button)
    add_child(_code_button)

    set_mode(MODE_SPLIT, false)

## Updates selected mode.
func set_mode(mode: int, emit_change: bool = false) -> void:
    setup()
    match mode:
        MODE_EVENT_SHEET:
            _sheet_button.button_pressed = true
        MODE_GDSCRIPT:
            _code_button.button_pressed = true
        _:
            _split_button.button_pressed = true

    if emit_change:
        emit_signal("view_mode_changed", mode)

func _make_button(label: String, mode: int) -> Button:
    var button: Button = Button.new()
    button.text = label
    button.toggle_mode = true
    button.button_group = _button_group
    button.pressed.connect(_on_mode_pressed.bind(mode))
    return button

func _on_mode_pressed(mode: int) -> void:
    emit_signal("view_mode_changed", mode)
