## A scout that walks toward a target. Most of it reads as events; the node
## references with no value stay as script blocks, because there is
## no node for a row to name.
class_name Scout
extends Node2D

@export var speed: float = 200.0

@onready var target: Node2D
@onready var muzzle: Node2D

@export var cooldown: float = 0.5

@onready var shell_scene: PackedScene
@onready var spark_scene: PackedScene


func _ready() -> void:
	speed = 200.0


func _process(delta: float) -> void:
	speed += delta
