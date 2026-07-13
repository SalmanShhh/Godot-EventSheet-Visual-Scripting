# Godot EventSheets - Inspector grouping survives a .gd round-trip.
#
# Before: a grouped @export var's @export_group/@export_subgroup lines couldn't be lifted, so on reopen the
# variable degraded into a stray @export_group GDScript BLOCK + an ungrouped variable (violating "no GDScript
# block" + losing the grouping UX). Now the importer absorbs those lines onto the tree variable's attributes
# (gated by the verify-lift rule, so it's byte-safe). This pins that a grouped var reopens as a clean grouped
# variable, the group/subgroup are recovered, and re-emission reproduces the exact source.
@tool
class_name VariableGroupRoundtripTest
extends RefCounted


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

	# Tooltip round-trip: a `## doc` immediately before a var is recovered as the tooltip (Godot's doc
	# convention), not stranded as a block - and it combines with grouping in canonical order.
	var tip_sheet: EventSheetResource = GDScriptImporter.new().import_external_source("extends Node2D\n\n## Player health.\n@export_group(\"Combat\")\n@export var hp: int = 100\n")
	var hp: LocalVariable = null
	var tip_block: bool = false
	for entry: Variant in tip_sheet.events:
		if entry is LocalVariable and (entry as LocalVariable).name == "hp":
			hp = entry as LocalVariable
		if entry is RawCodeRow and (entry as RawCodeRow).code.contains("Player health"):
			tip_block = true
	all_passed = _check("a var tooltip is recovered onto the variable",
		hp != null and str((hp.attributes as Dictionary).get("tooltip", "")) == "Player health.", true) and all_passed
	all_passed = _check("no stray tooltip comment block remains", tip_block, false) and all_passed
	if hp != null:
		all_passed = _check("tooltip re-emits before the group (canonical order)",
			SheetCompiler._emit_tree_variable_line(hp),
			"## Player health.\n@export_group(\"Combat\")\n@export var hp: int = 100") and all_passed

	# A `## @ace_*` annotation immediately before a var is NOT mistaken for a tooltip.
	var anno_sheet: EventSheetResource = GDScriptImporter.new().import_external_source("extends Node2D\n\n## @ace_tags(combat)\n@export var dmg: int = 5\n")
	var dmg: LocalVariable = null
	for entry: Variant in anno_sheet.events:
		if entry is LocalVariable and (entry as LocalVariable).name == "dmg":
			dmg = entry as LocalVariable
	all_passed = _check("the @ace-annotated var still lifts", dmg != null, true) and all_passed
	if dmg != null:
		all_passed = _check("an @ace annotation is not absorbed as a tooltip",
			(dmg.attributes as Dictionary).has("tooltip"), false) and all_passed

	# Editability: the dialog's apply keeps tooltip/group/subgroup on a tree variable (the attributes the
	# tree path round-trips), dropping the rest - so a reopened variable stays editable, not stuck or cleared.
	all_passed = _check("tree-var apply keeps tooltip + group + subgroup",
		EventSheetDock._tree_group_attributes({"tooltip": "HP", "group": "Combat", "subgroup": "Melee", "range": {"min": "0"}}),
		{"tooltip": "HP", "group": "Combat", "subgroup": "Melee"}) and all_passed
	all_passed = _check("a non-grouping attribute (range) is dropped from the tree subset",
		EventSheetDock._tree_group_attributes({"range": {"min": "0"}}), {}) and all_passed

	# Description-as-Inspector-tooltip: a variable's plain description compiles to a `## ` doc comment
	# above the @export var (Godot's Inspector-description convention), so a comment typed on a variable
	# automatically becomes the property's Inspector description - no separate Tooltip step needed.
	var described: LocalVariable = LocalVariable.new()
	described.name = "shield"
	described.type_name = "int"
	described.default_value = 50
	described.exported = true
	described.description = "Absorbs damage before health."
	all_passed = _check("a described exported var emits its description as a ## doc comment",
		SheetCompiler._emit_tree_variable_line(described),
		"## Absorbs damage before health.\n@export var shield: int = 50") and all_passed
	# An explicit tooltip attribute wins over the description field (the override path).
	described.attributes = {"tooltip": "Shield points."}
	all_passed = _check("an explicit tooltip wins over the description field",
		SheetCompiler._emit_tree_variable_line(described),
		"## Shield points.\n@export var shield: int = 50") and all_passed
	# A described but NON-exported var stays a plain private var (Godot only surfaces exported docs).
	var priv: LocalVariable = LocalVariable.new()
	priv.name = "_ticks"
	priv.type_name = "int"
	priv.default_value = 0
	priv.exported = false
	priv.description = "internal counter"
	all_passed = _check("a described private var emits no doc comment",
		SheetCompiler._emit_tree_variable_line(priv), "var _ticks: int = 0") and all_passed
	# Round-trip: the description-emitted `## ` reopens as the variable's tooltip (byte-identical re-emit,
	# so the lossless .gd contract holds). Pin the value, never a `bool and String` chain (it crashes).
	var desc_sheet: EventSheetResource = GDScriptImporter.new().import_external_source("extends Node2D\n\n## Absorbs damage before health.\n@export var shield: int = 50\n")
	var reopened: LocalVariable = null
	for entry: Variant in desc_sheet.events:
		if entry is LocalVariable and (entry as LocalVariable).name == "shield":
			reopened = entry as LocalVariable
	var reopened_tip: String = str((reopened.attributes as Dictionary).get("tooltip", "")) if reopened != null else ""
	all_passed = _check("the description-emitted doc reopens as a tooltip (round-trip)",
		reopened_tip, "Absorbs damage before health.") and all_passed

	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] variable_group_roundtrip_test: %s" % label)
		return true
	print("[FAIL] variable_group_roundtrip_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
