## @ace_tags(movement, screen)
## @ace_category("Bound To")
@icon("res://eventsheet_addons/behavior.svg")
class_name BoundToBehavior
extends Node

## The node this behavior acts on (its parent). Required host: Node2D.
var host: Node2D = null

func _enter_tree() -> void:
	host = get_parent() as Node2D
	if host == null:
		push_warning("BoundToBehavior behavior requires a Node2D parent.")

## @ace_trigger
## @ace_name("On Hit Bound")
signal bound_hit(side: String)

# --- Designer knobs (tune in the Inspector) ---
## What to stay inside: the camera's on-screen view, or the custom bounds rectangle.
@export_enum("screen", "custom") var bound_space: String = "screen"
## On: the host's EDGES stay inside (origin + half-size). Off: only the origin is bound.
@export var bound_by_edge: bool = true
## Half the host's width in pixels (edge binding uses it; match your sprite).
@export var half_width: float = 16.0
## Half the host's height in pixels (edge binding uses it; match your sprite).
@export var half_height: float = 16.0
## Master on/off - Set Bound Enabled flips it at runtime.
@export var bound_enabled: bool = true

# --- Internal state ---
# The custom rectangle (world space) used when bound_space is "custom" - Rect2 cannot
# emit from the variables dict, so it lives here; Set Custom Bounds writes it.
var custom_bounds: Rect2 = Rect2(0.0, 0.0, 1152.0, 648.0)
var _pressed_sides: Dictionary = {}
## The world-space rectangle being bound to: the camera's visible rect (the canvas
## transform inverted maps screen space to world space) or the custom rectangle.
## @ace_hidden
func _bound_rect() -> Rect2:
	if bound_space == "custom":
		return custom_bounds
	var viewport: Viewport = host.get_viewport() if host != null else null
	if viewport == null:
		return custom_bounds
	return viewport.get_canvas_transform().affine_inverse() * viewport.get_visible_rect()

func _physics_process(delta: float) -> void:
	if not bound_enabled or host == null:
		return
	var rect: Rect2 = _bound_rect()
	var extent: Vector2 = Vector2(half_width, half_height) if bound_by_edge else Vector2.ZERO
	var low: Vector2 = rect.position + extent
	var high: Vector2 = rect.end - extent
	# A rect smaller than the host still clamps sanely (low may exceed high - order them).
	var pos: Vector2 = host.global_position
	var clamped: Vector2 = Vector2(clampf(pos.x, minf(low.x, high.x), maxf(low.x, high.x)), clampf(pos.y, minf(low.y, high.y), maxf(low.y, high.y)))
	# Edge-triggered per side: On Hit Bound fires once per press, re-arming on release.
	var now_pressed: Dictionary = {}
	if clamped.x > pos.x:
		now_pressed["left"] = true
	elif clamped.x < pos.x:
		now_pressed["right"] = true
	if clamped.y > pos.y:
		now_pressed["top"] = true
	elif clamped.y < pos.y:
		now_pressed["bottom"] = true
	for side in now_pressed:
		if not _pressed_sides.has(side):
			bound_hit.emit(str(side))
	_pressed_sides = now_pressed
	if clamped != pos:
		host.global_position = clamped

## @ace_action
## @ace_name("Set Bound Enabled")
## @ace_category("Bound To")
## @ace_description("Turns the binding on or off at runtime (off = the host moves freely).")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$BoundToBehavior.set_bound_enabled({enabled})")
func set_bound_enabled(enabled: bool) -> void:
	bound_enabled = enabled
	if not enabled:
		_pressed_sides = {}

## @ace_action
## @ace_name("Set Custom Bounds")
## @ace_category("Bound To")
## @ace_description("Sets the custom rectangle (world-space pixels) and switches the binding to it - your level's playable area.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$BoundToBehavior.set_custom_bounds({x}, {y}, {width}, {height})")
func set_custom_bounds(x: float, y: float, width: float, height: float) -> void:
	custom_bounds = Rect2(x, y, width, height)
	bound_space = "custom"

## @ace_action
## @ace_name("Set Bound Extents")
## @ace_category("Bound To")
## @ace_description("Sets the host's half-size used by edge binding (half the sprite's width and height).")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$BoundToBehavior.set_bound_extents({new_half_width}, {new_half_height})")
func set_bound_extents(new_half_width: float, new_half_height: float) -> void:
	half_width = new_half_width
	half_height = new_half_height

## @ace_condition
## @ace_name("Is At Bound")
## @ace_description("True while the host is pressed against a bound. side: left / right / top / bottom / any.")
## @ace_param_options(side left, right, top, bottom, any)
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$BoundToBehavior.is_at_bound({side})")
func is_at_bound(side: String = "any") -> bool:
	if side == "any":
		return not _pressed_sides.is_empty()
	return _pressed_sides.has(side)

## @ace_action
## @ace_name("Set Bound Space")
## @ace_description("Switches what the host is kept inside: the on-screen camera view, or the custom rectangle.")
## @ace_param_options(space screen, custom)
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$BoundToBehavior.set_bound_space({space})")
func set_bound_space(space: String) -> void:
	if space in ["screen", "custom"]:
		bound_space = space

# Bound To behavior (event-sheet parity): keeps the host inside the SCREEN (the camera's view) or a CUSTOM rectangle, clamped every physics frame. Bound by edge (origin + half-size stays inside) or by origin alone. On Hit Bound fires once per press against each side. This pack is an event sheet - extend it by editing it.
