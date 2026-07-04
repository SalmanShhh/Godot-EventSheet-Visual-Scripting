# EventForge - starter recipes in the New Behaviour dialog. Beyond the teaching skeleton, "Start
# from" offers small COMPLETE behaviours (cooldown, stat pool) with every verb annotated. Pins: each
# recipe's source actually parses as GDScript, opening one as a sheet absorbs its trigger signals and
# renders its verbs as annotation shells (it reads code-free immediately), the vocabulary counts are
# what the label promises, and the dispatch + dialog wiring (index-stable RECIPES, unknown id falls
# back to the skeleton).
@tool
class_name RecipeScaffoldTest
extends RefCounted


static func run() -> bool:
	var ok: bool = true

	# ── Every recipe's source parses ──
	for recipe: Dictionary in EventSheetBehaviourAddonScaffold.RECIPES:
		var source: String = EventSheetBehaviourAddonScaffold.generate_recipe(
			str(recipe.get("id")), "ZzTestRecipe", "Node", "", "")
		var script: GDScript = GDScript.new()
		script.source_code = source
		ok = _check("recipe '%s' parses" % str(recipe.get("id")), script.reload() == OK, true) and ok

	# ── Unknown id falls back to the teaching skeleton ──
	ok = _check("unknown recipe id falls back to the skeleton",
		EventSheetBehaviourAddonScaffold.generate_recipe("nope", "ZzX", "Node").contains("Do The Thing"), true) and ok

	# ── The cooldown recipe opened AS A SHEET reads code-free ──
	var cooldown: String = EventSheetBehaviourAddonScaffold.generate_recipe("cooldown", "ZzCooldown", "Node", "Ability", "")
	var sheet: EventSheetResource = GDScriptImporter.new().import_external_source(cooldown)
	var counts: Dictionary = SheetIdentityBanner.manifest_for(sheet)
	ok = _check("cooldown publishes 2 triggers", int(counts.get("triggers", 0)), 2) and ok
	ok = _check("cooldown publishes 2 actions", int(counts.get("actions", 0)), 2) and ok
	ok = _check("cooldown publishes 2 conditions", int(counts.get("conditions", 0)), 2) and ok
	ok = _check("cooldown publishes 2 expressions", int(counts.get("expressions", 0)), 2) and ok
	ok = _check("cooldown exposes its duration knob", int(counts.get("knobs", 0)), 1) and ok
	var trigger_names: Array = []
	var shell_names: Array = []
	for row: Variant in sheet.events:
		if row is SignalRow and (row as SignalRow).trigger:
			trigger_names.append((row as SignalRow).ace_name)
		elif row is RawCodeRow:
			var shell: Dictionary = ViewportRowBuilder.define_shell_info((row as RawCodeRow).code)
			if not shell.is_empty():
				shell_names.append(str(shell.get("name")))
	ok = _check("trigger annotations folded onto the signals", trigger_names.has("On Cooldown Finished"), true) and ok
	ok = _check("verbs render as annotation shells (code-free at a glance)", shell_names.has("Start Cooldown"), true) and ok

	# ── The stat-pool recipe's anatomy ──
	var pool_sheet: EventSheetResource = GDScriptImporter.new().import_external_source(
		EventSheetBehaviourAddonScaffold.generate_recipe("stat_pool", "ZzPool", "Node", "", ""))
	var pool_counts: Dictionary = SheetIdentityBanner.manifest_for(pool_sheet)
	ok = _check("stat pool publishes 3 actions", int(pool_counts.get("actions", 0)), 3) and ok
	ok = _check("stat pool publishes 2 conditions", int(pool_counts.get("conditions", 0)), 2) and ok
	ok = _check("stat pool publishes 2 expressions", int(pool_counts.get("expressions", 0)), 2) and ok

	# ── Dialog wiring: the recipe picker exists, index-aligned to RECIPES ──
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	dock.setup(EventSheetResource.new())
	dock._new_addon_panel.open()
	var option: OptionButton = dock._new_addon_panel._recipe_option
	ok = _check("dialog offers every recipe", option.item_count, EventSheetBehaviourAddonScaffold.RECIPES.size()) and ok
	ok = _check("teaching skeleton is the default", option.selected, 0) and ok
	dock._new_addon_panel._dialog.hide()
	dock.free()

	return ok


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] recipe_scaffold_test: %s" % label)
		return true
	print("[FAIL] recipe_scaffold_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
