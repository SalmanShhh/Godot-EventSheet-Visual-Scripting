# Pack builder - light_flicker (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## Light Flicker: a flame, as a behaviour rather than as thirty lines of noise-and-lerp on a sheet.
## Attach it to any light - 2D or 3D - and it walks the light's brightness between two numbers on a
## noise field, which is what makes a flame look like a flame instead of like static. The four
## numbers a designer actually tunes live in the Inspector, so a flame can be dialled in while the
## game runs; the sheet keeps the two moments a game cares about - start and stop.
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	# Any light, either dimension. Light2D and Light3D share no ancestor below Node, and the pack
	# resolves which brightness property its host really has when it starts (see the binding block).
	sheet.host_class = "Node"
	sheet.custom_class_name = "LightFlickerBehavior"
	sheet.class_description = "Makes a light flicker like a flame. Attach it to any light, 2D or 3D, and its brightness walks between two numbers on a noise field - related from frame to frame, which is what reads as fire rather than as static. Between, Times A Second and Also Flicker Reach are tuned in the Inspector while the game runs; the sheet says when it starts and when it stops, and what it settles at."
	sheet.addon_category = "Light Flicker"
	sheet.addon_tags = PackedStringArray(["lighting", "juice", "visual"])
	# Every verb here is annotated, so `node` mode adds no vocabulary - what it adds is the CALL:
	# a method's code is synthesized as `$Class.method(...)` (retargetable) only in this mode, and
	# a member whose annotation block keeps it verbatim gets no template written for it otherwise.
	sheet.ace_expose_all_mode = "node"
	var about: CommentRow = CommentRow.new()
	about.text = "Light Flicker: put this under any light and its brightness walks between two numbers on a noise field. Start Flickering and Stop Flickering are the two rows a sheet needs - one takes a delay, the other the brightness to settle at. Between, Times A Second and Also Flicker Reach are Inspector knobs. This pack is an event sheet - extend it by editing it."
	sheet.events.append(about)

	# The knobs are written here rather than through sheet.variables so their literals land exactly
	# as typed: a Vector2 stores float32, so a default handed to the compiler as a real Vector2
	# re-emits as Vector2(0.80000001192093, 1.20000004768372). They still open as variable rows -
	# the importer lifts every `@export var` line into one.
	var block: RawCodeRow = RawCodeRow.new()
	var lines: PackedStringArray = PackedStringArray([
		"## The dimmest and brightest the light gets, as a pair. 0.8 and 1.2 is a candle; 0.2 and 1.4",
		"## is a failing bulb.",
		"@export var between: Vector2 = Vector2(0.8, 1.2)",
		"## How fast the flame moves. About 12 reads as a torch; below 3 reads as a slow breathing",
		"## glow, and above 30 as an electrical fault.",
		"@export_range(0.1, 60, 0.1) var times_a_second: float = 12.0",
		"## Also breathe the light's reach in and out with its brightness, which is what a real flame",
		"## does. A directional light has no reach and ignores this.",
		"@export var also_flicker_reach: bool = false",
		"## Whether the flicker is running right now. On means it starts flickering the moment the",
		"## scene does.",
		"@export var running: bool = true:",
		"\tset(value):",
		"\t\trunning = value",
		"\t\t# Every write lands here - a sheet's Set Running action, the Inspector, another script -",
		"\t\t# so processing follows the flame whoever switched it. A delay still counts down per",
		"\t\t# frame, which is why waiting counts as running here.",
		"\t\tset_process(value or _waiting > 0.0)",
		""
	])
	# The flame is the one of the two light packs that scales reach, so its binding block gets the
	# reach half - and the knob that says whether this flame is using it.
	lines.append_array(Lib.light_binding_lines("also_flicker_reach"))
	lines.append_array(PackedStringArray([
		"",
		"## The noise field the flame is sampled from, and how far along it we are. NOISE, not a fresh",
		"## random number per frame: consecutive samples of a noise field are RELATED, so the light",
		"## wanders the way a flame does. Independent random numbers read as static instead.",
		"var _flame: FastNoiseLite = null",
		"var _walked: float = 0.0",
		"## Seconds still to wait before Start Flickering takes effect, for the row that says \"after\".",
		"var _waiting: float = 0.0",
		"",
		"## Starts the flicker, either now or after a delay. The delay is what a row uses when a torch",
		"## should catch a moment after the thing that lit it.",
		"## @ace_action",
		"## @ace_featured",
		"## @ace_name(\"Start Flickering\")",
		"## @ace_display_template(\"Start flickering after [b]{after_seconds}[/b] s\")",
		# The two lines somebody who wired this flame by hand actually wrote: with a delay and
		# without one. Both read as the generic \"call a method\" row until the pack says otherwise,
		# and saying so upgrades them to this verb without moving a byte of their file.
		"## @ace_lift_example(\"[[target|node: $LightFlickerBehavior]].start_flickering([[after_seconds|argument: 0.5]])\")",
		"## @ace_lift_example(\"[[target|node: $LightFlickerBehavior]].start_flickering()\")",
		"func start_flickering(after_seconds: float = 0.0) -> void:",
		"\t_waiting = maxf(after_seconds, 0.0)",
		"\trunning = _waiting <= 0.0",
		"\t# A delayed start still counts its delay down per frame - waiting is not idle.",
		"\tset_process(true)",
		"",
		"## Stops the flicker and leaves the light at one steady brightness - the number the row",
		"## names, so a torch that goes out settles dark and one that is merely calmed settles lit.",
		"## A flame that was flickering its reach puts that back to whatever the scene was authored",
		"## with, rather than leaving the radius of the frame it stopped on.",
		"## @ace_action",
		"## @ace_name(\"Stop Flickering\")",
		"## @ace_display_template(\"Stop flickering and settle at [b]{settle_at}[/b]\")",
		"## @ace_lift_example(\"[[target|node: $LightFlickerBehavior]].stop_flickering([[settle_at|argument: 1.0]])\")",
		"## @ace_lift_example(\"[[target|node: $LightFlickerBehavior]].stop_flickering()\")",
		"func stop_flickering(settle_at: float = 1.0) -> void:",
		"\trunning = false",
		"\t_waiting = 0.0",
		"\t# A stopped flame costs nothing per frame; Start Flickering turns processing back on.",
		"\tset_process(false)",
		"\tif host == null or _brightness_property.is_empty():",
		"\t\treturn",
		"\t_apply_light(settle_at, 1.0)",
		"",
		"## True while the light is actually flickering - false while it waits out a delay, and false",
		"## once it has been stopped.",
		"## @ace_condition",
		"## @ace_name(\"Is Flickering\")",
		"func is_flickering() -> bool:",
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
		"\tpush_warning(\"Light Flicker needs a light for a parent - a PointLight2D, an OmniLight3D, or any other light node.\")",
		"\t# No light to drive means no frame will ever have work; stop paying for the tick at all.",
		"\tset_process(false)",
		"\treturn",
		"_flame = FastNoiseLite.new()",
		"# A seed per instance, so two torches in one room never flicker in step.",
		"_flame.seed = randi()",
		"_flame.frequency = 0.06",
		"# Processing runs only while the flame does - a flicker authored as stopped costs nothing",
		"# until Start Flickering.",
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
		"_walked += delta * times_a_second",
		"# Noise runs -1 to 1; the flame wants 0 to 1 so it can be read as a distance between the",
		"# two numbers the Inspector holds.",
		"var flame: float = (_flame.get_noise_1d(_walked) + 1.0) * 0.5",
		"# A real flame's light shrinks as it dims, so reach follows brightness rather than running",
		"# on a clock of its own - but only within a tenth either way, because a light whose radius",
		"# jumps is a light that pops.",
		"var reach_scale: float = lerpf(0.92, 1.08, flame) if also_flicker_reach else 1.0",
		"_apply_light(lerpf(between.x, between.y, flame), reach_scale)"
	]))
	tick.actions.append(tick_body)
	sheet.events.append(tick)

	return Lib.save_pack(sheet, "res://eventsheet_addons/light_flicker/light_flicker_behavior")
