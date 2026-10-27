## @ace_tags(movement, attachment)
## @ace_category("Pin")
## @ace_version(1.0.0)
@icon("res://eventsheet_addons/pin/icon.svg")
class_name PinBehavior
extends Node
## Sticks a Node2D to another object: every physics frame the host copies that object's position, its angle, or both, kept apart by the offset the pin was made with. Health bars over heads, a hat on a player, a turret on a tank, a shadow under a jumper - one action instead of a line of transform arithmetic. The mode picks HOW it follows: straight onto the place, on a rope that only pulls when taut, on a bar that holds its length, softly with a lag, or on a spring that overshoots and settles.

## The node this behavior acts on (its parent). Required host: Node2D.
var host: Node2D = null

func _enter_tree() -> void:
	host = get_parent() as Node2D
	if host == null:
		push_warning("PinBehavior behavior requires a Node2D parent.")

# --- Designer knobs (tune in the Inspector) ---
## What to copy from the object being ridden, and how to travel to it. The first three are
## the plain copies; rope, bar, soft and spring are the ways a follow can lag or be held at
## a distance, and size copies the anchor's scale instead of its place.
@export_enum("position", "angle", "position and angle", "rope", "bar", "soft", "spring", "size") var pin_mode: String = "position and angle"
## On: the offset turns with the anchor, so the host orbits it. Off: the offset stays axis-aligned.
@export var rotate_with_anchor: bool = true
## Master on/off - Unpin flips it, Pin To turns it back on.
@export var pin_enabled: bool = true
## How long the rope or the bar is, in pixels. A rope is slack below this and pulls at it; a
## bar holds the host at exactly this distance, every tick.
@export var pin_length: float = 80.0
## How quickly a soft pin closes the gap, per second. 10 catches up in about a tenth of a
## second; 2 trails a long way behind, which is what makes a follower feel alive.
@export var pin_speed: float = 10.0
## Spring pull toward the anchor (higher = snappier) - the same pair of numbers the Spring
## pack's own integrator takes, so a spring pin and a sprung number feel alike.
@export var pin_stiffness: float = 170.0
## 0 = oscillate forever, 1 = no overshoot.
@export var pin_damping: float = 0.85
## Which axes of the place follow. X only pins a shadow to a walker's column; Y only pins a
## side-bar to its height.
@export_enum("both", "x only", "y only") var pin_axes: String = "both"
## Also copy the anchor's scale, whatever else the mode copies.
@export var pin_follow_size: bool = false
## The name of a child of the anchor to ride instead of the anchor itself - a Bone2D, a
## Marker2D, the hand a weapon hangs off. Empty rides the anchor. A name that matches nothing
## falls back to the anchor rather than dropping the pin.
@export var pin_point: String = ""

# --- Internal state ---
# The object being ridden, and how far the host sat from it when the pin was made. The offset
# is stored in the ANCHOR's own frame when rotate_with_anchor is on, which is what lets the
# host swing round with it instead of sliding out of place the moment the anchor turns.
var anchor: Node2D = null
var pin_offset: Vector2 = Vector2.ZERO
var pin_angle_offset: float = 0.0
# The spring mode's carried velocity - the one piece of state overshoot needs.
var pin_velocity: Vector2 = Vector2.ZERO

# The modes that copy a PLACE and the modes that copy an ANGLE, written out rather than
# inferred. The three shipped modes keep exactly the meaning they always had ("position and
# angle" is in both lists, "position" only in the first, "angle" only in the second); the new
# modes are all ways of travelling to a place, so they join the first list only.
## @ace_hidden
const PIN_PLACE_MODES: PackedStringArray = [
	"position", "position and angle", "rope", "bar", "soft", "spring"
]
## @ace_hidden
const PIN_ANGLE_MODES: PackedStringArray = ["angle", "position and angle"]
# The node the host actually rides: the anchor, or the named point on it. The lookup is a
# RECURSIVE search of the anchor's whole subtree - fine once, far too much every physics
# frame - so the answer is remembered and only searched for again when it goes stale: a
# different anchor, a different point name, or a seat that has been freed. A skeleton that
# re-parents its attachments therefore still cannot leave the pin holding a dead node.
var _seat: Node2D = null
var _seat_of: Node2D = null
var _seat_named: String = ""
func _pin_seat() -> Node2D:
	if pin_point.is_empty():
		return anchor
	if _seat_of == anchor and _seat_named == pin_point and is_instance_valid(_seat):
		return _seat
	var point: Node2D = anchor.find_child(pin_point, true, false) as Node2D
	if point == null:
		# A name that matches nothing rides the anchor and is NOT remembered, so a rig that adds
		# the attachment later still gets picked up.
		return anchor
	_seat = point
	_seat_of = anchor
	_seat_named = pin_point
	return _seat

func _ready() -> void:
	# Nothing is being ridden until a Pin To row names something, and the tick can do no work
	# without an anchor - so a pin that has not been made yet costs nothing per physics frame.
	set_physics_process(is_pinned())

func _physics_process(delta: float) -> void:
	if not pin_enabled or host == null or not is_instance_valid(anchor):
		return
	var seat: Node2D = _pin_seat()
	if seat == null:
		return
	if pin_mode in PIN_PLACE_MODES:
		# The offset rides the anchor's own frame when asked to, so a turning anchor carries the
		# host round it; otherwise it stays the plain world-space gap the pin was made with.
		var offset: Vector2 = pin_offset.rotated(seat.global_rotation) if rotate_with_anchor else pin_offset
		_place_host(seat.global_position + offset, delta)
	if pin_mode in PIN_ANGLE_MODES:
		host.global_rotation = seat.global_rotation + pin_angle_offset
	if pin_follow_size or pin_mode == "size":
		host.scale = seat.scale

## @ace_action
## @ace_featured
## @ace_name("Pin To")
## @ace_category("Pin")
## @ace_description("Sticks the host to an object, remembering how far apart the two are right now. From this frame on the host rides it. A pin follows at runtime and can let go; a child is structure and is destroyed with its parent - this is the first of those two.")
## @ace_display_template("Pin to [b]{target}[/b]")
## @ace_icon("res://eventsheet_addons/pin/icon.svg")
## @ace_codegen_template("$PinBehavior.pin_to({target})")
func pin_to(target: Node2D) -> void:
	anchor = target
	pin_enabled = is_instance_valid(target)
	_clear_pin_modes()
	# The host rides something from this frame on, which is per-frame work; a target that
	# is already gone leaves the tick off rather than running it for nothing.
	set_physics_process(pin_enabled)
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
	_clear_pin_modes()
	# The host rides something from this frame on, which is per-frame work; a target that
	# is already gone leaves the tick off rather than running it for nothing.
	set_physics_process(pin_enabled)

## @ace_action
## @ace_name("Set Pin Offset")
## @ace_category("Pin")
## @ace_description("Moves the host to a new distance from the object it is riding, in pixels.")
## @ace_icon("res://eventsheet_addons/pin/icon.svg")
## @ace_codegen_template("$PinBehavior.set_pin_offset({offset_x}, {offset_y})")
func set_pin_offset(offset_x: float, offset_y: float) -> void:
	pin_offset = Vector2(offset_x, offset_y)

## @ace_action
## @ace_name("Pin To Rope")
## @ace_category("Pin")
## @ace_description("Hangs the host off an object on a rope of the given length. Inside that length it moves freely; past it the rope goes taut and pulls it back - a lantern on a stick, a leash, a wrecking ball.")
## @ace_display_template("Pin to [i]{target}[/i] on a rope of [b]{max_length}[/b]")
## @ace_icon("res://eventsheet_addons/pin/icon.svg")
## @ace_codegen_template("$PinBehavior.pin_rope({target}, {max_length})")
func pin_rope(target: Node2D, max_length: float) -> void:
	_begin_pin(target, "rope")
	pin_length = maxf(max_length, 0.0)

## @ace_action
## @ace_name("Pin To Bar")
## @ace_category("Pin")
## @ace_description("Holds the host at exactly the given distance from an object, every tick, in whatever direction it already lies - a linked cart, a rigid arm, a carriage coupling.")
## @ace_display_template("Pin to [i]{target}[/i] on a bar of [b]{length}[/b]")
## @ace_icon("res://eventsheet_addons/pin/icon.svg")
## @ace_codegen_template("$PinBehavior.pin_bar({target}, {length})")
func pin_bar(target: Node2D, length: float) -> void:
	_begin_pin(target, "bar")
	pin_length = maxf(length, 0.0)

## @ace_action
## @ace_name("Pin To Softly")
## @ace_category("Pin")
## @ace_description("Follows an object with a lag instead of snapping onto it. The speed is how much of the gap is closed each second - low numbers trail a long way behind, which is what makes a camera target or a pet feel alive.")
## @ace_display_template("Pin to [i]{target}[/i] softly at [b]{speed}[/b]")
## @ace_icon("res://eventsheet_addons/pin/icon.svg")
## @ace_codegen_template("$PinBehavior.pin_soft({target}, {speed})")
func pin_soft(target: Node2D, speed: float) -> void:
	_begin_pin(target, "soft")
	pin_speed = maxf(speed, 0.0)

## @ace_action
## @ace_name("Pin To With Spring")
## @ace_category("Pin")
## @ace_description("Follows an object on a spring: it overshoots, wobbles and settles instead of arriving flat. Stiffness is the pull, damping is how fast the wobble dies (0 never settles, 1 never overshoots) - the same pair of numbers the Spring pack's own integrator takes.")
## @ace_display_template("Pin to [i]{target}[/i] with a spring ([b]{stiffness}[/b], [b]{damping}[/b])")
## @ace_icon("res://eventsheet_addons/pin/icon.svg")
## @ace_codegen_template("$PinBehavior.pin_spring({target}, {stiffness}, {damping})")
func pin_spring(target: Node2D, stiffness: float, damping: float) -> void:
	_begin_pin(target, "spring")
	pin_stiffness = maxf(stiffness, 0.0)
	pin_damping = clampf(damping, 0.0, 1.0)

## @ace_action
## @ace_name("Pin X Position To")
## @ace_category("Pin")
## @ace_description("Follows an object's column and nothing else: the host keeps its own height. A shadow under a jumper, a rail-mounted turret.")
## @ace_display_template("Pin X position to [i]{target}[/i]")
## @ace_icon("res://eventsheet_addons/pin/icon.svg")
## @ace_codegen_template("$PinBehavior.pin_x_to({target})")
func pin_x_to(target: Node2D) -> void:
	_begin_pin(target, "position")
	pin_axes = "x only"

## @ace_action
## @ace_name("Pin Y Position To")
## @ace_category("Pin")
## @ace_description("Follows an object's height and nothing else: the host keeps its own column. A side bar that rides a lift, a depth marker.")
## @ace_display_template("Pin Y position to [i]{target}[/i]")
## @ace_icon("res://eventsheet_addons/pin/icon.svg")
## @ace_codegen_template("$PinBehavior.pin_y_to({target})")
func pin_y_to(target: Node2D) -> void:
	_begin_pin(target, "position")
	pin_axes = "y only"

## @ace_action
## @ace_name("Pin Size To")
## @ace_category("Pin")
## @ace_description("Copies an object's scale and nothing else, so the host grows and shrinks with it - a shadow that swells as its owner lands, a selection ring around a resizing token.")
## @ace_display_template("Pin size to [i]{target}[/i]")
## @ace_icon("res://eventsheet_addons/pin/icon.svg")
## @ace_codegen_template("$PinBehavior.pin_size_to({target})")
func pin_size_to(target: Node2D) -> void:
	_begin_pin(target, "size")
	pin_follow_size = true

## @ace_action
## @ace_name("Pin To Point")
## @ace_category("Pin")
## @ace_description("Rides a NAMED child of an object rather than the object itself - a Bone2D, a Marker2D, the hand a weapon hangs off. The gap the two are standing at right now is remembered, exactly as Pin To does.")
## @ace_display_template("Pin to [i]{target}[/i]'s [b]{point_name}[/b]")
## @ace_icon("res://eventsheet_addons/pin/icon.svg")
## @ace_codegen_template("$PinBehavior.pin_to_point({target}, {point_name})")
func pin_to_point(target: Node2D, point_name: String) -> void:
	anchor = target
	pin_enabled = is_instance_valid(target)
	_clear_pin_modes()
	pin_point = point_name
	pin_mode = "position and angle"
	# The host rides something from this frame on, which is per-frame work; a target that
	# is already gone leaves the tick off rather than running it for nothing.
	set_physics_process(pin_enabled)
	if not pin_enabled or host == null:
		return
	var seat: Node2D = _pin_seat()
	if seat == null:
		return
	var gap: Vector2 = host.global_position - seat.global_position
	pin_offset = gap.rotated(-seat.global_rotation) if rotate_with_anchor else gap
	pin_angle_offset = host.global_rotation - seat.global_rotation

## @ace_action
## @ace_name("Pin To Path")
## @ace_category("Pin")
## @ace_description("Rides a point that travels a curve. Pass a PathFollow2D and the host rides that one; pass a Path2D and the pack makes the follower once and rides it. Set Path Progress then drives the host along the curve.")
## @ace_display_template("Pin to [i]{path_node}[/i]'s path position")
## @ace_icon("res://eventsheet_addons/pin/icon.svg")
## @ace_codegen_template("$PinBehavior.pin_to_path({path_node})")
func pin_to_path(path_node: Node2D) -> void:
	var follower: PathFollow2D = path_node as PathFollow2D
	if follower == null:
		var path: Path2D = path_node as Path2D
		if path == null:
			return
		follower = path.get_node_or_null(NodePath("PinPathFollow")) as PathFollow2D
		if follower == null:
			follower = PathFollow2D.new()
			follower.name = "PinPathFollow"
			follower.loop = true
			path.add_child(follower)
	_begin_pin(follower, "position")
	pin_point = ""

## @ace_action
## @ace_name("Set Path Progress")
## @ace_category("Pin")
## @ace_description("Moves a path pin along its curve, 0 at the start and 1 at the end. Does nothing when the pin is not riding a path.")
## @ace_icon("res://eventsheet_addons/pin/icon.svg")
## @ace_codegen_template("$PinBehavior.set_path_progress({ratio})")
func set_path_progress(ratio: float) -> void:
	if not is_instance_valid(anchor):
		return
	var follower: PathFollow2D = anchor as PathFollow2D
	if follower != null:
		follower.progress_ratio = clampf(ratio, 0.0, 1.0)

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
	_clear_pin_modes()
	# Let go and the host moves on its own, so the copy-every-frame work is over - Pin To
	# turns processing back on. The host keeps the place it already had, written before this.
	set_physics_process(false)

## @ace_condition
## @ace_name("Is Pinned")
## @ace_description("True while the host is riding another object.")
## @ace_icon("res://eventsheet_addons/pin/icon.svg")
## @ace_codegen_template("$PinBehavior.is_pinned()")
func is_pinned() -> bool:
	return pin_enabled and is_instance_valid(anchor)

## @ace_condition
## @ace_name("Is Taut")
## @ace_description("True while a rope or bar pin is stretched out to its full length - the frame a swing starts pulling. Always false in the other modes, which have no length to be stretched to.")
## @ace_icon("res://eventsheet_addons/pin/icon.svg")
## @ace_codegen_template("$PinBehavior.is_taut()")
func is_taut() -> bool:
	if not pin_mode in ["rope", "bar"] or host == null or not is_instance_valid(anchor):
		return false
	return host.global_position.distance_to(anchor.global_position) >= pin_length - 0.5

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

## @ace_expression
## @ace_name("PinDistance")
## @ace_description("How far the host currently is from the object it rides, in pixels.")
## @ace_icon("res://eventsheet_addons/pin/icon.svg")
## @ace_codegen_template("$PinBehavior.pin_distance()")
func pin_distance() -> float:
	if host == null or not is_instance_valid(anchor):
		return 0.0
	return host.global_position.distance_to(anchor.global_position)

## @ace_expression
## @ace_name("PinPathProgress")
## @ace_description("How far along its path a path pin has travelled, 0 to 1. Zero when the pin is not riding a path.")
## @ace_icon("res://eventsheet_addons/pin/icon.svg")
## @ace_codegen_template("$PinBehavior.pin_path_progress()")
func pin_path_progress() -> float:
	if not is_instance_valid(anchor):
		return 0.0
	var follower: PathFollow2D = anchor as PathFollow2D
	return follower.progress_ratio if follower != null else 0.0

## Chooses what the host copies from its anchor, and how it travels there.
## Option labels carry no commas on purpose - the picker splits the list on them, so a comma
## inside a label would offer half a sentence as a ninth mode nothing answers to.
## @ace_action
## @ace_name("Set Pin Mode")
## @ace_param_options(mode position=Follow its place only, angle=Follow its angle only, position and angle=Follow both, rope=Hang on a rope and pull only when taut, bar=Hold at exactly the length, soft=Follow with a lag, spring=Overshoot and settle, size=Copy its scale only)
## @ace_icon("res://eventsheet_addons/pin/icon.svg")
## @ace_codegen_template("$PinBehavior.set_pin_mode("{mode}")")
func set_pin_mode(mode: String) -> void:
	if mode in ["position", "angle", "position and angle", "rope", "bar", "soft", "spring", "size"]:
		pin_mode = mode

## Chooses which axes of the place follow: both of them, the column only, or the height only.
## @ace_action
## @ace_name("Set Pin Axes")
## @ace_param_options(axes both=Follow both axes, x only=Follow the column only, y only=Follow the height only)
## @ace_icon("res://eventsheet_addons/pin/icon.svg")
## @ace_codegen_template("$PinBehavior.set_pin_axes("{axes}")")
func set_pin_axes(axes: String) -> void:
	if axes in ["both", "x only", "y only"]:
		pin_axes = axes

func _pin_reach(current: Vector2, goal: Vector2, delta: float) -> Vector2:
	# Where the host ends up this frame, for the mode it is in. The straight modes land on the
	# goal; a rope hangs free until the line is taut and is then pulled back onto it; a bar is held
	# at exactly its length in whatever direction the host already lies; soft closes a share of the
	# gap; spring carries a velocity, so it overshoots and settles.
	match pin_mode:
		"rope":
			var slack: Vector2 = current - goal
			return current if slack.length() <= pin_length else goal + slack.normalized() * pin_length
		"bar":
			var arm: Vector2 = current - goal
			if arm.length() < 0.0001:
				arm = Vector2.RIGHT
			return goal + arm.normalized() * pin_length
		"soft":
			return current.lerp(goal, clampf(pin_speed * delta, 0.0, 1.0))
		"spring":
			pin_velocity += (goal - current) * pin_stiffness * delta
			pin_velocity *= pow(1.0 - clampf(pin_damping, 0.0, 1.0), delta)
			return current + pin_velocity * delta
	return goal

func _place_host(goal: Vector2, delta: float) -> void:
	# Writes the reached place onto the host, one axis at a time when the pin is axis-locked.
	var placed: Vector2 = _pin_reach(host.global_position, goal, delta)
	if pin_axes == "x only":
		host.global_position.x = placed.x
	elif pin_axes == "y only":
		host.global_position.y = placed.y
	else:
		host.global_position = placed

func _clear_pin_modes() -> void:
	# Puts every mode knob back to its plain value. Each new pin starts from a clean sheet, or a
	# Pin X Position To followed later by a Pin To Rope would quietly give the rope one axis, and
	# a Pin Size To would keep copying an old anchor's scale forever.
	pin_axes = "both"
	pin_follow_size = false
	pin_point = ""
	pin_velocity = Vector2.ZERO

func _begin_pin(target: Node2D, mode: String) -> void:
	# Starts a pin in one of the distance/lag modes: the anchor's own place is the goal, so the
	# offset is cleared and the mode's length or speed does the work.
	anchor = target
	pin_enabled = is_instance_valid(target)
	pin_mode = mode
	pin_offset = Vector2.ZERO
	pin_angle_offset = 0.0
	_clear_pin_modes()
	# A pin has to copy its anchor every physics frame while it holds, so processing follows
	# the pin itself: on the moment there is something to ride, off again at Unpin.
	set_physics_process(pin_enabled)

# Pin behavior (event-sheet parity): the host rides another object. Pin To starts it and remembers how far apart the two were; Pin Mode chooses position, angle, both, rope, bar, soft, spring or size; Unpin lets go. Rotate With Anchor turns the offset with the anchor, so a pinned hat swings round the head instead of hovering beside it. Pin To Point rides a named child of the anchor - a bone, a marker, a hand - and Pin To Path rides a point that travels a Path2D. This pack is an event sheet - extend it by editing it.
