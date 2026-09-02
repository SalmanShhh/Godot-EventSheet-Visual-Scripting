# EventForge - trigger signals as first-class rows. A behaviour's `## @ace_trigger … signal X`
# declaration block (hand-written GDScript) is lifted into SignalRow trigger rows so it reads as a
# keyword-badged Trigger row and feeds the On Signal / Emit Signal pickers - and a bare zero-arg
# `signal_name.emit()` in an event body reverse-lifts to an Emit Signal action row.
@tool
class_name SignalRowLiftTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
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

	ok = _test_trigger_prose_travels_with_the_signal() and ok
	return ok


## A trigger signal's PROSE is its picker description (the analyzer reads a doc comment over a member
## as one), and it only reaches the picker if it travels ON the row. Both lifters used to absorb the
## annotation run alone, leaving the sentence in whatever block preceded the signal - so the signal
## moved to the top of the file, the prose stayed behind, and every documented trigger shipped with
## an EMPTY description while a paragraph turned up as the doc comment of an unrelated const.
static func _test_trigger_prose_travels_with_the_signal() -> bool:
	var ok: bool = true
	var source: String = "\n".join(PackedStringArray([
		"## Fires when the autosave clock comes round, INSTEAD of saving.",
		"## The conditions on this event decide whether now is a good moment.",
		"## @ace_trigger",
		"## @ace_name(\"On Autosave Due\")",
		"## @ace_category(\"Save System\")",
		"signal autosave_due(slot_index: int)",
	]))

	# 1. The PACK path (publish_pack's lifter): the prose comes off the block onto the row.
	var pack_sheet: EventSheetResource = EventSheetResource.new()
	pack_sheet.host_class = "Node"
	pack_sheet.custom_class_name = "ProseBehaviour"
	var block: RawCodeRow = RawCodeRow.new()
	block.code = source
	pack_sheet.events.append(block)
	EventSheetACELifter.lift_signal_declarations(pack_sheet, false)
	var lifted_row: SignalRow = null
	for row: Variant in pack_sheet.events:
		if row is SignalRow:
			lifted_row = row as SignalRow
	ok = _check("the pack lifter carries the prose onto the row", lifted_row != null and lifted_row.description ==
		"Fires when the autosave clock comes round, INSTEAD of saving.\nThe conditions on this event decide whether now is a good moment.", true) and ok
	ok = _check("and leaves no orphaned block behind it", _has_raw_code(pack_sheet), false) and ok
	var emitted: String = str(SheetCompiler.compile(pack_sheet, "user://sr_prose_pack.gd").get("output", ""))
	ok = _check("the emitted signal keeps its prose directly above the annotations",
		emitted.contains("## Fires when the autosave clock comes round, INSTEAD of saving.\n## The conditions on this event decide whether now is a good moment.\n## @ace_trigger"), true) and ok

	# 2. The ANALYZER really reads it as the trigger's description - the reason any of this matters.
	# Written to a real file first: the analyzer reads annotations off DISK, so a script built from
	# a source string in memory would pass for the wrong reason.
	var probe_path: String = "user://sr_prose_probe.gd"
	var handle: FileAccess = FileAccess.open(probe_path, FileAccess.WRITE)
	handle.store_string("extends Node\n\n%s\n" % source)
	handle.close()
	var metadata: Dictionary = EventSheetSemanticAnalyzer.new().parse_source_metadata(load(probe_path))
	var described: Dictionary = (metadata.get("signals", {}) as Dictionary).get("autosave_due", {})
	ok = _check("the picker gets a real description for the trigger", str(described.get("description", "")),
		"Fires when the autosave clock comes round, INSTEAD of saving. The conditions on this event decide whether now is a good moment.") and ok
	DirAccess.remove_absolute(probe_path)

	# 3. The OPEN-A-.gd path (the importer): same absorption, and the byte gate still holds - the
	# prose re-emits exactly where it came from.
	var file_source: String = "extends Node\n\n%s\n" % source
	var opened: EventSheetResource = GDScriptImporter.new().import_external_source(file_source)
	var opened_row: SignalRow = null
	for row: Variant in opened.events:
		if row is SignalRow:
			opened_row = row as SignalRow
	ok = _check("opening a .gd absorbs the prose too", opened_row != null and not opened_row.description.is_empty(), true) and ok
	opened.external_source_path = "user://sr_prose_open.gd"
	ok = _check("and the file round-trips byte-identically",
		str(SheetCompiler.compile(opened, "user://sr_prose_open.gd").get("output", "")) == file_source, true) and ok

	# 4. A plain signal with no prose emits exactly what it always did - no leading blank doc line.
	var bare: SignalRow = SignalRow.new()
	bare.signal_name = "jumped"
	bare.trigger = true
	bare.ace_name = "On Jumped"
	ok = _check("a trigger with no prose emits the annotation block alone",
		Array(SheetCompiler._emit_signal_annotations(bare)), ["## @ace_trigger", "## @ace_name(\"On Jumped\")"]) and ok
	return ok


static func _has_raw_code(sheet: EventSheetResource) -> bool:
	for row: Variant in sheet.events:
		if row is RawCodeRow and not (row as RawCodeRow).code.strip_edges().is_empty():
			return true
	return false


static func _has_emit_signal(row: EventRow) -> bool:
	for action: Variant in row.actions:
		if action is ACEAction and (action as ACEAction).ace_id == "EmitSignal":
			return true
	for sub: Variant in row.sub_events:
		if sub is EventRow and _has_emit_signal(sub as EventRow):
			return true
	return false


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("signal_row_lift_test", label, actual, expected)
