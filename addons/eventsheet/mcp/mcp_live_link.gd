# Godot EventSheets - MCP server, the editor's live link.
#
# The same protocol core the headless stdio server runs (EventSheetMCPServer.handle_message), served
# from inside the running editor, so an assistant sees what the dock holds and edits through it:
#
#   - a sheet open in a tab is read as the tab holds it, unsaved edits included;
#   - an edit goes through the dock's undo funnel as one named step, so the open tab redraws, the
#     step lands in the editor's history and Ctrl+Z takes it back, and the file is written when the
#     person saves - the same as an edit they made themselves;
#   - a sheet an edit names that is not open yet is opened in a tab first, so the change is in front
#     of the person rather than written behind their back.
#
# TRANSPORT. A TCP listener on 127.0.0.1 only, on a port the system picks, newline-delimited JSON-RPC
# exactly as the stdio transport frames it. The port and a fresh random token are written to
# LINK_FILE under user:// - the project's own per-machine folder - and the first line a client sends
# must carry that token, so only something that can read this project's user folder can talk to it.
# run_mcp_server.gd reads the file and relays an AI client's stdio to here; with no editor listening
# it serves the files itself, as it always has.
#
# LIFETIME. The dock starts the link when the workspace is built and the MCP switch is on, and stops
# it when the switch is turned off or the dock goes away; nothing listens before the workspace is
# first opened. The switch is still asked per call by the core, so a call in flight when it is turned
# off is refused like any other.
@tool
extends Node

const SERVER_PATH := "res://addons/eventsheet/mcp/mcp_server.gd"

## Where the listening port and the token are written while the link is up. Removed when it stops.
const LINK_FILE := "user://eventsheets_mcp_live.json"

## The MCP switch's marker, the same file the protocol core reads (EventSheetMCPServer's
## DISABLED_MARKER): spelled here so asking whether to start costs no load of the core.
const DISABLED_MARKER := "user://eventsheets_mcp_disabled"

## How long an edit waits for a `.gd` it opened to finish reading as events. A lift past this is
## told so rather than edited half-read.
const OPEN_WAIT_MSEC := 120000

var _dock: Control = null
var _server: RefCounted = null
var _listener: TCPServer = null
var _token: String = ""
## One entry per connected client: {peer: StreamPeerTCP, pending: String, lines: Array, linked: bool,
## busy: bool}.
var _clients: Array[Dictionary] = []


## Whether the MCP switch is on: the marker file absent. Asked when the workspace opens.
static func switched_on() -> bool:
	return not FileAccess.file_exists(DISABLED_MARKER)


func init(dock: Control) -> void:
	_dock = dock


## Starts listening, and writes the port and token for the stdio relay. True when listening.
func start() -> bool:
	if _listener != null and _listener.is_listening():
		return true
	_listener = TCPServer.new()
	if _listener.listen(0, "127.0.0.1") != OK:
		_listener = null
		return false
	_token = Crypto.new().generate_random_bytes(16).hex_encode()
	var file: FileAccess = FileAccess.open(LINK_FILE, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"port": _listener.get_local_port(), "token": _token}))
		file.close()
	set_process(true)
	return true


## Stops listening, drops every client and removes the link file.
func stop() -> void:
	for client: Dictionary in _clients:
		(client.get("peer") as StreamPeerTCP).disconnect_from_host()
	_clients.clear()
	if _listener != null:
		_listener.stop()
		_listener = null
	if FileAccess.file_exists(LINK_FILE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(LINK_FILE))
	if _server != null:
		_server.set("live_host", null)
		_server = null
	set_process(false)


## The port being listened on, 0 when the link is down.
func port() -> int:
	return _listener.get_local_port() if _listener != null and _listener.is_listening() else 0


func is_listening() -> bool:
	return _listener != null and _listener.is_listening()


func _exit_tree() -> void:
	stop()


func _process(_delta: float) -> void:
	if _listener == null:
		return
	while _listener.is_connection_available():
		var peer: StreamPeerTCP = _listener.take_connection()
		if peer != null:
			_clients.append({"peer": peer, "pending": "", "lines": [], "linked": false, "busy": false})
	for client: Dictionary in _clients.duplicate():
		var peer: StreamPeerTCP = client.get("peer") as StreamPeerTCP
		peer.poll()
		if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			_clients.erase(client)
			continue
		var available: int = peer.get_available_bytes()
		if available > 0:
			var received: Array = peer.get_data(available)
			if int(received[0]) == OK:
				client["pending"] = str(client.get("pending")) + (received[1] as PackedByteArray).get_string_from_utf8()
		var pending: String = str(client.get("pending"))
		while pending.contains("\n"):
			var cut: int = pending.find("\n")
			var line: String = pending.left(cut).strip_edges()
			pending = pending.substr(cut + 1)
			if not line.is_empty():
				(client.get("lines") as Array).append(line)
		client["pending"] = pending
		if not bool(client.get("busy")) and not (client.get("lines") as Array).is_empty():
			_answer_next(client)


## Answers the client's lines one at a time, in order: an edit can wait on a sheet opening, and the
## reply to a later line must never overtake it.
func _answer_next(client: Dictionary) -> void:
	client["busy"] = true
	while not (client.get("lines") as Array).is_empty():
		var line: String = str((client.get("lines") as Array).pop_front())
		var peer: StreamPeerTCP = client.get("peer") as StreamPeerTCP
		var parsed: Variant = JSON.parse_string(line)
		if not bool(client.get("linked")):
			if parsed is Dictionary and str((parsed as Dictionary).get("token", "")) == _token and not _token.is_empty():
				client["linked"] = true
				_send(peer, {"linked": true})
				continue
			peer.disconnect_from_host()
			_clients.erase(client)
			return
		if not (parsed is Dictionary):
			_send(peer, {"jsonrpc": "2.0", "id": null, "error": {"code": -32700, "message": "Parse error"}})
			continue
		var message: Dictionary = parsed as Dictionary
		var opened: String = await _open_for_edit(message)
		var response: Variant
		if not opened.is_empty():
			response = {"jsonrpc": "2.0", "id": load(SERVER_PATH).request_id(message), "result": {
				"content": [{"type": "text", "text": opened}], "isError": true}}
		else:
			response = _core().call("handle_message", message)
		if response is Dictionary and peer.get_status() == StreamPeerTCP.STATUS_CONNECTED:
			_send(peer, response as Dictionary)
	client["busy"] = false


## The protocol core, built when the first call arrives rather than when the link starts: the link
## starts right after the workspace opens, and loading the core there would add its compile to every
## first open, used or not.
func _core() -> RefCounted:
	if _server == null:
		_server = load(SERVER_PATH).new()
		_server.set("live_host", self)
	return _server


func _send(peer: StreamPeerTCP, payload: Dictionary) -> void:
	peer.put_data((JSON.stringify(payload) + "\n").to_utf8_buffer())


## Before an editing call runs, the sheet it names is opened in a tab - and, for a `.gd`, read all
## the way into events - so the edit lands in front of the person and as one undo step. "" when the
## call may go ahead, else the reason it may not.
func _open_for_edit(message: Dictionary) -> String:
	if str(message.get("method", "")) != "tools/call" or not load(SERVER_PATH).is_enabled():
		return ""
	var params: Dictionary = message.get("params", {}) if message.get("params") is Dictionary else {}
	if not load(SERVER_PATH).edits_sheet(str(params.get("name", ""))):
		return ""
	var arguments: Dictionary = params.get("arguments", {}) if params.get("arguments") is Dictionary else {}
	if bool(arguments.get("dry_run", false)):
		return ""
	var path: String = str(arguments.get("path", ""))
	if path.get_extension() not in ["gd", "tres"] or not FileAccess.file_exists(path):
		return "Not an event sheet: %s (a .tres sheet or a .gd script)." % path
	# The files the headless server refuses to write are refused here too, before a tab opens.
	var refused: String = load(SERVER_PATH).script_edit_refusal(path)
	if not refused.is_empty():
		return refused
	if sheet_open_at(path) == null or _reading(path):
		_dock.call("open_or_focus_sheet", path)
	var waited: int = Time.get_ticks_msec()
	while _reading(path):
		if Time.get_ticks_msec() - waited > OPEN_WAIT_MSEC:
			return "%s is still being read as events - try again when it has opened." % path
		await get_tree().process_frame
	if sheet_open_at(path) == null:
		return "%s could not be opened as a sheet in the editor." % path
	return ""


## Whether the dock is still reading `path` into events on its worker thread.
func _reading(path: String) -> bool:
	var sheet_io: Object = _dock.get("_sheet_io")
	return sheet_io != null and sheet_io.get("_open_job") != null and str(sheet_io.get("_open_job_path")) == path

# ── What the protocol core asks of the editor ─────────────────────────────────


## The index of the tab holding `path` (by its own path, or the `.gd` it reads), or -1.
func _tab_index(path: String) -> int:
	var tabs: Array = _dock.get("_open_tabs")
	for index: int in range(tabs.size()):
		var tab: Dictionary = tabs[index]
		var sheet: EventSheetResource = tab.get("sheet") as EventSheetResource
		if str(tab.get("path", "")) == path or (sheet != null and sheet.external_source_path == path):
			return index
	return -1


## The sheet a tab holds for `path`, as it is now - unsaved edits included - or null.
func sheet_open_at(path: String) -> EventSheetResource:
	var index: int = _tab_index(path)
	if index < 0:
		return null
	# The active tab's live sheet is the dock's own: every edit replaces it with a fresh copy, and the
	# tab list is brought up to date only when the tab is left.
	if index == int(_dock.get("_active_tab_index")):
		return _dock.get("_current_sheet") as EventSheetResource
	return (_dock.get("_open_tabs") as Array)[index].get("sheet") as EventSheetResource


## Every open tab: [{path, unsaved}].
func open_tabs() -> Array:
	var listing: Array = []
	var tabs: Array = _dock.get("_open_tabs")
	for index: int in range(tabs.size()):
		var tab: Dictionary = tabs[index]
		var sheet: EventSheetResource = tab.get("sheet") as EventSheetResource
		var tab_path: String = sheet.external_source_path if sheet != null and not sheet.external_source_path.is_empty() else str(tab.get("path", ""))
		var unsaved: bool = bool(_dock.get("_dirty")) if index == int(_dock.get("_active_tab_index")) else bool(tab.get("dirty", false))
		listing.append({"path": tab_path, "unsaved": unsaved})
	return listing


## One edit to the sheet open at `path`, through the dock's undo funnel: its tab is brought forward,
## `mutation` (sheet -> bool, true when it changed something) runs on the live sheet, and the change
## is one step named `label` - redrawn, marked unsaved, and undone by Ctrl+Z. {} or {"error"}.
func edit_sheet(path: String, label: String, mutation: Callable) -> Dictionary:
	var index: int = _tab_index(path)
	if index < 0:
		return {"error": "%s is not open in the editor." % path}
	if index != int(_dock.get("_active_tab_index")):
		_dock.call("_activate_tab", index)
	var changed: bool = bool(_dock.call("_perform_undoable_sheet_edit", label, func() -> bool:
		return bool(mutation.call(_dock.get("_current_sheet")))))
	if not changed:
		return {"error": "The editor did not take the edit (the sheet is read-only here, or nothing changed)."}
	_dock.call("_refresh_after_edit")
	_dock.call("_mark_dirty", label)
	return {}
