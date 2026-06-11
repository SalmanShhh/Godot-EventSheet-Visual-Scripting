import io

# ── Debugger bridge: outbound set + value parsing ──
p = "addons/eventsheet/editor/live_values_debugger.gd"
s = io.open(p, encoding="utf-8").read()
old = "signal values_received(values: Dictionary)"
assert old in s, 1
s = s.replace(old, old + "\n\nvar _last_session_id: int = -1", 1)
old = """func _capture(message: String, data: Array, _session_id: int) -> bool:
	if message != "eventsheets:live_values":
		return false
	values_received.emit(parse_payload(data))
	return true"""
assert old in s, 2
s = s.replace(old, """func _capture(message: String, data: Array, session_id: int) -> bool:
	if message != "eventsheets:live_values":
		return false
	_last_session_id = session_id
	values_received.emit(parse_payload(data))
	return true

## Edit-back: pushes a value change into the running game (the streaming session).
func send_set_value(variable_name: String, value: Variant) -> bool:
	if _last_session_id < 0:
		return false
	var session: EditorDebuggerSession = get_session(_last_session_id)
	if session == null or not session.is_active():
		return false
	session.send_message("eventsheets:set_value", [variable_name, value])
	return true

## "3.5" -> 3.5, "true" -> true, "Vector2(1, 2)" -> vector… plain words stay strings
## (str_to_var yields null for them).
static func parse_edited_value(text: String) -> Variant:
	var parsed: Variant = str_to_var(text)
	return parsed if parsed != null or text.strip_edges() == "null" else text""", 1)
io.open(p, "w", encoding="utf-8", newline="\n").write(s)
print("bridge done")

# ── Dock: editable tree + send wiring ──
p = "addons/eventsheet/editor/event_sheet_dock.gd"
s = io.open(p, encoding="utf-8").read()
old = "var _live_values_window: Window = null\nvar _live_values_label: RichTextLabel = null"
assert old in s, 3
s = s.replace(old, """var _live_values_window: Window = null
var _live_values_label: RichTextLabel = null
var _live_values_tree: Tree = null
var _live_values_debugger: EventSheetLiveValuesDebugger = null

## Wired by the plugin entry point so value edits can flow back to the running game.
func set_live_values_debugger(debugger: EventSheetLiveValuesDebugger) -> void:
    _live_values_debugger = debugger""", 1)

old = """    _live_values_label = RichTextLabel.new()
    _live_values_label.set_anchors_preset(Control.PRESET_FULL_RECT)
    _live_values_label.text = "Waiting for a running game…"
    _live_values_window.add_child(_live_values_label)
    add_child(_live_values_window)"""
assert old in s, 4
s = s.replace(old, """    var live_box: VBoxContainer = VBoxContainer.new()
    live_box.set_anchors_preset(Control.PRESET_FULL_RECT)
    _live_values_label = RichTextLabel.new()
    _live_values_label.fit_content = true
    _live_values_label.text = "Waiting for a running game…  (double-click a value to EDIT it live)"
    live_box.add_child(_live_values_label)
    _live_values_tree = Tree.new()
    _live_values_tree.hide_root = true
    _live_values_tree.columns = 2
    _live_values_tree.set_column_title(0, "Variable")
    _live_values_tree.set_column_title(1, "Value (editable)")
    _live_values_tree.column_titles_visible = true
    _live_values_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _live_values_tree.item_edited.connect(_on_live_value_edited)
    live_box.add_child(_live_values_tree)
    _live_values_window.add_child(live_box)
    add_child(_live_values_window)""", 1)

start = s.index("## Debugger-plugin sink (wired by the plugin entry point): one values frame -> text")
end = s.index('    _live_values_label.text = "\\n".join(frame_lines)') + len('    _live_values_label.text = "\\n".join(frame_lines)')
s = s[:start] + """## Debugger-plugin sink (wired by the plugin entry point): one values frame -> the
## editable tree + inline chips next to variable rows in every pane (rung 3).
func update_live_values(values: Dictionary) -> void:
    for pane: EventSheetViewport in [_viewport, _split_viewport, _detached_viewport]:
        if pane != null:
            pane.set_live_values(values)
    _ensure_live_values_window()
    _live_values_label.text = "Streaming — double-click a value to edit it in the running game."
    var value_keys: Array = values.keys()
    value_keys.sort()
    # Rebuild only when the key set changes; otherwise update in place so an
    # in-progress edit isn't stomped by the next frame.
    var rebuild: bool = _live_values_tree.get_root() == null or _live_values_tree.get_root().get_child_count() != value_keys.size()
    if rebuild:
        _live_values_tree.clear()
        var root_item: TreeItem = _live_values_tree.create_item()
        for value_key: Variant in value_keys:
            var item: TreeItem = _live_values_tree.create_item(root_item)
            item.set_text(0, str(value_key))
            item.set_text(1, str(values[value_key]))
            item.set_editable(1, true)
    else:
        var item: TreeItem = _live_values_tree.get_root().get_first_child()
        var index: int = 0
        while item != null and index < value_keys.size():
            item.set_text(0, str(value_keys[index]))
            if _live_values_tree.get_edited() != item:
                item.set_text(1, str(values[value_keys[index]]))
            item = item.get_next()
            index += 1

## Tree edit -> typed value -> running game (debug session). C3's editable debugger.
func _on_live_value_edited() -> void:
    var edited: TreeItem = _live_values_tree.get_edited()
    if edited == null:
        return
    var variable_name: String = edited.get_text(0)
    var new_value: Variant = EventSheetLiveValuesDebugger.parse_edited_value(edited.get_text(1))
    if _live_values_debugger != null and _live_values_debugger.send_set_value(variable_name, new_value):
        _set_status("Live edit: %s = %s sent to the running game." % [variable_name, str(new_value)])
    else:
        _set_status("Live edit needs a streaming debug session (run the game with Live Values on).", true)""" + s[end:]
io.open(p, "w", encoding="utf-8", newline="\n").write(s)
print("dock done")

# ── Plugin wiring ──
p = "addons/eventforge/plugin.gd"
s = io.open(p, encoding="utf-8").read()
old = "\t\t\tif _live_values_debugger != null and _event_sheet_editor.has_method(\"update_live_values\"):\n\t\t\t\t_live_values_debugger.values_received.connect(_event_sheet_editor.update_live_values)"
assert old in s, 5
s = s.replace(old, old + "\n\t\t\tif _live_values_debugger != null and _event_sheet_editor.has_method(\"set_live_values_debugger\"):\n\t\t\t\t_event_sheet_editor.set_live_values_debugger(_live_values_debugger)", 1)
io.open(p, "w", encoding="utf-8", newline="\n").write(s)
print("plugin done")
