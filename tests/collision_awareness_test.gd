# Godot EventSheets - who sees whom, and the four silent failures underneath it.
#
# Collision is the one part of a game whose truth lives outside the script, so this pins both halves
# and the seam between them:
#
#   the reader      what a `.tscn` really says - the layer, the mask, the monitoring switch, the
#                   shape that is not there, the one-way shape that is turned over.
#   the band        the head's collisions sentence, with the band scale law doing its work.
#   the four rules  each one fires on the fixture that has the bug AND stays silent on a clean twin
#                   that is the same sheet with the scene put right. Never crying wolf is half of
#                   every check here, and it is the half that is easy to lose.
#   the quiet law   a finding renders NOTHING in the sheet. The row wears the amber state; the words
#                   are read in the Doctor's inbox and in the selected row's help strip. This is
#                   pinned against the canvas's own source, because a note row added tomorrow would
#                   pass every other test in this file.
#   the doors       what the inbox offers per check, and the shape of a receipt.
#
# The layer names this needs are written, read and put back exactly as they were found, and every
# project-wide question is asked of the fixture scenes alone - so the run leaves the project as it
# started and says the same thing whatever else the repository grows.
@tool
class_name CollisionAwarenessTest
extends RefCounted

## The corpus every project-wide question here is asked of. Scoped on purpose: "which layers does
## anything sit on" is a question about a whole project, and answering it over this repository would
## make these sentences depend on every fixture and showcase anybody adds.
const SCENES: PackedStringArray = [
	"res://tests/fixtures/collision_scene_door.tscn",
	"res://tests/fixtures/collision_scene_enemy.tscn",
	"res://tests/fixtures/collision_scene_gate.tscn",
	"res://tests/fixtures/collision_scene_guarded.tscn",
	"res://tests/fixtures/collision_scene_hatch.tscn",
	"res://tests/fixtures/collision_scene_hollow.tscn",
	"res://tests/fixtures/collision_scene_hushed.tscn",
	"res://tests/fixtures/collision_scene_ledge.tscn",
	"res://tests/fixtures/collision_scene_platform.tscn",
	"res://tests/fixtures/collision_scene_switcher.tscn",
]

const GATE := "res://tests/fixtures/collision_scene_gate.gd"
const DOOR := "res://tests/fixtures/collision_scene_door.gd"
const HUSHED := "res://tests/fixtures/collision_scene_hushed.gd"
const HOLLOW := "res://tests/fixtures/collision_scene_hollow.gd"
const PLATFORM := "res://tests/fixtures/collision_scene_platform.gd"
const LEDGE := "res://tests/fixtures/collision_scene_ledge.gd"
const SWITCHER := "res://tests/fixtures/collision_scene_switcher.gd"
const GUARDED := "res://tests/fixtures/collision_scene_guarded.gd"
const HATCH := "res://tests/fixtures/collision_scene_hatch.gd"
const LEVEL := "res://tests/fixtures/collision_scene_level.gd"

## The corpus for the instanced-level questions, kept apart from the one above ON PURPOSE: this
## fixture puts a body on a layer none of the others use, and folding it into the shared corpus would
## move every census sentence pinned there for a reason that has nothing to do with it.
const LEVEL_SCENES: PackedStringArray = [
	"res://tests/fixtures/collision_scene_enemy.tscn",
	"res://tests/fixtures/collision_scene_level.tscn",
]

const CANVAS_SOURCE := "res://addons/eventsheet/editor/interaction/viewport_row_builder.gd"

## The layer names this test works against, written for the length of the run.
const LAYER_SETTINGS: Array = [
	["layer_names/2d_physics/layer_1", "World"],
	["layer_names/2d_physics/layer_2", "Doors"],
	["layer_names/2d_physics/layer_3", "Enemies"],
]


static func run() -> bool:
	var previous: Dictionary = _apply_layer_names()
	EventSheetSceneCollisionFacts.clear_cache()
	var ok: bool = _test_the_reader()
	ok = _test_a_scene_made_of_scenes() and ok
	ok = _test_the_band() and ok
	ok = _test_nothing_can_reach_it() and ok
	ok = _test_the_filtered_sentence_is_watched_too() and ok
	ok = _test_monitoring_is_off() and ok
	ok = _test_it_has_no_shape() and ok
	ok = _test_the_one_way_faces_down() and ok
	ok = _test_the_sheet_stays_quiet() and ok
	ok = _test_the_doors() and ok
	ok = _test_the_report() and ok
	_restore(previous)
	EventSheetSceneCollisionFacts.clear_cache()
	return ok


# -- the reader ----------------------------------------------------------------------------------


static func _test_the_reader() -> bool:
	var gate: Dictionary = _collidable("res://tests/fixtures/collision_scene_gate.tscn", "Gate")
	var ok: bool = _check("a mask written in the file is read as itself",
		int(gate.get("mask_bits", 0)), 2)
	ok = _check("and so is the layer", int(gate.get("layer_bits", 0)), 2) and ok
	ok = _check("an Area is known to be one", bool(gate.get("is_area", false)), true) and ok
	ok = _check("a shape child is found", bool(gate.get("has_shape", false)), true) and ok
	var enemy: Dictionary = _collidable("res://tests/fixtures/collision_scene_enemy.tscn", "Enemy")
	ok = _check("a body's groups come off its header",
		PackedStringArray(enemy.get("groups", PackedStringArray())),
		PackedStringArray(["enemies"])) and ok
	ok = _check("a property the file never wrote is the engine's default",
		bool(enemy.get("monitoring", false)), true) and ok
	var hollow: Dictionary = _collidable("res://tests/fixtures/collision_scene_hollow.tscn", "Hollow")
	ok = _check("a node with no shape child says so", bool(hollow.get("has_shape", true)), false) and ok
	var platform: Dictionary = _collidable("res://tests/fixtures/collision_scene_platform.tscn", "Platform")
	var turned: Array = platform.get("one_way", [])
	ok = _check("a one-way shape is found", turned.size(), 1) and ok
	ok = _check("and its facing is read off its own rotation",
		bool((turned[0] as Dictionary).get("faces_down", false)), true) and ok
	var ledge: Dictionary = _collidable("res://tests/fixtures/collision_scene_ledge.tscn", "Ledge")
	ok = _check("an upright one-way shape is not turned over",
		bool(((ledge.get("one_way", []) as Array)[0] as Dictionary).get("faces_down", true)), false) and ok
	# The facing itself, at the four rotations that decide it. A quarter turn is where the blocking
	# side stops pointing up, and a rotation is wrapped to the half turn either side of upright first:
	# a scene writes whatever the handle was dragged to, and `rotation = 6.2` is five degrees short of
	# a full turn - upright - rather than the most turned-over shape in the project.
	ok = _check("the facing is read at the quarter turn, not before it",
		[EventSheetSceneCollisionFacts.faces_down(0.0),
			EventSheetSceneCollisionFacts.faces_down(0.8727),
			EventSheetSceneCollisionFacts.faces_down(PI),
			EventSheetSceneCollisionFacts.faces_down(6.2),
			EventSheetSceneCollisionFacts.faces_down(-3.0)],
		[false, false, true, false, true]) and ok
	# The bit arithmetic underneath all of it - Godot numbers layers from 1 and stores them from 0,
	# which is the off-by-one every hand-written mask check gets wrong once.
	ok = _check("layer 1 is the first bit", EventSheetSceneCollisionFacts.bit_of(1), 1) and ok
	ok = _check("layer 3 is the third", EventSheetSceneCollisionFacts.bit_of(3), 4) and ok
	ok = _check("and a number that is not a layer is no bit at all",
		EventSheetSceneCollisionFacts.bit_of(33), 0) and ok
	ok = _check("a mask says which layers it holds",
		EventSheetSceneCollisionFacts.layer_numbers(6), PackedInt32Array([2, 3])) and ok
	ok = _check("the census finds every layer in use",
		EventSheetSceneCollisionFacts.occupied_bits(EventForgePhysicsLayers.DIMENSION_2D, SCENES), 6) and ok
	ok = _check("and a group answers with the layers its members are on",
		EventSheetSceneCollisionFacts.group_bits("\"enemies\"",
			EventForgePhysicsLayers.DIMENSION_2D, SCENES), 4) and ok
	ok = _check("a group is read the same however a row spells it",
		EventSheetSceneCollisionFacts.group_word("&\"enemies\""), "enemies") and ok
	return ok


## THE COMMONEST LAYOUT THERE IS: a level made of scenes. An instance site writes no `type=` on its
## header - the type, the groups, the shape and every property it did not override live in the file
## it points at - so a reader that goes by `type` alone sees an empty level, and a gate whose mask is
## exactly right is told the enemies sit somewhere else.
static func _test_a_scene_made_of_scenes() -> bool:
	var found: Array[Dictionary] = EventSheetSceneCollisionFacts.collidables_of_scene(
		"res://tests/fixtures/collision_scene_level.tscn")
	var names: PackedStringArray = PackedStringArray()
	for collidable: Dictionary in found:
		names.append(str(collidable.get("name", "")))
	var ok: bool = _check("an instanced body is a collidable of the scene that placed it",
		names, PackedStringArray(["Level", "Enemy"]))
	if found.size() < 2:
		return false
	var enemy: Dictionary = found[1]
	ok = _check("wearing the class the file it came from gives it",
		str(enemy.get("type", "")), "CharacterBody2D") and ok
	ok = _check("on the layer the INSTANCE overrides, because that is the copy that is really there",
		int(enemy.get("layer_bits", 0)), 8) and ok
	ok = _check("in the groups it was born in", PackedStringArray(enemy.get("groups", PackedStringArray())),
		PackedStringArray(["enemies"])) and ok
	ok = _check("and with the shape it brought with it, rather than none at all",
		bool(enemy.get("has_shape", false)), true) and ok
	ok = _check("so the group census counts both copies",
		EventSheetSceneCollisionFacts.group_bits("\"enemies\"",
			EventForgePhysicsLayers.DIMENSION_2D, LEVEL_SCENES), 12) and ok
	ok = _check("and the layer census sees the level is not empty",
		EventSheetSceneCollisionFacts.occupied_bits(
			EventForgePhysicsLayers.DIMENSION_2D, LEVEL_SCENES), 14) and ok
	# The whole point of the reading: a mask that is right is not accused.
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(LEVEL)
	ok = _check("a trigger watching the layer its instanced enemies really sit on says nothing",
		_kinds(EventSheetCollisionFindings.findings(sheet, LEVEL, LEVEL_SCENES)),
		PackedStringArray()) and ok
	return ok


# -- the band ------------------------------------------------------------------------------------


static func _test_the_band() -> bool:
	var bands: Array[Dictionary] = EventSheetSceneCollisionFacts.bands(GATE, SCENES)
	var ok: bool = _check("a sheet whose node collides grows one band", bands.size(), 1)
	if not ok:
		return false
	ok = _check("the band says what it sees, who sees it, and whether it is listening",
		str(bands[0].get("value", "")), "sees Doors · seen by Doors · monitoring on") and ok
	ok = _check("and echoes the lines of the scene file it came from",
		str(bands[0].get("echo", "")),
		"collision_scene_gate.tscn: Area2D \"Gate\", collision_layer = 2, collision_mask = 2") and ok
	ok = _check("with the node itself as the thing its control opens",
		str(bands[0].get("reference", "")),
		"res://tests/fixtures/collision_scene_gate.tscn|.") and ok
	# An Area that is switched off wears the problem's colour, because it is the one state that is
	# always a problem whatever the mask says.
	var hushed: Array[Dictionary] = EventSheetSceneCollisionFacts.bands(HUSHED, SCENES)
	ok = _check("an Area with monitoring off says so", str(hushed[0].get("value", "")),
		"sees Enemies · seen by Doors · monitoring off") and ok
	ok = _check("and the band wears the problem's colour",
		bool(hushed[0].get("warning", false)), true) and ok
	# THE BAND SCALE LAW: what fits is named, the rest is counted.
	var two_d: String = EventForgePhysicsLayers.DIMENSION_2D
	ok = _check("three layers are all named",
		EventSheetSceneCollisionFacts.words_for_bits(1 | 2 | 4, two_d), "World, Doors, Enemies") and ok
	ok = _check("a fourth is counted rather than listed",
		EventSheetSceneCollisionFacts.words_for_bits(1 | 2 | 4 | 8, two_d),
		"World, Doors, Enemies and 1 more") and ok
	ok = _check("a finding names every one of them",
		EventSheetSceneCollisionFacts.all_words_for_bits(1 | 2 | 4 | 8, two_d),
		"World, Doors, Enemies, 4") and ok
	ok = _check("and a mask with nothing in it says so",
		EventSheetSceneCollisionFacts.words_for_bits(0, two_d), "nothing") and ok
	# The head puts the band in the stack the file's own reading order gives it.
	var built: Array[Dictionary] = EventSheetHeadBands.bands({"extends": "Area2D",
		"collisions": [{"value": "sees Doors", "echo": "x", "reference": "a|b", "warning": false}]})
	var found: Dictionary = {}
	for band: Dictionary in built:
		if str(band.get("kind", "")) == EventSheetHeadBands.BAND_COLLISIONS:
			found = band
	ok = _check("the head builds a collisions band from those facts",
		str(found.get("leader", "")), "collisions") and ok
	ok = _check("whose control opens the node it is about",
		str(found.get("control", "")), "select the node") and ok
	return ok


# -- the four rules ------------------------------------------------------------------------------


static func _test_nothing_can_reach_it() -> bool:
	var found: Array[Dictionary] = _findings(GATE)
	var ok: bool = _check("a trigger nothing can reach earns one finding",
		_kinds(found), PackedStringArray([EventSheetCollisionFindings.KIND_CANNOT_SEE]))
	if found.is_empty():
		return false
	ok = _check("named by layer, and by the group the trigger filters on",
		str(found[0].get("message", "")),
		"Gate watches Doors, and the members of \"enemies\" sit on Enemies - so this trigger never fires.") and ok
	ok = _check("the door offers the layer to start watching",
		str(found[0].get("fix_label", "")), "Watch Enemies") and ok
	ok = _check("and carries the layer number the write needs",
		int(found[0].get("layer", 0)), 3) and ok
	ok = _check("with the node the write lands on", str(found[0].get("node", "")), ".") and ok
	# The clean twin: the same sheet, the same trigger, the same question, a mask that covers them.
	ok = _check("and the same sheet over a mask that covers them says nothing",
		_kinds(_findings(DOOR)), PackedStringArray()) and ok
	# THE OTHER CLEAN TWIN, and the one that is not about the scene at all: the gate's own scene,
	# watching the gate's own wrong layer, with a sheet that puts the mask right itself. A check
	# that accuses this is a check accusing the very rows this vocabulary teaches, so the rule
	# stands down for a sheet that writes its own layer or mask - the `.tscn` is then where the node
	# starts rather than what it watches.
	ok = _check("a sheet that sets its own mask is never told nothing can reach it",
		_kinds(_findings(SWITCHER)), PackedStringArray()) and ok
	ok = _check("and the rows are what says so, read once for the whole sheet",
		EventSheetCollisionFindings.writes_its_own_layers(
			EventSheetCollisionFindings.all_lines(
				GDScriptImporter.new().import_external(SWITCHER))), true) and ok
	ok = _check("while a sheet that never mentions them is judged by the scene",
		EventSheetCollisionFindings.writes_its_own_layers(
			EventSheetCollisionFindings.all_lines(
				GDScriptImporter.new().import_external(GATE))), false) and ok
	return ok


## THE SAME BUG, WRITTEN THE WAY THE PICKER OFFERS IT. The gate says its filter as a group question
## under a bare trigger; this sheet says it in the trigger's own With field, which is the flagship
## sentence of the whole family. Both are the same wrong mask over the same enemies, so both must
## earn the same finding - a safety net that switches off when the reader picks the newer row is
## worse than no net at all, because it is silent on exactly the sheets most likely to have the bug.
static func _test_the_filtered_sentence_is_watched_too() -> bool:
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(GUARDED)
	var events: Array[Dictionary] = EventSheetCollisionFindings.touch_events(sheet)
	var ok: bool = _check("a filtered trigger is a touch trigger", events.size(), 1)
	if events.is_empty():
		return false
	ok = _check("read as the filtered id the picker files it under",
		str(events[0].get("trigger", "")), "OnOverlapWithGroup") and ok
	ok = _check("with the group read off the trigger's own field",
		PackedStringArray(events[0].get("groups", PackedStringArray())),
		PackedStringArray(["\"enemies\""])) and ok
	var found: Array[Dictionary] = EventSheetCollisionFindings.findings(sheet, GUARDED, SCENES)
	ok = _check("so the same wrong mask earns the same finding",
		_kinds(found), PackedStringArray([EventSheetCollisionFindings.KIND_CANNOT_SEE])) and ok
	if found.is_empty():
		return false
	ok = _check("measured against the layers the group really sits on, not against every layer in use",
		str(found[0].get("message", "")),
		"Guarded watches Doors, and the members of \"enemies\" sit on Enemies - so this trigger never fires.") and ok
	return ok


static func _test_monitoring_is_off() -> bool:
	var found: Array[Dictionary] = _findings(HUSHED)
	var ok: bool = _check("an Area switched off earns one finding",
		_kinds(found), PackedStringArray([EventSheetCollisionFindings.KIND_MONITORING_OFF]))
	if found.is_empty():
		return false
	ok = _check("that says what the switch does",
		str(found[0].get("message", "")),
		"Hushed has monitoring switched off in the scene, so it reports no touches at all - every row waiting on one here is unreachable.") and ok
	ok = _check("and offers the one click that answers it",
		str(found[0].get("fix", "")), EventSheetCollisionFindings.FIX_MONITORING_ON) and ok
	ok = _check("an Area that is listening says nothing",
		_kinds(_findings(DOOR)), PackedStringArray()) and ok
	return ok


static func _test_it_has_no_shape() -> bool:
	var found: Array[Dictionary] = _findings(HOLLOW)
	var ok: bool = _check("a collision object with no shape earns one finding",
		_kinds(found), PackedStringArray([EventSheetCollisionFindings.KIND_NO_SHAPE]))
	if found.is_empty():
		return false
	ok = _check("carrying the engine's own warning to the sheet that depends on it",
		str(found[0].get("message", "")),
		"Hollow has no shape, so it cannot collide or interact with anything. Add a CollisionShape or a CollisionPolygon under it in the scene.") and ok
	ok = _check("with a door that shows the node rather than inventing a geometry",
		str(found[0].get("fix", "")), EventSheetCollisionFindings.FIX_SHOW_IN_SCENE) and ok
	ok = _check("a node that has a shape says nothing",
		_kinds(_findings(DOOR)), PackedStringArray()) and ok
	return ok


static func _test_the_one_way_faces_down() -> bool:
	var found: Array[Dictionary] = _findings(PLATFORM)
	var ok: bool = _check("a one-way shape turned over earns one finding",
		_kinds(found), PackedStringArray([EventSheetCollisionFindings.KIND_ONE_WAY_FACING]))
	if found.is_empty():
		return false
	ok = _check("advisory, because a shape can be turned on purpose",
		str(found[0].get("severity", "")), "info") and ok
	ok = _check("and it says which way round it is",
		str(found[0].get("message", "")),
		"Ledge is one-way and turned over, so bodies fall through it from above and are stopped from below. The rows here are waiting for the landing it blocks.") and ok
	ok = _check("the same sheet over an upright one-way shape says nothing",
		_kinds(_findings(LEDGE)), PackedStringArray()) and ok
	# AND THE GATE IS THE SENTENCE. Turning a one-way shape over is a choice somebody makes on
	# purpose; the finding only means anything where the sheet is plainly waiting for the landing the
	# shape blocks. A sheet with a touch trigger and no landing question anywhere in it was admitted
	# and then told its rows were waiting for one.
	ok = _check("a turned-over shape on a sheet that never asks about landing says nothing",
		_kinds(_findings(HATCH)), PackedStringArray()) and ok
	ok = _check("and the landing question is what admits it, however it is spelled",
		[EventSheetCollisionFindings.asks_about_landing("\tif is_on_floor():"),
			EventSheetCollisionFindings.asks_about_landing("\tif self.__just_landed_3():"),
			EventSheetCollisionFindings.asks_about_landing("\tqueue_free()")],
		[true, true, false]) and ok
	return ok


# -- the quiet sheet law -------------------------------------------------------------------------


static func _test_the_sheet_stays_quiet() -> bool:
	# ONE import, because the two halves have to be about the same rows: a second import makes a
	# second set of EventRow objects, and a finding anchored at one of them is not anchored at the
	# other however identical the two sheets read.
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(GATE)
	var found: Array[Dictionary] = EventSheetCollisionFindings.findings(sheet, GATE, SCENES)
	var event_row: EventRow = _first_event(sheet)
	var ok: bool = _check("the finding is anchored at the row it is about",
		found[0].get("event") == event_row, true)
	ok = _check("the row's help strip says it in full",
		EventSheetCollisionFindings.strip_text(found, event_row),
		str(found[0].get("message", ""))) and ok
	ok = _check("and a row with nothing wrong has nothing to say",
		EventSheetCollisionFindings.strip_text(found, null), "") and ok
	# The half a message-level test cannot see: the canvas must put the sentence into the row's amber
	# state and must NOT hang a note row off it. A note row added tomorrow would pass everything
	# above, so the canvas's own source is what says which of the two it does.
	var canvas: String = FileAccess.get_file_as_string(CANVAS_SOURCE)
	ok = _check("the canvas sets the row's quiet amber state from these findings",
		canvas.contains("row_data.attention_note = EventSheetCollisionFindings.strip_text("), true) and ok
	# Every family that DOES hang a note row reaches its findings through `for_event`, which is what
	# `_build_finding_note_rows` is handed. This family must never be read that way in the canvas:
	# the amber state is the whole of what the sheet gets.
	ok = _check("and never reaches them the way a note row is built",
		canvas.contains("EventSheetCollisionFindings.for_event"), false) and ok
	ok = _check("nor hangs one under the event",
		canvas.contains("_build_finding_note_rows(\n\t\t\t\tEventSheetCollisionFindings"), false) and ok
	return ok


# -- the doors -----------------------------------------------------------------------------------


static func _test_the_doors() -> bool:
	var ok: bool = _check("the inbox offers the mask write",
		_door_ids(EventSheetCollisionsDoctor.CHECK_CANNOT_SEE),
		PackedStringArray(["watch_the_layer"]))
	ok = _check("and the monitoring switch",
		_door_ids(EventSheetCollisionsDoctor.CHECK_MONITORING),
		PackedStringArray(["switch_monitoring_on"])) and ok
	ok = _check("and, where there is nothing to write, the way to the node",
		_door_ids(EventSheetCollisionsDoctor.CHECK_NO_SHAPE),
		PackedStringArray(["show_the_node"])) and ok
	ok = _check("the one-way advisory offers the same door",
		_door_ids(EventSheetCollisionsDoctor.CHECK_ONE_WAY),
		PackedStringArray(["show_the_node"])) and ok
	# The receipt: two lines of the scene file, either side of an arrow, so the reader is shown the
	# change rather than told a count.
	ok = _check("a write leaves the two lines side by side",
		EventSheetSceneCollisionFacts.receipt({"before": "collision_mask = 2", "after": "collision_mask = 6"}),
		"collision_mask = 2 -> collision_mask = 6") and ok
	# And outside the editor there is nothing to write into, which is said rather than silently done.
	var refused: Dictionary = EventSheetSceneCollisionFacts.let_it_see(
		"res://tests/fixtures/collision_scene_gate.tscn", ".", 3)
	ok = _check("and a write with no editor behind it refuses and says why",
		bool(refused.get("ok", true)), false) and ok
	ok = _check("a layer Godot does not have is refused before anything is opened",
		str(EventSheetSceneCollisionFacts.let_it_see("x", ".", 99).get("reason", "")),
		"Godot has collision layers 1 to 32.") and ok
	return ok


# -- the report ----------------------------------------------------------------------------------


static func _test_the_report() -> bool:
	var scripts: PackedStringArray = PackedStringArray([GATE, DOOR, HUSHED, HOLLOW, PLATFORM, LEDGE])
	# A moving platform connects no signal at all - it is a physics loop asking about the floor - so
	# the landing question is one of the words that gets a script opened. Without it the one-way
	# finding was filed against a sheet nothing ever read, which is a finding nobody can reach.
	var ok: bool = _check("the scripts that wait on a touch, and the ones that wait on a landing",
		EventSheetCollisionsDoctor.ranked(scripts),
		PackedStringArray([DOOR, GATE, HOLLOW, HUSHED, LEDGE, PLATFORM]))
	var filed: Array[Dictionary] = EventSheetCollisionsDoctor.report(scripts, SCENES)
	var checks: PackedStringArray = PackedStringArray()
	for finding: Dictionary in filed:
		checks.append(str(finding.get("check", "")))
	ok = _check("and the section files one line per finding under the summary", checks,
		PackedStringArray([EventSheetCollisionsDoctor.CHECK_ID,
			EventSheetCollisionsDoctor.CHECK_CANNOT_SEE,
			EventSheetCollisionsDoctor.CHECK_NO_SHAPE,
			EventSheetCollisionsDoctor.CHECK_MONITORING,
			EventSheetCollisionsDoctor.CHECK_ONE_WAY])) and ok
	ok = _check("the summary counts what it read",
		str(filed[0].get("message", "")),
		"Collisions: 6 script(s) waiting on a touch, 6 read, 4 whose trigger cannot fire as the scene stands.") and ok
	ok = _check("and a project whose scripts never ask about a touch hears nothing at all",
		EventSheetCollisionsDoctor.report(
			PackedStringArray(["res://tests/fixtures/lighting_hall_lamp.gd"]), SCENES).size(), 0) and ok
	return ok


# -- helpers -------------------------------------------------------------------------------------


static func _findings(script_path: String) -> Array[Dictionary]:
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(script_path)
	return EventSheetCollisionFindings.findings(sheet, script_path, SCENES)


static func _kinds(found: Array[Dictionary]) -> PackedStringArray:
	var kinds: PackedStringArray = PackedStringArray()
	for finding: Dictionary in found:
		kinds.append(str(finding.get("kind", "")))
	return kinds


static func _collidable(scene_path: String, node_name: String) -> Dictionary:
	for collidable: Dictionary in EventSheetSceneCollisionFacts.collidables_of_scene(scene_path):
		if str(collidable.get("name", "")) == node_name:
			return collidable
	return {}


static func _door_ids(check_id: String) -> PackedStringArray:
	var ids: PackedStringArray = PackedStringArray()
	for offer: Dictionary in EventSheetQuickFixes.fixes_for({"check": check_id, "subject": "Gate"}):
		ids.append(str(offer.get("id", "")))
	return ids


static func _first_event(sheet: EventSheetResource) -> EventRow:
	for item: Variant in sheet.events:
		if item is EventRow:
			return item as EventRow
	return null


static func _apply_layer_names() -> Dictionary:
	var previous: Dictionary = {}
	for entry: Array in LAYER_SETTINGS:
		previous[entry[0]] = ProjectSettings.get_setting(str(entry[0]), null)
		ProjectSettings.set_setting(str(entry[0]), str(entry[1]))
	return previous


static func _restore(previous: Dictionary) -> void:
	for key: Variant in previous:
		ProjectSettings.set_setting(str(key), previous[key])


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		return true
	print("[FAIL] %s\n  expected: %s\n  got:      %s" % [label, str(expected), str(actual)])
	return false
