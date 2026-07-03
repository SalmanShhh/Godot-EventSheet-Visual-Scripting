# Godot EventSheets — MCP server protocol core
# JSON-RPC handshake, tool listing, and every tool's happy/error path — driven through
# handle_message (the stdio transport in run_mcp_server.gd is a thin loop on top).
@tool
class_name McpServerTest
extends RefCounted


static func run() -> bool:
	var all_passed: bool = true
	var server: EventSheetMCPServer = EventSheetMCPServer.new()

	# Handshake.
	var init_response: Dictionary = server.handle_message({"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {}})
	all_passed = _check("initialize advertises tools",
		(init_response.get("result", {}) as Dictionary).get("capabilities", {}).has("tools"), true) and all_passed
	all_passed = _check("notifications get no response",
		server.handle_message({"jsonrpc": "2.0", "method": "notifications/initialized"}) == null, true) and all_passed
	var unknown: Dictionary = server.handle_message({"jsonrpc": "2.0", "id": 2, "method": "nope"})
	all_passed = _check("unknown methods error with -32601",
		int((unknown.get("error", {}) as Dictionary).get("code", 0)), -32601) and all_passed
	var tools_response: Dictionary = server.handle_message({"jsonrpc": "2.0", "id": 3, "method": "tools/list"})
	var tool_names: Array = []
	for tool: Variant in (tools_response.get("result", {}) as Dictionary).get("tools", []):
		tool_names.append(str((tool as Dictionary).get("name", "")))
	all_passed = _check("six tools listed", tool_names.size(), 6) and all_passed
	all_passed = _check("core tools present",
		tool_names.has("read_sheet") and tool_names.has("list_aces") and tool_names.has("compile_sheet") and tool_names.has("apply_snippet"), true) and all_passed

	# Activation gate: turned OFF, the server lists no tools and refuses any call; back ON, the
	# tools return — so the editor can activate/deactivate the MCP server at will, live.
	EventSheetMCPServer.enabled_override = false
	var off_list: Dictionary = server.handle_message({"jsonrpc": "2.0", "id": 31, "method": "tools/list"})
	all_passed = _check("disabled server lists no tools",
		((off_list.get("result", {}) as Dictionary).get("tools", []) as Array).size(), 0) and all_passed
	var off_call: Dictionary = server.handle_message({"jsonrpc": "2.0", "id": 32, "method": "tools/call", "params": {"name": "list_sheets", "arguments": {}}})
	all_passed = _check("disabled server refuses tool calls",
		bool((off_call.get("result", {}) as Dictionary).get("isError", false)), true) and all_passed
	EventSheetMCPServer.enabled_override = true
	all_passed = _check("re-enabled server lists tools again",
		((server.handle_message({"jsonrpc": "2.0", "id": 33, "method": "tools/list"}).get("result", {}) as Dictionary).get("tools", []) as Array).size(), 6) and all_passed
	EventSheetMCPServer.enabled_override = null

	# Fixture sheet on disk.
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "CharacterBody2D"
	sheet.variables = {"hp": {"type": "int", "default": 5, "exported": true}}
	var state: EnumRow = EnumRow.new()
	state.enum_name = "State"
	state.members = PackedStringArray(["IDLE", "RUN"])
	sheet.events.append(state)
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnReady"
	var act: ACEAction = ACEAction.new()
	act.provider_id = "Core"
	act.ace_id = "SetVar"
	act.codegen_template = "{var_name} = {value}"
	act.params = {"var_name": "hp", "value": "10"}
	event.actions.append(act)
	sheet.events.append(event)
	var fixture_path: String = "user://eventsheets_mcp_fixture.tres"
	var save_error: Error = ResourceSaver.save(sheet, fixture_path)
	all_passed = _check("fixture saves", save_error, OK) and all_passed

	# read_sheet.
	var read_payload: Dictionary = _call_tool(server, "read_sheet", {"path": fixture_path})
	all_passed = _check("read_sheet returns the host class", str(read_payload.get("host_class", "")), "CharacterBody2D") and all_passed
	var row_kinds: Array = []
	for row: Variant in read_payload.get("rows", []):
		row_kinds.append(str((row as Dictionary).get("kind", "")))
	all_passed = _check("read_sheet serializes enum + event rows",
		row_kinds.has("enum") and row_kinds.has("event"), true) and all_passed
	all_passed = _check("read_sheet errors on junk",
		_call_raw(server, "read_sheet", {"path": "res://nope.tres"}).get("isError", false), true) and all_passed

	# list_aces (registry incl. zero-config addons).
	var aces_payload: Dictionary = _call_tool(server, "list_aces", {"query": "dictionary"})
	all_passed = _check("list_aces filters by query", int(aces_payload.get("count", 0)) >= 8, true) and all_passed
	var all_aces: Dictionary = _call_tool(server, "list_aces", {})
	all_passed = _check("list_aces sees the addon providers (zero-config)",
		JSON.stringify(all_aces).contains("DemoHealthAddon"), true) and all_passed

	# compile_sheet (dry-run never writes the real path).
	var compile_payload: Dictionary = _call_tool(server, "compile_sheet", {"path": fixture_path})
	all_passed = _check("compile_sheet dry-run succeeds", bool(compile_payload.get("success", false)), true) and all_passed
	all_passed = _check("dry-run returns the generated script",
		str(compile_payload.get("output", "")).contains("hp = 10"), true) and all_passed
	all_passed = _check("dry-run marks nothing written", bool(compile_payload.get("wrote_file", true)), false) and all_passed

	# lint_block with sheet context (enum + variable must resolve).
	var lint_ok: Dictionary = _call_tool(server, "lint_block", {"code": "hp = int(State.RUN)", "in_flow": true, "sheet_path": fixture_path})
	all_passed = _check("lint_block resolves sheet context", bool(lint_ok.get("ok", false)), true) and all_passed
	var lint_bad: Dictionary = _call_tool(server, "lint_block", {"code": "hp +", "in_flow": true})
	all_passed = _check("lint_block rejects broken code", bool(lint_bad.get("ok", true)), false) and all_passed

	# apply_snippet: GDScript auto-conversion, dry-run preview, then a real mutation.
	var gd_text: String = "func _process(delta: float) -> void:\n\tqueue_free()\n"
	var preview: Dictionary = _call_tool(server, "apply_snippet", {"path": fixture_path, "text": gd_text, "dry_run": true})
	all_passed = _check("apply_snippet previews row kinds", int(preview.get("rows", 0)) >= 1, true) and all_passed
	var before_rows: int = (load(fixture_path) as EventSheetResource).events.size()
	var applied: Dictionary = _call_tool(server, "apply_snippet", {"path": fixture_path, "text": gd_text})
	all_passed = _check("apply_snippet applies rows", int(applied.get("applied", 0)) >= 1, true) and all_passed
	var after: EventSheetResource = ResourceLoader.load(fixture_path, "", ResourceLoader.CACHE_MODE_IGNORE) as EventSheetResource
	all_passed = _check("the saved sheet grew", after.events.size() > before_rows, true) and all_passed
	all_passed = _check("mutation is .tres-only",
		_call_raw(server, "apply_snippet", {"path": "res://demo/sheets/player_generated.gd", "text": gd_text}).get("isError", false), true) and all_passed

	return all_passed


static func _call_raw(server: EventSheetMCPServer, tool_name: String, arguments: Dictionary) -> Dictionary:
	var response: Dictionary = server.handle_message({
		"jsonrpc": "2.0", "id": 99, "method": "tools/call",
		"params": {"name": tool_name, "arguments": arguments}
	})
	return response.get("result", {})


static func _call_tool(server: EventSheetMCPServer, tool_name: String, arguments: Dictionary) -> Dictionary:
	var result: Dictionary = _call_raw(server, tool_name, arguments)
	var content: Array = result.get("content", [])
	if content.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(str((content[0] as Dictionary).get("text", "")))
	return parsed if parsed is Dictionary else {}


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] mcp_server_test: %s" % label)
		return true
	print("[FAIL] mcp_server_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
