## @ace_category("Sine")
## @ace_expose_all(node)
@icon("res://eventsheet_addons/sine/icon.svg")
class_name SineBehavior
extends Node
## Makes a Node2D oscillate on its own: pick what the wave drives (position, scale, angle, or opacity), how far it swings, how long a cycle takes, and the wave shape (sine, triangle, sawtooth, or square). The fastest way to add the small, endless motion that makes a scene feel alive - no timeline or keyframes.

## The node this behavior acts on (its parent). Required host: Node2D.
var host: Node2D = null

func _enter_tree() -> void:
	host = get_parent() as Node2D
	if host == null:
		push_warning("SineBehavior behavior requires a Node2D parent.")

## When off, pauses the oscillation and leaves the host in place.
@export var active: bool = true
var base_alpha: float = 1.0
var base_captured: bool = false
var base_rotation: float = 0.0
var base_scale_x: float = 1.0
var base_scale_y: float = 1.0
var base_x: float = 0.0
var base_y: float = 0.0
## Peak strength of the oscillation (pixels, degrees, or scale/opacity factor by movement).
@export var magnitude: float = 50.0
## Which host property the wave drives - position, size, angle, opacity, or value-only.
@export_enum("horizontal", "vertical", "forwards-backwards", "size", "angle", "opacity", "value-only") var movement: String = "horizontal"
## Seconds for one full wave cycle.
@export var period: float = 4.0
## Phase offset in degrees - shifts where in the cycle the wave starts.
@export var phase_degrees: float = 0.0
var time: float = 0.0
## Waveform shape of the oscillation - sine, triangle, sawtooth, reverse-sawtooth, or square.
@export_enum("sine", "triangle", "sawtooth", "reverse-sawtooth", "square") var wave: String = "sine"
var wave_value: float = 0.0

func _process(delta: float) -> void:
	if not active or host == null:
		return
	if not base_captured:
		update_initial_state()
	time += delta
	var t := time / maxf(period, 0.001) + phase_degrees / 360.0
	wave_value = _wave(t)
	var offset := wave_value * magnitude
	if movement == "horizontal":
		host.position.x = base_x + offset
	elif movement == "vertical":
		host.position.y = base_y + offset
	elif movement == "forwards-backwards":
		host.position = Vector2(base_x, base_y) + Vector2.from_angle(base_rotation) * offset
	elif movement == "size":
		host.scale = Vector2(base_scale_x, base_scale_y) * (1.0 + wave_value * magnitude * 0.01)
	elif movement == "angle":
		host.rotation = base_rotation + offset * 0.0174533
	elif movement == "opacity":
		host.modulate.a = clampf(base_alpha + wave_value * magnitude * 0.01, 0.0, 1.0)

## @ace_action
## @ace_name("Set Sine Active")
## @ace_category("Sine")
## @ace_description("Pauses or resumes the oscillation.")
## @ace_icon("res://eventsheet_addons/sine/icon.svg")
## @ace_codegen_template("$SineBehavior.set_sine_active({is_active})")
func set_sine_active(is_active: bool) -> void:
	active = is_active

## @ace_action
## @ace_name("Update Initial State")
## @ace_category("Sine")
## @ace_description("Re-captures the host's current position/scale/angle/opacity as the wave's base (updateInitialState).")
## @ace_icon("res://eventsheet_addons/sine/icon.svg")
## @ace_codegen_template("$SineBehavior.update_initial_state()")
func update_initial_state() -> void:
	if host == null:
		return
	base_x = host.position.x
	base_y = host.position.y
	base_rotation = host.rotation
	base_scale_x = host.scale.x
	base_scale_y = host.scale.y
	base_alpha = host.modulate.a
	base_captured = true

## @ace_action
## @ace_name("Set Phase")
## @ace_category("Sine")
## @ace_description("Phase offset in degrees.")
## @ace_icon("res://eventsheet_addons/sine/icon.svg")
## @ace_codegen_template("$SineBehavior.set_sine_phase({degrees})")
func set_sine_phase(degrees: float) -> void:
	phase_degrees = degrees

## @ace_action
## @ace_name("Reset Sine")
## @ace_category("Sine")
## @ace_description("Restarts the wave from the current state.")
## @ace_icon("res://eventsheet_addons/sine/icon.svg")
## @ace_codegen_template("$SineBehavior.reset_sine()")
func reset_sine() -> void:
	time = 0.0
	base_captured = false

## @ace_hidden
func _wave(t: float) -> float:
	var cycle := fposmod(t, 1.0)
	match wave:
		"triangle":
			return 1.0 - 4.0 * absf(cycle - 0.5)
		"sawtooth":
			return 2.0 * cycle - 1.0
		"reverse-sawtooth":
			return 1.0 - 2.0 * cycle
		"square":
			return 1.0 if cycle < 0.5 else -1.0
	return sin(cycle * TAU)

## @ace_hidden
static func editor_preview_sample(params: Dictionary, base: Dictionary, time: float) -> Dictionary:
	# Editor-preview contract (Tools > Preview Behaviors on Selected Node): pure wave math over
	# the Inspector values, so the editor can animate the host without running the behavior.
	if not bool(params.get("active", true)):
		return {}
	var t := time / maxf(float(params.get("period", 4.0)), 0.001) + float(params.get("phase_degrees", 0.0)) / 360.0
	var cycle := fposmod(t, 1.0)
	var value := sin(cycle * TAU)
	match str(params.get("wave", "sine")):
		"triangle":
			value = 1.0 - 4.0 * absf(cycle - 0.5)
		"sawtooth":
			value = 2.0 * cycle - 1.0
		"reverse-sawtooth":
			value = 1.0 - 2.0 * cycle
		"square":
			value = 1.0 if cycle < 0.5 else -1.0
	var magnitude := float(params.get("magnitude", 50.0))
	var offset := value * magnitude
	var base_position: Vector2 = base.get("position", Vector2.ZERO)
	var base_rot := float(base.get("rotation", 0.0))
	match str(params.get("movement", "horizontal")):
		"horizontal":
			return {"position": base_position + Vector2(offset, 0.0)}
		"vertical":
			return {"position": base_position + Vector2(0.0, offset)}
		"forwards-backwards":
			return {"position": base_position + Vector2.from_angle(base_rot) * offset}
		"size":
			var base_scale: Vector2 = base.get("scale", Vector2.ONE)
			return {"scale": base_scale * (1.0 + value * magnitude * 0.01)}
		"angle":
			return {"rotation": base_rot + offset * 0.0174533}
		"opacity":
			var color: Color = base.get("modulate", Color.WHITE)
			color.a = clampf(color.a + value * magnitude * 0.01, 0.0, 1.0)
			return {"modulate": color}
	return {}

# Sine behavior (event-sheet parity): wave-driven oscillation. movement: horizontal, vertical, forwards-backwards, size, angle, opacity, value-only. wave: sine, triangle, sawtooth, reverse-sawtooth, square. Read the current wave via $SineBehavior.wave_value.
