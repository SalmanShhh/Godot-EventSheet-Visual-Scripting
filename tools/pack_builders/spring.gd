# Pack builder — spring (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")

## Numeric springing (cleaned-up port of the author's C3 simple_spring addon): NAMED
## springs (value/target/velocity each) driven by stiffness + damping + precision, with
## impulses, reached-triggers and host-transform conveniences. Mesh deformation from the
## C3 original is an honest skip (that's shader/skeleton territory in Godot). Exported
## properties showcase Inspector attributes (ranges + tooltips) in a shipped pack.
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "Node2D"
	sheet.custom_class_name = "SpringBehavior"
	sheet.addon_tags = PackedStringArray(["motion", "juice"])
	sheet.variables = {
		"default_stiffness": {"type": "float", "default": 170.0, "exported": true,
			"attributes": {"tooltip": "Spring force toward the target (higher = snappier).", "range": {"min": "1", "max": "1000", "step": "1"}}},
		"default_damping": {"type": "float", "default": 0.85, "exported": true,
			"attributes": {"tooltip": "0 = oscillate forever, 1 = no overshoot.", "range": {"min": "0", "max": "1", "step": "0.01"}}},
		"default_precision": {"type": "float", "default": 0.01, "exported": true,
			"attributes": {"tooltip": "Distance + speed below which a spring counts as settled."}},
		"springs": {"type": "Dictionary", "default": {}, "exported": false},
		"color_springs": {"type": "Dictionary", "default": {}, "exported": false}
	}
	var about: CommentRow = CommentRow.new()
	about.text = "Numeric springing: snappy, physical motion for ANY number. Name a spring, set its target, read its value — or use the host helpers (x/y/angle/scale) for instant juice."
	sheet.events.append(about)
	var block: RawCodeRow = RawCodeRow.new()
	block.code = "\n".join(PackedStringArray([
		"## @ace_trigger",
		"## @ace_name(\"On Spring Reached\")",
		"## @ace_category(\"Spring\")",
		"signal spring_reached(spring_name: String)",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Spring Started\")",
		"## @ace_category(\"Spring\")",
		"signal spring_started(spring_name: String)",
		"",
		"## @ace_expression",
		"## @ace_name(\"Color Value\")",
		"## @ace_category(\"Spring\")",
		"func color_value(spring_name: String) -> Color:",
		"\treturn color_springs.get(spring_name, {}).get(\"value\", Color.WHITE)",
		"",
		"## @ace_condition",
		"## @ace_name(\"Is Springing\")",
		"## @ace_category(\"Spring\")",
		"## @ace_codegen_template(\"$SpringBehavior.is_springing({spring_name})\")",
		"func is_springing(spring_name: String) -> bool:",
		"\treturn springs.has(spring_name) and bool(springs[spring_name].get(\"active\", false))",
		"",
		"## @ace_expression",
		"## @ace_name(\"Spring Value\")",
		"## @ace_category(\"Spring\")",
		"func spring_value(spring_name: String) -> float:",
		"\treturn float(springs.get(spring_name, {}).get(\"value\", 0.0))",
		"",
		"## @ace_expression",
		"## @ace_name(\"Spring Velocity\")",
		"## @ace_category(\"Spring\")",
		"func spring_velocity(spring_name: String) -> float:",
		"\treturn float(springs.get(spring_name, {}).get(\"velocity\", 0.0))",
		"",
		"## @ace_expression",
		"## @ace_name(\"Spring Progress\")",
		"## @ace_category(\"Spring\")",
		"func spring_progress(spring_name: String) -> float:",
		"\tvar entry: Dictionary = springs.get(spring_name, {})",
		"\tvar span: float = absf(float(entry.get(\"target\", 0.0)) - float(entry.get(\"from\", 0.0)))",
		"\tif span <= 0.0:",
		"\t\treturn 1.0",
		"\treturn clampf(1.0 - absf(float(entry.get(\"target\", 0.0)) - float(entry.get(\"value\", 0.0))) / span, 0.0, 1.0)",
		"",
		"func _spring_entry(spring_name: String) -> Dictionary:",
		"\tif not springs.has(spring_name):",
		"\t\tsprings[spring_name] = {\"value\": 0.0, \"from\": 0.0, \"target\": 0.0, \"velocity\": 0.0,",
		"\t\t\t\"stiffness\": default_stiffness, \"damping\": default_damping, \"precision\": default_precision, \"active\": false}",
		"\treturn springs[spring_name]",
		"",
		"func _color_entry(spring_name: String) -> Dictionary:",
		"\tif not color_springs.has(spring_name):",
		"\t\tcolor_springs[spring_name] = {\"value\": Color.WHITE, \"target\": Color.WHITE, \"velocity\": Color(0, 0, 0, 0),",
		"\t\t\t\"stiffness\": default_stiffness, \"damping\": default_damping, \"precision\": default_precision, \"active\": false}",
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
	var tick: EventRow = EventRow.new()
	tick.trigger_provider_id = "Core"
	tick.trigger_id = "OnProcess"
	var simulate: RawCodeRow = RawCodeRow.new()
	simulate.code = "\n".join(PackedStringArray([
		"# Semi-implicit integration; damping uses pow() so motion is framerate-independent.",
		"for spring_name: Variant in springs.keys():",
		"\tvar entry: Dictionary = springs[spring_name]",
		"\tif not bool(entry.get(\"active\", false)):",
		"\t\tcontinue",
		"\tentry[\"velocity\"] = float(entry[\"velocity\"]) + (float(entry[\"target\"]) - float(entry[\"value\"])) * float(entry[\"stiffness\"]) * delta",
		"\t# Damping is the fraction of velocity LOST PER SECOND (framerate-independent).",
		"\tentry[\"velocity\"] = float(entry[\"velocity\"]) * pow(1.0 - float(entry[\"damping\"]), delta)",
		"\tentry[\"value\"] = float(entry[\"value\"]) + float(entry[\"velocity\"]) * delta",
		"\tif absf(float(entry[\"target\"]) - float(entry[\"value\"])) < float(entry[\"precision\"]) and absf(float(entry[\"velocity\"])) < float(entry[\"precision\"]):",
		"\t\tentry[\"value\"] = float(entry[\"target\"])",
		"\t\tentry[\"velocity\"] = 0.0",
		"\t\tentry[\"active\"] = false",
		"\t\tspring_reached.emit(str(spring_name))",
		"\t_apply_to_host(str(spring_name), float(entry[\"value\"]))",
		"# Colour springs integrate identically (Color supports +, - and *float component-wise).",
		"for color_name: Variant in color_springs.keys():",
		"\tvar centry: Dictionary = color_springs[color_name]",
		"\tif not bool(centry.get(\"active\", false)):",
		"\t\tcontinue",
		"\tvar cvel: Color = centry[\"velocity\"]",
		"\tvar cval: Color = centry[\"value\"]",
		"\tvar ctarget: Color = centry[\"target\"]",
		"\tcvel = cvel + (ctarget - cval) * float(centry[\"stiffness\"]) * delta",
		"\tcvel = cvel * pow(1.0 - float(centry[\"damping\"]), delta)",
		"\tcval = cval + cvel * delta",
		"\tcentry[\"velocity\"] = cvel",
		"\tcentry[\"value\"] = cval",
		"\tvar prec: float = float(centry[\"precision\"])",
		"\tif absf(ctarget.r - cval.r) < prec and absf(ctarget.g - cval.g) < prec and absf(ctarget.b - cval.b) < prec and absf(ctarget.a - cval.a) < prec:",
		"\t\tcentry[\"value\"] = ctarget",
		"\t\tcentry[\"velocity\"] = Color(0, 0, 0, 0)",
		"\t\tcentry[\"active\"] = false",
		"\t\tspring_reached.emit(str(color_name))"
	]))
	tick.actions.append(simulate)
	sheet.events.append(tick)
	Lib.append_function(sheet, "spring_to", "Spring To", "Spring", "Springs the named value toward a target.",
		[["spring_name", "String"], ["target", "float"]],
		"var entry: Dictionary = _spring_entry(spring_name)\nvar was_active := bool(entry[\"active\"])\nentry[\"from\"] = float(entry[\"value\"])\nentry[\"target\"] = target\nentry[\"active\"] = true\nif not was_active:\n\tspring_started.emit(spring_name)")
	Lib.append_function(sheet, "spring_between", "Spring Between", "Spring", "Snaps to a start value, then springs to the end value.",
		[["spring_name", "String"], ["from_value", "float"], ["to_value", "float"]],
		"var entry: Dictionary = _spring_entry(spring_name)\nentry[\"value\"] = from_value\nentry[\"from\"] = from_value\nentry[\"velocity\"] = 0.0\nentry[\"target\"] = to_value\nentry[\"active\"] = true")
	Lib.append_function(sheet, "set_spring", "Set Spring Value", "Spring", "Snaps the named spring (no motion).",
		[["spring_name", "String"], ["value", "float"]],
		"var entry: Dictionary = _spring_entry(spring_name)\nentry[\"value\"] = value\nentry[\"from\"] = value\nentry[\"target\"] = value\nentry[\"velocity\"] = 0.0\nentry[\"active\"] = false")
	Lib.append_function(sheet, "add_impulse", "Add Impulse", "Spring", "Kicks the named spring's velocity (instant juice).",
		[["spring_name", "String"], ["amount", "float"]],
		"var entry: Dictionary = _spring_entry(spring_name)\nentry[\"velocity\"] = float(entry[\"velocity\"]) + amount\nentry[\"active\"] = true")
	Lib.append_function(sheet, "stop_spring", "Stop Spring", "Spring", "Freezes the named spring where it is.",
		[["spring_name", "String"]],
		"if springs.has(spring_name):\n\tsprings[spring_name][\"active\"] = false")
	Lib.append_function(sheet, "configure_spring", "Configure Spring", "Spring", "Per-spring stiffness/damping/precision overrides.",
		[["spring_name", "String"], ["stiffness", "float"], ["damping", "float"], ["precision", "float"]],
		"var entry: Dictionary = _spring_entry(spring_name)\nentry[\"stiffness\"] = stiffness\nentry[\"damping\"] = clampf(damping, 0.0, 1.0)\nentry[\"precision\"] = precision")
	Lib.append_function(sheet, "spring_host_x", "Spring Host X", "Spring", "Springs the host's X position.",
		[["target", "float"]],
		"var entry: Dictionary = _spring_entry(\"__x\")\nif not bool(entry[\"active\"]) and host != null:\n\tentry[\"value\"] = host.position.x\nentry[\"from\"] = float(entry[\"value\"])\nentry[\"target\"] = target\nentry[\"active\"] = true")
	Lib.append_function(sheet, "spring_host_y", "Spring Host Y", "Spring", "Springs the host's Y position.",
		[["target", "float"]],
		"var entry: Dictionary = _spring_entry(\"__y\")\nif not bool(entry[\"active\"]) and host != null:\n\tentry[\"value\"] = host.position.y\nentry[\"from\"] = float(entry[\"value\"])\nentry[\"target\"] = target\nentry[\"active\"] = true")
	Lib.append_function(sheet, "spring_host_angle", "Spring Host Angle", "Spring", "Springs the host's rotation (degrees).",
		[["degrees", "float"]],
		"var entry: Dictionary = _spring_entry(\"__angle\")\nif not bool(entry[\"active\"]) and host != null:\n\tentry[\"value\"] = host.rotation_degrees\nentry[\"from\"] = float(entry[\"value\"])\nentry[\"target\"] = degrees\nentry[\"active\"] = true")
	Lib.append_function(sheet, "spring_host_scale", "Spring Host Scale", "Spring", "Springs the host's uniform scale (squash & stretch!).",
		[["target", "float"]],
		"var entry: Dictionary = _spring_entry(\"__scale\")\nif not bool(entry[\"active\"]) and host != null:\n\tentry[\"value\"] = host.scale.x\nentry[\"from\"] = float(entry[\"value\"])\nentry[\"target\"] = target\nentry[\"active\"] = true")
	Lib.append_function(sheet, "set_color", "Set Color Value", "Spring", "Snaps a named colour spring (no motion) — seed it before springing.",
		[["spring_name", "String"], ["color", "Color"]],
		"var entry: Dictionary = _color_entry(spring_name)\nentry[\"value\"] = color\nentry[\"target\"] = color\nentry[\"velocity\"] = Color(0, 0, 0, 0)\nentry[\"active\"] = false")
	Lib.append_function(sheet, "spring_color", "Spring Color", "Spring", "Springs a named colour toward a target (read it back with Color Value — great for hit flashes).",
		[["spring_name", "String"], ["target_color", "Color"]],
		"var entry: Dictionary = _color_entry(spring_name)\nvar was_active := bool(entry[\"active\"])\nentry[\"target\"] = target_color\nentry[\"active\"] = true\nif not was_active:\n\tspring_started.emit(spring_name)")
	Lib.append_function(sheet, "pause_spring", "Pause Spring", "Spring", "Freezes a spring in place (resume continues it).",
		[["spring_name", "String"]],
		"if springs.has(spring_name):\n\tsprings[spring_name][\"active\"] = false\nif color_springs.has(spring_name):\n\tcolor_springs[spring_name][\"active\"] = false")
	Lib.append_function(sheet, "resume_spring", "Resume Spring", "Spring", "Resumes a paused spring toward its target.",
		[["spring_name", "String"]],
		"if springs.has(spring_name):\n\tsprings[spring_name][\"active\"] = true\nif color_springs.has(spring_name):\n\tcolor_springs[spring_name][\"active\"] = true")
	Lib.append_function(sheet, "remove_spring", "Remove Spring", "Spring", "Deletes a named spring (numeric and/or colour).",
		[["spring_name", "String"]],
		"springs.erase(spring_name)\ncolor_springs.erase(spring_name)")
	Lib.append_function(sheet, "reset_springs", "Reset All Springs", "Spring", "Clears every spring on this behavior.",
		[],
		"springs.clear()\ncolor_springs.clear()")
	return Lib.save_pack(sheet, "res://eventsheet_addons/spring/spring_behavior")
