## @ace_tags(movement, screen)
## @ace_category("Wrap")
@icon("res://eventsheet_addons/behavior.svg")
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
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$WrapBehavior.set_wrap_enabled({enabled})")
func set_wrap_enabled(enabled: bool) -> void:
	wrap_enabled = enabled

## @ace_action
## @ace_name("Set Custom Wrap Bounds")
## @ace_category("Wrap")
## @ace_description("Sets the custom rectangle (world-space pixels) and switches wrapping to it - your arena's edges.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$WrapBehavior.set_custom_wrap_bounds({x}, {y}, {width}, {height})")
func set_custom_wrap_bounds(x: float, y: float, width: float, height: float) -> void:
	custom_bounds = Rect2(x, y, width, height)
	wrap_space = "custom"

## @ace_action
## @ace_name("Set Wrap Axes")
## @ace_category("Wrap")
## @ace_description("Chooses which axes wrap (horizontal: left/right edges, vertical: top/bottom).")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$WrapBehavior.set_wrap_axes({horizontal}, {vertical})")
func set_wrap_axes(horizontal: bool, vertical: bool) -> void:
	wrap_horizontal = horizontal
	wrap_vertical = vertical

## @ace_action
## @ace_name("Set Wrap Extents")
## @ace_category("Wrap")
## @ace_description("Sets the host's half-size (half the sprite's width and height) used by the fully-outside test.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$WrapBehavior.set_wrap_extents({new_half_width}, {new_half_height})")
func set_wrap_extents(new_half_width: float, new_half_height: float) -> void:
	half_width = new_half_width
	half_height = new_half_height

func set_wrap_space(space: String) -> void:
	if space in ["screen", "custom"]:
		wrap_space = space

# Wrap behavior (event-sheet parity): once the host is FULLY outside an edge of the SCREEN (the camera's view) or a CUSTOM rectangle, it teleports to the opposite edge - Asteroids in one attach. Per-axis toggles; On Wrapped tells you which side it left. This pack is an event sheet - extend it by editing it.
