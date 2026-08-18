@tool
class_name ReadingNounsFixture
extends CharacterBody2D

# A hand-written script carrying one of every shape the Construct NOUNS claim (M38 - M47), so the
# render harness can show what they read like. Never run: it exists to be OPENED.

enum State { PATROL, CHASE }

var state: int = State.PATROL
var dir: Vector2 = Vector2.ZERO
var reading: float = 0.0
var items: Array = []
var hp: int = 3

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var sfx: AudioStreamPlayer = $Sfx
@onready var hud: CanvasLayer = $HUD
@onready var boss: Node2D = $Enemies/Boss


func _ready() -> void:
	state = State.CHASE
	dir = Vector2.UP
	modulate = Color.RED
	reading = PI / 2
	sprite.play("run")
	sprite.stop()
	sfx.play()
	visible = false
	modulate.a = 0.5
	sprite.flip_h = true
	scale = Vector2(2, 2)
	rotation_degrees = 90
	look_at(boss.global_position)
	reading = global_position.distance_to(boss)
	reading = velocity.length()
	dir = dir.normalized()
	hp = get_tree().get_nodes_in_group("enemies").size()
	reading = get_viewport_rect().size.x
	dir = get_global_mouse_position()
	reading = Time.get_ticks_msec() / 1000.0
	reading = Engine.get_frames_per_second()
	get_tree().change_scene_to_file("res://scenes/menu.tscn")
	hud.visible = false
	get_node("Enemies/Boss").hp -= 10
	boss.set("hp", 3)
	hp = boss.get("hp")


func _physics_process(_delta: float) -> void:
	if is_on_wall():
		hp += 1
	if velocity.y < 0:
		hp += 1
	if items.is_empty():
		hp = 0
	if get_tree().get_nodes_in_group("enemies").size() == 0:
		hp = 2
	if boss.get("hp") > 0:
		hp = 3
	if hud.overlaps_body(boss):
		hp = 4
