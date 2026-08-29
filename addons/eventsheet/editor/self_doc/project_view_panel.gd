# Godot EventSheets - the Project View window: every sheet on one page, the search that reaches them
# all, and the manual the selected sheet writes about itself.
#
# The window is a VIEW and nothing else. Every number it shows was computed by the model beside it,
# out of data that already existed; the window's whole job is to lay that out, and its whole rule is
# that opening it costs one join. Nothing here scans res://, nothing here runs the Doctor, and
# nothing here recomputes anything per frame - the rows are built once when the window opens or the
# refresh button is pressed, and then they are just rows in a Tree.
#
# THE MANUAL TAB regenerates its page every time a sheet is selected, which is the point: a page that
# was stored could be wrong, and a page composed on selection cannot be. Exporting writes those same
# bytes to a file the reader chooses, so a team can commit them and read the diff.
@tool
class_name EventSheetProjectViewPanel
extends RefCounted

## The columns of the roll-up, in the order a reader scans them: what it is, how big, how much of it
## is described, and then only the numbers that exist for it. Each is a catalog key, translated where
## the header is set - the translation sweep reads literals out of a call and cannot see a table, so
## these six words are carried in the catalogs deliberately rather than by being swept up.
const COLUMN_TITLES: PackedStringArray = ["Sheet", "Runs as", "Events", "Described", "Findings", "Milliseconds"]

var _dock: Control = null
var _window: Window = null
var _tree: Tree = null
var _find_edit: LineEdit = null
var _facet_button: OptionButton = null
var _results: Tree = null
var _manual_view: TextEdit = null
var _tasks: Tree = null
var _rows: Array[Dictionary] = []
var _sheets: Dictionary = {}


func _init(dock: Control) -> void:
	_dock = dock


## Opens the window, joining the sheets handed in once. `findings` and `timings` are whatever the
## caller already has - an empty findings array simply means nobody has run the Doctor this session,
## and the Findings column stays at zero rather than the window starting a run to fill it.
func open(sheets: Dictionary, findings: Array = [], timings: Dictionary = {}) -> void:
	_sheets = sheets
	_rows = EventSheetProjectViewModel.rows(sheets, findings, timings)
	_ensure_window()
	_fill_rows()
	_fill_tasks()
	_window.popup_centered()


## Builds the window on first open and reuses it after, so reopening costs nothing but the join.
func _ensure_window() -> void:
	if _window != null:
		return
	_window = Window.new()
	_window.title = EventSheetL10n.translate("Project View")
	_window.size = Vector2i(800, 600)
	_window.close_requested.connect(func() -> void: _window.hide())
	var box: VBoxContainer = VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", EventSheetPopupUI.ROW_SEPARATION)

	_tree = Tree.new()
	_tree.hide_root = true
	_tree.columns = COLUMN_TITLES.size()
	for index: int in range(COLUMN_TITLES.size()):
		_tree.set_column_title(index, EventSheetL10n.translate(COLUMN_TITLES[index]))
	_tree.column_titles_visible = true
	_tree.custom_minimum_size = Vector2(0.0, 120.0)
	_tree.item_selected.connect(_on_sheet_selected)
	var sheets_card: PanelContainer = EventSheetPopupUI.titled_card(EventSheetL10n.translate("Every sheet"), _tree)
	sheets_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(sheets_card)

	var find_row: HBoxContainer = HBoxContainer.new()
	find_row.add_theme_constant_override("separation", EventSheetPopupUI.ROW_SEPARATION)
	_find_edit = LineEdit.new()
	_find_edit.placeholder_text = EventSheetL10n.translate("A name, a node, an animation, a mode…")
	_find_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_find_edit.text_submitted.connect(func(_text: String) -> void: _run_find())
	find_row.add_child(_find_edit)
	_facet_button = OptionButton.new()
	for facet: String in EventSheetProjectViewModel.FACETS:
		_facet_button.add_item(facet)
	_facet_button.item_selected.connect(func(_index: int) -> void: _run_find())
	find_row.add_child(_facet_button)
	var find_button: Button = Button.new()
	find_button.text = EventSheetL10n.translate("Find")
	find_button.pressed.connect(_run_find)
	find_row.add_child(find_button)
	box.add_child(EventSheetPopupUI.titled_card(EventSheetL10n.translate("Find across every sheet"), find_row))
	box.add_child(EventSheetPopupUI.hint_label(
		EventSheetL10n.translate("A name is not one thing: written, read and compared are different facts about it, and the facet says which one you are hunting."), 720.0))

	_results = Tree.new()
	_results.hide_root = true
	_results.columns = 3
	_results.set_column_title(0, EventSheetL10n.translate("Sheet"))
	_results.set_column_title(1, EventSheetL10n.translate("Where"))
	_results.set_column_title(2, EventSheetL10n.translate("Match"))
	_results.column_titles_visible = true
	_results.custom_minimum_size = Vector2(0.0, 90.0)
	_results.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var results_card: PanelContainer = EventSheetPopupUI.titled_card(EventSheetL10n.translate("Hits"), _results)
	results_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(results_card)

	# THE TO-DO LIST, and the only place a private `#` note is ever read. A note opening TODO or
	# FIXME is a thing to do rather than a thing to publish, so it is listed here once and never
	# reaches the manual, the search or an export.
	_tasks = Tree.new()
	_tasks.hide_root = true
	_tasks.columns = 3
	_tasks.set_column_title(0, EventSheetL10n.translate("Sheet"))
	_tasks.set_column_title(1, EventSheetL10n.translate("Where"))
	_tasks.set_column_title(2, EventSheetL10n.translate("Note"))
	_tasks.column_titles_visible = true
	_tasks.custom_minimum_size = Vector2(0.0, 80.0)
	box.add_child(EventSheetPopupUI.titled_card(EventSheetL10n.translate("Still to do"), _tasks))

	_manual_view = TextEdit.new()
	_manual_view.editable = false
	_manual_view.custom_minimum_size = Vector2(0.0, 130.0)
	_manual_view.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	var manual_card: PanelContainer = EventSheetPopupUI.titled_card(EventSheetL10n.translate("Your Game: the selected sheet's own page"), _manual_view)
	manual_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(manual_card)
	box.add_child(EventSheetPopupUI.hint_label(
		EventSheetL10n.translate("This page is composed from the sheet every time you select it, so it cannot be out of date. Select a sheet above to read it."), 720.0))

	var margined: MarginContainer = EventSheetPopupUI.margined(box)
	margined.set_anchors_preset(Control.PRESET_FULL_RECT)
	_window.add_child(margined)
	_dock.add_child(_window)


## Fills the roll-up. One pass over rows the model already built - the window computes nothing here.
func _fill_rows() -> void:
	_tree.clear()
	var root: TreeItem = _tree.create_item()
	for row: Dictionary in _rows:
		var item: TreeItem = _tree.create_item(root)
		item.set_text(0, str(row.get("path", "")).get_file())
		item.set_tooltip_text(0, str(row.get("path", "")))
		item.set_text(1, str(row.get("scene", "")))
		item.set_text(2, str(int(row.get("events", 0))))
		item.set_text(3, "%d of %d" % [int(row.get("described", 0)), int(row.get("describable", 0))])
		item.set_text(4, str(int(row.get("findings", 0))))
		# A sheet nobody profiled leaves the cell EMPTY rather than showing a zero, because zero
		# milliseconds is a claim about the sheet and nobody measured it.
		item.set_text(5, "" if row.get("milliseconds") == null else "%.1f" % float(row.get("milliseconds")))


## Fills the to-do strip from the notes the sheets already carry. No scan and no store: the chips are
## read out of the same rows the canvas draws, and a note that was deleted has no chip on the next
## open because there was never a copy of it anywhere.
func _fill_tasks() -> void:
	_tasks.clear()
	var root: TreeItem = _tasks.create_item()
	for chip: Dictionary in EventSheetProjectViewModel.tasks(_sheets):
		var item: TreeItem = _tasks.create_item(root)
		item.set_text(0, str(chip.get("path", "")).get_file())
		item.set_tooltip_text(0, str(chip.get("path", "")))
		item.set_text(1, str(chip.get("where", "")))
		item.set_text(2, str(chip.get("text", "")))


## Composes the selected sheet's page fresh. Selecting is the regeneration: there is no stored page
## anywhere for a rename or a new function to leave behind.
func _on_sheet_selected() -> void:
	var selected: TreeItem = _tree.get_selected()
	if selected == null:
		return
	var path: String = selected.get_tooltip_text(0)
	var sheet: Variant = _sheets.get(path)
	_manual_view.text = EventSheetProjectManual.page_for(sheet as EventSheetResource) if sheet is EventSheetResource else ""


## Runs the project-wide find for what is typed, under the facet that is chosen.
func _run_find() -> void:
	_results.clear()
	var root: TreeItem = _results.create_item()
	var facet: String = _facet_button.get_item_text(_facet_button.selected) if _facet_button.selected >= 0 \
		else EventSheetProjectViewModel.FACET_ANY
	for hit: Dictionary in EventSheetProjectViewModel.find(_sheets, _find_edit.text, facet):
		var item: TreeItem = _results.create_item(root)
		item.set_text(0, str(hit.get("path", "")).get_file())
		item.set_tooltip_text(0, str(hit.get("path", "")))
		item.set_text(1, str(hit.get("where", "")))
		item.set_text(2, "%s - %s" % [str(hit.get("name", "")), str(hit.get("text", ""))])
