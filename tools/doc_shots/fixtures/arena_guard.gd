extends CharacterBody3D

@export var speed: float = 6.0
@export var turn_rate: float = 90.0
@onready var target: Node3D = $"../Boss"
@onready var spawn: Marker3D = $SpawnPoint
var ground_normal: Vector3 = Vector3.UP


func _physics_process(delta: float) -> void:
	global_position += -transform.basis.z * speed * delta
	global_position += transform.basis.x * 2.0 * delta
	rotate_y(deg_to_rad(-turn_rate * delta))
	rotate_x(deg_to_rad(-15.0 * delta))
	rotate_z(deg_to_rad(30.0 * delta))


func can_see(enemy: Node3D) -> void:
	var forward := -global_transform.basis.z
	var to_enemy := (enemy.global_position - global_position).normalized()
	if forward.dot(to_enemy) > cos(deg_to_rad(45.0)):
		print("seen")


func relative(enemy: Node3D) -> void:
	if to_local(enemy.global_position).z > 0.0:
		print("behind")


func drop() -> void:
	global_position = spawn.global_position
	basis = Basis(Quaternion(Vector3.UP, ground_normal)) * basis


func ring(n: int, radius: float) -> void:
	for i in n:
		var angle := TAU * float(i) / float(n)
		var b = target.duplicate()
		add_child(b)
		b.position = position + Vector3(cos(angle), 0, sin(angle)) * radius
