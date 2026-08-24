# L8 - the five ways a light silently does nothing, and the section of the Doctor that says so.
#
# Lighting is the part of a game that fails without a word: the node is in the scene, the row runs, no
# error is printed, and the screen does not change. Every claim here is therefore a fact read off a
# `.tscn` or off the rows before the game runs once, and every one is pinned by the WORDS a reader
# meets - because a count of findings tells nobody which finding moved.
#
# What is pinned:
#   1. THE THREE SCENE RULES, each against a fixture built to fail it and against one built to pass:
#      a point light with no texture, shadows nothing can block, a darkened layer no light reaches.
#      The passing cases matter more than the failing ones - a check that cries wolf gets switched off.
#   2. THE TWO SHEET RULES, which need the rows as well as the scene: an environment row aimed at a
#      scene with no WorldEnvironment, and a row writing an environment `.tres` other scenes load.
#   3. THE ONE-CLICK FIX, by what it WRITES: the row's id, its parameters and the line it compiles to,
#      at the top of the sheet and on ready - and the finding gone afterwards, which is the only proof
#      a fix works that is worth having.
#   4. THE SECTION: registered through the public seam a pack uses, its summary counting lit scenes,
#      and every finding filed under the check id its kind maps to.
#   5. THE NOTE UNDER THE ROW: the canvas hangs the two sheet findings under the event they are about,
#      in the same note row an unknown variable already uses.
@tool
class_name LightingDoctorTest
extends RefCounted

const ROOM_SCENE: String = "res://tests/fixtures/lighting_scene_room.tscn"
const CRYPT_SCENE: String = "res://tests/fixtures/lighting_scene_crypt.tscn"
const CAVE_SCENE: String = "res://tests/fixtures/lighting_scene_cave.tscn"
const VAULT_SCENE: String = "res://tests/fixtures/lighting_scene_vault.tscn"
const SWAMP_SCENE: String = "res://tests/fixtures/lighting_scene_swamp.tscn"

const ROOM: String = "res://tests/fixtures/lighting_scene_room.gd"
const CRYPT: String = "res://tests/fixtures/lighting_scene_crypt.gd"


static func run() -> bool:
	EventSheetSceneLights.clear_cache()
	EventSheetSceneLightingFacts.clear_cache()
	var ok: bool = true
	ok = _test_a_light_that_lights_nothing() and ok
	ok = _test_shadows_nothing_blocks() and ok
	ok = _test_a_darkness_no_light_reaches() and ok
	ok = _test_a_world_that_is_not_there() and ok
	ok = _test_a_shared_environment() and ok
	ok = _test_the_one_click_fix() and ok
	ok = _test_the_section() and ok
	ok = _test_the_note_under_the_row() and ok
	return ok


## A 2D point light lights the SHAPE OF ITS TEXTURE. With none it is switched on, costs a draw and
## shows nothing - the quietest of the five, because everything about the node looks right. A light
## that HAS a texture, and a light of a class that has no texture to give, say nothing.
static func _test_a_light_that_lights_nothing() -> bool:
	var ok: bool = _check("both of the room's point lights cast through nothing",
		_subjects(ROOM_SCENE, EventSheetLightingFindings.KIND_NO_TEXTURE),
		PackedStringArray(["Torch", "Lantern"]))
	ok = _check("and the note says what to give it", _message(ROOM_SCENE,
		EventSheetLightingFindings.KIND_NO_TEXTURE),
		"Torch has no texture, so it lights nothing. Give it one - a soft white circle is the whole of a torch.") and ok
	# The vault's lamp has one, so it is not accused; the room's Moonlight is a DirectionalLight2D,
	# which has no texture property at all and needs none.
	ok = _check("a light with a texture is left alone",
		_subjects(VAULT_SCENE, EventSheetLightingFindings.KIND_NO_TEXTURE), PackedStringArray()) and ok
	ok = _check("and so is every light of a class that casts without one",
		_subjects(CAVE_SCENE, EventSheetLightingFindings.KIND_NO_TEXTURE), PackedStringArray()) and ok
	return _check("which is what the scene facts underneath answer",
		EventSheetSceneLightingFacts.textureless_lights(CAVE_SCENE), PackedStringArray()) and ok


## Godot draws a shadow only where an occluder's own mask shares a layer with the light's SHADOW
## mask. The crypt's occluder sits on another layer, so its candle spends the draw cost and shows
## nothing; the room's two occluders match, so nothing is said about it.
static func _test_shadows_nothing_blocks() -> bool:
	var ok: bool = _check("the crypt's candle casts shadows nothing can block",
		_subjects(CRYPT_SCENE, EventSheetLightingFindings.KIND_NO_OCCLUDER),
		PackedStringArray(["Candle"]))
	# The first sentence is the head band's own, word for word: a reader meets the same wording
	# wherever they meet the problem, and only the second sentence is the Doctor's advice.
	ok = _check("in the band's own words, with the step to take after them",
		_message(CRYPT_SCENE, EventSheetLightingFindings.KIND_NO_OCCLUDER),
		"Candle casts shadows and no occluder's mask matches - shadows never appear. Add an occluder, or turn the shadows off and save the draw cost.") and ok
	ok = _check("the room's occluders match, so nothing is said about it",
		_subjects(ROOM_SCENE, EventSheetLightingFindings.KIND_NO_OCCLUDER), PackedStringArray()) and ok
	return _check("and a scene whose lights cast no shadows is not asked",
		_subjects(VAULT_SCENE, EventSheetLightingFindings.KIND_NO_OCCLUDER), PackedStringArray()) and ok


## A darkened layer nothing reaches is a uniformly dark scene. The RANGE mask is the question here
## (`range_item_cull_mask` against what is drawn on layer 1), which is a different property from the
## shadow one - and confusing them is how "the light is right there and the room is black" happens.
static func _test_a_darkness_no_light_reaches() -> bool:
	var ok: bool = _check("the vault's lamp misses the layer its darkness is on",
		_subjects(VAULT_SCENE, EventSheetLightingFindings.KIND_NO_LIGHT), PackedStringArray(["Level"]))
	ok = _check("and the note says how dark it is and both ways out",
		_message(VAULT_SCENE, EventSheetLightingFindings.KIND_NO_LIGHT),
		"Level darkens the layer to 82% and no light reaches it - the scene is uniformly dark. Add a light, or check the range masks of the ones there are.") and ok
	ok = _check("the room's lights do reach it, so its darkness is fine",
		_subjects(ROOM_SCENE, EventSheetLightingFindings.KIND_NO_LIGHT), PackedStringArray()) and ok
	# The percentage is the row's own reading of the colour the file holds, so the Doctor and the
	# darkness row say the same number about the same node.
	return _check("and the number is the one the darkness row reads",
		EventForgeValueLens.darkness_percent("Color(0.15, 0.18, 0.3, 1)"), "82%") and ok


## An environment row aimed at a scene with no WorldEnvironment in it. The row compiles, runs, and
## writes a property of nothing at all - so this one needs the ROWS as well as the scene.
static func _test_a_world_that_is_not_there() -> bool:
	var sheet: EventSheetResource = _sheet_writing_the_world(ROOM)
	var found: Array[Dictionary] = EventSheetLightingFindings.findings(sheet)
	var ok: bool = _check("a fog row on a scene with no world is the finding",
		_kinds(found), PackedStringArray([EventSheetLightingFindings.KIND_NO_ENVIRONMENT]))
	ok = _check("and the note names the row and the scene", str(found[0].get("message", "")),
		"Turn Fog On writes the world's environment, and lighting_scene_room.tscn has no WorldEnvironment node - the row does nothing when the game runs. Add one to the scene.") and ok
	ok = _check("there is nothing one click could write, so nothing is offered",
		str(found[0].get("fix", "")), "") and ok
	ok = _check("it hangs under the event that writes it",
		EventSheetLightingFindings.for_event(found, sheet.events[0] as EventRow).size(), 1) and ok
	# The same row on the crypt, whose scene DOES hold a WorldEnvironment, says nothing of the kind.
	ok = _check("the same row on a scene that has one is not accused",
		_kinds(EventSheetLightingFindings.findings(_sheet_writing_the_world(CRYPT))),
		PackedStringArray([EventSheetLightingFindings.KIND_SHARED_ENVIRONMENT])) and ok
	return _check("and a sheet that says nothing about the environment earns neither",
		_kinds(EventSheetLightingFindings.findings(
			GDScriptImporter.new().import_external(ROOM))), PackedStringArray()) and ok


## An environment written at run time through a `.tres` other scenes load. An environment resource is
## a FILE: writing fog into it writes it for every scene holding the same file, so the change follows
## the player out of the room. The one finding of the five with a single step to take.
static func _test_a_shared_environment() -> bool:
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(CRYPT)
	var found: Array[Dictionary] = EventSheetLightingFindings.findings(sheet)
	var ok: bool = _check("the crypt writes an environment the swamp also loads",
		_kinds(found), PackedStringArray([EventSheetLightingFindings.KIND_SHARED_ENVIRONMENT]))
	ok = _check("and the note names the file and every scene that would follow the change",
		str(found[0].get("message", "")),
		"Turn Fog On writes lighting_environment.tres, which lighting_scene_swamp.tscn also uses - the change follows the player into those scenes. Give this scene its own copy first.") and ok
	ok = _check("its subject is the spelling the fix's row will be aimed at",
		str(found[0].get("subject", "")), "$World") and ok
	ok = _check("and the button says what the click will do",
		str(found[0].get("fix_label", "")), "Make the environment this scene's own") and ok
	# Every row that reaches the environment is one of these rows, whichever vocabulary wrote it: the
	# node-scoped World words, and the tween that names the member as an argument rather than a
	# receiver. A list of ace_ids would have missed the second.
	var reaching: PackedStringArray = PackedStringArray()
	for row: Dictionary in EventSheetLightingFindings.environment_rows(sheet):
		reaching.append(str((row["ace"] as Resource).get("ace_id")))
	ok = _check("all five of the crypt's environment rows are seen, the tween included", reaching,
		PackedStringArray(["WorldFogOn", "WorldSetFogThickness", "WorldSetAmbientLight",
			"WorldGlowOn", "WorldFadeGlow"])) and ok
	# The member has to be reached THROUGH, not merely mentioned: a variable that starts with the
	# same letters is somebody else's.
	ok = _check("a line that only starts with the word is not one of them",
		EventSheetLightingFindings.reaches_the_environment("$World.environment_hue = 3"), false) and ok
	return _check("and the frozen Core rows, which name it in a parameter, are",
		EventSheetLightingFindings.reaches_the_environment(
			"$WorldEnvironment.environment.fog_enabled = true"), true) and ok


## THE FIX, by what it writes. A copy taken every frame is not a fix and a copy taken after the rows
## that write through it is not one either, so the row goes at the top of the sheet, on ready.
static func _test_the_one_click_fix() -> bool:
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(CRYPT)
	var ok: bool = _check("the fix writes the shipped row, aimed at the node the finding named",
		_row_facts(EventSheetLightingFindings.own_environment_action("$World")),
		PackedStringArray(["Core", "WorldOwnEnvironment", "$World",
			"{target.}environment = {target.}environment.duplicate()"]))
	# The node the sheet is on is spelled `self` by the finding and BLANK by the row, because blank is
	# what the shipped descriptor opens on and what a reader would have left there.
	ok = _check("and aimed at nothing at all when the node is the sheet's own",
		str(EventSheetLightingFindings.own_environment_action("self").params.get("target", "?")), "") and ok
	ok = _check("it goes in at the top of the sheet, on ready",
		EventSheetLightingFindings.insert_own_environment(sheet, "$World"), true) and ok
	var inserted: EventRow = sheet.events[3] as EventRow
	ok = _check("after the file's own header lines, before the first row that runs",
		PackedStringArray([inserted.trigger_provider_id, inserted.trigger_id,
			str(inserted.actions.size())]), PackedStringArray(["Core", "OnReady", "1"])) and ok
	# The proof a fix works: the finding is gone, and the emitted code takes the copy before the first
	# row that writes through it.
	ok = _check("the finding is gone", EventSheetLightingFindings.findings(sheet).size(), 0) and ok
	var compiled: String = str(SheetCompiler.compile(sheet, "user://lighting_doctor_fix.gd").get("output", ""))
	ok = _check("and the copy is taken before anything writes through it",
		compiled.contains("func _ready() -> void:\n\t$World.environment = $World.environment.duplicate()\n\t$Level.color"),
		true) and ok
	ok = _check("a sheet that already takes its own copy is not told to again",
		EventSheetLightingFindings.insert_own_environment(sheet, "$World"), false) and ok
	# AND AFTER A SAVE AND A REOPEN, which is the only form of "fixed" a reader ever sees. The sheet
	# in memory is not the artefact - the FILE is - so the line has to read back as the row that wrote
	# it. Otherwise the finding returns on the next open, the reader clicks the fix again, and the
	# scene takes the copy twice every _ready.
	var reopened: EventSheetResource = GDScriptImporter.new().import_external_source(compiled, true, CRYPT)
	ok = _check("the file it wrote still holds the row when it is opened again",
		EventSheetLightingFindings.writes_its_own_environment(reopened), true) and ok
	ok = _check("so the reader is not told to fix it a second time",
		EventSheetLightingFindings.findings(reopened).size(), 0) and ok
	ok = _check("and a second click has nothing left to write",
		EventSheetLightingFindings.insert_own_environment(reopened, "$World"), false) and ok
	# The same gesture from the report: the panel's chip runs the dock operation the note row runs.
	var offered: Array[Dictionary] = EventSheetQuickFixes.fixes_for(
		{"check": EventSheetLightingDoctor.CHECK_SHARED, "subject": "$World"})
	return _check("the report offers it too, in the same words",
		[str(offered.size()), str(offered[0].get("label", ""))],
		["1", "Make the environment this scene's own"] as Array) and ok


## The section itself: registered through the very seam a pack uses, summarised by how many scenes are
## lit and how many of them have something wrong, and every finding filed under its own check id.
static func _test_the_section() -> bool:
	EventSheetLightingDoctor.ensure_registered()
	var registered: int = 0
	for entry: Dictionary in EventSheetProjectDoctor._extension_checks:
		if str(entry.get("id", "")) == EventSheetLightingDoctor.CHECK_ID:
			registered += 1
	# Registering twice would run the section twice; the seam replaces by id, and this is what proves
	# it (ensure_registered has now been called at least once by the Doctor and once here).
	var ok: bool = _check("the section is registered through the public seam, exactly once",
		registered, 1)
	var report: Array[Dictionary] = EventSheetLightingDoctor.report(
		PackedStringArray([CRYPT_SCENE, VAULT_SCENE, CAVE_SCENE]), PackedStringArray([CRYPT]))
	ok = _check("it leads with a summary counting the lit scenes and the troubled ones",
		str(report[0].get("message", "")),
		"Lighting: 3 lit scene(s), 2 with something that will not show at run time.") and ok
	ok = _check("and every finding is filed under the check its kind maps to", _checks(report),
		PackedStringArray([EventSheetLightingDoctor.CHECK_ID, EventSheetLightingDoctor.CHECK_TEXTURE,
			EventSheetLightingDoctor.CHECK_OCCLUDER, EventSheetLightingDoctor.CHECK_DARKNESS,
			EventSheetLightingDoctor.CHECK_SHARED])) and ok
	ok = _check("the summary is a note and the findings are warnings", _severities(report),
		PackedStringArray(["info", "warning", "warning", "warning", "warning"])) and ok
	# Each line points at the file a reader should open - the scene for a scene fact, the sheet for a
	# row - because double-clicking the line in the panel is what takes them there.
	ok = _check("and each points at the file to open", str(report[4].get("path", "")), CRYPT) and ok
	ok = _check("a project with no lighting in it reports nothing at all",
		EventSheetLightingDoctor.report(PackedStringArray(), PackedStringArray()).size(), 0) and ok
	ok = _check("a scene with nothing lighting in it is not counted as lit",
		EventSheetLightingDoctor.holds_lighting(
			"res://tests/fixtures/multiplayer_scene_level.tscn"), false) and ok
	return _check("and a scene holding only a world still is",
		EventSheetLightingDoctor.holds_lighting(SWAMP_SCENE), true) and ok


## The canvas half: a finding about a row is said UNDER that row, in the note the sheet already uses
## for an unknown variable - one note look and one fix click, not three.
static func _test_the_note_under_the_row() -> bool:
	var notes: PackedStringArray = _note_messages(GDScriptImporter.new().import_external(CRYPT))
	var ok: bool = _check("the crypt's shared environment is said under the event that writes it",
		notes.size(), 1)
	return _check("in the finding's own words, with the one click that repairs it beside them",
		notes[0] if not notes.is_empty() else "",
		"Turn Fog On writes lighting_environment.tres, which lighting_scene_swamp.tscn also uses - the change follows the player into those scenes. Give this scene its own copy first. Make the environment this scene's own") and ok


# ── the walk ────────────────────────────────────────────────────────────────────


## A sheet with ONE environment row on it, attached to the given script's scene. Built in memory
## rather than lifted, so the rule is pinned by what it reads rather than by what the importer
## happened to make of a file - and the row carries no template of its own, so the one the shipped
## descriptor holds is the one under test.
static func _sheet_writing_the_world(script_path: String) -> EventSheetResource:
	var sheet := EventSheetResource.new()
	sheet.external_source_path = script_path
	var action := ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "WorldFogOn"
	var event_row := EventRow.new()
	event_row.trigger_provider_id = "Core"
	event_row.trigger_id = "OnReady"
	event_row.actions.append(action)
	sheet.events.append(event_row)
	return sheet


## What one written row IS: its provider, its id, the node it is aimed at and the template it will
## compile through. Pinned together, because a row whose parameters do not match its template shows
## the default and still round-trips - the byte gate cannot see that, and this can.
static func _row_facts(action: ACEAction) -> PackedStringArray:
	return PackedStringArray([action.provider_id, action.ace_id,
		str(action.params.get("target", "")), action.codegen_template])


## Every note the canvas hangs under a row of this sheet, in row order, as the spans read left to
## right: the message and the button beside it. Read off the built spans, which is what a reader
## actually sees - and the button has to be there, because a finding whose repair is one click is
## only one click while the button is on the row.
static func _note_messages(sheet: EventSheetResource) -> PackedStringArray:
	sheet.read_only = true
	var style := EventSheetEditorStyle.new()
	style.ensure_defaults()
	sheet.editor_style = style
	var viewport := EventSheetViewport.new()
	viewport.set_ace_registry(EventSheetACERegistry.new())
	viewport.set_sheet(sheet)
	viewport.set_reading_mode(true)
	var messages: PackedStringArray = PackedStringArray()
	for row_data: EventRowData in _rows(viewport._root_rows, viewport):
		var words: PackedStringArray = PackedStringArray()
		for span: SemanticSpan in row_data.spans:
			if span.metadata is Dictionary \
					and str((span.metadata as Dictionary).get("variable_note", "")) in ["message", "fix"]:
				words.append(span.text)
		if not words.is_empty():
			messages.append(" ".join(words))
	viewport.free()
	return messages


## Every row in the tree, parents before children, with its spans built.
static func _rows(rows: Array, viewport: EventSheetViewport) -> Array:
	var found: Array = []
	for row_data: EventRowData in rows:
		viewport._row_builder._ensure_event_spans(row_data)
		found.append(row_data)
		found.append_array(_rows(row_data.children, viewport))
	return found


## The nodes one scene rule names, in scene order.
static func _subjects(scene_path: String, kind: String) -> PackedStringArray:
	var subjects: PackedStringArray = PackedStringArray()
	for finding: Dictionary in EventSheetLightingFindings.scene_findings(scene_path):
		if str(finding.get("kind", "")) == kind:
			subjects.append(str(finding.get("subject", "")))
	return subjects


## The first message one scene rule says about a scene, "" when it says nothing.
static func _message(scene_path: String, kind: String) -> String:
	for finding: Dictionary in EventSheetLightingFindings.scene_findings(scene_path):
		if str(finding.get("kind", "")) == kind:
			return str(finding.get("message", ""))
	return ""


static func _kinds(found: Array[Dictionary]) -> PackedStringArray:
	var kinds: PackedStringArray = PackedStringArray()
	for finding: Dictionary in found:
		kinds.append(str(finding.get("kind", "")))
	return kinds


static func _checks(found: Array[Dictionary]) -> PackedStringArray:
	var checks: PackedStringArray = PackedStringArray()
	for finding: Dictionary in found:
		checks.append(str(finding.get("check", "")))
	return checks


static func _severities(found: Array[Dictionary]) -> PackedStringArray:
	var severities: PackedStringArray = PackedStringArray()
	for finding: Dictionary in found:
		severities.append(str(finding.get("severity", "")))
	return severities


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] lighting_doctor_test: %s" % label)
		return true
	print("[FAIL] lighting_doctor_test: %s" % label)
	# Printed as ARGUMENTS rather than through `%`, because these readings are full of percent signs
	# and a format string would eat them (or refuse the whole line).
	print("  expected: ", expected)
	print("  actual:   ", actual)
	return false
