# Pack builder - juice_screen_flash_card (the example card of your own, written as an event sheet; run via build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## ScreenFlashCard: the example a card of your own is copied from.
##
## It is a Custom Resource sheet that extends JuiceCard, so the file it writes is the same plain script a
## person would write by hand: two exports for the card's fields, a `play` that flashes the whole screen, and a
## `length` so a Hold card can wait for it. It lists itself in the Add card box under "Yours" and is in no way
## special: delete the file and the card is gone, copy it and rename the class to make another.
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "JuiceCard"
	sheet.custom_class_name = "ScreenFlashCard"
	sheet.class_description = "Flashes the whole screen a colour."
	sheet.variables = {
		"colour": {"type": "Color", "default": Color(1.0, 1.0, 1.0, 1.0), "exported": true,
			"attributes": {"tooltip": "The colour to flash."}},
		"seconds": {"type": "float", "default": 0.1, "exported": true,
			"attributes": {"tooltip": "How long the flash lasts.", "range": {"min": "0.0", "max": "2.0", "step": "0.01"}}}
	}
	sheet.functions.append(_function("play", [["target", "Node"], ["strength", "float"]], "\n".join(PackedStringArray([
		"var layer: CanvasLayer = CanvasLayer.new()",
		"var flash: ColorRect = ColorRect.new()",
		"flash.color = Color(colour, clampf(strength, 0.0, 1.0))",
		"flash.set_anchors_preset(Control.PRESET_FULL_RECT)",
		"layer.add_child(flash)",
		"target.add_child(layer)",
		"_layer = layer",
		"await target.get_tree().create_timer(seconds).timeout",
		"if is_instance_valid(layer):",
		"\tlayer.queue_free()"
	])), TYPE_NIL))
	sheet.functions.append(_function("length", [], "return seconds", TYPE_FLOAT))
	sheet.functions.append(_function("stop", [], "if _layer != null and is_instance_valid(_layer):\n\t_layer.queue_free()", TYPE_NIL))
	var layer_line: RawCodeRow = RawCodeRow.new()
	layer_line.code = "## The layer the flash is drawn on while it lasts, so stop can take it away.\nvar _layer: CanvasLayer = null"
	sheet.events.append(layer_line)
	return Lib.save_pack(sheet, "res://eventsheet_addons/juice/screen_flash_card", Lib.BEHAVIOR_ICON, false)


## One plain function of the card: not a row the picker offers, only a method of the script, written with no
## annotation so the file reads as the script a person would write by hand.
static func _function(function_name: String, params: Array, body: String, return_type: int) -> EventFunction:
	var made: EventFunction = EventFunction.new()
	made.function_name = function_name
	made.expose_as_ace = false
	made.lifted_unannotated = true
	made.return_type = return_type
	for pair: Array in params:
		var parameter: ACEParam = ACEParam.new()
		parameter.id = str(pair[0])
		parameter.type_name = str(pair[1])
		made.params.append(parameter)
	var row: RawCodeRow = RawCodeRow.new()
	row.code = body
	made.events.append(row)
	return made
