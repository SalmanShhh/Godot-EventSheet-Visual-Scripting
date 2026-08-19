extends CharacterBody2D

@export var speed: float = 200.0
var path: String = "res://levels/level_2.tscn"
var agent: NavigationAgent2D
var player: Node2D
var hp: int = 100


@rpc("any_peer", "call_local", "reliable")
func take_damage(amount: int) -> void:
	hp -= amount


func _ready() -> void:
	ResourceLoader.load_threaded_request("res://levels/level_2.tscn")
	add_collision_exception_with(player)


func _physics_process(delta: float) -> void:
	velocity.y += 980.0 * delta
	velocity = velocity.limit_length(speed)
	move_and_slide()
	agent.target_position = player.global_position


func aim(_delta: float) -> void:
	take_damage.rpc_id(1, 10)
	if multiplayer.is_server():
		hp = 1
	if agent.is_navigation_finished():
		hp = 3
