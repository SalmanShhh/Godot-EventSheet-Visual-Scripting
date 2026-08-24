# L7 - the lighting recognisers, measured against hand-written lit scripts and the scenes behind them.
#
# WHY A SCENE AND NOT ONLY A SCRIPT: `$Torch.energy = 1.2` is a light row and `$Door.visible = false`
# is not, and the only thing that can tell them apart is the `.tscn`. So the corpus is two whole
# scenes - a lit 2D room and a 3D cave - each with the script somebody already wrote for it, plus a
# third script sharing the room's scene whose every line is written the way a light row is written
# and is about something else.
#
# Three things are pinned, and the first is absolute:
#   1. BYTE-EXACT round-trip. Opening one as a sheet and saving it untouched reproduces the file,
#      whichever spelling it used - `$Torch`, the variable it was held in, or `get_node()`.
#   2. The ROWS, by value: which spelling produced which row, with which values and which baked
#      template, because that template is what re-emits the author's own bytes.
#   3. The REFUSALS. A line whose target the scene cannot show to be a light gets no light row, and
#      the file says so by still reading as whatever it read as before.
@tool
class_name LightingLiftTest
extends RefCounted

const FIXTURE_DIR: String = "res://tests/fixtures/"
const ROOM: String = "lighting_scene_room.gd"
const CAVE: String = "lighting_scene_cave.gd"
const CRYPT: String = "lighting_scene_crypt.gd"
const BLOCK: String = "lighting_stays_a_block.gd"

## The prefix every row this family lifts to shares. Used to ask a whole file whether ANY of it
## became a light row, which is the shape the refusal test needs.
const LIGHT_ID_PREFIX: String = "Light"


static func run() -> bool:
	var ok: bool = true
	ok = _test_the_scene_is_read() and ok
	ok = _test_the_room() and ok
	ok = _test_the_cave() and ok
	ok = _test_the_crypt() and ok
	ok = _test_the_refusals() and ok
	ok = _test_the_guard_alone() and ok
	ok = _test_the_receiver_can_be_cleared() and ok
	return ok


## What the scene says, before any line is read: every light of it, what kind, whether it casts
## shadows, and the spelling a row addresses it by. The picker's shelf and the lift's guard are both
## this list, so it is pinned as values.
static func _test_the_scene_is_read() -> bool:
	EventSheetSceneLights.clear_cache()
	var read: Array[String] = []
	for light: Dictionary in EventSheetSceneLights.for_script(FIXTURE_DIR + ROOM):
		read.append("%s %s %s shadows=%s" % [str(light["reference"]), str(light["class"]),
			str(light["kind"]), str(light["shadows"])])
	var ok: bool = _check("the room's lights are read off its scene", read, [
		"$Torch PointLight2D point shadows=true",
		"$Moonlight DirectionalLight2D directional shadows=false",
		"$Props/Lantern PointLight2D point shadows=false"
	] as Array[String])
	ok = _check("a node the scene does not carry has no class",
		EventSheetSceneLights.class_of_reference(FIXTURE_DIR + ROOM, "$Nowhere"), "") and ok
	ok = _check("and one that is not a light is named for what it is",
		EventSheetSceneLights.class_of_reference(FIXTURE_DIR + ROOM, "$Door"), "StaticBody2D") and ok
	return _check("every spelling of one node reaches it", PackedStringArray([
		EventSheetSceneLights.class_of_reference(FIXTURE_DIR + ROOM, "$Props/Lantern"),
		EventSheetSceneLights.class_of_reference(FIXTURE_DIR + ROOM, "%Lantern"),
		EventSheetSceneLights.class_of_reference(FIXTURE_DIR + ROOM, "get_node(\"Props/Lantern\")"),
		EventSheetSceneLights.class_of_reference(FIXTURE_DIR + ROOM, "Lantern")
	]), PackedStringArray(["PointLight2D", "PointLight2D", "PointLight2D", "PointLight2D"])) and ok


## The 2D room: four spellings, five words, and the tween.
static func _test_the_room() -> bool:
	var sheet: EventSheetResource = _open(ROOM)
	var ok: bool = _roundtrips(ROOM, sheet)
	return _check("every hand-written light line in the room reads as its row", _rows_of(sheet), [
		"LightSetBrightness target=$Torch value=1.2 | {target.}energy = {value}",
		"LightSetColour target=torch value=Color(\"ffd9a1\") | {target.}color = {value}",
		"LightShadowsOn target=$Torch | {target.}shadow_enabled = true",
		"LightSetReach target=get_node(\"Props/Lantern\") value=1.5 | {target.}texture_scale = {value}",
		"LightLitOff target=$Moonlight | {target.}enabled = false",
		"LightFadeBrightness seconds=0.5 target=lantern value=1.0 | create_tween().tween_property({target}, \"energy\", {value}, {seconds})"
	] as Array[String]) and ok


## The 3D cave: the same five words, every one of them a different property.
static func _test_the_cave() -> bool:
	var sheet: EventSheetResource = _open(CAVE)
	var ok: bool = _roundtrips(CAVE, sheet)
	return _check("and the cave's lines read as the same words with the 3D properties", _rows_of(sheet), [
		"LightSetBrightness3D target=$Flashlight value=2.0 | {target.}light_energy = {value}",
		"LightSetReachSpot target=flashlight value=12.0 | {target.}spot_range = {value}",
		"LightSetConeAngle target=flashlight value=30.0 | {target.}spot_angle = {value}",
		"LightLit3DOff target=$Flashlight | {target.}visible = false",
		"LightSetReachOmni target=$Bulb value=8.0 | {target.}omni_range = {value}",
		"LightSetColour3D target=$Sun value=Color(0.9, 0.8, 0.7) | {target.}light_color = {value}",
		"LightFadeBrightness3D seconds=1.5 target=$Bulb value=0.0 | create_tween().tween_property({target}, \"light_energy\", {value}, {seconds})"
	] as Array[String]) and ok


## L4 / L6 - the two lighting nodes that are not lights. The crypt darkens a layer and writes the
## world's atmosphere by hand, in the spellings people really use: the `$` path and the variable the
## CanvasModulate was held in, and every World line reaching through `.environment`. The same promise
## holds: the colour is the value the row carries, and the file comes back byte for byte.
static func _test_the_crypt() -> bool:
	var sheet: EventSheetResource = _open(CRYPT)
	var ok: bool = _roundtrips(CRYPT, sheet)
	return _check("the crypt's darkness and atmosphere lines read as their rows", _rows_of(sheet), [
		"DarknessSet target=$Level value=Color(0.3, 0.3, 0.36) | {target.}color = {value}",
		"DarknessSet target=level value=Color(\"111522\") | {target.}color = {value}",
		"DarknessFade seconds=10.0 target=$Level value=Color(0.1, 0.1, 0.15) | create_tween().tween_property({target}, \"color\", {value}, {seconds})",
		"WorldFogOn target=$World | {target.}environment.fog_enabled = true",
		"WorldSetFogThickness target=$World value=0.03 | {target.}environment.fog_density = {value}",
		"WorldSetAmbientLight target=$World value=0.15 | {target.}environment.ambient_light_energy = {value}",
		"WorldGlowOn target=$World | {target.}environment.glow_enabled = true",
		"WorldFadeGlow seconds=4.0 target=$World value=1.2 | create_tween().tween_property({target}.environment, \"glow_intensity\", {value}, {seconds})"
	] as Array[String]) and ok


## The promise that makes the rest of it safe: a door that is hidden, a variable that happens to be
## called energy, and a toggle no row can say all stay exactly what they were.
static func _test_the_refusals() -> bool:
	var sheet: EventSheetResource = _open(BLOCK)
	var ok: bool = _roundtrips(BLOCK, sheet)
	var claimed: PackedStringArray = PackedStringArray()
	for row: String in _rows_of(sheet):
		if row.begins_with(LIGHT_ID_PREFIX):
			claimed.append(row)
	ok = _check("not one line that is about something else becomes a light row",
		claimed, PackedStringArray()) and ok
	return _check("they read as whatever they already read as", _rows_of(sheet), [
		"SetProperty property=visible target=$Door value=false | ",
		"SetVar value=2.0 var_name=energy | ",
		"ToggleVar var_name=$Torch.shadow_enabled | "
	] as Array[String]) and ok


## The guard on its own, without a file around it - the four answers it can give. A node of the
## wrong dimension matters as much as one that is not a light at all: `visible` is a property every
## 2D light also has, and only the 3D lights switch off with it.
static func _test_the_guard_alone() -> bool:
	EventForgeLightingLift.lift_fixture_context()
	var verdicts: Dictionary = {}
	for line: String in ["$Torch.enabled = false", "$Bulb.visible = false", "$Torch.visible = false",
			"$Nowhere.energy = 1.0", "hp.energy = 1.0"]:
		verdicts[line] = str(EventForgeLightingLift.match_line(line).get("ace_id", ""))
	return _check("the guard claims a light of the right dimension and nothing else", verdicts, {
		"$Torch.enabled = false": "LightLitOff",
		"$Bulb.visible = false": "LightLit3DOff",
		"$Torch.visible = false": "",
		"$Nowhere.energy = 1.0": "",
		"hp.energy = 1.0": ""
	})


## THE RECEIVER, CLEARED. "On node" is an optional field - its own description says to leave it blank
## for this node - so every line a row can emit with it empty has to parse. A lifted row carries its
## own baked spelling rather than the descriptor's, which is exactly where the two can come apart:
## `{target}.energy = {value}` reads the same on the row and emits `.energy = 1.2` the moment the
## field is cleared. The idiom with the dot INSIDE the braces is what the picker's own row uses, and
## these are the lines it leaves.
static func _test_the_receiver_can_be_cleared() -> bool:
	var sheet: EventSheetResource = _open(ROOM)
	var emitted: Array[String] = []
	for entry: Variant in sheet.events:
		var event: EventRow = entry as EventRow
		if event == null:
			continue
		for candidate: Variant in event.actions:
			var action: ACEAction = candidate as ACEAction
			if action == null or not str(action.codegen_template).begins_with(
					EventForgeLiftTable.optional_prefix_slot("target")):
				continue
			var cleared: Dictionary = action.params.duplicate()
			cleared["target"] = ""
			emitted.append(_emit(str(action.codegen_template), cleared))
	return _check("clearing On node leaves the line an authored row emits", emitted, [
		"energy = 1.2",
		"color = Color(\"ffd9a1\")",
		"shadow_enabled = true",
		"texture_scale = 1.5",
		"enabled = false"
	] as Array[String])


# ── the walk ────────────────────────────────────────────────────────────────────


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
	sheet.external_source_path = "user://_lighting_roundtrip.gd"
	var output: String = str(SheetCompiler.compile(sheet, sheet.external_source_path).get("output", ""))
	sheet.external_source_path = saved
	return _check("%s comes back byte for byte" % file_name, output == _source(file_name), true)


## Every action of every event, as `<ace_id> <name>=<value> … | <baked template>` - the row, what it
## shows, and the spelling it will write back. Values are sorted by name so the reading does not
## depend on the order a Dictionary happens to hold them in.
static func _rows_of(sheet: EventSheetResource) -> Array[String]:
	var rows: Array[String] = []
	for entry: Variant in sheet.events:
		var event: EventRow = entry as EventRow
		if event == null:
			continue
		for candidate: Variant in event.actions:
			var action: ACEAction = candidate as ACEAction
			if action == null:
				continue
			var values: PackedStringArray = PackedStringArray()
			var names: Array = action.params.keys()
			names.sort()
			for name: Variant in names:
				values.append("%s=%s" % [str(name), str(action.params[name])])
			rows.append("%s %s| %s" % [action.ace_id,
				" ".join(values) + (" " if not values.is_empty() else ""), action.codegen_template])
	return rows


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] lighting_lift_test: %s" % label)
		return true
	print("[FAIL] lighting_lift_test: %s" % label)
	print("  expected: %s" % expected)
	print("  actual:   %s" % actual)
	return false
