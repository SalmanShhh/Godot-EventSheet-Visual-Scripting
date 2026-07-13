## @ace_category("Sine 3D")
## @ace_expose_all(node)
@icon("res://eventsheet_addons/behavior.svg")
class_name Sine3DBehavior
extends Node

## The node this behavior acts on (its parent). Required host: Node3D.
var host: Node3D = null

func _enter_tree() -> void:
	host = get_parent() as Node3D
	if host == null:
		push_warning("Sine3DBehavior behavior requires a Node3D parent.")

## When on the oscillation runs; turn off to freeze the host.
@export var active: bool = true
var base_captured: bool = false
var base_rot_y: float = 0.0
var base_x: float = 0.0
var base_y: float = 0.0
var base_z: float = 0.0
## Peak offset from the start position (degrees for rotation-y).
@export var magnitude: float = 2.0
## Which axis the host oscillates on - x, y, z position or rotation around Y.
@export_enum("x", "y", "z", "rotation-y") var movement: String = "y"
## Seconds the wave takes to complete one full cycle.
@export var period: float = 4.0
## Starting offset into the wave cycle, in degrees.
@export var phase_degrees: float = 0.0
var time: float = 0.0
## The waveform shape used for the oscillation.
@export_enum("sine", "triangle", "sawtooth", "reverse-sawtooth", "square") var wave: String = "sine"

func _process(delta: float) -> void:
	if not active or host == null:
		return
	if not base_captured:
		base_x = host.position.x
		base_y = host.position.y
		base_z = host.position.z
		base_rot_y = host.rotation.y
		base_captured = true
	time += delta
	var t := time / maxf(period, 0.001) + phase_degrees / 360.0
	var offset := _wave(t) * magnitude
	if movement == "x":
		host.position.x = base_x + offset
	elif movement == "y":
		host.position.y = base_y + offset
	elif movement == "z":
		host.position.z = base_z + offset
	elif movement == "rotation-y":
		host.rotation.y = base_rot_y + offset * 0.0174533

## @ace_action
## @ace_name("Set Sine 3D Active")
## @ace_category("Sine 3D")
## @ace_description("Pauses or resumes the oscillation.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$Sine3DBehavior.set_sine3d_active({is_active})")
func set_sine3d_active(is_active: bool) -> void:
	active = is_active

## @ace_action
## @ace_name("Set Phase")
## @ace_category("Sine 3D")
## @ace_description("Phase offset in degrees.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$Sine3DBehavior.set_sine3d_phase({degrees})")
func set_sine3d_phase(degrees: float) -> void:
	phase_degrees = degrees

## @ace_action
## @ace_name("Reset Sine 3D")
## @ace_category("Sine 3D")
## @ace_description("Restarts the wave from the current state.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$Sine3DBehavior.reset_sine3d()")
func reset_sine3d() -> void:
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

# Sine 3D behavior (event-sheet-style): oscillates the host along an axis (x, y, z) or around the Y axis (rotation-y), with the full wave set.
