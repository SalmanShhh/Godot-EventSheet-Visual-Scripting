# Pack builder - light_pulse (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## Light Pulse: a beacon breathing, as a behaviour. Same host as Light Flicker beside it and the same
## two rows, but the shape is a smooth wave on a clock rather than a walk on a noise field - a
## lighthouse, a health pickup, a magic door, anything that should read as deliberate rather than as
## alight. Period is the length of one whole breath, so a designer sets a rhythm rather than a speed.
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	# Any light, either dimension - see the binding block, which asks the host which property it
	# spells brightness with rather than naming a light class here.
	sheet.host_class = "Node"
	sheet.custom_class_name = "LightPulseBehavior"
	sheet.class_description = "Makes a light breathe. Attach it to any light, 2D or 3D, and its brightness rides a smooth wave between two numbers - a beacon, a pickup, a rune that should read as deliberate rather than as merely alight. Between and Period Seconds are tuned in the Inspector while the game runs; the sheet says when it starts and when it stops, and what it settles at."
	sheet.addon_category = "Light Pulse"
	sheet.addon_tags = PackedStringArray(["lighting", "juice", "visual"])
	# Every verb here is annotated, so `node` mode adds no vocabulary - what it adds is the CALL:
	# a method's code is synthesized as `$Class.method(...)` (retargetable) only in this mode, and
	# a member whose annotation block keeps it verbatim gets no template written for it otherwise.
	sheet.ace_expose_all_mode = "node"
	var about: CommentRow = CommentRow.new()
	about.text = "Light Pulse: put this under any light and its brightness rides a smooth wave between two numbers. Start Pulsing and Stop Pulsing are the two rows a sheet needs - one takes a delay, the other the brightness to settle at. Between and Period Seconds are Inspector knobs. This pack is an event sheet - extend it by editing it."
	sheet.events.append(about)

	# Written here rather than through sheet.variables so the Vector2 literal lands exactly as typed
	# (a Vector2 stores float32, and a real one handed to the compiler re-emits its rounding). They
	# still open as variable rows - the importer lifts every `@export var` line into one.
	var block: RawCodeRow = RawCodeRow.new()
	var lines: PackedStringArray = PackedStringArray([
		"## The dimmest and brightest the light gets, as a pair. The wave spends most of its time",
		"## near the middle of the two and only touches the ends.",
		"@export var between: Vector2 = Vector2(0.6, 1.4)",
		"## How long one whole breath takes - dim to bright and back again. Two seconds reads as calm;",
		"## a quarter of a second reads as an alarm.",
		"@export_range(0.05, 60, 0.05) var period_seconds: float = 2.0",
		"## Whether the pulse is running right now. On means it starts breathing the moment the scene",
		"## does.",
		"@export var running: bool = true:",
		"\tset(value):",
		"\t\trunning = value",
		"\t\t# Every write lands here - a sheet's Set Running action, the Inspector, another script -",
		"\t\t# so processing follows the breath whoever switched it. A delay still counts down per",
		"\t\t# frame, which is why waiting counts as running here.",
		"\t\tset_process(value or _waiting > 0.0)",
		""
	])
	# No reach knob: a breath is a brightness effect here, so the binding block comes without the
	# reach half rather than with plumbing this pack never runs.
	lines.append_array(Lib.light_binding_lines())
	lines.append_array(PackedStringArray([
		"",
		"## How far into the current breath we are, in seconds. Kept rather than read off the game",
		"## clock so that stopping and starting again resumes from where the wave was, and so that",
		"## changing Period Seconds mid-breath does not snap the light.",
		"var _breath: float = 0.0",
		"## Seconds still to wait before Start Pulsing takes effect, for the row that says \"after\".",
		"var _waiting: float = 0.0",
		"",
		"## Starts the pulse, either now or after a delay - the delay is what a row uses when a beacon",
		"## should come up a moment after the thing that switched it on.",
		"## @ace_action",
		"## @ace_featured",
		"## @ace_name(\"Start Pulsing\")",
		"## @ace_display_template(\"Start pulsing after [b]{after_seconds}[/b] s\")",
		"func start_pulsing(after_seconds: float = 0.0) -> void:",
		"\t_waiting = maxf(after_seconds, 0.0)",
		"\trunning = _waiting <= 0.0",
		"\t# A delayed start still counts its delay down per frame - waiting is not idle.",
		"\tset_process(true)",
		"",
		"## Stops the pulse and leaves the light at one steady brightness - the number the row names.",
		"## @ace_action",
		"## @ace_name(\"Stop Pulsing\")",
		"## @ace_display_template(\"Stop pulsing and settle at [b]{settle_at}[/b]\")",
		"func stop_pulsing(settle_at: float = 1.0) -> void:",
		"\trunning = false",
		"\t_waiting = 0.0",
		"\t# A stopped beacon costs nothing per frame; Start Pulsing turns processing back on.",
		"\tset_process(false)",
		"\tif host == null or _brightness_property.is_empty():",
		"\t\treturn",
		"\t_apply_light(settle_at)",
		"",
		"## True while the light is actually pulsing - false while it waits out a delay, and false",
		"## once it has been stopped.",
		"## @ace_condition",
		"## @ace_name(\"Is Pulsing\")",
		"func is_pulsing() -> bool:",
		"\treturn running and _waiting <= 0.0"
	]))
	block.code = "\n".join(lines)
	sheet.events.append(block)

	var ready_row: EventRow = EventRow.new()
	ready_row.trigger_provider_id = "Core"
	ready_row.trigger_id = "OnReady"
	var ready_body: RawCodeRow = RawCodeRow.new()
	ready_body.code = "\n".join(PackedStringArray([
		"if not _bind_to_light():",
		"\tpush_warning(\"Light Pulse needs a light for a parent - a PointLight2D, an OmniLight3D, or any other light node.\")",
		"\t# No light to drive means no frame will ever have work; stop paying for the tick at all.",
		"\tset_process(false)",
		"\treturn",
		"# Processing runs only while the breath does - a pulse authored as stopped costs nothing",
		"# until Start Pulsing.",
		"set_process(running)"
	]))
	ready_row.actions.append(ready_body)
	sheet.events.append(ready_row)

	var tick: EventRow = EventRow.new()
	tick.trigger_provider_id = "Core"
	tick.trigger_id = "OnProcess"
	var tick_body: RawCodeRow = RawCodeRow.new()
	tick_body.code = "\n".join(PackedStringArray([
		"if host == null or _brightness_property.is_empty():",
		"\treturn",
		"if _waiting > 0.0:",
		"\t_waiting = maxf(_waiting - delta, 0.0)",
		"\trunning = _waiting <= 0.0",
		"\treturn",
		"if not running:",
		"\treturn",
		"_breath = fposmod(_breath + delta, maxf(period_seconds, 0.001))",
		"# A cosine, not a sine: a breath should START at the dim end rather than halfway up it, so",
		"# a light that begins pulsing does not jump on its first frame.",
		"var wave: float = (1.0 - cos(TAU * _breath / maxf(period_seconds, 0.001))) * 0.5",
		"_apply_light(lerpf(between.x, between.y, wave))"
	]))
	tick.actions.append(tick_body)
	sheet.events.append(tick)

	return Lib.save_pack(sheet, "res://eventsheet_addons/light_pulse/light_pulse_behavior")
