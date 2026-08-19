@tool
class_name EventSheetFindResultsBar
extends RefCounted
# The FIND RESULTS bar: every place a variable, function, object, signal or behavior is used,
# grouped by sheet with the event number of each hit, and it STAYS at the bottom of the sheet while
# you walk the list.
#
#   FIND RESULTS · hp · 7 in 2 sheets            F3 next · Shift+F3 previous · ✕
#   player.gd
#     event 1   Player: Set hp to 100
#     event 2   Player: Subtract damage from hp
#   hud.gd
#     event 5   HUD: Set text to "HP " & Player.hp
#
# Whole-symbol matching (the same walk Find References uses), so `hp` never matches `hp_max`.
# Clicking a result jumps to it, opening the sheet when it is not the one on screen; F3 and
# Shift+F3 step forward and back; the bar closes with ✕ and nothing else.
#
# Widgets are built lazily and mounted under the sheet in the dock's content host, so the bar
# shares the canvas's width and pushes nothing else around.

const RESULT_ROW_META := "find_result"

var _dock: Control = null
var bar: VBoxContainer = null
var tree: Tree = null
var _heading: Label = null
var _symbol: String = ""
# Flat leaf items in walk order, so F3 / Shift+F3 step the list rather than the tree's own
# selection rules (which would stop at a sheet heading).
var _leaves: Array[TreeItem] = []
var _cursor: int = -1


func init(dock: Control) -> void:
	_dock = dock


## Is the bar on screen? F3 routes to the results while it is, and back to the find bar when not.
func is_open() -> bool:
	return bar != null and bar.visible


## Runs the search and shows the bar. Returns the number of hits (so it is headlessly testable).
func open(symbol: String) -> int:
	var clean: String = symbol.strip_edges()
	if clean.is_empty():
		_dock._set_status("Nothing identifiable to find references for on this row.", true)
		return 0
	_symbol = clean
	_ensure_bar()
	var total: int = _fill(results_for(clean))
	bar.visible = true
	_dock._set_status("Find results: %s." % _summary(total))
	return total


func close() -> void:
	if bar != null:
		bar.visible = false


## Every reference to `symbol` across the open tabs and the project's sheets, grouped by sheet.
func results_for(symbol: String) -> Array:
	var open_sheets: Dictionary = {}
	for tab: Variant in _dock._open_tabs:
		if not (tab is Dictionary):
			continue
		var path: String = str((tab as Dictionary).get("path", ""))
		var sheet: EventSheetResource = (tab as Dictionary).get("sheet") as EventSheetResource
		if not path.is_empty() and sheet != null:
			open_sheets[path] = sheet
	if _dock._current_sheet != null and not _dock._current_sheet_path.is_empty():
		open_sheets[_dock._current_sheet_path] = _dock._current_sheet
	return EventSheetFindReferences.find_in_project_rows(symbol, open_sheets)


## "7 in 2 sheets" - what the bar's heading says after the symbol.
static func summary_text(total: int, sheet_count: int) -> String:
	return "%d in %d %s" % [total, sheet_count, "sheet" if sheet_count == 1 else "sheets"]


func _summary(total: int) -> String:
	var sheet_count: int = 0
	for child: TreeItem in tree.get_root().get_children():
		sheet_count += 1
	return "%s · %s" % [_symbol, summary_text(total, sheet_count)]


func _fill(grouped: Array) -> int:
	tree.clear()
	_leaves.clear()
	_cursor = -1
	var root: TreeItem = tree.create_item()
	var total: int = 0
	for entry: Dictionary in grouped:
		var sheet_path: String = str(entry.get("sheet", ""))
		var sheet_item: TreeItem = tree.create_item(root)
		sheet_item.set_text(0, sheet_path.get_file())
		sheet_item.set_selectable(0, false)
		sheet_item.set_selectable(1, false)
		for reference: Dictionary in (entry.get("references", []) as Array):
			var leaf: TreeItem = tree.create_item(sheet_item)
			var row_resource: Variant = reference.get("row", null)
			leaf.set_text(0, _event_label(row_resource))
			leaf.set_text(1, str(reference.get("preview", "")))
			leaf.set_metadata(0, {"sheet": sheet_path, "row": row_resource})
			_leaves.append(leaf)
			total += int(reference.get("count", 0))
	_heading.text = "FIND RESULTS · %s" % _summary(total)
	return total


## "event 12" for a row the open sheet numbers, "" for anything the margin does not number.
func _event_label(row_resource: Variant) -> String:
	if not (row_resource is Resource):
		return ""
	var view: EventSheetViewport = _dock._active_view()
	if view == null:
		return ""
	for flat_entry: Dictionary in view.get_flat_rows():
		var row_data: EventRowData = flat_entry.get("row")
		if row_data != null and row_data.source_resource == row_resource and row_data.event_number > 0:
			return "event %d" % row_data.event_number
	return ""


## F3 / Shift+F3: `direction` +1 next, -1 previous. Wraps, so stepping never dead-ends.
func step(direction: int) -> void:
	if _leaves.is_empty():
		return
	_cursor = wrapi(_cursor + (1 if direction >= 0 else -1), 0, _leaves.size())
	var leaf: TreeItem = _leaves[_cursor]
	leaf.select(0)
	tree.ensure_cursor_is_visible()
	_jump_to(leaf)


func _on_activated() -> void:
	var selected: TreeItem = tree.get_selected()
	if selected != null:
		_cursor = _leaves.find(selected)
		_jump_to(selected)


func _jump_to(leaf: TreeItem) -> void:
	var metadata: Variant = leaf.get_metadata(0)
	if not (metadata is Dictionary):
		return
	var sheet_path: String = str((metadata as Dictionary).get("sheet", ""))
	var row_resource: Variant = (metadata as Dictionary).get("row", null)
	if not sheet_path.is_empty() and sheet_path != _dock._current_sheet_path:
		_dock._navigate.record_current()
		_dock._navigate.open_or_focus(sheet_path)
		return
	if row_resource is Resource and _dock._active_view() != null:
		_dock._active_view().reveal_resource(row_resource as Resource)


func _ensure_bar() -> void:
	if bar != null:
		return
	bar = VBoxContainer.new()
	bar.name = "EventSheetFindResultsBar"
	bar.custom_minimum_size = Vector2(0.0, EventSheetPalette.scaled_f(150.0))
	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	_heading = EventSheetPopupUI.small_caps_label("FIND RESULTS")
	_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_heading)
	header.add_child(EventSheetPopupUI.hint_label("F3 next · Shift+F3 previous", 220.0))
	var close_button: Button = Button.new()
	close_button.text = "✕"
	close_button.flat = true
	close_button.tooltip_text = "Close the find results"
	close_button.pressed.connect(close)
	header.add_child(close_button)
	bar.add_child(header)
	tree = Tree.new()
	tree.name = "EventSheetFindResultsTree"
	tree.hide_root = true
	tree.columns = 2
	tree.set_column_title(0, "Where")
	tree.set_column_title(1, "Match")
	tree.set_column_expand(0, false)
	tree.set_column_custom_minimum_width(0, int(EventSheetPalette.scaled_f(120.0)))
	tree.column_titles_visible = true
	tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tree.item_activated.connect(_on_activated)
	bar.add_child(tree)
	_dock._content_host.add_child(bar)
	bar.visible = false
