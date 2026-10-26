@tool
class_name RailPanelsTest
extends RefCounted
# The side panel (dock/rail_panels.gd) and the Properties bar's empty state (dock/properties_bar.gd).
#
# Pins the model first, because it is what decides what a reader sees before anything is clicked:
# the tab order, the resting state (closed, on Objects), which tabs are on offer for a given sheet,
# and the stored-state round trip - including a record written by the stacked column the panel
# replaced. Then pins the BUILT panel: a thin rail with one open button, opening to Godot-style tabs
# (Objects and Functions) with no Open Sheets list, the chosen tab shown alone, every panel's fold
# header standing down inside its tab, the strip not draggable while closed, and the View menu
# saying the same. Finally the Properties bar being its splitter handle until something is selected.


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
	ok = _built_panel() and ok
	return ok


## The panel's state model: order, defaults, the census rule, and reading a stored record back.
static func _model() -> bool:
	var ok: bool = true
	ok = _check("the side panel's tabs, in strip order",
		Array(EventSheetRailPanels.panel_ids()), ["objects", "functions", "anatomy", "picker_preview"]) and ok
	ok = _check("it rests closed, on the Objects tab, 230 px wide when opened",
		EventSheetRailPanels.default_state(),
		{"panel_open": false, "panel_tab": "objects", "rail_width": 230.0,
			"properties_tucked": false, "properties_width": 270.0}) and ok

	# The census: a tab nothing can fill is not on offer at all.
	ok = _check("a plain sheet with the picker closed offers Objects and Functions",
		Array(EventSheetRailPanels.shown_panel_ids({"behaviour_pack": false, "picker_open": false})),
		["objects", "functions"]) and ok
	ok = _check("a behaviour pack also offers Anatomy",
		Array(EventSheetRailPanels.shown_panel_ids({"behaviour_pack": true, "picker_open": false})),
		["objects", "functions", "anatomy"]) and ok
	ok = _check("the Picker preview is on offer while the picker is open",
		Array(EventSheetRailPanels.shown_panel_ids({"behaviour_pack": false, "picker_open": true})),
		["objects", "functions", "picker_preview"]) and ok
	ok = _check("a remembered tab that is not on offer shows Objects instead",
		[EventSheetRailPanels.shown_tab("anatomy", PackedStringArray(["objects", "functions"])),
			EventSheetRailPanels.shown_tab("functions", PackedStringArray(["objects", "functions"]))],
		["objects", "functions"]) and ok

	# The stored record: written, read back, the same panel.
	var stored: Dictionary = {"panel_open": true, "panel_tab": "functions", "rail_width": 174.0,
		"properties_tucked": true, "properties_width": 312.0}
	ok = _check("a stored panel reads back exactly as it was written",
		EventSheetRailPanels.normalize_state(stored), stored) and ok
	# The column of stacked panels the side panel replaced kept other keys. Its record reads as the
	# resting panel, keeping only the widths both shapes share.
	var old_column: Dictionary = EventSheetRailPanels.normalize_state({
		"rail_tucked": false, "rail_width": 200.0, "properties_width": 300.0,
		"panels": {"open_sheets": {"folded": false, "tucked": false, "height": 150.0}}})
	ok = _check("the stacked column's record reads as a closed panel on Objects", old_column,
		{"panel_open": false, "panel_tab": "objects", "rail_width": 200.0,
			"properties_tucked": false, "properties_width": 300.0}) and ok
	ok = _check("a tab that does not exist reads as Objects",
		EventSheetRailPanels.normalize_state({"panel_tab": "open_sheets"})["panel_tab"], "objects") and ok
	ok = _check("a record that is not a dictionary reads as the defaults",
		EventSheetRailPanels.normalize_state("nonsense"), EventSheetRailPanels.default_state()) and ok
	return ok


## The built panel: the rail, the tabs, the chosen tab alone, the stood-down fold headers, the View
## menu, and the Properties bar waiting as its handle.
static func _built_panel() -> bool:
	var ok: bool = true
	var dock: EventSheetEditor = EventSheetEditor.new()
	dock.set_undo_redo_manager(NoopUndoManager.new())
	dock.setup(EventSheetResource.new())
	var rail: EventSheetRailPanels = dock._rail_panels

	var root: Control = dock._workspace_body.get_child(0) as Control
	ok = _check("the side panel is the workspace split's left side", str(root.name), "EventSheetLeftRail") and ok
	var body: Control = root.get_node("EventSheetSidePanelBody") as Control
	var edge: Control = root.get_node("EventSheetLeftRailEdge") as Control
	var open_button: Button = edge.find_child("EventSheetSidePanelOpen", true, false) as Button

	# At rest: a thin rail with one button, and the strip is not a thing to drag wider.
	ok = _check("it rests as a 30 px rail with one open button",
		[body.visible, edge.visible, root.custom_minimum_size.x, edge.get_child(0).get_child_count(), open_button.text],
		[false, true, EventSheetPalette.scaled_f(30.0), 1, "›"]) and ok
	ok = _check("the button says what is behind it", open_button.tooltip_text,
		"Objects and functions of this sheet") and ok
	ok = _check("the closed rail does not drag",
		[dock._workspace_body.dragging_enabled, dock._workspace_body.dragger_visibility],
		[false, SplitContainer.DRAGGER_HIDDEN_COLLAPSED]) and ok

	# Opened: Godot-style tabs, Objects showing, and no Open Sheets list anywhere.
	open_button.pressed.emit()
	var tabs: TabBar = body.find_child("EventSheetSidePanelTabs", true, false) as TabBar
	ok = _check("the button opens the panel, draggable wider",
		[body.visible, edge.visible, root.custom_minimum_size.x, dock._workspace_body.dragging_enabled],
		[true, false, 0.0, true]) and ok
	ok = _check("it opens to two tabs, Objects and Functions", _tab_titles(tabs), ["Objects", "Functions"]) and ok
	ok = _check("the Objects tab shows, and only it",
		[tabs.current_tab, dock._objects_panel.visible, dock._functions_panel.visible],
		[0, true, false]) and ok
	ok = _check("there is no Open Sheets list: the tabs above the sheet are the open sheets",
		root.find_child("Open Sheets", true, false), null) and ok

	# Picking a tab shows it alone and is remembered.
	tabs.current_tab = 1
	ok = _check("picking Functions shows it alone",
		[rail.active_tab(), dock._objects_panel.visible, dock._functions_panel.visible],
		["functions", false, true]) and ok
	ok = _check("and the Functions tab is a filter, then the list",
		[str(dock._functions_panel.get_child(0).name), str(dock._functions_panel.get_child(1).name)],
		["EventSheetFunctionsFilterRow", "EventSheetFunctionsList"]) and ok

	# A behaviour pack offers Anatomy as a third tab, with its fold header standing down.
	rail.set_census(true, false)
	ok = _check("a behaviour pack adds the Anatomy tab", _tab_titles(tabs),
		["Objects", "Functions", "Anatomy"]) and ok
	ok = _check("a panel's fold header stands down inside its tab, its body open",
		[(dock._anatomy_panel.rail_header_row() as Control).visible, dock._anatomy_panel.is_expanded()],
		[false, true]) and ok
	rail.set_census(false, false)

	# The close button closes it; View > Panels and View > Side Rail say and do the same.
	var close_button: Button = body.find_child("EventSheetSidePanelClose", true, false) as Button
	close_button.pressed.emit()
	ok = _check("the close button rests it as the rail again", [body.visible, edge.visible], [false, true]) and ok
	var view_popup: PopupMenu = dock._view_popup
	var panels_menu: PopupMenu = view_popup.get_node("EventSheetPanelsMenu") as PopupMenu
	view_popup.about_to_popup.emit()
	ok = _check("View > Panels lists the tabs on offer, none ticked while closed",
		_menu_state(panels_menu), [["Objects", false], ["Functions", false]]) and ok
	panels_menu.id_pressed.emit(0)
	view_popup.about_to_popup.emit()
	ok = _check("choosing one opens the panel on it, ticked",
		[body.visible, rail.active_tab(), _menu_state(panels_menu)],
		[true, "objects", [["Objects", true], ["Functions", false]]]) and ok
	ok = _check("View > Side Rail is ticked while the panel is open",
		view_popup.is_item_checked(view_popup.get_item_index(EventSheetMenuBar.SIDE_RAIL_VIEW_ID)), true) and ok
	panels_menu.id_pressed.emit(0)
	ok = _check("choosing the ticked one closes the panel", body.visible, false) and ok
	ok = _check("View has no Open Sheets Panel entry", view_popup.get_item_index(13), -1) and ok

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


static func _tab_titles(tabs: TabBar) -> Array:
	var titles: Array = []
	for index: int in tabs.tab_count:
		titles.append(tabs.get_tab_title(index))
	return titles


static func _menu_state(menu: PopupMenu) -> Array:
	var rows: Array = []
	for index: int in menu.item_count:
		rows.append([menu.get_item_text(index), menu.is_item_checked(index)])
	return rows


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("rail_panels_test", label, actual, expected)
