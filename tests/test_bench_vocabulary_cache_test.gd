# Building the Test Bench must leave the ACE vocabulary usable for the next file opened as a sheet.
#
# The Test Bench build is the first thing in a session that drives the whole author loop at once:
# it compiles the sheet, loads the emitted script and packs a scene, and on the way it forces the
# lazily-built vocabulary caches (the built-in descriptor cache, its definition mirror, the pack
# block kinds) into existence. A cache that came back from that build EMPTY while still counting
# as built would not rebuild on the next question, and the open path would then recognise no
# templates at all. Measured against a deliberately emptied vocabulary, that is what the failure
# looks like: a `_physics_process` that reads as three separate physics-tick events collapses to a
# SINGLE event still carrying its whole body as unconverted code, with nothing in the log to say why.
#
# So this pins the pair, in order, in one process: build the bench cold (the vocabulary cleared
# first, so the bench really is what fills it), then open a script and require the three trigger
# rows. Trigger IDS are pinned rather than a row count, so a lift that produces three rows of the
# wrong kind fails here too, and the body is checked for leftover code rows because the collapsed
# shape keeps its lines rather than dropping them.
@tool
class_name TestBenchVocabularyCacheTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const BENCH_SCENE_PATH := "user://eventsheets_vocab_bench.tscn"
const SUBJECT_PATH := "user://eventsheets_vocab_subject.gd"

## Three top-level `if` blocks in one lifecycle function: each lifts to its own physics-tick event.
const SUBJECT := """extends CharacterBody2D

var hp: int = 100
var score: int = 0


func _physics_process(delta: float) -> void:
	if hp > 0:
		score += 1
	if hp < 20:
		hp = 100
	if score > 50:
		score = 0
"""


class NoopUndoManager:
	extends RefCounted
	func create_action(_a = null) -> void: pass
	func add_do_method(_a = null, _b = null, _c = null, _d = null, _e = null) -> void: pass
	func add_undo_method(_a = null, _b = null, _c = null, _d = null, _e = null) -> void: pass
	func commit_action() -> void: pass
	func has_undo() -> bool: return false
	func has_redo() -> bool: return false
	func undo() -> void: pass
	func redo() -> void: pass
	func clear_history() -> void: pass


static func run() -> bool:
	var all_passed: bool = true
	var file: FileAccess = FileAccess.open(SUBJECT_PATH, FileAccess.WRITE)
	file.store_string(SUBJECT)
	file.close()

	# Cold start: drop the built-in descriptor cache so the bench build below is what fills it.
	# The suite has almost certainly warmed it by now, and a warm cache would hide exactly the
	# staleness this test exists to catch.
	ACERegistry.clear_cache()

	# Step 1 - the real Test Bench build path (host of host_class + the compiled behavior child).
	var editor: EventSheetEditor = EventSheetEditor.new()
	var pack: EventSheetResource = EventSheetResource.new()
	pack.behavior_mode = true
	pack.host_class = "Node2D"
	pack.custom_class_name = "VocabBenchKit"
	var tick: EventRow = EventRow.new()
	tick.trigger_provider_id = "Core"
	tick.trigger_id = "OnProcess"
	var tick_body: RawCodeRow = RawCodeRow.new()
	tick_body.code = "pass"
	tick.actions.append(tick_body)
	pack.events.append(tick)
	editor.setup(pack)
	editor.set_undo_redo_manager(NoopUndoManager.new())
	all_passed = _check("test bench builds", editor._build_test_bench(pack, BENCH_SCENE_PATH), "") and all_passed

	# The direct symptom: a vocabulary that came back empty from the build would still count as
	# built, so nothing would ever rebuild it.
	all_passed = _check("the vocabulary survives the bench build",
		ACERegistry.get_all_descriptors().is_empty(), false) and all_passed
	all_passed = _check("the built-in lookup index survives with it",
		ACERegistry.find_descriptor("Core", "OnPhysicsProcess") != null, true) and all_passed

	# Step 2 - the next script opened as a sheet still converts into editor rows.
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(SUBJECT_PATH)
	all_passed = _check("the subject opens as a sheet", sheet != null, true) and all_passed
	all_passed = _check("its physics tick reads as three trigger events, not one code block",
		_trigger_ids(sheet), "OnPhysicsProcess, OnPhysicsProcess, OnPhysicsProcess") and all_passed
	all_passed = _check("no part of the tick body stays as unconverted code",
		_unlifted_action_count(sheet), 0) and all_passed

	editor.free()
	return all_passed


## The trigger id of every event row in the sheet, in order, as one comparable string.
static func _trigger_ids(sheet: EventSheetResource) -> String:
	var ids: PackedStringArray = PackedStringArray()
	for row: Variant in (sheet.events if sheet != null else []):
		if row is EventRow:
			ids.append((row as EventRow).trigger_id)
	return ", ".join(ids)


## Action rows that kept their line as unconverted GDScript. A vocabulary that recognises the
## templates lifts all three bodies to real action rows and leaves none of these behind; an empty
## one folds the whole tick into a single event carrying its body verbatim.
static func _unlifted_action_count(sheet: EventSheetResource) -> int:
	var count: int = 0
	for row: Variant in (sheet.events if sheet != null else []):
		if not (row is EventRow):
			continue
		for action: Variant in (row as EventRow).actions:
			if action is RawCodeRow:
				count += 1
	return count


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("test_bench_vocabulary_cache_test", label, actual, expected)
