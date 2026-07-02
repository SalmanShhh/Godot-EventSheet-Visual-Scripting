# EventForge — per-function shell-lift with re-anchoring. The trailing-run lift used to be
# all-or-nothing: ONE hairy function body reverted every function in the file back to raw code. The
# run now RE-ANCHORS after each failure, so the longest cleanly-lifting TRAILING subset still becomes
# real EventFunctions (only a trailing subset can lift at all — emission places sheet.functions after
# the in-place raw rows, so a raw leftover between lifted functions would reorder the file; the
# byte-verify still gates everything). Pins: the synthetic hairy-then-clean case, byte-identical
# round-trips with a partial lift, and a census FLOOR across real packs so a regression screams.
@tool
extends RefCounted
class_name PerFunctionLiftTest

static func run() -> bool:
	var ok: bool = true

	# ── Synthetic: a hairy body BEFORE two clean verbs — the clean tail lifts, the hairy stays raw.
	# The source is built by FORWARD-compiling a sheet that already holds the two verbs, so its
	# annotation blocks carry the exact emission shape the byte-verify demands (hand-writing an
	# incomplete block is correctly refused — the verify only accepts what it can reproduce). ──
	var authored: EventSheetResource = EventSheetResource.new()
	authored.host_class = "Node"
	authored.tool_mode = true
	authored.external_source_path = "user://_per_fn_lift_source.gd"
	var hairy: RawCodeRow = RawCodeRow.new()
	hairy.code = "func gnarly(a: Array) -> HairyType:\n	return a.reduce(func(x, y): return x + y)"
	authored.events.append(hairy)
	for spec: Array in [["ping", TYPE_NIL, "Ping"], ["answer", TYPE_FLOAT, "Answer"]]:
		var verb: EventFunction = EventFunction.new()
		verb.function_name = str(spec[0])
		verb.return_type = int(spec[1])
		verb.expose_as_ace = true
		verb.ace_display_name = str(spec[2])
		authored.functions.append(verb)
	var source: String = str(SheetCompiler.compile(authored, "user://_per_fn_lift_source.gd").get("output", ""))
	ok = _check("the forward-compiled source holds all three funcs",
		source.contains("func gnarly") and source.contains("func ping") and source.contains("func answer"), true) and ok
	var sheet: EventSheetResource = GDScriptImporter.new().import_external_source(source)
	ok = _check("the clean trailing verbs lift as real functions", sheet.functions.size(), 2) and ok
	var names: Array = []
	for entry: Variant in sheet.functions:
		names.append((entry as EventFunction).function_name)
	ok = _check("both by name", names, ["ping", "answer"]) and ok
	ok = _check("lifted verbs carry their exposure",
		sheet.functions.size() > 0 and (sheet.functions[0] as EventFunction).expose_as_ace \
			and (sheet.functions[0] as EventFunction).ace_display_name == "Ping", true) and ok
	var hairy_stays: bool = false
	for row: Variant in sheet.events:
		if row is RawCodeRow and str((row as RawCodeRow).code).contains("func gnarly"):
			hairy_stays = true
	ok = _check("the hairy function stays raw (in place)", hairy_stays, true) and ok
	sheet.external_source_path = "user://_per_fn_lift_verify.gd"
	var output: String = str(SheetCompiler.compile(sheet, "user://_per_fn_lift_verify.gd").get("output", ""))
	ok = _check("the partial lift round-trips byte-identically", output == source, true) and ok

	# ── Census floor across real packs: the re-anchoring must keep these packs lifting.
	# Floors sit below today's counts (abilities 49, virtual_cursor 54, drag_drop 36, spring 22,
	# weapon_kit 18, juice 17) so content edits have headroom, while a mechanism regression —
	# which sends a pack back to ZERO — always fails loudly. ──
	var floors: Dictionary = {
		"abilities": 40, "virtual_cursor": 40, "drag_drop": 30,
		"spring": 15, "weapon_kit": 12, "juice": 10, "platformer_movement": 10,
		# Unlocked by the untyped-parameter fix (a bare `final_value` param re-emitted as
		# `final_value: String` — ACEParam's default type — and failed the byte-verify).
		"htn_agent": 15, "tween": 8, "time_slicer": 8,
	}
	for pack: Variant in floors:
		var path: String = "res://eventsheet_addons/%s/%s_behavior.gd" % [pack, pack]
		var pack_sheet: EventSheetResource = GDScriptImporter.new().import_external_source(
			FileAccess.get_file_as_string(path))
		ok = _check("%s lifts at least %d functions" % [pack, int(floors[pack])],
			pack_sheet.functions.size() >= int(floors[pack]), true) and ok

	return ok

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] per_function_lift_test: %s" % label)
		return true
	print("[FAIL] per_function_lift_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
