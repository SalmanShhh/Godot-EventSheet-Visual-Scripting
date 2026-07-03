# Godot EventSheets — GDScript-blocks spec P1: scaffolding detection + the foldable "Class setup" strip.
#
# Pins the two correctness gates of the blocks-as-rows polish:
#   - is_scaffolding_code() classifies class boilerplate (prelude, ## annotations, the host-binding
#     _enter_tree, blanks) as scaffolding but NEVER real logic (conservative — it must not hide code).
#   - _build_rows_from_sheet() collapses the LEADING run of ≥2 scaffolding RawCodeRows into ONE synthetic,
#     foldable, folded-by-default strip whose children are the real rows (view-state only — codegen
#     untouched). A single scaffolding row, or logic up top, is left inline.
@tool
class_name BlocksScaffoldingTest
extends RefCounted


static func run() -> bool:
	var all_passed: bool = true

	# ── is_scaffolding_code: boilerplate is scaffolding ──
	all_passed = _check("class prelude is scaffolding",
		EventSheetViewport.is_scaffolding_code("class_name Patrol\nextends Node2D\n## @ace_tags(movement)"), true) and all_passed
	all_passed = _check("the @ace_family marker is scaffolding",
		EventSheetViewport.is_scaffolding_code("## @ace_family(Enemy)"), true) and all_passed
	all_passed = _check("the host-binding _enter_tree is scaffolding",
		EventSheetViewport.is_scaffolding_code("func _enter_tree() -> void:\n\thost = get_parent() as CharacterBody2D"), true) and all_passed
	all_passed = _check("a blank separator is scaffolding", EventSheetViewport.is_scaffolding_code("\n  \n"), true) and all_passed

	# ── is_scaffolding_code: real logic is NOT scaffolding (never hidden) ──
	all_passed = _check("game logic is NOT scaffolding",
		EventSheetViewport.is_scaffolding_code("velocity.y += gravity * delta\nmove_and_slide()"), false) and all_passed
	all_passed = _check("an _enter_tree with extra logic is NOT scaffolding (conservative)",
		EventSheetViewport.is_scaffolding_code("func _enter_tree() -> void:\n\thost = get_parent() as Node\n\tprint(\"hi\")"), false) and all_passed
	all_passed = _check("a top-level const is NOT scaffolding",
		EventSheetViewport.is_scaffolding_code("const SPEED := 200.0"), false) and all_passed

	# ── The leading scaffolding run collapses into one folded strip ──
	var viewport: EventSheetViewport = EventSheetViewport.new()
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.events.append(_raw("class_name Patrol\nextends Node\n## @ace_tags(movement)"))
	sheet.events.append(_raw("func _enter_tree() -> void:\n\thost = get_parent() as Node"))
	sheet.events.append(_raw("velocity.y += gravity"))  # real logic — must stay inline
	var rows: Array = viewport._build_rows_from_sheet(sheet)
	var strip: EventRowData = _first_strip(rows)
	all_passed = _check("a leading run of ≥2 scaffolding rows collapses into a strip", strip != null, true) and all_passed
	if strip != null:
		all_passed = _check("the strip holds the 2 scaffolding rows as children", strip.children.size() == 2, true) and all_passed
		all_passed = _check("the strip is folded by default (boilerplate hidden)", strip.folded, true) and all_passed
	all_passed = _check("the logic row is NOT swallowed by the strip",
		_has_raw_row_with(rows, "velocity.y += gravity"), true) and all_passed

	all_passed = _check("the strip is recognized as the synthetic header (inert for selection)",
		strip != null and viewport._is_synthetic_scaffolding_strip(strip), true) and all_passed

	# ── A SINGLE multi-line prelude block collapses too (the importer bundles a whole prelude into ONE
	# RawCodeRow, so the threshold is line-based, not row-based — else the strip would never fire). ──
	var prelude_only: EventSheetResource = EventSheetResource.new()
	prelude_only.events.append(_raw("class_name Foe\nextends Node2D\n## @ace_family(Foe)"))  # 3 lines, 1 row
	prelude_only.events.append(_raw("position += velocity"))
	all_passed = _check("a single ≥3-line prelude block collapses into a strip",
		_first_strip(viewport._build_rows_from_sheet(prelude_only)) != null, true) and all_passed

	# ── A SHORT (<3 line) single scaffold row is left inline (not worth hiding) ──
	var lone: EventSheetResource = EventSheetResource.new()
	lone.events.append(_raw("extends Node"))  # 1 line
	lone.events.append(_raw("velocity.y += gravity"))
	all_passed = _check("a sub-threshold (<3 line) scaffold row stays inline (no strip)",
		_first_strip(viewport._build_rows_from_sheet(lone)) == null, true) and all_passed

	# ── A compile-error marker on a prelude block SURVIVES into the collapsed strip (not dropped) ──
	var flagged_sheet: EventSheetResource = EventSheetResource.new()
	var flagged_prelude: RawCodeRow = _raw("class_name Bad\nextends Node\n## @ace_family(Bad)")
	flagged_sheet.events.append(flagged_prelude)
	flagged_sheet.events.append(_raw("position += velocity"))
	viewport._row_diagnostics = {str(flagged_prelude.get_instance_id()): "boom"}
	var flagged_strip: EventRowData = _first_strip(viewport._build_rows_from_sheet(flagged_sheet))
	var marker_survived: bool = flagged_strip != null and not flagged_strip.children.is_empty() \
		and flagged_strip.children[0].error_message == "boom"
	all_passed = _check("a diagnostic on a prelude block survives into the strip", marker_survived, true) and all_passed
	viewport.free()

	return all_passed


static func _raw(code: String) -> RawCodeRow:
	var row: RawCodeRow = RawCodeRow.new()
	row.code = code
	return row


## The first synthetic scaffolding-strip header among the built root rows, or null.
static func _first_strip(rows: Array) -> EventRowData:
	for row: Variant in rows:
		if row is EventRowData and (row as EventRowData).row_uid.begins_with("scaffolding_strip_"):
			return row
	return null


## True when some top-level row is a RawCodeRow whose source code contains `needle` (i.e. it was left
## inline rather than collapsed into the strip).
static func _has_raw_row_with(rows: Array, needle: String) -> bool:
	for row: Variant in rows:
		if row is EventRowData and (row as EventRowData).source_resource is RawCodeRow \
				and ((row as EventRowData).source_resource as RawCodeRow).code.contains(needle):
			return true
	return false


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] blocks_scaffolding_test: %s" % label)
		return true
	print("[FAIL] blocks_scaffolding_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
