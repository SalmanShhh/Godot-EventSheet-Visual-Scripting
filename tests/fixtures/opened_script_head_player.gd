## A hand-written game script - not a behavior pack - whose HEAD is the subject: a class_name, a
## scene, signals, grouped @export knobs, typed collections, a constant and two preloaded scenes.
class_name PlayerAvatar
extends CharacterBody2D

signal died

signal picked_up_coin

signal hit(body: Node2D)

const PAD_SCENE := preload("res://tests/fixtures/opened_script_head_pad.tscn")
const MAX_SPEED := 300.0

## How fast the avatar walks, in pixels per second.
@export_group("Movement")
@export var move_speed: float = 180.0
@export var jump_height: float = 64.0

var bullet_scene: PackedScene = preload("res://tests/fixtures/head_bullet.tscn")
var names: Array[String] = []
var scores: Array[int] = []
var inventory: Dictionary = {}
var _cooldown: float = 0.0


func _physics_process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
