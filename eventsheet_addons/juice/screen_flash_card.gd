@icon("res://eventsheet_addons/juice/icon.svg")
class_name ScreenFlashCard
extends JuiceCard
## Flashes the whole screen a colour.

## The colour to flash.
@export var colour: Color = Color(1.0, 1.0, 1.0, 1.0)
## How long the flash lasts.
@export_range(0.0, 2.0, 0.01) var seconds: float = 0.1

## The layer the flash is drawn on while it lasts, so stop can take it away.
var _layer: CanvasLayer = null

func play(target: Node, strength: float) -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	var flash: ColorRect = ColorRect.new()
	flash.color = Color(colour, clampf(strength, 0.0, 1.0))
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(flash)
	target.add_child(layer)
	_layer = layer
	await target.get_tree().create_timer(seconds).timeout
	if is_instance_valid(layer):
		layer.queue_free()

func length() -> float:
	return seconds

func stop() -> void:
	if _layer != null and is_instance_valid(_layer):
		_layer.queue_free()
