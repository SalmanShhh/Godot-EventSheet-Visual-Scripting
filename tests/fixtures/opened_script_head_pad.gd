## A hand-written script with NO class_name - the common shape of a beginner's scene script, named
## on the Include bar after the ROOT NODE of the scene it is attached to.
extends Node2D

signal pad_touched

## Seconds between two launches.
@export var launch_interval: float = 1.5

var _elapsed: float = 0.0
var waiting: Array[String] = []


func _process(delta: float) -> void:
	_elapsed += delta
