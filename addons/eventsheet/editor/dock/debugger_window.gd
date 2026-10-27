# EventSheet - EventSheetDebuggerWindow: ONE debugger, five tabs.
#
# Everything this window shows already shipped, and that is the point of it. Live Values, the Watch
# box, the Event Trace and its hit counts, and F9 breakpoints were four separate panels and toggles
# scattered across two menus, and a reader arriving from another event-sheet editor went looking
# for one window with tabs and found none. So: one window, the names they expect, and every tab a
# thin view over a seam that was already there.
#
#   Inspect      the sheet's own variables, every object type this sheet talks about, and - for the
#                one you pick - its values (the sheet's are EDITABLE, straight into the running game;
#                a behavior's are read-only), over the Live Values stream
#   Watch        the existing watch box, sharing ONE list of expressions (and one table) with the
#                Live Values window rather than keeping a second one that quietly disagrees with it
#   Profile      per-event and per-function time from the Event Trace timings, busiest first, with
#                each row's share of the run drawn as a thin bar under it
#   Trail        what this object's state machine has just done, as past-tense sentences in the
#                sheet's own grammar, each one a door to the row it names
#   Breakpoints  the F9 rows, with enable / disable / jump
#
# Over every tab sits the RUN BAND - the sheet, whether a run is reporting, which streams are on, and
# where the run is paused - so the one fact a reader opened the window for is never a tab away.
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

## The Trail tab's hint. A constant because the preview harness photographs the tab and must show
## the words the tab really carries, not a second copy of them.
const TRAIL_HINT: String = "What this object's state machine has done, oldest first. Double-click a line to go to the row it names."

## What the trail cannot know, on the hint's hover card rather than on screen all the time.
const TRAIL_LIMITS: String = "Each moment is counted off the game's report frames, so it is accurate to a quarter of a second and no finer. The game reports one state per running copy without saying which node sent it, so this describes ONE running object: with several stateful objects alive at once their reports interleave here."

## What the patterns list says when the trail raised none - which is the ordinary case, and worth
## saying so it does not read as a panel that failed to load.
const TRAIL_NO_PATTERNS: String = "Nothing to point at in this trail."

## And what the list says for a run that HAS reported a state and never changed it. A machine that
## stayed put and a machine nobody watched are two different answers, and only one of them is empty.
const TRAIL_RESTING: String = "No change of state in this run yet."

var _dock: Control = null
var window: Window = null
var tabs: TabContainer = null
## The run band over the tabs: the sheet, what is streaming, and where the run is paused.
var band: EventSheetPopupUI.RowBand = null
## Inspect: the object tree on the left, the picked object's values on the right, and under them the
## strip that names the value under the cursor and says what an edit sent.
## How wide the Objects list's count column is, before the editor's scale.
const OBJECT_DETAIL_WIDTH: int = 96

var objects_tree: Tree = null
var values_tree: Tree = null
var value_strip: EventSheetPopupUI.HelpStrip = null
var _sent_line: Label = null
var watch_tree: Tree = null
var watch_input: LineEdit = null
var profile_tree: Tree = null
## Trail: the sentences, and under them the patterns read out of those same sentences.
var trail_tree: Tree = null
var trail_patterns_tree: Tree = null
var breakpoints_tree: Tree = null
## The object the reader picked in the Inspect tab, or "" for the sheet's own variables.
var _picked_object: String = ""
## The last streamed frame, so switching tabs redraws what is on screen instead of blanking it.
var _last_values: Dictionary = {}
## Breakpoints the reader has ticked or unticked in the list, by event uid: they stay listed
## whatever their state, so an unticked one can be ticked again. Kept even after a re-arm, because
## an undo past that re-arm leaves the event disarmed and it must not drop out of the list then.
## Belongs to one sheet - `_disarmed_sheet` - and is forgotten when another sheet is shown.
var _disarmed: Dictionary = {}
var _disarmed_sheet: String = ""


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
	window.popup_centered(Vector2i(720, 620))


func ensure_window() -> void:
	if window != null:
		return
	window = Window.new()
	window.title = EventSheetL10n.translate("Debugger")
	window.size = Vector2i(720, 620)
	window.close_requested.connect(window.hide)
	var column: VBoxContainer = VBoxContainer.new()
	band = EventSheetPopupUI.RowBand.new()
	band.name = "EventSheetDebuggerRunBand"
	band.note_label.add_theme_color_override("font_color",
		EventSheetPopupUI.tone_color(EventSheetPopupUI.TONE_WARNING))
	column.add_child(band)
	tabs = TabContainer.new()
	tabs.name = "EventSheetDebuggerTabs"
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(tabs)
	column.add_child(EventSheetLiveValuesPanel.footer(window,
		EventSheetL10n.translate("Nothing is drawn that no run has reported.")))
	tabs.add_child(_build_inspect_tab())
	tabs.add_child(_build_watch_tab())
	tabs.add_child(_build_profile_tab())
	tabs.add_child(_build_trail_tab())
	tabs.add_child(_build_breakpoints_tab())
	for index: int in range(TAB_TITLES.size()):
		tabs.set_tab_title(index, TAB_TITLES[index])
	tabs.tab_changed.connect(func(_index: int) -> void: refresh())
	# The painted body fills the window, so a light editor theme shows its own colour behind the cards.
	window.add_child(EventSheetPopupUI.window_body(column))
	_dock.add_child(window)
	# A window parented to the dock inherits the plugin's translation domain through the tree, but
	# claiming it here is what the dock's other detached windows do and what keeps a language switch
	# from stopping at the window's edge.
	EventSheetL10n.apply_to(window)


## A titled card that fills its share of the tab.
static func _card(title: String, content: Control) -> PanelContainer:
	var card: PanelContainer = EventSheetPopupUI.titled_card(title, content)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return card


## ── The run band ──────────────────────────────────────────────────────────────────────────────
## What the band says, as [sheet, state, paused]: the open sheet's file, whether a run is reporting
## and which of the two streams the sheet asks for, and - only while the game is paused at a row -
## the row it is paused at. Pure, so the suite pins the sentence without a window.
static func run_band(file: String, reporting: bool, live_on: bool, trace_on: bool,
		paused_at: String) -> PackedStringArray:
	var said: PackedStringArray = PackedStringArray([
		EventSheetL10n.translate("running") if reporting else EventSheetL10n.translate("no run reporting"),
		EventSheetL10n.translate("Live Values on") if live_on else EventSheetL10n.translate("Live Values off"),
		EventSheetL10n.translate("Event Trace on") if trace_on else EventSheetL10n.translate("Event Trace off"),
	])
	return PackedStringArray([file, " · ".join(said), "" if paused_at.is_empty()
		else EventSheetL10n.translate("Paused at %s") % paused_at])


func _refresh_band() -> void:
	var sheet: EventSheetResource = _dock._current_sheet if _dock != null else null
	var file: String = EventSheetLiveValuesPanel.sheet_file(_dock)
	window.title = EventSheetL10n.translate("Debugger") if file.is_empty() \
		else EventSheetL10n.translate("Debug %s while it runs") % file
	var said: PackedStringArray = run_band(file, not _last_values.is_empty(),
		sheet != null and sheet.emit_live_values, sheet != null and sheet.emit_event_trace,
		"" if _dock._paused_row_uid.is_empty() else _paused_text())
	band.show_row(said[0], said[1], said[2])


## ── Inspect ───────────────────────────────────────────────────────────────────────────────────
func _build_inspect_tab() -> Control:
	var page: VBoxContainer = EventSheetPopupUI.form_box()
	page.name = "Inspect"
	var split: HSplitContainer = HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(split)
	var objects_box: VBoxContainer = EventSheetPopupUI.form_box()
	objects_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	objects_tree = EventSheetPopupUI.table(PackedStringArray(["", ""]), 160.0)
	objects_tree.column_titles_visible = false
	# The count beside each name ("6 values", "(2)", "no report") is a column of its own, and a
	# column that does not expand is only as wide as its minimum - without one it drew nothing.
	objects_tree.set_column_expand(1, false)
	objects_tree.set_column_custom_minimum_width(1, EventSheetPalette.scaled(OBJECT_DETAIL_WIDTH))
	objects_tree.item_selected.connect(_on_object_picked)
	objects_box.add_child(objects_tree)
	objects_box.add_child(EventSheetPopupUI.hint_label(EventSheetL10n.translate(
		"Dim rows: this sheet names them, but the run has reported nothing for them yet."), 0.0))
	split.add_child(_card("Objects", objects_box))
	values_tree = EventSheetPopupUI.table(PackedStringArray(["Variable", "Value"]), 160.0)
	values_tree.item_edited.connect(_on_value_edited)
	values_tree.item_selected.connect(_describe_value)
	split.add_child(_card("Instance values", values_tree))
	value_strip = EventSheetPopupUI.help_strip()
	_sent_line = value_strip.add_line(EventSheetL10n.translate("Sent"))
	_describe_value()
	page.add_child(value_strip)
	return page


## The Objects side of Inspect: first the sheet's own variables, then one row per object type this
## sheet talks about, with the values the run reports for it (the "(N)" beside its name counts those
## values - the stream names behavior sections, never instances). Derived from the census the
## Object bar already builds, so the two surfaces never disagree about what this sheet is about.
## Each row is {label, key, kind, live, detail}; `key` is "" for the sheet's own row.
static func object_rows(census: Array, values: Dictionary) -> Array[Dictionary]:
	var own: PackedStringArray = PackedStringArray(
		EventSheetLiveValuesPanel.build_display_plan(values).get("plain", []))
	var own_detail: String = EventSheetL10n.translate("no report")
	if own.size() == 1:
		own_detail = EventSheetL10n.translate("1 value")
	elif own.size() > 1:
		own_detail = EventSheetL10n.translate("%d values") % own.size()
	var rows: Array[Dictionary] = [{
		"label": EventSheetL10n.translate("This sheet's variables"),
		"key": "",
		"kind": "sheet",
		"live": own,
		"detail": own_detail,
	}]
	for entry: Variant in census:
		var label: String = str((entry as Dictionary).get("label", ""))
		if label.is_empty():
			continue
		var live: PackedStringArray = _live_section_for(label, values)
		rows.append({
			"label": label,
			"key": label,
			"kind": str((entry as Dictionary).get("kind", "")),
			"live": live,
			"detail": ("(%d)" % live.size()) if not live.is_empty() else EventSheetL10n.translate("no report"),
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
	objects_tree.clear()
	values_tree.clear()
	var sheet: EventSheetResource = _dock._current_sheet if _dock != null else null
	if sheet == null:
		return
	var root: TreeItem = objects_tree.create_item()
	var dim: Color = EventSheetPopupUI.muted_text_color()
	for row: Dictionary in object_rows(EventSheetViewportReadingRows.object_census(sheet), _last_values):
		var item: TreeItem = objects_tree.create_item(root)
		item.set_text(0, str(row["label"]))
		item.set_text(1, str(row["detail"]))
		item.set_custom_color(1, dim)
		item.set_metadata(0, str(row["key"]))
		if (row["live"] as PackedStringArray).is_empty():
			item.set_custom_color(0, dim)
		if str(row["key"]) == _picked_object:
			item.select(0)
	_refresh_values()


## The picked object's values: the sheet's own variables when the sheet's row is picked (they are
## what the sheet is about), or that object's reported section when one is - read-only and muted,
## because a behavior's values are its own.
func _refresh_values() -> void:
	values_tree.clear()
	var root: TreeItem = values_tree.create_item()
	# With no run the table holds one sentence, not a variable and a value: it takes the whole width
	# rather than wrapping a word a line down the Variable column beside an empty Value column.
	_values_columns(not _last_values.is_empty())
	if _last_values.is_empty():
		var waiting: TreeItem = values_tree.create_item(root)
		var sheet: EventSheetResource = _dock._current_sheet if _dock != null else null
		waiting.set_text(0, inspect_empty_text(sheet != null and sheet.emit_live_values,
			EditorInterface.is_playing_scene() if Engine.is_editor_hint() else false,
			sheet != null and sheet.read_only))
		waiting.set_autowrap_mode(0, TextServer.AUTOWRAP_WORD_SMART)
		waiting.set_selectable(0, false)
		return
	var section: PackedStringArray = _live_section_for(_picked_object, _last_values)
	var keys: Array = Array(section) if not section.is_empty() \
		else EventSheetLiveValuesPanel.build_display_plan(_last_values).get("plain", [])
	for key: Variant in keys:
		var item: TreeItem = values_tree.create_item(root)
		var dotted: bool = str(key).contains(".")
		item.set_text(0, str(key).get_slice(".", 1) if dotted else str(key))
		EventSheetLiveValuesPanel.fill_value_item(item, _last_values[key], dotted)


## What the Inspect tab says while nothing has reported, from what is actually true: Live Values
## off, on and waiting for a run, or on with a game running that the sheet is not reaching. Live
## Values reaches the game through the SAVED file, so a script opened as a sheet and never saved -
## the first thing a user does with their own player.gd - runs without it, and the old sentence told
## them to turn on what was already on. Pure, so the suite pins every case without a window.
static func inspect_empty_text(live_on: bool, playing: bool, read_only: bool) -> String:
	if not live_on:
		return EventSheetL10n.translate(EMPTY_STATES["Inspect"])
	if read_only:
		return EventSheetL10n.translate("This sheet is a read-only preview, so the game runs the file as it was. Press Edit Events, save the sheet (Ctrl+S), then run again, and its values report here.")
	if playing:
		return EventSheetL10n.translate("The game is running, but this sheet has not reported. Live Values reaches the game through the saved file: save the sheet (Ctrl+S), then run again.")
	return EventSheetL10n.translate("Live Values is on for this sheet, and it reaches the game through the saved file: save the sheet (Ctrl+S), then run, and every object it talks about appears here with its instances.")


## Two titled columns (Variable, Value) while a run reports, one untitled column while it does not.
func _values_columns(reporting: bool) -> void:
	values_tree.columns = 2 if reporting else 1
	values_tree.column_titles_visible = reporting
	if reporting:
		values_tree.set_column_title(0, EventSheetL10n.translate("Variable"))
		values_tree.set_column_title(1, EventSheetL10n.translate("Value"))


func _on_object_picked() -> void:
	var selected: TreeItem = objects_tree.get_selected()
	_picked_object = str(selected.get_metadata(0)) if selected != null else ""
	_refresh_values()


## The strip names the value under the cursor and says what double-clicking it does.
func _describe_value() -> void:
	var selected: TreeItem = values_tree.get_selected()
	var said: String = EventSheetL10n.translate(
		"Double-click a value to change it in the running game. A behavior's own values are shown but not editable.")
	value_strip.describe(EventSheetL10n.translate("This value"),
		said if selected == null else "%s: %s" % [selected.get_text(0), said])


## The edit-back path, the same one the Live Values window uses: a changed value is sent into the
## running game rather than written to the sheet, and the strip says exactly what was sent.
func _on_value_edited() -> void:
	var edited: TreeItem = values_tree.get_edited()
	if edited != null and _dock != null:
		value_strip.set_line(_sent_line,
			_dock._ensure_live_values_panel().send_edit(edited.get_text(0), edited.get_text(1)))


## ── Watch ─────────────────────────────────────────────────────────────────────────────────────
## The Live Values window's own Watch card, over the same list: one card, two windows.
func _build_watch_tab() -> Control:
	var card: Dictionary = EventSheetLiveValuesPanel.watch_card(EventSheetL10n.translate(
		"Expressions over the streamed values. Double-click a row to remove it."), false)
	(card["root"] as Control).name = "Watch"
	watch_input = card["input"]
	watch_input.text_submitted.connect(func(_text: String) -> void: _add_watch())
	(card["button"] as Button).pressed.connect(_add_watch)
	watch_tree = card["tree"]
	watch_tree.item_activated.connect(_remove_watch)
	return card["root"]


func _add_watch() -> void:
	_dock._ensure_live_values_panel().add_watch(watch_input.text)
	watch_input.clear()
	_refresh_watch()


func _remove_watch() -> void:
	var selected: TreeItem = watch_tree.get_selected()
	if selected != null and selected.get_metadata(0) is String:
		_dock._ensure_live_values_panel().remove_watch(str(selected.get_metadata(0)))
		_refresh_watch()


func _refresh_watch() -> void:
	EventSheetLiveValuesPanel.fill_watch_tree(watch_tree,
		_dock._ensure_live_values_panel().watches(), _last_values)


## ── Profile ───────────────────────────────────────────────────────────────────────────────────
func _build_profile_tab() -> Control:
	var box: VBoxContainer = EventSheetPopupUI.form_box()
	box.name = "Profile"
	box.add_child(EventSheetPopupUI.hint_label(EventSheetL10n.translate(
		"Time per fire, busiest first. The last event of a frame is counted but not timed, so it reads \"-\"."), 0.0))
	profile_tree = EventSheetPopupUI.table(PackedStringArray(["Event", "Per fire", "Share", "Fires"]), 160.0)
	profile_tree.item_activated.connect(_jump_to_selected.bind(profile_tree))
	box.add_child(profile_tree)
	box.add_child(EventSheetPopupUI.hint_label(EventSheetL10n.translate(
		"Double-click a row to go to that event."), 0.0))
	return box


func _refresh_profile() -> void:
	profile_tree.clear()
	var root: TreeItem = profile_tree.create_item()
	if not EventSheetTraceTimings.has_run():
		var empty: TreeItem = profile_tree.create_item(root)
		empty.set_text(0, EventSheetL10n.translate(EMPTY_STATES["Profile"]))
		empty.set_selectable(0, false)
		return
	var rows: Array[Dictionary] = EventSheetTraceTimings.rows(_event_numbers())
	var busiest: float = 0.0
	for row: Dictionary in rows:
		busiest = maxf(busiest, float(row.get("share", 0.0)))
	for row: Dictionary in rows:
		var item: TreeItem = profile_tree.create_item(root)
		var number: int = int(row.get("event_number", 0))
		var share: float = float(row.get("share", 0.0))
		var hot: bool = EventSheetTraceHitCounts.is_hot(str(row.get("uid", "")))
		var tone: Color = EventSheetActiveTheme.reading().debugger_accent_color if hot \
			else EventSheetPopupUI.muted_text_color()
		item.set_cell_mode(0, TreeItem.CELL_MODE_CUSTOM)
		item.custom_minimum_height = int(EventSheetPalette.scaled_f(28.0))
		item.set_text(0, ("event %d" % number) if number > 0 else str(row.get("uid", "")))
		item.set_metadata(0, str(row.get("uid", "")))
		item.set_custom_draw_callback(0, _draw_share_bar.bind(
			share / busiest if busiest > 0.0 else 0.0, tone))
		var ms: float = float(row.get("ms", -1.0))
		item.set_text(1, "-" if ms < 0.0 else "%.2f ms" % ms)
		item.set_text(2, "%d%%" % int(round(share * 100.0)))
		item.set_text(3, EventSheetTraceHitCounts.format_count(int(row.get("calls", 0))))
		if hot:
			item.set_custom_color(0, tone)


## The thin share bar under an event's name: as long as its share of the run against the busiest
## event's, so the table's shape reads before a number is.
func _draw_share_bar(_item: TreeItem, rect: Rect2, fraction: float, tone: Color) -> void:
	var pad: float = EventSheetPalette.scaled_f(4.0)
	var height: float = EventSheetPalette.scaled_f(2.0)
	profile_tree.draw_rect(Rect2(rect.position.x + pad, rect.end.y - height,
		(rect.size.x - pad * 2.0) * clampf(fraction, 0.0, 1.0), height), tone)


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


## Going to a row from a list is a jump, never a pause: the run band says "Paused at" only when the
## game itself said so.
func _jump_to_selected(table: Tree) -> void:
	var selected: TreeItem = table.get_selected()
	if selected != null and _dock != null:
		_dock.reveal_event_row(str(selected.get_metadata(0)))


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
	var hint: Label = EventSheetPopupUI.hint_label(EventSheetL10n.translate(TRAIL_HINT), 0.0)
	hint.tooltip_text = EventSheetL10n.translate(TRAIL_LIMITS)
	hint.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_child(hint)
	var sentences: Tree = EventSheetPopupUI.table(PackedStringArray(), 200.0)
	box.add_child(sentences)
	var patterns: Tree = Tree.new()
	patterns.hide_root = true
	patterns.custom_minimum_size = Vector2(0.0, EventSheetPalette.scaled_f(128.0))
	box.add_child(EventSheetPopupUI.titled_card("What this trail shows", patterns))
	return {"root": box, "sentences": sentences, "patterns": patterns}


func _build_trail_tab() -> Control:
	var body: Dictionary = build_trail_body()
	trail_tree = body["sentences"]
	trail_patterns_tree = body["patterns"]
	trail_tree.item_activated.connect(_jump_to_selected.bind(trail_tree))
	trail_patterns_tree.item_activated.connect(_jump_to_selected.bind(trail_patterns_tree))
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
		empty.set_text(0, EventSheetL10n.translate(EMPTY_STATES["Trail"]))
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
		quiet.set_text(0, EventSheetL10n.translate(TRAIL_NO_PATTERNS))
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
	fill_trail(trail_tree, trail_patterns_tree, EventSheetStateTrail.all_entries(),
		EventSheetStateFacts.trail_rows(_dock._current_sheet if _dock != null else null),
		EventSheetStateTrail.has_run(), EventSheetStateWatch.band_reading(),
		str(_dock._current_sheet_path) if _dock != null else "")


## ── Breakpoints ───────────────────────────────────────────────────────────────────────────────
func _build_breakpoints_tab() -> Control:
	var box: VBoxContainer = EventSheetPopupUI.form_box()
	box.name = "Breakpoints"
	box.add_child(EventSheetPopupUI.hint_label(
		"Tick to arm a row, untick to leave it in place but inactive; double-click to go to it.", 0.0))
	breakpoints_tree = EventSheetPopupUI.table(PackedStringArray(["On", "Event"]), 160.0)
	breakpoints_tree.set_column_expand(0, false)
	breakpoints_tree.item_edited.connect(_on_breakpoint_toggled)
	breakpoints_tree.item_activated.connect(_jump_to_selected.bind(breakpoints_tree))
	box.add_child(breakpoints_tree)
	box.add_child(EventSheetPopupUI.hint_label(EventSheetL10n.translate(
		"More ▸ Set Breakpoint Condition… pauses only when you say so."), 0.0))
	return box


## The breakpoint rows of a sheet: every event carrying debug_break, plus every event whose uid is
## in `disarmed` (a breakpoint unticked in the list, kept in place but inactive), in reading order,
## as {uid, event_number, condition, armed}. Pure over the flattened rows, so the suite pins the
## list without a viewport of its own.
static func breakpoint_rows(flat_rows: Array, disarmed: Dictionary = {}) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for entry: Variant in flat_rows:
		var row_data: EventRowData = (entry as Dictionary).get("row")
		if row_data == null or not (row_data.source_resource is EventRow):
			continue
		var event_row: EventRow = row_data.source_resource as EventRow
		if not event_row.debug_break and not disarmed.has(event_row.event_uid):
			continue
		rows.append({
			"uid": event_row.event_uid,
			"event_number": row_data.event_number,
			"condition": event_row.debug_break_condition.strip_edges(),
			"armed": event_row.debug_break,
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
	breakpoints_tree.clear()
	var root: TreeItem = breakpoints_tree.create_item()
	var view: EventSheetViewport = _dock._active_view() if _dock != null else null
	var rows: Array[Dictionary] = breakpoint_rows(view.get_flat_rows() if view != null else [],
		listed_uids())
	if rows.is_empty():
		var empty: TreeItem = breakpoints_tree.create_item(root)
		empty.set_text(1, EventSheetL10n.translate(EMPTY_STATES["Breakpoints"]))
		empty.set_selectable(1, false)
		return
	for row: Dictionary in rows:
		var item: TreeItem = breakpoints_tree.create_item(root)
		item.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
		item.set_editable(0, true)
		item.set_checked(0, bool(row.get("armed", true)))
		item.set_text(1, breakpoint_text(row))
		item.set_metadata(0, str(row.get("uid", "")))


## The uids the list keeps whatever their state (see _disarmed), for the sheet shown now: a
## breakpoint touched on another sheet is not this sheet's to list.
func listed_uids() -> Dictionary:
	var sheet_key: String = str(_dock._current_sheet_path) if _dock != null else ""
	if sheet_key != _disarmed_sheet:
		_disarmed.clear()
		_disarmed_sheet = sheet_key
	return _disarmed


func _paused_text() -> String:
	var view: EventSheetViewport = _dock._active_view()
	for row: Dictionary in breakpoint_rows(view.get_flat_rows() if view != null else []):
		if str(row.get("uid", "")) == _dock._paused_row_uid:
			return breakpoint_text(row)
	return _dock._paused_row_uid


## Unticking a row disarms its breakpoint and ticking re-arms it, as one undoable sheet edit. An
## unticked row stays in the list, so the breakpoint is kept in place (with its condition) rather
## than deleted.
func _on_breakpoint_toggled() -> void:
	var edited: TreeItem = breakpoints_tree.get_edited()
	if edited == null or _dock == null:
		return
	set_breakpoint_armed(str(edited.get_metadata(0)), edited.is_checked(0))
	_refresh_breakpoints()


## Arms or disarms the breakpoint on one event through the undo funnel, and remembers it so the
## list keeps it through any later undo. Returns whether the sheet changed.
func set_breakpoint_armed(uid: String, armed: bool) -> bool:
	if _dock == null or uid.is_empty():
		return false
	var changed: bool = _dock._perform_undoable_sheet_edit(
		"Enable Breakpoint" if armed else "Disable Breakpoint", func() -> bool:
			var event_row: EventRow = EventSheetDock._find_event_by_uid(
				_dock._current_sheet.events, uid)
			if event_row == null or event_row.debug_break == armed:
				return false
			event_row.debug_break = armed
			return true
	)
	listed_uids()[uid] = true
	var view: EventSheetViewport = _dock._active_view()
	if view != null:
		if armed:
			view.get_shared_state().breakpoint_rows[uid] = true
		else:
			view.get_shared_state().breakpoint_rows.erase(uid)
		view.queue_redraw()
	return changed


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


## Redraws the band and whichever tab is showing. Only that one: rebuilding four trees on every
## 0.25 s frame would spend the reader's editor on three tables nobody is looking at.
func refresh() -> void:
	if tabs == null:
		return
	_refresh_band()
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
