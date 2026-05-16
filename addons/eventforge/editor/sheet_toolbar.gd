# EventForge — Sheet toolbar
# Provides first-run actions for creating/opening and editing event sheets.
@tool
extends PanelContainer
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
var _doc_meta_label: Label = null
var _selection_meta_label: Label = null
var _sheet_name_label: Label = null

func _init() -> void:
	_build_ui()

func _build_ui() -> void:
	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.082, 0.090, 0.116, 1.0)
	panel_style.border_color = Color(0.168, 0.195, 0.248, 1.0)
	panel_style.set_border_width_all(0)
	panel_style.border_width_bottom = 1
	panel_style.set_corner_radius_all(6)
	panel_style.set_content_margin_all(10)
	add_theme_stylebox_override("panel", panel_style)

	var shell: VBoxContainer = VBoxContainer.new()
	shell.add_theme_constant_override("separation", 6)
	add_child(shell)

	var top_line: HBoxContainer = HBoxContainer.new()
	top_line.add_theme_constant_override("separation", 6)
	shell.add_child(top_line)

	var title: Label = Label.new()
	title.text = "EventForge"
	title.add_theme_color_override("font_color", Color(0.78, 0.86, 0.98))
	title.add_theme_font_size_override("font_size", 12)
	top_line.add_child(title)

	var title_sep: VSeparator = VSeparator.new()
	title_sep.add_theme_color_override("color", Color(0.22, 0.26, 0.36, 0.60))
	top_line.add_child(title_sep)

	_sheet_name_label = Label.new()
	_sheet_name_label.text = ""
	_sheet_name_label.add_theme_color_override("font_color", Color(0.88, 0.94, 1.0))
	_sheet_name_label.add_theme_font_size_override("font_size", 12)
	top_line.add_child(_sheet_name_label)

	_doc_meta_label = Label.new()
	_doc_meta_label.text = "No sheet loaded"
	_doc_meta_label.add_theme_color_override("font_color", Color(0.50, 0.58, 0.72))
	_doc_meta_label.add_theme_font_size_override("font_size", 10)
	top_line.add_child(_doc_meta_label)

	var meta_sep: VSeparator = VSeparator.new()
	meta_sep.add_theme_color_override("color", Color(0.22, 0.26, 0.36, 0.60))
	top_line.add_child(meta_sep)

	_selection_meta_label = Label.new()
	_selection_meta_label.text = "No selection"
	_selection_meta_label.add_theme_color_override("font_color", Color(0.60, 0.70, 0.84))
	_selection_meta_label.add_theme_font_size_override("font_size", 10)
	top_line.add_child(_selection_meta_label)

	var top_spacer: Control = Control.new()
	top_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_line.add_child(top_spacer)

	_status_label = Label.new()
	_status_label.text = ""
	_status_label.add_theme_color_override("font_color", Color(0.70, 0.74, 0.80))
	_status_label.add_theme_font_size_override("font_size", 10)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top_line.add_child(_status_label)

	var actions_line: HBoxContainer = HBoxContainer.new()
	actions_line.add_theme_constant_override("separation", 5)
	shell.add_child(actions_line)

	var new_sheet_btn: Button = Button.new()
	new_sheet_btn.text = "New Sheet"
	new_sheet_btn.tooltip_text = "Create a new in-memory EventSheetResource"
	new_sheet_btn.connect("pressed", func() -> void: new_sheet_requested.emit())
	actions_line.add_child(new_sheet_btn)

	var open_sheet_btn: Button = Button.new()
	open_sheet_btn.text = "Open"
	open_sheet_btn.tooltip_text = "Open an existing EventSheetResource from project files"
	open_sheet_btn.connect("pressed", func() -> void: open_sheet_requested.emit())
	actions_line.add_child(open_sheet_btn)

	var sep: VSeparator = VSeparator.new()
	actions_line.add_child(sep)

	_add_event_btn = Button.new()
	_add_event_btn.text = "+ Event"
	_add_event_btn.tooltip_text = "Add a new event block to the sheet"
	_add_event_btn.connect("pressed", func() -> void: add_event_requested.emit())
	actions_line.add_child(_add_event_btn)

	_add_var_btn = Button.new()
	_add_var_btn.text = "+ Variable"
	_add_var_btn.tooltip_text = "Add a new global variable to the sheet"
	_add_var_btn.connect("pressed", func() -> void: add_var_requested.emit())
	actions_line.add_child(_add_var_btn)

	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions_line.add_child(spacer)

	_compile_btn = Button.new()
	_compile_btn.text = "Compile Preview"
	_compile_btn.tooltip_text = "Compile / Refresh Preview for the current event sheet"
	_compile_btn.connect("pressed", func() -> void: compile_requested.emit())
	actions_line.add_child(_compile_btn)

	set_sheet_loaded(false)

## Called by the plugin when the toolbar is attached to an editor instance.
func setup() -> void:
	pass

static func format_document_meta(sheet: EventSheetResource) -> String:
	if sheet == null:
		return "No sheet loaded"
	return "%d globals · %d root rows" % [sheet.variables.size(), sheet.events.size()]

static func _format_sheet_name(sheet: EventSheetResource) -> String:
	if sheet == null:
		return ""
	if sheet.resource_path.is_empty():
		return "Untitled Sheet"
	return sheet.resource_path.get_file().get_basename()

static func format_selection_meta(selection_kind: String) -> String:
	match selection_kind:
		"event":
			return "Selection: Event"
		"condition":
			return "Selection: Condition"
		"action":
			return "Selection: Action"
		"variable":
			return "Selection: Variable"
		"group":
			return "Selection: Group"
		_:
			return "No selection"

## Enables or disables sheet-editing actions that require a loaded sheet.
func set_sheet_loaded(loaded: bool) -> void:
	if _add_event_btn != null:
		_add_event_btn.disabled = not loaded
	if _add_var_btn != null:
		_add_var_btn.disabled = not loaded
	if _compile_btn != null:
		_compile_btn.disabled = not loaded
	if not loaded:
		set_context(null, "none")
		if _sheet_name_label != null:
			_sheet_name_label.text = ""

func set_context(sheet: EventSheetResource, selection_kind: String = "none") -> void:
	if _doc_meta_label != null:
		_doc_meta_label.text = format_document_meta(sheet)
	if _selection_meta_label != null:
		_selection_meta_label.text = format_selection_meta(selection_kind)
	if _sheet_name_label != null:
		_sheet_name_label.text = _format_sheet_name(sheet)

## Updates the toolbar status text.
func set_status(text: String, is_error: bool = false) -> void:
	if _status_label == null:
		return
	_status_label.text = text
	_status_label.add_theme_color_override("font_color", Color(0.90, 0.55, 0.55) if is_error else Color(0.70, 0.74, 0.80))
