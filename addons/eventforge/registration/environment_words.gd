# EventForge - the ENVIRONMENT WORDS: what the whole world looks like, and the property each one
# really is.
#
# A scene's LOOK lives on one Environment resource with well over a hundred properties on it, and
# the words below are the ones a game reaches for while it runs: how colourful the picture is, how
# bright, how much light the camera lets in, how the fog sits on the floor, how thick the air is,
# whether the shiny surfaces reflect the room, and which sky is behind everything. Godot spells the
# picture's brightness `adjustment_brightness` and does nothing with it until `adjustment_enabled`
# is true; it spells the fog's floor `fog_height` and does nothing with it until `fog_enabled` is
# true. A reader should not have to know that, and a row should never guess it.
#
# So the mapping is DERIVED, exactly the way the light words and the material words are. The table
# says only what the WORDS are and which spellings each word can take, in preference order; which of
# those spellings Environment actually answers to is asked of ClassDB, and so is the value each row
# opens on. Add a spelling and the rows resolve themselves.
#
# THE ONE THING THAT IS NOT DERIVED is the `ace_id` stem beside each spelling, and it cannot be: an
# ace_id is a compatibility promise (a sheet saved today names it forever), so it is written down
# once, frozen, and never computed from a property name the engine could rename under it.
#
# THE OWN-IT COURTESY, and why it is in the template rather than in a row of its own. An Environment
# is a FILE, and two scenes pointing at the same `.tres` are pointing at ONE object: turning the fog
# up in the cave turns it up in the town as well, and the change follows the player out of the room.
# So every write below is preceded by the lines that give this scene its own copy first - a plain
# Environment when the node is holding nothing, and a duplicate of whatever it is holding when that
# came from a file. A copy taken once has no `resource_path` of its own, which is what makes a row
# that runs every frame take one copy and not sixty. The frozen "Make The Environment This Scene's
# Own" row stays exactly what it was: it is still the right row for a reader who wants the copy
# taken at a moment they choose, and these rows simply never depend on it having been used.
#
# WHAT ONLY WORKS ON FORWARD+, said out loud. Screen-space reflections, indirect light, global
# illumination and volumetric fog are Forward+ features: on Mobile and on Compatibility the flag is
# set, the renderer ignores it, and nothing errors. Every row of those words says so in its own
# words, and the Doctor's ship-it section says it once more for a project whose rendering method is
# not Forward+.
@tool
class_name EventForgeEnvironmentWords
extends RefCounted

## The node class every row here is hosted on - the one node in a scene that holds an Environment
## and can be given its own copy of it.
const HOST: String = "WorldEnvironment"

## The member the rows write through. Spelled exactly as the frozen node-scoped World rows spell it,
## so a picked row and a hand-written line are the same bytes.
const ENVIRONMENT_MEMBER: String = "environment"

## The class the words are RESOLVED against, and the class the DEFAULTS are asked of. Environment is
## concrete, so it is both.
const ENVIRONMENT_CLASS: String = "Environment"

## The class a node holding nothing at all is given, so a row on a bare WorldEnvironment writes a
## world rather than reaching through a null.
const FALLBACK_ENVIRONMENT: String = "Environment"

## What kind of row a word makes. A VALUE word is set to a number and can be read back; a COLOUR is a
## value with a colour field rather than an expression one; a CHOICE is one of a fixed list of engine
## constants, optionally with companion properties on the same row; a SWITCH is turned on or off and
## can be asked about; a RESOURCE takes a file. One builder per kind, in environment_aces.gd.
const KIND_VALUE: String = "value"
const KIND_COLOUR: String = "colour"
const KIND_CHOICE: String = "choice"
const KIND_SWITCH: String = "switch"
const KIND_RESOURCE: String = "resource"

## THE LINES every write is preceded by - the own-it courtesy, spelled once. A node holding nothing
## is given a plain Environment, because there is nothing to copy; one holding an Environment FILE is
## given its own copy of it. An Environment the scene already keeps inside itself has no
## `resource_path` and is nobody else's, so it is left exactly as it is.
const OWN_LINES: String = "if %s == null:\n\t%s = %s.new()\nelif not %s.resource_path.is_empty():\n\t%s = %s.duplicate()\n" % [
	ENVIRONMENT_MEMBER, ENVIRONMENT_MEMBER, FALLBACK_ENVIRONMENT, ENVIRONMENT_MEMBER,
	ENVIRONMENT_MEMBER, ENVIRONMENT_MEMBER]

## THE WORDS. One entry per thing a game touches, and for each one the spellings it can take in
## preference order, as `property -> ace_id stem`. The stems are frozen (see the header); which
## spelling Environment resolves to is not written down anywhere, it is asked of ClassDB.
##
## `turns_on` is the switch a word does nothing without, written on the same row rather than left as
## a second thing to remember. `fades` says the word can be walked to over time. `forward_plus` says
## the row does nothing at all on the Mobile and Compatibility renderers, which the row's own words
## then say out loud.
##
## `reads_on` and `reads_off` are what a HAND-WRITTEN `environment.ssr_enabled = true` reads as, and
## they are written down rather than built out of the word because they are user-facing sentences a
## catalog has to be able to hold. They keep the shape the environment reading has always used
## ("Set fog on", "Set glow off") rather than the row's own "Turn ... on", so every switch in the
## world's look reads one way whichever of the two rows wrote it.
const WORDS: Array[Dictionary] = [
	{
		"word": "saturation",
		"kind": KIND_VALUE,
		"name": "Set Saturation",
		"verb": "Set saturation to {value}",
		"reads": "saturation",
		"about": "How colourful the whole picture is: 1 is untouched, 0 is grey, above 1 is louder. The one row that turns a flashback grey and a power-up garish.",
		"fades": true,
		"featured": true,
		"turns_on": "adjustment_enabled",
		"spellings": {"adjustment_saturation": "Saturation"}
	},
	{
		"word": "contrast",
		"kind": KIND_VALUE,
		"name": "Set Contrast",
		"verb": "Set contrast to {value}",
		"reads": "contrast",
		"about": "How far the darks and the lights are pushed apart: 1 is untouched, below 1 is flat and hazy, above 1 is hard.",
		"fades": true,
		"turns_on": "adjustment_enabled",
		"spellings": {"adjustment_contrast": "Contrast"}
	},
	{
		"word": "picture brightness",
		"kind": KIND_VALUE,
		"name": "Set Picture Brightness",
		"verb": "Set picture brightness to {value}",
		"reads": "picture brightness",
		"label": "Picture brightness",
		"about": "How bright the finished picture is, after every light in the scene has had its say: 1 is untouched. Different from a light's brightness, which changes what one lamp does.",
		"fades": true,
		"turns_on": "adjustment_enabled",
		"spellings": {"adjustment_brightness": "PictureBrightness"}
	},
	{
		"word": "exposure",
		"kind": KIND_VALUE,
		"name": "Set Exposure",
		"verb": "Set exposure to {value}",
		"reads": "exposure",
		"about": "How much light the camera lets in before the picture is made: 1 is untouched, higher blows the highlights out, lower sinks everything into the dark. What a flashbang and a slow walk out of a cave both need.",
		"fades": true,
		"featured": true,
		"spellings": {"tonemap_exposure": "Exposure"}
	},
	{
		"word": "glow bloom",
		"kind": KIND_VALUE,
		"name": "Set Glow Bloom",
		"verb": "Set glow bloom to {value}",
		"reads": "glow bloom",
		"label": "Bloom",
		"about": "How much of the picture bleeds into the glow, not just the bright parts: 0 is only what is over the threshold, 1 is everything. Switches the glow on as well, because it does nothing without it.",
		"fades": true,
		"turns_on": "glow_enabled",
		"spellings": {"glow_bloom": "GlowBloom"}
	},
	{
		"word": "glow threshold",
		"kind": KIND_VALUE,
		"name": "Set Glow Threshold",
		"verb": "Set glow threshold to {value}",
		"reads": "glow threshold",
		"label": "Threshold",
		"about": "How bright a thing has to be before it glows at all: 1 is the usual line, lower makes more of the scene bleed, higher keeps the glow for the neon and the fire only. Switches the glow on as well.",
		"turns_on": "glow_enabled",
		"spellings": {"glow_hdr_threshold": "GlowThreshold"}
	},
	{
		"word": "fog floor",
		"kind": KIND_VALUE,
		"name": "Set Fog Floor",
		"verb": "Set fog floor to {value}",
		"reads": "fog floor",
		"label": "Floor height",
		"about": "The height the fog lies at, in metres, so it pools in a valley and thins out over a hill. Switches the fog on as well, because it does nothing without it.",
		"turns_on": "fog_enabled",
		"spellings": {"fog_height": "FogFloor"}
	},
	{
		"word": "fog floor thickness",
		"kind": KIND_VALUE,
		"name": "Set Fog Floor Thickness",
		"verb": "Set fog floor thickness to {value}",
		"reads": "fog floor thickness",
		"label": "Floor thickness",
		"about": "How fast the fog thins out above its floor. 0 leaves the fog the same all the way up; a small number keeps it lying on the ground the way a morning mist does.",
		"fades": true,
		"turns_on": "fog_enabled",
		"spellings": {"fog_height_density": "FogFloorThickness"}
	},
	{
		"word": "aerial perspective",
		"kind": KIND_VALUE,
		"name": "Set Aerial Perspective",
		"verb": "Set aerial perspective to {value}",
		"reads": "aerial perspective",
		"label": "Aerial perspective",
		"about": "How much of the sky's own colour the far distance picks up, as a fraction: 0 is none, 1 is the far hills the same colour as the sky behind them. The thing that makes a view read as miles rather than metres.",
		"fades": true,
		"turns_on": "fog_enabled",
		"spellings": {"fog_aerial_perspective": "AerialPerspective"}
	},
	{
		"word": "fog sun glow",
		"kind": KIND_VALUE,
		"name": "Set Fog Sun Glow",
		"verb": "Set fog sun glow to {value}",
		"reads": "fog sun glow",
		"label": "Sun glow",
		"about": "How much the fog lights up around the sun, as a fraction: 0 is flat fog, 1 is the glare you look away from when you face into a low sun.",
		"fades": true,
		"turns_on": "fog_enabled",
		"spellings": {"fog_sun_scatter": "FogSunGlow"}
	},
	{
		"word": "volumetric thickness",
		"kind": KIND_VALUE,
		"name": "Set Volumetric Thickness",
		"verb": "Set volumetric thickness to {value}",
		"reads": "volumetric thickness",
		"label": "Thickness",
		"about": "How thick the air itself is, for the fog that lights up and casts shadows rather than the flat kind. Small numbers: 0.05 is a room with dust in the light, 0.5 is a swamp. Forward+ only - on Mobile and Compatibility the row does nothing.",
		"fades": true,
		"forward_plus": true,
		"turns_on": "volumetric_fog_enabled",
		"spellings": {"volumetric_fog_density": "VolumetricThickness"}
	},
	{
		"word": "volumetric colour",
		"kind": KIND_COLOUR,
		"name": "Set Volumetric Colour",
		"verb": "Set volumetric colour to {value}",
		"reads": "volumetric colour",
		"label": "Colour",
		"about": "The colour the thick air is, before any light falls through it - green for a swamp, brown for a dust storm, white for steam. Forward+ only - on Mobile and Compatibility the row does nothing.",
		"fades": true,
		"forward_plus": true,
		"turns_on": "volumetric_fog_enabled",
		"spellings": {"volumetric_fog_albedo": "VolumetricColour"}
	},
	{
		"word": "volumetric reach",
		"kind": KIND_VALUE,
		"name": "Set Volumetric Reach",
		"verb": "Set volumetric reach to {value}",
		"reads": "volumetric reach",
		"label": "Reach",
		"about": "How far from the camera the thick air is worked out at all, in metres. Shorter is cheaper and ends in a visible edge; longer costs frames. Forward+ only - on Mobile and Compatibility the row does nothing.",
		"fades": true,
		"forward_plus": true,
		"turns_on": "volumetric_fog_enabled",
		"spellings": {"volumetric_fog_length": "VolumetricReach"}
	},
	{
		"word": "volumetric fog",
		"kind": KIND_SWITCH,
		"on_name": "Turn Volumetric Fog On",
		"off_name": "Turn Volumetric Fog Off",
		"asks": "Is Volumetric Fog On",
		"on_verb": "Turn volumetric fog on",
		"off_verb": "Turn volumetric fog off",
		"ask_verb": "Volumetric fog is on",
		"reads_on": "Set volumetric fog on",
		"reads_off": "Set volumetric fog off",
		"about": "The fog that fills the air rather than sitting flat over the picture - it lights up where a lamp shines through it and goes dark where something blocks it. Costs frames. Forward+ only - on Mobile and Compatibility the row does nothing.",
		"forward_plus": true,
		"spellings": {"volumetric_fog_enabled": "VolumetricFog"}
	},
	{
		"word": "reflections",
		"kind": KIND_SWITCH,
		"on_name": "Turn Reflections On",
		"off_name": "Turn Reflections Off",
		"asks": "Are Reflections On",
		"on_verb": "Turn reflections on",
		"off_verb": "Turn reflections off",
		"ask_verb": "reflections are on",
		"reads_on": "Set reflections on",
		"reads_off": "Set reflections off",
		"about": "Whether shiny surfaces reflect what is already on the screen - the wet floor that shows the room above it. Forward+ only - on Mobile and Compatibility the row does nothing.",
		"forward_plus": true,
		"spellings": {"ssr_enabled": "Reflections"}
	},
	{
		"word": "indirect light",
		"kind": KIND_SWITCH,
		"on_name": "Turn Indirect Light On",
		"off_name": "Turn Indirect Light Off",
		"asks": "Is Indirect Light On",
		"on_verb": "Turn indirect light on",
		"off_verb": "Turn indirect light off",
		"ask_verb": "indirect light is on",
		"reads_on": "Set indirect light on",
		"reads_off": "Set indirect light off",
		"about": "Whether a lit surface throws its own colour onto what is beside it - the red wall that makes the white floor beside it pink. Forward+ only - on Mobile and Compatibility the row does nothing.",
		"forward_plus": true,
		"spellings": {"ssil_enabled": "IndirectLight"}
	},
	{
		"word": "global illumination",
		"kind": KIND_SWITCH,
		"on_name": "Turn Global Illumination On",
		"off_name": "Turn Global Illumination Off",
		"asks": "Is Global Illumination On",
		"on_verb": "Turn global illumination on",
		"off_verb": "Turn global illumination off",
		"ask_verb": "global illumination is on",
		"reads_on": "Set global illumination on",
		"reads_off": "Set global illumination off",
		"about": "Whether light bounces around the whole scene by itself, so a room with one window is lit rather than black in the corners. The most expensive switch here. Forward+ only - on Mobile and Compatibility the row does nothing.",
		"forward_plus": true,
		"spellings": {"sdfgi_enabled": "GlobalIllumination"}
	},
	{
		"word": "backdrop",
		"kind": KIND_CHOICE,
		"name": "Set Backdrop",
		"verb": "Set backdrop to {value}",
		"reads": "backdrop",
		"label": "Backdrop",
		"about": "What is drawn behind everything else. A sky is what an outdoor scene wants; a flat colour is what a menu and a stylised level want; transparent draws the project's own clear colour, which is what lets a see-through window show the desktop behind it.",
		"featured": true,
		# Written down rather than asked for: ClassDB answers a choice property's default as the
		# integer the enum really is, and a dropdown whose keys are constants cannot open on `0`.
		# The value is still the engine's own - it is the constant that integer names.
		"default": "Environment.BG_CLEAR_COLOR",
		"choices": [
			{"key": "Environment.BG_SKY", "label": "sky"},
			{"key": "Environment.BG_COLOR", "label": "colour"},
			{"key": "Environment.BG_CLEAR_COLOR", "label": "transparent"},
			{"key": "Environment.BG_KEEP", "label": "keep what was there"}
		],
		"companions": [
			{
				"property": "background_color",
				"param": "colour",
				"label": "Colour",
				"kind": KIND_COLOUR,
				"about": "The flat colour drawn behind everything. Only the colour backdrop reads it."
			}
		],
		"spellings": {"background_mode": "Backdrop"}
	},
	{
		"word": "tone map",
		"kind": KIND_CHOICE,
		"name": "Set Tone Map",
		"verb": "Set tone map to {value}",
		"reads": "tone map",
		"label": "Tone map",
		"about": "How the brightness the scene really has is squeezed into the range a screen can show. Linear is no squeezing at all and blows out; filmic and ACES roll the highlights off the way a camera does; AgX keeps the colour in a very bright highlight instead of letting it go white.",
		"default": "Environment.TONE_MAPPER_LINEAR",
		"choices": [
			{"key": "Environment.TONE_MAPPER_LINEAR", "label": "linear"},
			{"key": "Environment.TONE_MAPPER_REINHARDT", "label": "reinhard"},
			{"key": "Environment.TONE_MAPPER_FILMIC", "label": "filmic"},
			{"key": "Environment.TONE_MAPPER_ACES", "label": "ACES"},
			{"key": "Environment.TONE_MAPPER_AGX", "label": "AgX"}
		],
		"companions": [
			{
				"property": "tonemap_white",
				"param": "white",
				"label": "White at",
				"kind": KIND_VALUE,
				"about": "The brightness that comes out pure white. Read by every tone map except linear and AgX."
			},
			{
				"property": "tonemap_agx_contrast",
				"param": "agx_contrast",
				"label": "AgX contrast",
				"kind": KIND_VALUE,
				"about": "How hard AgX pushes the darks and lights apart. Only AgX reads it."
			}
		],
		"spellings": {"tonemap_mode": "ToneMap"}
	},
	{
		"word": "glow blend",
		"kind": KIND_CHOICE,
		"name": "Set Glow Blend",
		"verb": "Set glow blend to {value}",
		"reads": "glow blend",
		"label": "Glow blend",
		"about": "How the glow is mixed back over the picture. Additive is the brightest and blows out fastest; screen keeps the bright parts under control; soft light is the gentlest; replace shows the glow alone, which is what a dream sequence wants. Switches the glow on as well.",
		"turns_on": "glow_enabled",
		"default": "Environment.GLOW_BLEND_MODE_SCREEN",
		"choices": [
			{"key": "Environment.GLOW_BLEND_MODE_ADDITIVE", "label": "additive"},
			{"key": "Environment.GLOW_BLEND_MODE_SCREEN", "label": "screen"},
			{"key": "Environment.GLOW_BLEND_MODE_SOFTLIGHT", "label": "soft light"},
			{"key": "Environment.GLOW_BLEND_MODE_REPLACE", "label": "replace"},
			{"key": "Environment.GLOW_BLEND_MODE_MIX", "label": "mix"}
		],
		"spellings": {"glow_blend_mode": "GlowBlend"}
	},
	{
		"word": "colour grade",
		"kind": KIND_RESOURCE,
		"name": "Set Colour Grade",
		"verb": "Set colour grade to {value}",
		"reads": "colour grade",
		"label": "Colour grade",
		"about": "A picture that says what every colour in the scene turns into - the one file that makes a level read as a memory, a poison haze or a night-vision goggle. Blank it with null to go back to the colours as they are. Switches the picture adjustments on as well.",
		"turns_on": "adjustment_enabled",
		# Written down, because ClassDB answers an object property's default with a null OBJECT and
		# the text of that is `<Object#null>`, which is not a thing anybody can type. The value is
		# still the engine's own: a new Environment has no colour grade.
		"default": "null",
		"spellings": {"adjustment_color_correction": "ColourGrade"}
	}
]

## THE GLOW LEVELS, which are the one Environment setting that is not a property at all: Godot keeps
## them as `glow_levels/1` through `glow_levels/7` and reaches them through `set_glow_level(i, n)`.
## Seven numbers is not a row a person can read, so the shipped row offers three tables to pick from
## and a second row sets one level by hand.
const GLOW_LEVEL_COUNT: int = 7
const GLOW_LEVEL_SET_CALL: String = "set_glow_level"
const GLOW_LEVEL_GET_CALL: String = "get_glow_level"

## THE THREE TABLES, written down here and documented rather than computed, because each is a shape
## somebody chose. Level 1 is the sharpest, finest blur and level 7 is the widest, softest one, so a
## table that leans on the low numbers keeps the glow close to what is glowing and a table that leans
## on the high ones spreads it over the whole screen.
##
## These are STARTERS, not a house style: Set Glow Level sets any one of the seven to any number, and
## a project that wants its own shape writes it with seven of those rows and never asks here again.
const GLOW_LEVEL_SPREADS: Array[Dictionary] = [
	{
		"key": "tight",
		"label": "tight - close to what is glowing",
		"about": "Weight on the two sharpest levels, so a neon sign glows just around its own edge.",
		"levels": [1.0, 0.6, 0.2, 0.0, 0.0, 0.0, 0.0]
	},
	{
		"key": "balanced",
		"label": "balanced - Godot's own shape",
		"about": "The seven numbers a new Environment starts on: a little of each of the first four.",
		"levels": [0.0, 0.8, 0.4, 0.1, 0.0, 0.0, 0.0]
	},
	{
		"key": "wide",
		"label": "wide - over the whole screen",
		"about": "Weight on the widest levels, so a bright window washes light across the room.",
		"levels": [0.0, 0.2, 0.4, 0.6, 0.8, 1.0, 1.0]
	}
]

## THE QUALITY DIALS. Four of the world's switches have a matching quality setting that Project
## Settings writes once at boot and a graphics menu has to be able to write again while the game is
## running - and Godot puts that setting on the RenderingServer rather than on the Environment, so
## the flag and the quality are two different objects. One row says both.
##
## `flag` is the Environment property the switch itself is, `call` is the RenderingServer method, and
## `arguments` are the method's remaining arguments in the engine's own order -
## `environment_set_ssao_quality` takes six and only the first is a quality. They are written out
## because there is nothing to ask them of at descriptor-build time, and the values are the ones
## Project Settings itself hands the RenderingServer at boot:
## `rendering/environment/ssao/half_size` true, `adaptive_target` 0.5, `blur_passes` 2,
## `fadeout_from` 50.0, `fadeout_to` 300.0, and the same for `ssil` with four blur passes. THEY ARE
## NOT PLACEHOLDERS. `fadeout_from` and `fadeout_to` are the metres over which the effect is faded
## out with distance, so a row passing 0.01 and 0.0 there would switch the effect off within a
## centimetre of the camera while claiming to have turned it on - which is what these numbers being
## the project's own prevents. `stem` is frozen, exactly like a word's.
const QUALITY_DIALS: Array[Dictionary] = [
	{
		"word": "occlusion",
		"stem": "Occlusion",
		"name": "Turn Occlusion On At Quality",
		"off_name": "Turn Occlusion Off",
		"asks": "Is Occlusion On",
		"verb": "Turn occlusion on at {quality}",
		"off_verb": "Turn occlusion off",
		"ask_verb": "occlusion is on",
		"flag": "ssao_enabled",
		"call": "environment_set_ssao_quality",
		"arguments": "true, 0.5, 2, 50.0, 300.0",
		"default": "RenderingServer.ENV_SSAO_QUALITY_MEDIUM",
		"choices": [
			{"key": "RenderingServer.ENV_SSAO_QUALITY_VERY_LOW", "label": "very low"},
			{"key": "RenderingServer.ENV_SSAO_QUALITY_LOW", "label": "low"},
			{"key": "RenderingServer.ENV_SSAO_QUALITY_MEDIUM", "label": "medium"},
			{"key": "RenderingServer.ENV_SSAO_QUALITY_HIGH", "label": "high"},
			{"key": "RenderingServer.ENV_SSAO_QUALITY_ULTRA", "label": "ultra"}
		],
		"about": "Darkens the corners and creases of a 3D scene, which is what makes it look solid, and says how carefully at the same time. Forward+ only - on Mobile and Compatibility the row does nothing.",
		"off_about": "Switches the darkened corners off again, and gives the frames back. Forward+ only - on Mobile and Compatibility the row does nothing.",
		"ask_about": "True while the corners and creases of the scene are being darkened."
	},
	{
		"word": "indirect light",
		"stem": "IndirectLight",
		"name": "Turn Indirect Light On At Quality",
		"verb": "Turn indirect light on at {quality}",
		"flag": "ssil_enabled",
		"call": "environment_set_ssil_quality",
		"arguments": "true, 0.5, 4, 50.0, 300.0",
		"default": "RenderingServer.ENV_SSIL_QUALITY_MEDIUM",
		"choices": [
			{"key": "RenderingServer.ENV_SSIL_QUALITY_VERY_LOW", "label": "very low"},
			{"key": "RenderingServer.ENV_SSIL_QUALITY_LOW", "label": "low"},
			{"key": "RenderingServer.ENV_SSIL_QUALITY_MEDIUM", "label": "medium"},
			{"key": "RenderingServer.ENV_SSIL_QUALITY_HIGH", "label": "high"},
			{"key": "RenderingServer.ENV_SSIL_QUALITY_ULTRA", "label": "ultra"}
		],
		"about": "Lets a lit surface throw its own colour onto what is beside it, and says how carefully at the same time. Forward+ only - on Mobile and Compatibility the row does nothing."
	},
	{
		"word": "global illumination",
		"stem": "GlobalIllumination",
		"name": "Turn Global Illumination On At Quality",
		"verb": "Turn global illumination on at {quality}",
		"flag": "sdfgi_enabled",
		"call": "environment_set_sdfgi_ray_count",
		"arguments": "",
		"default": "RenderingServer.ENV_SDFGI_RAY_COUNT_32",
		"choices": [
			{"key": "RenderingServer.ENV_SDFGI_RAY_COUNT_4", "label": "4 rays - cheapest, noisiest"},
			{"key": "RenderingServer.ENV_SDFGI_RAY_COUNT_8", "label": "8 rays"},
			{"key": "RenderingServer.ENV_SDFGI_RAY_COUNT_16", "label": "16 rays"},
			{"key": "RenderingServer.ENV_SDFGI_RAY_COUNT_32", "label": "32 rays"},
			{"key": "RenderingServer.ENV_SDFGI_RAY_COUNT_64", "label": "64 rays"},
			{"key": "RenderingServer.ENV_SDFGI_RAY_COUNT_96", "label": "96 rays"},
			{"key": "RenderingServer.ENV_SDFGI_RAY_COUNT_128", "label": "128 rays - cleanest, dearest"}
		],
		"about": "Lets light bounce around the whole scene by itself, and says how many rays are traced to work it out. Forward+ only - on Mobile and Compatibility the row does nothing."
	},
	{
		"word": "reflections",
		"stem": "Reflections",
		"name": "Turn Reflections On At Quality",
		"verb": "Turn reflections on at {quality}",
		"flag": "ssr_enabled",
		"call": "environment_set_ssr_roughness_quality",
		"arguments": "",
		"default": "RenderingServer.ENV_SSR_ROUGHNESS_QUALITY_MEDIUM",
		"choices": [
			{"key": "RenderingServer.ENV_SSR_ROUGHNESS_QUALITY_DISABLED", "label": "no roughness - sharpest and cheapest"},
			{"key": "RenderingServer.ENV_SSR_ROUGHNESS_QUALITY_LOW", "label": "low"},
			{"key": "RenderingServer.ENV_SSR_ROUGHNESS_QUALITY_MEDIUM", "label": "medium"},
			{"key": "RenderingServer.ENV_SSR_ROUGHNESS_QUALITY_HIGH", "label": "high"}
		],
		"about": "Lets shiny surfaces reflect what is already on the screen, and says how carefully a rough surface blurs its reflection. Forward+ only - on Mobile and Compatibility the row does nothing."
	}
]

## The rendering methods a project can be built with, as Godot's own three names, with the plain
## words a row shows for each. The order is the engine's own: most capable first.
const RENDERING_METHODS: Array[Dictionary] = [
	{"key": "\"forward_plus\"", "label": "Forward+ - desktop, every feature"},
	{"key": "\"mobile\"", "label": "Mobile - phones and tablets"},
	{"key": "\"gl_compatibility\"", "label": "Compatibility - old GPUs and the web"}
]

## The call that answers which renderer the game is really running on. Frozen here rather than in the
## row, because both the row and the Doctor's note read it.
const RENDERING_METHOD_CALL: String = "RenderingServer.get_current_rendering_method()"

## Where Project Settings records the renderer a project is built with, and the two answers that are
## not Forward+.
const RENDERING_METHOD_SETTING: String = "rendering/renderer/rendering_method"
const FORWARD_PLUS: String = "forward_plus"

## Per class, `property -> true`, filled the first time a class is asked about. ClassDB answers the
## same thing for the life of the process, and this is asked once per word on every descriptor build.
static var _properties: Dictionary = {}


## The property Environment answers a word with, or "" when it has none of that word's spellings.
## Derived: the word says which spellings are possible, ClassDB says which of them the class has.
static func property_of(word: String) -> String:
	var entry: Dictionary = word_entry(word)
	if entry.is_empty():
		return ""
	for property: String in (entry["spellings"] as Dictionary).keys():
		if has_property(ENVIRONMENT_CLASS, property):
			return property
	return ""


## True when a class really carries a property, inherited ones included. The one question the whole
## word map is derived from.
static func has_property(class_text: String, property: String) -> bool:
	if not _properties.has(class_text):
		var names: Dictionary = {}
		for described: Dictionary in ClassDB.class_get_property_list(class_text, false):
			names[str(described.get("name", ""))] = true
		_properties[class_text] = names
	return bool((_properties[class_text] as Dictionary).get(property, false))


## The word entry by its word, or {}.
static func word_entry(word: String) -> Dictionary:
	for entry: Dictionary in WORDS:
		if str(entry["word"]) == word:
			return entry
	return {}


## The frozen ace_id stem for one word, or "" when Environment answers none of its spellings.
static func id_stem(word: String) -> String:
	var entry: Dictionary = word_entry(word)
	var property: String = property_of(word)
	if entry.is_empty() or property.is_empty():
		return ""
	return str((entry["spellings"] as Dictionary).get(property, ""))


## The value a row starts on: the word's own when it names one, and otherwise the ENGINE's default
## for the property, asked of ClassDB through the factory so a dropped row opens where Godot opens it.
static func default_of(word: String) -> String:
	var entry: Dictionary = word_entry(word)
	if entry.has("default"):
		return str(entry["default"])
	var property: String = property_of(word)
	return "" if property.is_empty() else default_literal(property)


## One Environment property's engine default, as the text a row starts on. Asked through the factory
## rather than of ClassDB directly, because the answer arrives as a float32 widened to a double and a
## row must not open on `0.00999999977648` when the engine's own number is a hundredth.
static func default_literal(property: String) -> String:
	return EventForgeACEFactory.default_literal(ENVIRONMENT_CLASS, property)


## Every word this vocabulary really resolves, in table order - the one list the rows, the reading
## and the tests all walk, so none of them can drift from the others.
static func words() -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	for entry: Dictionary in WORDS:
		if not property_of(str(entry["word"])).is_empty():
			found.append(str(entry["word"]))
	return found


## THE TABLE READ BACKWARDS: the word an Environment property IS, or "" for a property no word here
## means. What turns a hand-written `environment.fog_height = 4.0` back into the sentence the picker
## would have made - the same job the light words do for `energy` and the material words do for
## `metallic`, and the reason all three tables say what they mean rather than only how to write it.
static func word_of_property(property: String) -> String:
	var wanted: String = property.strip_edges()
	if wanted.is_empty():
		return ""
	for word: String in words():
		if property_of(word) == wanted:
			return word
	return ""


## The sentence a row of one word reads as, with `{value}` still in it - what the reading uses so a
## typed line and a picked row say exactly the same thing. "" for a word that is not one.
static func verb_of_property(property: String) -> String:
	var word: String = word_of_property(property)
	return "" if word.is_empty() else str(word_entry(word).get("verb", ""))


## The two sentences a SWITCH word READS as, on and off, or [] for a property that is not one. The
## reading's own pair rather than the row's - see the table's note on `reads_on`.
static func switch_readings_of_property(property: String) -> Array:
	var word: String = word_of_property(property)
	if word.is_empty():
		return []
	var entry: Dictionary = word_entry(word)
	if str(entry["kind"]) != KIND_SWITCH:
		return []
	return [str(entry["reads_on"]), str(entry["reads_off"])]


## The plain word a CHOICE word's dropdown shows for one engine constant, or "" when the property is
## not a choice word or the value is not one of its constants. What lets a hand-written
## `environment.tonemap_mode = Environment.TONE_MAPPER_AGX` read "Set tone map to AgX" rather than
## repeating the constant back. Both spellings are accepted - the qualified constant a file writes
## and the bare leg somebody wrote after a `using`-style alias - because the table holds the
## qualified one and the line may hold either.
static func choice_label(property: String, value: String) -> String:
	var word: String = word_of_property(property)
	if word.is_empty():
		return ""
	var entry: Dictionary = word_entry(word)
	if str(entry["kind"]) != KIND_CHOICE:
		return ""
	var wanted: String = value.strip_edges()
	var bare: String = wanted.substr(wanted.rfind(".") + 1)
	for choice: Variant in (entry["choices"] as Array):
		var option: Dictionary = choice
		var key: String = str(option["key"])
		if key == wanted or key.substr(key.rfind(".") + 1) == bare:
			return str(option["label"])
	return ""


## Every Environment property this vocabulary writes that ONLY does anything on Forward+ - the words
## that say so themselves, plus the flag of every quality dial that says so. Derived from the two
## tables above so the Doctor's renderer note can never drift from the rows it is about.
static func forward_plus_properties() -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	for entry: Dictionary in WORDS:
		if not bool(entry.get("forward_plus", false)):
			continue
		var property: String = property_of(str(entry["word"]))
		if not property.is_empty() and not found.has(property):
			found.append(property)
	for dial: Dictionary in QUALITY_DIALS:
		var flag: String = str(dial["flag"])
		if not found.has(flag):
			found.append(flag)
	return found


## Every LINE FRAGMENT this vocabulary emits that only does anything on Forward+, paired with the
## plain word a reader knows it by - `["environment.ssr_enabled", "reflections"]`. THE one table the
## Doctor's renderer note reads, derived from the two above rather than written a second time, so a
## note can never name a row this file has stopped publishing. A property both tables reach (the
## three Forward+ switches are words AND quality dials) is listed once, under the word.
static func forward_plus_reasons() -> Array[Array]:
	var found: Array[Array] = []
	var seen: Dictionary = {}
	for entry: Dictionary in WORDS:
		if not bool(entry.get("forward_plus", false)):
			continue
		var property: String = property_of(str(entry["word"]))
		if property.is_empty():
			continue
		var fragment: String = "%s.%s" % [ENVIRONMENT_MEMBER, property]
		if not seen.has(fragment):
			seen[fragment] = true
			found.append([fragment, str(entry["word"])])
	for dial: Dictionary in QUALITY_DIALS:
		for pair: Array in [["%s.%s" % [ENVIRONMENT_MEMBER, str(dial["flag"])], str(dial["word"])],
				["RenderingServer.%s(" % str(dial["call"]), str(dial["word"])]]:
			if not seen.has(str(pair[0])):
				seen[str(pair[0])] = true
				found.append(pair)
	return found


## Every RenderingServer quality call this vocabulary emits - the other half of the same question,
## because a graphics menu that writes a quality on a Mobile project is writing into the same void.
static func forward_plus_calls() -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	for dial: Dictionary in QUALITY_DIALS:
		var call_text: String = "RenderingServer.%s(" % str(dial["call"])
		if not found.has(call_text):
			found.append(call_text)
	return found


## True when a class is one these rows speak for - a WorldEnvironment, or a project's own subclass
## of one. Asked through ClassDB rather than against a list, so a subclass resolves too.
static func is_world_class(class_text: String) -> bool:
	var text: String = class_text.strip_edges()
	return not text.is_empty() and ClassDB.class_exists(text) and ClassDB.is_parent_class(text, HOST)


## One glow spread by its key, or {}.
static func glow_spread(key: String) -> Dictionary:
	for spread: Dictionary in GLOW_LEVEL_SPREADS:
		if str(spread["key"]) == key:
			return spread
	return {}
