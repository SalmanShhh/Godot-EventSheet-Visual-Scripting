## A script that does NOT entirely read as events. Most of it lifts; two runs of declarations with
## no default value and a trailing comment (the comment would be read as part of the type) stay as
## script blocks, which is what the reading-coverage chip counts and points a reader at.
class_name CoverageSample
extends Node2D

@export var speed: float = 200.0

@export var target: Node2D # set in the Inspector
@export var muzzle: Node2D # set in the Inspector

@export var cooldown: float = 0.5

@export var shell_scene: PackedScene # set in the Inspector
@export var spark_scene: PackedScene # set in the Inspector


func _ready() -> void:
	speed = 200.0


func _process(delta: float) -> void:
	speed += delta
