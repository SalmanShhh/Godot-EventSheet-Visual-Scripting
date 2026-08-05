# EventSheet - inference for reflected vocabulary. Pins the table BY VALUE,
# including the conservatism rules that decide whether the feature is trustworthy: a wrong
# widget or a wrong verb kind is worse than a plain expression field.
#
# The hint ids asserted here are the params dialog's REAL factory ids - a typo would degrade
# silently to a plain field, which reads as "the feature does nothing", so they are pinned
# as literals on purpose.
@tool
class_name VocabularyInferenceTest
extends RefCounted


static func run() -> bool:
	var ok: bool = true

	# ── Widget hints from argument name + declared type ──
	ok = _check("a declared Color gets the swatch",
		EventSheetVocabularyInference.param_hint_for("tint", TYPE_COLOR), "color") and ok
	ok = _check("a sound path gets the audio picker",
		EventSheetVocabularyInference.param_hint_for("sound_path", TYPE_STRING), "audio_path") and ok
	ok = _check("a scene path gets the scene picker",
		EventSheetVocabularyInference.param_hint_for("scene_file", TYPE_STRING), "scene_path") and ok
	ok = _check("an input action gets the live Input Map picker",
		EventSheetVocabularyInference.param_hint_for("action", TYPE_STRING), "input_action") and ok
	ok = _check("a group name gets the group picker",
		EventSheetVocabularyInference.param_hint_for("group", TYPE_STRING), "group_reference") and ok
	ok = _check("an animation name gets the animation picker",
		EventSheetVocabularyInference.param_hint_for("animation", TYPE_STRING), "animation_reference") and ok
	ok = _check("StringName arguments infer like Strings",
		EventSheetVocabularyInference.param_hint_for("anim", TYPE_STRING_NAME), "animation_reference") and ok

	# Conservatism: a name that LOOKS like a hint but is not text must never take the widget.
	ok = _check("an int named action_index is not an input action",
		EventSheetVocabularyInference.param_hint_for("action_index", TYPE_INT), "expression") and ok
	ok = _check("a float named group_weight is not a group",
		EventSheetVocabularyInference.param_hint_for("group_weight", TYPE_FLOAT), "expression") and ok
	ok = _check("an unknown name falls back to the expression field",
		EventSheetVocabularyInference.param_hint_for("amount", TYPE_FLOAT), "expression") and ok
	ok = _check("an untyped argument falls back to the expression field",
		EventSheetVocabularyInference.param_hint_for("value", TYPE_NIL), "expression") and ok

	# ── Row sentences ──
	ok = _check("a sentence shows every parameter slot",
		EventSheetVocabularyInference.display_template_for("Add item", ["item_id", "count"]),
		"Add item {item_id} {count}") and ok
	ok = _check("a no-parameter verb keeps a bare name (no trailing space)",
		EventSheetVocabularyInference.display_template_for("Respawn", []), "Respawn") and ok
	ok = _check("blank parameter ids are skipped",
		EventSheetVocabularyInference.display_template_for("Do", ["", "x"]), "Do {x}") and ok

	# ── Verb kind from the return declaration (THE conservatism rule) ──
	ok = _check("a bool return is a Condition",
		EventSheetVocabularyInference.ace_type_for_return({"type": TYPE_BOOL}),
		ACEDefinition.ACEType.CONDITION) and ok
	ok = _check("a value return is an Expression",
		EventSheetVocabularyInference.ace_type_for_return({"type": TYPE_FLOAT}),
		ACEDefinition.ACEType.EXPRESSION) and ok
	ok = _check("an explicit void return is an Action",
		EventSheetVocabularyInference.ace_type_for_return({"type": TYPE_NIL, "usage": 0}),
		ACEDefinition.ACEType.ACTION) and ok
	# The trap: an UNTYPED return also reports TYPE_NIL. Publishing a value-returning helper
	# as an Action would be the wrong guess, so it lands on the safe kind instead.
	ok = _check("an UNTYPED return is an Expression, not an Action",
		EventSheetVocabularyInference.ace_type_for_return({"type": TYPE_NIL, "usage": PROPERTY_USAGE_NIL_IS_VARIANT}),
		ACEDefinition.ACEType.EXPRESSION) and ok

	# ── End to end on a real reflected method: the sentence and hints reach the definition ──
	var method_info: Dictionary = {
		"name": "play_cue",
		"args": [{"name": "sound_path", "type": TYPE_STRING}, {"name": "volume", "type": TYPE_FLOAT}],
		"return": {"type": TYPE_NIL, "usage": 0},
		"flags": 0,
	}
	var definition: ACEDefinition = EventSheetClassDBSource._method_definition("ScratchAudioSource", method_info)
	# The sentence leads with the verb's DISPLAY name, which is the member title-cased
	# ("play_cue" -> "Play Cue") - the same read an annotated verb has.
	ok = _check("the reflected verb carries its sentence",
		str(definition.metadata.get("display_template", "")), "Play Cue {sound_path} {volume}") and ok
	ok = _check("the reflected verb's text argument carries its inferred widget",
		str((definition.parameters[0] as Dictionary).get("hint", "")), "audio_path") and ok
	ok = _check("the reflected verb's number argument stays an expression",
		str((definition.parameters[1] as Dictionary).get("hint", "")), "expression") and ok
	ok = _check("the emitted call is unchanged by inference",
		str(definition.metadata.get("codegen_template", "")), "{target.}play_cue({sound_path}, {volume})") and ok
	return ok


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		return true
	print("[FAIL] vocabulary_inference_test: %s - expected %s, got %s" % [label, str(expected), str(actual)])
	return false
