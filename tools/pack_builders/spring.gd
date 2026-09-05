# Pack builder - spring (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## Numeric springing (cleaned-up port of the author's simple_spring addon): NAMED
## springs (value/target/velocity each) driven by stiffness + damping + precision, with
## impulses, reached-triggers and host-transform conveniences. Mesh deformation from the
## original is an honest skip (that's shader/skeleton territory in Godot). Exported
## properties showcase Inspector attributes (ranges + tooltips) in a shipped pack.
## Backed by typed inner classes (SpringEntry / ColorSpringEntry) so the hot integrator
## reads typed fields instead of float()-casting an untyped Dictionary every spring, every frame.
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "Node2D"
	sheet.custom_class_name = "SpringBehavior"
	sheet.class_description = "A bank of named springs on a Node2D: numbers that chase a target with real velocity, overshoot, and settle instead of snapping. One-line helpers spring the host's position, angle, and scale, so squash-and-stretch juice is a single row."
	sheet.addon_category = "Spring"
	sheet.ace_expose_all_mode = "node"
	sheet.addon_tags = PackedStringArray(["motion", "juice"])
	sheet.variables = {
		"default_stiffness": {"type": "float", "default": 170.0, "exported": true,
			"attributes": {"tooltip": "Spring force toward the target (higher = snappier).", "range": {"min": "1", "max": "1000", "step": "1"}}},
		"default_damping": {"type": "float", "default": 0.85, "exported": true,
			"attributes": {"tooltip": "0 = oscillate forever, 1 = no overshoot.", "range": {"min": "0", "max": "1", "step": "0.01"}}},
		"default_precision": {"type": "float", "default": 0.01, "exported": true,
			"attributes": {"tooltip": "Distance + speed below which a spring counts as settled."}},
		"springs": {"type": "Dictionary", "default": {}, "exported": false},
		"color_springs": {"type": "Dictionary", "default": {}, "exported": false},
		"property_springs": {"type": "Dictionary", "default": {}, "exported": false}
	}
	var about: CommentRow = CommentRow.new()
	about.text = "Numeric springing: snappy, physical motion for ANY number. Name a spring, set its target, read its value - or use the host helpers (x/y/angle/scale) for instant juice."
	sheet.events.append(about)
	var block: RawCodeRow = RawCodeRow.new()
	block.code = "\n".join(PackedStringArray([
		"## The most of a velocity a damping may take away in a second. The decay below is EXPONENTIAL,",
		"## so a damping of exactly 1 leaves nothing of the velocity after any step at all: the spring",
		"## stops dead where it stands, never reaches its target, and never settles - which means the",
		"## per-frame tick never parks either. A thousandth of it left is still heavier damping than any",
		"## motion needs, and it is a spring rather than a freeze.",
		"const DAMPING_CEILING: float = 0.999",
		"",
		"## A single numeric spring's state, integrated each frame (typed - no dict casts in the hot loop).",
		"class SpringEntry:",
		"\tvar value: float = 0.0",
		"\tvar from_value: float = 0.0",
		"\tvar target: float = 0.0",
		"\tvar velocity: float = 0.0",
		"\tvar stiffness: float = 0.0",
		"\tvar damping: float = 0.0",
		"\tvar precision: float = 0.0",
		"\tvar active: bool = false",
		"\t## Semi-implicit, framerate-independent step; returns true on the frame it settles.",
		"\tfunc integrate(delta: float) -> bool:",
		"\t\tvelocity += (target - value) * stiffness * delta",
		"\t\t# Damping is the fraction of velocity LOST PER SECOND (framerate-independent), held under",
		"\t\t# the ceiling so the heaviest damping is still a spring rather than a freeze.",
		"\t\tvelocity *= pow(1.0 - clampf(damping, 0.0, SpringBehavior.DAMPING_CEILING), delta)",
		"\t\tvalue += velocity * delta",
		"\t\tif absf(target - value) < precision and absf(velocity) < precision:",
		"\t\t\tvalue = target",
		"\t\t\tvelocity = 0.0",
		"\t\t\tactive = false",
		"\t\t\treturn true",
		"\t\treturn false",
		"",
		"## A named colour spring (each channel springs component-wise).",
		"class ColorSpringEntry:",
		"\tvar value: Color = Color.WHITE",
		"\tvar target: Color = Color.WHITE",
		"\tvar velocity: Color = Color(0, 0, 0, 0)",
		"\tvar stiffness: float = 0.0",
		"\tvar damping: float = 0.0",
		"\tvar precision: float = 0.0",
		"\tvar active: bool = false",
		"\tfunc integrate(delta: float) -> bool:",
		"\t\tvelocity = velocity + (target - value) * stiffness * delta",
		"\t\tvelocity = velocity * pow(1.0 - clampf(damping, 0.0, SpringBehavior.DAMPING_CEILING), delta)",
		"\t\tvalue = value + velocity * delta",
		"\t\tif absf(target.r - value.r) < precision and absf(target.g - value.g) < precision and absf(target.b - value.b) < precision and absf(target.a - value.a) < precision:",
		"\t\t\tvalue = target",
		"\t\t\tvelocity = Color(0, 0, 0, 0)",
		"\t\t\tactive = false",
		"\t\t\treturn true",
		"\t\treturn false",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Spring Reached\")",
		"signal spring_reached(spring_name: String)",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Spring Started\")",
		"signal spring_started(spring_name: String)",
		"",
		"## @ace_expression",
		"## @ace_name(\"Color Value\")",
		"func color_value(spring_name: String) -> Color:",
		"\tif not color_springs.has(spring_name):",
		"\t\treturn Color.WHITE",
		"\treturn (color_springs[spring_name] as ColorSpringEntry).value",
		"",
		"## @ace_condition",
		"## @ace_name(\"Is Springing\")",
		"func is_springing(spring_name: String) -> bool:",
		"\treturn springs.has(spring_name) and (springs[spring_name] as SpringEntry).active",
		"",
		"## @ace_expression",
		"## @ace_name(\"Spring Value\")",
		"func spring_value(spring_name: String) -> float:",
		"\tif not springs.has(spring_name):",
		"\t\treturn 0.0",
		"\treturn (springs[spring_name] as SpringEntry).value",
		"",
		"## @ace_expression",
		"## @ace_name(\"Spring Velocity\")",
		"func spring_velocity(spring_name: String) -> float:",
		"\tif not springs.has(spring_name):",
		"\t\treturn 0.0",
		"\treturn (springs[spring_name] as SpringEntry).velocity",
		"",
		"## @ace_expression",
		"## @ace_name(\"Spring Progress\")",
		"func spring_progress(spring_name: String) -> float:",
		"\tif not springs.has(spring_name):",
		"\t\treturn 1.0",
		"\tvar entry: SpringEntry = springs[spring_name]",
		"\tvar span: float = absf(entry.target - entry.from_value)",
		"\tif span <= 0.0:",
		"\t\treturn 1.0",
		"\treturn clampf(1.0 - absf(entry.target - entry.value) / span, 0.0, 1.0)",
		"",
		"func _spring_entry(spring_name: String) -> SpringEntry:",
		"\tif not springs.has(spring_name):",
		"\t\tvar entry := SpringEntry.new()",
		"\t\tentry.stiffness = default_stiffness",
		"\t\tentry.damping = default_damping",
		"\t\tentry.precision = default_precision",
		"\t\tsprings[spring_name] = entry",
		"\treturn springs[spring_name]",
		"",
		"func _color_entry(spring_name: String) -> ColorSpringEntry:",
		"\tif not color_springs.has(spring_name):",
		"\t\tvar entry := ColorSpringEntry.new()",
		"\t\tentry.stiffness = default_stiffness",
		"\t\tentry.damping = default_damping",
		"\t\tentry.precision = default_precision",
		"\t\tcolor_springs[spring_name] = entry",
		"\treturn color_springs[spring_name]",
		"",
		"# Host conveniences: springs with these names write straight onto the parent.",
		"func _apply_to_host(spring_name: String, value: float) -> void:",
		"\tif host == null:",
		"\t\treturn",
		"\tmatch spring_name:",
		"\t\t\"__x\": host.position.x = value",
		"\t\t\"__y\": host.position.y = value",
		"\t\t\"__angle\": host.rotation_degrees = value",
		"\t\t\"__scale\": host.scale = Vector2(value, value)"
	]))
	sheet.events.append(block)
	var ready_row: EventRow = EventRow.new()
	ready_row.trigger_provider_id = "Core"
	ready_row.trigger_id = "OnReady"
	var ready_body: RawCodeRow = RawCodeRow.new()
	ready_body.code = "\n".join(PackedStringArray([
		"# An empty bank has nothing to integrate, so it costs no frames until a spring verb",
		"# starts one. Guarded rather than unconditional: a row may already have sprung something",
		"# before this node was readied.",
		"if springs.is_empty() and color_springs.is_empty():",
		"\tset_process(false)"
	]))
	ready_row.actions.append(ready_body)
	# Appended rather than folded into the guard above, so the pack's shipped bytes only ever grow:
	# a spring under a property is a bank of its own, and one started before this node was readied
	# keeps the frames the line above just gave away.
	var ready_properties: RawCodeRow = RawCodeRow.new()
	ready_properties.code = "
".join(PackedStringArray([
		"if not property_springs.is_empty():",
		"	set_process(true)"
	]))
	ready_row.actions.append(ready_properties)
	sheet.events.append(ready_row)
	var tick: EventRow = EventRow.new()
	tick.trigger_provider_id = "Core"
	tick.trigger_id = "OnProcess"
	var simulate: RawCodeRow = RawCodeRow.new()
	simulate.code = "\n".join(PackedStringArray([
		"# Each spring integrates itself (framerate-independent); host springs write to the parent.",
		"for spring_name: Variant in springs.keys():",
		"\tvar entry: SpringEntry = springs[spring_name]",
		"\tif not entry.active:",
		"\t\tcontinue",
		"\tif entry.integrate(delta):",
		"\t\tspring_reached.emit(str(spring_name))",
		"\t_apply_to_host(str(spring_name), entry.value)",
		"# Colour springs integrate identically (Color supports +, - and *float component-wise).",
		"for color_name: Variant in color_springs.keys():",
		"\tvar centry: ColorSpringEntry = color_springs[color_name]",
		"\tif not centry.active:",
		"\t\tcontinue",
		"\tif centry.integrate(delta):",
		"\t\tspring_reached.emit(str(color_name))",
		"# A bank with nothing left to settle costs nothing per frame; every spring verb turns",
		"# processing back on. Re-read after the emits above, so a row that starts a new spring",
		"# from On Spring Reached keeps its frames.",
		"var still_settling: bool = false",
		"for pending: Variant in springs.values():",
		"\tif (pending as SpringEntry).active:",
		"\t\tstill_settling = true",
		"\t\tbreak",
		"if not still_settling:",
		"\tfor color_pending: Variant in color_springs.values():",
		"\t\tif (color_pending as ColorSpringEntry).active:",
		"\t\t\tstill_settling = true",
		"\t\t\tbreak",
		"set_process(still_settling)"
	]))
	tick.actions.append(simulate)
	var simulate_properties: RawCodeRow = RawCodeRow.new()
	simulate_properties.code = "
".join(PackedStringArray([
		"# Springs under a PROPERTY of the host: each writes its own value back where it came from.",
		"# This runs after the named bank above and only ever turns processing back ON, so a property",
		"# spring keeps the frames the named springs just parked.",
		"var property_settling: bool = false",
		"for property_path: Variant in property_springs.keys():",
		"	var property_entry: PropertySpring = property_springs[property_path]",
		"	if not property_entry.active:",
		"		continue",
		"	var landed: bool = property_entry.integrate(delta)",
		"	if host != null:",
		"		host.set_indexed(property_entry.path, property_entry.unpack())",
		"	if landed:",
		"		spring_reached.emit(str(property_path))",
		"	else:",
		"		property_settling = true",
		"if property_settling:",
		"	set_process(true)"
	]))
	tick.actions.append(simulate_properties)
	sheet.events.append(tick)
	var property_block: RawCodeRow = RawCodeRow.new()
	property_block.code = "
".join(_property_spring_lines())
	sheet.events.append(property_block)
	Lib.append_function(sheet, "spring_to", "Spring To", "Spring", "Springs the named value toward a target.",
		[["spring_name", "String"], ["target", "float"]],
		"var entry: SpringEntry = _spring_entry(spring_name)\nvar was_active := entry.active\nentry.from_value = entry.value\nentry.target = target\nentry.active = true\n# A moving spring needs its per-frame integration back.\nset_process(true)\nif not was_active:\n\tspring_started.emit(spring_name)")
	Lib.append_function(sheet, "spring_between", "Spring Between", "Spring", "Snaps to a start value, then springs to the end value.",
		[["spring_name", "String"], ["from_value", "float"], ["to_value", "float"]],
		"var entry: SpringEntry = _spring_entry(spring_name)\nentry.value = from_value\nentry.from_value = from_value\nentry.velocity = 0.0\nentry.target = to_value\nentry.active = true\n# A moving spring needs its per-frame integration back.\nset_process(true)")
	Lib.append_function(sheet, "set_spring", "Set Spring Value", "Spring", "Snaps the named spring (no motion).",
		[["spring_name", "String"], ["value", "float"]],
		"var entry: SpringEntry = _spring_entry(spring_name)\nentry.value = value\nentry.from_value = value\nentry.target = value\nentry.velocity = 0.0\nentry.active = false")
	Lib.append_function(sheet, "add_impulse", "Add Impulse", "Spring", "Kicks the named spring's velocity (instant juice).",
		[["spring_name", "String"], ["amount", "float"]],
		"var entry: SpringEntry = _spring_entry(spring_name)\nentry.velocity += amount\nentry.active = true\n# A moving spring needs its per-frame integration back.\nset_process(true)")
	Lib.append_function(sheet, "stop_spring", "Stop Spring", "Spring", "Freezes the named spring where it is.",
		[["spring_name", "String"]],
		"if springs.has(spring_name):\n\t(springs[spring_name] as SpringEntry).active = false")
	Lib.append_function(sheet, "configure_spring", "Configure Spring", "Spring", "Per-spring stiffness/damping/precision overrides.",
		[["spring_name", "String"], ["stiffness", "float"], ["damping", "float"], ["precision", "float"]],
		"var entry: SpringEntry = _spring_entry(spring_name)\nentry.stiffness = stiffness\nentry.damping = clampf(damping, 0.0, 1.0)\nentry.precision = precision")
	Lib.append_function(sheet, "spring_host_x", "Spring Host X", "Spring", "Springs the host's X position.",
		[["target", "float"]],
		"var entry: SpringEntry = _spring_entry(\"__x\")\nif not entry.active and host != null:\n\tentry.value = host.position.x\nentry.from_value = entry.value\nentry.target = target\nentry.active = true\n# A moving spring needs its per-frame integration back.\nset_process(true)")
	Lib.append_function(sheet, "spring_host_y", "Spring Host Y", "Spring", "Springs the host's Y position.",
		[["target", "float"]],
		"var entry: SpringEntry = _spring_entry(\"__y\")\nif not entry.active and host != null:\n\tentry.value = host.position.y\nentry.from_value = entry.value\nentry.target = target\nentry.active = true\n# A moving spring needs its per-frame integration back.\nset_process(true)")
	Lib.append_function(sheet, "spring_host_angle", "Spring Host Angle", "Spring", "Springs the host's rotation (degrees).",
		[["degrees", "float"]],
		"var entry: SpringEntry = _spring_entry(\"__angle\")\nif not entry.active and host != null:\n\tentry.value = host.rotation_degrees\nentry.from_value = entry.value\nentry.target = degrees\nentry.active = true\n# A moving spring needs its per-frame integration back.\nset_process(true)")
	Lib.append_function(sheet, "spring_host_scale", "Spring Host Scale", "Spring", "Springs the host's uniform scale (squash & stretch!).",
		[["target", "float"]],
		"var entry: SpringEntry = _spring_entry(\"__scale\")\nif not entry.active and host != null:\n\tentry.value = host.scale.x\nentry.from_value = entry.value\nentry.target = target\nentry.active = true\n# A moving spring needs its per-frame integration back.\nset_process(true)")
	Lib.append_function(sheet, "set_color", "Set Color Value", "Spring", "Snaps a named colour spring (no motion) - seed it before springing.",
		[["spring_name", "String"], ["color", "Color"]],
		"var entry: ColorSpringEntry = _color_entry(spring_name)\nentry.value = color\nentry.target = color\nentry.velocity = Color(0, 0, 0, 0)\nentry.active = false")
	Lib.append_function(sheet, "spring_color", "Spring Color", "Spring", "Springs a named colour toward a target (read it back with Color Value - great for hit flashes).",
		[["spring_name", "String"], ["target_color", "Color"]],
		"var entry: ColorSpringEntry = _color_entry(spring_name)\nvar was_active := entry.active\nentry.target = target_color\nentry.active = true\n# A moving spring needs its per-frame integration back.\nset_process(true)\nif not was_active:\n\tspring_started.emit(spring_name)")
	Lib.append_function(sheet, "pause_spring", "Pause Spring", "Spring", "Freezes a spring in place (resume continues it).",
		[["spring_name", "String"]],
		"if springs.has(spring_name):\n\t(springs[spring_name] as SpringEntry).active = false\nif color_springs.has(spring_name):\n\t(color_springs[spring_name] as ColorSpringEntry).active = false")
	Lib.append_function(sheet, "resume_spring", "Resume Spring", "Spring", "Resumes a paused spring toward its target.",
		[["spring_name", "String"]],
		"if springs.has(spring_name):\n\t(springs[spring_name] as SpringEntry).active = true\nif color_springs.has(spring_name):\n\t(color_springs[spring_name] as ColorSpringEntry).active = true\n# A moving spring needs its per-frame integration back.\nset_process(true)")
	Lib.append_function(sheet, "remove_spring", "Remove Spring", "Spring", "Deletes a named spring (numeric and/or colour).",
		[["spring_name", "String"]],
		"springs.erase(spring_name)\ncolor_springs.erase(spring_name)")
	Lib.append_function(sheet, "reset_springs", "Reset All Springs", "Spring", "Clears every spring on this behavior.",
		[],
		"springs.clear()\ncolor_springs.clear()")
	# --- Springs under a property of the host (any number, vector or colour, by path) ---
	Lib.append_function(sheet, "spring_property_to", "Spring Property To", "Spring", "Springs any property of the host toward a value: a number, a Vector2, a Vector3 or a Color, addressed by the same path the Inspector shows. The property's own type is read once, on the first row that springs it, and the spring writes it back every frame until it settles.",
		[["property_path", "String", "The property to spring, as the Inspector spells it: modulate, position, rotation_degrees, scale:x."],
			["target_value", "Variant", "Where it should end up. Give it the same kind of value the property holds."]],
		"var entry: PropertySpring = _property_spring(property_path)\nif not entry.supported:\n\treturn\nentry.target = entry.pack(target_value)\nentry.active = true\n# A moving spring needs its per-frame integration back.\nset_process(true)",
		"Spring [b]{property_path}[/b] to [b]{target_value}[/b]")
	Lib.append_function(sheet, "bump_property", "Bump Property", "Spring", "Kicks a property's spring by an amount and lets it settle back on its own - the fastest juice there is: one row, no duration, nothing to clean up. Bump a field of view on a shot, a light's energy on a hit, a panel's scale on a press.",
		[["property_path", "String", "The property to push, as the Inspector spells it."],
			["amount", "Variant", "How hard the push is, in the property's own units. Negative pushes the other way."]],
		"var entry: PropertySpring = _property_spring(property_path)\nif not entry.supported:\n\treturn\nentry.velocity += entry.pack(amount)\nentry.active = true\n# A moving spring needs its per-frame integration back.\nset_process(true)",
		"Bump [b]{property_path}[/b] by [b]{amount}[/b]")
	Lib.append_function(sheet, "set_property_spring", "Set Spring Damping And Frequency", "Spring", "The two numbers a spring really has: how fast the bounce dies out (0 loose, 1 dead) and how many swings a second it wants. Set them per property, before the motion or during it.",
		[["property_path", "String", "The property whose spring is being tuned."],
			["damping", "float", "0 oscillates for ever, 1 never overshoots."],
			["frequency", "float", "Swings per second - how eager the spring is to get there."]],
		"var entry: PropertySpring = _property_spring(property_path)\nentry.damping = clampf(damping, 0.0, 1.0)\n# Frequency is the swings a second a designer asks for; stiffness is what the integrator wants.\nvar swings: float = maxf(frequency, 0.01) * TAU\nentry.stiffness = swings * swings",
		"Spring [b]{property_path}[/b]: damping [b]{damping}[/b], [b]{frequency}[/b] per second")
	Lib.append_function(sheet, "clamp_property_spring", "Clamp Spring Between", "Spring", "Holds a property's spring between two numbers: it stops dead at the wall instead of pushing through it. A lid that must not pass its hinge, a bar that must not go under zero. The same number on both sides takes the clamp off again.",
		[["property_path", "String", "The property whose spring is being fenced in."],
			["min_value", "float", "The lowest the value may go."],
			["max_value", "float", "The highest the value may go."]],
		"var entry: PropertySpring = _property_spring(property_path)\nentry.min_value = minf(min_value, max_value)\nentry.max_value = maxf(min_value, max_value)\n# One number on both sides is how a row says there is no fence: a spring pinned to a point is not a clamp.\nentry.clamped = not is_equal_approx(min_value, max_value)",
		"Clamp [b]{property_path}[/b] between [b]{min_value}[/b] and [b]{max_value}[/b]")
	Lib.condition(sheet, "property_spring_is_settled", "Spring Is Settled", "Spring", "True while nothing is springing that property - it has arrived, or it was never sprung at all.",
		[["property_path", "String", "The property to ask about."]],
		"if not property_springs.has(property_path):\n\treturn true\nreturn not (property_springs[property_path] as PropertySpring).active")
	Lib.number(sheet, "property_spring_value", "Spring Value Of", "Spring", "What the property's spring reads right now, as a number: the value itself for a number, x for a vector, red for a colour. 0 if nothing has sprung it.",
		[["property_path", "String", "The property to read."]],
		"if not property_springs.has(property_path):\n\treturn 0.0\nreturn (property_springs[property_path] as PropertySpring).value.x", TYPE_FLOAT)
	Lib.number(sheet, "property_spring_velocity", "Spring Velocity Of", "Spring", "How fast the property's spring is moving right now, as a number - drive a lean, a blur or a stretch off it so the motion shows its own speed. 0 if nothing has sprung it.",
		[["property_path", "String", "The property to read."]],
		"if not property_springs.has(property_path):\n\treturn 0.0\nreturn (property_springs[property_path] as PropertySpring).velocity.x", TYPE_FLOAT)
	# The pack's hero verbs: starred + bold at the top of their picker section.
	Lib.verb_sentences(sheet, {
		"add_impulse": "Kick spring [b]{spring_name}[/b] by [b]{amount}[/b]",
		"spring_to": "Spring [b]{spring_name}[/b] to [b]{target}[/b]",
	})
	Lib.feature_verbs(sheet, ["spring_to", "add_impulse"])
	return Lib.save_pack(sheet, "res://eventsheet_addons/spring/spring_behavior")


## Springs under a PROPERTY of the host, the breadth half of the pack: one entry per property, made
## on the first row that names it and reused for the life of the node, so a property bumped every
## frame allocates nothing at all.
##
## The four kinds a property can be - a number, a Vector2, a Vector3 and a Color - are one shape
## here: four floats in a Vector4, of which the entry remembers how many count and what to hand
## back. A Vector4 is a value rather than an object, so the hot loop touches no heap.
static func _property_spring_lines() -> PackedStringArray:
	return PackedStringArray([
		"## One property of the host, springing. `path` is resolved once, when the first row names the",
		"## property, and the type it holds then is the type it is written back as.",
		"class PropertySpring:",
		"\tvar path: NodePath = NodePath(\"\")",
		"\t## How many of the four floats below this property actually uses.",
		"\tvar components: int = 1",
		"\t## The Variant type the property held when it was first sprung.",
		"\tvar kind: int = TYPE_FLOAT",
		"\t## False when the property is missing, or holds something no spring can move.",
		"\tvar supported: bool = false",
		"\tvar value: Vector4 = Vector4.ZERO",
		"\tvar target: Vector4 = Vector4.ZERO",
		"\tvar velocity: Vector4 = Vector4.ZERO",
		"\tvar stiffness: float = 0.0",
		"\tvar damping: float = 0.0",
		"\tvar precision: float = 0.0",
		"\tvar min_value: float = 0.0",
		"\tvar max_value: float = 0.0",
		"\tvar clamped: bool = false",
		"\tvar active: bool = false",
		"\t## Reads the property's own type once, and starts the spring at rest on what it holds.",
		"\tfunc adopt(current: Variant) -> void:",
		"\t\tkind = typeof(current)",
		"\t\tmatch kind:",
		"\t\t\tTYPE_VECTOR2:",
		"\t\t\t\tcomponents = 2",
		"\t\t\tTYPE_VECTOR3:",
		"\t\t\t\tcomponents = 3",
		"\t\t\tTYPE_COLOR:",
		"\t\t\t\tcomponents = 4",
		"\t\t\tTYPE_FLOAT, TYPE_INT:",
		"\t\t\t\tcomponents = 1",
		"\t\t\t_:",
		"\t\t\t\tsupported = false",
		"\t\t\t\treturn",
		"\t\tsupported = true",
		"\t\tvalue = pack(current)",
		"\t\ttarget = value",
		"\t## Any of the four kinds as four floats. What a kind does not use stays 0.",
		"\tfunc pack(from_value: Variant) -> Vector4:",
		"\t\tmatch typeof(from_value):",
		"\t\t\tTYPE_VECTOR2:",
		"\t\t\t\tvar as_vector2: Vector2 = from_value",
		"\t\t\t\treturn Vector4(as_vector2.x, as_vector2.y, 0.0, 0.0)",
		"\t\t\tTYPE_VECTOR3:",
		"\t\t\t\tvar as_vector3: Vector3 = from_value",
		"\t\t\t\treturn Vector4(as_vector3.x, as_vector3.y, as_vector3.z, 0.0)",
		"\t\t\tTYPE_COLOR:",
		"\t\t\t\tvar as_color: Color = from_value",
		"\t\t\t\treturn Vector4(as_color.r, as_color.g, as_color.b, as_color.a)",
		"\t\t\tTYPE_INT, TYPE_FLOAT:",
		"\t\t\t\treturn Vector4(float(from_value), 0.0, 0.0, 0.0)",
		"\t\treturn Vector4.ZERO",
		"\t## The current value, in the type the property is written back as.",
		"\tfunc unpack() -> Variant:",
		"\t\tmatch kind:",
		"\t\t\tTYPE_VECTOR2:",
		"\t\t\t\treturn Vector2(value.x, value.y)",
		"\t\t\tTYPE_VECTOR3:",
		"\t\t\t\treturn Vector3(value.x, value.y, value.z)",
		"\t\t\tTYPE_COLOR:",
		"\t\t\t\treturn Color(value.x, value.y, value.z, value.w)",
		"\t\t\tTYPE_INT:",
		"\t\t\t\treturn int(roundf(value.x))",
		"\t\treturn value.x",
		"\t## Where a component is really allowed to end up: inside the fence, when there is one.",
		"\tfunc goal(index: int) -> float:",
		"\t\tif clamped:",
		"\t\t\treturn clampf(target[index], min_value, max_value)",
		"\t\treturn target[index]",
		"\t## One framerate-independent step per live component; true on the frame it settles.",
		"\tfunc integrate(delta: float) -> bool:",
		"\t\tvar settled: bool = true",
		"\t\t# Damping is the fraction of velocity LOST PER SECOND, as it is for the named springs, and",
		"\t\t# under the same ceiling for the same reason.",
		"\t\tvar decay: float = pow(1.0 - clampf(damping, 0.0, SpringBehavior.DAMPING_CEILING), delta)",
		"\t\tfor index: int in components:",
		"\t\t\tvar rest: float = goal(index)",
		"\t\t\tvar speed: float = velocity[index]",
		"\t\t\tspeed += (rest - value[index]) * stiffness * delta",
		"\t\t\tspeed *= decay",
		"\t\t\tvar moved: float = value[index] + speed * delta",
		"\t\t\tif clamped:",
		"\t\t\t\tvar held: float = clampf(moved, min_value, max_value)",
		"\t\t\t\tif not is_equal_approx(held, moved):",
		"\t\t\t\t\t# A clamped spring stops at the wall rather than pushing through it.",
		"\t\t\t\t\tspeed = 0.0",
		"\t\t\t\tmoved = held",
		"\t\t\tif absf(rest - moved) < precision and absf(speed) < precision:",
		"\t\t\t\tmoved = rest",
		"\t\t\t\tspeed = 0.0",
		"\t\t\telse:",
		"\t\t\t\tsettled = false",
		"\t\t\tvalue[index] = moved",
		"\t\t\tvelocity[index] = speed",
		"\t\tif settled:",
		"\t\t\tactive = false",
		"\t\treturn settled",
		"",
		"## The spring under one property, made on the first row that names it and kept afterwards.",
		"## The property's type is read here, once, so the per-frame step never has to ask again.",
		"func _property_spring(property_path: String) -> PropertySpring:",
		"\tif property_springs.has(property_path):",
		"\t\treturn property_springs[property_path]",
		"\tvar entry := PropertySpring.new()",
		"\tentry.path = NodePath(property_path)",
		"\tentry.stiffness = default_stiffness",
		"\tentry.damping = default_damping",
		"\tentry.precision = default_precision",
		"\tif host != null:",
		"\t\tentry.adopt(host.get_indexed(entry.path))",
		"\tif not entry.supported:",
		"\t\tpush_warning(\"SpringBehavior cannot spring %s: the host has no such property, or it holds something that is not a number, a vector or a colour.\" % property_path)",
		"\tproperty_springs[property_path] = entry",
		"\treturn entry"
	])
