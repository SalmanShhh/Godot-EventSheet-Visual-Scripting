# Godot EventSheets — Inspector grouping survives a .gd round-trip.
#
# Before: a grouped @export var's @export_group/@export_subgroup lines couldn't be lifted, so on reopen the
# variable degraded into a stray @export_group GDScript BLOCK + an ungrouped variable (violating "no GDScript
# block" + losing the grouping UX). Now the importer absorbs those lines onto the tree variable's attributes
# (gated by the verify-lift rule, so it's byte-safe). This pins that a grouped var reopens as a clean grouped
# variable, the group/subgroup are recovered, and re-emission reproduces the exact source.
@tool
extends RefCounted
class_name VariableGroupRoundtripTest

static func run() -> bool:
	var all_passed: bool = true

	var source: String = "extends Node2D\n\n@export_group(\"Combat\")\n@export_subgroup(\"Melee\")\n@export var attack: int = 10\n"
	var sheet: EventSheetResource = GDScriptImporter.new().import_external_source(source)

	var lifted: LocalVariable = null
	var has_group_block: bool = false
	for entry: Variant in sheet.events:
		if entry is LocalVariable and (entry as LocalVariable).name == "attack":
			lifted = entry as LocalVariable
		if entry is RawCodeRow and (entry as RawCodeRow).code.contains("@export_group"):
			has_group_block = true

	all_passed = _check("a grouped @export var lifts to a LocalVariable (not a block)", lifted != null, true) and all_passed
	all_passed = _check("no stray @export_group GDScript block remains", has_group_block, false) and all_passed
	if lifted != null:
		all_passed = _check("group recovered onto the variable",
			str((lifted.attributes as Dictionary).get("group", "")), "Combat") and all_passed
		all_passed = _check("subgroup recovered onto the variable",
			str((lifted.attributes as Dictionary).get("subgroup", "")), "Melee") and all_passed
		# Byte-stability: re-emitting the variable reproduces the exact source lines (the verify-lift guarantee).
		all_passed = _check("re-emits the group lines exactly (lossless round-trip)",
			SheetCompiler._emit_tree_variable_line(lifted),
			"@export_group(\"Combat\")\n@export_subgroup(\"Melee\")\n@export var attack: int = 10") and all_passed
		# And the reopened grouped tree variable shows its "Group › Subgroup" chip in the sheet.
		var viewport: EventSheetViewport = EventSheetViewport.new()
		var row: EventRowData = viewport._build_tree_variable_row(lifted, 0)
		var has_chip: bool = false
		for span: Variant in row.spans:
			var meta: Dictionary = (span as SemanticSpan).metadata if (span as SemanticSpan).metadata is Dictionary else {}
			if str((span as SemanticSpan).text) == "Combat › Melee" and bool(meta.get("badge", false)):
				has_chip = true
		all_passed = _check("reopened grouped tree var shows its chip", has_chip, true) and all_passed
		viewport.free()

	# A plain (ungrouped) var is unaffected: lifts clean, no attributes, single-line emission.
	var plain_sheet: EventSheetResource = GDScriptImporter.new().import_external_source("extends Node2D\n\n@export var speed: float = 5.0\n")
	var plain: LocalVariable = null
	for entry: Variant in plain_sheet.events:
		if entry is LocalVariable and (entry as LocalVariable).name == "speed":
			plain = entry as LocalVariable
	all_passed = _check("an ungrouped var still lifts cleanly", plain != null, true) and all_passed
	if plain != null:
		all_passed = _check("an ungrouped var carries no group attributes", (plain.attributes as Dictionary).is_empty(), true) and all_passed
		all_passed = _check("an ungrouped var emits a single line",
			SheetCompiler._emit_tree_variable_line(plain), "@export var speed: float = 5.0") and all_passed

	return all_passed

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] variable_group_roundtrip_test: %s" % label)
		return true
	print("[FAIL] variable_group_roundtrip_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
