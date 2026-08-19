## @ace_tags(movement, attachment)
## @ace_category("Pin")
## @ace_version(1.0.0)
@icon("res://eventsheet_addons/pin/icon.svg")
class_name PinBehavior
extends Node
## Sticks a Node2D to another object: every physics frame the host copies that object's position, its angle, or both, kept apart by the offset the pin was made with. Health bars over heads, a hat on a player, a turret on a tank, a shadow under a jumper - one action instead of a line of transform arithmetic.

## The node this behavior acts on (its parent). Required host: Node2D.
var host: Node2D = null

func _enter_tree() -> void:
	host = get_parent() as Node2D
	if host == null:
		push_warning("PinBehavior behavior requires a Node2D parent.")

# --- Designer knobs (tune in the Inspector) ---
## What to copy from the object being ridden: its place, its angle, or both.
@export_enum("position", "angle", "position and angle") var pin_mode: String = "position and angle"
## On: the offset turns with the anchor, so the host orbits it. Off: the offset stays axis-aligned.
@export var rotate_with_anchor: bool = true
## Master on/off - Unpin flips it, Pin To turns it back on.
@export var pin_enabled: bool = true

# --- Internal state ---
# The object being ridden, and how far the host sat from it when the pin was made. The offset
# is stored in the ANCHOR's own frame when rotate_with_anchor is on, which is what lets the
# host swing round with it instead of sliding out of place the moment the anchor turns.
var anchor: Node2D = null
var pin_offset: Vector2 = Vector2.ZERO
var pin_angle_offset: float = 0.0

func _physics_process(delta: float) -> void:
	if not pin_enabled or host == null or not is_instance_valid(anchor):
		return
	if pin_mode != "angle":
		# The offset rides the anchor's own frame when asked to, so a turning anchor carries the
		# host round it; otherwise it stays the plain world-space gap the pin was made with.
		var offset: Vector2 = pin_offset.rotated(anchor.global_rotation) if rotate_with_anchor else pin_offset
		host.global_position = anchor.global_position + offset
	if pin_mode != "position":
		host.global_rotation = anchor.global_rotation + pin_angle_offset

## @ace_action
## @ace_featured
## @ace_name("Pin To")
## @ace_category("Pin")
## @ace_description("Sticks the host to an object, remembering how far apart the two are right now. From this frame on the host rides it.")
## @ace_display_template("Pin to [b]{target}[/b]")
## @ace_icon("res://eventsheet_addons/pin/icon.svg")
## @ace_codegen_template("$PinBehavior.pin_to({target})")
func pin_to(target: Node2D) -> void:
	anchor = target
	pin_enabled = is_instance_valid(target)
	if not pin_enabled or host == null:
		return
	var gap: Vector2 = host.global_position - target.global_position
	pin_offset = gap.rotated(-target.global_rotation) if rotate_with_anchor else gap
	pin_angle_offset = host.global_rotation - target.global_rotation

## @ace_action
## @ace_name("Pin To At Offset")
## @ace_category("Pin")
## @ace_description("Sticks the host to an object at a chosen distance from it, in pixels, instead of wherever it happens to be standing.")
## @ace_icon("res://eventsheet_addons/pin/icon.svg")
## @ace_codegen_template("$PinBehavior.pin_to_at({target}, {offset_x}, {offset_y})")
func pin_to_at(target: Node2D, offset_x: float, offset_y: float) -> void:
	anchor = target
	pin_enabled = is_instance_valid(target)
	pin_offset = Vector2(offset_x, offset_y)
	pin_angle_offset = 0.0

## @ace_action
## @ace_name("Set Pin Offset")
## @ace_category("Pin")
## @ace_description("Moves the host to a new distance from the object it is riding, in pixels.")
## @ace_icon("res://eventsheet_addons/pin/icon.svg")
## @ace_codegen_template("$PinBehavior.set_pin_offset({offset_x}, {offset_y})")
func set_pin_offset(offset_x: float, offset_y: float) -> void:
	pin_offset = Vector2(offset_x, offset_y)

## @ace_action
## @ace_featured
## @ace_name("Unpin")
## @ace_category("Pin")
## @ace_description("Lets go. The host stays exactly where it was and moves on its own again.")
## @ace_display_template("Unpin")
## @ace_icon("res://eventsheet_addons/pin/icon.svg")
## @ace_codegen_template("$PinBehavior.unpin()")
func unpin() -> void:
	anchor = null
	pin_enabled = false

## @ace_condition
## @ace_name("Is Pinned")
## @ace_description("True while the host is riding another object.")
## @ace_icon("res://eventsheet_addons/pin/icon.svg")
## @ace_codegen_template("$PinBehavior.is_pinned()")
func is_pinned() -> bool:
	return pin_enabled and is_instance_valid(anchor)

## @ace_expression
## @ace_name("PinOffsetX")
## @ace_description("How far the host sits from its anchor along X, in pixels.")
## @ace_icon("res://eventsheet_addons/pin/icon.svg")
## @ace_codegen_template("$PinBehavior.pin_offset_x()")
func pin_offset_x() -> float:
	return pin_offset.x

## @ace_expression
## @ace_name("PinOffsetY")
## @ace_description("How far the host sits from its anchor along Y, in pixels.")
## @ace_icon("res://eventsheet_addons/pin/icon.svg")
## @ace_codegen_template("$PinBehavior.pin_offset_y()")
func pin_offset_y() -> float:
	return pin_offset.y

## @ace_action
## @ace_name("Set Pin Mode")
## @ace_description("Chooses what the host copies from its anchor.")
## @ace_param_options(mode position=Follow its place only, angle=Follow its angle only, position and angle=Follow both)
## @ace_icon("res://eventsheet_addons/pin/icon.svg")
## @ace_codegen_template("$PinBehavior.set_pin_mode({mode})")
func set_pin_mode(mode: String) -> void:
	if mode in ["position", "angle", "position and angle"]:
		pin_mode = mode

# Pin behavior (event-sheet parity): the host rides another object. Pin To starts it and remembers how far apart the two were; Pin Mode chooses position, angle, or both; Unpin lets go. Rotate With Anchor turns the offset with the anchor, so a pinned hat swings round the head instead of hovering beside it. This pack is an event sheet - extend it by editing it.
