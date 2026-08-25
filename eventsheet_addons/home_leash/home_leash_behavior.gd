## @ace_category("Home & Leash")
## @ace_expose_all(node)
## @ace_version(1.0.0)
@icon("res://eventsheet_addons/home_leash/icon.svg")
class_name HomeLeashBehavior
extends Node
## Keeps the host Node2D on a leash around a home point. Set Home Here plants the post, Is Beyond Home branches when the host has wandered too far (straight line, one axis, grid steps, or king moves), and Return Home walks it back and fires On Arrived Home. The guard, the shopkeeper, and the patrolling enemy that gives up the chase.

## The node this behavior acts on (its parent). Required host: Node2D.
var host: Node2D = null

func _enter_tree() -> void:
	host = get_parent() as Node2D
	if host == null:
		push_warning("HomeLeashBehavior behavior requires a Node2D parent.")

## @ace_trigger
## @ace_name("On Arrived Home")
## @ace_category("Home & Leash")
signal arrived_home

## Plant home where the host starts, so the leash works before you set one by hand.
@export var capture_on_ready: bool = true
var _home: Vector2 = Vector2(0.0, 0.0)
var _has_home: bool = false
var _returning: bool = false

func _ready() -> void:
	if capture_on_ready:
		_ensure_home()

## @ace_action
## @ace_name("Set Home Here")
## @ace_category("Home & Leash")
## @ace_description("Plants home on the spot the host is standing on right now.")
## @ace_display_template("Set home [b]here[/b]")
## @ace_icon("res://eventsheet_addons/home_leash/icon.svg")
## @ace_codegen_template("$HomeLeashBehavior.set_home_here()")
func set_home_here() -> void:
	if host == null:
		return
	_home = host.global_position
	_has_home = true

## @ace_action
## @ace_name("Set Home At")
## @ace_category("Home & Leash")
## @ace_description("Plants home on any point in the world, without moving the host.")
## @ace_display_template("Set home at [b]{point}[/b]")
## @ace_icon("res://eventsheet_addons/home_leash/icon.svg")
## @ace_codegen_template("$HomeLeashBehavior.set_home_at({point})")
func set_home_at(point: Vector2) -> void:
	_home = point
	_has_home = true

## @ace_expression
## @ace_name("Distance From Home")
## @ace_category("Home & Leash")
## @ace_description("How far the host is from its home point, measured the way you pick: straight line, one axis only, grid steps (across plus down), or king moves (the larger of the two).")
## @ace_param_options(metric 0=Straight line, 1=Horizontal only, 2=Vertical only, 3=Grid steps, 4=King moves)
## @ace_icon("res://eventsheet_addons/home_leash/icon.svg")
## @ace_codegen_template("$HomeLeashBehavior.distance_from_home({metric})")
func distance_from_home(metric: int) -> float:
	if host == null:
		return 0.0
	_ensure_home()
	var offset: Vector2 = host.global_position - _home
	match metric:
		1:
			return absf(offset.x)
		2:
			return absf(offset.y)
		3:
			return absf(offset.x) + absf(offset.y)
		4:
			return maxf(absf(offset.x), absf(offset.y))
	return offset.length()

## @ace_condition
## @ace_featured
## @ace_name("Is Beyond Home")
## @ace_category("Home & Leash")
## @ace_description("True while the host has wandered further than this from home, in the distance metric you pick.")
## @ace_param_options(metric 0=Straight line, 1=Horizontal only, 2=Vertical only, 3=Grid steps, 4=King moves)
## @ace_icon("res://eventsheet_addons/home_leash/icon.svg")
## @ace_codegen_template("$HomeLeashBehavior.is_beyond_home({distance}, {metric})")
func is_beyond_home(distance: float, metric: int) -> bool:
	return distance_from_home(metric) > distance

## @ace_action
## @ace_featured
## @ace_name("Return Home")
## @ace_category("Home & Leash")
## @ace_description("Walks the host one step back toward home - run it under a per-frame trigger and pass that trigger's delta. Fires On Arrived Home once, on the step that lands (within a pixel of home), not on every frame the host sits there.")
## @ace_display_template("Walk home at [b]{speed}[/b]")
## @ace_icon("res://eventsheet_addons/home_leash/icon.svg")
## @ace_codegen_template("$HomeLeashBehavior.return_home({speed}, {delta})")
func return_home(speed: float, delta: float) -> void:
	if host == null:
		return
	_ensure_home()
	host.global_position = host.global_position.move_toward(_home, maxf(speed, 0.0) * delta)
	if host.global_position.distance_to(_home) < 1.0:
		# Edge-triggered: only the step that ARRIVES emits, so a host parked at home does not
		# re-fire the trigger every frame.
		if _returning:
			_returning = false
			arrived_home.emit()
		return
	_returning = true

## @ace_hidden
func _ensure_home() -> void:
	if _has_home or host == null:
		return
	_home = host.global_position
	_has_home = true

# Home & Leash behavior: one home point per host. Is Beyond Home branches on the leash length in five distance metrics; Return Home walks the host back one step per call and fires On Arrived Home.
