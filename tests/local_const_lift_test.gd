# EventForge (gap G4) - a `const` inside a flow body round-trips as a Set Local Constant row instead of
# mis-lifting to a Set Variable named "const N". Three new Helper ACEs (plain / typed / inferred) mirror the
# Set Local Variable family; they emit `const ... = ...` via the registry template and are admitted to the
# reverse index (whitelisted out of the Helpers exclusion), where the literal_len sort makes typed outrank
# plain so `const N: int = 3` binds name="N". Everything is byte-gated by the recompile verify.
@tool
class_name LocalConstLiftTest
extends RefCounted


static func run() -> bool:
	var ok: bool = true

	# ── Registration: the three descriptors exist with the exact frozen templates ──
	ok = _check("SetLocalConst template", _template("SetLocalConst"), "const {name} = {value}") and ok
	ok = _check("SetLocalConstTyped template", _template("SetLocalConstTyped"), "const {name}: {const_type} = {value}") and ok
	ok = _check("SetLocalConstInferred template", _template("SetLocalConstInferred"), "const {name} := {value}") and ok

	# ── Reverse lift: all three const shapes lift, and nothing stays a raw cell ──
	var actions: Array = _lift_body_actions("const RATE = 3\nconst LIMIT: int = 10\nconst HEADING := Vector2.UP")
	var ids: Array = _ids(actions)
	ok = _check("plain const lifts to SetLocalConst", ids.has("SetLocalConst"), true) and ok
	ok = _check("typed const lifts to SetLocalConstTyped", ids.has("SetLocalConstTyped"), true) and ok
	ok = _check("inferred const lifts to SetLocalConstInferred", ids.has("SetLocalConstInferred"), true) and ok
	ok = _check("no in-flow const stayed a raw code cell", ids.has("__raw__"), false) and ok
	# Typed binds name="LIMIT", not name="LIMIT: int" (the typed-before-plain literal_len ordering).
	var typed: ACEAction = _by_id(actions, "SetLocalConstTyped")
	var typed_name: String = str((typed.params as Dictionary).get("name", "")) if typed != null else "<null>"
	ok = _check("typed const binds the bare name", typed_name, "LIMIT") and ok

	# ── Round-trip byte-identically (the covenant) ──
	ok = _roundtrips("const RATE = 3\nconst LIMIT: int = 10\nconst HEADING := Vector2.UP") and ok

	# ── Shadow guard: a plain assignment and a plain var are unaffected by the const additions ──
	var mixed: Array = _lift_body_actions("score = 3\nvar tmp = 7")
	var mixed_ids: Array = _ids(mixed)
	ok = _check("a plain assignment still lifts to SetVar", mixed_ids.has("SetVar"), true) and ok
	ok = _check("a plain local var still lifts to SetLocalVar", mixed_ids.has("SetLocalVar"), true) and ok
	ok = _check("neither mis-lifts to a const", mixed_ids.has("SetLocalConst") or mixed_ids.has("SetLocalConstTyped"), false) and ok

	# ── A const inside a loop body lifts too (const entries are not loop-control) and round-trips ──
	ok = _roundtrips("for i in range(3):\n\tconst STEP = 2\n\tmove(STEP)") and ok

	# ── Regression (review 22b835d): a string value containing both ': ' and ' = ' must NOT be carved by the
	# typed-const regex into name/type/value. It lifts to a PLAIN SetLocalConst with the string intact. ──
	var tricky: Array = _lift_body_actions("const FMT = \"ratio: a = b\"")
	var plain_c: ACEAction = _by_id(tricky, "SetLocalConst")
	ok = _check("a string with :/= lifts to PLAIN SetLocalConst (not typed)",
		plain_c != null and not _ids(tricky).has("SetLocalConstTyped"), true) and ok
	var fmt_name: String = str((plain_c.params as Dictionary).get("name", "")) if plain_c != null else "<null>"
	ok = _check("the const name is the bare identifier, string not split", fmt_name, "FMT") and ok
	ok = _roundtrips("const FMT = \"ratio: a = b\"") and ok

	return ok


static func _template(ace_id: String) -> String:
	var d: ACEDescriptor = ACERegistry.find_descriptor("Core", ace_id)
	return d.codegen_template if d != null else "<missing>"


## Authors an OnProcess body, compiles it, re-imports, and returns every lifted ACTION (recursively),
## with any surviving in-flow RawCodeRow represented by a synthetic action id "__raw__".
static func _lift_body_actions(body: String) -> Array:
	var authored: EventSheetResource = EventSheetResource.new()
	authored.host_class = "Node2D"
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnProcess"
	var raw: RawCodeRow = RawCodeRow.new()
	raw.code = body
	event.actions.append(raw)
	authored.events.append(event)
	var source: String = str(SheetCompiler.compile(authored, "user://lc_src.gd").get("output", ""))
	var imported: EventSheetResource = GDScriptImporter.new().import_external_source(source)
	return _collect_actions(imported.events)


static func _roundtrips(body: String) -> bool:
	var authored: EventSheetResource = EventSheetResource.new()
	authored.host_class = "Node2D"
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnProcess"
	var raw: RawCodeRow = RawCodeRow.new()
	raw.code = body
	event.actions.append(raw)
	authored.events.append(event)
	var source: String = str(SheetCompiler.compile(authored, "user://lc_src.gd").get("output", ""))
	var imported: EventSheetResource = GDScriptImporter.new().import_external_source(source)
	imported.external_source_path = "user://lc_rt.gd"
	var rt: String = str(SheetCompiler.compile(imported, "user://lc_rt.gd").get("output", ""))
	if rt != source:
		print("  --- source ---\n%s\n  --- roundtrip ---\n%s" % [source, rt])
	return _check("round-trips byte-identically (%s...)" % body.substr(0, 16), rt == source, true)


static func _collect_actions(rows: Array) -> Array:
	var out: Array = []
	for r: Variant in rows:
		if r is EventRow:
			for a: Variant in (r as EventRow).actions:
				out.append(a)
			out.append_array(_collect_actions((r as EventRow).sub_events))
	return out


static func _ids(actions: Array) -> Array:
	var out: Array = []
	for a: Variant in actions:
		if a is ACEAction:
			out.append((a as ACEAction).ace_id)
		elif a is RawCodeRow:
			out.append("__raw__")
	return out


static func _by_id(actions: Array, ace_id: String) -> ACEAction:
	for a: Variant in actions:
		if a is ACEAction and (a as ACEAction).ace_id == ace_id:
			return a as ACEAction
	return null


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] local_const_lift_test: %s" % label)
		return true
	print("[FAIL] local_const_lift_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
