@tool
class_name EventForgeMultiplayerACEs
extends RefCounted

# S10. Godot's high-level multiplayer as ONE object in the sheet's words.
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
# E1 adds the other half of a networked script: joining a game at all. Hosting, joining, leaving,
# the five things the connection itself tells a script, and the spawner's own verb. Each one names
# exactly the Godot call it compiles to (`ENetMultiplayerPeer.create_server`, `multiplayer_peer`,
# `MultiplayerAPI`'s signals, `MultiplayerSpawner.spawn`) - nothing here is a networking layer, and
# a project that already wrote those lines by hand opens on these same rows because the importer
# recognises the spellings people actually write (importer/multiplayer_lift.gd).

const F := preload("res://addons/eventforge/registration/ace_factory.gd")

## The one category every row here is filed under, which is also the object label the canvas draws.
const CATEGORY := "Multiplayer"

## The peer classes a game can talk over, as the dropdown behind "using". ENet is Godot's own
## default; the other two exist because a browser build cannot open a raw UDP socket.
const PEER_KINDS: Array = [
	{"key": "ENetMultiplayerPeer", "label": "ENet - desktop and mobile"},
	{"key": "WebSocketMultiplayerPeer", "label": "WebSocket - also works in a browser"},
	{"key": "WebRTCMultiplayerPeer", "label": "WebRTC - browser, peer to peer"}
]

## The three lines "Host a game" writes, and the three "Join a game" writes: make the peer, open the
## connection, hand it to the scene tree. Kept as ONE row because they are one decision - a reader
## who splits them has a half-connected game - and as one row they are also the shape the importer
## puts back together when it finds the same three lines in a file it did not write.
const HOST_TEMPLATE := "var __peer := {peer_kind}.new()\n__peer.create_server({port}, {max_players})\nmultiplayer.multiplayer_peer = __peer"
const JOIN_TEMPLATE := "var __peer := {peer_kind}.new()\n__peer.create_client({address}, {port})\nmultiplayer.multiplayer_peer = __peer"


static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []
	descriptors.append(F.make_descriptor("Core", "SendMessageToEveryone", "Send Message To Everyone", ACEDescriptor.ACEType.ACTION, "{message}.rpc({args})", "", [F.make_param("message", "String", "print", "Message", "The function marked as a message. Every peer runs it.", "expression"), F.make_param("args", "String", "", "Values", "Values to send with the message, comma separated.", "expression")], CATEGORY, "Send {message} to everyone {args}")
		.described("Runs a message on every peer in the game, including this one when the message says so. The function must be marked as a message first.").featured())
	descriptors.append(F.make_descriptor("Core", "SendMessageToHost", "Send Message To The Host", ACEDescriptor.ACEType.ACTION, "{message}.rpc_id(1{, args})", "", [F.make_param("message", "String", "print", "Message", "The function marked as a message.", "expression"), F.make_param("args", "String", "", "Values", "Values to send with the message, comma separated.", "expression")], CATEGORY, "Send {message} to the host {args}")
		.described("Runs a message on the host only - the peer that decides what is true, so cheats cannot be sent straight to everybody."))
	descriptors.append(F.make_descriptor("Core", "SendMessageToPeer", "Send Message To One Peer", ACEDescriptor.ACEType.ACTION, "{message}.rpc_id({peer}{, args})", "", [F.make_param("message", "String", "print", "Message", "The function marked as a message.", "expression"), F.make_param("peer", "String", "1", "Peer", "The peer id to send to.", "expression"), F.make_param("args", "String", "", "Values", "Values to send with the message, comma separated.", "expression")], CATEGORY, "Send {message} to {peer} {args}")
		.described("Runs a message on one named peer only - a private reply, or a correction sent back to the player it is about."))
	descriptors.append(F.make_descriptor("Core", "IsHost", "Is Host", ACEDescriptor.ACEType.CONDITION, "multiplayer.is_server()", "", [], CATEGORY, "Is host")
		.described("True on the peer that is hosting the game. Put everything that decides what is true behind this.").featured())
	descriptors.append(F.make_descriptor("Core", "OwnsThisObject", "Owns This Object", ACEDescriptor.ACEType.CONDITION, "is_multiplayer_authority()", "", [], CATEGORY, "Owns this object")
		.described("True when this peer is the one allowed to move and change this object - the player's own character rather than everybody else's copy of it."))
	descriptors.append(F.make_descriptor("Core", "MyPeerId", "My ID", ACEDescriptor.ACEType.EXPRESSION, "multiplayer.get_unique_id()", "", [], CATEGORY, "MyID")
		.described("This peer's own id. The host is always 1; everyone else gets a number when they join."))
	descriptors.append_array(_connection_descriptors())
	descriptors.append_array(_connection_triggers())
	return descriptors


## E1. Hosting, joining, leaving, and the spawner's verb - the actions a lobby is made of.
static func _connection_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []
	descriptors.append(F.make_descriptor("Core", "HostGame", "Host A Game", ACEDescriptor.ACEType.ACTION, HOST_TEMPLATE, "", [
		F.make_param("port", "String", "7777", "Port", "The port players connect to. Anything from 1024 to 65535 is yours to pick; both sides must use the same number.", "expression"),
		F.make_param("max_players", "String", "4", "Players", "How many peers may connect. The host is not one of them, so 4 here means the host plus four others.", "expression"),
		F.make_param("peer_kind", "String", "ENetMultiplayerPeer", "Using", "How the game talks over the network. ENet unless the game runs in a browser.", "", PEER_KINDS)
	], CATEGORY, "Host a game on port {port} for up to {max_players} players")
		.described("Opens this game to other players and makes this peer the host - the one whose answers everybody else takes as true. Nobody is connected yet; On player joined tells you when somebody is.").featured())
	descriptors.append(F.make_descriptor("Core", "JoinGame", "Join A Game", ACEDescriptor.ACEType.ACTION, JOIN_TEMPLATE, "", [
		F.make_param("address", "String", "\"127.0.0.1\"", "Address", "Where the host is. 127.0.0.1 is this same machine; on a home network it is the host's local address, and over the internet it is whatever address the host published.", "expression"),
		F.make_param("port", "String", "7777", "Port", "The port the host opened. It has to be the same number the host used.", "expression"),
		F.make_param("peer_kind", "String", "ENetMultiplayerPeer", "Using", "How the game talks over the network. It has to match what the host is using.", "", PEER_KINDS)
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


## E1. The five things the connection itself says. Signal triggers like every other one: the sheet
## connects them in `_ready`, on the `multiplayer` object rather than on a node in the scene.
static func _connection_triggers() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []
	descriptors.append(F.make_descriptor("Core", "OnPlayerJoined", "On Player Joined", ACEDescriptor.ACEType.TRIGGER, "", "peer_connected", [F.make_param("id", "int", "", "Player", "The id of the peer that just joined.")], CATEGORY, "On player joined {id}")
		.described("Runs when another peer connects - on the host, and on every peer already in the game. The host is the one that hands out what a new player needs.").featured())
	descriptors.append(F.make_descriptor("Core", "OnPlayerLeft", "On Player Left", ACEDescriptor.ACEType.TRIGGER, "", "peer_disconnected", [F.make_param("id", "int", "", "Player", "The id of the peer that just left.")], CATEGORY, "On player left {id}")
		.described("Runs when a peer disconnects, however it went - quit, crash or lost connection. Clean up whatever belonged to that player here."))
	descriptors.append(F.make_descriptor("Core", "OnJoinedTheHost", "On Joined The Host", ACEDescriptor.ACEType.TRIGGER, "", "connected_to_server", [], CATEGORY, "On joined the host")
		.described("Runs on the joining peer once the host has accepted it. This is where a lobby screen gives way to the game."))
	descriptors.append(F.make_descriptor("Core", "OnJoinFailed", "On Join Failed", ACEDescriptor.ACEType.TRIGGER, "", "connection_failed", [], CATEGORY, "On join failed")
		.described("Runs on the joining peer when the host never answered or refused it - the wrong address, the wrong port, or a game that is not accepting players."))
	descriptors.append(F.make_descriptor("Core", "OnTheHostLeft", "On The Host Left", ACEDescriptor.ACEType.TRIGGER, "", "server_disconnected", [], CATEGORY, "On the host left")
		.described("Runs on every remaining peer when the host goes away. The game is over for them: send them back to the menu here."))
	return descriptors


static func section_descriptions() -> Dictionary:
	return {
		CATEGORY: "Playing together over a network: hosting and joining a game, what the connection tells you, the messages peers send each other, who is the host, and who owns which object."
	}
