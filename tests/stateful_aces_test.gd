# Godot EventSheets — Stateful conditions + multi-statement actions (System batch 2)
# Every X Seconds owns a per-instance member (prelude accumulates, on_true rebases);
# Spawn Scene At is a multi-line template with a baked-uid local. Both keep the parity
# contract: plain members, plain statements, zero indirection.
@tool
extends RefCounted
class_name StatefulAcesTest

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

	# Apply-time baking: a fresh uid lands in member/prelude/on_true/template together.
	var registry_definition: ACEDefinition = null
	var editor: EventSheetEditor = EventSheetEditor.new()
	var sheet: EventSheetResource = EventSheetResource.new()
	editor.setup(sheet)
	editor.set_undo_redo_manager(NoopUndoManager.new())
	for definition in editor._ace_registry.get_all_definitions():
		if definition.id == "EveryXSeconds":
			registry_definition = definition
	all_passed = _check("Every X Seconds publishes", registry_definition != null, true) and all_passed
	var condition: ACECondition = editor._create_condition_from_definition(registry_definition, {"seconds": "2.0"})
	all_passed = _check("member bakes with a uid",
		condition.member_declaration.begins_with("var __every_") and not condition.member_declaration.contains("{uid}"), true) and all_passed
	var baked_name: String = condition.member_declaration.get_slice(":", 0).trim_prefix("var ")
	all_passed = _check("template/prelude/on_true share the uid",
		condition.codegen_template.contains(baked_name) and condition.codegen_prelude.contains(baked_name) and condition.codegen_on_true.contains(baked_name), true) and all_passed
	var second: ACECondition = editor._create_condition_from_definition(registry_definition, {"seconds": "2.0"})
	all_passed = _check("each instance gets its own state",
		second.member_declaration != condition.member_declaration, true) and all_passed
	editor.free()

	# Compile: member at class level, prelude before the if, on_true inside it.
	condition.params = {"seconds": "2.0"}
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnProcess"
	event.conditions.append(condition)
	var act: ACEAction = ACEAction.new()
	act.provider_id = "Core"
	act.ace_id = "PrintLog"
	act.codegen_template = "print({message})"
	act.params = {"message": "\"tick\""}
	event.actions.append(act)
	var compile_sheet: EventSheetResource = EventSheetResource.new()
	compile_sheet.events.append(event)
	var output: String = str(SheetCompiler.compile(compile_sheet, "user://eventsheets_stateful.gd").get("output", ""))
	all_passed = _check("member declared at class level",
		output.contains(condition.member_declaration), true) and all_passed
	all_passed = _check("prelude accumulates before the if",
		output.find("%s += get_process_delta_time()" % baked_name) < output.find("if %s >= maxf(2.0, 0.001):" % baked_name) and output.find("%s += get_process_delta_time()" % baked_name) != -1, true) and all_passed
	all_passed = _check("on_true rebases inside the if",
		output.contains("\t\t%s = fmod(%s, maxf(2.0, 0.001))" % [baked_name, baked_name]), true) and all_passed
	all_passed = _check("action runs after the rebase",
		output.find("fmod") < output.find("print(\"tick\")"), true) and all_passed
	var generated: GDScript = GDScript.new()
	generated.source_code = output
	all_passed = _check("stateful output parses", generated.reload(true) == OK, true) and all_passed

	# Multi-statement action: Spawn Scene At emits three lines with one baked local.
	var spawn: ACEAction = ACEAction.new()
	spawn.provider_id = "Core"
	spawn.ace_id = "SpawnSceneAt"
	spawn.codegen_template = "var __spawn_a1 = load({path}).instantiate()\n__spawn_a1.position = {position}\nadd_child(__spawn_a1)"
	spawn.params = {"path": "\"res://demo/scenes/player.tscn\"", "position": "Vector2(10, 20)"}
	var spawn_event: EventRow = EventRow.new()
	spawn_event.trigger_provider_id = "Core"
	spawn_event.trigger_id = "OnReady"
	spawn_event.actions.append(spawn)
	var spawn_sheet: EventSheetResource = EventSheetResource.new()
	spawn_sheet.events.append(spawn_event)
	var spawn_output: String = str(SheetCompiler.compile(spawn_sheet, "user://eventsheets_spawnat.gd").get("output", ""))
	all_passed = _check("multi-line template emits each line indented",
		spawn_output.contains("\tvar __spawn_a1 = load(\"res://demo/scenes/player.tscn\").instantiate()") and spawn_output.contains("\t__spawn_a1.position = Vector2(10, 20)") and spawn_output.contains("\tadd_child(__spawn_a1)"), true) and all_passed
	var spawn_script: GDScript = GDScript.new()
	spawn_script.source_code = spawn_output
	all_passed = _check("spawn-at output parses", spawn_script.reload(true) == OK, true) and all_passed

	# Sweep regressions: external sheets declare baked members; disabled conditions
	# leave no orphan members; OR-mode stateful events warn.
	var external_source: String = "extends Node
"
	var external_sheet: EventSheetResource = GDScriptImporter.new().import_external_source(external_source)
	external_sheet.external_source_path = "user://eventsheets_stateful_ext.gd"
	var ext_event: EventRow = EventRow.new()
	ext_event.trigger_provider_id = "Core"
	ext_event.trigger_id = "OnProcess"
	var ext_condition: ACECondition = ACECondition.new()
	ext_condition.provider_id = "Core"
	ext_condition.ace_id = "EveryXSeconds"
	ext_condition.codegen_template = "__every_ext1 >= maxf({seconds}, 0.001)"
	ext_condition.member_declaration = "var __every_ext1: float = 0.0"
	ext_condition.codegen_prelude = "__every_ext1 += delta"
	ext_condition.codegen_on_true = "__every_ext1 = fmod(__every_ext1, maxf({seconds}, 0.001))"
	ext_condition.params = {"seconds": "1.0"}
	ext_event.conditions.append(ext_condition)
	var ext_action: ACEAction = ACEAction.new()
	ext_action.provider_id = "Core"
	ext_action.ace_id = "PrintLog"
	ext_action.codegen_template = "print({message})"
	ext_action.params = {"message": "\"ext\""}
	ext_event.actions.append(ext_action)
	external_sheet.events.append(ext_event)
	var ext_output: String = str(SheetCompiler.compile(external_sheet, "user://eventsheets_stateful_ext.gd").get("output", ""))
	all_passed = _check("external sheets declare the baked member",
		ext_output.contains("var __every_ext1: float = 0.0"), true) and all_passed
	var ext_script: GDScript = GDScript.new()
	ext_script.source_code = ext_output
	all_passed = _check("external stateful output parses", ext_script.reload(true) == OK, true) and all_passed

	condition.enabled = false
	var disabled_output: String = str(SheetCompiler.compile(compile_sheet, "user://eventsheets_stateful_off.gd").get("output", ""))
	all_passed = _check("disabled stateful conditions leave no orphan member",
		disabled_output.contains(condition.member_declaration), false) and all_passed
	condition.enabled = true

	event.condition_mode = EventRow.ConditionMode.OR
	var extra: ACECondition = ACECondition.new()
	extra.provider_id = "Core"
	extra.ace_id = "Always"
	extra.codegen_template = "true"
	event.conditions.append(extra)
	var or_warnings: Array = SheetCompiler.compile(compile_sheet, "user://eventsheets_stateful_or.gd").get("warnings", [])
	all_passed = _check("OR-mode stateful events warn",
		str(or_warnings).contains("rebase"), true) and all_passed

	return all_passed

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] stateful_aces_test: %s" % label)
		return true
	print("[FAIL] stateful_aces_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
