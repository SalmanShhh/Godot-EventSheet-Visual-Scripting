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
#
# The link is looked for again before every call while there is none, so a server started before the
# editor's workspace opened, or one the editor dropped, finds the editor once it is back. And while an
# editor is listening for this project but will not take this server (a link file whose port answers
# and whose token does not), an edit is refused rather than written to a file that editor may hold
# open in a tab: its next save would overwrite the edit, or the edit its unsaved work.
@tool
extends SceneTree

const LINK_FILE := "user://eventsheets_mcp_live.json"
const SERVER_PATH := "res://addons/eventsheet/mcp/mcp_server.gd"
## How long to wait for the editor to accept the connection and answer the token.
const LINK_WAIT_MSEC := 3000
## How long one relayed call may take. An edit that opens a large `.gd` reads it into events first.
const REPLY_WAIT_MSEC := 180000
## The tools that change a sheet (EventSheetMCPServer.edits_sheet), spelled here so refusing one
## costs no load of the protocol core.
const EDITING_TOOLS: PackedStringArray = ["apply_snippet", "edit_row", "delete_row", "comment", "rename", "variable_properties"]

var _link: StreamPeerTCP = null
## Off after `-- --no-live`: the files serve every call and no editor is looked for.
var _live: bool = true
## The link file's text the last time joining it failed, and whether its port was listening then.
## A failed link is tried again only once the file changes - an editor that starts again writes a new
## port and token - so a file a closed editor left behind costs one refused connection, not one per call.
var _failed_link_text: String = ""
var _failed_link_listening: bool = false
var _pending: String = ""
## The protocol core, loaded by path on first use: naming its class here would compile it (and the
## compiler and importer behind it) before the first line is read, even in a session the editor
## answers.
var _server: RefCounted = null


func _init() -> void:
	if OS.get_cmdline_args().has("--quiet") or OS.get_cmdline_args().has("-q"):
		printerr("[Godot EventSheets] The MCP server was launched with --quiet, which silences every answer it writes. Launch it with --no-header instead.")
	_live = not OS.get_cmdline_user_args().has("--no-live")
	if _live:
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
	if _link == null and _live:
		_link = _connect_to_editor()
	var response: Variant = null
	if _link != null:
		response = _relay(message, line)
	else:
		var refused: String = file_edit_refusal(message, _live and _editor_listening())
		response = _serve(message) if refused.is_empty() else {"jsonrpc": "2.0",
			"id": int(message.get("id")) if message.get("id") is float else message.get("id"),
			"result": {"content": [{"type": "text", "text": refused}], "isError": true}}
	if response is Dictionary:
		printraw(JSON.stringify(response) + "\n")


## Why an edit must not be served from the files, or "": when an editor is listening for this project
## but did not take this server, a call that changes a sheet would write behind a tab it may hold.
static func file_edit_refusal(message: Dictionary, editor_listening: bool) -> String:
	if not editor_listening or str(message.get("method", "")) != "tools/call":
		return ""
	var params: Variant = message.get("params", {})
	var tool_name: String = str((params as Dictionary).get("name", "")) if params is Dictionary else ""
	if not (tool_name in EDITING_TOOLS):
		return ""
	return "The editor has this project open but did not accept this server's link, so this edit was not written to the file: the editor may hold the sheet in a tab, and the next save there would overwrite it. Turn the MCP switch off and on in the EventSheets dock, or restart this server, then retry."


## Whether an editor whose link this server could not join is listening for this project, as against
## a link file a closed editor left behind (or none at all).
func _editor_listening() -> bool:
	if not FileAccess.file_exists(LINK_FILE):
		return false
	return _failed_link_listening and FileAccess.get_file_as_string(LINK_FILE) == _failed_link_text


## Whether something accepts a connection on the port a link file's text names.
static func _listening(text: String) -> bool:
	var details: Variant = JSON.parse_string(text)
	if not (details is Dictionary) or int((details as Dictionary).get("port", 0)) <= 0:
		return false
	var peer: StreamPeerTCP = StreamPeerTCP.new()
	if peer.connect_to_host("127.0.0.1", int((details as Dictionary).get("port"))) != OK:
		return false
	var started: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < LINK_WAIT_MSEC:
		peer.poll()
		if peer.get_status() == StreamPeerTCP.STATUS_CONNECTED:
			peer.disconnect_from_host()
			return true
		if peer.get_status() != StreamPeerTCP.STATUS_CONNECTING:
			return false
		OS.delay_msec(10)
	return false


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
	var text: String = FileAccess.get_file_as_string(LINK_FILE)
	if text == _failed_link_text:
		return null
	var peer: StreamPeerTCP = _join(text)
	if peer == null:
		_failed_link_text = text
		_failed_link_listening = _listening(text)
	return peer


func _join(text: String) -> StreamPeerTCP:
	var details: Variant = JSON.parse_string(text)
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
