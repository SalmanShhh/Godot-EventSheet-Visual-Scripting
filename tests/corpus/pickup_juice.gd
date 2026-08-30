extends Area2D

## A coin that pops when you take it. Tweens, a shake, a sound and a particle burst - the pile of
## small touches every project grows once the mechanics work.

@export var value: int = 1
@export var pop_height: float = 18.0

var taken: bool = false

@onready var sprite: Sprite2D = $Sprite2D
@onready var sparkle: GPUParticles2D = $Sparkle
@onready var chime: AudioStreamPlayer2D = $Chime


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	var idle: Tween = create_tween()
	idle.set_loops()
	idle.tween_property(sprite, "position:y", -4.0, 0.6)
	idle.tween_property(sprite, "position:y", 0.0, 0.6)


func _on_body_entered(body: Node2D) -> void:
	if taken:
		return
	if not body.is_in_group("player"):
		return
	taken = true
	collect()


func collect() -> void:
	chime.play()
	sparkle.emitting = true
	var pop: Tween = create_tween()
	pop.set_parallel(true)
	pop.tween_property(sprite, "position:y", -pop_height, 0.25)
	pop.tween_property(sprite, "scale", Vector2(1.4, 1.4), 0.12)
	pop.tween_property(sprite, "modulate:a", 0.0, 0.25)
	pop.chain().tween_callback(queue_free)


func shake_camera() -> void:
	var camera: Camera2D = get_viewport().get_camera_2d()
	if camera == null:
		return
	var shake: Tween = create_tween()
	shake.tween_property(camera, "offset", Vector2(3.0, 0.0), 0.04)
	shake.tween_property(camera, "offset", Vector2(-3.0, 0.0), 0.04)
	shake.tween_property(camera, "offset", Vector2.ZERO, 0.04)
