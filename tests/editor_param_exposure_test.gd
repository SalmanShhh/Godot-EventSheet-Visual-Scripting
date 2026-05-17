# EventSheet — Editor parameter exposure tests
# Covers EditorParamStore, ACEDefinition exposure fields, ParamDefaultResolver,
# and ACEGenerator exposure inference.
@tool
extends RefCounted
class_name EditorParamExposureTest

const SAMPLE_SCRIPT := preload("res://tests/fixtures/auto_ace_sample.gd")

static func run() -> bool:
	var all_passed: bool = true
	all_passed = _test_editor_param_store() and all_passed
	all_passed = _test_ace_definition_exposure_fields() and all_passed
	all_passed = _test_param_default_resolver() and all_passed
	all_passed = _test_ace_generator_exposure_inference() and all_passed
	return all_passed

# ── EditorParamStore ──────────────────────────────────────────────────────────

static func _test_editor_param_store() -> bool:
	var passed: bool = true
	var store := EditorParamStore.new()

	passed = _check("store is empty initially", store.override_count(), 0) and passed
	passed = _check("has_param returns false for unknown", store.has_param("P", "A", "x"), false) and passed

	store.set_param("P", "A", "x", 42)
	passed = _check("has_param true after set", store.has_param("P", "A", "x"), true) and passed
	passed = _check("get_param returns stored value", store.get_param("P", "A", "x"), 42) and passed
	passed = _check("override count incremented", store.override_count(), 1) and passed

	store.set_param("P", "A", "x", 99)
	passed = _check("set_param overwrites existing", store.get_param("P", "A", "x"), 99) and passed

	store.set_param("P", "B", "y", "hello")
	passed = _check("second param stored", store.get_param("P", "B", "y"), "hello") and passed
	passed = _check("override count is 2", store.override_count(), 2) and passed

	store.clear_param("P", "A", "x")
	passed = _check("clear_param removes entry", store.has_param("P", "A", "x"), false) and passed
	passed = _check("override count decremented", store.override_count(), 1) and passed

	store.clear_all()
	passed = _check("clear_all empties store", store.override_count(), 0) and passed

	passed = _check("get_param returns default when missing", store.get_param("P", "A", "z", -1), -1) and passed

	return passed

# ── ACEDefinition exposure fields ─────────────────────────────────────────────

static func _test_ace_definition_exposure_fields() -> bool:
	var passed: bool = true
	var def := ACEDefinition.new()

	passed = _check("editor_exposed defaults to false", def.editor_exposed, false) and passed
	passed = _check("property_hint defaults to PROPERTY_HINT_NONE", def.property_hint, PROPERTY_HINT_NONE) and passed
	passed = _check("hint_string defaults empty", def.hint_string, "") and passed
	passed = _check("widget_hint defaults empty", def.widget_hint, "") and passed
	passed = _check("category_override defaults empty", def.category_override, "") and passed

	def.category = "Physics"
	def.category_override = ""
	passed = _check("get_inspector_category falls back to category", def.get_inspector_category(), "Physics") and passed

	def.category_override = "MyOverride"
	passed = _check("get_inspector_category uses override when set", def.get_inspector_category(), "MyOverride") and passed

	return passed

# ── ParamDefaultResolver ──────────────────────────────────────────────────────

static func _test_param_default_resolver() -> bool:
	var passed: bool = true
	var store := EditorParamStore.new()
	var resolver := ParamDefaultResolver.new()
	resolver.set_param_store(store)

	var param_meta := {
		"id": "amount",
		"type": TYPE_INT,
		"default_value": 10
	}

	# No overrides: should return ACE default
	var result: Variant = resolver.resolve("P", "A", "amount", param_meta, null)
	passed = _check("resolver returns ace default when no overrides", result, 10) and passed

	# Row override takes top priority
	result = resolver.resolve("P", "A", "amount", param_meta, 99)
	passed = _check("resolver returns row override first", result, 99) and passed

	# Editor store override
	store.set_param("P", "A", "amount", 55)
	result = resolver.resolve("P", "A", "amount", param_meta, null)
	passed = _check("resolver returns store override", result, 55) and passed

	# Row override still wins over store
	result = resolver.resolve("P", "A", "amount", param_meta, 77)
	passed = _check("row override still wins over store", result, 77) and passed

	# Zero-value fallback when no default in meta
	var no_default_meta := {"id": "flag", "type": TYPE_BOOL}
	result = resolver.resolve("P", "A", "flag", no_default_meta, null)
	passed = _check("resolver returns type zero-value as last resort", result, false) and passed

	# resolve_all
	var def := ACEDefinition.new()
	def.provider_id = "P"
	def.id = "A"
	def.parameters = [param_meta, no_default_meta]
	var resolved: Dictionary = resolver.resolve_all(def, {"amount": 3})
	passed = _check("resolve_all uses row params", resolved.get("amount"), 3) and passed

	return passed

# ── ACEGenerator exposure inference ───────────────────────────────────────────

static func _test_ace_generator_exposure_inference() -> bool:
	var passed: bool = true
	var sample: Node = SAMPLE_SCRIPT.new()
	var registry := EventSheetACERegistry.new()
	registry.refresh_from_sources([sample], false)  # no builtins needed

	var provider_id: String = "AutoACESample"

	# Exported property expression should be editor_exposed = true
	var health_expr: ACEDefinition = registry.find_definition(provider_id, "property:health")
	passed = _check("exported property expression is editor_exposed", health_expr.editor_exposed if health_expr != null else false, true) and passed

	# Signal trigger should NOT be editor_exposed
	var died_trig: ACEDefinition = registry.find_definition(provider_id, "signal:died")
	passed = _check("signal trigger is not editor_exposed", died_trig.editor_exposed if died_trig != null else true, false) and passed

	# Void method with primitive param should be editor_exposed
	var take_dmg: ACEDefinition = registry.find_definition(provider_id, "method:take_damage")
	passed = _check("void method with primitive param is editor_exposed", take_dmg.editor_exposed if take_dmg != null else false, true) and passed

	sample.free()
	return passed

# ── Helpers ───────────────────────────────────────────────────────────────────

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] editor_param_exposure_test: %s" % label)
		return true
	print("[FAIL] editor_param_exposure_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
