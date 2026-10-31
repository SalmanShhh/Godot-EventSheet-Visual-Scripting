# Godot EventSheets - MCP server protocol core
# JSON-RPC handshake, tool listing, and every tool's happy/error path - driven through
# handle_message (the stdio transport in run_mcp_server.gd is a thin loop on top). Then the two
# places an edit can go: a file on disk (a .tres saved, a .gd written only when it saves back byte
# for byte), and the running editor (a live host whose edits go through the dock's undo funnel), and
# the live link's own socket.
@tool
class_name McpServerTest
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")
const LIVE_LINK := preload("res://addons/eventsheet/mcp/mcp_live_link.gd")

const TOOL_NAMES: Array = ["list_sheets", "read_sheet", "list_aces", "compile_sheet", "lint_block",
	"apply_snippet", "edit_row", "delete_row", "comment", "variable_properties", "rename", "explain",
	"verify", "run_doctor"]

## A small script sheet, written to user:// for every write test so each starts from the same bytes.
const SCRIPT_SHEET := """extends Node

@export var speed: float = 2.0


func _ready() -> void:
	print(speed)
"""
const SCRIPT_PATH := "user://eventsheets_mcp_fixture.gd"


## A stand-in for the running editor: one open sheet, and a log of the edits handed to it.
class FakeEditor:
	extends RefCounted
	var sheet: EventSheetResource = null
	var path: String = ""
	var edits: Array = []

	func sheet_open_at(asked: String) -> EventSheetResource:
		return sheet if asked == path else null

	func open_tabs() -> Array:
		return [{"path": path, "unsaved": not edits.is_empty()}]

	func edit_sheet(asked: String, label: String, mutation: Callable) -> Dictionary:
		if asked != path:
			return {"error": "not open"}
		edits.append(label)
		mutation.call(sheet)
		return {}


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
	all_passed = _check("the fourteen tools, in order", _tool_names(server), TOOL_NAMES) and all_passed

	# Activation gate: turned OFF, the server lists no tools and refuses any call - the new editing
	# tools included; back ON, the tools return - so the editor can switch it at will, live.
	EventSheetMCPServer.enabled_override = false
	all_passed = _check("disabled server lists no tools", _tool_names(server), []) and all_passed
	for gated: String in ["list_sheets", "apply_snippet", "edit_row", "delete_row", "comment", "rename", "variable_properties", "explain", "verify"]:
		var off_call: Dictionary = server.handle_message({"jsonrpc": "2.0", "id": 32, "method": "tools/call", "params": {"name": gated, "arguments": {}}})
		all_passed = _check("disabled server refuses %s" % gated,
			str(((off_call.get("result", {}) as Dictionary).get("content", [{}]) as Array)[0].get("text", "")).contains("turned OFF"), true) and all_passed
	EventSheetMCPServer.enabled_override = true
	all_passed = _check("re-enabled server lists tools again", _tool_names(server).size(), 14) and all_passed
	EventSheetMCPServer.enabled_override = null

	# Fixture sheet on disk.
	var fixture_path: String = "user://eventsheets_mcp_fixture.tres"
	all_passed = _check("fixture saves", ResourceSaver.save(_stored_sheet(), fixture_path), OK) and all_passed

	# read_sheet: every row has its address.
	var read_payload: Dictionary = _call_tool(server, "read_sheet", {"path": fixture_path})
	all_passed = _check("read_sheet returns the host class", str(read_payload.get("host_class", "")), "CharacterBody2D") and all_passed
	all_passed = _check("read_sheet rows carry kind and address", _kinds_and_addresses(read_payload.get("rows", []) as Array),
		["enum@0", "event@1", "event@1/0"]) and all_passed
	all_passed = _check("read_sheet errors on junk",
		_call_raw(server, "read_sheet", {"path": "res://nope.tres"}).get("isError", false), true) and all_passed

	# list_sheets finds .gd sheets as well as .tres ones, and leaves the plugin's own packs out.
	var listed: Array = _call_tool(server, "list_sheets", {}).get("sheets", []) as Array
	all_passed = _check("list_sheets lists a .gd sheet", listed.has("res://demo/showcase/boomer_level/boomer_level.gd"), true) and all_passed
	all_passed = _check("list_sheets leaves a shipped pack out", listed.has("res://eventsheet_addons/bullet/bullet.gd"), false) and all_passed
	all_passed = _check("list_sheets keeps the plugin's own code out", listed.has("res://addons/eventsheet/mcp/mcp_server.gd"), false) and all_passed

	# list_aces (registry incl. zero-config addons).
	var aces_payload: Dictionary = _call_tool(server, "list_aces", {"query": "dictionary"})
	all_passed = _check("list_aces filters by query", int(aces_payload.get("count", 0)) >= 8, true) and all_passed
	all_passed = _check("list_aces sees the addon providers (zero-config)",
		JSON.stringify(_call_tool(server, "list_aces", {})).contains("DemoHealthAddon"), true) and all_passed

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

	# apply_snippet on a .tres: GDScript auto-conversion, dry-run preview, then a real mutation, then
	# an insert INSIDE an event at a position.
	var gd_text: String = "func _process(delta: float) -> void:\n\tqueue_free()\n"
	var preview: Dictionary = _call_tool(server, "apply_snippet", {"path": fixture_path, "text": gd_text, "dry_run": true})
	all_passed = _check("apply_snippet previews row kinds", int(preview.get("rows", 0)) >= 1, true) and all_passed
	var before_rows: int = _reload(fixture_path).events.size()
	var applied: Dictionary = _call_tool(server, "apply_snippet", {"path": fixture_path, "text": gd_text})
	all_passed = _check("apply_snippet applies rows", int(applied.get("applied", 0)) >= 1, true) and all_passed
	all_passed = _check("the saved sheet grew", _reload(fixture_path).events.size() > before_rows, true) and all_passed
	_call_tool(server, "comment", {"path": fixture_path, "text": "inside the event", "parent": "1", "position": 0})
	var inside: EventRow = _reload(fixture_path).events[1] as EventRow
	all_passed = _check("a comment goes inside an event at its position",
		(inside.sub_events[0] as CommentRow).text if inside.sub_events[0] is CommentRow else "", "inside the event") and all_passed
	all_passed = _check("the sub-event it went in front of is still there, second",
		inside.sub_events.size() == 2 and inside.sub_events[1] is EventRow, true) and all_passed
	all_passed = _check("a parent that holds no rows is refused",
		str(_call_raw(server, "comment", {"path": fixture_path, "text": "x", "parent": "0"}).get("content", [{}])[0].get("text", "")),
		"Row 0 is not an event or a group, so rows cannot go inside it.") and all_passed

	# variable_properties on a stored sheet's variable table.
	var stored_variable: Dictionary = _call_tool(server, "variable_properties", {"path": fixture_path, "name": "hp", "set": {"attributes": {"tooltip": "Hit points"}}})
	all_passed = _check("a stored sheet's variable takes an attribute", (stored_variable.get("attributes", {}) as Dictionary).get("tooltip", ""), "Hit points") and all_passed
	all_passed = _check("and keeps it on disk", ((_reload(fixture_path).variables["hp"] as Dictionary).get("attributes", {}) as Dictionary).get("tooltip", ""), "Hit points") and all_passed

	all_passed = _check_stdio_framing() and all_passed
	all_passed = _check_script_writes(server) and all_passed
	all_passed = _check_explain_and_verify(server) and all_passed
	all_passed = _check_live_host(server, fixture_path) and all_passed
	all_passed = _check_live_script_gates(server) and all_passed
	all_passed = _check_relay_refusal() and all_passed
	all_passed = _check_live_link_on_a_dock() and all_passed
	all_passed = _check_live_link_socket(fixture_path) and all_passed
	return all_passed


## The stdio loop's framing: Godot's stdin read hands back what has arrived with its last newline
## taken off, so two lines written together come as one read and a long line can come in parts.
## And a request id comes back the way it was sent, not as the float JSON reads every number as.
static func _check_stdio_framing() -> bool:
	var relay: Script = load("res://addons/eventsheet/mcp/run_mcp_server.gd")
	var all_passed: bool = SUPPORT.pins("mcp_server_test", [
		["two lines in one read are two lines", relay.call("cut_lines", "", "{\"id\":1}\n{\"id\":2}"), [PackedStringArray(["{\"id\":1}", "{\"id\":2}"]), ""]],
		["one line with its newline taken off is a line", relay.call("cut_lines", "", "{\"id\":1}"), [PackedStringArray(["{\"id\":1}"]), ""]],
		["the first part of a line waits", relay.call("cut_lines", "", "{\"id\":"), [PackedStringArray(), "{\"id\":"]],
		["and is a line once the rest arrives", relay.call("cut_lines", "{\"id\":", "3}"), [PackedStringArray(["{\"id\":3}"]), ""]],
	])
	var answered: Dictionary = EventSheetMCPServer.new().handle_message(JSON.parse_string("{\"jsonrpc\": \"2.0\", \"id\": 4, \"method\": \"ping\"}"))
	all_passed = _check("a whole-number id is answered whole", JSON.stringify(answered.get("id")), "4") and all_passed
	all_passed = _check("a string id is answered as it was sent", EventSheetMCPServer.request_id({"id": "abc"}), "abc") and all_passed
	return all_passed


## The .gd write path: every editing tool on a script sheet, each pinned to the bytes it writes.
static func _check_script_writes(server: EventSheetMCPServer) -> bool:
	var all_passed: bool = true
	_write(SCRIPT_PATH, SCRIPT_SHEET)
	var applied: Dictionary = _call_tool(server, "comment", {"path": SCRIPT_PATH, "text": "Added by a tool"})
	all_passed = _check("a .gd sheet takes a comment, saved", bool(applied.get("saved", false)), true) and all_passed
	all_passed = _check("the comment is written as the last line of the .gd", FileAccess.get_file_as_string(SCRIPT_PATH),
		SCRIPT_SHEET + "\n# Added by a tool\n") and all_passed
	all_passed = _check("the written .gd saves back byte for byte", EventSheets.round_trips(FileAccess.get_file_as_string(SCRIPT_PATH)), true) and all_passed
	var rows: Array = _call_tool(server, "read_sheet", {"path": SCRIPT_PATH}).get("rows", []) as Array
	all_passed = _check("a .gd sheet's rows carry the lines they are written on",
		(rows.filter(func(row: Dictionary) -> bool: return str(row.get("kind")) == "variable")[0] as Dictionary).get("lines", []), [3.0, 3.0]) and all_passed
	var comment_address: String = str((rows.filter(func(row: Dictionary) -> bool: return str(row.get("kind")) == "comment")[0] as Dictionary).get("address", ""))
	_call_tool(server, "comment", {"path": SCRIPT_PATH, "text": "Rewritten", "row": comment_address})
	all_passed = _check("a comment's text is rewritten in place", FileAccess.get_file_as_string(SCRIPT_PATH).ends_with("# Rewritten\n"), true) and all_passed
	_call_tool(server, "delete_row", {"path": SCRIPT_PATH, "row": comment_address})
	all_passed = _check("delete_row takes the comment back out", FileAccess.get_file_as_string(SCRIPT_PATH), SCRIPT_SHEET) and all_passed

	# Export options and a rename, on the declaration line itself.
	_write(SCRIPT_PATH, SCRIPT_SHEET)
	var properties: Dictionary = _call_tool(server, "variable_properties", {"path": SCRIPT_PATH, "name": "speed"})
	all_passed = _check("variable_properties reads a .gd variable", [properties.get("exported"), properties.get("type"), properties.get("row")], [true, "float", "1"]) and all_passed
	_call_tool(server, "variable_properties", {"path": SCRIPT_PATH, "name": "speed", "set": {"export_hint": "@export_range(0, 10)"}})
	all_passed = _check("an export hint is written on the declaration", FileAccess.get_file_as_string(SCRIPT_PATH).get_slice("\n", 2),
		"@export_range(0, 10) var speed: float = 2.0") and all_passed
	all_passed = _check("a field that is not an export option is refused",
		bool(_call_raw(server, "variable_properties", {"path": SCRIPT_PATH, "name": "speed", "set": {"name": "x"}}).get("isError", false)), true) and all_passed
	var renamed: Dictionary = _call_tool(server, "rename", {"path": SCRIPT_PATH, "from": "speed", "to": "pace"})
	all_passed = _check("rename renames the declaration and its use", FileAccess.get_file_as_string(SCRIPT_PATH),
		"extends Node\n\n@export_range(0, 10) var pace: float = 2.0\n\n\nfunc _ready() -> void:\n\tprint(pace)\n") and all_passed
	all_passed = _check("rename counts the places", int(renamed.get("places", 0)) >= 2, true) and all_passed
	all_passed = _check("a rename onto a name already taken is refused",
		bool(_call_raw(server, "rename", {"path": SCRIPT_PATH, "from": "pace", "to": "pace"}).get("isError", false)), true) and all_passed

	# edit_row: the variable row replaced with what new GDScript converts to.
	_write(SCRIPT_PATH, SCRIPT_SHEET)
	_call_tool(server, "edit_row", {"path": SCRIPT_PATH, "row": "1", "text": "var speed: float = 3.5\n"})
	all_passed = _check("edit_row replaces the row in place", FileAccess.get_file_as_string(SCRIPT_PATH).get_slice("\n", 2), "var speed: float = 3.5") and all_passed

	# Refusals leave the bytes exactly as they were.
	var unreproducible: String = "extends Node\n\nvar a = 1"
	_write(SCRIPT_PATH, unreproducible)
	var refused: Dictionary = _call_raw(server, "comment", {"path": SCRIPT_PATH, "text": "x"})
	all_passed = _check("a .gd that does not save back byte for byte is refused", bool(refused.get("isError", false)), true) and all_passed
	all_passed = _check("and is left untouched", FileAccess.get_file_as_string(SCRIPT_PATH), unreproducible) and all_passed
	var conflicted: String = "extends Node\n<<<<<<< HEAD\nvar a = 1\n=======\nvar a = 2\n>>>>>>> other\n"
	_write(SCRIPT_PATH, conflicted)
	all_passed = _check("a .gd mid-merge is refused",
		str(_call_raw(server, "apply_snippet", {"path": SCRIPT_PATH, "text": "var b = 2\n"}).get("content", [{}])[0].get("text", "")).contains("merge conflict markers"), true) and all_passed
	all_passed = _check("and is left untouched too", FileAccess.get_file_as_string(SCRIPT_PATH), conflicted) and all_passed
	# The gate on the bytes about to be written: an edit whose result would not save back is refused.
	_write(SCRIPT_PATH, SCRIPT_SHEET)
	var outcome: Dictionary = server._mutate(SCRIPT_PATH, "probe", func(sheet: EventSheetResource) -> Dictionary:
		var block: RawCodeRow = RawCodeRow.new()
		block.code = "var tail = 1"
		sheet.events.append(block)
		var last: RawCodeRow = RawCodeRow.new()
		last.code = ""
		sheet.events.append(last)
		return {})
	var written: String = FileAccess.get_file_as_string(SCRIPT_PATH)
	all_passed = _check("whatever the edit wrote saves back byte for byte",
		outcome.has("error") or EventSheets.round_trips(written), true) and all_passed
	all_passed = _check("and a refused edit wrote nothing",
		not outcome.has("error") or written == SCRIPT_SHEET, true) and all_passed
	return all_passed


static func _check_explain_and_verify(server: EventSheetMCPServer) -> bool:
	var all_passed: bool = true
	_write(SCRIPT_PATH, SCRIPT_SHEET)
	var explained: Dictionary = _call_tool(server, "explain", {"path": SCRIPT_PATH, "line": 3})
	all_passed = _check("explain names the row a line became", [explained.get("text"), explained.get("row"), explained.get("kind"), explained.get("lines")],
		["@export var speed: float = 2.0", "1", "variable", [3.0, 3.0]]) and all_passed
	all_passed = _check("explain refuses a line past the end",
		bool(_call_raw(server, "explain", {"path": SCRIPT_PATH, "line": 99}).get("isError", false)), true) and all_passed
	_write(SCRIPT_PATH, "extends Node\n\nvar a = 1")
	all_passed = _check("explain says when a file does not save back", str(_call_tool(server, "explain", {"path": SCRIPT_PATH, "line": 3}).get("reason", "")),
		"this file does not save back byte for byte, so no line number maps") and all_passed
	var verified: Dictionary = _call_tool(server, "verify", {"paths": ["res://tests/fixtures/compiler_golden_sheet_generated.gd"]})
	all_passed = _check("verify reads the file it was given and passes it", [verified.get("files"), verified.get("passed")], [1.0, true]) and all_passed
	return all_passed


## With a live host, reads come from the open tab and edits are handed to it - the file is not written.
static func _check_live_host(server: EventSheetMCPServer, fixture_path: String) -> bool:
	var all_passed: bool = true
	var editor: FakeEditor = FakeEditor.new()
	editor.path = fixture_path
	editor.sheet = EventSheetResource.new()
	editor.sheet.host_class = "Node2D"
	server.live_host = editor
	var bytes_before: PackedByteArray = FileAccess.get_file_as_bytes(fixture_path)
	var read_live: Dictionary = _call_tool(server, "read_sheet", {"path": fixture_path})
	all_passed = _check("a live host's open sheet is what is read", [read_live.get("host_class"), read_live.get("read_from")], ["Node2D", "editor"]) and all_passed
	var applied: Dictionary = _call_tool(server, "comment", {"path": fixture_path, "text": "from the AI"})
	all_passed = _check("an edit is handed to the editor, as one named step", editor.edits, ["Add Comment"]) and all_passed
	all_passed = _check("the answer says where it went and how to undo it", [applied.get("where"), applied.get("undo"), applied.get("saved")], ["editor", "Add Comment", false]) and all_passed
	all_passed = _check("the open sheet changed", (editor.sheet.events[0] as CommentRow).text, "from the AI") and all_passed
	all_passed = _check("the file on disk did not", FileAccess.get_file_as_bytes(fixture_path) == bytes_before, true) and all_passed
	all_passed = _check("list_sheets names the open tabs", _call_tool(server, "list_sheets", {}).get("open_in_editor", []),
		[{"path": fixture_path, "unsaved": true}]) and all_passed
	server.live_host = null
	return all_passed


## Through a live host, a `.gd` passes the same gates a file write does before the tab is edited: the
## person's next save writes what the edit left, so a file that does not save back byte for byte, or
## one mid-merge, is refused and the tab is never handed the edit.
static func _check_live_script_gates(server: EventSheetMCPServer) -> bool:
	var editor: FakeEditor = FakeEditor.new()
	editor.path = SCRIPT_PATH
	editor.sheet = EventSheetResource.new()
	server.live_host = editor
	_write(SCRIPT_PATH, "extends Node\n\nvar a = 1")
	var unreproducible: String = str(_call_raw(server, "comment", {"path": SCRIPT_PATH, "text": "x"}).get("content", [{}])[0].get("text", ""))
	_write(SCRIPT_PATH, "extends Node\n<<<<<<< HEAD\nvar a = 1\n=======\nvar a = 2\n>>>>>>> other\n")
	var conflicted: String = str(_call_raw(server, "comment", {"path": SCRIPT_PATH, "text": "x"}).get("content", [{}])[0].get("text", ""))
	_write(SCRIPT_PATH, SCRIPT_SHEET)
	_call_tool(server, "comment", {"path": SCRIPT_PATH, "text": "y"})
	server.live_host = null
	return SUPPORT.pins("mcp_server_test", [
		["a tab whose file does not save back is not edited", unreproducible,
			"%s does not save back byte for byte as a sheet, so editing it here could change lines the edit never touched. Nothing was written." % SCRIPT_PATH],
		["nor one mid-merge", conflicted, "%s still holds merge conflict markers - finish the merge before editing it." % SCRIPT_PATH],
		["only the file that saves back reached the tab", editor.edits, ["Add Comment"]],
	])


## The stdio relay with no link: an edit is refused while an editor it could not join is listening,
## and served from the files otherwise; a read is always served.
static func _check_relay_refusal() -> bool:
	var relay: Script = load("res://addons/eventsheet/mcp/run_mcp_server.gd")
	var edit: Dictionary = {"jsonrpc": "2.0", "id": 4, "method": "tools/call", "params": {"name": "edit_row", "arguments": {}}}
	var read: Dictionary = {"jsonrpc": "2.0", "id": 5, "method": "tools/call", "params": {"name": "read_sheet", "arguments": {}}}
	return SUPPORT.pins("mcp_server_test", [
		["an edit beside a listening editor is refused", str(relay.call("file_edit_refusal", edit, true)).begins_with("The editor has this project open"), true],
		["an edit with no editor listening is served", relay.call("file_edit_refusal", edit, false), ""],
		["a read beside a listening editor is served", relay.call("file_edit_refusal", read, true), ""],
		["the relay's list is the core's", Array(relay.get("EDITING_TOOLS")).all(func(name: String) -> bool: return EventSheetMCPServer.edits_sheet(name)), true],
	])


## The live link against a real dock: reads its tab, edits through its undo funnel, and one undo takes
## the edit back.
static func _check_live_link_on_a_dock() -> bool:
	var all_passed: bool = true
	var tres_path: String = "user://eventsheets_mcp_live_fixture.tres"
	ResourceSaver.save(_stored_sheet(), tres_path)
	var dock: EventSheetEditor = EventSheetEditor.new()
	var history: UndoRedo = UndoRedo.new()
	dock.set_undo_redo_manager(history)
	dock.setup(ResourceLoader.load(tres_path, "", ResourceLoader.CACHE_MODE_IGNORE) as EventSheetResource)
	dock._current_sheet_path = tres_path
	dock._open_tabs[dock._active_tab_index]["path"] = tres_path
	var link: Node = LIVE_LINK.new()
	link.call("init", dock)
	var server: EventSheetMCPServer = EventSheetMCPServer.new()
	server.live_host = link
	all_passed = _check("the link hands the dock's own sheet", link.call("sheet_open_at", tres_path) == dock.get_current_sheet(), true) and all_passed
	var rows_before: int = dock.get_current_sheet().events.size()
	var applied: Dictionary = _call_tool(server, "apply_snippet", {"path": tres_path, "text": "var shield: int = 2\n", "position": 0})
	all_passed = _check("the edit went through the dock", applied.get("undo"), "Add Rows") and all_passed
	all_passed = _check("the dock's sheet has the new row first", (dock.get_current_sheet().events[0] as LocalVariable).name if dock.get_current_sheet().events[0] is LocalVariable else "", "shield") and all_passed
	all_passed = _check("the tab is marked unsaved", dock._dirty, true) and all_passed
	all_passed = _check("and the step is on the undo history", history.get_current_action_name(), "Add Rows") and all_passed
	history.undo()
	all_passed = _check("one undo takes the edit back", dock.get_current_sheet().events.size(), rows_before) and all_passed
	all_passed = _check("an edit to a sheet that is not open is refused by the link",
		str(link.call("edit_sheet", "user://not_open.tres", "x", func(_sheet: EventSheetResource) -> bool: return true).get("error", "")),
		"user://not_open.tres is not open in the editor.") and all_passed
	link.free()
	dock.free()
	history.free()
	return all_passed


## The link's socket: only a client carrying the token is answered, and it is answered line for line.
static func _check_live_link_socket(fixture_path: String) -> bool:
	var all_passed: bool = true
	var dock: EventSheetEditor = EventSheetEditor.new()
	dock.setup(ResourceLoader.load(fixture_path, "", ResourceLoader.CACHE_MODE_IGNORE) as EventSheetResource)
	var link: Node = LIVE_LINK.new()
	link.call("init", dock)
	all_passed = _check("the link reads the same switch the core does", LIVE_LINK.DISABLED_MARKER, EventSheetMCPServer.DISABLED_MARKER) and all_passed
	all_passed = _check("the link listens", bool(link.call("start")), true) and all_passed
	var details: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(LIVE_LINK.LINK_FILE))
	all_passed = _check("the link file names the port", int(details.get("port", 0)), int(link.call("port"))) and all_passed
	var stranger: StreamPeerTCP = _client(link, int(details.get("port", 0)))
	stranger.put_data("{\"token\": \"wrong\"}\n".to_utf8_buffer())
	_pump(link, stranger, 20)
	all_passed = _check("a client without the token is dropped", stranger.get_status() == StreamPeerTCP.STATUS_CONNECTED and stranger.get_available_bytes() > 0, false) and all_passed
	var client: StreamPeerTCP = _client(link, int(details.get("port", 0)))
	client.put_data((JSON.stringify({"token": str(details.get("token", ""))}) + "\n").to_utf8_buffer())
	client.put_data((JSON.stringify({"jsonrpc": "2.0", "id": 7, "method": "tools/list"}) + "\n").to_utf8_buffer())
	var replies: Array = _replies(link, client, 2)
	all_passed = _check("the token is answered with linked", replies[0] if replies.size() > 0 else {}, {"linked": true}) and all_passed
	all_passed = _check("then the call is answered with the same tools",
		(((replies[1] as Dictionary).get("result", {}) as Dictionary).get("tools", []) as Array).size() if replies.size() > 1 else 0, 14) and all_passed
	link.call("stop")
	all_passed = _check("stopping removes the link file", FileAccess.file_exists(LIVE_LINK.LINK_FILE), false) and all_passed
	client.disconnect_from_host()
	link.free()
	dock.free()
	return all_passed


static func _client(link: Node, port: int) -> StreamPeerTCP:
	var peer: StreamPeerTCP = StreamPeerTCP.new()
	peer.connect_to_host("127.0.0.1", port)
	_pump(link, peer, 20)
	return peer


static func _pump(link: Node, peer: StreamPeerTCP, frames: int) -> void:
	for frame: int in range(frames):
		link.call("_process", 0.0)
		peer.poll()
		OS.delay_msec(5)


static func _replies(link: Node, peer: StreamPeerTCP, count: int) -> Array:
	var text: String = ""
	var replies: Array = []
	for attempt: int in range(400):
		_pump(link, peer, 1)
		var available: int = peer.get_available_bytes()
		if available > 0:
			text += (peer.get_data(available)[1] as PackedByteArray).get_string_from_utf8()
		while text.contains("\n"):
			replies.append(JSON.parse_string(text.get_slice("\n", 0)))
			text = text.substr(text.find("\n") + 1)
		if replies.size() >= count:
			break
	return replies


static func _stored_sheet() -> EventSheetResource:
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
	var sub_event: EventRow = EventRow.new()
	event.sub_events.append(sub_event)
	sheet.events.append(event)
	return sheet


static func _kinds_and_addresses(rows: Array) -> Array:
	var found: Array = []
	for row: Variant in rows:
		found.append("%s@%s" % [str((row as Dictionary).get("kind")), str((row as Dictionary).get("address"))])
		found.append_array(_kinds_and_addresses((row as Dictionary).get("sub_events", []) as Array))
	return found


static func _tool_names(server: EventSheetMCPServer) -> Array:
	var names: Array = []
	var tools_response: Dictionary = server.handle_message({"jsonrpc": "2.0", "id": 3, "method": "tools/list"})
	for tool: Variant in (tools_response.get("result", {}) as Dictionary).get("tools", []):
		names.append(str((tool as Dictionary).get("name", "")))
	return names


static func _reload(path: String) -> EventSheetResource:
	return ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as EventSheetResource


static func _write(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


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
	return SUPPORT.check("mcp_server_test", label, actual, expected)
