# Godot EventSheets — MCP server (stdio transport)
# Newline-delimited JSON-RPC over stdin/stdout, per the MCP stdio transport. Launch with
# --quiet so the engine banner doesn't corrupt the protocol stream:
#
#   <godot> --headless --quiet --path <project> --script addons/eventsheet/mcp/run_mcp_server.gd
#
# Protocol logic lives in EventSheetMCPServer (transport-free, unit-tested).
@tool
extends SceneTree


func _init() -> void:
	var server: EventSheetMCPServer = EventSheetMCPServer.new()
	while true:
		var line: String = OS.read_string_from_stdin(65536)
		if line.is_empty():
			break  # EOF: the client closed stdin.
		line = line.strip_edges()
		if line.is_empty():
			continue
		var parsed: Variant = JSON.parse_string(line)
		if not (parsed is Dictionary):
			printraw(JSON.stringify({"jsonrpc": "2.0", "id": null, "error": {"code": -32700, "message": "Parse error"}}) + "\n")
			continue
		var response: Variant = server.handle_message(parsed as Dictionary)
		if response is Dictionary:
			printraw(JSON.stringify(response) + "\n")
	quit(0)
