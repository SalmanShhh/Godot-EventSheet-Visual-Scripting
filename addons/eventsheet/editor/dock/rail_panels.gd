@tool
class_name EventSheetRailPanels
extends RefCounted
# The SIDE PANEL beside the sheet: a thin rail that rests closed, and opens to tabs.
#
# Closed, it is a strip 30 px wide with one button on it, and the sheet has the width. Open, it is
# a panel styled the way Godot's own docks are - a strip of flat tabs along the top, then whatever
# the chosen tab holds (a filter, then plain rows with an icon, a name and a count):
#
#   Objects     what this file uses and what else is in its scene, plus the Project bar's fold
#   Functions   the sheet's functions and the functions still written as code
#
# Two more tabs appear only when there is something behind them: Anatomy for a behaviour pack, and
# the Picker preview while the picker is open. There is no Open Sheets list: the tabs above the
# sheet already are the open sheets.
#
# Whether the panel is open, which tab it shows and how wide it is are remembered per project, in
# the editor's project metadata (the same record also holds the Properties bar's width).
#
# The state model at the top is static and pure, so the tab order, the defaults, the census rule
# and the stored-state round trip are all pinnable without an editor.

## Per-project editor metadata key holding the whole side panel state (see `default_state`).
const META_KEY: String = "eventsheets_rail_panels"
## The closed panel's width: the strip with the open button on it, at 1x.
const CLOSED_WIDTH: float = 30.0
## The narrowest the Properties bar may be dragged before it counts as "slide it off the edge".
const EDGE_STRIP_WIDTH: float = 14.0
## The open panel's width when nothing has dragged it yet, at 1x.
const DEFAULT_RAIL_WIDTH: float = 230.0
## The Properties bar's width when it is open and nothing has dragged it yet.
const DEFAULT_PROPERTIES_WIDTH: float = 270.0

## The tabs, in the order the strip shows them.
const PANEL_IDS: PackedStringArray = ["objects", "functions", "anatomy", "picker_preview"]


## The panel's tabs in strip order. The one place the order is written down.
static func panel_ids() -> PackedStringArray:
	return PANEL_IDS.duplicate()


## What the tab strip and the View menu call a panel, in the reader's language. Each title is a
## literal, so the translation harvester owes every one of them a row.
static func panel_title(panel_id: String) -> String:
	match panel_id:
		"objects":
			return EventSheetL10n.translate("Objects")
		"functions":
			return EventSheetL10n.translate("Functions")
		"anatomy":
			return EventSheetL10n.translate("Anatomy")
		"picker_preview":
			return EventSheetL10n.translate("Picker preview")
	return panel_id


## The side panel as it stands before anybody has opened it: closed, on the Objects tab, the panel
## and the Properties bar at their default widths.
static func default_state() -> Dictionary:
	return {
		"panel_open": false,
		"panel_tab": "objects",
		"rail_width": DEFAULT_RAIL_WIDTH,
		"properties_tucked": false,
		"properties_width": DEFAULT_PROPERTIES_WIDTH,
	}


## Read a stored state back into the full shape: every known key present, every unknown key dropped,
## every value the type it is meant to be. A half-written or older record therefore reads as the
## default for the parts it does not carry - and the column of stacked panels the side panel replaced
## kept different keys, so its record reads as a closed panel on the Objects tab.
static func normalize_state(stored: Variant) -> Dictionary:
	var state: Dictionary = default_state()
	if not (stored is Dictionary):
		return state
	var source: Dictionary = stored as Dictionary
	state["panel_open"] = bool(source.get("panel_open", state["panel_open"]))
	var tab: String = str(source.get("panel_tab", state["panel_tab"]))
	state["panel_tab"] = tab if PANEL_IDS.has(tab) else "objects"
	state["rail_width"] = maxf(CLOSED_WIDTH, float(source.get("rail_width", state["rail_width"])))
	state["properties_tucked"] = bool(source.get("properties_tucked", state["properties_tucked"]))
	state["properties_width"] = maxf(0.0, float(source.get("properties_width", state["properties_width"])))
	return state


## Which tabs the panel offers, given what the open sheet actually holds. Objects and Functions are
## every sheet's; Anatomy is a behaviour pack's organs, so it appears for a pack and nowhere else;
## the Picker preview shows how this sheet's verbs will read in the picker, so it appears while the
## picker is open. A tab nothing can fill is simply not there.
static func shown_panel_ids(census: Dictionary) -> PackedStringArray:
	var shown: PackedStringArray = PackedStringArray()
	for panel_id: String in PANEL_IDS:
		match panel_id:
			"anatomy":
				if bool(census.get("behaviour_pack", false)):
					shown.append(panel_id)
			"picker_preview":
				if bool(census.get("picker_open", false)):
					shown.append(panel_id)
			_:
				shown.append(panel_id)
	return shown


## The tab the panel shows for a stored choice: the chosen one while it is on offer, Objects when it
## is not (an Anatomy tab remembered from a pack, with an ordinary script open).
static func shown_tab(chosen: String, shown: PackedStringArray) -> String:
	return chosen if shown.has(chosen) else "objects"


## The whole side panel state as the editor remembers it for this project. Outside the editor there
## is nothing to read, and the defaults stand.
static func read_state() -> Dictionary:
	if Engine.is_editor_hint() and Engine.has_singleton("EditorInterface"):
		return normalize_state(EditorInterface.get_editor_settings().get_project_metadata(
			"eventsheets", META_KEY, {}))
	return default_state()


## Write the side panel state back for this project, keeping the keys this file does not own (the
## Properties bar writes its width into the same record). A no-op outside the editor.
static func save_state(state: Dictionary) -> void:
	if Engine.is_editor_hint() and Engine.has_singleton("EditorInterface"):
		EditorInterface.get_editor_settings().set_project_metadata("eventsheets", META_KEY, state)


# ── The built panel ───────────────────────────────────────────────────────────────────────────

var _dock: Control = null
var _state: Dictionary = default_state()
var _panels: Dictionary = {}          # panel id -> the panel Control
var _root: PanelContainer = null
var _body: VBoxContainer = null       # the open panel: the tab strip, then the chosen tab
var _strip: PanelContainer = null     # the tab strip's ground
var _content: PanelContainer = null   # the chosen tab's ground
var _tab_bar: TabBar = null
var _tab_ids: PackedStringArray = PackedStringArray()   # the tab bar's tabs, by index
var _edge: PanelContainer = null      # the closed panel: the rail with the open button
var _workspace_body: HSplitContainer = null
var _census: Dictionary = {"behaviour_pack": false, "picker_open": false}
# How many times the width has been corrected since the last state was applied. The correction
# below re-reads a minimum that only settles once the column has been laid out, so it is allowed a
# few goes and then stops - a width that will not settle is a width, not a loop.
var _width_fixes: int = 0
# Set while a grabber drag is being answered, so the next layout is read as the reader's chosen
# width rather than as a width to correct.
var _reading_drag: bool = false
# Set while the tab strip is being refilled, so the refill is not read as the reader picking a tab.
var _filling_tabs: bool = false


func init(dock: Control) -> void:
	_dock = dock


## Builds the side panel around the panels the dock has already made and wired, handed over as
## `{panel id: Control}`. Returns the control to put on the left of the workspace split;
## `attach_split` then gives it the HSplit so the open panel can be dragged wider.
func build(panels: Dictionary) -> Control:
	_root = PanelContainer.new()
	_root.name = "EventSheetLeftRail"
	# NOT expanding horizontally: an HSplitContainer whose two children both expand puts its
	# divider at a share of the width, and `split_offset` then reads as an offset FROM there. With
	# only the canvas expanding, the divider rests at the panel's own minimum, so the offset is the
	# panel's width in pixels and nothing has to guess.
	_root.size_flags_horizontal = Control.SIZE_FILL
	_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# The grounds below are the ones a Godot dock's TabContainer draws, read from the theme once the
	# panel is in the editor's tree and each time the theme changes; the root draws nothing itself.
	_root.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_root.tree_entered.connect(_dress_grounds)
	_root.theme_changed.connect(_dress_grounds)

	_body = VBoxContainer.new()
	_body.name = "EventSheetSidePanelBody"
	_body.add_theme_constant_override("separation", 0)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_root.add_child(_body)

	# The strip along the top: the tabs, and at its right end the button that closes the panel.
	_strip = PanelContainer.new()
	_strip.name = "EventSheetSidePanelStrip"
	var strip_row: HBoxContainer = HBoxContainer.new()
	strip_row.name = "EventSheetSidePanelStripRow"
	strip_row.add_theme_constant_override("separation", 0)
	_tab_bar = TabBar.new()
	_tab_bar.name = "EventSheetSidePanelTabs"
	_tab_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tab_bar.clip_tabs = true
	_tab_bar.tab_changed.connect(_on_tab_changed)
	strip_row.add_child(_tab_bar)
	var close_button: Button = _strip_button("‹",
		EventSheetL10n.translate("Close the side panel"),
		func() -> void: set_rail_tucked(true))
	close_button.name = "EventSheetSidePanelClose"
	strip_row.add_child(close_button)
	_strip.add_child(strip_row)
	_body.add_child(_strip)

	# The chosen tab, on the dock's own ground. Every panel is a child of it and only the chosen one
	# is visible, which is exactly how a TabContainer holds its pages.
	_content = PanelContainer.new()
	_content.name = "EventSheetSidePanelContent"
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_child(_content)
	for panel_id: String in PANEL_IDS:
		var panel: Control = panels.get(panel_id, null) as Control
		if panel == null:
			continue
		_panels[panel_id] = panel
		_dress_as_tab(panel)
		_content.add_child(panel)

	_edge = PanelContainer.new()
	_edge.name = "EventSheetLeftRailEdge"
	var edge_column: VBoxContainer = VBoxContainer.new()
	edge_column.name = "EventSheetLeftRailEdgeColumn"
	edge_column.alignment = BoxContainer.ALIGNMENT_BEGIN
	var open_button: Button = _strip_button("›",
		EventSheetL10n.translate("Objects and functions of this sheet"),
		func() -> void: set_rail_tucked(false))
	open_button.name = "EventSheetSidePanelOpen"
	# The one thing on the rail, so it wears a button's own ground rather than sitting flat on it.
	open_button.flat = false
	open_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	edge_column.add_child(open_button)
	_edge.add_child(edge_column)
	_root.add_child(_edge)
	_root.resized.connect(_on_rail_resized)
	_dress_grounds()
	return _root


## The grounds a Godot dock draws, from the theme: the tab strip on the TabContainer's tab-bar
## background, the chosen tab and the closed rail on its panel. The rail keeps a few pixels of air
## rather than the panel's own margins, so its one button fits the 30 px it rests at.
func _dress_grounds() -> void:
	if _root == null:
		return
	var bar_ground: StyleBox = _root.get_theme_stylebox("tabbar_background", "TabContainer")
	_strip.add_theme_stylebox_override("panel", bar_ground if bar_ground != null else StyleBoxEmpty.new())
	var page_ground: StyleBox = _root.get_theme_stylebox("panel", "TabContainer")
	_content.add_theme_stylebox_override("panel", page_ground if page_ground != null else StyleBoxEmpty.new())
	var rail_ground: StyleBox = page_ground.duplicate() as StyleBox if page_ground != null else StyleBoxFlat.new()
	var air: float = EventSheetPalette.scaled_f(4.0)
	rail_ground.content_margin_left = air
	rail_ground.content_margin_right = air
	rail_ground.content_margin_top = air
	rail_ground.content_margin_bottom = air
	_edge.add_theme_stylebox_override("panel", rail_ground)


## A panel that used to stand in a column of its own carried a fold header (its name, a chevron and
## sometimes a count). In a tab the tab names it, so the header stands down and the body is always
## open; and the panel brings no minimum size of its own, because the panel's width is the reader's.
func _dress_as_tab(panel: Control) -> void:
	panel.custom_minimum_size = Vector2.ZERO
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if panel.has_method("set_expanded"):
		panel.call("set_expanded", true)
	if panel.has_method("rail_header_row"):
		var header: Variant = panel.call("rail_header_row")
		if header is Control:
			(header as Control).visible = false


## The HSplit between the side panel and the canvas: a drag on its grabber is the open panel's
## remembered width. Closed, the panel is its strip and the grabber does nothing.
func attach_split(workspace_body: HSplitContainer) -> void:
	_workspace_body = workspace_body
	# A drag is answered by the width it actually produced rather than by the offset that was
	# asked for: what a SplitContainer's offset means depends on which of its two children expand
	# and on their minimums, and the panel wants to remember a WIDTH.
	_workspace_body.dragged.connect(func(_offset: int) -> void: _reading_drag = true)
	_apply()


## The width the panel is asked to be, in pixels: the remembered one, or the strip when it is closed.
func _wanted_rail_width() -> float:
	return EventSheetPalette.scaled_f(CLOSED_WIDTH if is_rail_tucked()
		else float(_state.get("rail_width", DEFAULT_RAIL_WIDTH)))


## The remembered width, on the splitter. A first guess: `_on_rail_resized` reads back what the
## split actually did with it and closes the gap, which is the one way to place a divider in
## pixels without depending on how a SplitContainer works out its own default position.
func _apply_rail_width() -> void:
	if _workspace_body == null:
		return
	_workspace_body.split_offset = int(_wanted_rail_width())


## The panel was laid out. Either it has just been dragged, in which case the width it landed on IS
## the answer and is remembered, or it came out at a width it was not asked for and the offset is
## nudged by the difference - a bounded number of times.
func _on_rail_resized() -> void:
	if _root == null or _root.size.x <= 0.0 or _workspace_body == null:
		return
	if _reading_drag:
		_reading_drag = false
		if is_rail_tucked():
			_apply_rail_width()
			return
		_state["rail_width"] = maxf(CLOSED_WIDTH, _root.size.x / maxf(0.001, EventSheetPalette.ui_scale()))
		_width_fixes = 0
		save_state(_merged_state())
		return
	if _width_fixes >= 4 or absf(_root.size.x - _wanted_rail_width()) <= 2.0:
		return
	_width_fixes += 1
	_workspace_body.split_offset += int(_wanted_rail_width() - _root.size.x)


## What the open sheet offers the panel: whether it is a behaviour pack (Anatomy), and whether the
## picker is open (Picker preview). Pushed by the dock whenever either could have changed.
func set_census(behaviour_pack: bool, picker_open: bool) -> void:
	var next: Dictionary = {"behaviour_pack": behaviour_pack, "picker_open": picker_open}
	if next == _census:
		return
	_census = next
	_apply()


## The tabs on offer right now, in strip order.
func offered_panel_ids() -> PackedStringArray:
	return shown_panel_ids(_census)


## The tab the panel shows (or would show, were it open).
func active_tab() -> String:
	return shown_tab(str(_state.get("panel_tab", "objects")), offered_panel_ids())


## Show one tab, remembering the choice. Opens nothing: the panel's open state is its own choice.
func set_active_tab(panel_id: String) -> void:
	if not PANEL_IDS.has(panel_id):
		return
	_state["panel_tab"] = panel_id
	save_state(_merged_state())
	_apply()


## Whether a panel is out of sight - the panel is closed, or another tab is showing. Bringing one
## back (`set_panel_tucked(id, false)`) opens the panel on that tab, and putting the showing one
## away closes the panel; putting away a tab that is not showing changes nothing.
func is_panel_tucked(panel_id: String) -> bool:
	return is_rail_tucked() or active_tab() != panel_id


func set_panel_tucked(panel_id: String, tucked: bool) -> void:
	if not PANEL_IDS.has(panel_id):
		return
	if not tucked:
		_state["panel_tab"] = panel_id
		set_rail_tucked(false)
		return
	if not is_panel_tucked(panel_id):
		set_rail_tucked(true)


## Close the panel to its strip, or open it at the width it had, remembering the choice.
func set_rail_tucked(tucked: bool) -> void:
	_state["panel_open"] = not tucked
	save_state(_merged_state())
	_apply()


## Whether the panel is closed to its strip.
func is_rail_tucked() -> bool:
	return not bool(_state.get("panel_open", false))


## Whether the panel is open: View > Side Panel's tick.
func is_rail_shown() -> bool:
	return not is_rail_tucked()


## Put a remembered (or a test's) state on the built panel.
func apply_state(state: Dictionary) -> void:
	_state = normalize_state(state)
	_apply()


## The state to write back: this file's keys over whatever the record already holds, so the
## Properties bar's width (written by its own file into the same record) is never lost.
func _merged_state() -> Dictionary:
	var merged: Dictionary = read_state()
	for key: Variant in _state.keys():
		if key != "properties_tucked" and key != "properties_width":
			merged[key] = _state[key]
	return merged


## Everything the state says, on the widgets: which tabs are on offer, which one shows, and whether
## the panel is open or its strip.
func _apply() -> void:
	if _root == null:
		return
	var shown: PackedStringArray = offered_panel_ids()
	var showing: String = active_tab()
	_fill_tabs(shown, showing)
	for panel_id: String in PANEL_IDS:
		var panel: Control = _panels.get(panel_id, null) as Control
		if panel != null:
			panel.visible = panel_id == showing
	var tucked: bool = is_rail_tucked()
	_body.visible = not tucked
	_edge.visible = tucked
	_root.custom_minimum_size = Vector2(EventSheetPalette.scaled_f(CLOSED_WIDTH) if tucked else 0.0, 0.0)
	if _workspace_body != null:
		# Closed, the strip is not a thing to drag wider: the button on it opens the panel.
		_workspace_body.dragging_enabled = not tucked
		_workspace_body.dragger_visibility = (SplitContainer.DRAGGER_HIDDEN_COLLAPSED if tucked
			else SplitContainer.DRAGGER_VISIBLE)
	_width_fixes = 0
	_apply_rail_width()
	# A tab that reads its rows only once it is on screen (the Functions tab) reads them now.
	var shown_panel: Control = _panels.get(showing, null) as Control
	if not tucked and shown_panel != null and shown_panel.has_method("catch_up"):
		shown_panel.call("catch_up")


## The tab strip, refilled only when the tabs on offer change, so a click is never undone by its
## own refill.
func _fill_tabs(shown: PackedStringArray, showing: String) -> void:
	if _tab_bar == null:
		return
	_filling_tabs = true
	if shown != _tab_ids:
		_tab_bar.clear_tabs()
		for panel_id: String in shown:
			_tab_bar.add_tab(panel_title(panel_id))
		_tab_ids = shown.duplicate()
	var index: int = _tab_ids.find(showing)
	if index >= 0 and _tab_bar.current_tab != index:
		_tab_bar.current_tab = index
	for tab_index: int in _tab_ids.size():
		var panel: Control = _panels.get(_tab_ids[tab_index], null) as Control
		if panel != null and panel.has_method("tab_tooltip"):
			_tab_bar.set_tab_tooltip(tab_index, str(panel.call("tab_tooltip")))
	_filling_tabs = false


func _on_tab_changed(index: int) -> void:
	if _filling_tabs or index < 0 or index >= _tab_ids.size():
		return
	set_active_tab(_tab_ids[index])


## Refresh the tabs' hovers - a panel says what it holds once the sheet has been read.
func refresh_tab_tooltips() -> void:
	if _root != null:
		_fill_tabs(offered_panel_ids(), active_tab())


func _strip_button(glyph: String, tooltip: String, on_pressed: Callable) -> Button:
	var button: Button = Button.new()
	button.flat = true
	button.text = glyph
	button.tooltip_text = tooltip
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(EventSheetPalette.scaled_f(22.0), EventSheetPalette.scaled_f(22.0))
	button.pressed.connect(on_pressed)
	return button
