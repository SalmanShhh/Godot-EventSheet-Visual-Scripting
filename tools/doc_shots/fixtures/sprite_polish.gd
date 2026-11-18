extends Node2D

@onready var sprite: Sprite2D = $Sprite2D
@onready var tilemap: TileMap = $TileMap
@onready var camera: Camera2D = $Camera2D
var mat: ShaderMaterial
var tween: Tween
var target: Node2D


func _ready() -> void:
	camera.make_current()
	camera.zoom = Vector2(2, 2)
	camera.limit_left = 0
	camera.limit_right = 1920
	camera.position_smoothing_enabled = true


func _process(delta: float) -> void:
	camera.global_position = camera.global_position.lerp(target.global_position, 5 * delta)


func _on_hit() -> void:
	sprite.material.set_shader_parameter("flash", 1.0)
	tween.tween_method(func(v): mat.set_shader_parameter("dissolve", v), 0.0, 1.0, 0.5)


func _on_healed() -> void:
	sprite.material = null


func _on_selected() -> void:
	sprite.material = preload("res://tools/doc_shots/fixtures/outline.tres")


func _on_paint(cell: Vector2i) -> void:
	tilemap.set_cell(0, cell, 1, Vector2i(2, 0))


func _on_erase(cell: Vector2i) -> void:
	tilemap.erase_cell(0, cell)


func tile_under_player() -> void:
	var cell = tilemap.local_to_map(position)
	var data = tilemap.get_cell_tile_data(0, cell)
	if data and data.get_custom_data("solid"):
		stop()


func stop() -> void:
	print("stopped")
