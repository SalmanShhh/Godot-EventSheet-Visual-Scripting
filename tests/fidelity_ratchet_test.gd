# EventForge — Phase 4: the reverse-lift FIDELITY RATCHET.
# A representative hand-written script must keep lifting AT LEAST this richly — variables, a helper
# function, a loop, a condition, and statements all become rows, and the whole file round-trips
# byte-identically. If a change regresses coverage, the raw-block count climbs past the cap (or a
# structure stops lifting) and this fails — the ratchet only tightens, never silently loosens.
@tool
extends RefCounted
class_name FidelityRatchetTest

const SOURCE := "extends Node2D\n\nvar speed: float = 100.0\nvar active: bool = true\n\nfunc _process(delta: float) -> void:\n\tif active:\n\t\tposition.x += speed\n\tfor enemy in get_tree().get_nodes_in_group(\"foes\"):\n\t\tenemy.set_visible(false)\n\nfunc reset() -> void:\n\tspeed = 0.0\n"

# The only block that stays raw is the structural `extends Node2D` class-header prelude (kept verbatim
# while host_class is also set, for lint/completion). Every actual STATEMENT, loop, condition, variable,
# and function lifts to a row — so the cap is 1 (the prelude). It may only ever drop, never climb.
const MAX_RAW_BLOCKS := 1

static func run() -> bool:
	var ok: bool = true
	var imported: EventSheetResource = GDScriptImporter.new().import_external_source(SOURCE)
	var c: Dictionary = {"vars": 0, "picks": 0, "conds": 0, "acts": 0, "raw": 0}
	_count(imported.events, c)
	for fn: Variant in imported.functions:
		_count((fn as EventFunction).events, c)
	print("[ratchet] vars=%d funcs=%d picks=%d conds=%d acts=%d raw=%d" % [c["vars"], imported.functions.size(), c["picks"], c["conds"], c["acts"], c["raw"]])

	ok = _check("two local variables lifted", c["vars"], 2) and ok
	ok = _check("helper function lifted", imported.functions.size() >= 1, true) and ok
	ok = _check("for-loop lifted to a pick filter", c["picks"] >= 1, true) and ok
	ok = _check("if condition lifted", c["conds"] >= 1, true) and ok
	ok = _check("statements lifted to ACE actions", c["acts"] >= 2, true) and ok
	ok = _check("raw blocks at or below the ratchet (%d)" % MAX_RAW_BLOCKS, c["raw"] <= MAX_RAW_BLOCKS, true) and ok

	imported.external_source_path = "user://ratchet_rt.gd"
	var rt: String = str(SheetCompiler.compile(imported, "user://ratchet_rt.gd").get("output", ""))
	ok = _check("representative script round-trips byte-identically", rt == SOURCE, true) and ok
	if rt != SOURCE:
		print("    SRC<%s>\n    RT <%s>" % [SOURCE, rt])
	return ok

static func _count(rows: Array, c: Dictionary) -> void:
	for r: Variant in rows:
		if r is LocalVariable:
			c["vars"] += 1
		elif r is EventRow:
			var ev: EventRow = r as EventRow
			c["conds"] += ev.conditions.size()
			c["picks"] += ev.pick_filters.size()
			for a: Variant in ev.actions:
				if a is ACEAction:
					c["acts"] += 1
				elif a is RawCodeRow:
					c["raw"] += 1
			_count(ev.sub_events, c)
		elif r is RawCodeRow:
			c["raw"] += 1

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] fidelity_ratchet_test: %s" % label)
		return true
	print("[FAIL] fidelity_ratchet_test: %s" % label)
	print("  expected: %s, actual: %s" % [str(expected), str(actual)])
	return false
