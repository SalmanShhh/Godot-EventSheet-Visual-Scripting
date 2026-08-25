## The object behind tests/fixtures/object_facts_player.tscn - a script that carries one of every
## thing the Object properties popup answers with, so the popup's two answers are proved against a real file rather
## than against a string a test made up: instance variables, functions (including one that answers
## yes-or-no, which is a condition on the sheet), triggers, and a family joined in code.
class_name ObjectFactsPlayer
extends CharacterBody2D

signal died

signal hit(body)

@export var max_speed: float = 300.0

var hp: int = 10

var target: Node = null


func _ready() -> void:
	add_to_group("respawnable")


func _physics_process(_delta: float) -> void:
	$Sprite2D.rotation += 0.1
	$Health.take_damage(1)
	EventForgeBridge.score += 1
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.queue_free()


func take_damage(amount: int) -> void:
	hp -= amount
	if hp <= 0:
		died.emit()


func flee() -> void:
	velocity = Vector2.LEFT


func is_alive() -> bool:
	return hp > 0
