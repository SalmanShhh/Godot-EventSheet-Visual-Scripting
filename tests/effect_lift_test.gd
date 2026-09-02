# The shader recognisers, measured against a hand-written effect script and the scene behind it.
#
# WHY A SCENE AND NOT ONLY A SCRIPT: `material.set_shader_parameter(&"dissolve", 0.7)` is a dial row
# and the identical line on a node wearing no material is not, and the only thing that can tell them
# apart is the `.tscn` and the shader at the end of it. So the corpus is a whole scene - a boss
# wearing a dissolve material saved as a file, an aura wearing one the scene keeps inside itself -
# with the script somebody already wrote for it, plus a second script whose every line is written the
# way an effect line is written and is about something else.
#
# Four things are pinned, and the first is absolute:
#   1. BYTE-EXACT round-trip. Opening one as a sheet and saving it untouched reproduces the file,
#      whichever of the five receiver spellings it used and whichever way it quoted the name.
#   2. The ROWS, by value: which spelling produced which row, with which values and which baked
#      template, because that template is what re-emits the author's own bytes.
#   3. The FALL-THROUGH. A dial the shader does not declare stays the shipped free-string row - it IS
#      that row - and so does every line on a node the scene says wears nothing.
#   4. The GUARD on its own: the four answers it can give without a file around it.
@tool
class_name EffectLiftTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const Repro := preload("res://tests/repro_bundle.gd")

const FIXTURE_DIR: String = "res://tests/fixtures/"
const BOSS: String = "effect_scene_boss.gd"
const BLOCK: String = "effect_stays_a_block.gd"

## The prefix every row this family lifts to shares - used to ask a whole file whether ANY of it
## became a dial row, which is the shape the fall-through test needs.
const DIAL_ID_PREFIX: String = "Effect"


static func run() -> bool:
	var ok: bool = true
	ok = _test_the_scene_is_read() and ok
	ok = _test_the_boss() and ok
	ok = _test_the_fall_through() and ok
	ok = _test_the_guard_alone() and ok
	ok = _test_the_receiver_can_be_cleared() and ok
	return ok


## What the scene says, before any line is read: which nodes wear a material, which file or inline
## copy it is, and which shader is at the end of the chain. The picker's shelves and the lift's guard
## are both this list, so it is pinned as values.
static func _test_the_scene_is_read() -> bool:
	EventSheetSceneEffects.clear_cache()
	EventForgeShaderUniforms.clear_cache()
	var read: Array[String] = []
	for node: Dictionary in EventSheetSceneEffects.for_script(FIXTURE_DIR + BOSS):
		read.append("%s %s shader=%s dials=%s" % [str(node["reference"]), str(node["class"]),
			str(node["shader_path"]).get_file(),
			",".join(EventForgeShaderUniforms.names_of(str(node["shader_path"])))])
	var ok: bool = _check("the boss scene's material-wearing nodes are read off it", read, [
		"self Sprite2D shader=effect_dissolve.gdshader dials=dissolve,edge_tint,burn_noise,steps",
		"$Aura Sprite2D shader=effect_glow.gdshader dials=glow"
	] as Array[String])
	ok = _check("a node the scene gives no material is not among them",
		EventSheetSceneEffects.shader_of(FIXTURE_DIR + BOSS, "$Plain"), "") and ok
	# The material a scene keeps INSIDE itself is followed exactly as far as a saved one: a reader who
	# made their material in the Inspector never saved a `.tres`, and would otherwise be told their
	# node wears nothing while the scene plainly shows it does.
	return _check("both shapes of material reach a shader", PackedStringArray([
		EventSheetSceneEffects.shader_of(FIXTURE_DIR + BOSS, "self").get_file(),
		EventSheetSceneEffects.shader_of(FIXTURE_DIR + BOSS, "%Aura").get_file(),
		EventSheetSceneEffects.shader_of(FIXTURE_DIR + BOSS, "get_node(\"Aura\")").get_file()
	]), PackedStringArray(["effect_dissolve.gdshader", "effect_glow.gdshader",
		"effect_glow.gdshader"])) and ok


## The boss: five receiver spellings, both ways of quoting the name, the tween, the copy and the
## preload. The template beside each row is what will be written back, which is why the `get_node()`
## line's stored spelling has no `&` in it and every other one does.
static func _test_the_boss() -> bool:
	var sheet: EventSheetResource = _open(BOSS)
	var ok: bool = _roundtrips(BOSS, sheet)
	return _check("every hand-written effect line in the boss reads as its row", _rows_of(sheet), [
		"SetShaderMaterial material=preload(\"res://tests/fixtures/effect_dissolve_material.tres\") | ",
		"EffectOwnMaterial target= | {target.}material = {target.}material.duplicate()",
		"EffectSetDial dial=dissolve target= value=0.7 | {target.}material.set_shader_parameter(&\"{dial}\", {value})",
		"EffectSetDial dial=edge_tint target= value=Color(\"ff9b3c\") | {target.}material.set_shader_parameter(&\"{dial}\", {value})",
		"EffectSetDial dial=glow target=$Aura value=2.0 | {target.}material.set_shader_parameter(&\"{dial}\", {value})",
		"EffectSetDial dial=glow target=%Aura value=1.5 | {target.}material.set_shader_parameter(&\"{dial}\", {value})",
		"EffectSetDial dial=glow target=get_node(\"Aura\") value=1.0 | {target.}material.set_shader_parameter(\"{dial}\", {value})",
		"EffectSetDial dial=glow target=aura value=0.5 | {target.}material.set_shader_parameter(&\"{dial}\", {value})",
		"SetShaderParameter param=\"disolve\" value=1.0 | ",
		"EffectFadeDial dial=dissolve from=0.0 seconds=0.8 target= to=1.0 | create_tween().tween_method(func(v): {target.}material.set_shader_parameter(&\"{dial}\", v), {from}, {to}, {seconds})",
		"RenderingSetGlobalShaderParam name=\"wind_strength\" value=2.0 | "
	] as Array[String]) and ok


## THE PROMISE that makes the rest of it safe. A name the shader does not declare is not a dial, and
## the line stays the free-string row it has always been - which is exactly right, because that row
## says only what the line says and claims nothing about a shader. The same for every line on a node
## the scene says wears no material at all.
static func _test_the_fall_through() -> bool:
	var sheet: EventSheetResource = _open(BLOCK)
	var ok: bool = _roundtrips(BLOCK, sheet)
	var claimed: PackedStringArray = PackedStringArray()
	for row: String in _rows_of(sheet):
		if row.begins_with(DIAL_ID_PREFIX):
			claimed.append(row)
	ok = _check("not one line on a node wearing nothing becomes a dial row",
		claimed, PackedStringArray()) and ok
	return _check("they read as whatever they already read as", _rows_of(sheet), [
		"SetShaderParameter param=\"dissolve\" value=0.7 | ",
		"SetShaderParameter param=\"glow\" target=$Door value=1.0 | ",
		"SetVar value=2 var_name=material_budget | "
	] as Array[String]) and ok


## The guard on its own, without a file around it - every answer it can give. A dial the shader does
## not declare matters as much as a node that wears nothing: both are silent failures at run time,
## and claiming either would put the plugin's name to a promise it cannot keep.
static func _test_the_guard_alone() -> bool:
	EventForgeEffectLift.lift_fixture_context()
	var verdicts: Dictionary = {}
	for line: String in ["$Aura.material.set_shader_parameter(&\"glow\", 1.0)",
			"$Aura.material.set_shader_parameter(&\"glo\", 1.0)",
			"$Nowhere.material.set_shader_parameter(&\"glow\", 1.0)",
			"$Aura.material = $Other.material.duplicate()",
			"create_tween().tween_method(func(v): $Aura.material.set_shader_parameter(&\"glow\", w), 0.0, 1.0, 0.8)"]:
		verdicts[line] = str(EventForgeEffectLift.match_line(line).get("ace_id", ""))
	return _check("the guard claims a declared dial on a wearing node and nothing else", verdicts, {
		"$Aura.material.set_shader_parameter(&\"glow\", 1.0)": "EffectSetDial",
		"$Aura.material.set_shader_parameter(&\"glo\", 1.0)": "",
		"$Nowhere.material.set_shader_parameter(&\"glow\", 1.0)": "",
		"$Aura.material = $Other.material.duplicate()": "",
		"create_tween().tween_method(func(v): $Aura.material.set_shader_parameter(&\"glow\", w), 0.0, 1.0, 0.8)": ""
	})


## THE RECEIVER, CLEARED. "On node" is an optional field on every one of these rows, and a lifted row
## carries its own baked spelling rather than the descriptor's - which is exactly where the two can
## come apart. Every line a row can emit with the field empty has to parse, and these are the lines
## it leaves.
static func _test_the_receiver_can_be_cleared() -> bool:
	var sheet: EventSheetResource = _open(BOSS)
	var emitted: PackedStringArray = PackedStringArray()
	for action: ACEAction in _actions_of(sheet):
		if not str(action.ace_id).begins_with(DIAL_ID_PREFIX) or not action.params.has("target"):
			continue
		var cleared: Dictionary = action.params.duplicate()
		cleared["target"] = ""
		emitted.append(_emit(str(action.codegen_template), cleared))
	return _check("clearing On node leaves the line an authored row emits", emitted, PackedStringArray([
		"material = material.duplicate()",
		"material.set_shader_parameter(&\"dissolve\", 0.7)",
		"material.set_shader_parameter(&\"edge_tint\", Color(\"ff9b3c\"))",
		"material.set_shader_parameter(&\"glow\", 2.0)",
		"material.set_shader_parameter(&\"glow\", 1.5)",
		"material.set_shader_parameter(\"glow\", 1.0)",
		"material.set_shader_parameter(&\"glow\", 0.5)",
		"create_tween().tween_method(func(v): material.set_shader_parameter(&\"dissolve\", v), 0.0, 1.0, 0.8)"
	]))


# -- the walk -----------------------------------------------------------------------------------


## One row's line, through the compiler's own emitter rather than a copy of the substitution.
static func _emit(template: String, params: Dictionary) -> String:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.codegen_template = template
	action.params = params.duplicate()
	return ActionCodegen.generate_action(action)


static func _source(file_name: String) -> String:
	return FileAccess.get_file_as_string(FIXTURE_DIR + file_name)


static func _open(file_name: String) -> EventSheetResource:
	var path: String = FIXTURE_DIR + file_name
	return GDScriptImporter.new().import_external_source(_source(file_name), true, path)


static func _roundtrips(file_name: String, sheet: EventSheetResource) -> bool:
	var saved: String = sheet.external_source_path
	sheet.external_source_path = "user://_effect_roundtrip.gd"
	var output: String = str(SheetCompiler.compile(sheet, sheet.external_source_path).get("output", ""))
	sheet.external_source_path = saved
	if output == _source(file_name):
		return _check("%s comes back byte for byte" % file_name, true, true)
	print(Repro.dump("effect_lift_test", file_name, _source(file_name), output, FIXTURE_DIR + file_name))
	return _check("%s comes back byte for byte" % file_name, false, true)


## Every action of every event, in sheet order.
static func _actions_of(sheet: EventSheetResource) -> Array[ACEAction]:
	var actions: Array[ACEAction] = []
	for entry: Variant in sheet.events:
		var event: EventRow = entry as EventRow
		if event == null:
			continue
		for candidate: Variant in event.actions:
			var action: ACEAction = candidate as ACEAction
			if action != null:
				actions.append(action)
	return actions


## Every action as `<ace_id> <name>=<value> … | <baked template>` - the row, what it shows, and the
## spelling it will write back. Values are sorted by name so the reading does not depend on the order
## a Dictionary happens to hold them in.
static func _rows_of(sheet: EventSheetResource) -> Array[String]:
	var rows: Array[String] = []
	for action: ACEAction in _actions_of(sheet):
		var values: PackedStringArray = PackedStringArray()
		var names: Array = action.params.keys()
		names.sort()
		for name: Variant in names:
			values.append("%s=%s" % [str(name), str(action.params[name])])
		rows.append("%s %s| %s" % [action.ace_id,
			" ".join(values) + (" " if not values.is_empty() else ""), action.codegen_template])
	return rows


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.pin_value("effect_lift_test", label, actual, expected)
