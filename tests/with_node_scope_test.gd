# Godot EventSheets - "With node X:" scope block (event-sheet-style pick-once).
#
# A row with a with_node_target scopes its actions - and its descendant sub-events' actions - to that
# node: any action that leaves its "On node" target on the host (blank, or the "self" of the group/meta
# ACEs) inlines to X ($Enemy.play()). Actions that are not node-targetable (Print) run on the host, and
# an explicit target the author set is never overridden. Verifies the compile model the user chose
# (inline per action), inheritance into nested sub-events, and the byte-identical .gd round-trip.
@tool
class_name WithNodeScopeTest
extends RefCounted


static func run() -> bool:
	var all_passed: bool = true

	# is_with_node_scope(): a bare target with no trigger/conditions is a scope block; a trigger is not.
	var scope_row: EventRow = EventRow.new()
	scope_row.with_node_target = "$Enemy"
	all_passed = _check("a bare target row is a With-node scope", scope_row.is_with_node_scope(), true) and all_passed
	var triggered: EventRow = EventRow.new()
	triggered.with_node_target = "$Enemy"
	triggered.trigger_id = "OnReady"
	all_passed = _check("a triggered row is not a scope block", triggered.is_with_node_scope(), false) and all_passed

	var source: String = _compile_scope_sheet()

	# Scoping: a blank-target node ACE inlines to the node.
	all_passed = _check("blank-target action scopes to the node", source.contains("$Enemy.modulate = Color.RED"), true) and all_passed
	# Non-targetable action runs on the host (no $Enemy. prefix).
	all_passed = _check("non-targetable action stays on the host", source.contains("\n\tprint(\"hi\")"), true) and all_passed
	all_passed = _check("non-targetable action is not retargeted", source.contains("$Enemy.print"), false) and all_passed
	# An explicit target the author chose wins over the scope.
	all_passed = _check("explicit target is preserved", source.contains("$Boss.modulate = Color.RED"), true) and all_passed
	# The "self" default of the group/meta ACEs is also folded into the scope.
	all_passed = _check("self-default action scopes to the node", source.contains("$Enemy.add_to_group(\"enemies\")"), true) and all_passed
	# Inheritance: a nested sub-event's action inherits the enclosing scope.
	all_passed = _check("nested sub-event inherits the scope", source.contains("$Enemy.play(&\"walk\")"), true) and all_passed
	all_passed = _check("nested action sits under its condition", source.contains("if is_on_floor():"), true) and all_passed

	# Round-trip: the generated .gd re-imports and recompiles byte-for-byte (Option A: the block
	# expands to individual targeted ACEs, which re-emit identically).
	var imported: EventSheetResource = GDScriptImporter.new().import_external_source(source)
	imported.external_source_path = "user://__with_node_roundtrip.gd"
	var roundtrip: String = str(SheetCompiler.compile(imported, "user://__with_node_roundtrip.gd").get("output", ""))
	all_passed = _check("scoped output re-imports + recompiles byte-identically", roundtrip == source, true) and all_passed

	return all_passed


## OnReady → With node $Enemy → { Set Modulate (blank), Print (host), Set Modulate on $Boss (explicit),
## Add To Group (self), and a nested `if on floor` sub-event with Play Animation (inherits the scope) }.
static func _compile_scope_sheet() -> String:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "CharacterBody2D"
	var on_ready: EventRow = EventRow.new()
	on_ready.trigger_provider_id = "Core"
	on_ready.trigger_id = "OnReady"

	var scope: EventRow = EventRow.new()
	scope.with_node_target = "$Enemy"
	scope.actions.append(_action("SetModulate", {"color": "Color.RED"}))
	scope.actions.append(_action("Print", {"value": "\"hi\""}))
	scope.actions.append(_action("SetModulate", {"color": "Color.RED", "target": "$Boss"}))
	scope.actions.append(_action("AddToGroup", {"target": "self", "group": "\"enemies\""}))

	var nested: EventRow = EventRow.new()
	var grounded: ACECondition = ACECondition.new()
	grounded.provider_id = "Core"
	grounded.ace_id = "IsOnFloor"
	nested.conditions.append(grounded)
	nested.actions.append(_action("PlaySpriteAnimation", {"anim": "\"walk\""}))
	scope.sub_events.append(nested)

	on_ready.sub_events.append(scope)
	sheet.events.append(on_ready)
	return str(SheetCompiler.compile(sheet, "user://__with_node_compiled.gd").get("output", ""))


## A Core action with empty codegen_template, so the compiler resolves the registered (post-processed)
## template - exercising the real {target.} node-scoped descriptors.
static func _action(ace_id: String, params: Dictionary) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = ace_id
	action.params = params
	return action


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] with_node_scope_test: %s" % label)
		return true
	print("[FAIL] with_node_scope_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
