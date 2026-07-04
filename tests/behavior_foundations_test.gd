# EventForge - Behavior foundations: host accessor + real signal-trigger codegen
#
# Two unlocks for eventsheet-authored Behaviors:
# 1. behavior_mode sheets compile to attachable Node components with a typed `host`
#    accessor (the parent node), bound in _enter_tree with an attach-time warning.
# 2. Signal-backed triggers now actually CONNECT: `_ready` gets
#    `<source>.<signal>.connect(<handler>)` lines (self and other nodes; custom
#    "signal:<name>" triggers use their baked trigger_args signature).
@tool
class_name BehaviorFoundationsTest
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


static func run() -> bool:
	var all_passed: bool = true

	# Behavior sheet: extends Node, typed host accessor, attach-time guard, triggers intact.
	var behavior_sheet: EventSheetResource = EventSheetResource.new()
	behavior_sheet.behavior_mode = true
	behavior_sheet.host_class = "CharacterBody2D"
	behavior_sheet.custom_class_name = "PatrolBehavior"
	var tick_event: EventRow = EventRow.new()
	tick_event.trigger_provider_id = "Core"
	tick_event.trigger_id = "OnProcess"
	tick_event.actions.append(_action("host.move_and_slide()"))
	behavior_sheet.events.append(tick_event)
	var behavior_output: String = str(SheetCompiler.compile(behavior_sheet, "user://eventforge_behavior.gd").get("output", ""))
	all_passed = _check("behavior compiles as a Node component", behavior_output.contains("extends Node"), true) and all_passed
	all_passed = _check("typed host accessor emitted", behavior_output.contains("var host: CharacterBody2D = null"), true) and all_passed
	all_passed = _check("host binds in _enter_tree", behavior_output.contains("host = get_parent() as CharacterBody2D"), true) and all_passed
	all_passed = _check("attach-time warning names the behavior", behavior_output.contains("PatrolBehavior behavior requires a CharacterBody2D parent."), true) and all_passed
	all_passed = _check("behavior actions act on the host", behavior_output.contains("host.move_and_slide()"), true) and all_passed

	# Lint understands behavior context: host.<member> resolves.
	var lint_result: Dictionary = EventSheetGDScriptLint.lint("host.velocity.x = 0.0\nhost.move_and_slide()", true, behavior_sheet)
	all_passed = _check("lint accepts host-member statements in behavior mode", bool(lint_result.get("ok", false)), true) and all_passed

	# Signal-backed triggers connect: self signal with an existing _ready group. The host
	# class must actually HAVE the signal (Area2D has body_entered).
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Area2D"
	var ready_event: EventRow = EventRow.new()
	ready_event.trigger_provider_id = "Core"
	ready_event.trigger_id = "OnReady"
	ready_event.actions.append(_action("setup()"))
	sheet.events.append(ready_event)
	var body_event: EventRow = EventRow.new()
	body_event.trigger_provider_id = "Core"
	body_event.trigger_id = "OnBodyEntered"
	body_event.actions.append(_action("take_damage()"))
	sheet.events.append(body_event)
	var output: String = str(SheetCompiler.compile(sheet, "user://eventforge_signals.gd").get("output", ""))
	all_passed = _check("self-signal connection emitted in _ready",
		output.contains("\tbody_entered.connect(_on_body_entered)"), true) and all_passed
	all_passed = _check("connections run before OnReady logic",
		output.find("body_entered.connect") < output.find("\tsetup()"), true) and all_passed
	all_passed = _check("handler keeps the classic name", output.contains("func _on_body_entered(body: Node) -> void:"), true) and all_passed

	# Compile-time validation: a self-signal the host class lacks is skipped with a warning
	# (emitting it blindly would make the whole generated script fail to parse).
	var invalid_sheet: EventSheetResource = EventSheetResource.new()
	invalid_sheet.host_class = "CharacterBody2D"
	var invalid_event: EventRow = EventRow.new()
	invalid_event.trigger_provider_id = "Core"
	invalid_event.trigger_id = "OnBodyEntered"
	invalid_event.actions.append(_action("take_damage()"))
	invalid_sheet.events.append(invalid_event)
	var invalid_result: Dictionary = SheetCompiler.compile(invalid_sheet, "user://eventforge_invalid_signal.gd")
	all_passed = _check("missing host signal skips the connection",
		str(invalid_result.get("output", "")).contains(".connect("), false) and all_passed
	all_passed = _check("missing host signal records a warning",
		not (invalid_result.get("warnings", []) as Array).is_empty(), true) and all_passed

	# Custom signal trigger ("signal:<name>") on ANOTHER node, with baked args; no OnReady
	# group exists, so _ready is synthesized for the connection.
	var custom_sheet: EventSheetResource = EventSheetResource.new()
	var landed_event: EventRow = EventRow.new()
	landed_event.trigger_provider_id = "PlatformBehavior"
	landed_event.trigger_id = "signal:landed"
	landed_event.trigger_source_path = "Platform"
	landed_event.trigger_args = "impact: float"
	landed_event.actions.append(_action("shake_camera()"))
	custom_sheet.events.append(landed_event)
	var custom_output: String = str(SheetCompiler.compile(custom_sheet, "user://eventforge_custom_signal.gd").get("output", ""))
	all_passed = _check("_ready synthesized for connections",
		custom_output.contains("func _ready() -> void:\n\tget_node(\"Platform\").landed.connect(_on_platform_landed)"), true) and all_passed
	all_passed = _check("source-aware handler with baked args",
		custom_output.contains("func _on_platform_landed(impact: float) -> void:"), true) and all_passed

	# Dock bake: applying a TRIGGER definition sets trigger id + args on the event (this is
	# also what makes picker-created trigger events compile at all).
	var editor: EventSheetEditor = EventSheetEditor.new()
	var dock_sheet: EventSheetResource = EventSheetResource.new()
	# Declare the custom signal in a class-level GDScript block so the self-connection
	# validates (the realistic authoring pattern for script-declared signals).
	var signal_block: RawCodeRow = RawCodeRow.new()
	signal_block.code = "signal healed(amount: int)"
	dock_sheet.events.append(signal_block)
	editor.setup(dock_sheet)
	editor.set_undo_redo_manager(NoopUndoManager.new())
	var trigger_definition: ACEDefinition = ACEDefinition.new()
	trigger_definition.provider_id = "DemoHealthAddon"
	trigger_definition.id = "signal:healed"
	trigger_definition.ace_type = ACEDefinition.ACEType.TRIGGER
	trigger_definition.parameters = [{"id": "amount", "type": TYPE_INT}]
	editor._apply_ace_definition(trigger_definition, {}, {"mode": "new_condition_event"})
	var created: EventRow = dock_sheet.events[dock_sheet.events.size() - 1] as EventRow
	all_passed = _check("apply bakes trigger id", created != null and created.trigger_id == "signal:healed", true) and all_passed
	all_passed = _check("apply bakes trigger args", created != null and created.trigger_args == "amount: int", true) and all_passed
	var baked_output: String = str(SheetCompiler.compile(dock_sheet, "user://eventforge_baked_trigger.gd").get("output", ""))
	all_passed = _check("picker-created custom trigger compiles + connects",
		baked_output.contains("healed.connect(_on_healed)") and baked_output.contains("func _on_healed(amount: int) -> void:"), true) and all_passed
	editor.free()

	return all_passed


static func _action(template: String) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Test"
	action.ace_id = template
	action.codegen_template = template
	return action


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] behavior_foundations_test: %s" % label)
		return true
	print("[FAIL] behavior_foundations_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
