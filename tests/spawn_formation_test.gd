# Godot EventSheets - many copies at once, in a shape.
#
# What this gate holds, in the order the mistakes actually happen:
#   1. THE LINES. One shape word changes one expression and nothing else; one timing word changes the
#      last two lines and nothing else. Both are pinned as the exact text they emit, in both
#      dimensions, because a branch that stops being kept emits NOTHING where a line used to be and
#      every other test stays green.
#   2. WHERE THE COPIES REALLY LAND. The emitted loop is run headless on a real node and the copies'
#      places are compared with the four compass points - by value, to a thousandth. A ring divided
#      by the wrong number is arithmetic no reading of the template can catch.
#   3. THE GROUP. Every copy joins the crowd, with Godot's persistent flag, so the row underneath has
#      something to address.
#   4. THE ROUND TRIP. A formation run opens as the formation row with its own values on it, and the
#      file re-emits byte for byte - the lossless rule, per shape and per timing.
#   5. THE DOCTOR. A formation added NOW inside a physics callback is the parenting Godot refuses;
#      the same row set to the next idle moment is not, and must not be reported.
#
# Values are pinned, never counts.
@tool
class_name SpawnFormationTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const SPAWN := preload("res://addons/eventforge/registration/modules/spawn_aces.gd")

const TEST_NAME: String = "spawn_formation_test"

## Where the runnable fixture is written. A real file rather than a script built from a string,
## because a script with no path is a script Godot cannot always instance back.
const FIXTURE_PATH: String = "user://eventforge_formation_fixture.gd"

## What the runtime check spawns: four copies, ten units out, around the origin - so the answer is
## the four compass points and nothing has to be worked out to read the assertion.
const RUNTIME_COUNT: String = "4"
const RUNTIME_RADIUS: String = "10.0"
const RUNTIME_CROWD: String = "\"ring_copies\""
const CLOSE_ENOUGH: float = 0.001


static func run() -> bool:
	var passed: bool = true
	passed = _test_each_shape_writes_one_expression() and passed
	passed = _test_the_timing_changes_the_last_two_lines() and passed
	passed = _test_the_copies_land_on_the_compass_points() and passed
	passed = _test_every_copy_joins_the_crowd() and passed
	passed = _test_a_formation_run_opens_as_the_row() and passed
	passed = _test_the_doctor_sees_the_parenting_it_writes() and passed
	return passed


# ── 1. The lines ──


static func _test_each_shape_writes_one_expression() -> bool:
	var passed: bool = true
	var places: Dictionary = SPAWN.formation_places()
	passed = SUPPORT.pins(TEST_NAME, [
		["a ring divides the whole turn by the count", places[SPAWN.FORMATION_RING],
			"{around} + Vector2.RIGHT.rotated(TAU * {name}_index / {count}) * {size}"],
		["an arc divides its sweep by one less, so it reaches its far end", places[SPAWN.FORMATION_ARC],
			"{around} + Vector2.RIGHT.rotated(deg_to_rad({start} + {sweep} * {name}_index / maxf({count} - 1.0, 1.0))) * {size}"],
		["a line walks from one end to the other", places[SPAWN.FORMATION_LINE],
			"{around}.lerp({to}, {name}_index / maxf({count} - 1.0, 1.0))"],
		["a grid takes the column from the remainder and the row from the whole division",
			places[SPAWN.FORMATION_GRID],
			"{around} + Vector2({name}_index % {across}, {name}_index / {across}) * {size}"],
		["scattering inside a shape is the shipped placement expression, not a second one",
			places[SPAWN.FORMATION_SHAPE],
			SPAWN.inside_shape_expression("({inside} as CollisionShape2D)")],
	]) and passed
	var places_3d: Dictionary = SPAWN.formation_places_3d()
	passed = SUPPORT.pins(TEST_NAME, [
		["a 3D ring turns about the up axis, so it lies on the ground plane",
			places_3d[SPAWN.FORMATION_RING],
			"{around} + Vector3.FORWARD.rotated(Vector3.UP, TAU * {name}_index / {count}) * {size}"],
		["a 3D grid lays its rows out on the ground plane", places_3d[SPAWN.FORMATION_GRID],
			"{around} + Vector3({name}_index % {across}, 0, {name}_index / {across}) * {size}"],
		["scattering inside a box is the shipped placement expression, not a second one",
			places_3d[SPAWN.FORMATION_BOX], SPAWN.inside_box_expression("{inside}")],
	]) and passed
	# THE FROZEN BYTES, said once here as well as in the placement row's own gate: both rows write
	# these characters, so a change to either would be a change to a shipped template.
	passed = SUPPORT.check(TEST_NAME, "the shared shape expression is the shipped one, character for character",
		SPAWN.inside_shape_expression("{shape}"),
		"{shape}.to_global(({shape}.shape as RectangleShape2D).size * Vector2(randf() - 0.5, randf() - 0.5)"
		+ " if {shape}.shape is RectangleShape2D"
		+ " else (Vector2.RIGHT.rotated(randf() * TAU) * ({shape}.shape as CircleShape2D).radius * sqrt(randf())"
		+ " if {shape}.shape is CircleShape2D else Vector2.ZERO))") and passed
	passed = SUPPORT.check(TEST_NAME, "the shared box expression is the shipped one, character for character",
		SPAWN.inside_box_expression("{box}"),
		"({box} as Node3D).to_global(Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5)"
		+ " * ((({box} as CollisionShape3D).shape as BoxShape3D).size"
		+ " if {box} is CollisionShape3D else ({box} as CSGBox3D).size))") and passed
	return passed


static func _test_the_timing_changes_the_last_two_lines() -> bool:
	var immediate: String = _emitted("SpawnFormation", {
		"scene": "Enemy", "name": "wave", "formation": SPAWN.FORMATION_RING, "count": "6",
		"around": "$Totem.global_position", "size": "80.0", "crowd": "\"enemies\"",
		"parent": "self", "when": SPAWN.WHEN_NOW,
	})
	var deferred: String = _emitted("SpawnFormation", {
		"scene": "Enemy", "name": "wave", "formation": SPAWN.FORMATION_RING, "count": "6",
		"around": "$Totem.global_position", "size": "80.0", "crowd": "\"enemies\"",
		"parent": "self", "when": SPAWN.WHEN_LATER,
	})
	var passed: bool = true
	passed = SUPPORT.check(TEST_NAME, "the scene is read once, above the loop",
		immediate.begins_with("var wave_scene = Enemy\nfor wave_index in range(6):\n"), true) and passed
	passed = SUPPORT.check(TEST_NAME, "added now, the copy is placed after it is in the tree",
		immediate.ends_with("\tself.add_child(wave)\n\twave.global_position = wave_place"), true) and passed
	passed = SUPPORT.check(TEST_NAME, "added later, the copy is placed before it is handed over",
		deferred.ends_with("\twave.position = wave_place\n\tself.call_deferred(\"add_child\", wave)"), true) and passed
	# The one thing a reader of the collapsed text cannot see: that the OTHER branch is gone rather
	# than merely further down.
	passed = SUPPORT.check(TEST_NAME, "the deferred spelling writes no immediate add at all",
		deferred.contains("self.add_child("), false) and passed
	passed = SUPPORT.check(TEST_NAME, "the immediate spelling writes no deferred add at all",
		immediate.contains("call_deferred"), false) and passed
	return passed


# ── 2 and 3. Where the copies really land, and what they join ──


static func _test_the_copies_land_on_the_compass_points() -> bool:
	var host: Node2D = _run_the_ring()
	if host == null:
		return SUPPORT.check(TEST_NAME, "the emitted formation loop runs", false, true)
	var passed: bool = true
	passed = SUPPORT.check(TEST_NAME, "four copies are made and added", host.get_child_count(), 4) and passed
	if host.get_child_count() == 4:
		var wanted: Array[Vector2] = [Vector2(10.0, 0.0), Vector2(0.0, 10.0), Vector2(-10.0, 0.0),
			Vector2(0.0, -10.0)]
		for index: int in 4:
			var landed: Vector2 = (host.get_child(index) as Node2D).global_position
			passed = SUPPORT.check(TEST_NAME,
				"copy %d lands on %s" % [index, str(wanted[index])],
				landed.distance_to(wanted[index]) < CLOSE_ENOUGH, true) and passed
	host.free()
	return passed


static func _test_every_copy_joins_the_crowd() -> bool:
	var host: Node2D = _run_the_ring()
	if host == null:
		return SUPPORT.check(TEST_NAME, "the emitted formation loop runs", false, true)
	var passed: bool = true
	for index: int in host.get_child_count():
		passed = SUPPORT.check(TEST_NAME, "copy %d is in the crowd the row named" % index,
			host.get_child(index).is_in_group("ring_copies"), true) and passed
	# The persistent flag is the difference between a crowd that survives being packed into a scene
	# file and one that silently empties. It is not readable off the node, so it is pinned on the line.
	passed = SUPPORT.check(TEST_NAME, "the group is joined with Godot's persistent flag",
		_emitted("SpawnFormation", _runtime_values(SPAWN.WHEN_NOW)).contains(
			"\tcopy.add_to_group(\"ring_copies\", true)"), true) and passed
	host.free()
	return passed


# ── 4. The round trip ──


static func _test_a_formation_run_opens_as_the_row() -> bool:
	var passed: bool = true
	for shape_word: String in SPAWN.FORMATION_ORDER:
		for timing: String in [SPAWN.WHEN_NOW, SPAWN.WHEN_LATER]:
			var values: Dictionary = {
				"scene": "load(\"res://enemy.tscn\")", "name": "wave", "formation": shape_word,
				"count": "6", "around": "$Totem" if shape_word == SPAWN.FORMATION_SHAPE \
					else "$Totem.global_position",
				"size": "80.0", "to": "$Exit.global_position", "start": "20.0", "sweep": "140.0",
				"across": "3", "crowd": "\"enemies\"", "parent": "self", "when": timing,
			}
			var source: String = _compiled("SpawnFormation", values)
			var reopened: EventSheetResource = SUPPORT.reopen(source)
			var lifted: ACEAction = _first_action(reopened)
			passed = SUPPORT.check(TEST_NAME,
				"a %s formation added %s opens as the formation row" % [shape_word, timing],
				"" if lifted == null else lifted.ace_id, "SpawnFormation") and passed
			if lifted != null:
				passed = SUPPORT.check(TEST_NAME,
					"the %s run says which shape it is" % shape_word,
					str(lifted.params.get("formation", "")), shape_word) and passed
				passed = SUPPORT.check(TEST_NAME,
					"the %s run keeps the author's own name for the copy" % shape_word,
					str(lifted.params.get("name", "")), "wave") and passed
				passed = SUPPORT.check(TEST_NAME,
					"the %s run keeps the crowd it joins" % shape_word,
					str(lifted.params.get("crowd", "")), "\"enemies\"") and passed
			passed = SUPPORT.check(TEST_NAME,
				"a %s formation added %s re-emits byte for byte" % [shape_word, timing],
				SUPPORT.reemit(source, "user://eventforge_formation_roundtrip.gd") == source,
				true) and passed
	return passed


# ── 5. The Doctor ──


static func _test_the_doctor_sees_the_parenting_it_writes() -> bool:
	var passed: bool = true
	var reported: PackedStringArray = _finding_kinds(_sheet_in_a_touch_handler("SpawnFormation",
		_runtime_values(SPAWN.WHEN_NOW)))
	passed = SUPPORT.check(TEST_NAME,
		"a formation added now inside a touch handler is the parenting Godot refuses",
		reported.has(EventSheetSpawnFindings.KIND_ADDED_DURING_PHYSICS), true) and passed
	var safe: PackedStringArray = _finding_kinds(_sheet_in_a_touch_handler("SpawnFormation",
		_runtime_values(SPAWN.WHEN_LATER)))
	passed = SUPPORT.check(TEST_NAME,
		"the same formation added on the next idle moment is not reported",
		safe.has(EventSheetSpawnFindings.KIND_ADDED_DURING_PHYSICS), false) and passed
	return passed


# ── Harness ──


## The values the runtime check spawns with: four copies, ten out, around the origin.
static func _runtime_values(timing: String) -> Dictionary:
	return {
		"scene": "fixture_scene()", "name": "copy", "formation": SPAWN.FORMATION_RING,
		"count": RUNTIME_COUNT, "around": "Vector2.ZERO", "size": RUNTIME_RADIUS,
		"crowd": RUNTIME_CROWD, "parent": "self", "when": timing,
	}


## The emitted ring loop, RUN - on a real Node2D, with a real PackedScene to copy. Nothing needs a
## scene tree: a node parents and places another node perfectly well outside one, which is what lets
## the arithmetic be checked headless.
static func _run_the_ring() -> Node2D:
	var body: String = ""
	for line: String in _emitted("SpawnFormation", _runtime_values(SPAWN.WHEN_NOW)).split("\n"):
		body += "\t%s\n" % line
	var file: FileAccess = FileAccess.open(FIXTURE_PATH, FileAccess.WRITE)
	if file == null:
		return null
	file.store_string("extends Node2D\n\n\nfunc fixture_scene() -> PackedScene:\n"
		+ "\tvar root := Node2D.new()\n\troot.name = \"Copy\"\n"
		+ "\tvar packed := PackedScene.new()\n\tpacked.pack(root)\n\troot.free()\n\treturn packed\n\n\n"
		+ "func spawn_the_ring() -> void:\n" + body)
	file.close()
	var script: GDScript = load(FIXTURE_PATH)
	if script == null:
		return null
	var host: Node2D = script.new()
	host.call("spawn_the_ring")
	return host


## One row's emitted statements, through the compiler's own emitter - the same call the compiler
## makes, so a test can never read a line the file would not get.
static func _emitted(ace_id: String, values: Dictionary) -> String:
	return ActionCodegen.generate_action(_action(ace_id, values))


## The whole file one row compiles to, in a ready handler on a Node2D.
static func _compiled(ace_id: String, values: Dictionary) -> String:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnReady"
	event.actions.append(_action(ace_id, values))
	sheet.events.append(event)
	return SUPPORT.compile_output(sheet, "user://eventforge_formation_row.gd")


## The same row inside a body-entered handler - the callback that runs while the physics server is
## flushing, and the one the parenting rule is about.
static func _sheet_in_a_touch_handler(ace_id: String, values: Dictionary) -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnAreaEntered"
	event.actions.append(_action(ace_id, values))
	sheet.events.append(event)
	return sheet


static func _finding_kinds(sheet: EventSheetResource) -> PackedStringArray:
	var kinds: PackedStringArray = PackedStringArray()
	for finding: Dictionary in EventSheetSpawnFindings.findings(sheet):
		kinds.append(str(finding.get("kind", "")))
	return kinds


static func _action(ace_id: String, values: Dictionary) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = ace_id
	action.params = values.duplicate()
	return action


## The first ACE action anywhere in a reopened sheet, or null. What a lifted run has to come back as.
static func _first_action(sheet: EventSheetResource) -> ACEAction:
	if sheet == null:
		return null
	for row: Variant in sheet.events:
		if not (row is EventRow):
			continue
		for entry: Variant in (row as EventRow).actions:
			if entry is ACEAction:
				return entry as ACEAction
	return null
