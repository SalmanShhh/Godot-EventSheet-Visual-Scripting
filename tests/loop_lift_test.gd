# EventForge — Phase 3 (Stage C) of the near-zero-RawCode roadmap: control-flow reverse-lift (loops).
# A `for X in EXPR:` / `for i in range(N):` / `while COND:` inside a lifted trigger body reverse-lifts
# to a PickFilter loop ROW (EXPRESSION / REPEAT / WHILE) with its body as sub-rows — instead of an
# in-flow GDScript cell. Mirrors the existing if/elif/else nesting; the byte-identical recompile gates
# every match. (No functions move, so the GDScript-backed-sheet append contract is untouched.)
@tool
extends RefCounted
class_name LoopLiftTest

static func run() -> bool:
	var ok: bool = true

	# Author an OnProcess body of three sibling loops (as a hand-written RawCode block).
	var authored: EventSheetResource = EventSheetResource.new()
	authored.host_class = "Node2D"
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnProcess"
	var raw: RawCodeRow = RawCodeRow.new()
	raw.code = "for enemy in get_tree().get_nodes_in_group(\"enemies\"):\n\tenemy.queue_free()\nfor i in range(3):\n\tspawn()\nwhile health > 0:\n\thealth -= 1"
	event.actions.append(raw)
	authored.events.append(event)
	var source: String = str(SheetCompiler.compile(authored, "user://loop_source.gd").get("output", ""))

	# Open the OUTPUT as a sheet: each loop header should become a PickFilter loop row.
	var imported: EventSheetResource = GDScriptImporter.new().import_external_source(source)
	var kinds: Array = _collect_pick_kinds(imported.events)
	ok = _check("for-in lifts to an EXPRESSION loop row", kinds.has(PickFilter.CollectionKind.EXPRESSION), true) and ok
	ok = _check("range() lifts to a REPEAT loop row", kinds.has(PickFilter.CollectionKind.REPEAT), true) and ok
	ok = _check("while lifts to a WHILE loop row", kinds.has(PickFilter.CollectionKind.WHILE), true) and ok
	ok = _check("no loop header stayed an in-flow code cell", _has_raw_loop_header(imported.events), false) and ok

	# The contract: recompiling reproduces the source byte-for-byte.
	imported.external_source_path = "user://loop_rt.gd"
	var roundtrip: String = str(SheetCompiler.compile(imported, "user://loop_rt.gd").get("output", ""))
	ok = _check("loop lift round-trips byte-identically", roundtrip == source, true) and ok
	if roundtrip != source:
		print("  --- source ---\n%s\n  --- roundtrip ---\n%s" % [source, roundtrip])

	# Nested control flow: a `for` containing an `if` containing a `while` must lift to NESTED loop
	# rows (regression pin for _is_plain_collector — a loop child must not be mistaken for a plain
	# statement collector, which would drop its pick_filter and force a raw fallback).
	var nested: EventSheetResource = EventSheetResource.new()
	nested.host_class = "Node2D"
	var nevent: EventRow = EventRow.new()
	nevent.trigger_provider_id = "Core"
	nevent.trigger_id = "OnProcess"
	var nraw: RawCodeRow = RawCodeRow.new()
	nraw.code = "for x in a:\n\tif c:\n\t\twhile d:\n\t\t\tbar()"
	nevent.actions.append(nraw)
	nested.events.append(nevent)
	var nsource: String = str(SheetCompiler.compile(nested, "user://nest_source.gd").get("output", ""))
	var nimported: EventSheetResource = GDScriptImporter.new().import_external_source(nsource)
	var nkinds: Array = _collect_pick_kinds(nimported.events)
	ok = _check("nested: outer for lifts to an EXPRESSION row", nkinds.has(PickFilter.CollectionKind.EXPRESSION), true) and ok
	ok = _check("nested: inner while lifts (through the if)", nkinds.has(PickFilter.CollectionKind.WHILE), true) and ok
	nimported.external_source_path = "user://nest_rt.gd"
	var nroundtrip: String = str(SheetCompiler.compile(nimported, "user://nest_rt.gd").get("output", ""))
	ok = _check("nested control flow round-trips byte-identically", nroundtrip == nsource, true) and ok
	if nroundtrip != nsource:
		print("  --- nsource ---\n%s\n  --- nroundtrip ---\n%s" % [nsource, nroundtrip])

	return ok

## Walks events + their sub_events, collecting every PickFilter's collection_kind.
static func _collect_pick_kinds(rows: Array) -> Array:
	var kinds: Array = []
	for row: Variant in rows:
		if row is EventRow:
			for pf: Variant in (row as EventRow).pick_filters:
				if pf is PickFilter:
					kinds.append((pf as PickFilter).collection_kind)
			kinds.append_array(_collect_pick_kinds((row as EventRow).sub_events))
	return kinds

## True if any loop header (`for `/`while `) survived as an in-flow RawCode cell instead of a row.
static func _has_raw_loop_header(rows: Array) -> bool:
	for row: Variant in rows:
		if row is EventRow:
			for a: Variant in (row as EventRow).actions:
				if a is RawCodeRow and ((a as RawCodeRow).code.contains("for ") or (a as RawCodeRow).code.contains("while ")):
					return true
			if _has_raw_loop_header((row as EventRow).sub_events):
				return true
	return false

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] loop_lift_test: %s" % label)
		return true
	print("[FAIL] loop_lift_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
