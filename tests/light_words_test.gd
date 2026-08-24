# L1 / L2 - the light words, and the rows they build.
#
# The claim this file holds to account is that the sheet says ONE word where Godot says several, and
# that the word is never a guess: `brightness` is `energy` on a 2D light and `light_energy` on a 3D
# one, `reach` is three different properties depending on which light you picked, and on/off is
# `enabled` in 2D and `visible` in 3D because a Light3D has no `enabled` at all. The mapping is
# derived from ClassDB, so what is pinned here is the ANSWERS - by value, per class - rather than the
# table that produces them.
#
# Then the rows: every id the vocabulary adds, registered exactly once, hosted on the class whose
# property it writes, and carrying help on itself and on every parameter. An ace_id is a
# compatibility promise the moment it ships, so two descriptors answering to one id is a silent coin
# toss over which template a row compiles through.
@tool
class_name LightWordsTest
extends RefCounted

const W := preload("res://addons/eventforge/registration/light_words.gd")
const MODULE := preload("res://addons/eventforge/registration/modules/light_node_aces.gd")


static func run() -> bool:
	var ok: bool = true
	ok = _test_the_word_map() and ok
	ok = _test_the_rows() and ok
	ok = _test_ids_are_unique() and ok
	ok = _test_every_row_carries_help() and ok
	ok = _test_light_classes() and ok
	ok = _test_the_picker_shelf() and ok
	ok = _test_the_dialog_says_the_real_property() and ok
	return ok


## The IN CODE line the parameter dialog's help strip shows, for one verb picked on four different
## lights. The sentence is the same word every time and the code is not, which is the whole of L2:
## the row says `brightness` and the strip says what the light picked actually answers to.
static func _test_the_dialog_says_the_real_property() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.external_source_path = "res://tests/fixtures/lighting_scene_room.gd"
	var registry: EventSheetACERegistry = EventSheetACERegistry.new()
	registry.refresh_from_sources([], true)
	var lines: Dictionary = {}
	for ace_id: String in ["LightSetBrightness", "LightSetBrightness3D", "LightSetReachSpot", "LightIsLit3D"]:
		var definition: ACEDefinition = registry.find_definition("Core", ace_id)
		if definition == null:
			lines[ace_id] = "not registered"
			continue
		lines[ace_id] = ACEParamsDialog.row_code_line(definition, {"target": "$Torch", "value": "1.2"})
	return _check("the dialog's code line is the property the picked light really has", lines, {
		"LightSetBrightness": "$Torch.energy = 1.2",
		"LightSetBrightness3D": "$Torch.light_energy = 1.2",
		"LightSetReachSpot": "$Torch.spot_range = 1.2",
		"LightIsLit3D": "if $Torch.visible:"
	})


## The picker's "Lights in this scene" shelf, off a real scene: one sub-folder per light, saying
## what kind it is and whether it casts shadows, and inside it exactly the verbs that light's class
## answers to - which is why the spot light has a cone angle and the point light does not.
static func _test_the_picker_shelf() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.external_source_path = "res://tests/fixtures/lighting_scene_cave.gd"
	var registry: EventSheetACERegistry = EventSheetACERegistry.new()
	registry.refresh_from_sources([], true)
	var shelves: Dictionary = {}
	for offered: ACEDefinition in ACEPickerDialog.light_row_definitions(sheet, registry):
		var key: String = ACEPickerDialog.light_group_key(offered)
		if not shelves.has(key):
			shelves[key] = PackedStringArray()
		var listed: PackedStringArray = shelves[key]
		listed.append(offered.id)
		shelves[key] = listed
	var spot: String = "Lights in this scene: Flashlight   SpotLight3D · casts shadows"
	var sun: String = "Lights in this scene: Sun   DirectionalLight3D"
	var ok: bool = _check("every light of the scene gets its own shelf, labelled by what it is",
		shelves.keys(), ["Lights in this scene: Flashlight   SpotLight3D · casts shadows",
			"Lights in this scene: Bulb   OmniLight3D", sun])
	ok = _check("the spot light is offered its own reach and its cone angle", shelves.get(spot, PackedStringArray()),
		PackedStringArray(["LightSetBrightness3D", "LightBrightness3D", "LightFadeBrightness3D",
			"LightSetColour3D", "LightColour3D", "LightSetReachSpot", "LightReachSpot",
			"LightSetConeAngle", "LightConeAngle", "LightLit3DOn", "LightLit3DOff", "LightIsLit3D",
			"LightShadows3DOn", "LightShadows3DOff", "LightIsShadows3D"])) and ok
	ok = _check("a light with no reach of its own is offered none", shelves.get(sun, PackedStringArray()),
		PackedStringArray(["LightSetBrightness3D", "LightBrightness3D", "LightFadeBrightness3D",
			"LightSetColour3D", "LightColour3D", "LightLit3DOn", "LightLit3DOff", "LightIsLit3D",
			"LightShadows3DOn", "LightShadows3DOff", "LightIsShadows3D"])) and ok
	return _check("and a sheet no scene lights has no shelf at all",
		ACEPickerDialog.light_row_definitions(EventSheetResource.new(), registry).size(), 0) and ok


## The whole map, as one table of answers: for every light class, the property each of the five
## words resolves to. This is the file's headline claim, and it is pinned as VALUES so a change in
## the derivation shows up here as the wrong property rather than as a silently missing row.
static func _test_the_word_map() -> bool:
	var answers: Dictionary = {}
	for class_text: String in W.classes():
		var per_word: PackedStringArray = PackedStringArray()
		for word: Dictionary in W.WORDS:
			per_word.append("%s=%s" % [str(word["word"]), W.property_of(class_text, str(word["word"]))])
		answers[class_text] = " ".join(per_word)
	return _check("every light class answers the five words with its own properties", answers, {
		"PointLight2D": "brightness=energy colour=color reach=texture_scale cone angle= on=enabled shadows=shadow_enabled",
		"DirectionalLight2D": "brightness=energy colour=color reach= cone angle= on=enabled shadows=shadow_enabled",
		"OmniLight3D": "brightness=light_energy colour=light_color reach=omni_range cone angle= on=visible shadows=shadow_enabled",
		"SpotLight3D": "brightness=light_energy colour=light_color reach=spot_range cone angle=spot_angle on=visible shadows=shadow_enabled",
		"DirectionalLight3D": "brightness=light_energy colour=light_color reach= cone angle= on=visible shadows=shadow_enabled"
	})


## Every row the vocabulary builds, as `ace_id -> host class | template`. One row per distinct
## property per dimension, hosted on the most general class that answers to it: `energy` is every 2D
## light's, so its row is a Light2D row, while `texture_scale` is only PointLight2D's.
static func _test_the_rows() -> bool:
	var built: Dictionary = {}
	for descriptor: ACEDescriptor in MODULE.get_descriptors():
		built[descriptor.ace_id] = "%s | %s" % [descriptor.node_type, descriptor.codegen_template]
	return _check("every light word builds its rows on the class that answers to it", built, {
		"LightSetBrightness": "Light2D | energy = {value}",
		"LightBrightness": "Light2D | energy",
		"LightFadeBrightness": "Light2D | create_tween().tween_property({target}, \"energy\", {value}, {seconds})",
		"LightSetBrightness3D": "Light3D | light_energy = {value}",
		"LightBrightness3D": "Light3D | light_energy",
		"LightFadeBrightness3D": "Light3D | create_tween().tween_property({target}, \"light_energy\", {value}, {seconds})",
		"LightSetColour": "Light2D | color = {value}",
		"LightColour": "Light2D | color",
		"LightSetColour3D": "Light3D | light_color = {value}",
		"LightColour3D": "Light3D | light_color",
		"LightSetReach": "PointLight2D | texture_scale = {value}",
		"LightReach": "PointLight2D | texture_scale",
		"LightSetReachOmni": "OmniLight3D | omni_range = {value}",
		"LightReachOmni": "OmniLight3D | omni_range",
		"LightSetReachSpot": "SpotLight3D | spot_range = {value}",
		"LightReachSpot": "SpotLight3D | spot_range",
		"LightSetConeAngle": "SpotLight3D | spot_angle = {value}",
		"LightConeAngle": "SpotLight3D | spot_angle",
		"LightLitOn": "Light2D | enabled = true",
		"LightLitOff": "Light2D | enabled = false",
		"LightIsLit": "Light2D | enabled",
		"LightLit3DOn": "Light3D | visible = true",
		"LightLit3DOff": "Light3D | visible = false",
		"LightIsLit3D": "Light3D | visible",
		"LightShadowsOn": "Light2D | shadow_enabled = true",
		"LightShadowsOff": "Light2D | shadow_enabled = false",
		"LightIsShadows": "Light2D | shadow_enabled",
		"LightShadows3DOn": "Light3D | shadow_enabled = true",
		"LightShadows3DOff": "Light3D | shadow_enabled = false",
		"LightIsShadows3D": "Light3D | shadow_enabled"
	})


## Against the WHOLE registry, not only this module: an id that collides with a shipped one is two
## rows answering to one name, and the row a sheet gets back is then whichever the registry
## happened to build last.
static func _test_ids_are_unique() -> bool:
	var counts: Dictionary = {}
	for descriptor: ACEDescriptor in ACERegistry.get_all_descriptors():
		counts[descriptor.ace_id] = int(counts.get(descriptor.ace_id, 0)) + 1
	var absent: PackedStringArray = PackedStringArray()
	var duplicated: PackedStringArray = PackedStringArray()
	for descriptor: ACEDescriptor in MODULE.get_descriptors():
		var seen: int = int(counts.get(descriptor.ace_id, 0))
		if seen == 0:
			absent.append(descriptor.ace_id)
		elif seen > 1:
			duplicated.append(descriptor.ace_id)
	var ok: bool = _check("every light row is registered", absent, PackedStringArray())
	return _check("and no light id collides with a shipped one", duplicated, PackedStringArray()) and ok


## The row and every parameter say what they are for. A row that shipped without help is a row whose
## dialog has nothing to put in the help strip.
static func _test_every_row_carries_help() -> bool:
	var silent: PackedStringArray = PackedStringArray()
	for descriptor: ACEDescriptor in MODULE.get_descriptors():
		if descriptor.description.strip_edges().is_empty():
			silent.append(descriptor.ace_id)
		for param: ACEParam in descriptor.params:
			if str(param.description).strip_edges().is_empty():
				silent.append("%s.%s" % [descriptor.ace_id, param.id])
	return _check("every light row and parameter carries real help", silent, PackedStringArray())


## What counts as a light, and what a reader calls it. Answered through ClassDB rather than against
## a list, so a project's own subclass of a light is still a light - and a CanvasModulate, which the
## darkness rows are about, is not one.
static func _test_light_classes() -> bool:
	var verdicts: Dictionary = {}
	for class_text: String in ["PointLight2D", "SpotLight3D", "CanvasModulate", "WorldEnvironment", "Sprite2D", "NotAClass"]:
		verdicts[class_text] = W.is_light_class(class_text)
	var ok: bool = _check("only the lights are lights", verdicts, {
		"PointLight2D": true, "SpotLight3D": true, "CanvasModulate": false,
		"WorldEnvironment": false, "Sprite2D": false, "NotAClass": false
	})
	var words: Dictionary = {}
	for class_text: String in W.classes():
		words[class_text] = W.kind_word(class_text)
	return _check("and each says what kind it is in one word", words, {
		"PointLight2D": "point", "DirectionalLight2D": "directional", "OmniLight3D": "omni",
		"SpotLight3D": "spot", "DirectionalLight3D": "directional"
	}) and ok


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] light_words_test: %s" % label)
		return true
	print("[FAIL] light_words_test: %s" % label)
	print("  expected: %s" % expected)
	print("  actual:   %s" % actual)
	return false
