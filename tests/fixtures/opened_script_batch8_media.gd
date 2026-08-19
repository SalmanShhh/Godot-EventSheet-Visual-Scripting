class_name SpriteSoundJuiceReader
extends Node2D

var dir: float = 1.0
var base_y: float = 0.0
var t: float = 0.0
var s: float = 4.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var anim_tree: AnimationTree = $AnimationTree
@onready var sfx: AudioStreamPlayer = $Sfx
@onready var music: AudioStreamPlayer = $Music
@onready var camera: Camera2D = $Camera2D
@onready var resume_button: Button = $ResumeButton
@onready var game_over: AcceptDialog = $GameOver

func _process(_delta: float) -> void:
	sprite.flip_h = dir < 0
	anim_tree.set("parameters/blend_position", dir)
	position.y = base_y + sin(t * 3.0) * 8.0
	scale = scale.lerp(Vector2.ONE, 10 * delta)

func _on_hit() -> void:
	sprite.frame = 3
	sprite.texture = load("res://hurt.png")
	anim_tree["parameters/playback"].travel("Hurt")
	camera.offset = Vector2(randf_range(-s, s), randf_range(-s, s))

func _on_jumped() -> void:
	sfx.stream = preload("res://jump.wav")
	sfx.pitch_scale = 1.1
	sfx.bus = "SFX"
	sfx.play()
	music.volume_db = linear_to_db(0.5)

func _on_pause_pressed() -> void:
	resume_button.grab_focus()
	game_over.popup_centered()
	AudioServer.set_bus_volume_db(0, linear_to_db(0.5))
