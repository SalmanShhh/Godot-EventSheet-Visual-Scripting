# EventForge module - the ENVIRONMENT vocabulary: what the whole world looks like, said in words.
#
# THE WORLD NODE AS THE OBJECT. Every row here is node-scoped: the WorldEnvironment sits in the
# object column and the row says the word - "World - Set saturation to 0.2" - while the code echo
# shows the property the Environment really has. Nothing is written twice. The words come from
# EventForgeEnvironmentWords and EventForgeSkyWords, which ask ClassDB which spelling each word
# resolves to and what value it opens on, and every row of every word is built by one of the five
# builders below (a value, a colour, a switch, a choice, a file).
#
# THEY LAND BESIDE THE FROZEN ROWS, never on top of them. The eight Core environment actions
# (Set Fog On/Off, Set Fog Density, Set Fog Colour, Set Glow On/Off, Set Glow Strength, Set Ambient
# Occlusion On/Off, Set Ambient Light, Set Sky Rotation) take the environment as a parameter and keep
# compiling exactly as they did; the seven node-scoped World rows beside them (Turn Fog On, Turn Glow
# Off, Set Fog Thickness, Set Ambient Light, Fade The Glow, Make The Environment This Scene's Own)
# keep their ace_ids and their templates. Everything in this file is a NEW id.
#
# THE OWN-IT COURTESY IS IN THE TEMPLATE, not in a row a reader has to remember. An Environment is a
# FILE: two scenes pointing at the same `.tres` point at ONE object, so turning the fog up in the
# cave turns it up in the town, and the change follows the player out of the room. So every write
# below opens with the lines that give this scene its own copy - a plain Environment when the node is
# holding nothing, a duplicate when it is holding a file. It is emitted, never assumed, and it is
# taken once. The frozen "Make The Environment This Scene's Own" row is still the right row for a
# reader who wants the copy taken at a moment they choose; these rows simply never depend on it.
#
# WHICH IS ALSO WHY THE WRITING ROWS ARE HOST-ONLY. Their templates open with an `if`, so the
# cross-node transform leaves them alone: a row that gives ANOTHER node's environment its own copy
# and then wrote through it would have to spell the same guard twice around a node named in the
# middle. The READ rows are plain member reads and take the ordinary "On node" the transform appends
# to every such row - looking at a world's saturation changes nothing about it.
#
# RENDERER HONESTY. Screen-space reflections, indirect light, global illumination and volumetric fog
# are Forward+ features. On Mobile and on Compatibility the flag is set, the renderer ignores it, and
# nothing errors - so every row of those words SAYS so, in its own description and in the help words a
# reader meets on the row, and the Doctor's ship-it section says it once more for a project whose
# rendering method is not Forward+.
#
# Module contract: see ace_factory.gd - ace_ids/templates are API (compatibility covenant).
@tool
class_name EventForgeEnvironmentACEs
extends RefCounted

const F := preload("res://addons/eventforge/registration/ace_factory.gd")
const W := preload("res://addons/eventforge/registration/environment_words.gd")
const S := preload("res://addons/eventforge/registration/sky_words.gd")

## The picker category every row here is filed under - the same shelf the eight frozen Core
## environment actions already sit on, so "Environment" is one section of the vocabulary rather than
## two that have to be read together.
const CAT := "Environment"

## How long a fade takes when nobody says - the same half second every other fade in the vocabulary
## opens on, so two fades side by side start in step.
const DEFAULT_FADE_SECONDS := "0.5"

## The slot every word's value is edited in, spelled once so the tests and the picker address them
## all by it.
const VALUE_PARAM := "value"

## The slot a quality dial's answer is edited in, and the slot a glow level's number is.
const QUALITY_PARAM := "quality"
const LEVEL_PARAM := "level"
const AMOUNT_PARAM := "amount"
const SPREAD_PARAM := "spread"
const IMAGE_PARAM := "image"

## The field a picture is picked in - a file field over the project's own resources, rather than an
## expression box a path has to be typed into by hand.
const RESOURCE_HINT := "resource_path"


static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []
	for word: String in W.words():
		descriptors.append_array(_rows_of(word))
	descriptors.append_array(_glow_level_rows())
	descriptors.append_array(_quality_rows())
	for word: String in S.words():
		descriptors.append_array(_sky_rows(S.word_entry(word)))
	descriptors.append_array(_sky_kind_rows())
	return descriptors


static func section_descriptions() -> Dictionary:
	return {CAT: "What the whole world looks like, said in words: how colourful and how bright the picture is, how much light the camera lets in, where the fog lies and how thick the air is, what the glow does, which sky is behind everything and what colour it is at the top, at the horizon and on the ground. Every write gives this scene its own copy of the environment first, so a shared environment file never changes under the other scenes that load it."}


# ── The words ────────────────────────────────────────────────────────────────────────────────────


## Every row one word makes, by the kind of thing the word is.
static func _rows_of(word: String) -> Array[ACEDescriptor]:
	var entry: Dictionary = W.word_entry(word)
	match str(entry["kind"]):
		W.KIND_SWITCH:
			return _switch_rows(entry)
		W.KIND_CHOICE:
			return _choice_rows(entry)
		W.KIND_RESOURCE:
			return _resource_rows(entry)
		W.KIND_COLOUR:
			return _colour_rows(entry)
		_:
			return _value_rows(entry)


## A word that is set to a NUMBER: the Set row, the expression that reads it back, and - for a word
## the world can be walked to over time - the one-line tween a fade is.
static func _value_rows(entry: Dictionary) -> Array[ACEDescriptor]:
	var word: String = str(entry["word"])
	var rows: Array[ACEDescriptor] = [
		_set_row(entry).param_typed("String", VALUE_PARAM, W.default_of(word), _label(entry),
			str(entry["about"]), "expression"),
		_read_row(entry)
	]
	if bool(entry.get("fades", false)):
		rows.append(_fade_row(entry))
	return rows


## A word that is set to a COLOUR - the same pair, with the field that opens a colour picker.
static func _colour_rows(entry: Dictionary) -> Array[ACEDescriptor]:
	var word: String = str(entry["word"])
	var rows: Array[ACEDescriptor] = [
		_set_row(entry).param_typed("Color", VALUE_PARAM, W.default_of(word), _label(entry),
			str(entry["about"]), "color"),
		_read_row(entry)
	]
	if bool(entry.get("fades", false)):
		rows.append(_fade_row(entry))
	return rows


## A word that is set to a FILE. No fade: a picture is swapped, never walked to.
static func _resource_rows(entry: Dictionary) -> Array[ACEDescriptor]:
	return [
		_set_row(entry).param_typed("String", VALUE_PARAM, W.default_of(str(entry["word"])),
			_label(entry), str(entry["about"]), RESOURCE_HINT),
		_read_row(entry)
	]


## A word that is one of a FIXED LIST of engine constants - a dropdown reading the plain word while
## the key stays the constant the template writes. A word with companion properties carries them on
## the same row, because they are the same decision: which tone map, and where its white point is.
static func _choice_rows(entry: Dictionary) -> Array[ACEDescriptor]:
	var word: String = str(entry["word"])
	var setter: ACEDescriptor = _set_row(entry).param_built(_choice_param(entry, W.default_of(word)))
	for companion: Variant in (entry.get("companions", []) as Array):
		var field: Dictionary = companion
		var property: String = str(field["property"])
		var is_colour: bool = str(field.get("kind", W.KIND_VALUE)) == W.KIND_COLOUR
		setter.param_typed("Color" if is_colour else "String", str(field["param"]),
			W.default_literal(property), str(field["label"]), str(field["about"]),
			"color" if is_colour else "expression")
	return [setter, _read_row(entry)]


## A word that is ON or OFF: two actions that say which, and the condition that asks. Two actions
## rather than one with a true/false field, because "Turn volumetric fog off" is the sentence a
## reader writes and "Set volumetric fog false" is the one they have to decode.
static func _switch_rows(entry: Dictionary) -> Array[ACEDescriptor]:
	var word: String = str(entry["word"])
	var stem: String = W.id_stem(word)
	var property: String = W.property_of(word)
	return [
		F.act("Env%sOn" % stem, str(entry["on_name"]), _write_template(entry, "true"), CAT,
			str(entry["on_verb"]), _about(entry), W.HOST).featured(),
		F.act("Env%sOff" % stem, str(entry["off_name"]), _write_template(entry, "false"), CAT,
			str(entry["off_verb"]), _about(entry), W.HOST),
		F.cond("EnvIs%s" % stem, str(entry["asks"]),
			_asked(property), CAT, str(entry["ask_verb"]),
			"True while %s. Reads %s, and answers false on a node holding no environment at all." % [
				str(entry["ask_verb"]), _echo(entry)], W.HOST)
	]


## The Set row of any word: the own-it lines, whatever switch the word does nothing without, and then
## the write itself.
static func _set_row(entry: Dictionary) -> ACEDescriptor:
	var word: String = str(entry["word"])
	var row: ACEDescriptor = F.act("EnvSet%s" % W.id_stem(word), str(entry["name"]),
		_write_template(entry, "{%s}" % VALUE_PARAM), CAT, str(entry["verb"]), _about(entry), W.HOST)
	return row.featured() if bool(entry.get("featured", false)) else row


## The expression that reads a word back - the plain member a person would type, so a hand-written
## read and a picked one are the same bytes.
static func _read_row(entry: Dictionary) -> ACEDescriptor:
	var word: String = str(entry["word"])
	return F.expr("Env%s" % W.id_stem(word), str(entry["name"]).trim_prefix("Set "),
		_read(W.property_of(word), W.default_of(word)), CAT, str(entry["reads"]),
		"Reads the world's %s back: %s. A node holding no environment at all answers with the value a new one starts on. Use it in any value field." % [
			word, _echo(entry)], W.HOST)


## The one row that is not a plain write: a tween walks the property from where it is to where the
## row says, over a number of seconds. The own-it lines come first here too, because the tween holds
## on to the environment it was handed and would otherwise walk a shared one.
static func _fade_row(entry: Dictionary) -> ACEDescriptor:
	var word: String = str(entry["word"])
	var is_colour: bool = str(entry["kind"]) == W.KIND_COLOUR
	var template: String = "%screate_tween().tween_property(%s, \"%s\", {%s}, {seconds})" % [
		_preamble(entry), W.ENVIRONMENT_MEMBER, W.property_of(word), VALUE_PARAM]
	return F.act("EnvFade%s" % W.id_stem(word), "Fade %s" % _fade_name(entry), template, CAT,
		"Fade %s to {%s} over {seconds} s" % [word, VALUE_PARAM],
		"Walks the world's %s to a new value over time instead of jumping to it - one tween, no state to keep. Writes %s on this scene's own copy of the environment." % [
			word, _echo(entry)], W.HOST).param_typed(
		"Color" if is_colour else "String", VALUE_PARAM, W.default_of(word), _label(entry),
		"The %s to arrive at." % word, "color" if is_colour else "expression").param_typed(
		"String", "seconds", DEFAULT_FADE_SECONDS, "Seconds", "How long the fade takes.",
		"expression")


## The whole write of one word: the preamble, the member operation itself, and then whatever
## companion properties the same decision also settles.
static func _write_template(entry: Dictionary, written: String) -> String:
	var lines: String = "%s%s.%s = %s" % [_preamble(entry), W.ENVIRONMENT_MEMBER,
		W.property_of(str(entry["word"])), written]
	for companion: Variant in (entry.get("companions", []) as Array):
		var field: Dictionary = companion
		lines += "\n%s.%s = {%s}" % [W.ENVIRONMENT_MEMBER, str(field["property"]),
			str(field["param"])]
	return lines


## Everything a write needs before it: this scene's own copy of the environment, then whatever switch
## the word does nothing without (bloom needs the glow on; saturation needs the adjustments on).
static func _preamble(entry: Dictionary) -> String:
	var lines: String = W.OWN_LINES
	if entry.has("turns_on"):
		lines += "%s.%s = true\n" % [W.ENVIRONMENT_MEMBER, str(entry["turns_on"])]
	return lines


## The dropdown one choice word offers. `display_option_labels` is what makes the ROW read "Set tone
## map to filmic" instead of "Set tone map to Environment.TONE_MAPPER_FILMIC": the KEY is still the
## engine constant (it is what the template writes and what every saved row holds, both frozen), and
## only the word a reader sees changes.
static func _choice_param(entry: Dictionary, opening: String) -> ACEParam:
	var parameter: ACEParam = F.make_param(VALUE_PARAM, "String", opening, _label(entry),
		str(entry["about"]), "", entry["choices"] as Array)
	parameter.display_option_labels = true
	return parameter


## What a row does, said once per word: the word, then the own-it promise, then the property the
## Environment really answers to - so the description and the code echo can never disagree.
static func _about(entry: Dictionary) -> String:
	return "%s Gives this scene its own copy of the environment first, so an environment file shared with other scenes never changes under them. Writes %s." % [
		str(entry["about"]), _echo(entry)]


## THE READS ASK FIRST, and they have to. A WorldEnvironment holding no Environment is the state
## every one of them starts in - the node is dropped, the slot is empty - and a bare
## `environment.saturation` there is an "attempt to access on a null instance" at run time. The
## WRITES are guarded already, by the own-it lines that fill the slot before they touch it; these
## are the other half. A node with no world answers with the value a new Environment starts on,
## which is the same promise the sky reads make and the same shape they are written in.
static func _read(property: String, opening: String) -> String:
	return "%s.%s if %s != null else %s" % [W.ENVIRONMENT_MEMBER, property, W.ENVIRONMENT_MEMBER,
		opening]


## The same question as a CONDITION. A switch nobody has an environment for is off, which is what
## `and` says in one line without a value to fall back on.
static func _asked(property: String) -> String:
	return "%s != null and %s.%s" % [W.ENVIRONMENT_MEMBER, W.ENVIRONMENT_MEMBER, property]


## The property a row writes, as the reader sees it in the code echo.
static func _echo(entry: Dictionary) -> String:
	return "`%s.%s`" % [W.ENVIRONMENT_CLASS, W.property_of(str(entry["word"]))]


## The field's name in the dialog: the word's own label where it has one, and the word itself
## otherwise.
static func _label(entry: Dictionary) -> String:
	return str(entry.get("label", str(entry["word"]).capitalize()))


## What a FADE row is called: the word's Set row without its verb, so "Set Glow Bloom" and "Fade Glow
## Bloom" are the same words twice. The dialog LABEL is not used here - it is a field's name, written
## in the sentence case a field wears, and "Fade Floor thickness" is not a row title.
static func _fade_name(entry: Dictionary) -> String:
	return str(entry["name"]).trim_prefix("Set ")


# ── The glow levels ──────────────────────────────────────────────────────────────────────────────


## THE ONE SETTING THAT IS NOT A PROPERTY. Godot keeps the glow's seven blur levels as
## `glow_levels/1` through `glow_levels/7` and reaches them through `set_glow_level(i, n)`, and seven
## numbers is not a row anybody can read. So there are two rows: one that lays a whole shape down at
## once from three written-down starting tables, and one that sets a single level by hand for a
## project that wants its own shape. The three tables are STARTERS, not a house style - the second row
## reaches every one of the seven, and a project that spells its own shape never asks the first again.
static func _glow_level_rows() -> Array[ACEDescriptor]:
	return [
		F.act("EnvSetGlowLevels", "Set Glow Levels", _glow_spread_template(), CAT,
			"Set glow levels to {%s}" % SPREAD_PARAM,
			"Lays down all seven of the glow's blur levels at once. Level 1 is the sharpest and finest, level 7 the widest and softest, so a shape leaning on the low numbers keeps the glow around what is glowing and one leaning on the high numbers washes it across the screen. Switches the glow on as well. Set Glow Level sets any single level by hand.",
			W.HOST).param_built(_spread_param()).featured(),
		F.act("EnvSetGlowLevel", "Set Glow Level", _glow_level_template(), CAT,
			"Set glow level {%s} to {%s}" % [LEVEL_PARAM, AMOUNT_PARAM],
			"Sets ONE of the glow's seven blur levels, for a project spelling its own shape rather than taking one of the three the row above offers. Level 1 is the sharpest and finest blur, level 7 the widest and softest. Switches the glow on as well.",
			W.HOST).param_typed("String", LEVEL_PARAM, "1", "Level",
			"Which blur level to set, 1 to %d. 1 is the sharpest, %d the widest." % [
				W.GLOW_LEVEL_COUNT, W.GLOW_LEVEL_COUNT], "expression").param_typed(
			"String", AMOUNT_PARAM, "1.0", "Amount",
			"How much this level contributes. 0 leaves it out entirely.", "expression")
	]


## The whole-shape row's template: the own-it lines, the glow switched on, the seven numbers named
## once in a local of their own, and the loop that hands them to the engine one at a time. The local
## is uid-suffixed so two of these rows in one function cannot collide.
static func _glow_spread_template() -> String:
	return "%s%s.glow_enabled = true\nvar __glow_{uid}: PackedFloat32Array = {%s}\nfor __level_{uid}: int in range(1, %d):\n\t%s.%s(__level_{uid}, __glow_{uid}[__level_{uid} - 1])" % [
		W.OWN_LINES, W.ENVIRONMENT_MEMBER, SPREAD_PARAM, W.GLOW_LEVEL_COUNT + 1,
		W.ENVIRONMENT_MEMBER, W.GLOW_LEVEL_SET_CALL]


## One level's template: the own-it lines, the glow switched on, and the engine's own call.
static func _glow_level_template() -> String:
	return "%s%s.glow_enabled = true\n%s.%s({%s}, {%s})" % [W.OWN_LINES, W.ENVIRONMENT_MEMBER,
		W.ENVIRONMENT_MEMBER, W.GLOW_LEVEL_SET_CALL, LEVEL_PARAM, AMOUNT_PARAM]


## The dropdown of written-down shapes. The KEY is the seven numbers themselves, spelled as the array
## the template assigns, so what a saved row holds is the shape rather than a name that would have to
## be looked up again - and a reader who opens the field sees the plain words instead.
static func _spread_param() -> ACEParam:
	var choices: Array = []
	var opening: String = ""
	for spread: Dictionary in W.GLOW_LEVEL_SPREADS:
		var numbers: PackedStringArray = PackedStringArray()
		for level: Variant in (spread["levels"] as Array):
			numbers.append(F.float_literal(float(level)))
		var written: String = "PackedFloat32Array([%s])" % ", ".join(numbers)
		if opening.is_empty():
			opening = written
		choices.append({"key": written, "label": "%s" % str(spread["label"])})
	var parameter: ACEParam = F.make_param(SPREAD_PARAM, "String", opening, "Shape",
		"Which of the three written-down shapes the seven levels take. Set Glow Level sets any one of them to any number instead.",
		"", choices)
	parameter.display_option_labels = true
	return parameter


# ── The quality dials ────────────────────────────────────────────────────────────────────────────


## FOUR SWITCHES WITH A QUALITY BEHIND THEM. Occlusion, indirect light, global illumination and
## reflections each have a matching quality setting that Project Settings writes once at boot - and
## Godot keeps that setting on the RenderingServer rather than on the Environment, so the flag and the
## quality are two different objects a graphics menu has to write together. One row says both.
##
## The Off row and the question are only minted where the words do not already have them: the three
## Forward+ switches are words in the table above and already ship a Turn Off and an Is On, so only
## occlusion - which has a frozen parameter-taking row and no node-scoped one - gets its pair here.
static func _quality_rows() -> Array[ACEDescriptor]:
	var rows: Array[ACEDescriptor] = []
	for dial: Dictionary in W.QUALITY_DIALS:
		var stem: String = str(dial["stem"])
		rows.append(F.act("EnvTurn%sOnAtQuality" % stem, str(dial["name"]), _quality_template(dial),
			CAT, str(dial["verb"]), "%s Gives this scene its own copy of the environment first, so an environment file shared with other scenes never changes under them. Writes `%s.%s` and `RenderingServer.%s`." % [
				str(dial["about"]), W.ENVIRONMENT_CLASS, str(dial["flag"]), str(dial["call"])],
			W.HOST).param_built(_quality_param(dial)))
		if dial.has("off_name"):
			rows.append(F.act("EnvTurn%sOff" % stem, str(dial["off_name"]),
				"%s%s.%s = false" % [W.OWN_LINES, W.ENVIRONMENT_MEMBER, str(dial["flag"])], CAT,
				str(dial["off_verb"]), "%s Writes `%s.%s`." % [str(dial["off_about"]),
					W.ENVIRONMENT_CLASS, str(dial["flag"])], W.HOST))
			rows.append(F.cond("EnvIs%sOn" % stem, str(dial["asks"]),
				_asked(str(dial["flag"])), CAT, str(dial["ask_verb"]),
				"%s Reads `%s.%s`, and answers false on a node holding no environment at all." % [
					str(dial["ask_about"]), W.ENVIRONMENT_CLASS, str(dial["flag"])], W.HOST))
	return rows


## One dial's template: the own-it lines, the Environment flag, and then the RenderingServer call
## Project Settings would have made - with the engine's own remaining arguments after the quality,
## because `environment_set_ssao_quality` takes six and only the first of them is a quality.
static func _quality_template(dial: Dictionary) -> String:
	var arguments: String = str(dial["arguments"])
	var rest: String = "" if arguments.is_empty() else ", %s" % arguments
	return "%s%s.%s = true\nRenderingServer.%s({%s}%s)" % [W.OWN_LINES, W.ENVIRONMENT_MEMBER,
		str(dial["flag"]), str(dial["call"]), QUALITY_PARAM, rest]


## The quality dropdown one dial offers, reading the plain word while the key stays the engine
## constant the call is handed.
static func _quality_param(dial: Dictionary) -> ACEParam:
	var parameter: ACEParam = F.make_param(QUALITY_PARAM, "String", str(dial["default"]), "Quality",
		"How carefully this is worked out. Higher looks better and costs more frames.", "",
		dial["choices"] as Array)
	parameter.display_option_labels = true
	return parameter


# ── The sky ──────────────────────────────────────────────────────────────────────────────────────


## Every row one sky word makes: the Set row, the expression that reads it back, and the tween that
## walks it there over time - which is what a day turning into an evening actually is.
static func _sky_rows(entry: Dictionary) -> Array[ACEDescriptor]:
	var word: String = str(entry["word"])
	var is_colour: bool = str(entry["kind"]) == S.KIND_COLOUR
	var setter: ACEDescriptor = F.act("SkySet%s" % S.id_stem(word), str(entry["name"]),
		_sky_template(entry, "%s.%s = {%s}" % [S.SKY_MATERIAL_PATH, S.property_of(word),
			VALUE_PARAM]), CAT, str(entry["verb"]), _sky_about(entry), S.HOST).param_typed(
		"Color" if is_colour else "String", VALUE_PARAM, S.default_of(word), _label(entry),
		str(entry["about"]), "color" if is_colour else "expression")
	if bool(entry.get("featured", false)):
		setter.featured()
	var reader: ACEDescriptor = F.expr("Sky%s" % S.id_stem(word),
		str(entry["name"]).trim_prefix("Set "), S.read_expression(word), CAT, str(entry["reads"]),
		"Reads the sky's %s back: `%s.%s`. A scene with no sky, or one wearing a panorama or a sky shader, answers with the value a new sky starts on. Use it in any value field." % [
			word, S.PROCEDURAL_CLASS, S.property_of(word)], S.HOST)
	var fade: ACEDescriptor = F.act("SkyFade%s" % S.id_stem(word), "Fade %s" % _fade_name(entry),
		_sky_template(entry, "create_tween().tween_property(%s, \"%s\", {%s}, {seconds})" % [
			S.SKY_MATERIAL_PATH, S.property_of(word), VALUE_PARAM]), CAT,
		"Fade %s to {%s} over {seconds} s" % [word, VALUE_PARAM],
		"Walks the sky's %s to a new value over time instead of jumping to it - one tween, no state to keep, and the whole of a sunset. Gives this scene its own copy of the sky material first. Does nothing on a scene whose backdrop is not a procedural sky." % word,
		S.HOST).param_typed("Color" if is_colour else "String", VALUE_PARAM, S.default_of(word),
		_label(entry), "The %s to arrive at." % word,
		"color" if is_colour else "expression").param_typed("String", "seconds",
		DEFAULT_FADE_SECONDS, "Seconds", "How long the fade takes.", "expression")
	return [setter, reader, fade]


## One sky row's whole template: this scene's own environment, the guard that says there really is a
## procedural sky here, this scene's own copy of the sky and of its material, and then the one line
## the row is about - indented, because it lives inside the guard.
static func _sky_template(_entry: Dictionary, written: String) -> String:
	return "%s%s\n%s\t%s" % [W.OWN_LINES, S.GUARD_LINE, S.OWN_LINES, written]


## What a sky row does, said once per word: the word, the own-it promise, the quiet refusal, and the
## property the sky material really answers to.
static func _sky_about(entry: Dictionary) -> String:
	return "%s Gives this scene its own copy of the sky material first, so a sky file shared with other scenes never changes under them. A scene whose backdrop is not a procedural sky is left completely alone - the row does nothing rather than erroring, and the Doctor says so. Writes `%s.%s`." % [
		str(entry["about"]), S.PROCEDURAL_CLASS, S.property_of(str(entry["word"]))]


## THE TWO KIND-SWAPS: which sky is behind everything at all. Both give the scene its own environment
## and its own Sky first, install a fresh material of the kind asked for, and set the backdrop to sky,
## because a sky nothing is drawing is a sky nobody sees.
static func _sky_kind_rows() -> Array[ACEDescriptor]:
	var own_sky: String = "%sif %s.%s == null:\n\t%s.%s = %s.new()\nelif not %s.%s.resource_path.is_empty():\n\t%s.%s = %s.%s.duplicate()\n" % [
		W.OWN_LINES, S.ENVIRONMENT_MEMBER, S.SKY_MEMBER, S.ENVIRONMENT_MEMBER, S.SKY_MEMBER,
		S.SKY_CLASS, S.ENVIRONMENT_MEMBER, S.SKY_MEMBER, S.ENVIRONMENT_MEMBER, S.SKY_MEMBER,
		S.ENVIRONMENT_MEMBER, S.SKY_MEMBER]
	var backdrop: String = "%s.background_mode = %s.BG_SKY" % [W.ENVIRONMENT_MEMBER,
		W.ENVIRONMENT_CLASS]
	return [
		F.act("SkyUseProcedural", "Use Procedural Sky",
			"%s%s = %s.new()\n%s" % [own_sky, S.SKY_MATERIAL_PATH, S.PROCEDURAL_CLASS, backdrop],
			CAT, "Use a procedural sky",
			"Puts Godot's own drawn sky behind everything - a gradient from the top colour down through the horizon to the ground, with the sun of any DirectionalLight3D in the scene painted on it - and sets the backdrop to sky so it is actually drawn. This is the sky the five sky words move; a scene without it is what makes them quietly do nothing.",
			S.HOST).featured(),
		F.act("SkyUsePanorama", "Use Panorama Sky",
			"%s%s = %s.new()\n%s.panorama = load({%s})\n%s" % [own_sky, S.SKY_MATERIAL_PATH,
				S.PANORAMA_CLASS, S.SKY_MATERIAL_PATH, IMAGE_PARAM, backdrop],
			CAT, "Use {%s} as the sky" % IMAGE_PARAM,
			"Wraps one picture around the whole world as the sky - a photographed or painted panorama, which is what a stylised or a photoreal scene wants instead of a drawn gradient. Sets the backdrop to sky so it is actually drawn. The five sky words do not reach a panorama: those are the drawn sky's own colours.",
			S.HOST).param_typed("String", IMAGE_PARAM, "\"\"", "Picture",
			"The panorama image, as an equirectangular picture in the project.", RESOURCE_HINT)
	]
