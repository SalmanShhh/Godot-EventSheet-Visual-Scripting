# The dials, read from the shader instead of typed - the reader, the words and the picker.
#
# A `.gdshader` already declares everything a row needs: the name, the type, the range, the value it
# starts at, and the `//` line an author wrote above it. Everything measured here is that file being
# read and those facts turning into a row somebody can pick, so nothing in the chain is ever a guess:
#
#   the PARSER, by value - every field of every declaration shape, including the ones it must NOT
#   claim (a split declaration is left alone rather than half-read);
#   the ROWS - five new ids beside the four frozen ones, their templates after the node-scoped
#   transform, and the flag that keeps them out of the picker's browse and out of the reverse index;
#   the READING - `effect.dissolve`, and the lead marked so the canvas draws it quietly;
#   the PICKER - one shelf per wearing node, named with its shader, one entry per dial per verb with
#   both already answered;
#   the FINDING - a row naming a dial the shader does not declare, and the declared name it was
#   nearly, offered as one click.
@tool
class_name ShaderDialsTest
extends RefCounted

const Pins := preload("res://tests/pin_table.gd")

const FIXTURE_DIR: String = "res://tests/fixtures/"
const BOSS: String = "effect_scene_boss.gd"
const DISSOLVE_SHADER: String = FIXTURE_DIR + "effect_dissolve.gdshader"

## A shader written the way people write them, with every declaration shape in it: a hinted float, a
## colour, a texture with two hints, an int with a step, a global, an array, a bare one, a note
## trailing the line it belongs to, two declarations sharing a line, a note in the middle of one, a
## uniform COMMENTED OUT the ordinary way, and a comment that belongs to the statement above rather
## than to the uniform two lines down.
const SOURCE: String = """shader_type canvas_item;

// How much has burned away.
uniform float dissolve : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint : source_color = vec4(1.0);
uniform sampler2D noise : repeat_enable, filter_linear;
uniform int steps : hint_range(1, 16, 1) = 8;
global uniform float wind_strength;
uniform float weights[4];
uniform bool lit;
uniform float speed = 2.0; // how fast the edge creeps
uniform float glow = 0.5; uniform float haze = 0.25;

/*
uniform float ghost = 1.0;
*/
uniform float /* left over from the first try */ shimmer = 0.1;

// This note is about the function, not about anything below it.
void fragment() {
	COLOR.a *= 1.0 - dissolve;
}
"""


static func run() -> bool:
	var ok: bool = true
	ok = _test_the_parser() and ok
	ok = _test_the_cache() and ok
	ok = _test_the_reading() and ok
	ok = _test_the_rows() and ok
	ok = _test_the_picker() and ok
	ok = _test_the_editors() and ok
	ok = _test_the_finding() and ok
	return ok


## Every declaration, as the fields a row is built from. Pinned by VALUE, because a hint read wrong
## is a field edited wrong and a default read wrong is a row that opens on a number nobody chose.
## The whole list is the pin, so `ghost` - the uniform wrapped in `/* … */` - failing to be in it is
## as much a measurement as every dial that is: a dial nobody declares is one the picker shelves,
## the lift claims a line for and the health check then clears.
static func _test_the_parser() -> bool:
	var read: Array[String] = []
	for uniform: Dictionary in EventForgeShaderUniforms.parse(SOURCE):
		read.append("%s %s hints=%s default=%s scope=%s colour=%s texture=%s about=%s" % [
			str(uniform["name"]), str(uniform["type"]), "|".join(uniform["hints"] as PackedStringArray),
			str(uniform["default"]), str(uniform["scope"]), str(uniform["is_color"]),
			str(uniform["sampler"]), str(uniform["about"])])
	var ok: bool = _check("every uniform shape reads as its fields", read, [
		"dissolve float hints=hint_range(0.0, 1.0) default=0.0 scope= colour=false texture=false about=How much has burned away.",
		"tint vec4 hints=source_color default=vec4(1.0) scope= colour=true texture=false about=",
		"noise sampler2D hints=repeat_enable|filter_linear default= scope= colour=false texture=true about=",
		"steps int hints=hint_range(1, 16, 1) default=8 scope= colour=false texture=false about=",
		"wind_strength float hints= default= scope=global colour=false texture=false about=",
		"weights float hints= default= scope= colour=false texture=false about=",
		"lit bool hints= default= scope= colour=false texture=false about=",
		"speed float hints= default=2.0 scope= colour=false texture=false about=",
		"glow float hints= default=0.5 scope= colour=false texture=false about=",
		"haze float hints= default=0.25 scope= colour=false texture=false about=",
		"shimmer float hints= default=0.1 scope= colour=false texture=false about="
	] as Array[String])
	# The two hints a field is derived from, kept apart from the author's own hint text: the ends of
	# a slider, and whether four numbers are a colour.
	ok = _check("a range reads as its ends and its step",
		EventForgeShaderUniforms.find(DISSOLVE_SHADER, "steps").get("range", {}),
		{"from": 1.0, "to": 16.0, "step": 1.0}) and ok
	ok = _check("and a dial with no range says so",
		EventForgeShaderUniforms.find(DISSOLVE_SHADER, "edge_tint").get("range", {}), {}) and ok
	# What the picker shows beside a dial's name when the shader's author wrote no comment.
	return _check("one dial reads as its declaration", PackedStringArray([
		EventForgeShaderUniforms.reading(EventForgeShaderUniforms.find(DISSOLVE_SHADER, "dissolve")),
		EventForgeShaderUniforms.reading(EventForgeShaderUniforms.find(DISSOLVE_SHADER, "burn_noise"))
	]), PackedStringArray(["float 0..1 = 0.0", "sampler2D"])) and ok


## The file is read once and answered from a table after that - the picker asks per keystroke and the
## lift asks per line, so a second read per ask would be a project scan in disguise. What is pinned is
## the ANSWER either way, and that dropping the cache changes nothing about it.
static func _test_the_cache() -> bool:
	EventForgeShaderUniforms.clear_cache()
	var first: PackedStringArray = EventForgeShaderUniforms.names_of(DISSOLVE_SHADER)
	var cached: PackedStringArray = EventForgeShaderUniforms.names_of(DISSOLVE_SHADER)
	EventForgeShaderUniforms.clear_cache()
	var reread: PackedStringArray = EventForgeShaderUniforms.names_of(DISSOLVE_SHADER)
	var ok: bool = _check("the dials are the same whether read or remembered",
		PackedStringArray([",".join(first), ",".join(cached), ",".join(reread)]),
		PackedStringArray(["dissolve,edge_tint,burn_noise,steps", "dissolve,edge_tint,burn_noise,steps",
			"dissolve,edge_tint,burn_noise,steps"])) and true
	# A path that is not a shader is not parsed at all, whatever it happens to contain.
	return _check("a file that is not a shader has no dials", PackedStringArray([
		",".join(EventForgeShaderUniforms.names_of(FIXTURE_DIR + "effect_dissolve_material.tres")),
		",".join(EventForgeShaderUniforms.names_of("")),
		",".join(EventForgeShaderUniforms.names_of("res://tests/fixtures/nothing_here.gdshader"))
	]), PackedStringArray(["", "", ""])) and ok


## The lead. A dial's name is read behind `effect.` so a reader can see it belongs to the material
## rather than to a variable, and the lead is MARKED so the canvas draws it quietly - the same device
## an autoload's name is read with, not a pill.
static func _test_the_reading() -> bool:
	var ok: bool = Pins.check("shader_dials_test", {
		"dissolve": "effect.dissolve",
		"edge_tint": "effect.edge_tint",
		"": "",
		"hp + 1": "hp + 1",
		"\"dissolve\"": "\"dissolve\""
	}, func(value: String) -> Variant:
		return EventForgeValueLens.read(EventForgeValueLens.LENS_EFFECT_DIAL, value))
	ok = _check("only the dial lens leads its reading", PackedStringArray([
		EventForgeValueLens.lead_of(EventForgeValueLens.LENS_EFFECT_DIAL),
		EventForgeValueLens.lead_of(EventForgeValueLens.LENS_DARKNESS),
		EventForgeValueLens.lead_of("")
	]), PackedStringArray(["effect.", "", ""])) and ok
	# The marking the renderer walks. It must arrive in START ORDER beside the value ranges, because
	# the draw stops at the first range that goes backwards - a lead inserted out of order would
	# silently drop the number after it.
	return _check("the lead is marked muted, in start order",
		ViewportRowBuilder.merged_muted_leads([[26, 3, "number"]],
			"Set effect.dissolve to 0.7", PackedStringArray(["effect."])),
		[[4, 7, "muted"], [26, 3, "number"]]) and ok


## The five rows, after the node-scoped transform that gives each an optional "On node". The template
## is what gets emitted, so it is pinned here rather than described: these are the lines a project
## ends up holding.
static func _test_the_rows() -> bool:
	var ok: bool = Pins.check("shader_dials_test", {
		"EffectSetDial": "{target.}material.set_shader_parameter(&\"{dial}\", {value})",
		"EffectFadeDial": "create_tween().tween_method(func(v): {target.}material.set_shader_parameter(&\"{dial}\", v), {from}, {to}, {seconds})",
		"EffectDial": "{target.}material.get_shader_parameter(&\"{dial}\")",
		"EffectDialIs": "{target.}material.get_shader_parameter(&\"{dial}\") {op} {value}",
		"EffectOwnMaterial": "{target.}material = {target.}material.duplicate()"
	}, func(ace_id: String) -> Variant:
		var descriptor: ACEDescriptor = ACERegistry.find_descriptor("Core", ace_id)
		return descriptor.codegen_template if descriptor != null else "")
	# The four dial rows are the project's to name, so neither the picker's browse nor the reverse
	# index may offer them; the copy row names nothing and stays an ordinary browsable verb.
	ok = Pins.check("shader_dials_test", {
		"EffectSetDial": true, "EffectFadeDial": true, "EffectDial": true, "EffectDialIs": true,
		"EffectOwnMaterial": false, "SetShaderParameter": false
	}, func(ace_id: String) -> Variant:
		var descriptor: ACEDescriptor = ACERegistry.find_descriptor("Core", ace_id)
		return descriptor != null and descriptor.is_project_scoped) and ok
	# The four shipped rows are frozen API and keep their own templates, beside the new ones.
	return Pins.check("shader_dials_test", {
		"SetShaderParameter": "{target.}material.set_shader_parameter(&{param}, {value})",
		"GetShaderParameter": "{target.}material.get_shader_parameter(&{param})",
		"SetShaderMaterial": "{target.}material = {material}",
		"ClearMaterial": "{target.}material = null"
	}, func(ace_id: String) -> Variant:
		var descriptor: ACEDescriptor = ACERegistry.find_descriptor("Core", ace_id)
		return descriptor.codegen_template if descriptor != null else "") and ok


## The shelves: one folder per node of the open scene that wears a shader material, named with the
## shader it runs, holding one entry per dial per verb with the node AND the dial already answered.
static func _test_the_picker() -> bool:
	EventSheetSceneEffects.clear_cache()
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.external_source_path = FIXTURE_DIR + BOSS
	var registry: EventSheetACERegistry = EventSheetACERegistry.new()
	registry.refresh_from_sources([], true)
	var offered: Array[ACEDefinition] = ACEPickerDialog.effect_dial_definitions(sheet, registry)
	var shelves: PackedStringArray = PackedStringArray()
	for definition: ACEDefinition in offered:
		var key: String = ACEPickerDialog.effect_group_key(definition, true)
		if not shelves.has(key):
			shelves.append(key)
	var ok: bool = _check("one shelf per wearing node, named with its shader", shelves,
		PackedStringArray([
			"Effects in this scene: Boss   effect_dissolve.gdshader",
			"Effects in this scene: Aura   effect_glow.gdshader"
		]))
	# Five dials across the two nodes, four verbs each - and every entry says which node and which
	# dial before the dialog opens, which is what makes the dialog open on the VALUE.
	var glow_entries: PackedStringArray = PackedStringArray()
	for definition: ACEDefinition in offered:
		if str(definition.metadata.get(ACEPickerDialog.SCENE_TARGET_META, "")) != "$Aura":
			continue
		glow_entries.append("%s | %s | %s" % [definition.display_name,
			str(definition.metadata.get(ACEPickerDialog.SCENE_TARGET_META, "")),
			str((definition.metadata.get(ACEPickerDialog.SCENE_PREFILL_META, {}) as Dictionary).get("dial", ""))])
	ok = _check("the aura's one dial is offered on every verb, already answered", glow_entries,
		PackedStringArray([
			"effect.glow  ·  Set Effect Dial | $Aura | glow",
			"effect.glow  ·  Fade Effect Dial | $Aura | glow",
			"effect.glow  ·  Effect Dial | $Aura | glow",
			"effect.glow  ·  Effect Dial Is | $Aura | glow"
		])) and ok
	# The description is the SHADER's - the author's own comment, then the declaration read back - so
	# a reader is told what this particular dial is rather than what dials are.
	ok = _check("an entry describes its own dial", _description_of(offered, "$Aura", "Set Effect Dial")
		.begins_with("How brightly the aura burns around the sprite. float 0..4 = 1.0"), true) and ok
	# The free-string rows keep their place until a sheet has dial shelves at all: a project with no
	# shaders in it sees the picker it has always seen.
	return _check("the frozen rows shelve beside the dials, and only then", PackedStringArray([
		ACEPickerDialog.effect_group_key(registry.find_definition("Core", "SetShaderParameter"), true),
		ACEPickerDialog.effect_group_key(registry.find_definition("Core", "SetShaderParameter"), false)
	]), PackedStringArray(["Effects in this scene: any material, name typed", ""])) and ok


## The EDITOR each dial asks for, derived from its own declaration rather than from a table: Godot's
## Inspector obeys these same hints, and a dial that edits as a slider there has no business editing
## as a text box here. Pinned by value because the derivation IS the feature - a hint read wrong is a
## field a reader cannot answer.
static func _test_the_editors() -> bool:
	var ok: bool = Pins.check("shader_dials_test", {
		"dissolve": "slider", "edge_tint": "color", "burn_noise": "texture", "steps": "stepper"
	}, func(dial: String) -> Variant:
		return EventForgeShaderUniforms.editor_kind(
			EventForgeShaderUniforms.find(DISSOLVE_SHADER, dial)))
	# The shapes with no file to read them from: a bare type decides on its own, a range of whole
	# numbers steps rather than slides, and a declaration nothing recognises falls to the ordinary
	# value field - which is what "never a dead end" means.
	var kinds: PackedStringArray = PackedStringArray()
	for uniform: Dictionary in EventForgeShaderUniforms.parse(SOURCE):
		kinds.append("%s=%s" % [str(uniform["name"]), EventForgeShaderUniforms.editor_kind(uniform)])
	# `weights` is an ARRAY of floats: not a slider, because the value is a list and none of the
	# derived editors is one. It takes the ordinary value field, where the list can be written.
	ok = _check("every declaration shape picks its own editor", kinds, PackedStringArray([
		"dissolve=slider", "tint=color", "noise=texture", "steps=stepper", "wind_strength=number",
		"weights=expression", "lit=toggle", "speed=number", "glow=number", "haze=number",
		"shimmer=number"])) and ok
	ok = _check("a dial nothing is known about takes the ordinary value field",
		EventForgeShaderUniforms.editor_kind({}), "expression") and ok
	# The value a field OPENS on when the row has none: the shader's own starting value, written as
	# the GDScript the row emits. `vec4` is not GDScript; `Color(…)` is the same value in the language
	# the line is in, and a single component fills the rest exactly as GLSL fills it.
	ok = Pins.check("shader_dials_test", {
		"uniform float a = 0.0;": "0.0",
		"uniform int b = 8;": "8",
		"uniform bool c = true;": "true",
		"uniform vec4 d : source_color = vec4(1.0, 0.6, 0.2, 1.0);": "Color(1.0, 0.6, 0.2, 1.0)",
		"uniform vec4 e : source_color = vec4(1.0);": "Color(1.0, 1.0, 1.0, 1.0)",
		"uniform vec2 f = vec2(3.0, 4.0);": "Vector2(3.0, 4.0)",
		"uniform vec3 g = vec3(1.0);": "Vector3(1.0, 1.0, 1.0)",
		"uniform float h;": ""
	}, func(declaration: String) -> Variant:
		var parsed: Array[Dictionary] = EventForgeShaderUniforms.parse(declaration)
		return "" if parsed.is_empty() else EventForgeShaderUniforms.gdscript_default(parsed[0])) and ok
	# A texture dial is a FILE in the field and a `preload` in the line, and the two are exact
	# inverses - a hand-written `load(…)` opens in the field as its own path rather than being
	# refused, because somebody really does write that.
	ok = Pins.check("shader_dials_test", {
		"res://noise.png": "preload(\"res://noise.png\")",
		"\"res://noise.png\"": "preload(\"res://noise.png\")",
		"": ""
	}, func(path: String) -> Variant: return ACEParamsDialog.texture_literal(path)) and ok
	ok = Pins.check("shader_dials_test", {
		"preload(\"res://noise.png\")": "res://noise.png",
		"load(\"res://noise.png\")": "res://noise.png",
		"hp / 100.0": ""
	}, func(literal: String) -> Variant: return ACEParamsDialog.texture_literal_path(literal)) and ok
	# And the chain the field walks to find any of that: the row's "On node", the material that node
	# wears, the shader behind it, and the dial by name. A blank node is the node the sheet is on.
	EventSheetSceneEffects.clear_cache()
	return Pins.check("shader_dials_test", {
		"|dissolve": "slider", "|burn_noise": "texture", "$Aura|glow": "slider",
		"$Plain|glow": "expression", "|nothing_like_it": "expression"
	}, func(asked: String) -> Variant:
		return EventForgeShaderUniforms.editor_kind(EventSheetSceneEffects.dial_declaration(
			FIXTURE_DIR + BOSS, asked.get_slice("|", 0), asked.get_slice("|", 1)))) and ok


## The finding: a row naming a dial the shader does not declare, which Godot accepts and acts on in no
## way at all. Amber, with the declared name it was nearly offered as one click.
static func _test_the_finding() -> bool:
	EventSheetSceneEffects.clear_cache()
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.external_source_path = FIXTURE_DIR + BOSS
	sheet.events.append(_event_setting("disolve"))
	sheet.events.append(_event_setting("dissolve"))
	var found: Array[Dictionary] = EventSheetEffectFindings.findings(sheet)
	var said: PackedStringArray = PackedStringArray()
	for finding: Dictionary in found:
		said.append("%s | %s | %s | %s" % [str(finding["subject"]), str(finding["message"]),
			str(finding["fix"]), str(finding["to"])])
	return _check("only the dial the shader does not declare is a finding", said, PackedStringArray([
		"disolve | effect_dissolve.gdshader declares no dial called disolve, so this row does nothing when the game runs. Did you mean dissolve? | pick_dial | dissolve"
	]))


# -- the walk -----------------------------------------------------------------------------------


## One event holding one Set row aimed at the node the sheet is on, turning `dial`.
static func _event_setting(dial: String) -> EventRow:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "EffectSetDial"
	action.params = {"target": "", EventForgeEffectDialACEs.DIAL_PARAM: dial, "value": "0.7"}
	var event_row: EventRow = EventRow.new()
	event_row.actions.append(action)
	return event_row


## One offered entry's description, found by the node it is aimed at and the verb it is.
static func _description_of(offered: Array[ACEDefinition], target: String, verb: String) -> String:
	for definition: ACEDefinition in offered:
		if str(definition.metadata.get(ACEPickerDialog.SCENE_TARGET_META, "")) == target \
				and definition.display_name.ends_with(verb):
			return definition.description
	return ""


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return Pins.check_value("shader_dials_test", label, actual, expected)
