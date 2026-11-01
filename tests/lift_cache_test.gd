# Godot EventSheets - the lifted sheet of an unchanged .gd is remembered, and only ever believed.
#
# The lift of the 3,580-line pathfinding pack takes 9 s and is a pure function of the file's text and
# of the code and vocabulary that read it, so lift_cache.gd keeps the answer in `.godot/`. This holds
# the three promises that make that safe:
#   * IT SAVES THE WORK: a second open of an unchanged file never starts a lift;
#   * IT NEVER SERVES STALE: one byte changed, a bumped compiler version, an edited lifter script or a
#     different vocabulary each force a fresh lift;
#   * IT NEVER SERVES WRONG: a corrupt or foreign entry is ignored, and an entry that does not
#     re-emit the source byte for byte is discarded and the file lifted fresh.
# Plus a wall budget on the remembered stage (measured on the 346-row sample; see the changelog for
# the pathfinding pack figure). The folder is pointed at user:// so a run writes nothing in the project.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := "lift_cache_test"
const CACHE_SCRIPT: String = "res://addons/eventforge/importer/lift_cache.gd"
const SAMPLE_PACK: String = "res://eventsheet_addons/fps_controller/fps_controller_behavior.gd"
const FOLDER: String = "user://lift_cache_test/"
const FIXTURE: String = "user://lift_cache_fixture.gd"
const FIXTURE_SOURCE: String = """extends Node2D

var speed: float = 120.0


func _ready() -> void:
	position = Vector2(10, 20)
	set_process(true)


## Moves the sprite one step.
func step(amount: float) -> void:
	position.x += amount
"""
## Reading an entry back is a binary load plus the byte check (one compile of the sheet). Measured
## 174 ms on the sample pack in the suite; set at about 3x.
const REMEMBERED_STAGE_BUDGET_MS: float = 600.0


static func run() -> bool:
	var cache: Script = load(CACHE_SCRIPT)
	var passed: bool = true
	var saved_dir: String = cache.cache_dir
	var was_enabled: bool = cache.enabled
	cache.cache_dir = FOLDER
	cache.enabled = true
	cache.clear()
	_write(FIXTURE, FIXTURE_SOURCE)

	# 1. The first open lifts and remembers; the second never lifts.
	var before: int = EventSheetACELifter.lift_attempts
	var first: EventSheetResource = _open(FIXTURE)
	passed = SUPPORT.check(P, "the first open lifts", EventSheetACELifter.lift_attempts > before, true) and passed
	passed = SUPPORT.check(P, "the first open leaves an entry", FileAccess.file_exists(cache.entry_path_for(FIXTURE)), true) and passed
	before = EventSheetACELifter.lift_attempts
	var hits_before: int = cache.hits
	var second: EventSheetResource = _open(FIXTURE)
	passed = SUPPORT.check(P, "the second open of an unchanged file never lifts", EventSheetACELifter.lift_attempts, before) and passed
	passed = SUPPORT.check(P, "the second open was served from the entry", cache.hits, hits_before + 1) and passed
	passed = SUPPORT.check(P, "the remembered sheet re-emits the source byte for byte",
		str(SheetCompiler.echo(second, true).get("output", "")), FIXTURE_SOURCE) and passed
	passed = SUPPORT.check(P, "and says what a fresh lift said (functions)", second.functions.size(), first.functions.size()) and passed
	passed = SUPPORT.check(P, "and knows its file", second.external_source_path, FIXTURE) and passed

	# 2. One byte changed outside the editor: lifted again, and the new text is what comes back.
	var changed: String = FIXTURE_SOURCE + "# one more byte\n"
	_write(FIXTURE, changed)
	before = EventSheetACELifter.lift_attempts
	var third: EventSheetResource = _open(FIXTURE)
	passed = SUPPORT.check(P, "one changed byte forces a fresh lift", EventSheetACELifter.lift_attempts > before, true) and passed
	passed = SUPPORT.check(P, "and the new text is what re-emits",
		str(SheetCompiler.echo(third, true).get("output", "")), changed) and passed

	# 3. A bumped compiler version, an edited lifter script, a different vocabulary: each is part of
	# the key, so an entry written under another one is a miss.
	var key: String = cache.key_for(changed)
	passed = SUPPORT.check(P, "the key carries the compiler version", key.contains("|%s|" % SheetCompiler.VERSION), true) and passed
	passed = SUPPORT.check(P, "the key carries the vocabulary size", key.contains("|%d|" % ACERegistry.descriptor_count()), true) and passed
	passed = SUPPORT.check(P, "the key carries the code stamp", key.ends_with("|" + cache.code_stamp_now()), true) and passed
	var stamped: PackedStringArray = PackedStringArray()
	cache._collect_scripts("res://addons/eventforge/", stamped)
	passed = SUPPORT.check(P, "the stamp reads the lifter's own script", stamped.has("res://addons/eventforge/importer/ace_lifter.gd"), true) and passed
	passed = SUPPORT.check(P, "the stamp reads the importer", stamped.has("res://addons/eventforge/importer/gdscript_importer.gd"), true) and passed
	var packs: PackedStringArray = PackedStringArray()
	cache._collect_scripts("res://eventsheet_addons/", packs)
	passed = SUPPORT.check(P, "the stamp reads the packs that add vocabulary", packs.is_empty(), false) and passed
	passed = SUPPORT.check(P, "a different set of files is a different stamp",
		cache.stamp_of(PackedStringArray([SAMPLE_PACK])) == cache.stamp_of(PackedStringArray([SAMPLE_PACK, FIXTURE])), false) and passed
	var swaps: Dictionary = {
		"a bumped compiler version": ["|%s|" % SheetCompiler.VERSION, "|0.0.0-other|"],
		"a different vocabulary": ["|%d|" % ACERegistry.descriptor_count(), "|%d|" % (ACERegistry.descriptor_count() + 1)],
		"an edited lifter": ["|" + cache.code_stamp_now(), "|edited"],
	}
	for label: String in swaps.keys():
		_rekey(FIXTURE, cache, str(swaps[label][0]), str(swaps[label][1]))
		before = EventSheetACELifter.lift_attempts
		_open(FIXTURE)
		passed = SUPPORT.check(P, "%s forces a fresh lift" % label, EventSheetACELifter.lift_attempts > before, true) and passed

	# 4. A corrupted or foreign entry is ignored safely.
	_write(cache.entry_path_for(FIXTURE), "this is not a resource")
	before = EventSheetACELifter.lift_attempts
	var after_corrupt: EventSheetResource = _open(FIXTURE)
	passed = SUPPORT.check(P, "a corrupt entry is ignored and the file lifted", EventSheetACELifter.lift_attempts > before, true) and passed
	passed = SUPPORT.check(P, "and the sheet is right", str(SheetCompiler.echo(after_corrupt, true).get("output", "")), changed) and passed
	var foreign: Resource = Resource.new()
	ResourceSaver.save(foreign, cache.entry_path_for(FIXTURE))
	before = EventSheetACELifter.lift_attempts
	_open(FIXTURE)
	passed = SUPPORT.check(P, "a foreign resource in its place is ignored", EventSheetACELifter.lift_attempts > before, true) and passed
	var keyless: EventSheetResource = EventSheetResource.new()
	ResourceSaver.save(keyless, cache.entry_path_for(FIXTURE))
	before = EventSheetACELifter.lift_attempts
	_open(FIXTURE)
	passed = SUPPORT.check(P, "a sheet with no key in its place is ignored", EventSheetACELifter.lift_attempts > before, true) and passed

	# 5. THE BINDING CHECK: an entry with the right key that does not re-emit the source is thrown
	# away, and the file is lifted fresh.
	var impostor_source: String = FIXTURE_SOURCE.replace("120.0", "999.0")
	var impostor: EventSheetResource = GDScriptImporter.new().import_external_source(impostor_source, true, FIXTURE)
	impostor.set_meta(cache.META_KEY, cache.key_for(changed))
	ResourceSaver.save(impostor, cache.entry_path_for(FIXTURE))
	before = EventSheetACELifter.lift_attempts
	var discarded_before: int = cache.discarded
	var rescued: EventSheetResource = _open(FIXTURE)
	passed = SUPPORT.check(P, "a remembered sheet that does not re-emit the source is discarded", cache.discarded, discarded_before + 1) and passed
	passed = SUPPORT.check(P, "and the file is lifted fresh", EventSheetACELifter.lift_attempts > before, true) and passed
	passed = SUPPORT.check(P, "and the answer is the file's own text",
		str(SheetCompiler.echo(rescued, true).get("output", "")), changed) and passed

	# 6. Off means off.
	cache.clear()
	cache.enabled = false
	_open(FIXTURE)
	passed = SUPPORT.check(P, "with the cache off nothing is written", FileAccess.file_exists(cache.entry_path_for(FIXTURE)), false) and passed
	cache.enabled = true

	# 7. The wall budget on the remembered stage, on a real pack.
	cache.clear()
	var pack_source: String = FileAccess.get_file_as_string(SAMPLE_PACK)
	_open(SAMPLE_PACK)
	before = EventSheetACELifter.lift_attempts
	var start_usec: int = Time.get_ticks_usec()
	var remembered: EventSheetResource = cache.fetch(SAMPLE_PACK, pack_source)
	var elapsed_ms: float = float(Time.get_ticks_usec() - start_usec) / 1000.0
	passed = SUPPORT.check(P, "the sample pack is served from its entry", remembered == null, false) and passed
	passed = SUPPORT.check(P, "serving it starts no lift", EventSheetACELifter.lift_attempts, before) and passed
	passed = SUPPORT.check(P, "the remembered stage costs under %.0f ms (took %.1f ms)" % [REMEMBERED_STAGE_BUDGET_MS, elapsed_ms],
		elapsed_ms <= REMEMBERED_STAGE_BUDGET_MS, true) and passed

	cache.clear()
	cache.cache_dir = saved_dir
	cache.enabled = was_enabled
	return passed


static func _open(path: String) -> EventSheetResource:
	var job: EventSheetOpenJob = EventSheetOpenJob.new()
	job.start(path)
	return job.finish()


static func _write(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


## Rewrites the key an entry was stored under, as if the world it was lifted in had changed.
static func _rekey(path: String, cache: Script, from_text: String, to_text: String) -> void:
	var entry_path: String = cache.entry_path_for(path)
	var entry: Resource = ResourceLoader.load(entry_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if entry == null:
		return
	entry.set_meta(cache.META_KEY, str(entry.get_meta(cache.META_KEY, "")).replace(from_text, to_text))
	ResourceSaver.save(entry, entry_path)
