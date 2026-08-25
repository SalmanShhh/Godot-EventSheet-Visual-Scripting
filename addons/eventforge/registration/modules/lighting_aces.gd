# EventForge module - lights, layer tint and the world's ambient light.
#
# The six knobs a game actually touches at run time: how bright a light is, what colour it is,
# whether it is on, whether it casts shadows, the tint over a whole 2D layer, and how much ambient
# light the world has. Godot spells brightness `energy` on a 2D light and `light_energy` on a 3D one,
# which is why each of those two is its own row rather than one row that guesses.
#
# Every template writes the shape the reading recognises, so a light set from a hand-written line and
# a light set from the picker are the same bytes and read as the same row.
@tool
class_name EventForgeLightingACEs
extends RefCounted

const F := preload("res://addons/eventforge/registration/ace_factory.gd")

const CAT := "Lighting"

## The world's LOOK is its own section of the picker: fog, glow, ambient occlusion and the sky
## belong to the environment rather than to any light a reader can point at.
const ENV_CAT := "Environment"

## Where the environment lives in a scene that has a WorldEnvironment node - the default every
## environment row starts from, and the exact spelling the Environment reading recognises.
const ENV := "$WorldEnvironment.environment"


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


static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []

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

	return descriptors
