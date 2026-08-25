# Godot EventSheets - scaffolding detection + the head BAND STACK it feeds.
#
# Pins the two correctness gates of the sheet head:
#   - is_scaffolding_code() classifies class boilerplate (prelude, ## annotations, the host-binding
#     _enter_tree, blanks) as scaffolding but NEVER real logic (conservative - it must not hide code).
#   - _build_rows_from_sheet() reads the LEADING run of scaffolding into the head: ONE row per line
#     the file opens with, always visible, none of them folding. View-state only - the RawCodeRows
#     and the emitted bytes are untouched, and a diagnostic on a prelude block still surfaces.
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
	# The shape a hand-written script actually opens with: a plain `#` header comment above the
	# prelude. Only `##` was accepted, so that one line made the whole prelude read as real content
	# and every such file opened showing a GDScript block instead of the collapsed strip.
	all_passed = _check("a plain # file header above the prelude is scaffolding",
		EventSheetViewport.is_scaffolding_code("# EventForge - Variable parser\n#\n# Parses declarations.\n@tool\nclass_name VariableParser\nextends RefCounted"), true) and all_passed
	all_passed = _check("a lone # note is scaffolding",
		EventSheetViewport.is_scaffolding_code("# just a note"), true) and all_passed
	# The other line a prelude really opens with: the import. Every pack recipe in this repo begins
	# `@tool` + `const Lib := preload(…)`, and while only the annotation was accepted that one line
	# left the whole prelude standing as a script block in any file whose body split cleanly.
	all_passed = _check("a preloaded constant is an import, and scaffolding",
		EventSheetViewport.is_scaffolding_code(
			"@tool\n\nconst Lib := preload(\"res://tools/pack_builders/_lib.gd\")"), true) and all_passed
	all_passed = _check("a # comment sitting above real logic does NOT make it scaffolding",
		EventSheetViewport.is_scaffolding_code("# bump the score\nscore += 1"), false) and all_passed

	# ── is_scaffolding_code: real logic is NOT scaffolding (never hidden) ──
	all_passed = _check("game logic is NOT scaffolding",
		EventSheetViewport.is_scaffolding_code("velocity.y += gravity * delta\nmove_and_slide()"), false) and all_passed
	all_passed = _check("an _enter_tree with extra logic is NOT scaffolding (conservative)",
		EventSheetViewport.is_scaffolding_code("func _enter_tree() -> void:\n\thost = get_parent() as Node\n\tprint(\"hi\")"), false) and all_passed
	all_passed = _check("a top-level const the game plays by is NOT scaffolding",
		EventSheetViewport.is_scaffolding_code("const SPEED := 200.0"), false) and all_passed

	# ── The leading scaffolding run reads as the head's band stack ──
	var viewport: EventSheetViewport = EventSheetViewport.new()
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.events.append(_raw("class_name Patrol
extends Node
## @ace_tags(movement)"))
	sheet.events.append(_raw("func _enter_tree() -> void:
	host = get_parent() as Node"))
	sheet.events.append(_raw("velocity.y += gravity"))  # real logic - must stay inline
	var rows: Array = viewport._build_rows_from_sheet(sheet)
	all_passed = _check("the head reads one band per line, in reading order",
		_band_kinds(rows), "name | extends | host") and all_passed
	all_passed = _check("the name band says the class the file declares",
		_band_texts(rows, "name"), "▣ | Patrol | class_name Patrol") and all_passed
	all_passed = _check("the extends band says what it builds on",
		_band_texts(rows, "extends"), "extends | Node | change… | extends Node") and all_passed
	all_passed = _check("the host binding is ONE band, however many lines it is",
		_band_texts(rows, "host"),
		"host | acts on its parent | var host: Node · _enter_tree: host = get_parent()") and all_passed
	all_passed = _check("no band folds, and none has children to fold",
		_any_band_folds(rows), false) and all_passed
	all_passed = _check("the head offers the lines this sheet has not got",
		_add_row_text(rows), "+ add: icon · @tool · description") and all_passed
	all_passed = _check("a band owns no resource - selection, drag and delete skip it",
		_bands_are_inert(rows), true) and all_passed
	all_passed = _check("the logic row is NOT swallowed by the head",
		_has_raw_row_with(rows, "velocity.y += gravity"), true) and all_passed

	# ── A SINGLE multi-line prelude block reads as bands too (the importer bundles a whole prelude
	# into ONE RawCodeRow, so the threshold is line-based, not row-based). ──
	var prelude_only: EventSheetResource = EventSheetResource.new()
	prelude_only.events.append(_raw("class_name Foe
extends Node2D
## @ace_family(Foe)"))  # 3 lines, 1 row
	prelude_only.events.append(_raw("position += velocity"))
	all_passed = _check("a single ≥3-line prelude block reads as bands",
		_band_kinds(viewport._build_rows_from_sheet(prelude_only)), "name | extends") and all_passed

	# ── A lone identity line still makes a head (after the lifts it is often the whole prelude) ──
	var lone: EventSheetResource = EventSheetResource.new()
	lone.events.append(_raw("extends Node"))  # 1 line
	lone.events.append(_raw("velocity.y += gravity"))
	var lone_rows: Array = viewport._build_rows_from_sheet(lone)
	all_passed = _check("a lone extends still makes a head",
		_band_kinds(lone_rows), "name | extends | attach") and all_passed
	# A sheet with nothing named yet asks, rather than showing an empty strip.
	all_passed = _check("a sheet with no class_name and no file asks to be named",
		_band_texts(lone_rows, "name"), "▣ | Untitled | name it | # no class_name yet") and all_passed
	all_passed = _check("and it offers to be attached to a node",
		_band_texts(lone_rows, "attach"), "attach | attach to a node") and all_passed

	# ── A compile-error marker on a prelude block SURVIVES beside the head (not dropped) ──
	var flagged_sheet: EventSheetResource = EventSheetResource.new()
	var flagged_prelude: RawCodeRow = _raw("class_name Bad
extends Node
## @ace_family(Bad)")
	flagged_sheet.events.append(flagged_prelude)
	flagged_sheet.events.append(_raw("position += velocity"))
	viewport._row_diagnostics = {str(flagged_prelude.get_instance_id()): "boom"}
	var marker_survived: bool = false
	for row: Variant in viewport._build_rows_from_sheet(flagged_sheet):
		if row is EventRowData and (row as EventRowData).error_message == "boom":
			marker_survived = true
	all_passed = _check("a diagnostic on a prelude block survives beside the head", marker_survived, true) and all_passed
	viewport.free()

	return all_passed


static func _raw(code: String) -> RawCodeRow:
	var row: RawCodeRow = RawCodeRow.new()
	row.code = code
	return row


## The head's bands, in order, by kind - "name | extends | host".
static func _band_kinds(rows: Array) -> String:
	var kinds: PackedStringArray = PackedStringArray()
	for row: Variant in rows:
		if not (row is EventRowData):
			continue
		var uid: String = (row as EventRowData).row_uid
		if not uid.begins_with("sheet_head_") or uid.begins_with("sheet_head_add_"):
			continue
		kinds.append(uid.trim_prefix("sheet_head_").rsplit("_", true, 1)[0])
	return " | ".join(kinds)


## One band's spans joined - the whole sentence that band reads as, echo included.
static func _band_texts(rows: Array, band_kind: String) -> String:
	for row: Variant in rows:
		if row is EventRowData and (row as EventRowData).row_uid.begins_with("sheet_head_%s_" % band_kind):
			var parts: PackedStringArray = PackedStringArray()
			for span: SemanticSpan in (row as EventRowData).spans:
				parts.append(str(span.text))
			return " | ".join(parts)
	return ""


## The "+ add" row's text, "" when there is no such row.
static func _add_row_text(rows: Array) -> String:
	for row: Variant in rows:
		if row is EventRowData and (row as EventRowData).row_uid.begins_with("sheet_head_add_"):
			return str((row as EventRowData).spans[0].text)
	return ""


## True when ANY head band folds or carries children (the head must do neither).
static func _any_band_folds(rows: Array) -> bool:
	for row: Variant in rows:
		if not (row is EventRowData) or not (row as EventRowData).row_uid.begins_with("sheet_head_"):
			continue
		if (row as EventRowData).folded or not (row as EventRowData).children.is_empty():
			return true
	return false


## True when every head band is inert (null source), which is what keeps Delete off the prelude.
static func _bands_are_inert(rows: Array) -> bool:
	for row: Variant in rows:
		if row is EventRowData and (row as EventRowData).row_uid.begins_with("sheet_head_") 				and (row as EventRowData).source_resource != null:
			return false
	return true


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
