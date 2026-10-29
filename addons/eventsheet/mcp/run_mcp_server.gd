# Godot EventSheets - MCP server (stdio transport)
# Newline-delimited JSON-RPC over stdin/stdout, per the MCP stdio transport. Launch with
# --no-header so the engine banner doesn't corrupt the protocol stream:
#
#   <godot> --headless --no-header --path <project> --script addons/eventsheet/mcp/run_mcp_server.gd
#
# NOT --quiet: in Godot 4.7 it silences everything written to stdout, the answers included, so a
# client launched that way waits forever. A launch that still carries it is told so on stderr.
#
# THE EDITOR FIRST. When the project is open in the editor with its EventSheets workspace built and
# the MCP switch on, the editor is listening on 127.0.0.1 (mcp_live_link.gd) and has written its port
# and token to user://eventsheets_mcp_live.json. This loop then RELAYS every line to it, so the
# client sees the open tabs as they are and its edits land as undo steps in them. With no editor
# answering - or after `-- --no-live`, which CI and scripted runs pass - it serves the files itself
# through the same protocol core, EventSheetMCPServer (transport-free, unit-tested).
@tool
extends SceneTree

const LINK_FILE := "user://eventsheets_mcp_live.json"
const SERVER_PATH := "res://addons/eventsheet/mcp/mcp_server.gd"
## How long to wait for the editor to accept the connection and answer the token.
const LINK_WAIT_MSEC := 3000
## How long one relayed call may take. An edit that opens a large `.gd` reads it into events first.
const REPLY_WAIT_MSEC := 180000

var _link: StreamPeerTCP = null
var _pending: String = ""
## The protocol core, loaded by path on first use: naming its class here would compile it (and the
## compiler and importer behind it) before the first line is read, even in a session the editor
## answers.
var _server: RefCounted = null


func _init() -> void:
	if OS.get_cmdline_args().has("--quiet") or OS.get_cmdline_args().has("-q"):
		printerr("[Godot EventSheets] The MCP server was launched with --quiet, which silences every answer it writes. Launch it with --no-header instead.")
	if not OS.get_cmdline_user_args().has("--no-live"):
		_link = _connect_to_editor()
	var unread: String = ""
	while true:
		var chunk: String = OS.read_string_from_stdin(65536)
		if chunk.is_empty():
			break  # EOF: the client closed stdin.
		var cut: Array = cut_lines(unread, chunk)
		unread = str(cut[1])
		for line: String in cut[0] as PackedStringArray:
			_answer(line, JSON.parse_string(line))
	if not unread.strip_edges().is_empty():
		_answer(unread.strip_edges(), null)
	if _link != null:
		_link.disconnect_from_host()
	quit(0)


## The whole lines in `unread` + `chunk`, and what is left waiting: [PackedStringArray, String].
##
## read_string_from_stdin hands back whatever has arrived with its last newline taken off - one
## line, several lines at once when the client wrote faster than this answers, or the first part of
## a line too long for one read. Every piece but the last is a line; the last is one too when it is
## already a whole JSON value, and otherwise waits for the rest of itself.
static func cut_lines(unread: String, chunk: String) -> Array:
	var lines: PackedStringArray = PackedStringArray()
	var pieces: PackedStringArray = (unread + chunk).split("\n")
	for index: int in range(pieces.size()):
		var line: String = pieces[index].strip_edges()
		if line.is_empty():
			continue
		if index == pieces.size() - 1 and JSON.new().parse(line) != OK:
			return [lines, pieces[index]]
		lines.append(line)
	return [lines, ""]


## One line from the client, answered on stdout - by the editor when it is linked, else from the files.
func _answer(line: String, parsed: Variant) -> void:
	if not (parsed is Dictionary):
		printraw(JSON.stringify({"jsonrpc": "2.0", "id": null, "error": {"code": -32700, "message": "Parse error"}}) + "\n")
		return
	var message: Dictionary = parsed as Dictionary
	var response: Variant = _relay(message, line) if _link != null else _serve(message)
	if response is Dictionary:
		printraw(JSON.stringify(response) + "\n")


## The protocol core, answering from the files. Built on first use, so a session the editor answers
## never bootstraps the vocabulary twice.
func _serve(message: Dictionary) -> Variant:
	if _server == null:
		_server = load(SERVER_PATH).new()
	return _server.call("handle_message", message)


## The editor's live link, connected and past the token, or null when no editor is answering.
func _connect_to_editor() -> StreamPeerTCP:
	if not FileAccess.file_exists(LINK_FILE):
		return null
	var details: Variant = JSON.parse_string(FileAccess.get_file_as_string(LINK_FILE))
	if not (details is Dictionary) or int((details as Dictionary).get("port", 0)) <= 0:
		return null
	var peer: StreamPeerTCP = StreamPeerTCP.new()
	if peer.connect_to_host("127.0.0.1", int((details as Dictionary).get("port"))) != OK:
		return null
	var started: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < LINK_WAIT_MSEC:
		peer.poll()
		if peer.get_status() == StreamPeerTCP.STATUS_CONNECTED:
			break
		if peer.get_status() == StreamPeerTCP.STATUS_ERROR or peer.get_status() == StreamPeerTCP.STATUS_NONE:
			return null
		OS.delay_msec(10)
	if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		return null
	peer.put_data((JSON.stringify({"token": str((details as Dictionary).get("token", ""))}) + "\n").to_utf8_buffer())
	var answer: Variant = JSON.parse_string(_read_line(peer, LINK_WAIT_MSEC))
	if not (answer is Dictionary) or not bool((answer as Dictionary).get("linked", false)):
		peer.disconnect_from_host()
		return null
	return peer


## One message through the editor. A message that expects no reply (a notification) gets none. If the
## editor goes away mid-call, that call is answered with an error saying so and the files serve every
## call after it - re-running the call on the files could do twice what the editor already did.
func _relay(message: Dictionary, line: String) -> Variant:
	_link.put_data((line + "\n").to_utf8_buffer())
	var expects_reply: bool = message.has("id") and not str(message.get("method", "")).begins_with("notifications/")
	if not expects_reply:
		return null
	var reply: Variant = JSON.parse_string(_read_line(_link, REPLY_WAIT_MSEC))
	if reply is Dictionary:
		return reply
	_link.disconnect_from_host()
	_link = null
	return {"jsonrpc": "2.0", "id": int(message.get("id")) if message.get("id") is float else message.get("id"), "result": {"content": [{"type": "text",
		"text": "The editor stopped answering during this call, so whether it was applied is not known - read the sheet again before retrying. Later calls are served from the files."}], "isError": true}}


## The next newline-terminated line from `peer`, or "" when it closes or `wait_msec` passes.
func _read_line(peer: StreamPeerTCP, wait_msec: int) -> String:
	var started: int = Time.get_ticks_msec()
	while not _pending.contains("\n"):
		peer.poll()
		if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			return ""
		var available: int = peer.get_available_bytes()
		if available > 0:
			var received: Array = peer.get_data(available)
			if int(received[0]) == OK:
				_pending += (received[1] as PackedByteArray).get_string_from_utf8()
				continue
		if Time.get_ticks_msec() - started > wait_msec:
			return ""
		OS.delay_msec(5)
	var cut: int = _pending.find("\n")
	var line: String = _pending.left(cut)
	_pending = _pending.substr(cut + 1)
	return line
