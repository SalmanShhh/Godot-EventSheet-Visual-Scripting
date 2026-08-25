# The facts a lit scene already holds, and the two lighting objects that are not lights.
#
# Lighting is the part of a game that fails without saying anything: the light is in the scene, the
# row runs, and the screen does not change. Every claim here is therefore a fact READ off a `.tscn`
# before the game runs - which lights there are, whether anything can block the shadows they cast,
# and whether the environment being written at run time is a file three other scenes also load.
#
# What is pinned:
#   1. THE BANDS, by value. The words a reader sees on the head, the echo naming the lines of the
#      scene file they came from, and the node each band's click selects. A band whose fact is a
#      PROBLEM says the warning instead of the count, and says it in the words the Doctor will use.
#   2. NOTHING IS STORED. The bands are derived on every ask, so a sheet whose scene has no lighting
#      grows no bands, and the `.gd` behind a lit one still round-trips (that half is in
#      lighting_lift_test - this one only proves the head asks the scene rather than the sheet).
#   3. THE READING. Godot stores 2D darkness as a colour; the row stores the colour too and READS as
#      the percentage it means, which is the one place in this vocabulary where what a row shows is
#      not what it holds.
@tool
class_name SceneLightingFactsTest
extends RefCounted

const ROOM: String = "res://tests/fixtures/lighting_scene_room.gd"
const CRYPT: String = "res://tests/fixtures/lighting_scene_crypt.gd"
const CRYPT_SCENE: String = "res://tests/fixtures/lighting_scene_crypt.tscn"
const ENVIRONMENT: String = "res://tests/fixtures/lighting_environment.tres"

## A hall lit by two shadow-casting lights, one of which an occluder can block and one of which
## nothing can - the scene that tells the band's WARNING apart from the band's CLICK.
const HALL: String = "res://tests/fixtures/lighting_hall_lamp.gd"
const HALL_SCENE: String = "res://tests/fixtures/lighting_scene_hall.tscn"


static func run() -> bool:
	EventSheetSceneLights.clear_cache()
	EventSheetSceneLightingFacts.clear_cache()
	var ok: bool = true
	ok = _test_the_lit_by_bands() and ok
	ok = _test_the_shadow_band() and ok
	ok = _test_the_environment_band() and ok
	ok = _test_the_head_wears_them() and ok
	ok = _test_the_public_seam() and ok
	ok = _test_the_darkness_lens() and ok
	ok = _test_the_rows_read_as_percentages() and ok
	ok = _test_the_picker_shelves() and ok
	ok = _test_the_rows_open_on_the_engines_numbers() and ok
	ok = _test_the_masks_default_the_way_the_engine_does() and ok
	return ok


## One band per light, in scene order: what it is called, the plain word for what kind it is, and
## whether it casts shadows. The echo names the scene file's own lines, and the reference is the
## node the band's control selects.
static func _test_the_lit_by_bands() -> bool:
	var readings: Array[String] = []
	for band: Dictionary in EventSheetSceneLightingFacts.lit_by(ROOM):
		readings.append(str(band["value"]))
	var ok: bool = _check("every light of the room gets its own band", readings, [
		"Torch · point · casts shadows",
		"Moonlight · directional",
		"Lantern · point"
	] as Array[String])
	var torch: Dictionary = EventSheetSceneLightingFacts.lit_by(ROOM)[0]
	ok = _check("and echoes the lines of the scene file it was read from", str(torch["echo"]),
		"lighting_scene_room.tscn: PointLight2D \"Torch\", shadow_enabled = true") and ok
	ok = _check("and points at the node its control selects", str(torch["reference"]),
		"res://tests/fixtures/lighting_scene_room.tscn|Torch") and ok
	ok = _check("a script no scene runs is lit by nothing",
		EventSheetSceneLightingFacts.lit_by("res://tests/fixtures/lighting_environment.tres").size(), 0) and ok
	# A band is a fact a reader can go and look at, so it needs ONE scene to look at. A behaviour worn
	# by five levels would otherwise wear five levels' lights, none of them about the sheet in hand.
	ok = _check("the bands are about the one scene this script is attached to",
		EventSheetSceneLightingFacts.attached_scene(ROOM),
		"res://tests/fixtures/lighting_scene_room.tscn") and ok
	var shared: String = "res://tests/fixtures/lighting_stays_a_block.gd"
	ok = _check("a script two scenes run has no single scene to be about",
		EventSheetSceneLightingFacts.attached_scene(shared), "") and ok
	return _check("so it wears no lighting bands at all", PackedInt32Array([
		EventSheetSceneLightingFacts.lit_by(shared).size(),
		EventSheetSceneLightingFacts.shadow_bands(shared).size(),
		EventSheetSceneLightingFacts.environment_bands(shared).size()
	]), PackedInt32Array([0, 0, 0])) and ok


## The band that decides whether the shadows a reader turned on will ever appear. Godot draws one
## only where an occluder's own mask shares a layer with the light's shadow mask, so the healthy
## reading is a count and the unhealthy one is the sentence the Doctor raises about the same scene.
static func _test_the_shadow_band() -> bool:
	var healthy: Array[Dictionary] = EventSheetSceneLightingFacts.shadow_bands(ROOM)
	var ok: bool = _check("the room's occluders can block the light it casts",
		str(healthy[0]["value"]), "2 occluders block the light on this layer")
	ok = _check("so the band is a fact and not a warning", bool(healthy[0]["warning"]), false) and ok
	ok = _check("and it says which properties decided that", str(healthy[0]["echo"]),
		"lighting_scene_room.tscn: LightOccluder2D x 2, 2 whose occluder_light_mask matches shadow_item_cull_mask") and ok
	var stranded: Array[Dictionary] = EventSheetSceneLightingFacts.shadow_bands(CRYPT)
	ok = _check("the crypt's occluder is on another layer, so the band says so",
		str(stranded[0]["value"]),
		"Candle casts shadows and no occluder's mask matches - shadows never appear") and ok
	ok = _check("in the note colour, because it is a problem", bool(stranded[0]["warning"]), true) and ok
	# The echo tells the two shapes of that problem apart: an occluder on the wrong layer is a mask
	# to fix, and no occluder at all is a node to add.
	ok = _check("and its echo counts the occluders that exist as well as the ones that match",
		str(stranded[0]["echo"]),
		"lighting_scene_crypt.tscn: LightOccluder2D x 1, 0 whose occluder_light_mask matches shadow_item_cull_mask") and ok
	# THE CLICK, in a scene where the two halves of the band could disagree. The hall's chandelier is
	# blocked and its candle is not, so the warning names the candle - and the control beside it has to
	# select the candle too, or the click sends a reader to the light that is fine.
	var mixed: Array[Dictionary] = EventSheetSceneLightingFacts.shadow_bands(HALL)
	ok = _check("with several shadow-casters, the warning names the stranded one",
		str(mixed[0]["value"]),
		"Candle casts shadows and no occluder's mask matches - shadows never appear") and ok
	ok = _check("and the band's control selects the light it just named",
		str(mixed[0]["reference"]), "%s|Candle" % HALL_SCENE) and ok
	ok = _check("a band with nothing wrong points at a light too", str(healthy[0]["reference"]),
		"res://tests/fixtures/lighting_scene_room.tscn|Torch") and ok
	return _check("and a scene whose lights cast nothing has no shadow band at all",
		EventSheetSceneLightingFacts.shadow_bands("res://tests/fixtures/lighting_scene_cave.gd").size(), 0) and ok


## The band that answers the biggest surprise in Godot lighting: an environment `.tres` is a FILE,
## so a row that writes fog at run time writes it for every other scene that loads the same file.
static func _test_the_environment_band() -> bool:
	var bands: Array[Dictionary] = EventSheetSceneLightingFacts.environment_bands(CRYPT)
	var ok: bool = _check("the crypt's environment names its file and who else holds it",
		str(bands[0]["value"]), "lighting_environment.tres · shared with 1 other scene")
	ok = _check("and the echo names the scene that would follow the change", str(bands[0]["echo"]),
		"lighting_scene_crypt.tscn: WorldEnvironment \"World\", environment = \"%s\" · also in lighting_scene_swamp.tscn"
			% ENVIRONMENT) and ok
	ok = _check("and points at the holder", str(bands[0]["reference"]),
		"%s|World" % CRYPT_SCENE) and ok
	ok = _check("the other scenes are named, own scene excluded", EventSheetSceneLightingFacts.scenes_sharing(
		ENVIRONMENT, CRYPT_SCENE), PackedStringArray(["res://tests/fixtures/lighting_scene_swamp.tscn"])) and ok
	ok = _check("an environment kept inside its scene is shared with nobody",
		EventSheetSceneLightingFacts.environment_reading("", PackedStringArray()),
		"kept inside this scene - nothing else can see the change") and ok
	ok = _check("and a file only one scene loads says that too",
		EventSheetSceneLightingFacts.environment_reading(ENVIRONMENT, PackedStringArray()),
		"lighting_environment.tres · used by this scene only") and ok
	return _check("a scene with no WorldEnvironment has no environment band",
		EventSheetSceneLightingFacts.environment_bands(ROOM).size(), 0) and ok


## The head itself: the three bands sit after the file's own, in reading order, each with the control
## that opens the editor owning the fact - and a sheet whose scene has no lighting grows none.
static func _test_the_head_wears_them() -> bool:
	var bands: Array[Dictionary] = _head_bands(CRYPT, "extends Node2D")
	var kinds: PackedStringArray = PackedStringArray()
	for band: Dictionary in bands:
		kinds.append(str(band["kind"]))
	var ok: bool = _check("the scene's lighting bands come after the file's own lines", kinds,
		PackedStringArray([EventSheetHeadBands.BAND_NAME, EventSheetHeadBands.BAND_EXTENDS,
			EventSheetHeadBands.BAND_LIT_BY, EventSheetHeadBands.BAND_SHADOWS,
			EventSheetHeadBands.BAND_ENVIRONMENT]))
	ok = _check("the lit-by band leads with the word it stands for",
		str(EventSheetHeadBands.LEADERS[EventSheetHeadBands.BAND_LIT_BY]), "lit by") and ok
	ok = _check("and its control selects the light in the scene",
		str(_band(bands, EventSheetHeadBands.BAND_LIT_BY)["control"]),
		EventSheetL10n.translate("select the light")) and ok
	ok = _check("the environment band's control selects the node holding it",
		str(_band(bands, EventSheetHeadBands.BAND_ENVIRONMENT)["control"]),
		EventSheetL10n.translate("select the node")) and ok
	# The gesture behind those controls is dispatched by band KIND, so a band that comes from the
	# scene and names no node would be a control with nothing to click through to.
	var referenceless: PackedStringArray = PackedStringArray()
	for band: Dictionary in bands:
		if EventSheetHeadBands.SCENE_BANDS.has(str(band["kind"])) \
				and str(band["reference"]).get_slice("|", 1).is_empty():
			referenceless.append(str(band["kind"]))
	ok = _check("every band read from the scene names the node its click selects",
		referenceless, PackedStringArray()) and ok
	var quiet: PackedStringArray = PackedStringArray()
	for band: Dictionary in _head_bands("res://tests/fixtures/multiplayer_player_messages.gd", "extends Node"):
		quiet.append(str(band["kind"]))
	return _check("and nothing about lighting appears on a head whose scene has none", quiet,
		PackedStringArray([EventSheetHeadBands.BAND_NAME, EventSheetHeadBands.BAND_EXTENDS])) and ok


## The seam a pack asks the same question through. Read-only and derived on every ask, exactly like
## the replication seams beside it - nothing about the scene is stored in the sheet.
static func _test_the_public_seam() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.external_source_path = ROOM
	var lights: Array[Dictionary] = EventSheets.scene_lights(sheet)
	var read: Array[String] = []
	for light: Dictionary in lights:
		read.append("%s %s %s shadows=%s masks=%s shadow_masks=%s" % [str(light["reference"]),
			str(light["class"]), str(light["kind"]), str(light["shadows"]), str(light["masks"]),
			str(light["shadow_masks"])])
	var ok: bool = _check("scene_lights answers with every light of the sheet's scene", read, [
		"$Torch PointLight2D point shadows=true masks=3 shadow_masks=",
		"$Moonlight DirectionalLight2D directional shadows=false masks= shadow_masks=",
		"$Props/Lantern PointLight2D point shadows=false masks= shadow_masks="
	] as Array[String])
	ok = _check("typed, so a caller of a public method casts nothing",
		lights.get_typed_builtin(), TYPE_DICTIONARY) and ok
	# The LIST is the caller's own. The reader behind it answers from a session cache, so handing the
	# cached array out would let a pack that sorts or filters its "read-only" answer in place
	# rearrange the picker's shelf, the head's bands and the lift's guard for the rest of the session.
	lights.append({"name": "NotALight"})
	ok = _check("and the list a caller is handed is theirs to do what they like with",
		EventSheets.scene_lights(sheet).size(), 3) and ok
	return _check("and no sheet at all has no lights", EventSheets.scene_lights(null).size(), 0) and ok


## The reading lens on its own: a colour said as how dark it makes the layer. The percentage is the
## engine's own luminance subtracted from full light, and the tint is the colour the file keeps -
## which is why a value the lens cannot read comes back exactly as it went in.
static func _test_the_darkness_lens() -> bool:
	var readings: Dictionary = {}
	for value: String in ["Color(0.3, 0.3, 0.36)", "Color(\"111522\")", "Color.BLACK", "Color.WHITE",
			"night_tint", "Color.from_hsv(0.6, 0.5, 0.3)"]:
		readings[value] = EventForgeValueLens.read(EventForgeValueLens.LENS_DARKNESS, value)
	var ok: bool = _check("a stored darkness colour reads as the darkness it makes", readings, {
		"Color(0.3, 0.3, 0.36)": "70%, tinted #4d4d5c",
		"Color(\"111522\")": "92%, tinted #111522",
		"Color.BLACK": "100%, tinted #000000",
		"Color.WHITE": "0%, tinted #ffffff",
		"night_tint": "night_tint",
		"Color.from_hsv(0.6, 0.5, 0.3)": "Color.from_hsv(0.6, 0.5, 0.3)"
	})
	ok = _check("the fade row asks for the percentage alone",
		EventForgeValueLens.read(EventForgeValueLens.LENS_DARKNESS_PERCENT, "Color(0.1, 0.1, 0.15)"),
		"90%") and ok
	# The two worked examples the lens documents itself with, and the value a dropped row starts on.
	# A comment quoting a percentage the lens does not produce is how a reader concludes the lens is
	# broken, so both numbers are pinned here rather than trusted to stay written down correctly.
	ok = _check("the worked example in the lens's own header reads as the lens reads it",
		EventForgeValueLens.darkness("Color(\"26304d\")"), "81%, tinted #26304d") and ok
	ok = _check("and a dropped darkness row starts at the percentage its default says",
		EventForgeValueLens.darkness_percent(EventForgeSceneLightingACEs.DEFAULT_DARKNESS), "82%") and ok
	return _check("and a param that named no lens is read exactly as it always was",
		EventForgeValueLens.read("", "Color(0.3, 0.3, 0.36)"), "Color(0.3, 0.3, 0.36)") and ok


## WHAT A DROPPED ROW STARTS ON. Every one of these values is Godot's own default for the property
## the row writes, and every one of them is stored as a float32 that ClassDB hands back widened to a
## double - so the row that says "0.01 is a haze" has to open on `0.01` rather than on the
## `0.00999999977648` that widening prints. Pinned as the literal text a reader sees in the field.
static func _test_the_rows_open_on_the_engines_numbers() -> bool:
	var registry: EventSheetACERegistry = EventSheetACERegistry.new()
	registry.refresh_from_sources([], true)
	var starts: Dictionary = {}
	for ace_id: String in ["WorldSetFogThickness", "WorldSetAmbientLight", "WorldFadeGlow",
			"LightSetBrightness", "LightSetReachOmni", "LightSetConeAngle"]:
		starts[ace_id] = _first_value_default(registry, ace_id)
	return _check("every lighting row opens on the engine's own number, said the way a person types it",
		starts, {
			"WorldSetFogThickness": "0.01",
			"WorldSetAmbientLight": "1.0",
			"WorldFadeGlow": "0.3",
			"LightSetBrightness": "1.0",
			"LightSetReachOmni": "5.0",
			"LightSetConeAngle": "45.0"
		})


## THE TWO MASK DEFAULTS, which are not the same number. Godot starts `light_cull_mask` (3D) with
## every layer set and the three 2D masks on layer 1 alone, so a scene file that never wrote one
## means "all of them" in 3D and "layer 1" in 2D. Read off ClassDB here rather than restated, because
## the constants exist to save the readers a lookup, not to become a second opinion.
static func _test_the_masks_default_the_way_the_engine_does() -> bool:
	var ok: bool = _check("an absent 2D mask means the layer the engine puts it on",
		EventSheetSceneLights.mask_bits(""), int(ClassDB.class_get_property_default_value(
			"PointLight2D", EventSheetSceneLights.MASK_PROPERTY_2D)))
	ok = _check("an absent 3D mask means every layer, not the first one",
		EventSheetSceneLights.mask_bits("", EventSheetSceneLights.DEFAULT_MASK_3D),
		int(ClassDB.class_get_property_default_value(
			"OmniLight3D", EventSheetSceneLights.MASK_PROPERTY_3D))) and ok
	ok = _check("and the two are really different numbers",
		EventSheetSceneLights.DEFAULT_MASK == EventSheetSceneLights.DEFAULT_MASK_3D, false) and ok
	return _check("a mask the file DID write is read as itself",
		EventSheetSceneLights.mask_bits("3", EventSheetSceneLights.DEFAULT_MASK_3D), 3) and ok


## The default a row's first value field opens on - the number a reader meets the moment they drop it.
static func _first_value_default(registry: EventSheetACERegistry, ace_id: String) -> String:
	for definition: ACEDefinition in registry.get_all_definitions():
		if definition.id != ace_id:
			continue
		for parameter: Variant in definition.parameters:
			if parameter is Dictionary and str((parameter as Dictionary).get("id", "")) == "value":
				return str((parameter as Dictionary).get("default_value", ""))
	return ""


## The lens where a reader meets it: on the canvas, in the row the crypt's hand-written lines opened
## as. The object column is the node, the sentence is the plain word, and the percentage is the
## reading of a value the file still holds as a colour.
static func _test_the_rows_read_as_percentages() -> bool:
	return _check("the crypt's lit lines read as sentences about its own nodes",
		_readings(GDScriptImporter.new().import_external(CRYPT)), [
			"Level ▸ Set darkness to 70%, tinted #4d4d5c",
			"level ▸ Set darkness to 92%, tinted #111522",
			"Level ▸ Fade darkness to 90% over 10 s",
			"World ▸ Turn fog on",
			"World ▸ Set fog thickness to 0.03",
			"World ▸ Set ambient light to 0.15",
			"World ▸ Turn glow on",
			"World ▸ Fade the glow to 1.2 over 4 s"
		] as Array[String])


## The picker's three shelves: the scene's own lights, its darkness and its atmosphere, each offering
## exactly the verbs that node's class answers to.
static func _test_the_picker_shelves() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.external_source_path = CRYPT
	var registry: EventSheetACERegistry = EventSheetACERegistry.new()
	registry.refresh_from_sources([], true)
	var shelves: Dictionary = {}
	for offered: ACEDefinition in ACEPickerDialog.scene_lighting_definitions(sheet, registry):
		var key: String = ACEPickerDialog.scene_lighting_group_key(offered)
		var listed: PackedStringArray = shelves.get(key, PackedStringArray())
		listed.append(offered.id)
		shelves[key] = listed
	var ok: bool = _check("the crypt's lighting nodes each get a shelf of their own", shelves.keys(), [
		"Lights in this scene: Candle   PointLight2D · casts shadows",
		"Darkness in this scene: Level   CanvasModulate",
		"Atmosphere in this scene: World   WorldEnvironment"
	])
	ok = _check("the darkness shelf offers the two rows a CanvasModulate answers to",
		shelves.get("Darkness in this scene: Level   CanvasModulate", PackedStringArray()),
		PackedStringArray(["DarknessSet", "DarknessFade"])) and ok
	return _check("and the atmosphere shelf the world's own words",
		shelves.get("Atmosphere in this scene: World   WorldEnvironment", PackedStringArray()),
		PackedStringArray(["WorldFogOn", "WorldFogOff", "WorldGlowOn", "WorldGlowOff",
			"WorldSetFogThickness", "WorldSetAmbientLight", "WorldFadeGlow",
			"WorldOwnEnvironment"])) and ok


# ── the walk ────────────────────────────────────────────────────────────────────


## The head's bands for one script, as the canvas builds them: the file's own facts merged with the
## scene's, which is the one place the two halves of a head meet.
static func _head_bands(script_path: String, scaffold: String) -> Array[Dictionary]:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.external_source_path = script_path
	var facts: Dictionary = EventSheetHeadBands.facts(sheet, scaffold)
	facts.merge(EventSheetHeadBands.scene_facts(sheet), true)
	return EventSheetHeadBands.bands(facts)


static func _band(bands: Array[Dictionary], kind: String) -> Dictionary:
	for band: Dictionary in bands:
		if str(band["kind"]) == kind:
			return band
	return {}


## Every row of a sheet that NAMES AN OBJECT, as the canvas reads it: `<object> ▸ <sentence>`. A cell
## is several spans, so they are grouped back into the line a reader sees by the lane and line they
## share. The head's own bands are read the same way and left out here - they are pinned as facts
## above, where a change to one of them says which fact changed rather than which row moved.
static func _readings(sheet: EventSheetResource) -> Array[String]:
	sheet.read_only = true
	var style: EventSheetEditorStyle = EventSheetEditorStyle.new()
	style.ensure_defaults()
	sheet.editor_style = style
	var viewport: EventSheetViewport = EventSheetViewport.new()
	viewport.set_ace_registry(EventSheetACERegistry.new())
	viewport.set_sheet(sheet)
	viewport.set_reading_mode(true)
	var readings: Array[String] = []
	for row_data: EventRowData in _rows(viewport._root_rows, viewport):
		var cells: Dictionary = {}
		var order: Array = []
		for span: SemanticSpan in row_data.spans:
			var key: String = "%s|%d" % [str(span.metadata.get("lane", "")),
				int(span.metadata.get("line_index", 0))]
			if not cells.has(key):
				cells[key] = {"object": str(span.metadata.get("object_label", "")), "text": ""}
				order.append(key)
			var cell: Dictionary = cells[key]
			cell["text"] = str(cell["text"]) + span.text
		for key: Variant in order:
			var cell: Dictionary = cells[key]
			var body: String = str(cell["text"]).strip_edges()
			if body.is_empty() or str(cell["object"]).is_empty():
				continue
			readings.append("%s ▸ %s" % [str(cell["object"]), body])
	viewport.free()
	return readings


## Every row in the tree, parents before children, with its spans built.
static func _rows(rows: Array, viewport: EventSheetViewport) -> Array:
	var found: Array = []
	for row_data: EventRowData in rows:
		viewport._row_builder._ensure_event_spans(row_data)
		found.append(row_data)
		found.append_array(_rows(row_data.children, viewport))
	return found


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] scene_lighting_facts_test: %s" % label)
		return true
	print("[FAIL] scene_lighting_facts_test: %s" % label)
	# Printed as ARGUMENTS rather than through `%`, because a reading of this vocabulary is full of
	# percent signs and a format string would eat them (or refuse the whole line).
	print("  expected: ", expected)
	print("  actual:   ", actual)
	return false
