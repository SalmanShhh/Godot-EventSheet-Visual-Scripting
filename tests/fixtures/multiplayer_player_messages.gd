# Messages, in every spelling Godot 4 accepts. The four functions carry `@rpc` with its options in
# different orders and subsets (and one with a channel), and the sender walks all six ways a project
# writes a call: the callable form, the two string forms, the addressed forms, and a call aimed at
# another node's message.
extends CharacterBody2D

var hp: int = 100


@rpc("any_peer", "call_local", "reliable")
func take_damage(amount: int) -> void:
	hp -= amount


@rpc("call_local", "any_peer")
func heal(amount: int) -> void:
	hp += amount


@rpc("authority", "unreliable_ordered", 2)
func set_skin(skin: String) -> void:
	print(skin)


@rpc
func ping() -> void:
	print("pong")


func send_every_spelling(peer_id: int) -> void:
	take_damage.rpc(10)
	rpc(&"take_damage", 10)
	rpc("take_damage", 10)
	rpc_id(1, &"take_damage", 10)
	take_damage.rpc_id(peer_id, 10)
	rpc_id(peer_id, "heal", 5)
	$Other.take_damage.rpc(10)
	$Other.rpc(&"ping")
