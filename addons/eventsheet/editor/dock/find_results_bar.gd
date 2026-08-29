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
# Where a cross-sheet jump is trying to land. Held across the open because opening a `.gd` finishes
# asynchronously, and cleared as soon as it lands or the bar is refilled.
var _pending_line: int = 0
var _pending_path: String = ""
var _landing_hook_registered: bool = false


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
	return EventSheetFindReferences.find_in_project_rows(symbol, EventSheetFindReferences.open_sheets_of(_dock))


## "7 in 2 sheets" - what the bar's heading says after the symbol.
static func summary_text(total: int, sheet_count: int) -> String:
	return "%d in %d %s" % [total, sheet_count, "sheet" if sheet_count == 1 else "sheets"]


func _summary(total: int) -> String:
	var sheet_count: int = 0
	for child: TreeItem in tree.get_root().get_children():
		sheet_count += 1
	return "%s · %s" % [_symbol, summary_text(total, sheet_count)]


func _fill(grouped: Array) -> int:
	_ensure_landing_hook()
	tree.clear()
	_leaves.clear()
	_cursor = -1
	_pending_line = 0
	_pending_path = ""
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
			# `line` rides along beside `row`: the row resource works while the sheet is the one on
			# screen, and the line is what survives a jump into another sheet (see _jump_to).
			leaf.set_metadata(0, {"sheet": sheet_path, "row": row_resource, "line": int(reference.get("line", 0))})
			_leaves.append(leaf)
			total += int(reference.get("count", 0))
	_heading.text = "FIND RESULTS · %s" % _summary(total)
	return total


## Registers the once-per-session hook that finishes a cross-sheet landing. A `.gd` opens in two
## halves - the raw pass now, the lifted sheet when the worker finishes - and the tab is REPLACED in
## between, so a landing done only at click time is undone a moment later. One permanent listener
## rather than a per-jump one, because the lifecycle hooks have no unregister and a listener per
## click would pile up for the life of the editor.
func _ensure_landing_hook() -> void:
	if _landing_hook_registered:
		return
	_landing_hook_registered = true
	EventSheets.on_sheet_opened(func(_payload: Dictionary) -> void:
		_land_pending())


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
	var line: int = int((metadata as Dictionary).get("line", 0))
	if jump_to_line(sheet_path, line):
		return
	if row_resource is Resource and _dock._active_view() != null:
		_dock._active_view().reveal_resource(row_resource as Resource)


## "Take me to that row, in that file" - the ONE cross-sheet landing in the editor. The find results
## and the Manual's project-wide usage list both ask for it here, because the tricky half is not the
## jump but the WAIT: opening a `.gd` finishes on a worker thread, so the landing is remembered
## before the open and re-tried when the lifted sheet swaps in.
##
## False when there is nothing to land on (no path and no line), which is what lets a caller holding
## a row resource fall back to revealing it directly.
func jump_to_line(sheet_path: String, line: int) -> bool:
	if not sheet_path.is_empty() and sheet_path != _dock._current_sheet_path \
			and sheet_path != _current_source_path():
		_dock._navigate.record_current()
		# Remembered BEFORE the open, because opening a `.gd` finishes on a worker thread: the raw
		# pass lands the sheet now and the lifted one replaces it a moment later, and the landing has
		# to survive that swap. `on_sheet_opened` fires for both.
		_pending_line = line
		_pending_path = sheet_path
		_dock._navigate.open_or_focus(sheet_path)
		_land_pending()
		return true
	if line > 0:
		# The row on screen, by the line it emits at - the same door Ctrl+G and the code panel use.
		_dock.goto_generated_line(line)
		return true
	return false


## Lands on the remembered line, if the sheet it belongs to is the one now on screen. Called once
## straight after the open (which is enough for a `.tres` and for a `.gd`'s raw pass) and again from
## the sheet-opened hook when the lift swaps in the finished sheet.
func _land_pending() -> void:
	if _pending_line <= 0 or _pending_path.is_empty():
		return
	if _dock._current_sheet_path != _pending_path and _current_source_path() != _pending_path:
		return
	_dock.goto_generated_line(_pending_line)


## The file behind the sheet on screen. A `.gd` opened as a sheet has no `_current_sheet_path` - the
## file it came from is on the sheet itself - so both are asked before giving up on a landing.
func _current_source_path() -> String:
	return _dock._current_sheet.external_source_path if _dock._current_sheet != null else ""


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
