# Pack builder — flash (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")

## C3 "Flash" behavior: toggles host visibility at an interval for a duration.
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "CanvasItem"
	sheet.custom_class_name = "FlashBehavior"
	sheet.variables = {
		"interval": {"type": "float", "default": 0.1, "exported": true},
		"remaining": {"type": "float", "default": 0.0, "exported": false},
		"accumulator": {"type": "float", "default": 0.0, "exported": false},
		"flashing": {"type": "bool", "default": false, "exported": false}
	}
	var about: CommentRow = CommentRow.new()
	about.text = "Flash behavior (C3-style): blinks the host's visibility for a duration, then restores it and fires On Flash Finished."
	sheet.events.append(about)
	var signal_block: RawCodeRow = RawCodeRow.new()
	signal_block.code = "## @ace_trigger\n## @ace_name(\"On Flash Finished\")\n## @ace_category(\"Flash\")\nsignal flash_finished"
	sheet.events.append(signal_block)
	var tick: EventRow = EventRow.new()
	tick.trigger_provider_id = "Core"
	tick.trigger_id = "OnProcess"
	var blink: RawCodeRow = RawCodeRow.new()
	blink.code = "\n".join(PackedStringArray([
		"if not flashing or host == null:",
		"\treturn",
		"remaining -= delta",
		"accumulator += delta",
		"if accumulator >= interval:",
		"\taccumulator = 0.0",
		"\thost.visible = not host.visible",
		"if remaining <= 0.0:",
		"\tflashing = false",
		"\thost.visible = true",
		"\tflash_finished.emit()"
	]))
	tick.actions.append(blink)
	sheet.events.append(tick)

	var flash: EventFunction = EventFunction.new()
	flash.function_name = "flash"
	flash.expose_as_ace = true
	flash.ace_display_name = "Flash"
	flash.ace_category = "Flash"
	flash.description = "Blinks the host for the given number of seconds."
	var flash_seconds: ACEParam = ACEParam.new()
	flash_seconds.id = "seconds"
	flash_seconds.type_name = "float"
	flash.params.append(flash_seconds)
	var flash_body: RawCodeRow = RawCodeRow.new()
	flash_body.code = "remaining = seconds\naccumulator = 0.0\nflashing = true"
	flash.events.append(flash_body)
	sheet.functions.append(flash)

	var stop_flash: EventFunction = EventFunction.new()
	stop_flash.function_name = "stop_flash"
	stop_flash.expose_as_ace = true
	stop_flash.ace_display_name = "Stop Flash"
	stop_flash.ace_category = "Flash"
	stop_flash.description = "Stops flashing and restores visibility."
	var stop_flash_body: RawCodeRow = RawCodeRow.new()
	stop_flash_body.code = "flashing = false\nif host != null:\n\thost.visible = true"
	stop_flash.events.append(stop_flash_body)
	sheet.functions.append(stop_flash)
	return Lib.save_pack(sheet, "res://eventsheet_addons/flash/flash_behavior")
