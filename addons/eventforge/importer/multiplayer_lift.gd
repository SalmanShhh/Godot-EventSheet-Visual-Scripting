@tool
class_name EventForgeMultiplayerLift
extends RefCounted

# E1 - the multiplayer RECOGNISERS: the spellings people actually wrote before this plugin existed.
#
# Most networked projects are older than the sheet that opens them, so every row the Multiplayer
# object offers has to be readable BACKWARDS out of hand-written GDScript. What is here is one
# matcher per spelling family, and each one hands back the exact template it matched so the row
# re-emits the author's own bytes rather than the canonical ones. That is the same trick a walrus
# variable's `inferred_type` and a flipped comparison already use, and it rides on a field that
# already exists: `ACEAction.codegen_template`, the baked template that outranks the registry. No
# second store, no parallel emitter - the row IS the spelling.
#
# What lifts here, and nothing else:
#   Host / Join   `<peer>.create_server(<port>[, <max>])` or `.create_client(<address>, <port>)`
#                 followed by `multiplayer.multiplayer_peer = <peer>` (or the `get_tree()`
#                 spelling), optionally preceded by the `var <peer> := <Kind>.new()` that declares
#                 it. THREE or more create_server arguments (channels, bandwidth) are refused on
#                 purpose: the row cannot say them, so the lines stay a script block and the
#                 coverage count says so.
#   Leave         `<peer>.close()` and the `get_tree()` spelling of `multiplayer_peer = null`.
#                 (The plain `multiplayer.multiplayer_peer = null` needs nothing here - it IS the
#                 Leave The Game template, so the shipped reverse index already claims it.)
#   Send          the NAMED-message spellings `rpc("f", …)` / `rpc(&"f", …)` / `rpc_id(1, &"f", …)`
#                 / `rpc_id(<peer>, "f", …)`, with an optional receiver in front. The callable
#                 spellings (`f.rpc(…)`, `f.rpc_id(…)`) are deliberately NOT here: the first is
#                 already the shipped Send Message To Everyone template, and the second reads
#                 through the sentence grammar, which names the message's own parameters
#                 ("Send Take Damage to the host  amount = 10") - a row cannot say more than that,
#                 and a lift is only worth making when the row reads at least as well as the line.
#   Spawn         `<node>.spawn(<data>)`, claimed by the Spawn template itself (nothing here).
#   Triggers      `multiplayer.<signal>.connect(<handler>)` for MultiplayerAPI's five signals.
#   Owner         `set_multiplayer_authority(…)`, read as a FACT about the script rather than
#                 lifted to a row: it says who owns this object, which belongs on the sheet head.

## The five things the connection itself says, as the trigger each one lifts to. Keyed by SIGNAL and
## gated on the connect line's source being `multiplayer` (see CONNECT_SOURCE), never by the signal
## alone: `peer_connected` is a name any project could give its own signal, and a table keyed on the
## bare name would relabel every such handler in every game as "On player joined".
const SIGNAL_TRIGGERS: Dictionary = {
	"peer_connected": "OnPlayerJoined",
	"peer_disconnected": "OnPlayerLeft",
	"connected_to_server": "OnJoinedTheHost",
	"connection_failed": "OnJoinFailed",
	"server_disconnected": "OnTheHostLeft"
}

## The object a connect line names for those signals - the `multiplayer` property every node has.
const CONNECT_SOURCE: String = "multiplayer"

## ENetMultiplayerPeer's own answer when `create_server` is called without a maximum. A one-argument
## call therefore reads "for up to 32 players", which is what the game does; the baked template still
## writes the one argument the author wrote, so the file is unchanged.
const DEFAULT_MAX_PLAYERS: String = "32"

## Fragments that make a line part of the networking story, for the per-script coverage count. A
## reading of the TEXT rather than a list of ACEs, so a line that stayed a script block still counts
## against the number instead of quietly leaving it.
const NETWORKING_MARKS: Array[String] = [
	"multiplayer", "Multiplayer", "@rpc", "rpc(", "rpc_id(", "create_server(", "create_client(",
	"peer_connected", "peer_disconnected", "connected_to_server", "connection_failed",
	"server_disconnected"
]

## The peer variables the file under lift declares: name -> the peer class it was made from. Filled
## once per lift from the whole source (see note_source), because a `peer.create_server(…)` line
## cannot say on its own whether `peer` is a network peer or somebody's audio object. Static for the
## same reason `EventSheetACELifter.scene_source_path` is: it is one fact about the file being read,
## and threading it through the whole recursive body walk would say nothing extra.
static var peer_variables: Dictionary = {}

## One compiled RegEx per pattern, kept for the life of the session: these run on every statement of
## every opened file, and recompiling them per line was the whole cost of the matcher.
static var _compiled: Dictionary = {}


## Records the peer variables of one source. Called at the start of every lift; a source that
## declares none simply leaves the recognisers with nothing to match on.
static func note_source(source: String) -> void:
	peer_variables = {}
	if not source.contains("MultiplayerPeer"):
		return
	var declaration: RegEx = _regex("(?m)^[ \\t]*var[ \\t]+([A-Za-z_][A-Za-z0-9_]*)[ \\t]*(?::[ \\t]*[A-Za-z_][A-Za-z0-9_]*[ \\t]*)?:?=[ \\t]*([A-Za-z_][A-Za-z0-9_]*MultiplayerPeer)\\.new\\(\\)[ \\t]*$")
	for hit: RegExMatch in declaration.search_all(source):
		peer_variables[hit.get_string(1)] = hit.get_string(2)


## The multi-line spellings: hosting and joining, which are two or three statements that only mean
## something together. `lines` is the function body as the lifter holds it, `index` the statement to
## try and `depth` its indentation. Returns {ace_id, params, template, consumed} or {}.
static func match_run(lines: PackedStringArray, index: int, depth: int) -> Dictionary:
	var opener: String = _statement_at(lines, index, depth)
	# Every statement of every opened file passes through here, so the impossible ones are rejected on
	# a substring before any pattern runs: a run always opens on a peer being made or a connection
	# being opened, and neither word can be missing from its own line.
	if opener.is_empty() or not (opener.contains("MultiplayerPeer") or opener.contains("create_server(") \
			or opener.contains("create_client(")):
		return {}
	var consumed: int = 0
	var peer_kind: String = ""
	var declared: Dictionary = _match_peer_declaration(opener)
	if not declared.is_empty():
		peer_kind = str(declared["kind"])
		consumed = 1
		opener = _statement_at(lines, index + 1, depth)
		if opener.is_empty():
			return {}
	var call: Dictionary = _match_create_call(opener)
	if call.is_empty():
		return {}
	var peer_name: String = str(call["peer"])
	if not declared.is_empty() and str(declared["name"]) != peer_name:
		return {}
	if declared.is_empty():
		if not peer_variables.has(peer_name):
			return {}
		peer_kind = str(peer_variables[peer_name])
	consumed += 1
	var assignment: String = _statement_at(lines, index + consumed, depth)
	var assigned: Dictionary = _match_peer_assignment(assignment)
	if assigned.is_empty() or str(assigned["value"]) != peer_name:
		return {}
	consumed += 1
	var params: Dictionary = {"peer_kind": peer_kind}
	var template_lines: PackedStringArray = PackedStringArray()
	if not declared.is_empty():
		template_lines.append(str(declared["line"]).replace(peer_kind, "{peer_kind}"))
	template_lines.append(str(call["template"]))
	template_lines.append(assignment)
	params.merge(call["params"] as Dictionary)
	return {
		"ace_id": str(call["ace_id"]),
		"params": params,
		"template": "\n".join(template_lines),
		"consumed": consumed
	}


## The single-line spellings: leaving, and the named-message sends. Returns
## {ace_id, params, template} or {}. `line` is one statement, already dedented.
static func match_line(line: String) -> Dictionary:
	var text: String = line.strip_edges()
	# The same cheap rejection as match_run, for the same reason: three words, one of which every
	# spelling below has to contain.
	if not (text.contains("rpc") or text.contains(".close()") or text.contains("multiplayer_peer")):
		return {}
	var closed: RegExMatch = _regex("^([A-Za-z_][A-Za-z0-9_]*)\\.close\\(\\)$").search(text)
	if closed != null and peer_variables.has(closed.get_string(1)):
		return {"ace_id": "LeaveGame", "params": {}, "template": text}
	if text == "get_tree().get_multiplayer().multiplayer_peer = null":
		return {"ace_id": "LeaveGame", "params": {}, "template": text}
	return _match_named_send(text)


## Every `set_multiplayer_authority(…)` in a source, as the fact it is: who owns this object. One
## entry per call - {owner, keeps_children, spelling, function} - where `owner` is the expression the
## peer id comes from and `function` the function it was called in, which together are what the sheet
## head's owner band says. Nothing is lifted or rewritten here: the call itself stays the ordinary
## row it already reads as, and this only says what it MEANS.
static func owner_readings(source: String) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	var current_function: String = ""
	var header: RegEx = _regex("^func[ \\t]+([A-Za-z_][A-Za-z0-9_]*)[ \\t]*\\(")
	var call: RegEx = _regex("^[ \\t]*(?:self\\.)?set_multiplayer_authority\\((.*)\\)[ \\t]*$")
	for line: String in source.split("\n"):
		var header_match: RegExMatch = header.search(line)
		if header_match != null:
			current_function = header_match.get_string(1)
			continue
		var call_match: RegExMatch = call.search(line)
		if call_match == null:
			continue
		var arguments: PackedStringArray = EventSheetBlockRegistry.split_params_top_level(call_match.get_string(1))
		if arguments.is_empty() or arguments.size() > 2:
			continue
		found.append({
			"owner": arguments[0].strip_edges(),
			"keeps_children": arguments.size() < 2 or arguments[1].strip_edges() == "true",
			"spelling": line.strip_edges(),
			"function": current_function
		})
	return found


## Every "only some peers run this" guard in a source, as the fact it is: which function it guards,
## WHO it lets through, and which of the two shapes it was written in. One entry per guard -
## {function, runs_on, form, spelling} - where `runs_on` is "owner" or "host" and `form` is
## "early_return" or "whole_body".
##
## A reading, not a lift: both shapes already lift to rows of their own (the early return keeps its
## `return`, the wrapping `if` becomes a condition on the body), and rewriting either into the other
## would change a file the plugin promised not to touch. What the guard MEANS - this function runs on
## the owner, that one on the host - is a fact about the function, which is where it belongs.
static func guard_readings(source: String) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	var lines: PackedStringArray = source.split("\n")
	var header: RegEx = _regex("^func[ \\t]+([A-Za-z_][A-Za-z0-9_]*)[ \\t]*\\(")
	var current_function: String = ""
	var body_started: bool = false
	for index: int in range(lines.size()):
		var header_match: RegExMatch = header.search(lines[index])
		if header_match != null:
			current_function = header_match.get_string(1)
			body_started = false
			continue
		var stripped: String = lines[index].strip_edges()
		if stripped.is_empty() or stripped.begins_with("#"):
			continue
		var first_statement: bool = not body_started
		body_started = true
		if current_function.is_empty():
			continue
		var runs_on: String = _guard_subject(stripped)
		if runs_on.is_empty():
			continue
		var form: String = ""
		if stripped.begins_with("if not "):
			if stripped.ends_with(": return") or _next_statement_is_return(lines, index):
				form = "early_return"
		elif first_statement and _wraps_rest_of_body(lines, index):
			form = "whole_body"
		if form.is_empty():
			continue
		found.append({"function": current_function, "runs_on": runs_on, "form": form, "spelling": stripped})
	return found


## "owner" / "host" / "" for an `if` line, whichever question it asks.
static func _guard_subject(statement: String) -> String:
	if not statement.begins_with("if "):
		return ""
	if statement.contains("is_multiplayer_authority()"):
		return "owner"
	if statement.contains("multiplayer.is_server()"):
		return "host"
	return ""


## True when the statement after `index` is a bare `return` one level deeper - the early-return shape
## written over two lines.
static func _next_statement_is_return(lines: PackedStringArray, index: int) -> bool:
	var guard_indent: int = _indent_of(lines[index])
	for scan: int in range(index + 1, lines.size()):
		if lines[scan].strip_edges().is_empty():
			continue
		return _indent_of(lines[scan]) > guard_indent and lines[scan].strip_edges() == "return"
	return false


## True when every remaining line of this function sits INSIDE the `if` at `index` - the shape that
## wraps a whole body rather than bailing out of it.
static func _wraps_rest_of_body(lines: PackedStringArray, index: int) -> bool:
	var guard_indent: int = _indent_of(lines[index])
	var saw_body: bool = false
	for scan: int in range(index + 1, lines.size()):
		var stripped: String = lines[scan].strip_edges()
		if stripped.is_empty():
			continue
		if _indent_of(lines[scan]) <= guard_indent:
			return saw_body
		saw_body = true
	return saw_body


static func _indent_of(line: String) -> int:
	return line.length() - line.lstrip(" \t").length()


## True when a line of code is part of the networking story - the filter behind the per-script
## "reads as" count. Deliberately generous: a line this says yes to and no row claims is exactly the
## line the count should be honest about.
static func is_networking_line(text: String) -> bool:
	var stripped: String = text.strip_edges()
	if stripped.is_empty() or stripped.begins_with("#"):
		return false
	for mark: String in NETWORKING_MARKS:
		if stripped.contains(mark):
			return true
	return false


# ── the pieces ──────────────────────────────────────────────────────────────────


## The statement at `index`, dedented, or "" when there is none at exactly this depth (a blank, a
## dedent, or a line that lives deeper inside a block this run has no business reaching into).
static func _statement_at(lines: PackedStringArray, index: int, depth: int) -> String:
	if index < 0 or index >= lines.size():
		return ""
	var line: String = lines[index]
	if not line.begins_with("\t".repeat(depth)):
		return ""
	var rest: String = line.substr(depth)
	if rest.begins_with("\t") or rest.strip_edges().is_empty():
		return ""
	return rest


## `var peer := ENetMultiplayerPeer.new()` in any of its spellings -> {name, kind, line}.
static func _match_peer_declaration(line: String) -> Dictionary:
	var declared: RegExMatch = _regex("^var[ \\t]+([A-Za-z_][A-Za-z0-9_]*)[ \\t]*(?::[ \\t]*[A-Za-z_][A-Za-z0-9_]*[ \\t]*)?:?=[ \\t]*([A-Za-z_][A-Za-z0-9_]*MultiplayerPeer)\\.new\\(\\)$").search(line)
	if declared == null:
		return {}
	return {"name": declared.get_string(1), "kind": declared.get_string(2), "line": line}


## `peer.create_server(PORT, 4)` / `peer.create_client(ip, PORT)` -> the row it opens, its
## parameters, and the template that writes this exact line back. {} for every other argument count,
## which is what leaves a channels-and-bandwidth call as the script block it has to stay.
static func _match_create_call(line: String) -> Dictionary:
	var opened: RegExMatch = _regex("^([A-Za-z_][A-Za-z0-9_]*)\\.create_(server|client)\\((.*)\\)$").search(line)
	if opened == null:
		return {}
	var peer_name: String = opened.get_string(1)
	var arguments: PackedStringArray = EventSheetBlockRegistry.split_params_top_level(opened.get_string(3))
	if opened.get_string(2) == "server":
		if arguments.is_empty() or arguments.size() > 2:
			return {}
		var host_params: Dictionary = {"port": arguments[0].strip_edges(), "max_players": DEFAULT_MAX_PLAYERS}
		var host_slots: String = "{port}"
		if arguments.size() == 2:
			host_params["max_players"] = arguments[1].strip_edges()
			host_slots = "{port}, {max_players}"
		return {"ace_id": "HostGame", "peer": peer_name, "params": host_params,
			"template": "%s.create_server(%s)" % [peer_name, host_slots]}
	if arguments.size() != 2:
		return {}
	return {"ace_id": "JoinGame", "peer": peer_name,
		"params": {"address": arguments[0].strip_edges(), "port": arguments[1].strip_edges()},
		"template": "%s.create_client({address}, {port})" % peer_name}


## `multiplayer.multiplayer_peer = peer` in either spelling -> {value}.
static func _match_peer_assignment(line: String) -> Dictionary:
	var assigned: RegExMatch = _regex("^(?:multiplayer|get_tree\\(\\)\\.get_multiplayer\\(\\))\\.multiplayer_peer = ([A-Za-z_][A-Za-z0-9_]*)$").search(line)
	if assigned == null:
		return {}
	return {"value": assigned.get_string(1)}


## The message spellings that name their message as a STRING: `rpc("f", …)`, `rpc(&"f", …)`,
## `rpc_id(1, "f", …)`, `rpc_id(peer, &"f", …)`, each with an optional receiver in front. The
## receiver and the quoting ride into the template, so the line comes back exactly as it went in.
static func _match_named_send(text: String) -> Dictionary:
	var called: RegExMatch = _regex("^((?:\\$[A-Za-z0-9_/]+|%[A-Za-z0-9_]+|[A-Za-z_][A-Za-z0-9_.]*)\\.)?rpc(_id)?\\((.*)\\)$").search(text)
	if called == null:
		return {}
	var receiver: String = called.get_string(1)
	var arguments: PackedStringArray = EventSheetBlockRegistry.split_params_top_level(called.get_string(3))
	var addressed: bool = not called.get_string(2).is_empty()
	var peer_slot: String = ""
	if addressed:
		if arguments.size() < 2:
			return {}
		peer_slot = arguments[0].strip_edges()
		arguments = arguments.slice(1)
	elif arguments.is_empty():
		return {}
	var quoted: String = arguments[0].strip_edges()
	var name_form: String = _quoted_name_form(quoted)
	if name_form.is_empty():
		return {}
	var params: Dictionary = {"message": _unquote_name(quoted), "args": ", ".join(_stripped(arguments.slice(1)))}
	var slots: PackedStringArray = PackedStringArray()
	if addressed:
		if peer_slot == "1":
			slots.append("1")
		else:
			slots.append("{peer}")
			params["peer"] = peer_slot
	slots.append(name_form)
	if not str(params["args"]).is_empty():
		slots.append("{args}")
	var ace_id: String = "SendMessageToEveryone"
	if addressed:
		ace_id = "SendMessageToHost" if peer_slot == "1" else "SendMessageToPeer"
	return {"ace_id": ace_id, "params": params,
		"template": "%srpc%s(%s)" % [receiver, "_id" if addressed else "", ", ".join(slots)]}


## `&"take_damage"` -> `&"{message}"`, `"take_damage"` -> `"{message}"`, anything else -> "". The
## quoting is part of the author's spelling, so it is kept rather than normalised.
static func _quoted_name_form(argument: String) -> String:
	var body: String = argument.trim_prefix("&")
	if body.length() < 3 or not body.begins_with("\"") or not body.ends_with("\""):
		return ""
	var inner: String = body.substr(1, body.length() - 2)
	if _regex("^[A-Za-z_][A-Za-z0-9_]*$").search(inner) == null:
		return ""
	return "%s\"{message}\"" % ("&" if argument.begins_with("&") else "")


static func _unquote_name(argument: String) -> String:
	return argument.trim_prefix("&").trim_prefix("\"").trim_suffix("\"")


static func _stripped(values: PackedStringArray) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for value: String in values:
		out.append(value.strip_edges())
	return out


static func _regex(pattern: String) -> RegEx:
	if not _compiled.has(pattern):
		_compiled[pattern] = RegEx.create_from_string(pattern)
	return _compiled[pattern]
