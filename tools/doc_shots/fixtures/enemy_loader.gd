extends Node

@export var stats: Resource
var hp: int = 0
var s: Resource


func _ready() -> void:
	hp = stats.hp
	s = load("res://tools/doc_shots/fixtures/slime.tres")
	ResourceSaver.save(stats, "res://tools/doc_shots/fixtures/slime.tres")
