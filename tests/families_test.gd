# Godot EventSheets — Families (the C3-style "one rule for every instance of a type").
#
# Pins the Families v1 contract:
#   - A sheet flagged `is_family` emits a `## @ace_family(<Class>)` marker (metadata only, like @ace_tags
#     — NO code, so it round-trips byte-exact and can never double-emit).
#   - Re-importing that .gd recovers `is_family` (the family survives the .gd ↔ sheet round-trip).
#   - `family_group()` derives the runtime group from the class name (Enemy → "family_enemy").
#   - A family-scoped event (a PickFilter over the family group) compiles to a loop over
#     get_tree().get_nodes_in_group("family_enemy") — the abstraction's whole point: logic-per-type.
@tool
extends RefCounted
class_name FamiliesTest

static func run() -> bool:
	var all_passed: bool = true

	# ── A family sheet emits the @ace_family marker + derives its group ──
	var family: EventSheetResource = EventSheetResource.new()
	family.host_class = "Node2D"
	family.custom_class_name = "Enemy"
	family.is_family = true
	family.variables = {"health": {"type": "int", "default": 100, "exported": true}}
	var family_out: String = str(SheetCompiler.compile(family, "user://__family_enemy.gd").get("output", ""))
	all_passed = _check("family sheet emits `## @ace_family(Enemy)`",
		family_out.contains("## @ace_family(Enemy)"), true) and all_passed
	all_passed = _check("family group derives from the class name",
		family.family_group() == "family_enemy", true) and all_passed
	all_passed = _check("the family flag emits NO add_to_group code (membership is an explicit action)",
		family_out.contains("add_to_group"), false) and all_passed

	# ── Round-trip: re-importing the compiled .gd recovers the family flag ──
	var reimported: EventSheetResource = GDScriptImporter.new().import_external_source(family_out)
	all_passed = _check("re-importing the .gd recovers is_family", reimported.is_family, true) and all_passed
	# Byte gate: an opened .gd recompiles to itself EXACTLY — pins the @ace_family marker's PLACEMENT
	# (not just its presence), so it can't drift or double-emit. Must go through the real opened-file path:
	# write to a .gd, import_external (which sets external_source_path), then recompile via the
	# order-preserving external path (the same lossless route every opened .gd takes).
	var rt_path: String = "user://__family_rt.gd"
	var rt_file: FileAccess = FileAccess.open(rt_path, FileAccess.WRITE)
	rt_file.store_string(family_out)
	rt_file.close()
	var reopened: EventSheetResource = GDScriptImporter.new().import_external(rt_path)
	var recompiled: String = str(SheetCompiler.compile(reopened, "user://__family_rt2.gd").get("output", ""))
	all_passed = _check("the family .gd recompiles byte-identically (opened-file round-trip)", recompiled == family_out, true) and all_passed
	all_passed = _check("a non-family sheet stays non-family after round-trip",
		not _roundtrip_is_family("Plain", false), true) and all_passed

	# ── A family-scoped event compiles to a loop over the family group ──
	var game: EventSheetResource = EventSheetResource.new()
	game.host_class = "Node2D"
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnProcess"
	var pick: PickFilter = PickFilter.new()
	pick.collection_kind = PickFilter.CollectionKind.GROUP
	pick.collection_value = family.family_group()  # "family_enemy"
	pick.iterator_name = "enemy"
	event.pick_filters.append(pick)
	event.actions.append(_raw_action("enemy.modulate = Color.RED"))
	game.events.append(event)
	var game_out: String = str(SheetCompiler.compile(game, "user://__family_game.gd").get("output", ""))
	all_passed = _check("family-scoped event compiles to a group loop",
		game_out.contains("for enemy in get_tree().get_nodes_in_group(\"family_enemy\"):"), true) and all_passed
	all_passed = _check("the per-instance action runs inside the loop body",
		game_out.contains("enemy.modulate = Color.RED"), true) and all_passed

	# ── A family flag with no class name warns (it would silently be no family at all) ──
	var unnamed: EventSheetResource = EventSheetResource.new()
	unnamed.host_class = "Node2D"
	unnamed.is_family = true  # but no custom_class_name
	var unnamed_result: Dictionary = SheetCompiler.compile(unnamed, "user://__family_unnamed.gd")
	var warned: bool = false
	for warning: String in unnamed_result.get("warnings", []):
		if warning.contains("Family") and warning.contains("class name"):
			warned = true
	all_passed = _check("a Family with no class name warns", warned, true) and all_passed

	return all_passed

## Compiles a one-class sheet with the given family flag, re-imports it, and returns the recovered flag.
static func _roundtrip_is_family(class_id: String, flag: bool) -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	sheet.custom_class_name = class_id
	sheet.is_family = flag
	var out: String = str(SheetCompiler.compile(sheet, "user://__family_rt.gd").get("output", ""))
	return GDScriptImporter.new().import_external_source(out).is_family

## A self-contained per-instance action: the codegen_template carries the whole statement (no params),
## so it emits verbatim inside the family loop.
static func _raw_action(statement: String) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "RawStatement"
	action.codegen_template = statement
	return action

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] families_test: %s" % label)
		return true
	print("[FAIL] families_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
