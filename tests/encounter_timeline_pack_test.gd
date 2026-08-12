# Godot EventSheets - Encounter Timeline pack runtime behaviour.
#
# Loads the COMPILED Encounter Timeline behavior and drives its clock by hand, treeless (signals
# still emit on a bare instance, and a spawn parents itself to the behavior when there is no scene):
# beats sorted by time whatever order they were typed in, spawning on schedule, groups (persistent,
# proven by packing a spawn into a scene), the huge-delta catch-up, stop / skip / add-mid-run, the
# DECOUPLED Object Pool seam proven against a stub pool that knows nothing about this pack, and the
# derived report - totals, density and the honest list of fields it could not read - written to a
# real file.
#
# What this file CANNOT reach: the seam's /root/ObjectPool autoload tier. A treeless suite has no
# main loop, so is_inside_tree() is false and that branch never runs here - the explicit Use Object
# Pool Node tier and the no-pool fallback are the two that are proven, plus the contract guard that
# refuses a node missing any of the three functions.
@tool
class_name EncounterTimelinePackTest
extends RefCounted

const PACK := "res://eventsheet_addons/encounter_timeline/encounter_timeline_behavior.gd"
const RESOURCE_PACK := "res://eventsheet_addons/encounter_resource/encounter_resource.gd"
const PROBE_SCENE := "user://eventsheets_encounter_probe.tscn"
const REPORT_PATH := "user://eventsheets_encounter_report_probe.txt"
const MISSING_SCENE := "res://__eventsheets_no_such_scene__.tscn"


## A pool that is not the ObjectPool autoload and knows nothing about this pack - it just answers
## the three functions the seam asks for. If the timeline spawns through THIS, it spawns through
## anything the contract describes.
class StubPool:
	extends Node

	var created: Array = []
	var spawns: Array = []

	func has_pool(pool_name: String) -> bool:
		return created.has(pool_name)

	func create_pool(pool_name: String, _scene_path: String, _prewarm: int) -> void:
		created.append(pool_name)

	func spawn(pool_name: String) -> Node:
		spawns.append(pool_name)
		return Node.new()


## A node that looks like a pool but cannot spawn - the third of the three functions the contract
## asks for is missing. The seam must fall through to instantiating rather than call it blindly,
## which at runtime would be "Invalid call to 'spawn'" on every single beat.
class HalfPool:
	extends Node

	var asked: Array = []

	func has_pool(pool_name: String) -> bool:
		asked.append(pool_name)
		return false

	func create_pool(pool_name: String, _scene_path: String, _prewarm: int) -> void:
		asked.append(pool_name)


static func run() -> bool:
	var all_passed: bool = true
	var script: GDScript = load(PACK)
	all_passed = _check("encounter timeline pack loads + parses", script != null, true) and all_passed
	var resource_script: GDScript = load(RESOURCE_PACK)
	all_passed = _check("encounter resource pack loads + parses", resource_script != null, true) and all_passed
	if script == null or resource_script == null:
		return all_passed

	all_passed = _check("the probe scene saved for the spawn test", _write_probe_scene(), OK) and all_passed

	# An ambush, typed OUT of time order, with two deliberately imperfect beats: one with no scene
	# at all and no group, and one pointing at a scene that is not in the project.
	var plan: Resource = resource_script.new()
	plan.encounter_name = "Ambush"
	plan.entries = [
		{"at_seconds": 40.0, "scene_path": PROBE_SCENE, "count": 2, "group_name": "wave2", "note": "flankers"},
		{"at_seconds": 5.0, "scene_path": PROBE_SCENE, "count": 3, "group_name": "wave1", "note": "opener"},
		{"at_seconds": 70.0, "scene_path": MISSING_SCENE, "count": 1, "group_name": "boss", "note": "the big one"},
		{"at_seconds": 20.0, "scene_path": "", "count": 4, "group_name": "", "note": "beat only"}
	]

	var timeline: Node = script.new()
	var seen: Dictionary = {"groups": [], "finished": 0}
	timeline.on_entry_spawned.connect(func(_node: Node, group_name: String) -> void: (seen.groups as Array).append(group_name))
	timeline.on_encounter_finished.connect(func() -> void: seen.finished = int(seen.finished) + 1)
	timeline.load_encounter(plan)

	# --- What the timeline read off the resource ---
	all_passed = _check("every beat loaded", timeline.entry_count(), 4) and all_passed
	all_passed = _check("the encounter name comes off the resource", timeline.encounter_title(), "Ambush") and all_passed
	all_passed = _check("beats are sorted by time, not by typing order", timeline.entry_seconds_at(0), 5.0) and all_passed
	all_passed = _check("the last beat is the latest one", timeline.entry_seconds_at(3), 70.0) and all_passed
	all_passed = _check("a note travels with its beat through the sort", timeline.entry_note_at(0), "opener") and all_passed
	all_passed = _check("an out-of-range beat has no note", timeline.entry_note_at(9), "") and all_passed
	all_passed = _check("the encounter lasts until its last beat", timeline.duration(), 70.0) and all_passed
	all_passed = _check("the plan intends every count added up", timeline.planned_spawns(), 10) and all_passed
	all_passed = _check("a loaded plan is not empty", timeline.is_empty(), false) and all_passed
	all_passed = _check("density is derived from the beats: first 30 s", timeline.spawns_between(0.0, 30.0), 7) and all_passed
	all_passed = _check("second 30 s", timeline.spawns_between(30.0, 60.0), 2) and all_passed
	all_passed = _check("third 30 s", timeline.spawns_between(60.0, 90.0), 1) and all_passed
	all_passed = _check("a window with nothing in it counts 0", timeline.spawns_between(90.0, 120.0), 0) and all_passed

	# --- Playing it back on its own clock ---
	all_passed = _check("nothing runs until it is started", timeline.is_running(), false) and all_passed
	timeline.start_encounter()
	all_passed = _check("starting sets it running", timeline.is_running(), true) and all_passed
	all_passed = _check("the first beat is the next one due", timeline.next_entry_seconds(), 5.0) and all_passed
	timeline.advance(4.0)
	all_passed = _check("a beat does not fire early", timeline.spawned_count(), 0) and all_passed
	all_passed = _check("the clock is where the deltas put it", timeline.elapsed_seconds(), 4.0) and all_passed
	timeline.advance(2.0)
	all_passed = _check("its count spawns the moment its time arrives", timeline.spawned_count(), 3) and all_passed
	all_passed = _check("each spawn joined the beat's group", seen.groups, ["wave1", "wave1", "wave1"]) and all_passed
	all_passed = _check("the group is real on the node, not just reported", (timeline.last_spawned_node() as Node).is_in_group("wave1"), true) and all_passed
	# And PERSISTENT, which is a different thing: PackedScene.pack() saves persistent groups only, so a
	# group added without that flag is on the live node yet gone from any scene the spawn is packed
	# into - and every group-based pick then silently finds nothing. is_in_group cannot tell the two
	# apart; packing the node and reading the copy can.
	var packed_spawn: PackedScene = PackedScene.new()
	packed_spawn.pack(timeline.last_spawned_node() as Node)
	var repacked: Node = packed_spawn.instantiate()
	all_passed = _check("the group survives being packed into a scene", repacked.is_in_group("wave1"), true) and all_passed
	repacked.free()
	all_passed = _check("the last-spawn group reads back", timeline.last_spawned_group(), "wave1") and all_passed
	all_passed = _check("the next beat is now the one after it", timeline.next_entry_seconds(), 20.0) and all_passed

	timeline.advance(20.0)
	all_passed = _check("a beat with no scene spawns nothing and blocks nothing", timeline.spawned_count(), 3) and all_passed
	all_passed = _check("and the clock moved past it", timeline.next_entry_seconds(), 40.0) and all_passed
	timeline.advance(20.0)
	all_passed = _check("the second wave spawned", timeline.spawned_count(), 5) and all_passed
	all_passed = _check("in its own group", seen.groups, ["wave1", "wave1", "wave1", "wave2", "wave2"]) and all_passed
	all_passed = _check("the encounter is still running with a beat left", timeline.is_running(), true) and all_passed
	timeline.advance(30.0)
	all_passed = _check("a beat whose scene is missing spawns nothing", timeline.spawned_count(), 5) and all_passed
	all_passed = _check("the last beat ends the encounter", timeline.is_running(), false) and all_passed
	all_passed = _check("On Encounter Finished fired exactly once", seen.finished, 1) and all_passed
	all_passed = _check("and the encounter reads as finished", timeline.is_finished(), true) and all_passed
	all_passed = _check("no beat is due any more", timeline.next_entry_seconds(), -1.0) and all_passed
	timeline.advance(10.0)
	all_passed = _check("ticking a finished encounter fires nothing more", seen.finished, 1) and all_passed

	# --- One huge delta plays every beat it crossed (a stall, a loading hitch) ---
	var caught_up: Node = script.new()
	var catch_up_spawns: Array = []
	caught_up.on_entry_spawned.connect(func(_node: Node, group_name: String) -> void: catch_up_spawns.append(group_name))
	caught_up.load_encounter(plan)
	caught_up.start_encounter()
	caught_up.advance(1000.0)
	all_passed = _check("a single huge delta plays every beat it crossed", caught_up.spawned_count(), 5) and all_passed
	all_passed = _check("in time order", catch_up_spawns, ["wave1", "wave1", "wave1", "wave2", "wave2"]) and all_passed
	all_passed = _check("and it ends there", caught_up.is_finished(), true) and all_passed

	# --- Stop, skip, and adding a beat mid-encounter ---
	var director: Node = script.new()
	director.load_encounter(plan)
	director.start_encounter()
	director.advance(6.0)
	director.stop_encounter()
	director.advance(100.0)
	all_passed = _check("a stopped encounter spawns nothing more", director.spawned_count(), 3) and all_passed
	all_passed = _check("stopping is not finishing", director.is_finished(), false) and all_passed
	all_passed = _check("and the clock kept where it stopped", director.elapsed_seconds(), 6.0) and all_passed

	director.start_encounter()
	director.skip_to(50.0)
	all_passed = _check("skipping spawns nothing it passes", director.spawned_count(), 0) and all_passed
	all_passed = _check("but marks those beats played", director.next_entry_seconds(), 70.0) and all_passed
	director.add_entry(10.0, PROBE_SCENE, 1, "late", "added behind the clock")
	all_passed = _check("a beat added behind the clock still joins the plan", director.entry_count(), 5) and all_passed
	all_passed = _check("without becoming the next one due", director.next_entry_seconds(), 70.0) and all_passed
	director.advance(30.0)
	all_passed = _check("and it is never replayed", director.spawned_count(), 0) and all_passed
	director.add_entry(95.0, PROBE_SCENE, 2, "reinforcements", "")
	director.start_encounter()
	director.advance(200.0)
	all_passed = _check("a beat added ahead of the clock does spawn", director.spawned_count(), 8) and all_passed

	# --- The pooling seam: a stub pool that knows nothing about this pack ---
	var pool: Node = StubPool.new()
	var pooled: Node = script.new()
	pooled.load_encounter(plan)
	pooled.use_pool_node(pool)
	pooled.start_encounter()
	pooled.advance(1000.0)
	all_passed = _check("every spawn went through the pool", pool.spawns, [PROBE_SCENE, PROBE_SCENE, PROBE_SCENE, PROBE_SCENE, PROBE_SCENE]) and all_passed
	all_passed = _check("one pool per scene path, made once", pool.created, [PROBE_SCENE]) and all_passed
	all_passed = _check("the tally is the same either way", pooled.spawned_count(), 5) and all_passed

	pooled.use_object_pool = false
	pooled.start_encounter()
	pooled.advance(1000.0)
	all_passed = _check("turning pooling off goes back to instantiating", pool.spawns.size(), 5) and all_passed
	all_passed = _check("and still spawns the same nodes", pooled.spawned_count(), 5) and all_passed

	# A node that answers only part of the contract must be ignored, not called blindly.
	var half_pool: Node = HalfPool.new()
	var half_pooled: Node = script.new()
	half_pooled.load_encounter(plan)
	half_pooled.use_pool_node(half_pool)
	half_pooled.start_encounter()
	half_pooled.advance(1000.0)
	all_passed = _check("a pool missing spawn() is never asked anything", half_pool.asked, []) and all_passed
	all_passed = _check("and the wave still spawns, by instantiating", half_pooled.spawned_count(), 5) and all_passed

	# --- The report: derived from the data, honest about what it could not read ---
	var report: String = timeline.encounter_report()
	all_passed = _check("the report names the encounter", report.contains("Encounter report: Ambush"), true) and all_passed
	all_passed = _check("the totals are the derived ones", report.contains("Beats: 4   Planned spawns: 10"), true) and all_passed
	all_passed = _check("a beat with no scene is called out", report.contains("no scene path - it spawns nothing"), true) and all_passed
	all_passed = _check("a scene that is not in the project is named", report.contains("scene not found in this project (%s)" % MISSING_SCENE), true) and all_passed
	all_passed = _check("a beat with no group is called out", report.contains("no group name - its spawns join no group"), true) and all_passed
	all_passed = _check("the density block matches Spawns Between: 0-30", report.contains("0-30 s: 7"), true) and all_passed
	all_passed = _check("30-60", report.contains("30-60 s: 2"), true) and all_passed
	all_passed = _check("60-90", report.contains("60-90 s: 1"), true) and all_passed
	all_passed = _check("the density stops at the last beat", report.contains("90-120 s"), false) and all_passed
	all_passed = _check("a note appears in the beat table", report.contains("flankers"), true) and all_passed
	all_passed = _check("and a blank cell reads as (none), not as nothing", report.contains("| (none) | (none)"), true) and all_passed

	var clean: Node = script.new()
	clean.add_entry(1.0, PROBE_SCENE, 1, "solo", "the only beat")
	all_passed = _check("a plan with nothing wrong says so", clean.encounter_report().contains("Every beat reads cleanly."), true) and all_passed
	all_passed = _check("an empty plan still reports one density bucket", clean.encounter_report().contains("0-30 s: 1"), true) and all_passed

	# --- Writing it out, with plain file access and no editor ---
	timeline.write_report(REPORT_PATH)
	all_passed = _check("the report file was written", FileAccess.file_exists(REPORT_PATH), true) and all_passed
	all_passed = _check("its contents are the report itself", FileAccess.get_file_as_string(REPORT_PATH), report) and all_passed

	# --- The save seam: the plan and the cursor travel together ---
	var mid_run: Node = script.new()
	mid_run.load_encounter(plan)
	mid_run.start_encounter()
	mid_run.advance(6.0)
	var restored: Node = script.new()
	restored.load_state(mid_run.save_state())
	all_passed = _check("the restored plan has every beat", restored.entry_count(), 4) and all_passed
	all_passed = _check("the restored clock is where the save was", restored.elapsed_seconds(), 6.0) and all_passed
	all_passed = _check("the restored cursor is on the next unplayed beat", restored.next_entry_seconds(), 20.0) and all_passed
	all_passed = _check("a save mid-wave reopens mid-wave", restored.is_running(), true) and all_passed
	all_passed = _check("the spawn tally travels with the save", restored.spawned_count(), 3) and all_passed
	restored.advance(20.0)
	all_passed = _check("and the beat it had not played (which spawns nothing) leaves the tally alone", restored.spawned_count(), 3) and all_passed
	restored.advance(20.0)
	all_passed = _check("while the beat after that spawns for real", restored.spawned_count(), 5) and all_passed

	all_passed = _check("the Encounter Timeline guide ships", FileAccess.file_exists("res://docs/Addons/Encounter-Timeline.md"), true) and all_passed

	_forget_probe_files()
	restored.free()
	mid_run.free()
	clean.free()
	half_pooled.free()
	half_pool.free()
	pooled.free()
	pool.free()
	director.free()
	caught_up.free()
	timeline.free()
	return all_passed


## A one-node scene on disk, so the plain-instantiate path is exercised for real rather than mocked.
static func _write_probe_scene() -> int:
	var probe: Node = Node.new()
	probe.name = "EncounterProbe"
	var packed: PackedScene = PackedScene.new()
	packed.pack(probe)
	var result: int = ResourceSaver.save(packed, PROBE_SCENE)
	probe.free()
	return result


## Leaves user:// as it was found, so neither file can colour a later run.
static func _forget_probe_files() -> void:
	for path: String in [PROBE_SCENE, REPORT_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] encounter_timeline_pack_test: %s" % label)
		return true
	print("[FAIL] encounter_timeline_pack_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
