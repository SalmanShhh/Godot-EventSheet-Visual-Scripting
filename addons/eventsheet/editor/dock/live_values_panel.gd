# Godot EventSheets - the Live Values panel (dock subsystem)
#
# Extracted from EventSheetDock (decomposition arc, step 3): the per-pane chip forwarding, the
# watch list and the mode trail the streamed frames feed. It opens no window of its own: a running
# object's values are Godot's own Debugger > Remote, and the sheet shows them beside its variable rows.
# The Debugger window reads its watch list and its watch table from here. The dock forwards its
# historical field/method names here so the test surface and the plugin wiring are unchanged.
@tool
class_name EventSheetLiveValuesPanel
extends RefCounted

## How many transitions the trail keeps. Enough to answer how the game reached the mode it is stuck
## in; not so many that the line stops being readable.
const MODE_TRAIL_LENGTH: int = 8

## The words Expression understands on its own, which are therefore never a missing streamed value.
const EXPRESSION_WORDS: PackedStringArray = ["true", "false", "null", "PI", "TAU", "INF", "NAN",
	"and", "or", "not", "in", "self"]

var _dock: Control = null
var debugger: EventSheetLiveValuesDebugger = null

## Watch expressions (session-scoped): evaluated editor-side against each streamed values
## frame via Expression, so you can watch any expression over the sheet's variables, live.
var _watches: Array[String] = []
var _last_values: Dictionary = {}

## Where the game has BEEN: every mode it changed to, in order, as the streamed frames go past.
## Kept here rather than recorded in the game, because the editor is already being told the mode
## every quarter second and a game should not carry a history nobody reads to play it. Mode bugs are
## invisibility bugs - nothing crashed, the group just never ran - and "how did we get here" is the
## question they present as.
var _mode_trail: PackedStringArray = PackedStringArray()


func _init(dock: Control) -> void:
	_dock = dock


## One streamed frame -> the trail. Only a CHANGE is recorded: the frames arrive four times a
## second and a trail of the same mode eighty times answers nothing.
func note_mode(values: Dictionary) -> void:
	var now: String = str(values.get("mode", "")).strip_edges()
	if now.is_empty():
		return
	if not _mode_trail.is_empty() and _mode_trail[_mode_trail.size() - 1] == now:
		return
	_mode_trail.append(now)
	while _mode_trail.size() > MODE_TRAIL_LENGTH:
		_mode_trail.remove_at(0)


## How the game got where it is: "Menu › Playing › Cutscene". Empty until a mode has streamed, and
## static over the trail so the sentence is pinned without a debug session.
static func trail_reading(trail: PackedStringArray) -> String:
	var said: PackedStringArray = PackedStringArray()
	for member: String in trail:
		said.append(EventSheetModeFacts.word_for(member))
	return " › ".join(said)


## How the game got where it is, as the trail line in the Debugger's Trail tab says it. Empty until
## a mode has streamed.
func mode_trail_text() -> String:
	return trail_reading(_mode_trail)


## Toggles live-value streaming for this sheet (debug compiles send variable frames: the chips beside
## the variable rows, the Debugger's Watch and Trail, the Why panel and Live Edit read them). Recompile
## and run to start streaming.
func toggle() -> void:
	if _dock._current_sheet == null:
		return
	_dock._current_sheet.emit_live_values = not _dock._current_sheet.emit_live_values
	if _dock._current_sheet.emit_live_values:
		_dock._set_status("Live Values ON: recompile and run - values show beside the variable rows and in the Debugger's Watch and Trail; Godot's own Debugger > Remote lists every object's variables.")
	else:
		_dock._set_status("Live Values OFF (recompile to remove the stream).")


## The open sheet's file name, for the Debugger window's title ("Debug player.gd while it runs").
static func sheet_file(dock: Control) -> String:
	return str(dock._current_sheet_path).get_file() if dock != null else ""


## The foot the Debugger window carries: the sentence that says how to use the window, then Close.
static func footer(host: Window, words: String) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	var said: Label = EventSheetPopupUI.hint_label(words, 0.0)
	said.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(said)
	var close: Button = Button.new()
	close.text = EventSheetL10n.translate("Close")
	close.pressed.connect(host.hide)
	row.add_child(close)
	return row


## The Watch card the Debugger's Watch tab draws: the hint, the input row and the table. Returns
## {root, input, button, tree} for the caller to wire to the one shared list.
static func watch_card(hint: String, titled: bool = true) -> Dictionary:
	var box: VBoxContainer = EventSheetPopupUI.form_box()
	box.add_child(EventSheetPopupUI.hint_label(hint, 0.0))
	var row: HBoxContainer = HBoxContainer.new()
	var input: LineEdit = LineEdit.new()
	input.placeholder_text = "e.g. health <= 0"
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(input)
	var button: Button = Button.new()
	button.text = "Watch"
	row.add_child(button)
	box.add_child(row)
	var table: Tree = EventSheetPopupUI.table(PackedStringArray(["Expression", "Value"]), 80.0)
	box.add_child(table)
	var card: PanelContainer = EventSheetPopupUI.titled_card("Watch", box) if titled \
		else EventSheetPopupUI.panel_section(box)
	card.size_flags_vertical = Control.SIZE_FILL if titled else Control.SIZE_EXPAND_FILL
	return {"root": card, "input": input, "button": button, "tree": table}


## Debugger-plugin sink (wired by the plugin entry point): one values frame -> the inline chips next
## to variable rows in every pane (rung 3), the mode trail, and the frame the watches read.
func update_values(values: Dictionary, instance: String = "") -> void:
	for pane: EventSheetViewport in [_dock._viewport, _dock._multi_view._split_viewport, _dock._detached_viewport]:
		if pane != null:
			pane.set_live_values(values, instance)
	# How the game got to the mode it is in: recorded here at no cost to the game, because the
	# editor was told the mode anyway, and shown on the Debugger's Trail tab.
	note_mode(values)
	_last_values = values


## The watch list, shared by the Debugger window's Watch tab and the Why didn't this fire? panel's
## "watch this" button, so the two cannot disagree about what is being watched.
func watches() -> Array[String]:
	return _watches.duplicate()


## Adds an expression from anywhere (the Debugger's box, or the Why panel). Duplicates and blanks
## are dropped rather than added twice.
func add_watch(expression: String) -> void:
	var wanted: String = expression.strip_edges()
	if wanted.is_empty() or _watches.has(wanted):
		return
	_watches.append(wanted)


func remove_watch(expression: String) -> void:
	if _watches.has(expression):
		_watches.erase(expression)


## The run ended: the last streamed frame is history now, not live. Anything that reads
## `_last_values` to decide whether it is looking at a running game (the Why didn't this fire?
## panel) has to see the emptiness, or it stamps minutes-old numbers "live".
func clear_live_values() -> void:
	_last_values = {}
	# The row chips are the other half of "this is no longer live" - a labelled chip left over from
	# a finished run would go on naming a window that is not there any more.
	for pane: EventSheetViewport in [_dock._viewport, _dock._multi_view._split_viewport, _dock._detached_viewport]:
		if pane != null:
			pane.clear_live_values()


## The one watch table the Debugger window draws. A watch that cannot be read says so in the warning tone
## and says WHY on its own line under it, rather than packing an engine error into the value cell.
static func fill_watch_tree(table: Tree, expressions: Array[String], values: Dictionary) -> void:
	table.clear()
	var root: TreeItem = table.create_item()
	var warning: Color = EventSheetPopupUI.tone_color(EventSheetPopupUI.TONE_WARNING)
	for expression: String in expressions:
		var item: TreeItem = table.create_item(root)
		item.set_text(0, expression)
		item.set_metadata(0, expression)
		if values.is_empty():
			item.set_text(1, "-")
			continue
		var verdict: Dictionary = evaluate_watch(expression, values)
		if bool(verdict.get("ok", false)):
			item.set_text(1, str(verdict.get("value")))
			continue
		item.set_text(1, EventSheetL10n.translate("cannot read"))
		item.set_custom_color(1, warning)
		var why: TreeItem = item.create_child()
		why.set_text(0, str(verdict.get("error", "")))
		why.set_custom_color(0, warning)
		why.set_selectable(0, false)
		why.set_selectable(1, false)


## Evaluates a watch expression against a streamed values dict (variable name -> value), via
## Expression. Returns {ok: true, value: Variant} or {ok: false, error: String}. Pure + static,
## so it is unit-testable without a debug session.
static func evaluate_watch(expression: String, values: Dictionary) -> Dictionary:
	if expression.strip_edges().is_empty():
		return {"ok": false, "error": "empty expression"}
	var expr: Expression = Expression.new()
	var names: PackedStringArray = PackedStringArray()
	var inputs: Array = []
	for key: Variant in values.keys():
		# Behavior debugger sections stream dotted keys ("Sine.phase") - not valid Expression
		# identifiers, so they'd poison the parse for EVERY watch. Sheet variables only here.
		if not str(key).is_valid_identifier():
			continue
		names.append(str(key))
		inputs.append(values[key])
	if expr.parse(expression, names) != OK:
		return {"ok": false, "error": expr.get_error_text()}
	var result: Variant = expr.execute(inputs, null, false)
	if expr.has_execute_failed():
		var missing: String = missing_name(expression, names)
		return {"ok": false, "error": expr.get_error_text() if missing.is_empty() \
			else EventSheetL10n.translate("%s is not a streamed value.") % missing}
	return {"ok": true, "value": result}


## The first plain name in `expression` that is neither a streamed value nor one of Expression's own
## words - what the engine reports only as "self can't be used because instance is null". A name
## followed by "(" is a function call and a name after "." is a member, so neither counts.
static func missing_name(expression: String, names: PackedStringArray) -> String:
	var words: RegEx = RegEx.create_from_string("(?<![\\w.])([A-Za-z_]\\w*)\\b(?!\\s*\\()")
	for found: RegExMatch in words.search_all(expression):
		var word: String = found.get_string(1)
		if not names.has(word) and not EXPRESSION_WORDS.has(word):
			return word
	return ""
