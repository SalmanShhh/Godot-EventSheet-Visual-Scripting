# The shape every multiplayer tutorial ends at: one autoload that hosts, joins, leaves, and reacts
# to the connection. Written the way a reader following a tutorial writes it - a peer declared once
# at the top and reused, a port constant, a lambda for the one-liner - so the recognisers are
# measured against what people type rather than against what the compiler emits.
extends Node

const PORT = 7000
var peer = ENetMultiplayerPeer.new()


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.server_disconnected.connect(func(): get_tree().change_scene_to_file("res://menu.tscn"))


func host() -> void:
	peer.create_server(PORT, 4)
	multiplayer.multiplayer_peer = peer


func join(ip) -> void:
	peer.create_client(ip, PORT)
	multiplayer.multiplayer_peer = peer


func leave() -> void:
	peer.close()


func _on_player_connected(id) -> void:
	if multiplayer.is_server():
		$Spawner.spawn(id)
