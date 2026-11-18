extends Node3D

@onready var hud_layer: CanvasLayer = $HUD


func pick_up(item: Node3D) -> void:
	item.reparent($Hand)


func drop_item(item: Node3D) -> void:
	item.reparent(get_tree().current_scene)


func holster(item: Node3D) -> void:
	item.get_parent().remove_child(item)
	$Back.add_child(item)


func mount(rider: Node3D) -> void:
	rider.reparent($Saddle, false)


func equip(hat: Node3D) -> void:
	hat.reparent($Head)
	hat.top_level = true
	var __follow_hat := RemoteTransform3D.new()
	__follow_hat.update_scale = false
	$Head.add_child(__follow_hat)
	__follow_hat.remote_path = __follow_hat.get_path_to(hat)


func stow(card: Node3D) -> void:
	card.reparent(hud_layer)


func heal_squad(leader: Node3D) -> void:
	for unit in leader.get_children():
		unit.hp += 10
