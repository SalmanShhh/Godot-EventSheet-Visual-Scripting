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
	"res://eventsheet_addons/eight_direction/eight_direction_movement_behavior",
	"res://eventsheet_addons/timer/timer_behavior",
	"res://eventsheet_addons/flash/flash_behavior",
	"res://eventsheet_addons/state_machine/state_machine_behavior",
	"res://eventsheet_addons/sine/sine_behavior",
	"res://eventsheet_addons/orbit/orbit_behavior",
	"res://eventsheet_addons/bullet/bullet_behavior",
	"res://eventsheet_addons/move_to/move_to_behavior",
	"res://eventsheet_addons/follow/follow_behavior",
	"res://eventsheet_addons/drag_drop/drag_drop_behavior",
	"res://eventsheet_addons/car/car_behavior",
	"res://eventsheet_addons/tile_movement/tile_movement_behavior",
	"res://eventsheet_addons/line_of_sight/line_of_sight_behavior",
	"res://eventsheet_addons/line_of_sight_3d/line_of_sight_3d_behavior",
	"res://eventsheet_addons/sine_3d/sine_3d_behavior",
	"res://eventsheet_addons/orbit_3d/orbit_3d_behavior",
	"res://eventsheet_addons/bullet_3d/bullet_3d_behavior",
	"res://eventsheet_addons/move_to_3d/move_to_3d_behavior",
	"res://eventsheet_addons/health/health_behavior",
	"res://eventsheet_addons/virtual_cursor/virtual_cursor_behavior",
	"res://eventsheet_addons/weapon_kit/weapon_kit_behavior",
	"res://eventsheet_addons/htn_agent/htn_agent_behavior",
	"res://eventsheet_addons/abilities/abilities_behavior"
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
	# New packs: Timer/Flash actions, the On Timer trigger, and the state-machine CONDITION
	# authored as an annotated class-level block (with its own codegen template).
	var start_timer: ACEDefinition = editor._ace_registry.find_definition("TimerBehavior", "method:start_timer")
	var on_timer: ACEDefinition = editor._ace_registry.find_definition("TimerBehavior", "signal:timer_finished")
	var flash_action: ACEDefinition = editor._ace_registry.find_definition("FlashBehavior", "method:flash")
	var is_in_state: ACEDefinition = editor._ace_registry.find_definition("StateMachineBehavior", "method:is_in_state")
	all_passed = _check("Timer pack publishes Start Timer", start_timer != null, true) and all_passed
	all_passed = _check("Timer pack publishes the On Timer trigger",
		on_timer != null and on_timer.display_name == "On Timer", true) and all_passed
	all_passed = _check("Flash pack publishes Flash", flash_action != null, true) and all_passed
	all_passed = _check("state machine block-condition publishes with its template",
		is_in_state != null and str(is_in_state.metadata.get("codegen_template", "")) == "$StateMachineBehavior.state == {state_name}", true) and all_passed
	all_passed = _check("block condition is typed as a condition",
		is_in_state != null and is_in_state.ace_type == ACEDefinition.ACEType.CONDITION, true) and all_passed
	# Abilities pack: an action, a trigger, a condition (with its template), and the
	# CurrentAbilityID expression (the Godot-suited reader the C3 original lacked).
	var ab_activate: ACEDefinition = editor._ace_registry.find_definition("SimpleAbilitiesBehavior", "method:activate_ability")
	var ab_on_activated: ACEDefinition = editor._ace_registry.find_definition("SimpleAbilitiesBehavior", "signal:on_ability_activated")
	var ab_is_ready: ACEDefinition = editor._ace_registry.find_definition("SimpleAbilitiesBehavior", "method:is_ready")
	var ab_current: ACEDefinition = editor._ace_registry.find_definition("SimpleAbilitiesBehavior", "method:current_ability")
	all_passed = _check("abilities pack publishes Activate Ability",
		ab_activate != null and ab_activate.category == "Abilities", true) and all_passed
	all_passed = _check("abilities pack publishes the On Ability Activated trigger",
		ab_on_activated != null and ab_on_activated.display_name == "On Ability Activated", true) and all_passed
	all_passed = _check("abilities Is Ready is a condition with its template",
		ab_is_ready != null and ab_is_ready.ace_type == ACEDefinition.ACEType.CONDITION and str(ab_is_ready.metadata.get("codegen_template", "")) == "$SimpleAbilitiesBehavior.is_ready({id})", true) and all_passed
	all_passed = _check("abilities Current Ability ID is an expression",
		ab_current != null and ab_current.ace_type == ACEDefinition.ACEType.EXPRESSION, true) and all_passed
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
