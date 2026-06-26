# EventForge — Phase 2 (Stage B) of the near-zero-RawCode roadmap: statement-level reverse coverage.
# Inside an already-lifted trigger body, a property assignment `a.b = c` reverse-lifts to a Set
# Property row and a method call `a.b()` to a Call Method row — instead of staying an in-flow GDScript
# cell. These two Helper catch-alls are admitted to the reverse index at LOWEST specificity, so a
# specific ACE always wins; the byte-identical recompile gates correctness. (No functions move, so the
# GDScript-backed-sheet append contract is untouched — this is independent of the Phase-1 fork.)
@tool
extends RefCounted
class_name StatementLiftTest

static func run() -> bool:
	var ok: bool = true

	# Author an OnProcess event whose body is two hand-written statements (as a RawCode block).
	var authored: EventSheetResource = EventSheetResource.new()
	authored.host_class = "Node2D"
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnProcess"
	var raw: RawCodeRow = RawCodeRow.new()
	# Property / method with NO dedicated ACE, so the generic Set Property / Call Method catch-alls
	# win (a property like `modulate` or method like `play` would match a specific ACE instead — which
	# is the correct, higher-specificity behaviour).
	raw.code = "$Hud.custom_value = 7\n$Hud.refresh_now(true)"
	event.actions.append(raw)
	authored.events.append(event)
	var source: String = str(SheetCompiler.compile(authored, "user://sb_source.gd").get("output", ""))

	# Open the OUTPUT as a sheet: the two statements should lift to rows, not stay a code cell.
	var imported: EventSheetResource = GDScriptImporter.new().import_external_source(source)
	var ace_ids: Array = []
	var inflow_blocks: int = 0
	for row: Variant in imported.events:
		if row is EventRow:
			for a: Variant in (row as EventRow).actions:
				if a is ACEAction:
					ace_ids.append((a as ACEAction).ace_id)
				elif a is RawCodeRow:
					inflow_blocks += 1
	ok = _check("property assignment lifts to SetProperty", ace_ids.has("SetProperty"), true) and ok
	ok = _check("method call lifts to CallMethod", ace_ids.has("CallMethod"), true) and ok
	ok = _check("no in-flow code cell remains", inflow_blocks, 0) and ok

	# The contract: recompiling reproduces the source byte-for-byte.
	imported.external_source_path = "user://sb_rt.gd"
	var roundtrip: String = str(SheetCompiler.compile(imported, "user://sb_rt.gd").get("output", ""))
	ok = _check("statement lift round-trips byte-identically", roundtrip == source, true) and ok
	if roundtrip != source:
		print("  --- source ---\n%s\n  --- roundtrip ---\n%s" % [source, roundtrip])

	return ok

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] statement_lift_test: %s" % label)
		return true
	print("[FAIL] statement_lift_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
