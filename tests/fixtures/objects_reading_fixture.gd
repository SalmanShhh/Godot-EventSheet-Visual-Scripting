## A hand-written script that names every KIND of object a reader looks for, so the object model
## is proved against real lifted rows rather than against strings a test made up.
## It carries, on purpose: the script's own object (its class_name), an @onready node with a
## declared type, a bare `$Node` reference, a behaviour pack node under the same node, an
## autoload singleton, a group, and a preloaded scene.
##
## It is also a round-trip subject: opening it as a sheet and re-emitting it must reproduce this
## file byte for byte, because everything the object model does is display-only.
class_name ObjectsReadingFixture
extends CharacterBody2D

const BULLET_SCENE := preload("res://tests/fixtures/head_bullet.tscn")

@onready var hp_bar: ProgressBar = %HpBar


func _physics_process(_delta: float) -> void:
	EventForgeBridge.score += 1
	if EventForgeBridge.score > 100:
		EventForgeBridge.reset()
	$Health.take_damage(3)
	$FPSController.do_jump()
	$Sprite2D.play("run")
	hp_bar.value = 10.0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.queue_free()
