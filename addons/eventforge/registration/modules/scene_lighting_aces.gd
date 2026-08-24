# EventForge module - L4/L6: the two lighting objects that are not lights.
#
# A lit scene has three kinds of node in it. The lights themselves are the object of their own rows
# (light_node_aces.gd beside this file). The other two are here:
#
#   DARKNESS is a CanvasModulate. Godot stores it as a colour multiplied over everything on the
#   layer, which is exactly right and says nothing: `Color(0.3, 0.3, 0.36)` does not tell a reader
#   how dark the cave feels. So the row STORES the colour - all Godot stores, and what a re-save
#   writes back byte for byte - and READS as the percentage it means, through the darkness lens.
#
#   THE WORLD is a WorldEnvironment. The sixteen Core environment actions beside this file take the
#   environment as their first parameter, so the object column says Core and the node lives two
#   clicks away; these are node-scoped, so the column says World and the row says the word.
#
# The sixteen Core actions are untouched and keep compiling: their ace_ids and templates are frozen
# API. These are new ids beside them.
#
# THE ONE ROW THAT IS NOT A KNOB: "Make the environment this scene's own". A WorldEnvironment
# usually points at a `.tres`, and a `.tres` is shared - so writing fog at run time writes it for
# every other scene that loads the same file, and the change follows the player out of the room.
# `environment = environment.duplicate()` is the engine's own answer, and this is the row that says
# it (the head's `environment` band is where a reader finds out they need it).
@tool
class_name EventForgeSceneLightingACEs
extends RefCounted

const F := preload("res://addons/eventforge/registration/ace_factory.gd")

## The picker category, shared with the lights and the sixteen Core lighting actions so "Lighting"
## is one section of the vocabulary rather than three. It also keeps these rows out of the reverse
## index (see ace_lifter's excluded categories), which is deliberate: `$Level.color = ...` is only a
## darkness row when the attached scene says Level is a CanvasModulate, and that gate lives in
## lighting_lift.gd rather than in a template match that would claim every `.color =` line there is.
const CAT := "Lighting"

## The two nodes this file speaks for.
const DARKNESS_HOST := "CanvasModulate"
const WORLD_HOST := "WorldEnvironment"

## The resource the World rows really write through - the member every one of their templates opens
## with, and the one the Core environment actions name in full as `$WorldEnvironment.environment`.
const ENVIRONMENT_MEMBER := "environment"

## How long a fade takes when nobody says. Half a second reads as deliberate rather than as a
## flicker; a darkness fade is usually a scene change, so it is given longer.
const DEFAULT_FADE_SECONDS := "0.5"
const DEFAULT_DARKNESS_SECONDS := "2.0"

## What a scene starts at when a reader drops a darkness row in: a night blue that reads as 82%
## dark - dark enough to be night, light enough to still see the level through. (The reading is the
## engine's own luminance, which counts green for most of what an eye calls brightness, so a blue
## this deep reads darker than its numbers look.)
const DEFAULT_DARKNESS := "Color(0.15, 0.18, 0.3)"


static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []
	descriptors.append_array(_darkness_rows())
	descriptors.append_array(_world_rows())
	return descriptors


## L4 - the darkness pair. Both rows store a COLOUR and read as a percentage: the set row says the
## tint as well, because that is the whole row, and the fade row leaves it off, because the row is
## already about where the darkness is going rather than what colour it is.
static func _darkness_rows() -> Array[ACEDescriptor]:
	var tint: ACEParam = F.make_param("value", "Color", DEFAULT_DARKNESS, "Darkness",
		"How dark the layer goes, and what colour the dark is. The row shows the percentage; the file keeps the colour.",
		"color")
	tint.display_lens = EventForgeValueLens.LENS_DARKNESS
	var faded_tint: ACEParam = F.make_param("value", "Color", "Color(0.1, 0.1, 0.15)", "Darkness",
		"The darkness to arrive at.", "color")
	faded_tint.display_lens = EventForgeValueLens.LENS_DARKNESS_PERCENT
	return [
		F.make_descriptor("Core", "DarknessSet", "Set Darkness", ACEDescriptor.ACEType.ACTION,
			"color = {value}", "", [tint], CAT, "Set darkness to {value}", DARKNESS_HOST)
			.described("Darkens a whole 2D layer at once - the one row that makes a level read as night. Writes `CanvasModulate.color`; the row reads the colour back as how dark it makes the layer.")
			.featured(),
		F.make_descriptor("Core", "DarknessFade", "Fade Darkness", ACEDescriptor.ACEType.ACTION,
			"create_tween().tween_property({target}, \"color\", {value}, {seconds})", "",
			[_target_param("The darkness to fade. Leave it as self to fade the CanvasModulate this sheet is on."),
				faded_tint,
				F.make_param("seconds", "String", DEFAULT_DARKNESS_SECONDS, "Seconds",
					"How long the fade takes.", "expression")],
			CAT, "Fade darkness to {value} over {seconds} s", DARKNESS_HOST)
			.described("Walks the layer's darkness to a new value over time instead of jumping to it - one tween, no state to keep. Dusk, a cave mouth closing, a light going out.")
			.featured()
	]


## L6 - the World rows. Every one of them writes a property of the ENVIRONMENT the scene's
## WorldEnvironment holds, which is why each template opens with the member rather than naming a
## node: the node is the row's object.
static func _world_rows() -> Array[ACEDescriptor]:
	return [
		_world_switch("WorldFogOn", "Turn Fog On", "fog_enabled", true, "Turn fog on",
			"Switches the world's fog on - the one row that turns a clear day into a misty one."),
		_world_switch("WorldFogOff", "Turn Fog Off", "fog_enabled", false, "Turn fog off",
			"Switches the world's fog off again."),
		_world_switch("WorldGlowOn", "Turn Glow On", "glow_enabled", true, "Turn glow on",
			"Switches the world's glow on - what makes neon, fire and magic read as bright."),
		_world_switch("WorldGlowOff", "Turn Glow Off", "glow_enabled", false, "Turn glow off",
			"Switches the world's glow off again - and gives the frames back."),
		_world_value("WorldSetFogThickness", "Set Fog Thickness", "fog_density", "Thickness",
			"How thick the fog is. Small numbers: 0.01 is a haze, 0.1 is a wall.",
			"Set fog thickness to {value}",
			"Sets how thick the world's fog is. Ramp it up over time for a storm rolling in."),
		_world_value("WorldSetAmbientLight", "Set Ambient Light", "ambient_light_energy", "Light",
			"How much light everything gets regardless of the lights, as a fraction.",
			"Set ambient light to {value}",
			"Sets how much light the scene has with no light shining on it - the floor under every other light."),
		F.make_descriptor("Core", "WorldFadeGlow", "Fade The Glow", ACEDescriptor.ACEType.ACTION,
			"create_tween().tween_property({target}.%s, \"glow_intensity\", {value}, {seconds})" % ENVIRONMENT_MEMBER,
			"", [_target_param("The WorldEnvironment to fade. Leave it as self to fade the one this sheet is on."),
				F.make_param("value", "String", _environment_default("glow_intensity"), "Strength",
					"How much bright things bleed by the end. Around 1 is strong.", "expression"),
				F.make_param("seconds", "String", DEFAULT_FADE_SECONDS, "Seconds",
					"How long the fade takes.", "expression")],
			CAT, "Fade the glow to {value} over {seconds} s", WORLD_HOST)
			.described("Walks the world's glow to a new strength over time - a boss room brightening, a spell fading out. One tween, no state to keep.")
			.featured(),
		F.make_descriptor("Core", "WorldOwnEnvironment", "Make The Environment This Scene's Own",
			ACEDescriptor.ACEType.ACTION,
			"{target.}%s = {target.}%s.duplicate()" % [ENVIRONMENT_MEMBER, ENVIRONMENT_MEMBER], "",
			[F.make_param("target", "String", "", "On node",
				"The WorldEnvironment to give its own copy. Leave it blank for this node.", "expression")],
			CAT, "Make the environment this scene's own", WORLD_HOST)
			.described("Gives this scene its own copy of the environment before anything changes it. Without it, every fog or glow row written at run time changes the shared `.tres` file, so the change follows the player into every other scene that loads it.")
	]


## One environment switch: on and off are two rows, because "Turn fog off" is the sentence a reader
## writes and "Set fog false" is the one they have to decode.
static func _world_switch(ace_id: String, display_name: String, property: String, turned_on: bool,
		verb: String, about: String) -> ACEDescriptor:
	return F.make_descriptor("Core", ace_id, display_name, ACEDescriptor.ACEType.ACTION,
		"%s.%s = %s" % [ENVIRONMENT_MEMBER, property, "true" if turned_on else "false"], "",
		[], CAT, verb, WORLD_HOST) \
		.described("%s Writes `Environment.%s`." % [about, property])


## One environment knob that carries a number. Its starting value is the ENGINE's own default for
## that property, asked of ClassDB rather than guessed.
static func _world_value(ace_id: String, display_name: String, property: String, field: String,
		field_about: String, verb: String, about: String) -> ACEDescriptor:
	return F.make_descriptor("Core", ace_id, display_name, ACEDescriptor.ACEType.ACTION,
		"%s.%s = {value}" % [ENVIRONMENT_MEMBER, property], "",
		[F.make_param("value", "String", _environment_default(property), field, field_about, "expression")],
		CAT, verb, WORLD_HOST) \
		.described("%s Writes `Environment.%s`." % [about, property])


## The "On node" param the two FADE rows carry themselves. A tween's target is an ARGUMENT of the
## call rather than its receiver - `create_tween()` belongs to the node running the sheet - so these
## rows are left alone by the node-scoped transform and answer for their own target.
static func _target_param(about: String) -> ACEParam:
	return F.make_param("target", "String", "self", "On node", about, "expression")


## One Environment property's engine default, as the text a row starts on. Asked through the factory
## rather than of ClassDB directly, because the answer arrives as a float32 widened to a double and a
## row must not open on `0.00999999977648` when the engine's own number is a hundredth.
static func _environment_default(property: String) -> String:
	return F.default_literal("Environment", property)
