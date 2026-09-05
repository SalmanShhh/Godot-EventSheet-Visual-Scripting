## @ace_tags(motion, juice)
## @ace_category("Spring")
## @ace_expose_all(node)
## @ace_version(1.0.0)
@icon("res://eventsheet_addons/spring/icon.svg")
class_name SpringBehavior
extends Node
## A bank of named springs on a Node2D: numbers that chase a target with real velocity, overshoot, and settle instead of snapping. One-line helpers spring the host's position, angle, and scale, so squash-and-stretch juice is a single row.

## The node this behavior acts on (its parent). Required host: Node2D.
var host: Node2D = null

func _enter_tree() -> void:
	host = get_parent() as Node2D
	if host == null:
		push_warning("SpringBehavior behavior requires a Node2D parent.")

## @ace_trigger
## @ace_name("On Spring Reached")
signal spring_reached(spring_name: String)
## @ace_trigger
## @ace_name("On Spring Started")
signal spring_started(spring_name: String)

## Spring force toward the target (higher = snappier).
@export_range(1, 1000, 1) var default_stiffness: float = 170.0
## 0 = oscillate forever, 1 = no overshoot.
@export_range(0, 1, 0.01) var default_damping: float = 0.85
## Distance + speed below which a spring counts as settled.
@export var default_precision: float = 0.01
var springs: Dictionary = {}
var color_springs: Dictionary = {}
var property_springs: Dictionary = {}

## The most of a velocity a damping may take away in a second. The decay below is EXPONENTIAL,
## so a damping of exactly 1 leaves nothing of the velocity after any step at all: the spring
## stops dead where it stands, never reaches its target, and never settles - which means the
## per-frame tick never parks either. A thousandth of it left is still heavier damping than any
## motion needs, and it is a spring rather than a freeze.
const DAMPING_CEILING: float = 0.999

## A single numeric spring's state, integrated each frame (typed - no dict casts in the hot loop).
class SpringEntry:
	var value: float = 0.0
	var from_value: float = 0.0
	var target: float = 0.0
	var velocity: float = 0.0
	var stiffness: float = 0.0
	var damping: float = 0.0
	var precision: float = 0.0
	var active: bool = false
	## Semi-implicit, framerate-independent step; returns true on the frame it settles.
	func integrate(delta: float) -> bool:
		velocity += (target - value) * stiffness * delta
		# Damping is the fraction of velocity LOST PER SECOND (framerate-independent), held under
		# the ceiling so the heaviest damping is still a spring rather than a freeze.
		velocity *= pow(1.0 - clampf(damping, 0.0, SpringBehavior.DAMPING_CEILING), delta)
		value += velocity * delta
		if absf(target - value) < precision and absf(velocity) < precision:
			value = target
			velocity = 0.0
			active = false
			return true
		return false

## A named colour spring (each channel springs component-wise).
class ColorSpringEntry:
	var value: Color = Color.WHITE
	var target: Color = Color.WHITE
	var velocity: Color = Color(0, 0, 0, 0)
	var stiffness: float = 0.0
	var damping: float = 0.0
	var precision: float = 0.0
	var active: bool = false
	func integrate(delta: float) -> bool:
		velocity = velocity + (target - value) * stiffness * delta
		velocity = velocity * pow(1.0 - clampf(damping, 0.0, SpringBehavior.DAMPING_CEILING), delta)
		value = value + velocity * delta
		if absf(target.r - value.r) < precision and absf(target.g - value.g) < precision and absf(target.b - value.b) < precision and absf(target.a - value.a) < precision:
			value = target
			velocity = Color(0, 0, 0, 0)
			active = false
			return true
		return false
func _spring_entry(spring_name: String) -> SpringEntry:
	if not springs.has(spring_name):
		var entry := SpringEntry.new()
		entry.stiffness = default_stiffness
		entry.damping = default_damping
		entry.precision = default_precision
		springs[spring_name] = entry
	return springs[spring_name]
func _color_entry(spring_name: String) -> ColorSpringEntry:
	if not color_springs.has(spring_name):
		var entry := ColorSpringEntry.new()
		entry.stiffness = default_stiffness
		entry.damping = default_damping
		entry.precision = default_precision
		color_springs[spring_name] = entry
	return color_springs[spring_name]

## One property of the host, springing. `path` is resolved once, when the first row names the
## property, and the type it holds then is the type it is written back as.
class PropertySpring:
	var path: NodePath = NodePath("")
	## How many of the four floats below this property actually uses.
	var components: int = 1
	## The Variant type the property held when it was first sprung.
	var kind: int = TYPE_FLOAT
	## False when the property is missing, or holds something no spring can move.
	var supported: bool = false
	var value: Vector4 = Vector4.ZERO
	var target: Vector4 = Vector4.ZERO
	var velocity: Vector4 = Vector4.ZERO
	var stiffness: float = 0.0
	var damping: float = 0.0
	var precision: float = 0.0
	var min_value: float = 0.0
	var max_value: float = 0.0
	var clamped: bool = false
	var active: bool = false
	## Reads the property's own type once, and starts the spring at rest on what it holds.
	func adopt(current: Variant) -> void:
		kind = typeof(current)
		match kind:
			TYPE_VECTOR2:
				components = 2
			TYPE_VECTOR3:
				components = 3
			TYPE_COLOR:
				components = 4
			TYPE_FLOAT, TYPE_INT:
				components = 1
			_:
				supported = false
				return
		supported = true
		value = pack(current)
		target = value
	## Any of the four kinds as four floats. What a kind does not use stays 0.
	func pack(from_value: Variant) -> Vector4:
		match typeof(from_value):
			TYPE_VECTOR2:
				var as_vector2: Vector2 = from_value
				return Vector4(as_vector2.x, as_vector2.y, 0.0, 0.0)
			TYPE_VECTOR3:
				var as_vector3: Vector3 = from_value
				return Vector4(as_vector3.x, as_vector3.y, as_vector3.z, 0.0)
			TYPE_COLOR:
				var as_color: Color = from_value
				return Vector4(as_color.r, as_color.g, as_color.b, as_color.a)
			TYPE_INT, TYPE_FLOAT:
				return Vector4(float(from_value), 0.0, 0.0, 0.0)
		return Vector4.ZERO
	## The current value, in the type the property is written back as.
	func unpack() -> Variant:
		match kind:
			TYPE_VECTOR2:
				return Vector2(value.x, value.y)
			TYPE_VECTOR3:
				return Vector3(value.x, value.y, value.z)
			TYPE_COLOR:
				return Color(value.x, value.y, value.z, value.w)
			TYPE_INT:
				return int(roundf(value.x))
		return value.x
	## Where a component is really allowed to end up: inside the fence, when there is one.
	func goal(index: int) -> float:
		if clamped:
			return clampf(target[index], min_value, max_value)
		return target[index]
	## One framerate-independent step per live component; true on the frame it settles.
	func integrate(delta: float) -> bool:
		var settled: bool = true
		# Damping is the fraction of velocity LOST PER SECOND, as it is for the named springs, and
		# under the same ceiling for the same reason.
		var decay: float = pow(1.0 - clampf(damping, 0.0, SpringBehavior.DAMPING_CEILING), delta)
		for index: int in components:
			var rest: float = goal(index)
			var speed: float = velocity[index]
			speed += (rest - value[index]) * stiffness * delta
			speed *= decay
			var moved: float = value[index] + speed * delta
			if clamped:
				var held: float = clampf(moved, min_value, max_value)
				if not is_equal_approx(held, moved):
					# A clamped spring stops at the wall rather than pushing through it.
					speed = 0.0
				moved = held
			if absf(rest - moved) < precision and absf(speed) < precision:
				moved = rest
				speed = 0.0
			else:
				settled = false
			value[index] = moved
			velocity[index] = speed
		if settled:
			active = false
		return settled
## The spring under one property, made on the first row that names it and kept afterwards.
## The property's type is read here, once, so the per-frame step never has to ask again.
func _property_spring(property_path: String) -> PropertySpring:
	if property_springs.has(property_path):
		return property_springs[property_path]
	var entry := PropertySpring.new()
	entry.path = NodePath(property_path)
	entry.stiffness = default_stiffness
	entry.damping = default_damping
	entry.precision = default_precision
	if host != null:
		entry.adopt(host.get_indexed(entry.path))
	if not entry.supported:
		push_warning("SpringBehavior cannot spring %s: the host has no such property, or it holds something that is not a number, a vector or a colour." % property_path)
	property_springs[property_path] = entry
	return entry

func _ready() -> void:
	# An empty bank has nothing to integrate, so it costs no frames until a spring verb
	# starts one. Guarded rather than unconditional: a row may already have sprung something
	# before this node was readied.
	if springs.is_empty() and color_springs.is_empty():
		set_process(false)
	if not property_springs.is_empty():
		set_process(true)

func _process(delta: float) -> void:
	# Each spring integrates itself (framerate-independent); host springs write to the parent.
	for spring_name: Variant in springs.keys():
		var entry: SpringEntry = springs[spring_name]
		if not entry.active:
			continue
		if entry.integrate(delta):
			spring_reached.emit(str(spring_name))
		_apply_to_host(str(spring_name), entry.value)
	# Colour springs integrate identically (Color supports +, - and *float component-wise).
	for color_name: Variant in color_springs.keys():
		var centry: ColorSpringEntry = color_springs[color_name]
		if not centry.active:
			continue
		if centry.integrate(delta):
			spring_reached.emit(str(color_name))
	# A bank with nothing left to settle costs nothing per frame; every spring verb turns
	# processing back on. Re-read after the emits above, so a row that starts a new spring
	# from On Spring Reached keeps its frames.
	var still_settling: bool = false
	for pending: Variant in springs.values():
		if (pending as SpringEntry).active:
			still_settling = true
			break
	if not still_settling:
		for color_pending: Variant in color_springs.values():
			if (color_pending as ColorSpringEntry).active:
				still_settling = true
				break
	set_process(still_settling)
	# Springs under a PROPERTY of the host: each writes its own value back where it came from.
	# This runs after the named bank above and only ever turns processing back ON, so a property
	# spring keeps the frames the named springs just parked.
	var property_settling: bool = false
	for property_path: Variant in property_springs.keys():
		var property_entry: PropertySpring = property_springs[property_path]
		if not property_entry.active:
			continue
		var landed: bool = property_entry.integrate(delta)
		if host != null:
			host.set_indexed(property_entry.path, property_entry.unpack())
		if landed:
			spring_reached.emit(str(property_path))
		else:
			property_settling = true
	if property_settling:
		set_process(true)

## @ace_action
## @ace_featured
## @ace_name("Spring To")
## @ace_category("Spring")
## @ace_description("Springs the named value toward a target.")
## @ace_display_template("Spring [b]{spring_name}[/b] to [b]{target}[/b]")
## @ace_icon("res://eventsheet_addons/spring/icon.svg")
## @ace_codegen_template("$SpringBehavior.spring_to({spring_name}, {target})")
func spring_to(spring_name: String, target: float) -> void:
	var entry: SpringEntry = _spring_entry(spring_name)
	var was_active := entry.active
	entry.from_value = entry.value
	entry.target = target
	entry.active = true
	# A moving spring needs its per-frame integration back.
	set_process(true)
	if not was_active:
		spring_started.emit(spring_name)

## @ace_action
## @ace_name("Spring Between")
## @ace_category("Spring")
## @ace_description("Snaps to a start value, then springs to the end value.")
## @ace_icon("res://eventsheet_addons/spring/icon.svg")
## @ace_codegen_template("$SpringBehavior.spring_between({spring_name}, {from_value}, {to_value})")
func spring_between(spring_name: String, from_value: float, to_value: float) -> void:
	var entry: SpringEntry = _spring_entry(spring_name)
	entry.value = from_value
	entry.from_value = from_value
	entry.velocity = 0.0
	entry.target = to_value
	entry.active = true
	# A moving spring needs its per-frame integration back.
	set_process(true)

## @ace_action
## @ace_name("Set Spring Value")
## @ace_category("Spring")
## @ace_description("Snaps the named spring (no motion).")
## @ace_icon("res://eventsheet_addons/spring/icon.svg")
## @ace_codegen_template("$SpringBehavior.set_spring({spring_name}, {value})")
func set_spring(spring_name: String, value: float) -> void:
	var entry: SpringEntry = _spring_entry(spring_name)
	entry.value = value
	entry.from_value = value
	entry.target = value
	entry.velocity = 0.0
	entry.active = false

## @ace_action
## @ace_featured
## @ace_name("Add Impulse")
## @ace_category("Spring")
## @ace_description("Kicks the named spring's velocity (instant juice).")
## @ace_display_template("Kick spring [b]{spring_name}[/b] by [b]{amount}[/b]")
## @ace_icon("res://eventsheet_addons/spring/icon.svg")
## @ace_codegen_template("$SpringBehavior.add_impulse({spring_name}, {amount})")
func add_impulse(spring_name: String, amount: float) -> void:
	var entry: SpringEntry = _spring_entry(spring_name)
	entry.velocity += amount
	entry.active = true
	# A moving spring needs its per-frame integration back.
	set_process(true)

## @ace_action
## @ace_name("Stop Spring")
## @ace_category("Spring")
## @ace_description("Freezes the named spring where it is.")
## @ace_icon("res://eventsheet_addons/spring/icon.svg")
## @ace_codegen_template("$SpringBehavior.stop_spring({spring_name})")
func stop_spring(spring_name: String) -> void:
	if springs.has(spring_name):
		(springs[spring_name] as SpringEntry).active = false

## @ace_action
## @ace_name("Configure Spring")
## @ace_category("Spring")
## @ace_description("Per-spring stiffness/damping/precision overrides.")
## @ace_icon("res://eventsheet_addons/spring/icon.svg")
## @ace_codegen_template("$SpringBehavior.configure_spring({spring_name}, {stiffness}, {damping}, {precision})")
func configure_spring(spring_name: String, stiffness: float, damping: float, precision: float) -> void:
	var entry: SpringEntry = _spring_entry(spring_name)
	entry.stiffness = stiffness
	entry.damping = clampf(damping, 0.0, 1.0)
	entry.precision = precision

## @ace_action
## @ace_name("Spring Host X")
## @ace_category("Spring")
## @ace_description("Springs the host's X position.")
## @ace_icon("res://eventsheet_addons/spring/icon.svg")
## @ace_codegen_template("$SpringBehavior.spring_host_x({target})")
func spring_host_x(target: float) -> void:
	var entry: SpringEntry = _spring_entry("__x")
	if not entry.active and host != null:
		entry.value = host.position.x
	entry.from_value = entry.value
	entry.target = target
	entry.active = true
	# A moving spring needs its per-frame integration back.
	set_process(true)

## @ace_action
## @ace_name("Spring Host Y")
## @ace_category("Spring")
## @ace_description("Springs the host's Y position.")
## @ace_icon("res://eventsheet_addons/spring/icon.svg")
## @ace_codegen_template("$SpringBehavior.spring_host_y({target})")
func spring_host_y(target: float) -> void:
	var entry: SpringEntry = _spring_entry("__y")
	if not entry.active and host != null:
		entry.value = host.position.y
	entry.from_value = entry.value
	entry.target = target
	entry.active = true
	# A moving spring needs its per-frame integration back.
	set_process(true)

## @ace_action
## @ace_name("Spring Host Angle")
## @ace_category("Spring")
## @ace_description("Springs the host's rotation (degrees).")
## @ace_icon("res://eventsheet_addons/spring/icon.svg")
## @ace_codegen_template("$SpringBehavior.spring_host_angle({degrees})")
func spring_host_angle(degrees: float) -> void:
	var entry: SpringEntry = _spring_entry("__angle")
	if not entry.active and host != null:
		entry.value = host.rotation_degrees
	entry.from_value = entry.value
	entry.target = degrees
	entry.active = true
	# A moving spring needs its per-frame integration back.
	set_process(true)

## @ace_action
## @ace_name("Spring Host Scale")
## @ace_category("Spring")
## @ace_description("Springs the host's uniform scale (squash & stretch!).")
## @ace_icon("res://eventsheet_addons/spring/icon.svg")
## @ace_codegen_template("$SpringBehavior.spring_host_scale({target})")
func spring_host_scale(target: float) -> void:
	var entry: SpringEntry = _spring_entry("__scale")
	if not entry.active and host != null:
		entry.value = host.scale.x
	entry.from_value = entry.value
	entry.target = target
	entry.active = true
	# A moving spring needs its per-frame integration back.
	set_process(true)

## @ace_action
## @ace_name("Set Color Value")
## @ace_category("Spring")
## @ace_description("Snaps a named colour spring (no motion) - seed it before springing.")
## @ace_icon("res://eventsheet_addons/spring/icon.svg")
## @ace_codegen_template("$SpringBehavior.set_color({spring_name}, {color})")
func set_color(spring_name: String, color: Color) -> void:
	var entry: ColorSpringEntry = _color_entry(spring_name)
	entry.value = color
	entry.target = color
	entry.velocity = Color(0, 0, 0, 0)
	entry.active = false

## @ace_action
## @ace_name("Spring Color")
## @ace_category("Spring")
## @ace_description("Springs a named colour toward a target (read it back with Color Value - great for hit flashes).")
## @ace_icon("res://eventsheet_addons/spring/icon.svg")
## @ace_codegen_template("$SpringBehavior.spring_color({spring_name}, {target_color})")
func spring_color(spring_name: String, target_color: Color) -> void:
	var entry: ColorSpringEntry = _color_entry(spring_name)
	var was_active := entry.active
	entry.target = target_color
	entry.active = true
	# A moving spring needs its per-frame integration back.
	set_process(true)
	if not was_active:
		spring_started.emit(spring_name)

## @ace_action
## @ace_name("Pause Spring")
## @ace_category("Spring")
## @ace_description("Freezes a spring in place (resume continues it).")
## @ace_icon("res://eventsheet_addons/spring/icon.svg")
## @ace_codegen_template("$SpringBehavior.pause_spring({spring_name})")
func pause_spring(spring_name: String) -> void:
	if springs.has(spring_name):
		(springs[spring_name] as SpringEntry).active = false
	if color_springs.has(spring_name):
		(color_springs[spring_name] as ColorSpringEntry).active = false

## @ace_action
## @ace_name("Resume Spring")
## @ace_category("Spring")
## @ace_description("Resumes a paused spring toward its target.")
## @ace_icon("res://eventsheet_addons/spring/icon.svg")
## @ace_codegen_template("$SpringBehavior.resume_spring({spring_name})")
func resume_spring(spring_name: String) -> void:
	if springs.has(spring_name):
		(springs[spring_name] as SpringEntry).active = true
	if color_springs.has(spring_name):
		(color_springs[spring_name] as ColorSpringEntry).active = true
	# A moving spring needs its per-frame integration back.
	set_process(true)

## @ace_action
## @ace_name("Remove Spring")
## @ace_category("Spring")
## @ace_description("Deletes a named spring (numeric and/or colour).")
## @ace_icon("res://eventsheet_addons/spring/icon.svg")
## @ace_codegen_template("$SpringBehavior.remove_spring({spring_name})")
func remove_spring(spring_name: String) -> void:
	springs.erase(spring_name)
	color_springs.erase(spring_name)

## @ace_action
## @ace_name("Reset All Springs")
## @ace_category("Spring")
## @ace_description("Clears every spring on this behavior.")
## @ace_icon("res://eventsheet_addons/spring/icon.svg")
## @ace_codegen_template("$SpringBehavior.reset_springs()")
func reset_springs() -> void:
	springs.clear()
	color_springs.clear()

## @ace_action
## @ace_name("Spring Property To")
## @ace_category("Spring")
## @ace_description("Springs any property of the host toward a value: a number, a Vector2, a Vector3 or a Color, addressed by the same path the Inspector shows. The property's own type is read once, on the first row that springs it, and the spring writes it back every frame until it settles.")
## @ace_display_template("Spring [b]{property_path}[/b] to [b]{target_value}[/b]")
## @ace_param(property_path, desc: "The property to spring, as the Inspector spells it: modulate, position, rotation_degrees, scale:x.")
## @ace_param(target_value, desc: "Where it should end up. Give it the same kind of value the property holds.")
## @ace_icon("res://eventsheet_addons/spring/icon.svg")
## @ace_codegen_template("$SpringBehavior.spring_property_to({property_path}, {target_value})")
func spring_property_to(property_path: String, target_value: Variant) -> void:
	var entry: PropertySpring = _property_spring(property_path)
	if not entry.supported:
		return
	entry.target = entry.pack(target_value)
	entry.active = true
	# A moving spring needs its per-frame integration back.
	set_process(true)

## @ace_action
## @ace_name("Bump Property")
## @ace_category("Spring")
## @ace_description("Kicks a property's spring by an amount and lets it settle back on its own - the fastest juice there is: one row, no duration, nothing to clean up. Bump a field of view on a shot, a light's energy on a hit, a panel's scale on a press.")
## @ace_display_template("Bump [b]{property_path}[/b] by [b]{amount}[/b]")
## @ace_param(property_path, desc: "The property to push, as the Inspector spells it.")
## @ace_param(amount, desc: "How hard the push is, in the property's own units. Negative pushes the other way.")
## @ace_icon("res://eventsheet_addons/spring/icon.svg")
## @ace_codegen_template("$SpringBehavior.bump_property({property_path}, {amount})")
func bump_property(property_path: String, amount: Variant) -> void:
	var entry: PropertySpring = _property_spring(property_path)
	if not entry.supported:
		return
	entry.velocity += entry.pack(amount)
	entry.active = true
	# A moving spring needs its per-frame integration back.
	set_process(true)

## @ace_action
## @ace_name("Set Spring Damping And Frequency")
## @ace_category("Spring")
## @ace_description("The two numbers a spring really has: how fast the bounce dies out (0 loose, 1 dead) and how many swings a second it wants. Set them per property, before the motion or during it.")
## @ace_display_template("Spring [b]{property_path}[/b]: damping [b]{damping}[/b], [b]{frequency}[/b] per second")
## @ace_param(property_path, desc: "The property whose spring is being tuned.")
## @ace_param(damping, desc: "0 oscillates for ever, 1 never overshoots.")
## @ace_param(frequency, desc: "Swings per second - how eager the spring is to get there.")
## @ace_icon("res://eventsheet_addons/spring/icon.svg")
## @ace_codegen_template("$SpringBehavior.set_property_spring({property_path}, {damping}, {frequency})")
func set_property_spring(property_path: String, damping: float, frequency: float) -> void:
	var entry: PropertySpring = _property_spring(property_path)
	entry.damping = clampf(damping, 0.0, 1.0)
	# Frequency is the swings a second a designer asks for; stiffness is what the integrator wants.
	var swings: float = maxf(frequency, 0.01) * TAU
	entry.stiffness = swings * swings

## @ace_action
## @ace_name("Clamp Spring Between")
## @ace_category("Spring")
## @ace_description("Holds a property's spring between two numbers: it stops dead at the wall instead of pushing through it. A lid that must not pass its hinge, a bar that must not go under zero. The same number on both sides takes the clamp off again.")
## @ace_display_template("Clamp [b]{property_path}[/b] between [b]{min_value}[/b] and [b]{max_value}[/b]")
## @ace_param(property_path, desc: "The property whose spring is being fenced in.")
## @ace_param(min_value, desc: "The lowest the value may go.")
## @ace_param(max_value, desc: "The highest the value may go.")
## @ace_icon("res://eventsheet_addons/spring/icon.svg")
## @ace_codegen_template("$SpringBehavior.clamp_property_spring({property_path}, {min_value}, {max_value})")
func clamp_property_spring(property_path: String, min_value: float, max_value: float) -> void:
	var entry: PropertySpring = _property_spring(property_path)
	entry.min_value = minf(min_value, max_value)
	entry.max_value = maxf(min_value, max_value)
	# One number on both sides is how a row says there is no fence: a spring pinned to a point is not a clamp.
	entry.clamped = not is_equal_approx(min_value, max_value)

## @ace_condition
## @ace_name("Spring Is Settled")
## @ace_category("Spring")
## @ace_description("True while nothing is springing that property - it has arrived, or it was never sprung at all.")
## @ace_param(property_path, desc: "The property to ask about.")
## @ace_icon("res://eventsheet_addons/spring/icon.svg")
## @ace_codegen_template("$SpringBehavior.property_spring_is_settled({property_path})")
func property_spring_is_settled(property_path: String) -> bool:
	if not property_springs.has(property_path):
		return true
	return not (property_springs[property_path] as PropertySpring).active

## @ace_expression
## @ace_name("Spring Value Of")
## @ace_category("Spring")
## @ace_description("What the property's spring reads right now, as a number: the value itself for a number, x for a vector, red for a colour. 0 if nothing has sprung it.")
## @ace_param(property_path, desc: "The property to read.")
## @ace_icon("res://eventsheet_addons/spring/icon.svg")
## @ace_codegen_template("$SpringBehavior.property_spring_value({property_path})")
func property_spring_value(property_path: String) -> float:
	if not property_springs.has(property_path):
		return 0.0
	return (property_springs[property_path] as PropertySpring).value.x

## @ace_expression
## @ace_name("Spring Velocity Of")
## @ace_category("Spring")
## @ace_description("How fast the property's spring is moving right now, as a number - drive a lean, a blur or a stretch off it so the motion shows its own speed. 0 if nothing has sprung it.")
## @ace_param(property_path, desc: "The property to read.")
## @ace_icon("res://eventsheet_addons/spring/icon.svg")
## @ace_codegen_template("$SpringBehavior.property_spring_velocity({property_path})")
func property_spring_velocity(property_path: String) -> float:
	if not property_springs.has(property_path):
		return 0.0
	return (property_springs[property_path] as PropertySpring).velocity.x

## @ace_expression
## @ace_name("Color Value")
## @ace_icon("res://eventsheet_addons/spring/icon.svg")
## @ace_codegen_template("$SpringBehavior.color_value({spring_name})")
func color_value(spring_name: String) -> Color:
	if not color_springs.has(spring_name):
		return Color.WHITE
	return (color_springs[spring_name] as ColorSpringEntry).value

## @ace_condition
## @ace_name("Is Springing")
## @ace_icon("res://eventsheet_addons/spring/icon.svg")
## @ace_codegen_template("$SpringBehavior.is_springing({spring_name})")
func is_springing(spring_name: String) -> bool:
	return springs.has(spring_name) and (springs[spring_name] as SpringEntry).active

## @ace_expression
## @ace_name("Spring Value")
## @ace_icon("res://eventsheet_addons/spring/icon.svg")
## @ace_codegen_template("$SpringBehavior.spring_value({spring_name})")
func spring_value(spring_name: String) -> float:
	if not springs.has(spring_name):
		return 0.0
	return (springs[spring_name] as SpringEntry).value

## @ace_expression
## @ace_name("Spring Velocity")
## @ace_icon("res://eventsheet_addons/spring/icon.svg")
## @ace_codegen_template("$SpringBehavior.spring_velocity({spring_name})")
func spring_velocity(spring_name: String) -> float:
	if not springs.has(spring_name):
		return 0.0
	return (springs[spring_name] as SpringEntry).velocity

## @ace_expression
## @ace_name("Spring Progress")
## @ace_icon("res://eventsheet_addons/spring/icon.svg")
## @ace_codegen_template("$SpringBehavior.spring_progress({spring_name})")
func spring_progress(spring_name: String) -> float:
	if not springs.has(spring_name):
		return 1.0
	var entry: SpringEntry = springs[spring_name]
	var span: float = absf(entry.target - entry.from_value)
	if span <= 0.0:
		return 1.0
	return clampf(1.0 - absf(entry.target - entry.value) / span, 0.0, 1.0)

func _apply_to_host(spring_name: String, value: float) -> void:
	# Host conveniences: springs with these names write straight onto the parent.
	if host == null:
		return
	match spring_name:
		"__x": host.position.x = value
		"__y": host.position.y = value
		"__angle": host.rotation_degrees = value
		"__scale": host.scale = Vector2(value, value)

# Numeric springing: snappy, physical motion for ANY number. Name a spring, set its target, read its value - or use the host helpers (x/y/angle/scale) for instant juice.
