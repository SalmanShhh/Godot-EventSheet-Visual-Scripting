# Godot EventSheets - a copy spawned already facing somewhere and already moving.
#
# What this gate holds, in the order the mistakes actually happen:
#   1. THE FACING. Four answers in 2D and three in 3D, each one line, each pinned as the exact text
#      it writes. Every one of them assigns the copy's own rotation, because the line after it reads
#      that rotation back - the two are one sentence, and a facing that stopped writing the rotation
#      would leave the launch pointing wherever the scene happened to open.
#   2. THE LAUNCH. One local, so the speed is said once whatever kind of body the scene is - and so
#      that "plus this node's speed" has one place to be added rather than three.
#   3. WHERE THE SPEED IS WRITTEN. A character body is driven by velocity, a rigid body is thrown
#      with linear_velocity, and a bullet flies at its behaviour's own speed. Pinned per answer.
#   4. WHAT THE SCENE SAYS. The dialog reads the scene file rather than guessing, and this pins the
#      reading against real scene files - including one that really does wear the Bullet behaviour,
#      which is the one answer no class name can give.
#   5. THE ROUND TRIP. A launched run opens as the row with its own values on it, and the file
#      re-emits byte for byte.
#   6. THE DOCTOR. The row parents a node, so inside a physics callback it is reported.
#
# Values are pinned, never counts.
@tool
class_name SpawnLaunchedTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const SPAWN := preload("res://addons/eventforge/registration/modules/spawn_aces.gd")

const TEST_NAME: String = "spawn_launched_test"

## Three scenes that really are what they say, read the same way the dialog reads them: the shot
## wears the Bullet behaviour, the enemy is a character body, and the crate is a rigid body.
const BULLET_SCENE: String = "load(\"res://demo/showcase/platformer_shooter/shot.tscn\")"
const BODY_SCENE: String = "load(\"res://tests/fixtures/collision_scene_enemy.tscn\")"
const THROWN_SCENE: String = "load(\"res://tests/fixtures/spawn_scene_crate.tscn\")"


static func run() -> bool:
	var passed: bool = true
	passed = _test_each_facing_writes_one_line() and passed
	passed = _test_the_launch_is_one_local() and passed
	passed = _test_the_speed_lands_where_the_scene_keeps_it() and passed
	passed = _test_the_dialog_reads_the_scene_rather_than_guessing() and passed
	passed = _test_a_launched_run_opens_as_the_row() and passed
	passed = _test_the_doctor_sees_the_parenting_it_writes() and passed
	return passed


# ── 1. The facing ──


static func _test_each_facing_writes_one_line() -> bool:
	var passed: bool = true
	var facings: Dictionary = SPAWN.facing_lines()
	passed = SUPPORT.pins(TEST_NAME, [
		["facing the same way this node does copies this node's rotation",
			facings[SPAWN.FACE_SPAWNER], "{name}.rotation = rotation"],
		["facing a node points the copy from where it landed to where that node is",
			facings[SPAWN.FACE_NODE],
			"{name}.rotation = ({toward}.global_position - {name}.global_position).angle()"],
		["facing the mouse asks the viewport, in world coordinates",
			facings[SPAWN.FACE_MOUSE],
			"{name}.rotation = (get_global_mouse_position() - {name}.global_position).angle()"],
		["facing an angle converts the degrees a person typed",
			facings[SPAWN.FACE_ANGLE], "{name}.rotation = deg_to_rad({angle})"],
	]) and passed
	var facings_3d: Dictionary = SPAWN.facing_lines_3d()
	passed = SUPPORT.pins(TEST_NAME, [
		["a 3D copy facing this node's way copies its whole global rotation",
			facings_3d[SPAWN.FACE_SPAWNER], "{name}.global_rotation = global_rotation"],
		["a 3D copy facing a node is Godot's own look_at",
			facings_3d[SPAWN.FACE_NODE], "{name}.look_at({toward}.global_position)"],
		["a 3D copy facing an angle turns about the up axis",
			facings_3d[SPAWN.FACE_ANGLE], "{name}.rotation.y = deg_to_rad({angle})"],
	]) and passed
	# The one thing every facing has in common, and the reason the launch line can be one line: they
	# all write the copy's own rotation, so the direction is read back off the copy rather than
	# recomputed per answer.
	for word: String in SPAWN.FACING_ORDER:
		passed = SUPPORT.check(TEST_NAME, "the %s facing writes the copy's own rotation" % word,
			str(facings[word]).begins_with("{name}.rotation"), true) and passed
	return passed


# ── 2 and 3. The launch, and where it is written ──


static func _test_the_launch_is_one_local() -> bool:
	var plain: String = _emitted("SpawnFacingAndMoving", _values({}))
	var carried: String = _emitted("SpawnFacingAndMoving", _values({"carry": true}))
	var passed: bool = true
	passed = SUPPORT.check(TEST_NAME, "the 2D launch is the facing turned into a direction, times the speed",
		plain.contains("\nvar shot_launch = Vector2.from_angle(shot.rotation) * 900.0\n"), true) and passed
	passed = SUPPORT.check(TEST_NAME, "nothing is added to the launch unless the row says so",
		plain.contains("shot_launch += velocity"), false) and passed
	passed = SUPPORT.check(TEST_NAME, "this node's own speed is added to the launch, once",
		carried.contains("\nvar shot_launch = Vector2.from_angle(shot.rotation) * 900.0\nshot_launch += velocity\n"),
		true) and passed
	var plain_3d: String = _emitted("SpawnFacingAndMoving3D", _values({"facing": SPAWN.FACE_SPAWNER}))
	passed = SUPPORT.check(TEST_NAME, "forward in three dimensions is the copy's own -Z",
		plain_3d.contains("\nvar shot_launch = -shot.global_transform.basis.z * 900.0\n"), true) and passed
	return passed


static func _test_the_speed_lands_where_the_scene_keeps_it() -> bool:
	var passed: bool = true
	passed = SUPPORT.pin_table(TEST_NAME, {
		SPAWN.MOVE_VELOCITY: "shot.velocity = shot_launch",
		SPAWN.MOVE_LINEAR: "shot.linear_velocity = shot_launch",
		SPAWN.MOVE_BULLET: "shot.get_node(\"BulletBehavior\").speed = shot_launch.length()",
	}, func(word: Variant) -> String:
		return _last_line(_emitted("SpawnFacingAndMoving", _values({"moves": str(word)})))) and passed
	passed = SUPPORT.pin_table(TEST_NAME, {
		SPAWN.MOVE_VELOCITY: "shot.velocity = shot_launch",
		SPAWN.MOVE_LINEAR: "shot.linear_velocity = shot_launch",
		SPAWN.MOVE_BULLET: "shot.get_node(\"Bullet3DBehavior\").speed = shot_launch.length()",
	}, func(word: Variant) -> String:
		return _last_line(_emitted("SpawnFacingAndMoving3D", _values({"moves": str(word)})))) and passed
	# A bullet already flies along its own facing, so what is left to tell it is a LENGTH. Said here
	# because it is the one answer of the three that is not a vector, and reading it as one is the
	# mistake that would make every shot fly to the right.
	passed = SUPPORT.check(TEST_NAME, "a bullet is told a speed rather than handed a direction",
		_last_line(_emitted("SpawnFacingAndMoving", _values({"moves": SPAWN.MOVE_BULLET}))).ends_with(
			".length()"), true) and passed
	return passed


# ── 4. What the scene says ──


static func _test_the_dialog_reads_the_scene_rather_than_guessing() -> bool:
	var passed: bool = true
	passed = SUPPORT.check(TEST_NAME, "a scene wearing the Bullet behaviour is read as one",
		EventSheetSceneVerbs.launch_write_for_scene(BULLET_SCENE),
		EventSheetSceneVerbs.LAUNCH_BULLET) and passed
	passed = SUPPORT.check(TEST_NAME, "a character body scene is read as one driven by velocity",
		EventSheetSceneVerbs.launch_write_for_scene(BODY_SCENE),
		EventSheetSceneVerbs.LAUNCH_VELOCITY) and passed
	passed = SUPPORT.check(TEST_NAME, "a rigid body scene is read as one thrown with linear_velocity",
		EventSheetSceneVerbs.launch_write_for_scene(THROWN_SCENE),
		EventSheetSceneVerbs.LAUNCH_LINEAR) and passed
	passed = SUPPORT.check(TEST_NAME, "a scene named by something no file can be read out of says nothing",
		EventSheetSceneVerbs.launch_write_for_scene("Enemy"), "") and passed
	passed = SUPPORT.check(TEST_NAME, "a path to a file that is not there says nothing",
		EventSheetSceneVerbs.launch_write_for_scene("load(\"res://nowhere/missing.tscn\")"), "") and passed
	passed = SUPPORT.check(TEST_NAME, "the note names the scene it read",
		EventSheetSceneVerbs.launch_note(BULLET_SCENE).contains("shot.tscn"), true) and passed
	passed = SUPPORT.check(TEST_NAME, "the note says where the speed is kept",
		EventSheetSceneVerbs.launch_note(BODY_SCENE).contains("velocity"), true) and passed
	passed = SUPPORT.check(TEST_NAME, "a scene it cannot read gets no note at all",
		EventSheetSceneVerbs.launch_note("Enemy"), "") and passed
	return passed


# ── 5. The round trip ──


static func _test_a_launched_run_opens_as_the_row() -> bool:
	var passed: bool = true
	for word: String in SPAWN.FACING_ORDER:
		for moved: String in SPAWN.MOVE_ORDER:
			for carried: bool in [false, true]:
				var values: Dictionary = _values({"facing": word, "moves": moved, "carry": carried})
				var source: String = _compiled("SpawnFacingAndMoving", values)
				var lifted: ACEAction = _first_action(SUPPORT.reopen(source))
				var said: String = "%s facing, moving by %s%s" % [word, moved,
					", plus this node's speed" if carried else ""]
				passed = SUPPORT.check(TEST_NAME, "a copy spawned %s opens as the launched row" % said,
					"" if lifted == null else lifted.ace_id, "SpawnFacingAndMoving") and passed
				if lifted != null:
					passed = SUPPORT.check(TEST_NAME, "the run says which way it faced (%s)" % said,
						str(lifted.params.get("facing", "")), word) and passed
					passed = SUPPORT.check(TEST_NAME, "the run says where the speed went (%s)" % said,
						str(lifted.params.get("moves", "")), moved) and passed
					passed = SUPPORT.check(TEST_NAME, "the run says whether it carried this node's speed (%s)" % said,
						lifted.params.get("carry", null), carried) and passed
					passed = SUPPORT.check(TEST_NAME, "the run keeps the speed the author typed (%s)" % said,
						str(lifted.params.get("speed", "")), "900.0") and passed
				passed = SUPPORT.check(TEST_NAME, "a copy spawned %s re-emits byte for byte" % said,
					SUPPORT.reemit(source, "user://eventforge_launched_roundtrip.gd") == source,
					true) and passed
	return passed


# ── 6. The Doctor ──


static func _test_the_doctor_sees_the_parenting_it_writes() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnBodyEntered"
	event.actions.append(_action("SpawnFacingAndMoving", _values({})))
	sheet.events.append(event)
	var kinds: PackedStringArray = PackedStringArray()
	for finding: Dictionary in EventSheetSpawnFindings.findings(sheet):
		kinds.append(str(finding.get("kind", "")))
	return SUPPORT.check(TEST_NAME,
		"a launched copy parented inside a touch handler is the parenting Godot refuses",
		kinds.has(EventSheetSpawnFindings.KIND_ADDED_DURING_PHYSICS), true)


# ── Harness ──


## The row's values, with whatever the case under test changes folded in. One base so a pin is about
## the one field it names rather than about a whole dictionary written out again.
static func _values(changed: Dictionary) -> Dictionary:
	var values: Dictionary = {
		"scene": BULLET_SCENE, "name": "shot", "at": "$Muzzle.global_position",
		"facing": SPAWN.FACE_SPAWNER, "toward": "$Target", "angle": "45.0", "speed": "900.0",
		"carry": false, "moves": SPAWN.MOVE_VELOCITY, "parent": "self",
	}
	values.merge(changed, true)
	return values


static func _emitted(ace_id: String, values: Dictionary) -> String:
	return ActionCodegen.generate_action(_action(ace_id, values))


static func _last_line(emitted: String) -> String:
	var lines: PackedStringArray = emitted.split("\n")
	return "" if lines.is_empty() else lines[lines.size() - 1]


static func _compiled(ace_id: String, values: Dictionary) -> String:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnReady"
	event.actions.append(_action(ace_id, values))
	sheet.events.append(event)
	return SUPPORT.compile_output(sheet, "user://eventforge_launched_row.gd")


static func _action(ace_id: String, values: Dictionary) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = ace_id
	action.params = values.duplicate()
	return action


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
