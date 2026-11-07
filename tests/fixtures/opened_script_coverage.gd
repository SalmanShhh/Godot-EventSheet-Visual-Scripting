## A script that does NOT entirely read as events. Most of it lifts; two runs of @onready declarations
## with no value (there is no node for the row to read) stay as script blocks, which is what the
## reading-coverage chip counts and points a reader at.
class_name CoverageSample
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
