## @ace_tags(grid, movement)
## @ace_category("Slide Movement")
@icon("res://eventsheet_addons/behavior.svg")
class_name SlideMove
extends Node

## The node this behavior acts on (its parent). Required host: Node2D.
var host: Node2D = null

func _enter_tree() -> void:
	host = get_parent() as Node2D
	if host == null:
		push_warning("SlideMove behavior requires a Node2D parent.")

## @ace_trigger
## @ace_name("On Slide Started")
signal on_slide_started
## @ace_trigger
## @ace_name("On Slide Stopped")
signal on_slide_stopped
## @ace_trigger
## @ace_name("On Hit Wall")
signal on_hit_wall

# --- Designer knobs (tune the FEEL in the Inspector) ---
## Tile size in pixels - the character snaps to this grid.
@export var grid_size: float = 64.0
## Slide speed in pixels per second.
@export var slide_speed: float = 400.0
## Which physics collision layer counts as a wall (a layer-bit mask).
@export_flags_2d_physics var wall_mask: int = 1
## Let the arrow keys / ui_* actions start a slide automatically.
@export var default_controls: bool = true
## Safety cap: the most tiles a single slide may cross (stops a runaway slide on an open map).
@export_range(1, 512, 1) var max_slide_tiles: int = 64

# --- Internal state ---
var _sliding: bool = false
var _dir: Vector2 = Vector2.ZERO
var _target: Vector2 = Vector2.ZERO
var _dir_name: String = ""

func _ready() -> void:
	if host is Node2D:
		(host as Node2D).global_position = _snap((host as Node2D).global_position)

func _physics_process(delta: float) -> void:
	_move(delta)

## @ace_action
## @ace_name("Slide")
## @ace_category("Slide Movement")
## @ace_description("Starts a slide in a direction (left / right / up / down): the character glides until the tile ahead is a wall, then stops snapped to the grid. Ignored while already sliding; fires On Hit Wall immediately if the very next tile is a wall.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$SlideMove.slide({direction})")
func slide(direction: String) -> void:
	if _sliding:
		return
	var dir: Vector2 = _dir_from(direction)
	if dir == Vector2.ZERO or host == null:
		return
	_dir_name = direction
	var target: Vector2 = _scan_target(dir)
	if target.distance_to(_snap((host as Node2D).global_position)) < grid_size * 0.5:
		on_hit_wall.emit()
		return
	_dir = dir
	_target = target
	_sliding = true
	on_slide_started.emit()

## @ace_action
## @ace_name("Stop Slide")
## @ace_category("Slide Movement")
## @ace_description("Stops a slide immediately and snaps the character to the nearest tile.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$SlideMove.stop_slide()")
func stop_slide() -> void:
	_sliding = false
	if host is Node2D:
		(host as Node2D).global_position = _snap((host as Node2D).global_position)

## @ace_action
## @ace_name("Snap To Grid")
## @ace_category("Slide Movement")
## @ace_description("Snaps the character to the nearest grid intersection right now.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$SlideMove.snap_to_grid()")
func snap_to_grid() -> void:
	if host is Node2D:
		(host as Node2D).global_position = _snap((host as Node2D).global_position)

## @ace_action
## @ace_name("Teleport To Tile")
## @ace_category("Slide Movement")
## @ace_description("Jumps instantly to a tile coordinate (multiplied by the grid size), cancelling any slide.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$SlideMove.teleport_to_tile({tile_x}, {tile_y})")
func teleport_to_tile(tile_x: int, tile_y: int) -> void:
	_sliding = false
	if host is Node2D:
		(host as Node2D).global_position = Vector2(tile_x, tile_y) * grid_size

## @ace_action
## @ace_name("Set Grid Size")
## @ace_category("Slide Movement")
## @ace_description("Changes the tile size in pixels at runtime.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$SlideMove.set_grid_size({pixels})")
func set_grid_size(pixels: float) -> void:
	grid_size = maxf(pixels, 1.0)

## @ace_condition
## @ace_name("Is Sliding")
## @ace_category("Slide Movement")
## @ace_description("Whether the character is mid-slide.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$SlideMove.is_sliding()")
func is_sliding() -> bool:
	return _sliding

## @ace_condition
## @ace_name("Can Slide")
## @ace_category("Slide Movement")
## @ace_description("Whether the tile next to the character in a direction is open (not a wall).")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$SlideMove.can_slide({direction})")
func can_slide(direction: String) -> bool:
	var dir: Vector2 = _dir_from(direction)
	if dir == Vector2.ZERO or host == null:
		return false
	return _scan_target(dir).distance_to(_snap((host as Node2D).global_position)) >= grid_size * 0.5

## @ace_expression
## @ace_name("Slide Direction")
## @ace_category("Slide Movement")
## @ace_description("The direction of the current or last slide ("left" / "right" / "up" / "down").")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$SlideMove.slide_direction()")
func slide_direction() -> String:
	return _dir_name

## @ace_expression
## @ace_name("Tile X")
## @ace_category("Slide Movement")
## @ace_description("The character's current column on the grid.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$SlideMove.tile_x()")
func tile_x() -> int:
	return roundi((host as Node2D).global_position.x / grid_size) if host is Node2D else 0

## @ace_expression
## @ace_name("Tile Y")
## @ace_category("Slide Movement")
## @ace_description("The character's current row on the grid.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$SlideMove.tile_y()")
func tile_y() -> int:
	return roundi((host as Node2D).global_position.y / grid_size) if host is Node2D else 0

func _dir_from(direction: String) -> Vector2:
	# Maps a direction word to a unit step (screen axes: down is +Y).
	match direction:
		"left": return Vector2.LEFT
		"right": return Vector2.RIGHT
		"up": return Vector2.UP
		"down": return Vector2.DOWN
		_: return Vector2.ZERO

func _snap(point: Vector2) -> Vector2:
	# Snaps a world position to the nearest grid intersection.
	return Vector2(roundi(point.x / grid_size), roundi(point.y / grid_size)) * grid_size

func _scan_target(dir: Vector2) -> Vector2:
	# The farthest open tile centre in a direction: steps tile by tile, casting a ray on the wall
	# layer, and stops at the last tile before a wall.
	var body: Node2D = host as Node2D
	if body == null or not is_inside_tree():
		return body.global_position if body != null else Vector2.ZERO
	var space: PhysicsDirectSpaceState2D = get_viewport().get_world_2d().direct_space_state
	var pos: Vector2 = _snap(body.global_position)
	for _i: int in max_slide_tiles:
		var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(pos, pos + dir * grid_size, wall_mask)
		if body is CollisionObject2D:
			query.exclude = [(body as CollisionObject2D).get_rid()]
		if not space.intersect_ray(query).is_empty():
			break
		pos += dir * grid_size
	return pos

func _move(delta: float) -> void:
	# Per physics frame: glide toward the target, or (idle + default controls) read the arrow keys.
	var body: Node2D = host as Node2D
	if body == null:
		return
	if _sliding:
		var step: float = slide_speed * delta
		if body.global_position.distance_to(_target) <= step:
			body.global_position = _target
			_sliding = false
			on_slide_stopped.emit()
			on_hit_wall.emit()
		else:
			body.global_position += _dir * step
		return
	if default_controls:
		if Input.is_action_pressed(&"ui_left"):
			slide("left")
		elif Input.is_action_pressed(&"ui_right"):
			slide("right")
		elif Input.is_action_pressed(&"ui_up"):
			slide("up")
		elif Input.is_action_pressed(&"ui_down"):
			slide("down")

# SlideMove: attach to a Node2D for Tomb-of-the-Mask sliding - a tap sends it gliding across the grid until it hits a wall, then snaps to the tile. Set the grid size and the wall physics layer; arrow keys drive it by default, or call Slide. React with On Hit Wall. This pack is an event sheet - extend it by editing it.
