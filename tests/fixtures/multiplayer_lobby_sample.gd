# The lobby autoload Godot's own high-level multiplayer documentation builds: all five connection
# signals wired in _ready to named handlers, a peer made locally inside each of create/join, and the
# error-returning spelling of create_client that the docs use to bail out early. Kept as the docs
# write it, including the parts no row can say.
extends Node

const PORT = 7000
const DEFAULT_SERVER_IP = "127.0.0.1"
const MAX_CONNECTIONS = 20

var players = {}
var player_info = {"name": "Name"}

signal player_connected(peer_id, info)
signal player_disconnected(peer_id)


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.peer_disconnected.connect(_on_player_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_ok)
	multiplayer.connection_failed.connect(_on_connected_fail)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func create_game() -> void:
	var peer := ENetMultiplayerPeer.new()
	peer.create_server(PORT, MAX_CONNECTIONS)
	multiplayer.multiplayer_peer = peer
	players[1] = player_info


func join_game() -> void:
	var peer := ENetMultiplayerPeer.new()
	peer.create_client(DEFAULT_SERVER_IP, PORT)
	multiplayer.multiplayer_peer = peer


func join_game_checked(address: String) -> int:
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(address, PORT)
	if error:
		return error
	multiplayer.multiplayer_peer = peer
	return OK


func remove_multiplayer_peer() -> void:
	multiplayer.multiplayer_peer = null


func _on_player_connected(id) -> void:
	players[id] = player_info
	player_connected.emit(id, player_info)


func _on_player_disconnected(id) -> void:
	players.erase(id)
	player_disconnected.emit(id)


func _on_connected_ok() -> void:
	players[multiplayer.get_unique_id()] = player_info


func _on_connected_fail() -> void:
	multiplayer.multiplayer_peer = null


func _on_server_disconnected() -> void:
	multiplayer.multiplayer_peer = null
	players.clear()
