# EventForge - Phase 4: hinted exports (@export_range / @export_file / @export_flags / …).
# Inspector-tuned variables in an opened .gd lift to variable ROWS with the annotation kept verbatim
# (export_hint), instead of staying RawCode blocks - so a real tuned script renders as a sheet and
# round-trips byte-identically. The per-line verify-lift gate rejects any hint we can't reproduce.
@tool
class_name HintedExportTest
extends RefCounted

const SOURCE := "extends Node2D\n\n@export_range(0, 100) var speed: float = 5.0\n@export_file var data_path: String = \"\"\n@export_flags(\"Fire\", \"Water\") var elements: int = 0\n"


static func run() -> bool:
	var ok: bool = true
	var imported: EventSheetResource = GDScriptImporter.new().import_external_source(SOURCE)
	var hints: Dictionary = {}
	var ranges: Dictionary = {}
	var raw_blocks: int = 0
	for r: Variant in imported.events:
		if r is LocalVariable:
			hints[(r as LocalVariable).name] = (r as LocalVariable).export_hint
			ranges[(r as LocalVariable).name] = (r as LocalVariable).attributes.get("range", {})
		elif r is RawCodeRow and (r as RawCodeRow).code.contains("@export"):
			raw_blocks += 1
	# Range, file and flags hints all lift STRUCTURED: the hint moves into editable attributes and
	# export_hint empties. A two-argument @export_range leaves its step to Godot, so it reads with an
	# empty step that the compiler writes back unwritten.
	ok = _check("range hint lifts structured (hint consumed)", hints.get("speed", "missing"), "") and ok
	ok = _check("and its bounds are the variable's range, with no step written",
		ranges.get("speed", {}), {"min": "0", "max": "100", "step": ""}) and ok
	ok = _check("file hint lifts structured (hint consumed)", hints.get("data_path", "missing"), "") and ok
	ok = _check("flags hint lifts structured (hint consumed)", hints.get("elements", "missing"), "") and ok
	ok = _check("no hinted export stayed a raw block", raw_blocks, 0) and ok

	imported.external_source_path = "user://hint_rt.gd"
	var rt: String = str(SheetCompiler.compile(imported, "user://hint_rt.gd").get("output", ""))
	ok = _check("hinted exports round-trip byte-identically", rt == SOURCE, true) and ok
	if rt != SOURCE:
		print("    SRC<%s>\n    RT <%s>" % [SOURCE, rt])
	return ok


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] hinted_export_test: %s" % label)
		return true
	print("[FAIL] hinted_export_test: %s" % label)
	print("  expected: %s, actual: %s" % [str(expected), str(actual)])
	return false
