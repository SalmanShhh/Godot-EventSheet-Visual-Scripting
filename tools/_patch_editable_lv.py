import io

# ── Compiler: debug compiles also REGISTER a set-value receiver (edit-back channel) ──
p = "addons/eventforge/compiler/sheet_compiler.gd"
s = io.open(p, encoding="utf-8").read()

old = "static var _live_values_payload: String = \"\""
assert old in s
s = s.replace(old, old + """
# Whether the current debug compile still needs the edit-back receiver emitted (the
# Live Values window's value edits arrive through it). Cleared once injected.
static var _live_values_receiver_pending: bool = false""", 1)

old = "\t\t\t_live_values_payload = \", \".join(payload_parts)"
assert old in s
s = s.replace(old, old + "\n\t\t\t_live_values_receiver_pending = true", 1)
old = '\t_live_values_payload = ""\n\t# C3-style includes:'
assert old in s
s = s.replace(old, '\t_live_values_payload = ""\n\t_live_values_receiver_pending = false\n\t# C3-style includes:', 1)
old = "static func _compile_external(sheet: EventSheetResource, result: Dictionary, output_path: String) -> Dictionary:\n\t_emit_breakpoints_flag = sheet.emit_breakpoints\n\t_live_values_payload = \"\""
assert old in s
s = s.replace(old, old + "\n\t_live_values_receiver_pending = false", 1)

# Inject registration at the top of _ready (mirrors the _process stream injection).
old = """		var had_body: bool = false
		if function_name == "_process" and not _live_values_payload.is_empty():"""
assert old in s
s = s.replace(old, """		var had_body: bool = false
		if function_name == "_ready" and _live_values_receiver_pending:
			# Edit-back channel: the Live Values window's edits arrive as
			# "eventsheets:set_value" messages (debug sessions only; one receiver per
			# game — the first streaming sheet wins, documented in the window).
			lines.append("\\tif EngineDebugger.is_active() and not EngineDebugger.has_capture(\\"eventsheets\\"):")
			lines.append("\\t\\tEngineDebugger.register_message_capture(&\\"eventsheets\\", _eventsheets_debug_set)")
			had_body = true
			_live_values_receiver_pending = false
		if function_name == "_process" and not _live_values_payload.is_empty():""", 1)

# Synthesized _ready covers the receiver too; the handler function emits with the
# standalone _process block (same pre-functions slot).
old = """	# No OnReady events but connections needed → synthesize a `_ready` for them.
	if not has_ready_group and not ready_connections.is_empty():
		lines.append("")
		lines.append("func _ready() -> void:")
		for connection_line: String in ready_connections:
			lines.append(connection_line)"""
assert old in s
s = s.replace(old, """	# No OnReady events but connections/receiver needed → synthesize a `_ready`.
	if not has_ready_group and (not ready_connections.is_empty() or _live_values_receiver_pending):
		lines.append("")
		lines.append("func _ready() -> void:")
		if _live_values_receiver_pending:
			lines.append("\\tif EngineDebugger.is_active() and not EngineDebugger.has_capture(\\"eventsheets\\"):")
			lines.append("\\t\\tEngineDebugger.register_message_capture(&\\"eventsheets\\", _eventsheets_debug_set)")
			_live_values_receiver_pending = false
		for connection_line: String in ready_connections:
			lines.append(connection_line)""", 1)

old = '''	if not _live_values_payload.is_empty():
		lines.append("")
		lines.append("func _process(delta: float) -> void:")'''
assert old in s
s = s.replace(old, '''	if sheet.emit_live_values and not _live_values_payload.is_empty() or sheet.emit_live_values and not str(_live_values_payload).is_empty():
		pass  # (placeholder removed below)
	if not _live_values_payload.is_empty():
		lines.append("")
		lines.append("func _process(delta: float) -> void:")''', 1)
# remove the accidental placeholder construct cleanly
s = s.replace('''	if sheet.emit_live_values and not _live_values_payload.is_empty() or sheet.emit_live_values and not str(_live_values_payload).is_empty():
		pass  # (placeholder removed below)
''', "", 1)

# Handler function: emit right before the sheet-functions section when streaming.
old = "\t# Emit sheet functions as callable GDScript methods (after the trigger handlers)."
assert old in s
s = s.replace(old, """	if sheet.emit_live_values and not sheet.variables.is_empty():
		lines.append("")
		lines.append("## Live Values edit-back receiver (debug sessions only).")
		lines.append("func _eventsheets_debug_set(message: String, data: Array) -> bool:")
		lines.append("\\tif message != \\"set_value\\" or data.size() < 2:")
		lines.append("\\t\\treturn false")
		lines.append("\\tset(str(data[0]), data[1])")
		lines.append("\\treturn true")

""" + old, 1)
io.open(p, "w", encoding="utf-8", newline="\n").write(s)
print("compiler done")

# ── Debugger bridge: outbound set ──
p = "addons/eventsheet/editor/live_values_debugger.gd"
s = io.open(p, encoding="utf-8").read()
old = "signal values_received(values: Dictionary)"
assert old in s
s = s.replace(old, old + """

var _last_session_id: int = -1""", 1)
old = """func _capture(message: String, data: Array, _session_id: int) -> bool:
	if message != "eventsheets:live_values":
		return false
	values_received.emit(parse_payload(data))
	return true"""
assert old in s
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

## "3.5" -> 3.5, "true" -> true, "[1,2]" -> array… falls back to the raw string.
## (str_to_var returns null for plain words — those stay strings.)
static func parse_edited_value(text: String) -> Variant:
	var parsed: Variant = str_to_var(text)
	return parsed if parsed != null or text.strip_edges() == "null" else text""", 1)
io.open(p, "w", encoding="utf-8", newline="\n").write(s)
print("bridge done")

# ── Dock: window becomes an editable Tree; commits send through the bridge ──
p = "addons/eventsheet/editor/event_sheet_dock.gd"
s = io.open(p, encoding="utf-8").read()
old = "var _live_values_window: Window = null\nvar _live_values_label: RichTextLabel = null"
assert old in s
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
assert old in s
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

old = """## Debugger-plugin sink (wired by the plugin entry point): one values frame -> text
## window + inline chips next to variable rows in every pane (rung 3).
func update_live_values(values: Dictionary) -> void:
    for pane: EventSheetViewport in [_viewport, _split_viewport, _detached_viewport]:
        if pane != null:
            pane.set_live_values(values)
    _ensure_live_values_window()
    var frame_lines: PackedStringArray = PackedStringArray()
    var value_keys: Array = values.keys()
    value_keys.sort()
    for value_key: Variant in value_keys:
        frame_lines.append("%s = %s" % [str(value_key), str(values[value_key])])
    _live_values_label.text = "\\n".join(frame_lines)"""
assert old in s
s = s.replace(old, """## Debugger-plugin sink (wired by the plugin entry point): one values frame -> the
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
    # in-progress edit isn't stomped every frame.
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
        _set_status("Live edit needs a streaming debug session (run the game with Live Values on).", true)""", 1)
io.open(p, "w", encoding="utf-8", newline="\n").write(s)
print("dock done")

# ── Plugin wiring ──
p = "addons/eventforge/plugin.gd"
s = io.open(p, encoding="utf-8").read()
old = "\t\t\tif _live_values_debugger != null and _event_sheet_editor.has_method(\"update_live_values\"):\n\t\t\t\t_live_values_debugger.values_received.connect(_event_sheet_editor.update_live_values)"
assert old in s
s = s.replace(old, old + "\n\t\t\tif _live_values_debugger != null and _event_sheet_editor.has_method(\"set_live_values_debugger\"):\n\t\t\t\t_event_sheet_editor.set_live_values_debugger(_live_values_debugger)", 1)
io.open(p, "w", encoding="utf-8", newline="\n").write(s)
print("plugin done")
