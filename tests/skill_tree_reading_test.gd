# EventForge - the SKILL TREE: the data asset, the Upgrades tree words, the skill wording
# on the Abilities pack, the readings that recognise a hand-written tree, the Doctor's three checks
# and the screen starter.
#
# Every pin here is a VALUE - a sentence, a number, a message - rather than a count, so a failure
# says which word or which number moved.
@tool
class_name SkillTreeReadingTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const FIXTURE := "res://tests/fixtures/opened_script_skill_tree.gd"
const UPGRADES_PACK := "res://eventsheet_addons/upgrades/upgrades_addon.gd"
const ABILITIES_PACK := "res://eventsheet_addons/abilities/abilities_behavior.gd"
const STAT_FORGE_PACK := "res://eventsheet_addons/stat_forge/stat_forge_behavior.gd"
const TREE_ASSET := "res://demo/showcase/skill_tree/adventurer_tree.tres"

## The file-level fact every tree reading is gated on, as the fixture states it.
const TREE_CONTEXT: Dictionary = {"unlocked_tables": {"unlocked": true}}


static func run() -> bool:
	var all_passed: bool = true
	all_passed = _test_grammar() and all_passed
	all_passed = _test_gating() and all_passed
	all_passed = _test_pattern_claim() and all_passed
	all_passed = _test_round_trip() and all_passed
	all_passed = _test_upgrades_pack() and all_passed
	all_passed = _test_abilities_wording() and all_passed
	all_passed = _test_doctor() and all_passed
	all_passed = _test_starter() and all_passed
	all_passed = _test_showcase_asset() and all_passed
	return all_passed


## The sentences themselves.
static func _test_grammar() -> bool:
	var passed: bool = true
	var learned: Dictionary = EventSheetSentence.condition("unlocked.has(\"double_jump\")", TREE_CONTEXT)
	passed = _check("an unlocked lookup reads under the Skills object", str(learned.get("object", "")), "Skills") and passed
	passed = _check("an unlocked lookup reads as Is unlocked", _words(learned), "Is unlocked \"double jump\"") and passed
	passed = _check("the reading claims the skill tree", str(learned.get("pattern", "")), "skill_tree") and passed
	passed = _check("the reading offers the Upgrades pack", str(learned.get("adoptable", "")), "upgrades") and passed
	var missing: Dictionary = EventSheetSentence.condition("not unlocked.has(required)", TREE_CONTEXT)
	passed = _check("the prerequisite walk reads as Is not unlocked", _words(missing), "Is not unlocked required") and passed
	passed = _check("a stat with an upgrade level inside reads as one sentence",
		EventSheetSentence.expression_text("base_speed * (1.0 + level_of(\"speed\") * 0.1)", {}),
		"base_speed boosted by Speed upgrade (10% per level)") and passed
	passed = _check("a whole-number multiplier keeps its round per-cent",
		EventSheetSentence.expression_text("damage * (1.0 + upgrades.level_of(\"power\") * 0.25)", {}),
		"damage boosted by Power upgrade (25% per level)") and passed
	passed = _check("a flat amount per level reads as one sentence",
		EventSheetSentence.expression_text("base_damage + 5.0 * level_of(\"power\")", {}),
		"base_damage +5 per level") and passed
	passed = _check("an upgrade name is the reader's name for it",
		EventSheetSentence.skill_level_call_name("upgrades.level(\"fire_rate\")"), "Fire Rate") and passed
	return passed


## The gates: every one of these readings must REFUSE the lines it was not written for, because each
## of them is a spelling ordinary code uses for something else entirely.
static func _test_gating() -> bool:
	var passed: bool = true
	passed = _check("a lookup in a file that keeps no unlocked table is left alone",
		EventSheetSentence.skill_tree_condition("unlocked.has(\"double_jump\")", {}).is_empty(), true) and passed
	passed = _check("a lookup in a table this file does not own is left alone",
		EventSheetSentence.skill_tree_condition("doors.has(\"gate\")", TREE_CONTEXT).is_empty(), true) and passed
	passed = _check("an ordinary percentage is not an upgrade",
		EventSheetSentence.skill_boost_words("base * (1.0 + wetness * 0.1)"), "") and passed
	passed = _check("an ordinary product is not an upgrade",
		EventSheetSentence.skill_boost_words("base + 5.0 * combo"), "") and passed
	passed = _check("a level call with no id is not an upgrade",
		EventSheetSentence.skill_level_call_name("level_of(current)"), "") and passed
	# The whole-file gate itself: a table of flags is a table of flags.
	var flags: PackedStringArray = PackedStringArray(["var flags: Dictionary = {}", "flags[\"seen\"] = true"])
	passed = _check("a file with flags and no tree keeps its flags",
		EventSheetPatternReadings.skill_tree_facts(flags).is_empty(), true) and passed
	var doors: PackedStringArray = PackedStringArray(["var doors: Dictionary = {}",
		"doors[\"gate\"] = true", "if skill_points > 0:"])
	passed = _check("a tree's marks do not make a neighbouring dictionary a tree",
		EventSheetPatternReadings.skill_tree_facts(doors).is_empty(), true) and passed
	var tree: PackedStringArray = PackedStringArray(["var unlocked: Dictionary = {}",
		"unlocked[id] = true", "skill_points -= cost"])
	passed = _check("the tree's own table is found", EventSheetPatternReadings.skill_tree_facts(tree),
		{"unlocked_tables": {"unlocked": true}}) and passed
	return passed


## The pattern id exists, and the fixture claims it with the Upgrades pack to adopt.
static func _test_pattern_claim() -> bool:
	var passed: bool = true
	passed = _check("the skill tree is a pattern the readings may claim",
		EventSheetPatternFacts.PATTERN_IDS.has("skill_tree"), true) and passed
	passed = _check("the offered pack has a name a reader would recognise",
		EventSheetPatternVocabulary.pack_label("upgrades"), "Upgrades") and passed
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(FIXTURE)
	EventSheetPatternFacts.clear(sheet)
	EventSheetViewportReadingRows.claim_godot_systems_patterns(sheet)
	var words: String = ""
	var adoptable: String = ""
	for claim: Variant in EventSheetPatternFacts.claims(sheet):
		if str((claim as Dictionary).get("pattern", "")) != "skill_tree":
			continue
		words = str((claim as Dictionary).get("words", ""))
		adoptable = EventSheetPatternVocabulary.adoptable_for(claim as Dictionary)
	passed = _check("the fixture claims the skill tree in the sheet's words", words,
		"A skill tree - prerequisites, points and unlocks") and passed
	passed = _check("the claim offers the Upgrades pack", adoptable, "upgrades") and passed
	EventSheetPatternFacts.clear(sheet)
	return passed


## Display only: opening the fixture and writing it back must not move a byte.
static func _test_round_trip() -> bool:
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(FIXTURE)
	var reopened: String = str(SheetCompiler.compile(sheet, FIXTURE).get("output", ""))
	return _check("the hand-written tree re-emits byte for byte",
		reopened == FileAccess.get_file_as_string(FIXTURE), true)


## The pack's own answers, pinned as the numbers a player would see.
static func _test_upgrades_pack() -> bool:
	var passed: bool = true
	var upgrades: Node = (load(UPGRADES_PACK) as GDScript).new()
	var stats: Node = (load(STAT_FORGE_PACK) as GDScript).new()
	upgrades.apply_grants_to(stats)
	stats.set_stat_base("speed", 100.0)
	upgrades.load_skill_tree(load(TREE_ASSET))
	passed = _check("loading a tree hands over its starting points", upgrades.skill_points_left(), 4) and passed
	passed = _check("the tree names itself", upgrades.skill_tree_name(), "Adventurer") and passed
	passed = _check("the tree holds its skills", upgrades.skill_count(), 6) and passed
	passed = _check("a skill knows what it needs first", upgrades.skill_requires_text("sprint"), "swift") and passed
	passed = _check("the tree answers what a skill requires", upgrades.skill_requires("sprint", "swift"), true) and passed
	passed = _check("a root skill requires nothing", upgrades.skill_requires_text("toughness"), "") and passed
	passed = _check("depth is counted from the roots", upgrades.skill_depth_of("sprint"), 2) and passed
	# The order is enforced: a skill whose prerequisite is missing refuses, and costs nothing.
	upgrades.unlock_skill("sprint")
	passed = _check("a skill with an unmet prerequisite refuses", upgrades.is_skill_unlocked("sprint"), false) and passed
	passed = _check("a refused unlock spends nothing", upgrades.skill_points_left(), 4) and passed
	passed = _check("the refusal names the skill", upgrades.last_skill_id(), "sprint") and passed
	passed = _check("affording a skill is not the same as being allowed it",
		upgrades.can_afford_skill("sprint"), true) and passed
	passed = _check("but it cannot be unlocked", upgrades.can_unlock_skill("sprint"), false) and passed
	upgrades.unlock_skill("toughness")
	upgrades.unlock_skill("swift")
	passed = _check("unlocking spends the cost", upgrades.skill_points_left(), 2) and passed
	passed = _check("the level is recorded", upgrades.skill_level_of("swift"), 1) and passed
	passed = _check("a grant reaches the stat stack", snappedf(stats.stat_total("speed"), 0.001), 110.0) and passed
	upgrades.unlock_skill("swift")
	passed = _check("a second level replaces the first rather than stacking beside it",
		snappedf(stats.stat_total("speed"), 0.001), 121.0) and passed
	passed = _check("a capped skill refuses a fourth level", upgrades.skill_max_level_of("swift"), 3) and passed
	passed = _check("the grants cell is handed back in the asset's own words",
		upgrades.skill_grants_text("swift"), "speed x1.1 per level") and passed
	passed = _check("a perk grants nothing at all", upgrades.skill_grants_text("double_jump"), "") and passed
	passed = _check("two skills are unlocked", upgrades.unlocked_skill_count(), 2) and passed
	# Respec: every point back, every unlock gone, every grant taken off the stack.
	upgrades.respec()
	passed = _check("respec refunds every point spent", upgrades.skill_points_left(), 4) and passed
	passed = _check("respec clears the table", upgrades.unlocked_skill_count(), 0) and passed
	passed = _check("respec takes the grants back", stats.stat_total("speed"), 100.0) and passed
	# Skill points as a Currency Ledger account: the number lives there instead.
	var ledger: Node = (load("res://eventsheet_addons/currency_ledger/currency_ledger_addon.gd") as GDScript).new()
	ledger.define_currency("skill_points", 7.0, -1.0)
	passed = _check("an account holds what it was given", ledger.balance("skill_points"), 7.0) and passed
	upgrades.free()
	stats.free()
	ledger.free()
	return passed


## The skill wording on the Abilities pack answers exactly what the ability wording does.
static func _test_abilities_wording() -> bool:
	var passed: bool = true
	var abilities: Node = (load(ABILITIES_PACK) as GDScript).new()
	abilities.create_ability_with_stacks("dash", 2.0, 2, true)
	passed = _check("a fresh skill is ready", abilities.is_skill_ready("dash"), true) and passed
	passed = _check("its charges are the stacks it was created with", abilities.skill_charges("dash"), 2) and passed
	abilities.use_skill("dash")
	passed = _check("using a skill consumes a charge", abilities.skill_charges("dash"), 1) and passed
	abilities.use_skill("dash")
	passed = _check("the last charge goes too", abilities.skill_charges("dash"), 0) and passed
	passed = _check("a spent skill is not ready", abilities.is_skill_ready("dash"), false) and passed
	abilities.free()
	return passed


## The three ways a tree is wrong, said out loud.
static func _test_doctor() -> bool:
	var passed: bool = true
	var good: Array[Dictionary] = []
	EventSheetProjectDoctor.check_skill_tree_rows("res://tree.tres", [
		{"id": "root", "requires": "", "grants": "speed x1.1"},
		{"id": "leaf", "requires": "root", "grants": "jump +1"}
	], "", good)
	passed = _check("a sound tree says nothing", good.size(), 0) and passed
	var missing: Array[Dictionary] = []
	EventSheetProjectDoctor.check_skill_tree_rows("res://tree.tres", [
		{"id": "leaf", "requires": "roto", "grants": "jump +1"}
	], "", missing)
	passed = _check("a prerequisite that is not in the tree is an error",
		str(missing[0].get("severity", "")), "error") and passed
	passed = _check("and it names both ends of the mistake",
		str(missing[0].get("message", "")).begins_with("\"leaf\" requires \"roto\", which is not a skill in this tree."), true) and passed
	var cycle: Array[Dictionary] = []
	EventSheetProjectDoctor.check_skill_tree_rows("res://tree.tres", [
		{"id": "a", "requires": "b", "grants": "speed x1.1"},
		{"id": "b", "requires": "a", "grants": "speed x1.1"}
	], "", cycle)
	passed = _check("a cycle is an error at both ends", cycle.size(), 2) and passed
	passed = _check("and it says what a cycle costs",
		str(cycle[0].get("message", "")).contains("permanently locked"), true) and passed
	passed = _check("the cycle walk answers yes",
		EventSheetProjectDoctor.skill_tree_cycle("a", {"a": PackedStringArray(["b"]), "b": PackedStringArray(["a"])}), true) and passed
	passed = _check("and no for a tree that only branches",
		EventSheetProjectDoctor.skill_tree_cycle("a", {"a": PackedStringArray(["b"]), "b": PackedStringArray()}), false) and passed
	var duplicate: Array[Dictionary] = []
	EventSheetProjectDoctor.check_skill_tree_rows("res://tree.tres", [
		{"id": "a", "requires": "", "grants": "speed x1.1"},
		{"id": "a", "requires": "", "grants": "jump +1"}
	], "", duplicate)
	passed = _check("a repeated id is an error", str(duplicate[0].get("severity", "")), "error") and passed
	var pointless: Array[Dictionary] = []
	EventSheetProjectDoctor.check_skill_tree_rows("res://tree.tres", [
		{"id": "ghost", "requires": "", "grants": ""}
	], "", pointless)
	passed = _check("a skill that grants nothing and is never read is a warning",
		str(pointless[0].get("severity", "")), "warning") and passed
	var perk: Array[Dictionary] = []
	EventSheetProjectDoctor.check_skill_tree_rows("res://tree.tres", [
		{"id": "double_jump", "requires": "", "grants": ""}
	], "if unlocked.has(\"double_jump\"):", perk)
	passed = _check("a perk a script asks about is not a complaint", perk.size(), 0) and passed
	return passed


## The screen starter.
static func _test_starter() -> bool:
	var passed: bool = true
	var sheet: EventSheetResource = EventSheetStarterTemplates.build_starter(34)
	passed = _check("the skill tree screen is a Control", sheet.host_class, "Control") and passed
	passed = _check("it names itself", sheet.custom_class_name, "SkillTreeScreen") and passed
	passed = _check("it asks for the asset it draws",
		(sheet.variables.get("tree", {}) as Dictionary).get("exported", false), true) and passed
	passed = _check("and marks it required so an empty slot warns in the Inspector",
		((sheet.variables.get("tree", {}) as Dictionary).get("attributes", {}) as Dictionary).get("required", false), true) and passed
	var function_names: PackedStringArray = PackedStringArray()
	for entry: Variant in sheet.functions:
		if entry is EventFunction:
			function_names.append((entry as EventFunction).function_name)
	passed = _check("it lays out, refreshes, hovers and draws", ", ".join(function_names),
		"lay_out, refresh_states, show_grants, _draw") and passed
	var compiled: Dictionary = SheetCompiler.compile(sheet, "user://skill_tree_screen_probe.gd")
	passed = _check("the starter compiles", bool(compiled.get("success", false)), true) and passed
	var output: String = str(compiled.get("output", ""))
	passed = _check("a click is one Unlock row", output.contains("Upgrades.unlock_skill("), true) and passed
	passed = _check("the points label is filled through the HUD Kit",
		output.contains("$HudKitBehavior.set_text(points_label"), true) and passed
	passed = _check("the asset is loaded into the tree words",
		output.contains("Upgrades.load_skill_tree(tree)"), true) and passed
	passed = _check("nothing ships an unbaked row id", output.contains("{uid}"), false) and passed
	# The FileSystem dialog offers it under the same words the New-Sheet menu uses.
	var labels: PackedStringArray = PackedStringArray()
	for starter: Dictionary in EventSheetStarterTemplates.create_new_starters():
		if int(starter.get("id", 0)) == 34:
			labels.append(str(starter.get("label", "")))
	passed = _check("the Create New dialog offers it too", ", ".join(labels), "Skill Tree Screen") and passed
	return passed


## The showcase tree: the numbers the guide and the smoke both quote.
static func _test_showcase_asset() -> bool:
	var passed: bool = true
	var asset: Resource = load(TREE_ASSET)
	passed = _check("the showcase tree is named", str(asset.get("tree_name")), "Adventurer") and passed
	passed = _check("it opens with four points", int(asset.get("starting_points")), 4) and passed
	var ids: PackedStringArray = PackedStringArray()
	for row: Variant in (asset.get("skills") as Array):
		ids.append(str((row as Dictionary).get("id", "")))
	passed = _check("it holds two branches of three", ", ".join(ids),
		"toughness, swift, sprint, agility, double_jump, wall_jump") and passed
	passed = _check("it is a data asset the editor can open as a table",
		EventSheetDataTable.is_data_asset(TREE_ASSET), true) and passed
	var columns: PackedStringArray = PackedStringArray()
	for column: Variant in EventSheetDataTable.columns_of(asset):
		columns.append(str((column as Dictionary).get("name", "")))
	passed = _check("with the columns the asset declares", ", ".join(columns),
		"starting_points, tree_name, skills") and passed
	return passed


## The words a reading says, with the object left off - what a row prints in its lane.
static func _words(reading: Dictionary) -> String:
	var text: String = ""
	for segment: Variant in (reading.get("segments", []) as Array):
		text += str((segment as Dictionary).get("text", ""))
	return text


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("skill_tree_reading_test", label, actual, expected)
