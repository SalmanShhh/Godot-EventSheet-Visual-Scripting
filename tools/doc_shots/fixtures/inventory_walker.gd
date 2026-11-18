extends CharacterBody2D

var items: Array = []
var inventory: Dictionary = {}
var label: String = ""


func _ready() -> void:
	items.append("sword")
	items.push_front("torch")
	items.insert(2, "rope")
	items.remove_at(0)
	inventory.erase("potion")
	items.shuffle()
	set_collision_layer_value(2, true)
	process_mode = 3
	position.y = 1000000
	rotation = 1.5707963
	call_deferred("reset")


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("jump"):
		reset()
	if Input.is_action_just_released("fire"):
		reset()


func reset() -> void:
	pass
