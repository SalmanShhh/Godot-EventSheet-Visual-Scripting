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
					W.KIND_CHOICE:
						descriptors.append_array(_choice_rows(word, row))
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
		F.act("LightSet%s" % stem, str(word["name"]), "%s = {value}" % property, CAT, str(word["verb"]), _about(word, row), host).param_typed("String", "value", initial, str(word["word"]).capitalize(), str(word["about"]), "expression"),
		F.expr("Light%s" % stem, str(word["word"]).capitalize(), property, CAT, str(word["reads"]), "Reads %s back: %s. Use it in any value field." % [str(word["word"]), _echo(row)], host)
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
		F.act("LightSet%s" % stem, str(word["name"]), "%s = {value}" % str(row["property"]), CAT, str(word["verb"]), _about(word, row), str(row["host"])).param_typed("Color", "value", _default_of(row), str(word["word"]).capitalize(), str(word["about"]), "color"),
		F.expr("Light%s" % stem, str(word["word"]).capitalize(), str(row["property"]), CAT, str(word["reads"]), "Reads the light's %s back: %s. Use it in any value field." % [str(word["word"]), _echo(row)], str(row["host"]))
	]


## A word that is one of a FIXED LIST of engine constants: the Set row with a dropdown, and the
## expression that reads it back. No fade - there is nothing between add and subtract to walk
## through - and no engine default asked for either, because ClassDB answers a choice property with
## the integer the enum really is and a dropdown whose keys are constants cannot open on `0`. The
## table writes the constant that integer names, which is still the engine's own value.
##
## `display_option_labels` is what makes the ROW read "Blend light as add" instead of "Blend light as
## Light2D.BLEND_MODE_ADD": the KEY is still the constant (it is what the template writes and what
## every saved row holds, both frozen), and only the word a reader sees changes.
static func _choice_rows(word: Dictionary, row: Dictionary) -> Array[ACEDescriptor]:
	var stem: String = str(row["id_stem"])
	var chosen: ACEParam = F.make_param("value", "String", str(word["default"]),
		str(word.get("label", str(word["word"]).capitalize())), str(word["about"]), "",
		word["choices"] as Array)
	chosen.display_option_labels = true
	return [
		F.act("LightSet%s" % stem, str(word["name"]), "%s = {value}" % str(row["property"]), CAT, str(word["verb"]), _about(word, row), str(row["host"])).param_built(chosen),
		F.expr("Light%s" % stem, str(word["name"]).trim_prefix("Set "), str(row["property"]), CAT, str(word["reads"]), "Reads the light's %s back: %s. Use it in any value field." % [str(word["word"]), _echo(row)], str(row["host"]))
	]


## A word that is ON or OFF: two actions that say which, and the condition that asks. Two actions
## rather than one with a true/false field, because "Turn off" is the sentence a reader writes and
## "Set lit false" is the one they have to decode.
static func _switch_rows(word: Dictionary, row: Dictionary) -> Array[ACEDescriptor]:
	var stem: String = str(row["id_stem"])
	var property: String = str(row["property"])
	var host: String = str(row["host"])
	return [
		F.act("Light%sOn" % stem, str(word["on_name"]), "%s = true" % property, CAT, str(word["on_verb"]), _about(word, row), host).featured(),
		F.act("Light%sOff" % stem, str(word["off_name"]), "%s = false" % property, CAT, str(word["off_verb"]), _about(word, row), host),
		F.cond("LightIs%s" % stem, str(word["asks"]), property, CAT, str(word["ask_verb"]), "True while %s. Reads %s." % [str(word["ask_verb"]).to_lower(), _echo(row)], host)
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
	descriptors.append(F.act("SetLightEnergy", "Set Light Energy (2D)", "{node}.energy = {value}", CAT, "Set light energy to {value}", "Sets how bright a 2D light is. The row shows the fraction as a percentage.").param("node", "$PointLight2D", "Light", "The 2D light to change.", "expression").param_typed("float", "value", "1.0", "Energy", "How bright, as a fraction: 0.5 is half, 2.0 is double.", "expression").featured())
	descriptors.append(F.act("SetLightColour", "Set Light Colour (2D)", "{node}.color = {colour}", CAT, "Set light colour to {colour}", "Sets the colour a 2D light casts.").param("node", "$PointLight2D", "Light", "The 2D light to change.", "expression").param_typed("Color", "colour", "Color.WHITE", "Colour", "The colour the light casts.", "color"))
	descriptors.append(F.act("SetLightEnabled", "Set Light On/Off", "{node}.enabled = {on}", CAT, "Set light {on}", "Switches a 2D light on or off. Different from hiding the node, which also hides its children.").param("node", "$PointLight2D", "Light", "The 2D light to switch.", "expression").param_built(_on_off_param("Whether the light is lit. Off is different from hiding the node, which also hides its children.")))
	descriptors.append(F.act("SetLightShadows", "Set Shadows On/Off", "{node}.shadow_enabled = {on}", CAT, "Set shadows {on}", "Turns a light's shadows on or off - the cheapest lighting switch there is.").param("node", "$PointLight2D", "Light", "The light to change.", "expression").param_built(_on_off_param("Whether the light casts shadows.")))

	# ── 3D lights ──
	descriptors.append(F.act("SetLightEnergy3D", "Set Light Energy (3D)", "{node}.light_energy = {value}", CAT, "Set light energy to {value}", "Sets how bright a 3D light is. The row shows the fraction as a percentage.").param("node", "$DirectionalLight3D", "Light", "The 3D light to change.", "expression").param_typed("float", "value", "1.0", "Energy", "How bright, as a fraction: 0.5 is half, 2.0 is double.", "expression"))
	descriptors.append(F.act("SetLightColour3D", "Set Light Colour (3D)", "{node}.light_color = {colour}", CAT, "Set light colour to {colour}", "Sets the colour a 3D light casts - the one knob that turns midday into sunset.").param("node", "$DirectionalLight3D", "Light", "The 3D light to change.", "expression").param_typed("Color", "colour", "Color.WHITE", "Colour", "The colour the light casts.", "color"))

	# ── The whole layout ──
	descriptors.append(F.act("SetLayerTint", "Set Layer Tint", "{node}.color = {colour}", CAT, "Set layer tint to {colour}", "Tints a whole 2D layer at once - the one row that makes a level read as night.").param("node", "$CanvasModulate", "Canvas modulate", "The CanvasModulate node that tints the layer.", "expression").param_typed("Color", "colour", "Color(0.2, 0.2, 0.4)", "Colour", "The tint laid over everything on the layer.", "color").featured())
	descriptors.append(F.act("SetAmbientLight", "Set Ambient Light", "{node}.environment.ambient_light_energy = {value}", CAT, "Set ambient light to {value}", "Sets how much light a 3D scene has with no light shining on it.").param("node", "$WorldEnvironment", "World environment", "The WorldEnvironment node holding the environment.", "expression").param_typed("float", "value", "0.3", "Energy", "How much light everything gets regardless of the lights, as a fraction.", "expression"))

	# ── the Environment: fog, glow, ambient occlusion and the sky ───────
	#
	# The world's LOOK, which belongs to no node a reader can point at, so every row here takes the
	# environment itself. Each template writes the exact shape the Environment reading recognises, so
	# a mood set from the picker and one typed by hand are the same bytes and read as the same rows.
	descriptors.append(F.act("SetFog", "Set Fog On/Off", "{env}.fog_enabled = {on}", ENV_CAT, "Set fog {on}", "Switches the world's fog on or off - the one row that turns a clear day into a misty one.").param_typed("String", "env", ENV, "Environment", "The environment whose look is being changed.", "expression").param_built(F.make_param("on", "bool", "true", "On", "Whether the world has fog at all.", "", ["true", "false"])).featured())
	descriptors.append(F.act("SetFogDensity", "Set Fog Density", "{env}.fog_density = {value}", ENV_CAT, "Set fog thickness to {value}", "Sets how thick the world's fog is. Ramp it up over time for a storm rolling in.").param_typed("String", "env", ENV, "Environment", "The environment whose look is being changed.", "expression").param("value", "0.02", "Density", "How thick the fog is. Small numbers: 0.01 is a haze, 0.1 is a wall.", "expression"))
	descriptors.append(F.act("SetFogColour", "Set Fog Colour", "{env}.fog_light_color = {colour}", ENV_CAT, "Set fog colour to {colour}", "Sets the colour of the world's fog - dusk purple, underwater green, dust orange.").param_typed("String", "env", ENV, "Environment", "The environment whose look is being changed.", "expression").param_typed("Color", "colour", "Color(0.7, 0.6, 0.8)", "Colour", "The colour the fog picks up from the light.", "color"))
	descriptors.append(F.act("SetGlow", "Set Glow On/Off", "{env}.glow_enabled = {on}", ENV_CAT, "Set glow {on}", "Switches the world's glow on or off - what makes neon, fire and magic read as bright.").param_typed("String", "env", ENV, "Environment", "The environment whose look is being changed.", "expression").param_built(F.make_param("on", "bool", "true", "On", "Whether bright things bleed light into what is around them.", "", ["true", "false"])))
	descriptors.append(F.act("SetGlowStrength", "Set Glow Strength", "{env}.glow_intensity = {value}", ENV_CAT, "Set glow strength to {value}", "Sets how strongly bright things glow. Push it up for a boss room, back down when the fight ends.").param_typed("String", "env", ENV, "Environment", "The environment whose look is being changed.", "expression").param("value", "0.4", "Strength", "How much bright things bleed. Around 1 is strong.", "expression"))
	descriptors.append(F.act("SetAmbientOcclusion", "Set Ambient Occlusion On/Off", "{env}.ssao_enabled = {on}", ENV_CAT, "Set ambient occlusion {on}", "Darkens the corners and creases of a 3D scene, which is what makes it look solid. Costs frames - turn it off on weak machines.").param_typed("String", "env", ENV, "Environment", "The environment whose look is being changed.", "expression").param_built(F.make_param("on", "bool", "true", "On", "Whether corners and creases are darkened.", "", ["true", "false"])))
	descriptors.append(F.act("SetSkyRotation", "Set Sky Rotation", "{env}.sky_rotation = {value}", ENV_CAT, "Set sky rotation to {value}", "Turns the sky. Advance it slowly every tick and the clouds drift.").param("value", "Vector3(0.0, 0.0, 0.0)", "Rotation", "How the sky is turned, in radians on each axis.", "expression").param_typed("String", "env", ENV, "Environment", "The environment whose look is being changed.", "expression"))
