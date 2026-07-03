# Godot EventSheets — AI event-generation pipeline test.
# Verifies the grounded prompt, the GDScript→events lift (the same lossless path the editor's
# paste uses), markdown-fence stripping, and the injectable response provider — so the whole
# "describe → events" pipeline is deterministic and testable without a live LLM.
@tool
class_name AIGenerationTest
extends RefCounted


static func run() -> bool:
    var passed: bool = true
    var sheet: EventSheetResource = EventSheetResource.new()
    sheet.host_class = "CharacterBody2D"
    sheet.variables = {"hp": {"type": "int", "default": 100}}

    var prompt: String = EventSheetAIGeneration.build_prompt("make the player jump", sheet)
    passed = _check("prompt grounds in the host class", prompt.contains("CharacterBody2D"), true) and passed
    passed = _check("prompt lists the sheet variables", prompt.contains("hp"), true) and passed
    passed = _check("prompt carries the description", prompt.contains("make the player jump"), true) and passed

    var generated: Dictionary = EventSheetAIGeneration.generate_rows("", sheet, "velocity.y = -400.0\nhp -= 1")
    passed = _check("generated GDScript lifts into editable rows", (generated.get("rows", []) as Array).size() >= 1, true) and passed
    passed = _check("a good generation has no error", str(generated.get("error", "")), "") and passed

    var fenced: Dictionary = EventSheetAIGeneration.generate_rows("", sheet, "```gdscript\nhp += 5\n```")
    passed = _check("markdown fences are stripped before lifting", (fenced.get("rows", []) as Array).size() >= 1, true) and passed

    var empty: Dictionary = EventSheetAIGeneration.generate_rows("", sheet, "   ")
    passed = _check("empty generation reports an error", str(empty.get("error", "")) != "", true) and passed

    EventSheetAIGeneration.response_provider = func(_p: String) -> String: return "hp = 50"
    var resolved: String = EventSheetAIGeneration.resolve_gdscript("set hp to 50", sheet)
    EventSheetAIGeneration.response_provider = Callable()  # reset so it can't leak to other tests
    passed = _check("injected provider resolves GDScript (offline/testable path)", resolved, "hp = 50") and passed

    passed = _check("live AI is not configured by default (no silent network calls)",
        EventSheetAIGeneration.is_live_configured(), false) and passed

    return passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
    if actual == expected:
        print("[PASS] ai_generation_test: %s" % label)
        return true
    print("[FAIL] ai_generation_test: %s" % label)
    print("  expected: %s" % str(expected))
    print("  actual:   %s" % str(actual))
    return false
