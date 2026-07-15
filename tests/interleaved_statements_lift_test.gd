# EventForge (gap G4) - a statement placed AFTER a nested block in the same body no longer collapses the
# whole enclosing block to a verbatim code cell. `if outer: pre(); if inner: mid(); post()` used to lift to
# ZERO structure (the whole outer block became one RawCodeRow) because the emitter writes an event's actions
# before its sub-events, so a trailing statement had no home. Now a plain collector that appears after a
# nested block becomes a CONDITION-LESS sub-event (an "Every Tick" row), which the compiler already emits as
# bare statements at the parent's body depth - so the block reads fully as events and still re-emits byte for
# byte. Every reconstruction is gated by the byte-identical recompile, so the .gd round-trips.
@tool
class_name InterleavedStatementsLiftTest
extends RefCounted


static func run() -> bool:
	var ok: bool = true

	# An `if` whose body has a leading statement, a nested `if`, and a TRAILING statement after that if.
	ok = _case("if with a trailing statement after a nested if",
		"if outer:\n\tpre()\n\tif inner:\n\t\tmid()\n\tpost()", 2) and ok
	# A loop whose body has a nested `if` and then a trailing statement.
	ok = _case("loop with a trailing statement after a nested if",
		"for e in items:\n\te.pre()\n\tif e.hit:\n\t\te.flash()\n\te.post()", 2) and ok
	# Arbitrary interleaving: statement, block, statement, block, statement.
	ok = _case("arbitrary interleaving of statements and blocks",
		"if gate:\n\tstep_1()\n\tif a:\n\t\tstep_2()\n\tstep_3()\n\tif b:\n\t\tstep_4()\n\tstep_5()", 4) and ok
	# No LEADING statement - a nested block then a trailing statement (actions empty, two sub-events).
	ok = _case("nested block then trailing statement, no leading action",
		"if outer:\n\tif inner:\n\t\tmid()\n\tpost()", 2) and ok

	# Adversarial byte-trap: a trailing assignment whose value literally contains a compound-assign operator
	# inside a string must stay a verbatim action (not mis-lift to Add To Property) - and still round-trip.
	ok = _case("trailing string with a += operator stays verbatim",
		"if outer:\n\tif inner:\n\t\tmid()\n\tlabel.text = \"x += 1\"", 2) and ok

	# Regression: the control case (statement only BEFORE the block) is unchanged - one sub-event.
	ok = _case("control: leading statement then block only (unchanged)",
		"if outer:\n\tpre()\n\tif inner:\n\t\tmid()", 1) and ok

	return ok


## Authors an OnProcess body, compiles it, re-opens it, asserts the OUTER block structured with
## `expected_children` sub-events (the interleaving), and that the whole thing round-trips byte-exact.
static func _case(label: String, body: String, expected_children: int) -> bool:
	var ok: bool = true
	var authored: EventSheetResource = EventSheetResource.new()
	authored.host_class = "Node2D"
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnProcess"
	var raw: RawCodeRow = RawCodeRow.new()
	raw.code = body
	event.actions.append(raw)
	authored.events.append(event)
	var source: String = str(SheetCompiler.compile(authored, "user://il_source.gd").get("output", ""))

	var imported: EventSheetResource = GDScriptImporter.new().import_external_source(source)
	# The outer block is the first event that carries a condition or a loop and has children.
	var outer: EventRow = _first_block_with_children(imported.events)
	ok = _check("%s: the outer block structured (did not stay a raw cell)" % label, outer != null, true) and ok
	if outer != null:
		ok = _check("%s: outer block has the expected sub-event count" % label, outer.sub_events.size(), expected_children) and ok

	imported.external_source_path = "user://il_rt.gd"
	var roundtrip: String = str(SheetCompiler.compile(imported, "user://il_rt.gd").get("output", ""))
	ok = _check("%s: round-trips byte-identically" % label, roundtrip == source, true) and ok
	if roundtrip != source:
		print("  --- source ---\n%s\n  --- roundtrip ---\n%s" % [source, roundtrip])
	return ok


## The first EventRow (depth-first) that is a real block (has conditions or a pick_filter) AND has children.
static func _first_block_with_children(rows: Array) -> EventRow:
	for r: Variant in rows:
		if r is EventRow:
			var ev: EventRow = r as EventRow
			var is_block: bool = not ev.conditions.is_empty() or not ev.pick_filters.is_empty()
			if is_block and not ev.sub_events.is_empty():
				return ev
			var nested: EventRow = _first_block_with_children(ev.sub_events)
			if nested != null:
				return nested
	return null


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] interleaved_statements_lift_test: %s" % label)
		return true
	print("[FAIL] interleaved_statements_lift_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
