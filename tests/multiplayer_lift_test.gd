# The multiplayer recognisers, measured against a corpus of HAND-WRITTEN multiplayer scripts.
#
# WHY A CORPUS AND NOT A FIXTURE PER ASSERTION: a fixture written to suit the lifter cannot notice
# that real code does not look like it. So tests/fixtures/multiplayer_*.gd are whole scripts in the
# shapes people actually publish - the tutorial autoload, the lobby singleton Godot's own
# documentation builds, a player with `@rpc` messages sent in every spelling Godot 4 accepts, the
# four ways an authority guard is written, the spawner, and the networking no row can say.
#
# Two things are pinned for every one of them, and the first is absolute:
#   1. BYTE-EXACT round-trip. Opening it as a sheet and saving it untouched reproduces the file.
#   2. The ROWS it reads as, by value - which spelling produced which row, and with which baked
#      template, because that template is what re-emits the author's own bytes.
# Plus the per-script networking count, and the emission of a row the SHEET authored, which has to be
# the canonical form rather than any lifted one.
@tool
class_name MultiplayerLiftTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const FIXTURE_DIR: String = "res://tests/fixtures/"

## Every ace_id the networking vocabulary adds. Checked for collisions against the WHOLE registry, because an id is a
## compatibility promise the moment it ships and two descriptors answering to one id is a silent
## coin toss over which template a row compiles through.
const NEW_ACE_IDS: Array[String] = [
	"HostGame", "JoinGame", "LeaveGame", "Spawn",
	"OnPlayerJoined", "OnPlayerLeft", "OnJoinedTheHost", "OnJoinFailed", "OnTheHostLeft"
]


static func run() -> bool:
	var ok: bool = true
	ok = _test_descriptors() and ok
	ok = _test_authored_emission() and ok
	ok = _test_network_autoload() and ok
	ok = _test_lobby_sample() and ok
	ok = _test_messages() and ok
	ok = _test_guards() and ok
	ok = _test_spawner() and ok
	ok = _test_unclaimed() and ok
	return ok


# ── the vocabulary ──────────────────────────────────────────────────────────────


static func _test_descriptors() -> bool:
	var ok: bool = true
	var counts: Dictionary = {}
	var missing_help: PackedStringArray = PackedStringArray()
	for descriptor: ACEDescriptor in ACERegistry.get_all_descriptors():
		if not NEW_ACE_IDS.has(descriptor.ace_id):
			continue
		counts[descriptor.ace_id] = int(counts.get(descriptor.ace_id, 0)) + 1
		if descriptor.description.strip_edges().is_empty():
			missing_help.append(descriptor.ace_id)
		for param: ACEParam in descriptor.params:
			if str(param.description).strip_edges().is_empty():
				missing_help.append("%s.%s" % [descriptor.ace_id, param.id])
	var duplicated: PackedStringArray = PackedStringArray()
	var absent: PackedStringArray = PackedStringArray()
	for ace_id: String in NEW_ACE_IDS:
		var seen: int = int(counts.get(ace_id, 0))
		if seen == 0:
			absent.append(ace_id)
		elif seen > 1:
			duplicated.append(ace_id)
	ok = _check("every new id is registered", absent, PackedStringArray()) and ok
	ok = _check("no new id collides with an existing one", duplicated, PackedStringArray()) and ok
	ok = _check("every new row and parameter carries real help", missing_help, PackedStringArray()) and ok

	var host: ACEDescriptor = ACERegistry.find_descriptor("Core", "HostGame")
	ok = _check("Host a game reads as a sentence", host.get_display_text(),
		"Host a game on port {port} for up to {max_players} players") and ok
	ok = _check("Host a game writes the three lines it names", host.codegen_template,
		"var __peer_{uid} := {peer_kind}.new()\n__peer_{uid}.create_server({port}, {max_players})\nmultiplayer.multiplayer_peer = __peer_{uid}") and ok
	ok = _check("Join a game reads as a sentence", ACERegistry.find_descriptor("Core", "JoinGame").get_display_text(),
		"Join a game at {address} port {port}") and ok
	ok = _check("Leave the game is the one line it names", ACERegistry.find_descriptor("Core", "LeaveGame").codegen_template,
		"multiplayer.multiplayer_peer = null") and ok
	ok = _check("Spawn is the spawner's own call", ACERegistry.find_descriptor("Core", "Spawn").codegen_template,
		"{target}.spawn({data})") and ok
	ok = _check("On player joined names the signal behind it",
		ACERegistry.find_descriptor("Core", "OnPlayerJoined").signal_name, "peer_connected") and ok
	ok = _check("On the host left names the signal behind it",
		ACERegistry.find_descriptor("Core", "OnTheHostLeft").signal_name, "server_disconnected") and ok
	return ok


## A row the SHEET authored writes the canonical form - the three-line local peer, and a connect line
## on `multiplayer` for the trigger. This is the half a lifted row deliberately does not do, so the
## two spellings are pinned in one place.
static func _test_authored_emission() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnPlayerJoined"
	event.trigger_source_path = TriggerResolver.MULTIPLAYER_SOURCE
	# Both rows in ONE handler, which is what a lobby screen is: a Host button and a Join button
	# answering in the same place. The `{uid}` slot is baked at apply time, the way the dock bakes it.
	event.actions.append(_authored_action("HostGame",
		{"port": "7777", "max_players": "4", "peer_kind": "ENetMultiplayerPeer"}, "a1"))
	event.actions.append(_authored_action("JoinGame",
		{"address": "\"127.0.0.1\"", "port": "7777", "peer_kind": "WebSocketMultiplayerPeer"}, "b2"))
	event.actions.append(_authored_action("LeaveGame", {}))
	event.actions.append(_authored_action("Spawn", {"target": "$Spawner", "data": "id"}))
	sheet.events.append(event)
	var output: String = str(SheetCompiler.compile(sheet, "user://_multiplayer_authored.gd").get("output", ""))
	var ok: bool = true
	ok = _check("the trigger connects on multiplayer, in _ready", output.contains(
		"\tmultiplayer.peer_connected.connect(_on_player_joined)"), true) and ok
	ok = _check("and lands in a handler taking the peer id", output.contains(
		"func _on_player_joined(id: int) -> void:"), true) and ok
	ok = _check("an authored Host a game writes its own peer", output.contains(
		"\tvar __peer_a1 := ENetMultiplayerPeer.new()\n\t__peer_a1.create_server(7777, 4)\n\tmultiplayer.multiplayer_peer = __peer_a1"), true) and ok
	ok = _check("an authored Join a game writes the peer kind it was given", output.contains(
		"\tvar __peer_b2 := WebSocketMultiplayerPeer.new()\n\t__peer_b2.create_client(\"127.0.0.1\", 7777)"), true) and ok
	ok = _check("two connection rows in one scope declare two peers",
		_declared_peers(output), PackedStringArray(["__peer_a1", "__peer_b2"])) and ok
	ok = _check("an authored Leave the game drops the peer", output.contains(
		"\tmultiplayer.multiplayer_peer = null"), true) and ok
	ok = _check("an authored Spawn calls the spawner", output.contains("\t$Spawner.spawn(id)"), true) and ok
	return _test_two_connection_rows_parse() and ok


## The peer each connection row makes is a LOCAL, so two of those rows in one scope have to be two
## variables. A fixed name compiles a lobby - a Host button and a Join button answering in the same
## place - to `var __peer` twice, which GDScript refuses: the exported project stops parsing, and
## nothing between the row and the export says so. Parse-checked rather than read, because that is
## the failure, and both rows are ENet because that is the kind whose `create_client(address, port)`
## the row's own line is.
static func _test_two_connection_rows_parse() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnReady"
	event.actions.append(_authored_action("HostGame",
		{"port": "7777", "max_players": "4", "peer_kind": "ENetMultiplayerPeer"}, "a1"))
	event.actions.append(_authored_action("JoinGame",
		{"address": "\"127.0.0.1\"", "port": "7777", "peer_kind": "ENetMultiplayerPeer"}, "b2"))
	sheet.events.append(event)
	var compiled := GDScript.new()
	compiled.source_code = str(SheetCompiler.compile(sheet, "user://_multiplayer_two_peers.gd").get("output", ""))
	return _check("a lobby that hosts and joins in one handler parses", compiled.reload(), OK)


# ── the corpus ──────────────────────────────────────────────────────────────────


static func _test_network_autoload() -> bool:
	var sheet: EventSheetResource = _open("multiplayer_network_autoload.gd")
	var ok: bool = _roundtrips("multiplayer_network_autoload.gd", sheet)
	var hosting: ACEAction = _function_action(sheet, "host", 0)
	ok = _check("two lines and a declared peer read as Host a game", _row_of(hosting), "HostGame") and ok
	ok = _check("with the port and player count the file wrote", _params_of(hosting),
		{"peer_kind": "ENetMultiplayerPeer", "port": "PORT", "max_players": "4"}) and ok
	ok = _check("and the author's own two-line spelling baked on", _template_of(hosting),
		"peer.create_server({port}, {max_players})\nmultiplayer.multiplayer_peer = peer") and ok
	var joining: ACEAction = _function_action(sheet, "join", 0)
	ok = _check("the client twin reads as Join a game", _row_of(joining), "JoinGame") and ok
	ok = _check("with the address and port the file wrote", _params_of(joining),
		{"peer_kind": "ENetMultiplayerPeer", "address": "ip", "port": "PORT"}) and ok
	ok = _check("and its own spelling baked on", _template_of(joining),
		"peer.create_client({address}, {port})\nmultiplayer.multiplayer_peer = peer") and ok
	var leaving: ACEAction = _function_action(sheet, "leave", 0)
	ok = _check("closing the declared peer reads as Leave the game", _row_of(leaving), "LeaveGame") and ok
	ok = _check("re-emitting the author's close()", _template_of(leaving), "peer.close()") and ok

	var joined: EventRow = _event_with_trigger(sheet, "OnPlayerJoined")
	ok = _check("the peer_connected handler reads as On player joined", joined != null, true) and ok
	if joined != null:
		ok = _check("wired on the multiplayer object", joined.trigger_source_path, TriggerResolver.MULTIPLAYER_SOURCE) and ok
		ok = _check("its whole-body guard reads as Is host", _condition_ids(joined), PackedStringArray(["IsHost"])) and ok
		ok = _check("and the spawner call reads as Spawn", _row_of(joined.actions[0]), "Spawn") and ok
		ok = _check("naming the spawner and what it is sent", _params_of(joined.actions[0]),
			{"target": "$Spawner", "data": "id"}) and ok
	ok = _check("every networking line of the tutorial autoload reads as a row",
		EventSheetReadingCoverage.networking(sheet), {"read": 9, "blocked": 0, "total": 9, "percent": 100}) and ok
	ok = _check("and says so in words", EventSheetReadingCoverage.networking_text(sheet),
		"every networking line reads as a row - 9 of 9") and ok
	# The public surface answers the same two questions, so a pack that adds its own networking
	# reports the same number about the same sheet instead of inventing a second one.
	ok = _check("the public API answers the same count", EventSheets.networking_coverage(sheet),
		EventSheetReadingCoverage.networking(sheet)) and ok
	ok = _check("and the same words", EventSheets.networking_coverage_text(sheet),
		"every networking line reads as a row - 9 of 9") and ok
	ok = _check("a sheet that says nothing about the network counts nothing",
		EventSheets.networking_coverage(null), {"read": 0, "blocked": 0, "total": 0, "percent": 100}) and ok
	ok = _check("and says nothing", EventSheets.networking_coverage_text(null), "") and ok
	return ok


static func _test_lobby_sample() -> bool:
	var sheet: EventSheetResource = _open("multiplayer_lobby_sample.gd")
	var ok: bool = _roundtrips("multiplayer_lobby_sample.gd", sheet)
	var triggers: PackedStringArray = PackedStringArray()
	for event: EventRow in _events_of(sheet):
		triggers.append(event.trigger_id)
	ok = _check("all five connection signals read as their own triggers", triggers,
		PackedStringArray(["OnPlayerJoined", "OnPlayerLeft", "OnJoinedTheHost", "OnJoinFailed", "OnTheHostLeft"])) and ok

	var hosting: ACEAction = _function_action(sheet, "create_game", 0)
	ok = _check("the docs' three-line create reads as Host a game", _row_of(hosting), "HostGame") and ok
	ok = _check("with the constants it named", _params_of(hosting),
		{"peer_kind": "ENetMultiplayerPeer", "port": "PORT", "max_players": "MAX_CONNECTIONS"}) and ok
	ok = _check("and the local-peer spelling baked on", _template_of(hosting),
		"var peer := {peer_kind}.new()\npeer.create_server({port}, {max_players})\nmultiplayer.multiplayer_peer = peer") and ok
	ok = _check("its client twin reads as Join a game", _row_of(_function_action(sheet, "join_game", 0)), "JoinGame") and ok
	ok = _check("and dropping the peer reads as Leave the game",
		_row_of(_function_action(sheet, "remove_multiplayer_peer", 0)), "LeaveGame") and ok

	# The docs also keep the create_client whose ERROR they check. No row can say "and give me back
	# what it answered", so the recogniser refuses it and the lines stay the code they are.
	var checked: PackedStringArray = _function_row_ids(sheet, "join_game_checked")
	ok = _check("the error-returning spelling is refused, not guessed at", checked,
		PackedStringArray(["SetLocalVarInferred", "SetLocalVarInferred", "ReturnValue", "SetProperty", "ReturnValue"])) and ok
	ok = _check("every networking line of the lobby reads as a row",
		EventSheetReadingCoverage.networking(sheet), {"read": 19, "blocked": 0, "total": 19, "percent": 100}) and ok
	return ok


static func _test_messages() -> bool:
	var sheet: EventSheetResource = _open("multiplayer_player_messages.gd")
	var ok: bool = _roundtrips("multiplayer_player_messages.gd", sheet)
	ok = _check("an @rpc in the documented order is kept verbatim",
		_annotations_of(sheet, "take_damage"), PackedStringArray(["@rpc(\"any_peer\", \"call_local\", \"reliable\")"])) and ok
	ok = _check("so is one whose options are in another order",
		_annotations_of(sheet, "heal"), PackedStringArray(["@rpc(\"call_local\", \"any_peer\")"])) and ok
	# A channel is only ever the FOURTH argument (Godot rejects an int in any earlier slot), so the
	# spelling that carries one always names all three options first.
	ok = _check("so is one carrying a channel",
		_annotations_of(sheet, "set_skin"),
		PackedStringArray(["@rpc(\"authority\", \"call_remote\", \"unreliable_ordered\", 2)"])) and ok
	ok = _check("and the bare annotation", _annotations_of(sheet, "ping"), PackedStringArray(["@rpc"])) and ok

	var sent: PackedStringArray = _function_row_ids(sheet, "send_every_spelling")
	# Six of the eight lines read as Send rows. The two that read as something else are deliberate:
	# `take_damage.rpc_id(peer, 10)` keeps the Call Method row whose reading names the message's own
	# parameters ("Send Take Damage to peer   amount = 10"), which is more than the Send row could
	# say; and `$Other.take_damage.rpc(10)` is claimed by the shipped Send Message To Everyone
	# template exactly as it always was.
	ok = _check("every call spelling reads as the row it means", sent, PackedStringArray([
		"SendMessageToEveryone", "SendMessageToEveryone", "SendMessageToEveryone", "SendMessageToHost",
		"CallMethod", "SendMessageToPeer", "SendMessageToEveryone", "SendMessageToEveryone"])) and ok
	var templates: PackedStringArray = _function_row_templates(sheet, "send_every_spelling")
	ok = _check("and re-emits the exact spelling it matched", templates, PackedStringArray([
		"", "rpc(&\"{message}\", {args})", "rpc(\"{message}\", {args})", "rpc_id(1, &\"{message}\", {args})",
		"", "rpc_id({peer}, \"{message}\", {args})", "", "$Other.rpc(&\"{message}\")"])) and ok
	var addressed: ACEAction = _function_action(sheet, "send_every_spelling", 5)
	ok = _check("an addressed send names the peer it is aimed at", _params_of(addressed),
		{"message": "heal", "args": "5", "peer": "peer_id"}) and ok
	ok = _check("every networking line of the player script reads as a row",
		EventSheetReadingCoverage.networking(sheet), {"read": 12, "blocked": 0, "total": 12, "percent": 100}) and ok
	return ok


static func _test_guards() -> bool:
	var sheet: EventSheetResource = _open("multiplayer_authority_guards.gd")
	var ok: bool = _roundtrips("multiplayer_authority_guards.gd", sheet)
	# The whole-body shapes lift to the condition they are; the early-return shapes keep their
	# `return`, which is the shape the file wrote and the shape it gets back.
	var owns: EventRow = _event_with_trigger(sheet, "OnProcess")
	ok = _check("a body wrapped in is_multiplayer_authority reads as Owns this object",
		_condition_ids(owns), PackedStringArray(["OwnsThisObject"])) and ok
	ok = _check("a body wrapped in multiplayer.is_server reads as Is host",
		_function_condition_ids(sheet, "award_points"), PackedStringArray(["IsHost"])) and ok
	return ok


static func _test_spawner() -> bool:
	var sheet: EventSheetResource = _open("multiplayer_spawner.gd")
	var ok: bool = _roundtrips("multiplayer_spawner.gd", sheet)
	var by_path: ACEAction = _function_action(sheet, "welcome", 0)
	ok = _check("a spawner addressed by node path reads as Spawn", _row_of(by_path), "Spawn") and ok
	ok = _check("naming the node and the id it sends", _params_of(by_path), {"target": "$Spawner", "data": "id"}) and ok
	var by_variable: ACEAction = _function_action(sheet, "welcome_named", 0)
	ok = _check("so does one addressed through a variable", _row_of(by_variable), "Spawn") and ok
	ok = _check("carrying the whole record it sends", _params_of(by_variable),
		{"target": "spawner", "data": "{\"name\": \"Player\", \"id\": 2}"}) and ok
	return ok


static func _test_unclaimed() -> bool:
	var sheet: EventSheetResource = _open("multiplayer_stays_a_block.gd")
	var ok: bool = _roundtrips("multiplayer_stays_a_block.gd", sheet)
	var claimed: PackedStringArray = PackedStringArray()
	for function_entry: Variant in sheet.functions:
		for ace_id: String in _function_row_ids(sheet, (function_entry as EventFunction).function_name):
			if NEW_ACE_IDS.has(ace_id):
				claimed.append(ace_id)
	ok = _check("channels, bandwidth, compression and raw packets claim no networking row",
		claimed, PackedStringArray()) and ok
	ok = _check("the five-argument create_server keeps every argument it was given",
		_params_of(_function_action(sheet, "host_with_channels", 1)),
		{"target": "peer", "method": "create_server", "args": "PORT, 4, 2, 0, 0"}) and ok
	return ok


# ── the walk ────────────────────────────────────────────────────────────────────


static func _source(file_name: String) -> String:
	return FileAccess.get_file_as_string(FIXTURE_DIR + file_name)


static func _open(file_name: String) -> EventSheetResource:
	var path: String = FIXTURE_DIR + file_name
	return GDScriptImporter.new().import_external_source(_source(file_name), true, path)


static func _roundtrips(file_name: String, sheet: EventSheetResource) -> bool:
	var saved: String = sheet.external_source_path
	sheet.external_source_path = "user://_multiplayer_roundtrip.gd"
	var output: String = str(SheetCompiler.compile(sheet, sheet.external_source_path).get("output", ""))
	sheet.external_source_path = saved
	return _check("%s comes back byte for byte" % file_name, output == _source(file_name), true)


## A row the SHEET authored. `uid` bakes the per-row id of a template that declares locals, which is
## what the dock does at apply time and what nothing downstream does for it: a test that skipped the
## bake would pin a line no sheet ever writes.
static func _authored_action(ace_id: String, params: Dictionary, uid: String = "") -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = ace_id
	action.params = params
	if not uid.is_empty():
		action.codegen_template = ACERegistry.find_descriptor("Core", ace_id).codegen_template.replace("{uid}", uid)
	return action


## The peer locals a compiled sheet declares, in file order - the one thing two connection rows in
## one scope must not say twice.
static func _declared_peers(output: String) -> PackedStringArray:
	var declared: PackedStringArray = PackedStringArray()
	for raw_line: String in output.split("\n"):
		var line: String = raw_line.strip_edges()
		if line.begins_with("var __peer"):
			declared.append(line.get_slice(" ", 1))
	return declared


## Every top-level EventRow of a sheet, in file order. A handler anchored in place leaves an
## EventAnchorRow in the slot and its rows immediately after it, so both shapes land here.
static func _events_of(sheet: EventSheetResource) -> Array[EventRow]:
	var found: Array[EventRow] = []
	for row: Variant in sheet.events:
		if row is EventRow:
			found.append(row as EventRow)
	return found


static func _event_with_trigger(sheet: EventSheetResource, trigger_id: String) -> EventRow:
	for event: EventRow in _events_of(sheet):
		if event.trigger_id == trigger_id:
			return event
	return null


static func _function_of(sheet: EventSheetResource, function_name: String) -> EventFunction:
	for entry: Variant in sheet.functions:
		if entry is EventFunction and (entry as EventFunction).function_name == function_name:
			return entry as EventFunction
	return null


## The nth ACE action of a lifted function's body, counting across its rows in order.
static func _function_action(sheet: EventSheetResource, function_name: String, index: int) -> ACEAction:
	var found: Array[ACEAction] = []
	var event_function: EventFunction = _function_of(sheet, function_name)
	if event_function != null:
		for row: Variant in event_function.events:
			if row is EventRow:
				for action: Variant in (row as EventRow).actions:
					if action is ACEAction:
						found.append(action as ACEAction)
	return found[index] if index < found.size() else null


static func _function_row_ids(sheet: EventSheetResource, function_name: String) -> PackedStringArray:
	var ids: PackedStringArray = PackedStringArray()
	var index: int = 0
	while true:
		var action: ACEAction = _function_action(sheet, function_name, index)
		if action == null:
			break
		ids.append(action.ace_id)
		index += 1
	return ids


static func _function_row_templates(sheet: EventSheetResource, function_name: String) -> PackedStringArray:
	var templates: PackedStringArray = PackedStringArray()
	var index: int = 0
	while true:
		var action: ACEAction = _function_action(sheet, function_name, index)
		if action == null:
			break
		templates.append(action.codegen_template)
		index += 1
	return templates


static func _function_condition_ids(sheet: EventSheetResource, function_name: String) -> PackedStringArray:
	var event_function: EventFunction = _function_of(sheet, function_name)
	if event_function == null:
		return PackedStringArray()
	for row: Variant in event_function.events:
		if row is EventRow and not (row as EventRow).conditions.is_empty():
			return _condition_ids(row as EventRow)
	return PackedStringArray()


static func _condition_ids(event: EventRow) -> PackedStringArray:
	var ids: PackedStringArray = PackedStringArray()
	if event == null:
		return ids
	for condition: Variant in event.conditions:
		if condition is ACECondition:
			ids.append((condition as ACECondition).ace_id)
	return ids


static func _annotations_of(sheet: EventSheetResource, function_name: String) -> PackedStringArray:
	var event_function: EventFunction = _function_of(sheet, function_name)
	return event_function.annotation_lines if event_function != null else PackedStringArray()


static func _row_of(action: ACEAction) -> String:
	return action.ace_id if action != null else "(no row)"


static func _params_of(action: ACEAction) -> Dictionary:
	return action.params if action != null else {}


static func _template_of(action: ACEAction) -> String:
	return action.codegen_template if action != null else "(no row)"


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("multiplayer_lift_test", label, actual, expected)
