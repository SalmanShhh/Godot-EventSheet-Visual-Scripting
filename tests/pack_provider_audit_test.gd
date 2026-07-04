# Godot EventSheets - every shipped pack audited against the ACE provider system.
#
# Sweeps every scanned addon script (the exact list the live registry consumes) and
# holds each one to the provider covenant:
#   - the script loads and instantiates (a broken pack must never ship),
#   - no unknown @ace_* annotations (typos silently drop metadata),
#   - every action/condition BAKES to real code: an explicit codegen template, or the
#     reflected-method/property synthesis - never empty (empty = a row that compiles
#     to nothing, the silent-no-op covenant violation),
#   - every expression carries insertable code (an empty template inserts the display
#     NAME into the sheet as if it were code).
# Triggers are exempt: signals bake through the trigger-connection path, not templates.
@tool
class_name PackProviderAuditTest
extends RefCounted


static func run() -> bool:
	var ok: bool = true
	var analyzer: EventSheetSemanticAnalyzer = EventSheetSemanticAnalyzer.new()
	var generator: EventSheetACEGenerator = EventSheetACEGenerator.new()
	var scripts: Array[String] = EventSheetAddonScanner.list_addon_scripts()
	ok = _check("the scanner finds the shipped packs", scripts.size() >= 30, true) and ok
	var violations: PackedStringArray = PackedStringArray()
	var audited: int = 0
	var definition_count: int = 0
	for script_path: String in scripts:
		var script: Script = load(script_path) as Script
		if script == null or not script.can_instantiate():
			violations.append("%s: does not load/instantiate" % script_path)
			continue
		var instance: Object = script.new()
		if instance == null:
			violations.append("%s: new() returned null" % script_path)
			continue
		audited += 1
		var metadata: Dictionary = analyzer.parse_source_metadata(script)
		for unknown: Variant in (metadata.get("unknown_annotations", []) as Array):
			violations.append("%s: unknown annotation %s" % [script_path.get_file(), str(unknown)])
		for definition: ACEDefinition in generator.generate_from_object(instance):
			definition_count += 1
			if definition.ace_type == ACEDefinition.ACEType.TRIGGER:
				continue
			if _bakes_to_code(definition):
				continue
			violations.append("%s: %s \"%s\" bakes to EMPTY codegen" % [
				script_path.get_file(), _type_label(definition.ace_type), definition.id])
		if instance is Node:
			(instance as Node).free()
	print("[info] pack_provider_audit_test: %d scripts audited, %d definitions checked" % [audited, definition_count])
	for violation: String in violations:
		print("  [VIOLATION] %s" % violation)
	ok = _check("every pack definition holds the provider covenant (0 violations)", violations.size(), 0) and ok

	# The detector self-check: a template-less, non-method definition MUST be flagged,
	# so a metadata-key rename can never turn the whole audit into a vacuous pass.
	var empty_definition: ACEDefinition = ACEDefinition.new()
	empty_definition.ace_type = ACEDefinition.ACEType.ACTION
	empty_definition.metadata = {"semantic_source": "reflection", "source_kind": "property_action", "source_name": "x"}
	ok = _check("the detector flags a template-less non-method bake", _bakes_to_code(empty_definition), false) and ok
	var method_definition: ACEDefinition = ACEDefinition.new()
	method_definition.ace_type = ACEDefinition.ACEType.ACTION
	method_definition.metadata = {"semantic_source": "reflection", "source_kind": "method", "source_name": "x"}
	ok = _check("the detector accepts the reflected-method synthesis", _bakes_to_code(method_definition), true) and ok
	return ok


## Mirrors the apply-time bake (_baked_template_for) plus the expression-insert path:
## explicit template wins; reflected METHODS synthesize the owned-instance call at bake.
static func _bakes_to_code(definition: ACEDefinition) -> bool:
	if not str(definition.metadata.get("codegen_template", "")).strip_edges().is_empty():
		return true
	return str(definition.metadata.get("semantic_source", "")) == "reflection" \
		and str(definition.metadata.get("source_kind", "")) == "method" \
		and not str(definition.metadata.get("source_name", "")).is_empty()


static func _type_label(ace_type: int) -> String:
	match ace_type:
		ACEDefinition.ACEType.CONDITION:
			return "condition"
		ACEDefinition.ACEType.EXPRESSION:
			return "expression"
	return "action"


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] pack_provider_audit_test: %s" % label)
		return true
	print("[FAIL] pack_provider_audit_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
