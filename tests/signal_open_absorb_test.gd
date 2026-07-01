# EventForge — opening a .gd behaviour folds each `## @ace_trigger` annotation block ONTO its signal
# row (a first-class trigger row) instead of stranding it as a separate GDScript "setup" block above a
# bare signal. Pins the importer's _absorb_signal_trigger_annotations + the external compiler emitting
# the annotations back inline, so the whole thing round-trips byte-identically. The reverse of
# signal_row_lift_test (which pins the pack-BUILD path); this pins the user-OPEN path.
@tool
extends RefCounted
class_name SignalOpenAbsorbTest

static func run() -> bool:
	var ok: bool = true

	# A behaviour-shaped source: a named+categorised trigger signal, a bare @ace_trigger signal, and a
	# plain signal — the exact shape _compile_external now emits for a trigger SignalRow.
	var source: String = "\n".join(PackedStringArray([
		"@tool",
		"extends Node",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Jumped\")",
		"## @ace_category(\"Player\")",
		"signal jumped",
		"## @ace_trigger",
		"signal landed",
		"",
		"signal died(amount: int)",
	])) + "\n"

	var importer: GDScriptImporter = GDScriptImporter.new()
	var sheet: EventSheetResource = importer.import_external_source(source)

	# The two trigger signals folded onto their SignalRows; nothing stranded a `## @ace_trigger` block.
	var jumped: SignalRow = _find_signal(sheet, "jumped")
	var landed: SignalRow = _find_signal(sheet, "landed")
	var died: SignalRow = _find_signal(sheet, "died")
	ok = _check("jumped is a trigger signal", jumped != null and jumped.trigger, true) and ok
	ok = _check("jumped @ace_name folded in", jumped.ace_name if jumped != null else "", "On Jumped") and ok
	ok = _check("jumped @ace_category folded in", jumped.ace_category if jumped != null else "", "Player") and ok
	ok = _check("landed is a bare trigger (no name/category)", landed != null and landed.trigger and landed.ace_name == "" and landed.ace_category == "", true) and ok
	ok = _check("died stays a plain signal", died != null and not died.trigger, true) and ok
	ok = _check("died keeps its typed param", died != null and died.params.size() == 1 and died.params[0] == "amount: int", true) and ok
	ok = _check("no RawCodeRow still holds a @ace_trigger block", _count_raw_containing(sheet, "## @ace_trigger"), 0) and ok

	# External round-trip: re-emitting the sheet reproduces the source byte-for-byte (the annotations
	# come back inline above each trigger signal — the whole point of the folding being byte-safe).
	sheet.external_source_path = "user://_signal_open_absorb_verify.gd"
	var compiled: String = str(SheetCompiler.compile(sheet, "user://_signal_open_absorb_verify.gd").get("output", ""))
	ok = _check("external round-trip is byte-identical", compiled, source) and ok

	# Non-canonical / orphan blocks are NEVER absorbed (byte-safety): a `## @ace_name` with no
	# `## @ace_trigger` above the signal stays a verbatim block and the signal stays plain.
	var orphan_source: String = "\n".join(PackedStringArray([
		"extends Node",
		"",
		"## @ace_name(\"Orphan\")",
		"signal orphan",
	])) + "\n"
	var orphan_sheet: EventSheetResource = GDScriptImporter.new().import_external_source(orphan_source)
	var orphan: SignalRow = _find_signal(orphan_sheet, "orphan")
	ok = _check("orphan @ace_name (no @ace_trigger) is NOT absorbed", orphan != null and not orphan.trigger, true) and ok
	orphan_sheet.external_source_path = "user://_signal_orphan_verify.gd"
	var orphan_compiled: String = str(SheetCompiler.compile(orphan_sheet, "user://_signal_orphan_verify.gd").get("output", ""))
	ok = _check("orphan block round-trips verbatim", orphan_compiled, orphan_source) and ok

	return ok

static func _find_signal(sheet: EventSheetResource, name: String) -> SignalRow:
	for row: Variant in sheet.events:
		if row is SignalRow and (row as SignalRow).signal_name == name:
			return row
	return null

static func _count_raw_containing(sheet: EventSheetResource, needle: String) -> int:
	var count: int = 0
	for row: Variant in sheet.events:
		if row is RawCodeRow and (row as RawCodeRow).code.contains(needle):
			count += 1
	return count

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] signal_open_absorb_test: %s" % label)
		return true
	print("[FAIL] signal_open_absorb_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
