## @ace_category("Checkpoint")
## @ace_expose_all(node)
## @ace_version(1.0.0)
@icon("res://eventsheet_addons/checkpoint/icon.svg")
class_name CheckpointBehavior
extends Node
## Remembers one point to send the host Node2D back to. Set Checkpoint Here marks the spot the host is standing on, Set Checkpoint At marks any point, and Respawn At Checkpoint teleports the host back and fires On Respawned. The starting position is captured on ready, so respawning works before the player ever touches a flag.

## The node this behavior acts on (its parent). Required host: Node2D.
var host: Node2D = null

func _enter_tree() -> void:
	host = get_parent() as Node2D
	if host == null:
		push_warning("CheckpointBehavior behavior requires a Node2D parent.")

## @ace_trigger
## @ace_name("On Respawned")
## @ace_category("Checkpoint")
signal respawned

## Remember where the host starts as its first checkpoint, so Respawn At Checkpoint works before any flag is touched.
@export var capture_on_ready: bool = true
var _checkpoint: Vector2 = Vector2(0.0, 0.0)
var _has_checkpoint: bool = false

func _ready() -> void:
	if capture_on_ready:
		_ensure_checkpoint()

## @ace_action
## @ace_featured
## @ace_name("Set Checkpoint Here")
## @ace_category("Checkpoint")
## @ace_description("Marks the spot the host is standing on right now as its checkpoint.")
## @ace_display_template("Set the checkpoint [b]here[/b]")
## @ace_icon("res://eventsheet_addons/checkpoint/icon.svg")
## @ace_codegen_template("$CheckpointBehavior.set_checkpoint_here()")
func set_checkpoint_here() -> void:
	if host == null:
		return
	_checkpoint = host.global_position
	_has_checkpoint = true

## @ace_action
## @ace_name("Set Checkpoint At")
## @ace_category("Checkpoint")
## @ace_description("Marks any point in the world as the checkpoint, without moving the host.")
## @ace_display_template("Set the checkpoint at [b]{point}[/b]")
## @ace_icon("res://eventsheet_addons/checkpoint/icon.svg")
## @ace_codegen_template("$CheckpointBehavior.set_checkpoint_at({point})")
func set_checkpoint_at(point: Vector2) -> void:
	_checkpoint = point
	_has_checkpoint = true

## @ace_action
## @ace_featured
## @ace_name("Respawn At Checkpoint")
## @ace_category("Checkpoint")
## @ace_description("Teleports the host back to its checkpoint and fires On Respawned. If the host defines a reset() method it is called too - the same duck-typed seam the Object Pool uses when it wakes a pooled node - so velocity, health, and timers clear without this behavior knowing about them.")
## @ace_display_template("[b]Respawn[/b] at the checkpoint")
## @ace_icon("res://eventsheet_addons/checkpoint/icon.svg")
## @ace_codegen_template("$CheckpointBehavior.respawn()")
func respawn() -> void:
	if host == null:
		return
	_ensure_checkpoint()
	host.global_position = _checkpoint
	if host.has_method(&"reset"):
		host.call(&"reset")
	respawned.emit()

## @ace_expression
## @ace_name("Checkpoint Position")
## @ace_category("Checkpoint")
## @ace_description("The point the host respawns at.")
## @ace_icon("res://eventsheet_addons/checkpoint/icon.svg")
## @ace_codegen_template("$CheckpointBehavior.checkpoint_position()")
func checkpoint_position() -> Vector2:
	return _checkpoint

## @ace_hidden
func _ensure_checkpoint() -> void:
	if _has_checkpoint or host == null:
		return
	_checkpoint = host.global_position
	_has_checkpoint = true

# Checkpoint behavior: one remembered point per host. Set Checkpoint Here / At marks it, Respawn At Checkpoint sends the host back and fires On Respawned.
