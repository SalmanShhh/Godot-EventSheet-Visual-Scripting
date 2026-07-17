@tool
class_name EventSheetNewResourceWizard
extends RefCounted

# New Custom Resource wizard (Sheet ▸ New Custom Resource…).
#
# Three beginner questions - what is one entry called, what columns does an entry have, must
# the grid be filled - and out comes a Resource-host sheet whose exported grid variable IS the
# Inspector: a table drawer with typed and dropdown columns, exactly the UHTNPlanResource /
# LootTableResource shape, without the author ever seeing the column-hint syntax. The column
# phrases are parsed by EventSheets.resource_grid (the one owner of that syntax), so the
# wizard, pack builders, and extensions can never drift apart.
#
# Mirrors EventSheetNewAddonPanel's shape: owns its dialog, parents it on the dock, and after
# Create adopts the fresh sheet through the dock (unsaved - Save As to keep). The sheet
# building is a PURE static (build_wizard_sheet) so tests cover it headless, no window needed.

var _dock: Control = null
var _dialog: Window = null
var _entry_edit: LineEdit = null
var _class_edit: LineEdit = null
var _columns_edit: TextEdit = null
var _required_check: CheckBox = null
var _preview_label: Label = null


func init(dock: Control) -> void:
	_dock = dock


## Opens the dialog fresh (clears the fields), building it lazily on first use.
func open() -> void:
	_build_dialog()
	_entry_edit.text = ""
	_class_edit.text = ""
	_columns_edit.text = ""
	_required_check.button_pressed = false
	_refresh_preview()
	if _dialog.is_inside_tree():  # headless tests: fields reset, no window to pop
		_dialog.popup_centered(Vector2i(560, 600))
		_entry_edit.grab_focus()


func _build_dialog() -> void:
	if _dialog != null:
		return
	_dialog = Window.new()
	_dialog.title = "New Custom Resource"
	_dialog.visible = false
	_dialog.min_size = Vector2i(520, 520)
	_dialog.close_requested.connect(func() -> void: _dialog.hide())
	_dock.add_child(_dialog)

	var content: VBoxContainer = EventSheetPopupUI.form_box()
	content.add_child(EventSheetPopupUI.hint_label("Makes your own data asset: a Resource with a table designers fill in the Inspector and save as .tres files - loot tables, dialogue lines, wave plans, anything that is rows of data. No annotations to learn; describe the rows and the sheet is generated."))

	var identity_box: VBoxContainer = EventSheetPopupUI.form_box()
	content.add_child(EventSheetPopupUI.titled_card("What are you making?", identity_box))
	_entry_edit = LineEdit.new()
	_entry_edit.placeholder_text = "Loot Drop  (what is ONE entry called?)"
	_entry_edit.text_changed.connect(func(_t: String) -> void: _refresh_preview())
	identity_box.add_child(EventSheetPopupUI.form_row("One entry is a…", _entry_edit))
	_class_edit = LineEdit.new()
	_class_edit.placeholder_text = "LootTable  (auto from the entry name)"
	_class_edit.text_changed.connect(func(_t: String) -> void: _refresh_preview())
	identity_box.add_child(EventSheetPopupUI.form_row("Resource name", _class_edit))

	var columns_box: VBoxContainer = EventSheetPopupUI.form_box()
	content.add_child(EventSheetPopupUI.titled_card("What does an entry have?", columns_box))
	columns_box.add_child(EventSheetPopupUI.hint_label("One column per line. Plain words make a text column; add \": float\", \": int\", or \": bool\" for numbers and toggles; list choices with | for a dropdown.\n\nname\nkind: coin|gem|key\nweight: float"))
	_columns_edit = TextEdit.new()
	_columns_edit.custom_minimum_size = Vector2(0, 110)
	_columns_edit.placeholder_text = "name\nkind: coin|gem|key\nweight: float"
	_columns_edit.text_changed.connect(_refresh_preview)
	columns_box.add_child(_columns_edit)

	var safety_box: VBoxContainer = EventSheetPopupUI.form_box()
	content.add_child(EventSheetPopupUI.titled_card("Before it works", safety_box))
	_required_check = CheckBox.new()
	_required_check.text = "Warn in the Inspector until the table has rows (required)"
	_required_check.toggled.connect(func(_on: bool) -> void: _refresh_preview())
	safety_box.add_child(_required_check)

	_preview_label = EventSheetPopupUI.hint_label("")
	content.add_child(_preview_label)

	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	var cancel_button: Button = Button.new()
	cancel_button.text = "Cancel"
	cancel_button.pressed.connect(func() -> void: _dialog.hide())
	buttons.add_child(cancel_button)
	var create_button: Button = Button.new()
	create_button.text = "Create"
	create_button.pressed.connect(_on_create)
	buttons.add_child(create_button)
	content.add_child(buttons)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.add_child(content)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dialog.add_child(scroll)


## Live receipt: what the grid will look like in the Inspector, phrased by the API's own
## describer so the preview can never disagree with the emitted sheet.
func _refresh_preview() -> void:
	if _preview_label == null:
		return
	var grid_name: String = grid_name_for(_entry_edit.text)
	var descriptor: Dictionary = EventSheets.resource_grid(_column_lines(), {"required": _required_check.button_pressed})
	_preview_label.text = "Ships as: %s - %s" % [
		grid_name if not grid_name.is_empty() else "(name the entry above)",
		EventSheets.describe_inspector("Array", descriptor.get("attributes", {}))
	]


func _column_lines() -> Array:
	var lines: Array = []
	for line: String in _columns_edit.text.split("\n"):
		if not line.strip_edges().is_empty():
			lines.append(line.strip_edges())
	return lines


func _on_create() -> void:
	var entry_name: String = _entry_edit.text.strip_edges()
	if entry_name.is_empty():
		_dock._set_status("Name what one entry is called first (e.g. \"Loot Drop\").", true)
		return
	var columns: Array = _column_lines()
	if columns.is_empty():
		_dock._set_status("List at least one column (one per line).", true)
		return
	var sheet: EventSheetResource = build_wizard_sheet(_class_edit.text, entry_name, columns, _required_check.button_pressed)
	_dialog.hide()
	_dock.setup(sheet)
	_dock._current_sheet_path = ""
	_dock._dirty = true
	_dock._refresh_title_strip()
	_dock._clear_undo_history()
	_dock._set_status("New %s resource - fill the %s grid via the Inspector Designer, then Save As… to keep it." % [sheet.custom_class_name, grid_name_for(entry_name)])


## The whole wizard as a pure function: entry name + column phrases -> a Resource-host sheet
## whose grid variable came from EventSheets.resource_grid. Headless-testable.
static func build_wizard_sheet(resource_name: String, entry_name: String, columns: Array, required: bool) -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Resource"
	sheet.custom_class_name = class_name_for(resource_name, entry_name)
	sheet.class_description = "A data asset holding %ss. Fill the grid in the Inspector and save as a .tres - one asset per variant, shared by every scene that loads it." % entry_name.to_lower()
	var grid_name: String = grid_name_for(entry_name)
	sheet.variables = {
		grid_name: EventSheets.resource_grid(columns, {
			"tooltip": "One %s per row." % entry_name.to_lower(),
			"required": required,
		})
	}
	var about: CommentRow = CommentRow.new()
	about.text = "[b]%s[/b] - a data asset. The [b]%s[/b] grid is the whole Inspector: designers fill rows and save .tres variants (FileSystem dock > right-click > New Resource > %s once this compiles). Resources have no _ready or _process - add [b]functions[/b] for logic (roll a row, find by name) and call them from the sheets that load the asset." % [sheet.custom_class_name, grid_name, sheet.custom_class_name]
	sheet.events.append(about)
	return sheet


## "Loot Drop" -> "loot_drops" (the grid variable). Naive plural: append s unless it ends in s.
static func grid_name_for(entry_name: String) -> String:
	var snake: String = entry_name.strip_edges().to_snake_case().replace(" ", "_")
	while snake.contains("__"):
		snake = snake.replace("__", "_")
	if snake.is_empty():
		return ""
	return snake if snake.ends_with("s") else snake + "s"


## The class_name: the explicit Resource-name field wins; else derived from the entry name
## ("Loot Drop" -> "LootDropTable"). Always a valid PascalCase identifier.
static func class_name_for(resource_name: String, entry_name: String) -> String:
	var chosen: String = resource_name.strip_edges()
	if chosen.is_empty():
		chosen = entry_name.strip_edges() + " Table"
	var pascal: String = ""
	for word: String in chosen.replace("_", " ").split(" ", false):
		pascal += word.substr(0, 1).to_upper() + word.substr(1)
	var identifier: RegEx = RegEx.new()
	identifier.compile("[^A-Za-z0-9_]")
	pascal = identifier.sub(pascal, "", true)
	if pascal.is_empty() or pascal.substr(0, 1).is_valid_int():
		pascal = "My" + pascal
	return pascal
