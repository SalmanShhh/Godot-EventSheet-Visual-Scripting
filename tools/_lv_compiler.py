import io

p = "addons/eventforge/compiler/sheet_compiler.gd"
s = io.open(p, encoding="utf-8").read()

old = 'static var _live_values_payload: String = ""'
assert old in s, 1
s = s.replace(old, old + """
# Whether the current debug compile still needs the edit-back receiver emitted (the
# Live Values window's value edits arrive through it). Cleared once injected.
static var _live_values_receiver_pending: bool = false""", 1)

old = '\t_live_values_payload = ""\n\tif sheet.emit_live_values:'
assert old in s, 2
s = s.replace(old, '\t_live_values_payload = ""\n\t_live_values_receiver_pending = false\n\tif sheet.emit_live_values:', 1)

old = '\t\t\t_live_values_payload = ", ".join(payload_parts)'
assert old in s, 3
s = s.replace(old, old + "\n\t\t\t_live_values_receiver_pending = true", 1)

old = 'static func _compile_external(sheet: EventSheetResource, result: Dictionary, output_path: String) -> Dictionary:'
assert old in s, 4
idx = s.index(old)
line_end = s.index("\n", idx) + 1
s = s[:line_end] + '\t_live_values_receiver_pending = false\n' + s[line_end:]

old = """		var had_body: bool = false
		if function_name == "_process" and not _live_values_payload.is_empty():"""
assert old in s, 5
s = s.replace(old, """		var had_body: bool = false
		if function_name == "_ready" and _live_values_receiver_pending:
			# Edit-back channel: the Live Values window's edits arrive as
			# "eventsheets:set_value" messages (debug sessions only; one receiver per
			# game — the first streaming sheet wins, noted in the window).
			lines.append("\\tif EngineDebugger.is_active() and not EngineDebugger.has_capture(\\"eventsheets\\"):")
			lines.append("\\t\\tEngineDebugger.register_message_capture(&\\"eventsheets\\", _eventsheets_debug_set)")
			had_body = true
			_live_values_receiver_pending = false
		if function_name == "_process" and not _live_values_payload.is_empty():""", 1)

old = """	# No OnReady events but connections needed → synthesize a `_ready` for them.
	if not has_ready_group and not ready_connections.is_empty():
		lines.append("")
		lines.append("func _ready() -> void:")
		for connection_line: String in ready_connections:
			lines.append(connection_line)"""
assert old in s, 6
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

old = "\t# Emit sheet functions as callable GDScript methods (after the trigger handlers)."
assert old in s, 7
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
print("compiler lv done")
