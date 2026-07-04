# Godot EventSheets - include manager + Extract-to-Include test.
# Covers summarize() (what an included sheet contributes, for the manager preview) and
# extract_to_include() (move selected rows into a new library sheet + wire the include).
@tool
class_name SheetIncludesTest
extends RefCounted


static func run() -> bool:
    var passed: bool = true

    # ── summarize ──────────────────────────────────────────────────────────────────
    var library_sheet: EventSheetResource = EventSheetResource.new()
    library_sheet.custom_class_name = "Shared"
    library_sheet.variables = {"score": {"type": "int", "default": 0}, "lives": {"type": "int", "default": 3}}
    library_sheet.events.append(EventRow.new())
    var helper: EventFunction = EventFunction.new()
    helper.function_name = "add_score"
    library_sheet.functions.append(helper)
    var path: String = "user://_includes_test_lib.tres"
    ResourceSaver.save(library_sheet, path)
    var summary: Dictionary = EventSheetIncludes.summarize(path)
    passed = _check("summarize reports a valid include", bool(summary.get("valid", false)), true) and passed
    passed = _check("summarize counts events", int(summary.get("events", -1)), 1) and passed
    passed = _check("summarize lists functions", (summary.get("functions", []) as Array).has("add_score"), true) and passed
    passed = _check("summarize lists variables",
        (summary.get("variables", []) as Array).has("score") and (summary.get("variables", []) as Array).has("lives"), true) and passed
    passed = _check("summarize of a missing path is invalid",
        bool(EventSheetIncludes.summarize("res://does_not_exist.tres").get("valid", true)), false) and passed
    DirAccess.remove_absolute(path)

    # ── extract_to_include ─────────────────────────────────────────────────────────
    var source: EventSheetResource = EventSheetResource.new()
    source.host_class = "Node2D"
    var r1: EventRow = EventRow.new(); r1.event_uid = "r1"
    var r2: EventRow = EventRow.new(); r2.event_uid = "r2"
    var r3: EventRow = EventRow.new(); r3.event_uid = "r3"
    source.events.append(r1); source.events.append(r2); source.events.append(r3)
    var outcome: Dictionary = EventSheetIncludes.extract_to_include(source, [r1, r2], "res://lib/extracted.tres")
    var library: EventSheetResource = outcome.get("library") as EventSheetResource
    passed = _check("extract produced a library sheet", library != null, true) and passed
    passed = _check("library holds the extracted rows", library.events.size() if library != null else -1, 2) and passed
    passed = _check("library inherits the source host class", library.host_class if library != null else "", "Node2D") and passed
    passed = _check("source lost the extracted rows", source.events.size(), 1) and passed
    passed = _check("the one remaining row is r3", (source.events[0] as EventRow).event_uid, "r3") and passed
    passed = _check("source now includes the new library", source.includes.has("res://lib/extracted.tres"), true) and passed
    passed = _check("extracting nothing is rejected",
        str(EventSheetIncludes.extract_to_include(source, [], "res://x.tres").get("error", "")) != "", true) and passed

    # ── provenance: included_rows resolves what each include contributes ────────────
    var prov_lib: EventSheetResource = EventSheetResource.new()
    prov_lib.events.append(EventRow.new())
    prov_lib.events.append(EventRow.new())
    var prov_fn: EventFunction = EventFunction.new()
    prov_fn.function_name = "shared_helper"
    prov_lib.functions.append(prov_fn)
    prov_lib.variables = {"shared_var": {"type": "int", "default": 0}}
    var prov_path: String = "user://_includes_test_prov.tres"
    ResourceSaver.save(prov_lib, prov_path)
    var including: EventSheetResource = EventSheetResource.new()
    including.includes.append(prov_path)
    var provenance: Array = EventSheetIncludes.included_rows(including)
    passed = _check("included_rows resolves the include", provenance.size(), 1) and passed
    passed = _check("included_rows returns the included events (for read-only display)",
        (provenance[0].get("events", []) as Array).size() if not provenance.is_empty() else -1, 2) and passed
    passed = _check("included_rows lists the included functions",
        (provenance[0].get("functions", []) as Array).has("shared_helper") if not provenance.is_empty() else false, true) and passed
    DirAccess.remove_absolute(prov_path)

    # ── cycle guard ────────────────────────────────────────────────────────────────
    passed = _check("a sheet including itself is a cycle",
        EventSheetIncludes.would_create_cycle("res://a.tres", "res://a.tres"), true) and passed

    return passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
    if actual == expected:
        print("[PASS] sheet_includes_test: %s" % label)
        return true
    print("[FAIL] sheet_includes_test: %s" % label)
    print("  expected: %s" % str(expected))
    print("  actual:   %s" % str(actual))
    return false
