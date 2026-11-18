extends RigidBody2D

@export var kick: float = 400.0
var mat: PhysicsMaterial = PhysicsMaterial.new()
var frames: int = 0


func _enter_tree() -> void:
	mass = 2.0
	gravity_scale = 0.5
	mat.friction = 0.8
	mat.bounce = 0.3
	physics_material_override = mat
	linear_damp = 2.0


func _on_hit(dir: Vector2) -> void:
	apply_torque_impulse(10)
	apply_impulse(dir * kick, Vector2(0, 10))
	freeze = true
	frames = Engine.get_frames_drawn()
	OS.delay_msec(500)
