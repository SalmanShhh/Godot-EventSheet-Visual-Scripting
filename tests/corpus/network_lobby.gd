extends Node

## The lobby autoload. Hosts a game, joins one, and keeps a name per peer. Written the way the
## engine's own multiplayer docs spell it, which is the shape the networking readings look for.

const PORT: int = 7777
const MAX_PLAYERS: int = 8

var peer: ENetMultiplayerPeer = null
var players: Dictionary = {}
var my_name: String = "Player"


func host_game() -> void:
	peer = ENetMultiplayerPeer.new()
	peer.create_server(PORT, MAX_PLAYERS)
	peer.host.compress(ENetConnection.COMPRESS_RANGE_CODER)
	multiplayer.multiplayer_peer = peer
	players[1] = my_name


func join_game(address: String) -> void:
	peer = ENetMultiplayerPeer.new()
	peer.create_client(address, PORT)
	multiplayer.multiplayer_peer = peer


func leave_game() -> void:
	peer.close()
	players.clear()


func announce_myself() -> void:
	rpc("register_player", my_name)


func tell_host_i_am_ready() -> void:
	rpc_id(1, "player_is_ready")


func kick(id: int) -> void:
	rpc_id(id, "you_were_kicked")


@rpc("any_peer", "call_local", "reliable")
func register_player(display_name: String) -> void:
	players[multiplayer.get_remote_sender_id()] = display_name


@rpc("any_peer", "reliable")
func player_is_ready() -> void:
	print("ready: ", multiplayer.get_remote_sender_id())


@rpc("authority", "reliable")
func you_were_kicked() -> void:
	get_tree().get_multiplayer().multiplayer_peer = null
