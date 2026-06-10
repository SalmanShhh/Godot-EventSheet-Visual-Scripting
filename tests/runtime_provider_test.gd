# EventForge — Runtime addon bridge + instance-backed addon ACEs
#
# Two halves of the "addon ACEs work everywhere" story:
# 1. EventForgeBridge.register_script_as_provider — code-registered provider scripts join
#    the picker vocabulary exactly like eventsheet_addons/ scans (for other plugins/tools).
# 2. Instance-backed ACEs — addon METHODS without @ace_codegen_template bake a
#    per-provider member call; the compiler declares each used provider ONCE as a plain
#    owned instance. Output stays free of EventForge classes (parity contract).
@tool
extends RefCounted
class_name RuntimeProviderTest

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

	# Bridge registration: static API, deduped, picked up by the dock's source builder.
	EventForgeBridgeRuntime.register_provider_script("res://tests/fixtures/runtime_provider_fixture.gd")
	EventForgeBridgeRuntime.register_provider_script("res://tests/fixtures/runtime_provider_fixture.gd")
	all_passed = _check("bridge registration is deduped",
		EventForgeBridgeRuntime.get_registered_provider_scripts().count("res://tests/fixtures/runtime_provider_fixture.gd"), 1) and all_passed
	var editor: EventSheetEditor = EventSheetEditor.new()
	editor.setup(EventSheetResource.new())
	editor.set_undo_redo_manager(NoopUndoManager.new())
	var fixture_definition: ACEDefinition = editor._ace_registry.find_definition("RuntimeProviderFixture", "method:emit_pulse")
	all_passed = _check("code-registered provider publishes its ACEs", fixture_definition != null, true) and all_passed

	# Instance-backed baking: the demo addon's template-less method bakes a member call.
	var announce_definition: ACEDefinition = editor._ace_registry.find_definition("DemoHealthAddon", "method:announce_heal")
	all_passed = _check("template-less addon method publishes", announce_definition != null, true) and all_passed
	if announce_definition != null:
		var baked_action: ACEAction = editor._create_action_from_definition(announce_definition, {"amount": 7})
		all_passed = _check("instance-backed template baked",
			baked_action.codegen_template, "__eventsheet_provider_DemoHealthAddon.announce_heal({amount})") and all_passed

		# Compiler declares the provider member once, before the first function, and the
		# call compiles as a direct typed call.
		var sheet: EventSheetResource = EventSheetResource.new()
		var event: EventRow = EventRow.new()
		event.trigger_provider_id = "Core"
		event.trigger_id = "OnReady"
		event.actions.append(baked_action)
		var second_action: ACEAction = editor._create_action_from_definition(announce_definition, {"amount": 9})
		event.actions.append(second_action)
		sheet.events.append(event)
		var output: String = str(SheetCompiler.compile(sheet, "user://eventforge_instance_backed.gd").get("output", ""))
		all_passed = _check("direct call emitted",
			output.contains("\t__eventsheet_provider_DemoHealthAddon.announce_heal(7)"), true) and all_passed
		all_passed = _check("provider member declared exactly once",
			output.count("var __eventsheet_provider_DemoHealthAddon := DemoHealthAddon.new()"), 1) and all_passed
		all_passed = _check("member declared before first function",
			output.find("var __eventsheet_provider_") < output.find("func _ready"), true) and all_passed
		all_passed = _check("no EventForge classes in output (parity holds)",
			output.contains("EventForgeBridge") or output.contains("ACERegistry"), false) and all_passed
		var generated: GDScript = GDScript.new()
		generated.source_code = output
		all_passed = _check("instance-backed output parses", generated.reload(true) == OK, true) and all_passed
	editor.free()

	EventForgeBridgeRuntime.unregister_provider_script("res://tests/fixtures/runtime_provider_fixture.gd")
	all_passed = _check("bridge unregistration works",
		EventForgeBridgeRuntime.get_registered_provider_scripts().has("res://tests/fixtures/runtime_provider_fixture.gd"), false) and all_passed

	return all_passed

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] runtime_provider_test: %s" % label)
		return true
	print("[FAIL] runtime_provider_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
