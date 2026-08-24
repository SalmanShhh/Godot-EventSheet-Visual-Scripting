# The script half of a scene that keeps a player in step: ordinary variables, with not one word about
# the network in them. Everything about replication lives in multiplayer_scene_player.tscn, which is
# exactly the split this fixture exists to prove - the sheet has to read the scene to know that `hp`
# is shared and `armour` is not.
extends CharacterBody2D

var hp: int = 100
var nickname: String = ""
var stamina: float = 1.0
var armour: int = 0


func take_damage(amount: int) -> void:
	hp -= amount
