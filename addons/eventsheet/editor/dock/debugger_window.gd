# EventSheet - EventSheetDebuggerWindow: ONE debugger, five tabs.
#
# Everything this window shows already shipped, and that is the point of it. Live Values, the Watch
# box, the Event Trace and its hit counts, and F9 breakpoints were four separate panels and toggles
# scattered across two menus, and a reader arriving from another event-sheet editor went looking
# for one window with tabs and found none. So: one window, the names they expect, and every tab a
# thin view over a seam that was already there.
#
#   Inspect      every object type this sheet talks about, its running instances, and - for the one
#                you pick - its instance variables (EDITABLE, straight into the running game) and
#                its behaviors' values, over the Live Values stream
#   Watch        the existing watch box, sharing ONE list of expressions with the Live Values
#                window rather than keeping a second one that quietly disagrees with it
#   Profile      per-event and per-function time from the Event Trace timings, busiest first, with
#                each row's share of the run
#   Trail        what this object's state machine has just done, as past-tense sentences in the
#                sheet's own grammar, each one a door to the row it names
#   Breakpoints  the F9 rows, with enable / disable / jump, and where the run is paused right now
#
# THE ONE RULE they all obey: nothing is drawn that no run has reported. An empty tab says what to
# do to fill it ("run the game with Live Values on"), because a table of zeroes and a table of
# "nothing has happened yet" look identical and only one of them is true.
@tool
class_name EventSheetDebuggerWindow
extends RefCounted

## The tabs, in the order they are shown. The words are the ones a reader arrives holding. Trail
## sits beside Profile because the two of them read the same run: one says what it cost, the other
## says what it did.
const TAB_TITLES: Array[String] = ["Inspect", "Watch", "Profile", "Trail", "Breakpoints"]

## What each tab says before a run has reported anything. Never a table of zeroes: "nothing has
## happened yet" and "everything is zero" look the same and only one of them is true.
const EMPTY_STATES := {
	"Inspect": "No running game. Turn on Tools ▸ Live Values, then run - every object this sheet talks about appears here with its instances, and you can edit their values live.",
	"Watch": "Watch any expression over the sheet's variables - health <= 0, score + lives - and see it flip while the game runs.",
	"Profile": "No traced run yet. Turn on Tools ▸ Event Trace, then run - every event that fires is timed here, busiest first.",
	"Trail": "No run has reported a state yet. Declare states on the sheet head, turn on Tools ▸ Live Values, then run - every change of state is written here as a sentence. Turn on Tools ▸ Event Trace as well and each one names the row that did it.",
	"Breakpoints": "No breakpoints. Select a row and press F9 to pause the running game there; More ▸ Set Breakpoint Condition… pauses only when you say so.",
}

## The Trail tab's two hints. Constants because the preview harness photographs the tab and must
## show the words the tab really carries, not a second copy of them.
const TRAIL_HINT: String = "What this object's state machine has done, oldest first - it reads down, like the sheet. Double-click a line to go to the row it names. Each moment is counted off the game's report frames, so it is accurate to a quarter of a second and no finer. The game reports one state per running copy without saying which node sent it, so this describes ONE running object: with several stateful objects alive at once their reports interleave here."
const TRAIL_PATTERNS_HINT: String = "Read from the trail above and from nothing else."

## What the patterns list says when the trail raised none - which is the ordinary case, and worth
## saying so it does not read as a panel that failed to load.
const TRAIL_NO_PATTERNS: String = "Nothing to point at in this trail."

## And what the list says for a run that HAS reported a state and never changed it. A machine that
## stayed put and a machine nobody watched are two different answers, and only one of them is empty.
const TRAIL_RESTING: String = "No change of state in this run yet."

var _dock: Control = null
var window: Window = null
var tabs: TabContainer = null
## Inspect: the object/instance tree on the left, the picked instance's values on the right.
var objects_tree: Tree = null
var values_tree: Tree = null
var watch_tree: Tree = null
var watch_input: LineEdit = null
var profile_tree: Tree = null
## Trail: the sentences, and under them the patterns read out of those same sentences.
var trail_tree: Tree = null
var trail_patterns_tree: Tree = null
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
	tabs.add_child(_build_trail_tab())
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


## ── Trail ─────────────────────────────────────────────────────────────────────────────────────
## The state machine's own past, as sentences. Deliberately a LIST and nothing else: no timeline, no
## scrubber, no replay and no picture. A state is a variable, so what it did is a list of sentences
## about a variable, which is the shape every reader of this plugin already knows.
## The tab's body, built without a window, a dock or a run behind it: the sentences, and under them
## the patterns read out of those same sentences. Static so the preview harness photographs the tab
## itself rather than a second drawing of it. Returns {root, sentences, patterns}.
static func build_trail_body() -> Dictionary:
	var box: VBoxContainer = EventSheetPopupUI.form_box()
	box.name = "Trail"
	box.add_child(EventSheetPopupUI.hint_label(TRAIL_HINT))
	var sentences: Tree = Tree.new()
	sentences.hide_root = true
	sentences.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sentences.custom_minimum_size = Vector2(0.0, 200.0)
	box.add_child(sentences)
	var patterns_box: VBoxContainer = EventSheetPopupUI.form_box()
	patterns_box.add_child(EventSheetPopupUI.hint_label(TRAIL_PATTERNS_HINT))
	var patterns: Tree = Tree.new()
	patterns.hide_root = true
	patterns.custom_minimum_size = Vector2(0.0, 128.0)
	patterns_box.add_child(patterns)
	box.add_child(EventSheetPopupUI.titled_card("What this trail shows", patterns_box))
	return {"root": box, "sentences": sentences, "patterns": patterns}


func _build_trail_tab() -> Control:
	var body: Dictionary = build_trail_body()
	trail_tree = body["sentences"]
	trail_patterns_tree = body["patterns"]
	trail_tree.item_activated.connect(_jump_to_trail_row)
	trail_patterns_tree.item_activated.connect(_jump_to_trail_pattern)
	return body["root"]


## Fill the two trees from a ring and the sheet's own index. Static and handed everything it draws,
## so the tab and the preview cannot show two different trails.
##
## `standing` is what the band is reading right now, which is the difference between a machine that
## has stayed put and a machine nobody watched: a run reporting Chase and never leaving it is not an
## empty table, and an empty table is what it would otherwise look like.
##
## `home` is the sheet in front right now. A line's cause was found in whatever sheet was in front
## when its frame arrived, so a line read against another document keeps its sentence and loses its
## door rather than pointing a reader at a row of an object it was never about.
static func fill_trail(sentences: Tree, patterns: Tree, ring: Array, rows: Dictionary,
		has_run: bool, standing: String, home: String = "") -> void:
	sentences.clear()
	patterns.clear()
	var root: TreeItem = sentences.create_item()
	if not has_run:
		var empty: TreeItem = sentences.create_item(root)
		empty.set_text(0, EMPTY_STATES["Trail"])
		empty.set_autowrap_mode(0, TextServer.AUTOWRAP_WORD_SMART)
		empty.set_selectable(0, false)
		patterns.create_item()
		return
	if ring.is_empty():
		var resting: TreeItem = sentences.create_item(root)
		resting.set_text(0, TRAIL_RESTING if standing.is_empty() \
			else "%s · %s" % [TRAIL_RESTING, standing])
		resting.set_selectable(0, false)
	for entry: Variant in ring:
		var line: TreeItem = sentences.create_item(root)
		line.set_text(0, EventSheetStateTrail.sentence(entry as Dictionary))
		var read_in: String = str((entry as Dictionary).get(EventSheetStateTrail.HOME_KEY, ""))
		line.set_metadata(0, "" if read_in != home \
			else str((entry as Dictionary).get("cause_uid", "")))
	var patterns_root: TreeItem = patterns.create_item()
	var notes: Array[Dictionary] = EventSheetStateTrail.notes_for(ring, rows)
	if notes.is_empty():
		var quiet: TreeItem = patterns.create_item(patterns_root)
		quiet.set_text(0, TRAIL_NO_PATTERNS)
		quiet.set_selectable(0, false)
		return
	for note: Dictionary in notes:
		var item: TreeItem = patterns.create_item(patterns_root)
		item.set_text(0, str(note.get("text", "")))
		# A note is a SENTENCE, so it wraps rather than running off the right edge into an ellipsis -
		# the half a truncated note loses is always the half that names the second row.
		item.set_autowrap_mode(0, TextServer.AUTOWRAP_WORD_SMART)
		item.set_metadata(0, str(note.get("uid", "")))
		item.set_custom_color(0, EventSheetActiveTheme.reading().debugger_accent_color)


func _refresh_trail() -> void:
	if trail_tree == null:
		return
	fill_trail(trail_tree, trail_patterns_tree, EventSheetStateTrail.all_entries(),
		EventSheetStateFacts.trail_rows(_dock._current_sheet if _dock != null else null),
		EventSheetStateTrail.has_run(), EventSheetStateWatch.band_reading(),
		str(_dock._current_sheet_path) if _dock != null else "")


func _jump_to_trail_row() -> void:
	var selected: TreeItem = trail_tree.get_selected()
	if selected != null and _dock != null:
		_dock.reveal_event_row(str(selected.get_metadata(0)))


func _jump_to_trail_pattern() -> void:
	var selected: TreeItem = trail_patterns_tree.get_selected()
	if selected != null and _dock != null:
		_dock.reveal_event_row(str(selected.get_metadata(0)))


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
			_refresh_trail()
		4:
			_refresh_breakpoints()
