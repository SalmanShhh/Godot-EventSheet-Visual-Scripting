## @ace_category("Eight Direction")
## @ace_expose_all(node)
## @ace_version(1.0.0)
@icon("res://eventsheet_addons/eight_direction/icon.svg")
class_name EightDirectionMovement
extends Node
## Top-down eight-way movement with nothing to wire: attach under a CharacterBody2D and it reads the built-in ui_left/right/up/down actions every physics frame and moves the host. Arrow keys work the moment you press play; set, nudge, or read the move speed from the sheet.
##
## Changes on its parent: velocity, move_and_slide().

## The node this behavior acts on. Empty: its parent.
@export var acts_on: CharacterBody2D = null

## The node this behavior acts on (Acts on, or else its parent). Required host: CharacterBody2D.
var host: CharacterBody2D = null

func _enter_tree() -> void:
	host = acts_on if acts_on != null else get_parent() as CharacterBody2D
	if host == null:
		push_warning("Eight Direction Movement needs a CharacterBody2D: put it under one, or set Acts on.")

## AI drive: take movement from the AI move inputs instead of the keyboard (the standard seam an AI driver flips on).
@export var ai_controlled: bool = false
## Horizontal input from -1 to 1 when something other than the player drives the host.
var ai_move_x: float = 0.0
## Vertical input from -1 to 1 when something other than the player drives the host.
var ai_move_y: float = 0.0
## Movement speed in pixels per second the host travels at full input.
@export var move_speed: float = 200.0

func _physics_process(_delta: float) -> void:
	if is_instance_valid(host):
		var input_vector: Vector2 = Vector2(ai_move_x, ai_move_y).limit_length(1.0) if ai_controlled else Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		host.velocity = input_vector * move_speed
		host.move_and_slide()

## @ace_action
## @ace_name("Set Move Speed")
## @ace_category("Eight Direction")
## @ace_description("Changes the movement speed.")
## @ace_icon("res://eventsheet_addons/eight_direction/icon.svg")
## @ace_codegen_template("$EightDirectionMovement.set_move_speed({speed})")
func set_move_speed(speed: float) -> void:
	move_speed = speed

# Top-down 8-direction movement: attach under a CharacterBody2D; moves with the ui_* input actions. An AI can steer it through the standard drive seam: flip ai_controlled on and write ai_move_x/ai_move_y.
