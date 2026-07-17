# EventForge - looping conditions (@ace_looping, the C3 is-looping idea): a pack method that
# returns a collection, annotated `## @ace_looping(iterator)`, sits with conditions in the
# picker but APPLIES as a pick filter - the event's actions loop once per returned item,
# through the existing pick machinery (for-emission, lane UI, round-trip lift all reused).
# Pins: annotation parsing (iterator name, "item" default, forced CONDITION type), the
# registered StatForge "For Each Buff" definition, collection-expression baking with params
# substituted, and the compiled for-loop shape.
@tool
class_name LoopingConditionsTest
extends RefCounted


static func run() -> bool:
	var all_passed: bool = true

	# ---- annotation parsing off the shipped StatForge pack ----
	var analyzer: EventSheetSemanticAnalyzer = EventSheetSemanticAnalyzer.new()
	var pack_script: Script = load("res://eventsheet_addons/stat_forge/stat_forge_behavior.gd")
	var source_metadata: Dictionary = analyzer.parse_source_metadata(pack_script)
	var overrides: Dictionary = source_metadata.get("methods", {}).get("each_buff", {})
	all_passed = _check("@ace_looping parses", bool(overrides.get("looping", false)), true) and all_passed
	all_passed = _check("the iterator name rides along", str(overrides.get("looping_iterator", "")), "buff_id") and all_passed
	all_passed = _check("looping members sit with conditions", int(overrides.get("forced_ace_type", -1)), ACEDefinition.ACEType.CONDITION) and all_passed

	# ---- a bare @ace_looping falls back to the "item" iterator ----
	var probe_path: String = "user://looping_probe.gd"
	var probe: FileAccess = FileAccess.open(probe_path, FileAccess.WRITE)
	probe.store_string("extends Node\n\n\n## @ace_looping\nfunc each_thing() -> Array:\n\treturn []\n")
	probe.close()
	var probe_metadata: Dictionary = analyzer.parse_source_metadata(load(probe_path))
	var probe_overrides: Dictionary = probe_metadata.get("methods", {}).get("each_thing", {})
	all_passed = _check("bare @ace_looping defaults the iterator to item", str(probe_overrides.get("looping_iterator", "")), "item") and all_passed
	DirAccess.remove_absolute(probe_path)

	# ---- the collection expression bakes the call with params substituted ----
	var definition: ACEDefinition = ACEDefinition.new()
	definition.provider_id = "StatForge"
	definition.id = "method:buffs_with_tag"
	definition.ace_type = ACEDefinition.ACEType.CONDITION
	definition.metadata = {"looping": true, "looping_iterator": "buff_id", "codegen_template": "__eventsheet_provider_StatForge.buffs_with_tag({tag})"}
	var apply_script: Script = load("res://addons/eventsheet/editor/dock/ace_apply.gd")
	var collection: String = apply_script.call("build_looping_collection", definition, {"tag": "\"poison\""})
	all_passed = _check("params bake into the loop collection", collection, "__eventsheet_provider_StatForge.buffs_with_tag(\"poison\")") and all_passed

	# ---- the applied pick filter compiles to a plain for loop ----
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	var row: EventRow = EventRow.new()
	row.trigger_provider_id = "Core"
	row.trigger_id = "OnProcess"
	var pick: PickFilter = PickFilter.new()
	pick.collection_kind = PickFilter.CollectionKind.EXPRESSION
	pick.collection_value = "each_buff()"
	pick.iterator_name = "buff_id"
	row.pick_filters.append(pick)
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "Print"
	action.codegen_template = "print(buff_id)"
	row.actions.append(action)
	sheet.events.append(row)
	var output: String = str(SheetCompiler.compile(sheet, "user://looping_compile_probe.gd").get("output", ""))
	all_passed = _check("the loop compiles as a plain for", output.contains("for buff_id in each_buff():"), true) and all_passed
	all_passed = _check("the action runs inside the loop body", output.contains("\t\tprint(buff_id)"), true) and all_passed
	if FileAccess.file_exists("user://looping_compile_probe.gd"):
		DirAccess.remove_absolute("user://looping_compile_probe.gd")

	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		return true
	print("  [FAIL] looping_conditions_test: %s (got %s, expected %s)" % [label, str(actual), str(expected)])
	return false
