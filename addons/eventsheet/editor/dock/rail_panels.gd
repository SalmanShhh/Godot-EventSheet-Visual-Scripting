@tool
class_name EventSheetRailPanels
extends RefCounted
# The LEFT RAIL: the five workspace panels as one column that rests, slides and gets out of the way.
#
# The rail used to be a plain VBoxContainer with five panels stacked in it, each carrying a fixed
# minimum size, and the only draggable edge was the rail-to-canvas grabber - which the editor theme
# only draws on hover, so the rail read as a fixed strip of counters beside the sheet. This builds
# the same five panels as a chain of VSplitContainers inside that HSplit instead:
#
#   VSplit(Open Sheets, VSplit(Objects, VSplit(Functions, VSplit(Anatomy, Picker preview))))
#
# so every boundary drags, every panel's minimum size is zero (the rail can be dragged to a sliver),
# and the grabbers are DRAWN rather than revealed on hover (`autohide` off, a bar background behind
# them). Three states, all remembered per project:
#
#   open       the panel takes its share of the column
#   tucked     the panel takes no room at all, not even a header; its name sits in the tab strip at
#              the foot of the rail, and clicking that tab brings it back at the height it had
#   rail off   the whole rail tucks into a narrow edge strip with a restore chevron, and the sheet
#              takes the width - the way a browser sidebar tucks away
#
# A panel is tucked by the button at the right edge of its header, or by dragging its divider up
# past that header; the rail is tucked by the chevron above it, or by dragging its grabber into the
# canvas edge. Nothing is ever CLOSED here: a tucked panel is off screen and its tab says what is
# there, which is why the View menu lists them too.
#
# Which panels are ON OFFER is a census question, not a preference: Anatomy only means something for
# a behaviour pack, and the Picker preview only while the picker is open, so a first sheet shows the
# two panels it has things in rather than five headers counting to zero.
#
# The state model at the top is static and pure, so panel order, defaults, the census rule and the
# stored-state round trip are all pinnable without an editor.

## Per-project editor metadata key holding the whole rail state (see `default_state`).
const META_KEY: String = "eventsheets_rail_panels"
## The tucked rail's width, and the width under which a rail drag counts as "tuck it".
const EDGE_STRIP_WIDTH: float = 14.0
## A drag that leaves a panel shorter than this has dragged it past its own header.
const TUCK_THRESHOLD: float = 18.0
## The rail's width when it is open and nothing has dragged it yet.
const DEFAULT_RAIL_WIDTH: float = 200.0
## The Properties bar's width when it is open and nothing has dragged it yet.
const DEFAULT_PROPERTIES_WIDTH: float = 270.0

## The panels, in the order the rail stacks them.
const PANEL_IDS: PackedStringArray = ["open_sheets", "objects", "functions", "anatomy", "picker_preview"]
## What a tab, a View entry and a tooltip call each panel.
const PANEL_TITLES: Dictionary = {
	"open_sheets": "Open Sheets",
	"objects": "Objects",
	"functions": "Functions",
	"anatomy": "Anatomy",
	"picker_preview": "Picker preview",
}
## The rail rests on the two panels every sheet fills; the rest are folds, closed until asked for.
const OPEN_BY_DEFAULT: PackedStringArray = ["open_sheets", "objects"]
## The starting height of each panel's slice of the column, at 1x.
const DEFAULT_HEIGHTS: Dictionary = {
	"open_sheets": 150.0,
	"objects": 150.0,
	"functions": 110.0,
	"anatomy": 120.0,
	"picker_preview": 110.0,
}


## The rail's panels in stacking order. The one place the order is written down.
static func panel_ids() -> PackedStringArray:
	return PANEL_IDS.duplicate()


## What the tab strip and the View menu call a panel.
static func panel_title(panel_id: String) -> String:
	return str(PANEL_TITLES.get(panel_id, panel_id))


## Whether a panel starts open (its body showing) or folded to its header line.
static func opens_by_default(panel_id: String) -> bool:
	return Array(OPEN_BY_DEFAULT).has(panel_id)


## The rail as it stands before anybody has dragged anything: two panels open, three folded, none
## tucked, the rail and the Properties bar at their default widths.
static func default_state() -> Dictionary:
	var panels: Dictionary = {}
	for panel_id: String in PANEL_IDS:
		panels[panel_id] = {
			"folded": not opens_by_default(panel_id),
			"tucked": false,
			"height": float(DEFAULT_HEIGHTS.get(panel_id, 110.0)),
		}
	return {
		"panels": panels,
		"rail_tucked": false,
		"rail_width": DEFAULT_RAIL_WIDTH,
		"properties_tucked": false,
		"properties_width": DEFAULT_PROPERTIES_WIDTH,
	}


## Read a stored state back into the full shape: every known panel present, every unknown key
## dropped, every value the type it is meant to be. A half-written or older record therefore reads
## as the default for the parts it does not carry, and never as a missing panel.
static func normalize_state(stored: Variant) -> Dictionary:
	var state: Dictionary = default_state()
	if not (stored is Dictionary):
		return state
	var source: Dictionary = stored as Dictionary
	state["rail_tucked"] = bool(source.get("rail_tucked", state["rail_tucked"]))
	state["rail_width"] = maxf(EDGE_STRIP_WIDTH, float(source.get("rail_width", state["rail_width"])))
	state["properties_tucked"] = bool(source.get("properties_tucked", state["properties_tucked"]))
	state["properties_width"] = maxf(0.0, float(source.get("properties_width", state["properties_width"])))
	var stored_panels: Variant = source.get("panels", {})
	if not (stored_panels is Dictionary):
		return state
	for panel_id: String in PANEL_IDS:
		var entry: Variant = (stored_panels as Dictionary).get(panel_id, null)
		if not (entry is Dictionary):
			continue
		var record: Dictionary = state["panels"][panel_id]
		record["folded"] = bool((entry as Dictionary).get("folded", record["folded"]))
		record["tucked"] = bool((entry as Dictionary).get("tucked", record["tucked"]))
		record["height"] = maxf(0.0, float((entry as Dictionary).get("height", record["height"])))
	return state


## Which panels the rail offers at all, given what the open sheet actually holds. Open Sheets,
## Objects and Functions are every sheet's; Anatomy is a behaviour pack's organs, so it appears
## for a pack and nowhere else; the Picker preview shows how this sheet's verbs will read in the
## picker, so it appears while the picker is open. A panel nothing can fill is not a fold the
## reader has to close - it is simply not there.
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


## The tucked panels, in rail order - what the foot tab strip and View ▸ Panels list.
static func tucked_panel_ids(state: Dictionary) -> PackedStringArray:
	var tucked: PackedStringArray = PackedStringArray()
	var panels: Variant = state.get("panels", {})
	if not (panels is Dictionary):
		return tucked
	for panel_id: String in PANEL_IDS:
		var entry: Variant = (panels as Dictionary).get(panel_id, null)
		if entry is Dictionary and bool((entry as Dictionary).get("tucked", false)):
			tucked.append(panel_id)
	return tucked


## The whole rail state as the editor remembers it for this project. Outside the editor there is
## nothing to read, and the defaults stand.
static func read_state() -> Dictionary:
	if Engine.is_editor_hint() and Engine.has_singleton("EditorInterface"):
		return normalize_state(EditorInterface.get_editor_settings().get_project_metadata(
			"eventsheets", META_KEY, {}))
	return default_state()


## Write the rail state back for this project. A no-op outside the editor.
static func save_state(state: Dictionary) -> void:
	if Engine.is_editor_hint() and Engine.has_singleton("EditorInterface"):
		EditorInterface.get_editor_settings().set_project_metadata("eventsheets", META_KEY, state)


# ── The built rail ────────────────────────────────────────────────────────────────────────────

var _dock: Control = null
var _state: Dictionary = default_state()
var _panels: Dictionary = {}          # panel id -> the panel Control
var _splits: Dictionary = {}          # panel id -> the VSplitContainer whose FIRST child it is
var _tabs: HBoxContainer = null       # the foot strip of tucked-panel tabs
var _body: VBoxContainer = null       # the whole rail: chevron strip, splits, tabs
var _edge: VBoxContainer = null       # the tucked rail's narrow strip
var _edge_label: Label = null
var _root: VBoxContainer = null
var _workspace_body: HSplitContainer = null
var _census: Dictionary = {"behaviour_pack": false, "picker_open": false}
# How many times the width has been corrected since the last state was applied. The correction
# below re-reads a minimum that only settles once the column has been laid out, so it is allowed a
# few goes and then stops - a width that will not settle is a width, not a loop.
var _width_fixes: int = 0
# Set while a grabber drag is being answered, so the next layout is read as the reader's chosen
# width rather than as a width to correct.
var _reading_drag: bool = false


func init(dock: Control) -> void:
	_dock = dock


## Builds the rail around the five panels the dock has already made and wired, handed over as
## `{panel id: Control}`. Returns the control to put on the left of the workspace split;
## `attach_split` then gives it the HSplit so the rail can drag and tuck itself.
func build(panels: Dictionary) -> Control:
	_root = VBoxContainer.new()
	_root.name = "EventSheetLeftRail"
	# NOT expanding horizontally: an HSplitContainer whose two children both expand puts its
	# divider at a share of the width, and `split_offset` then reads as an offset FROM there. With
	# only the canvas expanding, the divider rests at the rail's own minimum - which is zero - so
	# the offset is the rail's width in pixels and nothing has to guess.
	_root.size_flags_horizontal = Control.SIZE_FILL
	_root.size_flags_vertical = Control.SIZE_EXPAND_FILL

	_body = VBoxContainer.new()
	_body.name = "EventSheetLeftRailBody"
	_body.add_theme_constant_override("separation", 0)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_root.add_child(_body)

	# The rail's own minimise, on its top edge: the chevron a browser puts on its sidebar.
	var top_strip: HBoxContainer = HBoxContainer.new()
	top_strip.name = "EventSheetLeftRailTopStrip"
	var top_spacer: Control = Control.new()
	top_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_strip.add_child(top_spacer)
	top_strip.add_child(_chevron_button("‹", "Tuck the rail into the edge - the sheet takes the width.",
		func() -> void: set_rail_tucked(true)))
	_body.add_child(top_strip)

	for panel_id: String in PANEL_IDS:
		var panel: Control = panels.get(panel_id, null) as Control
		if panel == null:
			continue
		_panels[panel_id] = panel
		# The rail decides the column's heights, so a panel brings no minimum of its own to it.
		panel.custom_minimum_size = Vector2.ZERO
		_add_header_button(panel, panel_id)
		_connect_fold(panel, panel_id)

	_body.add_child(_build_chain(0))

	_tabs = HBoxContainer.new()
	_tabs.name = "EventSheetLeftRailTabs"
	_tabs.add_theme_constant_override("separation", 3)
	_body.add_child(_tabs)

	_edge = VBoxContainer.new()
	_edge.name = "EventSheetLeftRailEdge"
	_edge.visible = false
	_edge.custom_minimum_size = Vector2(EventSheetPalette.scaled_f(EDGE_STRIP_WIDTH), 0.0)
	_edge.add_child(_chevron_button("›", "Bring the rail back at the width it had.",
		func() -> void: set_rail_tucked(false)))
	_edge_label = Label.new()
	_edge_label.name = "EventSheetLeftRailEdgeLabel"
	# One narrow column of characters - the panel names read down the strip, so the tucked rail
	# still says what is behind it.
	_edge_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_edge_label.add_theme_font_size_override("font_size", EventSheetPalette.scaled(9))
	_edge_label.add_theme_color_override("font_color", EventSheetPalette.TEXT_SECONDARY)
	_edge_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_edge.add_child(_edge_label)
	_root.add_child(_edge)
	_root.resized.connect(_on_rail_resized)
	return _root


## The nested VSplit chain, one split per boundary between two panels. Built over ALL the panels
## rather than only the shown ones, because a SplitContainer hands the whole area to whichever of
## its two children is visible - so showing and hiding a panel is a visibility flag, never a
## rebuild of the column under the reader's cursor.
func _build_chain(index: int) -> Control:
	var panel_id: String = PANEL_IDS[index]
	var panel: Control = _panels.get(panel_id, null) as Control
	if panel == null:
		panel = Control.new()
		panel.name = "EventSheetRailMissing_%s" % panel_id
	if index == PANEL_IDS.size() - 1:
		return panel
	var split: VSplitContainer = VSplitContainer.new()
	split.name = "EventSheetRailSplit_%s" % panel_id
	split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.dragger_visibility = SplitContainer.DRAGGER_VISIBLE
	# The two theme overrides that make the boundary a THING ON SCREEN rather than something the
	# pointer discovers: `autohide` off keeps the grabber drawn, and the bar gets a ground of its own.
	split.add_theme_constant_override("autohide", 0)
	split.add_theme_constant_override("separation", int(EventSheetPalette.scaled_f(6.0)))
	split.add_theme_constant_override("minimum_grab_thickness", int(EventSheetPalette.scaled_f(6.0)))
	var bar: StyleBoxFlat = StyleBoxFlat.new()
	bar.bg_color = EventSheetPalette.TEXT_SECONDARY
	bar.bg_color.a = 0.22
	split.add_theme_stylebox_override("split_bar_background", bar)
	split.split_offset = int(EventSheetPalette.scaled_f(
		float((_state["panels"][panel_id] as Dictionary).get("height", 110.0))))
	split.add_child(panel)
	split.add_child(_build_chain(index + 1))
	split.dragged.connect(func(offset: int) -> void: _on_split_dragged(panel_id, offset))
	_splits[panel_id] = split
	return split


## A drag on one panel's lower boundary: remember the height, and treat a drag that took the panel
## up past its own header as the same gesture as pressing its minimise button.
func _on_split_dragged(panel_id: String, offset: int) -> void:
	if float(offset) < EventSheetPalette.scaled_f(TUCK_THRESHOLD):
		set_panel_tucked(panel_id, true)
		return
	(_state["panels"][panel_id] as Dictionary)["height"] = float(offset) / maxf(0.001, EventSheetPalette.ui_scale())
	save_state(_state)


## The HSplit between the rail and the canvas: dragging its grabber into the edge tucks the rail,
## exactly as the chevron does, and any other drag is the rail's remembered width.
func attach_split(workspace_body: HSplitContainer) -> void:
	_workspace_body = workspace_body
	_workspace_body.dragger_visibility = SplitContainer.DRAGGER_VISIBLE
	_workspace_body.add_theme_constant_override("autohide", 0)
	_workspace_body.add_theme_constant_override("separation", int(EventSheetPalette.scaled_f(6.0)))
	var bar: StyleBoxFlat = StyleBoxFlat.new()
	bar.bg_color = EventSheetPalette.TEXT_SECONDARY
	bar.bg_color.a = 0.22
	_workspace_body.add_theme_stylebox_override("split_bar_background", bar)
	# A drag is answered by the width it actually produced rather than by the offset that was
	# asked for: what a SplitContainer's offset means depends on which of its two children expand
	# and on their minimums, and the rail wants to remember a WIDTH.
	_workspace_body.dragged.connect(func(_offset: int) -> void: _reading_drag = true)


## The width the rail is asked to be, in pixels: the remembered one, or the edge strip when it is
## tucked away.
func _wanted_rail_width() -> float:
	return EventSheetPalette.scaled_f(EDGE_STRIP_WIDTH if is_rail_tucked()
		else float(_state.get("rail_width", DEFAULT_RAIL_WIDTH)))


## The remembered width, on the splitter. A first guess: `_on_rail_resized` reads back what the
## split actually did with it and closes the gap, which is the one way to place a divider in
## pixels without depending on how a SplitContainer works out its own default position.
func _apply_rail_width() -> void:
	if _workspace_body == null:
		return
	_workspace_body.split_offset = int(_wanted_rail_width())


## The rail was laid out. Either it has just been dragged, in which case the width it landed on IS
## the answer and is remembered, or it came out at a width it was not asked for and the offset is
## nudged by the difference - a bounded number of times, because a width that will not settle is a
## width, not a loop.
func _on_rail_resized() -> void:
	if _root == null or _root.size.x <= 0.0:
		return
	if _reading_drag:
		_reading_drag = false
		if _root.size.x <= EventSheetPalette.scaled_f(EDGE_STRIP_WIDTH + 6.0):
			set_rail_tucked(true)
			return
		_state["rail_width"] = _root.size.x / maxf(0.001, EventSheetPalette.ui_scale())
		_width_fixes = 0
		save_state(_state)
		return
	if _width_fixes >= 4 or absf(_root.size.x - _wanted_rail_width()) <= 2.0:
		return
	_width_fixes += 1
	_workspace_body.split_offset += int(_wanted_rail_width() - _root.size.x)


## What the open sheet offers the rail: whether it is a behaviour pack (Anatomy), and whether the
## picker is open (Picker preview). Pushed by the dock whenever either could have changed.
func set_census(behaviour_pack: bool, picker_open: bool) -> void:
	var next: Dictionary = {"behaviour_pack": behaviour_pack, "picker_open": picker_open}
	if next == _census:
		return
	_census = next
	_apply()


## Fold or unfold a panel - the header's own gesture, kept here so the choice is remembered with
## the rest of the rail rather than by each panel separately. Pushing it down and hearing it back
## are the same call, so the rail and the header can never disagree about what is folded.
func set_panel_folded(panel_id: String, folded: bool) -> void:
	if not (_state["panels"] as Dictionary).has(panel_id):
		return
	if bool((_state["panels"][panel_id] as Dictionary).get("folded", false)) == folded:
		return
	(_state["panels"][panel_id] as Dictionary)["folded"] = folded
	_push_fold(panel_id)
	save_state(_state)


func is_panel_folded(panel_id: String) -> bool:
	var entry: Variant = (_state["panels"] as Dictionary).get(panel_id, null)
	return entry is Dictionary and bool((entry as Dictionary).get("folded", false))


## A panel's own header button folded it: record it here, so one project memory holds every fold.
func _connect_fold(panel: Control, panel_id: String) -> void:
	if panel.has_signal("fold_toggled"):
		panel.connect("fold_toggled", func(expanded: bool) -> void: set_panel_folded(panel_id, not expanded))
	elif panel.has_signal("collapse_toggled"):
		panel.connect("collapse_toggled", func(collapsed: bool) -> void: set_panel_folded(panel_id, collapsed))


## The remembered fold, on the panel. Open Sheets calls it collapsing to a strip and the folds call
## it expanding; both are the same choice from the rail's side.
func _push_fold(panel_id: String) -> void:
	var panel: Control = _panels.get(panel_id, null) as Control
	if panel == null:
		return
	var folded: bool = is_panel_folded(panel_id)
	if panel.has_method("set_expanded"):
		if bool(panel.call("is_expanded")) == folded:
			panel.call("set_expanded", not folded)
	elif panel.has_method("set_collapsed"):
		if bool(panel.call("is_collapsed")) != folded:
			panel.call("set_collapsed", folded)
	# A panel that shrinks itself when it folds is asking for a width the rail decides. The rail
	# decides it, so the minimum goes back to nothing.
	panel.custom_minimum_size = Vector2.ZERO


## Slide a panel off the column (it takes no room, not even a header, and its name joins the tab
## strip at the foot of the rail) or bring it back at the height it had.
func set_panel_tucked(panel_id: String, tucked: bool) -> void:
	if not (_state["panels"] as Dictionary).has(panel_id):
		return
	(_state["panels"][panel_id] as Dictionary)["tucked"] = tucked
	save_state(_state)
	_apply()


func is_panel_tucked(panel_id: String) -> bool:
	var entry: Variant = (_state["panels"] as Dictionary).get(panel_id, null)
	return entry is Dictionary and bool((entry as Dictionary).get("tucked", false))


## Tuck the whole rail into its edge strip, or bring it back at the width it had.
func set_rail_tucked(tucked: bool) -> void:
	_state["rail_tucked"] = tucked
	save_state(_state)
	_apply()


func is_rail_tucked() -> bool:
	return bool(_state.get("rail_tucked", false))


## The rail state for this project, for the dock to hand to the Properties bar and for a test to
## round-trip. A copy: the rail is the only writer.
func export_state() -> Dictionary:
	return _state.duplicate(true)


## Put a remembered (or a test's) state on the built rail: the folds go down to the panels, and
## everything else is laid out by `_apply`.
func apply_state(state: Dictionary) -> void:
	_state = normalize_state(state)
	for panel_id: String in PANEL_IDS:
		_push_fold(panel_id)
	_apply()


## Everything the state says, on the widgets: which panels are on offer, which are tucked, the
## column's heights, the tab strip, and whether the rail itself is an edge strip.
func _apply() -> void:
	if _root == null:
		return
	var shown: PackedStringArray = shown_panel_ids(_census)
	var on_screen: PackedStringArray = PackedStringArray()
	for panel_id: String in PANEL_IDS:
		var panel: Control = _panels.get(panel_id, null) as Control
		if panel == null:
			continue
		var visible_now: bool = shown.has(panel_id) and not is_panel_tucked(panel_id)
		panel.visible = visible_now
		if visible_now:
			on_screen.append(panel_id)
		var split: VSplitContainer = _splits.get(panel_id, null) as VSplitContainer
		if split != null and visible_now:
			split.split_offset = int(EventSheetPalette.scaled_f(
				float((_state["panels"][panel_id] as Dictionary).get("height", 110.0))))
	_rebuild_tabs(shown)
	var tucked: bool = is_rail_tucked()
	_body.visible = not tucked
	_edge.visible = tucked
	_root.custom_minimum_size = Vector2(EventSheetPalette.scaled_f(EDGE_STRIP_WIDTH) if tucked else 0.0, 0.0)
	if _edge_label != null:
		var titles: PackedStringArray = PackedStringArray()
		for panel_id2: String in on_screen:
			titles.append(panel_title(panel_id2).to_upper())
		_edge_label.text = " · ".join(titles)
	_width_fixes = 0
	_apply_rail_width()


## The foot strip: one thin tab per panel that is on offer but tucked away. Clicking one brings its
## panel back. A panel the census does not offer has no tab - there is nothing behind it to restore.
func _rebuild_tabs(shown: PackedStringArray) -> void:
	if _tabs == null:
		return
	for child: Node in Array(_tabs.get_children()):
		_tabs.remove_child(child)
		child.queue_free()
	for panel_id: String in tucked_panel_ids(_state):
		if not shown.has(panel_id):
			continue
		var tab: Button = Button.new()
		tab.name = "EventSheetRailTab_%s" % panel_id
		tab.flat = true
		tab.text = "› %s" % panel_title(panel_id)
		tab.tooltip_text = "Bring %s back at the height it had." % panel_title(panel_id)
		tab.add_theme_font_size_override("font_size", EventSheetPalette.scaled(10))
		var restored_id: String = panel_id
		tab.pressed.connect(func() -> void: set_panel_tucked(restored_id, false))
		_tabs.add_child(tab)
	_tabs.visible = _tabs.get_child_count() > 0


## The minimise button every panel header carries at its right edge. The panel says WHERE its
## header is (`rail_header_row`); the rail says what the button does, so the gesture is one
## sentence in one place rather than five copies of it.
func _add_header_button(panel: Control, panel_id: String) -> void:
	if not panel.has_method("rail_header_row"):
		return
	var header: Node = panel.call("rail_header_row")
	if not (header is Control):
		return
	# A header that says a lot ("Objects  player.tscn - 10 used - 2 more") would otherwise set the
	# rail's minimum width to the length of its own sentence, and no drag could make the column
	# narrower than the longest thing it currently says. The words are clipped instead: the rail's
	# width is the reader's choice, and the full text is a tooltip away.
	for child: Node in (header as Control).get_children():
		if child is Button:
			(child as Button).clip_text = true
		elif child is Label:
			(child as Label).clip_text = true
	var button: Button = _chevron_button("–",
		"Slide %s off the rail - its name waits in the tab strip at the foot." % panel_title(panel_id),
		func() -> void: set_panel_tucked(panel_id, true))
	button.name = "EventSheetRailMinimise_%s" % panel_id
	(header as Control).add_child(button)


func _chevron_button(glyph: String, tooltip: String, on_pressed: Callable) -> Button:
	var button: Button = Button.new()
	button.flat = true
	button.text = glyph
	button.tooltip_text = tooltip
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", EventSheetPalette.scaled(11))
	button.pressed.connect(on_pressed)
	return button
