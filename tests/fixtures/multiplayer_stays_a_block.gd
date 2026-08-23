# The half of Godot's networking no row here can say, and must therefore not pretend to: a server
# opened with channel and bandwidth limits, ENet's own compression, and packets put on the wire by
# hand. Not one line of this becomes a Host a game / Join a game / Leave the game row - the
# recognisers refuse every one of them and the file stays the code it is, byte for byte. What the
# reader gets instead is the ordinary reading of each line (a Call Method row naming create_server
# with all five of its arguments), which is honest about what the sheet can and cannot edit here.
extends Node

const PORT = 7000


func host_with_channels() -> void:
	var peer := ENetMultiplayerPeer.new()
	peer.create_server(PORT, 4, 2, 0, 0)
	peer.host.compress(ENetConnection.COMPRESS_RANGE_CODER)
	multiplayer.multiplayer_peer = peer


func join_with_channels(address: String) -> void:
	var peer := ENetMultiplayerPeer.new()
	peer.create_client(address, PORT, 2, 0, 0, 0)
	multiplayer.multiplayer_peer = peer


func send_raw(bytes: PackedByteArray) -> void:
	multiplayer.multiplayer_peer.put_packet(bytes)


func drain_raw() -> Array:
	var received := []
	while multiplayer.multiplayer_peer.get_available_packet_count() > 0:
		received.append(multiplayer.multiplayer_peer.get_packet())
	return received
