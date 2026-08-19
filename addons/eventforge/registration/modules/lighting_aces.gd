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


static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []

	# ── 2D lights ──
	descriptors.append(F.make_descriptor("Core", "SetLightEnergy", "Set Light Energy (2D)", ACEDescriptor.ACEType.ACTION, "{node}.energy = {value}", "", [F.make_param("node", "String", "$PointLight2D", "Light", "The 2D light to change.", "expression"), F.make_param("value", "float", "1.0", "Energy", "How bright, as a fraction: 0.5 is half, 2.0 is double.", "expression")], CAT, "Set light energy to {value}")
		.described("Sets how bright a 2D light is. The row shows the fraction as a percentage.").featured())
	descriptors.append(F.make_descriptor("Core", "SetLightColour", "Set Light Colour (2D)", ACEDescriptor.ACEType.ACTION, "{node}.color = {colour}", "", [F.make_param("node", "String", "$PointLight2D", "Light", "The 2D light to change.", "expression"), F.make_param("colour", "Color", "Color.WHITE", "Colour", "The colour the light casts.", "color")], CAT, "Set light colour to {colour}")
		.described("Sets the colour a 2D light casts."))
	descriptors.append(F.make_descriptor("Core", "SetLightEnabled", "Set Light On/Off", ACEDescriptor.ACEType.ACTION, "{node}.enabled = {on}", "", [F.make_param("node", "String", "$PointLight2D", "Light", "The 2D light to switch.", "expression"), F.make_param("on", "bool", "true", "On", "false turns the light off without hiding the node.", "", ["true", "false"])], CAT, "Set light {on}")
		.described("Switches a 2D light on or off. Different from hiding the node, which also hides its children."))
	descriptors.append(F.make_descriptor("Core", "SetLightShadows", "Set Shadows On/Off", ACEDescriptor.ACEType.ACTION, "{node}.shadow_enabled = {on}", "", [F.make_param("node", "String", "$PointLight2D", "Light", "The light to change.", "expression"), F.make_param("on", "bool", "true", "On", "Whether the light casts shadows.", "", ["true", "false"])], CAT, "Set shadows {on}")
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

	return descriptors
