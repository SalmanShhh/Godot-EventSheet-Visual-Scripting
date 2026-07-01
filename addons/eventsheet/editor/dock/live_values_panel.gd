# Godot EventSheets — the Live Values panel (dock subsystem)
#
# Extracted from EventSheetDock (decomposition arc, step 3): the streaming window
# (editable tree, nested containers), the per-pane chip forwarding, and the edit-back
# send path. The dock forwards its historical field/method names here so the test
# surface and the plugin wiring are unchanged.
@tool
extends RefCounted
class_name EventSheetLiveValuesPanel

var _dock: Control = null

func _init(dock: Control) -> void:
	_dock = dock

var window: Window = null
var label: RichTextLabel = null
var tree: Tree = null
var debugger: EventSheetLiveValuesDebugger = null

## Watch expressions (session-scoped): evaluated editor-side against each streamed values
## frame via Expression, so you can watch any expression over the sheet's variables, live.
var _watches: Array[String] = []
var _last_values: Dictionary = {}
var watch_tree: Tree = null
var watch_input: LineEdit = null

## Wired by the plugin entry point so value edits can flow back to the running game.
func setdebugger(debugger: EventSheetLiveValuesDebugger) -> void:
	debugger = debugger

## Toggles live-value streaming for this sheet (debug compiles send variable frames;
## the window shows them while the game runs). Recompile + run to start streaming.
func toggle() -> void:
	if _dock._current_sheet == null:
		return
	_dock._current_sheet.emit_live_values = not _dock._current_sheet.emit_live_values
	if _dock._current_sheet.emit_live_values:
		ensure_window()
		window.popup_centered()
		_dock._set_status("Live Values ON: recompile and run — variables stream every 0.25s while the debugger is attached.")
	else:
		if window != null:
			window.hide()
		_dock._set_status("Live Values OFF (recompile to remove the stream).")

## Lazily builds the floating Live Values window the first time it's needed. Named to match
## the dock's call site (event_sheet_dock.gd: _ensure_live_values_panel().ensure_window()).
func ensure_window() -> void:
	if window != null:
		return
	window = Window.new()
	window.title = "Live Values"
	window.size = Vector2i(320, 380)
	window.close_requested.connect(func() -> void: window.hide())
	var live_box: VBoxContainer = VBoxContainer.new()
	live_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Group 1 — the Live Values stream: status line + the editable values tree, in one titled card.
	var stream_box: VBoxContainer = EventSheetPopupUI.form_box()
	label = RichTextLabel.new()
	label.fit_content = true
	label.text = "Waiting for a running game…  (double-click a value to EDIT it live)"
	stream_box.add_child(label)
	tree = Tree.new()
	tree.hide_root = true
	tree.columns = 2
	tree.set_column_title(0, "Variable")
	tree.set_column_title(1, "Value (editable)")
	tree.column_titles_visible = true
	tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tree.item_edited.connect(_on_live_value_edited)
	stream_box.add_child(tree)
	var stream_card: PanelContainer = EventSheetPopupUI.titled_card("Live Values", stream_box)
	stream_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stream_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	live_box.add_child(stream_card)
	# Group 2 — Watch: the hint + the input row + the watch tree, in one titled card.
	var watch_box: VBoxContainer = EventSheetPopupUI.form_box()
	watch_box.add_child(EventSheetPopupUI.hint_label("Expressions over the streamed values above (double-click a row to remove)."))
	var watch_row: HBoxContainer = HBoxContainer.new()
	watch_input = LineEdit.new()
	watch_input.placeholder_text = "e.g. health <= 0"
	watch_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	watch_input.text_submitted.connect(func(_t: String) -> void: _add_watch_from_input())
	watch_row.add_child(watch_input)
	var add_watch_button: Button = Button.new()
	add_watch_button.text = "Watch"
	add_watch_button.pressed.connect(_add_watch_from_input)
	watch_row.add_child(add_watch_button)
	watch_box.add_child(watch_row)
	watch_tree = Tree.new()
	watch_tree.hide_root = true
	watch_tree.columns = 2
	watch_tree.set_column_title(0, "Expression")
	watch_tree.set_column_title(1, "Value")
	watch_tree.column_titles_visible = true
	watch_tree.custom_minimum_size = Vector2(0.0, 110.0)
	watch_tree.item_activated.connect(_remove_selected_watch)
	watch_box.add_child(watch_tree)
	var watch_card: PanelContainer = EventSheetPopupUI.titled_card("Watch", watch_box)
	watch_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	live_box.add_child(watch_card)
	window.add_child(EventSheetPopupUI.margined(live_box))
	_dock.add_child(window)

## Debugger-plugin sink (wired by the plugin entry point): one values frame -> the
## editable tree + inline chips next to variable rows in every pane (rung 3).
func update_values(values: Dictionary) -> void:
	for pane: EventSheetViewport in [_dock._viewport, _dock._multi_view._split_viewport, _dock._detached_viewport]:
		if pane != null:
			pane.set_live_values(values)
	ensure_window()
	label.text = "Streaming — double-click a value to edit it in the running game."
	var value_keys: Array = values.keys()
	value_keys.sort()
	# Rebuild only when the key set changes; otherwise update in place so an
	# in-progress edit isn't stomped by the next frame.
	var rebuild: bool = tree.get_root() == null or tree.get_root().get_child_count() != value_keys.size()
	if rebuild:
		tree.clear()
		var root_item: TreeItem = tree.create_item()
		for value_key: Variant in value_keys:
			var item: TreeItem = tree.create_item(root_item)
			item.set_text(0, str(value_key))
			_fill_live_value_item(item, values[value_key])
	else:
		var item: TreeItem = tree.get_root().get_first_child()
		var index: int = 0
		while item != null and index < value_keys.size():
			item.set_text(0, str(value_keys[index]))
			if tree.get_edited() != item:
				_fill_live_value_item(item, values[value_keys[index]])
			item = item.get_next()
			index += 1
	_refresh_watches(values)

## One value -> one tree row. Dictionaries/Arrays expand into read-only subtrees
## (GDevelop's variables-debugger style); scalars stay editable leaves.
func _fill_live_value_item(item: TreeItem, value: Variant) -> void:
	for stale: TreeItem in item.get_children():
		item.remove_child(stale)
	if value is Dictionary:
		item.set_text(1, "{…} %d entries" % (value as Dictionary).size())
		item.set_editable(1, false)
		var dictionary_keys: Array = (value as Dictionary).keys()
		dictionary_keys.sort()
		for child_key: Variant in dictionary_keys:
			var child: TreeItem = item.create_child()
			child.set_text(0, str(child_key))
			_fill_live_value_item(child, (value as Dictionary)[child_key])
			child.set_editable(1, false)
	elif value is Array:
		item.set_text(1, "[…] %d items" % (value as Array).size())
		item.set_editable(1, false)
		for child_index: int in range((value as Array).size()):
			var element: TreeItem = item.create_child()
			element.set_text(0, "[%d]" % child_index)
			_fill_live_value_item(element, (value as Array)[child_index])
			element.set_editable(1, false)
	else:
		item.set_text(1, str(value))
		item.set_editable(1, true)

## Adds the input expression to the watch list and re-evaluates against the latest frame.
func _add_watch_from_input() -> void:
	if watch_input == null:
		return
	var expression: String = watch_input.text.strip_edges()
	if expression.is_empty() or _watches.has(expression):
		watch_input.clear()
		return
	_watches.append(expression)
	watch_input.clear()
	_refresh_watches(_last_values)

## Double-click a watch row to remove it.
func _remove_selected_watch() -> void:
	if watch_tree == null:
		return
	var selected: TreeItem = watch_tree.get_selected()
	if selected == null:
		return
	var expression: Variant = selected.get_metadata(0)
	if expression is String and _watches.has(expression):
		_watches.erase(expression)
		_refresh_watches(_last_values)

## Re-evaluates every watch against the latest values frame (editor-side, via Expression).
func _refresh_watches(values: Dictionary) -> void:
	_last_values = values
	if watch_tree == null:
		return
	watch_tree.clear()
	var root: TreeItem = watch_tree.create_item()
	for expression: String in _watches:
		var item: TreeItem = watch_tree.create_item(root)
		item.set_text(0, expression)
		item.set_metadata(0, expression)
		if values.is_empty():
			item.set_text(1, "—")
			continue
		var verdict: Dictionary = evaluate_watch(expression, values)
		if bool(verdict.get("ok", false)):
			item.set_text(1, str(verdict.get("value")))
		else:
			item.set_text(1, "⚠ %s" % str(verdict.get("error", "error")))
			item.set_custom_color(1, Color(1.0, 0.5, 0.5))

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
		names.append(str(key))
		inputs.append(values[key])
	if expr.parse(expression, names) != OK:
		return {"ok": false, "error": expr.get_error_text()}
	var result: Variant = expr.execute(inputs, null, false)
	if expr.has_execute_failed():
		return {"ok": false, "error": expr.get_error_text()}
	return {"ok": true, "value": result}

## Tree edit -> typed value -> running game (debug session). The event-sheet editable debugger.
func _on_live_value_edited() -> void:
	var edited: TreeItem = tree.get_edited()
	if edited == null:
		return
	var variable_name: String = edited.get_text(0)
	var new_value: Variant = EventSheetLiveValuesDebugger.parse_edited_value(edited.get_text(1))
	if debugger != null and debugger.send_set_value(variable_name, new_value):
		_dock._set_status("Live edit: %s = %s sent to the running game." % [variable_name, str(new_value)])
	else:
		_dock._set_status("Live edit needs a streaming debug session (run the game with Live Values on).", true)

