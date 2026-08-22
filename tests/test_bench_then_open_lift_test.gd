# EventForge - compiler scratch state never leaks across emission entry points. A behaviour compile
# (the Test Bench, a pack build) sets the {host.} prefix to "host" for its own emission; the lifter's
# per-function byte gate then runs through emit_anchored_trigger_text / emit_function_block_text,
# which live OUTSIDE a compile. Those fragments used to inherit the stale prefix, regenerate
# `host.move_and_slide()` against a file that says `move_and_slide()`, and keep the whole
# _physics_process as one verbatim block - repaired only by the next compile of anything (a provider
# rescan, a second open). Every entry point now starts from its sheet's own scratch state.
@tool
class_name TestBenchThenOpenLiftTest
extends RefCounted


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


const HOST_SCRIPT_PATH := "user://test_bench_then_open_host.gd"
const BENCH_SCENE_PATH := "user://test_bench_then_open_bench.tscn"

## A plain game script: a velocity line, a jump branch on is_on_floor(), move_and_slide(), and one
## helper. _physics_process lifts to three OnPhysicsProcess events, so the file opens as four rows
## (the `extends` line plus the three events; the helper lifts to a sheet function).
const PHYSICS_FUNCTION := "func _physics_process(delta: float) -> void:
	velocity.y += 980.0 * delta
	if Input.is_action_just_pressed(\"jump\") and is_on_floor():
		velocity.y = -400.0
	move_and_slide()"
const HOST_SOURCE := "extends CharacterBody2D

" + PHYSICS_FUNCTION + "


func _on_hit(damage: int) -> void:
	print(damage)
"
const LIFTED_ROW_COUNT := 4
const LIFTED_TRIGGERS := "OnPhysicsProcess,OnPhysicsProcess,OnPhysicsProcess"


static func run() -> bool:
	var all_passed: bool = true
	var host_file: FileAccess = FileAccess.open(HOST_SCRIPT_PATH, FileAccess.WRITE)
	host_file.store_string(HOST_SOURCE)
	host_file.close()

	var before: EventSheetResource = GDScriptImporter.new().import_external(HOST_SCRIPT_PATH)
	all_passed = _check("the game script opens with _physics_process lifted (baseline)",
		before.events.size(), LIFTED_ROW_COUNT) and all_passed
	all_passed = _check("baseline trigger ids", _trigger_ids(before), LIFTED_TRIGGERS) and all_passed

	# The same Test Bench the author tools build: a behaviour pack with a class_name, an exported
	# variable, an exposed function and an annotated signal, compiled + packed into a host scene.
	var author_editor: EventSheetEditor = EventSheetEditor.new()
	var pack: EventSheetResource = _build_pack()
	author_editor.setup(pack)
	author_editor.set_undo_redo_manager(NoopUndoManager.new())
	var bench_problem: String = author_editor._build_test_bench(pack, BENCH_SCENE_PATH)
	all_passed = _check("the Test Bench builds", bench_problem, "") and all_passed

	var after: EventSheetResource = GDScriptImporter.new().import_external(HOST_SCRIPT_PATH)
	all_passed = _check("the next open after the bench still lifts _physics_process",
		after.events.size(), LIFTED_ROW_COUNT) and all_passed
	all_passed = _check("the next open keeps all three trigger events", _trigger_ids(after), LIFTED_TRIGGERS) and all_passed

	# The mechanism, pinned on its own: right after a behaviour compile the anchored-trigger emitter
	# still reproduces the file's bytes (no "host." prefix on the node-scoped calls).
	var bench_script_path: String = BENCH_SCENE_PATH.get_basename() + ".gd"
	SheetCompiler.compile(pack, bench_script_path)
	var fragment: String = SheetCompiler.emit_anchored_trigger_text(after.events.slice(1))
	all_passed = _check("an anchored trigger emitted right after a behaviour compile matches the file",
		fragment, PHYSICS_FUNCTION) and all_passed
	var helper: EventFunction = after.functions[0] if not after.functions.is_empty() else null
	all_passed = _check("the helper lifted to a sheet function",
		helper != null and helper.function_name == "_on_hit", true) and all_passed
	if helper != null:
		SheetCompiler.compile(pack, bench_script_path)
		all_passed = _check("a function block emitted right after a behaviour compile carries no host prefix",
			SheetCompiler.emit_function_block_text(helper, after).contains("host."), false) and all_passed

	author_editor.free()
	DirAccess.remove_absolute(HOST_SCRIPT_PATH)
	DirAccess.remove_absolute(BENCH_SCENE_PATH)
	DirAccess.remove_absolute(bench_script_path)
	return all_passed


static func _build_pack() -> EventSheetResource:
	var pack: EventSheetResource = EventSheetResource.new()
	pack.behavior_mode = true
	pack.host_class = "Node2D"
	pack.custom_class_name = "JuiceKit"
	pack.addon_tags = PackedStringArray(["juice"])
	pack.variables = {"strength": {"type": "float", "default": 1.0, "exported": true, "attributes": {"tooltip": "How juicy."}}}
	var kick: EventFunction = EventFunction.new()
	kick.function_name = "kick"
	kick.expose_as_ace = true
	kick.ace_display_name = "Kick"
	kick.ace_category = "Juice"
	var kick_param: ACEParam = ACEParam.new()
	kick_param.id = "amount"
	kick_param.type_name = "float"
	kick.params.append(kick_param)
	var kick_body: RawCodeRow = RawCodeRow.new()
	kick_body.code = "pass"
	kick.events.append(kick_body)
	pack.functions.append(kick)
	var kit_signal: RawCodeRow = RawCodeRow.new()
	kit_signal.code = "## @ace_trigger
## @ace_name(\"On Kicked\")
signal kicked"
	pack.events.append(kit_signal)
	return pack


## The trigger id of every event row, joined - a raw block contributes nothing, so a function that
## fell back to verbatim code shows up as a shorter list, never as a count that happens to match.
static func _trigger_ids(sheet: EventSheetResource) -> String:
	var ids: PackedStringArray = PackedStringArray()
	for row: Variant in sheet.events:
		if row is EventRow:
			ids.append(str((row as EventRow).trigger_id))
	return ",".join(ids)


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] test_bench_then_open_lift_test: %s" % label)
		return true
	print("[FAIL] test_bench_then_open_lift_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
