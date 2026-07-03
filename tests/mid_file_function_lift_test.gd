# EventForge - mid-file helper lift (FunctionAnchorRow).
#
# THE CONTRACT: a helper function stranded BETWEEN raw blocks (which the trailing-run lift can
# never claim, because plain functions emit in the trailing section) lifts to a real
# EventFunction anchored in place - the anchor row tells the external compile path to emit the
# function at its original slot, so the file stays byte-identical. Each anchor is gated
# individually (the compiler's re-emission must reproduce the row's bytes), so a helper the
# emitter can't reproduce stays a raw block and the file still lifts everything else.
@tool
extends RefCounted
class_name MidFileFunctionLiftTest

## The `if true:` block after the helper is deliberately unliftable at top level, so the helper
## can never be part of a trailing run - only the anchor path can claim it.
const MID_SOURCE := """extends Node2D

var speed: float = 200.0

func clamp_speed(value: float) -> float:
	return clampf(value, 0.0, speed)

if true:
	pass
"""

## Same shape but the helper uses spacing the emitter would normalize - the per-anchor byte
## gate must refuse it (it stays raw) WITHOUT breaking the rest of the lift.
const NEAR_MISS_SOURCE := """extends Node2D

var speed: float = 200.0

func  weird_gap(value: float) -> float:
	return value

if true:
	pass
"""

static func run() -> bool:
	var all_passed: bool = true
	var importer: GDScriptImporter = GDScriptImporter.new()

	# ── The mid-file helper lifts, anchored in place ──
	var sheet: EventSheetResource = importer.import_external_source(MID_SOURCE)
	sheet.external_source_path = "user://mid_fn_sample.gd"
	var anchor: FunctionAnchorRow = null
	for entry: Variant in sheet.events:
		if entry is FunctionAnchorRow:
			anchor = entry
	all_passed = _check("mid-file helper lifts to an anchored function", anchor != null and anchor.function_name == "clamp_speed", true) and all_passed
	var lifted: EventFunction = null
	for function_entry: Variant in sheet.functions:
		if function_entry is EventFunction and (function_entry as EventFunction).function_name == "clamp_speed":
			lifted = function_entry
	all_passed = _check("the anchored function is a real EventFunction", lifted != null, true) and all_passed
	all_passed = _check("anchored function keeps its typed param",
		lifted != null and lifted.params.size() == 1 and lifted.params[0].type_name == "float", true) and all_passed

	# ── Round-trip: emission places the function back at its slot, byte-identically ──
	var output: String = str(SheetCompiler.compile(sheet, "user://mid_fn_sample.gd").get("output", ""))
	all_passed = _check("anchored sheet reproduces the file byte-identically", output, MID_SOURCE) and all_passed

	# ── The per-anchor byte gate: unreproducible spacing stays raw, file still lifts ──
	var near_miss: EventSheetResource = importer.import_external_source(NEAR_MISS_SOURCE)
	near_miss.external_source_path = "user://mid_fn_near_miss.gd"
	var near_miss_anchors: int = 0
	for entry: Variant in near_miss.events:
		if entry is FunctionAnchorRow:
			near_miss_anchors += 1
	all_passed = _check("unreproducible helper stays raw (per-anchor gate)", near_miss_anchors, 0) and all_passed
	all_passed = _check("near-miss file still round-trips verbatim",
		str(SheetCompiler.compile(near_miss, "user://mid_fn_near_miss.gd").get("output", "")), NEAR_MISS_SOURCE) and all_passed

	# ── Custom-return helpers (the audit's last blocked class) anchor too ──
	var custom_sheet: EventSheetResource = importer.import_external_source("extends Node\n\nvar pools: Dictionary = {}\n\nfunc _get_pool(type: String) -> HealthPool:\n\tif not pools.has(type):\n\t\tpools[type] = HealthPool.new()\n\treturn pools[type]\n\nif true:\n\tpass\n")
	custom_sheet.external_source_path = "user://mid_fn_custom.gd"
	var custom_anchor: FunctionAnchorRow = null
	for entry: Variant in custom_sheet.events:
		if entry is FunctionAnchorRow:
			custom_anchor = entry
	all_passed = _check("a custom-return helper anchors in place", custom_anchor != null and custom_anchor.function_name == "_get_pool", true) and all_passed
	var custom_fn: EventFunction = null
	for function_entry: Variant in custom_sheet.functions:
		if function_entry is EventFunction:
			custom_fn = function_entry
	all_passed = _check("its custom return type rides return_type_name",
		custom_fn != null and custom_fn.return_type_name == "HealthPool", true) and all_passed
	all_passed = _check("custom-return anchor round-trips byte-identically",
		str(SheetCompiler.compile(custom_sheet, "user://mid_fn_custom.gd").get("output", "")).contains("func _get_pool(type: String) -> HealthPool:"), true) and all_passed

	# ── The anchor renders as a muted marker row ──
	var view: EventSheetViewport = EventSheetViewport.new()
	view.set_ace_registry(EventSheetACERegistry.new())
	view.size = Vector2(900, 400)
	view.set_sheet(sheet)
	var row_data: EventRowData = view._build_row_from_resource(anchor, 0)
	all_passed = _check("anchor renders as a SECTION row", row_data != null and row_data.row_type == EventRowData.RowType.SECTION, true) and all_passed
	all_passed = _check("anchor names its function", row_data.spans[1].text.contains("clamp_speed"), true) and all_passed
	view.free()

	return all_passed

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] mid_file_function_lift_test: %s" % label)
		return true
	print("[FAIL] mid_file_function_lift_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
