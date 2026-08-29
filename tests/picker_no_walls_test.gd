# EventForge - the picker never dead-ends: gates carry a reason and a fix, empty results carry
# nearest matches and recipes.
#
# Three promises pinned here:
#   1. Every GATE (the fixable preconditions that grey a picker entry instead of hiding it) has a
#      one-line reason AND a fix, and both lines are translated in every shipped locale.
#   2. Walking EVERY definition the registry offers, under every gate-tripping context, never
#      yields an entry that is gated without those two lines - no silent wall can be added.
#   3. The empty-result shelves have something to say: the relaxed ranker finds nearest entries,
#      and the guides' self-drawing figures are enumerable as insertable recipes.
#
# And the other half of promise 2, which a walk over the gates alone cannot see: an entry that is
# HIDDEN is not on screen to carry a reason at all, so the reasons an entry may be hidden are a
# closed list, every shipped definition is walked through it, and the answer is proved on a
# definition wearing each mark before the sweep is trusted.
@tool
class_name PickerNoWallsTest
extends RefCounted

const TEMPLATE_PATH := "res://addons/eventsheet/translations/TEMPLATE.csv"
const TRANSLATIONS_DIR := "res://addons/eventsheet/translations"
const SHIPPED_LOCALES: PackedStringArray = ["de", "es", "fr", "it", "ja", "ko", "ru", "zh_CN"]


static func run() -> bool:
	var ok: bool = true
	ok = _test_gate_table() and ok
	ok = _test_gate_translations() and ok
	ok = _test_gate_decisions() and ok
	ok = _test_no_silent_walls() and ok
	ok = _test_nearest_and_recipes() and ok
	# Session caches built here are dropped so a serial run's later tests see cold state.
	EventSheetPickerRecipes.clear_cache()
	EventSheetSceneLights.clear_cache()
	return ok


## Promise 1a: the table itself - every gate carries all four fields, non-empty.
static func _test_gate_table() -> bool:
	var ok: bool = true
	ok = _check("the gate table is not empty", EventSheetPickerGates.GATES.is_empty(), false) and ok
	for gate: Dictionary in EventSheetPickerGates.GATES:
		var gate_id: String = str(gate.get("id", ""))
		ok = _check("gate %s has an id" % gate_id, gate_id.is_empty(), false) and ok
		ok = _check("gate %s has a reason" % gate_id, str(gate.get("reason", "")).is_empty(), false) and ok
		ok = _check("gate %s has a fix label" % gate_id, str(gate.get("fix_label", "")).is_empty(), false) and ok
		ok = _check("gate %s has a fix id" % gate_id, str(gate.get("fix_id", "")).is_empty(), false) and ok
	return ok


## Promise 1b: every reason and fix label is a key of the template AND of every shipped locale,
## with a real translation in the cell (an empty cell is an untranslated string wearing a
## translation's clothes).
static func _test_gate_translations() -> bool:
	var ok: bool = true
	var wanted: PackedStringArray = PackedStringArray()
	for gate: Dictionary in EventSheetPickerGates.GATES:
		wanted.append(str(gate.get("reason", "")))
		wanted.append(str(gate.get("fix_label", "")))
	var template_keys: Dictionary = _csv_keys(TEMPLATE_PATH)
	for key: String in wanted:
		ok = _check("TEMPLATE.csv carries \"%s\"" % key, template_keys.has(key), true) and ok
	for locale: String in SHIPPED_LOCALES:
		var catalog: Dictionary = _csv_translations("%s/%s.csv" % [TRANSLATIONS_DIR, locale])
		for key: String in wanted:
			ok = _check("%s.csv translates \"%s\"" % [locale, key],
				not str(catalog.get(key, "")).strip_edges().is_empty(), true) and ok
	return ok


## Promise 1c: each gate fires exactly where its precondition fails, and nowhere else.
static func _test_gate_decisions() -> bool:
	var ok: bool = true
	var plain_context: Dictionary = {
		"is_behavior_sheet": false, "tool_gate_wired": true, "is_tool_sheet": false,
		"scene_known": false, "has_scene": false, "scene_classes": PackedStringArray(),
	}

	var host_def: ACEDefinition = ACEDefinition.new()
	host_def.provider_id = "Core"
	host_def.id = "BehaviorHost"
	ok = _check("a host verb off a plain sheet is gated",
		str(EventSheetPickerGates.gate_for(host_def, plain_context).get("id", "")),
		EventSheetPickerGates.GATE_BEHAVIOR_HOST) and ok
	var behavior_context: Dictionary = plain_context.duplicate()
	behavior_context["is_behavior_sheet"] = true
	ok = _check("the same verb on a behavior sheet is offered plainly",
		EventSheetPickerGates.gate_for(host_def, behavior_context), {}) and ok

	var editor_def: ACEDefinition = ACEDefinition.new()
	editor_def.provider_id = "Core"
	editor_def.id = "EditorSomething"
	editor_def.category = "Editor Tools: Panels & menus"
	ok = _check("an Editor verb off a game sheet is gated",
		str(EventSheetPickerGates.gate_for(editor_def, plain_context).get("id", "")),
		EventSheetPickerGates.GATE_EDITOR_TOOLS) and ok
	var tool_context: Dictionary = plain_context.duplicate()
	tool_context["is_tool_sheet"] = true
	ok = _check("the same verb on a Tool sheet is offered plainly",
		EventSheetPickerGates.gate_for(editor_def, tool_context), {}) and ok
	var unwired_context: Dictionary = plain_context.duplicate()
	unwired_context["tool_gate_wired"] = false
	ok = _check("no tool provider wired = no tool gate (embedders keep their picker)",
		EventSheetPickerGates.gate_for(editor_def, unwired_context), {}) and ok

	var animation_def: ACEDefinition = ACEDefinition.new()
	animation_def.provider_id = "Core"
	animation_def.id = "PlayAnimation"
	animation_def.ace_type = ACEDefinition.ACEType.ACTION
	animation_def.metadata = {"node_type": "AnimationPlayer"}
	var scene_context: Dictionary = plain_context.duplicate()
	scene_context["scene_known"] = true
	scene_context["has_scene"] = true
	scene_context["scene_classes"] = PackedStringArray(["Node2D", "Sprite2D"])
	var needs_node: Dictionary = EventSheetPickerGates.gate_for(animation_def, scene_context)
	ok = _check("a verb whose node the scene lacks is gated",
		str(needs_node.get("id", "")), EventSheetPickerGates.GATE_NEEDS_NODE) and ok
	ok = _check("that gate names the node class", str(needs_node.get("node_type", "")), "AnimationPlayer") and ok
	ok = _check("the reason line names the class",
		EventSheetPickerGates.reason_text(needs_node).contains("AnimationPlayer"), true) and ok
	ok = _check("the fix line names the class",
		EventSheetPickerGates.fix_text(needs_node).contains("AnimationPlayer"), true) and ok
	var satisfied_context: Dictionary = scene_context.duplicate()
	satisfied_context["scene_classes"] = PackedStringArray(["AnimationPlayer"])
	ok = _check("the scene having the node lifts the gate",
		EventSheetPickerGates.gate_for(animation_def, satisfied_context), {}) and ok
	var subclass_context: Dictionary = scene_context.duplicate()
	subclass_context["scene_classes"] = PackedStringArray(["CharacterBody2D"])
	var body_def: ACEDefinition = ACEDefinition.new()
	body_def.provider_id = "Core"
	body_def.id = "SomeBodyVerb"
	body_def.ace_type = ACEDefinition.ACEType.ACTION
	body_def.metadata = {"node_type": "PhysicsBody2D"}
	ok = _check("a subclass in the scene satisfies the wanted class",
		EventSheetPickerGates.gate_for(body_def, subclass_context), {}) and ok
	ok = _check("an unknown scene gates nothing (a wall on a guess is worse than no wall)",
		EventSheetPickerGates.gate_for(animation_def, plain_context), {}) and ok

	var trigger_def: ACEDefinition = ACEDefinition.new()
	trigger_def.provider_id = "Core"
	trigger_def.id = "OnAnimationFinished"
	trigger_def.ace_type = ACEDefinition.ACEType.TRIGGER
	trigger_def.metadata = {"node_type": "AnimationPlayer"}
	var no_scene_context: Dictionary = plain_context.duplicate()
	no_scene_context["scene_known"] = true
	ok = _check("a node trigger on an unattached sheet is gated on the scene",
		str(EventSheetPickerGates.gate_for(trigger_def, no_scene_context).get("id", "")),
		EventSheetPickerGates.GATE_NEEDS_SCENE) and ok
	var unattached_action: Dictionary = EventSheetPickerGates.gate_for(animation_def, no_scene_context)
	ok = _check("a node action on an unattached sheet stays quiet (no wall of grey)",
		unattached_action, {}) and ok

	# The picker's frozen statics delegate to the same answers, so the two cannot drift.
	ok = _check("host_ace_hidden still answers through the gates",
		ACEPickerDialog.host_ace_hidden("Core", "BehaviorHost", false), true) and ok
	ok = _check("is_editor_tools_category still answers through the gates",
		ACEPickerDialog.is_editor_tools_category("Editor Tools: Project & preferences"), true) and ok
	return ok


## Promise 2: walk EVERY definition the registry offers under gate-tripping contexts - anything
## gated must carry a non-empty reason and fix, and the formatted lines must resolve.
static func _test_no_silent_walls() -> bool:
	var ok: bool = true
	var registry: EventSheetACERegistry = EventSheetACERegistry.new()
	registry.refresh_from_sources([], true)
	var contexts: Array[Dictionary] = [
		{"is_behavior_sheet": false, "tool_gate_wired": true, "is_tool_sheet": false,
			"scene_known": false, "has_scene": false, "scene_classes": PackedStringArray()},
		{"is_behavior_sheet": false, "tool_gate_wired": true, "is_tool_sheet": false,
			"scene_known": true, "has_scene": true, "scene_classes": PackedStringArray(["Node"])},
		{"is_behavior_sheet": false, "tool_gate_wired": true, "is_tool_sheet": false,
			"scene_known": true, "has_scene": false, "scene_classes": PackedStringArray()},
	]
	var gated: int = 0
	var faulty: PackedStringArray = PackedStringArray()
	for definition: ACEDefinition in registry.get_all_definitions():
		for context: Dictionary in contexts:
			var gate: Dictionary = EventSheetPickerGates.gate_for(definition, context)
			if gate.is_empty():
				continue
			gated += 1
			if EventSheetPickerGates.reason_text(gate).strip_edges().is_empty() \
					or EventSheetPickerGates.fix_text(gate).strip_edges().is_empty() \
					or str(gate.get("fix_id", "")).is_empty():
				faulty.append("%s/%s -> %s" % [definition.provider_id, definition.id, str(gate)])
	ok = _check("the walk saw real gates (the contexts trip them)", gated > 0, true) and ok
	ok = _check("no definition is gated without a reason and a fix: %s" % ", ".join(faulty),
		faulty.is_empty(), true) and ok
	ok = _test_nothing_vanishes_for_another_reason(registry) and ok
	return ok


## Promise 2b: the HIDING path, which the gate walk above never touches. A gated entry is on screen
## and says what to do; a hidden one is not on screen at all, so the list of reasons an entry may be
## hidden has to be closed - and it has to be the list the picker actually keeps, not the one the
## comment above it claims.
static func _test_nothing_vanishes_for_another_reason(registry: EventSheetACERegistry) -> bool:
	var allowed: PackedStringArray = PackedStringArray([
		EventSheetPickerGates.HIDDEN_DEPRECATED,
		EventSheetPickerGates.HIDDEN_PROJECT_TEMPLATE,
	])
	var reasons: Dictionary = {}
	var unexpected: PackedStringArray = PackedStringArray()
	for definition: ACEDefinition in registry.get_all_definitions():
		var reason: String = EventSheetPickerGates.hidden_reason(definition)
		if reason.is_empty():
			continue
		reasons[reason] = int(reasons.get(reason, 0)) + 1
		if not allowed.has(reason):
			unexpected.append("%s/%s -> %s" % [definition.provider_id, definition.id, reason])
	_print_hiding_sweep(reasons)
	var ok: bool = _check("no shipped entry is hidden for a reason outside the closed list: %s"
		% ", ".join(unexpected), unexpected.is_empty(), true)
	# Proved by value before it is trusted: the answer really does fire on a definition wearing each
	# mark, so a walk that found nothing cannot pass for having asked nothing.
	ok = _check("a deprecated row is hidden, and says which of the three reasons it is",
		EventSheetPickerGates.hidden_reason(_marked({EventSheetPickerGates.DEPRECATED_META: true})),
		EventSheetPickerGates.HIDDEN_DEPRECATED) and ok
	ok = _check("a project-scoped template is hidden because its per-scene copies are what is listed",
		EventSheetPickerGates.hidden_reason(_marked({EventSheetPickerGates.PROJECT_SCOPED_META: true})),
		EventSheetPickerGates.HIDDEN_PROJECT_TEMPLATE) and ok
	ok = _check("but a copy built FOR a node is offered like anything else",
		EventSheetPickerGates.hidden_reason(_marked({
			EventSheetPickerGates.PROJECT_SCOPED_META: true,
			EventSheetPickerGates.SCENE_TARGET_META: "$Torch",
		})), "") and ok
	ok = _check("and an ordinary row is hidden for nothing at all",
		EventSheetPickerGates.hidden_reason(_marked({})), "") and ok
	return ok


## A definition wearing exactly the metadata under test, so each answer is proved on its own.
static func _marked(metadata: Dictionary) -> ACEDefinition:
	var definition: ACEDefinition = ACEDefinition.new()
	definition.provider_id = "Core"
	definition.id = "PickerGateProbe"
	definition.metadata = metadata
	return definition


## The counts the sweep saw, printed so a run that hid nothing is visible rather than silent.
static func _print_hiding_sweep(reasons: Dictionary) -> void:
	print("[PASS] picker_no_walls_test: the hiding sweep saw %s" % str(reasons))


## Promise 3: the empty-result shelves. The relaxed ranker ranks near-misses the strict filter
## drops, and the guides' figures enumerate as insertable recipes from the shipped bundle.
static func _test_nearest_and_recipes() -> bool:
	var ok: bool = true
	ok = _check("a word that misses no longer disqualifies (strict says 0)",
		EventSheetQuickAdd.score("boss flash", "Flash") == 0, true) and ok
	ok = _check("…while loose still ranks the near half",
		EventSheetQuickAdd.loose_score("boss flash", "Flash") > 0, true) and ok
	ok = _check("loose on a total miss is still 0",
		EventSheetQuickAdd.loose_score("zzqqxx", "Flash"), 0) and ok

	var registry: EventSheetACERegistry = EventSheetACERegistry.new()
	registry.refresh_from_sources([], true)
	var nearest: Array[ACEDefinition] = EventSheetPickerRecipes.nearest_definitions(
		"boss flash", registry.get_all_definitions())
	ok = _check("nearest entries exist for a half-missing query", nearest.is_empty(), false) and ok
	ok = _check("nearest entries are capped",
		nearest.size() <= EventSheetPickerRecipes.NEAREST_LIMIT, true) and ok

	var recipes: Array[Dictionary] = EventSheetPickerRecipes.all_recipes()
	ok = _check("the guides carry recipes (self-drawing figures)", recipes.size() > 0, true) and ok
	for recipe: Dictionary in recipes.slice(0, 5):
		ok = _check("recipe \"%s\" names its page" % str(recipe.get("title", "")),
			str(recipe.get("page_id", "")).is_empty(), false) and ok
		ok = _check("recipe \"%s\" lifts to drawable rows" % str(recipe.get("title", "")),
			EventSheetDocFigures.sheet_for_body(str(recipe.get("body", ""))) != null, true) and ok
	var first_shelf: Array[Dictionary] = EventSheetPickerRecipes.search("")
	ok = _check("an empty query still fills the shelf", first_shelf.is_empty(), false) and ok
	ok = _check("the shelf is capped", first_shelf.size() <= EventSheetPickerRecipes.RECIPES_LIMIT, true) and ok
	return ok


static func _csv_keys(path: String) -> Dictionary:
	var keys: Dictionary = {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return keys
	file.get_csv_line()
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if row.size() >= 1 and not row[0].is_empty():
			keys[row[0]] = true
	return keys


static func _csv_translations(path: String) -> Dictionary:
	var catalog: Dictionary = {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return catalog
	file.get_csv_line()
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if row.size() >= 2 and not row[0].is_empty():
			catalog[row[0]] = row[1]
	return catalog


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] picker_no_walls_test: %s" % label)
		return true
	print("[FAIL] picker_no_walls_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
