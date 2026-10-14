# Godot EventSheets - the Live Values panel (dock subsystem)
#
# Extracted from EventSheetDock (decomposition arc, step 3): the streaming window
# (editable tree, nested containers), the per-pane chip forwarding, and the edit-back
# send path. The dock forwards its historical field/method names here so the test
# surface and the plugin wiring are unchanged. The Debugger window reads its watch list, its
# watch table and its edit-back path from here too, so the two windows cannot disagree.
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
var window: Window = null
## The status line ("Streaming from Player · every 0.25 s") and, on its own line under it, how the
## game got to the mode it is in.
var label: Label = null
var trail_label: Label = null
var tree: Tree = null
var debugger: EventSheetLiveValuesDebugger = null

## Watch expressions (session-scoped): evaluated editor-side against each streamed values
## frame via Expression, so you can watch any expression over the sheet's variables, live.
var _watches: Array[String] = []
var _last_values: Dictionary = {}
var watch_tree: Tree = null
var watch_input: LineEdit = null

## Where the game has BEEN: every mode it changed to, in order, as the streamed frames go past.
## Kept here rather than recorded in the game, because the editor is already being told the mode
## every quarter second and a game should not carry a history nobody reads to play it. Mode bugs are
## invisibility bugs - nothing crashed, the group just never ran - and "how did we get here" is the
## question they present as.
var _mode_trail: PackedStringArray = PackedStringArray()
var _leaf_signature: String = ""


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


## Toggles live-value streaming for this sheet (debug compiles send variable frames;
## the window shows them while the game runs). Recompile + run to start streaming.
func toggle() -> void:
	if _dock._current_sheet == null:
		return
	_dock._current_sheet.emit_live_values = not _dock._current_sheet.emit_live_values
	if _dock._current_sheet.emit_live_values:
		ensure_window()
		window.popup_centered()
		_dock._set_status("Live Values ON: recompile and run - variables stream every 0.25s while the debugger is attached.")
	else:
		if window != null:
			window.hide()
		_dock._set_status("Live Values OFF (recompile to remove the stream).")


## The open sheet's file name, for the two windows' titles ("Debug player.gd while it runs").
static func sheet_file(dock: Control) -> String:
	return str(dock._current_sheet_path).get_file() if dock != null else ""


## The foot both run windows share: the sentence that says how to use the window, then Close.
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


## Lazily builds the floating Live Values window the first time it's needed. Named to match
## the dock's call site (event_sheet_dock.gd: _ensure_live_values_panel().ensure_window()).
func ensure_window() -> void:
	if window != null:
		return
	window = Window.new()
	window.title = EventSheetL10n.translate("Live Values")
	window.size = Vector2i(380, 620)
	window.close_requested.connect(window.hide)
	var live_box: VBoxContainer = VBoxContainer.new()
	# Group 1 - the Live Values stream: status line + the editable values tree, in one titled card.
	var stream_box: VBoxContainer = EventSheetPopupUI.form_box()
	label = Label.new()
	label.text = EventSheetL10n.translate("Waiting for a running game…")
	stream_box.add_child(label)
	trail_label = EventSheetPopupUI.hint_label("", 0.0)
	trail_label.visible = false
	stream_box.add_child(trail_label)
	tree = Tree.new()
	tree.hide_root = true
	tree.columns = 2
	tree.set_column_title(0, "Variable")
	tree.set_column_title(1, "Value (editable)")
	tree.column_titles_visible = true
	tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tree.custom_minimum_size = Vector2(0.0, EventSheetPalette.scaled_f(160.0))
	tree.item_edited.connect(_on_live_value_edited)
	stream_box.add_child(tree)
	var stream_card: PanelContainer = EventSheetPopupUI.titled_card("Live Values", stream_box)
	stream_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	live_box.add_child(stream_card)
	# Group 2 - Watch: the hint + the input row + the watch tree, in one titled card.
	var watch_box: Dictionary = watch_card(EventSheetL10n.translate(
		"Expressions over the streamed values above. The Debugger's Watch tab shows the same list."))
	watch_input = watch_box["input"]
	watch_input.text_submitted.connect(func(_t: String) -> void: _add_watch_from_input())
	(watch_box["button"] as Button).pressed.connect(_add_watch_from_input)
	watch_tree = watch_box["tree"]
	watch_tree.item_activated.connect(_remove_selected_watch)
	live_box.add_child(watch_box["root"])
	live_box.add_child(footer(window, EventSheetL10n.translate("Double-click a value to edit it live.")))
	window.add_child(EventSheetPopupUI.window_body(live_box))
	_dock.add_child(window)


## The Watch card both windows draw: the hint, the input row and the table - titled in this window,
## untitled in the Debugger's Watch tab, whose tab already says it. Returns {root, input, button,
## tree} for the caller to wire to the one shared list.
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
	var table: Tree = Tree.new()
	table.hide_root = true
	table.columns = 2
	table.set_column_title(0, "Expression")
	table.set_column_title(1, "Value")
	table.column_titles_visible = true
	table.size_flags_vertical = Control.SIZE_EXPAND_FILL
	table.custom_minimum_size = Vector2(0.0, EventSheetPalette.scaled_f(80.0))
	box.add_child(table)
	var card: PanelContainer = EventSheetPopupUI.titled_card("Watch", box) if titled \
		else EventSheetPopupUI.panel_section(box)
	card.size_flags_vertical = Control.SIZE_FILL if titled else Control.SIZE_EXPAND_FILL
	return {"root": card, "input": input, "button": button, "tree": table}


## Debugger-plugin sink (wired by the plugin entry point): one values frame -> the
## editable tree + inline chips next to variable rows in every pane (rung 3).
func update_values(values: Dictionary, instance: String = "") -> void:
	for pane: EventSheetViewport in [_dock._viewport, _dock._multi_view._split_viewport, _dock._detached_viewport]:
		if pane != null:
			pane.set_live_values(values, instance)
	ensure_window()
	var file: String = sheet_file(_dock)
	if not file.is_empty():
		window.title = EventSheetL10n.translate("Edit %s's values while it runs") % file
	# With two copies of the game running, the tree below is whichever of them streamed last,
	# so it says which one that was. The row chips show every instance side by side.
	label.text = EventSheetL10n.translate("Streaming · every 0.25 s") if instance.is_empty() \
		else EventSheetL10n.translate("Streaming from %s · every 0.25 s") % instance
	# And how the game got to the mode it is in, on a line of its own. The single most useful line in
	# this window for a game with modes, and it costs the game nothing: the editor was told anyway.
	note_mode(values)
	var trail: String = trail_reading(_mode_trail)
	trail_label.text = EventSheetL10n.translate("How it got here: %s") % trail
	trail_label.visible = not trail.is_empty()
	# Sheet variables list flat (editable); dotted keys ("Sine.phase" - a behavior's
	# debugger_properties section, the event-sheet debugger idea) group under one read-only
	# section per behavior child, after the variables.
	var plan: Dictionary = build_display_plan(values)
	var plain_keys: Array = plan.get("plain", [])
	var sections: Dictionary = plan.get("sections", {})
	var leaf_signature: String = str(plan.get("signature", ""))
	# Rebuild only when the key set changes; otherwise update in place so an
	# in-progress edit isn't stomped by the next frame.
	if leaf_signature != _leaf_signature or tree.get_root() == null:
		_leaf_signature = leaf_signature
		tree.clear()
		var root_item: TreeItem = tree.create_item()
		for value_key: Variant in plain_keys:
			var item: TreeItem = tree.create_item(root_item)
			item.set_text(0, str(value_key))
			fill_value_item(item, values[value_key])
		for section_name: Variant in sections:
			var section_item: TreeItem = tree.create_item(root_item)
			section_item.set_text(0, str(section_name))
			section_item.set_selectable(0, false)
			section_item.set_selectable(1, false)
			section_item.set_custom_color(0, EventSheetPopupUI.accent_color())
			for full_key: Variant in sections[section_name]:
				var leaf: TreeItem = tree.create_item(section_item)
				leaf.set_text(0, str(full_key).get_slice(".", 1))
				fill_value_item(leaf, values[full_key], true)
	else:
		var item: TreeItem = tree.get_root().get_first_child()
		var index: int = 0
		while item != null and index < plain_keys.size():
			item.set_text(0, str(plain_keys[index]))
			if tree.get_edited() != item:
				fill_value_item(item, values[plain_keys[index]])
			item = item.get_next()
			index += 1
		# `item` now walks the section headers, in the same insertion order as the plan.
		for section_name: Variant in sections:
			if item == null:
				break
			var leaf: TreeItem = item.get_first_child()
			for full_key: Variant in sections[section_name]:
				if leaf == null:
					break
				fill_value_item(leaf, values[full_key], true)
				leaf = leaf.get_next()
			item = item.get_next()
	_refresh_watches(values)


## Splits a streamed frame into flat sheet variables and per-behavior sections (dotted keys),
## both sorted, plus a signature the tree rebuild keys on. Pure + static → unit-testable.
static func build_display_plan(values: Dictionary) -> Dictionary:
	var plain_keys: Array = []
	var sections: Dictionary = {}
	for key: Variant in values.keys():
		var key_text: String = str(key)
		if key_text.contains("."):
			var section_name: String = key_text.get_slice(".", 0)
			if not sections.has(section_name):
				sections[section_name] = []
			(sections[section_name] as Array).append(key_text)
		else:
			plain_keys.append(key_text)
	plain_keys.sort()
	var section_names: Array = sections.keys()
	section_names.sort()
	var ordered_sections: Dictionary = {}
	var signature_parts: PackedStringArray = PackedStringArray(plain_keys)
	for section_name: Variant in section_names:
		var section_keys: Array = sections[section_name]
		section_keys.sort()
		ordered_sections[section_name] = section_keys
		signature_parts.append_array(PackedStringArray(section_keys))
	return {"plain": plain_keys, "sections": ordered_sections, "signature": ",".join(signature_parts)}


## One value -> one tree row. Dictionaries/Arrays expand into read-only subtrees
## (GDevelop's variables-debugger style); scalars stay editable leaves unless `read_only` (a
## behavior's own values). A value that cannot be edited reads muted, so it never looks editable.
static func fill_value_item(item: TreeItem, value: Variant, read_only: bool = false) -> void:
	for stale: TreeItem in item.get_children():
		item.remove_child(stale)
	var children: Array = []
	if value is Dictionary:
		item.set_text(1, "{…} %d entries" % (value as Dictionary).size())
		children = (value as Dictionary).keys()
		children.sort()
	elif value is Array:
		item.set_text(1, "[…] %d items" % (value as Array).size())
		children = range((value as Array).size())
	else:
		item.set_text(1, str(value))
	for child_key: Variant in children:
		var child: TreeItem = item.create_child()
		child.set_text(0, ("[%d]" % child_key) if value is Array else str(child_key))
		fill_value_item(child, value[child_key], true)
	var editable: bool = not read_only and not (value is Dictionary or value is Array)
	item.set_editable(1, editable)
	item.set_custom_color(1, EventSheetPopupUI.text_color() if editable else EventSheetPopupUI.muted_text_color())


## The watch list, shared. The Debugger window's Watch tab and this window are two views of ONE
## list on purpose: two lists that quietly disagree about what is being watched is exactly the bug
## a reader would never think to look for.
func watches() -> Array[String]:
	return _watches.duplicate()


## Adds an expression from anywhere (this window's box, or the Debugger's). Duplicates and blanks
## are dropped rather than added twice.
func add_watch(expression: String) -> void:
	var wanted: String = expression.strip_edges()
	if wanted.is_empty() or _watches.has(wanted):
		return
	_watches.append(wanted)
	_refresh_watches(_last_values)


func remove_watch(expression: String) -> void:
	if _watches.has(expression):
		_watches.erase(expression)
		_refresh_watches(_last_values)


## Adds the input expression to the watch list and re-evaluates against the latest frame.
func _add_watch_from_input() -> void:
	if watch_input == null:
		return
	add_watch(watch_input.text)
	watch_input.clear()


## Double-click a watch row to remove it.
func _remove_selected_watch() -> void:
	var selected: TreeItem = watch_tree.get_selected() if watch_tree != null else null
	if selected != null and selected.get_metadata(0) is String:
		remove_watch(selected.get_metadata(0) as String)


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
	_refresh_watches(_last_values)


## Re-evaluates every watch against the latest values frame (editor-side, via Expression).
func _refresh_watches(values: Dictionary) -> void:
	_last_values = values
	if watch_tree != null:
		fill_watch_tree(watch_tree, _watches, values)


## The one watch table both windows draw. A watch that cannot be read says so in the warning tone
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


## Sends one edited value into the running game - never into the sheet - and returns the line that
## says what was sent, or "" when no streaming session could take it. Both windows edit through here.
func send_edit(variable_name: String, text: String) -> String:
	var new_value: Variant = EventSheetLiveValuesDebugger.parse_edited_value(text)
	if debugger == null or not debugger.send_set_value(variable_name, new_value):
		_dock._set_status(EventSheetL10n.translate("Live edit needs a streaming debug session (run the game with Live Values on)."), true)
		return ""
	_dock._set_status(EventSheetL10n.translate("Live edit: %s = %s sent to the running game.") % [variable_name, str(new_value)])
	return EventSheetL10n.translate("%s = %s   # into the running game; the sheet is not changed") \
		% [variable_name, str(new_value)]


## Tree edit -> typed value -> running game (debug session). The event-sheet editable debugger.
func _on_live_value_edited() -> void:
	var edited: TreeItem = tree.get_edited()
	if edited != null:
		send_edit(edited.get_text(0), edited.get_text(1))
