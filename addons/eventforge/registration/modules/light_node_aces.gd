# EventForge module - the LIGHT is the object, not a parameter.
#
# The sixteen Core lighting actions beside this file take the light as their first parameter, so a
# row reads "Set light energy to 1.0" and which light that is lives two clicks away. These rows are
# node-scoped instead: the light sits in the object column and the row says the word - "Torch · Set
# brightness to 1.2" - while the code echo shows the property that light really has.
#
# Nothing here is written twice. The words come from EventForgeLightWords, which asks ClassDB which
# spelling each light class answers to, and every row of every word is built by one of the three
# builders below (a value, a colour, a switch). A light class the engine adds, or a project's own
# subclass of one, resolves through the same map with nothing added here.
#
# The sixteen Core actions are untouched and keep compiling: their ace_ids and templates are frozen
# API, and a sheet saved with one of them opens with it. These are new ids beside them.
@tool
class_name EventForgeLightNodeACEs
extends RefCounted

const F := preload("res://addons/eventforge/registration/ace_factory.gd")
const W := preload("res://addons/eventforge/registration/light_words.gd")

## The picker category these rows are filed under - the same one the sixteen Core lighting actions
## use, so "Lighting" is one section of the vocabulary rather than two. It also keeps them out of the
## reverse index (see ace_lifter's excluded categories), which is deliberate: a light row is only
## lifted when the attached scene says the node really is a light, and that gate lives in
## lighting_lift.gd rather than in a template match that would claim any `.enabled = false` line.
const CAT := "Lighting"

## How long a fade takes when nobody says - half a second, which is the length a light change reads
## as deliberate rather than as a flicker.
const DEFAULT_FADE_SECONDS := "0.5"


static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []
	for word: Dictionary in W.WORDS:
		for dimension: Array in [[W.CLASSES_2D, W.ROOT_2D], [W.CLASSES_3D, W.ROOT_3D]]:
			for row: Dictionary in W.rows_of(str(word["word"]), dimension[0], str(dimension[1])):
				match str(word["kind"]):
					W.KIND_SWITCH:
						descriptors.append_array(_switch_rows(word, row))
					W.KIND_COLOUR:
						descriptors.append_array(_colour_rows(word, row))
					_:
						descriptors.append_array(_value_rows(word, row))
	return descriptors


## A word that is set to a NUMBER: the Set row, the expression that reads it back, and - for a word
## a light can be faded on - the one-line tween that walks it there over time.
static func _value_rows(word: Dictionary, row: Dictionary) -> Array[ACEDescriptor]:
	var stem: String = str(row["id_stem"])
	var property: String = str(row["property"])
	var host: String = str(row["host"])
	var initial: String = _default_of(row)
	var rows: Array[ACEDescriptor] = [
		F.make_descriptor("Core", "LightSet%s" % stem, str(word["name"]), ACEDescriptor.ACEType.ACTION,
			"%s = {value}" % property, "",
			[F.make_param("value", "String", initial, str(word["word"]).capitalize(), str(word["about"]), "expression")],
			CAT, str(word["verb"]), host)
			.described(_about(word, row)),
		F.make_descriptor("Core", "Light%s" % stem, str(word["word"]).capitalize(), ACEDescriptor.ACEType.EXPRESSION,
			property, "", [], CAT, str(word["reads"]), host)
			.described("Reads %s back: %s. Use it in any value field." % [str(word["word"]), _echo(row)])
	]
	if bool(word.get("fades", false)):
		rows.append(_fade_row(word, row, initial))
	return rows


## The one row that is not a member operation: a tween walks the property from where it is to where
## the row says over a number of seconds. It carries its own `target` (which is why the node-scoped
## transform leaves it alone) because the light is an ARGUMENT of the call here, not its receiver -
## `create_tween()` belongs to the node running the sheet.
static func _fade_row(word: Dictionary, row: Dictionary, initial: String) -> ACEDescriptor:
	var params: Array[ACEParam] = [
		F.make_param("target", "String", "self", "On node",
			"The light to fade. Leave it as self to fade the light this sheet is on.", "expression"),
		F.make_param("value", "String", initial, str(word["word"]).capitalize(),
			"The %s to arrive at." % str(word["word"]), "expression"),
		F.make_param("seconds", "String", DEFAULT_FADE_SECONDS, "Seconds",
			"How long the fade takes.", "expression")
	]
	var faded: ACEDescriptor = F.make_descriptor("Core", "LightFade%s" % str(row["id_stem"]),
		"Fade %s" % str(word["word"]).capitalize(), ACEDescriptor.ACEType.ACTION,
		"create_tween().tween_property({target}, \"%s\", {value}, {seconds})" % str(row["property"]), "",
		params, CAT, "Fade to {value} over {seconds} s", str(row["host"]))
	return faded.described("Walks %s to a new value over time instead of jumping to it - one tween, no state to keep. Writes %s." % [
		str(word["word"]), _echo(row)]).featured()


## A word that is set to a COLOUR. The same pair as a value word, with the field that opens a colour
## picker instead of an expression box.
static func _colour_rows(word: Dictionary, row: Dictionary) -> Array[ACEDescriptor]:
	var stem: String = str(row["id_stem"])
	return [
		F.make_descriptor("Core", "LightSet%s" % stem, str(word["name"]), ACEDescriptor.ACEType.ACTION,
			"%s = {value}" % str(row["property"]), "",
			[F.make_param("value", "Color", _default_of(row), str(word["word"]).capitalize(),
				str(word["about"]), "color")],
			CAT, str(word["verb"]), str(row["host"]))
			.described(_about(word, row)),
		F.make_descriptor("Core", "Light%s" % stem, str(word["word"]).capitalize(),
			ACEDescriptor.ACEType.EXPRESSION, str(row["property"]), "", [], CAT, str(word["reads"]), str(row["host"]))
			.described("Reads the light's %s back: %s. Use it in any value field." % [str(word["word"]), _echo(row)])
	]


## A word that is ON or OFF: two actions that say which, and the condition that asks. Two actions
## rather than one with a true/false field, because "Turn off" is the sentence a reader writes and
## "Set lit false" is the one they have to decode.
static func _switch_rows(word: Dictionary, row: Dictionary) -> Array[ACEDescriptor]:
	var stem: String = str(row["id_stem"])
	var property: String = str(row["property"])
	var host: String = str(row["host"])
	return [
		F.make_descriptor("Core", "Light%sOn" % stem, str(word["on_name"]), ACEDescriptor.ACEType.ACTION,
			"%s = true" % property, "", [], CAT, str(word["on_verb"]), host)
			.described(_about(word, row)).featured(),
		F.make_descriptor("Core", "Light%sOff" % stem, str(word["off_name"]), ACEDescriptor.ACEType.ACTION,
			"%s = false" % property, "", [], CAT, str(word["off_verb"]), host)
			.described(_about(word, row)),
		F.make_descriptor("Core", "LightIs%s" % stem, str(word["asks"]), ACEDescriptor.ACEType.CONDITION,
			property, "", [], CAT, str(word["ask_verb"]), host)
			.described("True while %s. Reads %s." % [str(word["ask_verb"]).to_lower(), _echo(row)])
	]


## What a row does, said once for every row of a word: the word, then the property this particular
## light class answers to, so the description and the code echo can never disagree.
static func _about(word: Dictionary, row: Dictionary) -> String:
	return "%s Writes %s." % [str(word["about"]), _echo(row)]


## The property a row writes, as the reader sees it in the code echo.
static func _echo(row: Dictionary) -> String:
	return "`%s.%s`" % [str(row["host"]), str(row["property"])]


## The value a row starts on: the ENGINE's own default for that property, asked of the factory (which
## asks ClassDB, and rounds the float32 the answer arrives widened from) rather than guessed. A
## light's brightness starts at 1.0 because that is where Godot starts it, and an omni light's reach
## at 5.0 for the same reason.
static func _default_of(row: Dictionary) -> String:
	return F.default_literal(str(row["classes"][0]), str(row["property"]))
