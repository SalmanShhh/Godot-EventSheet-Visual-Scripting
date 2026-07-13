## @ace_category("Tile Movement")
## @ace_expose_all(node)
@icon("res://eventsheet_addons/behavior.svg")
class_name TileMovementBehavior
extends Node

## The node this behavior acts on (its parent). Required host: Node2D.
var host: Node2D = null

func _enter_tree() -> void:
	host = get_parent() as Node2D
	if host == null:
		push_warning("TileMovementBehavior behavior requires a Node2D parent.")

## @ace_trigger
## @ace_name("On Step Finished")
signal step_finished

## AI drive: read ai_move_x/ai_move_y instead of the arrow keys (a sheet or AI driver flips this on to steer).
@export var ai_controlled: bool = false
var ai_move_x: float = 0.0
var ai_move_y: float = 0.0
## When on, the arrow keys step the host one tile at a time.
@export var default_controls: bool = true
var from_x: float = 0.0
var from_y: float = 0.0
## Seconds to slide across one tile.
@export var move_time: float = 0.15
var moving: bool = false
var pending_x: float = 0.0
var pending_y: float = 0.0
var progress: float = 0.0
## Pixel size of one grid tile - each step moves the host this many pixels.
@export var tile_size: float = 64.0
var to_x: float = 0.0
var to_y: float = 0.0

## @ace_hidden
func to_grid(pixel: Vector2) -> Vector2i:
	return Vector2i(roundi(pixel.x / tile_size), roundi(pixel.y / tile_size))

func _process(delta: float) -> void:
	if host == null:
		return
	if moving:
		progress += delta / move_time
		if progress >= 1.0:
			host.position = Vector2(to_x, to_y)
			moving = false
			step_finished.emit()
		else:
			host.position = Vector2(from_x, from_y).lerp(Vector2(to_x, to_y), progress)
		return
	var step := Vector2(pending_x, pending_y)
	pending_x = 0.0
	pending_y = 0.0
	# The AI seam: a driver holds ai_move_x/ai_move_y like held keys - consumed one grid
	# step per completed step; off (the default) the keyboard read below is untouched.
	if step == Vector2.ZERO and ai_controlled:
		step = Vector2(ai_move_x, ai_move_y)
	if step == Vector2.ZERO and default_controls and not ai_controlled:
		step = Vector2(Input.get_axis(&"ui_left", &"ui_right"), Input.get_axis(&"ui_up", &"ui_down"))
	if step.x != 0.0:
		step.y = 0.0
	if step != Vector2.ZERO:
		from_x = host.position.x
		from_y = host.position.y
		to_x = from_x + signf(step.x) * tile_size
		to_y = from_y + signf(step.y) * tile_size
		progress = 0.0
		moving = true

## @ace_action
## @ace_name("Simulate Step")
## @ace_category("Tile Movement")
## @ace_description("Steps one tile in a direction: left, right, up or down (simulate control).")
## @ace_param_options(direction left, right, up, down)
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$TileMovementBehavior.simulate_step({direction})")
func simulate_step(direction: String) -> void:
	if direction == "left":
		pending_x = -1.0
	elif direction == "right":
		pending_x = 1.0
	elif direction == "up":
		pending_y = -1.0
	elif direction == "down":
		pending_y = 1.0

## @ace_action
## @ace_name("Teleport To Tile")
## @ace_category("Tile Movement")
## @ace_description("Snaps to a tile coordinate instantly.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$TileMovementBehavior.teleport_to_tile({tile_x}, {tile_y})")
func teleport_to_tile(tile_x: float, tile_y: float) -> void:
	if host != null:
		host.position = Vector2(tile_x, tile_y) * tile_size
	moving = false

## @ace_hidden
func from_grid(tile: Vector2i) -> Vector2:
	return Vector2(tile) * tile_size

# Tile Movement behavior (event-sheet parity): grid-locked stepping (arrow keys or Simulate Step); grid-space helpers convert between tiles and pixels. Fires On Step Finished per tile.
