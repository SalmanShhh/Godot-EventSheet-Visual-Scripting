# EventForge - Phase 2 (Stage B) of the near-zero-RawCode roadmap: statement-level reverse coverage.
# Inside an already-lifted trigger body, a property assignment `a.b = c` reverse-lifts to a Set
# Property row and a method call `a.b()` to a Call Method row - instead of staying an in-flow GDScript
# cell. These two Helper catch-alls are admitted to the reverse index at LOWEST specificity, so a
# specific ACE always wins; the byte-identical recompile gates correctness. (No functions move, so the
# GDScript-backed-sheet append contract is untouched - this is independent of the Phase-1 fork.)
@tool
class_name StatementLiftTest
extends RefCounted


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
	# win (a property like `modulate` or method like `play` would match a specific ACE instead - which
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

	# Compound-assignment coverage: a property changed relative to itself (`+= -= *= /=`) lifts to the
	# Set-Property twins, and a bare `%=` to Modulo Variable - so "self.x += v" reads as a row, not a block.
	# Properties/vars with NO specific ACE are used so the generic catch-alls win (the correct fallback).
	var authored2: EventSheetResource = EventSheetResource.new()
	authored2.host_class = "Node2D"
	var event2: EventRow = EventRow.new()
	event2.trigger_provider_id = "Core"
	event2.trigger_id = "OnProcess"
	var raw2: RawCodeRow = RawCodeRow.new()
	raw2.code = "$Hud.custom_value += 7\n$Hud.custom_value -= 2\n$Hud.zoom_factor *= 3\n$Hud.zoom_factor /= 4\ncombo_index %= 5"
	event2.actions.append(raw2)
	authored2.events.append(event2)
	var source2: String = str(SheetCompiler.compile(authored2, "user://sb_source2.gd").get("output", ""))
	var imported2: EventSheetResource = GDScriptImporter.new().import_external_source(source2)
	var ace_ids2: Array = []
	var inflow2: int = 0
	for row2: Variant in imported2.events:
		if row2 is EventRow:
			for a2: Variant in (row2 as EventRow).actions:
				if a2 is ACEAction:
					ace_ids2.append((a2 as ACEAction).ace_id)
				elif a2 is RawCodeRow:
					inflow2 += 1
	ok = _check("property += lifts to AddToProperty", ace_ids2.has("AddToProperty"), true) and ok
	ok = _check("property -= lifts to SubtractFromProperty", ace_ids2.has("SubtractFromProperty"), true) and ok
	ok = _check("property *= lifts to MultiplyProperty", ace_ids2.has("MultiplyProperty"), true) and ok
	ok = _check("property /= lifts to DivideProperty", ace_ids2.has("DivideProperty"), true) and ok
	ok = _check("bare %= lifts to ModuloVar", ace_ids2.has("ModuloVar"), true) and ok
	ok = _check("no in-flow code cell remains (compound)", inflow2, 0) and ok
	imported2.external_source_path = "user://sb_rt2.gd"
	var roundtrip2: String = str(SheetCompiler.compile(imported2, "user://sb_rt2.gd").get("output", ""))
	ok = _check("compound-assign lift round-trips byte-identically", roundtrip2 == source2, true) and ok
	if roundtrip2 != source2:
		print("  --- source2 ---\n%s\n  --- roundtrip2 ---\n%s" % [source2, roundtrip2])

	# Specificity guard: the generic property twins must NOT out-rank a specific compound ACE. A
	# `velocity += …` is Add To Velocity, never the generic Add To Property (the literal-length sort
	# keeps the specific one ahead). Without this, a too-greedy generic could shadow real vocabulary.
	var authored3: EventSheetResource = EventSheetResource.new()
	authored3.host_class = "CharacterBody2D"
	var event3: EventRow = EventRow.new()
	event3.trigger_provider_id = "Core"
	event3.trigger_id = "OnPhysicsProcess"
	var raw3: RawCodeRow = RawCodeRow.new()
	raw3.code = "velocity += Vector2(1, 0)"
	event3.actions.append(raw3)
	authored3.events.append(event3)
	var source3: String = str(SheetCompiler.compile(authored3, "user://sb_source3.gd").get("output", ""))
	var imported3: EventSheetResource = GDScriptImporter.new().import_external_source(source3)
	var ace_ids3: Array = []
	for row3: Variant in imported3.events:
		if row3 is EventRow:
			for a3: Variant in (row3 as EventRow).actions:
				if a3 is ACEAction:
					ace_ids3.append((a3 as ACEAction).ace_id)
	ok = _check("specific velocity += wins over the generic property twin", ace_ids3.has("AddVelocity") and not ace_ids3.has("AddToProperty"), true) and ok

	# Shadow guard: a PLAIN assignment whose string value contains a compound operator must lift as a Set,
	# never as a bogus compound row. `label.text = "score += 1"` is a Set Property, not an Add To Property;
	# `msg = "combo += 1"` is a Set Variable, not an Add Variable. (Both round-trip either way, but the row
	# must read correctly.) This also covers the pre-existing bare-var compound catch-alls.
	var authored4: EventSheetResource = EventSheetResource.new()
	authored4.host_class = "Node2D"
	var event4: EventRow = EventRow.new()
	event4.trigger_provider_id = "Core"
	event4.trigger_id = "OnReady"
	var raw4: RawCodeRow = RawCodeRow.new()
	raw4.code = "$Label.text = \"score += 1\"\nmsg = \"combo += 1\""
	event4.actions.append(raw4)
	authored4.events.append(event4)
	var source4: String = str(SheetCompiler.compile(authored4, "user://sb_source4.gd").get("output", ""))
	var imported4: EventSheetResource = GDScriptImporter.new().import_external_source(source4)
	var ace_ids4: Array = []
	for row4: Variant in imported4.events:
		if row4 is EventRow:
			for a4: Variant in (row4 as EventRow).actions:
				if a4 is ACEAction:
					ace_ids4.append((a4 as ACEAction).ace_id)
	ok = _check("in-string += does not shadow Set Property", ace_ids4.has("SetProperty") and not ace_ids4.has("AddToProperty"), true) and ok
	ok = _check("in-string += does not shadow Set Variable", ace_ids4.has("SetVar") and not ace_ids4.has("AddVar"), true) and ok
	imported4.external_source_path = "user://sb_rt4.gd"
	var roundtrip4: String = str(SheetCompiler.compile(imported4, "user://sb_rt4.gd").get("output", ""))
	ok = _check("shadow-guard case round-trips byte-identically", roundtrip4 == source4, true) and ok

	# Local declarations: the three `var` forms each lift to their own row, distinctly. The inferred `:=`
	# (var heading := ...) used to force a raw block because the plain `=` template needs a space-equals-space
	# that `:=` never has; SetLocalVarInferred closes that. The `=` and `: T =` forms must stay distinct.
	var authored5: EventSheetResource = EventSheetResource.new()
	authored5.host_class = "Node2D"
	var event5: EventRow = EventRow.new()
	event5.trigger_provider_id = "Core"
	event5.trigger_id = "OnProcess"
	var raw5: RawCodeRow = RawCodeRow.new()
	raw5.code = "var heading := position * 2.0\nvar plain = 5\nvar typed: int = 7"
	event5.actions.append(raw5)
	authored5.events.append(event5)
	var source5: String = str(SheetCompiler.compile(authored5, "user://sb_source5.gd").get("output", ""))
	var imported5: EventSheetResource = GDScriptImporter.new().import_external_source(source5)
	var ace_ids5: Array = []
	var inflow5: int = 0
	for row5: Variant in imported5.events:
		if row5 is EventRow:
			for a5: Variant in (row5 as EventRow).actions:
				if a5 is ACEAction:
					ace_ids5.append((a5 as ACEAction).ace_id)
				elif a5 is RawCodeRow:
					inflow5 += 1
	ok = _check("inferred := lifts to SetLocalVarInferred", ace_ids5.has("SetLocalVarInferred"), true) and ok
	ok = _check("plain = still lifts to SetLocalVar", ace_ids5.has("SetLocalVar"), true) and ok
	ok = _check("typed : T = still lifts to SetLocalVarTyped", ace_ids5.has("SetLocalVarTyped"), true) and ok
	ok = _check("no in-flow block remains (all three var forms lift)", inflow5, 0) and ok
	imported5.external_source_path = "user://sb_rt5.gd"
	var roundtrip5: String = str(SheetCompiler.compile(imported5, "user://sb_rt5.gd").get("output", ""))
	ok = _check("inferred-local lift round-trips byte-identically", roundtrip5 == source5, true) and ok

	return ok


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] statement_lift_test: %s" % label)
		return true
	print("[FAIL] statement_lift_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
