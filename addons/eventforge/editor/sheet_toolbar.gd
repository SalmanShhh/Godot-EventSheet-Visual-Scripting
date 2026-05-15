# EventForge — Sheet toolbar
@tool
extends HBoxContainer
class_name SheetToolbar

signal new_sheet_requested
signal open_sheet_requested
signal save_sheet_requested
signal save_sheet_as_requested
signal add_event_requested
signal compile_requested
signal refresh_preview_requested
signal view_mode_changed(mode: int)
signal copy_requested
signal paste_requested
signal duplicate_requested
signal delete_requested

var _new_button: Button
var _open_button: Button
var _save_button: Button
var _save_as_button: Button
var _add_event_button: Button
var _compile_button: Button
var _refresh_button: Button
var _copy_button: Button
var _paste_button: Button
var _duplicate_button: Button
var _delete_button: Button
var _view_switcher: DualViewSwitcher

## Builds toolbar controls.
func setup() -> void:
    if _new_button != null:
        return

    _new_button = _make_button("New Sheet", _on_new_pressed)
    _open_button = _make_button("Open Sheet", _on_open_pressed)
    _save_button = _make_button("Save Sheet", _on_save_pressed)
    _save_as_button = _make_button("Save Sheet As", _on_save_as_pressed)
    _add_event_button = _make_button("Add Event", _on_add_event_pressed)
    _compile_button = _make_button("Compile", _on_compile_pressed)
    _refresh_button = _make_button("Refresh Preview", _on_refresh_pressed)
    _copy_button = _make_button("Copy", _on_copy_pressed)
    _paste_button = _make_button("Paste", _on_paste_pressed)
    _duplicate_button = _make_button("Duplicate", _on_duplicate_pressed)
    _delete_button = _make_button("Delete", _on_delete_pressed)

    add_child(_new_button)
    add_child(_open_button)
    add_child(_save_button)
    add_child(_save_as_button)
    add_child(_add_event_button)
    add_child(_compile_button)
    add_child(_refresh_button)
    add_child(_copy_button)
    add_child(_paste_button)
    add_child(_duplicate_button)
    add_child(_delete_button)

    var spacer: Control = Control.new()
    spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    add_child(spacer)

    _view_switcher = DualViewSwitcher.new()
    _view_switcher.setup()
    _view_switcher.view_mode_changed.connect(_on_view_mode_changed)
    add_child(_view_switcher)

## Keeps switcher state in sync with active mode.
func set_view_mode(mode: int) -> void:
    if _view_switcher == null:
        setup()
    _view_switcher.set_mode(mode, false)

func _make_button(label: String, callback: Callable) -> Button:
    var button: Button = Button.new()
    button.text = label
    button.pressed.connect(callback)
    return button

func _on_new_pressed() -> void:
    emit_signal("new_sheet_requested")

func _on_open_pressed() -> void:
    emit_signal("open_sheet_requested")

func _on_save_pressed() -> void:
    emit_signal("save_sheet_requested")

func _on_save_as_pressed() -> void:
    emit_signal("save_sheet_as_requested")

func _on_add_event_pressed() -> void:
    emit_signal("add_event_requested")

func _on_compile_pressed() -> void:
    emit_signal("compile_requested")

func _on_refresh_pressed() -> void:
    emit_signal("refresh_preview_requested")

func _on_copy_pressed() -> void:
    emit_signal("copy_requested")

func _on_paste_pressed() -> void:
    emit_signal("paste_requested")

func _on_duplicate_pressed() -> void:
    emit_signal("duplicate_requested")

func _on_delete_pressed() -> void:
    emit_signal("delete_requested")

func _on_view_mode_changed(mode: int) -> void:
    emit_signal("view_mode_changed", mode)
