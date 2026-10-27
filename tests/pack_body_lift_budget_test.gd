# Godot EventSheets - publishing a pack does not compile the whole sheet twice per function.
#
# A pack's function bodies are de-coded into rows at build time, each kept only when the file still
# compiles byte for byte to what it did. That gate used to compile the whole sheet twice for EVERY
# function - once before the swap and once after - so the cost grew with functions times file size.
# Measured 2026-10-27 on platformer_pathfinding (127 functions, 3,522 lines): 265 s of a 270 s build
# was that loop. Every kept swap leaves the output unchanged, so the gate now compiles the file once
# and tries the swaps in halves: the same pack builds in 18 s, its bytes unchanged.
#
# Pinned two ways, because a millisecond budget alone flaps on a loaded machine:
#   1. STRUCTURAL: the halving gate keeps exactly the swaps that leave the output alone, and applies
#      a run of harmless swaps once each - no per-swap compile, no per-swap revert.
#   2. A wall budget on a real pack build (save_system: 98 functions, 1,553 lines), three times
#      today's figure, which the per-function gate overran nine times over.
@tool
class_name PackBodyLiftBudgetTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const Lib := preload("res://tools/pack_builders/_lib.gd")

# `Lib.output_override_dir` is a shared static, and the budget wants a quiet machine: the serial tail.
const PARALLEL_UNSAFE := true

const PIN := "pack_body_lift_budget_test"
const TEMP_DIR := "user://eventsheets_pack_body_lift_budget"
const BUILDER := "res://tools/pack_builders/save_system.gd"
const SHIPPED := "res://eventsheet_addons/save_system/save_system_addon.gd"
## Building the save_system pack through its real builder, redirected to a temporary folder.
## Measured 2026-10-27 with other Godot processes running: 51.6 and 53.8 s with two compiles of the
## sheet per function, 5.5, 5.8 and 6.6 s with the halving gate. Three times the latter.
const BUILD_BUDGET_MS: int = 18000


static func run() -> bool:
	var ok: bool = true
	ok = _pin_halving_gate() and ok
	ok = _pin_real_build() and ok
	return ok


## Sixteen swaps, one of which (the sixth) renames the class and so moves the output. The gate keeps
## the fifteen harmless ones, leaves the sixth out, and leaves the sheet compiling to what it did.
static func _pin_halving_gate() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	sheet.custom_class_name = "GateProbe"
	var before: String = str(SheetCompiler.echo(sheet).get("output", ""))
	var calls: Dictionary = {"in": 0, "out": 0, "bad_in": 0}
	var swaps: Array[Callable] = []
	for index: int in range(16):
		if index == 5:
			swaps.append(func(lift: bool) -> void:
				sheet.custom_class_name = "GateProbeMoved" if lift else "GateProbe"
				calls["bad_in" if lift else "out"] = int(calls["bad_in" if lift else "out"]) + 1)
		else:
			swaps.append(func(lift: bool) -> void:
				calls["in" if lift else "out"] = int(calls["in" if lift else "out"]) + 1)
	var kept: int = EventSheetACELifter._adopt_byte_identical(sheet, swaps)
	var after: String = str(SheetCompiler.echo(sheet).get("output", ""))
	var ok: bool = true
	ok = SUPPORT.check(PIN, "the fifteen harmless swaps are kept", kept, 15) and ok
	ok = SUPPORT.check(PIN, "the sheet compiles to what it did", after == before, true) and ok
	ok = SUPPORT.check(PIN, "the moving swap is left out", sheet.custom_class_name, "GateProbe") and ok
	# The runs tried: 0-15 (moved), 0-7 (moved), 0-3 (kept), 4-7 (moved), 4-5 (moved), 4 (kept),
	# 5 (moved), 6-7 (kept), 8-15 (kept) - nine compiles for sixteen swaps, where the per-swap gate
	# made thirty-two. A swap goes in once per run it is part of and comes out once per moved run.
	ok = SUPPORT.check(PIN, "harmless swaps put in", int(calls["in"]), 15 + 7 + 4 + 3 + 1 + 1 + 2 + 8) and ok
	ok = SUPPORT.check(PIN, "the moving swap tried once per halving down to it", int(calls["bad_in"]), 5) and ok
	ok = SUPPORT.check(PIN, "swaps taken back out", int(calls["out"]), 16 + 8 + 4 + 2 + 1) and ok
	return ok


static func _pin_real_build() -> bool:
	DirAccess.make_dir_recursive_absolute(TEMP_DIR)
	Lib.output_override_dir = TEMP_DIR
	var builder: GDScript = load(BUILDER)
	var start_usec: int = Time.get_ticks_usec()
	var built: bool = builder != null and bool(builder.call("build"))
	var elapsed_ms: int = int((Time.get_ticks_usec() - start_usec) / 1000)
	Lib.output_override_dir = ""
	var ok: bool = SUPPORT.check(PIN, "the save_system pack builds", built, true)
	var rebuilt: String = FileAccess.get_file_as_string(TEMP_DIR.path_join(SHIPPED.get_file()))
	ok = SUPPORT.check(PIN, "the rebuilt save_system pack is the shipped one", rebuilt == FileAccess.get_file_as_string(SHIPPED), true) and ok
	print("[budget] pack_body_lift save_system build %d ms (budget %d)" % [elapsed_ms, BUILD_BUDGET_MS])
	ok = SUPPORT.check(PIN, "the save_system pack builds within %d ms" % BUILD_BUDGET_MS, elapsed_ms <= BUILD_BUDGET_MS, true) and ok
	return ok
