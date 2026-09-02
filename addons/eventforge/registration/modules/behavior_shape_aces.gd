# EventForge module - the behavior SHAPES as free actions.
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

	# ── the Bullet shape ──────────────────────────────────────────────────────────────────────
	# `velocity` is what all three of these are written against, so they file under the body whose
	# velocity it is - the same scoping the shipped Set Velocity row already has.
	descriptors.append(F.act("SetAngleOfMotion", "Set Angle Of Motion", "{host.}velocity = Vector2.RIGHT.rotated({angle}) * {speed}", CAT_BULLET, "Set angle of motion to {angle}", "Sends the object flying along an angle at a speed - the one line a projectile's movement is.", "CharacterBody2D").param("angle", "rotation", "Angle", "Direction to fly along, in radians. `rotation` is the object's own facing.", "expression").param("speed", "600.0", "Speed", "How fast to travel along that direction, in pixels per second.", "expression"))
	descriptors.append(F.act("StepAlongVelocity", "Move", "{host.}position += {host.}velocity * {delta_t}", CAT_BULLET, "Move", "Takes this frame's step along the current velocity. The step a projectile makes every tick.", "CharacterBody2D").param("delta_t", "delta", "Delta", "Frame time; defaults to `delta`.", "expression"))
	descriptors.append(F.act("BounceOffSolid", "Bounce Off Solids", "{host.}velocity = {host.}velocity.bounce({normal})", CAT_BULLET, "Bounce off solids", "Reflects the current velocity off a surface, so the projectile ricochets instead of stopping.", "CharacterBody2D").param("normal", "Vector2.UP", "Surface normal", "The direction the surface that was hit is facing.", "expression"))
	# The acceleration step and the distance a projectile has flown are ALREADY shipped rows - Add To
	# Variable writes `speed += accel * delta` exactly, and the Distance To expression is
	# `position.distance_to(start)`. Adding a second row for either would put two entries with one
	# template in the picker, and the more specific one would quietly claim every line the general one
	# was written for. So the reading recognises those two shapes and the existing rows author them.

	# ── the Move To shape ─────────────────────────────────────────────────────────────────────
	# The arrival question is the shipped Is Within Distance row for the same reason.
	descriptors.append(F.act("GlideToward", "Move Toward Position", "{host.}position = {host.}position.move_toward({destination}, {speed} * {delta_t})", CAT_MOVE_TO, "Move toward {destination} at {speed}", "Glides this frame's share of the way toward a point, never overshooting it.", "Node2D").param("destination", "Vector2.ZERO", "Destination", "The point to glide toward.", "expression").param("speed", "200.0", "Speed", "Pixels per second.", "expression").param("delta_t", "delta", "Delta", "Frame time; defaults to `delta`.", "expression"))

	# ── the one-liners ────────────────────────────────────────────────────────────────────────
	descriptors.append(F.act("RotateClockwise", "Rotate Clockwise", "{host.}rotation_degrees += {degrees_per_second} * {delta_t}", CAT_LAYOUT, "Rotate clockwise at {degrees_per_second} (degrees per second)", "Spins the object at a steady rate - a coin, a fan, a saw blade.", "Node2D").param("degrees_per_second", "90.0", "Degrees per second", "How far to turn each second (negative turns the other way).", "expression").param("delta_t", "delta", "Delta", "Frame time; defaults to `delta`.", "expression"))
	descriptors.append(F.act("WrapAroundLayoutX", "Wrap Around Layout Horizontally", "{host.}position.x = wrapf({host.}position.x, {low}, {high})", CAT_LAYOUT, "Wrap around layout horizontally", "Sends the object off one side of the layout and back in the other - the arcade wrap.", "Node2D").param("low", "0.0", "Left edge", "The left edge of the layout, in pixels.", "expression").param("high", "1152.0", "Right edge", "The right edge of the layout, in pixels.", "expression"))
	descriptors.append(F.act("WrapAroundLayoutY", "Wrap Around Layout Vertically", "{host.}position.y = wrapf({host.}position.y, {low}, {high})", CAT_LAYOUT, "Wrap around layout vertically", "Sends the object off the top of the layout and back in at the bottom, or the other way round.", "Node2D").param("low", "0.0", "Top edge", "The top edge of the layout, in pixels.", "expression").param("high", "648.0", "Bottom edge", "The bottom edge of the layout, in pixels.", "expression"))
	descriptors.append(F.act("BoundToLayout", "Bound To Layout", "{host.}position = {host.}position.clamp({low}, {high})", CAT_LAYOUT, "Bound to layout (inside {low} - {high})", "Holds the object inside the layout's edges instead of letting it leave - the arcade fence.", "Node2D").param("low", "Vector2.ZERO", "Top left", "The top-left corner the object is kept inside.", "expression").param("high", "Vector2(1152, 648)", "Bottom right", "The bottom-right corner the object is kept inside.", "expression"))
	descriptors.append(F.act("PinToObject", "Pin To", "{host.}global_position = {anchor}.global_position + {offset}", CAT_PIN, "Pin to {anchor} (position · offset {offset})", "Puts the object at another object's place, offset by however far apart you want them.\n\nPin or child? A pin follows at runtime and can let go; a child is structure and is destroyed with its parent. Reach for Add Child when the two are one thing that lives and dies together, and for a pin when one thing rides another for a while.", "Node2D").param("anchor", "self", "Object", "The object to ride.", "expression").param("offset", "Vector2(0, 0)", "Offset", "How far from it to sit, in pixels.", "expression"))
	descriptors.append(F.act("PinAngleToObject", "Pin Angle To", "{host.}rotation = {anchor}.rotation", CAT_PIN, "Pin to {anchor} (angle)", "Turns the object to match another object's angle, so the two stay aligned.", "Node2D").param("anchor", "self", "Object", "The object whose angle to copy.", "expression"))

	# ── the two DISTANCE pin modes, one line each ─────────────────────────────────────────────
	# The Pin behavior pack owns the whole family - a mode dropdown, a remembered offset, an Unpin
	# and an Is Pinned - and the pattern chip offers it first. These two rows are for the projects
	# that want the one line: a rope, and a bar.
	#
	# The other four pin modes are pack rows ONLY, and that is the same rule the acceleration
	# step above is left out under. `global_position.x = a.global_position.x`, `scale = a.scale` and
	# `p = p.lerp(a.p, k * delta)` are three of the most general lines in the language - the last of
	# them is byte-for-byte how a CAMERA scrolls toward a target, which the sheet has had its own
	# words for since the camera-scroll vocabulary landed. A picker row is not just a row: its template is what the IMPORTER matches,
	# so shipping one would silently re-file every such line in every project as a pin, whatever the
	# reading's own gates say. So those four are authored as Pin ▸ Pin To Softly / Pin X Position To
	# / Pin Y Position To / Pin Size To on the pack, and the hand-written shapes only READ as pins in
	# a file that has already pinned that anchor another way. Spring is a pack row for a different
	# reason: it carries velocity between frames, and a row that needs somewhere to keep a number is
	# a behavior, not a one-liner.
	descriptors.append(F.act("PinToObjectRope", "Pin To (Rope)", "{host.}global_position = {anchor}.global_position + ({host.}global_position - {anchor}.global_position).limit_length({length})", CAT_PIN, "Pin to {anchor} (rope, max length {length})", "Hangs the object off another on a rope: free to move inside the length, pulled back the moment the line goes taut. A lantern on a stick, a leash, a wrecking ball.\n\nA pin follows at runtime and can let go; a child is structure and is destroyed with its parent.", "Node2D").param("anchor", "self", "Object", "The object the rope hangs from.", "expression").param("length", "80.0", "Max length", "How long the rope is, in pixels. Inside that the object hangs free.", "expression"))
	descriptors.append(F.act("PinToObjectBar", "Pin To (Bar)", "{host.}global_position = {anchor}.global_position + ({host.}global_position - {anchor}.global_position).normalized() * {length}", CAT_PIN, "Pin to {anchor} (bar, length {length})", "Holds the object at exactly one distance from another, in whatever direction it already lies - a linked cart, a rigid arm, a carriage coupling.\n\nA pin follows at runtime and can let go; a child is structure and is destroyed with its parent.", "Node2D").param("anchor", "self", "Object", "The object the bar is fixed to.", "expression").param("length", "80.0", "Length", "The distance the object is held at, in pixels, every tick.", "expression"))

	return descriptors
