# The environment and sky words, and the rows they build.
#
# The claim this file holds to account is that the sheet says ONE word where Godot says a property
# name: `saturation` is `adjustment_saturation` and does nothing until `adjustment_enabled` is true,
# `fog floor` is `fog_height`, `reflections` is `ssr_enabled`, and the sky's top colour is three
# objects past the node. The mapping is derived from ClassDB, so what is pinned here is the ANSWERS -
# by value - rather than the table that produces them.
#
# And the OWN-IT COURTESY, which is the whole reason these templates are several lines rather than
# one: every write gives this scene its own copy of the environment first, so an environment file
# loaded by two scenes never changes under the other one. It is pinned as the emitted BYTES, because
# that promise is only kept by what the row actually writes.
@tool
class_name EnvironmentWordsTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const W := preload("res://addons/eventforge/registration/environment_words.gd")
const S := preload("res://addons/eventforge/registration/sky_words.gd")
const MODULE := preload("res://addons/eventforge/registration/modules/environment_aces.gd")

## The four lines every environment write opens with, written out here rather than read from the
## file under test: a test that builds its expectation from the same constant proves only that a
## constant equals itself.
const OWN_LINES := "if environment == null:\n" \
	+ "\tenvironment = Environment.new()\n" \
	+ "elif not environment.resource_path.is_empty():\n" \
	+ "\tenvironment = environment.duplicate()\n"

## The guard and the two owning lines a sky write adds on top of those four, for the same reason.
const SKY_GUARD := "if environment.sky != null and environment.sky.sky_material is ProceduralSkyMaterial:\n" \
	+ "\tif not environment.sky.resource_path.is_empty():\n" \
	+ "\t\tenvironment.sky = environment.sky.duplicate()\n" \
	+ "\tif not environment.sky.sky_material.resource_path.is_empty():\n" \
	+ "\t\tenvironment.sky.sky_material = environment.sky.sky_material.duplicate()\n"


static func run() -> bool:
	var ok: bool = true
	ok = _test_the_word_map() and ok
	ok = _test_the_defaults_come_from_classdb() and ok
	ok = _test_the_id_stems() and ok
	ok = _test_the_templates() and ok
	ok = _test_the_choice_words() and ok
	ok = _test_the_glow_levels() and ok
	ok = _test_the_quality_dials() and ok
	ok = _test_the_renderer_condition() and ok
	ok = _test_the_sky_words() and ok
	ok = _test_ids_are_unique() and ok
	ok = _test_every_row_carries_help() and ok
	ok = _test_the_forward_plus_answer() and ok
	ok = _test_a_hand_written_line_reads_as_the_word() and ok
	ok = _test_the_doctor_says_the_renderer() and ok
	ok = _test_the_doctor_says_the_backdrop() and ok
	return ok


## Every word resolves to a property Environment really has - the one thing the whole vocabulary is
## derived from, so it is pinned by value, word by word.
static func _test_the_word_map() -> bool:
	var resolved: Dictionary = {}
	for word: String in W.words():
		resolved[word] = W.property_of(word)
	var ok: bool = SUPPORT.check("environment_words_test", "each word resolves to its property",
		resolved, {
			"saturation": "adjustment_saturation",
			"contrast": "adjustment_contrast",
			"picture brightness": "adjustment_brightness",
			"exposure": "tonemap_exposure",
			"glow bloom": "glow_bloom",
			"glow threshold": "glow_hdr_threshold",
			"fog floor": "fog_height",
			"fog floor thickness": "fog_height_density",
			"aerial perspective": "fog_aerial_perspective",
			"fog sun glow": "fog_sun_scatter",
			"volumetric thickness": "volumetric_fog_density",
			"volumetric colour": "volumetric_fog_albedo",
			"volumetric reach": "volumetric_fog_length",
			"volumetric fog": "volumetric_fog_enabled",
			"reflections": "ssr_enabled",
			"indirect light": "ssil_enabled",
			"global illumination": "sdfgi_enabled",
			"backdrop": "background_mode",
			"tone map": "tonemap_mode",
			"glow blend": "glow_blend_mode",
			"colour grade": "adjustment_color_correction"
		})
	return SUPPORT.check("environment_words_test", "every word the table names really resolves",
		W.words().size(), W.WORDS.size()) and ok


## The value a row opens on is Godot's own, asked of ClassDB - so a dropped row starts where the
## engine starts and a reader never meets a number nobody chose, nor the float32 widening that
## printing one in full would write into their script.
static func _test_the_defaults_come_from_classdb() -> bool:
	var defaults: Dictionary = {}
	for word: String in ["saturation", "exposure", "glow bloom", "volumetric thickness",
			"volumetric colour", "volumetric reach", "colour grade"]:
		defaults[word] = W.default_of(word)
	return SUPPORT.check("environment_words_test", "each field opens on Godot's own default",
		defaults, {
			"saturation": "1.0",
			"exposure": "1.0",
			"glow bloom": "0.0",
			"volumetric thickness": "0.05",
			"volumetric colour": "Color.WHITE",
			"volumetric reach": "64.0",
			"colour grade": "null"
		})


## The one thing that is NOT derived, because an ace_id is a compatibility promise: the stem each
## word's rows are named after.
static func _test_the_id_stems() -> bool:
	var stems: Dictionary = {}
	for word: String in W.words():
		stems[word] = W.id_stem(word)
	return SUPPORT.check("environment_words_test", "the frozen id stems", stems, {
		"saturation": "Saturation", "contrast": "Contrast",
		"picture brightness": "PictureBrightness", "exposure": "Exposure",
		"glow bloom": "GlowBloom", "glow threshold": "GlowThreshold", "fog floor": "FogFloor",
		"fog floor thickness": "FogFloorThickness", "aerial perspective": "AerialPerspective",
		"fog sun glow": "FogSunGlow", "volumetric thickness": "VolumetricThickness",
		"volumetric colour": "VolumetricColour", "volumetric reach": "VolumetricReach",
		"volumetric fog": "VolumetricFog", "reflections": "Reflections",
		"indirect light": "IndirectLight", "global illumination": "GlobalIllumination",
		"backdrop": "Backdrop", "tone map": "ToneMap", "glow blend": "GlowBlend",
		"colour grade": "ColourGrade"
	})


## The bytes the rows write. The own-it lines first on every write, the switch a word does nothing
## without written on the same row, a read that is the plain line a person would type, and a fade
## that walks the owned copy rather than the shared file.
static func _test_the_templates() -> bool:
	var templates: Dictionary = _templates()
	return SUPPORT.pins("environment_words_test", [
		["a plain write owns the environment first",
			templates.get("EnvSetExposure", ""),
			OWN_LINES + "environment.tonemap_exposure = {value}"],
		["saturation turns the picture adjustments on in the same row",
			templates.get("EnvSetSaturation", ""),
			OWN_LINES + "environment.adjustment_enabled = true\n"
				+ "environment.adjustment_saturation = {value}"],
		["the fog floor turns the fog on in the same row",
			templates.get("EnvSetFogFloor", ""),
			OWN_LINES + "environment.fog_enabled = true\nenvironment.fog_height = {value}"],
		["a switch is two rows, and each owns the environment first",
			[templates.get("EnvReflectionsOn", ""), templates.get("EnvReflectionsOff", "")],
			[OWN_LINES + "environment.ssr_enabled = true",
				OWN_LINES + "environment.ssr_enabled = false"]],
		# The reads and the questions ask whether there is an environment at all before they touch
		# one: an empty `environment` slot is the state a fresh WorldEnvironment is in, and a bare
		# member read there is an access on a null instance at run time. The writes need no such
		# guard - their own-it lines fill the slot before they write it.
		["the question answers false when there is no world to ask",
			templates.get("EnvIsReflections", ""),
			"environment != null and environment.ssr_enabled"],
		["and a read answers with what a new world starts on",
			templates.get("EnvExposure", ""),
			"environment.tonemap_exposure if environment != null else 1.0"],
		# A word whose starting value is a resource nobody set has no literal to fall back to, so
		# the read says null rather than ending in `else` with nothing after it.
		["a picture word falls back to null rather than to nothing",
			templates.get("EnvColourGrade", ""),
			"environment.adjustment_color_correction if environment != null else null"],
		["a fade walks the owned copy, never the shared file",
			templates.get("EnvFadeVolumetricThickness", ""),
			OWN_LINES + "environment.volumetric_fog_enabled = true\n"
				+ "create_tween().tween_property(environment, \"volumetric_fog_density\", {value}, {seconds})"]
	])


## The dropdown words a reader sees and the engine constants they really write. The KEY is frozen -
## it is what the template inserts and what every saved row holds - and the LABEL is the only half
## that is allowed to be reworded.
static func _test_the_choice_words() -> bool:
	var read: Dictionary = {}
	for row: ACEDescriptor in MODULE.get_descriptors():
		if not ["EnvSetBackdrop", "EnvSetToneMap", "EnvSetGlowBlend"].has(row.ace_id):
			continue
		for parameter: ACEParam in row.params:
			if str(parameter.id) != "value":
				continue
			var pairs: PackedStringArray = PackedStringArray()
			for option: Variant in parameter.options:
				pairs.append("%s -> %s" % [str((option as Dictionary)["label"]),
					str((option as Dictionary)["key"])])
			read[row.ace_id] = ", ".join(pairs)
	var ok: bool = SUPPORT.check("environment_words_test",
		"the dropdown words and the constants they write", read, {
			"EnvSetBackdrop": "sky -> Environment.BG_SKY, colour -> Environment.BG_COLOR, the project's clear colour -> Environment.BG_CLEAR_COLOR, keep what was there -> Environment.BG_KEEP",
			"EnvSetToneMap": "linear -> Environment.TONE_MAPPER_LINEAR, reinhard -> Environment.TONE_MAPPER_REINHARDT, filmic -> Environment.TONE_MAPPER_FILMIC, ACES -> Environment.TONE_MAPPER_ACES, AgX -> Environment.TONE_MAPPER_AGX",
			"EnvSetGlowBlend": "additive -> Environment.GLOW_BLEND_MODE_ADDITIVE, screen -> Environment.GLOW_BLEND_MODE_SCREEN, soft light -> Environment.GLOW_BLEND_MODE_SOFTLIGHT, replace -> Environment.GLOW_BLEND_MODE_REPLACE, mix -> Environment.GLOW_BLEND_MODE_MIX"
		})
	# A choice word's companions are the same DECISION, so they are fields of the same row: which
	# tone map, and where its white point and its AgX contrast sit.
	ok = SUPPORT.check("environment_words_test", "a choice word carries its companions on one row",
		_fields("EnvSetToneMap"),
		"value=Environment.TONE_MAPPER_LINEAR, white=1.0, agx_contrast=1.25") and ok
	return SUPPORT.check("environment_words_test", "and writes all three of them",
		_templates().get("EnvSetToneMap", ""),
		OWN_LINES + "environment.tonemap_mode = {value}\nenvironment.tonemap_white = {white}\n"
			+ "environment.tonemap_agx_contrast = {agx_contrast}") and ok


## THE SEVEN NUMBERS. Godot keeps the glow's blur levels as `glow_levels/1` through `glow_levels/7`
## and reaches them through a call, so the whole-shape row loops over the three written-down tables
## and the single-level row hands one number straight to the engine.
static func _test_the_glow_levels() -> bool:
	var shapes: Dictionary = {}
	for spread: Dictionary in W.GLOW_LEVEL_SPREADS:
		shapes[str(spread["key"])] = spread["levels"]
	var ok: bool = SUPPORT.check("environment_words_test", "the three suggested shapes", shapes, {
		"tight": [1.0, 0.6, 0.2, 0.0, 0.0, 0.0, 0.0],
		"balanced": [0.0, 0.8, 0.4, 0.1, 0.0, 0.0, 0.0],
		"wide": [0.0, 0.2, 0.4, 0.6, 0.8, 1.0, 1.0]
	})
	return SUPPORT.pins("environment_words_test", [
		# The counter is the engine's INDEX, which counts from 0: `glow_levels/1` is index 0 and
		# `glow_levels/7` is index 6. A loop from 1 would write every number one level too wide and
		# error out of bounds on its last turn, so the counter subscripts the array unshifted.
		["the whole shape is one loop over the seven levels",
			_templates().get("EnvSetGlowLevels", ""),
			OWN_LINES + "environment.glow_enabled = true\n"
				+ "var __glow_{uid}: PackedFloat32Array = {spread}\n"
				+ "for __level_{uid}: int in range(7):\n"
				+ "\tenvironment.set_glow_level(__level_{uid}, __glow_{uid}[__level_{uid}])"],
		# The row says the Inspector's number, 1 to 7, and the line subtracts on the reader's behalf.
		["and one level by hand is the engine's own call, one lower than the name",
			_templates().get("EnvSetGlowLevel", ""),
			OWN_LINES + "environment.glow_enabled = true\n"
				+ "environment.set_glow_level(({level}) - 1, {amount})"],
		["the shape a reader writes is the seven numbers themselves",
			_fields("EnvSetGlowLevels"), "spread=PackedFloat32Array([1.0, 0.6, 0.2, 0.0, 0.0, 0.0, 0.0])"],
		# The field is a TYPED one with suggestions, not a dropdown: three shapes chosen inside the
		# plugin must not be the only three the row can reach.
		["and any seven numbers are typeable, the three being suggestions",
			[_options_of("EnvSetGlowLevels", "spread").size(),
				_suggestions_of("EnvSetGlowLevels", "spread").size()], [0, 3]],
		# THE TEMPLATES ARE RUN, not just read, because the bug they carried was an off-by-one no
		# string comparison can see: the numbers land where the reader named them, or they do not.
		["the seven numbers land on the seven levels the reader wrote",
			_glow_levels_after(_templates().get("EnvSetGlowLevels", ""), {
				"spread": "PackedFloat32Array([1.0, 0.6, 0.2, 0.0, 0.0, 0.0, 0.0])"
			}), [1.0, 0.6, 0.2, 0.0, 0.0, 0.0, 0.0]],
		# Level 3 is `glow_levels/3`, the third number - not the fourth, which is what an unshifted
		# index would have written. The rest keep Godot's own starting numbers.
		["and level 3 by hand is the third of them, the others left alone",
			_glow_levels_after(_templates().get("EnvSetGlowLevel", ""), {
				"level": "3", "amount": "0.5"
			}), [0.0, 0.8, 0.5, 0.1, 0.0, 0.0, 0.0]]
	]) and ok


## Runs an emitted glow template against a REAL Environment and reads the seven levels back off it.
## The template is filled the way the dock fills one (`{uid}` baked, parameters substituted), wrapped
## in a throwaway script and executed, so what is pinned is what the engine ended up holding rather
## than what the string looked like. `glow_levels/1` through `glow_levels/7` are the property names
## Godot prints; the call behind them counts from 0, which is the whole point of the pin.
static func _glow_levels_after(template: String, params: Dictionary) -> Array:
	var body: String = template.replace("{uid}", "1")
	for name: String in params:
		body = body.replace("{%s}" % name, str(params[name]))
	var script := GDScript.new()
	script.source_code = "extends RefCounted\nvar environment: Environment = null\nfunc apply() -> void:\n\t" \
		+ body.replace("\n", "\n\t") + "\n"
	script.reload()
	var runner: Object = script.new()
	runner.call("apply")
	var written: Object = runner.get("environment")
	var levels: Array = []
	for level: int in range(1, W.GLOW_LEVEL_COUNT + 1):
		levels.append(snappedf(float(written.get("glow_levels/%d" % level)), 0.01))
	return levels


## The flag and the quality are two different objects - the Environment's and the RenderingServer's -
## and one row writes both, with the engine's own remaining arguments after the quality.
static func _test_the_quality_dials() -> bool:
	var templates: Dictionary = _templates()
	return SUPPORT.pins("environment_words_test", [
		["occlusion writes the flag and the quality Project Settings would",
			templates.get("EnvTurnOcclusionOnAtQuality", ""),
			OWN_LINES + "environment.ssao_enabled = true\n"
				+ "RenderingServer.environment_set_ssao_quality({quality}, true, 0.5, 2, 50.0, 300.0)"],
		["indirect light writes its own six-argument call",
			templates.get("EnvTurnIndirectLightOnAtQuality", ""),
			OWN_LINES + "environment.ssil_enabled = true\n"
				+ "RenderingServer.environment_set_ssil_quality({quality}, true, 0.5, 4, 50.0, 300.0)"],
		# The five arguments after the quality are the ones Project Settings hands the
		# RenderingServer at boot, and the last two are METRES: `fadeout_from` 50 and `fadeout_to` 300
		# are where the effect starts and finishes fading out with distance. A row passing 0.01 and 0
		# there turns occlusion on and then fades it away within a centimetre of the camera, and
		# `half_size` false doubles the cost of an effect the project asked for at half resolution.
		["neither dial fades its effect out at the camera",
			[str(W.QUALITY_DIALS[0]["arguments"]), str(W.QUALITY_DIALS[1]["arguments"])],
			["true, 0.5, 2, 50.0, 300.0", "true, 0.5, 4, 50.0, 300.0"]],
		["global illumination's quality is a ray count",
			templates.get("EnvTurnGlobalIlluminationOnAtQuality", ""),
			OWN_LINES + "environment.sdfgi_enabled = true\n"
				+ "RenderingServer.environment_set_sdfgi_ray_count({quality})"],
		["reflections' quality is how a rough surface blurs one",
			templates.get("EnvTurnReflectionsOnAtQuality", ""),
			OWN_LINES + "environment.ssr_enabled = true\n"
				+ "RenderingServer.environment_set_ssr_roughness_quality({quality})"],
		["occlusion is the one dial with no switch word, so it mints the off row and the question",
			[templates.get("EnvTurnOcclusionOff", ""), templates.get("EnvIsOcclusionOn", "")],
			[OWN_LINES + "environment.ssao_enabled = false",
				"environment != null and environment.ssao_enabled"]],
		["and the other three take theirs from the words they already are",
			[templates.has("EnvTurnReflectionsOff"), templates.has("EnvTurnIndirectLightOff"),
				templates.has("EnvTurnGlobalIlluminationOff")], [false, false, false]]
	])


## Which renderer the game is really running on, as a question a sheet can ask - beside the frozen
## Uses Modern Renderer, which cannot tell Forward+ from Mobile.
static func _test_the_renderer_condition() -> bool:
	var found: Dictionary = {}
	for row: ACEDescriptor in EventForgeRenderingACEs.get_descriptors():
		if row.ace_id == "RenderingRendererIs":
			var options: PackedStringArray = PackedStringArray()
			for parameter: ACEParam in row.params:
				for option: Variant in parameter.options:
					options.append(str((option as Dictionary)["key"]))
			found = {"template": str(row.codegen_template), "options": ", ".join(options)}
	return SUPPORT.check("environment_words_test", "the renderer question and its three answers",
		found, {
			"template": "RenderingServer.get_current_rendering_method() == {method}",
			"options": "\"forward_plus\", \"mobile\", \"gl_compatibility\""
		})


## The sky is three objects past the node, and every row of it refuses to guess: a scene whose
## backdrop is not a procedural sky falls straight through the guard and the row does nothing.
static func _test_the_sky_words() -> bool:
	var resolved: Dictionary = {}
	for word: String in S.words():
		resolved[word] = "%s / %s" % [S.property_of(word), S.id_stem(word)]
	var ok: bool = SUPPORT.check("environment_words_test",
		"each sky word, its property and its frozen stem", resolved, {
			"sky top": "sky_top_color / SkyTop",
			"sky horizon": "sky_horizon_color / SkyHorizon",
			"sky ground": "ground_bottom_color / SkyGround",
			"sun size": "sun_angle_max / SunSize",
			"sky energy": "energy_multiplier / SkyEnergy"
		})
	var templates: Dictionary = _templates()
	return SUPPORT.pins("environment_words_test", [
		["a sky write owns the environment, the sky and the material, in that order",
			templates.get("SkySetSkyTop", ""),
			OWN_LINES + SKY_GUARD + "\tenvironment.sky.sky_material.sky_top_color = {value}"],
		["a scene with no procedural sky answers a read with the value a new sky starts on",
			templates.get("SkySkyTop", ""),
			"(environment.sky.sky_material as ProceduralSkyMaterial).sky_top_color if environment != null and environment.sky != null and environment.sky.sky_material is ProceduralSkyMaterial else Color(0.385, 0.454, 0.55)"],
		["the drawn sky is installed with the backdrop that draws it",
			templates.get("SkyUseProcedural", ""),
			OWN_LINES + "if environment.sky == null:\n\tenvironment.sky = Sky.new()\n"
				+ "elif not environment.sky.resource_path.is_empty():\n"
				+ "\tenvironment.sky = environment.sky.duplicate()\n"
				+ "environment.sky.sky_material = ProceduralSkyMaterial.new()\n"
				+ "environment.background_mode = Environment.BG_SKY"],
		# The picture is written straight in, because the field already ships the `preload(...)`
		# Browse wrote: wrapping it in `load()` would emit `load(preload("res://sky.exr"))`. And
		# the field is the PICTURE one rather than the general resource one, which lists `.tres`
		# and `.res` only and could not offer an `.exr` panorama at all.
		["the picture field lists pictures, and the row writes what it ships",
			[_hint_of("SkyUsePanorama", "image"), _hint_of("EnvSetColourGrade", "value")],
			["texture_path", "texture_path"]],
		["and so is a panorama",
			templates.get("SkyUsePanorama", ""),
			OWN_LINES + "if environment.sky == null:\n\tenvironment.sky = Sky.new()\n"
				+ "elif not environment.sky.resource_path.is_empty():\n"
				+ "\tenvironment.sky = environment.sky.duplicate()\n"
				+ "environment.sky.sky_material = PanoramaSkyMaterial.new()\n"
				+ "environment.sky.sky_material.panorama = {image}\n"
				+ "environment.background_mode = Environment.BG_SKY"]
	]) and ok


## No id is published twice, and every row the two tables promise is really there.
static func _test_ids_are_unique() -> bool:
	var seen: Dictionary = {}
	var doubled: PackedStringArray = PackedStringArray()
	for row: ACEDescriptor in MODULE.get_descriptors():
		if seen.has(row.ace_id):
			doubled.append(row.ace_id)
		seen[row.ace_id] = true
	var ok: bool = SUPPORT.check("environment_words_test", "no id is published twice", doubled,
		PackedStringArray())
	return SUPPORT.check("environment_words_test", "the module publishes every word's rows",
		seen.size(), MODULE.get_descriptors().size()) and ok


## Every row and every field says what it is for. A row that ships without words is a row nobody can
## use without reading the source.
static func _test_every_row_carries_help() -> bool:
	var silent: PackedStringArray = PackedStringArray()
	var homeless: PackedStringArray = PackedStringArray()
	for row: ACEDescriptor in MODULE.get_descriptors():
		if str(row.description).strip_edges().is_empty():
			silent.append(row.ace_id)
		for parameter: ACEParam in row.params:
			if str(parameter.description).strip_edges().is_empty():
				silent.append("%s.%s" % [row.ace_id, parameter.id])
		if str(row.node_type) != W.HOST:
			homeless.append(row.ace_id)
	var ok: bool = SUPPORT.check("environment_words_test", "every row and field carries help",
		silent, PackedStringArray())
	return SUPPORT.check("environment_words_test",
		"every row is hosted on the node it writes through", homeless, PackedStringArray()) and ok


## What only works on Forward+, derived from the two tables rather than listed a second time - so a
## word marked Forward+ and the Doctor's note about it can never drift apart.
static func _test_the_forward_plus_answer() -> bool:
	return SUPPORT.pins("environment_words_test", [
		["the properties that do nothing off Forward+", W.forward_plus_properties(),
			PackedStringArray(["volumetric_fog_density", "volumetric_fog_albedo",
				"volumetric_fog_length", "volumetric_fog_enabled", "ssr_enabled", "ssil_enabled",
				"sdfgi_enabled", "ssao_enabled"])],
		["and the quality calls that do nothing either", W.forward_plus_calls(),
			PackedStringArray(["RenderingServer.environment_set_ssao_quality(",
				"RenderingServer.environment_set_ssil_quality(",
				"RenderingServer.environment_set_sdfgi_ray_count(",
				"RenderingServer.environment_set_ssr_roughness_quality("])]
	])


## A LINE SOMEBODY TYPED reads as the word the sheet has for it - which is the other half of the
## claim, and the half a picked row cannot prove on its own.
static func _test_a_hand_written_line_reads_as_the_word() -> bool:
	return SUPPORT.pin_table("environment_words_test", {
		"environment.adjustment_saturation = 0.2": "Environment: Set saturation to 0.2",
		"environment.tonemap_exposure = 1.5": "Environment: Set exposure to 1.5",
		"environment.fog_height = 4.0": "Environment: Set fog floor to 4",
		"environment.ssr_enabled = true": "Environment: Set reflections on",
		"environment.ssil_enabled = false": "Environment: Set indirect light off",
		"environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC":
			"Environment: Set tone map to filmic",
		"environment.background_mode = Environment.BG_SKY": "Environment: Set backdrop to sky",
		"environment.sky.sky_material.sky_top_color = Color.RED":
			"Environment: Set sky top to red",
		"environment.sky.sky_material.energy_multiplier = 2.0":
			"Environment: Set sky energy to 2",
		# The two the world vocabulary already had words for keep them exactly: an override list is
		# an override list, and a second spelling of one setting is the drift the table prevents.
		"environment.fog_enabled = true": "Environment: Set fog on",
		"environment.fog_density = 0.05": "Environment: Set fog thickness to 0.05"
	}, func(line: Variant) -> String:
		var text: String = str(line)
		var written: int = text.find(" = ")
		var target: String = text.substr(0, written)
		var owner_text: String = target.substr(0, target.rfind("."))
		var member: String = target.substr(target.rfind(".") + 1)
		var said: Dictionary = EventSheetSentence.environment_assignment("", member, owner_text,
			text.substr(written + 3), {})
		if said.is_empty():
			return "(nothing)"
		var words: PackedStringArray = PackedStringArray()
		for segment: Variant in (said["segments"] as Array):
			words.append(str((segment as Dictionary)["text"]))
		return "%s: %s" % [str(said["object"]), "".join(words)])


## The ship-it note, over two made-up projects: a Forward+-only row in a Mobile project is one quiet
## note naming the renderer, and the same rows in a Forward+ project are silent.
static func _test_the_doctor_says_the_renderer() -> bool:
	const SOURCE := "func _ready() -> void:\n\tenvironment.ssr_enabled = true\n"
	var mobile: Array[Dictionary] = EventSheetShipItDoctor.renderer_findings(
		{"res://look.gd": SOURCE}, "mobile")
	var forward: Array[Dictionary] = EventSheetShipItDoctor.renderer_findings(
		{"res://look.gd": SOURCE}, "forward_plus")
	return SUPPORT.pins("environment_words_test", [
		["a Forward+ row in a Mobile project is one quiet note", mobile.size(), 1],
		["and it names the renderer and the row that does nothing",
			"" if mobile.is_empty() else str(mobile[0]["message"]),
			"look.gd asks for reflections, which only the Forward+ renderer draws - this row does nothing on mobile. Either build for Forward+, or drop the row."],
		["the same rows on Forward+ say nothing at all", forward.size(), 0]
	])


## And the sky's own quiet case: a sky word on a scene whose backdrop is never set to a sky.
static func _test_the_doctor_says_the_backdrop() -> bool:
	const NO_SKY := "func _ready() -> void:\n\tenvironment.sky.sky_material.sky_top_color = Color.RED\n"
	const WITH_SKY := NO_SKY + "\tenvironment.background_mode = Environment.BG_SKY\n"
	# The second argument is the PROOF: the scripts whose own scene was read and found to be
	# drawing something other than a sky. Without it the note fired on every file that wrote a sky
	# word and did not also write the backdrop line - which is every scene whose backdrop was set to
	# Sky in the Inspector, the normal way to do it.
	var flat: PackedStringArray = PackedStringArray(["res://look.gd"])
	var missing: Array[Dictionary] = EventSheetShipItDoctor.sky_backdrop_findings(
		{"res://look.gd": NO_SKY}, flat)
	var settled: Array[Dictionary] = EventSheetShipItDoctor.sky_backdrop_findings(
		{"res://look.gd": WITH_SKY}, flat)
	var unproven: Array[Dictionary] = EventSheetShipItDoctor.sky_backdrop_findings(
		{"res://look.gd": NO_SKY}, PackedStringArray())
	return SUPPORT.pins("environment_words_test", [
		["a sky word with no sky behind it is one quiet note", missing.size(), 1],
		["and the words say the door that fixes it",
			"" if missing.is_empty() else str(missing[0]["message"]),
			"look.gd sets the sky's colours, and nothing in it makes the sky the backdrop - the rows do nothing while the world is drawing a flat colour. Use Procedural Sky, or set the backdrop to sky."],
		["a file that does set the backdrop says nothing", settled.size(), 0],
		["and a scene that never said what it draws is left alone", unproven.size(), 0]
	])


## Every template the module publishes, by ace_id - the one walk the pins above share.
static func _templates() -> Dictionary:
	var found: Dictionary = {}
	for row: ACEDescriptor in MODULE.get_descriptors():
		found[row.ace_id] = str(row.codegen_template)
	return found


## One field's fixed OPTIONS and its typed-field SUGGESTIONS - the difference between a list a reader
## must choose from and a list they may start from.
static func _options_of(ace_id: String, param_id: String) -> Array:
	for row: ACEDescriptor in MODULE.get_descriptors():
		if row.ace_id != ace_id:
			continue
		for parameter: ACEParam in row.params:
			if parameter.id == param_id:
				return parameter.options
	return []


static func _suggestions_of(ace_id: String, param_id: String) -> Array[String]:
	for row: ACEDescriptor in MODULE.get_descriptors():
		if row.ace_id != ace_id:
			continue
		for parameter: ACEParam in row.params:
			if parameter.id == param_id:
				return parameter.autocomplete
	var none: Array[String] = []
	return none


## One field's HINT, which is what decides the widget the dialog builds for it - and, for a file
## field, which files Browse is even willing to list.
static func _hint_of(ace_id: String, param_id: String) -> String:
	for row: ACEDescriptor in MODULE.get_descriptors():
		if row.ace_id != ace_id:
			continue
		for parameter: ACEParam in row.params:
			if parameter.id == param_id:
				return str(parameter.hint)
	return ""


## One row's fields as `id=default` pairs, for a pin about what a reader is handed.
static func _fields(ace_id: String) -> String:
	for row: ACEDescriptor in MODULE.get_descriptors():
		if row.ace_id != ace_id:
			continue
		var pairs: PackedStringArray = PackedStringArray()
		for parameter: ACEParam in row.params:
			pairs.append("%s=%s" % [parameter.id, str(parameter.default_value)])
		return ", ".join(pairs)
	return ""
