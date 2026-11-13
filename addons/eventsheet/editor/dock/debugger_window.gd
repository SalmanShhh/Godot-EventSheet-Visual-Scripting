# EventSheet - EventSheetDebuggerWindow: the two things Godot's own Debugger does not have.
#
# What a running object's variables hold is Godot's own Debugger > Remote (the Scene dock's Remote
# tab), or Stack Variables while paused; breakpoints are listed in Godot's Debugger > Breakpoints;
# per-event timing is drawn on the rows themselves after Tools > Run With Profiler. So this window
# keeps only what Godot has no equal for:
#
#   Watch        an expression over the sheet's variables - health <= 0, score + lives - evaluated
#                against every streamed frame, in ONE list shared with the Why didn't this fire? panel
#   Trail        what this object's state machine has just done, as past-tense sentences in the
#                sheet's own grammar, each one a door to the row it names, with how the game got to the
#                mode it is in above them
#
# Over both sits the RUN BAND - the sheet, whether a run is reporting, which streams are on, and
# where the run is paused - so the one fact a reader opened the window for is never a tab away.
#
# THE ONE RULE they obey: nothing is drawn that no run has reported. An empty tab says what to
# do to fill it ("run the game with Live Values on"), because a table of zeroes and a table of
# "nothing has happened yet" look identical and only one of them is true.
@tool
class_name EventSheetDebuggerWindow
extends RefCounted

## The tabs, in the order they are shown.
const TAB_TITLES: Array[String] = ["Watch", "Trail"]

## What each tab says before a run has reported anything. Never a table of zeroes: "nothing has
## happened yet" and "everything is zero" look the same and only one of them is true.
const EMPTY_STATES := {
	"Watch": "Watch any expression over the sheet's variables - health <= 0, score + lives - and see it flip while the game runs.",
	"Trail": "No run has reported a state yet. Declare states on the sheet head, turn on Tools ▸ Live Values, then run - every change of state is written here as a sentence. Turn on Tools ▸ Event Trace as well and each one names the row that did it.",
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
var watch_tree: Tree = null
var watch_input: LineEdit = null
## Trail: the sentences, and under them the patterns read out of those same sentences.
var trail_tree: Tree = null
var trail_patterns_tree: Tree = null
## The line above the sentences: how the game got to the mode it is in.
var trail_modes_label: Label = null
## The last streamed frame, so switching tabs redraws what is on screen instead of blanking it.
var _last_values: Dictionary = {}


func _init(dock: Control) -> void:
	_dock = dock


## Opens the window, building it the first time. `tab` names which tab to land on ("Watch" or
## "Trail"); with none it opens where it was left.
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
	EventSheetWindowPlacement.popup_centered(window, Vector2i(720, 620))


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
	tabs.add_child(_build_watch_tab())
	tabs.add_child(_build_trail_tab())
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


## ── Jumping to a row ──────────────────────────────────────────────────────────────────────────
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
## the patterns read out of those same sentences, and above them the line saying how the game got to
## the mode it is in. Static so the preview harness photographs the tab itself rather than a second
## drawing of it. Returns {root, sentences, patterns, modes}.
static func build_trail_body() -> Dictionary:
	var box: VBoxContainer = EventSheetPopupUI.form_box()
	box.name = "Trail"
	var hint: Label = EventSheetPopupUI.hint_label(EventSheetL10n.translate(TRAIL_HINT), 0.0)
	hint.tooltip_text = EventSheetL10n.translate(TRAIL_LIMITS)
	hint.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_child(hint)
	var modes: Label = EventSheetPopupUI.hint_label("", 0.0)
	modes.visible = false
	box.add_child(modes)
	var sentences: Tree = EventSheetPopupUI.table(PackedStringArray(), 200.0)
	box.add_child(sentences)
	var patterns: Tree = Tree.new()
	patterns.hide_root = true
	patterns.custom_minimum_size = Vector2(0.0, EventSheetPalette.scaled_f(128.0))
	box.add_child(EventSheetPopupUI.titled_card("What this trail shows", patterns))
	return {"root": box, "sentences": sentences, "patterns": patterns, "modes": modes}


func _build_trail_tab() -> Control:
	var body: Dictionary = build_trail_body()
	trail_tree = body["sentences"]
	trail_patterns_tree = body["patterns"]
	trail_modes_label = body["modes"]
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
	# How the game got to the mode it is in: "Menu › Playing › Cutscene". Empty until a mode has
	# streamed, and the line stays hidden until then.
	var reading: String = _dock._ensure_live_values_panel().mode_trail_text() if _dock != null else ""
	trail_modes_label.text = EventSheetL10n.translate("How it got here: %s") % reading
	trail_modes_label.visible = not reading.is_empty()
	fill_trail(trail_tree, trail_patterns_tree, EventSheetStateTrail.all_entries(),
		EventSheetStateFacts.trail_rows(_dock._current_sheet if _dock != null else null),
		EventSheetStateTrail.has_run(), EventSheetStateWatch.band_reading(),
		str(_dock._current_sheet_path) if _dock != null else "")


## ── The paused row ─────────────────────────────────────────────────────────────────────────────
## The breakpoint rows of a sheet: every event carrying debug_break, in reading order, as {uid,
## event_number, condition, armed}. The run band names the one the game is paused at. Pure over the
## flattened rows, so the suite pins the list without a viewport of its own.
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


func _paused_text() -> String:
	var view: EventSheetViewport = _dock._active_view()
	for row: Dictionary in breakpoint_rows(view.get_flat_rows() if view != null else []):
		if str(row.get("uid", "")) == _dock._paused_row_uid:
			return breakpoint_text(row)
	return _dock._paused_row_uid


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


## Redraws the band and whichever tab is showing. Only that one: rebuilding both trees on every
## 0.25 s frame would spend the reader's editor on a table nobody is looking at.
func refresh() -> void:
	if tabs == null:
		return
	_refresh_band()
	match tabs.current_tab:
		0:
			_refresh_watch()
		1:
			_refresh_trail()
