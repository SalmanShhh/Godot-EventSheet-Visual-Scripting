extends Node2D

## Spawned at the hinges.
@export var spark_prefab: PackedScene
@export var creak_sound: AudioStream
@export var speed: float
@export_range(0, 10) var level: int
@export_range(0, 10, 0.5, "or_greater") var reach: float
@export_file("*.json") var data_path: String
@export_node_path("Node2D") var aim: NodePath
@export_multiline var bio: String
@export_color_no_alpha var tint: Color
@export_enum("Walk", "Run") var gait: String

@export_group("Targets")
@export var guards: Array[Node2D]

static var shared_target: Node

var target: Node2D
var hp: int
var tags: Array[String]
var lookup: Dictionary[String, int]
var wounded: bool

@onready var cam: Camera2D

var health: int:
	set(value):
		health = clampi(value, 0, 100)

var note: PackedScene # set in the Inspector


func _ready() -> void:
	target = get_parent() as Node2D
