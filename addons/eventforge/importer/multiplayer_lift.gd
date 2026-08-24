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
# The SINGLE-STATEMENT families (leaving, and the named-message sends) are table entries run by
# EventForgeLiftTable - a pattern, the row it means, and the captures that are values; the engine
# stores the spelling by splicing those captures out of the author's own line. The RUNS below stay
# hand-written, because two or three statements that only mean something together are not a pattern.
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
#   Spawn         `<node>.spawn(<data>)`, claimed by the Spawn template itself (nothing here); the
#                 four-line AUTO spawn (instance a scene, name it, place it, add it under the
#                 spawner's own `spawn_path`) is a run, and lifts here.
#   Triggers      `multiplayer.<signal>.connect(<handler>)` for the seven connection signals.

## The seven things the connection itself says, as the trigger each one lifts to - five off
## `MultiplayerAPI` and the two `SceneMultiplayer` adds for the handshake, all on the same
## `multiplayer` property. Keyed by SIGNAL and gated on the connect line's source being `multiplayer`
## (see CONNECT_SOURCE), never by the signal alone: `peer_connected` is a name any project could give
## its own signal, and a table keyed on the bare name would relabel every such handler in every game
## as "On player joined".
const SIGNAL_TRIGGERS: Dictionary = {
	"peer_connected": "OnPlayerJoined",
	"peer_disconnected": "OnPlayerLeft",
	"connected_to_server": "OnJoinedTheHost",
	"connection_failed": "OnJoinFailed",
	"server_disconnected": "OnTheHostLeft",
	"peer_authenticating": "OnPlayerAuthenticating",
	"peer_authentication_failed": "OnAuthenticationFailed"
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
	"server_disconnected", "peer_authenticating", "peer_authentication_failed",
	"complete_auth(", "send_auth(", "disconnect_peer(", "refuse_new_connections",
	"set_multiplayer_authority(", "get_multiplayer_authority()",
	# M4 - the scene side. `Multiplayer` above already covers a line naming either node class, so what
	# is left is the calls and the properties those two nodes answer to.
	"spawn_path", "spawn_function", "set_visibility_for(", "public_visibility",
	"add_visibility_filter(", "remove_visibility_filter("
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
	if opener.is_empty():
		return {}
	# Every statement of every opened file passes through here, so the impossible ones are rejected on
	# a substring before any pattern runs: a connection run always opens on a peer being made or a
	# connection being opened, and a spawn run always opens on a scene being instanced.
	if opener.contains("MultiplayerPeer") or opener.contains("create_server(") \
			or opener.contains("create_client("):
		return _match_connection_run(lines, index, depth, opener)
	if opener.contains(".instantiate()"):
		return _match_spawn_run(lines, index, depth, opener)
	return {}


## Hosting and joining: the two or three statements that only mean something together. `opener` is
## the statement at `index`, already dedented by the caller.
static func _match_connection_run(lines: PackedStringArray, index: int, depth: int, opener: String) -> Dictionary:
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


## M4. The four lines a networked spawn IS: make the copy, name it, place it, and hand it to the
## node the spawner watches. Deliberately the WHOLE shape and nothing looser - an `instantiate()`
## followed by an `add_child` is the commonest run in every project ever written, networked or not,
## and the one thing that makes THIS run a spawn is the last line reading `spawn_path` off a
## spawner. A three-line version, an `add_child` onto any other parent, or a name and a position in
## the other order stays the script block it is, and the per-script count says so.
static func _match_spawn_run(lines: PackedStringArray, index: int, depth: int, opener: String) -> Dictionary:
	# Group 1 is the whole head of the line - `var __spawn_a1 = load` - kept verbatim so the template
	# re-emits the author's own spelling of it (`=` or `:=`, `load` or `preload`) rather than a
	# canonical one the byte gate would then refuse.
	var made: RegExMatch = _regex("^(var[ \\t]+([A-Za-z_][A-Za-z0-9_]*)[ \\t]*:?=[ \\t]*(?:pre)?load)\\((.*)\\)\\.instantiate\\(\\)$").search(opener)
	if made == null:
		return {}
	var holder: String = made.get_string(2)
	var named: RegExMatch = _regex("^%s\\.name = (.+)$" % holder).search(_statement_at(lines, index + 1, depth))
	if named == null:
		return {}
	var placed: RegExMatch = _regex("^%s\\.position = (.+)$" % holder).search(_statement_at(lines, index + 2, depth))
	if placed == null:
		return {}
	var added: String = _statement_at(lines, index + 3, depth)
	# Godot's own samples pass `true` for a readable name, which is what makes the copy's name the
	# same on every peer - but the row says nothing about it either way, so both spellings lift and
	# the one that was written is the one that comes back.
	var tail: String = ".add_child(%s, true)" % holder
	if not added.ends_with(tail):
		tail = ".add_child(%s)" % holder
		if not added.ends_with(tail):
			return {}
	var parent: String = added.substr(0, added.length() - tail.length())
	var spawner: String = parent.get_slice(".get_node(", 0)
	if spawner.is_empty() or parent != "%s.get_node(%s.spawn_path)" % [spawner, spawner]:
		return {}
	return {
		"ace_id": "SpawnReplicatedScene",
		"params": {
			"target": spawner,
			"scene": made.get_string(3).strip_edges(),
			"name": named.get_string(1).strip_edges(),
			"at": placed.get_string(1).strip_edges()
		},
		"template": "\n".join(PackedStringArray([
			"%s({scene}).instantiate()" % made.get_string(1),
			"%s.name = {name}" % holder,
			"%s.position = {at}" % holder,
			"{target}.get_node({target}.spawn_path)%s" % tail
		])),
		"consumed": 4
	}


## The single-line spellings: leaving, and the named-message sends. Returns
## {ace_id, params, template} or {}. `line` is one statement, already dedented.
##
## Both families are TABLE entries (see lift_entries below): one statement, one pattern, and the
## matched spelling stored by splicing the row's values out of the author's own line. The runs above
## stay hand-written, because three statements that only mean something together are not a pattern.
static func match_line(line: String) -> Dictionary:
	var text: String = line.strip_edges()
	# The same cheap rejection as match_run, for the same reason: three words, one of which every
	# spelling below has to contain. Cheaper than running six patterns over every statement of a file.
	if not (text.contains("rpc") or text.contains(".close()") or text.contains("multiplayer_peer")):
		return {}
	return EventForgeLiftTable.match_line(lift_entries(), text)


## The two single-statement families, as table entries. Order is meaning: `rpc_id(1, …)` is the HOST,
## so it is asked before the entry that reads the first argument as any peer at all.
##
## What is NOT here, deliberately: the plain `multiplayer.multiplayer_peer = null`, which IS the Leave
## The Game template and so is already claimed by the shipped reverse index; and the callable sends
## (`f.rpc(…)`), the first of which is likewise the shipped Send Message To Everyone template while
## the second reads better through the sentence grammar, which can name the message's own parameters.
static func lift_entries() -> Array[Dictionary]:
	# An optional receiver in front of the call (`$Other.`, `%Ui.`, `state.`). Not a param: the row
	# says nothing about it, so it rides into the stored spelling verbatim and comes back unchanged.
	const RECEIVER: String = "(?:(?:\\$[A-Za-z0-9_/]+|%[A-Za-z0-9_]+|[A-Za-z_][A-Za-z0-9_.]*)\\.)?"
	# The message name as a STRING, in either quoting. The `&` is the author's spelling, not a value,
	# so it stays outside the capture and rides into the template the same way the receiver does.
	const NAME: String = "&?\"(?<message>[A-Za-z_][A-Za-z0-9_]*)\""
	# The separator as WRITTEN. Everything outside a param capture is kept verbatim, so a call spelled
	# without the space re-emits without it instead of being canonicalised into a byte-gate failure.
	const GAP: String = ",[ \\t]*"
	var peer_is_declared: Callable = Callable(EventForgeMultiplayerLift, "_peer_is_declared")
	return [
		{
			"id": "send_everyone_with_arguments",
			"ace_id": "SendMessageToEveryone",
			"pattern": "^%srpc\\(%s%s(?<args>.+)\\)$" % [RECEIVER, NAME, GAP],
			"params": ["message", "args"],
			"shape": "rpc(\"{message}\", {args})",
			"slots": {"message": "take_damage", "args": "10"}
		},
		{
			"id": "send_everyone",
			"ace_id": "SendMessageToEveryone",
			"pattern": "^%srpc\\(%s\\)$" % [RECEIVER, NAME],
			"params": ["message"],
			"defaults": {"args": ""},
			"shape": "rpc(\"{message}\")",
			"slots": {"message": "ping"}
		},
		{
			"id": "send_host_with_arguments",
			"ace_id": "SendMessageToHost",
			"pattern": "^%srpc_id\\(1%s%s%s(?<args>.+)\\)$" % [RECEIVER, GAP, NAME, GAP],
			"params": ["message", "args"],
			"shape": "rpc_id(1, \"{message}\", {args})",
			"slots": {"message": "take_damage", "args": "10"}
		},
		{
			"id": "send_host",
			"ace_id": "SendMessageToHost",
			"pattern": "^%srpc_id\\(1%s%s\\)$" % [RECEIVER, GAP, NAME],
			"params": ["message"],
			"defaults": {"args": ""},
			"shape": "rpc_id(1, \"{message}\")",
			"slots": {"message": "ping"}
		},
		{
			"id": "send_peer_with_arguments",
			"ace_id": "SendMessageToPeer",
			"pattern": "^%srpc_id\\((?<peer>.+?)%s%s%s(?<args>.+)\\)$" % [RECEIVER, GAP, NAME, GAP],
			"params": ["peer", "message", "args"],
			"shape": "rpc_id({peer}, \"{message}\", {args})",
			"slots": {"peer": "peer_id", "message": "heal", "args": "5"}
		},
		{
			"id": "send_peer",
			"ace_id": "SendMessageToPeer",
			"pattern": "^%srpc_id\\((?<peer>.+?)%s%s\\)$" % [RECEIVER, GAP, NAME],
			"params": ["peer", "message"],
			"defaults": {"args": ""},
			"shape": "rpc_id({peer}, \"{message}\")",
			"slots": {"peer": "peer_id", "message": "ping"}
		},
		{
			# `peer` is captured for the guard only - the row says nothing about which variable held
			# the connection, so the name stays part of the spelling and comes back as it was written.
			"id": "leave_by_closing_the_peer",
			"ace_id": "LeaveGame",
			"pattern": "^(?<peer>[A-Za-z_][A-Za-z0-9_]*)\\.close\\(\\)$",
			"guard": peer_is_declared,
			"shape": "peer.close()",
			"slots": {}
		},
		{
			"id": "leave_via_the_tree",
			"ace_id": "LeaveGame",
			"pattern": "^get_tree\\(\\)\\.get_multiplayer\\(\\)\\.multiplayer_peer = null$",
			"shape": "get_tree().get_multiplayer().multiplayer_peer = null",
			"slots": {}
		}
	]


## The guard behind `<peer>.close()`: a `close()` on anything the file did not declare as a network
## peer is somebody's file handle, or their audio stream, and lifting it would relabel their code.
static func _peer_is_declared(captures: Dictionary) -> bool:
	return peer_variables.has(str(captures.get("peer", "")))


## The peer variables a GENERATED fixture line cannot have: the harness builds `peer.close()` out of
## the entry itself, with no file around it to have declared anything. Called once per family before
## its entries are probed (see EventForgeLiftTable.FIXTURE_CONTEXT_METHOD).
static func lift_fixture_context() -> void:
	peer_variables = {"peer": "ENetMultiplayerPeer"}


## True when a line of code is part of the networking story - the filter behind the per-script
## "reads as" count. Deliberately generous: a line this says yes to and no row claims is exactly the
## line the count should be honest about.
static func is_networking_line(text: String) -> bool:
	var stripped: String = text.strip_edges()
	if stripped.is_empty() or stripped.begins_with("#"):
		return false
	# A mark inside a QUOTED RUN is a word in a message, a label, or a test's expectation - not a
	# line that talks to the network. `rpc("take_damage", 10)` still counts, because the call itself
	# is outside the quotes; `add_to_group("multiplayer")` does not, because nothing else is.
	var code: String = outside_strings(stripped)
	for mark: String in NETWORKING_MARKS:
		if code.contains(mark):
			return true
	return false


## One line with every quoted run removed, so what is left is only the code. Kept simple on purpose:
## it answers "is this word part of the code or part of a string", which needs no parser.
static func outside_strings(text: String) -> String:
	var code: String = ""
	var quote: String = ""
	var index: int = 0
	while index < text.length():
		var character: String = text[index]
		if quote.is_empty():
			if character == "\"" or character == "'":
				quote = character
			else:
				code += character
		elif character == "\\":
			index += 1
		elif character == quote:
			quote = ""
		index += 1
	return code


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


static func _regex(pattern: String) -> RegEx:
	if not _compiled.has(pattern):
		_compiled[pattern] = RegEx.create_from_string(pattern)
	return _compiled[pattern]
