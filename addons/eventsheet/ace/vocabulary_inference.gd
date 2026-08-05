# EventSheet - inference for reflected vocabulary.
#
# Turns a bare reflected member into something that READS and EDITS like curated vocabulary,
# without the author writing a single annotation: the row sentence that shows the parameter
# values, the widget each parameter deserves, and the verb kind - each derived from what the
# script already declares (member name, argument names, argument types, return type).
#
# The governing rule is conservatism, borrowed from the Doctor's law: a wrong guess costs
# more than no guess. Every rule below falls back to the plain expression field / the safe
# kind rather than reaching. Widget hints are only ever emitted from THIS list, which is the
# params dialog's real factory set - inventing a hint name would silently degrade to a plain
# field, which looks like the feature simply not working.
@tool
class_name EventSheetVocabularyInference
extends RefCounted

## Argument-name keywords -> the params dialog's own hint ids. Ordered most specific first;
## matching is on word-ish containment of the lower-cased argument name.
const _NAME_HINTS: Array = [
	["audio", "audio_path"], ["sound", "audio_path"], ["sfx", "audio_path"], ["music", "audio_path"],
	["scene", "scene_path"],
	["animation", "animation_reference"], ["anim", "animation_reference"],
	["action", "input_action"],
	["group", "group_reference"],
]


## The widget hint for one reflected argument. `arg_type` is the declared Variant type
## (TYPE_NIL when untyped). Returns "expression" whenever nothing is certain - the current
## behaviour, and the safe one.
static func param_hint_for(param_name: String, arg_type: int) -> String:
	# A declared Color gets the swatch + saved palette; the value still round-trips as the
	# `Color(r, g, b, a)` literal the expression field would have held.
	if arg_type == TYPE_COLOR:
		return "color"
	# Name-based hints only apply to text arguments: an int called `action_index` is not an
	# input action, and a float `group_weight` is not a group name.
	if arg_type == TYPE_STRING or arg_type == TYPE_STRING_NAME:
		var lowered: String = param_name.to_lower()
		for entry: Array in _NAME_HINTS:
			if lowered.contains(str(entry[0])):
				return str(entry[1])
	return "expression"


## The row sentence for a reflected member: the verb's name followed by its parameter slots,
## so a row shows the VALUES ("Add item "potion", 3") instead of the bare verb name. Mirrors
## the shape the annotation-driven generator produces, so a reflected verb and an annotated
## one read the same way. Empty parameter list -> just the name (no trailing space).
static func display_template_for(display_name: String, param_ids: Array) -> String:
	var parts: PackedStringArray = PackedStringArray([display_name])
	for param_id: Variant in param_ids:
		var id: String = str(param_id).strip_edges()
		if not id.is_empty():
			parts.append("{%s}" % id)
	return " ".join(parts)


## The verb kind for a reflected method, from its RETURN declaration.
##
## The subtlety that matters: an UNTYPED return (`func pick():`) also reports TYPE_NIL, and
## treating it as "returns nothing" would publish a value-returning helper as an Action -
## the exact wrong-guess the conservatism rule forbids. Godot marks that case with
## PROPERTY_USAGE_NIL_IS_VARIANT, so untyped returns land on Expression, the kind that can
## be used in the most places and misleads in none.
static func ace_type_for_return(return_info: Dictionary) -> int:
	var return_type: int = int(return_info.get("type", TYPE_NIL))
	if return_type == TYPE_BOOL:
		return ACEDefinition.ACEType.CONDITION
	if return_type != TYPE_NIL:
		return ACEDefinition.ACEType.EXPRESSION
	if int(return_info.get("usage", 0)) & PROPERTY_USAGE_NIL_IS_VARIANT:
		return ACEDefinition.ACEType.EXPRESSION
	return ACEDefinition.ACEType.ACTION
