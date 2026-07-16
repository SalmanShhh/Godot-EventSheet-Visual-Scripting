## @ace_tags(movement, screen)
## @ace_category("Wrap")
@icon("res://eventsheet_addons/wrap/icon.svg")
class_name WrapBehavior
extends Node

## The node this behavior acts on (its parent). Required host: Node2D.
var host: Node2D = null

func _enter_tree() -> void:
	host = get_parent() as Node2D
	if host == null:
		push_warning("WrapBehavior behavior requires a Node2D parent.")

## @ace_trigger
## @ace_name("On Wrapped")
signal wrapped(side: String)

# --- Designer knobs (tune in the Inspector) ---
## What to wrap around: the camera's on-screen view, or the custom bounds rectangle.
@export_enum("screen", "custom") var wrap_space: String = "screen"
## The custom constraint's SHAPE: a rectangle (wrap across opposite edges) or a circle
## (wrap to the antipode - leave one side of the arena, glide in from the other).
@export_enum("rect", "circle") var wrap_shape: String = "rect"
## Circle constraint: the center of the circular arena (world space).
@export var wrap_circle_center: Vector2 = Vector2(576.0, 324.0)
## Circle constraint: the arena radius in pixels.
@export var wrap_circle_radius: float = 300.0
## Wrap across the left/right edges.
@export var wrap_horizontal: bool = true
## Wrap across the top/bottom edges.
@export var wrap_vertical: bool = true
## Half the host's width in pixels - it must be FULLY off screen before wrapping.
@export var half_width: float = 16.0
## Half the host's height in pixels - it must be FULLY off screen before wrapping.
@export var half_height: float = 16.0
## Master on/off - Set Wrap Enabled flips it at runtime.
@export var wrap_enabled: bool = true

# --- Internal state ---
# The custom rectangle (world space) used when wrap_space is "custom" - Rect2 cannot
# emit from the variables dict, so it lives here; Set Custom Wrap Bounds writes it.
var custom_bounds: Rect2 = Rect2(0.0, 0.0, 1152.0, 648.0)
## The world-space rectangle being wrapped around: the camera's visible rect (the canvas
## transform inverted maps screen space to world space) or the custom rectangle.
## @ace_hidden
func _wrap_rect() -> Rect2:
	if wrap_space == "custom":
		return custom_bounds
	var viewport: Viewport = host.get_viewport() if host != null else null
	if viewport == null:
		return custom_bounds
	return viewport.get_canvas_transform().affine_inverse() * viewport.get_visible_rect()

func _physics_process(delta: float) -> void:
	if not wrap_enabled or host == null:
		return
	# The circular constraint: once fully outside the circle, re-enter at the ANTIPODE
	# (still fully outside, so momentum glides the host in instead of popping it).
	if wrap_shape == "circle" and wrap_space == "custom":
		var offset: Vector2 = host.global_position - wrap_circle_center
		var pad: float = maxf(half_width, half_height)
		if offset.length() - pad > wrap_circle_radius:
			var direction: Vector2 = offset.normalized()
			host.global_position = wrap_circle_center - direction * (wrap_circle_radius + pad)
			wrapped.emit(_direction_side(direction))
		return
	var rect: Rect2 = _wrap_rect()
	var pos: Vector2 = host.global_position
	# Fully-outside test per side; re-enter at the opposite edge, still fully outside,
	# so a fast mover glides on instead of popping mid-screen.
	if wrap_horizontal:
		if pos.x - half_width > rect.end.x:
			pos.x = rect.position.x - half_width
			host.global_position = pos
			wrapped.emit("right")
		elif pos.x + half_width < rect.position.x:
			pos.x = rect.end.x + half_width
			host.global_position = pos
			wrapped.emit("left")
	if wrap_vertical:
		if pos.y - half_height > rect.end.y:
			pos.y = rect.position.y - half_height
			host.global_position = pos
			wrapped.emit("bottom")
		elif pos.y + half_height < rect.position.y:
			pos.y = rect.end.y + half_height
			host.global_position = pos
			wrapped.emit("top")

## @ace_action
## @ace_name("Set Wrap Enabled")
## @ace_category("Wrap")
## @ace_description("Turns wrapping on or off at runtime.")
## @ace_icon("res://eventsheet_addons/wrap/icon.svg")
## @ace_codegen_template("$WrapBehavior.set_wrap_enabled({enabled})")
func set_wrap_enabled(enabled: bool) -> void:
	wrap_enabled = enabled

## @ace_action
## @ace_name("Set Custom Wrap Bounds")
## @ace_category("Wrap")
## @ace_description("Sets the custom rectangle (world-space pixels) and switches wrapping to it - your arena's edges.")
## @ace_icon("res://eventsheet_addons/wrap/icon.svg")
## @ace_codegen_template("$WrapBehavior.set_custom_wrap_bounds({x}, {y}, {width}, {height})")
func set_custom_wrap_bounds(x: float, y: float, width: float, height: float) -> void:
	custom_bounds = Rect2(x, y, width, height)
	wrap_shape = "rect"
	wrap_space = "custom"

## @ace_action
## @ace_name("Set Wrap Axes")
## @ace_category("Wrap")
## @ace_description("Chooses which axes wrap (horizontal: left/right edges, vertical: top/bottom).")
## @ace_icon("res://eventsheet_addons/wrap/icon.svg")
## @ace_codegen_template("$WrapBehavior.set_wrap_axes({horizontal}, {vertical})")
func set_wrap_axes(horizontal: bool, vertical: bool) -> void:
	wrap_horizontal = horizontal
	wrap_vertical = vertical

## @ace_action
## @ace_name("Set Wrap Extents")
## @ace_category("Wrap")
## @ace_description("Sets the host's half-size (half the sprite's width and height) used by the fully-outside test.")
## @ace_icon("res://eventsheet_addons/wrap/icon.svg")
## @ace_codegen_template("$WrapBehavior.set_wrap_extents({new_half_width}, {new_half_height})")
func set_wrap_extents(new_half_width: float, new_half_height: float) -> void:
	half_width = new_half_width
	half_height = new_half_height

## @ace_action
## @ace_name("Set Wrap Space")
## @ace_description("Switches what the host wraps around: the on-screen camera view, or the custom rectangle.")
## @ace_param_options(space screen, custom)
## @ace_icon("res://eventsheet_addons/wrap/icon.svg")
## @ace_codegen_template("$WrapBehavior.set_wrap_space({space})")
func set_wrap_space(space: String) -> void:
	if space in ["screen", "custom"]:
		wrap_space = space

## @ace_action
## @ace_name("Set Circle Wrap Bounds")
## @ace_description("Sets a CIRCULAR wrap constraint (world-space center + radius) and switches to it: fully outside the circle teleports to the antipode - a round arena in one action.")
## @ace_icon("res://eventsheet_addons/wrap/icon.svg")
## @ace_codegen_template("$WrapBehavior.set_circle_wrap_bounds({center_x}, {center_y}, {radius})")
func set_circle_wrap_bounds(center_x: float, center_y: float, radius: float) -> void:
	wrap_circle_center = Vector2(center_x, center_y)
	wrap_circle_radius = maxf(radius, 1.0)
	wrap_shape = "circle"
	wrap_space = "custom"

## @ace_hidden
func _direction_side(direction: Vector2) -> String:
	if absf(direction.x) >= absf(direction.y):
		return "right" if direction.x >= 0.0 else "left"
	return "bottom" if direction.y >= 0.0 else "top"

# Wrap behavior (event-sheet parity): once the host is FULLY outside an edge of the SCREEN (the camera's view) or a CUSTOM rectangle, it teleports to the opposite edge - Asteroids in one attach. Per-axis toggles; On Wrapped tells you which side it left. This pack is an event sheet - extend it by editing it.
