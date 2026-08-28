# Godot EventSheets - every shipped pack opens as a sheet WITH its verbs.
#
# Opening a pack .gd the way the dock does (GDScriptImporter.import_external) must lift its
# published verbs into EventFunctions (the two-lane verb rows) rather than leaving them as
# annotation-shell code blocks - and the reopened sheet must compile back to the exact bytes.
# Measured 2026-08-17 before the fix: 38 of 91 packs opened with ZERO verbs (the FPS Controller,
# Save System, Storylet Weaver, ...) because a lifecycle handler after the verbs, an unknown
# codegen prefix, a class doc glued to the first verb, a Toggle over-match or one bad body each
# reverted the WHOLE file. This pins the fleet-wide numbers so none of it comes back.
@tool
class_name PackOpenLiftTest
extends RefCounted

## Packs that legitimately publish no verbs: data-asset resources and two loaders whose only
## functions are the host binding and _ready. Anything else opening with zero functions fails.
const NO_VERB_PACKS: Array[String] = [
	"ability_set_resource.gd", "encounter_resource.gd", "loot_loader_behavior.gd",
	"loot_table_resource.gd", "price_table_resource.gd", "quest_resource.gd",
	"random_table_resource.gd", "skin_catalog_loader_behavior.gd", "skin_catalog_resource.gd",
	"stat_sheet_resource.gd", "storylet_resource.gd", "touch_shape_library_resource.gd",
	"uhtn_plan_resource.gd", "color_palette_resource.gd", "skill_tree_resource.gd",
	"quality_preset.gd",
]
## Verbs the lifter still cannot reproduce byte-exactly (one function each - an async loop guard,
## an @ace_param header, two Line of Sight helpers, one Drawing Canvas verb). Each stays a raw block
## while every OTHER verb in its file lifts. Shrink this list, never grow it.
const KNOWN_SHORT: Dictionary = {
	"drawing_canvas_behavior.gd": 1, "event_bus_addon.gd": 1, "line_of_sight_behavior.gd": 1,
	"line_of_sight_3d_behavior.gd": 1, "named_scenes_addon.gd": 1,
}


static func run() -> bool:
	var all_passed: bool = true
	var total_verbs: int = 0
	var lifted_verbs: int = 0
	var packs: int = 0
	for dir: String in DirAccess.get_directories_at("res://eventsheet_addons"):
		for file_name: String in DirAccess.get_files_at("res://eventsheet_addons/" + dir):
			if not file_name.ends_with(".gd"):
				continue
			var path: String = "res://eventsheet_addons/%s/%s" % [dir, file_name]
			var source: String = FileAccess.get_file_as_string(path)
			var declared: int = 0
			for line: String in source.split("\n"):
				if line == "## @ace_action" or line == "## @ace_condition" or line == "## @ace_expression":
					declared += 1
			var sheet: EventSheetResource = GDScriptImporter.new().import_external(path)
			packs += 1
			var exposed: int = 0
			for function: Variant in sheet.functions:
				if function is EventFunction and (function as EventFunction).expose_as_ace:
					exposed += 1
			total_verbs += declared
			lifted_verbs += exposed
			var allowed_short: int = int(KNOWN_SHORT.get(file_name, 0))
			all_passed = _check("%s opens with its verbs (%d of %d declared)" % [file_name, exposed, declared], exposed >= declared - allowed_short, true) and all_passed
			if NO_VERB_PACKS.has(file_name):
				all_passed = _check("%s publishes no verbs (data asset / loader)" % file_name, declared, 0) and all_passed
			else:
				all_passed = _check("%s lifts at least one function" % file_name, sheet.functions.size() > 0, true) and all_passed
			var reopened: String = str(SheetCompiler.compile(sheet, path).get("output", ""))
			all_passed = _check("%s reopened sheet compiles back byte-identically" % file_name, reopened == source, true) and all_passed
	# Batch 13 added two packs (Touch Gestures and its shape-library data asset): 93 + 2.
	# The leftovers parcel added the colour-palette data asset: + 1. Recomputed as base + deltas.
	# Batch 14: Pin 3D (+1), the skill-tree data asset (+1), Skateboard + Skateboard 3D (+2), the
	# two Traversal Kits (+2), on the colour-palette asset (+1) and the two gesture packs (+2).
	# Recomputed as base + deltas.
	# Lighting: Light Flicker, Light Pulse and Day/Night Cycle (+3). Recomputed as base + deltas.
	# Effects: Hit Flash, Dissolve, Outline, Grayscale, Wave and Screen FX (+6). Same recomputation.
	# Rendering: the Quality Preset data asset (+1). Same recomputation.
	all_passed = _check("the fleet was scanned (112 packs)", packs, 93 + 2 + 1 + 1 + 1 + 2 + 2 + 3 + 6 + 1) and all_passed
	all_passed = _check("fleet-wide verb lift is at least 1264 of the declared verbs (measured floor)", lifted_verbs >= 1264, true) and all_passed
	# Batch 13: +3 Advanced Random pity verbs (kits 1) and +19 Touch Gestures verbs (kits 2)
	# on the 1283 base: 1283 + 3 + 19 = 1305. Recomputed as base + both deltas at merge.
	# The leftovers parcel: +2 FPS Controller verbs (the firing slowdown and its question).
	# The colour-palette pack adds none - it is a data asset and publishes no verbs.
	# The boomer parcel: +4 FPS Controller verbs; pins: +14 Pin, +24 Pin 3D; skills: +26 Upgrades,
	# +3 Abilities; skateboard: +32 Skateboard, +34 Skateboard 3D, +7 Combo Box chain rows, +1 HUD
	# Kit needle; traversal: +21 Traversal Kit, +22 on its 3D twin (the same words plus Float);
	# combos: +4 more Combo Box rows - the move table (Set / Clear Animation For Combo) and the
	# two that read it back (Combo Has Animation, Animation For Combo).
	# lighting: +3 Light Flicker (start, stop, is flickering), +3 Light Pulse (the same three), and
	# +6 Day/Night Cycle (set the time, run the clock faster, pause, resume, it is day, it is night).
	# effects: +3 Hit Flash (flash, stop, is flashing), +4 Dissolve (dissolve, appear, is gone, burnt
	# away), +4 Outline (outline, no outline, fade outline, is outlined), +4 Grayscale (grayscale,
	# recolour, is gray, grayness), +4 Wave (wave, settle, is waving, wave strength) and +7 Screen FX
	# (shockwave, fade to, fade back, blur, chromatic pulse, clear, is running).
	# rendering: +7 Game Settings quality verbs (apply a preset, step one, the folder's paths and
	# words, the preset in force, the word to show, and the question about it). The Quality Preset
	# asset itself adds none - it is data.
	# options menus: +30 more Game Settings verbs - the binding pair (bind a control, why a control
	# and a setting disagree), the page four (a setting's page, its label, the settings on a page,
	# the rows built from them) plus the focus pair (wire the order, what nothing can reach), the
	# way-back four (apply with one, keep, go back, seconds left), and eighteen for rebinding: the
	# Input Map's own actions, the two binding words, the unbound list and its question, the two
	# conflict readings, whether a row is listening, listen, the three answers, cancel, the two
	# resets, save, load, and the page built from the Input Map.
	# Recomputed as base + every delta at merge.
	all_passed = _check("fleet-wide declared verbs count", total_verbs,
		1283 + 3 + 19 + 2 + 4 + 38 + 26 + 3 + 32 + 34 + 7 + 1 + 21 + 22 + 4 + 3 + 3 + 6
		+ 3 + 4 + 4 + 4 + 4 + 7 + 7 + 30) and all_passed
	# The file that started it: the FPS Controller must open with every one of its verbs.
	var fps: EventSheetResource = GDScriptImporter.new().import_external("res://eventsheet_addons/fps_controller/fps_controller_behavior.gd")
	var fps_exposed: int = 0
	for function: Variant in fps.functions:
		if function is EventFunction and (function as EventFunction).expose_as_ace:
			fps_exposed += 1
	# The leftovers parcel gave the pack Set Move Speed While Firing and Is Firing (31 + 2), and the
	# feel layer four more: Bob With Movement, Sway With Mouse, Set Air Control, Is Bunny Hopping.
	all_passed = _check("FPS Controller opens with all 37 published verbs", fps_exposed, 31 + 2 + 4) and all_passed
	all_passed = _check("FPS Controller's hidden helpers lift too (44 functions in all)", fps.functions.size(), 38 + 2 + 4) and all_passed
	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] pack_open_lift_test: %s" % label)
		return true
	print("[FAIL] pack_open_lift_test: %s (got %s, expected %s)" % [label, str(actual), str(expected)])
	return false
