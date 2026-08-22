@tool
extends SceneTree

const SOURCE_PATH := "user://zz_bench_repro_subject.gd"
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


func _init() -> void:
	var file: FileAccess = FileAccess.open(SOURCE_PATH, FileAccess.WRITE)
	file.store_string(SUBJECT)
	file.close()
	print("=== BUILD TEST BENCH (FIRST, nothing warmed) ===")
	_build_bench()
	print("=== AFTER BENCH ===")
	_report()
	print("=== AFTER RESCAN ===")
	_rescan()
	_report()
	quit(0)


func _build_bench() -> void:
	var editor: EventSheetEditor = EventSheetEditor.new()
	var pack: EventSheetResource = EventSheetResource.new()
	pack.behavior_mode = true
	pack.host_class = "Node2D"
	pack.custom_class_name = "ZzBenchKit"
	var tick: EventRow = EventRow.new()
	tick.trigger_provider_id = "Core"
	tick.trigger_id = "OnProcess"
	var raw: RawCodeRow = RawCodeRow.new()
	raw.code = "pass"
	tick.actions.append(raw)
	pack.events.append(tick)
	editor.setup(pack)
	editor.set_undo_redo_manager(NoopUndoManager.new())
	var problem: String = editor._build_test_bench(pack, "user://zz_bench.tscn")
	print("  bench problem: '%s'" % problem)
	editor.free()


func _rescan() -> void:
	var editor: EventSheetEditor = EventSheetEditor.new()
	editor.setup(EventSheetResource.new())
	editor.set_undo_redo_manager(NoopUndoManager.new())
	editor._build_addon_ace_sources()
	editor.free()


func _report() -> void:
	print("  ACERegistry.get_all_descriptors(): %d" % ACERegistry.get_all_descriptors().size())
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(SOURCE_PATH)
	var triggers: int = 0
	var raws: int = 0
	for row: Variant in sheet.events:
		if row is EventRow and (row as EventRow).trigger_id == "OnPhysicsProcess":
			triggers += 1
		elif row is RawCodeRow and (row as RawCodeRow).code.contains("_physics_process"):
			raws += 1
	print("  OnPhysicsProcess events: %d, verbatim _physics_process blocks: %d" % [triggers, raws])
