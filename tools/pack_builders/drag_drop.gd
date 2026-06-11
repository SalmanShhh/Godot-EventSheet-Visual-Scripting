# Pack builder — drag_drop (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")

## Drag & Drop behavior (C3 parity)
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "Node2D"
	sheet.custom_class_name = "DragDropBehavior"
	sheet.variables = {
		"grab_radius": {"type": "float", "default": 48.0, "exported": true},
		"axes": {"type": "String", "default": "both", "exported": true, "options": ["both", "horizontal", "vertical"]},
		"dragging": {"type": "bool", "default": false, "exported": false},
		"grab_x": {"type": "float", "default": 0.0, "exported": false},
		"grab_y": {"type": "float", "default": 0.0, "exported": false}
	}
	var about: CommentRow = CommentRow.new()
	about.text = "Drag & Drop behavior (C3 parity): grab within the radius; axes locks dragging to one axis (both, horizontal, vertical). Fires On Drag Start / On Dropped."
	sheet.events.append(about)
	var signal_block: RawCodeRow = RawCodeRow.new()
	signal_block.code = "\n".join(PackedStringArray([
		"## @ace_trigger",
		"## @ace_name(\"On Drag Start\")",
		"## @ace_category(\"Drag & Drop\")",
		"signal drag_started",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Dropped\")",
		"## @ace_category(\"Drag & Drop\")",
		"signal dropped"
	]))
	sheet.events.append(signal_block)
	var tick: EventRow = EventRow.new()
	tick.trigger_provider_id = "Core"
	tick.trigger_id = "OnProcess"
	var tick_body: RawCodeRow = RawCodeRow.new()
	tick_body.code = "\n".join(PackedStringArray([
		"if host == null:",
		"\treturn",
		"if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):",
		"\tvar mouse := host.get_global_mouse_position()",
		"\tif not dragging and mouse.distance_to(host.global_position) <= grab_radius:",
		"\t\tdragging = true",
		"\t\tgrab_x = host.global_position.x",
		"\t\tgrab_y = host.global_position.y",
		"\t\tdrag_started.emit()",
		"\tif dragging:",
		"\t\tvar destination := mouse",
		"\t\tif axes == \"horizontal\":",
		"\t\t\tdestination.y = grab_y",
		"\t\telif axes == \"vertical\":",
		"\t\t\tdestination.x = grab_x",
		"\t\thost.global_position = destination",
		"elif dragging:",
		"\tdragging = false",
		"\tdropped.emit()"
	]))
	tick.actions.append(tick_body)
	sheet.events.append(tick)

	var drop_now_fn: EventFunction = EventFunction.new()
	drop_now_fn.function_name = "drop_now"
	drop_now_fn.expose_as_ace = true
	drop_now_fn.ace_display_name = "Drop Now"
	drop_now_fn.ace_category = "Drag & Drop"
	drop_now_fn.description = "Releases the drag immediately."
	var drop_now_fn_body: RawCodeRow = RawCodeRow.new()
	drop_now_fn_body.code = "\n".join(PackedStringArray([
		"if dragging:",
		"\tdragging = false",
		"\tdropped.emit()"
	]))
	drop_now_fn.events.append(drop_now_fn_body)
	sheet.functions.append(drop_now_fn)

	return Lib.save_pack(sheet, "res://eventsheet_addons/drag_drop/drag_drop_behavior")
