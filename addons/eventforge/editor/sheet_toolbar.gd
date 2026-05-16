# EventForge — EventSheet workspace toolbar
# Provides document-level and authoring actions for the EventSheet workspace.
@tool
extends PanelContainer
class_name SheetToolbar

## Emitted when the user requests a blank event sheet.
signal new_sheet_requested
## Emitted when the user requests opening an existing event sheet.
signal open_sheet_requested
## Emitted when the user requests saving the current sheet in place.
signal save_requested
## Emitted when the user requests saving the current sheet to a new path.
signal save_as_requested
## Emitted when the user requests a new event row.
signal add_event_requested
## Emitted when the user requests a new global variable.
signal add_var_requested
## Emitted when the user requests a compile/preview.
signal compile_requested

const SHORTCUT_SAVE: String = "Ctrl+S Save"
const SHORTCUT_ADD_EVENT: String = "Ctrl+E Event"
const SHORTCUT_ADD_VARIABLE: String = "Ctrl+Shift+V Variable"
const SHORTCUT_ADD_CONDITION: String = "Ctrl+Shift+C Condition"
const SHORTCUT_ADD_ACTION: String = "Ctrl+Shift+A Action"
const SHORTCUT_ADD_COMMENT: String = "Q Comment"
const SHORTCUT_ADD_GROUP: String = "G Group"
const SHORTCUT_COPY_EVENT: String = "Ctrl+C Copy Event"
const SHORTCUT_PASTE_EVENT: String = "Ctrl+V Paste Event"
const SHORTCUT_DUPLICATE_EVENT: String = "Ctrl+D Duplicate"
const SHORTCUT_DELETE_SELECTION: String = "Del Delete"
const SHORTCUT_ESCAPE: String = "Esc Deselect"
const SHORTCUTS_HINT_SEGMENTS: PackedStringArray = [
	SHORTCUT_SAVE,
	SHORTCUT_ADD_EVENT,
	SHORTCUT_ADD_VARIABLE,
	SHORTCUT_ADD_CONDITION,
	SHORTCUT_ADD_ACTION,
	SHORTCUT_ADD_COMMENT,
	SHORTCUT_ADD_GROUP,
	SHORTCUT_COPY_EVENT,
	SHORTCUT_PASTE_EVENT,
	SHORTCUT_DUPLICATE_EVENT,
	SHORTCUT_DELETE_SELECTION,
	SHORTCUT_ESCAPE
]
const SHORTCUTS_HINT_COLOR: Color = Color(0.52, 0.61, 0.74)

var _add_event_btn: Button = null
var _add_var_btn: Button = null
var _compile_btn: Button = null
var _save_btn: Button = null
var _save_as_btn: Button = null
var _doc_meta_label: Label = null
var _sheet_path_label: Label = null
var _selection_meta_label: Label = null
var _sheet_name_label: Label = null
var _dirty_indicator: Label = null
var _shortcuts_hint_label: Label = null

func _init() -> void:
	_build_ui()

func _build_ui() -> void:
	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.076, 0.084, 0.108, 1.0)
	panel_style.border_color = Color(0.148, 0.171, 0.218, 1.0)
	panel_style.set_border_width_all(0)
	panel_style.border_width_bottom = 1
	# No corner radius: toolbar sits flush at the top of the main-screen workspace.
	panel_style.set_corner_radius_all(0)
	panel_style.set_content_margin(SIDE_LEFT, 6)
	panel_style.set_content_margin(SIDE_RIGHT, 6)
	panel_style.set_content_margin(SIDE_TOP, 3)
	panel_style.set_content_margin(SIDE_BOTTOM, 3)
	add_theme_stylebox_override("panel", panel_style)

	var shell: VBoxContainer = VBoxContainer.new()
	shell.add_theme_constant_override("separation", 1)
	add_child(shell)

	var top_line: HBoxContainer = HBoxContainer.new()
	top_line.add_theme_constant_override("separation", 4)
	top_line.visible = false
	shell.add_child(top_line)

	var title: Label = Label.new()
	title.text = "EventSheet"
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

	_dirty_indicator = Label.new()
	_dirty_indicator.text = "●"
	_dirty_indicator.add_theme_color_override("font_color", Color(0.95, 0.72, 0.30))
	_dirty_indicator.add_theme_font_size_override("font_size", 10)
	_dirty_indicator.tooltip_text = "Unsaved changes"
	_dirty_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dirty_indicator.visible = false
	top_line.add_child(_dirty_indicator)

	_doc_meta_label = Label.new()
	_doc_meta_label.text = "No sheet loaded"
	_doc_meta_label.add_theme_color_override("font_color", Color(0.44, 0.52, 0.66))
	_doc_meta_label.add_theme_font_size_override("font_size", 9)
	_doc_meta_label.visible = false
	top_line.add_child(_doc_meta_label)

	var meta_sep: VSeparator = VSeparator.new()
	meta_sep.add_theme_color_override("color", Color(0.22, 0.26, 0.36, 0.60))
	top_line.add_child(meta_sep)

	_sheet_path_label = Label.new()
	_sheet_path_label.text = ""
	_sheet_path_label.add_theme_color_override("font_color", Color(0.42, 0.50, 0.64))
	_sheet_path_label.add_theme_font_size_override("font_size", 9)
	_sheet_path_label.visible = false
	top_line.add_child(_sheet_path_label)

	var path_sep: VSeparator = VSeparator.new()
	path_sep.add_theme_color_override("color", Color(0.22, 0.26, 0.36, 0.60))
	top_line.add_child(path_sep)

	_selection_meta_label = Label.new()
	_selection_meta_label.text = "No selection"
	_selection_meta_label.add_theme_color_override("font_color", Color(0.52, 0.62, 0.76))
	_selection_meta_label.add_theme_font_size_override("font_size", 9)
	_selection_meta_label.visible = false
	top_line.add_child(_selection_meta_label)

	var top_spacer: Control = Control.new()
	top_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_line.add_child(top_spacer)

	var actions_line: HBoxContainer = HBoxContainer.new()
	actions_line.add_theme_constant_override("separation", 2)
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

	_save_btn = Button.new()
	_save_btn.text = "Save"
	_save_btn.tooltip_text = "Save the current EventSheetResource to its file path (Ctrl+S)"
	_save_btn.connect("pressed", func() -> void: save_requested.emit())
	actions_line.add_child(_save_btn)

	_save_as_btn = Button.new()
	_save_as_btn.text = "Save As\u2026"
	_save_as_btn.tooltip_text = "Save the current EventSheetResource to a new file path"
	_save_as_btn.connect("pressed", func() -> void: save_as_requested.emit())
	actions_line.add_child(_save_as_btn)

	var sep: VSeparator = VSeparator.new()
	actions_line.add_child(sep)

	_add_event_btn = Button.new()
	_add_event_btn.text = "+ Event"
	_add_event_btn.tooltip_text = "Add a new event block to the sheet (Ctrl+E)"
	_add_event_btn.connect("pressed", func() -> void: add_event_requested.emit())
	actions_line.add_child(_add_event_btn)

	_add_var_btn = Button.new()
	_add_var_btn.text = "+ Variable"
	_add_var_btn.tooltip_text = "Add a new global variable to the sheet (Ctrl+Shift+V)"
	_add_var_btn.connect("pressed", func() -> void: add_var_requested.emit())
	actions_line.add_child(_add_var_btn)

	_shortcuts_hint_label = Label.new()
	_shortcuts_hint_label.text = shortcut_hint_text()
	_shortcuts_hint_label.add_theme_color_override("font_color", SHORTCUTS_HINT_COLOR)
	_shortcuts_hint_label.add_theme_font_size_override("font_size", 8)
	_shortcuts_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shortcuts_hint_label.visible = false
	actions_line.add_child(_shortcuts_hint_label)

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

static func shortcut_hint_text() -> String:
	return "Shortcuts: %s" % " | ".join(SHORTCUTS_HINT_SEGMENTS)

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

static func format_document_path(sheet: EventSheetResource) -> String:
	if sheet == null:
		return "No path"
	if sheet.resource_path.is_empty():
		return "Unsaved (in-memory)"
	return sheet.resource_path

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
		"comment":
			return "Selection: Comment"
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
	if _save_btn != null:
		_save_btn.disabled = not loaded
	if _save_as_btn != null:
		_save_as_btn.disabled = not loaded
	if _shortcuts_hint_label != null:
		_shortcuts_hint_label.visible = false
	if _doc_meta_label != null:
		_doc_meta_label.visible = loaded
	if _sheet_path_label != null:
		_sheet_path_label.visible = false
	if _selection_meta_label != null:
		_selection_meta_label.visible = false
	if not loaded:
		set_context(null, "none")
		set_dirty(false)
		if _sheet_name_label != null:
			_sheet_name_label.text = ""

## Shows or hides the unsaved-changes indicator (●) next to the sheet name.
func set_dirty(dirty: bool) -> void:
	if _dirty_indicator != null:
		_dirty_indicator.visible = dirty

func set_context(sheet: EventSheetResource, selection_kind: String = "none") -> void:
	if _doc_meta_label != null:
		_doc_meta_label.text = format_document_meta(sheet)
	if _selection_meta_label != null:
		_selection_meta_label.text = format_selection_meta(selection_kind)
	if _sheet_name_label != null:
		_sheet_name_label.text = _format_sheet_name(sheet)
		var meta: String = format_document_meta(sheet)
		var path: String = format_document_path(sheet)
		var selection: String = format_selection_meta(selection_kind)
		_sheet_name_label.tooltip_text = "Meta: %s\nPath: %s\nSelection: %s" % [meta, path, selection]
	if _sheet_path_label != null:
		_sheet_path_label.text = format_document_path(sheet)
