@tool
class_name EventSheetFindReferencesPanel
extends RefCounted
# The "Find References" window: whole-symbol uses of a variable / function / signal across EVERY sheet,
# grouped under the sheet they sit in, with Go to Row. Symbol-aware (so `speed` never matches
# `move_speed`), unlike substring Find. Extracted from event_sheet_dock.gd to keep that file
# maintainable; this owns its own window / edit / results-tree widgets and reaches dock state (the
# active view + load-sheet) through the `_dock` back-reference, the same pattern as the other dock/
# helpers.

var _dock: Control = null
var _find_refs_window: ConfirmationDialog = null
var _find_refs_edit: LineEdit = null
var _find_refs_tree: Tree = null
var _find_refs_count: Label = null
var _find_refs_strip: EventSheetPopupUI.HelpStrip = null
var _find_refs_this_row: Label = null


func init(dock: Control) -> void:
	_dock = dock


## Find References: whole-symbol uses of a variable/function/signal across EVERY sheet, with
## Go to Row - symbol-aware (so `speed` never matches `move_speed`), unlike substring Find.
func open() -> void:
	if _find_refs_window == null:
		_build()
	var seed: String = _selected_symbol_text()
	if not seed.is_empty():
		_find_refs_edit.text = seed
	_find_refs_window.popup_centered()
	_find_refs_edit.grab_focus()
	if not _find_refs_edit.text.strip_edges().is_empty():
		_run_find_references()


func _build() -> void:
	var parts: Dictionary = EventSheetPopupUI.action_window(EventSheetL10n.translate("Find References"),
		EventSheetL10n.translate("Go to Row"), EventSheetL10n.translate("Close"), Vector2i(600, 460), _dock)
	_find_refs_window = parts["window"]
	_find_refs_window.confirmed.connect(_on_find_reference_activated)
	var box: VBoxContainer = parts["box"]
	var row: HBoxContainer = HBoxContainer.new()
	_find_refs_edit = LineEdit.new()
	_find_refs_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_find_refs_edit.text_submitted.connect(func(_t: String) -> void: _run_find_references())
	row.add_child(_find_refs_edit)
	var find_button: Button = Button.new()
	find_button.text = EventSheetL10n.translate("Find References")
	find_button.pressed.connect(_run_find_references)
	row.add_child(find_button)
	var card: PanelContainer = EventSheetPopupUI.titled_card(EventSheetL10n.translate("Find symbol"),
		EventSheetPopupUI.form_row(EventSheetL10n.translate("Symbol"), row))
	# What "whole symbol" means is a question for the title, not a line the window always shows.
	card.tooltip_text = EventSheetL10n.translate("Whole symbol, so move_speed never matches max_move_speed.")
	box.add_child(card)
	_find_refs_tree = Tree.new()
	_find_refs_tree.hide_root = true
	_find_refs_tree.columns = 2
	_find_refs_tree.set_column_title(0, EventSheetL10n.translate("Where"))
	_find_refs_tree.set_column_title(1, EventSheetL10n.translate("Match"))
	_find_refs_tree.set_column_expand(0, false)
	_find_refs_tree.set_column_custom_minimum_width(0, roundi(EventSheetPalette.scaled_f(170.0)))
	_find_refs_tree.column_titles_visible = true
	_find_refs_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_find_refs_tree.custom_minimum_size.y = EventSheetPalette.scaled_f(170.0)
	_find_refs_tree.item_selected.connect(_on_find_reference_selected)
	_find_refs_tree.item_activated.connect(_on_find_reference_activated)
	var results: VBoxContainer = EventSheetPopupUI.form_box()
	results.size_flags_vertical = Control.SIZE_EXPAND_FILL
	results.add_child(_find_refs_tree)
	_find_refs_count = EventSheetPopupUI.hint_label("")
	results.add_child(_find_refs_count)
	var results_card: PanelContainer = EventSheetPopupUI.titled_card(EventSheetL10n.translate("Results"), results)
	results_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(results_card)
	_find_refs_strip = EventSheetPopupUI.help_strip()
	_find_refs_this_row = _find_refs_strip.add_line(EventSheetL10n.translate("THIS ROW"), true)
	_find_refs_strip.visible = false
	box.add_child(_find_refs_strip)


## Populates the references tree: one item per sheet, its uses under it. Returns the total count (so
## it's headlessly testable).
func _run_find_references() -> int:
	_find_refs_tree.clear()
	_find_refs_strip.visible = false
	_find_refs_window.get_ok_button().disabled = true
	var root: TreeItem = _find_refs_tree.create_item()
	var symbol: String = _find_refs_edit.text.strip_edges()
	_find_refs_window.title = EventSheetL10n.translate("Find every use of %s") % symbol if not symbol.is_empty() \
		else EventSheetL10n.translate("Find References")
	_find_refs_count.text = ""
	if symbol.is_empty():
		return 0
	var total: int = 0
	var sheets: Array = EventSheetFindReferences.find_in_project(symbol, EventSheetFindReferences.open_sheets_of(_dock))
	for entry: Dictionary in sheets:
		var sheet_path: String = str(entry.get("sheet", ""))
		var sheet_item: TreeItem = _find_refs_tree.create_item(root)
		sheet_item.set_text(0, sheet_path.get_file())
		sheet_item.set_text(1, EventSheetL10n.translate("%d reference(s)") % int(entry.get("count", 0)))
		sheet_item.set_metadata(0, sheet_path)
		for reference: Dictionary in (entry.get("references", []) as Array):
			var item: TreeItem = _find_refs_tree.create_item(sheet_item)
			item.set_text(0, "%s ×%d" % [str(reference.get("kind", "")), int(reference.get("count", 0))])
			item.set_text(1, str(reference.get("preview", "")))
			item.set_metadata(0, sheet_path)
			# The ROW the hit sits on, so Go to Row lands on it rather than on the top of the file -
			# the same metadata the Find results bar carries.
			item.set_metadata(1, reference.get("row", null))
			# The line the row emits at survives the open (a freshly opened sheet is a new resource
			# tree, so the row above only matches when the sheet was already open).
			item.set_metadata(2, int(reference.get("line", 0)))
			total += int(reference.get("count", 0))
	_find_refs_count.text = EventSheetL10n.translate("%d reference(s) in %d sheet(s)") % [total, sheets.size()] \
		if total > 0 else EventSheetL10n.translate("No whole-symbol matches.")
	return total


## The strip names the selected use - how many, which surface, which sheet - and Go to Row wakes up.
func _on_find_reference_selected() -> void:
	var item: TreeItem = _find_refs_tree.get_selected()
	_find_refs_window.get_ok_button().disabled = item == null
	if item == null or item.get_parent() == _find_refs_tree.get_root():
		_find_refs_strip.visible = false
		return
	_find_refs_strip.set_line(_find_refs_this_row, EventSheetL10n.translate("%s, in %s.") % [
		item.get_text(0), str(item.get_metadata(0)).get_file()])
	_find_refs_strip.set_reading("", item.get_text(1))
	_find_refs_strip.visible = true


func _on_find_reference_activated() -> void:
	var item: TreeItem = _find_refs_tree.get_selected()
	if item == null:
		return
	var path: String = str(item.get_metadata(0)) if item.get_metadata(0) != null else ""
	if path.is_empty():
		return
	_find_refs_window.hide()
	# The same landing the Find results bar uses: open (or focus) the sheet, then select the row the
	# hit sits on - by its line, which survives the open, or by the row itself when no line is known.
	var line: int = int(item.get_metadata(2)) if item.get_metadata(2) != null else 0
	if _dock._find_results.jump_to_line(path, line):
		return
	var row: Variant = item.get_metadata(1)
	if row is Resource and _dock._active_view() != null:
		_dock._active_view().reveal_resource(row as Resource)


## Seeds the search box from a selected local-variable or signal row (a quick "find this").
func _selected_symbol_text() -> String:
	var resource: Variant = _dock._active_view().get_selected_context().get("source_resource", null)
	if resource is LocalVariable:
		return (resource as LocalVariable).name
	if resource is SignalRow:
		return (resource as SignalRow).signal_name
	return ""
