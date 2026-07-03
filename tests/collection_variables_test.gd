# Godot EventSheets — Collection variables (rich-variables phase 2)
# Array/Dictionary (incl. Godot 4 typed Array[T] / Dictionary[K, V]) variables with
# canonical literal emission (recursive, escaped, str_to_var-parseable), verify-lift
# round-trips, and dialog literal validation (live hint + commit guardrail).
@tool
class_name CollectionVariablesTest
extends RefCounted


static func run() -> bool:
	var all_passed: bool = true

	# Canonical emission: recursion, escaping, determinism.
	var sheet: EventSheetResource = EventSheetResource.new()
	var inventory: LocalVariable = LocalVariable.new()
	inventory.name = "inventory"
	inventory.type_name = "Dictionary"
	inventory.default_value = {"sword": 1, "note": "say \"hi\"", "nested": {"ids": [1, 2.5]}}
	sheet.events.append(inventory)
	var ids: LocalVariable = LocalVariable.new()
	ids.name = "ids"
	ids.type_name = "Array[int]"
	ids.default_value = [1, 2, 3]
	ids.exported = true
	sheet.events.append(ids)
	sheet.variables = {"tags": {"type": "Array[String]", "default": ["a", "b"], "exported": true}}
	var output: String = str(SheetCompiler.compile(sheet, "user://eventsheets_coll.gd").get("output", ""))
	all_passed = _check("dictionary emits canonically (escaped, recursive)",
		output.contains("var inventory: Dictionary = {\"sword\": 1, \"note\": \"say \\\"hi\\\"\", \"nested\": {\"ids\": [1, 2.5]}}"), true) and all_passed
	all_passed = _check("typed array emits", output.contains("@export var ids: Array[int] = [1, 2, 3]"), true) and all_passed
	all_passed = _check("global collection variables emit", output.contains("@export var tags: Array[String] = [\"a\", \"b\"]"), true) and all_passed
	var generated: GDScript = GDScript.new()
	generated.source_code = output
	all_passed = _check("collection output parses", generated.reload(true) == OK, true) and all_passed

	# Verify-lift: canonical collection declarations re-open as variable rows.
	var external_source: String = "extends Node\n\n@export var ids: Array[int] = [1, 2, 3]\n\nvar inv: Dictionary = {\"sword\": 1}\n\nvar messy: Dictionary = { \"a\":1 }\n"
	var imported: EventSheetResource = GDScriptImporter.new().import_external_source(external_source)
	var lifted_ids: LocalVariable = null
	var lifted_inv: LocalVariable = null
	var messy_stays_block: bool = false
	for row in imported.events:
		if row is LocalVariable:
			if (row as LocalVariable).name == "ids":
				lifted_ids = row
			elif (row as LocalVariable).name == "inv":
				lifted_inv = row
		elif row is RawCodeRow and (row as RawCodeRow).code.contains("messy"):
			messy_stays_block = true
	all_passed = _check("typed array lifts with its value",
		lifted_ids != null and lifted_ids.type_name == "Array[int]" and lifted_ids.default_value == [1, 2, 3] and lifted_ids.exported, true) and all_passed
	all_passed = _check("dictionary lifts with its value",
		lifted_inv != null and lifted_inv.default_value == {"sword": 1}, true) and all_passed
	all_passed = _check("non-canonical literals stay blocks", messy_stays_block, true) and all_passed
	imported.external_source_path = "user://eventsheets_coll_rt.gd"
	var roundtrip: String = str(SheetCompiler.compile(imported, "user://eventsheets_coll_rt.gd").get("output", ""))
	all_passed = _check("collection round-trip is byte-identical", roundtrip == external_source, true) and all_passed

	# Dialog parsing + validation guardrails.
	all_passed = _check("array literal parses", VariableDialog._parse_default("Array", "[1, 2]"), [1, 2]) and all_passed
	all_passed = _check("empty dictionary default", VariableDialog._parse_default("Dictionary[String, int]", ""), {}) and all_passed
	all_passed = _check("valid literal passes",
		bool(VariableDialog.validate_default("Dictionary", "{\"k\": 1}").get("ok", false)), true) and all_passed
	all_passed = _check("wrong container kind fails",
		bool(VariableDialog.validate_default("Array", "{\"k\": 1}").get("ok", true)), false) and all_passed
	all_passed = _check("garbage fails",
		bool(VariableDialog.validate_default("Dictionary", "not a dict").get("ok", true)), false) and all_passed
	all_passed = _check("typed element mismatch fails",
		bool(VariableDialog.validate_default("Array[int]", "[1, \"a\"]").get("ok", true)), false) and all_passed
	all_passed = _check("ints satisfy float elements",
		bool(VariableDialog.validate_default("Array[float]", "[1, 2.5]").get("ok", false)), true) and all_passed
	all_passed = _check("typed dictionary checks value types",
		bool(VariableDialog.validate_default("Dictionary[String, int]", "{\"a\": \"x\"}").get("ok", true)), false) and all_passed
	all_passed = _check("scalars skip collection validation",
		bool(VariableDialog.validate_default("int", "whatever").get("ok", false)), true) and all_passed

	# Structured "Edit items…" data editor: literal <-> one-item-per-line round-trip.
	all_passed = _check("array literal splits into top-level items (bracket+string aware)",
		Array(VariableDialog.collection_literal_items("[1, [2, 3], \"a,b\"]")), ["1", "[2, 3]", "\"a,b\""]) and all_passed
	all_passed = _check("dictionary literal splits into pairs",
		Array(VariableDialog.collection_literal_items("{\"a\": 1, \"b\": 2}")), ["\"a\": 1", "\"b\": 2"]) and all_passed
	all_passed = _check("items wrap back into an array literal",
		VariableDialog.items_to_collection_literal(PackedStringArray(["1", "2"]), false), "[1, 2]") and all_passed
	all_passed = _check("items wrap back into a dictionary literal",
		VariableDialog.items_to_collection_literal(PackedStringArray(["\"a\": 1"]), true), "{\"a\": 1}") and all_passed
	all_passed = _check("empty items -> empty array literal",
		VariableDialog.items_to_collection_literal(PackedStringArray(), false), "[]") and all_passed

	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] collection_variables_test: %s" % label)
		return true
	print("[FAIL] collection_variables_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
