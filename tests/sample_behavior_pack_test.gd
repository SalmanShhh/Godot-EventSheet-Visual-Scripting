# EventForge — Sample behavior packs (Platformer / Eight-Direction)
#
# The shipped packs are behavior sheets (.tres sources) plus their compiled scripts in
# res://eventsheet_addons/, where the zero-config scanner publishes their ACEs. Guards:
# the committed script never drifts from its sheet (recompile == file), the scripts load
# as real classes (GDScript interop), and the published ACEs resolve with their templates.
@tool
extends RefCounted
class_name SampleBehaviorPackTest

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

const PACKS: Array[String] = [
	"res://eventsheet_addons/platformer_movement/platformer_movement_behavior",
	"res://eventsheet_addons/eight_direction/eight_direction_movement_behavior"
]

static func run() -> bool:
	var all_passed: bool = true

	for base_path in PACKS:
		var pack_name: String = base_path.get_file()
		var sheet: EventSheetResource = load(base_path + ".tres") as EventSheetResource
		all_passed = _check("%s sheet loads as a behavior" % pack_name, sheet != null and sheet.behavior_mode, true) and all_passed
		if sheet == null:
			continue
		# No-drift golden: the committed script is exactly what the sheet compiles to.
		var recompiled: String = str(SheetCompiler.compile(sheet, "user://%s_drift.gd" % pack_name).get("output", ""))
		var committed: String = FileAccess.get_file_as_string(base_path + ".gd")
		all_passed = _check("%s script matches its sheet (no drift)" % pack_name, recompiled == committed, true) and all_passed
		# GDScript interop: the compiled behavior is a real, instantiable class.
		var script: Script = load(base_path + ".gd")
		all_passed = _check("%s compiled script loads + instantiates" % pack_name, script != null and script.can_instantiate(), true) and all_passed

	# The scanner picks the compiled packs up; their ACEs publish project-wide.
	var scanned: Array[String] = EventSheetAddonScanner.list_addon_scripts()
	all_passed = _check("scanner finds both packs",
		scanned.has(PACKS[0] + ".gd") and scanned.has(PACKS[1] + ".gd"), true) and all_passed

	var editor: EventSheetEditor = EventSheetEditor.new()
	editor.setup(EventSheetResource.new())
	editor.set_undo_redo_manager(NoopUndoManager.new())
	var jump_definition: ACEDefinition = null
	var jumped_trigger: ACEDefinition = null
	for definition in editor._ace_registry.get_all_definitions():
		if definition.provider_id == "PlatformerMovement" and definition.id == "method:jump":
			jump_definition = definition
		elif definition.provider_id == "PlatformerMovement" and definition.id == "signal:jumped":
			jumped_trigger = definition
	all_passed = _check("Jump publishes from the pack", jump_definition != null, true) and all_passed
	if jump_definition != null:
		all_passed = _check("Jump carries the child-node codegen template",
			str(jump_definition.metadata.get("codegen_template", "")), "$PlatformerMovement.jump()") and all_passed
		all_passed = _check("Jump categorized for the picker", jump_definition.category, "Platformer") and all_passed
	all_passed = _check("On Jumped trigger publishes from the block annotation",
		jumped_trigger != null and jumped_trigger.display_name == "On Jumped", true) and all_passed
	editor.free()

	# The movement block lints against the behavior context (host accessor + sheet vars).
	var platformer_sheet: EventSheetResource = load(PACKS[0] + ".tres") as EventSheetResource
	var lint_result: Dictionary = EventSheetGDScriptLint.lint(
		"host.velocity.x = Input.get_axis(\"ui_left\", \"ui_right\") * move_speed", true, platformer_sheet)
	all_passed = _check("pack code lints in behavior context", bool(lint_result.get("ok", false)), true) and all_passed

	return all_passed

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] sample_behavior_pack_test: %s" % label)
		return true
	print("[FAIL] sample_behavior_pack_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
