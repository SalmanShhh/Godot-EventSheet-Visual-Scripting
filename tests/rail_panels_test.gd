@tool
class_name RailPanelsTest
extends RefCounted
# The left rail (dock/rail_panels.gd) and the Properties bar's empty state (dock/properties_bar.gd).
#
# Pins the model first, because it is what decides what a reader sees before anything is dragged:
# the panel order, which panels rest open and which are folds, which panels are on offer at all for
# a given sheet, and the stored-state round trip. Then pins the BUILT rail: the VSplit chain in
# panel order, every panel's minimum size handed to the rail, grabbers drawn rather than revealed on
# hover, a tucked panel gone from the column and named by a tab at the foot, and the whole rail
# tucked into its edge strip. Finally the two Open Sheets readings the rail leans on - duplicate
# tabs of one file grouped under one line with a count, and which tab a click on that line goes to -
# and the Properties bar being its splitter handle until something is selected.


const SUPPORT := preload("res://tests/support.gd")


class NoopUndoManager:
	extends RefCounted
	func create_action(_a = null) -> void: pass
	func add_do_method(_a = null, _b = null, _c = null, _d = null, _e = null) -> void: pass
	func add_undo_method(_a = null, _b = null, _c = null, _d = null, _e = null) -> void: pass
	func commit_action() -> void: pass
	func has_undo() -> bool: return false
	func has_redo() -> bool: return false
	func undo() -> void: pass
	func redo() -> void: pass
	func clear_history() -> void: pass


static func run() -> bool:
	var ok: bool = true
	ok = _model() and ok
	ok = _open_sheets_grouping() and ok
	ok = _built_rail() and ok
	return ok


## The rail's state model: order, defaults, the census rule, and reading a stored record back.
static func _model() -> bool:
	var ok: bool = true
	ok = _check("the rail's panel order",
		Array(EventSheetRailPanels.panel_ids()),
		["open_sheets", "objects", "functions", "anatomy", "picker_preview"]) and ok

	var defaults: Dictionary = EventSheetRailPanels.default_state()
	var folded_by_default: Array = []
	for panel_id: String in EventSheetRailPanels.panel_ids():
		if bool((defaults["panels"][panel_id] as Dictionary).get("folded")):
			folded_by_default.append(panel_id)
	ok = _check("the rail rests on Open Sheets and Objects; the rest are folds",
		folded_by_default, ["functions", "anatomy", "picker_preview"]) and ok
	ok = _check("nothing starts tucked away",
		Array(EventSheetRailPanels.tucked_panel_ids(defaults)), []) and ok
	ok = _check("the rail and the Properties bar start on screen",
		[defaults["rail_tucked"], defaults["properties_tucked"]], [false, false]) and ok

	# The census: a panel nothing can fill is not on offer at all.
	ok = _check("a plain sheet with the picker closed offers three panels",
		Array(EventSheetRailPanels.shown_panel_ids({"behaviour_pack": false, "picker_open": false})),
		["open_sheets", "objects", "functions"]) and ok
	ok = _check("a behaviour pack also offers Anatomy",
		Array(EventSheetRailPanels.shown_panel_ids({"behaviour_pack": true, "picker_open": false})),
		["open_sheets", "objects", "functions", "anatomy"]) and ok
	ok = _check("the Picker preview is on offer while the picker is open",
		Array(EventSheetRailPanels.shown_panel_ids({"behaviour_pack": false, "picker_open": true})),
		["open_sheets", "objects", "functions", "picker_preview"]) and ok

	# The stored record: written, read back, the same rail.
	var stored: Dictionary = EventSheetRailPanels.default_state()
	(stored["panels"]["objects"] as Dictionary)["tucked"] = true
	(stored["panels"]["objects"] as Dictionary)["height"] = 233.0
	(stored["panels"]["functions"] as Dictionary)["folded"] = false
	stored["rail_tucked"] = true
	stored["rail_width"] = 174.0
	stored["properties_tucked"] = true
	stored["properties_width"] = 312.0
	var read_back: Dictionary = EventSheetRailPanels.normalize_state(stored)
	ok = _check("a stored rail reads back exactly as it was written", read_back, stored) and ok
	ok = _check("the tucked panels are listed in rail order",
		Array(EventSheetRailPanels.tucked_panel_ids(read_back)), ["objects"]) and ok

	# A record from before a panel existed, or a record that is not a record at all, reads as the
	# defaults for what it does not carry - never as a missing panel.
	var partial: Dictionary = EventSheetRailPanels.normalize_state({
		"rail_width": 120.0, "panels": {"objects": {"tucked": true}}})
	ok = _check("a half-written record keeps every panel",
		Array((partial["panels"] as Dictionary).keys()),
		Array(EventSheetRailPanels.panel_ids())) and ok
	ok = _check("a half-written record keeps the defaults it does not carry",
		[partial["rail_width"], partial["rail_tucked"],
			(partial["panels"]["functions"] as Dictionary)["folded"],
			(partial["panels"]["objects"] as Dictionary)["tucked"]],
		[120.0, false, true, true]) and ok
	ok = _check("a record that is not a dictionary reads as the defaults",
		EventSheetRailPanels.normalize_state("nonsense"), EventSheetRailPanels.default_state()) and ok
	return ok


## Open Sheets: eight tabs on one file are one line with a count, and a click walks them.
static func _open_sheets_grouping() -> bool:
	var ok: bool = true
	var open: Array = []
	for i: int in 8:
		open.append({"title": "Flash", "path": "res://eventsheet_addons/flash/flash_behavior.gd", "dirty": false})
	open.append({"title": "InputRebindDemo", "path": "res://demo/input_rebind.gd", "dirty": true})
	open.append({"title": "Untitled", "path": "", "dirty": true})
	open.append({"title": "Untitled", "path": "", "dirty": false})

	var grouped: Array = EventSheetOpenSheetsDock.group_entries(open)
	var labels: Array = []
	for entry: Dictionary in grouped:
		labels.append(EventSheetOpenSheetsDock.list_label(entry))
	ok = _check("duplicates of one file are one line with a count; unsaved sheets never group",
		labels, ["Flash ×8", "InputRebindDemo", "Untitled", "Untitled"]) and ok
	ok = _check("the grouped line carries every tab it stands for",
		(grouped[0] as Dictionary).get("indices"), [0, 1, 2, 3, 4, 5, 6, 7]) and ok
	ok = _check("a dirty tab anywhere in the group marks the line",
		(grouped[1] as Dictionary).get("dirty"), true) and ok
	ok = _check("the hover says how many tabs are on the file",
		EventSheetOpenSheetsDock.hover_text(grouped[0]).ends_with(
			"8 tabs are open on this file - clicking walks them."), true) and ok

	var indices: Array = (grouped[0] as Dictionary).get("indices")
	ok = _check("clicking a group with the active tab elsewhere goes to its first tab",
		EventSheetOpenSheetsDock.next_index(indices, 9), 0) and ok
	ok = _check("clicking it again walks to the next tab of that file",
		EventSheetOpenSheetsDock.next_index(indices, 3), 4) and ok
	ok = _check("the walk wraps round at the end",
		EventSheetOpenSheetsDock.next_index(indices, 7), 0) and ok

	# The rendered list says the same thing.
	var panel: EventSheetOpenSheetsDock = EventSheetOpenSheetsDock.new()
	panel.set_state(open, 0, [])
	var rendered: Array = []
	for row: int in panel._list.item_count:
		rendered.append(panel._list.get_item_text(row))
	ok = _check("the panel renders one row per file", rendered,
		["Flash ×8", "InputRebindDemo", "Untitled", "Untitled"]) and ok
	panel.free()
	return ok


## The built rail: the chain, the minimum sizes, the drawn grabbers, a tucked panel, a tucked rail,
## and the Properties bar waiting as its handle.
static func _built_rail() -> bool:
	var ok: bool = true
	var dock: EventSheetEditor = EventSheetEditor.new()
	dock.set_undo_redo_manager(NoopUndoManager.new())
	dock.setup(EventSheetResource.new())

	var rail: Control = dock._workspace_body.get_child(0) as Control
	ok = _check("the rail is the workspace split's left side", rail.name, "EventSheetLeftRail") and ok
	var body: Control = rail.get_child(0) as Control
	var chain: Control = body.get_child(1) as Control
	ok = _check("the panels stack in rail order", _chain_names(chain),
		["Open Sheets", "Objects", "Functions", "Anatomy", "PickerPreview"]) and ok

	var minimums: Array = []
	for panel: Control in [dock._open_sheets_panel, dock._objects_panel, dock._functions_panel,
			dock._anatomy_panel, dock._picker_preview_panel]:
		minimums.append(panel.custom_minimum_size)
	ok = _check("no panel brings a minimum size of its own to the rail", minimums,
		[Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]) and ok

	var autohidden: Array = []
	for split: SplitContainer in _chain_splits(chain):
		autohidden.append([split.dragger_visibility, split.get_theme_constant("autohide")])
	ok = _check("every grabber in the chain is drawn, not revealed on hover", autohidden,
		[[SplitContainer.DRAGGER_VISIBLE, 0], [SplitContainer.DRAGGER_VISIBLE, 0],
			[SplitContainer.DRAGGER_VISIBLE, 0], [SplitContainer.DRAGGER_VISIBLE, 0]]) and ok
	ok = _check("so is the rail-to-canvas grabber",
		[dock._workspace_body.dragger_visibility, dock._workspace_body.get_theme_constant("autohide")],
		[SplitContainer.DRAGGER_VISIBLE, 0]) and ok

	# A plain sheet is not a behaviour pack and the picker is closed: two of the five stand down.
	ok = _check("a plain sheet shows the three panels it can fill",
		[dock._open_sheets_panel.visible, dock._objects_panel.visible, dock._functions_panel.visible,
			dock._anatomy_panel.visible, dock._picker_preview_panel.visible],
		[true, true, true, false, false]) and ok

	# Minimising a panel: gone from the column, named by a tab at the foot, back at a click.
	dock._rail_panels.set_panel_tucked("objects", true)
	ok = _check("a tucked panel takes no room at all",
		[dock._objects_panel.visible, dock._rail_panels.is_panel_tucked("objects")],
		[false, true]) and ok
	ok = _check("its name waits in a tab at the foot of the rail", _tab_labels(body), ["› Objects"]) and ok
	dock._rail_panels.set_panel_tucked("objects", false)
	ok = _check("clicking the tab brings it back",
		[dock._objects_panel.visible, _tab_labels(body)], [true, []]) and ok

	# A divider dragged up past a panel's own header is the same gesture as its minimise button.
	dock._rail_panels._on_split_dragged("functions", 2)
	ok = _check("a divider dragged past a header slides that panel off",
		dock._rail_panels.is_panel_tucked("functions"), true) and ok
	dock._rail_panels.set_panel_tucked("functions", false)

	# The rail itself: an edge strip with a chevron, and the sheet takes the width.
	dock._rail_panels.set_rail_tucked(true)
	var edge: Control = rail.get_child(1) as Control
	ok = _check("the tucked rail is one narrow edge strip",
		[body.visible, edge.visible, rail.custom_minimum_size.x],
		[false, true, EventSheetPalette.scaled_f(EventSheetRailPanels.EDGE_STRIP_WIDTH)]) and ok
	ok = _check("the strip says what is behind it",
		(edge.get_child(1) as Label).text, "OPEN SHEETS · OBJECTS · FUNCTIONS") and ok
	dock._rail_panels.set_rail_tucked(false)
	ok = _check("restoring the rail brings the column back",
		[body.visible, edge.visible, rail.custom_minimum_size.x], [true, false, 0.0]) and ok

	# The Properties bar is its splitter handle until something is selected.
	var bar: EventSheetPropertiesBar = dock._properties_bar
	ok = _check("nothing selected: the bar hands its width back to the canvas",
		[bar.panel.custom_minimum_size.x, bar._body.visible], [0.0, false]) and ok
	var group: EventGroup = EventGroup.new()
	group.group_name = "Walls"
	bar._show_group(group)
	ok = _check("the first selection opens the bar with the row's fields",
		[bar.panel.custom_minimum_size.x > 0.0, bar._body.visible, bar._heading.text],
		[true, true, "PROPERTIES · Walls · group"]) and ok
	bar._show_nothing()
	ok = _check("deselecting closes it again to the handle",
		[bar.panel.custom_minimum_size.x, bar._body.visible], [0.0, false]) and ok

	dock.free()
	return ok


## The panel names down the VSplit chain, in the order a reader meets them.
static func _chain_names(chain: Control) -> Array:
	var names: Array = []
	var node: Control = chain
	while node is SplitContainer:
		names.append(str((node.get_child(0) as Control).name))
		node = node.get_child(1) as Control
	names.append(str(node.name))
	return names


static func _chain_splits(chain: Control) -> Array:
	var splits: Array = []
	var node: Control = chain
	while node is SplitContainer:
		splits.append(node)
		node = node.get_child(1) as Control
	return splits


## What the foot tab strip reads, in order.
static func _tab_labels(body: Control) -> Array:
	var labels: Array = []
	for child: Node in (body.get_child(2) as Control).get_children():
		if child is Button:
			labels.append((child as Button).text)
	return labels


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("rail_panels_test", label, actual, expected)
