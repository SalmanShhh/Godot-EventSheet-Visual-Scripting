# Godot EventSheets - grouped @export emission collapses into clean Inspector folds.
#
# When sheet variables carry a group (or subgroup / category) attribute, the compiler clusters that
# section's variables contiguously and writes its @export_group header ONCE, so the Godot Inspector
# shows one collapsible fold per group instead of a header before every variable. A sheet with no
# groups keeps the exact pure-alphabetical order (byte-identical to before this change).
@tool
class_name InspectorGroupEmitTest
extends RefCounted


static func run() -> bool:
	var ok: bool = true

	# Variables whose NAMES interleave the groups alphabetically (alpha_move, beta_look, ...):
	# the old header-per-var path would have emitted the group headers interleaved and repeated.
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	sheet.variables = {
		"alpha_move": {"type": "float", "default": 1.0, "exported": true, "attributes": {"group": "Movement"}},
		"beta_look": {"type": "float", "default": 2.0, "exported": true, "attributes": {"group": "Look"}},
		"gamma_move": {"type": "float", "default": 3.0, "exported": true, "attributes": {"group": "Movement"}},
		"delta_look": {"type": "float", "default": 4.0, "exported": true, "attributes": {"group": "Look"}},
		"plain": {"type": "float", "default": 5.0, "exported": true},
	}
	var out: String = str(SheetCompiler.compile(sheet, "user://grp.gd").get("output", ""))
	ok = _check("each group header appears exactly once", _count(out, "@export_group(\"Movement\")") == 1 and _count(out, "@export_group(\"Look\")") == 1, true) and ok
	# The two Movement vars sit together under the one header (no other @export between them).
	var movement_block: String = out.substr(out.find("@export_group(\"Movement\")"))
	ok = _check("a group's variables cluster contiguously",
		movement_block.contains("alpha_move") and movement_block.contains("gamma_move")
		and not movement_block.substr(0, movement_block.find("gamma_move")).contains("@export_group(\"Look\")"), true) and ok
	# The ungrouped variable sorts BEFORE any group header (empty section first).
	ok = _check("ungrouped variables emit before any group", out.find("var plain") < out.find("@export_group"), true) and ok

	# A subgroup nests under its group and also emits once.
	var nested: EventSheetResource = EventSheetResource.new()
	nested.host_class = "Node"
	nested.variables = {
		"a": {"type": "int", "default": 1, "exported": true, "attributes": {"group": "Combat", "subgroup": "Melee"}},
		"b": {"type": "int", "default": 2, "exported": true, "attributes": {"group": "Combat", "subgroup": "Melee"}},
	}
	var nested_out: String = str(SheetCompiler.compile(nested, "user://grp2.gd").get("output", ""))
	ok = _check("group + subgroup each emit once, group before subgroup",
		_count(nested_out, "@export_group(\"Combat\")") == 1 and _count(nested_out, "@export_subgroup(\"Melee\")") == 1
		and nested_out.find("@export_group(\"Combat\")") < nested_out.find("@export_subgroup(\"Melee\")"), true) and ok

	# The covenant: a sheet with NO groups is byte-identical to the pure-alphabetical order.
	var flat: EventSheetResource = EventSheetResource.new()
	flat.host_class = "Node"
	flat.variables = {
		"zulu": {"type": "int", "default": 1, "exported": true},
		"alpha": {"type": "int", "default": 2, "exported": true},
		"mike": {"type": "int", "default": 3, "exported": true},
	}
	var flat_out: String = str(SheetCompiler.compile(flat, "user://grp3.gd").get("output", ""))
	ok = _check("ungrouped vars stay pure-alphabetical (alpha < mike < zulu)",
		flat_out.find("var alpha") < flat_out.find("var mike") and flat_out.find("var mike") < flat_out.find("var zulu"), true) and ok
	ok = _check("no group header appears when nothing is grouped", flat_out.contains("@export_group"), false) and ok

	return ok


static func _count(haystack: String, needle: String) -> int:
	var n: int = 0
	var from: int = haystack.find(needle)
	while from >= 0:
		n += 1
		from = haystack.find(needle, from + needle.length())
	return n


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] inspector_group_emit_test: %s" % label)
		return true
	print("[FAIL] inspector_group_emit_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
