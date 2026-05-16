# EventForge — Sheet toolbar
# Provides first-run actions for creating/opening and editing event sheets.
@tool
extends HBoxContainer
class_name SheetToolbar

## Emitted when the user requests a blank event sheet.
signal new_sheet_requested
## Emitted when the user requests opening an existing event sheet.
signal open_sheet_requested
## Emitted when the user requests a new event row.
signal add_event_requested
## Emitted when the user requests a new global variable.
signal add_var_requested
## Emitted when the user requests a compile/preview.
signal compile_requested

var _add_event_btn: Button = null
var _add_var_btn: Button = null
var _compile_btn: Button = null
var _status_label: Label = null

func _init() -> void:
	_build_ui()

func _build_ui() -> void:
	add_theme_constant_override("separation", 4)

	var new_sheet_btn: Button = Button.new()
	new_sheet_btn.text = "Create New Event Sheet"
	new_sheet_btn.tooltip_text = "Create a new in-memory EventSheetResource"
	new_sheet_btn.connect("pressed", func() -> void: new_sheet_requested.emit())
	add_child(new_sheet_btn)

	var open_sheet_btn: Button = Button.new()
	open_sheet_btn.text = "Open Existing Event Sheet"
	open_sheet_btn.tooltip_text = "Open an existing EventSheetResource from project files"
	open_sheet_btn.connect("pressed", func() -> void: open_sheet_requested.emit())
	add_child(open_sheet_btn)

	var sep: VSeparator = VSeparator.new()
	add_child(sep)

	_add_event_btn = Button.new()
	_add_event_btn.text = "Add Event"
	_add_event_btn.tooltip_text = "Add a new event block to the sheet"
	_add_event_btn.connect("pressed", func() -> void: add_event_requested.emit())
	add_child(_add_event_btn)

	_add_var_btn = Button.new()
	_add_var_btn.text = "Add Variable"
	_add_var_btn.tooltip_text = "Add a new global variable to the sheet"
	_add_var_btn.connect("pressed", func() -> void: add_var_requested.emit())
	add_child(_add_var_btn)

	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(spacer)

	_status_label = Label.new()
	_status_label.text = ""
	_status_label.add_theme_color_override("font_color", Color(0.70, 0.74, 0.80))
	_status_label.add_theme_font_size_override("font_size", 10)
	add_child(_status_label)

	_compile_btn = Button.new()
	_compile_btn.text = "Compile / Refresh Preview"
	_compile_btn.tooltip_text = "Compile the current event sheet for preview"
	_compile_btn.connect("pressed", func() -> void: compile_requested.emit())
	add_child(_compile_btn)

	set_sheet_loaded(false)

## Called by the plugin when the toolbar is attached to an editor instance.
func setup() -> void:
	pass

## Enables or disables sheet-editing actions that require a loaded sheet.
func set_sheet_loaded(loaded: bool) -> void:
	if _add_event_btn != null:
		_add_event_btn.disabled = not loaded
	if _add_var_btn != null:
		_add_var_btn.disabled = not loaded
	if _compile_btn != null:
		_compile_btn.disabled = not loaded

## Updates the toolbar status text.
func set_status(text: String, is_error: bool = false) -> void:
	if _status_label == null:
		return
	_status_label.text = text
	_status_label.add_theme_color_override("font_color", Color(0.90, 0.55, 0.55) if is_error else Color(0.70, 0.74, 0.80))
