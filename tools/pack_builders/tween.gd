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
	sheet.class_description = "Wraps Godot's tween system in plain event rows: pick the feel once in the Inspector (transition curve and easing), then one action slides, scales, spins, or fades the host, with a trigger when it finishes. Compiles down to a normal create_tween() with zero plugin dependency."
	sheet.addon_category = "Tween"
	sheet.ace_expose_all_mode = "node"
	sheet.addon_tags = PackedStringArray(["motion", "juice"])
	sheet.variables = {
		"default_duration": {"type": "float", "default": 0.3, "exported": true,
			"attributes": {"tooltip": "Seconds used when a tween call passes 0.", "range": {"min": "0.01", "max": "10", "step": "0.01"}}},
		"easing": {"type": "String", "default": "out", "exported": true,
			"description": "Where the motion eases - in, out, or both ends.",
			"options": ["in", "out", "in_out", "out_in"]},
		"transition": {"type": "String", "default": "sine", "exported": true,
			"description": "Motion curve every tween uses (sine, bounce, elastic, and so on).",
			"options": ["linear", "sine", "quad", "cubic", "quart", "quint", "expo", "circ", "elastic", "back", "bounce", "spring"]}
	}
	var about: CommentRow = CommentRow.new()
	about.text = "Tweens, the behavior way: pick transition + easing in the Inspector, then call one action - Tween Position / Scale / Rotation / Alpha / any property."
	sheet.events.append(about)
	var block: RawCodeRow = RawCodeRow.new()
	block.code = "\n".join(PackedStringArray([
		"## @ace_trigger",
		"## @ace_name(\"On Tween Finished\")",
		"signal tween_finished",
		"",
		"## @ace_condition",
		"## @ace_name(\"Is Tweening\")",
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
	var along_block: RawCodeRow = RawCodeRow.new()
	along_block.code = "\n".join(_along_lines())
	sheet.events.append(along_block)
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
	# --- Along a curve the game owns, and back to where the property started ---
	Lib.append_function(sheet, "tween_along", "Tween Property Along Curve", "Tween", "Tweens a number property along a Curve file you own, in one of four readings: the curve as the value, added to where the property was, from there to a destination, or the curve's 0 to 1 remapped between two numbers. The value the property had before the first of these touched it is remembered, so Tween Property Back can return to it.",
		[["property_path", "String", "The number property to move, as the Inspector spells it: rotation_degrees, modulate:a, position:x."],
			["final_value", "float", "The number the mode reads: the value, the offset, or the destination. Ignored by remap."],
			["seconds", "float", "How long the whole curve takes. 0 uses the behavior's default duration."],
			["curve", "Curve", "The Curve file the motion follows. It is your file: draw it once in the Inspector and reuse it anywhere."],
			["mode", "String", "How the curve is read: absolute, relative, to destination, or remap."],
			["from_value", "float", "Remap only: the number the curve's 0 stands for."],
			["to_value", "float", "Remap only: the number the curve's 1 stands for."]],
		"_tween_along(property_path, final_value, seconds, curve, mode, from_value, to_value)",
		"Tween [b]{property_path}[/b] along [b]{curve}[/b] over [b]{seconds}[/b] s")
	_param_options(sheet, "mode", ["absolute", "relative", "to destination", "remap"])
	_default(sheet, "mode", "to destination")
	_default(sheet, "seconds", "0.4")
	_quoted_argument(sheet, "tween_along({property_path}, {final_value}, {seconds}, {curve}, \"{mode}\", {from_value}, {to_value})")
	Lib.append_function(sheet, "tween_along_and_wait", "Tween Property And Wait", "Tween", "The same curve tween, waited on: the rows under it run when the property has arrived. Use it to write a beat as one column of rows instead of a timer guessed to match.",
		[["property_path", "String", "The number property to move, as the Inspector spells it."],
			["final_value", "float", "The number the mode reads: the value, the offset, or the destination. Ignored by remap."],
			["seconds", "float", "How long the whole curve takes. 0 uses the behavior's default duration."],
			["curve", "Curve", "The Curve file the motion follows."],
			["mode", "String", "How the curve is read: absolute, relative, to destination, or remap."],
			["from_value", "float", "Remap only: the number the curve's 0 stands for."],
			["to_value", "float", "Remap only: the number the curve's 1 stands for."]],
		"var along: Tween = _tween_along(property_path, final_value, seconds, curve, mode, from_value, to_value)\nif along != null:\n\tawait along.finished",
		"Tween [b]{property_path}[/b] along [b]{curve}[/b] over [b]{seconds}[/b] s and wait")
	_param_options(sheet, "mode", ["absolute", "relative", "to destination", "remap"])
	_default(sheet, "mode", "to destination")
	_default(sheet, "seconds", "0.4")
	_quoted_argument(sheet, "tween_along_and_wait({property_path}, {final_value}, {seconds}, {curve}, \"{mode}\", {from_value}, {to_value})", true)
	Lib.append_function(sheet, "tween_back", "Tween Property Back", "Tween", "Returns a property to the value it held before the first curve tween touched it, over the behavior's own transition and easing. A lid that opened closes with the same number nobody had to type twice.",
		[["property_path", "String", "The property to send home."],
			["seconds", "float", "How long the way back takes. 0 uses the behavior's default duration."]],
		"if host == null or not _tween_starts.has(property_path):\n\treturn\n_along_kill()\n_start_tween(property_path, float(_tween_starts[property_path]), seconds)",
		"Tween [b]{property_path}[/b] back over [b]{seconds}[/b] s")
	_default(sheet, "seconds", "0.3")
	# The pack's hero verbs: starred + bold at the top of their picker section.
	Lib.verb_sentences(sheet, {
		"tween_property_to": "Tween [b]{property_path}[/b] to [b]{final_value}[/b] over [b]{duration}[/b] s",
	})
	Lib.feature_verbs(sheet, ["tween_property_to"])
	if not Lib.save_pack(sheet, "res://eventsheet_addons/tween/tween_behavior"):
		return false
	# Two starter curves ship beside the pack so a first curve tween has something to point at on the
	# day it is written. They are ordinary Curve files: open one, drag its points, rename it,
	# duplicate it into the curve this game actually wants, or delete both. Nothing in the pack
	# names them, and a game is expected to end up with its own.
	return Lib.ship_files("tween", "res://eventsheet_addons/tween/tween_behavior",
		PackedStringArray(["tres"]))


## The CURVE half of the pack: the tween a Curve file drives, the four readings of that curve, and
## the memory of where a property was before the first of them moved it.
##
## Nothing here is a house style: the curve is a file the game draws and owns, and the two that ship
## beside the pack are starters to edit or delete. The pack knows how to read a curve, not which
## curves a game should have.
static func _along_lines() -> PackedStringArray:
	return PackedStringArray([
		"## The curve tween in flight, kept so a second row on the same property replaces it rather",
		"## than fighting it.",
		"var _along_tween: Tween = null",
		"",
		"## What a property held before the FIRST curve tween touched it, keyed by the property path.",
		"## Only ever written once per property, which is what makes Tween Property Back exact however",
		"## many times the property has been tweened since.",
		"var _tween_starts: Dictionary = {}",
		"",
		"func _along_kill() -> void:",
		"\tif _along_tween != null and _along_tween.is_valid():",
		"\t\t_along_tween.kill()",
		"\t_along_tween = null",
		"",
		"## The number the property takes at one point along the curve, in the mode the row chose.",
		"## `sampled` is what the curve reads at that point, which is usually 0 to 1 but need not be:",
		"## a curve that overshoots is exactly how a lid slams past its stop and settles back.",
		"func _along_value(start_value: float, sampled: float, final_value: float, mode: String, from_value: float, to_value: float) -> float:",
		"\tmatch mode:",
		"\t\t\"relative\":",
		"\t\t\treturn start_value + final_value * sampled",
		"\t\t\"to destination\":",
		"\t\t\treturn lerpf(start_value, final_value, sampled)",
		"\t\t\"remap\":",
		"\t\t\treturn lerpf(from_value, to_value, sampled)",
		"\treturn final_value * sampled",
		"",
		"## The one implementation behind Tween Property Along Curve and its awaiting twin. Returns the",
		"## tween so the awaiting row has something to wait on, and null when there is nothing to move.",
		"func _tween_along(property_path: String, final_value: float, seconds: float, curve: Curve, mode: String, from_value: float, to_value: float) -> Tween:",
		"\tif host == null or curve == null:",
		"\t\treturn null",
		"\tvar path := NodePath(property_path)",
		"\tvar start_value: float = float(host.get_indexed(path))",
		"\tif not _tween_starts.has(property_path):",
		"\t\t_tween_starts[property_path] = start_value",
		"\tvar seconds_used: float = seconds if seconds > 0.0 else default_duration",
		"\t_along_kill()",
		"\tif not host.is_inside_tree():",
		"\t\t# A tween needs a live tree. A row that ran before the host entered one has still",
		"\t\t# recorded where the property was, so Tween Property Back knows the way home.",
		"\t\treturn null",
		"\tvar along: Tween = host.create_tween()",
		"\tvar write := func(fraction: float) -> void:",
		"\t\tif host == null:",
		"\t\t\treturn",
		"\t\thost.set_indexed(path, _along_value(start_value, curve.sample(fraction), final_value, mode, from_value, to_value))",
		"\talong.tween_method(write, 0.0, 1.0, maxf(seconds_used, 0.01))",
		"\talong.finished.connect(func() -> void: tween_finished.emit())",
		"\t_along_tween = along",
		"\treturn along"
	])


## Sets the dropdown options on the last-appended ACE's parameter (append_function only sets id,
## type and help), so a word parameter is picked from a list instead of typed from memory.
static func _param_options(sheet: EventSheetResource, param_id: String, choices: Array) -> void:
	var fn: EventFunction = sheet.functions[sheet.functions.size() - 1]
	for parameter: ACEParam in fn.params:
		if parameter.id == param_id:
			var typed: PackedStringArray = PackedStringArray()
			for choice: Variant in choices:
				typed.append(str(choice))
			parameter.options = typed


## Pre-fills the last-appended ACE's parameter default, so the dialog opens with a usable value
## (authoring-time metadata only - defaults never appear in the compiled .gd).
static func _default(sheet: EventSheetResource, param_id: String, value: String) -> void:
	var fn: EventFunction = sheet.functions[sheet.functions.size() - 1]
	for parameter: ACEParam in fn.params:
		if parameter.id == param_id:
			parameter.default_value = value


## Writes the last-appended ACE's whole call by hand. A dropdown over WORDS is a String argument, so
## its quotes belong in the template rather than in the word the picker shows; `awaited` marks the
## row a coroutine, which is what makes the rows under it wait.
static func _quoted_argument(sheet: EventSheetResource, call: String, awaited: bool = false) -> void:
	var fn: EventFunction = sheet.functions[sheet.functions.size() - 1]
	var prefix: String = "await " if awaited else ""
	fn.codegen_template_override = "%s$%s.%s" % [prefix, sheet.custom_class_name, call]
