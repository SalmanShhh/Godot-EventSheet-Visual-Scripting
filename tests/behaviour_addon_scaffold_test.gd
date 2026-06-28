# Godot EventSheets — the "New Behaviour Addon" scaffold generator.
#
# The scaffold writes a richly-commented skeleton .gd that teaches the @ace_* vocabulary and is dropped into
# res://eventsheet_addons/ to become an auto-discovered ACE provider. The load-bearing guarantee: the
# generated skeleton must be VALID GDScript for every base class offered — a scaffold that doesn't parse is
# worse than none. This pins name validation, the path, the content, and that parse for all bases.
@tool
extends RefCounted
class_name BehaviourAddonScaffoldTest

# preload (not the global class_name) so the test parses even before a project re-import registers the
# freshly-added EventSheetBehaviourAddonScaffold in the global class cache.
const Scaffold := preload("res://addons/eventsheet/editor/behaviour_addon_scaffold.gd")

static func run() -> bool:
	var all_passed: bool = true

	# Name validation.
	all_passed = _check("accepts a valid PascalCase name", Scaffold.is_valid_class_name("PlayerCombat"), true) and all_passed
	all_passed = _check("rejects an empty name", Scaffold.is_valid_class_name(""), false) and all_passed
	all_passed = _check("rejects a leading digit", Scaffold.is_valid_class_name("3Lives"), false) and all_passed
	all_passed = _check("rejects a reserved word", Scaffold.is_valid_class_name("func"), false) and all_passed
	all_passed = _check("rejects an existing engine class", Scaffold.is_valid_class_name("Node"), false) and all_passed

	# Suggested path (snake_cased under the auto-scanned folder).
	all_passed = _check("suggested path is snake_cased under eventsheet_addons",
		Scaffold.suggested_path("PlayerCombat"),
		"res://eventsheet_addons/player_combat/player_combat.gd") and all_passed

	# Content: identity + the taught vocabulary.
	var src: String = Scaffold.generate("PlayerCombat", "Node2D", "Combat", "Handles attacks.")
	all_passed = _check("includes the class_name", src.contains("class_name PlayerCombat"), true) and all_passed
	all_passed = _check("includes the chosen base", src.contains("extends Node2D"), true) and all_passed
	all_passed = _check("applies the category", src.contains("@ace_category(\"Combat\")"), true) and all_passed
	all_passed = _check("teaches the core annotation types + a trigger signal",
		src.contains("@ace_action") and src.contains("@ace_condition") and src.contains("@ace_expression") and src.contains("signal activated"), true) and all_passed

	# CRITICAL: the skeleton must be valid GDScript for EVERY offered base class.
	for base: String in Scaffold.BASE_CLASSES:
		var script: GDScript = GDScript.new()
		script.source_code = Scaffold.generate("ScaffoldProbe%s" % base, base, "Demo", "Probe.")
		all_passed = _check("the skeleton parses cleanly (extends %s)" % base, script.reload(), OK) and all_passed

	# Each ACE kind the scaffold teaches is present + annotated, so the generator (which reads these exact
	# annotations from the file, exercised by the real behaviour packs) turns them into a Trigger / Action /
	# Condition / Expression. Kept deterministic (no temp-file load, which is flaky headless).
	var sample: String = Scaffold.generate("AcesProbe", "Node", "Demo", "Probe.")
	all_passed = _check("a signal trigger is annotated", sample.contains("signal activated"), true) and all_passed
	all_passed = _check("an action method is annotated", sample.contains("@ace_action") and sample.contains("func do_the_thing"), true) and all_passed
	all_passed = _check("a condition method is annotated", sample.contains("@ace_condition") and sample.contains("func is_ready"), true) and all_passed
	all_passed = _check("an expression method is annotated", sample.contains("@ace_expression") and sample.contains("func current_strength"), true) and all_passed
	all_passed = _check("an @export property is present", sample.contains("@export var strength"), true) and all_passed

	# ── Adversarial-review regression cases ──
	# Finding 1: a duplicate class_name is a HARD project error, so an existing GLOBAL script class is rejected.
	all_passed = _check("rejects an existing global script class", Scaffold.is_valid_class_name("ACEAction"), false) and all_passed
	# Finding 4: _to_snake_case must not mangle acronyms / digits.
	all_passed = _check("snake_case keeps an acronym intact (HUDManager)", Scaffold._to_snake_case("HUDManager"), "hud_manager") and all_passed
	all_passed = _check("snake_case keeps a leading acronym (ABCWidget)", Scaffold._to_snake_case("ABCWidget"), "abc_widget") and all_passed
	all_passed = _check("snake_case keeps a digit run (Box2DBody)", Scaffold._to_snake_case("Box2DBody"), "box2d_body") and all_passed
	all_passed = _check("snake_case the simple case (PlayerCombat)", Scaffold._to_snake_case("PlayerCombat"), "player_combat") and all_passed
	# Findings 2 + 3: newlines / quotes in category + description never corrupt the generated GDScript.
	var dirty: String = Scaffold.generate("DirtyInput", "Node", "Multi\nLine", "Has \"quotes\" and\nnewlines")
	var dirty_script: GDScript = GDScript.new()
	dirty_script.source_code = dirty
	all_passed = _check("newline/quote-laden category & description still parse", dirty_script.reload(), OK) and all_passed
	all_passed = _check("embedded double-quotes are neutralised in the annotation", dirty.contains("Has 'quotes'"), true) and all_passed

	return all_passed

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] behaviour_addon_scaffold_test: %s" % label)
		return true
	print("[FAIL] behaviour_addon_scaffold_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
