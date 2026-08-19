# EventForge module - the behavior SHAPES as free actions (T1 / T3 / T4).
#
# Every reading of a hand-rolled behavior shape has to be authorable in the same words, and every
# template here writes EXACTLY the line the reading recognises - so a row dropped from the picker and
# a line typed into a .gd file are the same bytes and read the same sentence.
#
# These are the SECOND option, not the first: where a shipped behavior pack covers the whole shape
# (Bullet, Move To, Rotate, Wrap, Bound To, Pin, Fade), attaching it is the tidier answer, and the
# pattern chip offers that first. These rows are for the projects that want the one line and nothing
# else - a coin that only spins, a bullet whose whole life is three rows.
# Module contract: see ace_factory.gd - ace_ids/templates are API (compatibility covenant).
@tool
class_name EventForgeBehaviorShapeACEs
extends RefCounted

const F := preload("res://addons/eventforge/registration/ace_factory.gd")

## The picker sections these file under - the behavior each shape belongs to, so a reader who saw the
## row's chip finds the row under the same word.
const CAT_BULLET := "Bullet"
const CAT_MOVE_TO := "Move To"
const CAT_LAYOUT := "Layout Edges"
const CAT_PIN := "Pin"


static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []

	# ── T1: the Bullet shape ──────────────────────────────────────────────────────────────────
	# `velocity` is what all three of these are written against, so they file under the body whose
	# velocity it is - the same scoping the shipped Set Velocity row already has.
	descriptors.append(F.make_descriptor("Core", "SetAngleOfMotion", "Set Angle Of Motion", ACEDescriptor.ACEType.ACTION, "{host.}velocity = Vector2.RIGHT.rotated({angle}) * {speed}", "", [F.make_param("angle", "String", "rotation", "Angle", "Direction to fly along, in radians. `rotation` is the object's own facing.", "expression"), F.make_param("speed", "String", "600.0", "Speed", "How fast to travel along that direction, in pixels per second.", "expression")], CAT_BULLET, "Set angle of motion to {angle}", "CharacterBody2D")
		.described("Sends the object flying along an angle at a speed - the one line a projectile's movement is."))
	descriptors.append(F.make_descriptor("Core", "StepAlongVelocity", "Move", ACEDescriptor.ACEType.ACTION, "{host.}position += {host.}velocity * {delta_t}", "", [F.make_param("delta_t", "String", "delta", "Delta", "Frame time; defaults to `delta`.", "expression")], CAT_BULLET, "Move", "CharacterBody2D")
		.described("Takes this frame's step along the current velocity. The step a projectile makes every tick."))
	descriptors.append(F.make_descriptor("Core", "BounceOffSolid", "Bounce Off Solids", ACEDescriptor.ACEType.ACTION, "{host.}velocity = {host.}velocity.bounce({normal})", "", [F.make_param("normal", "String", "Vector2.UP", "Surface normal", "The direction the surface that was hit is facing.", "expression")], CAT_BULLET, "Bounce off solids", "CharacterBody2D")
		.described("Reflects the current velocity off a surface, so the projectile ricochets instead of stopping."))
	# The acceleration step and the distance a projectile has flown are ALREADY shipped rows - Add To
	# Variable writes `speed += accel * delta` exactly, and the Distance To expression is
	# `position.distance_to(start)`. Adding a second row for either would put two entries with one
	# template in the picker, and the more specific one would quietly claim every line the general one
	# was written for. So the reading recognises those two shapes and the existing rows author them.

	# ── T3: the Move To shape ─────────────────────────────────────────────────────────────────
	# The arrival question is the shipped Is Within Distance row for the same reason.
	descriptors.append(F.make_descriptor("Core", "GlideToward", "Move Toward Position", ACEDescriptor.ACEType.ACTION, "{host.}position = {host.}position.move_toward({destination}, {speed} * {delta_t})", "", [F.make_param("destination", "String", "Vector2.ZERO", "Destination", "The point to glide toward.", "expression"), F.make_param("speed", "String", "200.0", "Speed", "Pixels per second.", "expression"), F.make_param("delta_t", "String", "delta", "Delta", "Frame time; defaults to `delta`.", "expression")], CAT_MOVE_TO, "Move toward {destination} at {speed}", "Node2D")
		.described("Glides this frame's share of the way toward a point, never overshooting it."))

	# ── T4: the one-liners ────────────────────────────────────────────────────────────────────
	descriptors.append(F.make_descriptor("Core", "RotateClockwise", "Rotate Clockwise", ACEDescriptor.ACEType.ACTION, "{host.}rotation_degrees += {degrees_per_second} * {delta_t}", "", [F.make_param("degrees_per_second", "String", "90.0", "Degrees per second", "How far to turn each second (negative turns the other way).", "expression"), F.make_param("delta_t", "String", "delta", "Delta", "Frame time; defaults to `delta`.", "expression")], CAT_LAYOUT, "Rotate clockwise at {degrees_per_second} (degrees per second)", "Node2D")
		.described("Spins the object at a steady rate - a coin, a fan, a saw blade."))
	descriptors.append(F.make_descriptor("Core", "WrapAroundLayoutX", "Wrap Around Layout Horizontally", ACEDescriptor.ACEType.ACTION, "{host.}position.x = wrapf({host.}position.x, {low}, {high})", "", [F.make_param("low", "String", "0.0", "Left edge", "The left edge of the layout, in pixels.", "expression"), F.make_param("high", "String", "1152.0", "Right edge", "The right edge of the layout, in pixels.", "expression")], CAT_LAYOUT, "Wrap around layout horizontally", "Node2D")
		.described("Sends the object off one side of the layout and back in the other - the arcade wrap."))
	descriptors.append(F.make_descriptor("Core", "WrapAroundLayoutY", "Wrap Around Layout Vertically", ACEDescriptor.ACEType.ACTION, "{host.}position.y = wrapf({host.}position.y, {low}, {high})", "", [F.make_param("low", "String", "0.0", "Top edge", "The top edge of the layout, in pixels.", "expression"), F.make_param("high", "String", "648.0", "Bottom edge", "The bottom edge of the layout, in pixels.", "expression")], CAT_LAYOUT, "Wrap around layout vertically", "Node2D")
		.described("Sends the object off the top of the layout and back in at the bottom, or the other way round."))
	descriptors.append(F.make_descriptor("Core", "BoundToLayout", "Bound To Layout", ACEDescriptor.ACEType.ACTION, "{host.}position = {host.}position.clamp({low}, {high})", "", [F.make_param("low", "String", "Vector2.ZERO", "Top left", "The top-left corner the object is kept inside.", "expression"), F.make_param("high", "String", "Vector2(1152, 648)", "Bottom right", "The bottom-right corner the object is kept inside.", "expression")], CAT_LAYOUT, "Bound to layout (inside {low} - {high})", "Node2D")
		.described("Holds the object inside the layout's edges instead of letting it leave - the arcade fence."))
	descriptors.append(F.make_descriptor("Core", "PinToObject", "Pin To", ACEDescriptor.ACEType.ACTION, "{host.}global_position = {anchor}.global_position + {offset}", "", [F.make_param("anchor", "String", "self", "Object", "The object to ride.", "expression"), F.make_param("offset", "String", "Vector2(0, 0)", "Offset", "How far from it to sit, in pixels.", "expression")], CAT_PIN, "Pin to {anchor} (position · offset {offset})", "Node2D")
		.described("Puts the object at another object's place, offset by however far apart you want them."))
	descriptors.append(F.make_descriptor("Core", "PinAngleToObject", "Pin Angle To", ACEDescriptor.ACEType.ACTION, "{host.}rotation = {anchor}.rotation", "", [F.make_param("anchor", "String", "self", "Object", "The object whose angle to copy.", "expression")], CAT_PIN, "Pin to {anchor} (angle)", "Node2D")
		.described("Turns the object to match another object's angle, so the two stay aligned."))

	return descriptors
