# EventForge - trigger signals as first-class rows. A behaviour's `## @ace_trigger … signal X`
# declaration block (hand-written GDScript) is lifted into SignalRow trigger rows so it reads as a
# keyword-badged Trigger row and feeds the On Signal / Emit Signal pickers - and a bare zero-arg
# `signal_name.emit()` in an event body reverse-lifts to an Emit Signal action row.
@tool
class_name SignalRowLiftTest
extends RefCounted

const GDScriptImporter := preload("res://addons/eventforge/importer/gdscript_importer.gd")


static func run() -> bool:
	var ok: bool = true

	# 1) @ace_trigger signal blocks -> SignalRow rows (name/category/params recovered).
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	sheet.custom_class_name = "TestBehaviour"
	var block: RawCodeRow = RawCodeRow.new()
	block.code = "\n".join(PackedStringArray([
		"## @ace_trigger",
		"## @ace_name(\"On Jumped\")",
		"## @ace_category(\"Test\")",
		"signal jumped",
		"",
		"## @ace_trigger",
		"signal hit(damage: int)",
	]))
	sheet.events.append(block)
	var lifted: int = EventSheetACELifter.lift_signal_declarations(sheet, false)
	ok = _check("two signals lifted to SignalRows", lifted, 2) and ok

	var jumped: SignalRow = null
	var hit: SignalRow = null
	for row: Variant in sheet.events:
		if row is SignalRow:
			if (row as SignalRow).signal_name == "jumped":
				jumped = row
			elif (row as SignalRow).signal_name == "hit":
				hit = row
	ok = _check("trigger flag + @ace_name recovered", jumped != null and jumped.trigger and jumped.ace_name == "On Jumped", true) and ok
	ok = _check("@ace_category recovered", jumped != null and jumped.ace_category == "Test", true) and ok
	ok = _check("typed signal params recovered", hit != null and hit.params.size() == 1 and hit.params[0] == "damage: int", true) and ok

	# The recompiled output still declares both signals with their @ace_trigger annotations.
	var compiled: String = str(SheetCompiler.compile(sheet, "user://sr_decl.gd").get("output", ""))
	ok = _check("output keeps signal jumped", compiled.contains("signal jumped"), true) and ok
	ok = _check("output keeps signal hit(damage: int)", compiled.contains("signal hit(damage: int)"), true) and ok
	ok = _check("output keeps the @ace_trigger annotation", compiled.contains("## @ace_trigger"), true) and ok

	# 2) A zero-arg `signal.emit()` in an event body lifts to an Emit Signal action row.
	var sheet2: EventSheetResource = EventSheetResource.new()
	sheet2.host_class = "Node2D"
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnProcess"
	var raw: RawCodeRow = RawCodeRow.new()
	raw.code = "jumped.emit()"
	event.actions.append(raw)
	sheet2.events.append(event)
	var before: String = str(SheetCompiler.compile(sheet2, "user://sr_emit_before.gd").get("output", ""))
	EventSheetACELifter.lift_event_bodies(sheet2)
	var emit_found: bool = false
	for row: Variant in sheet2.events:
		if row is EventRow and (row as EventRow).trigger_id == "OnProcess":
			emit_found = _has_emit_signal(row as EventRow)
	ok = _check("zero-arg signal.emit() lifts to Emit Signal", emit_found, true) and ok
	var after: String = str(SheetCompiler.compile(sheet2, "user://sr_emit_after.gd").get("output", ""))
	ok = _check("emit lift round-trips byte-identically", after == before, true) and ok

	# 3) Review fix: comma splits are TOP-LEVEL only. The naive split(", ") fragmented a typed
	# collection (`Dictionary[String, int]`) into two garbage params that still REJOINED
	# byte-identically, so the byte gate passed while the editor showed broken param fields.
	var pieces: PackedStringArray = EventSheetBlockRegistry.split_params_top_level("a: int, b: Dictionary[String, int], c := f(1, 2)")
	ok = _check("top-level split keeps brackets and calls whole", pieces.size(), 3) and ok
	ok = _check("empty text splits to a no-param list", EventSheetBlockRegistry.split_params_top_level(" ").size(), 0) and ok
	var typed_line: String = "signal scored(totals: Dictionary[String, int], label: String)"
	var typed_signal: SignalRow = null
	for kind: EventSheetBlockKind in EventSheetBlockRegistry.all_kinds():
		var claim: Dictionary = kind.lift(PackedStringArray([typed_line]), 0)
		if claim.get("resource") is SignalRow:
			typed_signal = claim["resource"]
	ok = _check("typed-collection signal lifts with TWO whole params", typed_signal != null and typed_signal.params.size() == 2, true) and ok
	if typed_signal != null and typed_signal.params.size() == 2:
		ok = _check("the Dictionary[String, int] param stays one piece", typed_signal.params[0], "totals: Dictionary[String, int]") and ok
	var fn_src: String = "extends Node\n\n## @ace_hidden\nfunc tally(totals: Dictionary[String, int], label: String) -> int:\n\treturn 7\n"
	var fn_sheet: EventSheetResource = GDScriptImporter.new().import_external_source(fn_src)
	var tally_fn: EventFunction = null
	for lifted_function: EventFunction in fn_sheet.functions:
		if lifted_function.function_name == "tally":
			tally_fn = lifted_function
	ok = _check("typed-collection function args lift as TWO params", tally_fn != null and tally_fn.params.size() == 2, true) and ok
	if tally_fn != null and tally_fn.params.size() == 2:
		ok = _check("the collection arg keeps its full type", tally_fn.params[0].type_name, "Dictionary[String, int]") and ok
	fn_sheet.external_source_path = "user://sr_typed_fn.gd"
	ok = _check("typed-collection function round-trips byte-identically", str(SheetCompiler.compile(fn_sheet, "user://sr_typed_fn.gd").get("output", "")) == fn_src, true) and ok

	return ok


static func _has_emit_signal(row: EventRow) -> bool:
	for action: Variant in row.actions:
		if action is ACEAction and (action as ACEAction).ace_id == "EmitSignal":
			return true
	for sub: Variant in row.sub_events:
		if sub is EventRow and _has_emit_signal(sub as EventRow):
			return true
	return false


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] signal_row_lift_test: %s" % label)
		return true
	print("[FAIL] signal_row_lift_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
