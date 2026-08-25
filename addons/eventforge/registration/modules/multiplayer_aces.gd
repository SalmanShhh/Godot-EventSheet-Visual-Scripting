@tool
class_name EventForgeMultiplayerACEs
extends RefCounted

# Godot's high-level multiplayer as ONE object in the sheet's words.
#
# Once a game is connected, a networked script says four things: it sends a message, it asks whether
# it is the host, it asks whether it owns the object it is running on, and it wants to know its own
# peer id. Those were the first rows here, and their templates are EXACTLY the lines the reading
# recognises - `f.rpc(...)`,
# `f.rpc_id(1, ...)`, `multiplayer.is_server()`, `multiplayer.get_unique_id()` - so a sent message
# reads the same sentence whether it was typed by hand or picked from this vocabulary.
#
# The message itself is a function marked `@rpc`; marking it is what the function row's own menu
# does, because the annotation belongs to the function rather than to the row that sends to it.
# Everything is filed under one category so the whole vocabulary reads and picks as one object -
# Multiplayer, standing next to System, exactly as the Editor object does.
#
# Adds the other half of a networked script: joining a game at all. Hosting, joining, leaving,
# the seven things the connection itself tells a script, and the spawner's own verb. Each one names
# exactly the Godot call it compiles to (`ENetMultiplayerPeer.create_server`, `multiplayer_peer`,
# `MultiplayerAPI`'s signals, `MultiplayerSpawner.spawn`) - nothing here is a networking layer, and
# a project that already wrote those lines by hand opens on these same rows because the importer
# recognises the spellings people actually write (importer/multiplayer_lift.gd).

const F := preload("res://addons/eventforge/registration/ace_factory.gd")

## The one category every row here is filed under, which is also the object label the canvas draws.
const CATEGORY := "Multiplayer"

## The three shelves the Add event picker sorts the triggers onto, spelled as the picker's own
## "Parent: Sub" section names. ONLY the picker reads them: every descriptor keeps CATEGORY, so the
## object column still says "Multiplayer" on every row.
const SECTION_PLAYERS := "Multiplayer: Players"
const SECTION_CONNECTION := "Multiplayer: Connection"
const SECTION_SCENES := "Multiplayer: Scenes"

## The two ways a host can treat a message from a client, as the dropdown behind "Relay messages
## between players". The words are the reading; the keys are the booleans the line assigns.
const RELAY_CHOICES: Array = [
	{"key": "true", "label": "on", "note": "The host forwards a client's message on to the other clients."},
	{"key": "false", "label": "off", "note": "A client reaches the host only, which is what a host-decides game wants."}
]

## The tags the Started As row suggests before it lists the project's own. Host and client are
## what Play as host + client sets on the two test instances; dedicated_server is Godot's own.
const SERVER_ROLE_TAGS: Array[String] = ["\"host\"", "\"client\"", "\"dedicated_server\""]

## The peer classes a game can talk over, as the dropdown behind "using". ENet is Godot's own
## default; the other two exist because a browser build cannot open a raw UDP socket.
## Each kind carries the line the dropdown shows UNDER it - what the choice costs and when it is
## the right one - so the reader picks on the facts rather than on the class name. The line is read by
## the params dialog through the option's own `note`, the same source a pack's dropdown uses.
const PEER_KINDS: Array = [
	{"key": "ENetMultiplayerPeer", "label": "ENet - desktop and mobile",
		"note": "UDP, fast, and Godot's own default."},
	{"key": "WebSocketMultiplayerPeer", "label": "WebSocket - also works in a browser",
		"note": "TCP, a little slower, and the only one a browser export can open."},
	{"key": "WebRTCMultiplayerPeer", "label": "WebRTC - browser, peer to peer",
		"note": "Browser to browser, and it needs a signalling server you run yourself."}
]

## The three lines "Host a game" writes, and the three "Join a game" writes: make the peer, open the
## connection, hand it to the scene tree. Kept as ONE row because they are one decision - a reader
## who splits them has a half-connected game - and as one row they are also the shape the importer
## puts back together when it finds the same three lines in a file it did not write.
##
## The peer local carries `{uid}` for the same reason the spawn run below does: the dock bakes a
## fresh id into it at apply time, so two of these rows in one scope declare two variables. A fixed
## name compiles a lobby with a Host row and a Join row in the same `_ready` to `var __peer` twice,
## which is not GDScript at all - and nothing before the game is exported says so.
const HOST_TEMPLATE := "var __peer_{uid} := {peer_kind}.new()\n__peer_{uid}.create_server({port}, {max_players})\nmultiplayer.multiplayer_peer = __peer_{uid}"
const JOIN_TEMPLATE := "var __peer_{uid} := {peer_kind}.new()\n__peer_{uid}.create_client({address}, {port})\nmultiplayer.multiplayer_peer = __peer_{uid}"

## The four lines "Spawn a scene" writes: make the copy, name it, put it where it goes, and hand
## it to the node the spawner watches. Four because that is what Godot's AUTO spawn IS - a scene in
## the spawner's own list, added under its spawn path, copied from there onto every peer without a
## factory function anywhere. The name is set BEFORE the child goes in, because the name is what
## travels with the copy and is how the peer that owns it is worked out on the other side.
const SPAWN_SCENE_TEMPLATE := "var __spawn_{uid} = load({scene}).instantiate()\n__spawn_{uid}.name = {name}\n__spawn_{uid}.position = {at}\n{target}.get_node({target}.spawn_path).add_child(__spawn_{uid}, true)"


static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []
	descriptors.append(F.make_descriptor("Core", "SendMessageToEveryone", "Send Message To Everyone", ACEDescriptor.ACEType.ACTION, "{message}.rpc({args})", "", [F.make_param("message", "String", "print", "Message", "The function marked as a message. Every peer runs it.", "expression"), F.make_param("args", "String", "", "Values", "Values to send with the message, comma separated.", "expression")], CATEGORY, "Send {message} to everyone {args}")
		.described("Runs a message on every peer in the game, including this one when the message says so. The function must be marked as a message first.").featured())
	descriptors.append(F.make_descriptor("Core", "SendMessageToHost", "Send Message To The Host", ACEDescriptor.ACEType.ACTION, "{message}.rpc_id(1{, args})", "", [F.make_param("message", "String", "print", "Message", "The function marked as a message. Only the host runs it.", "expression"), F.make_param("args", "String", "", "Values", "Values to send with the message, comma separated.", "expression")], CATEGORY, "Send {message} to the host {args}")
		.described("Runs a message on the host only - the peer that decides what is true, so cheats cannot be sent straight to everybody."))
	descriptors.append(F.make_descriptor("Core", "SendMessageToPeer", "Send Message To One Peer", ACEDescriptor.ACEType.ACTION, "{message}.rpc_id({peer}{, args})", "", [F.make_param("message", "String", "print", "Message", "The function marked as a message. Only the peer you name runs it.", "expression"), F.make_param("peer", "String", "1", "Peer", "Who to send it to: the id an event handed you, or Sender to answer whoever asked.", "expression"), F.make_param("args", "String", "", "Values", "Values to send with the message, comma separated.", "expression")], CATEGORY, "Send {message} to {peer} {args}")
		.described("Runs a message on one named peer only - a private reply, or a correction sent back to the player it is about."))
	descriptors.append(F.make_descriptor("Core", "IsHost", "Is Host", ACEDescriptor.ACEType.CONDITION, "multiplayer.is_server()", "", [], CATEGORY, "Is host")
		.described("True on the peer that is hosting the game. Put everything that decides what is true behind this.").featured())
	descriptors.append(F.make_descriptor("Core", "OwnsThisObject", "Owns This Object", ACEDescriptor.ACEType.CONDITION, "is_multiplayer_authority()", "", [], CATEGORY, "Owns this object")
		.described("True when this peer is the one allowed to move and change this object - the player's own character rather than everybody else's copy of it."))
	descriptors.append(F.make_descriptor("Core", "MyPeerId", "My ID", ACEDescriptor.ACEType.EXPRESSION, "multiplayer.get_unique_id()", "", [], CATEGORY, "MyID")
		.described("This peer's own id. The host is always 1; everyone else gets a number when they join."))
	descriptors.append_array(_connection_descriptors())
	descriptors.append_array(_lobby_descriptors())
	descriptors.append_array(_state_descriptors())
	descriptors.append_array(_connection_triggers())
	descriptors.append_array(_scene_descriptors())
	descriptors.append_array(_scene_triggers())
	return descriptors


## Hosting, joining, leaving, and the spawner's verb - the actions a lobby is made of.
static func _connection_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []
	descriptors.append(F.make_descriptor("Core", "HostGame", "Host A Game", ACEDescriptor.ACEType.ACTION, HOST_TEMPLATE, "", [
		F.make_param("port", "String", "7777", "Port", "The port players connect to. Anything from 1024 to 65535 is yours to pick; both sides must use the same number.", "net_port"),
		F.make_param("max_players", "String", "4", "Players", "How many peers may connect. The host is not one of them, so 4 here means the host plus four others.", "max_players"),
		F.make_param("peer_kind", "String", "ENetMultiplayerPeer", "Using", "How the game talks over the network. ENet unless the game runs in a browser.", "peer_kind", PEER_KINDS)
	], CATEGORY, "Host a game on port {port} for up to {max_players} players")
		.described("Opens this game to other players and makes this peer the host - the one whose answers everybody else takes as true. Nobody is connected yet; On player joined tells you when somebody is.").featured())
	descriptors.append(F.make_descriptor("Core", "JoinGame", "Join A Game", ACEDescriptor.ACEType.ACTION, JOIN_TEMPLATE, "", [
		F.make_param("address", "String", "\"127.0.0.1\"", "Address", "Where the host is. 127.0.0.1 is this same machine; on a home network it is the host's local address, and over the internet it is whatever address the host published.", "net_address"),
		F.make_param("port", "String", "7777", "Port", "The port the host opened. It has to be the same number the host used.", "net_port"),
		F.make_param("peer_kind", "String", "ENetMultiplayerPeer", "Using", "How the game talks over the network. It has to match what the host is using.", "peer_kind", PEER_KINDS)
	], CATEGORY, "Join a game at {address} port {port}")
		.described("Asks a host to let this peer in. The answer arrives later as On joined the host or On join failed - nothing is connected the moment this row runs.").featured())
	descriptors.append(F.make_descriptor("Core", "LeaveGame", "Leave The Game", ACEDescriptor.ACEType.ACTION, "multiplayer.multiplayer_peer = null", "", [], CATEGORY, "Leave the game")
		.described("Drops this peer's connection and puts the game back to single player. On the host this ends the game for everybody, because there is nobody left to answer them."))
	descriptors.append(F.make_descriptor("Core", "Spawn", "Spawn", ACEDescriptor.ACEType.ACTION, "{target}.spawn({data})", "", [
		F.make_param("target", "String", "self", "Spawner", "The MultiplayerSpawner that makes the copies. It decides which scene, and where in the tree it goes.", "expression"),
		F.make_param("data", "String", "null", "What to send", "What the spawner is told to make. A plain value when the spawner has a spawn function to read it, or nothing at all when its scene list is enough.", "expression")
	], CATEGORY, "Spawn {data}", "MultiplayerSpawner")
		.described("Makes one copy of a scene on the host and on every peer at once. Only the host may call it; everybody else receives the copy."))
	return descriptors


## The five things `MultiplayerAPI` itself says. Signal triggers like every other one: the sheet
## connects them in `_ready`, on the `multiplayer` object rather than on a node in the scene. The lobby vocabulary adds
## the two `SceneMultiplayer` says about the handshake, on the same object, for seven in all.
static func _connection_triggers() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []
	descriptors.append(F.make_descriptor("Core", "OnPlayerJoined", "On Player Joined", ACEDescriptor.ACEType.TRIGGER, "", "peer_connected", [F.make_param("id", "int", "", "Player", "The id of the peer that just joined. Whatever a new player needs is sent to this id.")], CATEGORY, "On player joined {id}")
		.described("Runs when another peer connects - on the host, and on every peer already in the game. The host is the one that hands out what a new player needs.").featured())
	descriptors.append(F.make_descriptor("Core", "OnPlayerLeft", "On Player Left", ACEDescriptor.ACEType.TRIGGER, "", "peer_disconnected", [F.make_param("id", "int", "", "Player", "The id of the peer that just left. It is already gone, so nothing can be sent to it.")], CATEGORY, "On player left {id}")
		.described("Runs when a peer disconnects, however it went - quit, crash or lost connection. Clean up whatever belonged to that player here."))
	descriptors.append(F.make_descriptor("Core", "OnJoinedTheHost", "On Joined The Host", ACEDescriptor.ACEType.TRIGGER, "", "connected_to_server", [], CATEGORY, "On joined the host")
		.described("Runs on the joining peer once the host has accepted it. This is where a lobby screen gives way to the game."))
	descriptors.append(F.make_descriptor("Core", "OnJoinFailed", "On Join Failed", ACEDescriptor.ACEType.TRIGGER, "", "connection_failed", [], CATEGORY, "On join failed")
		.described("Runs on the joining peer when the host never answered or refused it - the wrong address, the wrong port, or a game that is not accepting players."))
	descriptors.append(F.make_descriptor("Core", "OnTheHostLeft", "On The Host Left", ACEDescriptor.ACEType.TRIGGER, "", "server_disconnected", [], CATEGORY, "On the host left")
		.described("Runs on every remaining peer when the host goes away. The game is over for them: send them back to the menu here."))
	# The two the handshake says, off the same object. A game that checks a password or a token
	# before a peer counts as joined hears about it here; a game that checks nothing never sees either.
	descriptors.append(F.make_descriptor("Core", "OnPlayerAuthenticating", "On Player Authenticating", ACEDescriptor.ACEType.TRIGGER, "", "peer_authenticating", [F.make_param("id", "int", "", "Player", "The id of the peer that is trying to join. It is not in the game yet.")], CATEGORY, "On player authenticating {id}")
		.described("Runs on the host while a peer is still proving who it is - before On player joined. Answer it with Accept player or Reject player; the bytes the peer sent arrive through the auth callback."))
	descriptors.append(F.make_descriptor("Core", "OnAuthenticationFailed", "On Authentication Failed", ACEDescriptor.ACEType.TRIGGER, "", "peer_authentication_failed", [F.make_param("id", "int", "", "Player", "The id of the peer whose handshake did not finish.")], CATEGORY, "On authentication failed {id}")
		.described("Runs when a peer never proved who it was - the wrong answer, or nobody answered in time. The peer is dropped; this is where the reason is shown."))
	return descriptors


## Lobby control and the authentication handshake: the rows a host needs once players are
## actually arriving. Every one names the MultiplayerAPI call it compiles to, which is also the line
## the reading recognises when a project wrote it by hand.
static func _lobby_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []
	descriptors.append(F.make_descriptor("Core", "KickPlayer", "Kick Player", ACEDescriptor.ACEType.ACTION, "multiplayer.multiplayer_peer.disconnect_peer({id})", "", [
		F.make_param("id", "String", "1", "Player", "The peer id to drop. On player left then runs on everybody, the dropped peer included.", "expression")
	], CATEGORY, "Kick player {id}")
		.described("Drops one player's connection from the host. Only the host may do it - a client that wants somebody kicked sends the host a message and lets it decide."))
	descriptors.append(F.make_descriptor("Core", "StopAcceptingPlayers", "Stop Accepting Players", ACEDescriptor.ACEType.ACTION, "multiplayer.multiplayer_peer.refuse_new_connections = true", "", [], CATEGORY, "Stop accepting players")
		.described("Closes the lobby without ending the game: everybody already in stays, and nobody else gets in. Run it when the match starts, or when the last seat is taken."))
	descriptors.append(F.make_descriptor("Core", "SetRelay", "Relay Messages Between Players", ACEDescriptor.ACEType.ACTION, "multiplayer.server_relay = {on}", "", [
		_relay_param()
	], CATEGORY, "Relay messages between players {on}")
		.described("Whether the host forwards messages between clients. Off is the safer setting for a game where the host decides what is true, because then no client can talk to another behind its back."))
	descriptors.append(F.make_descriptor("Core", "AcceptPlayer", "Accept Player", ACEDescriptor.ACEType.ACTION, "multiplayer.complete_auth({id})", "", [
		F.make_param("id", "String", "1", "Player", "The peer whose handshake is finished - the id On player authenticating gave you.", "expression")
	], CATEGORY, "Accept player {id}")
		.described("Finishes the handshake for one peer: it counts as joined, and On player joined runs. A peer that is never accepted or rejected simply waits, so every handshake needs one of the two."))
	descriptors.append(F.make_descriptor("Core", "RejectPlayer", "Reject Player", ACEDescriptor.ACEType.ACTION, "multiplayer.multiplayer_peer.disconnect_peer({id})", "", [
		F.make_param("id", "String", "1", "Player", "The peer to turn away. It never counted as joined, so On player left does not run for it.", "expression")
	], CATEGORY, "Reject player {id}")
		.described("Turns away a peer that did not prove who it is. That peer sees On join failed; nobody else in the game hears about it."))
	descriptors.append(F.make_descriptor("Core", "SendAuth", "Send Auth", ACEDescriptor.ACEType.ACTION, "multiplayer.send_auth({id}, {data})", "", [
		F.make_param("id", "String", "1", "Player", "Who to send it to. A client answering the host sends to 1.", "expression"),
		F.make_param("data", "String", "PackedByteArray()", "Data", "The bytes to send. var_to_bytes(...) turns a value into them, and bytes_to_var(...) reads them back on the other side.", "expression")
	], CATEGORY, "Send auth {data} to player {id}")
		.described("Sends the bytes one side of the handshake wants the other to check - a password, a token, a version number. They travel before the peer counts as joined, which is why this is not an ordinary message."))
	descriptors.append(F.make_descriptor("Core", "GiveAuthority", "Give To Player", ACEDescriptor.ACEType.ACTION, "{target}.set_multiplayer_authority({id})", "", [
		F.make_param("target", "String", "self", "Object", "The node whose owner changes. Its children follow it unless one was given an owner of its own.", "expression"),
		F.make_param("id", "String", "1", "Player", "The peer that may now move and change it. Everybody else keeps a copy they may only read.", "expression")
	], CATEGORY, "Give {target} to player {id}")
		.described("Hands one object to one player: from then on that peer is the one allowed to move it, and Owns this object is true only there. Run it on every peer - a host that decides alone leaves the others disagreeing about who owns what."))
	return descriptors


## The relay dropdown. `display_option_labels` is what makes the ROW read "Relay messages between
## players off" while the line it writes still assigns `false`.
static func _relay_param() -> ACEParam:
	var parameter: ACEParam = F.make_param("on", "String", "false", "Relay", "On, the host passes a message from one client on to another. Off, a client can only reach the host.", "", RELAY_CHOICES)
	parameter.display_option_labels = true
	return parameter


## What a script asks ABOUT the connection: whether there is one, which build this is, who else
## is in the game, and who sent the message being handled.
static func _state_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []
	# Parenthesised on purpose: the row is ONE question, and a condition whose text carries a bare
	# `and` binds wrongly the moment it sits in an Or block beside another condition.
	descriptors.append(F.make_descriptor("Core", "IsConnected", "Is Connected", ACEDescriptor.ACEType.CONDITION, "(multiplayer.multiplayer_peer != null and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED)", "", [], CATEGORY, "Is connected")
		.described("True once this peer is really in a game - hosting one, or accepted by a host. It stays false while a join is still being answered, which is the moment a lobby screen has to keep waiting.").featured())
	descriptors.append(F.make_descriptor("Core", "StartedAs", "Started As", ACEDescriptor.ACEType.CONDITION, "OS.has_feature({tag})", "", [
		F.make_param("tag", "String", "\"dedicated_server\"", "Tag", "The feature tag this build was exported with. host and client are tags you add to two presets yourself; dedicated_server is the one Godot's own server preset sets.", "feature_tag", [], SERVER_ROLE_TAGS)
	], CATEGORY, "Started as {tag}")
		.described("True when this build carries the named export tag, so one project can host itself, join itself, or run headless as a server. A real server build gets its tag from the Dedicated Server export preset and is run with --headless."))
	descriptors.append(F.make_descriptor("Core", "Players", "Players", ACEDescriptor.ACEType.EXPRESSION, "multiplayer.get_peers()", "", [], CATEGORY, "Players")
		.described("The ids of every OTHER peer in the game, as a list. This peer is not in it - My ID is that one."))
	descriptors.append(F.make_descriptor("Core", "PlayerCount", "Player Count", ACEDescriptor.ACEType.EXPRESSION, "multiplayer.get_peers().size()", "", [], CATEGORY, "Player count")
		.described("How many other peers are in the game. Add one for this peer when the number a player reads should include them."))
	descriptors.append(F.make_descriptor("Core", "Sender", "Sender", ACEDescriptor.ACEType.EXPRESSION, "multiplayer.get_remote_sender_id()", "", [], CATEGORY, "Sender")
		.described("Inside a message, the id of the peer that sent it - the one thing a message cannot lie about, so check it before trusting what it asked for. It is 0 anywhere else."))
	descriptors.append(F.make_descriptor("Core", "OwnerOf", "Owner Of", ACEDescriptor.ACEType.EXPRESSION, "{target}.get_multiplayer_authority()", "", [
		F.make_param("target", "String", "self", "Object", "The node to ask about. Its owner is the peer allowed to move and change it.", "expression")
	], CATEGORY, "Owner of {target}")
		.described("The id of the peer that owns an object - the one allowed to move it. It is 1 until somebody gives it away, because the host owns everything to begin with."))
	return descriptors


## The two nodes Godot hands a networked scene to, as verbs. A `MultiplayerSpawner` makes
## one copy of a scene on every peer at once; a `MultiplayerSynchronizer` keeps the properties it
## lists in step and decides which players are allowed to see them at all. Both are configured in the
## Inspector and neither has ever had a word in the sheet - these are their rows, each naming the
## exact call it compiles to.
##
## The spawn row writes the AUTO-spawn shape rather than `spawn(data)`: a scene from the spawner's
## own list, added under its spawn path. The custom-spawn row (Spawn, above) stays what it always
## was, for a spawner that builds its copies out of a value through its own spawn function.
static func _scene_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []
	descriptors.append(F.make_descriptor("Core", "SpawnReplicatedScene", "Spawn A Scene", ACEDescriptor.ACEType.ACTION, SPAWN_SCENE_TEMPLATE, "", [
		F.make_param("target", "String", "self", "Spawner", "The MultiplayerSpawner that watches for the copy: it carries the list of scenes and the path a copy goes under.", "scene_node"),
		F.make_param("scene", "String", "\"res://player.tscn\"", "Scene", "The scene to make, from the spawner's own list of the scenes it may spawn. One that is not in the list yet is added to it when this row is applied.", "spawn_scene"),
		F.make_param("name", "String", "\"Player\"", "Name", "What to call the copy. Naming it after the player's id is the usual choice, because that is what lets the copy make that player its owner.", "expression"),
		F.make_param("at", "String", "Vector2.ZERO", "At", "Where to put it - a point for a 2D scene, a Vector3 for a 3D one. It is set before the copy joins the tree, so it never shows up at the origin first.", "expression")
	], CATEGORY, "Spawn {scene} named {name} at {at}", "MultiplayerSpawner")
		.described("Makes one copy of a scene on the host and on every peer at once. Only the host may run it, and everybody else receives the copy from the spawner - which is why the scene has to be in that spawner's list.").featured())
	descriptors.append(F.make_descriptor("Core", "Despawn", "Despawn", ACEDescriptor.ACEType.ACTION, "queue_free()", "", [], CATEGORY, "Despawn")
		.described("Takes this copy out of the game everywhere. Run it on the peer that owns the object: the spawner that made it sees it go and removes it on every other peer, so nothing has to be sent by hand."))
	descriptors.append(F.make_descriptor("Core", "ShowToPlayer", "Show To Player", ACEDescriptor.ACEType.ACTION, "set_visibility_for({id}, true)", "", [
		F.make_param("id", "String", "1", "Player", "The peer that may see it from now on. It starts receiving whatever this synchronizer keeps in step.", "expression")
	], CATEGORY, "Show to player {id}", "MultiplayerSynchronizer")
		.described("Lets one player see what this synchronizer keeps in step. Visibility is decided per peer, so a game can keep a hand of cards, a scouted unit or a room nobody else is in away from everybody but the player it belongs to."))
	descriptors.append(F.make_descriptor("Core", "HideFromPlayer", "Hide From Player", ACEDescriptor.ACEType.ACTION, "set_visibility_for({id}, false)", "", [
		F.make_param("id", "String", "1", "Player", "The peer that stops seeing it. Nothing is sent to them for this node until it is shown again.", "expression")
	], CATEGORY, "Hide from player {id}", "MultiplayerSynchronizer")
		.described("Stops sending one player anything this synchronizer keeps in step. The node is not deleted on that peer, it simply stops arriving - so a value they were never meant to see cannot be read out of the packets either."))
	descriptors.append(F.make_descriptor("Core", "ShowToEveryone", "Show To Everyone", ACEDescriptor.ACEType.ACTION, "public_visibility = true", "", [], CATEGORY, "Show to everyone", "MultiplayerSynchronizer")
		.described("Puts this synchronizer back to being seen by every player, whatever was shown or hidden per peer before. That is the setting it starts on, so this row is how hiding is undone rather than something a game has to say first."))
	descriptors.append(F.make_descriptor("Core", "AddVisibilityFilter", "Ask A Function Who May See It", ACEDescriptor.ACEType.ACTION, "add_visibility_filter({filter})", "", [
		F.make_param("filter", "String", "Callable()", "Function", "The function that answers. It is handed one player's id and returns true when that player may see this node - a function of this sheet, named without its brackets.", "expression")
	], CATEGORY, "Ask {filter} who may see it", "MultiplayerSynchronizer")
		.described("Hands the who-may-see-it question to a function instead of answering it player by player. It is asked again as players come and go, so a rule like same room or same team keeps itself true with no row saying so."))
	return descriptors


## The three things the scene's own two nodes say. Signal triggers like every other one, but on
## the NODE rather than on `multiplayer`: the sheet connects them in `_ready` to the spawner or the
## synchronizer the event names, which is the spelling a hand-written project already uses.
static func _scene_triggers() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []
	descriptors.append(F.make_descriptor("Core", "OnSpawned", "On Spawned", ACEDescriptor.ACEType.TRIGGER, "", "spawned", [
		F.make_param("node", "Node", "", "Copy", "The copy that has just been made - the same node, on every peer that got it.")
	], CATEGORY, "On spawned {node}", "MultiplayerSpawner")
		.described("Runs on every peer the moment this spawner makes a copy, the host included. It is where a copy is joined up to the rest of the game: a name added to a scoreboard, a camera pointed at it.").featured())
	descriptors.append(F.make_descriptor("Core", "OnDespawned", "On Despawned", ACEDescriptor.ACEType.TRIGGER, "", "despawned", [
		F.make_param("node", "Node", "", "Copy", "The copy that is going away. It is still in the tree while this runs, so it can still be asked what it was.")
	], CATEGORY, "On despawned {node}", "MultiplayerSpawner")
		.described("Runs on every peer as this spawner takes a copy away, whether its owner despawned it or the player it belonged to left the game. Clean up whatever was pointing at that copy here."))
	descriptors.append(F.make_descriptor("Core", "OnSynchronized", "On Synchronized", ACEDescriptor.ACEType.TRIGGER, "", "synchronized", [], CATEGORY, "On synchronized", "MultiplayerSynchronizer")
		.described("Runs on a peer that has just been sent new values for the properties this synchronizer keeps in step. Right for anything that has to answer a value that ARRIVED rather than one this peer changed itself."))
	return descriptors


static func section_descriptions() -> Dictionary:
	return {
		CATEGORY: "Playing together over a network: hosting and joining a game, what the connection tells you, the messages peers send each other, who is the host, and who owns which object.",
		# The three shelves the Add event picker sorts these triggers onto. WHICH trigger lands on
		# which is derived from the trigger itself (ACEPickerDialog.multiplayer_group_key), so one added
		# later is filed without a list being edited.
		SECTION_PLAYERS: "What one player did: arrived, left, or is still proving who it is. Each of these hands you that player's id.",
		SECTION_CONNECTION: "What happened to this peer's own connection: it got in, it was refused, or the host went away. None of them is about a particular player.",
		SECTION_SCENES: "What a MultiplayerSpawner or a MultiplayerSynchronizer in the scene just did - a copy made, or new values delivered."
	}
