# EventForge module - the Lighting vocabulary: lights, the world's look, and the light as an object.
#
# TWO WAYS TO SAY THE SAME THING, ON PURPOSE, and this file holds both, so that "Lighting" is one
# vocabulary in one place rather than a picker section split across two files that have to be read
# together to be understood.
#
# THE LIGHT AS THE OBJECT. The first rows are node-scoped: the light sits in the object column and
# the row says the word - "Torch - Set brightness to 1.2" - while the code echo shows the property
# that light really has. Nothing there is written twice. The words come from EventForgeLightWords,
# which asks ClassDB which spelling each light class answers to, and every row of every word is
# built by one of the three builders below (a value, a colour, a switch). A light class the engine
# adds, or a project's own subclass of one, resolves through the same map with nothing added here.
#
# THE LIGHT AS A PARAMETER. The Core lighting actions after them take the light as their first
# parameter, so a row reads "Set light energy to 1.0" and which light that is lives two clicks away.
# They are the knobs a game touches at run time: how bright a light is, what colour it is, whether
# it is on, whether it casts shadows, the tint over a whole 2D layer, and how much ambient light the
# world has. Godot spells brightness `energy` on a 2D light and `light_energy` on a 3D one, which is
# why each of those two is its own row rather than one row that guesses. Their ace_ids and templates
# are frozen API - a sheet saved with one of them opens with it - so the node-scoped rows are NEW
# ids beside them, never replacements.
#
# THE WORLD'S LOOK is the third section: fog, glow, ambient occlusion and the sky belong to the
# environment rather than to any light a reader can point at, so those rows take the environment
# itself and are filed under their own picker category.
#
# Every template writes the shape the reading recognises, so a light set from a hand-written line
# and a light set from the picker are the same bytes and read as the same row.
# Module contract: see ace_factory.gd - ace_ids/templates are API (compatibility covenant).
@tool
class_name EventForgeLightingACEs
extends RefCounted

const F := preload("res://addons/eventforge/registration/ace_factory.gd")
const W := preload("res://addons/eventforge/registration/light_words.gd")

## The picker category every light row is filed under, node-scoped and parameter-taking alike, so
## "Lighting" is one section of the vocabulary rather than two. It also keeps the node-scoped rows
## out of the reverse index (see ace_lifter's excluded categories), which is deliberate: a light row
## is only lifted when the attached scene says the node really is a light, and that gate lives in
## lighting_lift.gd rather than in a template match that would claim any `.enabled = false` line.
const CAT := "Lighting"

## The world's LOOK is its own section of the picker: fog, glow, ambient occlusion and the sky
## belong to the environment rather than to any light a reader can point at.
const ENV_CAT := "Environment"

## Where the environment lives in a scene that has a WorldEnvironment node - the default every
## environment row starts from, and the exact spelling the Environment reading recognises.
const ENV := "$WorldEnvironment.environment"

## How long a fade takes when nobody says - half a second, which is the length a light change reads
## as deliberate rather than as a flicker.
const DEFAULT_FADE_SECONDS := "0.5"


## The node-scoped rows first, then the ones that take the light as a parameter. That is the order
## the two halves registered in while they were two files, and registry order breaks ties in the
## reverse-lifter, so it is kept exactly.
static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []
	_append_light_as_object(descriptors)
	_append_light_as_parameter(descriptors)
	return descriptors


## Every word of every light class, in both dimensions - the light in the object column.
static func _append_light_as_object(descriptors: Array[ACEDescriptor]) -> void:
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


## The on/off dropdown the two light switches share. `display_option_labels` is what makes the
## ROW read "Set light off" instead of "Set light false": the KEY is still `true`/`false` (it is what
## the template writes and what every saved row holds, both frozen), and only the word a reader sees
## changes. The same two words the reading already gives a hand-written `enabled = false`, so a
## picked row and a typed line say the same thing.
static func _on_off_param(description: String) -> ACEParam:
	var parameter: ACEParam = F.make_param("on", "bool", "true", "On", description, "",
		[{"key": "true", "label": "on"}, {"key": "false", "label": "off"}])
	parameter.display_option_labels = true
	return parameter


## The lights that take their light as a parameter, then the whole layout, then the world's look.
static func _append_light_as_parameter(descriptors: Array[ACEDescriptor]) -> void:
	# ── 2D lights ──
	descriptors.append(F.make_descriptor("Core", "SetLightEnergy", "Set Light Energy (2D)", ACEDescriptor.ACEType.ACTION, "{node}.energy = {value}", "", [F.make_param("node", "String", "$PointLight2D", "Light", "The 2D light to change.", "expression"), F.make_param("value", "float", "1.0", "Energy", "How bright, as a fraction: 0.5 is half, 2.0 is double.", "expression")], CAT, "Set light energy to {value}")
		.described("Sets how bright a 2D light is. The row shows the fraction as a percentage.").featured())
	descriptors.append(F.make_descriptor("Core", "SetLightColour", "Set Light Colour (2D)", ACEDescriptor.ACEType.ACTION, "{node}.color = {colour}", "", [F.make_param("node", "String", "$PointLight2D", "Light", "The 2D light to change.", "expression"), F.make_param("colour", "Color", "Color.WHITE", "Colour", "The colour the light casts.", "color")], CAT, "Set light colour to {colour}")
		.described("Sets the colour a 2D light casts."))
	descriptors.append(F.make_descriptor("Core", "SetLightEnabled", "Set Light On/Off", ACEDescriptor.ACEType.ACTION, "{node}.enabled = {on}", "", [F.make_param("node", "String", "$PointLight2D", "Light", "The 2D light to switch.", "expression"), _on_off_param("Whether the light is lit. Off is different from hiding the node, which also hides its children.")], CAT, "Set light {on}")
		.described("Switches a 2D light on or off. Different from hiding the node, which also hides its children."))
	descriptors.append(F.make_descriptor("Core", "SetLightShadows", "Set Shadows On/Off", ACEDescriptor.ACEType.ACTION, "{node}.shadow_enabled = {on}", "", [F.make_param("node", "String", "$PointLight2D", "Light", "The light to change.", "expression"), _on_off_param("Whether the light casts shadows.")], CAT, "Set shadows {on}")
		.described("Turns a light's shadows on or off - the cheapest lighting switch there is."))

	# ── 3D lights ──
	descriptors.append(F.make_descriptor("Core", "SetLightEnergy3D", "Set Light Energy (3D)", ACEDescriptor.ACEType.ACTION, "{node}.light_energy = {value}", "", [F.make_param("node", "String", "$DirectionalLight3D", "Light", "The 3D light to change.", "expression"), F.make_param("value", "float", "1.0", "Energy", "How bright, as a fraction: 0.5 is half, 2.0 is double.", "expression")], CAT, "Set light energy to {value}")
		.described("Sets how bright a 3D light is. The row shows the fraction as a percentage."))
	descriptors.append(F.make_descriptor("Core", "SetLightColour3D", "Set Light Colour (3D)", ACEDescriptor.ACEType.ACTION, "{node}.light_color = {colour}", "", [F.make_param("node", "String", "$DirectionalLight3D", "Light", "The 3D light to change.", "expression"), F.make_param("colour", "Color", "Color.WHITE", "Colour", "The colour the light casts.", "color")], CAT, "Set light colour to {colour}")
		.described("Sets the colour a 3D light casts - the one knob that turns midday into sunset."))

	# ── The whole layout ──
	descriptors.append(F.make_descriptor("Core", "SetLayerTint", "Set Layer Tint", ACEDescriptor.ACEType.ACTION, "{node}.color = {colour}", "", [F.make_param("node", "String", "$CanvasModulate", "Canvas modulate", "The CanvasModulate node that tints the layer.", "expression"), F.make_param("colour", "Color", "Color(0.2, 0.2, 0.4)", "Colour", "The tint laid over everything on the layer.", "color")], CAT, "Set layer tint to {colour}")
		.described("Tints a whole 2D layer at once - the one row that makes a level read as night.").featured())
	descriptors.append(F.make_descriptor("Core", "SetAmbientLight", "Set Ambient Light", ACEDescriptor.ACEType.ACTION, "{node}.environment.ambient_light_energy = {value}", "", [F.make_param("node", "String", "$WorldEnvironment", "World environment", "The WorldEnvironment node holding the environment.", "expression"), F.make_param("value", "float", "0.3", "Energy", "How much light everything gets regardless of the lights, as a fraction.", "expression")], CAT, "Set ambient light to {value}")
		.described("Sets how much light a 3D scene has with no light shining on it."))

	# ── the Environment: fog, glow, ambient occlusion and the sky ───────
	#
	# The world's LOOK, which belongs to no node a reader can point at, so every row here takes the
	# environment itself. Each template writes the exact shape the Environment reading recognises, so
	# a mood set from the picker and one typed by hand are the same bytes and read as the same rows.
	descriptors.append(F.make_descriptor("Core", "SetFog", "Set Fog On/Off", ACEDescriptor.ACEType.ACTION,
		"{env}.fog_enabled = {on}", "",
		[F.make_param("env", "String", ENV, "Environment", "The environment whose look is being changed.", "expression"),
			F.make_param("on", "bool", "true", "On", "Whether the world has fog at all.", "", ["true", "false"])],
		ENV_CAT, "Set fog {on}")
		.described("Switches the world's fog on or off - the one row that turns a clear day into a misty one.").featured())
	descriptors.append(F.make_descriptor("Core", "SetFogDensity", "Set Fog Density", ACEDescriptor.ACEType.ACTION,
		"{env}.fog_density = {value}", "",
		[F.make_param("env", "String", ENV, "Environment", "The environment whose look is being changed.", "expression"),
			F.make_param("value", "String", "0.02", "Density", "How thick the fog is. Small numbers: 0.01 is a haze, 0.1 is a wall.", "expression")],
		ENV_CAT, "Set fog thickness to {value}")
		.described("Sets how thick the world's fog is. Ramp it up over time for a storm rolling in."))
	descriptors.append(F.make_descriptor("Core", "SetFogColour", "Set Fog Colour", ACEDescriptor.ACEType.ACTION,
		"{env}.fog_light_color = {colour}", "",
		[F.make_param("env", "String", ENV, "Environment", "The environment whose look is being changed.", "expression"),
			F.make_param("colour", "Color", "Color(0.7, 0.6, 0.8)", "Colour", "The colour the fog picks up from the light.", "color")],
		ENV_CAT, "Set fog colour to {colour}")
		.described("Sets the colour of the world's fog - dusk purple, underwater green, dust orange."))
	descriptors.append(F.make_descriptor("Core", "SetGlow", "Set Glow On/Off", ACEDescriptor.ACEType.ACTION,
		"{env}.glow_enabled = {on}", "",
		[F.make_param("env", "String", ENV, "Environment", "The environment whose look is being changed.", "expression"),
			F.make_param("on", "bool", "true", "On", "Whether bright things bleed light into what is around them.", "", ["true", "false"])],
		ENV_CAT, "Set glow {on}")
		.described("Switches the world's glow on or off - what makes neon, fire and magic read as bright."))
	descriptors.append(F.make_descriptor("Core", "SetGlowStrength", "Set Glow Strength", ACEDescriptor.ACEType.ACTION,
		"{env}.glow_intensity = {value}", "",
		[F.make_param("env", "String", ENV, "Environment", "The environment whose look is being changed.", "expression"),
			F.make_param("value", "String", "0.4", "Strength", "How much bright things bleed. Around 1 is strong.", "expression")],
		ENV_CAT, "Set glow strength to {value}")
		.described("Sets how strongly bright things glow. Push it up for a boss room, back down when the fight ends."))
	descriptors.append(F.make_descriptor("Core", "SetAmbientOcclusion", "Set Ambient Occlusion On/Off", ACEDescriptor.ACEType.ACTION,
		"{env}.ssao_enabled = {on}", "",
		[F.make_param("env", "String", ENV, "Environment", "The environment whose look is being changed.", "expression"),
			F.make_param("on", "bool", "true", "On", "Whether corners and creases are darkened.", "", ["true", "false"])],
		ENV_CAT, "Set ambient occlusion {on}")
		.described("Darkens the corners and creases of a 3D scene, which is what makes it look solid. Costs frames - turn it off on weak machines."))
	descriptors.append(F.make_descriptor("Core", "SetSkyRotation", "Set Sky Rotation", ACEDescriptor.ACEType.ACTION,
		"{env}.sky_rotation = {value}", "",
		[F.make_param("value", "String", "Vector3(0.0, 0.0, 0.0)", "Rotation", "How the sky is turned, in radians on each axis.", "expression"),
			F.make_param("env", "String", ENV, "Environment", "The environment whose look is being changed.", "expression")],
		ENV_CAT, "Set sky rotation to {value}")
		.described("Turns the sky. Advance it slowly every tick and the clouds drift."))
