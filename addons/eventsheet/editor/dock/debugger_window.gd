# EventSheet - EventSheetDebuggerWindow: ONE debugger, four tabs.
#
# Everything this window shows already shipped, and that is the point of it. Live Values, the Watch
# box, the Event Trace and its hit counts, and F9 breakpoints were four separate panels and toggles
# scattered across two menus, and a reader arriving from another event-sheet editor went looking
# for one window with four tabs and found none. So: one window, the four names they expect, and
# every tab a thin view over a seam that was already there.
#
#   Inspect      every object type this sheet talks about, its running instances, and - for the one
#                you pick - its instance variables (EDITABLE, straight into the running game) and
#                its behaviors' values, over the Live Values stream
#   Watch        the existing watch box, sharing ONE list of expressions with the Live Values
#                window rather than keeping a second one that quietly disagrees with it
#   Profile      per-event and per-function time from the Event Trace timings, busiest first, with
#                each row's share of the run
#   Breakpoints  the F9 rows, with enable / disable / jump, and where the run is paused right now
#
# THE ONE RULE all four obey: nothing is drawn that no run has reported. An empty tab says what to
# do to fill it ("run the game with Live Values on"), because a table of zeroes and a table of
# "nothing has happened yet" look identical and only one of them is true.
@tool
class_name EventSheetDebuggerWindow
extends RefCounted

## The tabs, in the order they are shown. The words are the ones a reader arrives holding.
const TAB_TITLES: Array[String] = ["Inspect", "Watch", "Profile", "Breakpoints"]

## What each tab says before a run has reported anything. Never a table of zeroes: "nothing has
## happened yet" and "everything is zero" look the same and only one of them is true.
const EMPTY_STATES := {
	"Inspect": "No running game. Turn on Tools ▸ Live Values, then run - every object this sheet talks about appears here with its instances, and you can edit their values live.",
	"Watch": "Watch any expression over the sheet's variables - health <= 0, score + lives - and see it flip while the game runs.",
	"Profile": "No traced run yet. Turn on Tools ▸ Event Trace, then run - every event that fires is timed here, busiest first.",
	"Breakpoints": "No breakpoints. Select a row and press F9 to pause the running game there; More ▸ Set Breakpoint Condition… pauses only when you say so.",
}

var _dock: Control = null
var window: Window = null
var tabs: TabContainer = null
## Inspect: the object/instance tree on the left, the picked instance's values on the right.
var objects_tree: Tree = null
var values_tree: Tree = null
var watch_tree: Tree = null
var watch_input: LineEdit = null
var profile_tree: Tree = null
var breakpoints_tree: Tree = null
var paused_label: Label = null
## The object type the reader picked in the Inspect tab, or "" for "whatever this sheet is about".
var _picked_object: String = ""
## The last streamed frame, so switching tabs redraws what is on screen instead of blanking it.
var _last_values: Dictionary = {}


func _init(dock: Control) -> void:
	_dock = dock


## Opens the window, building it the first time. `tab` names which tab to land on, so Debug layout
## can arm the debugger and open it on Profile while View ▸ Debugger opens it where it was left.
func open(tab: String = "") -> void:
	ensure_window()
	# Frames that streamed BEFORE this window existed were delivered to the Live Values panel and
	# nowhere else, so opening the debugger mid-run has to take the latest one from there. Without
	# this, the first thing a reader sees after opening it during a run is "no running game".
	if _last_values.is_empty() and _dock != null:
		_last_values = _dock._ensure_live_values_panel()._last_values.duplicate()
	var index: int = TAB_TITLES.find(tab)
	if index >= 0:
		tabs.current_tab = index
	refresh()
	window.popup_centered(Vector2i(720, 520))


func ensure_window() -> void:
	if window != null:
		return
	window = Window.new()
	window.title = "Debugger"
	window.size = Vector2i(720, 520)
	window.close_requested.connect(func() -> void: window.hide())
	tabs = TabContainer.new()
	tabs.name = "EventSheetDebuggerTabs"
	tabs.set_anchors_preset(Control.PRESET_FULL_RECT)
	tabs.add_child(_build_inspect_tab())
	tabs.add_child(_build_watch_tab())
	tabs.add_child(_build_profile_tab())
	tabs.add_child(_build_breakpoints_tab())
	for index: int in range(TAB_TITLES.size()):
		tabs.set_tab_title(index, TAB_TITLES[index])
	tabs.tab_changed.connect(func(_index: int) -> void: refresh())
	# The margin wrapper is what the window actually holds, so IT is the thing that has to fill the
	# window - anchoring the TabContainer inside a container that does not fill leaves four tabs in
	# the top-left corner of an empty window.
	var margined: MarginContainer = EventSheetPopupUI.margined(tabs)
	margined.set_anchors_preset(Control.PRESET_FULL_RECT)
	window.add_child(margined)
	_dock.add_child(window)
	# A window parented to the dock inherits the plugin's translation domain through the tree, but
	# claiming it here is what the dock's other detached windows do and what keeps a language switch
	# from stopping at the window's edge.
	EventSheetL10n.apply_to(window)


## ── Inspect ───────────────────────────────────────────────────────────────────────────────────
func _build_inspect_tab() -> Control:
	var split: HSplitContainer = HSplitContainer.new()
	split.name = "Inspect"
	var objects_box: VBoxContainer = EventSheetPopupUI.form_box()
	objects_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	objects_tree = Tree.new()
	objects_tree.hide_root = true
	objects_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	objects_tree.custom_minimum_size = Vector2(0.0, 240.0)
	objects_tree.item_selected.connect(_on_object_picked)
	objects_box.add_child(objects_tree)
	var objects_card: PanelContainer = EventSheetPopupUI.titled_card("Objects", objects_box)
	objects_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	objects_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(objects_card)
	var values_box: VBoxContainer = EventSheetPopupUI.form_box()
	values_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	values_box.add_child(EventSheetPopupUI.hint_label(
		"Double-click a value to change it in the running game. A behavior's own values are shown but not editable."))
	values_tree = Tree.new()
	values_tree.hide_root = true
	values_tree.columns = 2
	values_tree.set_column_title(0, "Variable")
	values_tree.set_column_title(1, "Value")
	values_tree.column_titles_visible = true
	values_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	values_tree.custom_minimum_size = Vector2(0.0, 240.0)
	values_tree.item_edited.connect(_on_value_edited)
	values_box.add_child(values_tree)
	var values_card: PanelContainer = EventSheetPopupUI.titled_card("Instance values", values_box)
	values_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	values_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(values_card)
	return split


## The Objects side of Inspect: one row per object type this sheet talks about, with its running
## instance count, and the sheet's own variables under a row of their own. Derived from the census
## the Object bar already builds, so the two surfaces never disagree about what this sheet is about.
static func object_rows(census: Array, values: Dictionary) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for entry: Variant in census:
		var label: String = str((entry as Dictionary).get("label", ""))
		if label.is_empty():
			continue
		rows.append({
			"label": label,
			"kind": str((entry as Dictionary).get("kind", "")),
			"live": _live_section_for(label, values),
		})
	return rows


## Which streamed keys belong to one object: the behavior sections the running game reports under
## that name ("Sine.phase"), as full keys. Empty for an object the run says nothing about, which is
## how the tree knows to draw it dim rather than to promise values it does not have.
static func _live_section_for(label: String, values: Dictionary) -> PackedStringArray:
	var keys: PackedStringArray = PackedStringArray()
	for key: Variant in values.keys():
		var text: String = str(key)
		if text.contains(".") and text.get_slice(".", 0) == label:
			keys.append(text)
	keys.sort()
	return keys


func _refresh_inspect() -> void:
	if objects_tree == null:
		return
	objects_tree.clear()
	values_tree.clear()
	var sheet: EventSheetResource = _dock._current_sheet if _dock != null else null
	if sheet == null:
		return
	var census: Array = EventSheetViewportReadingRows.object_census(sheet)
	var root: TreeItem = objects_tree.create_item()
	for row: Dictionary in object_rows(census, _last_values):
		var item: TreeItem = objects_tree.create_item(root)
		var live: PackedStringArray = row["live"]
		item.set_text(0, "%s%s" % [str(row["label"]),
			"" if live.is_empty() else " (%d)" % live.size()])
		item.set_metadata(0, str(row["label"]))
		if live.is_empty():
			item.set_custom_color(0, EventSheetActiveTheme.reading().disabled_row_color)
		if str(row["label"]) == _picked_object:
			item.select(0)
	_refresh_values()


## The picked object's values: the sheet's own variables when nothing is picked (they are what the
## sheet is about), or that object's reported section when one is.
func _refresh_values() -> void:
	if values_tree == null:
		return
	values_tree.clear()
	var root: TreeItem = values_tree.create_item()
	if _last_values.is_empty():
		var waiting: TreeItem = values_tree.create_item(root)
		waiting.set_text(0, EMPTY_STATES["Inspect"])
		waiting.set_selectable(0, false)
		return
	var section: PackedStringArray = _live_section_for(_picked_object, _last_values)
	if _picked_object.is_empty() or section.is_empty():
		var plan: Dictionary = EventSheetLiveValuesPanel.build_display_plan(_last_values)
		for key: Variant in (plan.get("plain", []) as Array):
			var item: TreeItem = values_tree.create_item(root)
			item.set_text(0, str(key))
			item.set_text(1, str(_last_values[key]))
			item.set_editable(1, true)
		return
	for key: String in section:
		var leaf: TreeItem = values_tree.create_item(root)
		leaf.set_text(0, key.get_slice(".", 1))
		leaf.set_text(1, str(_last_values[key]))
		leaf.set_editable(1, false)


func _on_object_picked() -> void:
	var selected: TreeItem = objects_tree.get_selected()
	_picked_object = str(selected.get_metadata(0)) if selected != null else ""
	_refresh_values()


## The edit-back path, the same one the Live Values window uses: a changed value is sent into the
## running game rather than written to the sheet.
func _on_value_edited() -> void:
	var edited: TreeItem = values_tree.get_edited()
	if edited == null or _dock == null:
		return
	var panel: EventSheetLiveValuesPanel = _dock._ensure_live_values_panel()
	var value: Variant = EventSheetLiveValuesDebugger.parse_edited_value(edited.get_text(1))
	if panel.debugger != null and panel.debugger.send_set_value(edited.get_text(0), value):
		_dock._set_status("Live edit: %s = %s sent to the running game." % [edited.get_text(0),
			str(value)])
	else:
		_dock._set_status("Live edit needs a streaming debug session (run the game with Live Values on).", true)


## ── Watch ─────────────────────────────────────────────────────────────────────────────────────
func _build_watch_tab() -> Control:
	var box: VBoxContainer = EventSheetPopupUI.form_box()
	box.name = "Watch"
	box.add_child(EventSheetPopupUI.hint_label(
		"Expressions over the streamed values (double-click a row to remove). The same list the Live Values window shows."))
	var row: HBoxContainer = HBoxContainer.new()
	watch_input = LineEdit.new()
	watch_input.placeholder_text = "e.g. health <= 0"
	watch_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	watch_input.text_submitted.connect(func(_text: String) -> void: _add_watch())
	row.add_child(watch_input)
	var add_button: Button = Button.new()
	add_button.text = "Watch"
	add_button.pressed.connect(_add_watch)
	row.add_child(add_button)
	box.add_child(row)
	watch_tree = Tree.new()
	watch_tree.hide_root = true
	watch_tree.columns = 2
	watch_tree.set_column_title(0, "Expression")
	watch_tree.set_column_title(1, "Value")
	watch_tree.column_titles_visible = true
	watch_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	watch_tree.custom_minimum_size = Vector2(0.0, 240.0)
	watch_tree.item_activated.connect(_remove_watch)
	box.add_child(watch_tree)
	return box


func _add_watch() -> void:
	if watch_input == null or _dock == null:
		return
	_dock._ensure_live_values_panel().add_watch(watch_input.text)
	watch_input.clear()
	_refresh_watch()


func _remove_watch() -> void:
	var selected: TreeItem = watch_tree.get_selected()
	if selected == null or _dock == null:
		return
	_dock._ensure_live_values_panel().remove_watch(str(selected.get_metadata(0)))
	_refresh_watch()


func _refresh_watch() -> void:
	if watch_tree == null or _dock == null:
		return
	watch_tree.clear()
	var root: TreeItem = watch_tree.create_item()
	for expression: String in _dock._ensure_live_values_panel().watches():
		var item: TreeItem = watch_tree.create_item(root)
		item.set_text(0, expression)
		item.set_metadata(0, expression)
		if _last_values.is_empty():
			item.set_text(1, "-")
			continue
		var verdict: Dictionary = EventSheetLiveValuesPanel.evaluate_watch(expression, _last_values)
		if bool(verdict.get("ok", false)):
			item.set_text(1, str(verdict.get("value")))
		else:
			item.set_text(1, "⚠ %s" % str(verdict.get("error", "error")))


## ── Profile ───────────────────────────────────────────────────────────────────────────────────
func _build_profile_tab() -> Control:
	var box: VBoxContainer = EventSheetPopupUI.form_box()
	box.name = "Profile"
	box.add_child(EventSheetPopupUI.hint_label(
		"Time per fire, busiest first. A fire is timed by how long it ran before the next event started in the same frame, so the last event of a frame is counted but not timed - it reads \"-\" rather than 0."))
	profile_tree = Tree.new()
	profile_tree.hide_root = true
	profile_tree.columns = 4
	profile_tree.set_column_title(0, "Event")
	profile_tree.set_column_title(1, "Per fire")
	profile_tree.set_column_title(2, "Share of run")
	profile_tree.set_column_title(3, "Fires")
	profile_tree.column_titles_visible = true
	profile_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	profile_tree.custom_minimum_size = Vector2(0.0, 240.0)
	profile_tree.item_activated.connect(_jump_to_profile_row)
	box.add_child(profile_tree)
	return box


func _refresh_profile() -> void:
	if profile_tree == null:
		return
	profile_tree.clear()
	var root: TreeItem = profile_tree.create_item()
	if not EventSheetTraceTimings.has_run():
		var empty: TreeItem = profile_tree.create_item(root)
		empty.set_text(0, EMPTY_STATES["Profile"])
		empty.set_selectable(0, false)
		return
	var numbers: Dictionary = _event_numbers()
	for row: Dictionary in EventSheetTraceTimings.rows(numbers):
		var item: TreeItem = profile_tree.create_item(root)
		var number: int = int(row.get("event_number", 0))
		item.set_text(0, ("event %d" % number) if number > 0 else str(row.get("uid", "")))
		item.set_metadata(0, str(row.get("uid", "")))
		var ms: float = float(row.get("ms", -1.0))
		item.set_text(1, "-" if ms < 0.0 else "%.2f ms" % ms)
		item.set_text(2, "%d%%" % int(round(float(row.get("share", 0.0)) * 100.0)))
		item.set_text(3, EventSheetTraceHitCounts.format_count(int(row.get("calls", 0))))
		if EventSheetTraceHitCounts.is_hot(str(row.get("uid", ""))):
			item.set_custom_color(0, EventSheetActiveTheme.reading().debugger_accent_color)


## uid -> the event number the sheet shows, for every event of the open sheet. The profile speaks
## in the sheet's numbers, never in uids, wherever it can.
func _event_numbers() -> Dictionary:
	var numbers: Dictionary = {}
	var view: EventSheetViewport = _dock._active_view() if _dock != null else null
	if view == null:
		return numbers
	for entry: Variant in view.get_flat_rows():
		var row_data: EventRowData = (entry as Dictionary).get("row")
		if row_data == null or row_data.event_number <= 0:
			continue
		if row_data.source_resource is EventRow:
			numbers[(row_data.source_resource as EventRow).event_uid] = row_data.event_number
	return numbers


func _jump_to_profile_row() -> void:
	var selected: TreeItem = profile_tree.get_selected()
	if selected != null and _dock != null:
		_dock.reveal_paused_row(str(selected.get_metadata(0)))


## ── Breakpoints ───────────────────────────────────────────────────────────────────────────────
func _build_breakpoints_tab() -> Control:
	var box: VBoxContainer = EventSheetPopupUI.form_box()
	box.name = "Breakpoints"
	paused_label = Label.new()
	paused_label.name = "EventSheetDebuggerPaused"
	box.add_child(paused_label)
	box.add_child(EventSheetPopupUI.hint_label(
		"Tick to arm a row, untick to leave it in place but inactive; double-click to go to it."))
	breakpoints_tree = Tree.new()
	breakpoints_tree.hide_root = true
	breakpoints_tree.columns = 2
	breakpoints_tree.set_column_title(0, "On")
	breakpoints_tree.set_column_title(1, "Event")
	breakpoints_tree.column_titles_visible = true
	breakpoints_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	breakpoints_tree.custom_minimum_size = Vector2(0.0, 240.0)
	breakpoints_tree.item_edited.connect(_on_breakpoint_toggled)
	breakpoints_tree.item_activated.connect(_jump_to_breakpoint)
	box.add_child(breakpoints_tree)
	return box


## The breakpoint rows of a sheet: every event carrying debug_break, in reading order, as
## {uid, event_number, condition}. Pure over the flattened rows, so the suite pins the list without
## a viewport of its own.
static func breakpoint_rows(flat_rows: Array) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for entry: Variant in flat_rows:
		var row_data: EventRowData = (entry as Dictionary).get("row")
		if row_data == null or not (row_data.source_resource is EventRow):
			continue
		var event_row: EventRow = row_data.source_resource as EventRow
		if not event_row.debug_break:
			continue
		rows.append({
			"uid": event_row.event_uid,
			"event_number": row_data.event_number,
			"condition": event_row.debug_break_condition.strip_edges(),
		})
	return rows


## The label one breakpoint row reads as. "event 12" alone where it always pauses, and
## "event 12 - when health <= 0" where it does not, because a conditional breakpoint that looked
## like an unconditional one is the reason somebody spends ten minutes wondering why nothing stopped.
static func breakpoint_text(row: Dictionary) -> String:
	var number: int = int(row.get("event_number", 0))
	var label: String = ("event %d" % number) if number > 0 else str(row.get("uid", ""))
	var condition: String = str(row.get("condition", "")).strip_edges()
	return label if condition.is_empty() else "%s - when %s" % [label, condition]


func _refresh_breakpoints() -> void:
	if breakpoints_tree == null:
		return
	breakpoints_tree.clear()
	paused_label.text = "" if _dock._paused_row_uid.is_empty() else \
		"⏸ Paused at %s" % _paused_text()
	var root: TreeItem = breakpoints_tree.create_item()
	var view: EventSheetViewport = _dock._active_view() if _dock != null else null
	var rows: Array[Dictionary] = breakpoint_rows(view.get_flat_rows() if view != null else [])
	if rows.is_empty():
		var empty: TreeItem = breakpoints_tree.create_item(root)
		empty.set_text(1, EMPTY_STATES["Breakpoints"])
		empty.set_selectable(1, false)
		return
	for row: Dictionary in rows:
		var item: TreeItem = breakpoints_tree.create_item(root)
		item.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
		item.set_editable(0, true)
		item.set_checked(0, true)
		item.set_text(1, breakpoint_text(row))
		item.set_metadata(0, str(row.get("uid", "")))


func _paused_text() -> String:
	for row: Dictionary in breakpoint_rows(
			_dock._active_view().get_flat_rows() if _dock._active_view() != null else []):
		if str(row.get("uid", "")) == _dock._paused_row_uid:
			return breakpoint_text(row)
	return _dock._paused_row_uid


## Unticking a row clears its breakpoint on the sheet - the same thing F9 does, reached from the
## list instead of from the row.
func _on_breakpoint_toggled() -> void:
	var edited: TreeItem = breakpoints_tree.get_edited()
	if edited == null or edited.is_checked(0) or _dock == null:
		return
	var uid: String = str(edited.get_metadata(0))
	var event_row: EventRow = EventSheetDock._find_event_by_uid(
		_dock._current_sheet.events if _dock._current_sheet != null else [], uid)
	if event_row != null:
		event_row.debug_break = false
	var view: EventSheetViewport = _dock._active_view()
	if view != null:
		view.get_shared_state().breakpoint_rows.erase(uid)
		view.queue_redraw()
	_refresh_breakpoints()


func _jump_to_breakpoint() -> void:
	var selected: TreeItem = breakpoints_tree.get_selected()
	if selected != null and _dock != null:
		_dock.reveal_paused_row(str(selected.get_metadata(0)))


## ── The feeds ─────────────────────────────────────────────────────────────────────────────────
## One streamed values frame. Held even while the window is closed, so opening it mid-run shows the
## run rather than an empty table.
func update_values(values: Dictionary) -> void:
	_last_values = values
	if window != null and window.visible:
		refresh()


## The run ended: the last frame is history now, and a table still stamping it "live" would be
## answering questions about a game that is not running.
func clear_live_values() -> void:
	_last_values = {}
	if window != null and window.visible:
		refresh()


## Redraws whichever tab is showing. Only that one: rebuilding four trees on every 0.25 s frame
## would spend the reader's editor on three tables nobody is looking at.
func refresh() -> void:
	if tabs == null:
		return
	match tabs.current_tab:
		0:
			_refresh_inspect()
		1:
			_refresh_watch()
		2:
			_refresh_profile()
		3:
			_refresh_breakpoints()
