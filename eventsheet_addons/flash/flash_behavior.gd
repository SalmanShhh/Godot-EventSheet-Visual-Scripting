## @ace_category("Flash")
@icon("res://eventsheet_addons/behavior.svg")
class_name FlashBehavior
extends Node

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

var accumulator: float = 0.0
var flashing: bool = false
@export var interval: float = 0.1
var remaining: float = 0.0

func _process(delta: float) -> void:
	if flashing and is_instance_valid(host):
		remaining += -delta
		accumulator += delta
		if accumulator >= interval:
			accumulator = 0.0
			host.visible = not host.visible
		if remaining <= 0.0:
			flashing = false
			host.visible = true
			flash_finished.emit()

## @ace_action
## @ace_name("Flash")
## @ace_category("Flash")
## @ace_description("Blinks the host for the given number of seconds.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$FlashBehavior.flash({seconds})")
func flash(seconds: float) -> void:
	remaining = seconds
	accumulator = 0.0
	flashing = true

## @ace_action
## @ace_name("Stop Flash")
## @ace_category("Flash")
## @ace_description("Stops flashing and restores visibility.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$FlashBehavior.stop_flash()")
func stop_flash() -> void:
	flashing = false
	if is_instance_valid(host):
		host.visible = true

# Flash behavior (event-sheet-style): blinks the host's visibility for a duration, then restores it and fires On Flash Finished.
