# EventForge — integrated auto ACE system tests
@tool
class_name AutoACESystemTest
extends RefCounted

const SAMPLE_SCRIPT := preload("res://tests/fixtures/auto_ace_sample.gd")


static func run() -> bool:
    var all_passed: bool = true
    var sample: Node = SAMPLE_SCRIPT.new()
    var registry := EventSheetACERegistry.new()
    registry.refresh_from_sources([sample], true)

    var provider_id: String = "AutoACESample"
    var died_trigger: ACEDefinition = registry.find_definition(provider_id, "signal:died")
    all_passed = _check("signal generates trigger", died_trigger.display_name if died_trigger != null else "", "On Died") and all_passed

    var health_expression: ACEDefinition = registry.find_definition(provider_id, "property:health")
    all_passed = _check("exported var generates expression", health_expression.display_name if health_expression != null else "", "Health") and all_passed

    var set_health: ACEDefinition = registry.find_definition(provider_id, "set:health")
    all_passed = _check("exported var generates setter", set_health.display_name if set_health != null else "", "Set Health") and all_passed

    var add_health: ACEDefinition = registry.find_definition(provider_id, "add:health")
    all_passed = _check("numeric exported var generates add action", add_health.display_name if add_health != null else "", "Add To Health") and all_passed

    var subtract_health: ACEDefinition = registry.find_definition(provider_id, "subtract:health")
    all_passed = _check("numeric exported var generates subtract action", subtract_health.display_name if subtract_health != null else "", "Subtract From Health") and all_passed

    var is_dead: ACEDefinition = registry.find_definition(provider_id, "method:is_dead")
    all_passed = _check("bool method generates condition", is_dead.ace_type if is_dead != null else -1, ACEDefinition.ACEType.CONDITION) and all_passed
    all_passed = _check("bool method display name is semantic", is_dead.display_name if is_dead != null else "", "Dead") and all_passed

    var take_damage: ACEDefinition = registry.find_definition(provider_id, "method:take_damage")
    all_passed = _check("void method generates action", take_damage.ace_type if take_damage != null else -1, ACEDefinition.ACEType.ACTION) and all_passed
    all_passed = _check("doc category override applied", take_damage.category if take_damage != null else "", "Combat") and all_passed

    var status_text: ACEDefinition = registry.find_definition(provider_id, "method:get_status_label")
    all_passed = _check("value method generates expression", status_text.ace_type if status_text != null else -1, ACEDefinition.ACEType.EXPRESSION) and all_passed
    all_passed = _check("doc name override applied", status_text.display_name if status_text != null else "", "Status Text") and all_passed

    all_passed = _check("hidden methods are excluded", registry.find_definition(provider_id, "method:hidden_editor_helper") == null, true) and all_passed

    var search_results: Array[ACEDefinition] = registry.search("damage", "Combat")
    all_passed = _check("semantic search returns damage action", _contains_definition(search_results, "method:take_damage"), true) and all_passed
    all_passed = _check("registry includes builtins too", registry.find_definition("Core", "Always") != null, true) and all_passed

    sample.free()
    return all_passed


static func _contains_definition(definitions: Array[ACEDefinition], definition_id: String) -> bool:
    for definition: ACEDefinition in definitions:
        if definition != null and definition.id == definition_id:
            return true
    return false


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
    if actual == expected:
        print("[PASS] auto_ace_system_test: %s" % label)
        return true
    print("[FAIL] auto_ace_system_test: %s" % label)
    print("  expected: %s" % str(expected))
    print("  actual:   %s" % str(actual))
    return false
