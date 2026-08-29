## @ace_category("Flash")
## @ace_expose_all(node)
## @ace_version(1.0.0)
@icon("res://eventsheet_addons/flash/icon.svg")
class_name FlashBehavior
extends Node
## Blinks the host node's visibility on and off for a duration, then snaps it back to fully visible and fires On Flash Finished. The classic damage-flicker and invincibility-frames effect, with a single interval knob you can change live.

## The node this behavior acts on (its parent). Required host: CanvasItem.
var host: CanvasItem = null

func _enter_tree() -> void:
	host = get_parent() as CanvasItem
	if host == null:
		push_warning("FlashBehavior behavior requires a CanvasItem parent.")

## @ace_trigger
## @ace_name("On Flash Finished")
## @ace_category("Flash")
signal flash_finished

## Seconds between visibility toggles - smaller values blink faster.
@export var interval: float = 0.1
var remaining: float = 0.0
var accumulator: float = 0.0
var flashing: bool = false

func _ready() -> void:
	set_process(false)

func _process(delta: float) -> void:
	if flashing and is_instance_valid(host):
		remaining += -delta
		accumulator += delta
		if accumulator >= interval:
			accumulator = 0.0
			if bool(Engine.get_meta("no_flashing", false)):
				host.visible = true
				host.modulate.a = 1.0 if host.modulate.a < 0.7 else 0.35
			else:
				host.visible = not host.visible
		if remaining <= 0.0:
			flashing = false
			host.visible = true
			host.modulate.a = 1.0
			set_process(false)
			flash_finished.emit()

## @ace_action
## @ace_name("Flash")
## @ace_category("Flash")
## @ace_description("Blinks the host for the given number of seconds.")
## @ace_icon("res://eventsheet_addons/flash/icon.svg")
## @ace_codegen_template("$FlashBehavior.flash({seconds})")
func flash(seconds: float) -> void:
	remaining = seconds
	accumulator = 0.0
	flashing = true
	set_process(true)

## @ace_action
## @ace_name("Stop Flash")
## @ace_category("Flash")
## @ace_description("Stops flashing and restores visibility.")
## @ace_icon("res://eventsheet_addons/flash/icon.svg")
## @ace_codegen_template("$FlashBehavior.stop_flash()")
func stop_flash() -> void:
	flashing = false
	set_process(false)
	if is_instance_valid(host):
		host.visible = true

# Flash behavior (event-sheet-style): blinks the host's visibility for a duration, then restores it and fires On Flash Finished.
