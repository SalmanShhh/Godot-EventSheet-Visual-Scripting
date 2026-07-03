# Pack builder - tween (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## Tween behavior: Godot's Tween, the event-sheet-behavior way - duration/transition/easing as
## Inspector combos, one-call property/position/scale/rotation/alpha tweens on the host,
## and an On Tween Finished trigger. Plain create_tween underneath (parity contract).
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "Node2D"
	sheet.custom_class_name = "TweenBehavior"
	sheet.addon_tags = PackedStringArray(["motion", "juice"])
	sheet.variables = {
		"default_duration": {"type": "float", "default": 0.3, "exported": true,
			"attributes": {"tooltip": "Seconds used when a tween call passes 0.", "range": {"min": "0.01", "max": "10", "step": "0.01"}}},
		"transition": {"type": "String", "default": "sine", "exported": true,
			"options": ["linear", "sine", "quad", "cubic", "quart", "quint", "expo", "circ", "elastic", "back", "bounce", "spring"]},
		"easing": {"type": "String", "default": "out", "exported": true,
			"options": ["in", "out", "in_out", "out_in"]}
	}
	var about: CommentRow = CommentRow.new()
	about.text = "Tweens, the behavior way: pick transition + easing in the Inspector, then call one action - Tween Position / Scale / Rotation / Alpha / any property."
	sheet.events.append(about)
	var block: RawCodeRow = RawCodeRow.new()
	block.code = "\n".join(PackedStringArray([
		"## @ace_trigger",
		"## @ace_name(\"On Tween Finished\")",
		"## @ace_category(\"Tween\")",
		"signal tween_finished",
		"",
		"## @ace_condition",
		"## @ace_name(\"Is Tweening\")",
		"## @ace_category(\"Tween\")",
		"## @ace_codegen_template(\"$TweenBehavior.is_tweening()\")",
		"func is_tweening() -> bool:",
		"\treturn _active_tween != null and _active_tween.is_running()",
		"",
		"var _active_tween: Tween = null",
		"",
		"func _trans_id() -> int:",
		"\tmatch transition:",
		"\t\t\"linear\": return Tween.TRANS_LINEAR",
		"\t\t\"quad\": return Tween.TRANS_QUAD",
		"\t\t\"cubic\": return Tween.TRANS_CUBIC",
		"\t\t\"quart\": return Tween.TRANS_QUART",
		"\t\t\"quint\": return Tween.TRANS_QUINT",
		"\t\t\"expo\": return Tween.TRANS_EXPO",
		"\t\t\"circ\": return Tween.TRANS_CIRC",
		"\t\t\"elastic\": return Tween.TRANS_ELASTIC",
		"\t\t\"back\": return Tween.TRANS_BACK",
		"\t\t\"bounce\": return Tween.TRANS_BOUNCE",
		"\t\t\"spring\": return Tween.TRANS_SPRING",
		"\treturn Tween.TRANS_SINE",
		"",
		"func _ease_id() -> int:",
		"\tmatch easing:",
		"\t\t\"in\": return Tween.EASE_IN",
		"\t\t\"in_out\": return Tween.EASE_IN_OUT",
		"\t\t\"out_in\": return Tween.EASE_OUT_IN",
		"\treturn Tween.EASE_OUT",
		"",
		"func _start_tween(property_path: String, final_value: Variant, duration: float) -> void:",
		"\tif host == null:",
		"\t\treturn",
		"\tvar seconds: float = duration if duration > 0.0 else default_duration",
		"\t_active_tween = host.create_tween()",
		"\t_active_tween.tween_property(host, NodePath(property_path), final_value, seconds).set_trans(_trans_id()).set_ease(_ease_id())",
		"\t_active_tween.finished.connect(func() -> void: tween_finished.emit())"
	]))
	sheet.events.append(block)
	Lib.append_function(sheet, "tween_property_to", "Tween Property", "Tween", "Tweens any host property (e.g. position:x) to a value.",
		[["property_path", "String"], ["final_value", "float"], ["duration", "float"]],
		"_start_tween(property_path, final_value, duration)")
	Lib.append_function(sheet, "tween_position", "Tween Position", "Tween", "Moves the host to (x, y).",
		[["x", "float"], ["y", "float"], ["duration", "float"]],
		"_start_tween(\"position\", Vector2(x, y), duration)")
	Lib.append_function(sheet, "tween_scale", "Tween Scale", "Tween", "Scales the host uniformly.",
		[["amount", "float"], ["duration", "float"]],
		"_start_tween(\"scale\", Vector2(amount, amount), duration)")
	Lib.append_function(sheet, "tween_rotation", "Tween Rotation", "Tween", "Rotates the host to the given degrees.",
		[["degrees", "float"], ["duration", "float"]],
		"_start_tween(\"rotation_degrees\", degrees, duration)")
	Lib.append_function(sheet, "tween_alpha", "Tween Alpha", "Tween", "Fades the host's modulate alpha.",
		[["alpha", "float"], ["duration", "float"]],
		"_start_tween(\"modulate:a\", clampf(alpha, 0.0, 1.0), duration)")
	Lib.append_function(sheet, "stop_tweens", "Stop Tweens", "Tween", "Kills the running tween (host stays where it is).",
		[],
		"if _active_tween != null:\n\t_active_tween.kill()\n\t_active_tween = null")
	return Lib.save_pack(sheet, "res://eventsheet_addons/tween/tween_behavior")
