# EventForge — Sheet toolbar
# Provides Add Event, Add Var, and compile/preview buttons for the event sheet editor.
@tool
extends HBoxContainer
class_name SheetToolbar

## Emitted when the user requests a new event row.
signal add_event_requested
## Emitted when the user requests a new global variable.
signal add_var_requested
## Emitted when the user requests a compile/preview.
signal compile_requested

func _init() -> void:
	_build_ui()

func _build_ui() -> void:
	add_theme_constant_override("separation", 4)

	var add_event_btn: Button = Button.new()
	add_event_btn.text = "+ Add Event"
	add_event_btn.tooltip_text = "Add a new event block to the sheet"
	add_event_btn.connect("pressed", func() -> void: add_event_requested.emit())
	add_child(add_event_btn)

	var add_var_btn: Button = Button.new()
	add_var_btn.text = "+ Add Var"
	add_var_btn.tooltip_text = "Add a new global variable to the sheet"
	add_var_btn.connect("pressed", func() -> void: add_var_requested.emit())
	add_child(add_var_btn)

	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(spacer)

	var compile_btn: Button = Button.new()
	compile_btn.text = "▶ Compile"
	compile_btn.tooltip_text = "Compile event sheet to GDScript"
	compile_btn.connect("pressed", func() -> void: compile_requested.emit())
	add_child(compile_btn)

## Called by the plugin when the toolbar is attached to an editor instance.
func setup() -> void:
	pass
