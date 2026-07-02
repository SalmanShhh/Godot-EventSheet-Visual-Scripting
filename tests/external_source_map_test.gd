# EventForge — the external (opened-pack) source map must point at the RIGHT lines. A few non-raw
# entries (a doc-commented @export var emits its `##` line plus the declaration but records only the
# declaration) undercounted their emitted lines, cascading a small offset onto every raw row after
# them — so click-to-select / error→row / sheet-diff landed a few rows off on opened packs. The
# compiler now realigns raw entries against the byte-exact output. This test proves, across EVERY
# pack, that each raw row's mapped first line equals its code's first line — and that the realign is
# map-only (bytes unchanged, drift still 0).
@tool
extends RefCounted
class_name ExternalSourceMapTest

static func run() -> bool:
	var ok: bool = true
	var checked_packs: int = 0

	for pack_path: String in _all_pack_scripts():
		var source: String = FileAccess.get_file_as_string(pack_path)
		var sheet: EventSheetResource = GDScriptImporter.new().import_external_source(source)
		sheet.external_source_path = pack_path
		var result: Dictionary = SheetCompiler.compile(sheet, "user://_ext_map_test.gd")
		var output: String = str(result.get("output", ""))
		# The realign must not disturb the byte-exact round-trip.
		if output != source:
			ok = _check("%s round-trips byte-identical (realign is map-only)" % pack_path.get_file(), false, true)
			continue
		var lines: PackedStringArray = output.split("\n")
		var mismatches: int = 0
		var total_raw: int = 0
		for entry: Variant in result.get("source_map", []):
			if str((entry as Dictionary).get("kind", "")) != "raw":
				continue
			var resource: Resource = instance_from_id(int(str((entry as Dictionary).get("uid", "0")))) as Resource
			if resource == null or resource.get("code") == null:
				continue
			total_raw += 1
			var code_first: String = str(resource.get("code")).split("\n")[0]
			var start: int = int((entry as Dictionary).get("start", 0))
			var mapped_first: String = lines[start - 1] if start >= 1 and start - 1 < lines.size() else "<oob>"
			# The row's code emits at its mapped first line — compared stripped, because a raw body
			# block picks up leading indentation on emission (its content, and thus the row it points
			# at, is unchanged; only the leading whitespace differs). A genuine offset — the pre-fix
			# bug — showed an entirely DIFFERENT line here, not just different indentation.
			if code_first.strip_edges() != mapped_first.strip_edges():
				mismatches += 1
		ok = _check("%s: every raw row's map points at its code (%d rows)" % [pack_path.get_file(), total_raw], mismatches, 0) and ok
		checked_packs += 1

	ok = _check("checked a meaningful number of packs", checked_packs > 5, true) and ok

	# End-to-end on health: heal now lifts as a REAL EventFunction, and its mapped range must cover
	# its whole emission — the annotation block through the final body line.
	var health: String = FileAccess.get_file_as_string("res://eventsheet_addons/health/health_behavior.gd")
	var health_sheet: EventSheetResource = GDScriptImporter.new().import_external_source(health)
	health_sheet.external_source_path = "res://eventsheet_addons/health/health_behavior.gd"
	var health_result: Dictionary = SheetCompiler.compile(health_sheet, "user://_ext_map_test.gd")
	var health_lines: PackedStringArray = str(health_result.get("output", "")).split("\n")
	var heal_fn: EventFunction = null
	for entry: Variant in health_sheet.functions:
		if entry is EventFunction and (entry as EventFunction).function_name == "heal":
			heal_fn = entry as EventFunction
	ok = _check("heal lifts as a real function", heal_fn != null, true) and ok
	var heal_range: Vector2i = EventSheetLineRowMapper.range_for_resource(health_result.get("source_map", []), heal_fn)
	var heal_text: String = "\n".join(health_lines.slice(maxi(heal_range.x - 1, 0), heal_range.y)) if heal_range.x > 0 else ""
	ok = _check("heal's mapped range contains its signature", heal_text.contains("func heal(amount: float) -> void:"), true) and ok
	ok = _check("heal's mapped range reaches its final body line", heal_text.contains("on_health_changed.emit()"), true) and ok

	return ok

static func _all_pack_scripts() -> PackedStringArray:
	var scripts: PackedStringArray = PackedStringArray()
	var root: String = "res://eventsheet_addons"
	for folder: String in DirAccess.get_directories_at(root):
		var candidate: String = "%s/%s/%s_behavior.gd" % [root, folder, folder]
		if FileAccess.file_exists(candidate):
			scripts.append(candidate)
	# Fall back to any *_behavior.gd if the naming differs, so the test covers real packs.
	if scripts.size() < 3:
		for folder: String in DirAccess.get_directories_at(root):
			for file: String in DirAccess.get_files_at("%s/%s" % [root, folder]):
				if file.ends_with(".gd") and not file.ends_with(".uid"):
					scripts.append("%s/%s/%s" % [root, folder, file])
	return scripts

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] external_source_map_test: %s" % label)
		return true
	print("[FAIL] external_source_map_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
